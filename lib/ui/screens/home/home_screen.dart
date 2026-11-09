import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/home_sections.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/activity_button.dart';
import '../../widgets/empty_state.dart';
import '../../../providers/folder_actions.dart';
import '../activity/activity_log_screen.dart';
import '../settings/settings_screen.dart';
import '../daylist/daylist_card.dart';
import 'exportify_card.dart';
import 'home_blocks.dart';
import 'home_bottom_rows.dart';
import 'resume_rows.dart';
import '../../widgets/cc_app_bar.dart';

/// The clock of the greeting; tests override it to be independent of the time of day.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

String _greeting(AppLocalizations l, int hour) =>
    switch (greetingForHour(hour)) {
      Greeting.morning => l.greetingMorning,
      Greeting.afternoon => l.greetingAfternoon,
      Greeting.evening => l.greetingEvening,
    };

/// Home: shuffle everything, shortcuts, what to resume, the latest additions
/// as a fan and a few short lists. Sections without data stay hidden.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final folders = ref.watch(foldersProvider).value;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap16,
        CcDims.gap4,
        CcDims.gap8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _greeting(l, ref.read(clockProvider)().hour),
              style: theme.headlineSmall,
            ),
          ),
          const ActivityButton(),
          IconButton(
            tooltip: l.activityLog,
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => ShellNav.open<void>(context, const ActivityLogScreen()),
          ),
          IconButton(
            tooltip: l.navSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => ShellNav.open<void>(
              context,
              Scaffold(
                appBar: CcAppBar(title: l.navSettings),
                body: const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
    );

    if (trackCount == 0 && folders != null && folders.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(
                child: EmptyState(
                  icon: Icons.library_music,
                  message: l.addMusicFolder,
                  actionLabel: l.addFolder,
                  onAction: () => addFolderAndScan(ref),
                  secondaryLabel: l.useDefaultFolder,
                  onSecondary: () => addDefaultFolderAndScan(ref),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // bottom: false, the list scrolls under the dock and pads itself.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= CcDims.wideBreakpoint;
                const lead = [ShuffleHero(), ShortcutsRow(), ExportifyCard()];
                return ListView(
                  children: [
                    header,
                    if (wide) ...[
                      // Desktop (mockup): invite and counters left, Riprendi right.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SizedBox(
                            width: 420,
                            child: Column(
                              children: [
                                ShuffleHero(),
                                ShortcutsRow(),
                                ExportifyCard(),
                                AddedLately(),
                              ],
                            ),
                          ),
                          SizedBox(width: 48),
                          Expanded(
                            child: Column(children: [ResumeList(), DaylistCard()]),
                          ),
                        ],
                      ),
                    ] else ...[
                      ...lead,
                      const ResumeList(),
                      const DaylistCard(),
                      const AddedLately(),
                    ],
                    HomeBottomRows(wide: wide),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
