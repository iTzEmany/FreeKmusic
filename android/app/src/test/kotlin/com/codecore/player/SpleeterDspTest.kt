package com.codecore.player

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
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
}
