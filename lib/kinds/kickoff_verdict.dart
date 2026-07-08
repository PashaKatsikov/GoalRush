/// Parsed response from the gate (config) endpoint.
///
/// Wire format from the backend is `{ ok, url, expires, message }`.
/// The fields are renamed here for readability but the JSON keys are
/// preserved verbatim so the backend contract is untouched.
class KickoffVerdict {
  const KickoffVerdict({
    required this.granted,
    this.contentUrl,
    this.diagnostic,
    this.expiresAt,
  });

  /// Backend `ok` — true means show the WebView with [contentUrl].
  final bool granted;

  /// Backend `url` — the content URL to display.
  final String? contentUrl;

  /// Backend `message` — diagnostic note (e.g. "organic").
  final String? diagnostic;

  /// Backend `expires` — unix seconds after which [contentUrl] should
  /// be refreshed via a new gate request.
  final int? expiresAt;

  factory KickoffVerdict.fromMap(Map<String, dynamic> map) {
    return KickoffVerdict(
      granted: map['ok'] as bool? ?? false,
      contentUrl: map['url'] as String?,
      diagnostic: map['message'] as String?,
      expiresAt: map['expires'] as int?,
    );
  }

  factory KickoffVerdict.rejected(String reason) =>
      KickoffVerdict(granted: false, diagnostic: reason);

  bool get hasUrl => contentUrl != null && contentUrl!.isNotEmpty;
}
