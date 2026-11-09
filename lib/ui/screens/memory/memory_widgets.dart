import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/format_utils.dart';

/// Width (at normal text size) of the size label column of a [WeightRow].
const sizeColumnWidth = 76.0;

/// A row of a «Memoria» list: name, what it holds, how much space it takes,
/// and a thin dimmed bar of its share ([fraction] 0–1, null = no bar).
/// [detail] is a small faint line (a folder path).
class WeightRow extends StatelessWidget {
  const WeightRow({
    super.key,
    required this.title,
    required this.bytes,
    this.subtitle,
    this.detail,
    this.leading,
    this.fraction,
    this.onTap,
    this.trailing,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle, detail;
  final int bytes;
  final Widget? leading;
  final double? fraction;
  final VoidCallback? onTap;

  /// After the size (the «apri» hint of a folder row).
  final Widget? trailing;

  /// Replaces what a screen reader reads for the whole row.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final f = fraction;
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CcDims.margin,
          vertical: CcDims.gap8,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyLarge,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                    ),
                  if (detail != null)
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(color: cc.textFaint),
                    ),
                  if (f != null) ...[
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CcDims.rBar),
                        child: LinearProgressIndicator(
                          value: f.clamp(0.0, 1.0),
                          minHeight: 3,
                          color: cc.surface3,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // A fixed column, so every bar in the list has the same track.
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(sizeColumnWidth),
              child: Text(
                formatBytes(bytes, Localizations.localeOf(context).toString()),
                maxLines: 1,
                textAlign: TextAlign.end,
                style: theme.titleSmall?.copyWith(color: cc.text),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    final label = semanticLabel;
    return label == null
        ? row
        : Semantics(button: true, label: label, excludeSemantics: true, onTap: onTap, child: row);
  }
}

/// Share of [part] in [whole] for a bar; 0 when there is no whole.
double shareOf(int part, int whole) => whole <= 0 ? 0 : part / whole;

/// The 44 px icon square that stands for a row without a cover.
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: context.cc.surface2,
      borderRadius: BorderRadius.circular(CcDims.rList),
    ),
    child: Icon(icon, size: 22, color: context.cc.textMuted),
  );
}
