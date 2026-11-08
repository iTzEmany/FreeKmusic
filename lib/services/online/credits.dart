import '../../core/artist_key.dart';

// Names without letters («!!!») have an empty matchKey: keep them apart.
String creditNameKey(String name) {
  final k = matchKey(name);
  return k.isEmpty ? name.trim().toLowerCase() : k;
}

/// One person with one role on a track. The DB key is `nameKey + role`.
class TrackCredit {
  TrackCredit(this.name, this.role, this.source)
    : nameKey = creditNameKey(name);

  final String name;
  final String nameKey;

  /// Lower-case role as the source spells it (`mixingengineer`, `guitar`).
  final String role;

  /// `deezer` or `musicbrainz`.
  final String source;

  Map<String, Object?> toJson() => {
    'name': name,
    'role': role,
    'source': source,
  };

  /// Untrusted input: null when a field is not a usable string.
  static TrackCredit? tryParse(Object? j) {
    if (j is! Map) return null;
    final (n, r, s) = (j['name'], j['role'], j['source']);
    if (n is! String || r is! String || s is! String) return null;
    if (n.trim().isEmpty ||
        r.trim().isEmpty ||
        n.length > 200 ||
        r.length > 100 ||
        (s != 'deezer' && s != 'musicbrainz')) {
      return null;
    }
    return TrackCredit(n.trim(), r.trim().toLowerCase(), s);
  }
}

/// The valid credits of a JSON list, stopping at the first [max].
List<TrackCredit> parseCreditList(Object? raw, {required int max}) {
  final out = <TrackCredit>[];
  if (raw is! List) return out;
  for (final j in raw) {
    if (out.length >= max) break;
    final c = TrackCredit.tryParse(j);
    if (c != null) out.add(c);
  }
  return out;
}

class DeezerContributors {
  const DeezerContributors(
    this.credits, {
    this.copyright,
    this.physicalReleaseDate,
  });
  final List<TrackCredit> credits;
  final String? copyright;
  final String? physicalReleaseDate;
}

/// [data] is `results.DATA` of a gw `deezer.pageTrack` answer.
/// `main_artist` is dropped: the artist is already `tracks.artist`.
DeezerContributors parseDeezerContributors(Map<String, dynamic> data) {
  final credits = <TrackCredit>[];
  final contributors = data['SNG_CONTRIBUTORS'];
  if (contributors is Map) {
    contributors.forEach((role, names) {
      final r = role.toString().toLowerCase();
      if (r == 'main_artist' || names is! List) return;
      for (final n in names) {
        if (n is String && n.trim().isNotEmpty) {
          credits.add(TrackCredit(n.trim(), r, 'deezer'));
        }
      }
    });
  }
  String? text(Object? v) => v is String && v.isNotEmpty ? v : null;
  return DeezerContributors(
    _dedupe(credits),
    copyright: text(data['COPYRIGHT']),
    physicalReleaseDate: text(data['PHYSICAL_RELEASE_DATE']),
  );
}

/// [recording] is a MusicBrainz `/recording/{mbid}?inc=artist-rels+work-rels+work-level-rels`
/// answer. Instrument relations take the instrument as role; work-to-work
/// and non-artist relations are ignored.
List<TrackCredit> parseMbCredits(Map<String, dynamic> recording) {
  final out = <TrackCredit>[];
  void fromRelations(Object? rels) {
    if (rels is! List) return;
    for (final rel in rels) {
      if (rel is! Map || rel['target-type'] != 'artist') continue;
      final artist = rel['artist'];
      if (artist is! Map) continue;
      final name = artist['name'];
      final type = rel['type'];
      final attrList = rel['attributes'];
      // A malformed relation is skipped, the others stay.
      if (name is! String || name.trim().isEmpty || type is! String) continue;
      if (attrList != null && attrList is! List) continue;
      final attrs = [
        for (final a in attrList as List? ?? const [])
          if (a is String && a.trim().isNotEmpty) a.trim().toLowerCase(),
      ];
      final t = type.trim().toLowerCase();
      final roles = t == 'instrument' && attrs.isNotEmpty ? attrs : [t];
      for (final role in roles) {
        if (role.isEmpty) continue;
        out.add(TrackCredit(name.trim(), role, 'musicbrainz'));
      }
    }
  }

  final rels = recording['relations'];
  fromRelations(rels);
  if (rels is List) {
    for (final rel in rels) {
      if (rel is Map && rel['target-type'] == 'work' && rel['work'] is Map) {
        fromRelations((rel['work'] as Map)['relations']);
      }
    }
  }
  return _dedupe(out);
}

/// Deezer first; MusicBrainz only adds the `nameKey + role` pairs still missing.
List<TrackCredit> mergeCredits(
  List<TrackCredit> deezer,
  List<TrackCredit> mb,
) => _dedupe([...deezer, ...mb]);

List<TrackCredit> _dedupe(List<TrackCredit> all) {
  final seen = <String>{};
  return [
    for (final c in all)
      if (seen.add('${c.nameKey}\u0000${c.role}')) c,
  ];
}

/// Extra data of the public API (`/track/{id}` + `/album/{id}`). [copyright] and
/// [physicalReleaseDate] come from the gw API (task 50.4), never from here.
class TrackDetails {
  const TrackDetails({
    this.bpm,
    this.label,
    this.digitalReleaseDate,
    this.recordType,
    this.rank,
    this.albumFans,
    this.explicit,
    this.copyright,
    this.physicalReleaseDate,
  });

  factory TrackDetails.fromJson(Map<dynamic, dynamic> j) => TrackDetails(
    bpm: _num(j['bpm'], 1, 400)?.toDouble(),
    label: _str(j['label']),
    digitalReleaseDate: _str(j['digitalReleaseDate']),
    recordType: _str(j['recordType']),
    rank: _num(j['rank'], 0, _big)?.toInt(),
    albumFans: _num(j['albumFans'], 0, _big)?.toInt(),
    explicit: j['explicit'] is bool ? j['explicit'] as bool : null,
    copyright: _str(j['copyright'], 500),
    physicalReleaseDate: _str(j['physicalReleaseDate']),
  );

  // Untrusted input: a wrong type is null, a long string is cut.
  static String? _str(Object? v, [int max = 200]) =>
      v is String ? (v.length > max ? v.substring(0, max) : v) : null;
  static const _big = 1e10;
  static num? _num(Object? v, num min, num max) =>
      v is num && v.isFinite && v >= min && v <= max ? v : null;

  TrackDetails copyWith({String? copyright, String? physicalReleaseDate}) =>
      TrackDetails(
        bpm: bpm,
        label: label,
        digitalReleaseDate: digitalReleaseDate,
        recordType: recordType,
        rank: rank,
        albumFans: albumFans,
        explicit: explicit,
        copyright: copyright ?? this.copyright,
        physicalReleaseDate: physicalReleaseDate ?? this.physicalReleaseDate,
      );

  Map<String, Object?> toJson() => {
    'bpm': bpm,
    'label': label,
    'digitalReleaseDate': digitalReleaseDate,
    'recordType': recordType,
    'rank': rank,
    'albumFans': albumFans,
    'explicit': explicit,
    'copyright': copyright,
    'physicalReleaseDate': physicalReleaseDate,
  };

  /// Null when Deezer has none (it answers 0).
  final double? bpm;
  final String? label, digitalReleaseDate, recordType;
  final String? copyright, physicalReleaseDate;
  final int? rank, albumFans;
  final bool? explicit;
}
