part of 'app_state.dart';

extension AppStateAccounts on AppState {
  void _queueInitialAccountCheck() {
    if (_initialAccountCheckStarted || accounts.isEmpty) return;
    _initialAccountCheckStarted = true;
    unawaited(checkOutlookAccounts(initial: true));
  }

  Future<void> checkOutlookAccounts({bool initial = false}) async {
    if (checkingAccounts || accounts.isEmpty || _api == null) return;
    checkingAccounts = true;
    if (!initial) lifecycle = text.ui('正在检查账号令牌');
    _emit();
    try {
      await _requireApi().checkAccounts(
        accounts.map((item) => item.id).toList(),
      );
      accounts = await _requireApi().accounts();
      selectedAccount = _resolveSelectedAccount();
      await _refreshDashboardSafely();
      lifecycle = text.ui('账号初始检查完成');
    } catch (ex) {
      if (!initial) error = ex.toString();
      lifecycle = text.ui('账号检查未完成');
    } finally {
      checkingAccounts = false;
      _emit();
    }
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
    _emit();
    return deleted;
  }

  Future<String> importAccounts(String content) async {
    error = '';
    lifecycle = text.importingAccounts;
    _emit();
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
      _emit();
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
    _emit();
  }

  Future<void> setAccountMarker(int id, String color) async {
    _replaceAccountMarker(id, color);
    lifecycle = text.markerUpdated;
    _emit();
    try {
      await _requireApi().setAccountMarker(id, color);
      await refresh();
    } catch (ex) {
      final message = ex.toString();
      await refresh();
      error = message;
      lifecycle = text.refreshFailed;
      _emit();
    }
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
}
