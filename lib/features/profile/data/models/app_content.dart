class AppContent {
  const AppContent({
    required this.key,
    required this.title,
    required this.body,
  });

  final String key;
  final String title;
  final String body;

  bool get isHtml => _looksLikeHtml(body);

  factory AppContent.fromJson(
    Map<String, dynamic> json, {
    required String fallbackKey,
    String fallbackTitle = '',
  }) {
    return AppContent(
      key: _readString(json['key'] ?? json['policy_key']) ?? fallbackKey,
      title: _readString(
            json['title'] ??
                json['name'] ??
                json['label'] ??
                json['heading'],
          ) ??
          fallbackTitle,
      body: _readBody(json),
    );
  }

  static String _readBody(Map<String, dynamic> json) {
    final html = _readString(
      json['html'] ??
          json['content_html'] ??
          json['policy_html'] ??
          json['html_content'],
    );
    if (html != null && html.isNotEmpty) return html;

    final direct = _readString(
      json['content'] ??
          json['body'] ??
          json['value'] ??
          json['policy_value'] ??
          json['description'] ??
          json['text'],
    );
    if (direct != null && direct.isNotEmpty) return direct;

    final sections = json['sections'];
    if (sections is List) {
      final parts = <String>[];
      for (final section in sections) {
        if (section is! Map) continue;
        final map = section.map((key, value) => MapEntry(key.toString(), value));
        final title = _readString(map['title'] ?? map['heading']);
        final content = _readString(
          map['html'] ??
              map['content'] ??
              map['body'] ??
              map['text'],
        );
        if (title != null && title.isNotEmpty && !_looksLikeHtml(title)) {
          parts.add('<h3>$title</h3>');
        }
        if (content != null && content.isNotEmpty) parts.add(content);
      }
      if (parts.isNotEmpty) return parts.join('');
    }

    return '';
  }

  static bool _looksLikeHtml(String value) {
    return RegExp(r'<[^>]+>').hasMatch(value);
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
