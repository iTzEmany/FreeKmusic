import 'package:flutter/material.dart';

/// A short list of choices in a dialog (the current one ticked); null when dismissed.
/// Used by settings rows that show the value as a subtitle, so the title keeps the full width.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label})> options,
  required T current,
}) => showDialog<T>(
  context: context,
  builder: (c) => SimpleDialog(
    title: Text(title),
    children: [
      for (final o in options)
        ListTile(
          title: Text(o.label),
          trailing: o.value == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(c, o.value),
        ),
    ],
  ),
);
