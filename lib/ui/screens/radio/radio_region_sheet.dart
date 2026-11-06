import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/radio_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/radio/radio_browser_client.dart';
import '../../../services/radio/regions.dart';
import '../../../services/radio/country_names.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/async_body.dart';

/// Country and region for «Vicino a te». Nothing about the user's position is
/// asked: they are picked by hand. The sheet opens by itself the first time.
class RadioRegionSheet extends ConsumerStatefulWidget {
  const RadioRegionSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.8,
      child: RadioRegionSheet(),
    ),
  );

  @override
  ConsumerState<RadioRegionSheet> createState() => _RadioRegionSheetState();
}

class _RadioRegionSheetState extends ConsumerState<RadioRegionSheet> {
  bool _pickingCountry = false;

  void _chooseRegion(RadioRegion r) {
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(radioRegion: r.id));
    Navigator.of(context).pop();
  }

  void _chooseCountry(RadioCountry c) {
    // The regions are the old country's: the choice starts again.
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(radioCountry: c.code, radioRegion: ''));
    setState(() => _pickingCountry = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final code = ref.watch(radioCountryProvider);
    final countries = ref.watch(radioCountriesProvider);
    final countryName = countryNameIn(
      code,
      Localizations.localeOf(context).languageCode,
      countries.value
              ?.where((c) => c.code == code)
              .map((c) => c.name)
              .firstOrNull ??
          code,
    );
    final selected = ref.watch(settingsProvider.select((s) => s.radioRegion));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            0,
            CcDims.margin,
            CcDims.gap4,
          ),
          child: Text(
            _pickingCountry ? l.radioChooseCountry : l.radioChooseRegion,
            style: theme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Text(
            l.radioRegionHint,
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        if (!_pickingCountry)
          ListTile(
            key: const ValueKey('radio-country'),
            leading: const Icon(Icons.public_rounded),
            title: Text(l.radioCountryChip(countryName)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() => _pickingCountry = true),
          ),
        Expanded(
          child: _pickingCountry
              ? _countryList(countries)
              : _regionList(selected),
        ),
      ],
    );
  }

  Widget _countryList(AsyncValue<List<RadioCountry>> countries) =>
      AsyncBody(
        value: countries,
        errorMessage: context.l10n.radioLoadFailed,
        data: (list) {
          final sorted = [...list]
            ..sort((a, b) => b.stationCount.compareTo(a.stationCount));
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(sorted[i].name),
              trailing: Text('${sorted[i].stationCount}'),
              onTap: () => _chooseCountry(sorted[i]),
            ),
          );
        },
      );

  Widget _regionList(String selected) {
    final regions = ref.watch(radioRegionsProvider);
    return AsyncBody(
      value: regions,
      errorMessage: context.l10n.radioLoadFailed,
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => ListTile(
          key: ValueKey('region-${list[i].id}'),
          title: Text(list[i].label),
          trailing: list[i].id == selected
              ? Icon(Icons.check_rounded, color: context.cc.accent)
              : null,
          onTap: () => _chooseRegion(list[i]),
        ),
      ),
    );
  }
}
