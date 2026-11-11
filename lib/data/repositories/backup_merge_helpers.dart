import 'package:path/path.dart' as p;

/// An automatic cover [key] whose file is present: [exists] answers for a file name.
bool hasCoverFile(String key, bool Function(String fileName) exists) =>
    key == p.basename(key) && ['jpg', 'png', 'webp'].any((e) => exists('$key.$e'));

/// Same item, or a copy an earlier merge made of it: «name (ripristinata N)».
bool isRestoredCopyOf(String name, String base) =>
    name == base || name.startsWith('$base (ripristinata');

/// [base], or «base (ripristinata)» / «base (ripristinata N)» when [taken] has it.
String restoredName(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  var name = '$base (ripristinata)';
  for (var n = 2; taken.contains(name); n++) {
    name = '$base (ripristinata $n)';
  }
  return name;
}

/// The file name of zip entry [name] under [prefix] (`covers/`), or null when it
/// is not a plain file name there (`covers/..`, `covers/a/b`): nothing leaves the folder.
String? zipLeaf(String name, String prefix) {
  if (!name.startsWith(prefix)) return null;
  final leaf = name.substring(prefix.length);
  return leaf.isEmpty || leaf == '.' || leaf == '..' || p.basename(leaf) != leaf ? null : leaf;
}
