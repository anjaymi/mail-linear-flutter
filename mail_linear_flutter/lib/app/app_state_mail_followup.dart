part of 'app_state.dart';

extension AppStateMailFollowUp on AppState {
  void _scheduleOutlookCacheFollowUp(int accountId, MailFetchResult result) {
    if (!_needsOutlookFollowUp(result)) return;
    _cancelOutlookFollowUp(accountId);
    _outlookFollowUpAttempts[accountId] = 0;
    _outlookFollowUpTimers[accountId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollOutlookCacheAfterBackgroundFetch(accountId)),
    );
  }

  Future<void> _pollOutlookCacheAfterBackgroundFetch(int accountId) async {
    if (_outlookFollowUpBusy.contains(accountId)) return;
    _outlookFollowUpBusy.add(accountId);
    try {
      final attempts = (_outlookFollowUpAttempts[accountId] ?? 0) + 1;
      _outlookFollowUpAttempts[accountId] = attempts;
      final next = await _loadOutlookCacheSafely(accountId);
      final isCurrent = _isCurrentOutlookAccount(accountId);
      final changed = isCurrent && _mailListChanged(next, mails);

      if (changed) {
        final oldFirstId = mails.isEmpty ? null : mails.first.id;
        final oldSelectedId = selectedMail?.id;
        mails = next;
        selectedMail = _followUpSelection(next, oldFirstId, oldSelectedId);
        mailSource = text.ui('本地缓存');
        mailWarning = _mailMessage([text.ui('后台收取已同步，邮件列表已更新。')]);
        lifecycle = text.ui('后台收取已同步');
        await _playMailSoundIfNeeded(_looksLikeNewMail(next, oldFirstId));
        await _refreshDashboardSafely();
        _cancelOutlookFollowUp(accountId);
        _emit();
        return;
      }

      if (mode == WorkMode.outlook) {
        await _refreshDashboardSafely();
      }
      if (attempts >= 12) {
        _cancelOutlookFollowUp(accountId);
      }
    } finally {
      _outlookFollowUpBusy.remove(accountId);
    }
  }

  bool _needsOutlookFollowUp(MailFetchResult result) {
    final messages = <String>[result.warning];
    final warnings = result.trace['warnings'];
    if (warnings is Iterable) {
      messages.addAll(warnings.map((item) => item.toString()));
    } else if (warnings != null) {
      messages.add(warnings.toString());
    }
    return result.cached && messages.join('\n').contains('后台任务仍会尝试完成');
  }

  bool _mailListChanged(List<MailItem> next, List<MailItem> current) {
    if (next.length != current.length) return true;
    for (var i = 0; i < next.length; i += 1) {
      if (next[i].id != current[i].id) return true;
    }
    return false;
  }

  bool _looksLikeNewMail(List<MailItem> next, int? oldFirstId) {
    return next.isNotEmpty && next.first.id != oldFirstId;
  }

  MailItem? _followUpSelection(
    List<MailItem> next,
    int? oldFirstId,
    int? oldSelectedId,
  ) {
    if (next.isEmpty) return null;
    if (oldSelectedId == null || oldSelectedId == oldFirstId) return next.first;
    for (final item in next) {
      if (item.id == oldSelectedId) return item;
    }
    return next.first;
  }

  void _cancelOutlookFollowUp(int accountId) {
    _outlookFollowUpTimers.remove(accountId)?.cancel();
    _outlookFollowUpAttempts.remove(accountId);
    _outlookFollowUpBusy.remove(accountId);
  }

  void _cancelAllOutlookFollowUps() {
    for (final timer in _outlookFollowUpTimers.values) {
      timer.cancel();
    }
    _outlookFollowUpTimers.clear();
    _outlookFollowUpAttempts.clear();
    _outlookFollowUpBusy.clear();
  }
}
