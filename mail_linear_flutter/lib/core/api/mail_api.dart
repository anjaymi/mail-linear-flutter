import 'dart:convert';
import 'dart:io';

import '../models/dashboard_stats.dart';
import '../models/mail_account.dart';
import '../models/mail_item.dart';

part 'mail_fetch_result.dart';

class MailApi {
  MailApi(this.baseUrl);

  final String baseUrl;
  final HttpClient _client = HttpClient();
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const Duration _checkTimeout = Duration(milliseconds: 700);

  Future<bool> check() async {
    try {
      await _get('/api/auth/check', timeout: _checkTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DashboardStats> dashboard() async {
    return DashboardStats.fromJson(await _get('/api/dashboard/stats'));
  }

  Future<List<MailAccount>> accounts({String search = ''}) async {
    final query = search.trim().isEmpty
        ? ''
        : '&search=${Uri.encodeQueryComponent(search)}';
    final data = await _get('/api/accounts?page=1&pageSize=200$query');
    return (data['list'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MailAccount.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<MailItem>> cachedMails(int accountId) async {
    final data = await _get(
      '/api/mails/cached?account_id=$accountId&pageSize=100&mailbox=all',
    );
    return (data['list'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MailItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<MailFetchResult> fetchMails(int accountId) async {
    final data = await _post('/api/mails/fetch', {
      'account_id': accountId,
      'mailbox': 'all',
      'top': 100,
    });
    final mails = (data['mails'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MailItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return MailFetchResult(
      mails: mails,
      protocol: data['protocol']?.toString() ?? 'outlook',
      cached: data['cached'] == true,
      partialCached: data['partialCached'] == true,
      warning: _combinedWarning([data['warning'], data['graphWarning']]),
      newCount: (data['savedCount'] as num?)?.toInt() ?? 0,
      trace: _mapOf(data['trace']),
    );
  }

  Future<int> batchDeleteAccounts(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final data = await _post('/api/accounts/batch-delete', {'ids': ids});
    return (data['deleted'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> checkAccounts(List<int> ids) {
    return _post('/api/accounts/check', {'ids': ids, 'limit': ids.length});
  }

  Future<Map<String, dynamic>> importAccounts(String content) {
    return _post('/api/accounts/import', {
      'content': content,
      'separator': '----',
      'format': ['email', 'password', 'client_id', 'refresh_token'],
    });
  }

  Future<void> deleteAccount(int id) async {
    await _delete('/api/accounts/$id');
  }

  Future<void> setAccountMarker(int id, String color) async {
    await _post('/api/accounts/$id/marker', {'color': color});
  }

  Future<Map<String, dynamic>> startBrowserLogin({
    required String clientId,
    required String redirectUri,
  }) {
    return _post('/api/oauth/browser/start', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
    });
  }

  Future<Map<String, dynamic>> pollBrowserLogin(String state) {
    return _post('/api/oauth/browser/poll', {'state': state});
  }

  Future<Map<String, dynamic>> databaseHealth() {
    return _get('/api/database/health');
  }

  Future<Map<String, dynamic>> databaseRepair({required bool dryRun}) {
    return _post('/api/database/repair', {'dryRun': dryRun});
  }

  Future<Map<String, dynamic>> databaseOptimize() {
    return _post('/api/database/optimize', {});
  }

  Future<DashboardStats> clawStats() async {
    return DashboardStats.fromJson(await _get('/api/claw/stats'));
  }

  Future<Map<String, dynamic>> clawStatus() {
    return _get('/api/claw/status');
  }

  Future<List<Map<String, dynamic>>> clawMailboxes({bool sync = false}) async {
    final data = await _get('/api/claw/mailboxes${sync ? '?sync=true' : ''}');
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<MailFetchResult> clawMails({
    required String mailbox,
    bool sync = false,
  }) async {
    final data = await _get(
      '/api/claw/mails?mailbox=${Uri.encodeQueryComponent(mailbox)}'
      '&page=1&pageSize=100${sync ? '&sync=true' : ''}',
    );
    final mails = (data['list'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MailItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final syncInfo = data['sync'] is Map
        ? Map<String, dynamic>.from(data['sync'] as Map)
        : <String, dynamic>{};
    return MailFetchResult(
      mails: mails,
      protocol: sync ? 'claw' : 'claw-cache',
      cached: !sync,
      partialCached: false,
      warning: _combinedWarning([syncInfo['message']]),
      newCount: (syncInfo['savedCount'] as num?)?.toInt() ?? 0,
      trace: syncInfo,
    );
  }

  Map<String, dynamic> _mapOf(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _combinedWarning(Iterable<Object?> values) {
    final parts = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final message = value?.toString() ?? '';
      for (final line in message.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !seen.add(trimmed)) continue;
        parts.add(trimmed);
      }
    }
    return parts.join('\n');
  }

  Future<void> clawSendCode(String email) async {
    await _post('/api/claw/auth/send-code', {'email': email});
  }

  Future<void> clawVerifyCode(String email, String code) async {
    await _post('/api/claw/auth/verify-code', {'email': email, 'code': code});
  }

  Future<void> clawRefreshAuth() async {
    await _post('/api/claw/auth/refresh', {});
  }

  Future<void> clawCreateMailbox(String suffix) async {
    await _post('/api/claw/mailboxes', {'suffix': suffix});
  }

  void close() => _client.close(force: true);

  Future<Map<String, dynamic>> _get(
    String path, {
    Duration timeout = _requestTimeout,
  }) async {
    final request = await _client
        .getUrl(Uri.parse('$baseUrl$path'))
        .timeout(timeout);
    return _unwrap(await request.close().timeout(timeout));
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final request = await _client
        .postUrl(Uri.parse('$baseUrl$path'))
        .timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return _unwrap(await request.close().timeout(_requestTimeout));
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final request = await _client
        .deleteUrl(Uri.parse('$baseUrl$path'))
        .timeout(_requestTimeout);
    return _unwrap(await request.close().timeout(_requestTimeout));
  }

  Future<Map<String, dynamic>> _unwrap(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final envelope = jsonDecode(text) as Map<String, dynamic>;
    if ((envelope['code'] as num?)?.toInt() != 200) {
      throw MailApiException(
        envelope['message']?.toString() ?? 'API request failed',
      );
    }
    final data = envelope['data'];
    return data is Map<String, dynamic> ? data : {'value': data};
  }
}
