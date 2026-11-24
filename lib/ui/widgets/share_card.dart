import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/share/share_fragment.dart' show SharedKind;
import '../theme/tokens.dart';

const kShareCardSize = Size(1080, 1350);

/// The picture shared for a track, album or playlist (D-713): always dark, drawn off screen at
/// 1080 x 1350, so it uses the fixed `notte` colours and not the theme of the screen.
/// [covers] are decoded already (up to 4: the playlist mosaic); [qrLink] is null when the QR is left out.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.kind,
    required this.brand,
    required this.kindLabel,
    required this.title,
    required this.meta,
    required this.tint,
    this.subtitle,
    this.covers = const [],
    this.qrLink,
  });

  final SharedKind kind;
  final String brand, kindLabel, title, meta;
  final String? subtitle;
  final Color tint;
  final List<ui.Image> covers;
  final String? qrLink;

  static const _c = CcColors.notte;
  static const _art = 560.0;

  @override
  Widget build(BuildContext context) {
    // With the QR (520 px wide) the text column is narrow: a smaller title keeps it readable.
    final head = ccStyle('Unbounded', qrLink == null ? 64 : 52, 700, color: _c.text, height: 1.1);
    return SizedBox.fromSize(
      size: kShareCardSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tint, _c.bg]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(brand, style: ccStyle('Unbounded', 40, 700, color: _c.accentSoft)),
                  Text(kindLabel.toUpperCase(), style: ccStyle('Figtree', 34, 700, color: _c.textMuted)),
                ],
              ),
              Expanded(child: Center(child: _artwork())),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: head),
                        if ((subtitle ?? '').isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: ccStyle('Figtree', 40, 600, color: _c.textMuted)),
                        ],
                        const SizedBox(height: 16),
                        Text(meta, style: ccStyle('Figtree', 34, 500, color: _c.textFaint)),
                      ],
                    ),
                  ),
                  if (qrLink != null) ...[
                    const SizedBox(width: 32),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      // Level M and 480 px are what the link limit (QR version 15) was worked out for.
                      child: QrImageView(key: ValueKey<String>(qrLink!), data: qrLink!, size: 480, padding: EdgeInsets.zero, errorCorrectionLevel: QrErrorCorrectLevel.M),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Track: the cover in a ring. Album: the cover. Playlist: the first 4 in a mosaic. No cover: the ring with the initial.
  Widget _artwork() {
    if (covers.isEmpty) return _ring(Text(_initial, style: ccStyle('Unbounded', 240, 700, color: _c.onAccent)));
    if (kind == SharedKind.track) return _ring(SizedBox.expand(child: _img(covers.first)));
    // Fewer than 4 distinct covers: one cover, as an album (a mosaic would repeat or leave holes).
    if (kind != SharedKind.track && covers.length < 4) return ClipRRect(borderRadius: BorderRadius.circular(32), child: SizedBox.square(dimension: _art, child: _img(covers.first)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox.square(
        dimension: _art,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [for (var i = 0; i < 4; i++) i < covers.length ? _img(covers[i]) : ColoredBox(color: _c.surface3)],
        ),
      ),
    );
  }

  /// The first letter or digit of the title (whole grapheme), else a note.
  String get _initial {
    final first = title.trim().characters.firstOrNull;
    return first != null && RegExp(r'^[\p{L}\p{N}]', unicode: true).hasMatch(first) ? first.toUpperCase() : '♪';
  }

  Widget _img(ui.Image i) => RawImage(image: i, fit: BoxFit.cover);

  Widget _ring(Widget inner) => Container(
    width: _art,
    height: _art,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _c.accent, width: 14)),
    child: ClipOval(child: ColoredBox(color: _c.accent, child: Center(child: inner))),
  );
}
