/// lib/features/settings/presentation/screens/account_tab.dart
library;

import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import '../../application/setting_provider.dart';

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});

  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  final _competencyController = TextEditingController();

  late List<String> _competencies;
  late List<Certification> _certifications;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  UserModel get _user => ref.read(authProvider).user!;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _user.fullName);
    _bioController = TextEditingController(text: _user.bio ?? '');
    _locationController = TextEditingController(text: _user.location ?? '');
    _competencies = List.of(_user.competencies);
    _certifications = List.of(_user.certifications);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _competencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // NOTE: the mockup has a single "Full Name" field but the backend
      // model keeps firstName/lastName separate — splitting on the first
      // space is a reasonable default but breaks for multi-word given
      // names. Swap this for two inputs if that matters for your users.
      final parts = _nameController.text.trim().split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final updated = await ref.read(settingsRepositoryProvider).updateAccount(
            firstName: firstName,
            lastName: lastName,
            bio: _bioController.text.trim(),
            location: _locationController.text.trim(),
            competencies: _competencies,
            certifications: _certifications
                .map((c) => {
                      'name': c.name,
                      if (c.issuer != null) 'issuer': c.issuer,
                      if (c.issuedAt != null)
                        'issuedAt': c.issuedAt!.toIso8601String(),
                      if (c.validThru != null)
                        'validThru': c.validThru!.toIso8601String(),
                    })
                .toList(),
          );

      ref.read(authProvider.notifier).setUser(updated);
      if (mounted) {
        AppToast.success(context, 'Changes saved.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not save changes: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPhoto() async {
    // Requires `image_picker` in pubspec.yaml (flutter pub add image_picker)
    // — wasn't part of what you'd shared, so add that dependency if it
    // isn't already there.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await ref.read(settingsRepositoryProvider).uploadPhoto(picked);
      final refreshed =
          await ref.read(settingsRepositoryProvider).getMyAccount();
      ref.read(authProvider.notifier).setUser(refreshed);
      if (mounted) AppToast.success(context, 'Profile photo updated.');
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not upload photo: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _openEmailChangeDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change work email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send confirmation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(settingsRepositoryProvider).requestEmailChange(
            newEmail: emailController.text.trim(),
            currentPassword: passwordController.text,
          );
      if (mounted) {
        AppToast.success(context,
            'Confirmation link sent to ${emailController.text.trim()}.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not start email change: $e');
      }
    }
  }

  void _addCompetency() {
    final value = _competencyController.text.trim();
    if (value.isEmpty || _competencies.contains(value)) return;
    setState(() {
      _competencies.add(value);
      _competencyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile Photo',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.peach,
                            backgroundImage: _user.profileImage != null
                                ? NetworkImage(_user.profileImage!.url)
                                : null,
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : (_user.profileImage == null
                                    ? const Icon(Icons.person,
                                        size: 28, color: AppColors.orange)
                                    : null),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _pickPhoto,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: AppColors.orange,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.edit,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Text('PNG, JPG or GIF. Max size 2MB.',
                          style: TextStyle(
                              color: BrandColors.muted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('FULL NAME',
                      style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  TextField(controller: _nameController),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WORK EMAIL',
                                style: TextStyle(
                                    color: BrandColors.muted,
                                    fontSize: 10.5,
                                    letterSpacing: 0.4)),
                            const SizedBox(height: 4),
                            TextField(
                              controller:
                                  TextEditingController(text: _user.email),
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _openEmailChangeDialog,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('BIO',
                      style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  TextField(
                      controller: _bioController, maxLines: 3, maxLength: 1000),
                  const SizedBox(height: 8),
                  const Text('LOCATION',
                      style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  TextField(controller: _locationController),
                  const SizedBox(height: 20),
                  const Text('CORE COMPETENCIES',
                      style: TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10.5,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _competencies
                        .map((c) => Chip(
                              label:
                                  Text(c, style: const TextStyle(fontSize: 11)),
                              onDeleted: () =>
                                  setState(() => _competencies.remove(c)),
                              backgroundColor: AppColors.surface,
                              side: BorderSide.none,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _competencyController,
                          decoration: const InputDecoration(
                              hintText: 'Add a competency'),
                          onSubmitted: (_) => _addCompetency(),
                        ),
                      ),
                      IconButton(
                          onPressed: _addCompetency,
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange),
                      child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            flex: 2,
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal Information',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.orange)),
                  SizedBox(height: 8),
                  Text(
                    'Update your profile details and contact email used for candidate communication.',
                    style: TextStyle(color: BrandColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}
