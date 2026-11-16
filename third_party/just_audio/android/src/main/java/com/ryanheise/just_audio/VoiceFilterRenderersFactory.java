package com.ryanheise.just_audio;

import android.content.Context;

import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.exoplayer.DefaultRenderersFactory;
import androidx.media3.exoplayer.audio.AudioSink;
import androidx.media3.exoplayer.audio.DefaultAudioSink;

/** DefaultRenderersFactory whose audio sink also runs the karaoke {@link VoiceFilterProcessor}. */
final class VoiceFilterRenderersFactory extends DefaultRenderersFactory {
    private final VoiceFilterProcessor voiceFilter;

    VoiceFilterRenderersFactory(Context context, VoiceFilterProcessor voiceFilter) {
        super(context);
        this.voiceFilter = voiceFilter;
    }

    @Override
    protected AudioSink buildAudioSink(Context context, boolean enableFloatOutput,
            boolean enableAudioTrackPlaybackParams) {
        return new DefaultAudioSink.Builder(context)
                .setEnableFloatOutput(enableFloatOutput)
                .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
                .setAudioProcessors(new AudioProcessor[] {voiceFilter})
                .build();
    }
}
