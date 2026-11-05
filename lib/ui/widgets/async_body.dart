import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'error_state.dart';
import 'skeleton.dart';

/// Loading / empty / error / data for an [AsyncValue]. Error: «Riprova» when
/// [onRetry] is given; the exception goes to `AppLog` (via `LoadError`, once).
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.loading,
    this.errorMessage,
    this.rowHeight,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// With [empty]: when true on the loaded data, [empty] is shown instead.
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;

  /// Replaces the default row skeleton (e.g. a thin linear bar).
  final Widget? loading;

  /// Replaces the default `loadFailed` text.
  final String? errorMessage;

  /// Height of the real rows, for the default row skeleton.
  final double? rowHeight;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => loading ?? RowsLoading(rowHeight: rowHeight),
    error: (e, st) => LoadError(e, st, onRetry: onRetry, message: errorMessage),
    data: (d) =>
        empty != null && (isEmpty?.call(d) ?? false) ? empty! : data(d),
  );
}

/// [AsyncBody] for a sliver list: the error is a fixed-height box, the
/// loading and data slivers are the caller's (so a list keeps its element
/// across loading and data).
class SliverAsyncBody<T> extends StatelessWidget {
  const SliverAsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.errorHeight = 240,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final double errorHeight;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () =>
        loading ?? const SliverToBoxAdapter(child: Skeleton.list()),
    error: (e, st) => SliverToBoxAdapter(
      child: SizedBox(
        height: errorHeight,
        child: LoadError(e, st, onRetry: onRetry),
      ),
    ),
    data: data,
  );
}

/// Row skeleton, shown only if the data takes longer than
/// [CcMotion.skeletonDelay] (a fast screen never flashes it). Clipped at the
/// bottom when the height is bounded, natural height (8 rows) when unbounded
/// (e.g. inside a sheet). [rowHeight]: the height of the real rows.
class RowsLoading extends StatefulWidget {
  const RowsLoading({super.key, this.rowHeight});

  final double? rowHeight;

  @override
  State<RowsLoading> createState() => _RowsLoadingState();
}

class _RowsLoadingState extends State<RowsLoading> {
  late final Timer _timer;
  bool _late = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(CcMotion.skeletonDelay, () => setState(() => _late = true));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_late) return const SizedBox.shrink();
    final rows = Skeleton.list(rowHeight: widget.rowHeight);
    return LayoutBuilder(
      builder: (context, box) => box.hasBoundedHeight
          ? ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: rows,
              ),
            )
          : rows,
    );
  }
}
