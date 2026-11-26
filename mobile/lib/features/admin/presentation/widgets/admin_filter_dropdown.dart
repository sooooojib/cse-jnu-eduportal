import 'package:flutter/material.dart';

/// One option in an [AdminFilterDropdown]. A null [value] means "All".
class FilterOption<T> {
  final T? value;
  final String label;

  const FilterOption(this.value, this.label);
}

/// Compact dropdown used under the scrolling chips on admin list screens
/// (User Directory, Signup Petitions, Semester Petitions, Courses, ...).
///
/// It is a *controlled* widget: the parent owns [value], so changing the
/// selection only updates the displayed text. Nothing is recreated and the
/// label stays floated, which keeps the field from jumping or flickering.
class AdminFilterDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<FilterOption<T>> options;
  final ValueChanged<T?> onChanged;

  const AdminFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon = Icons.filter_list_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // Guard against a stale selection that is no longer offered.
    final effective = options.any((o) => o.value == value) ? value : null;

    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: effective,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          items: options
              .map((o) => DropdownMenuItem<T?>(
                    value: o.value,
                    child: Text(o.label, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != effective) onChanged(v);
          },
        ),
      ),
    );
  }
}
