import 'package:flutter/material.dart';

/// Below this width, use the mobile layout (bottom nav, stacked single column).
/// At or above it, use the desktop/web layout (persistent sidebar, multi-column).
const double kMobileBreakpoint = 900;

bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= kMobileBreakpoint;
