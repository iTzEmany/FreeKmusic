import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform.dart' show isDesktop;
import 'l10n/app_localizations.dart';
import 'providers/database_providers.dart' show folderRepositoryProvider;
import 'providers/equalizer_providers.dart';
import 'providers/karaoke_providers.dart';
import 'providers/folder_actions.dart' show ensureDefaultFolder, scanWithPermission;
import 'providers/jam_providers.dart' show jamOnlineFailuresProvider;
import 'providers/open_files_providers.dart';
import 'providers/player_providers.dart';
import 'providers/volume_zero_pause_provider.dart';
import 'providers/podcast_providers.dart' show podcastOrphansStartProvider;
import 'providers/settings_providers.dart';
import 'providers/share_hub.dart';
import 'providers/genre_reread_providers.dart';
import 'providers/artist_country_providers.dart';
import 'providers/startup_providers.dart'
    show enrichCompleterStartProvider, mp3LengthFixStartProvider, permissionRescanProvider, autoBackupStartProvider;
import 'providers/stream_providers.dart' show streamEnrichTriggerProvider;
import 'providers/theme_providers.dart';
import 'providers/update_providers.dart';
import 'providers/youtube_providers.dart' show promoteErrorsProvider;
import 'providers/activity_log_providers.dart';
import 'providers/import_notification_providers.dart';
import 'core/app_log.dart';
import 'l10n/l10n_ext.dart';
import 'ui/screens/onboarding/onboarding_gate.dart';
import 'providers/dislike_store_provider.dart' show dislikeStoreProvider;
import 'providers/permission_providers.dart';
import 'providers/releases_providers.dart' show releaseCheckControllerProvider;
import 'ui/screens/settings/update_tiles.dart' show updateSnackBar;
import 'ui/screens/settings/whats_new_page.dart' show showWhatsNew;
import 'ui/shell/app_shell.dart';
import 'ui/shell/drop_overlay.dart';
import 'ui/widgets/app_icon_sync.dart';
import 'ui/widgets/track_actions.dart' show TrackMenuHost;
import 'ui/widgets/user_activity_scope.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart' show CcTiming;
import 'ui/widgets/show_msg.dart' show CcSnackContent;

const _updateSnack = Duration(seconds: 8);

final _messengerKey = GlobalKey<ScaffoldMessengerState>();
final _navigatorKey = GlobalKey<NavigatorState>();

class CodecoreApp extends ConsumerWidget {
  const CodecoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(shareAutoStartProvider);
    // Alive from the start, so the Registro has the real times of what ends.
    ref.listen(activityLogProvider, (_, _) {});
    ref.watch(equalizerApplierProvider);
    ref.watch(karaokeBaseApplierProvider);
    ref.watch(karaokeAutoProvider);
    // Enriches a streamed track as soon as it has its row (D-351).
    ref.listen(streamEnrichTriggerProvider, (_, _) {});
    ref.watch(outputRouteSyncProvider);
    ref.listen(volumeZeroPauseProvider, (_, _) {});
    ref.listen(settingsFlushOnPauseProvider, (_, _) {});
    ref.watch(importNotificationProvider);
    // Checks for new releases of followed artists (starts once settled).
    ref.watch(releaseCheckControllerProvider);
    // Opens dislikes.json and imports the old «disliked» records before any SuggestionLog.clear.
    ref.read(dislikeStoreProvider);
    // Completes the library in the background (starts once settled).
    ref.watch(enrichCompleterStartProvider);
    // Corrects once the lengths of mp3 files read wrong before (starts once settled).
    ref.watch(mp3LengthFixStartProvider);
    ref.watch(permissionRescanProvider);
    ref.listen(audioPermissionProvider, (_, _) {});
    ref.watch(autoBackupStartProvider);
    ref.watch(podcastOrphansStartProvider);
    // Reads the genres of the existing library again, in the background (starts once settled).
    ref.watch(genreRereadStartProvider);
    // Looks up where the library's artists come from, only with the enrichment on (starts once settled).
    ref.watch(artistCountryStartProvider);
    // Empties the folder of downloaded updates (starts once settled).
    ref.watch(updatesCleanupProvider);
    // A new version, at most once a day and only if the user asked for it.
    ref.listen(updateOnStartProvider, (_, next) {
      final info = next.value;
      // Not on top of «Aggiornata alla X»: that start has the page only.
      if (info == null || ref.read(whatsNewOnStartProvider).value != null) return;
      final c = _navigatorKey.currentState?.overlay?.context;
      if (c == null) {
        AppLog.w('no navigator to show the update notice on');
        return;
      }
      _messengerKey.currentState?.showSnackBar(updateSnackBar(c, info, _updateSnack));
    });
    // «Aggiornata alla X», once after an update.
    ref.listen(whatsNewOnStartProvider, (_, next) {
      final info = next.value;
      final c = _navigatorKey.currentState?.overlay?.context;
      if (info != null && c != null && c.mounted) showWhatsNew(c, info);
    });
    ref.listen(promoteErrorsProvider, (_, next) {
      final e = next.value;
      if (e != null) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Builder(
              builder: (c) => CcSnackContent(
                e.noSpace ? c.l10n.promoteNoSpace : c.l10n.promoteFailed,
                CcTiming.msg,
              ),
            ),
          ),
        );
      }
    });
    ref.listen(openOutsideProvider, (_, next) {
      final paths = next.value;
      final c = _navigatorKey.currentState?.overlay?.context;
      if (paths == null || c == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Builder(builder: (c) => CcSnackContent(c.l10n.openOutsideLibrary(paths.length), CcTiming.msg)),
          action: SnackBarAction(
            label: c.l10n.openAddToLibrary,
            onPressed: () => unawaited(ref.read(openFilesProvider).addToLibrary(paths)),
          ),
        ),
      );
    });
    ref.listen(openPortalProvider, (_, next) {
      if (next.value == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Builder(builder: (c) => CcSnackContent(c.l10n.openPortalFile, CcTiming.msg))),
      );
    });
    ref.listen(jamOnlineFailuresProvider, (_, next) {
      final r = next.value;
      if (r != null) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Builder(
              builder: (c) =>
                  CcSnackContent(c.l10n.jamOnlineFailed(r.title), CcTiming.msg),
            ),
          ),
        );
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
      title: 'FreeKmusic',
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      scrollBehavior: const AppScrollBehavior(),
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
          disableAnimations:
              s.reducedMotion || MediaQuery.disableAnimationsOf(context),
          textScaler: AppTextScaler(
            MediaQuery.textScalerOf(context),
            isDesktop ? 1.0 : s.fontScale, // phone-only setting (D-720)
          ).clamp(maxScaleFactor: 2.0),
        ),
        child: AppBackground(
          colors: themeColors,
          background: themeBackground,
          child: UserActivityScope(child: _withDrop(ref, child ?? const SizedBox.shrink())),
        ),
      ),
      home: TrackMenuHost(
        child: AppIconSync(
          child: OnboardingGate(
            ensureFolder: () => ensureDefaultFolder(
              ref.read(folderRepositoryProvider),
              () => scanWithPermission(ref),
            ),
            child: const AppShell(),
          ),
        ),
      ),
    );
  }
}

Widget _withDrop(WidgetRef ref, Widget child) =>
    isDesktop ? DropOverlay(onAudio: ref.read(openFilesProvider).handle, child: child) : child;

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

/// Lets the mouse drag scrollables (horizontal shelves/chips on desktop).
/// Shift+wheel already scrolls horizontally in Flutter; a plain wheel is left
/// alone so it keeps scrolling the vertical page under a shelf.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}
