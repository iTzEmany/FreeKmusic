import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/permission_providers.dart';
import '../../theme/tokens.dart';

/// «Permesso audio mancante» with «Concedi»; nothing while the permission is there.
class AudioPermissionBanner extends ConsumerWidget {
  const AudioPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(audioPermissionProvider)) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap4, CcDims.margin, CcDims.gap8),
      child: Container(
        padding: const EdgeInsets.all(CcDims.gap12),
        decoration: BoxDecoration(
          color: cc.surface1,
          borderRadius: BorderRadius.circular(CcDims.rCard),
          border: Border.all(color: cc.error),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cc.error),
            const SizedBox(width: 12),
            Expanded(child: Text(l.audioPermissionBanner, style: Theme.of(context).textTheme.bodyMedium)),
            TextButton(
              onPressed: ref.read(audioPermissionProvider.notifier).grant,
              child: Text(l.grantPermission),
            ),
          ],
        ),
      ),
    );
  }
}
