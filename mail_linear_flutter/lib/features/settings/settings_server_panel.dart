part of 'settings_page.dart';

class _ServerPanel extends StatelessWidget {
  const _ServerPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.text.localApiEngine,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          StatusPill(
            label: state.serverUrl.replaceFirst('http://', ''),
            icon: Icons.cloud_done_outlined,
            maxWidth: 240,
          ),
          const SizedBox(height: 16),
          Text(state.text.apiEngineDetail, style: AppText.muted),
          const SizedBox(height: 24),
          LinearButton(
            label: state.text.testConnection,
            icon: Icons.bolt_outlined,
            primary: true,
            onPressed: state.refresh,
          ),
        ],
      ),
    );
  }
}
