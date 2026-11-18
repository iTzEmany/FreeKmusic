package com.codecore.player

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SpleeterDspTest {
    private fun tone(n: Int, hz: Double, rate: Int = 44100) =
        ShortArray(n) { (16000 * sin(2 * PI * hz * it / rate)).toInt().toShort() }

    /** Unit-mask round trip through the streaming synthesis; returns the decoded 16-bit channels. */
    private fun roundTrip(x: ShortArray): Array<ShortArray> {
        val bos = ByteArrayOutputStream()
        val synth = SpleeterDsp.StreamingSynth(bos, x.size)
        val stft = SpleeterDsp.Stft()
        val re = FloatArray(SpleeterDsp.BINS)
        val im = FloatArray(SpleeterDsp.BINS)
        val splits = (synth.frames + SpleeterDsp.BLOCK - 1) / SpleeterDsp.BLOCK
        for (s in 0 until splits) {
            for (f in s * SpleeterDsp.BLOCK until minOf(synth.frames, (s + 1) * SpleeterDsp.BLOCK)) {
                stft.analyze(x, f, re, im, 0)
                for (c in 0..1) synth.add(c, f, re, im, 0)
            }
            synth.finishBlock(s == splits - 1)
        }
        val b = ByteBuffer.wrap(bos.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(44 + x.size * 4, b.capacity())
        return Array(2) { c -> ShortArray(x.size) { b.getShort(44 + it * 4 + c * 2) } }
    }

    @Test
    fun unitMaskReconstructsTheSignal() {
        val x = tone(10000, 440.0)
        val y = roundTrip(x)
        var worst = 0f
        for (c in 0..1) for (i in x.indices) worst = maxOf(worst, abs(y[c][i] - x[i]) / 32768f)
        assertTrue("error $worst", worst < 1e-4f)
    }

    @Test
    fun streamingAcrossBlockBoundariesReconstructsTheSignal() {
        // Three blocks of 512 frames; the 16-bit output scale is 32767 against 32768 in.
        val x = tone(1_300_000, 440.0)
        val y = roundTrip(x)
        var worst = 0f
        for (c in 0..1) for (i in x.indices) worst = maxOf(worst, abs(y[c][i] - x[i]) / 32768f)
        assertTrue("error $worst", worst < 1e-4f)
    }

    @Test
    fun maskIsExtendedAboveTheModelBins() {
        val voc = FloatArray(SpleeterDsp.MODEL_BINS) { if (it < 1000) 1f else 0f }
        val acc = FloatArray(SpleeterDsp.MODEL_BINS) { if (it < 1000) 0f else 1f }
        val mask = FloatArray(SpleeterDsp.BINS)
        SpleeterDsp.maskFrame(voc, acc, 0, mask)
        assertEquals(0f, mask[10], 1e-6f)
        assertEquals(1f, mask[1010], 1e-6f)
        // Bins 960..999 are 0 and 1000..1023 are 1: mean of the last 64.
        val expected = 24f / 64f
        assertEquals(expected, mask[1024], 1e-6f)
        assertEquals(expected, mask[2048], 1e-6f)
    }

    @Test
    fun resamplingKeepsTheFrequency() {
        val rate = 48000
        val pcm = tone(rate, 1000.0, rate)
        val out = SpleeterDsp.toStereo44k(pcm, pcm.size, 1, rate)
        assertEquals(44100, out[0].size)
        assertTrue(out[0].contentEquals(out[1]))
        var crossings = 0
        for (i in 1 until out[0].size) if (out[0][i - 1] < 0 && out[0][i] >= 0) crossings++
        assertTrue("crossings $crossings", abs(crossings - 1000) <= 1)
    }

    @Test
    fun wavHeaderIsCorrect() {
        val bos = ByteArrayOutputStream()
        SpleeterDsp.writeWavHeader(bos, 3)
        val b = ByteBuffer.wrap(bos.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(44, b.capacity())
        assertEquals(0x46464952, b.getInt(0)) // "RIFF"
        assertEquals(36 + 12, b.getInt(4))
        assertEquals(2, b.getShort(22).toInt())
        assertEquals(44100, b.getInt(24))
        assertEquals(16, b.getShort(34).toInt())
        assertEquals(12, b.getInt(40))
    }

    private fun wav(s: ShortArray): ByteArray {
        val bos = ByteArrayOutputStream()
        SpleeterDsp.writeWavHeader(bos, s.size / 2)
        val b = ByteBuffer.allocate(s.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        s.forEach { b.putShort(it) }
        bos.write(b.array())
        return bos.toByteArray()
    }

    private fun mix(base: ShortArray, voice: ShortArray, level: Double): ShortArray {
        val out = ByteArrayOutputStream()
        SpleeterDsp.mixWav(ByteArrayInputStream(wav(base)), ByteArrayInputStream(wav(voice)), level, out)
        val b = ByteBuffer.wrap(out.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        return ShortArray(base.size) { b.getShort(44 + it * 2) }
    }

    @Test
    fun basePlusVoiceReconstructsTheOriginal() {
        val x = tone(20000, 440.0)
        val bBos = ByteArrayOutputStream()
        val vBos = ByteArrayOutputStream()
        val bs = SpleeterDsp.StreamingSynth(bBos, x.size)
        val vs = SpleeterDsp.StreamingSynth(vBos, x.size)
        val stft = SpleeterDsp.Stft()
        val re = FloatArray(SpleeterDsp.BINS)
        val im = FloatArray(SpleeterDsp.BINS)
        val vre = FloatArray(SpleeterDsp.BINS)
        val vim = FloatArray(SpleeterDsp.BINS)
        // Non-trivial mask, including the extended bins above the model's.
        val mask = FloatArray(SpleeterDsp.BINS) { 0.2f + 0.6f * (it % 7) / 6f }
        val splits = (bs.frames + SpleeterDsp.BLOCK - 1) / SpleeterDsp.BLOCK
        for (s in 0 until splits) {
            for (f in s * SpleeterDsp.BLOCK until minOf(bs.frames, (s + 1) * SpleeterDsp.BLOCK)) {
                stft.analyze(x, f, re, im, 0)
                SpleeterDsp.voiceFrame(re, im, 0, mask, vre, vim)
                for (k in 0 until SpleeterDsp.BINS) { re[k] *= mask[k]; im[k] *= mask[k] }
                for (c in 0..1) { bs.add(c, f, re, im, 0); vs.add(c, f, vre, vim, 0) }
            }
            bs.finishBlock(s == splits - 1)
            vs.finishBlock(s == splits - 1)
        }
        val b = ByteBuffer.wrap(bBos.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        val v = ByteBuffer.wrap(vBos.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        var worst = 0f
        for (i in x.indices) for (c in 0..1) {
            val sum = b.getShort(44 + i * 4 + c * 2) + v.getShort(44 + i * 4 + c * 2)
            worst = maxOf(worst, abs(sum - x[i]) / 32768f)
        }
        assertTrue("error $worst", worst < 1e-3f)
    }

    @Test
    fun mixAtLevelsGivesBasePlusScaledVoice() {
        val base = shortArrayOf(100, -200, 30000, -30000)
        val voice = shortArrayOf(10, 20, 4000, -4000)
        assertTrue(mix(base, voice, 0.0).contentEquals(base))
        assertTrue(mix(base, voice, 0.5).contentEquals(shortArrayOf(105, -190, 32000, -32000)))
        // 1.0 sums and clamps to 16 bit.
        assertTrue(mix(base, voice, 1.0).contentEquals(shortArrayOf(110, -180, 32767, -32768)))
    }

    @Test
    fun mixOfDifferentLengthsFails() {
        try {
            mix(shortArrayOf(1, 2, 3, 4), shortArrayOf(1, 2), 0.5)
            fail("expected a failure")
        } catch (e: SpleeterDsp.WavFormatException) {
            assertTrue(e is IOException)
        }
    }
}
