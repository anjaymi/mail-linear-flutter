import 'package:flutter/widgets.dart';

part 'app_strings_zh.dart';
part 'app_strings_ja_en.dart';
part 'app_strings_ko.dart';
part 'app_language.dart';
part 'app_ui_map_zh_hant.dart';
part 'app_ui_map_ja.dart';
part 'app_ui_map_en.dart';
part 'app_ui_map_ko.dart';

class AppStrings {
  const AppStrings._({
    required this.appTitle,
    required this.workspace,
    required this.dashboard,
    required this.accounts,
    required this.mail,
    required this.settings,
    required this.clawSettings,
    required this.outlookChannel,
    required this.clawChannel,
    required this.outlookChannelDetail,
    required this.clawChannelDetail,
    required this.dashboardSubtitle,
    required this.accountsSubtitle,
    required this.mailSubtitle,
    required this.clawSubtitle,
    required this.settingsSubtitle,
    required this.fetching,
    required this.startFetch,
    required this.clawFetch,
    required this.refreshAccounts,
    required this.syncing,
    required this.fetchLatest,
    required this.syncClaw,
    required this.testConnection,
    required this.languageTitle,
    required this.languageDetail,
    required this.autoStartTitle,
    required this.autoStartDetail,
    required this.enabled,
    required this.autoReceiveTitle,
    required this.autoReceiveDetail,
    required this.portPolicyTitle,
    required this.portPolicyDetail,
    required this.autoSwitch,
    required this.soundTitle,
    required this.soundDetail,
    required this.localApiEngine,
    required this.apiEngineDetail,
    required this.autoReceiveInterval,
    required this.selectSound,
    required this.preview,
    required this.minute,
    required this.bootingApi,
    required this.loadingAccounts,
    required this.ready,
    required this.needsAttention,
    required this.refreshingData,
    required this.refreshFailed,
    required this.fetchingMail,
    required this.noNewMail,
    required this.fetchDone,
    required this.fetchFailed,
    required this.batchFetching,
    required this.batchFetchDone,
    required this.batchFetchFailed,
    required this.fetchingClawMail,
    required this.clawNoNewMail,
    required this.clawFetchDone,
    required this.clawFetchFailed,
    required this.importingAccounts,
    required this.importDone,
    required this.importFailed,
    required this.accountDeleted,
    required this.markerUpdated,
    required this.localApiNotStarted,
    required this.soundMailLabel,
    required this.soundMailDescription,
    required this.soundSoftLabel,
    required this.soundSoftDescription,
    required this.soundNoticeLabel,
    required this.soundNoticeDescription,
    required this.soundSuccessLabel,
    required this.soundSuccessDescription,
    required this.soundUrgentLabel,
    required this.soundUrgentDescription,
  });

  final String appTitle;
  final String workspace;
  final String dashboard;
  final String accounts;
  final String mail;
  final String settings;
  final String clawSettings;
  final String outlookChannel;
  final String clawChannel;
  final String outlookChannelDetail;
  final String clawChannelDetail;
  final String dashboardSubtitle;
  final String accountsSubtitle;
  final String mailSubtitle;
  final String clawSubtitle;
  final String settingsSubtitle;
  final String fetching;
  final String startFetch;
  final String clawFetch;
  final String refreshAccounts;
  final String syncing;
  final String fetchLatest;
  final String syncClaw;
  final String testConnection;
  final String languageTitle;
  final String languageDetail;
  final String autoStartTitle;
  final String autoStartDetail;
  final String enabled;
  final String autoReceiveTitle;
  final String autoReceiveDetail;
  final String portPolicyTitle;
  final String portPolicyDetail;
  final String autoSwitch;
  final String soundTitle;
  final String soundDetail;
  final String localApiEngine;
  final String apiEngineDetail;
  final String autoReceiveInterval;
  final String selectSound;
  final String preview;
  final String minute;
  final String bootingApi;
  final String loadingAccounts;
  final String ready;
  final String needsAttention;
  final String refreshingData;
  final String refreshFailed;
  final String fetchingMail;
  final String noNewMail;
  final String fetchDone;
  final String fetchFailed;
  final String batchFetching;
  final String batchFetchDone;
  final String batchFetchFailed;
  final String fetchingClawMail;
  final String clawNoNewMail;
  final String clawFetchDone;
  final String clawFetchFailed;
  final String importingAccounts;
  final String importDone;
  final String importFailed;
  final String accountDeleted;
  final String markerUpdated;
  final String localApiNotStarted;
  final String soundMailLabel;
  final String soundMailDescription;
  final String soundSoftLabel;
  final String soundSoftDescription;
  final String soundNoticeLabel;
  final String soundNoticeDescription;
  final String soundSuccessLabel;
  final String soundSuccessDescription;
  final String soundUrgentLabel;
  final String soundUrgentDescription;

  String deletedAccounts(int count) => switch (this) {
    final s when identical(s, appStringsZhHant) => '已刪除 $count 個帳號',
    final s when identical(s, appStringsJa) => '$count 件のアカウントを削除しました',
    final s when identical(s, appStringsEn) => 'Deleted $count accounts',
    final s when identical(s, appStringsKo) => '$count개 계정을 삭제했습니다',
    _ => '已删除 $count 个账号',
  };

  String importResult(int imported, int skipped, int errors) => switch (this) {
    final s when identical(s, appStringsZhHant) =>
      '匯入 $imported 個，略過 $skipped 個，錯誤 $errors 個',
    final s when identical(s, appStringsJa) =>
      '$imported 件インポート、$skipped 件スキップ、$errors 件エラー',
    final s when identical(s, appStringsEn) =>
      'Imported $imported, skipped $skipped, errors $errors',
    final s when identical(s, appStringsKo) =>
      '$imported개 가져옴, $skipped개 건너뜀, 오류 $errors개',
    _ => '导入 $imported 个，跳过 $skipped 个，错误 $errors 个',
  };

  String selectedAccounts(int count) => switch (this) {
    final s when identical(s, appStringsZhHant) => '已選 $count 個',
    final s when identical(s, appStringsJa) => '$count 件選択中',
    final s when identical(s, appStringsEn) => '$count selected',
    final s when identical(s, appStringsKo) => '$count개 선택됨',
    _ => '已选 $count',
  };

  String colorName(String source) => switch (source) {
    '蓝' => ui('蓝'),
    '绿' => ui('绿'),
    '橙' => ui('橙'),
    '红' => ui('红'),
    '紫' => ui('紫'),
    '青' => ui('青'),
    _ => source,
  };

  String colorLabel(String source) => switch (this) {
    final s when identical(s, appStringsZhHant) => '${colorName(source)}色',
    final s when identical(s, appStringsJa) => '${colorName(source)}マーク',
    final s when identical(s, appStringsEn) => colorName(source),
    final s when identical(s, appStringsKo) => colorName(source),
    _ => '${colorName(source)}色',
  };

  String colorMarker(String source) => switch (this) {
    final s when identical(s, appStringsZhHant) => '${colorName(source)}色標記',
    final s when identical(s, appStringsJa) => '${colorName(source)}マーク',
    final s when identical(s, appStringsEn) => '${colorName(source)} marker',
    final s when identical(s, appStringsKo) => '${colorName(source)} 표시',
    _ => '${colorName(source)}色标记',
  };

  String minutes(int value) => switch (this) {
    final s when identical(s, appStringsJa) => '$value 分',
    final s when identical(s, appStringsEn) => '$value min',
    final s when identical(s, appStringsKo) => '$value분',
    _ => '$value $minute',
  };

  String autoReceiveDone(int accounts, int mails) => switch (this) {
    final s when identical(s, appStringsZhHant) =>
      '自動接收完成：$accounts 個帳號，$mails 封新郵件',
    final s when identical(s, appStringsJa) =>
      '自動受信完了：$accounts 件のアカウント、$mails 件の新着',
    final s when identical(s, appStringsEn) =>
      'Auto receive complete: $accounts accounts, $mails new mails',
    final s when identical(s, appStringsKo) =>
      '자동 수신 완료: 계정 $accounts개, 새 메일 $mails개',
    _ => '自动接收完成：$accounts 个账号，$mails 封新邮件',
  };

  String autoReceivePartial(
    int accounts,
    int failed,
    int mails,
  ) => switch (this) {
    final s when identical(s, appStringsZhHant) =>
      '自動接收部分完成：$accounts 個成功，$failed 個失敗，$mails 封新郵件',
    final s when identical(s, appStringsJa) =>
      '自動受信一部完了：成功 $accounts、失敗 $failed、新着 $mails',
    final s when identical(s, appStringsEn) =>
      'Auto receive partial: $accounts ok, $failed failed, $mails new mails',
    final s when identical(s, appStringsKo) =>
      '자동 수신 일부 완료: 성공 $accounts개, 실패 $failed개, 새 메일 $mails개',
    _ => '自动接收部分完成：$accounts 个成功，$failed 个失败，$mails 封新邮件',
  };

  String soundLabel(String value) => switch (value) {
    'soft' => soundSoftLabel,
    'notice' => soundNoticeLabel,
    'success' => soundSuccessLabel,
    'urgent' => soundUrgentLabel,
    _ => soundMailLabel,
  };

  String soundDescription(String value) => switch (value) {
    'soft' => soundSoftDescription,
    'notice' => soundNoticeDescription,
    'success' => soundSuccessDescription,
    'urgent' => soundUrgentDescription,
    _ => soundMailDescription,
  };

  String ui(String source) {
    if (identical(this, appStringsZhHans)) return source;
    final map = identical(this, appStringsZhHant)
        ? appUiZhHant
        : identical(this, appStringsJa)
        ? appUiJa
        : identical(this, appStringsEn)
        ? appUiEn
        : appUiKo;
    return map[source] ?? source;
  }

  static AppStrings of(AppLanguage language) => switch (language) {
    AppLanguage.zhHant => appStringsZhHant,
    AppLanguage.ja => appStringsJa,
    AppLanguage.en => appStringsEn,
    AppLanguage.ko => appStringsKo,
    AppLanguage.zhHans => appStringsZhHans,
  };
}
