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
    let mut file = File::open(path).with_context(|| format!("cannot open {path}"))?;
    let off = id3v2_len(&mut file)?;
    let mss = MediaSourceStream::new(Box::new(FromOffset { file, off }), Default::default());
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
    let known_secs = match (track.duration, track.time_base) {
        (Some(d), Some(tb)) => tb
            .calc_time(symphonia::core::units::Timestamp::new(d.get() as i64))
            .map(|t| t.as_secs_f64() as u32),
        _ => None,
    };

    let mut printer = Fingerprinter::new(&Configuration::preset_test2());
    let mut started = false;
    let (mut rate, mut fed, mut total) = (0u64, 0u64, 0u64);
    let mut buf: Vec<i16> = Vec::new();
    let mut reached_eof = true;

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
            // Stop exactly at MAX_SECS: feed only the frames still needed.
            let take = frames.min(MAX_SECS * rate - fed);
            printer.consume(&buf[..(take as usize * spec.channels().count())]);
            fed += take;
        }
        // The rest of the file need not be decoded.
        if fed >= MAX_SECS * rate {
            reached_eof = false;
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
    let secs = if reached_eof {
        (total / rate) as u32
    } else if let Some(n) = known_frames {
        (n / rate) as u32
    } else if let Some(s) = known_secs {
        s
    } else {
        // Decoding stopped early and the container gave no length: ask lofty.
        use lofty::file::AudioFile;
        lofty::read_from_path(path)
            .context("cannot read the duration")?
            .properties()
            .duration()
            .as_secs() as u32
    };
    Ok((raw, secs))
}

/// A file that starts `off` bytes in: symphonia's probe gives up on a huge ID3v2 tag
/// (big cover), so the tag is hidden from it.
struct FromOffset {
    file: File,
    off: u64,
}

impl std::io::Read for FromOffset {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.file.read(buf)
    }
}

impl std::io::Seek for FromOffset {
    fn seek(&mut self, pos: std::io::SeekFrom) -> std::io::Result<u64> {
        use std::io::SeekFrom::*;
        let abs = self.file.seek(match pos {
            Start(p) => Start(p + self.off),
            other => other,
        })?;
        Ok(abs.saturating_sub(self.off))
    }
}

impl symphonia::core::io::MediaSource for FromOffset {
    fn is_seekable(&self) -> bool {
        true
    }
    fn byte_len(&self) -> Option<u64> {
        self.file.metadata().ok().map(|m| m.len().saturating_sub(self.off))
    }
}

/// Bytes taken by a leading ID3v2 tag (0 when there is none).
fn id3v2_len(file: &mut File) -> Result<u64> {
    use std::io::{Read, Seek, SeekFrom};
    let mut h = [0u8; 10];
    let n = if file.read_exact(&mut h).is_ok() && &h[..3] == b"ID3" {
        let size = h[6..].iter().fold(0u64, |a, &b| a << 7 | u64::from(b & 0x7f));
        10 + size + if h[5] & 0x10 != 0 { 10 } else { 0 }
    } else {
        0
    };
    file.seek(SeekFrom::Start(n))?;
    Ok(n)
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
