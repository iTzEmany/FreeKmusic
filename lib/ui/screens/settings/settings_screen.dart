import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/motion.dart';
import 'settings_pages.dart';
import 'settings_summaries.dart';
import '../../widgets/cc_app_bar.dart';
import '../stats/stats_screen.dart';

export 'settings_pages.dart' show SettingsPage, SettingsPageView, SettingsGroup, settingsPageTitle;

/// Settings as an index of pages. Phone: the index, each entry opens its
/// page. Desktop: index on the left, the page on the right.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initial});

  /// The page to show first (phone: opens straight on it).
  final SettingsPage? initial;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SettingsPage _page = widget.initial ?? SettingsPage.appearance;

  Widget _index(bool wide) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(CcDims.margin).withDock(context),
      children: [
        Material(
          color: cc.surface1,
          borderRadius: BorderRadius.circular(CcDims.rCard),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final p in SettingsPage.values)
                ListTile(
                  selected: wide && p == _page,
                  selectedTileColor: cc.surface2,
                  selectedColor: cc.text,
                  title: Text(
                    settingsPageTitle(l, p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: wide && p == _page ? FontWeight.w700 : null,
                    ),
                  ),
                  subtitle: Text(
                    settingsSummary(context, ref, p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cc.textMuted),
                  ),
                  trailing: wide ? null : const Icon(Icons.chevron_right_rounded),
                  onTap: () => wide
                      ? setState(() => _page = p)
                      : ShellNav.open<void>(
                          context,
                          Scaffold(
                            appBar: CcAppBar(title: settingsPageTitle(l, p)),
                            body: SettingsPageView(p),
                          ),
                        ),
                ),
              // Fixed entry, always there (D-484); opens the same screen as Home.
              ListTile(
                title: Text(l.statsTitle, style: text.titleSmall),
                subtitle: Text(
                  l.statsSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cc.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ShellNav.open<void>(context, const StatsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    if (wide) {
      return Row(
        children: [
          SizedBox(width: 280, child: _index(true)),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: TabFade(
                child: SettingsPageView(_page, key: ValueKey(_page)),
              ),
            ),
          ),
        ],
      );
    }
    final initial = widget.initial;
    return initial != null ? SettingsPageView(initial) : _index(false);
  }
}
