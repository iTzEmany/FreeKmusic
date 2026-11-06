import '../../widgets/cc_sheet.dart';
import '../../theme/tokens.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../settings/shuffle_plus_tiles.dart';
import 'suggestions_screen.dart';

/// Long press on the shuffle button: the Shuffle+ settings and its state.
Future<void> showShufflePlusSheet(BuildContext context) => showCcSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(CcDims.gap16, CcDims.gap8, CcDims.gap16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(sheet.l10n.shufflePlusTitle, style: Theme.of(sheet).textTheme.titleMedium),
                ),
              ),
              const ShufflePlusTiles(),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(sheet.l10n.suggestionsRecentTitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheet).pop();
                  unawaited(openSuggestions(context));
                },
              ),
            ],
          ),
        ),
      ),
    );
