part of 'app_state.dart';

extension AppStateClawMail on AppState {
  Future<void> fetchSelectedClawMail({bool openMail = true}) async {
    final mailbox = selectedClawMailbox;
    if (mailbox == null) return;
    final email = clawMailboxEmail(mailbox);
    if (email.isEmpty) return;
    fetching = true;
    error = '';
    lifecycle = text.fetchingClawMail;
    _emit();
    try {
      final result = await _requireApi().clawMails(mailbox: email, sync: true);
      mails = result.mails;
      selectedMail = mails.isEmpty ? null : mails.first;
      await _refreshClawStatsSafely();
      mailSource = result.sourceLabel;
      mailWarning = _mailMessage([result.warning]);
      if (openMail) page = AppPage.mail;
      await _playMailSoundIfNeeded(result.newCount > 0);
      lifecycle = mails.isEmpty ? text.clawNoNewMail : text.clawFetchDone;
    } catch (ex) {
      error = ex.toString();
      lifecycle = text.clawFetchFailed;
    } finally {
      fetching = false;
      _emit();
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
      mailWarning = _mailMessage([result.warning]);
    } catch (ex) {
      error = ex.toString();
    }
    _emit();
  }

  void selectClawMailbox(Map<String, dynamic> mailbox) {
    selectedClawMailbox = mailbox;
    _emit();
  }

  String clawMailboxEmail(Map<String, dynamic> mailbox) {
    return mailbox['email']?.toString() ??
        mailbox['address']?.toString() ??
        mailbox['mailbox']?.toString() ??
        '';
  }
}
