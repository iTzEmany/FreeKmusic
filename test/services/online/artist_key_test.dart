import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/core/artist_key.dart';

// Callers pass null as `artist ?? ''`; the signature takes a non-null String.
String key(String? x) => artistKey(x);

void main() {
  const cases = <String?, String>{
    'Queen feat. David Bowie': 'queen',
    'Simon & Garfunkel': 'simon',
    'Queen & David Bowie': 'queen',
    'QUEEN': 'queen',
    'Beyoncé': 'beyonce',
    'Sigur Rós feat. Björk': 'sigur ros',
    'AC/DC': 'ac', // the «/» splits credits
    '  Queen  ': 'queen',
    '': '',
    null: '',
  };
  cases.forEach((input, expected) {
    test(
      'key(${input == null ? 'null' : "'$input'"}) is \'$expected\'',
      () => expect(key(input), expected),
    );
  });
}
