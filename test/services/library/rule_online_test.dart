import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/library/rules/rule_online.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _r = YtResult(
  id: 'x',
  title: 'Time',
  channel: 'chan',
  duration: Duration(seconds: 200),
  artists: ['Pink Floyd', 'Café Tacvba'],
  album: 'The Dark Side',
);

bool m(String rules, [YtResult r = _r]) => onlineMatches(parseRules(rules).expr, r);

void main() {
  test('artist and album: contains, case and accents ignored', () {
    expect(m('artista:"PINK"'), isTrue);
    expect(m('artista:cafe'), isTrue);
    expect(m('artista:queen'), isFalse);
    expect(m('artistaalbum:floyd'), isTrue);
    expect(m('album:dark'), isTrue);
    expect(m('album:wall'), isFalse);
  });

  test('a list holds the whole value, not a part', () {
    expect(m('artista:"pink floyd","x"'), isTrue);
    expect(m('artista:"pink",'), isFalse);
  });

  test('duration in seconds', () {
    expect(m('durata>3m'), isTrue);
    expect(m('durata>4m'), isFalse);
    expect(m('durata:3m..4m'), isTrue);
    expect(m('durata<=200s'), isTrue);
  });

  test('exclusion applies to checkable fields', () {
    expect(m('-artista:queen'), isTrue);
    expect(m('-artista:pink'), isFalse);
  });

  test('unverifiable and library-only fields count as satisfied, also under -', () {
    for (final q in ['genere:rock', 'anno:1973', 'ascolti>5', 'preferiti', 'cartella:x', 'tag:a', 'bpm>100']) {
      expect(m(q), isTrue, reason: q);
      expect(m('-$q'), isTrue, reason: '-$q');
    }
  });

  test('all and any with ignored rules', () {
    expect(m('artista:pink genere:rock'), isTrue);
    expect(m('artista:queen genere:rock'), isFalse);
    expect(m('artista:queen OR genere:rock'), isTrue);
    expect(m('artista:queen OR album:wall'), isFalse);
  });

  test('a result without credits uses the channel; no length means not checked', () {
    const bare = YtResult(id: 'y', title: 't', channel: 'Muse', duration: null);
    expect(m('artista:muse', bare), isTrue);
    expect(m('durata>10m', bare), isTrue);
    expect(m('album:x', bare), isTrue);
    expect(m('-album:x', bare), isTrue);
    expect(m('-durata>10m', bare), isTrue);
    const topic = YtResult(id: 'z', title: 't', channel: 'Pink Floyd - Topic', duration: null);
    expect(m('artista:"pink floyd",', topic), isTrue);
  });

  test('Not over And is not read as ignored', () {
    expect(onlineMatches(RuleNot(RuleAnd([parseRules('artista:pink').expr])), _r), isFalse);
    expect(onlineMatches(RuleNot(RuleAnd([parseRules('genere:rock').expr])), _r), isTrue);
  });

  test('free text: title, artist, album', () {
    expect(m('time'), isTrue);
    expect(m('floyd'), isTrue);
    expect(m('nothing'), isFalse);
  });
}
