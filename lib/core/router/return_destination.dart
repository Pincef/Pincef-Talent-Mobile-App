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

/// Repairs legacy share links that placed the job route in the URL path but
/// left the current Flutter hash route attached (for example `#/jobs`).
String? legacySharedJobDestination(Uri browserUri) {
  final match =
      RegExp(r'^/shared/jobs/([a-fA-F0-9]{24})/?$').firstMatch(browserUri.path);
  if (match == null || browserUri.fragment.startsWith('/shared/jobs/')) {
    return null;
  }
  return '/shared/jobs/${match.group(1)}';
}

/// Builds an external URL using Flutter's default hash based web routing.
Uri sharedJobUrl(Uri currentUri, String jobId) => Uri(
      scheme: currentUri.scheme,
      userInfo: currentUri.userInfo,
      host: currentUri.host,
      port: currentUri.hasPort ? currentUri.port : null,
      path: '/',
      fragment: '/shared/jobs/$jobId',
    );
