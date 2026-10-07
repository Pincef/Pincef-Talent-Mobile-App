import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_provider.dart' show dioProvider;
import '../data/location_repository.dart';
import '../data/models/location_models.dart';

final locationsRepositoryProvider = Provider<LocationsRepository>((ref) {
  return LocationsRepository(ref.watch(dioProvider));
});

/// Holds the cascading *option lists* (which countries/states/cities are
/// available to pick from) — not which one is selected. The selected
/// values live wherever the picker is used (e.g. ProfileSetupState),
/// since that's form-specific; the lists themselves are shared/cached
/// here so switching between forms doesn't re-fetch the country list
/// every time.
class LocationsState {
  const LocationsState({
    this.countries = const [],
    this.states = const [],
    this.cities = const [],
    this.isLoadingCountries = false,
    this.isLoadingStates = false,
    this.isLoadingCities = false,
    this.error,
  });

  final List<CountryEntry> countries;
  final List<StateEntry> states;
  final List<CityEntry> cities;
  final bool isLoadingCountries;
  final bool isLoadingStates;
  final bool isLoadingCities;
  final String? error;

  LocationsState copyWith({
    List<CountryEntry>? countries,
    List<StateEntry>? states,
    List<CityEntry>? cities,
    bool? isLoadingCountries,
    bool? isLoadingStates,
    bool? isLoadingCities,
    String? error,
    bool clearError = false,
  }) {
    return LocationsState(
      countries: countries ?? this.countries,
      states: states ?? this.states,
      cities: cities ?? this.cities,
      isLoadingCountries: isLoadingCountries ?? this.isLoadingCountries,
      isLoadingStates: isLoadingStates ?? this.isLoadingStates,
      isLoadingCities: isLoadingCities ?? this.isLoadingCities,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LocationsNotifier extends StateNotifier<LocationsState> {
  LocationsNotifier(this._repository) : super(const LocationsState());
  final LocationsRepository _repository;

  /// Countries are a fixed reference list — fetched once per app
  /// session and cached, rather than re-fetched every time a picker
  /// screen opens.
  Future<void> loadCountries() async {
    if (state.countries.isNotEmpty || state.isLoadingCountries) {
      // ignore: avoid_print
      print('loadCountries: skipped — already loaded or already loading (isLoadingCountries=${state.isLoadingCountries}, countries.length=${state.countries.length})');
      return;
    }
    state = state.copyWith(isLoadingCountries: true, clearError: true);
    // ignore: avoid_print
    print('loadCountries: fetching...');
    try {
      final countries = await _repository.fetchCountries();
      // ignore: avoid_print
      print('loadCountries: success — ${countries.length} countries');
      state = state.copyWith(countries: countries, isLoadingCountries: false);
    } catch (e) {
      // ignore: avoid_print
      print('loadCountries: FAILED — $e');
      state = state.copyWith(isLoadingCountries: false, error: e.toString());
    }
  }

  /// Clears any previously-loaded states/cities immediately (not just on
  /// success) so a stale list from the last-selected country never
  /// briefly shows while the new one loads.
  Future<void> loadStates(String countryCode) async {
    state = state.copyWith(states: [], cities: [], isLoadingStates: true, clearError: true);
    try {
      final states = await _repository.fetchStates(countryCode);
      state = state.copyWith(states: states, isLoadingStates: false);
    } catch (e) {
      state = state.copyWith(isLoadingStates: false, error: e.toString());
    }
  }

  Future<void> loadCities(String countryCode, String stateCode) async {
    state = state.copyWith(cities: [], isLoadingCities: true, clearError: true);
    try {
      final cities = await _repository.fetchCities(countryCode, stateCode);
      state = state.copyWith(cities: cities, isLoadingCities: false);
    } catch (e) {
      state = state.copyWith(isLoadingCities: false, error: e.toString());
    }
  }

  void clearStatesAndCities() => state = state.copyWith(states: [], cities: []);

  void clearCities() => state = state.copyWith(cities: []);
}

final locationsProvider = StateNotifierProvider<LocationsNotifier, LocationsState>((ref) {
  return LocationsNotifier(ref.watch(locationsRepositoryProvider));
});