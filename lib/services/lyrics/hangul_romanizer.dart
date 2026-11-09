// Revised Romanization of Korean with the common pronunciation rules.
// shortcut: no tensification or word-boundary rules (not reflected in the
// revised system either); upgrade only if a real lyric needs it.

const _onsets = [
  'g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '', 'j', 'jj',
  'ch', 'k', 't', 'p', 'h', //
];
const _vowels = [
  'a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae', 'oe',
  'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i', //
];

// Final (index 0-27) as pronounced before a consonant or at the end.
const _codas = [
  '', 'k', 'k', 'k', 'n', 'n', 'n', 't', 'l', 'k', 'm', 'l', 'l', 'l', 'p',
  'l', 'm', 'p', 'p', 't', 't', 'ng', 't', 't', 'k', 't', 'p', 't', //
];

// Final before an ㅇ initial: (final left behind, sound carried over).
const _liaison = <int, (String, String)>{
  1: ('', 'g'), 2: ('', 'kk'), 3: ('k', 's'), 4: ('', 'n'), 5: ('n', 'j'),
  6: ('', 'n'), 7: ('', 'd'), 8: ('', 'r'), 9: ('l', 'g'), 10: ('l', 'm'),
  11: ('l', 'b'), 12: ('l', 's'), 13: ('l', 't'), 14: ('l', 'p'),
  15: ('', 'r'), 16: ('', 'm'), 17: ('', 'b'), 18: ('p', 's'), 19: ('', 's'),
  20: ('', 'ss'), 22: ('', 'j'), 23: ('', 'ch'), 24: ('', 'k'),
  25: ('', 't'), 26: ('', 'p'), 27: ('', ''), //
};

const _ieung = 11, _nieun = 2, _mieum = 6, _rieul = 5, _hieut = 18;
const _vowelI = 20;
const _nasal = {'k': 'ng', 't': 'n', 'p': 'm'};

class _Syl {
  _Syl(int code)
    : initial = (code - 0xAC00) ~/ 588,
      vowel = (code - 0xAC00) % 588 ~/ 28,
      fin = (code - 0xAC00) % 28 {
    onset = _onsets[initial];
    coda = _codas[fin];
  }
  final int initial, vowel, fin;
  late String onset, coda;

  @override
  String toString() => '$onset${_vowels[vowel]}$coda';
}

bool _isSyllable(int c) => c >= 0xAC00 && c <= 0xD7A3;

// Adjusts the boundary between two adjacent syllables.
void _link(_Syl a, _Syl b) {
  if (a.fin == 0) {
    return;
  }
  if (b.initial == _ieung) {
    if (a.fin == 21) {
      return;
    }
    final (left, moved) = _liaison[a.fin]!;
    a.coda = left;
    // ㄷ/ㅌ before 이 palatalize.
    b.onset = b.vowel == _vowelI && (a.fin == 7 || a.fin == 25)
        ? (a.fin == 7 ? 'j' : 'ch')
        : moved;
    return;
  }
  // ㅎ (alone or in ㄶ/ㅀ) aspirates a following ㄱ/ㄷ/ㅈ.
  if ((a.fin == 27 || a.fin == 6 || a.fin == 15) &&
      const {0: 'k', 3: 't', 12: 'ch'}.containsKey(b.initial)) {
    a.coda = a.fin == 27 ? '' : (a.fin == 6 ? 'n' : 'l');
    b.onset = const {0: 'k', 3: 't', 12: 'ch'}[b.initial]!;
    return;
  }
  // k/t/p + ㅎ aspirate the ㅎ.
  if (b.initial == _hieut && _nasal.containsKey(a.coda)) {
    b.onset = a.coda;
    a.coda = '';
    return;
  }
  if (b.initial == _rieul) {
    switch (a.coda) {
      case 'n' || 'l':
        a.coda = 'l';
        b.onset = 'l';
      case 'm' || 'ng':
        b.onset = 'n';
      case 'k' || 'p' || 't':
        a.coda = _nasal[a.coda]!;
        b.onset = 'n';
    }
    return;
  }
  if (b.initial == _nieun && a.coda == 'l') {
    b.onset = 'l';
  } else if ((b.initial == _nieun || b.initial == _mieum) &&
      _nasal.containsKey(a.coda)) {
    a.coda = _nasal[a.coda]!;
  }
}

/// Romanizes the hangul of [line]; any other character is kept as is.
String romanizeHangul(String line) {
  final out = StringBuffer();
  final run = <_Syl>[];
  void flush() {
    for (var i = 1; i < run.length; i++) {
      _link(run[i - 1], run[i]);
    }
    run.forEach(out.write);
    run.clear();
  }

  for (final c in line.runes) {
    if (_isSyllable(c)) {
      run.add(_Syl(c));
    } else {
      flush();
      out.writeCharCode(c);
    }
  }
  flush();
  return out.toString();
}
