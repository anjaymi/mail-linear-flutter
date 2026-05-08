class MailItem {
  const MailItem({
    required this.id,
    required this.accountId,
    required this.subject,
    required this.sender,
    required this.senderName,
    required this.mailboxEmail,
    required this.preview,
    required this.htmlContent,
    required this.date,
  });

  final int id;
  final int accountId;
  final String subject;
  final String sender;
  final String senderName;
  final String mailboxEmail;
  final String preview;
  final String htmlContent;
  final String date;

  factory MailItem.fromJson(Map<String, dynamic> json) {
    final text = _clean(json['text_content']);
    final html = _clean(json['html_content']);
    return MailItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      accountId: (json['account_id'] as num?)?.toInt() ?? 0,
      subject: _clean(json['subject']) == ''
          ? '(无主题)'
          : _clean(json['subject']),
      sender: _clean(json['sender']),
      senderName: _clean(json['sender_name']),
      mailboxEmail: _clean(json['mailbox_email']),
      preview: text.isNotEmpty ? text : _htmlToText(html),
      htmlContent: html,
      date: _clean(json['mail_date'] ?? json['received_at']),
    );
  }

  static String _clean(Object? value) => value?.toString().trim() ?? '';

  static String _htmlToText(String html) {
    if (html.isEmpty) return '';
    final withBreaks = html
        .replaceAll(
          RegExp(
            r'<(br|/p|/div|/li|/tr|/h[1-6])\b[^>]*>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(
          RegExp(
            r'<style\b[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );
    final stripped = withBreaks
        .replaceAll(RegExp(r'<[^>]+>', dotAll: true), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
    return stripped;
  }
}
