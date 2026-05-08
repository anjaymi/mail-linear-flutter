import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/status_pill.dart';

class DatabasePanel extends StatefulWidget {
  const DatabasePanel({super.key, required this.state});
  final AppState state;

  @override
  State<DatabasePanel> createState() => _DatabasePanelState();
}

class _DatabasePanelState extends State<DatabasePanel> {
  Map<String, dynamic>? health;
  Map<String, dynamic>? repair;
  String message = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _health();
  }

  @override
  Widget build(BuildContext context) {
    final cache = health?['outlookCache'];
    final issues = cache is Map ? Map<String, dynamic>.from(cache) : null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppSurfaces.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.state.text.ui('数据库维护'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                label: busy
                    ? widget.state.text.ui('处理中')
                    : widget.state.text.ready,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MetricLine(
            label: widget.state.text.ui('文件'),
            value: _shortPath(health?['dbPath']),
          ),
          _MetricLine(
            label: widget.state.text.ui('大小'),
            value: _size(health?['sizeBytes']),
          ),
          _MetricLine(
            label: widget.state.text.ui('缓存邮件'),
            value: '${issues?['totalRows'] ?? 0}',
          ),
          _MetricLine(
            label: widget.state.text.ui('重复/孤立'),
            value: _issueText(issues),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(message, style: AppText.muted),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              LinearButton(
                label: widget.state.text.ui('健康检查'),
                icon: Icons.health_and_safety_outlined,
                onPressed: busy ? null : _health,
              ),
              LinearButton(
                label: widget.state.text.ui('预检查'),
                icon: Icons.manage_search,
                onPressed: busy ? null : () => _repair(dryRun: true),
              ),
              LinearButton(
                label: widget.state.text.ui('修复缓存'),
                icon: Icons.build_circle_outlined,
                primary: true,
                onPressed: busy ? null : () => _repair(dryRun: false),
              ),
              LinearButton(
                label: widget.state.text.ui('压缩优化'),
                icon: Icons.compress,
                onPressed: busy ? null : _optimize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _health() async {
    await _run(() async {
      health = await widget.state.api!.databaseHealth();
      message = widget.state.text.ui('健康检查完成');
    });
  }

  Future<void> _repair({required bool dryRun}) async {
    await _run(() async {
      repair = await widget.state.api!.databaseRepair(dryRun: dryRun);
      health = await widget.state.api!.databaseHealth();
      final left = repair?['remainingIssues'];
      final remaining = left is Map ? Map<String, dynamic>.from(left) : null;
      message = dryRun
          ? _repairPreview()
          : '${widget.state.text.ui('修复完成，剩余问题')} ${_issueText(remaining)}';
    });
  }

  Future<void> _optimize() async {
    await _run(() async {
      final result = await widget.state.api!.databaseOptimize();
      health = await widget.state.api!.databaseHealth();
      message = '${widget.state.text.ui('已压缩')} ${_size(result['savedBytes'])}';
    });
  }

  Future<void> _run(Future<void> Function() task) async {
    final api = widget.state.api;
    if (api == null || busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await task();
    } catch (ex) {
      message = ex.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _repairPreview() {
    final next = repair;
    if (next == null) return widget.state.text.ui('预检查完成');
    return '${widget.state.text.ui('可处理：空 ID')} ${next['normalizedEmptyMailIds'] ?? 0}'
        '${widget.state.text.ui('，重复')} ${next['deletedDuplicateRows'] ?? 0}'
        '${widget.state.text.ui('，孤立')} ${next['deletedOrphanRows'] ?? 0}';
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: AppText.muted)),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortPath(Object? value) {
  final path = value?.toString() ?? '';
  if (path.length <= 34) return path.isEmpty ? '-' : path;
  return '...${path.substring(path.length - 31)}';
}

String _issueText(Map<String, dynamic>? issues) {
  if (issues == null) return '0 / 0';
  final duplicate = issues['duplicateRows'] ?? 0;
  final orphan = issues['orphanRows'] ?? 0;
  return '$duplicate / $orphan';
}

String _size(Object? value) {
  final bytes = value is num ? value.toDouble() : 0;
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
