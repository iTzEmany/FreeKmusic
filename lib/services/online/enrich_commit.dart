import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/credits_repository.dart' show CreditsRepository, decodeRec, mergeDetails;
import '../import/track_matcher.dart' show matchKey;
import '../recognition/track_identity.dart';
import '../../data/repositories/track_repository.dart';
import '../covers/cover_store.dart';
import 'cover_fetcher.dart';
import 'credits_enricher.dart';
import 'curiosity_service.dart';
import 'enrich_gather.dart';
import 'enrich_parts.dart';
import 'enrich_writer.dart';
import 'enrichment_proposal.dart';
import 'lrclib_client.dart' show LyricsResult;

/// One track's commit in flight: the row and `track_enrich` read once, and
/// what the parts decided on the way.
class _Commit {
  _Commit(this.g, this.f, this.enrichRow, this.fields) : raw = enrichRow?.details ?? '{}';

  final EnrichGather g;
  final Track f;
  final TrackEnrichData? enrichRow;
  final Set<EnrichField> fields;
  List<TrackCreditRow>? stored; // read when credits were gathered
  String? plain, synced; // to write
  bool fills = false, coverPending = false;

  /// The `details` column as it will be: the stored one with `rec` merged in
  /// ([rawDirty]: to write with the marks), and the identity's MBID if the row has none.
  String raw;
  bool rawDirty = false, credited = false;
  String? mbid;

  /// The recognition to apply to the track once the transaction is closed.
  Recognition? correct;

  bool get byUser => enrichRow?.lyricsByUser ?? false;

  /// A part the row no longer needs (filled meanwhile by another track of the
  /// album, the download enricher or a refresh) is left alone: not «found»,
  /// not «nothing».
  void leave(EnrichPart p) {
    if (g.out.containsKey(p)) g.out[p] = PartOutcome.skipped;
    g.marks.remove(p);
  }
}

/// The writing half of the engine: one gathered track into `tracks`, the
/// cover, `track_credits`, the curiosities and `track_enrich`. The caller
/// holds the transaction.
class EnrichCommitter {
  EnrichCommitter(
    this.db,
    this.tracks,
    this._writer, {
    this.credits,
    this.curiosities,
    this.onSure,
  });

  final AppDatabase db;
  final TrackRepository tracks;
  final EnrichWriter _writer;
  final CreditsEnricher? credits;
  final CuriosityService? curiosities;

  /// Applies a sure recognition to the track (`TrackCorrections.apply`, not by the user).
  final Future<void> Function(Track, Recognition)? onSure;

  /// Applies the sure corrections [commitOne] returned, once the transaction is closed.
  Future<void> runCorrections(List<(Track, Recognition)> todo) async {
    for (final (t, rec) in todo) {
      try {
        await onSure!(t, rec);
      } on Object catch (e, st) {
        AppLog.w('correction of track ${t.id} not applied', e, st);
        // Not lost: the user can still accept it.
        try {
          await CreditsRepository(db).setRecDecision(t.id, 'open', from: rec);
        } on Object catch (e2, st2) {
          AppLog.w('proposal of track ${t.id} not kept', e2, st2);
        }
      }
    }
  }

  /// Writes one gathered track; the caller holds the transaction. Returns the
  /// correction to apply when the transaction is closed, if the recognition is sure.
  Future<(Track, Recognition)?> commitOne(EnrichGather g) async {
    final trackId = g.trackId;
    // The row may have changed (or be gone) while the sources were asked.
    final f = await tracks.getById(trackId);
    if (f == null) {
      g.out.updateAll((_, _) => PartOutcome.skipped); // nothing was saved
      g.rec = null; // and no recognition counts
      return null;
    }
    final enrichRow = await (db.select(
      db.trackEnrich,
    )..where((e) => e.trackId.equals(trackId))).getSingleOrNull();
    final c = _Commit(g, f, enrichRow, fillableFields(f));
    if (g.credits != null) c.stored = await credits!.repo.creditsOf(trackId);
    _commitLyrics(c);
    await _commitMeta(c);
    _commitRec(c);
    await _commitCredits(c);
    await _commitCurio(c);
    await _writeMarks(c);
    final status = statusAfter(EnrichStatus.fromCode(f.enrichStatus), g.out);
    if (status != null && status.code != f.enrichStatus) {
      await _writer.writeStatus(trackId, status);
    }
    return c.correct == null ? null : (f, c.correct!);
  }

  void _commitLyrics(_Commit c) {
    final f = c.f;
    if (c.byUser || f.lyricsPlain != null || f.lyricsSynced != null) {
      c.leave(EnrichPart.lyrics);
    }
    if (c.byUser || f.lyricsSynced != null) c.leave(EnrichPart.synced);
    c.plain = f.lyricsPlain == null && !c.byUser ? c.g.plain : null;
    c.synced = f.lyricsSynced == null && !c.byUser ? c.g.synced : null;
  }

  /// The fields of the row (meta and lyrics together: one write), then the cover.
  Future<void> _commitMeta(_Commit c) async {
    final g = c.g, f = c.f, marks = g.marks;
    final at = DateTime.fromMillisecondsSinceEpoch(g.now);
    final metaEmpty = isDue(EnrichPart.meta, f, c.enrichRow, at, mode: AskMode.force);
    final meta = g.meta;
    final m = meta?.match;
    final fields = c.fields;
    c.fills =
        m != null &&
        ((fields.contains(EnrichField.album) && m.album != null) ||
            (fields.contains(EnrichField.year) && m.year != null) ||
            (fields.contains(EnrichField.genre) && m.genre != null) ||
            (fields.contains(EnrichField.trackNumber) &&
                (m.trackNumber != null ||
                    (meta!.disc != null && f.discNumber == null))) ||
            (meta!.isrc != null && f.isrc == null));
    // The cover is the only thing meta would fill.
    c.coverPending =
        g.metaAsked &&
        !c.fills &&
        m?.artworkUrl != null &&
        !f.hasCover &&
        f.coverSource == 0;
    // A cover that is yet to be applied settles meta after it.
    final metaLeft = g.metaAsked && !c.coverPending && !c.fills && !metaEmpty;
    if (g.metaAsked && !c.coverPending && !metaLeft) {
      g.settle(
        EnrichPart.meta,
        c.fills ? PartOutcome.found : PartOutcome.none,
        g.now,
      );
    }
    var albumKey = f.albumKey;
    if (c.fills || c.plain != null || c.synced != null) {
      albumKey = (await _writer.writeFields(
        f,
        EnrichmentProposal(
          track: f,
          meta: c.fills ? m : null,
          disc: c.fills ? meta!.disc : null,
          isrc: c.fills ? meta!.isrc : null,
          lyrics: LyricsResult(plain: c.plain, synced: c.synced),
        ),
        fields,
      )).key;
    }
    // Only if the album is still the one the file was saved for.
    final fetched = g.cover == CoverResult.saved || g.cover == CoverResult.albumHasCover;
    final saved =
        fetched && g.coverAlbum == albumKey && !f.hasCover && f.coverSource == 0;
    if (saved) {
      await tracks.setCoverForAlbum(albumKey, true, CoverStore.coverKeyFor(albumKey));
    }
    if (c.coverPending) {
      // No cover, nothing else filled: not «found». A cover that does not exist
      // is «nothing» (mark set); a download that failed is unknown (mark stays, invariant 3).
      if (!saved && g.cover == CoverResult.sourceHasNoFile) {
        g.settle(EnrichPart.meta, PartOutcome.none, g.now);
      } else {
        g.out[EnrichPart.meta] = saved ? PartOutcome.found : PartOutcome.failed;
      }
      if (saved) marks[EnrichPart.meta] = null;
    }
  }

  Future<void> _commitCredits(_Commit c) async {
    final g = c.g;
    if (g.credits == null) return;
    if (g.mode != AskMode.force && c.stored!.isNotEmpty) {
      c.leave(EnrichPart.credits);
    } else {
      c.raw = await credits!.save(g.trackId, g.credits, trackKnown: true, stored: c.stored, baseDetails: c.raw) ?? c.raw;
      c.credited = true;
    }
  }

  /// The recognition joins the shared `details` JSON (written with the marks).
  /// Nothing to write when it was saved already or got no answer. It is merged
  /// with the stored one: a proposal the user discarded (or accepted, or applied) keeps
  /// its state while the identity is the same, `was` is kept, and a hand-edited row (read fresh
  /// here) never gets an open proposal. The row's title and artist stay.
  void _commitRec(_Commit c) {
    var rec = c.g.rec;
    if (rec == null) return;
    final old = decodeRec(c.raw, c.g.trackId);
    var prop = rec.prop;
    final same = old != null && _sameIdentity(old.identity, rec.identity);
    // The same song keeps what was decided about it.
    if (same && const {'discarded', 'accepted', 'auto'}.contains(old.prop)) prop = old.prop;
    final id = rec.identity;
    final differs = id != null &&
        (matchKey(id.title) != matchKey(c.f.title) ||
            (id.artist.isNotEmpty && matchKey(id.artist) != matchKey(c.f.artist ?? '')));
    final decided = const {'discarded', 'accepted', 'auto'}.contains(prop);
    final fixes = differs && !c.f.userEdited && !decided;
    if (fixes && !rec.sure) prop = 'open';
    if (prop == 'open' && c.f.userEdited) prop = null;
    final original = rec.original ?? (same ? old.original : null);
    if (prop != rec.prop || (rec.was == null && old?.was != null) || original != rec.original) {
      rec = rec.copyWith(prop: prop, was: rec.was ?? old?.was, original: original);
    }
    c.raw = mergeDetails(c.raw, rec: rec);
    c.rawDirty = true;
    if (fixes && rec.sure && onSure != null) c.correct = rec;
    if ((c.enrichRow?.mbid ?? '').isEmpty && rec.sure && rec.usable) c.mbid = rec.identity?.mbid;
  }

  Future<void> _commitCurio(_Commit c) async {
    final g = c.g;
    final lookup = g.curio;
    if (lookup != null && g.mode != AskMode.force && c.f.curiosities != null) {
      c.leave(EnrichPart.curio);
    } else if (lookup != null &&
        (await curiosities!.save(g.trackId, lookup)).failed) {
      g.out[EnrichPart.curio] = PartOutcome.failed;
      g.marks.remove(EnrichPart.curio);
    }
  }

  /// The «searched, nothing» marks (and their clearing) of the parts that settled.
  Future<void> _writeMarks(_Commit c) async {
    final marks = c.g.marks;
    if (marks.isEmpty && !c.rawDirty) return;
    // A MBID the credits just saved is not «empty».
    final mbid = c.credited && c.g.credits?.mbid != null ? null : c.mbid;
    Value<int?> mark(EnrichPart p) =>
        marks.containsKey(p) ? Value(marks[p]) : const Value.absent();
    final row = TrackEnrichCompanion(
      trackId: Value(c.g.trackId),
      details: c.rawDirty ? Value(c.raw) : const Value.absent(),
      mbid: mbid == null ? const Value.absent() : Value(mbid),
      metaNoneAt: mark(EnrichPart.meta),
      lyricsNoneAt: mark(EnrichPart.lyrics),
      syncedNoneAt: mark(EnrichPart.synced),
      curioNoneAt: mark(EnrichPart.curio),
    );
    await db.into(db.trackEnrich).insert(row, onConflict: DoUpdate((_) => row));
  }
}

/// The same song: the same MusicBrainz id, else the same title and artist.
bool _sameIdentity(TrackIdentity? a, TrackIdentity? b) {
  if (a == null || b == null) return false;
  if (a.mbid != null && a.mbid == b.mbid) return true;
  return matchKey(a.title) == matchKey(b.title) && matchKey(a.artist) == matchKey(b.artist);
}
