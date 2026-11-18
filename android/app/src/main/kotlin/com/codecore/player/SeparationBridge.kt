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
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.Executors
import kotlin.math.sqrt
import java.util.concurrent.atomic.AtomicBoolean

/**
 * `codecore/separation`: `separate {input, output, voiceOutput, vocals, accompaniment}` writes the
 * accompaniment of [input] to `output` and the voice to `voiceOutput`, both WAV (Spleeter 2-stem
 * through ONNX Runtime; base + voice = original), `mix {base, voice, level, output}` writes
 * base + level * voice, `cancel` stops a separation, and `progress {fraction}` is pushed to Dart. It runs here, off the main thread, because the
 * ONNX Runtime Flutter plugin would run inference on the UI thread.
 */
object SeparationBridge {
    private class Failure(val code: String, message: String, cause: Throwable? = null) :
        Exception(message, cause)

    // Background priority is inherited by the ONNX Runtime threads, so playback never underruns.
    private val executor = Executors.newSingleThreadExecutor { r ->
        Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            r.run()
        }
    }
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
                    val voiceOutput = call.argument<String>("voiceOutput")
                    val vocals = call.argument<String>("vocals")
                    val accompaniment = call.argument<String>("accompaniment")
                    if (input == null || output == null || voiceOutput == null || vocals == null || accompaniment == null) {
                        result.error("io", "missing arguments", null)
                    } else if (!running.compareAndSet(false, true)) {
                        result.error("busy", "a separation is already running", null)
                    } else {
                        cancelled.set(false)
                        executor.execute { run(channel, input, output, voiceOutput, vocals, accompaniment, result) }
                    }
                }
                "mix" -> {
                    val base = call.argument<String>("base")
                    val voice = call.argument<String>("voice")
                    val level = call.argument<Double>("level")
                    val output = call.argument<String>("output")
                    if (base == null || voice == null || level == null || output == null) {
                        result.error("io", "missing arguments", null)
                    } else if (!running.compareAndSet(false, true)) {
                        result.error("busy", "a separation is already running", null)
                    } else {
                        executor.execute { runMix(base, voice, level.coerceIn(0.0, 1.0), output, result) }
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
        channel: MethodChannel, input: String, output: String, voiceOutput: String, vocals: String,
        accompaniment: String, result: MethodChannel.Result,
    ) {
        var failure: Failure? = null
        try {
            separate(channel, input, output, voiceOutput, vocals, accompaniment)
        } catch (e: Failure) {
            failure = e
        } catch (e: OrtException) {
            failure = Failure("model", e.message ?: "model error", e)
        } catch (e: IOException) {
            failure = Failure("io", e.message ?: "io error", e)
        } catch (e: OutOfMemoryError) {
            failure = Failure("io", "out of memory")
        } catch (e: LinkageError) {
            failure = Failure("model", e.message ?: "ONNX Runtime not loadable", e)
        } catch (e: Throwable) {
            failure = Failure("io", e.message ?: e.javaClass.simpleName, e)
        } finally {
            // Whatever happened, the worker thread must free the slot and answer Dart.
            if (failure != null) {
                if (failure.code != "cancelled") {
                    android.util.Log.w("Codecore", "separation failed: ${failure.code}", failure)
                }
                File(output).delete()
                File(voiceOutput).delete()
            }
            running.set(false)
            val f = failure
            main.post {
                if (f == null) result.success(null) else result.error(f.code, f.message, null)
            }
        }
    }

    private fun runMix(base: String, voice: String, level: Double, output: String, result: MethodChannel.Result) {
        var failure: Failure? = null
        try {
            File(base).inputStream().buffered(1 shl 16).use { b ->
                File(voice).inputStream().buffered(1 shl 16).use { v ->
                    File(output).outputStream().buffered(1 shl 16).use { SpleeterDsp.mixWav(b, v, level, it) }
                }
            }
        } catch (e: SpleeterDsp.WavFormatException) {
            failure = Failure("decode", e.message ?: "bad WAV", e)
        } catch (e: IOException) {
            failure = Failure("io", e.message ?: "io error", e)
        } catch (e: Throwable) {
            failure = Failure("io", e.message ?: e.javaClass.simpleName, e)
        } finally {
            if (failure != null) {
                android.util.Log.w("Codecore", "mix failed: ${failure.code}", failure)
                File(output).delete()
            }
            running.set(false)
            val f = failure
            main.post { if (f == null) result.success(null) else result.error(f.code, f.message, null) }
        }
    }

    private fun checkCancelled() {
        if (cancelled.get()) throw Failure("cancelled", "cancelled")
    }

    private fun separate(
        channel: MethodChannel, input: String, output: String, voiceOutput: String, vocalsPath: String, accPath: String,
    ) {
        // The decoded PCM is garbage as soon as it is resampled: nothing keeps it alive.
        val x = decode(input).let { SpleeterDsp.toStereo44k(it.pcm, it.size, it.channels, it.rate) }
        val n = x[0].size
        if (n == 0) throw Failure("decode", "empty audio")
        val frames = SpleeterDsp.frameCount(n)
        val splits = (frames + SpleeterDsp.BLOCK - 1) / SpleeterDsp.BLOCK

        val env = OrtEnvironment.getEnvironment()
        val options = OrtSession.SessionOptions()
        var vocSession: OrtSession? = null
        var accSession: OrtSession? = null
        try {
            options.setIntraOpNumThreads(4)
            vocSession = env.createSession(vocalsPath, options)
            accSession = env.createSession(accPath, options)
            BufferedOutputStream(File(output).outputStream()).use { os ->
              BufferedOutputStream(File(voiceOutput).outputStream()).use { vos ->
                val synth = SpleeterDsp.StreamingSynth(os, n)
                val voiceSynth = SpleeterDsp.StreamingSynth(vos, n)
                val vre = FloatArray(SpleeterDsp.BINS)
                val vim = FloatArray(SpleeterDsp.BINS)
                val stft = SpleeterDsp.Stft()
                val b = SpleeterDsp.BLOCK
                val m = SpleeterDsp.MODEL_BINS
                val bins = SpleeterDsp.BINS
                val re = FloatArray(2 * b * bins)
                val im = FloatArray(2 * b * bins)
                // Direct, so ONNX Runtime wraps it without a copy.
                val mag = java.nio.ByteBuffer.allocateDirect(2 * b * m * 4)
                    .order(ByteOrder.nativeOrder()).asFloatBuffer()
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
                            val r = re[off + k]
                            val i = im[off + k]
                            mag.put((c * b + t) * m + k, sqrt(r * r + i * i))
                        }
                    }
                    mag.rewind()
                    infer(env, vocSession!!, mag, shape, voc)
                    mag.rewind()
                    infer(env, accSession!!, mag, shape, acc)
                    for (c in 0..1) for (t in 0 until count) {
                        val off = (c * b + t) * bins
                        // The magnitudes and the model outputs share the layout (c * b + t) * m.
                        SpleeterDsp.maskFrame(voc, acc, (c * b + t) * m, mask)
                        SpleeterDsp.voiceFrame(re, im, off, mask, vre, vim)
                        voiceSynth.add(c, s * b + t, vre, vim, 0)
                        for (k in 0 until bins) {
                            re[off + k] *= mask[k]
                            im[off + k] *= mask[k]
                        }
                        synth.add(c, s * b + t, re, im, off)
                    }
                    synth.finishBlock(s == splits - 1)
                    voiceSynth.finishBlock(s == splits - 1)
                    val fraction = (s + 1).toDouble() / splits
                    main.post { channel.invokeMethod("progress", mapOf("fraction" to fraction)) }
                }
              }
            }
        } finally {
            vocSession?.close()
            accSession?.close()
            options.close()
        }
    }

    private fun infer(env: OrtEnvironment, session: OrtSession, data: FloatBuffer, shape: LongArray, into: FloatArray) {
        OnnxTensor.createTensor(env, data, shape).use { tensor ->
            session.run(mapOf("x" to tensor)).use { r ->
                (r[0] as OnnxTensor).floatBuffer.get(into)
            }
        }
    }

    private const val MAX_SECONDS = 20 * 60

    private class Decoded(val pcm: ShortArray, val size: Int, val channels: Int, val rate: Int)

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
            val rate0 = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 48000
            val ch0 = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2
            // The memory of a longer track (a podcast) would not fit: refuse it up front or while decoding.
            val maxSamples = MAX_SECONDS.toLong() * rate0 * ch0
            if (format.containsKey(MediaFormat.KEY_DURATION) && format.getLong(MediaFormat.KEY_DURATION) > MAX_SECONDS * 1_000_000L) {
                throw Failure("too_long", "longer than $MAX_SECONDS s")
            }
            val expected = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION) * rate0 * ch0 / 1_000_000L + (1 shl 16)
            } else (1 shl 20).toLong()
            var pcm = ShortArray(minOf(expected, maxSamples).toInt())
            var idle = 0
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
                    // ~5 s without a buffer after the end of the input: the decoder is stuck.
                    idle = if (o < 0 && o != MediaCodec.INFO_OUTPUT_FORMAT_CHANGED && inputDone) idle + 1 else 0
                    if (idle > 500) throw Failure("decode", "decoder stalled")
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        format = codec.outputFormat
                    } else if (o >= 0) {
                        val buf = codec.getOutputBuffer(o)!!.order(ByteOrder.nativeOrder())
                        buf.position(info.offset).limit(info.offset + info.size)
                        // Decoders emit 16-bit unless the output format says float.
                        val float = format.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            format.getInteger(MediaFormat.KEY_PCM_ENCODING) == android.media.AudioFormat.ENCODING_PCM_FLOAT
                        val count = info.size / if (float) 4 else 2
                        if (size + count > maxSamples) throw Failure("too_long", "longer than $MAX_SECONDS s")
                        if (size + count > pcm.size) pcm = pcm.copyOf(minOf(maxOf(pcm.size.toLong() * 3 / 2, (size + count).toLong()), maxSamples).toInt())
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
