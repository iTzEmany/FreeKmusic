import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/equalizer_providers.dart';
import 'providers/jam_providers.dart' show jamOnlineFailuresProvider;
import 'providers/player_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/share_hub.dart';
import 'providers/startup_providers.dart' show enrichCompleterStartProvider, mp3LengthFixStartProvider;
import 'providers/theme_providers.dart';
import 'providers/update_providers.dart';
import 'providers/youtube_providers.dart' show promoteErrorsProvider;
import 'providers/activity_log_providers.dart';
import 'providers/import_notification_providers.dart';
import 'l10n/l10n_ext.dart';
import 'ui/screens/onboarding/onboarding_gate.dart';
import 'providers/releases_providers.dart' show releaseCheckControllerProvider;
import 'ui/shell/app_shell.dart';
import 'ui/widgets/app_icon_sync.dart';
import 'ui/widgets/user_activity_scope.dart';
import 'ui/theme/app_theme.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class CodecoreApp extends ConsumerWidget {
  const CodecoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(shareAutoStartProvider);
    // Alive from the start, so the Registro has the real times of what ends.
    ref.listen(activityLogProvider, (_, _) {});
    ref.watch(equalizerApplierProvider);
    ref.watch(outputRouteSyncProvider);
    ref.watch(importNotificationProvider);
    // Checks for new releases of followed artists (starts once settled).
    ref.watch(releaseCheckControllerProvider);
    // Completes the library in the background (starts once settled).
    ref.watch(enrichCompleterStartProvider);
    // Corrects once the lengths of mp3 files read wrong before (starts once settled).
    ref.watch(mp3LengthFixStartProvider);
    // A new version, at most once a day and only if the user asked for it.
    ref.listen(updateOnStartProvider, (_, next) {
      final info = next.value;
      if (info == null) return;
      _messengerKey.currentState?.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Builder(builder: (c) => Text(c.l10n.updateAvailable(info.version))),
      ));
    });
    ref.listen(promoteErrorsProvider, (_, next) {
      final e = next.value;
      if (e != null) {
        _messengerKey.currentState?.showSnackBar(SnackBar(
          content: Builder(builder: (c) => Text(e.noSpace ? c.l10n.promoteNoSpace : c.l10n.promoteFailed)),
        ));
      }
    });
    ref.listen(jamOnlineFailuresProvider, (_, next) {
      final r = next.value;
      if (r != null) {
        _messengerKey.currentState?.showSnackBar(SnackBar(
          content: Builder(builder: (c) => Text(c.l10n.jamOnlineFailed(r.title))),
        ));
      }
    });
    final s = ref.watch(settingsProvider);
    final themeColors = ref.watch(themeColorsProvider);
    final themeBackground = ref.watch(themeBackgroundProvider);
    ref.read(audioHandlerProvider)
      ..recordHistory = s.recordHistory
      ..setNormalize(s.normalizeVolume)
      ..setSpeed(s.playbackSpeed)
      ..setTransition(
        s.transition,
        plainInAlbum: s.crossfadePlainInAlbum,
        crossfadeSeconds: s.crossfadeSeconds,
      );
    return MaterialApp(
      title: 'Codecore',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildThemeFromColors(
        themeColors,
        s.compactMode,
        pageBackdrop: themeBackground.isCustom,
      ),
      locale: Locale(s.language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        // App setting OR system flag; system text scale times the app one, capped at 2.0 (D-31).
        data: MediaQuery.of(context).copyWith(
          disableAnimations: s.reducedMotion || MediaQuery.disableAnimationsOf(context),
          textScaler: AppTextScaler(MediaQuery.textScalerOf(context), s.fontScale)
              .clamp(maxScaleFactor: 2.0),
        ),
        child: AppBackground(
          colors: themeColors,
          background: themeBackground,
          child: UserActivityScope(child: child ?? const SizedBox.shrink()),
        ),
      ),
      home: const AppIconSync(child: OnboardingGate(child: AppShell())),
    );
  }
}

/// System scaler (kept, so non-linear Android scaling survives) times the app setting.
/// Value equality matters: an unequal scaler on every rebuild makes MediaQuery
/// relayout every Text in the app.
@visibleForTesting
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.base, this.app);

  final TextScaler base;
  final double app;

  @override
  double scale(double fontSize) => base.scale(fontSize) * app;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.base == base && other.app == app;

  @override
  int get hashCode => Object.hash(base, app);
}
