import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/local_api_controller.dart';
import '../core/api/mail_api.dart';
import '../core/models/dashboard_stats.dart';
import '../core/models/mail_account.dart';
import '../core/models/mail_item.dart';
import '../core/platform/sound_service.dart';
import '../core/preferences/app_preferences.dart';

enum AppPage { dashboard, accounts, mail, claw, settings }

enum WorkMode { outlook, claw }

class AppState extends ChangeNotifier {
  final LocalApiController _controller = LocalApiController();
  final AppPreferences _prefs = AppPreferences();
  MailApi? _api;
  MailApi? get api => _api;

  AppPage page = AppPage.dashboard;
  WorkMode mode = WorkMode.outlook;
  DashboardStats stats = DashboardStats.empty();
  List<MailAccount> accounts = [];
  List<Map<String, dynamic>> clawMailboxes = [];
  List<MailItem> mails = [];
  MailAccount? selectedAccount;
  Map<String, dynamic>? selectedClawMailbox;
  MailItem? selectedMail;
  String serverUrl = 'starting';
  String error = '';
  bool loading = true;
  bool fetching = false;
  String lifecycle = '正在启动本地 API';
  String mailSource = '缓存';
  String mailWarning = '';
  bool soundEnabled = true;
  String soundTone = 'mail';
  bool autoReceiveEnabled = false;
  int autoReceiveMinutes = 5;
  Timer? _autoReceiveTimer;

  Future<void> boot() async {
    loading = true;
    error = '';
    lifecycle = '正在启动本地 API';
    notifyListeners();
    try {
      autoReceiveEnabled = await _prefs.loadAutoReceiveEnabled();
      autoReceiveMinutes = await _prefs.loadAutoReceiveMinutes();
      soundEnabled = await _prefs.loadSoundEnabled();
      soundTone = await _prefs.loadSoundTone();
      serverUrl = await _controller.start();
      _api = MailApi(serverUrl);
      loading = false;
      lifecycle = '正在载入账号';
      notifyListeners();
      await refresh();
      _syncAutoReceiveTimer();
    } catch (ex) {
      error = ex.toString();
      loading = false;
    } finally {
      lifecycle = error.isEmpty ? '就绪' : '需要处理';
      notifyListeners();
    }
  }

  Future<void> refresh({bool loadSelectedMail = false}) async {
    final api = _requireApi();
    error = '';
    lifecycle = '正在刷新数据';
    notifyListeners();
    try {
      if (mode == WorkMode.claw) {
        final result = await Future.wait<Object>([
          api.clawStats(),
          api.clawMailboxes(),
        ]);
        stats = result[0] as DashboardStats;
        clawMailboxes = result[1] as List<Map<String, dynamic>>;
        selectedClawMailbox = _resolveSelectedClawMailbox();
        selectedAccount = null;
        accounts = [];
        mails = [];
        selectedMail = null;
      } else {
        final result = await Future.wait<Object>([
          api.dashboard(),
          api.accounts(),
        ]);
        stats = result[0] as DashboardStats;
        accounts = result[1] as List<MailAccount>;
        selectedAccount = _resolveSelectedAccount();
        selectedClawMailbox = null;
        clawMailboxes = [];
      }
      if (loadSelectedMail) {
        if (mode == WorkMode.outlook && selectedAccount != null) {
          await loadCachedMails(selectedAccount!);
        } else if (mode == WorkMode.claw && selectedClawMailbox != null) {
          await loadCachedClawMails(selectedClawMailbox!);
        }
      }
      lifecycle = '就绪';
    } catch (ex) {
      error = ex.toString();
      lifecycle = '刷新失败';
    }
    notifyListeners();
  }

  Future<void> selectAccount(
    MailAccount account, {
    bool openMail = true,
  }) async {
    selectedAccount = account;
    if (openMail) page = AppPage.mail;
    notifyListeners();
    await loadCachedMails(account);
  }

  Future<void> loadCachedMails(MailAccount account) async {
    error = '';
    try {
      mails = await _requireApi().cachedMails(account.id);
      selectedMail = mails.isEmpty ? null : mails.first;
    } catch (ex) {
      error = ex.toString();
    }
    notifyListeners();
  }

  Future<void> fetchSelectedMail() async {
    if (mode == WorkMode.claw) {
      await fetchSelectedClawMail(openMail: true);
      return;
    }
    await _fetchSelectedMail(openMail: true);
  }

  Future<void> _fetchSelectedMail({required bool openMail}) async {
    final account = selectedAccount;
    if (account == null) return;
    fetching = true;
    error = '';
    lifecycle = '正在收取邮件';
    notifyListeners();
    try {
      final result = await _requireApi().fetchMails(account.id);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      stats = await _requireApi().dashboard();
      if (openMail) page = AppPage.mail;
      mailSource = result.sourceLabel;
      mailWarning = result.warning;
      await _playMailSoundIfNeeded(mails.isNotEmpty);
      lifecycle = mails.isEmpty ? '无新邮件' : '收取完成';
    } catch (ex) {
      error = ex.toString();
      lifecycle = '收取失败';
    } finally {
      fetching = false;
      notifyListeners();
    }
  }

  Future<void> fetchAccounts(List<int> ids) async {
    final targets = ids.map(_accountById).whereType<MailAccount>().toList();
    if (targets.isEmpty) return;
    fetching = true;
    error = '';
    lifecycle = '正在批量收取';
    notifyListeners();
    try {
      for (final account in targets) {
        final result = await _requireApi().fetchMails(account.id);
        if (account.id == targets.last.id) {
          selectedAccount = account;
          mails = result.mails;
          selectedMail = mails.isEmpty ? null : mails.first;
          mailSource = result.sourceLabel;
          mailWarning = result.warning;
          await _playMailSoundIfNeeded(mails.isNotEmpty);
        }
      }
      stats = await _requireApi().dashboard();
      page = AppPage.mail;
      lifecycle = '批量收取完成';
    } catch (ex) {
      error = ex.toString();
      lifecycle = '批量收取失败';
    } finally {
      fetching = false;
      notifyListeners();
    }
  }

  Future<void> fetchSelectedClawMail({bool openMail = true}) async {
    final mailbox = selectedClawMailbox;
    if (mailbox == null) return;
    final email = clawMailboxEmail(mailbox);
    if (email.isEmpty) return;
    fetching = true;
    error = '';
    lifecycle = '正在收取 Claw 邮件';
    notifyListeners();
    try {
      final result = await _requireApi().clawMails(mailbox: email, sync: true);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      stats = await _requireApi().clawStats();
      mailSource = result.sourceLabel;
      mailWarning = result.warning;
      if (openMail) page = AppPage.mail;
      await _playMailSoundIfNeeded(mails.isNotEmpty);
      lifecycle = mails.isEmpty ? 'Claw 无新邮件' : 'Claw 收取完成';
    } catch (ex) {
      error = ex.toString();
      lifecycle = 'Claw 收取失败';
    } finally {
      fetching = false;
      notifyListeners();
    }
  }

  Future<void> loadCachedClawMails(Map<String, dynamic> mailbox) async {
    final email = clawMailboxEmail(mailbox);
    if (email.isEmpty) return;
    selectedClawMailbox = mailbox;
    error = '';
    try {
      final result = await _requireApi().clawMails(mailbox: email);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      mailSource = result.sourceLabel;
      mailWarning = result.warning;
    } catch (ex) {
      error = ex.toString();
    }
    notifyListeners();
  }

  void setPage(AppPage next) {
    if (mode == WorkMode.outlook && next == AppPage.claw) {
      mode = WorkMode.claw;
      _clearOutlookSelection();
      unawaited(refresh());
    }
    page = next;
    notifyListeners();
  }

  void setMode(WorkMode next) {
    if (mode == next) return;
    mode = next;
    if (next == WorkMode.claw && page != AppPage.claw) {
      page = AppPage.dashboard;
      _clearOutlookSelection();
    }
    if (next == WorkMode.outlook && page == AppPage.claw) {
      page = AppPage.dashboard;
      selectedClawMailbox = null;
      clawMailboxes = [];
    }
    notifyListeners();
    unawaited(refresh());
  }

  void selectClawMailbox(Map<String, dynamic> mailbox) {
    selectedClawMailbox = mailbox;
    notifyListeners();
  }

  String clawMailboxEmail(Map<String, dynamic> mailbox) {
    return mailbox['email']?.toString() ??
        mailbox['address']?.toString() ??
        mailbox['mailbox']?.toString() ??
        '';
  }

  void selectMail(MailItem mail) {
    selectedMail = mail;
    notifyListeners();
  }

  Future<void> openCachedMail(MailItem mail) async {
    selectedMail = mail;
    page = AppPage.mail;
    if (mail.accountId == 0 && mail.mailboxEmail.isNotEmpty) {
      if (mode != WorkMode.claw) mode = WorkMode.claw;
      if (clawMailboxes.isEmpty) {
        try {
          clawMailboxes = await _requireApi().clawMailboxes();
        } catch (_) {}
      }
      for (final mailbox in clawMailboxes) {
        if (clawMailboxEmail(mailbox) == mail.mailboxEmail) {
          selectedClawMailbox = mailbox;
          break;
        }
      }
      notifyListeners();
      if (selectedClawMailbox == null) return;
      try {
        final result = await _requireApi().clawMails(
          mailbox: mail.mailboxEmail,
        );
        mails = result.mails;
        selectedMail = mails.firstWhere(
          (item) => item.id == mail.id,
          orElse: () => mail,
        );
        mailSource = result.sourceLabel;
        mailWarning = result.warning;
      } catch (ex) {
        error = ex.toString();
      }
      notifyListeners();
      return;
    }
    final account = _accountById(mail.accountId);
    if (account != null) selectedAccount = account;
    notifyListeners();
    if (account == null) return;

    try {
      final cached = await _requireApi().cachedMails(account.id);
      mails = cached;
      selectedMail = cached.firstWhere(
        (item) => item.id == mail.id,
        orElse: () => mail,
      );
    } catch (ex) {
      error = ex.toString();
    }
    notifyListeners();
  }

  Future<int> deleteAccounts(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final deleted = await _requireApi().batchDeleteAccounts(ids);
    accounts = accounts.where((item) => !ids.contains(item.id)).toList();
    if (selectedAccount != null && ids.contains(selectedAccount!.id)) {
      selectedAccount = accounts.isEmpty ? null : accounts.first;
      mails = [];
      selectedMail = null;
    }
    stats = await _requireApi().dashboard();
    lifecycle = '已删除 $deleted 个账号';
    notifyListeners();
    return deleted;
  }

  Future<String> importAccounts(String content) async {
    error = '';
    lifecycle = '正在导入账号';
    notifyListeners();
    try {
      final result = await _requireApi().importAccounts(content);
      await refresh();
      final imported = (result['imported'] as num?)?.toInt() ?? 0;
      final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
      final errors = (result['errors'] as List? ?? []).length;
      lifecycle = '导入完成';
      return '导入 $imported 个，跳过 $skipped 个，错误 $errors 个';
    } catch (ex) {
      error = ex.toString();
      lifecycle = '导入失败';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount(int id) async {
    await _requireApi().deleteAccount(id);
    accounts = accounts.where((item) => item.id != id).toList();
    if (selectedAccount?.id == id) {
      selectedAccount = accounts.isEmpty ? null : accounts.first;
      mails = [];
      selectedMail = null;
    }
    stats = await _requireApi().dashboard();
    lifecycle = '账号已删除';
    notifyListeners();
  }

  Future<void> setAccountMarker(int id, String color) async {
    await _requireApi().setAccountMarker(id, color);
    await refresh();
    lifecycle = '标记已更新';
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    await _prefs.saveSoundEnabled(enabled);
    notifyListeners();
  }

  Future<void> setSoundTone(String tone) async {
    soundTone = SoundService.optionOf(tone).value;
    await _prefs.saveSoundTone(soundTone);
    notifyListeners();
  }

  Future<void> previewSound() async {
    await SoundService.play(soundTone);
  }

  Future<void> setAutoReceiveEnabled(bool enabled) async {
    autoReceiveEnabled = enabled;
    await _prefs.saveAutoReceiveEnabled(enabled);
    _syncAutoReceiveTimer();
    notifyListeners();
  }

  Future<void> setAutoReceiveMinutes(int minutes) async {
    autoReceiveMinutes = minutes.clamp(1, 60);
    await _prefs.saveAutoReceiveMinutes(autoReceiveMinutes);
    _syncAutoReceiveTimer();
    notifyListeners();
  }

  void _syncAutoReceiveTimer() {
    _autoReceiveTimer?.cancel();
    _autoReceiveTimer = null;
    if (!autoReceiveEnabled) return;
    _autoReceiveTimer = Timer.periodic(
      Duration(minutes: autoReceiveMinutes),
      (_) => _autoReceiveTick(),
    );
  }

  Future<void> _autoReceiveTick() async {
    if (fetching || loading || _api == null) return;
    if (mode == WorkMode.claw) {
      if (selectedClawMailbox == null) {
        await refresh();
        if (selectedClawMailbox == null) return;
      }
      await fetchSelectedClawMail(openMail: false);
      return;
    }
    if (selectedAccount == null) {
      await refresh();
      if (selectedAccount == null) return;
    }
    await _fetchSelectedMail(openMail: false);
  }

  Future<void> _playMailSoundIfNeeded(bool hasMail) async {
    if (!soundEnabled || !hasMail) return;
    await SoundService.play(soundTone);
  }

  MailAccount? _resolveSelectedAccount() {
    if (accounts.isEmpty) return null;
    final current = selectedAccount;
    if (current == null) return accounts.first;
    for (final account in accounts) {
      if (account.id == current.id) return account;
    }
    return accounts.first;
  }

  Map<String, dynamic>? _resolveSelectedClawMailbox() {
    if (clawMailboxes.isEmpty) return null;
    final currentEmail = selectedClawMailbox == null
        ? ''
        : clawMailboxEmail(selectedClawMailbox!);
    if (currentEmail.isEmpty) return clawMailboxes.first;
    for (final mailbox in clawMailboxes) {
      if (clawMailboxEmail(mailbox) == currentEmail) return mailbox;
    }
    return clawMailboxes.first;
  }

  void _clearOutlookSelection() {
    selectedAccount = null;
    accounts = [];
    mails = [];
    selectedMail = null;
    mailWarning = '';
    mailSource = 'Claw';
  }

  MailAccount? _accountById(int id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  MailApi _requireApi() {
    final api = _api;
    if (api == null) throw Exception('本地 API 未启动。');
    return api;
  }

  @override
  void dispose() {
    _autoReceiveTimer?.cancel();
    _api?.close();
    _controller.stop();
    super.dispose();
  }
}
