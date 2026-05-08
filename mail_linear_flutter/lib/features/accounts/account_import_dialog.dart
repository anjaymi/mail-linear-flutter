import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

Future<void> showAccountImportDialog(
  BuildContext context,
  AppState state,
) async {
  final controller = TextEditingController();
  var busy = false;
  var message = '';

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            final content = controller.text.trim();
            if (content.isEmpty || busy) return;
            setState(() {
              busy = true;
              message = '';
            });
            try {
              final result = await state.importAccounts(content);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result)));
            } catch (ex) {
              setState(() {
                message = ex.toString();
                busy = false;
              });
            }
          }

          return AlertDialog(
            title: Text(state.text.ui('批量导入账号')),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.text.ui(
                      '每行格式：邮箱----密码----client_id----refresh_token。如果 client_id 和令牌顺序反了，后端会自动修正。',
                    ),
                    style: TextStyle(
                      color: LinearColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    minLines: 8,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      hintText: 'user@outlook.com----x----M.C...----client-id',
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        color: LinearColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: Text(state.text.ui('取消')),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(state.text.ui(busy ? '导入中' : '导入')),
              ),
            ],
          );
        },
      );
    },
  );
}
