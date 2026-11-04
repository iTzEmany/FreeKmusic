import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/ui/screens/library/library_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows [LibraryResults] for what `typeSearch` puts in the shared search
/// controller, like the Library's own field does.
class ResultsHost extends ConsumerStatefulWidget {
  const ResultsHost({super.key});

  @override
  ConsumerState<ResultsHost> createState() => _ResultsHostState();
}

class _ResultsHostState extends ConsumerState<ResultsHost> {
  late final _c = ref.read(searchControllerProvider);

  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LibraryResults(text: _c.text.trim(), onOnline: () {}),
  );
}
