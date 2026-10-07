class CountryEntry {
  const CountryEntry({
    required this.name,
    required this.isoCode,
    required this.phoneCode,
    required this.flag,
  });

  final String name;
  final String isoCode;
  final String phoneCode;
  final String flag;

  factory CountryEntry.fromJson(Map<String, dynamic> json) => CountryEntry(
        name: json['name'] as String,
        isoCode: json['isoCode'] as String,
        phoneCode: json['phoneCode'] as String? ?? '',
        flag: json['flag'] as String? ?? '',
      );

  /// e.g. "🇳🇬 Nigeria" — used as the dropdown item label.
  String get displayLabel => flag.isEmpty ? name : '$flag $name';
}

class StateEntry {
  const StateEntry({
    required this.name,
    required this.isoCode,
    required this.countryCode,
  });

  final String name;
  final String isoCode;
  final String countryCode;

  factory StateEntry.fromJson(Map<String, dynamic> json) => StateEntry(
        name: json['name'] as String,
        isoCode: json['isoCode'] as String,
        countryCode: json['countryCode'] as String,
      );
}

/// ASSUMPTION: only the cities endpoint's URL pattern was shared, not its
/// response shape — guessing a `{ "name": "..." }` shape matching the
/// countries/states convention. Adjust fromJson if the real shape differs.
class CityEntry {
  const CityEntry({required this.name});

  final String name;

  factory CityEntry.fromJson(Map<String, dynamic> json) => CityEntry(
        name: json['name'] as String,
      );
}