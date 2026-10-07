import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/form_shell.dart';
import '../../application/profile_setup_provider.dart';
import '../../data/models/profile_setup_models.dart';

const _employmentTypes = [
  'Full-time',
  'Part-time',
  'Contract',
  'Internship',
  'Freelance'
];

/// Opened from the "+ Add Experience" button on the Experience &
/// Verification step. Mirrors education_history_modal.dart's shape —
/// same local-only-until-submit pattern, same date-field/checkbox layout.
class WorkExperienceModal extends ConsumerStatefulWidget {
  const WorkExperienceModal({super.key});

  @override
  ConsumerState<WorkExperienceModal> createState() =>
      _WorkExperienceModalState();
}

class _WorkExperienceModalState extends ConsumerState<WorkExperienceModal> {
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  String? _employmentType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _currentlyWorkHere = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
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
    if (_titleController.text.trim().isEmpty ||
        _companyController.text.trim().isEmpty ||
        _employmentType == null ||
        _startDate == null) {
      setState(() => _errorText =
          'Job Title, Company, Employment Type, and Start Date are required.');
      return;
    }
    if (!_currentlyWorkHere && _endDate == null) {
      setState(() =>
          _errorText = 'Add an end date, or check "I currently work here".');
      return;
    }

    ref.read(profileSetupProvider.notifier).addWorkExperience(
          WorkExperienceEntry(
            title: _titleController.text.trim(),
            company: _companyController.text.trim(),
            employmentType: _employmentType!,
            startYear: _startDate!.year.toString(),
            endYear: _currentlyWorkHere ? null : _endDate!.year.toString(),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormModalShell(
      icon: Icons.work_outline,
      title: 'Add Experience',
      onCancel: () => Navigator.of(context).pop(),
      onPrimaryPressed: _submit,
      primaryLabel: 'Add to Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('JOB TITLE', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleController,
            decoration:
                authInputDecoration(hint: 'e.g Senior Product Designer'),
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
                    const Text('COMPANY', style: authLabelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _companyController,
                      decoration: authInputDecoration(hint: 'e.g Acme Corp'),
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
                    const Text('EMPLOYMENT TYPE', style: authLabelStyle),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _employmentType,
                      dropdownColor: Colors.white,
                      decoration: authInputDecoration(hint: 'Select Type'),
                      style: const TextStyle(
                          color: BrandColors.navy, fontSize: 13.5),
                      items: _employmentTypes
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _employmentType = v),
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
                      enabled: !_currentlyWorkHere,
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
                  value: _currentlyWorkHere,
                  activeColor: BrandColors.orange,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    _currentlyWorkHere = v ?? false;
                    if (_currentlyWorkHere) _endDate = null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              const Text('I currently work here',
                  style: TextStyle(fontSize: 12.5, color: BrandColors.muted)),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(_errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.onTap, this.enabled = true});

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
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 16, color: BrandColors.navy),
          filled: !enabled,
          fillColor: BrandColors.iconBg,
        ),
        child: Text(
          label.isEmpty ? 'dd/mm/yyyy' : label,
          style: TextStyle(
            fontSize: 13.5,
            color: label.isEmpty
                ? BrandColors.navy.withValues(alpha: 0.4)
                : BrandColors.navy,
          ),
        ),
      ),
    );
  }
}
