use anyhow::Result;
use lofty::{file::TaggedFileExt, tag::ItemKey};

pub struct TrackIds {
    /// MusicBrainz recording id (MP3 UFID "http://musicbrainz.org", Vorbis, M4A).
    pub mbid: Option<String>,
    pub isrc: Option<String>,
}

/// MusicBrainz recording id and ISRC of an mp3, flac, ogg or m4a file.
pub fn read_ids(path: String) -> Result<TrackIds> {
    let file = lofty::read_from_path(&path)?;
    let text = |key: &ItemKey| {
        file.tags()
            .iter()
            .filter_map(|t| t.get_string(key))
            .map(|s| s.trim().to_string())
            .find(|s| !s.is_empty())
    };
    // lofty has no key for the TXXX "MusicBrainz Track Id" some taggers write.
    let txxx = ItemKey::Unknown("MusicBrainz Track Id".into());
    let mbid = text(&ItemKey::MusicBrainzRecordingId).or_else(|| text(&txxx));
    Ok(TrackIds { mbid, isrc: text(&ItemKey::Isrc) })
}
