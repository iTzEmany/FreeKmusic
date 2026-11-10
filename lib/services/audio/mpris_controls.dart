import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dbus/dbus.dart';

import '../../core/app_log.dart';
import 'codecore_audio_handler.dart';
import 'mpris_mapping.dart';
import 'play_queue.dart';
import 'system_media_controls.dart';

const _root = 'org.mpris.MediaPlayer2';
const _player = 'org.mpris.MediaPlayer2.Player';

/// MPRIS on the session bus: `playerctl`, GNOME's media widget and the media
/// keys. Mirrors the handler's `mediaItem` / `playbackState` and sends the
/// commands back to it.
class MprisControls implements SystemMediaControls {
  DBusClient? _client;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Future<void> attach(CodecoreAudioHandler handler) async {
    try {
      final client = DBusClient.session();
      final obj = _Object(handler);
      await client.registerObject(obj);
      await client.requestName('org.mpris.MediaPlayer2.freekmusic');
      _client = client;
      _subs
        ..add(handler.mediaItem.listen(obj.onMediaItem))
        ..add(handler.playbackState.listen(obj.onPlaybackState))
        ..add(handler.positionStream.listen(obj.onPosition))
        ..add(handler.volumeStream.listen(obj.onVolume));
      AppLog.i('mpris: on the session bus');
    } on Object catch (e, st) {
      // No session bus (a container, SSH): the app runs without system controls.
      AppLog.w('mpris unavailable', e, st);
      await dispose();
    }
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _client?.close();
    _client = null;
  }
}

class _Object extends DBusObject {
  _Object(this._h) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final CodecoreAudioHandler _h;
  MediaItem? _item;
  bool _playing = false;
  bool _hasTrack = false;
  Duration _position = Duration.zero;
  double _rate = 1;
  bool _shuffle = false;
  String _loop = 'None';

  Map<String, DBusValue> get _metadata => mprisMetadata(
        mediaId: _item?.id,
        title: _item?.title,
        artist: _item?.artist,
        album: _item?.album,
        duration: _item?.duration,
        artUri: _item?.artUri,
      );

  String get _status => mprisStatus(hasTrack: _hasTrack, playing: _playing);

  void onMediaItem(MediaItem? item) {
    _item = item;
    _hasTrack = item != null;
    unawaited(emitPropertiesChanged(_player, changedProperties: {
      'Metadata': DBusDict.stringVariant(_metadata),
      'PlaybackStatus': DBusString(_status),
    }));
  }

  void onPlaybackState(PlaybackState s) {
    final changed = s.playing != _playing || s.speed != _rate;
    _playing = s.playing;
    _rate = s.speed;
    if (changed) {
      unawaited(emitPropertiesChanged(_player, changedProperties: {
        'PlaybackStatus': DBusString(_status),
        'Rate': DBusDouble(_rate),
      }));
    }
    final shuffle = s.shuffleMode != AudioServiceShuffleMode.none;
    final loop = mprisLoopStatus(_h.repeatMode);
    if (shuffle != _shuffle || loop != _loop) {
      _shuffle = shuffle;
      _loop = loop;
      unawaited(emitPropertiesChanged(_player, changedProperties: {
        'Shuffle': DBusBoolean(_shuffle),
        'LoopStatus': DBusString(_loop),
      }));
    }
  }

  void onVolume(double v) {
    unawaited(emitPropertiesChanged(_player, changedProperties: {
      'Volume': DBusDouble(v),
    }));
  }

  void onPosition(Duration p) {
    final jumped = (p - _position).abs() > const Duration(seconds: 2);
    _position = p;
    if (jumped) unawaited(emitSignal(_player, 'Seeked', [DBusInt64(p.inMicroseconds)]));
  }

  @override
  List<DBusIntrospectInterface> introspect() => [
        DBusIntrospectInterface(_root, methods: [
          DBusIntrospectMethod('Raise'),
          DBusIntrospectMethod('Quit'),
        ], properties: [
          for (final (n, t) in [
            ('CanQuit', 'b'), ('CanRaise', 'b'), ('HasTrackList', 'b'),
            ('Identity', 's'), ('DesktopEntry', 's'),
          ])
            DBusIntrospectProperty(n, DBusSignature(t), access: DBusPropertyAccess.read),
        ]),
        DBusIntrospectInterface(_player, methods: [
          for (final m in ['Next', 'Previous', 'Pause', 'PlayPause', 'Stop', 'Play']) DBusIntrospectMethod(m),
          DBusIntrospectMethod('Seek', args: [DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Offset')]),
          DBusIntrospectMethod('SetPosition', args: [
            DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_, name: 'TrackId'),
            DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Position'),
          ]),
        ], signals: [
          DBusIntrospectSignal('Seeked', args: [DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.out, name: 'Position')]),
        ], properties: [
          for (final (n, t) in [
            ('PlaybackStatus', 's'), ('Metadata', 'a{sv}'), ('Position', 'x'), ('Rate', 'd'),
            ('MinimumRate', 'd'), ('MaximumRate', 'd'),
            ('CanGoNext', 'b'), ('CanGoPrevious', 'b'), ('CanPlay', 'b'), ('CanPause', 'b'),
            ('CanSeek', 'b'), ('CanControl', 'b'),
          ])
            DBusIntrospectProperty(n, DBusSignature(t), access: DBusPropertyAccess.read),
          for (final (n, t) in [('Volume', 'd'), ('Shuffle', 'b'), ('LoopStatus', 's')])
            DBusIntrospectProperty(n, DBusSignature(t), access: DBusPropertyAccess.readwrite),
        ]),
      ];

  DBusValue? _value(String interface, String name) {
    if (interface == _root) {
      return switch (name) {
        'CanQuit' => const DBusBoolean(false),
        'CanRaise' => const DBusBoolean(false),
        'HasTrackList' => const DBusBoolean(false),
        'Identity' => const DBusString('FreeKmusic'),
        'DesktopEntry' => const DBusString('freekmusic'),
        _ => null,
      };
    }
    if (interface == _player) {
      return switch (name) {
        'PlaybackStatus' => DBusString(_status),
        'Metadata' => DBusDict.stringVariant(_metadata),
        'Position' => DBusInt64(_position.inMicroseconds),
        'Rate' => DBusDouble(_rate),
        'MinimumRate' => const DBusDouble(0.5),
        'MaximumRate' => const DBusDouble(2),
        'Volume' => DBusDouble(_h.volume),
        'Shuffle' => DBusBoolean(_h.shuffleEnabled),
        'LoopStatus' => DBusString(mprisLoopStatus(_h.repeatMode)),
        'CanGoNext' => DBusBoolean(_hasTrack && _h.hasNext),
        'CanGoPrevious' || 'CanPlay' || 'CanPause' || 'CanSeek' => DBusBoolean(_hasTrack),
        'CanControl' => const DBusBoolean(true),
        _ => null,
      };
    }
    return null;
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final v = _value(interface, name);
    return v == null ? DBusMethodErrorResponse.unknownProperty() : DBusGetPropertyResponse(v);
  }

  @override
  Future<DBusMethodResponse> setProperty(String interface, String name, DBusValue value) async {
    if (interface != _player) return DBusMethodErrorResponse.unknownProperty();
    switch ((name, value)) {
      case ('Volume', DBusDouble(:final value)):
        _h.requestVolume(value.isNaN ? 0 : value.clamp(0.0, 1.0));
      case ('Shuffle', DBusBoolean(:final value)):
        await _h.setShuffleMode(value ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
      case ('LoopStatus', DBusString(:final value)):
        final r = mprisRepeatFromLoop(value);
        if (r == null) return DBusMethodErrorResponse.invalidArgs();
        await _h.setRepeatMode(switch (r) {
          PlayRepeat.off => AudioServiceRepeatMode.none,
          PlayRepeat.one => AudioServiceRepeatMode.one,
          PlayRepeat.all => AudioServiceRepeatMode.all,
        });
      case ('Volume' || 'Shuffle' || 'LoopStatus', _):
        return DBusMethodErrorResponse.invalidArgs();
      default:
        return DBusMethodErrorResponse.propertyReadOnly();
    }
    return DBusMethodSuccessResponse();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    const names = {
      _root: ['CanQuit', 'CanRaise', 'HasTrackList', 'Identity', 'DesktopEntry'],
      _player: [
        'PlaybackStatus', 'Metadata', 'Position', 'Rate', 'MinimumRate', 'MaximumRate', 'Volume', 'Shuffle', 'LoopStatus',
        'CanGoNext', 'CanGoPrevious', 'CanPlay', 'CanPause', 'CanSeek', 'CanControl',
      ],
    };
    return DBusGetAllPropertiesResponse({
      for (final n in names[interface] ?? const <String>[]) n: _value(interface, n)!,
    });
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == _root) {
      return call.name == 'Raise' || call.name == 'Quit'
          ? DBusMethodSuccessResponse()
          : DBusMethodErrorResponse.unknownMethod();
    }
    if (call.interface != _player) return DBusMethodErrorResponse.unknownInterface();
    switch (call.name) {
      case 'Play':
        await _h.play();
      case 'Pause':
        await _h.pause();
      case 'PlayPause':
        await _h.togglePlayPause();
      case 'Stop':
        await _h.stop();
      case 'Next':
        await _h.skipToNext();
      case 'Previous':
        await _h.skipToPrevious();
      case 'Seek':
        final t = mprisSeekTarget(
            current: _position, length: _item?.duration, offsetMicros: (call.values[0] as DBusInt64).value);
        if (t != null) await _h.seek(t);
      case 'SetPosition':
        final t = mprisSeekTarget(
          current: _position,
          length: _item?.duration,
          trackId: call.values[0] as DBusObjectPath,
          positionMicros: (call.values[1] as DBusInt64).value,
          currentTrackId: _item == null ? null : mprisTrackId(_item!.id),
        );
        if (t != null) await _h.seek(t);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }
}
