import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/form_shell.dart';
import '../../application/profile_setup_provider.dart';
import '../../data/models/profile_setup_models.dart';

/// Opened from the "+ Add New" button on the Education History card in
/// Step 4 (profile_step4_verification.dart).
class EducationHistoryModal extends ConsumerStatefulWidget {
  const EducationHistoryModal({super.key});

  @override
  ConsumerState<EducationHistoryModal> createState() => _EducationHistoryModalState();
}

class _EducationHistoryModalState extends ConsumerState<EducationHistoryModal> {
  final _schoolController = TextEditingController();
  final _degreeController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _stillStudying = false;
  String? _errorText;

  @override
  void dispose() {
    _schoolController.dispose();
    _degreeController.dispose();
    _fieldOfStudyController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    if (_schoolController.text.trim().isEmpty || _startDate == null) {
      setState(() => _errorText = 'School/University and Start Date are required.');
      return;
    }
    if (!_stillStudying && _endDate == null) {
      setState(() => _errorText = 'Add an end date, or check "I am still studying here".');
      return;
    }

    final programme = [
      _degreeController.text.trim(),
      _fieldOfStudyController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' - ');

    // Local-only now — this entry goes out with everything else at Step
    // 4's "Complete Profile", not on its own. Nothing to await, nothing
    // that can fail here.
    ref.read(profileSetupProvider.notifier).addEducationEntry(
          EducationEntry(
            school: _schoolController.text.trim(),
            programme: programme.isEmpty ? 'Not specified' : programme,
            startYear: _startDate!.year.toString(),
            endYear: _stillStudying ? null : _endDate!.year.toString(),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormModalShell(
      icon: Icons.school_outlined,
      title: 'Add Education History',
      onCancel: () => Navigator.of(context).pop(),
      onPrimaryPressed: _submit,
      primaryLabel: 'Add to Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('SCHOOL/UNIVERSITY', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _schoolController,
            decoration: authInputDecoration(hint: 'e.g Obafemi Awolowo University'),
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEGREE', style: authLabelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _degreeController,
                      decoration: authInputDecoration(hint: 'e.g Business Admin.'),
                      style: const TextStyle(color: BrandColors.navy),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FIELD OF STUDY', style: authLabelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _fieldOfStudyController,
                      // ASSUMPTION: the mock's hint text here is cut off
                      // ("e.g Business Admin...") and reads identically to
                      // the Degree field's hint — almost certainly a
                      // different example in the real design. Using a
                      // distinct placeholder rather than guessing wrong.
                      decoration: authInputDecoration(hint: 'e.g UI/UX Design'),
                      style: const TextStyle(color: BrandColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('START DATE', style: authLabelStyle),
                    const SizedBox(height: 6),
                    _DateField(
                      label: _startDate == null ? '' : _formatDate(_startDate!),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('END DATE', style: authLabelStyle),
                    const SizedBox(height: 6),
                    _DateField(
                      label: _endDate == null ? '' : _formatDate(_endDate!),
                      enabled: !_stillStudying,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: _stillStudying,
                  activeColor: BrandColors.orange,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    _stillStudying = v ?? false;
                    if (_stillStudying) _endDate = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              const Text('I am still studying here', style: TextStyle(fontSize: 12.5, color: BrandColors.muted)),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap, this.enabled = true});

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: authInputDecoration(hint: '').copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: BrandColors.navy),
          filled: !enabled,
          fillColor: BrandColors.iconBg,
        ),
        child: Text(
          label.isEmpty ? 'dd/mm/yyyy' : label,
          style: TextStyle(
            fontSize: 13.5,
            color: label.isEmpty ? BrandColors.navy.withValues(alpha: 0.4) : BrandColors.navy,
          ),
        ),
      ),
    );
  }
}