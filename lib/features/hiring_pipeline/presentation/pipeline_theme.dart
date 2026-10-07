import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';

class PT {
  PT._();
  static const ink = Color(0xFF17233D);
  static const muted = Color(0xFF667085);
  static const line = Color(0xFFE5EAF2);
  static const orange = Color(0xFFFF6B18);
  static const blue = Color(0xFF2878E5);
  static const bg = Color(0xFFF7F8FC);
  static const green = Color(0xFF13A66B);
  static const slate = Color(0xFF526079);
  static const softBlue = Color(0xFFEAF1FF);
  static const soft = Color(0xFFF2F5FB);
  static const softOrange = Color(0xFFFFF4EC);
  static const danger = Color(0xFFD92D20);
}

void showSnack(
  BuildContext context,
  String text, {
  AppToastKind kind = AppToastKind.info,
}) {
  AppToast.show(context, text, kind: kind);
}

BoxDecoration cardBox({Color? border, double width = 1, double radius = 11}) =>
    BoxDecoration(
      color: Colors.white,
      border: Border.all(color: border ?? PT.line, width: width),
      borderRadius: BorderRadius.circular(radius),
    );

OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c),
    );

InputDecoration pipelineInput(
        {String? hint, Widget? prefix, String? errorText}) =>
    InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      hintText: hint,
      errorText: errorText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
      prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: _border(PT.line),
      enabledBorder: _border(PT.line),
      disabledBorder: _border(PT.line),
      focusedBorder: _border(PT.blue),
    );

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, this.color, {super.key, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 3)
          ],
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2)),
        ]),
      );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String timeAgo(DateTime t) {
  if (t.millisecondsSinceEpoch == 0) return '—';
  final local = t.toLocal();
  final d = DateTime.now().difference(local);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) {
    return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24) {
    return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  }
  if (d.inDays == 1) return 'Yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}
