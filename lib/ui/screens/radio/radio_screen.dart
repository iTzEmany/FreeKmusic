import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/radio_ops.dart';
import '../../../providers/radio_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/radio/country_names.dart';
import '../../theme/tokens.dart';
import 'add_station_dialog.dart';
import 'radio_region_sheet.dart';
import 'radio_sections.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_search_field.dart';

/// Library → Radio: a search box, «Le mie radio», «Vicino a te» (country and
/// region chosen by hand), the genres and the most listened of the country.
class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String? _genre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The saved stations are read again once a day, without waiting for it.
      unawaited(ref.read(radioOpsProvider).refreshSaved());
      // First visit: no region yet, so the sheet that asks for it opens by itself.
      if (ref.read(settingsProvider).radioRegion.isEmpty) {
        RadioRegionSheet.show(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final searching = _query.length >= 2;
    final onlyCountry = ref.watch(
      settingsProvider.select((s) => s.radioOnlyCountry),
    );
    final code = ref.watch(radioCountryProvider);
    final countryName = countryNameIn(
      code,
      Localizations.localeOf(context).languageCode,
      ref
              .watch(radioCountriesProvider)
              .value
              ?.where((c) => c.code == code)
              .map((c) => c.name)
              .firstOrNull ??
          code,
    );
    final List<Widget> body;
    if (searching) {
      body = [SearchResultsSection(query: _query)];
    } else if (_genre != null) {
      body = [
        GenresSection(
          selected: _genre,
          onSelect: (t) => setState(() => _genre = t),
        ),
        GenreResultsSection(
          tag: _genre!,
          onClose: () => setState(() => _genre = null),
        ),
      ];
    } else {
      body = [
        const MineSection(),
        GenresSection(
          selected: null,
          onSelect: (t) => setState(() => _genre = t),
        ),
        const NearYouSection(),
        const TopSection(),
      ];
    }
    return Scaffold(
      appBar: CcAppBar(
        title: l.radioTitle,
        actions: [
          IconButton(
            key: const ValueKey('radio-add-address'),
            tooltip: l.radioAddAddress,
            icon: const Icon(Icons.add_link_rounded),
            onPressed: () => AddStationDialog.show(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    CcDims.gap8,
                    CcDims.margin,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CcSearchField(
                        key: const ValueKey('radio-search'),
                        controller: _controller,
                        focusNode: _focus,
                        hint: l.radioSearchHint,
                        debounce: CcTiming.radioDebounce,
                        onQuery: (v) => setState(() => _query = v),
                      ),
                      if (searching || _genre != null)
                        Padding(
                          padding: const EdgeInsets.only(top: CcDims.gap8),
                          child: FilterChip(
                            key: const ValueKey('radio-only-country'),
                            label: Text(l.radioOnlyCountry(countryName)),
                            selected: onlyCountry,
                            onSelected: (v) => ref
                                .read(settingsProvider.notifier)
                                .update((s) => s.copyWith(radioOnlyCountry: v)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ...body,
              SliverToBoxAdapter(
          child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ),
            ],
          ),
        ),
      ),
    );
  }
}
