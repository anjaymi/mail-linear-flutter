import 'package:flutter/widgets.dart';

enum AppLanguage {
  zhHans('zh-Hans', '简体中文', Locale('zh', 'Hans')),
  zhHant('zh-Hant', '繁體中文', Locale('zh', 'Hant')),
  ja('ja', '日本語', Locale('ja')),
  en('en', 'English', Locale('en')),
  ko('ko', '한국어', Locale('ko'));

  const AppLanguage(this.code, this.nativeName, this.locale);

  final String code;
  final String nativeName;
  final Locale locale;

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return AppLanguage.zhHans;
  }
}

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
    final s when identical(s, zhHant) => '已刪除 $count 個帳號',
    final s when identical(s, ja) => '$count 件のアカウントを削除しました',
    final s when identical(s, en) => 'Deleted $count accounts',
    final s when identical(s, ko) => '$count개 계정을 삭제했습니다',
    _ => '已删除 $count 个账号',
  };

  String importResult(int imported, int skipped, int errors) => switch (this) {
    final s when identical(s, zhHant) =>
      '匯入 $imported 個，略過 $skipped 個，錯誤 $errors 個',
    final s when identical(s, ja) =>
      '$imported 件インポート、$skipped 件スキップ、$errors 件エラー',
    final s when identical(s, en) =>
      'Imported $imported, skipped $skipped, errors $errors',
    final s when identical(s, ko) =>
      '$imported개 가져옴, $skipped개 건너뜀, 오류 $errors개',
    _ => '导入 $imported 个，跳过 $skipped 个，错误 $errors 个',
  };

  String minutes(int value) => switch (this) {
    final s when identical(s, ja) => '$value 分',
    final s when identical(s, en) => '$value min',
    final s when identical(s, ko) => '$value분',
    _ => '$value $minute',
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

  static AppStrings of(AppLanguage language) => switch (language) {
    AppLanguage.zhHant => zhHant,
    AppLanguage.ja => ja,
    AppLanguage.en => en,
    AppLanguage.ko => ko,
    AppLanguage.zhHans => zhHans,
  };

  static const zhHans = AppStrings._(
    appTitle: '邮箱工作台',
    workspace: '邮箱工作台',
    dashboard: '工作台',
    accounts: '账号',
    mail: '邮件',
    settings: '设置',
    clawSettings: 'Claw 设置',
    outlookChannel: 'Outlook 通道',
    clawChannel: 'Claw 通道',
    outlookChannelDetail: '令牌收件与缓存',
    clawChannelDetail: '子邮箱与通讯规则',
    dashboardSubtitle: '收件、状态和最近动态集中处理。',
    accountsSubtitle: '令牌账号、标记和分组管理。',
    mailSubtitle: '缓存阅读、验证码识别和复制。',
    clawSubtitle: 'ClawEmail 绑定与子邮箱同步。',
    settingsSubtitle: '端口、启动、声音和语言偏好。',
    fetching: '收取中',
    startFetch: '开始收取',
    clawFetch: 'Claw 收件',
    refreshAccounts: '刷新账号',
    syncing: '同步中',
    fetchLatest: '收取最新',
    syncClaw: '同步 Claw',
    testConnection: '测试连接',
    languageTitle: '界面语言',
    languageDetail: '切换桌面端主要界面文字。',
    autoStartTitle: '自动启动',
    autoStartDetail: '打开 EXE 后自动创建本地 API 端口。',
    enabled: '已开启',
    autoReceiveTitle: '自动接收',
    autoReceiveDetail: '按间隔自动收取当前选中的 Outlook 账号。',
    portPolicyTitle: '端口策略',
    portPolicyDetail: '3000 被占用时改用下一个可用端口。',
    autoSwitch: '自动切换',
    soundTitle: '声音提示',
    soundDetail: '新邮件到达时播放提醒，可选择提示音。',
    localApiEngine: '本地 API 引擎',
    apiEngineDetail: 'Flutter 只负责桌面 UI，收件、数据库和 Claw 适配继续由 Rust sidecar 处理。',
    autoReceiveInterval: '自动接收间隔',
    selectSound: '选择提示音',
    preview: '试听',
    minute: '分钟',
    bootingApi: '正在启动本地 API',
    loadingAccounts: '正在载入账号',
    ready: '就绪',
    needsAttention: '需要处理',
    refreshingData: '正在刷新数据',
    refreshFailed: '刷新失败',
    fetchingMail: '正在收取邮件',
    noNewMail: '无新邮件',
    fetchDone: '收取完成',
    fetchFailed: '收取失败',
    batchFetching: '正在批量收取',
    batchFetchDone: '批量收取完成',
    batchFetchFailed: '批量收取失败',
    fetchingClawMail: '正在收取 Claw 邮件',
    clawNoNewMail: 'Claw 无新邮件',
    clawFetchDone: 'Claw 收取完成',
    clawFetchFailed: 'Claw 收取失败',
    importingAccounts: '正在导入账号',
    importDone: '导入完成',
    importFailed: '导入失败',
    accountDeleted: '账号已删除',
    markerUpdated: '标记已更新',
    localApiNotStarted: '本地 API 未启动。',
    soundMailLabel: '清脆邮件',
    soundMailDescription: '双音阶新邮件提示',
    soundSoftLabel: '轻提示',
    soundSoftDescription: '低打扰柔和提示',
    soundNoticeLabel: '注意提示',
    soundNoticeDescription: '需要处理时使用',
    soundSuccessLabel: '完成提示',
    soundSuccessDescription: '同步完成反馈',
    soundUrgentLabel: '强提醒',
    soundUrgentDescription: '验证码或异常提醒',
  );

  static const zhHant = AppStrings._(
    appTitle: '郵箱工作台',
    workspace: '郵箱工作台',
    dashboard: '工作台',
    accounts: '帳號',
    mail: '郵件',
    settings: '設定',
    clawSettings: 'Claw 設定',
    outlookChannel: 'Outlook 通道',
    clawChannel: 'Claw 通道',
    outlookChannelDetail: 'Token 收件與快取',
    clawChannelDetail: '子郵箱與通訊規則',
    dashboardSubtitle: '集中處理收件、狀態與最近動態。',
    accountsSubtitle: 'Token 帳號、標記與分組管理。',
    mailSubtitle: '快取閱讀、驗證碼辨識與複製。',
    clawSubtitle: 'ClawEmail 綁定與子郵箱同步。',
    settingsSubtitle: '連接埠、啟動、聲音與語言偏好。',
    fetching: '收取中',
    startFetch: '開始收取',
    clawFetch: 'Claw 收件',
    refreshAccounts: '重新整理帳號',
    syncing: '同步中',
    fetchLatest: '收取最新',
    syncClaw: '同步 Claw',
    testConnection: '測試連線',
    languageTitle: '介面語言',
    languageDetail: '切換桌面端主要介面文字。',
    autoStartTitle: '自動啟動',
    autoStartDetail: '開啟 EXE 後自動建立本地 API 連接埠。',
    enabled: '已開啟',
    autoReceiveTitle: '自動接收',
    autoReceiveDetail: '依間隔自動收取目前選取的 Outlook 帳號。',
    portPolicyTitle: '連接埠策略',
    portPolicyDetail: '3000 被占用時改用下一個可用連接埠。',
    autoSwitch: '自動切換',
    soundTitle: '聲音提示',
    soundDetail: '新郵件到達時播放提醒，可選擇提示音。',
    localApiEngine: '本地 API 引擎',
    apiEngineDetail: 'Flutter 只負責桌面 UI，收件、資料庫與 Claw 適配繼續由 Rust sidecar 處理。',
    autoReceiveInterval: '自動接收間隔',
    selectSound: '選擇提示音',
    preview: '試聽',
    minute: '分鐘',
    bootingApi: '正在啟動本地 API',
    loadingAccounts: '正在載入帳號',
    ready: '就緒',
    needsAttention: '需要處理',
    refreshingData: '正在重新整理資料',
    refreshFailed: '重新整理失敗',
    fetchingMail: '正在收取郵件',
    noNewMail: '沒有新郵件',
    fetchDone: '收取完成',
    fetchFailed: '收取失敗',
    batchFetching: '正在批次收取',
    batchFetchDone: '批次收取完成',
    batchFetchFailed: '批次收取失敗',
    fetchingClawMail: '正在收取 Claw 郵件',
    clawNoNewMail: 'Claw 沒有新郵件',
    clawFetchDone: 'Claw 收取完成',
    clawFetchFailed: 'Claw 收取失敗',
    importingAccounts: '正在匯入帳號',
    importDone: '匯入完成',
    importFailed: '匯入失敗',
    accountDeleted: '帳號已刪除',
    markerUpdated: '標記已更新',
    localApiNotStarted: '本地 API 尚未啟動。',
    soundMailLabel: '清脆郵件',
    soundMailDescription: '雙音階新郵件提示',
    soundSoftLabel: '輕提示',
    soundSoftDescription: '低干擾柔和提示',
    soundNoticeLabel: '注意提示',
    soundNoticeDescription: '需要處理時使用',
    soundSuccessLabel: '完成提示',
    soundSuccessDescription: '同步完成回饋',
    soundUrgentLabel: '強提醒',
    soundUrgentDescription: '驗證碼或異常提醒',
  );

  static const ja = AppStrings._(
    appTitle: 'メールワークスペース',
    workspace: 'メールワークスペース',
    dashboard: 'ダッシュボード',
    accounts: 'アカウント',
    mail: 'メール',
    settings: '設定',
    clawSettings: 'Claw 設定',
    outlookChannel: 'Outlook チャネル',
    clawChannel: 'Claw チャネル',
    outlookChannelDetail: 'トークン受信とキャッシュ',
    clawChannelDetail: 'サブメールボックスとルール',
    dashboardSubtitle: '受信、状態、最近の動きをまとめて確認します。',
    accountsSubtitle: 'トークンアカウント、マーク、グループを管理します。',
    mailSubtitle: 'キャッシュ閲覧、認証コード検出、コピーを行います。',
    clawSubtitle: 'ClawEmail の連携とサブメールボックス同期。',
    settingsSubtitle: 'ポート、起動、通知音、言語の設定。',
    fetching: '受信中',
    startFetch: '受信開始',
    clawFetch: 'Claw 受信',
    refreshAccounts: '更新',
    syncing: '同期中',
    fetchLatest: '最新を受信',
    syncClaw: 'Claw 同期',
    testConnection: '接続テスト',
    languageTitle: '表示言語',
    languageDetail: 'デスクトップ UI の主要テキストを切り替えます。',
    autoStartTitle: '自動起動',
    autoStartDetail: 'EXE 起動時にローカル API ポートを作成します。',
    enabled: '有効',
    autoReceiveTitle: '自動受信',
    autoReceiveDetail: '選択中の Outlook アカウントを一定間隔で受信します。',
    portPolicyTitle: 'ポート設定',
    portPolicyDetail: '3000 が使用中の場合は次の空きポートを使います。',
    autoSwitch: '自動切替',
    soundTitle: '通知音',
    soundDetail: '新着メール時に通知音を再生します。',
    localApiEngine: 'ローカル API エンジン',
    apiEngineDetail:
        'Flutter はデスクトップ UI を担当し、受信、DB、Claw 連携は Rust sidecar が処理します。',
    autoReceiveInterval: '自動受信間隔',
    selectSound: '通知音を選択',
    preview: '試聴',
    minute: '分',
    bootingApi: 'ローカル API を起動中',
    loadingAccounts: 'アカウントを読み込み中',
    ready: '準備完了',
    needsAttention: '確認が必要',
    refreshingData: 'データを更新中',
    refreshFailed: '更新失敗',
    fetchingMail: 'メールを受信中',
    noNewMail: '新着なし',
    fetchDone: '受信完了',
    fetchFailed: '受信失敗',
    batchFetching: '一括受信中',
    batchFetchDone: '一括受信完了',
    batchFetchFailed: '一括受信失敗',
    fetchingClawMail: 'Claw メールを受信中',
    clawNoNewMail: 'Claw 新着なし',
    clawFetchDone: 'Claw 受信完了',
    clawFetchFailed: 'Claw 受信失敗',
    importingAccounts: 'アカウントをインポート中',
    importDone: 'インポート完了',
    importFailed: 'インポート失敗',
    accountDeleted: 'アカウントを削除しました',
    markerUpdated: 'マークを更新しました',
    localApiNotStarted: 'ローカル API が起動していません。',
    soundMailLabel: 'クリアメール',
    soundMailDescription: '二音階の新着メール通知',
    soundSoftLabel: 'ソフト通知',
    soundSoftDescription: '控えめな柔らかい通知',
    soundNoticeLabel: '注意通知',
    soundNoticeDescription: '確認が必要な時に使用',
    soundSuccessLabel: '完了通知',
    soundSuccessDescription: '同期完了のフィードバック',
    soundUrgentLabel: '強い通知',
    soundUrgentDescription: '認証コードや異常時の通知',
  );

  static const en = AppStrings._(
    appTitle: 'Mail Workspace',
    workspace: 'Mail Workspace',
    dashboard: 'Dashboard',
    accounts: 'Accounts',
    mail: 'Mail',
    settings: 'Settings',
    clawSettings: 'Claw Settings',
    outlookChannel: 'Outlook Channel',
    clawChannel: 'Claw Channel',
    outlookChannelDetail: 'Token fetch and cache',
    clawChannelDetail: 'Mailboxes and rules',
    dashboardSubtitle: 'Mail, status, and recent activity in one place.',
    accountsSubtitle: 'Token accounts, markers, and grouping.',
    mailSubtitle: 'Cached reading, code detection, and copy helpers.',
    clawSubtitle: 'ClawEmail binding and mailbox sync.',
    settingsSubtitle: 'Ports, startup, sound, and language preferences.',
    fetching: 'Fetching',
    startFetch: 'Start Fetch',
    clawFetch: 'Claw Fetch',
    refreshAccounts: 'Refresh Accounts',
    syncing: 'Syncing',
    fetchLatest: 'Fetch Latest',
    syncClaw: 'Sync Claw',
    testConnection: 'Test Connection',
    languageTitle: 'Interface Language',
    languageDetail: 'Switch the main desktop interface text.',
    autoStartTitle: 'Auto Start',
    autoStartDetail: 'Create the local API port when the EXE opens.',
    enabled: 'Enabled',
    autoReceiveTitle: 'Auto Receive',
    autoReceiveDetail:
        'Fetch mail for the selected Outlook account on an interval.',
    portPolicyTitle: 'Port Policy',
    portPolicyDetail: 'Use the next free port when 3000 is occupied.',
    autoSwitch: 'Auto Switch',
    soundTitle: 'Sound Alert',
    soundDetail: 'Play a selectable sound when new mail arrives.',
    localApiEngine: 'Local API Engine',
    apiEngineDetail:
        'Flutter handles the desktop UI; mail, database, and Claw integration are handled by the Rust sidecar.',
    autoReceiveInterval: 'Auto receive interval',
    selectSound: 'Select sound',
    preview: 'Preview',
    minute: 'min',
    bootingApi: 'Starting local API',
    loadingAccounts: 'Loading accounts',
    ready: 'Ready',
    needsAttention: 'Needs attention',
    refreshingData: 'Refreshing data',
    refreshFailed: 'Refresh failed',
    fetchingMail: 'Fetching mail',
    noNewMail: 'No new mail',
    fetchDone: 'Fetch complete',
    fetchFailed: 'Fetch failed',
    batchFetching: 'Batch fetching',
    batchFetchDone: 'Batch fetch complete',
    batchFetchFailed: 'Batch fetch failed',
    fetchingClawMail: 'Fetching Claw mail',
    clawNoNewMail: 'No new Claw mail',
    clawFetchDone: 'Claw fetch complete',
    clawFetchFailed: 'Claw fetch failed',
    importingAccounts: 'Importing accounts',
    importDone: 'Import complete',
    importFailed: 'Import failed',
    accountDeleted: 'Account deleted',
    markerUpdated: 'Marker updated',
    localApiNotStarted: 'Local API is not running.',
    soundMailLabel: 'Crisp Mail',
    soundMailDescription: 'Two-tone new mail alert',
    soundSoftLabel: 'Soft Alert',
    soundSoftDescription: 'Low-interruption gentle alert',
    soundNoticeLabel: 'Notice Alert',
    soundNoticeDescription: 'Use when attention is needed',
    soundSuccessLabel: 'Success Alert',
    soundSuccessDescription: 'Feedback after sync completes',
    soundUrgentLabel: 'Urgent Alert',
    soundUrgentDescription: 'For codes or errors',
  );

  static const ko = AppStrings._(
    appTitle: '메일 작업대',
    workspace: '메일 작업대',
    dashboard: '대시보드',
    accounts: '계정',
    mail: '메일',
    settings: '설정',
    clawSettings: 'Claw 설정',
    outlookChannel: 'Outlook 채널',
    clawChannel: 'Claw 채널',
    outlookChannelDetail: '토큰 수신 및 캐시',
    clawChannelDetail: '하위 메일함과 규칙',
    dashboardSubtitle: '수신, 상태, 최근 활동을 한곳에서 확인합니다.',
    accountsSubtitle: '토큰 계정, 표시, 그룹을 관리합니다.',
    mailSubtitle: '캐시 읽기, 인증 코드 감지, 복사 도구.',
    clawSubtitle: 'ClawEmail 연결 및 하위 메일함 동기화.',
    settingsSubtitle: '포트, 시작, 소리, 언어 설정.',
    fetching: '수신 중',
    startFetch: '수신 시작',
    clawFetch: 'Claw 수신',
    refreshAccounts: '계정 새로고침',
    syncing: '동기화 중',
    fetchLatest: '최신 수신',
    syncClaw: 'Claw 동기화',
    testConnection: '연결 테스트',
    languageTitle: '인터페이스 언어',
    languageDetail: '데스크톱 주요 UI 문구를 전환합니다.',
    autoStartTitle: '자동 시작',
    autoStartDetail: 'EXE 실행 시 로컬 API 포트를 만듭니다.',
    enabled: '켜짐',
    autoReceiveTitle: '자동 수신',
    autoReceiveDetail: '선택한 Outlook 계정을 주기적으로 수신합니다.',
    portPolicyTitle: '포트 정책',
    portPolicyDetail: '3000이 사용 중이면 다음 사용 가능 포트를 씁니다.',
    autoSwitch: '자동 전환',
    soundTitle: '소리 알림',
    soundDetail: '새 메일 도착 시 선택한 알림음을 재생합니다.',
    localApiEngine: '로컬 API 엔진',
    apiEngineDetail:
        'Flutter는 데스크톱 UI를 맡고, 수신, DB, Claw 연동은 Rust sidecar가 처리합니다.',
    autoReceiveInterval: '자동 수신 간격',
    selectSound: '알림음 선택',
    preview: '미리 듣기',
    minute: '분',
    bootingApi: '로컬 API 시작 중',
    loadingAccounts: '계정 불러오는 중',
    ready: '준비됨',
    needsAttention: '확인 필요',
    refreshingData: '데이터 새로고침 중',
    refreshFailed: '새로고침 실패',
    fetchingMail: '메일 수신 중',
    noNewMail: '새 메일 없음',
    fetchDone: '수신 완료',
    fetchFailed: '수신 실패',
    batchFetching: '일괄 수신 중',
    batchFetchDone: '일괄 수신 완료',
    batchFetchFailed: '일괄 수신 실패',
    fetchingClawMail: 'Claw 메일 수신 중',
    clawNoNewMail: 'Claw 새 메일 없음',
    clawFetchDone: 'Claw 수신 완료',
    clawFetchFailed: 'Claw 수신 실패',
    importingAccounts: '계정 가져오는 중',
    importDone: '가져오기 완료',
    importFailed: '가져오기 실패',
    accountDeleted: '계정 삭제됨',
    markerUpdated: '표시가 업데이트됨',
    localApiNotStarted: '로컬 API가 시작되지 않았습니다.',
    soundMailLabel: '맑은 메일음',
    soundMailDescription: '두 음의 새 메일 알림',
    soundSoftLabel: '부드러운 알림',
    soundSoftDescription: '방해가 적은 부드러운 알림',
    soundNoticeLabel: '주의 알림',
    soundNoticeDescription: '확인이 필요할 때 사용',
    soundSuccessLabel: '완료 알림',
    soundSuccessDescription: '동기화 완료 피드백',
    soundUrgentLabel: '강한 알림',
    soundUrgentDescription: '인증 코드 또는 오류 알림',
  );
}
