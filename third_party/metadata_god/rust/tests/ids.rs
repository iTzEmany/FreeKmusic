use lofty::config::WriteOptions;
use lofty::prelude::*;
use lofty::tag::{ItemKey, ItemValue, Tag, TagItem, TagType};
use metadata_god::api::api::read_metadata;
use metadata_god::api::ids::read_ids;
use std::process::Command;

const MBID: &str = "b1a9c0e9-d987-4042-ae91-78d6a3267d69";
const ISRC: &str = "GBAYE0601498";

fn gen(name: &str) -> String {
    let path = format!("{}/ids-{name}", env!("CARGO_TARGET_TMPDIR"));
    let _ = std::fs::remove_file(&path);
    let ok = Command::new("ffmpeg")
        .args(["-v", "error", "-f", "lavfi", "-i", "sine=d=1", "-map_metadata", "-1", &path])
        .status()
        .unwrap()
        .success();
    assert!(ok, "ffmpeg failed for {name}");
    path
}

fn tag_with(path: &str, tag_type: TagType, items: Vec<TagItem>) {
    let mut tag = Tag::new(tag_type);
    for i in items {
        tag.insert(i);
    }
    tag.save_to_path(path, WriteOptions::default()).unwrap();
}

fn item(key: ItemKey, v: &str) -> TagItem {
    TagItem::new(key, ItemValue::Text(v.to_string()))
}

fn ids_tags() -> Vec<TagItem> {
    vec![item(ItemKey::MusicBrainzRecordingId, MBID), item(ItemKey::Isrc, ISRC)]
}

fn check(path: &str) {
    let ids = read_ids(path.to_string()).unwrap();
    assert_eq!(ids.mbid.as_deref(), Some(MBID));
    assert_eq!(ids.isrc.as_deref(), Some(ISRC));
}

/// Prepends an ID3v2.3 tag made of raw frames (lofty cannot write UFID or TYER).
fn id3v3(path: &str, frames: &[(&str, Vec<u8>)]) {
    let body: Vec<u8> = frames
        .iter()
        .flat_map(|(id, data)| {
            let mut f = id.as_bytes().to_vec();
            f.extend((data.len() as u32).to_be_bytes());
            f.extend([0, 0]);
            f.extend(data);
            f
        })
        .collect();
    let n = body.len() as u32;
    let mut out = b"ID3\x03\x00\x00".to_vec();
    out.extend([(n >> 21) as u8 & 0x7f, (n >> 14) as u8 & 0x7f, (n >> 7) as u8 & 0x7f, n as u8 & 0x7f]);
    out.extend(body);
    out.extend(std::fs::read(path).unwrap());
    std::fs::write(path, out).unwrap();
}

fn text_frame(s: &str) -> Vec<u8> {
    [&[0u8][..], s.as_bytes()].concat()
}

#[test]
fn mp3_ufid() {
    let p = gen("a.mp3");
    id3v3(
        &p,
        &[
            ("UFID", [&b"http://musicbrainz.org\0"[..], MBID.as_bytes()].concat()),
            ("TSRC", text_frame(ISRC)),
        ],
    );
    check(&p);
}

#[test]
fn mp3_txxx() {
    let p = gen("b.mp3");
    id3v3(
        &p,
        &[
            ("TXXX", [&b"\0MusicBrainz Track Id\0"[..], MBID.as_bytes()].concat()),
            ("TSRC", text_frame(ISRC)),
        ],
    );
    check(&p);
}

#[test]
fn flac_vorbis() {
    let p = gen("c.flac");
    tag_with(&p, TagType::VorbisComments, ids_tags());
    check(&p);
}

#[test]
fn m4a_freeform() {
    let p = gen("d.m4a");
    tag_with(&p, TagType::Mp4Ilst, ids_tags());
    check(&p);
}

#[test]
fn no_ids_is_none() {
    let p = gen("e.mp3");
    tag_with(&p, TagType::Id3v2, vec![item(ItemKey::TrackTitle, "x")]);
    let ids = read_ids(p).unwrap();
    assert!(ids.mbid.is_none() && ids.isrc.is_none());
}

/// Dates like "20151119" crash the Dart parser; lofty must still give 2015 (D-320).
#[test]
fn full_date_year_is_read() {
    let mp3 = gen("f.mp3");
    id3v3(&mp3, &[("TIT2", text_frame("T")), ("TYER", text_frame("20151119"))]);
    let m4a = gen("g.m4a");
    tag_with(&m4a, TagType::Mp4Ilst, vec![item(ItemKey::TrackTitle, "T"), item(ItemKey::RecordingDate, "20151119")]);
    for p in [mp3, m4a] {
        let m = read_metadata(p.clone()).unwrap();
        assert_eq!(m.title.as_deref(), Some("T"), "{p}");
        assert_eq!(m.year, Some(2015), "{p}");
    }
}

#[test]
fn garbage_ufid_is_none() {
    let p = gen("h.mp3");
    id3v3(&p, &[("UFID", [&b"http://musicbrainz.org\0"[..], b"not-a-uuid"].concat())]);
    assert!(read_ids(p).unwrap().mbid.is_none());
}
