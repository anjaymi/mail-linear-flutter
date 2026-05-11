part of 'app_state.dart';

enum SettingsTab { general, accounts, claw, server, database }

extension AppStateSettings on AppState {
  void setSettingsTab(SettingsTab next) {
    settingsTab = next;
    _emit();
  }

  Future<void> setLanguage(AppLanguage next) async {
    if (language == next) return;
    language = next;
    await _prefs.saveLanguageCode(next.code);
    lifecycle = text.ready;
    _emit();
  }

  Future<void> setAccentColor(Color color) async {
    accentColor = color;
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    await _prefs.saveAccentColor(hex);
    _emit();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    await _prefs.saveSoundEnabled(enabled);
    _emit();
  }

  Future<void> setSoundTone(String tone) async {
    soundTone = SoundService.optionOf(tone).value;
    await _prefs.saveSoundTone(soundTone);
    _emit();
  }

  Future<void> previewSound() async {
    await SoundService.play(soundTone);
  }

  Future<void> setAutoReceiveEnabled(bool enabled) async {
    autoReceiveEnabled = enabled;
    await _prefs.saveAutoReceiveEnabled(enabled);
    _syncAutoReceiveTimer();
    _emit();
  }

  Future<void> setAutoReceiveMinutes(int minutes) async {
    autoReceiveMinutes = minutes.clamp(1, 60);
    await _prefs.saveAutoReceiveMinutes(autoReceiveMinutes);
    _syncAutoReceiveTimer();
    _emit();
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
    final target = _nextAutoReceiveTarget();
    if (target == null) return;

    lifecycle = text.ui('自动接收中');
    _emit();

    var newCount = 0;
    var checked = 0;
    var failed = 0;
    MailFetchResult? selectedResult;

    try {
      final result = await _fetchOutlookMails(target.id);
      checked += 1;
      newCount += result.newCount;
      if (selectedAccount?.id == target.id) {
        selectedResult = result;
      }
    } catch (ex) {
      failed += 1;
      if (selectedAccount?.id == target.id) {
        final cached = await _loadOutlookCacheSafely(target.id);
        if (cached.isNotEmpty) {
          mails = cached;
          selectedMail = cached.first;
          mailSource = text.ui('缓存');
          mailWarning = _mailMessage([text.ui('自动接收失败，已保留本地缓存：$ex')]);
        }
      }
    }

    if (selectedResult != null) {
      final account = selectedAccount;
      if (account != null) {
        final cached = await _requireApi().cachedMails(account.id);
        mails = _chooseOutlookMails(selectedResult, cached);
      } else {
        mails = selectedResult.mails;
      }
      selectedMail = mails.isEmpty ? null : mails.first;
      mailSource = selectedResult.sourceLabel;
      mailWarning = _mailFetchMessage(selectedResult);
      _scheduleOutlookCacheFollowUp(
        selectedAccount?.id ?? target.id,
        selectedResult,
      );
    }

    await _refreshDashboardSafely();

    if (newCount > 0) {
      await _playMailSoundIfNeeded(true);
    }
    lifecycle = failed == 0
        ? text.autoReceiveDone(checked, newCount)
        : text.autoReceivePartial(checked, failed, newCount);
    _emit();
  }

  MailAccount? _nextAutoReceiveTarget() {
    if (accounts.isEmpty) return null;
    final index = _autoReceiveCursor % accounts.length;
    final target = accounts[index];
    _autoReceiveCursor = (index + 1) % accounts.length;
    return target;
  }

  void _syncAutoReceiveCursorToSelected() {
    final selected = selectedAccount;
    if (selected == null || accounts.isEmpty) {
      _autoReceiveCursor = 0;
      return;
    }
    final index = accounts.indexWhere((account) => account.id == selected.id);
    _autoReceiveCursor = index < 0 ? 0 : index;
  }

  Future<MailFetchResult> _fetchOutlookMails(int accountId) {
    final running = _outlookFetches[accountId];
    if (running != null) return running;

    final future = _requireApi().fetchMails(accountId);
    _outlookFetches[accountId] = future;
    return future.whenComplete(() {
      if (_outlookFetches[accountId] == future) {
        _outlookFetches.remove(accountId);
      }
    });
  }

  Future<List<MailItem>> _loadOutlookCacheSafely(int accountId) async {
    try {
      return await _requireApi().cachedMails(accountId);
    } catch (_) {
      return const [];
    }
  }

  List<MailItem> _chooseOutlookMails(
    MailFetchResult result,
    List<MailItem> cached,
  ) {
    if (cached.isEmpty) return result.mails;
    if (result.mails.isEmpty) return cached;
    if (result.newCount <= 0) return cached;

    final newest = result.mails.first.id;
    final cacheHasNewest = cached.any((mail) => mail.id == newest);
    return cacheHasNewest ? cached : result.mails;
  }

  Future<void> _playMailSoundIfNeeded(bool hasMail) async {
    if (!soundEnabled || !hasMail) return;
    await SoundService.play(soundTone);
  }

  String _mailFetchMessage(MailFetchResult result) => _mailMessage([
    if (result.newCount > 0) text.ui('已保存 ${result.newCount} 封新邮件。'),
    result.warning,
    if (result.warning.isNotEmpty || result.mails.isEmpty) result.traceSummary,
  ]);

  String _mailMessage(Iterable<String> messages) {
    final parts = <String>[];
    final seen = <String>{};
    for (final message in messages) {
      for (final line in message.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !seen.add(trimmed)) continue;
        parts.add(trimmed);
      }
    }
    return parts.join('\n');
  }
}
