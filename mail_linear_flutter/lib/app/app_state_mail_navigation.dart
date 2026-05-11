part of 'app_state.dart';

extension AppStateMailNavigation on AppState {
  Future<void> refreshCurrentMailbox() async {
    error = '';
    if (mode == WorkMode.claw) {
      final mailbox = selectedClawMailbox;
      if (mailbox == null) {
        await refresh(loadSelectedMail: true);
        return;
      }
      await loadCachedClawMails(mailbox);
      return;
    }
    final account = selectedAccount;
    if (account == null) {
      await refresh(loadSelectedMail: true);
      return;
    }
    await loadCachedMails(account);
  }

  void selectMail(MailItem mail) {
    selectedMail = mail;
    _emit();
  }

  Future<void> openCachedMail(MailItem mail) async {
    selectedMail = mail;
    page = AppPage.mail;
    if (mail.accountId == 0 && mail.mailboxEmail.isNotEmpty) {
      await _openClawCachedMail(mail);
      return;
    }
    await _openOutlookCachedMail(mail);
  }

  Future<void> _openClawCachedMail(MailItem mail) async {
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
    _emit();
    if (selectedClawMailbox == null) return;
    try {
      final result = await _requireApi().clawMails(mailbox: mail.mailboxEmail);
      mails = result.mails;
      selectedMail = mails.firstWhere(
        (item) => item.id == mail.id,
        orElse: () => mail,
      );
      mailSource = result.sourceLabel;
      mailWarning = _mailMessage([result.warning]);
    } catch (ex) {
      error = ex.toString();
    }
    _emit();
  }

  Future<void> _openOutlookCachedMail(MailItem mail) async {
    final account = _accountById(mail.accountId);
    if (account != null) selectedAccount = account;
    _emit();
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
    _emit();
  }
}
