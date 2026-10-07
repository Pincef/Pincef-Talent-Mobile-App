import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import '../../application/setting_provider.dart';

class ProfileInformationTab extends ConsumerStatefulWidget {
  const ProfileInformationTab({super.key});

  @override
  ConsumerState<ProfileInformationTab> createState() =>
      _ProfileInformationTabState();
}

class _ProfileInformationTabState extends ConsumerState<ProfileInformationTab> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _summaryController;
  late bool _remoteFriendly;
  late bool _activeSeeking;
  bool _isSaving = false;
  bool _isRemovingPhoto = false;
  bool _isUploadingPhoto = false;

  UserModel get _user => ref.read(authProvider).user!;

  @override
  void initState() {
    super.initState();
    _resetFromUser();
  }

  void _resetFromUser() {
    _nameController = TextEditingController(text: _user.fullName);
    _phoneController = TextEditingController(text: _user.phone ?? '');
    _locationController = TextEditingController(text: _user.location ?? '');
    _summaryController = TextEditingController(text: _user.bio ?? '');
    _remoteFriendly = _user.workPreferences.remoteFriendly;
    _activeSeeking = _user.workPreferences.activeSeeking;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Same first-space split caveat as the recruiter Account tab — the
      // model keeps firstName/lastName separate, the mockup has one field.
      final parts = _nameController.text.trim().split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final updated = await ref.read(settingsRepositoryProvider).updateAccount(
            firstName: firstName,
            lastName: lastName,
            phone: _phoneController.text.trim(),
            location: _locationController.text.trim(),
            bio: _summaryController.text.trim(),
            remoteFriendly: _remoteFriendly,
            activeSeeking: _activeSeeking,
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

  void _cancel() {
    setState(_resetFromUser);
  }

  Future<void> _updatePhoto() async {
    // Requires `image_picker` in pubspec.yaml (flutter pub add image_picker).
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

  Future<void> _removePhoto() async {
    setState(() => _isRemovingPhoto = true);
    try {
      await ref.read(settingsRepositoryProvider).removePhoto();
      final refreshedUser =
          await ref.read(settingsRepositoryProvider).getMyAccount();
      ref.read(authProvider.notifier).setUser(refreshedUser);
      if (mounted) AppToast.success(context, 'Profile photo removed.');
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not remove photo: $e');
      }
    } finally {
      if (mounted) setState(() => _isRemovingPhoto = false);
    }
  }

  Future<void> _openEmailChangeDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email address'),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Basic Information',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _LabeledField(
                                  label: 'FULL NAME',
                                  child: TextField(controller: _nameController),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _LabeledField(
                                  label: 'EMAIL ADDRESS',
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: TextEditingController(
                                              text: _user.email),
                                          enabled: false,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _openEmailChangeDialog,
                                        child: const Text('Change'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _LabeledField(
                                  label: 'PHONE NUMBER',
                                  child:
                                      TextField(controller: _phoneController),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _LabeledField(
                                  label: 'LOCATION',
                                  child: TextField(
                                      controller: _locationController),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'PROFESSIONAL SUMMARY',
                            child: TextField(
                                controller: _summaryController,
                                maxLines: 3,
                                maxLength: 1000),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Work Preferences',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 8),
                          _PreferenceSwitch(
                            title: 'Remote Friendly',
                            subtitle:
                                'You are open to remote or hybrid opportunities.',
                            value: _remoteFriendly,
                            onChanged: (v) =>
                                setState(() => _remoteFriendly = v),
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _PreferenceSwitch(
                            title: 'Active Seeking',
                            subtitle:
                                'Allow recruiters to find your profile in talent searches.',
                            value: _activeSeeking,
                            onChanged: (v) =>
                                setState(() => _activeSeeking = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile Picture',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 14),
                      Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.peach,
                          backgroundImage: _user.profileImage != null
                              ? NetworkImage(_user.profileImage!.url)
                              : null,
                          child: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : (_user.profileImage == null
                                  ? const Icon(Icons.person,
                                      size: 36, color: AppColors.orange)
                                  : null),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text('JPG, GIF or PNG. Max size 800K',
                            style: TextStyle(
                                color: BrandColors.muted, fontSize: 10.5)),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isUploadingPhoto ? null : _updatePhoto,
                          child: Text(_isUploadingPhoto
                              ? 'Uploading...'
                              : 'Update Photo'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed:
                              (_user.profileImage == null || _isRemovingPhoto)
                                  ? null
                                  : _removePhoto,
                          child: Text(
                            _isRemovingPhoto ? 'Removing...' : 'Remove',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                  onPressed: _isSaving ? null : _cancel,
                  child: const Text('Cancel')),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                child: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: BrandColors.muted, fontSize: 10.5, letterSpacing: 0.4)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(color: BrandColors.muted, fontSize: 11)),
            ],
          ),
        ),
        Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.orange),
      ],
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
