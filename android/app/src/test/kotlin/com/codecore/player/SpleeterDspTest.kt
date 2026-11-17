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
        FloatArray(n) { (0.5 * sin(2 * PI * hz * it / rate)).toFloat() }

    @Test
    fun unitMaskReconstructsTheSignal() {
        val x = tone(10000, 440.0)
        val out = FloatArray(x.size)
        val stft = SpleeterDsp.Stft()
        val re = FloatArray(SpleeterDsp.BINS)
        val im = FloatArray(SpleeterDsp.BINS)
        for (f in 0 until SpleeterDsp.frameCount(x.size)) {
            stft.analyze(x, f, re, im, 0)
            stft.synthesize(re, im, 0, f, out)
        }
        SpleeterDsp.normalize(out)
        var worst = 0f
        for (i in x.indices) worst = maxOf(worst, abs(out[i] - x[i]))
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
        val pcm = ShortArray(rate) { (16000 * sin(2 * PI * 1000.0 * it / rate)).toInt().toShort() }
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
        SpleeterDsp.writeWav(bos, floatArrayOf(0f, 2f, -2f), floatArrayOf(0.5f, 0f, 0f))
        val b = ByteBuffer.wrap(bos.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(44 + 12, b.capacity())
        assertEquals(0x46464952, b.getInt(0)) // "RIFF"
        assertEquals(36 + 12, b.getInt(4))
        assertEquals(2, b.getShort(22).toInt())
        assertEquals(44100, b.getInt(24))
        assertEquals(16, b.getShort(34).toInt())
        assertEquals(12, b.getInt(40))
        assertEquals(32767, b.getShort(48).toInt()) // second frame left, clamped
        assertEquals(-32767, b.getShort(52).toInt())
    }
}
