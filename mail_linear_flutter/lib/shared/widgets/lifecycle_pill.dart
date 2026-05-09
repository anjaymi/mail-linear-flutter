import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import 'status_pill.dart';

class LifecyclePill extends StatelessWidget {
  const LifecyclePill({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.error.isNotEmpty) {
      return StatusPill(
        label: state.text.ui('有异常'),
        color: LinearColors.red,
        icon: Icons.error_outline,
      );
    }
    if (state.fetching || state.lifecycle != state.text.ready) {
      return StatusPill(
        label: state.lifecycle,
        color: LinearColors.blue,
        icon: Icons.sync,
        busy: state.fetching,
      );
    }
    return StatusPill(label: state.text.ready);
  }
}
