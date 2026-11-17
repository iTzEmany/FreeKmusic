package com.ryanheise.just_audio;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor.AudioFormat;
import androidx.media3.common.audio.BaseAudioProcessor;

import java.nio.ByteBuffer;

/**
 * Karaoke voice filter (FreeKmusic, D-603). On stereo 16-bit or float PCM it splits each frame
 * into mid m = (L+R)/2 and side s = (L-R)/2, low-passes the mid (2nd-order Butterworth, ~150 Hz:
 * bass and kick live in the centre) and outputs
 *   mid' = low + level * (m - low),  L' = mid' + s,  R' = mid' - s.
 * level 1.0 copies the input unchanged; level 0 leaves only the side and the mid below 150 Hz.
 * Other formats (mono, other encodings) are not touched (processor inactive).
 */
public final class VoiceFilterProcessor extends BaseAudioProcessor {
    private static final double CUTOFF_HZ = 150.0;
    // Per-frame smoothing of the level (about 10 ms at 44.1 kHz) so a change does not click.
    private static final double SMOOTHING = 0.002;

    /** Set from the platform thread, read by the audio thread. */
    private volatile double target = 1.0;

    // Audio-thread state.
    private double level = 1.0;
    private double b0, b1, a1, a2, z1, z2;
    private double outL, outR;

    /** Level 0..1 of the voice; null or 1 means untouched. */
    public void setLevel(Double newLevel) {
        target = newLevel == null || newLevel.isNaN() ? 1.0 : Math.max(0.0, Math.min(1.0, newLevel));
    }

    @Override
    protected AudioFormat onConfigure(AudioFormat in) {
        if (in.channelCount != 2
                || (in.encoding != C.ENCODING_PCM_16BIT && in.encoding != C.ENCODING_PCM_FLOAT)) {
            return AudioFormat.NOT_SET;
        }
        double w = 2.0 * Math.PI * CUTOFF_HZ / in.sampleRate;
        double alpha = Math.sin(w) / (2.0 * Math.sqrt(0.5));
        double a0 = 1.0 + alpha;
        b1 = (1.0 - Math.cos(w)) / a0;
        b0 = b1 / 2.0;
        a1 = -2.0 * Math.cos(w) / a0;
        a2 = (1.0 - alpha) / a0;
        return in;
    }

    @Override
    protected void onFlush() {
        z1 = 0;
        z2 = 0;
        level = target;
    }

    @Override
    public void queueInput(ByteBuffer input) {
        // The pipeline also calls with the shared EMPTY_BUFFER, which replaceOutputBuffer(0) hands back.
        if (!input.hasRemaining()) return;
        int size = input.remaining();
        ByteBuffer out = replaceOutputBuffer(size);
        boolean isFloat = inputAudioFormat.encoding == C.ENCODING_PCM_FLOAT;
        if (level == 1.0 && target == 1.0) {
            // Bytes unchanged, but the low-pass keeps following the mid, so a later level change starts clean.
            for (int i = input.position(); i < input.limit(); i += isFloat ? 8 : 4) {
                lowPass(isFloat ? (input.getFloat(i) + input.getFloat(i + 4)) * 0.5
                        : (input.getShort(i) + input.getShort(i + 2)) * 0.5);
            }
            out.put(input);
            out.flip();
            return;
        }
        while (input.hasRemaining()) {
            if (isFloat) {
                process(input.getFloat(), input.getFloat());
                out.putFloat((float) outL).putFloat((float) outR);
            } else {
                process(input.getShort(), input.getShort());
                out.putShort(clip(outL)).putShort(clip(outR));
            }
        }
        out.flip();
    }

    private void process(double l, double r) {
        double t = target;
        level = Math.abs(t - level) < 1e-4 ? t : level + (t - level) * SMOOTHING;
        double m = (l + r) * 0.5;
        double s = (l - r) * 0.5;
        double low = lowPass(m);
        double mid = low + level * (m - low);
        outL = mid + s;
        outR = mid - s;
    }

    private double lowPass(double m) {
        double low = b0 * m + z1;
        z1 = b1 * m - a1 * low + z2;
        z2 = b0 * m - a2 * low;
        return low;
    }

    private static short clip(double v) {
        return (short) Math.max(Short.MIN_VALUE, Math.min(Short.MAX_VALUE, Math.round(v)));
    }
}
