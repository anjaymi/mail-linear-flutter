import 'dart:async';

import 'package:flutter/foundation.dart';
import 'dart:ui' show Color;

import '../core/api/local_api_controller.dart';
import '../core/api/mail_api.dart';
import '../core/localization/app_localizations.dart';
import '../core/models/dashboard_stats.dart';
import '../core/models/mail_account.dart';
import '../core/models/mail_item.dart';
import '../core/platform/sound_service.dart';
import '../core/preferences/app_preferences.dart';
import '../core/theme/app_theme.dart';

part 'app_state_accounts.dart';
part 'app_state_claw_mail.dart';
part 'app_state_mail_followup.dart';
part 'app_state_mail_navigation.dart';
part 'app_state_outlook_mail.dart';
part 'app_state_settings.dart';

enum AppPage { mail, settings }

enum WorkMode { outlook, claw }

enum MailFilter { all, codes }

class AppState extends ChangeNotifier {
  final LocalApiController _controller = LocalApiController();
  final AppPreferences _prefs = AppPreferences();
  final Map<int, Future<MailFetchResult>> _outlookFetches = {};
  final Map<int, Timer> _outlookFollowUpTimers = {};
  final Map<int, int> _outlookFollowUpAttempts = {};
  final Set<int> _outlookFollowUpBusy = {};
  bool _initialAccountCheckStarted = false;

  MailApi? _api;
  MailApi? get api => _api;

  AppPage page = AppPage.mail;
  SettingsTab settingsTab = SettingsTab.general;
  WorkMode mode = WorkMode.outlook;
  MailFilter mailFilter = MailFilter.all;
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
  bool checkingAccounts = false;
  String lifecycle = '正在启动本地 API';
  String mailSource = '缓存';
  String mailWarning = '';
  bool soundEnabled = true;
  String soundTone = 'mail';
  bool autoReceiveEnabled = false;
  int autoReceiveMinutes = 5;
  AppLanguage language = AppLanguage.zhHans;
  Color accentColor = LinearColors.ink;

  Timer? _autoReceiveTimer;
  bool _autoReceiveRunning = false;
  int _autoReceiveCursor = 0;
  int _mailLoadEpoch = 0;

  AppStrings get text => AppStrings.of(language);

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
      final accentHex = await _prefs.loadAccentColor();
      if (accentHex.isNotEmpty) {
        final raw = accentHex.replaceFirst('#', '');
        if (raw.length == 6) {
          accentColor = Color(int.parse('ff$raw', radix: 16));
        }
      }
      serverUrl = await _controller.start();
      _api = MailApi(serverUrl);
      loading = false;
      lifecycle = text.loadingAccounts;
      notifyListeners();
      await refresh();
      _syncAutoReceiveTimer();
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
        _syncAutoReceiveCursorToSelected();
        _queueInitialAccountCheck();
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

  void setPage(AppPage next) {
    page = next;
    notifyListeners();
  }

  void setMailFilter(MailFilter next) {
    if (mailFilter == next) return;
    mailFilter = next;
    notifyListeners();
  }

  /// Mails filtered by the current MailFilter (all / codes).
  /// Codes filter: mails whose body or subject contains 4-8 consecutive digits.
  List<MailItem> get filteredMails {
    if (mailFilter == MailFilter.all) return mails;
    final re = RegExp(r'\b\d{4,8}\b');
    return mails.where((m) {
      final body = m.bodyText;
      return re.hasMatch(m.subject) || re.hasMatch(body) || re.hasMatch(m.preview);
    }).toList();
  }

  void setMode(WorkMode next) {
    if (mode == next) return;
    mode = next;
    if (next == WorkMode.claw) {
      _clearOutlookSelection();
    } else {
      selectedClawMailbox = null;
      clawMailboxes = [];
    }
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> _refreshDashboardSafely() async {
    try {
      stats = await _requireApi().dashboard();
    } catch (_) {}
  }

  Future<void> _refreshClawStatsSafely() async {
    try {
      stats = await _requireApi().clawStats();
    } catch (_) {}
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

  bool _isCurrentOutlookAccount(int accountId, [int? epoch]) {
    if (mode != WorkMode.outlook || selectedAccount?.id != accountId) {
      return false;
    }
    return epoch == null || epoch == _mailLoadEpoch;
  }

  MailApi _requireApi() {
    final api = _api;
    if (api == null) throw Exception(text.localApiNotStarted);
    return api;
  }

  void _emit() => notifyListeners();

  @override
  void dispose() {
    _autoReceiveTimer?.cancel();
    _cancelAllOutlookFollowUps();
    _outlookFetches.clear();
    _api?.close();
    _controller.stop();
    super.dispose();
  }
}
