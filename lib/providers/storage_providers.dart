import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage_volumes.dart';

/// App folders of the SD cards in the device (empty without one, D-579).
final sdVolumesProvider = FutureProvider.autoDispose<List<String>>((ref) => sdVolumeDirs());
