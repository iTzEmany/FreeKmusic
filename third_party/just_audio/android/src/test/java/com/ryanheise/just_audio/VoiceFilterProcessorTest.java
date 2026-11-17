package com.ryanheise.just_audio;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.audio.AudioProcessor.AudioFormat;

import org.junit.Test;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public class VoiceFilterProcessorTest {
    private static final int RATE = 44100;

    private static VoiceFilterProcessor processor(int channels, int encoding) throws Exception {
        VoiceFilterProcessor p = new VoiceFilterProcessor();
        p.configure(new AudioFormat(RATE, channels, encoding));
        p.flush();
        return p;
    }

    /** Interleaved stereo 16-bit through the processor, in 1024-frame blocks like a real sink. */
    private static short[] run(VoiceFilterProcessor p, short[] in) {
        short[] out = new short[in.length];
        for (int i = 0; i < in.length; i += 2048) {
            int n = Math.min(2048, in.length - i);
            ByteBuffer b = ByteBuffer.allocateDirect(n * 2).order(ByteOrder.nativeOrder());
            for (int k = 0; k < n; k++) b.putShort(in[i + k]);
            b.flip();
            p.queueInput(b);
            p.getOutput().asReadOnlyBuffer().order(ByteOrder.nativeOrder()).asShortBuffer().get(out, i, n);
        }
        return out;
    }

    private static short[] stereo(int frames, double lAmp, double lHz, double rAmp, double rHz) {
        short[] s = new short[frames * 2];
        for (int i = 0; i < frames; i++) {
            s[2 * i] = (short) Math.round(lAmp * Math.sin(2 * Math.PI * lHz * i / RATE));
            s[2 * i + 1] = (short) Math.round(rAmp * Math.sin(2 * Math.PI * rHz * i / RATE));
        }
        return s;
    }

    /** RMS of one channel over the last half of the buffer (after the level ramp and the filter settle). */
    private static double rmsTail(short[] s, int channel) {
        double sum = 0;
        int from = s.length / 4;
        for (int i = from; i < s.length / 2; i++) sum += Math.pow(s[2 * i + channel], 2);
        return Math.sqrt(sum / (s.length / 2 - from));
    }

    @Test
    public void emptyInputIsIgnored() throws Exception {
        // The audio pipeline polls processors with the shared EMPTY_BUFFER.
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        p.queueInput(AudioProcessor.EMPTY_BUFFER);
        assertFalse(p.getOutput().hasRemaining());
    }

    @Test
    public void level1IsByteIdentical() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        short[] in = stereo(RATE, 12000, 440, 9000, 3000);
        assertArrayEquals(in, run(p, in));
        p.setLevel(1.0);
        assertArrayEquals(in, run(p, in));
        p.setLevel(null);
        assertArrayEquals(in, run(p, in));
    }

    @Test
    public void level0RemovesCentreHighsAndKeepsLowBand() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        p.setLevel(0.0);
        // Same content on L and R: 60 Hz bass plus a 2 kHz "voice".
        short[] in = new short[RATE * 2 * 2];
        for (int i = 0; i < RATE * 2; i++) {
            short v = (short) Math.round(8000 * Math.sin(2 * Math.PI * 60 * i / RATE)
                    + 8000 * Math.sin(2 * Math.PI * 2000 * i / RATE));
            in[2 * i] = v;
            in[2 * i + 1] = v;
        }
        short[] out = run(p, in);
        // L == R (no side), the 60 Hz band stays (rms of an 8000 sine = 5657), the 2 kHz is gone.
        for (int i = in.length / 2; i < in.length; i += 2) assertEquals(out[i], out[i + 1]);
        assertEquals(5657, rmsTail(out, 0), 5657 * 0.05);
    }

    @Test
    public void level0LeavesSideUntouched() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        p.setLevel(0.0);
        // L = -R: pure side content at 2 kHz.
        short[] in = stereo(RATE * 2, 8000, 2000, -8000, 2000);
        short[] out = run(p, in);
        assertEquals(rmsTail(in, 0), rmsTail(out, 0), 100);
        assertEquals(rmsTail(in, 1), rmsTail(out, 1), 100);
    }

    @Test
    public void nanLevelIsBypass() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        p.setLevel(Double.NaN);
        short[] in = stereo(RATE, 12000, 440, 9000, 3000);
        assertArrayEquals(in, run(p, in));
    }

    /** Largest distance between the first second after lowering to 0 and the ideal (continuous filter) output. */
    private static double maxErrorAfterLowering(boolean bypassFirst) throws Exception {
        short[] bass = stereo(RATE, 8000, 60, 8000, 60);
        // Reference: level 0 for 2 s, so its second second is the steady low band.
        VoiceFilterProcessor ref = processor(2, C.ENCODING_PCM_16BIT);
        ref.setLevel(0.0);
        run(ref, bass);
        short[] low = run(ref, bass);
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        if (bypassFirst) run(p, bass); // level 1: the filter state must keep following the signal
        else run(p, new short[bass.length]); // a state that knows nothing about the bass
        p.setLevel(0.0);
        short[] out = run(p, bass);
        double level = 1.0, worst = 0;
        for (int i = 0; i < 1000; i++) {
            level = level < 1e-4 ? 0.0 : level - level * 0.002; // the processor's ramp towards 0
            double expected = low[2 * i] + level * (bass[2 * i] - low[2 * i]);
            worst = Math.max(worst, Math.abs(out[2 * i] - expected));
        }
        return worst;
    }

    @Test
    public void loweringTheLevelAfterBypassStartsWithoutABlip() throws Exception {
        assertTrue(maxErrorAfterLowering(true) < 4);
        assertTrue("the check can tell a stale state", maxErrorAfterLowering(false) > 40);
    }

    @Test
    public void halfLevelHalvesTheCentre() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_16BIT);
        p.setLevel(0.5);
        short[] in = stereo(RATE * 2, 8000, 2000, 8000, 2000);
        assertEquals(rmsTail(in, 0) / 2, rmsTail(run(p, in), 0), 150);
    }

    @Test
    public void monoAndOtherFormatsAreInactive() throws Exception {
        assertFalse(processor(1, C.ENCODING_PCM_16BIT).isActive());
        assertFalse(processor(2, C.ENCODING_PCM_24BIT).isActive());
        assertTrue(processor(2, C.ENCODING_PCM_16BIT).isActive());
        assertTrue(processor(2, C.ENCODING_PCM_FLOAT).isActive());
    }

    @Test
    public void floatPathMatchesTheShortPath() throws Exception {
        VoiceFilterProcessor p = processor(2, C.ENCODING_PCM_FLOAT);
        p.setLevel(0.0);
        int frames = RATE * 2;
        ByteBuffer b = ByteBuffer.allocateDirect(frames * 8).order(ByteOrder.nativeOrder());
        for (int i = 0; i < frames; i++) {
            float v = (float) (0.25 * Math.sin(2 * Math.PI * 2000 * i / RATE));
            b.putFloat(v).putFloat(v);
        }
        b.flip();
        p.queueInput(b);
        ByteBuffer o = p.getOutput().order(ByteOrder.nativeOrder());
        o.position(o.limit() - 8 * 1000);
        for (int i = 0; i < 1000; i++) {
            assertEquals(0.0, o.getFloat(), 0.01);
            o.getFloat();
        }
    }
}
