import 'dart:math';

enum PlayRepeat { off, all, one }

/// The queue as it was, to put it back (the undo of «Svuota»).
class QueueState {
  const QueueState._(
    this._items,
    this._keys,
    this._natural,
    this._pos,
    this._history,
    this._user,
    this._currentFromUser,
  );

  final List<int> _items, _keys, _history, _user;
  final List<int>? _natural;
  final int _pos;
  final bool _currentFromUser;

  int? get currentId => _pos < 0 ? null : _items[_pos];
}

/// Pure queue logic. [items] is always the order the tracks will play in:
/// turning shuffle on reorders what follows the current track, so the queue a
/// screen lists is the one «next» walks (headset buttons included). Every entry
/// has a key, so shuffle off can put the natural order back.
class PlayQueue {
  PlayQueue({Random? random}) : _random = random ?? Random();

  static const _maxHistory = 100;

  final Random _random;
  final List<int> _items = [];
  final List<int> _keys = []; // one per item, never reused
  List<int>? _natural; // keys in the order before shuffling; null if unknown
  final List<int> _history = []; // keys, most recent last
  int _serial = 0;
  int _pos = -1;
  // Keys of the entries the user added and that did not play yet, in arrival
  // order. I1: they sit at _pos+1.._pos+userAhead in this order. I2: the
  // current entry is never in it. [_settle] restores both.
  final List<int> _user = [];
  bool _currentFromUser = false;
  bool _shuffle = false;
  PlayRepeat _repeat = PlayRepeat.off;
  int _revision = 0;

  /// The order of the next wrap-around (indices into [items]), fixed in
  /// advance by [peekNext] so that [next] lands on the very track announced.
  List<int>? _pendingOrder;

  PlayRepeat get repeat => _repeat;
  set repeat(PlayRepeat value) {
    if (value == _repeat) return;
    _repeat = value;
    _changed();
  }

  /// Grows with every change to the queue (items, order, position, modes), so
  /// whoever prepared «the next track» knows when to prepare it again.
  int get revision => _revision;

  void _changed() {
    _pendingOrder = null;
    _revision++;
  }

  List<int> get items => List.unmodifiable(_items);
  int get currentIndex => _pos;
  int? get currentId => _pos < 0 ? null : _items[_pos];
  bool get isEmpty => _items.isEmpty;
  bool get shuffle => _shuffle;
  int get userAhead => _user.length;
  bool get currentFromUser => _currentFromUser;

  /// Ids in the order they will be played (the same as [items]).
  List<int> get playOrder => items;

  int _newKey() => _serial++;

  /// Restores I1/I2 after something moved [_pos] or reordered. [arrived]: the
  /// current entry just changed, so it may have come out of the block.
  void _settle({bool arrived = false}) {
    if (_pos < 0) {
      _user.clear();
      return;
    }
    final cur = _keys[_pos];
    final left = _user.remove(cur);
    if (arrived) _currentFromUser = left;
    if (_user.isEmpty) return;
    final id = {for (var i = 0; i < _keys.length; i++) _keys[i]: _items[i]};
    final inBlock = _user.toSet();
    final items = <int>[], keys = <int>[];
    for (final k in _keys) {
      if (inBlock.contains(k)) continue;
      keys.add(k);
      items.add(id[k]!);
      if (k == cur) {
        for (final u in _user) {
          keys.add(u);
          items.add(id[u]!);
        }
      }
    }
    _items
      ..clear()
      ..addAll(items);
    _keys
      ..clear()
      ..addAll(keys);
    _pos = _keys.indexOf(cur);
  }

  set shuffle(bool value) {
    if (value == _shuffle) return;
    _shuffle = value;
    if (_items.isNotEmpty) {
      if (value) {
        _natural = List.of(_keys);
        _applyOrder(_shuffledFrom(_pos));
        _pos = 0;
      } else {
        _restoreNaturalOrder();
      }
      _settle();
    }
    _changed();
  }

  /// Current first, then every other index in random order.
  List<int> _shuffledFrom(int first) {
    final rest = [
      for (var i = 0; i < _items.length; i++)
        if (i != first) i,
    ];
    _shuffleInPlace(rest);
    return [first, ...rest];
  }

  void _restoreNaturalOrder() {
    final natural = _natural;
    _natural = null;
    if (natural == null) return;
    final current = _keys[_pos];
    final at = {for (var i = 0; i < _keys.length; i++) _keys[i]: i};
    final perm = [
      for (final k in natural)
        if (at.containsKey(k)) at.remove(k)!,
      ...at.values, // defensive: keys the natural list does not know
    ];
    _applyOrder(perm);
    _pos = _keys.indexOf(current);
  }

  /// New position `i` takes the entry now at `perm[i]`.
  void _applyOrder(List<int> perm) {
    final items = [for (final i in perm) _items[i]];
    final keys = [for (final i in perm) _keys[i]];
    _items
      ..clear()
      ..addAll(items);
    _keys
      ..clear()
      ..addAll(keys);
  }

  /// [alreadyShuffled]: [trackIds] is an order to play as it is (a restored
  /// session), even with shuffle on.
  void setItems(
    List<int> trackIds, {
    int startIndex = 0,
    bool alreadyShuffled = false,
    bool keepUser = false,
  }) {
    final kept = keepUser
        ? [for (final k in _user) _items[_keys.indexOf(k)]]
        : const <int>[];
    _history.clear();
    _changed();
    _load(
      trackIds,
      trackIds.isEmpty ? 0 : startIndex.clamp(0, trackIds.length - 1),
      shuffleNow: _shuffle && !alreadyShuffled,
    );
    if (_pos < 0) return;
    for (final id in kept) {
      _insertUser(_pos + 1 + _user.length, id);
    }
  }

  /// A new user entry at [at] (it joins the block and the natural order).
  void _insertUser(int at, int id) {
    final key = _newKey();
    _natural?.add(key);
    _items.insert(at, id);
    _keys.insert(at, key);
    _user.add(key);
  }

  void _load(List<int> ids, int start, {required bool shuffleNow}) {
    _items
      ..clear()
      ..addAll(ids);
    _keys
      ..clear()
      ..addAll(List.generate(ids.length, (_) => _newKey()));
    _natural = null;
    _user.clear();
    _currentFromUser = false;
    if (_items.isEmpty) {
      _pos = -1;
      return;
    }
    _pos = start;
    if (shuffleNow) {
      _natural = List.of(_keys);
      _applyOrder(_shuffledFrom(start));
      _pos = 0;
    }
  }

  void _shuffleInPlace(List<int> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// A fresh shuffle of every item for the next lap, never starting with the
  /// track that just played when there is a choice.
  List<int> _newLapOrder() {
    final order = List<int>.generate(_items.length, (i) => i);
    _shuffleInPlace(order);
    if (order.length > 1 && order[0] == _pos) {
      final swap = order[1];
      order[1] = order[0];
      order[0] = swap;
    }
    return order;
  }

  void _pushHistory() {
    _history.add(_keys[_pos]);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  /// Whether [next] would land on a track (not past the end).
  bool get hasNext =>
      _pos >= 0 && (_pos + 1 < _items.length || repeat != PlayRepeat.off);

  /// The id [next] would return with the same [auto], without changing the
  /// queue, the history or the revision. At the end of a shuffled lap with
  /// repeat-all it fixes the next lap's order, so [next] agrees with it.
  int? peekNext({bool auto = true}) {
    if (_pos < 0) return null;
    if (auto && repeat == PlayRepeat.one) return currentId;
    if (_pos + 1 < _items.length) return _items[_pos + 1];
    if (repeat == PlayRepeat.off) return null;
    if (!_shuffle) return _items[0];
    return _items[(_pendingOrder ??= _newLapOrder())[0]];
  }

  /// `auto` is true when a track ended by itself.
  int? next({bool auto = false}) {
    if (_pos < 0) return null;
    if (auto && repeat == PlayRepeat.one) return currentId;
    if (_pos + 1 < _items.length) {
      _pushHistory();
      _pos++;
      _settle(arrived: true);
      _changed();
      return currentId;
    }
    if (repeat == PlayRepeat.off) return null;
    _pushHistory();
    if (_shuffle) _applyOrder(_pendingOrder ?? _newLapOrder());
    _pos = 0;
    _settle(arrived: true);
    _changed();
    return currentId;
  }

  /// Returns the id to play, or null only for an empty queue.
  int? previous() {
    if (_pos < 0) return null;
    _changed();
    if (_history.isNotEmpty) {
      final p = _keys.indexOf(_history.removeLast());
      if (p >= 0) _pos = p;
      _settle(arrived: true);
      return currentId;
    }
    if (_pos > 0) {
      _pos--;
    } else if (repeat == PlayRepeat.all) {
      _pos = _items.length - 1;
    }
    _settle(arrived: true);
    return currentId;
  }

  void jumpTo(int index) {
    if (index < 0 || index >= _items.length) return;
    if (_pos >= 0 && _pos != index) _pushHistory();
    _pos = index;
    _settle(arrived: true);
    _changed();
  }

  /// Returns true when the removed item was the current one (the caller must
  /// load [currentId] again, which now points at the following item).
  bool removeAt(int index) {
    if (index < 0 || index >= _items.length) return false;
    _changed();
    final wasCurrent = index == _pos;
    final key = _keys[index];
    _items.removeAt(index);
    _keys.removeAt(index);
    _natural?.remove(key);
    _history.removeWhere((k) => k == key);
    _user.remove(key);
    if (_items.isEmpty) {
      _pos = -1;
    } else if (index < _pos) {
      _pos--;
    } else if (_pos >= _items.length) {
      _pos = _items.length - 1;
    }
    if (wasCurrent) _settle(arrived: true);
    return wasCurrent;
  }

  /// Moves an item, keeping the current track playing.
  void move(int from, int to) {
    if (from < 0 || from >= _items.length || to < 0 || to >= _items.length) return;
    if (from == to) return;
    _changed();
    final currentKey = _pos >= 0 ? _keys[_pos] : null;
    final moved = _keys[from];
    _user.remove(moved);
    _items.insert(to, _items.removeAt(from));
    _keys.insert(to, _keys.removeAt(from));
    if (currentKey != null) _pos = _keys.indexOf(currentKey);
    // Landing inside the block (or right after it) joins it, elsewhere it is normal.
    if (_user.isNotEmpty &&
        moved != currentKey &&
        to > _pos &&
        to <= _pos + _user.length + 1) {
      _user.insert(to - _pos - 1, moved);
    }
    _settle();
  }

  /// What follows the current track, built again from [source] (the list
  /// playback started from): in order from the current track on or, with
  /// shuffle, a fresh shuffle of the whole list, kept in the queue's own order
  /// so the queue shows what will play. Without [source] it is just dropped.
  /// The current track stays; the history goes (it pointed into old items).
  void rebuildUpcoming(List<int>? source) {
    final current = currentId;
    if (current == null) return;
    final from = source ?? const <int>[];
    final at = from.indexOf(current);
    final List<int> ids;
    var start = 0;
    if (from.isEmpty) {
      ids = [current];
    } else if (at >= 0) {
      ids = [...from];
      start = at;
    } else {
      ids = [current, ...from];
    }
    _history.clear();
    _changed();
    final fromUser = _currentFromUser;
    _load(ids, start, shuffleNow: _shuffle);
    _currentFromUser = fromUser;
  }

  QueueState saveState() => QueueState._(
    List.of(_items),
    List.of(_keys),
    _natural == null ? null : List.of(_natural!),
    _pos,
    List.of(_history),
    List.of(_user),
    _currentFromUser,
  );

  /// Puts [state] back, only while the same track plays; false otherwise.
  bool restoreState(QueueState state) {
    if (state.currentId == null || state.currentId != currentId) return false;
    _items
      ..clear()
      ..addAll(state._items);
    _keys
      ..clear()
      ..addAll(state._keys);
    _natural = state._natural == null ? null : List.of(state._natural!);
    _pos = state._pos;
    _user
      ..clear()
      ..addAll(state._user);
    _currentFromUser = state._currentFromUser;
    _history
      ..clear()
      ..addAll(state._history);
    _changed();
    return true;
  }

  /// Puts [id] at [index] of the play order (past the end = at the end). The
  /// current track keeps playing. With the natural order saved, the new key
  /// goes right after the key of the entry now before it, so shuffle off keeps
  /// the entry where the listener saw it.
  void insertAt(int index, int id) {
    if (_items.isEmpty) {
      setItems([id]);
      return;
    }
    _changed();
    var at = index.clamp(0, _items.length);
    if (at > _pos && at <= _pos + _user.length) at = _pos + 1 + _user.length;
    final key = _newKey();
    final natural = _natural;
    if (natural != null) {
      final before = at == 0 ? -1 : natural.indexOf(_keys[at - 1]);
      natural.insert(before + 1, key);
    }
    _items.insert(at, id);
    _keys.insert(at, key);
    if (at <= _pos) _pos++;
  }

  /// Removes the first occurrence of [id], as [removeAt]; true when it was the
  /// current track. False (and no change) when [id] is not in the queue.
  bool removeId(int id) {
    final i = _items.indexOf(id);
    return i < 0 ? false : removeAt(i);
  }

  /// Swaps every entry [oldId] for [newId], keeping its place, key and
  /// shuffle position. The current entry is left alone (it is already loaded).
  /// Returns how many entries changed.
  int replaceId(int oldId, int newId) {
    var n = 0;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i] == oldId && i != _pos) {
        _items[i] = newId;
        n++;
      }
    }
    if (n > 0) _changed();
    return n;
  }

  /// «Add to queue»: after the current track and the user entries before it.
  void enqueue(int trackId) {
    if (_items.isEmpty) {
      setItems([trackId]);
      return;
    }
    _changed();
    _insertUser(_pos + 1 + _user.length, trackId);
  }
}
