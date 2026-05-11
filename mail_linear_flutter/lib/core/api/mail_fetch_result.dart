part of 'mail_api.dart';

class MailApiException implements Exception {
  const MailApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MailFetchResult {
  const MailFetchResult({
    required this.mails,
    required this.protocol,
    required this.cached,
    required this.partialCached,
    required this.warning,
    required this.newCount,
    this.trace = const {},
  });

  final List<MailItem> mails;
  final String protocol;
  final bool cached;
  final bool partialCached;
  final String warning;
  final int newCount;
  final Map<String, dynamic> trace;

  String get sourceLabel {
    final normalized = protocol.toLowerCase();
    if (normalized == 'cache') return '本地缓存';
    final source = switch (normalized) {
      'graph' => 'Graph',
      'imap' => 'IMAP',
      'outlook' => 'Outlook',
      'claw' => 'Claw',
      'claw-cache' => 'Claw',
      _ => protocol.toUpperCase(),
    };
    if (partialCached) return '$source 实时/缓存混合';
    return cached ? '$source 缓存' : '$source 实时';
  }

  String get traceSummary {
    if (trace.isEmpty) return '';
    final source = trace['source']?.toString() ?? protocol;
    final mailbox = trace['selectedMailbox']?.toString() ?? '';
    final resultCount = (trace['resultCount'] as num?)?.toInt();
    final cacheBefore = (trace['cacheBefore'] as num?)?.toInt();
    final cacheAfter = (trace['cacheAfter'] as num?)?.toInt();
    final containsNewest = trace['cacheContainsNewest'];
    final bodylessCache = (trace['bodylessCacheCount'] as num?)?.toInt();
    final parts = <String>[
      '诊断：$source${mailbox.isEmpty ? '' : ' / $mailbox'}',
      if (resultCount != null) '返回 $resultCount 封',
      if (cacheBefore != null && cacheAfter != null)
        '缓存 $cacheBefore->$cacheAfter',
      '新增 $newCount 封',
      if (containsNewest == false) '最新邮件未进入缓存',
      if (bodylessCache != null && bodylessCache > 0) '空正文 $bodylessCache 封',
    ];
    return parts.join('，');
  }
}
