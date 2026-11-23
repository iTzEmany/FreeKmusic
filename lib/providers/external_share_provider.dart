import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/share/external_share.dart';

final externalShareProvider = Provider<ExternalShare>(
  (ref) => const SharePlusExternalShare(),
);
