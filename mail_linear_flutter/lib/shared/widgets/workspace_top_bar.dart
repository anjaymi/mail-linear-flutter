import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

/// ProMail-style top bar: just a centered search field spanning the width.
class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: LinearColors.surface,
        border: Border(
          bottom: BorderSide(color: LinearColors.line, width: 0.5),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SizedBox(
            height: 34,
            child: TextField(
              style: AppText.body,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 34,
                ),
                hintText: state.text.ui('搜索邮件…'),
                hintStyle: AppText.muted.copyWith(fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: LinearColors.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  borderSide: const BorderSide(
                    color: LinearColors.blue,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
