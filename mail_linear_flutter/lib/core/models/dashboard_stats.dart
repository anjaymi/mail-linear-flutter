import 'mail_item.dart';

class DashboardStats {
  const DashboardStats({
    required this.totalAccounts,
    required this.activeAccounts,
    required this.totalInboxMails,
    required this.errorAccounts,
    required this.recentMails,
  });

  final int totalAccounts;
  final int activeAccounts;
  final int totalInboxMails;
  final int errorAccounts;
  final List<MailItem> recentMails;

  factory DashboardStats.empty() => const DashboardStats(
    totalAccounts: 0,
    activeAccounts: 0,
    totalInboxMails: 0,
    errorAccounts: 0,
    recentMails: [],
  );

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final recent = (json['recentMails'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MailItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return DashboardStats(
      totalAccounts: (json['totalAccounts'] as num?)?.toInt() ?? 0,
      activeAccounts: (json['activeAccounts'] as num?)?.toInt() ?? 0,
      totalInboxMails: (json['totalInboxMails'] as num?)?.toInt() ?? 0,
      errorAccounts: (json['errorAccounts'] as num?)?.toInt() ?? 0,
      recentMails: recent,
    );
  }
}
