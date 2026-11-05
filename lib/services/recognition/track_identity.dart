import 'package:drift/drift.dart' show Value;

import '../../data/db/app_database.dart' show Track;

/// Bump to redo the recognition pass with new rules (R-176).
const kRecogVersion = 2;

const _keep = Object();

/// Where an identity came from; the name is the JSON value of `rec.src`.
enum RecogSource { tags, ytid, text, acoustid, ytm }

const _props = {'auto', 'open', 'accepted', 'discarded'};

/// The song a track was recognised as.
class TrackIdentity {
  const TrackIdentity({
    required this.title,
    required this.artist,
    this.ms,
    this.isrc,
    this.mbid,
    this.vid,
  });

  final String title, artist;
  final int? ms;
  final String? isrc, mbid, vid;

  /// The artist a track gets: an empty one here keeps the [current] one.
  String? artistOver(String? current) => artist.isEmpty ? current : artist;

  /// [t] as this identity says it is: what meta, lyrics and curiosities are searched with.
  Track applyTo(Track t) => t.copyWith(
        title: title,
        artist: artist.isEmpty ? const Value.absent() : Value(artist),
        durationMs: ms != null && ms! > 0 ? ms : null,
        isrc: Value(isrc ?? t.isrc),
      );
}

/// The `rec` key of `track_enrich.details`. [src] null = every source answered «nothing found».
class Recognition {
  const Recognition({
    required this.at,
    this.v = kRecogVersion,
    this.src,
    this.score,
    this.sure = false,
    this.identity,
    this.prop,
    this.was,
    this.original,
    this.cover = false,
  });

  final int v, at;
  final RecogSource? src;
  final double? score;
  final bool sure;
  final TrackIdentity? identity;

  /// `auto`, `open`, `accepted`, `discarded`; null when nothing is to change.
  final String? prop;

  /// Title and artist before an automatic correction.
  final Map<String, String>? was;

  /// The original song of a cover (69e).
  final Map<String, String>? original;

  /// False once the user discarded (or reverted) the proposal: it must not drive searches.
  bool get usable => prop != 'discarded';

  /// The track is a cover, an arrangement or a remix; [original] may still be unknown.
  final bool cover;

  /// A copy with other [sure], [identity], [prop], [was], [original] or [cover]; the rest is kept.
  /// A nullable field is replaced even by null when it is passed.
  Recognition copyWith({
    bool? sure,
    TrackIdentity? identity,
    Object? prop = _keep,
    Object? was = _keep,
    Object? original = _keep,
    bool? cover,
  }) =>
      Recognition(
        v: v,
        at: at,
        src: src,
        score: score,
        sure: sure ?? this.sure,
        identity: identity ?? this.identity,
        prop: identical(prop, _keep) ? this.prop : prop as String?,
        was: identical(was, _keep) ? this.was : was as Map<String, String>?,
        original: identical(original, _keep) ? this.original : original as Map<String, String>?,
        cover: cover ?? this.cover,
      );

  Map<String, Object?> toJson() {
    final i = identity;
    return {
      'v': v,
      'at': at,
      'src': src?.name,
      if (src != null) 'sure': sure,
      'score': ?score,
      if (i != null) ...{
        'title': i.title,
        'artist': i.artist,
        'ms': ?i.ms,
        'isrc': ?i.isrc,
        'mbid': ?i.mbid,
        'vid': ?i.vid,
      },
      'prop': ?prop,
      'was': ?was,
      'original': ?original,
      if (cover) 'cover': true,
    };
  }

  /// Untrusted input (a stored or restored row): whatever has the wrong type
  /// is left out, and anything that is not a map is null. Never throws.
  static Recognition? fromJson(Object? json) {
    if (json is! Map) return null;
    String? str(String k) => json[k] is String && (json[k] as String).trim().isNotEmpty ? (json[k] as String).trim() : null;
    int? integer(String k) {
      final x = json[k];
      return x is num && x.isFinite ? x.toInt() : null;
    }

    Map<String, String>? strings(String k) {
      final m = json[k];
      if (m is! Map) return null;
      final out = {
        for (final e in m.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
      return out.isEmpty ? null : out;
    }

    final title = str('title');
    final score = json['score'];
    return Recognition(
      v: integer('v') ?? 0,
      at: integer('at') ?? 0,
      src: RecogSource.values.asNameMap()[json['src']],
      score: score is num && score.isFinite ? score.toDouble() : null,
      sure: json['sure'] == true,
      identity: title == null
          ? null
          : TrackIdentity(
              title: title,
              artist: str('artist') ?? '',
              ms: integer('ms'),
              isrc: str('isrc'),
              mbid: str('mbid'),
              vid: str('vid'),
            ),
      prop: _props.contains(json['prop']) ? json['prop'] as String : null,
      was: strings('was'),
      original: strings('original'),
      cover: json['cover'] == true,
    );
  }
}
