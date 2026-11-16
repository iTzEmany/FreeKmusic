import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/radio/country_names.dart' show countryNameIn;
import '../../widgets/cc_sheet.dart';

/// Countries of Apple's feed offered for the Top 20 (D-614); Deezer's chart follows the IP.
const _chartCountries = [
  'IT', 'US', 'GB', 'DE', 'FR', 'ES', 'PT', 'BR', 'CH', 'AT',
  'NL', 'BE', 'IE', 'CA', 'AU', 'MX', 'AR', 'SE', 'PL', 'JP',
];

/// «Paese delle classifiche»: automatic (device region) or one country.
class ChartCountryTile extends ConsumerWidget {
  const ChartCountryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final chosen = ref.watch(settingsProvider.select((s) => s.chartCountry));
    String name(String c) => countryNameIn(c, lang, c);
    void set(String c) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(chartCountry: c));
    return ListTile(
      key: const ValueKey('chart-country'),
      leading: const Icon(Icons.public_rounded),
      title: Text(l.chartCountryTitle),
      subtitle: Text(chosen.isEmpty ? l.chartCountryAuto : name(chosen)),
      onTap: () => showCcActionSheet<String>(
        context: context,
        title: l.chartCountryTitle,
        groups: [
          [
            CcAction(
              icon: Icons.auto_mode_rounded,
              label: l.chartCountryAuto,
              selected: chosen.isEmpty,
              onTap: () => set(''),
            ),
            for (final c in _chartCountries)
              CcAction(
                icon: Icons.public_rounded,
                label: name(c),
                selected: chosen == c,
                onTap: () => set(c),
              ),
          ],
        ],
      ),
    );
  }
}
