part of 'app_state.dart';

extension AppStateOutlookMail on AppState {
  Future<void> selectAccount(
    MailAccount account, {
    bool openMail = true,
  }) async {
    final epoch = ++_mailLoadEpoch;
    mode = WorkMode.outlook;
    selectedAccount = account;
    _syncAutoReceiveCursorToSelected();
    selectedClawMailbox = null;
    mails = [];
    selectedMail = null;
    mailWarning = '';
    mailSource = text.ui('缓存');
    if (openMail) page = AppPage.mail;
    _emit();
    await loadCachedMails(account, epoch: epoch);
  }

  Future<void> loadCachedMails(MailAccount account, {int? epoch}) async {
    final requestEpoch = epoch ?? ++_mailLoadEpoch;
    error = '';
    try {
      final cached = await _requireApi().cachedMails(account.id);
      if (!_isCurrentOutlookAccount(account.id, requestEpoch)) return;
      mails = cached;
      selectedMail = cached.isEmpty ? null : cached.first;
    } catch (ex) {
      if (!_isCurrentOutlookAccount(account.id, requestEpoch)) return;
      error = ex.toString();
    }
    _emit();
  }

  Future<void> fetchSelectedMail() async {
    if (mode == WorkMode.claw) {
      await fetchSelectedClawMail(openMail: true);
      return;
    }
    await _fetchSelectedMail(openMail: true);
  }

  Future<void> fetchAccounts(List<int> ids) async {
    final targets = ids.map(_accountById).whereType<MailAccount>().toList();
    if (targets.isEmpty) return;
    final displayAccount = targets.last;
    fetching = true;
    error = '';
    selectedAccount = displayAccount;
    mails = [];
    selectedMail = null;
    mailSource = text.ui('缓存');
    mailWarning = '';
    lifecycle = text.batchFetching;
    _emit();
    try {
      var checked = 0;
      var failed = 0;
      var newCount = 0;
      String lastError = '';

      for (final account in targets) {
        MailFetchResult? result;
        Object? fetchError;
        try {
          result = await _fetchOutlookMails(account.id);
          checked += 1;
          newCount += result.newCount;
        } catch (ex) {
          failed += 1;
          fetchError = ex;
          lastError = ex.toString();
        }

        if (account.id == displayAccount.id) {
          final cached = await _loadOutlookCacheSafely(account.id);
          mails = result == null ? cached : _chooseOutlookMails(result, cached);
          selectedMail = mails.isEmpty ? null : mails.first;
          if (result != null) {
            mailSource = result.sourceLabel;
            mailWarning = _mailFetchMessage(result);
            _scheduleOutlookCacheFollowUp(account.id, result);
            await _playMailSoundIfNeeded(result.newCount > 0);
          } else {
            mailSource = cached.isEmpty ? text.ui('实时') : text.ui('缓存');
            mailWarning = _mailMessage([
              cached.isEmpty
                  ? text.ui('批量收取中该账号失败，且本地没有可显示缓存：$fetchError')
                  : text.ui('批量收取中该账号失败，已显示本地缓存：$fetchError'),
            ]);
          }
        } else if (result != null) {
          await _playMailSoundIfNeeded(result.newCount > 0);
        }
      }

      await _refreshDashboardSafely();
      page = AppPage.mail;
      lifecycle = failed == 0
          ? text.batchFetchDone
          : text.ui('批量收取完成：成功 $checked 个，失败 $failed 个，新增 $newCount 封。');
      if (failed > 0 && checked == 0 && mails.isEmpty) {
        error = lastError;
        lifecycle = text.batchFetchFailed;
      }
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.batchFetchFailed;
    } finally {
      fetching = false;
      _emit();
    }
  }

  Future<void> _fetchSelectedMail({required bool openMail}) async {
    final account = selectedAccount;
    if (account == null) return;
    fetching = true;
    error = '';
    lifecycle = text.fetchingMail;
    _emit();
    try {
      final result = await _fetchOutlookMails(account.id);
      if (!_isCurrentOutlookAccount(account.id)) return;
      final cached = await _requireApi().cachedMails(account.id);
      if (!_isCurrentOutlookAccount(account.id)) return;
      mails = _chooseOutlookMails(result, cached);
      selectedMail = mails.isEmpty ? null : mails.first;
      await _refreshDashboardSafely();
      if (openMail) page = AppPage.mail;
      mailSource = result.sourceLabel;
      mailWarning = _mailFetchMessage(result);
      _scheduleOutlookCacheFollowUp(account.id, result);
      await _playMailSoundIfNeeded(result.newCount > 0);
      lifecycle = result.newCount > 0
          ? text.ui('收取完成，新增 ${result.newCount} 封。')
          : mails.isEmpty
          ? text.noNewMail
          : text.fetchDone;
    } catch (ex) {
      final cached = await _loadOutlookCacheSafely(account.id);
      if (!_isCurrentOutlookAccount(account.id)) return;
      if (cached.isNotEmpty) {
        mails = cached;
        selectedMail = cached.first;
        mailSource = text.ui('缓存');
        mailWarning = _mailMessage([text.ui('实时收取失败，已显示本地缓存：$ex')]);
        if (openMail) page = AppPage.mail;
        lifecycle = text.fetchDone;
      } else {
        error = ex.toString();
        lifecycle = text.fetchFailed;
      }
    } finally {
      fetching = false;
      _emit();
    }
  }
}
