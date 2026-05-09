import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/local_api_controller.dart';
import '../core/api/mail_api.dart';
import '../core/localization/app_localizations.dart';
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
  AppLanguage language = AppLanguage.zhHans;
  AppStrings get text => AppStrings.of(language);
  Timer? _autoReceiveTimer;
  bool _autoReceiveRunning = false;

  Future<void> boot() async {
    loading = true;
    error = '';
    language = AppLanguage.fromCode(await _prefs.loadLanguageCode());
    lifecycle = text.bootingApi;
    notifyListeners();
    try {
      autoReceiveEnabled = await _prefs.loadAutoReceiveEnabled();
      autoReceiveMinutes = await _prefs.loadAutoReceiveMinutes();
      soundEnabled = await _prefs.loadSoundEnabled();
      soundTone = await _prefs.loadSoundTone();
      serverUrl = await _controller.start();
      _api = MailApi(serverUrl);
      loading = false;
      lifecycle = text.loadingAccounts;
      notifyListeners();
      await refresh();
      _syncAutoReceiveTimer();
      if (autoReceiveEnabled) unawaited(_autoReceiveTick());
    } catch (ex) {
      error = ex.toString();
      loading = false;
    } finally {
      lifecycle = error.isEmpty ? text.ready : text.needsAttention;
      notifyListeners();
    }
  }

  Future<void> refresh({bool loadSelectedMail = false}) async {
    final api = _requireApi();
    error = '';
    lifecycle = text.refreshingData;
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
      lifecycle = text.ready;
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.refreshFailed;
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
    lifecycle = text.fetchingMail;
    notifyListeners();
    try {
      final result = await _requireApi().fetchMails(account.id);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      stats = await _requireApi().dashboard();
      if (openMail) page = AppPage.mail;
      mailSource = result.sourceLabel;
      mailWarning = result.warning;
      await _playMailSoundIfNeeded(result.newCount > 0);
      lifecycle = mails.isEmpty ? text.noNewMail : text.fetchDone;
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.fetchFailed;
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
    lifecycle = text.batchFetching;
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
          await _playMailSoundIfNeeded(result.newCount > 0);
        }
      }
      stats = await _requireApi().dashboard();
      page = AppPage.mail;
      lifecycle = text.batchFetchDone;
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.batchFetchFailed;
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
    lifecycle = text.fetchingClawMail;
    notifyListeners();
    try {
      final result = await _requireApi().clawMails(mailbox: email, sync: true);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      stats = await _requireApi().clawStats();
      mailSource = result.sourceLabel;
      mailWarning = result.warning;
      if (openMail) page = AppPage.mail;
      await _playMailSoundIfNeeded(result.newCount > 0);
      lifecycle = mails.isEmpty ? text.clawNoNewMail : text.clawFetchDone;
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.clawFetchFailed;
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
    lifecycle = text.deletedAccounts(deleted);
    notifyListeners();
    return deleted;
  }

  Future<String> importAccounts(String content) async {
    error = '';
    lifecycle = text.importingAccounts;
    notifyListeners();
    try {
      final result = await _requireApi().importAccounts(content);
      await refresh();
      final imported = (result['imported'] as num?)?.toInt() ?? 0;
      final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
      final errors = (result['errors'] as List? ?? []).length;
      lifecycle = text.importDone;
      return text.importResult(imported, skipped, errors);
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.importFailed;
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
    lifecycle = text.accountDeleted;
    notifyListeners();
  }

  Future<void> setAccountMarker(int id, String color) async {
    _replaceAccountMarker(id, color);
    lifecycle = text.markerUpdated;
    notifyListeners();
    try {
      await _requireApi().setAccountMarker(id, color);
      await refresh();
    } catch (ex) {
      final message = ex.toString();
      await refresh();
      error = message;
      lifecycle = text.refreshFailed;
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage next) async {
    if (language == next) return;
    language = next;
    await _prefs.saveLanguageCode(next.code);
    lifecycle = text.ready;
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
    if (enabled) unawaited(_autoReceiveTick());
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
    if (_autoReceiveRunning || fetching || loading || _api == null) return;
    _autoReceiveRunning = true;
    try {
      if (mode == WorkMode.claw) {
        await _autoReceiveClaw();
        return;
      }
      await _autoReceiveOutlook();
    } finally {
      _autoReceiveRunning = false;
    }
  }

  Future<void> _autoReceiveClaw() async {
    if (mode == WorkMode.claw) {
      if (selectedClawMailbox == null) {
        await refresh();
        if (selectedClawMailbox == null) return;
      }
      await fetchSelectedClawMail(openMail: false);
    }
  }

  Future<void> _autoReceiveOutlook() async {
    if (selectedAccount == null) {
      await refresh();
    }
    final targets = _autoReceiveTargets();
    if (targets.isEmpty) return;

    lifecycle = text.ui('自动接收中');
    notifyListeners();

    var newCount = 0;
    var checked = 0;
    var failed = 0;
    MailFetchResult? selectedResult;

    for (final account in targets) {
      try {
        final result = await _requireApi().fetchMails(account.id);
        checked += 1;
        newCount += result.newCount;
        if (selectedAccount?.id == account.id) {
          selectedResult = result;
        }
      } catch (_) {
        failed += 1;
      }
    }

    if (selectedResult != null) {
      mails = selectedResult.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      mailSource = selectedResult.sourceLabel;
      mailWarning = selectedResult.warning;
    }

    try {
      stats = await _requireApi().dashboard();
    } catch (_) {}

    if (newCount > 0) {
      await _playMailSoundIfNeeded(true);
    }
    lifecycle = failed == 0
        ? text.autoReceiveDone(checked, newCount)
        : text.autoReceivePartial(checked, failed, newCount);
    notifyListeners();
  }

  List<MailAccount> _autoReceiveTargets() {
    final active = accounts
        .where((account) => account.status.toLowerCase() != 'error')
        .toList();
    final selected = selectedAccount;
    if (selected == null) return active;
    active.sort((a, b) {
      if (a.id == selected.id) return -1;
      if (b.id == selected.id) return 1;
      return b.id.compareTo(a.id);
    });
    return active;
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

  void _replaceAccountMarker(int id, String color) {
    accounts = [
      for (final account in accounts)
        account.id == id ? account.copyWith(markerColor: color) : account,
    ];
    final selected = selectedAccount;
    if (selected != null && selected.id == id) {
      selectedAccount = selected.copyWith(markerColor: color);
    }
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
    if (api == null) throw Exception(text.localApiNotStarted);
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
