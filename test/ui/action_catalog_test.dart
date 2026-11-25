import 'package:codecore/ui/widgets/action_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every catalog action has its own icon', () {
    final icons = CatalogAction.values.map((a) => a.icon).toSet();
    expect(icons.length, CatalogAction.values.length);
  });
}
