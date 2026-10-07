import 'package:flutter/material.dart';
import '../theme/auth_form_style.dart';
import '../theme/brand_color.dart';

/// A text field that filters [options] as you type and shows matches in a
/// dropdown-style overlay — built on Flutter's own `Autocomplete` widget,
/// so no extra package dependency. Used for Country/State/City, where
/// plain `DropdownButtonFormField` makes long lists (250 countries) tedious
/// to scroll through.
///
/// IMPORTANT: give this a `key` that changes whenever [options] represents
/// a genuinely different list the field should reset against (e.g. a new
/// `ValueKey('state-$countryCode')` each time the selected country
/// changes) — `Autocomplete` only reads `initialValue` on first build, so
/// without a fresh key the field won't clear/reset when its parent
/// selection changes.
class SearchableField<T extends Object> extends StatelessWidget {
  const SearchableField({
    super.key,
    required this.options,
    required this.displayStringForOption,
    required this.onSelected,
    this.initialValue,
    this.hintText = 'Search...',
    this.icon,
    this.enabled = true,
  });

  final List<T> options;
  final String Function(T) displayStringForOption;
  final ValueChanged<T> onSelected;
  final T? initialValue;
  final String hintText;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<T>(
      initialValue: TextEditingValue(
        text: initialValue != null
            ? displayStringForOption(initialValue as T)
            : '',
      ),
      displayStringForOption: displayStringForOption,
      optionsBuilder: (textEditingValue) {
        if (!enabled) return const Iterable.empty();
        if (textEditingValue.text.isEmpty) return options;
        final query = textEditingValue.text.toLowerCase();
        return options.where(
            (o) => displayStringForOption(o).toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          decoration: authInputDecoration(hint: hintText, icon: icon),
          style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionsList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 260),
              child: optionsList.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No matches',
                          style: TextStyle(
                              fontSize: 12.5, color: BrandColors.muted)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: optionsList.length,
                      itemBuilder: (context, index) {
                        final option = optionsList[index];
                        return ListTile(
                          dense: true,
                          title: Text(displayStringForOption(option),
                              style: const TextStyle(
                                  fontSize: 13, color: BrandColors.navy)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
