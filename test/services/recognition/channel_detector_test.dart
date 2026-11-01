import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/recognition/channel_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final data = jsonDecode(File('test/fixtures/recognition/channels.json').readAsStringSync()) as Map;
  final channels = (data['channels'] as List).cast<String>();
  final real = (data['real'] as List).cast<String>();

  test('every channel of Test.zip makes the tags dubious', () {
    expect(channels, hasLength(36));
    expect([for (final c in channels) if (!tagsDubious(track('Song', c))) c], isEmpty);
  });

  test('no real artist is dubious (K-RB-07)', () {
    expect([for (final a in real) if (tagsDubious(track('Song', a))) a], isEmpty);
  });

  test('an empty artist is dubious', () {
    expect(tagsDubious(track('Song', null)), isTrue);
    expect(tagsDubious(track('Song', '  ')), isTrue);
  });

  test('«A - B» in the title with another artist in the tags is dubious', () {
    expect(tagsDubious(track('Adele - Skyfall', 'Someone Else')), isTrue);
    expect(tagsDubious(track('Adele - Skyfall', 'Adele')), isFalse);
    expect(tagsDubious(track('Believer - Live', 'Imagine Dragons')), isFalse);
  });

  test('a channel word needs something before it; «The» does not count', () {
    expect(tagsDubious(track('Song', 'Atlantic Records')), isTrue);
    expect(tagsDubious(track('Song', 'Sony Music')), isTrue);
    expect(tagsDubious(track('Song', 'The Music')), isFalse);
    expect(tagsDubious(track('Song', 'Lyrics Born')), isFalse);
  });
}
