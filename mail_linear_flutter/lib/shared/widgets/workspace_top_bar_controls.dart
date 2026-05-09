import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/motion/motion_tokens.dart';
import '../../core/theme/app_theme.dart';
import 'lifecycle_pill.dart';
import 'motion_widgets.dart';
import 'status_pill.dart';
import 'vector_chrome_icons.dart';

class WorkspaceHeaderTools extends StatelessWidget {
  const WorkspaceHeaderTools({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MotionTokens.duration(context, MotionTokens.normal),
      curve: MotionTokens.easeOut,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LinearColors.chrome.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            children[index],
          ],
        ],
      ),
    );
  }
}

class WorkspaceTopAction extends StatelessWidget {
  const WorkspaceTopAction({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final action = _ActionSpec.from(state);
    return MotionTapSurface(
      enabled: action.onTap != null,
      child: FilledButton.icon(
        onPressed: action.onTap,
        icon: MotionSyncIcon(
          icon: action.icon,
          active: state.fetching && action.isReceive,
          size: 17,
          color: action.primary ? Colors.white : LinearColors.ink,
        ),
        label: Text(action.label),
        style: FilledButton.styleFrom(
          backgroundColor: action.primary
              ? LinearColors.ink
              : LinearColors.panel,
          foregroundColor: action.primary ? Colors.white : LinearColors.ink,
          disabledBackgroundColor: LinearColors.surfaceSoft,
          disabledForegroundColor: LinearColors.faint,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: action.primary ? Colors.transparent : LinearColors.line,
            ),
          ),
          textStyle: AppText.control,
        ),
      ),
    );
  }
}

class WorkspaceModeSwitch extends StatelessWidget {
  const WorkspaceModeSwitch({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LinearColors.surfaceSoft.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: LinearColors.chromeLine.withValues(alpha: .62),
        ),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Outlook',
            selected: state.mode == WorkMode.outlook,
            onTap: () => state.setMode(WorkMode.outlook),
          ),
          _ModeButton(
            label: 'Claw',
            selected: state.mode == WorkMode.claw,
            onTap: () => state.setMode(WorkMode.claw),
          ),
        ],
      ),
    );
  }
}

class WorkspacePageGlyph extends StatelessWidget {
  const WorkspacePageGlyph({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MotionTapSurface(
      enabled: false,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: LinearColors.blue,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: LinearColors.blue.withValues(alpha: .18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: icon == Icons.mail_outline
              ? const MailLogoGlyph(color: Colors.white, size: 22)
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class TopBarStatusItems {
  static Widget lifecycle(AppState state) => LifecyclePill(state: state);

  static Widget server(String label) {
    return StatusPill(
      label: label,
      icon: Icons.cloud_done_outlined,
      maxWidth: 150,
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MotionTapSurface(
      lift: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.duration(context, MotionTokens.normal),
          curve: MotionTokens.easeOut,
          width: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? LinearColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppText.label.copyWith(
              color: selected ? Colors.white : LinearColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isReceive,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isReceive;
  final bool primary;

  factory _ActionSpec.from(AppState state) {
    final canReceive = state.mode == WorkMode.claw
        ? state.selectedClawMailbox != null
        : state.selectedAccount != null;
    return switch (state.page) {
      AppPage.dashboard => _ActionSpec(
        label: state.mode == WorkMode.claw
            ? state.fetching
                  ? state.text.fetching
                  : state.text.clawFetch
            : state.fetching
            ? state.text.fetching
            : state.text.startFetch,
        icon: Icons.sync,
        primary: true,
        isReceive: true,
        onTap: state.fetching || !canReceive ? null : state.fetchSelectedMail,
      ),
      AppPage.accounts => _ActionSpec(
        label: state.text.refreshAccounts,
        icon: Icons.refresh,
        isReceive: false,
        onTap: state.refresh,
      ),
      AppPage.mail => _ActionSpec(
        label: state.fetching ? state.text.syncing : state.text.fetchLatest,
        icon: Icons.mark_email_unread_outlined,
        primary: true,
        isReceive: true,
        onTap: state.fetching || !canReceive ? null : state.fetchSelectedMail,
      ),
      AppPage.claw => _ActionSpec(
        label: state.text.syncClaw,
        icon: Icons.sync_alt,
        isReceive: false,
        onTap: state.refresh,
      ),
      AppPage.settings => _ActionSpec(
        label: state.text.testConnection,
        icon: Icons.cable_outlined,
        isReceive: false,
        onTap: state.refresh,
      ),
    };
  }
}
