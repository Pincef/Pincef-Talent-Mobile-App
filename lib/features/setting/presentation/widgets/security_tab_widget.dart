/// lib/features/settings/presentation/screens/security_tab.dart
library;

import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import '../../application/setting_provider.dart';
import '../../data/models/security_log_item_model.dart';

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PasswordManagementCard()),
              SizedBox(width: 16),
              Expanded(child: _TwoFactorAuthCard()),
            ],
          ),
          SizedBox(height: 16),
          _ActiveSessionsCard(),
          SizedBox(height: 16),
          _SecurityLogsCard(),
        ],
      ),
    );
  }
}

class _PasswordManagementCard extends ConsumerStatefulWidget {
  const _PasswordManagementCard();

  @override
  ConsumerState<_PasswordManagementCard> createState() =>
      _PasswordManagementCardState();
}

class _PasswordManagementCardState
    extends ConsumerState<_PasswordManagementCard> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Confirm-matches-new is a client-side check only — the backend's
    // changePasswordSchema just takes current/new, same as before.
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New password and confirmation don\'t match');
      AppToast.error(context, 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      if (mounted) {
        AppToast.success(context, 'Password updated.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Couldn\'t update password: $e');
        AppToast.error(context, 'Could not update password: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Password Management',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('CURRENT PASSWORD',
              style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 10.5,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          TextField(controller: _currentController, obscureText: true),
          const SizedBox(height: 12),
          const Text('NEW PASSWORD',
              style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 10.5,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          TextField(controller: _newController, obscureText: true),
          const SizedBox(height: 12),
          const Text('CONFIRM PASSWORD',
              style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 10.5,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          TextField(controller: _confirmController, obscureText: true),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 11.5)),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              child: Text(_isSaving ? 'Updating...' : 'Update Password'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rather than a fake working toggle — real 2FA needs a TOTP
/// secret field on IUser plus a library (e.g. otplib) to generate/verify
/// codes and a QR-provisioning step, none of which exists yet. Wiring a
/// toggle up to nothing would be worse than being upfront that it's not
/// built.
class _TwoFactorAuthCard extends StatelessWidget {
  const _TwoFactorAuthCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Two-Factor Auth',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Add an extra layer of security using an authenticator app or SMS verification.',
            style: TextStyle(color: BrandColors.muted, fontSize: 12),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Enable 2FA Protection', style: TextStyle(fontSize: 12.5)),
              Switch(
                value: false,
                onChanged: null, // disabled — see class doc
                activeThumbColor: AppColors.orange,
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('Coming soon',
              style: TextStyle(
                  color: BrandColors.muted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// Your current auth model tracks a single refreshTokenHash per user —
/// there's no per-device session record to list, so this shows the one
/// real thing that's true today rather than a fabricated multi-device
/// list like the mockup's. Multi-session support (a Session collection,
/// device/IP tracking, per-session revoke) is a real auth change, not an
/// additive one — worth its own discussion before building the mockup's
/// full version of this card.
class _ActiveSessionsCard extends StatelessWidget {
  const _ActiveSessionsCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_outlined, size: 16, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Active Sessions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle, color: Colors.green, size: 18),
            title: Text('This device', style: TextStyle(fontSize: 12.5)),
            subtitle: Text('Current session',
                style: TextStyle(color: BrandColors.muted, fontSize: 11)),
          ),
          SizedBox(height: 4),
          Text(
            'Multi-device session management isn\'t available yet — logging in elsewhere currently signs you out here.',
            style: TextStyle(
                color: BrandColors.muted,
                fontSize: 11,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _SecurityLogsCard extends ConsumerWidget {
  const _SecurityLogsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(securityLogProvider);
    final loaded = logState.valueOrNull;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, size: 16, color: AppColors.orange),
              SizedBox(width: 8),
              Text('Security Logs',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          logState.when(
            data: (data) => data.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No security events yet.',
                        style:
                            TextStyle(color: BrandColors.muted, fontSize: 12)),
                  )
                : Column(
                    children: data.items
                        .map((item) => _SecurityLogRow(item: item))
                        .toList(),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("Couldn't load security logs.",
                  style: TextStyle(color: BrandColors.muted, fontSize: 12)),
            ),
          ),
          if (loaded?.nextCursor != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: loaded!.isLoadingMore
                    ? null
                    : () => ref.read(securityLogProvider.notifier).loadMore(),
                child: Text(
                  loaded.isLoadingMore
                      ? 'Loading...'
                      : 'View Full Activity History',
                  style:
                      const TextStyle(color: AppColors.orange, fontSize: 11.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecurityLogRow extends StatelessWidget {
  const _SecurityLogRow({required this.item});
  final SecurityLogItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isWarning
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            size: 16,
            color: item.isWarning ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.message, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(item.relativeTime,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 10.5)),
              ],
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
