import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/brand_color.dart';
import '../../application/profile_setup_provider.dart';
import '../../data/models/profile_setup_models.dart';
import 'education_history_modal.dart';
import 'portfolio_link_modal.dart';
import 'profile_setup_widgets.dart';

class ProfileStep4Verification extends ConsumerWidget {
  const ProfileStep4Verification({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileSetupProvider);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 760;

      final educationCard = WizardCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 16, color: BrandColors.navy),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Education History',
                    style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const EducationHistoryModal(),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text(
                    '+ Add New',
                    style: TextStyle(color: BrandColors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < state.educationHistory.length; i++) ...[
              _EducationRow(
                entry: state.educationHistory[i],
                onDelete: () => ref.read(profileSetupProvider.notifier).removeEducationEntry(i),
              ),
              if (i != state.educationHistory.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      );

      final certificationsCard = WizardCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_outlined, size: 16, color: BrandColors.navy),
                SizedBox(width: 6),
                Text(
                  'Professional Certifications',
                  style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                  // Needed to get bytes back on web (desktop/mobile also
                  // get a usable `path`, but web only ever gives bytes).
                  withData: true,
                );
                if (result == null || result.files.isEmpty) return;
                final picked = result.files.single;
                final bytes = picked.bytes;
                if (bytes == null) return; // shouldn't happen with withData: true

                // Local-only — the file's bytes are kept on the entry
                // (CertificationEntry.fileBytes) and go out with
                // everything else at Step 4's "Complete Profile", not
                // uploaded the moment it's picked.
                ref.read(profileSetupProvider.notifier).addCertification(
                      bytes: bytes,
                      filename: picked.name,
                    );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: BrandColors.background,
                  borderRadius: BorderRadius.circular(10),
                  // NOTE: mock shows a dashed border — approximated as
                  // solid, same reasoning as the other upload zones.
                  border: Border.all(color: BrandColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: Color(0xFFFBE3D0), shape: BoxShape.circle),
                      child: const Icon(Icons.description_outlined, color: BrandColors.orange, size: 18),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Certificate PDF',
                      style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    const Text('Drag & drop or click to browse', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
                    const Text('MAX FILE SIZE 10MB', style: TextStyle(fontSize: 9.5, color: BrandColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < state.certifications.length; i++) ...[
              _CertificationRow(
                entry: state.certifications[i],
                onDelete: () => ref.read(profileSetupProvider.notifier).removeCertification(i),
              ),
              if (i != state.certifications.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      );

      // ASSUMPTION: neither screenshot shows this section un-obscured by
      // its own modal — both show the identical Education/Certifications
      // background. Added anyway because the sidebar's application-flow
      // list (Step 2) names this whole step "Portfolio Upload", so a
      // Portfolio section belongs somewhere on this page. Placement
      // (full-width, below the two-column row) is a judgment call — move
      // it if you have the real layout.
      final portfolioCard = WizardCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, size: 16, color: BrandColors.navy),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Portfolio Links',
                    style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const PortfolioLinkModal(),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text(
                    '+ Add New',
                    style: TextStyle(color: BrandColors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.portfolioLinks.isEmpty)
              const Text(
                'No portfolio links added yet.',
                style: TextStyle(fontSize: 12, color: BrandColors.muted),
              )
            else
              for (var i = 0; i < state.portfolioLinks.length; i++) ...[
                _PortfolioLinkRow(
                  entry: state.portfolioLinks[i],
                  onDelete: () => ref.read(profileSetupProvider.notifier).removePortfolioLink(i),
                ),
                if (i != state.portfolioLinks.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      );

      final columns = isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: educationCard),
                const SizedBox(width: 16),
                Expanded(child: certificationsCard),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                educationCard,
                const SizedBox(height: 16),
                certificationsCard,
              ],
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Verify your expertise',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            'Final step, ${state.firstNameOrFallback}! '
            "Let's get your educational background and professional certifications verified to unlock "
            'premium job opportunities.',
            style: const TextStyle(fontSize: 12.5, color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          columns,
          const SizedBox(height: 16),
          portfolioCard,
          const SizedBox(height: 16),
          const _InstantCredentialCheckCard(),
          const SizedBox(height: 16),
          _ProfileSummaryCard(state: state),
          const SizedBox(height: 24),
          WizardFooterRow(
            onBack: onBack,
            onPrimary: onComplete,
            primaryLabel: 'Complete Profile',
            primaryIcon: Icons.check,
          ),
        ],
      );
    });
  }
}

class _EducationRow extends StatelessWidget {
  const _EducationRow({required this.entry, required this.onDelete});
  final EducationEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: BrandColors.background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.school, style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(entry.programme, style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${entry.startYear} - ${entry.endYear ?? 'Present'}',
              style: const TextStyle(fontSize: 10.5, color: BrandColors.navy, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          _DeleteIconButton(onTap: onDelete, tooltip: 'Remove education entry'),
        ],
      ),
    );
  }
}

class _CertificationRow extends StatelessWidget {
  const _CertificationRow({required this.entry, required this.onDelete});
  final CertificationEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final verified = entry.status == CertificationStatus.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: verified ? const Color(0xFFBBF7D0) : BrandColors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.check_circle : Icons.bolt,
            size: 16,
            color: verified ? const Color(0xFF16A34A) : BrandColors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 12)),
                Text(
                  verified ? (entry.verifiedLabel ?? 'Verified') : 'Auto-Verifying...',
                  style: TextStyle(fontSize: 10.5, color: verified ? const Color(0xFF16A34A) : BrandColors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _DeleteIconButton(onTap: onDelete, tooltip: 'Remove certification'),
        ],
      ),
    );
  }
}

class _PortfolioLinkRow extends StatelessWidget {
  const _PortfolioLinkRow({required this.entry, required this.onDelete});
  final PortfolioLinkEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: BrandColors.background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16, color: BrandColors.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayTitle.isEmpty ? entry.platform : entry.displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 12),
                ),
                Text(
                  entry.url,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: BrandColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(20)),
            child: Text(
              entry.platform,
              style: const TextStyle(fontSize: 10, color: BrandColors.navy, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          _DeleteIconButton(onTap: onDelete, tooltip: 'Remove portfolio link'),
        ],
      ),
    );
  }
}

/// Small trailing delete affordance shared by both list rows above.
class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({required this.onTap, required this.tooltip});
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 15, color: BrandColors.muted),
        ),
      ),
    );
  }
}

class _InstantCredentialCheckCard extends StatelessWidget {
  const _InstantCredentialCheckCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: BrandColors.navy, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -6,
            child: Icon(Icons.description, size: 64, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instant Credential Check',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your PDF certificates. Our AI engine parses the data and authenticates with '
                      'issuer databases in real-time.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.state});
  final ProfileSetupState state;

  @override
  Widget build(BuildContext context) {
    final displayName = state.fullName.trim().isEmpty ? 'Your Name' : state.fullName.trim().toUpperCase();
    final displayTitle = state.professionalTitle.trim().isEmpty ? 'Add your title in Step 1' : state.professionalTitle.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: BrandColors.orange, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(radius: 22, backgroundColor: BrandColors.iconBg, child: Icon(Icons.person, color: BrandColors.navy)),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 9, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w800, color: BrandColors.navy, fontSize: 13)),
                Text(displayTitle, style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
              ],
            ),
          ),
          // NOTE: "Credentials: Verified" and "Match Score: 94%" are static
          // demo values in the mock — there's no scoring/verification API
          // wired up yet, so these are hardcoded placeholders until that
          // backend exists.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(8)),
            child: const Column(
              children: [
                Text('CREDENTIALS', style: TextStyle(fontSize: 8, color: BrandColors.muted, fontWeight: FontWeight.w700)),
                Text('Verified', style: TextStyle(fontSize: 11, color: BrandColors.navy, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFFF1E6), borderRadius: BorderRadius.circular(8)),
            child: const Column(
              children: [
                Text('MATCH SCORE', style: TextStyle(fontSize: 8, color: BrandColors.muted, fontWeight: FontWeight.w700)),
                Text('94%', style: TextStyle(fontSize: 11, color: BrandColors.orange, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}