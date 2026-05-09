import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/status_pill.dart';

class MailReader extends StatelessWidget {
  const MailReader({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final mail = state.selectedMail;
    final body = mail?.bodyText ?? '';
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: AppSurfaces.panel(radius: 28),
      child: mail == null
          ? Center(child: Text(state.text.ui('选择一封邮件开始阅读')))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: state.text.ui('收件箱')),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: MotionTokens.duration(context, MotionTokens.normal),
                  child: Text(
                    mail.subject,
                    key: ValueKey('subject-${mail.id}-${mail.subject}'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: MotionTokens.duration(context, MotionTokens.fast),
                  child: Text(
                    '${mail.senderName}  ${mail.sender}',
                    key: ValueKey('sender-${mail.id}-${mail.sender}'),
                    style: AppText.muted,
                  ),
                ),
                const Divider(height: 36),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MotionTokens.duration(
                      context,
                      MotionTokens.normal,
                    ),
                    switchInCurve: MotionTokens.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: SingleChildScrollView(
                      key: ValueKey('body-${mail.id}-${body.hashCode}'),
                      child: Text(
                        body.isEmpty ? state.text.ui('无正文预览。') : body,
                        style: AppText.body.copyWith(fontSize: 16, height: 1.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
