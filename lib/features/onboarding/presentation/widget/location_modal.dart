import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/searchable_fields_widget.dart';
import '../../../../core/application/location_provider.dart';
import '../../../../core/data/models/location_models.dart';

class LocationSelection {
  const LocationSelection({
    this.countryCode,
    this.countryName,
    this.stateCode,
    this.stateName,
    this.city,
    this.isRemote = false,
  });

  final String? countryCode;
  final String? countryName;
  final String? stateCode;
  final String? stateName;
  final String? city;
  final bool isRemote;
}

/// Opens a modal containing the real Country -> State -> City search
/// cascade (backend-fetched via locationsProvider) plus a "Remote" toggle
/// — the parent screen shows this behind a single tappable "Location *"
/// field per the client's design, while the actual selection underneath
/// stays the structured, backend-driven search we built last round.
Future<LocationSelection?> showLocationPickerModal(
  BuildContext context, {
  required LocationSelection initial,
}) {
  return showDialog<LocationSelection>(
    context: context,
    builder: (_) => _LocationPickerDialog(initial: initial),
  );
}

class _LocationPickerDialog extends ConsumerStatefulWidget {
  const _LocationPickerDialog({required this.initial});
  final LocationSelection initial;

  @override
  ConsumerState<_LocationPickerDialog> createState() =>
      _LocationPickerDialogState();
}

class _LocationPickerDialogState extends ConsumerState<_LocationPickerDialog> {
  String? _countryCode;
  String? _countryName;
  String? _stateCode;
  String? _stateName;
  String? _city;
  bool _isRemote = false;

  @override
  void initState() {
    super.initState();
    _countryCode = widget.initial.countryCode;
    _countryName = widget.initial.countryName;
    _stateCode = widget.initial.stateCode;
    _stateName = widget.initial.stateName;
    _city = widget.initial.city;
    _isRemote = widget.initial.isRemote;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(locationsProvider.notifier);
      notifier.loadCountries();
      if (_countryCode != null) {
        notifier.loadStates(_countryCode!).then((_) {
          if (_stateCode != null && mounted) {
            notifier.loadCities(_countryCode!, _stateCode!);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);
    final selectedCountry = _countryCode == null
        ? null
        : locations.countries
            .cast<CountryEntry?>()
            .firstWhere((c) => c!.isoCode == _countryCode, orElse: () => null);
    final selectedState = _stateCode == null
        ? null
        : locations.states
            .cast<StateEntry?>()
            .firstWhere((s) => s!.isoCode == _stateCode, orElse: () => null);
    final cityNames = locations.cities.map((c) => c.name).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Location',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: Checkbox(
                      value: _isRemote,
                      activeColor: BrandColors.orange,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _isRemote = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('I work remotely / no fixed location',
                      style:
                          TextStyle(fontSize: 12.5, color: BrandColors.muted)),
                ],
              ),
              if (!_isRemote) ...[
                const SizedBox(height: 12),
                const Text('COUNTRY', style: authLabelStyle),
                const SizedBox(height: 6),
                locations.error != null && locations.countries.isEmpty
                    ? _InlineRetry(
                        message: 'Failed to load countries.',
                        onRetry: () => ref
                            .read(locationsProvider.notifier)
                            .loadCountries(),
                      )
                    : SearchableField<CountryEntry>(
                        options: locations.countries,
                        displayStringForOption: (c) => c.displayLabel,
                        initialValue: selectedCountry,
                        hintText: locations.isLoadingCountries
                            ? 'Loading countries...'
                            : 'Search country',
                        icon: Icons.public_outlined,
                        enabled: !locations.isLoadingCountries,
                        onSelected: (c) {
                          setState(() {
                            _countryCode = c.isoCode;
                            _countryName = c.name;
                            _stateCode = null;
                            _stateName = null;
                            _city = null;
                          });
                          ref
                              .read(locationsProvider.notifier)
                              .loadStates(c.isoCode);
                        },
                      ),
                const SizedBox(height: 14),
                const Text('STATE', style: authLabelStyle),
                const SizedBox(height: 6),
                SearchableField<StateEntry>(
                  key: ValueKey('state-$_countryCode'),
                  options: locations.states,
                  displayStringForOption: (s) => s.name,
                  initialValue: selectedState,
                  hintText: _countryCode == null
                      ? 'Select a country first'
                      : (locations.isLoadingStates
                          ? 'Loading states...'
                          : 'Search state'),
                  icon: Icons.map_outlined,
                  enabled: _countryCode != null && !locations.isLoadingStates,
                  onSelected: (s) {
                    setState(() {
                      _stateCode = s.isoCode;
                      _stateName = s.name;
                      _city = null;
                    });
                    ref
                        .read(locationsProvider.notifier)
                        .loadCities(_countryCode!, s.isoCode);
                  },
                ),
                const SizedBox(height: 14),
                const Text('CITY', style: authLabelStyle),
                const SizedBox(height: 6),
                SearchableField<String>(
                  key: ValueKey('city-$_stateCode'),
                  options: cityNames,
                  displayStringForOption: (n) => n,
                  initialValue: (_city != null && cityNames.contains(_city))
                      ? _city
                      : null,
                  hintText: _stateCode == null
                      ? 'Select a state first'
                      : (locations.isLoadingCities
                          ? 'Loading cities...'
                          : 'Search city'),
                  icon: Icons.location_city_outlined,
                  enabled: _stateCode != null && !locations.isLoadingCities,
                  onSelected: (name) => setState(() => _city = name),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        LocationSelection(
                          countryCode: _isRemote ? null : _countryCode,
                          countryName: _isRemote ? null : _countryName,
                          stateCode: _isRemote ? null : _stateCode,
                          stateName: _isRemote ? null : _stateName,
                          city: _isRemote ? 'Remote' : _city,
                          isRemote: _isRemote,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.orange,
                        foregroundColor: Colors.white),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 12.5, color: Colors.red))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
}
