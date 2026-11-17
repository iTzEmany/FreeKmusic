package com.codecore.player

import java.io.OutputStream
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

        /** Spectrum of [frame] of [x] (unpadded) into [outRe]/[outIm] at [off], BINS values each. */
        fun analyze(x: FloatArray, frame: Int, outRe: FloatArray, outIm: FloatArray, off: Int) {
            for (k in 0 until N) {
                val i = frame * HOP + k - N
                re[k] = if (i in x.indices) x[i] * window[k] else 0.0
                im[k] = 0.0
            }
            fft.forward(re, im)
            for (b in 0 until BINS) {
                outRe[off + b] = re[b].toFloat()
                outIm[off + b] = im[b].toFloat()
            }
        }

        /** Adds the windowed inverse of the BINS-bin spectrum at [off] into [out] (unpadded). */
        fun synthesize(inRe: FloatArray, inIm: FloatArray, off: Int, frame: Int, out: FloatArray) {
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
                val i = frame * HOP + k - N
                if (i in out.indices) out[i] += (re[k] / N * window[k]).toFloat()
            }
        }
    }

    /** Divides the overlap-added [out] by the sum of squared windows, like the reference. */
    fun normalize(out: FloatArray) {
        val frames = frameCount(out.size)
        val sq = DoubleArray(N) { window[it] * window[it] }
        for (i in out.indices) {
            val p = i + N
            var w = 0.0
            for (j in 0 until N / HOP) {
                val f = p / HOP - j
                if (f in 0 until frames) w += sq[p - f * HOP]
            }
            out[i] = (out[i] / max(w, 1e-8)).toFloat()
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

    /** Interleaved 16-bit PCM to two 44.1 kHz float channels (mono duplicated, linear resampling). */
    fun toStereo44k(pcm: ShortArray, size: Int, channels: Int, rate: Int): Array<FloatArray> {
        val frames = size / channels
        val outLen = (frames.toLong() * RATE / rate).toInt()
        val r = if (channels > 1) 1 else 0
        val out = Array(2) { FloatArray(outLen) }
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
                out[c][i] = (a + (b - a) * t) / 32768f
            }
        }
        return out
    }

    /** 16-bit stereo 44.1 kHz WAV, samples clamped to +-1. */
    fun writeWav(os: OutputStream, left: FloatArray, right: FloatArray) {
        val data = left.size * 4
        val h = java.nio.ByteBuffer.allocate(44).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()).putInt(36 + data).put("WAVEfmt ".toByteArray())
            .putInt(16).putShort(1).putShort(2).putInt(RATE).putInt(RATE * 4).putShort(4).putShort(16)
            .put("data".toByteArray()).putInt(data)
        os.write(h.array())
        val buf = java.nio.ByteBuffer.allocate(8192 * 4).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        var i = 0
        while (i < left.size) {
            buf.clear()
            val end = min(left.size, i + 8192)
            while (i < end) {
                buf.putShort((left[i].coerceIn(-1f, 1f) * 32767f).toInt().toShort())
                buf.putShort((right[i].coerceIn(-1f, 1f) * 32767f).toInt().toShort())
                i++
            }
            os.write(buf.array(), 0, buf.position())
        }
    }
}
