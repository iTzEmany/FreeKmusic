import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/theme_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/color_picker.dart';
import '../../widgets/confirm.dart';
import 'theme_background_editor.dart';
import 'theme_labels.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

/// The tokens a simple theme asks for; the rest follow from them.
const _simpleTokens = [CcToken.bg, CcToken.accent, CcToken.text];

/// One pair of colours that has to be readable together.
class ContrastCheck {
  const ContrastCheck(this.label, this.fg, this.bg, this.min, this.fix);

  final String label;
  final Color fg, bg;
  final double min;

  /// The token to move so the pair reads, and the value it should take.
  final (CcToken, Color) Function() fix;

  double get ratio => contrastRatio(fg, bg);
  bool get ok => ratio >= min;
}

List<ContrastCheck> contrastChecks(AppLocalizations l, CcColors c) => [
  ContrastCheck(l.contrastTextBg, c.text, c.bg, 4.5,
      () => (CcToken.text, ensureContrast(c.text, c.bg))),
  ContrastCheck(l.contrastMutedSurface, c.textMuted, c.surface1, 4.5,
      () => (CcToken.textMuted, ensureContrast(c.textMuted, c.surface1))),
  ContrastCheck(l.contrastOnAccent, c.onAccent, c.accent, 4.5,
      () => (CcToken.onAccent, ensureContrast(c.onAccent, c.accent))),
  ContrastCheck(l.contrastAccentBg, c.accent, c.bg, 3,
      () => (CcToken.accent, ensureContrast(c.accent, c.bg, min: 3))),
];

/// Makes or changes one of the user's themes. Nothing is applied until «Salva».
class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({super.key, required this.initial});

  final CustomTheme initial;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  late CustomTheme _t = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  bool _advanced = false;
  bool _saved = false;
  CcToken? _open;
  final _recent = <Color>[];

  bool get _dirty => _t.copyWith(name: _name.text.trim()) != widget.initial;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(CustomTheme next) => setState(() => _t = next);

  void _pick(CcToken token, Color c) => _set(_t.withColor(token, c));

  /// The colour of the row being closed becomes one of the «recent» ones (not
  /// every step of a drag or of typing a code).
  void _commitOpen() {
    final t = _open;
    final c = t == null ? null : _t.overrides[t];
    if (c == null) return;
    _recent
      ..remove(c)
      ..insert(0, c);
    if (_recent.length > 8) _recent.removeLast();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l = context.l10n;
    return showConfirm(
      context,
      title: l.themeDiscardTitle,
      body: l.themeDiscardBody,
      confirmLabel: l.themeDiscard,
      destructive: true,
    );
  }

  void _save() {
    final l = context.l10n;
    _commitOpen();
    final name = _name.text.trim();
    final theme = _t.copyWith(name: name.isEmpty ? l.themeEditorTitle : name);
    final ok = ref.read(customThemesProvider.notifier).put(theme);
    if (!ok) {
      showMsg(context, l.themeLimit);
      return;
    }
    _saved = true;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(theme: customThemeSettingValue(theme.id)));
    showMsg(context, l.themeSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = _t.resolve();
    final tokens = _advanced ? CcToken.values : _simpleTokens;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: CcAppBar(
          title: l.themeEditorTitle,
          actions: [
            TextButton(onPressed: _save, child: Text(l.themeSave)),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap32),
              children: [
                TextField(
                  controller: _name,
                  maxLength: 40,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l.themeName),
                ),
                const SizedBox(height: 8),
                Text(l.themePreview, style: text.titleSmall),
                const SizedBox(height: 8),
                ThemePreview(colors: colors, background: _t.background),
                const SizedBox(height: 16),
                Text(l.themeBase, style: text.titleSmall),
                const SizedBox(height: 8),
                SegmentedBlocks<AppThemeId>(
                  items: [
                    BlockItem(value: AppThemeId.notte, icon: Icons.dark_mode_outlined, label: l.themeNotte),
                    BlockItem(value: AppThemeId.oled, icon: Icons.contrast, label: l.themeOled),
                    BlockItem(value: AppThemeId.chiaro, icon: Icons.light_mode_outlined, label: l.themeChiaro),
                  ],
                  selected: _t.base,
                  onChanged: (v) => _set(_t.copyWith(base: v)),
                ),
                const SizedBox(height: 16),
                SegmentedBlocks<bool>(
                  items: [
                    BlockItem(value: false, icon: Icons.palette_outlined, label: l.themeModeSimple),
                    BlockItem(value: true, icon: Icons.tune, label: l.themeModeAdvanced),
                  ],
                  selected: _advanced,
                  onChanged: (v) => setState(() {
                    _commitOpen();
                    _advanced = v;
                    _open = null;
                  }),
                ),
                const SizedBox(height: 8),
                for (final t in tokens)
                  _TokenRow(
                    key: ValueKey('token-${t.name}'),
                    label: tokenLabel(l, t),
                    color: tokenColor(colors, t),
                    set: _t.overrides.containsKey(t),
                    open: _open == t,
                    recent: _recent,
                    onToggle: () => setState(() {
                      _commitOpen();
                      _open = _open == t ? null : t;
                    }),
                    onChanged: (c) => _pick(t, c),
                    onReset: () => _set(_t.withoutColor(t)),
                  ),
                const SizedBox(height: 16),
                _ContrastSection(
                  colors: colors,
                  onFix: (token, color) => _set(_t.withColor(token, color)),
                ),
                const SizedBox(height: 16),
                const _BlurredChromeRow(),
                const SizedBox(height: 16),
                ThemeBackgroundEditor(
                  themeId: _t.id,
                  colors: colors,
                  background: _t.background,
                  recent: _recent,
                  onChanged: (b) => _set(_t.copyWith(background: b)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContrastSection extends StatelessWidget {
  const _ContrastSection({required this.colors, required this.onFix});

  final CcColors colors;
  final void Function(CcToken token, Color color) onFix;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final checks = contrastChecks(l, colors);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.themeContrastTitle, style: text.titleSmall),
        if (hasLowContrastText(colors))
          Padding(
            padding: const EdgeInsets.only(top: CcDims.gap4),
            child: Text(l.themeLowContrastWarning,
                key: const ValueKey('low-contrast-warning'),
                style: text.bodySmall?.copyWith(color: cc.error)),
          ),
        for (final c in checks)
          ListTile(
            key: ValueKey('contrast-${c.label}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              c.ok ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              color: c.ok ? cc.accentSoft : cc.error,
            ),
            title: Text(c.label),
            subtitle: Text(
              '${c.ratio.toStringAsFixed(1)}:1, ${c.ok ? l.themeContrastOk : l.themeContrastLow}',
            ),
            trailing: c.ok
                ? null
                : TextButton(
                    onPressed: () {
                      final (token, color) = c.fix();
                      onFix(token, color);
                    },
                    child: Text(l.themeFix),
                  ),
          ),
      ],
    );
  }
}

/// A colour of the theme: its swatch and code; a tap opens the picker below.
class _TokenRow extends StatelessWidget {
  const _TokenRow({
    super.key,
    required this.label,
    required this.color,
    required this.set,
    required this.open,
    required this.recent,
    required this.onToggle,
    required this.onChanged,
    required this.onReset,
  });

  final String label;
  final Color color;
  final bool set, open;
  final List<Color> recent;
  final VoidCallback onToggle, onReset;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onToggle,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: cc.textFaint),
            ),
          ),
          title: Text(label),
          subtitle: Text(colorToHex(color)),
          trailing: set
              ? IconButton(
                  tooltip: l.themeResetColor,
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: onReset,
                )
              : Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        ),
        // Instant open/close: no per-row layout animation.
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: CcDims.gap12),
            child: CcColorPicker(
              color: color,
              onChanged: onChanged,
              recent: recent,
              labels: pickerLabels(l),
            ),
          ),
      ],
    );
  }
}

/// A few real widgets in the theme being made, so the colours can be judged
/// together before they are saved.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.colors, required this.background});

  final CcColors colors;
  final ThemeBackground background;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = buildThemeFromColors(colors, false);
    return Theme(
      data: data,
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return ClipRRect(
            borderRadius: BorderRadius.circular(CcDims.rCard),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bg,
                gradient: themeGradient(colors, background),
                border: Border.all(color: colors.surface3),
                borderRadius: BorderRadius.circular(CcDims.rCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(CcDims.gap12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.tokenText, style: text.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.surface3,
                            borderRadius: BorderRadius.circular(CcDims.rList),
                          ),
                          child: Icon(Icons.music_note_rounded, color: colors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.tokenText, style: text.bodyLarge),
                              Text(l.tokenTextMuted, style: text.bodyMedium),
                              Text(l.tokenTextFaint,
                                  style: text.bodySmall?.copyWith(color: colors.textFaint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: CcDims.gap12, vertical: CcDims.gap8),
                      decoration: BoxDecoration(
                        color: colors.surface1,
                        borderRadius: BorderRadius.circular(CcDims.rCard),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(l.tokenSurface1, style: text.bodyMedium)),
                          Switch(value: true, onChanged: (_) {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: CcDims.gap12, vertical: CcDims.gap8),
                      decoration: BoxDecoration(
                        color: colors.surface2,
                        borderRadius: BorderRadius.circular(CcDims.rCard),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(l.tokenSurface2, style: text.bodyMedium)),
                          Text(l.tokenError, style: TextStyle(color: colors.error)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(onPressed: () {}, child: Text(l.tokenOnAccent)),
                        OutlinedButton(onPressed: () {}, child: Text(l.tokenAccent)),
                        Chip(
                          label: Text(l.tokenAccentSoft),
                          backgroundColor: colors.surface3,
                          labelStyle: TextStyle(color: colors.accentSoft),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// App-wide switch (not part of the theme draft): it applies at once.
class _BlurredChromeRow extends ConsumerWidget {
  const _BlurredChromeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(settingsProvider.select((s) => s.blurredChrome));
    return SwitchListTile(
      key: const ValueKey('blurred-chrome'),
      contentPadding: EdgeInsets.zero,
      title: Text(l.blurredChrome),
      subtitle: Text(l.blurredChromeHint),
      value: on,
      onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(blurredChrome: v)),
    );
  }
}
