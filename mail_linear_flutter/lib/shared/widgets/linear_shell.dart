import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import 'desktop_title_bar.dart';
import 'workspace_sidebar.dart';
import 'workspace_top_bar.dart';

class LinearShell extends StatelessWidget {
  const LinearShell({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: LinearColors.surface,
        child: Stack(
          children: [
            Row(
              children: [
                WorkspaceSidebar(state: state),
                Expanded(
                  child: Column(
                    children: [
                      WorkspaceTopBar(state: state),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DesktopTitleBar(),
            ),
          ],
        ),
      ),
    );
  }
}
