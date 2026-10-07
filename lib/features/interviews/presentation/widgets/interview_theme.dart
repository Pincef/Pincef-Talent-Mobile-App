import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/interview_repository.dart';

const ivNavy = Color(0xFF10163D);
const ivOrange = Color(0xFFFF6818);
const ivMuted = Color(0xFF657188);
const ivBorder = Color(0xFFE2E8F0);
const ivCanvas = Color(0xFFF6F8FB);
const ivGreen = Color(0xFF14A878);
const ivSoft = Color(0xFFF2F4F7);
const ivRed = Color(0xFFD92D20);

const _roundPalette = [
  Color(0xFFFF7C37),
  Color(0xFF7560D8),
  Color(0xFF4287E9),
  Color(0xFF26A879),
  Color(0xFF10163D),
  Color(0xFF52647B),
];

/// roundName is free text on the backend, so colours are derived from it
/// (stable across launches) instead of a fixed Tech/Portfolio/Final enum.
Color roundColor(String name) {
  var sum = 0;
  for (final u in name.trim().toLowerCase().codeUnits) {
    sum = (sum * 31 + u) & 0x7fffffff;
  }
  return _roundPalette[sum % _roundPalette.length];
}

final _timeFmt = DateFormat('h:mm a');
String fmtTime(DateTime d) => _timeFmt.format(d);
String fmtRange(DateTime a, DateTime b) => '${fmtTime(a)} – ${fmtTime(b)}';
String fmtDay(DateTime d) => DateFormat('EEE, MMM d').format(d);
String fmtLong(DateTime d) => DateFormat('EEEE, MMM d, y').format(d);

/// e.g. "UTC+01:00" — the real device offset, not a hardcoded "PST".
String utcLabel() {
  final o = DateTime.now().timeZoneOffset;
  final abs = o.abs();
  final hh = abs.inHours.toString().padLeft(2, '0');
  final mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return 'UTC${o.isNegative ? '−' : '+'}$hh:$mm';
}

String errorMessage(Object e) => e is InterviewException
    ? e.message
    : 'Something went wrong. Please try again.';

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

Widget ivTag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .2)),
    );

class IvAvatar extends StatelessWidget {
  const IvAvatar({super.key, required this.name, this.url, this.radius = 18});
  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4E7EC),
      foregroundImage: hasUrl ? NetworkImage(url!) : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: Text(initials(name),
          style: TextStyle(
              color: ivNavy,
              fontSize: radius * .7,
              fontWeight: FontWeight.w700)),
    );
  }
}
