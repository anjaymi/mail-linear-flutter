import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

/// ProMail-style reader: icon toolbar + subject + sender row with avatar +
/// body. Verification code chip inline in meta when detected.
class MailReader extends StatelessWidget {
  const MailReader({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mail = state.selectedMail;
    final body = mail?.bodyText ?? '';
    final code = mail == null ? null : _extractCode(body);

    return Container(
      color: LinearColors.surface,
      child: mail == null
          ? Center(
              child: Text(
                state.text.ui('选择一封邮件开始阅读'),
                style: AppText.muted,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IconToolbar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // subject
                        Text(
                          mail.subject,
                          style: AppText.pageTitle.copyWith(
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // sender row
                        _SenderRow(mail: mail, state: state),
                        const SizedBox(height: 24),
                        // verification code card (when detected)
                        if (code != null) ...[
                          _VerificationCard(code: code, state: state),
                          const SizedBox(height: 24),
                        ],
                        // body
                        SelectionArea(
                          child: Text(
                            body.isEmpty
                                ? state.text.ui('无正文预览。')
                                : body,
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              height: 1.7,
                              color: LinearColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static String? _extractCode(String text) =>
      RegExp(r'\b\d{4,8}\b').firstMatch(text)?.group(0);
}

class _IconToolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LinearColors.line, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _ToolIcon(Icons.reply_outlined),
          _ToolIcon(Icons.reply_all_outlined),
          _ToolIcon(Icons.shortcut_outlined),
          const Spacer(),
          _ToolIcon(Icons.archive_outlined),
          _ToolIcon(Icons.delete_outline),
          _ToolIcon(Icons.more_horiz),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {},
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: LinearColors.muted),
          ),
        ),
      ),
    );
  }
}

class _SenderRow extends StatelessWidget {
  const _SenderRow({
    required this.mail,
    required this.state,
  });
  final dynamic mail;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final name = mail.senderName.isEmpty ? mail.sender : mail.senderName;
    final letter = name.isEmpty ? '?' : name[0].toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // avatar
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: LinearColors.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // name + email + to
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: AppText.bodyStrong.copyWith(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '<${mail.sender}>',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.muted.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'To: ${state.selectedAccount?.email ?? ''}',
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  color: LinearColors.faint,
                ),
              ),
            ],
          ),
        ),
        // time only (no code chip — verification card handles it)
        Text(
          _shortDate(mail.date),
          style: AppText.caption.copyWith(
            fontSize: 11.5,
            color: LinearColors.faint,
          ),
        ),
      ],
    );
  }

  String _shortDate(String value) =>
      value.length > 10 ? value.substring(0, 16) : value;
}

/// ProMail-style verification code card — centered, grey bg, large mono digits,
/// full-width black "Copy" button, expiry hint.
class _VerificationCard extends StatefulWidget {
  const _VerificationCard({required this.code, required this.state});
  final String code;
  final AppState state;

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Format code with spaces between each digit for visual clarity
    final spaced = widget.code.split('').join(' ');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          decoration: BoxDecoration(
            color: LinearColors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LinearColors.line, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // label
              Text(
                'VERIFICATION CODE',
                style: AppText.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: LinearColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              // code digits in a bordered white box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: LinearColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LinearColors.line, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    spaced,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: LinearColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // copy button — full width, black
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _copied
                        ? widget.state.text.ui('已复制')
                        : widget.state.text.ui('复制验证码'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: LinearColors.ink,
                    foregroundColor: LinearColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: AppText.bodyStrong.copyWith(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // expiry hint
              Text(
                widget.state.text.ui('自动识别 · 请勿分享此验证码'),
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  color: LinearColors.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
