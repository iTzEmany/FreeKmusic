use metadata_god::api::fingerprint::{fingerprint, fingerprint_raw};

const FIXTURES: [&str; 5] = ["tones.mp3", "sweep.m4a", "noise.ogg", "tones2.flac", "sweep.wav"];

fn path(name: &str) -> String {
    format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

/// Pulls the values out of `fpcalc -json -raw` output, plus its duration.
fn fpcalc_raw(name: &str) -> (Vec<u32>, u32) {
    let text = std::fs::read_to_string(path(&format!("{name}.fpcalc.raw.json"))).unwrap();
    let (head, list) = text.split_once("\"fingerprint\": [").unwrap();
    let dur: f64 = head.trim_start_matches("{\"duration\": ").trim().trim_end_matches(',').parse().unwrap();
    let vals = list.split(']').next().unwrap().split(',').map(|v| v.trim().parse().unwrap()).collect();
    (vals, dur as u32)
}

#[test]
fn matches_fpcalc_on_fixtures() {
    for name in FIXTURES {
        let (ours, dur) = fingerprint_raw(&path(name)).unwrap();
        let (theirs, theirs_dur) = fpcalc_raw(name);
        assert_eq!(dur, theirs_dur, "{name}: duration");
        let n = ours.len().min(theirs.len());
        assert!(ours.len().abs_diff(theirs.len()) <= 2, "{name}: length {} vs {}", ours.len(), theirs.len());
        let same = (0..n).filter(|&i| ours[i] == theirs[i]).count() as f64 / n as f64;
        let hamming = (0..n).map(|i| (ours[i] ^ theirs[i]).count_ones() as f64).sum::<f64>() / n as f64;
        println!("{name}: identical {:.2}%, mean hamming {hamming:.3}", same * 100.0);
        assert!(same >= 0.98 || hamming <= 2.0, "{name}: identical {same}, hamming {hamming}");
    }
}

#[test]
fn compressed_text_has_fpcalc_shape() {
    let fp = fingerprint(path("tones.mp3")).unwrap();
    // Identical raw values (see the other test) must give fpcalc's exact text.
    let theirs = std::fs::read_to_string(path("tones.mp3.fpcalc.json")).unwrap();
    assert!(theirs.contains(&format!("\"fingerprint\": \"{}\"", fp.fingerprint)));
    assert_eq!(fp.duration_s, 40);
}

#[test]
fn bad_inputs_are_errors_not_panics() {
    let dir = std::env::temp_dir();
    let empty = dir.join("fp_empty.mp3");
    std::fs::write(&empty, b"").unwrap();
    let junk = dir.join("fp_junk.ogg");
    std::fs::write(&junk, vec![0x5au8; 4096]).unwrap();
    for p in [empty.to_str().unwrap(), junk.to_str().unwrap(), "/no/such/file.mp3"] {
        assert!(fingerprint(p.to_string()).is_err(), "{p}");
    }
}

/// An ID3v2 tag of ~3 MB (big cover) must not stop the probe.
#[test]
fn huge_id3v2_tag_is_skipped() {
    let dir = env!("CARGO_TARGET_TMPDIR");
    let src = format!("{dir}/big-src.mp3");
    let out = format!("{dir}/big.mp3");
    let ok = |a: &[&str]| std::process::Command::new("ffmpeg").args(["-v", "error", "-y"]).args(a).status().unwrap().success();
    assert!(ok(&["-f", "lavfi", "-i", "sine=d=8", "-map_metadata", "-1", &src]));
    let apic = {
        let mut f = vec![0u8, b'i', b'm', b'a', b'g', b'e', b'/', b'j', b'p', b'e', b'g', 0, 3, 0];
        f.extend(vec![0xAB; 3_000_000]);
        f
    };
    let mut frame = b"APIC".to_vec();
    frame.extend((apic.len() as u32).to_be_bytes());
    frame.extend([0, 0]);
    frame.extend(&apic);
    let n = frame.len() as u32;
    let mut bytes = b"ID3\x03\x00\x00".to_vec();
    bytes.extend([(n >> 21) as u8 & 0x7f, (n >> 14) as u8 & 0x7f, (n >> 7) as u8 & 0x7f, n as u8 & 0x7f]);
    bytes.extend(frame);
    bytes.extend(std::fs::read(&src).unwrap());
    std::fs::write(&out, bytes).unwrap();
    let fp = fingerprint(out).unwrap();
    assert_eq!(fp.duration_s, 8);
}
