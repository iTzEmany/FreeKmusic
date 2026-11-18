package com.codecore.player

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Pure-Kotlin DSP of the Spleeter 2-stem recipe (STFT 4096/1024, ratio mask, WAV). No Android here. */
object SpleeterDsp {
    const val N = 4096
    const val HOP = 1024
    const val BINS = N / 2 + 1
    const val MODEL_BINS = 1024
    const val BLOCK = 512
    const val RATE = 44100
    private const val EPS = 1e-10f

    /** Periodic Hann, the same as np.hanning(N + 1)[:-1]. */
    val window = DoubleArray(N) { 0.5 - 0.5 * cos(2.0 * PI * it / N) }

    /** In-place iterative radix-2 complex FFT of size [n] (a power of two). */
    class Fft(private val n: Int) {
        private val cosT = DoubleArray(n / 2) { cos(2.0 * PI * it / n) }
        private val sinT = DoubleArray(n / 2) { -sin(2.0 * PI * it / n) }
        private val rev = IntArray(n).also { r ->
            val bits = Integer.numberOfTrailingZeros(n)
            for (i in 0 until n) r[i] = Integer.reverse(i) ushr (32 - bits)
        }

        fun forward(re: DoubleArray, im: DoubleArray) {
            for (i in 0 until n) {
                val j = rev[i]
                if (j > i) {
                    var t = re[i]; re[i] = re[j]; re[j] = t
                    t = im[i]; im[i] = im[j]; im[j] = t
                }
            }
            var len = 2
            while (len <= n) {
                val half = len / 2
                val step = n / len
                var start = 0
                while (start < n) {
                    for (k in 0 until half) {
                        val wr = cosT[k * step]
                        val wi = sinT[k * step]
                        val a = start + k
                        val b = a + half
                        val tr = re[b] * wr - im[b] * wi
                        val ti = re[b] * wi + im[b] * wr
                        re[b] = re[a] - tr; im[b] = im[a] - ti
                        re[a] += tr; im[a] += ti
                    }
                    start += len
                }
                len *= 2
            }
        }
    }

    /** Frames of the padded signal (N zeros before, N + HOP after) for [n] samples. */
    fun frameCount(n: Int): Int = 1 + (n + N + HOP) / HOP

    /** Per-frame STFT and overlap-add synthesis; owns its scratch, so one per thread. */
    class Stft {
        private val fft = Fft(N)
        private val re = DoubleArray(N)
        private val im = DoubleArray(N)

        /** Spectrum of [frame] of the 16-bit [x] (unpadded) into [outRe]/[outIm] at [off], BINS values each. */
        fun analyze(x: ShortArray, frame: Int, outRe: FloatArray, outIm: FloatArray, off: Int) {
            for (k in 0 until N) {
                val i = frame * HOP + k - N
                re[k] = if (i in x.indices) x[i] / 32768.0 * window[k] else 0.0
                im[k] = 0.0
            }
            fft.forward(re, im)
            for (b in 0 until BINS) {
                outRe[off + b] = re[b].toFloat()
                outIm[off + b] = im[b].toFloat()
            }
        }

        /** Adds the windowed inverse of the BINS-bin spectrum at [off] into [out], whose index 0 is sample [base]. */
        fun synthesize(inRe: FloatArray, inIm: FloatArray, off: Int, frame: Int, out: FloatArray, base: Int = 0) {
            for (b in 0 until BINS) {
                re[b] = inRe[off + b].toDouble()
                // Inverse through the forward FFT: conjugate in, conjugate out.
                im[b] = -inIm[off + b].toDouble()
            }
            for (b in BINS until N) {
                re[b] = re[N - b]
                im[b] = -im[N - b]
            }
            fft.forward(re, im)
            for (k in 0 until N) {
                val i = frame * HOP + k - N - base
                if (i in out.indices) out[i] += (re[k] / N * window[k]).toFloat()
            }
        }
    }

    /**
     * Mask of one frame into [mask] (BINS): ratio mask for the first MODEL_BINS, then the mean of
     * the last 64 of them for every bin above. [voc]/[acc] are magnitudes read from [off].
     */
    fun maskFrame(voc: FloatArray, acc: FloatArray, off: Int, mask: FloatArray) {
        for (k in 0 until MODEL_BINS) {
            val v = voc[off + k] * voc[off + k]
            val a = acc[off + k] * acc[off + k]
            mask[k] = (a + EPS / 2) / (v + a + EPS)
        }
        var s = 0f
        for (k in MODEL_BINS - 64 until MODEL_BINS) s += mask[k]
        mask.fill(s / 64, MODEL_BINS, BINS)
    }

    /** Voice spectrum of one frame: (1 - [mask]) of the BINS bins at [off], so base + voice is the original. */
    fun voiceFrame(re: FloatArray, im: FloatArray, off: Int, mask: FloatArray, outRe: FloatArray, outIm: FloatArray) {
        for (k in 0 until BINS) {
            outRe[k] = re[off + k] * (1f - mask[k])
            outIm[k] = im[off + k] * (1f - mask[k])
        }
    }

    /** A WAV that is not the 44-byte-header 16-bit stereo 44.1 kHz file [writeWavHeader] makes, or a pair of different lengths. */
    class WavFormatException(message: String) : IOException(message)

    /** Reads the header and returns the number of data bytes. */
    private fun readWavHeader(ins: InputStream): Int {
        val h = ByteArray(44)
        var got = 0
        while (got < 44) {
            val r = ins.read(h, got, 44 - got)
            if (r < 0) throw WavFormatException("truncated WAV header")
            got += r
        }
        val b = ByteBuffer.wrap(h).order(ByteOrder.LITTLE_ENDIAN)
        val ok = String(h, 0, 4) == "RIFF" && String(h, 8, 8) == "WAVEfmt " && b.getInt(16) == 16 &&
            b.getShort(20).toInt() == 1 && b.getShort(22).toInt() == 2 && b.getInt(24) == RATE &&
            b.getShort(34).toInt() == 16 && String(h, 36, 4) == "data"
        val data = b.getInt(40)
        if (!ok || data < 0 || data % 4 != 0) throw WavFormatException("unsupported WAV")
        return data
    }

    /** Streams two [writeWavHeader] WAVs of the same length into one: base + level * voice, clamped to 16 bit. */
    fun mixWav(base: InputStream, voice: InputStream, level: Double, out: OutputStream) {
        val total = readWavHeader(base)
        if (readWavHeader(voice) != total) throw WavFormatException("base and voice differ in length")
        writeWavHeader(out, total / 4)
        val a = ByteArray(1 shl 16)
        val v = ByteArray(1 shl 16)
        var left = total
        while (left > 0) {
            val n = min(left, a.size)
            readFully(base, a, n)
            readFully(voice, v, n)
            val ab = ByteBuffer.wrap(a, 0, n).order(ByteOrder.LITTLE_ENDIAN)
            val vb = ByteBuffer.wrap(v, 0, n).order(ByteOrder.LITTLE_ENDIAN)
            val ob = ByteBuffer.wrap(a, 0, n).order(ByteOrder.LITTLE_ENDIAN) // overwrites the base in place
            for (i in 0 until n / 2) {
                val s = Math.round(ab.getShort(i * 2) + level * vb.getShort(i * 2)).toInt()
                ob.putShort(i * 2, s.coerceIn(-32768, 32767).toShort())
            }
            out.write(a, 0, n)
            left -= n
        }
    }

    private fun readFully(ins: InputStream, buf: ByteArray, n: Int) {
        var got = 0
        while (got < n) {
            val r = ins.read(buf, got, n - got)
            if (r < 0) throw WavFormatException("truncated WAV data")
            got += r
        }
    }

    /** Interleaved 16-bit PCM to two 44.1 kHz 16-bit channels (mono duplicated, linear resampling). */
    fun toStereo44k(pcm: ShortArray, size: Int, channels: Int, rate: Int): Array<ShortArray> {
        val frames = size / channels
        val outLen = (frames.toLong() * RATE / rate).toInt()
        val r = if (channels > 1) 1 else 0
        val out = Array(2) { ShortArray(outLen) }
        val ratio = rate.toDouble() / RATE
        for (i in 0 until outLen) {
            val pos = i * ratio
            val i0 = min(floor(pos).toInt(), frames - 1)
            val i1 = min(i0 + 1, frames - 1)
            val t = (pos - i0).toFloat()
            for (c in 0..1) {
                val ch = if (c == 0) 0 else r
                val a = pcm[i0 * channels + ch]
                val b = pcm[i1 * channels + ch]
                out[c][i] = Math.round(a + (b - a) * t).toShort()
            }
        }
        return out
    }

    /** Header of a 16-bit stereo 44.1 kHz WAV of [frames] sample frames. */
    fun writeWavHeader(os: OutputStream, frames: Int) {
        val data = frames * 4
        val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()).putInt(36 + data).put("WAVEfmt ".toByteArray())
            .putInt(16).putShort(1).putShort(2).putInt(RATE).putInt(RATE * 4).putShort(4).putShort(16)
            .put("data".toByteArray()).putInt(data)
        os.write(h.array())
    }

    /**
     * Overlap-add synthesis that writes the finished samples as 16-bit WAV data while it goes,
     * so only a few MB of float samples are alive. Feed whole blocks of BLOCK frames in order:
     * [add] for every frame, then [finishBlock].
     */
    class StreamingSynth(private val os: OutputStream, private val n: Int) {
        val frames = frameCount(n)
        private val stft = Stft()
        private val buf = Array(2) { FloatArray((BLOCK + N / HOP - 1) * HOP) }
        private var base = -N // sample index of buf[.][0]
        private var written = 0
        private val bytes = ByteBuffer.allocate(8192 * 4).order(ByteOrder.LITTLE_ENDIAN)
        private val sq = DoubleArray(N) { window[it] * window[it] }

        init { writeWavHeader(os, n) }

        fun add(channel: Int, frame: Int, re: FloatArray, im: FloatArray, off: Int) =
            stft.synthesize(re, im, off, frame, buf[channel], base)

        /** Samples before base + BLOCK * HOP get no more contributions: normalise and write them. */
        fun finishBlock(last: Boolean) {
            val end = if (last) n else min(n, base + BLOCK * HOP)
            while (written < end) {
                bytes.clear()
                val stop = min(end, written + 8192)
                while (written < stop) {
                    val w = weight(written)
                    for (c in 0..1) {
                        val v = (buf[c][written - base] / max(w, 1e-8)).toFloat()
                        bytes.putShort((v.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
                    }
                    written++
                }
                os.write(bytes.array(), 0, bytes.position())
            }
            for (c in 0..1) {
                buf[c].copyInto(buf[c], 0, BLOCK * HOP)
                buf[c].fill(0f, buf[c].size - BLOCK * HOP)
            }
            base += BLOCK * HOP
        }

        /** Sum of squared windows over the frames covering sample [i]. */
        private fun weight(i: Int): Double {
            val p = i + N
            var w = 0.0
            for (j in 0 until N / HOP) {
                val f = p / HOP - j
                if (f in 0 until frames) w += sq[p - f * HOP]
            }
            return w
        }
    }
}
