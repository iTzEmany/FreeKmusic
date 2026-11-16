import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/online/youtube_service.dart' show AudioQuality;
import '../memory/free_space_screen.dart';

String audioQualityLabel(AppLocalizations l, AudioQuality q) => switch (q) {
  AudioQuality.high => l.qualityHigh,
  AudioQuality.medium => l.qualityMedium,
  AudioQuality.low => l.qualityLow,
};

/// D-580: «Qualità download» or «Qualità streaming».
class QualityTile extends ConsumerWidget {
  const QualityTile({super.key, required this.stream});

  final bool stream;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final value = ref.watch(settingsProvider.select((s) => stream ? s.streamQuality : s.downloadQuality));
    return ListTile(
      leading: Icon(stream ? Icons.wifi_tethering : Icons.high_quality_outlined),
      title: Text(stream ? l.qualityStream : l.qualityDownload),
      trailing: DropdownButton<AudioQuality>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [for (final q in AudioQuality.values) DropdownMenuItem(value: q, child: Text(audioQualityLabel(l, q)))],
        onChanged: (q) => q == null
            ? null
            : ref.read(settingsProvider.notifier).update(
                (s) => stream ? s.copyWith(streamQuality: q) : s.copyWith(downloadQuality: q),
              ),
      ),
    );
  }
}

/// D-581: opens «Libera spazio».
class FreeSpaceTile extends StatelessWidget {
  const FreeSpaceTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.cleaning_services_outlined),
    title: Text(context.l10n.freeSpaceTitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FreeSpaceScreen())),
  );
}
