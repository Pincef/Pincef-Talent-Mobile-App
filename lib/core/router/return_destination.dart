/// Accepts only an internal public job URL as an auth return destination.
/// This prevents a crafted `returnTo` query from becoming an open redirect.
String? safeSharedJobDestination(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length != 3 ||
      segments[0] != 'shared' ||
      segments[1] != 'jobs' ||
      !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(segments[2])) {
    return null;
  }
  return '/shared/jobs/${segments[2]}';
}
