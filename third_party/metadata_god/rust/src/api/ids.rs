use anyhow::Result;
use lofty::{config::{ParseOptions, ParsingMode}, file::TaggedFileExt, probe::Probe, tag::ItemKey};

pub struct TrackIds {
    /// MusicBrainz recording id (MP3 UFID "http://musicbrainz.org", Vorbis, M4A).
    pub mbid: Option<String>,
    pub isrc: Option<String>,
}

/// MusicBrainz recording id and ISRC of an mp3, flac, ogg or m4a file.
pub fn read_ids(path: String) -> Result<TrackIds> {
    let file = Probe::open(&path)?
        .options(ParseOptions::new().parsing_mode(ParsingMode::Relaxed).read_cover_art(false).read_properties(false))
        .read()?;
    let text = |key: &ItemKey| {
        file.tags()
            .iter()
            .filter_map(|t| t.get_string(key))
            .map(|s| s.trim().to_string())
            .find(|s| !s.is_empty())
    };
    let mbid = text(&ItemKey::MusicBrainzRecordingId).or_else(|| {
        // lofty has no key for the TXXX frame some taggers write.
        ["MusicBrainz Track Id", "MUSICBRAINZ_TRACKID"]
            .iter()
            .find_map(|d| text(&ItemKey::Unknown(d.to_string())))
    });
    Ok(TrackIds { mbid: mbid.and_then(|m| uuid(&m)), isrc: text(&ItemKey::Isrc) })
}

/// Lowercased `m` when it is a UUID (8-4-4-4-12 hex), else None.
fn uuid(m: &str) -> Option<String> {
    let ok = m.split('-').map(str::len).eq([8, 4, 4, 4, 12]) && m.chars().all(|c| c == '-' || c.is_ascii_hexdigit());
    ok.then(|| m.to_lowercase())
}
