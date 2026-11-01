use anyhow::{bail, Context, Result};
use rusty_chromaprint::{Configuration, FingerprintCompressor, Fingerprinter};
use std::fs::File;
use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::errors::Error as SymError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;

/// Only the first seconds are fingerprinted, like `fpcalc` (default `-length 120`).
const MAX_SECS: u64 = 120;

pub struct Fingerprint {
    /// Chromaprint, compressed and base64url without padding (same text as `fpcalc`).
    pub fingerprint: String,
    /// Duration of the whole file, in seconds.
    pub duration_s: u32,
}

/// Chromaprint of an audio file (mp3, aac/m4a, flac, ogg vorbis, wav).
/// Opus/WebM and unreadable files return an error, as does an empty fingerprint.
pub fn fingerprint(path: String) -> Result<Fingerprint> {
    let (raw, duration_s) = fingerprint_raw(&path)?;
    let config = Configuration::preset_test2();
    let bytes = FingerprintCompressor::from(&config).compress(&raw);
    Ok(Fingerprint { fingerprint: base64_url(&bytes), duration_s })
}

/// Uncompressed 32-bit values and the file duration; used by the tests.
#[flutter_rust_bridge::frb(ignore)]
pub fn fingerprint_raw(path: &str) -> Result<(Vec<u32>, u32)> {
    let file = File::open(path).with_context(|| format!("cannot open {path}"))?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = std::path::Path::new(path).extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }
    let mut format = symphonia::default::get_probe()
        .probe(&hint, mss, FormatOptions::default(), MetadataOptions::default())
        .context("unsupported or unreadable audio format")?;
    let track = format.default_track(TrackType::Audio).context("no audio track")?;
    let params = track
        .codec_params
        .as_ref()
        .and_then(|p| p.audio())
        .context("no audio parameters")?;
    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(params, &AudioDecoderOptions::default())
        .context("unsupported audio codec (Opus/WebM are not supported)")?;
    let track_id = track.id;
    let known_frames = track.num_frames;

    let mut printer = Fingerprinter::new(&Configuration::preset_test2());
    let mut started = false;
    let (mut rate, mut fed, mut total) = (0u64, 0u64, 0u64);
    let mut buf: Vec<i16> = Vec::new();

    loop {
        let packet = match format.next_packet() {
            Ok(Some(p)) => p,
            Ok(None) => break,
            Err(SymError::IoError(e)) if e.kind() == std::io::ErrorKind::UnexpectedEof => break,
            Err(e) => bail!("read error: {e}"),
        };
        if packet.track_id != track_id {
            continue;
        }
        let audio = match decoder.decode(&packet) {
            Ok(a) => a,
            Err(SymError::DecodeError(_)) => continue, // corrupt frame: skip it
            Err(e) => bail!("decode error: {e}"),
        };
        let spec = audio.spec();
        rate = u64::from(spec.rate());
        let frames = audio.frames() as u64;
        total += frames;
        if fed < MAX_SECS * rate {
            if !started {
                printer
                    .start(spec.rate(), spec.channels().count() as u32)
                    .map_err(|e| anyhow::anyhow!("fingerprinter start: {e:?}"))?;
                started = true;
            }
            buf.resize(audio.samples_interleaved(), 0);
            audio.copy_to_slice_interleaved(&mut buf);
            printer.consume(&buf);
            fed += frames;
        }
        // With a known length the rest of the file need not be decoded.
        if known_frames.is_some() && fed >= MAX_SECS * rate {
            break;
        }
    }
    if !started || rate == 0 {
        bail!("no decodable audio");
    }
    printer.finish();
    let raw = printer.fingerprint().to_vec();
    if raw.is_empty() {
        bail!("empty fingerprint (audio too short or silent)");
    }
    let total = known_frames.unwrap_or(total);
    Ok((raw, (total / rate) as u32))
}

fn base64_url(data: &[u8]) -> String {
    const A: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut out = String::with_capacity(data.len() * 4 / 3 + 4);
    for c in data.chunks(3) {
        let n = (u32::from(c[0]) << 16)
            | (u32::from(*c.get(1).unwrap_or(&0)) << 8)
            | u32::from(*c.get(2).unwrap_or(&0));
        for i in 0..=c.len() {
            out.push(A[(n >> (18 - 6 * i) & 63) as usize] as char);
        }
    }
    out
}
