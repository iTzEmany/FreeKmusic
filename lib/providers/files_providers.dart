import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/files/folder_opener.dart';

final folderOpenerProvider = Provider<FolderOpener>((ref) => FolderOpener());
