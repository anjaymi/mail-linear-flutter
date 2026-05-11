---
inclusion: fileMatch
fileMatchPattern: '**/*.{dart,yaml,arb}'
---

# Power · Flutter Dev

> 本文件模拟 Kiro Power 的 POWER.md 入口。Kiro 在打开 Dart / pubspec / arb 或用户提到 Flutter 话题时自动加载本文件，等同于"启用一个 Flutter 能力插件"。

## 何时激活

- 打开 `.dart` / `.yaml`（尤其 `pubspec.yaml` / `l10n.yaml`）/ `.arb` 文件（已由 fileMatchPattern 触发）
- 用户消息出现触发词：`#flutter`、`#dart`、"widget""pubspec""路由""go_router""widget test""widgettester""overflow""unbounded""renderflex""响应式""国际化""i18n""arb""json 解析""http""integration test""预览""previews.dart""架构""MVVM""Repository"
- 用户要建页面、拆组件、修布局、加测试、加 i18n、调 routing、调用 http

激活后**告诉用户一句**："已激活 Flutter Dev Power — skill: <pick>"。

## Power 提供的 skill

每个 skill 对应 `~/.kiro/skills/<name>/SKILL.md`。按下表挑最贴近的 1~2 个自动激活：

| 场景 | Skill |
|---|---|
| 分层 / 重构 / 项目结构 / MVVM | `flutter-apply-architecture-best-practices` |
| overflow / unbounded / RenderFlex / Stack 脱离 | `flutter-fix-layout-issues` |
| 多尺寸 / 断点 / 平板 / 桌面 | `flutter-build-responsive-layout` |
| widget test / WidgetTester / pumpWidget | `flutter-add-widget-test` |
| 集成测试 / Flutter Driver | `flutter-add-integration-test` |
| widget 预览 / previews.dart | `flutter-add-widget-preview` |
| json 解析 / fromJson / toJson | `flutter-implement-json-serialization` |
| 路由 / go_router / deeplink | `flutter-setup-declarative-routing` |
| i18n / intl / arb / l10n | `flutter-setup-localization` |
| REST / http GET/POST/PUT/DELETE | `flutter-use-http-package` |

## 执行规则

1. 用 `discloseContext` 激活对应的 `flutter-*` skill，这是权威手册。
2. **先读项目上下文再动手**：
   - `mail_linear_flutter/pubspec.yaml` 看已有依赖
   - `mail_linear_flutter/lib/app/app_state*.dart` 看现有状态分片
   - `mail_linear_flutter/lib/features/<feature>/*_page.dart` 看 feature 入口
   - `mail_linear_flutter/lib/core/localization/*` 看已有 i18n 方案
3. 本仓库约定：
   - 状态分片已做：`app_state_accounts.dart` / `app_state_claw_mail.dart` / `app_state_mail_followup.dart` / `app_state_mail_navigation.dart` / `app_state_outlook_mail.dart` / `app_state_settings.dart`。新状态优先继续这种分片，不要倒退回巨型 `app_state.dart`。
   - i18n 目前是**自写映射**（`app_strings_zh.dart` / `app_ui_map_*.dart`），**不是**官方 `gen-l10n`。如果用户要求加 i18n 或扩展某个词条，沿用现有自写映射；除非用户明确要求迁移，不主动换轨。
   - 布局入口在 `features/<feature>/*_page.dart` 与 `*_panel.dart`；状态不允许出现在 Widget 的布局逻辑里。
4. 改动前告诉用户改哪些文件、为什么改；等确认再下手（布局类 quick fix 例外）。

## 配套按钮（Agent Hooks）

- `[Flutter] 🧪 加 Widget 测试`
- `[Flutter] 🛠️ 修布局`
- `[Flutter] 📱 响应式适配`
- `[Flutter] 🌐 加国际化`

点按钮等同于带着当前文件手动激活本 Power 的对应 skill。
