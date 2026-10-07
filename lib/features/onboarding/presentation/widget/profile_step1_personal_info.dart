import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/application/location_provider.dart';
import '../../../../core/data/models/location_models.dart';
import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/profile_setup_provider.dart';
import 'profile_setup_widgets.dart';

class ProfileStep1PersonalInfo extends ConsumerStatefulWidget {
  const ProfileStep1PersonalInfo({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  ConsumerState<ProfileStep1PersonalInfo> createState() => _ProfileStep1PersonalInfoState();
}

class _ProfileStep1PersonalInfoState extends ConsumerState<ProfileStep1PersonalInfo> {
  late final TextEditingController _nameController;
  late final TextEditingController _titleController;
  late final TextEditingController _streetAddressController;
  Uint8List? _imageBytes;

  // Stored as codes (not full CountryEntry/StateEntry objects) since
  // dropdown equality needs a stable, comparable value type — a freshly
  // fetched object instance wouldn't `==` a previously-stored one even
  // with identical fields.
  String? _countryCode;
  String? _countryName;
  String? _stateCode;
  String? _stateName;
  String? _city;

  @override
  void initState() {
    super.initState();
    // Pre-fill from provider state so values survive a Back navigation
    // from a later step.
    final state = ref.read(profileSetupProvider);
    _nameController = TextEditingController(text: state.fullName);
    _titleController = TextEditingController(text: state.professionalTitle);
    _streetAddressController = TextEditingController(text: state.streetAddress);
    _imageBytes = state.profileImageBytes;
    _countryCode = state.countryCode;
    _countryName = state.countryName;
    _stateCode = state.stateCode;
    _stateName = state.stateName;
    _city = state.city;

    // Fetch the country list (cached after first load — see
    // LocationsNotifier.loadCountries). If a country/state were already
    // picked before navigating away, re-populate their dependent lists
    // too so the dropdowns show real options instead of just the raw
    // stored code.
    //
    // Deferred to after this frame finishes building: Riverpod disallows
    // modifying provider state synchronously during a widget's build
    // phase (initState counts), and loadCountries()'s first line does
    // exactly that (state = state.copyWith(isLoadingCountries: true))
    // before it ever reaches an `await`. Calling it directly from here
    // throws "Tried to modify a provider while the widget tree was
    // building."
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locationsNotifier = ref.read(locationsProvider.notifier);
      locationsNotifier.loadCountries();
      if (_countryCode != null) {
        locationsNotifier.loadStates(_countryCode!).then((_) {
          if (_stateCode != null && mounted) {
            locationsNotifier.loadCities(_countryCode!, _stateCode!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _streetAddressController.dispose();
    super.dispose();
  }

  /// Dropdowns throw if `value` doesn't exactly match one of `items` —
  /// this avoids that assertion when a stored code hasn't shown up in
  /// the (still-loading, or since-changed) options list yet.
  String? _safeValue(String? current, Iterable<String> validValues) {
    if (current == null) return null;
    return validValues.contains(current) ? current : null;
  }

  void _onCountryChanged(String? code, List<CountryEntry> countries) {
    if (code == null) return;
    final country = countries.firstWhere((c) => c.isoCode == code);
    setState(() {
      _countryCode = country.isoCode;
      _countryName = country.name;
      _stateCode = null;
      _stateName = null;
      _city = null;
    });
    ref.read(locationsProvider.notifier).loadStates(code);
    _pushLocation();
  }

  void _onStateChanged(String? code, List<StateEntry> states) {
    if (code == null) return;
    final selected = states.firstWhere((s) => s.isoCode == code);
    setState(() {
      _stateCode = selected.isoCode;
      _stateName = selected.name;
      _city = null;
    });
    ref.read(locationsProvider.notifier).loadCities(_countryCode!, code);
    _pushLocation();
  }

  void _onCityChanged(String? name) {
    if (name == null) return;
    setState(() => _city = name);
    _pushLocation();
  }

  void _pushLocation() {
    ref.read(profileSetupProvider.notifier).updateLocation(
          countryCode: _countryCode,
          countryName: _countryName,
          stateCode: _stateCode,
          stateName: _stateName,
          city: _city,
          streetAddress: _streetAddressController.text.trim(),
        );
  }

  void _saveAndContinue() {
    ref.read(profileSetupProvider.notifier).updatePersonalInfo(
          fullName: _nameController.text.trim(),
          professionalTitle: _titleController.text.trim(),
        );
    // Street address isn't pushed live like the dropdowns are — commit
    // it now, alongside whatever country/state/city is currently set.
    _pushLocation();
    widget.onContinue();
  }

  Future<void> _pickAndSetImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
    // Saved immediately (not just on Continue) so the photo survives even
    // if the person navigates away via Skip rather than Continue.
    ref.read(profileSetupProvider.notifier).updateProfileImage(bytes);
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: BrandColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: BrandColors.navy),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickAndSetImage(ImageSource.gallery);
                },
              ),
              // NOTE: on Flutter web, image_picker's camera source isn't
              // reliably supported across browsers — this option is
              // hidden there so it isn't offered as something that might
              // silently fail. It works fine on Android/iOS builds.
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: BrandColors.navy),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickAndSetImage(ImageSource.camera);
                  },
                ),
              if (_imageBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _imageBytes = null);
                    ref.read(profileSetupProvider.notifier).removeProfileImage();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);

    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Build your profile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            "Let's start with the basics. This information helps recruiters find you for the right roles.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BrandColors.iconBg,
                      // NOTE: mock shows a dotted ring here — approximated
                      // as a solid border. A true dashed circle needs a
                      // CustomPainter or a package like dotted_border,
                      // which isn't confirmed to be in pubspec.yaml.
                      border: Border.all(color: BrandColors.orange, width: 1.5),
                    ),
                    child: _imageBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              _imageBytes!,
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined, color: BrandColors.orange, size: 20),
                              SizedBox(height: 2),
                              Text(
                                'UPLOAD',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: BrandColors.orange,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: BrandColors.navy, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'PROFILE PICTURE',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BrandColors.muted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          const Text('Full Name', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: authInputDecoration(hint: 'Alex Rivera', icon: Icons.person_outline),
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 16),
          const Text('Professional Title', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleController,
            decoration: authInputDecoration(hint: 'Senior UI/UX Designer', icon: Icons.work_outline),
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 16),
          const Text('Country', style: authLabelStyle),
          const SizedBox(height: 6),
          if (locations.error != null && locations.countries.isEmpty)
            _InlineRetry(
              message: 'Failed to load countries.',
              onRetry: () => ref.read(locationsProvider.notifier).loadCountries(),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _safeValue(_countryCode, locations.countries.map((c) => c.isoCode)),
              dropdownColor: Colors.white,
              decoration: authInputDecoration(
                hint: locations.isLoadingCountries ? 'Loading countries...' : 'Select country',
                icon: Icons.public_outlined,
              ),
              style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
              items: locations.countries
                  .map((c) => DropdownMenuItem(value: c.isoCode, child: Text(c.displayLabel)))
                  .toList(),
              onChanged: locations.isLoadingCountries ? null : (code) => _onCountryChanged(code, locations.countries),
            ),
          const SizedBox(height: 16),
          const Text('State', style: authLabelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _safeValue(_stateCode, locations.states.map((s) => s.isoCode)),
            dropdownColor: Colors.white,
            decoration: authInputDecoration(
              hint: _countryCode == null
                  ? 'Select a country first'
                  : (locations.isLoadingStates ? 'Loading states...' : 'Select state'),
              icon: Icons.map_outlined,
            ),
            style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
            items: locations.states.map((s) => DropdownMenuItem(value: s.isoCode, child: Text(s.name))).toList(),
            onChanged: (_countryCode == null || locations.isLoadingStates)
                ? null
                : (code) => _onStateChanged(code, locations.states),
          ),
          const SizedBox(height: 16),
          const Text('City', style: authLabelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _safeValue(_city, locations.cities.map((c) => c.name)),
            dropdownColor: Colors.white,
            decoration: authInputDecoration(
              hint: _stateCode == null
                  ? 'Select a state first'
                  : (locations.isLoadingCities ? 'Loading cities...' : 'Select city'),
              icon: Icons.location_city_outlined,
            ),
            style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
            items: locations.cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
            onChanged: (_stateCode == null || locations.isLoadingCities) ? null : _onCityChanged,
          ),
          const SizedBox(height: 16),
          const Text('Street Address (optional)', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _streetAddressController,
            decoration: authInputDecoration(hint: '12 Adeola Odeku Street', icon: Icons.home_outlined),
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 24),
          WizardFooterRow(
            onBack: null, // first step — nothing to go back to
            onSkip: widget.onSkip,
            onPrimary: _saveAndContinue,
            primaryLabel: 'Continue',
          ),
        ],
      ),
    );
  }
}

class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: Colors.red))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}