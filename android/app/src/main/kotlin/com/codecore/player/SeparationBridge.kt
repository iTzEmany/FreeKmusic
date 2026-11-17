package com.codecore.player

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtException
import ai.onnxruntime.OrtSession
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * `codecore/separation`: `separate {input, output, vocals, accompaniment}` writes the
 * accompaniment of [input] as a WAV (Spleeter 2-stem through ONNX Runtime), `cancel` stops it,
 * and `progress {fraction}` is pushed to Dart. It runs here, off the main thread, because the
 * ONNX Runtime Flutter plugin would run inference on the UI thread.
 */
object SeparationBridge {
    private class Failure(val code: String, message: String, cause: Throwable? = null) :
        Exception(message, cause)

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, "codecore/separation")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "separate" -> {
                    val input = call.argument<String>("input")
                    val output = call.argument<String>("output")
                    val vocals = call.argument<String>("vocals")
                    val accompaniment = call.argument<String>("accompaniment")
                    if (input == null || output == null || vocals == null || accompaniment == null) {
                        result.error("io", "missing arguments", null)
                    } else if (!running.compareAndSet(false, true)) {
                        result.error("busy", "a separation is already running", null)
                    } else {
                        cancelled.set(false)
                        executor.execute { run(channel, input, output, vocals, accompaniment, result) }
                    }
                }
                "cancel" -> {
                    cancelled.set(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun run(
        channel: MethodChannel, input: String, output: String, vocals: String,
        accompaniment: String, result: MethodChannel.Result,
    ) {
        var failure: Failure? = null
        try {
            separate(channel, input, output, vocals, accompaniment)
        } catch (e: Failure) {
            failure = e
        } catch (e: OrtException) {
            failure = Failure("model", e.message ?: "model error", e)
        } catch (e: IOException) {
            failure = Failure("io", e.message ?: "io error", e)
        } catch (e: OutOfMemoryError) {
            failure = Failure("io", "out of memory")
        }
        if (failure != null) {
            if (failure.code != "cancelled") {
                android.util.Log.w("Codecore", "separation failed: ${failure.code}", failure)
            }
            File(output).delete()
        }
        running.set(false)
        main.post {
            if (failure == null) result.success(null)
            else result.error(failure.code, failure.message, null)
        }
    }

    private fun checkCancelled() {
        if (cancelled.get()) throw Failure("cancelled", "cancelled")
    }

    private fun separate(
        channel: MethodChannel, input: String, output: String, vocalsPath: String, accPath: String,
    ) {
        val (pcm, size, channels, rate) = decode(input)
        val x = SpleeterDsp.toStereo44k(pcm, size, channels, rate)
        val n = x[0].size
        if (n == 0) throw Failure("decode", "empty audio")
        val frames = SpleeterDsp.frameCount(n)
        val splits = (frames + SpleeterDsp.BLOCK - 1) / SpleeterDsp.BLOCK

        val env = OrtEnvironment.getEnvironment()
        val options = OrtSession.SessionOptions().apply { setIntraOpNumThreads(4) }
        val vocSession: OrtSession
        val accSession: OrtSession
        try {
            vocSession = env.createSession(vocalsPath, options)
            accSession = try {
                env.createSession(accPath, options)
            } catch (e: Exception) {
                vocSession.close()
                throw e
            }
        } catch (e: OrtException) {
            options.close()
            throw Failure("model", e.message ?: "cannot load the models", e)
        }
        val out = Array(2) { FloatArray(n) }
        try {
            val stft = SpleeterDsp.Stft()
            val b = SpleeterDsp.BLOCK
            val m = SpleeterDsp.MODEL_BINS
            val bins = SpleeterDsp.BINS
            val re = FloatArray(2 * b * bins)
            val im = FloatArray(2 * b * bins)
            // Direct, so ONNX Runtime wraps it without a copy.
            val mag = java.nio.ByteBuffer.allocateDirect(2 * b * m * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()
            val zeros = FloatArray(2 * b * m)
            val voc = FloatArray(2 * b * m)
            val acc = FloatArray(2 * b * m)
            val mask = FloatArray(bins)
            val shape = longArrayOf(2, 1, b.toLong(), m.toLong())
            for (s in 0 until splits) {
                checkCancelled()
                val count = minOf(b, frames - s * b)
                mag.clear()
                mag.put(zeros) // the last block is zero-padded
                for (c in 0..1) for (t in 0 until count) {
                    val off = (c * b + t) * bins
                    stft.analyze(x[c], s * b + t, re, im, off)
                    for (k in 0 until m) {
                        mag.put((c * b + t) * m + k, Math.hypot(re[off + k].toDouble(), im[off + k].toDouble()).toFloat())
                    }
                }
                mag.rewind()
                infer(env, vocSession, mag, shape, voc)
                mag.rewind()
                infer(env, accSession, mag, shape, acc)
                for (c in 0..1) for (t in 0 until count) {
                    val off = (c * b + t) * bins
                    SpleeterDsp.maskFrame(voc, acc, (c * b + t) * m, mask)
                    // maskFrame reads voc and acc at the same offset: the magnitudes layout.
                    for (k in 0 until bins) {
                        re[off + k] *= mask[k]
                        im[off + k] *= mask[k]
                    }
                    stft.synthesize(re, im, off, s * b + t, out[c])
                }
                val fraction = (s + 1).toDouble() / splits
                main.post { channel.invokeMethod("progress", mapOf("fraction" to fraction)) }
            }
        } finally {
            vocSession.close()
            accSession.close()
            options.close()
        }
        checkCancelled()
        out.forEach { SpleeterDsp.normalize(it) }
        BufferedOutputStream(File(output).outputStream()).use { SpleeterDsp.writeWav(it, out[0], out[1]) }
    }

    private fun infer(env: OrtEnvironment, session: OrtSession, data: FloatBuffer, shape: LongArray, into: FloatArray) {
        OnnxTensor.createTensor(env, data, shape).use { tensor ->
            session.run(mapOf("x" to tensor)).use { r ->
                (r[0] as OnnxTensor).floatBuffer.get(into)
            }
        }
    }

    private data class Decoded(val pcm: ShortArray, val size: Int, val channels: Int, val rate: Int)

    /** Any audio file to interleaved 16-bit PCM in memory. */
    private fun decode(path: String): Decoded {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            try {
                extractor.setDataSource(path)
            } catch (e: IOException) {
                throw Failure("decode", "cannot open the audio", e)
            }
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: throw Failure("decode", "no audio track")
            extractor.selectTrack(track)
            var format = extractor.getTrackFormat(track)
            var pcm = ShortArray(1 shl 20)
            var size = 0
            try {
                codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
                codec.configure(format, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                while (!outputDone) {
                    checkCancelled()
                    if (!inputDone) {
                        val i = codec.dequeueInputBuffer(10_000)
                        if (i >= 0) {
                            val buf = codec.getInputBuffer(i)!!
                            val read = extractor.readSampleData(buf, 0)
                            if (read < 0) {
                                codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(i, 0, read, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    val o = codec.dequeueOutputBuffer(info, 10_000)
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        format = codec.outputFormat
                    } else if (o >= 0) {
                        val buf = codec.getOutputBuffer(o)!!.order(ByteOrder.nativeOrder())
                        buf.position(info.offset).limit(info.offset + info.size)
                        // Decoders emit 16-bit unless the output format says float.
                        val float = format.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            format.getInteger(MediaFormat.KEY_PCM_ENCODING) == android.media.AudioFormat.ENCODING_PCM_FLOAT
                        val count = info.size / if (float) 4 else 2
                        if (size + count > pcm.size) pcm = pcm.copyOf(maxOf(pcm.size * 2, size + count))
                        if (float) {
                            val f = buf.asFloatBuffer()
                            for (j in 0 until count) pcm[size + j] = (f.get() * 32767f).coerceIn(-32768f, 32767f).toInt().toShort()
                        } else {
                            buf.asShortBuffer().get(pcm, size, count)
                        }
                        size += count
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            } catch (e: IllegalStateException) {
                throw Failure("decode", "decoder failed", e)
            } catch (e: IllegalArgumentException) {
                throw Failure("decode", "unsupported audio", e)
            } catch (e: IOException) {
                throw Failure("decode", "decoder failed", e)
            }
            val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            if (channels < 1 || rate < 1 || size < channels) throw Failure("decode", "empty audio")
            return Decoded(pcm, size, channels, rate)
        } finally {
            try { codec?.stop() } catch (e: IllegalStateException) {
                android.util.Log.w("Codecore", "decoder stop failed", e)
            }
            codec?.release()
            extractor.release()
        }
    }
}
