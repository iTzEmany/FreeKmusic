import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/system_volume.dart';

final systemVolumeProvider = Provider<SystemVolume>((ref) => SystemVolume());
