# Bugfix Requirements Document

## Introduction

某些 Outlook 别名账号（例如 `outlook.com.ar` 别名 Linda，其 Microsoft profile 主邮箱可能是 `linda@outlook.com`）在 native-mail-api 走 IMAP 流程时：

1. **收不到新邮件**：即使 IMAP 完整认证并成功登录，新邮件永远不会进入本地缓存。本地已有缓存的邮件能正常展示，但服务端每次都返回空的增量结果。
2. **误报身份不一致**：UI 弹出橙色警告"账号身份可能不一致"，即便邮件实际上是正常投递给该别名对应的 Microsoft 主邮箱。
3. **"无新邮件"不应触发警告**：正常无新增邮件的情况，也不该弹出任何橙色警告。

该问题同时影响用户信心（误报）和实际功能（新邮件永远拉不到）。此 Bugfix 聚焦于两处纯函数/流程级别的根因：
- `fetch_imap_with_auth` 在第一个 candidate 返回空结果时提前 break，后续 candidate 没有机会尝试；
- `recipient_identity_warning` 只用 `account.email` 一个 key 做匹配，对别名账号永远匹配不上 Microsoft primary 邮箱。

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN `ImapAuth.candidates` 包含多个候选 login（例如 `[profile_primary_email, account.email]`）AND 第一个 candidate 通过 IMAP 登录成功并返回 `Ok(vec![])`（空邮件列表）THEN the system 立即 break 循环，不再尝试后续 candidate，导致别名登录永远不会被尝试，新邮件永远拉不到
1.2 WHEN 账号是 Microsoft 别名（如 `linda@outlook.com.ar`）AND 邮件的 `recipients` 字段包含的是该别名对应的 Microsoft primary 邮箱（如 `linda@outlook.com`）AND 成功登录使用的 login（`used_login`/profile primary）与 `account.email` 不同 THEN `recipient_identity_warning` 仅用 `account.email` 构造 `account_keys`，把每一封正常邮件都算作 mismatch，最终满足 `mismatch_count == visible_count` 且 `visible_count >= 2`，返回"账号身份可能不一致"橙色警告
1.3 WHEN 实时拉取返回的 `mails` 为空（本次没有新邮件）AND 本地缓存非空 THEN 当前 fetch 流程虽然不直接因"空"而生成警告，但上层 `fetch_outlook_mailboxes` 对 `recipient_identity_warning(&account.email, &mails)` 的再次调用仍然只依赖 `account.email`，导致只要缓存里历史邮件 recipients 都是 primary，就会因为根因 B 持续回显身份警告

### Expected Behavior (Correct)

2.1 WHEN `ImapAuth.candidates` 包含多个候选 login AND 第一个 candidate 登录成功但返回空邮件列表 THEN the system SHALL 继续尝试剩余 candidate，直到任一 candidate 返回非空邮件列表或所有 candidate 都尝试完毕；只有在所有 candidate 都无新邮件的情况下才视为"本次无新增"，且 the system SHALL 把最后一个登录成功的 candidate 作为 `used_login`（或至少记录所有成功过的 login）
2.2 WHEN 账号是别名账号 AND 邮件的 recipients 实际投递给 profile primary 邮箱（或任意 `ImapAuth.candidates`/成功的 `used_login`）THEN `recipient_identity_warning` SHALL 把 `ImapAuth.candidates`（或成功登录的 `used_login`）以及 `account.email` 一并纳入可信身份集合，只要 recipients 命中集合中任一身份就视为匹配，不再返回警告
2.3 WHEN 本次实时拉取的 `mails` 为空（无新邮件）THEN the system SHALL NOT 因为"空"或"只有缓存"而产生任何橙色身份警告；仅当确实存在至少 2 封可见邮件且全部不命中任何可信身份时才返回身份警告

### Unchanged Behavior (Regression Prevention)

3.1 WHEN 账号不是别名（即 `account.email` 本身是 Microsoft primary，如 `user@outlook.com`）AND 收到的邮件 recipients 命中 `account.email` THEN the system SHALL CONTINUE TO 不返回身份警告（`recipient_identity_warning` 返回 `None`）
3.2 WHEN `ImapAuth.candidates` 只有一个候选 AND 该候选返回非空邮件列表 THEN the system SHALL CONTINUE TO 正常完成登录、写入缓存、返回 mails，不改变 `used_login` 或 saved_count 语义
3.3 WHEN 任何一个 candidate 登录失败（返回 `Err`）THEN the system SHALL CONTINUE TO 把错误记到 `last_error` 并尝试下一个 candidate；仅当所有 candidate 都失败且从未有任何 `Ok` THEN 返回 `last_error`
3.4 WHEN 邮件列表中至少 2 封邮件的 recipients 完全不命中 `account.email` 且不命中任何 candidate/profile primary（真正的身份不一致）THEN the system SHALL CONTINUE TO 返回"账号身份可能不一致"警告，保留原有告警能力
3.5 WHEN Graph 路径（`fetch_graph_with_auth`）、`fetch_outlook_mailboxes` 上层汇总调用 `recipient_identity_warning` THEN the system SHALL CONTINUE TO 使用相同的扩展身份集合语义（即 Graph 路径也应受益于更宽容的身份匹配；如无显式 candidates 可用，则退化为仅用 `account.email`，与当前行为一致，但不应新增误报）
3.6 WHEN IMAP 候选迭代完成 THEN the system SHALL CONTINUE TO 在编译层面通过（无 lifetime / 临时值借用错误），例如 `email.trim().to_lowercase()` 的临时值需要持久化绑定到局部变量而非引用临时值
