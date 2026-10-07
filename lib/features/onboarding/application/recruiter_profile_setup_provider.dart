import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart' show dioProvider;
import '../data/recruiter_profile_setup_repository.dart';

final recruiterProfileSetupRepositoryProvider = Provider<RecruiterProfileSetupRepository>((ref) {
  return RecruiterProfileSetupRepository(ref.watch(dioProvider));
});

class RecruiterProfileSetupState {
  const RecruiterProfileSetupState({
    this.companyName = '',
    this.industry,
    this.companySize,
    this.companyWebsite = '',
    this.logoBytes,
    this.isSaving = false,
    this.saveError,
  });

  final String companyName;
  final String? industry;
  final String? companySize;
  final String companyWebsite;
  final Uint8List? logoBytes;
  final bool isSaving;
  final String? saveError;

  RecruiterProfileSetupState copyWith({
    String? companyName,
    String? industry,
    String? companySize,
    String? companyWebsite,
    Uint8List? logoBytes,
    bool clearLogo = false,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return RecruiterProfileSetupState(
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      companySize: companySize ?? this.companySize,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

class RecruiterProfileSetupNotifier extends StateNotifier<RecruiterProfileSetupState> {
  RecruiterProfileSetupNotifier(this._repository) : super(const RecruiterProfileSetupState());

  final RecruiterProfileSetupRepository _repository;

  void updateLogo(Uint8List bytes) => state = state.copyWith(logoBytes: bytes);

  void removeLogo() => state = state.copyWith(clearLogo: true);

  /// Combined submit — validates lightly (companyName required, website
  /// must look like a URL if provided), then sends everything (including
  /// the logo, if one was picked) in a single request via the
  /// repository. Returns true only on real success; the screen should
  /// only navigate onward then, and otherwise show state.saveError.
  Future<bool> submit({
    required String companyName,
    String? industry,
    String? companySize,
    required String companyWebsite,
  }) async {
    state = state.copyWith(
      companyName: companyName,
      industry: industry,
      companySize: companySize,
      companyWebsite: companyWebsite,
      isSaving: true,
      clearSaveError: true,
    );

    try {
      await _repository.saveCompanyProfile(
        companyName: companyName,
        industry: industry,
        companySize: companySize,
        companyWebsite: companyWebsite,
        logoBytes: state.logoBytes,
        logoFilename: 'company-logo.png',
      );
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: e.toString());
      return false;
    }
  }
}

final recruiterProfileSetupProvider =
    StateNotifierProvider<RecruiterProfileSetupNotifier, RecruiterProfileSetupState>((ref) {
  return RecruiterProfileSetupNotifier(ref.watch(recruiterProfileSetupRepositoryProvider));
});