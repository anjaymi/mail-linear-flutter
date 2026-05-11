# 阶段 0 邮件系统重构 API 契约基线

本文档冻结当前重构前邮件读取相关 API 的既有行为，作为阶段 0 邮件系统重构的契约基线。后续引入 `/api/sync/jobs`、同步任务队列、增量同步或 provider 重构时，必须兼容本文列出的请求字段、响应字段、响应 envelope、`MailItem` 字段兼容关系和前端来源标签语义。

## 1. 通用响应 Envelope

当前本地 API 对业务处理结果统一包裹在 JSON envelope 中返回。HTTP 状态通常为 `200`，业务成功或失败由 envelope 内的 `code` 表示。

### 1.1 成功 Envelope

```json
{
  "code": 200,
  "message": "ok",
  "data": {}
}
```

字段说明：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | number | 业务状态码。成功为 `200`。 |
| `message` | string | 成功时通常为 `ok`。 |
| `data` | object / array / null | 具体接口数据。本文后续所有“响应字段”均指 `data` 内部字段。 |

### 1.2 错误 Envelope

```json
{
  "code": 400,
  "message": "account_id is required",
  "data": null
}
```

字段说明：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | number | 业务错误码，例如 `400`、`404`、`409`、`504`、`500`。 |
| `message` | string | 面向调用方或界面的错误说明。当前实现中包含中文或英文消息。 |
| `data` | null | 错误时为 `null`。 |

> 契约要求：后续新接口可以使用更规范的 HTTP 状态码，但旧接口兼容层必须继续支持 `{code,message,data}` envelope，且前端不能因为 HTTP `200` 下的业务错误 envelope 失效。

## 2. `POST /api/mails/fetch`

用于触发 Outlook 邮件实时收取，并在失败、超时或并发收取时回退到本地缓存。当前前端用于手动收信、批量收信和自动收信。

### 2.1 请求字段

请求体为 JSON object。

| 字段 | 类型 | 必填 | 当前默认值 / 限制 | 说明 |
| --- | --- | --- | --- | --- |
| `account_id` | number | 是，与 `accountId` 二选一 | 无 | 账号 ID。当前后端优先读取 `account_id`。 |
| `accountId` | number | 是，与 `account_id` 二选一 | 无 | `account_id` 的兼容别名。 |
| `mailbox` | string | 否 | `INBOX` | 邮箱文件夹。`all` 表示聚合收取 `INBOX` 和 `Junk`。 |
| `top` | number | 否 | `50`，范围 `1..200` | 单次返回或缓存查询数量上限。当前前端传 `100`。 |

示例：

```json
{
  "account_id": 1,
  "mailbox": "all",
  "top": 100
}
```

### 2.2 响应字段

响应数据位于 envelope 的 `data` 字段中。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `mails` | array | 邮件列表，元素为 `MailItem` 兼容对象。当前实时收取成功后通常也从本地缓存重新读取并返回。 |
| `total` | number | 当前查询条件下可展示邮件总数。 |
| `protocol` | string | 数据来源协议或通道。当前可能包含 `graph`、`imap`、`cache`、`outlook` 等语义；前端未知值会按 Outlook 类来源展示。 |
| `cached` | boolean | 是否整体使用缓存结果。`true` 表示本次展示主要来自本地缓存。 |
| `partialCached` | boolean | 是否实时结果与缓存结果混合。聚合多个 mailbox 时，部分 mailbox 实时成功、部分使用缓存时为 `true`。 |
| `savedCount` | number | 本次收取新写入或更新到缓存的邮件数量。前端将其作为新邮件数量提示。 |
| `folders` | array | 聚合收取时的文件夹级结果列表。当前 `mailbox=all` 时用于描述 `INBOX`、`Junk` 等子文件夹结果。 |
| `warning` | string | 普通警告信息，例如超时后使用缓存、并发任务进行中、部分文件夹失败等。可为空或缺省。 |
| `graphWarning` | string | Graph 相关警告信息。当前前端会与 `warning` 合并展示。可为空或缺省。 |

典型成功响应：

```json
{
  "code": 200,
  "message": "ok",
  "data": {
    "mails": [],
    "total": 0,
    "protocol": "graph",
    "cached": false,
    "partialCached": false,
    "savedCount": 0,
    "folders": [],
    "warning": "",
    "graphWarning": ""
  }
}
```

### 2.3 当前行为要点

- `account_id` 和 `accountId` 必须保持兼容；任一字段可用于定位账号。
- `mailbox=all` 是当前前端默认收信方式，表示同时处理 `INBOX` 与 `Junk`。
- 当前接口是“长请求收信”模型：请求期间会尝试 Graph，失败后尝试 IMAP 或缓存 fallback。
- 同一账号已有实时收信任务进行中时，当前实现会尝试返回缓存结果；无缓存时返回业务错误。
- `warning` 与 `graphWarning` 都是兼容字段，后续不能随意删除。

## 3. `GET /api/mails/cached`

用于读取 Outlook 邮件本地缓存，不触发实时收取。

### 3.1 请求字段

字段通过 query string 传递。

| 字段 | 类型 | 必填 | 当前默认值 / 限制 | 说明 |
| --- | --- | --- | --- | --- |
| `account_id` | number | 是 | 无 | 账号 ID。小于等于 `0` 时返回业务错误。 |
| `mailbox` | string | 否 | `INBOX` | 邮箱文件夹。`all` 表示读取该账号所有缓存邮件。 |
| `page` | number | 否 | `1`，最小 `1` | 页码。 |
| `pageSize` | number | 否 | `50`，范围 `1..500` | 每页数量。当前前端读取缓存时传 `100`。 |

示例：

```text
GET /api/mails/cached?account_id=1&mailbox=all&page=1&pageSize=100
```

### 3.2 响应字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `list` | array | 缓存邮件列表，元素为 `MailItem` 兼容对象。 |
| `total` | number | 当前账号和 mailbox 条件下的缓存总数。 |
| `page` | number | 当前页码。 |
| `pageSize` | number | 当前每页数量。 |

示例：

```json
{
  "code": 200,
  "message": "ok",
  "data": {
    "list": [],
    "total": 0,
    "page": 1,
    "pageSize": 100
  }
}
```

## 4. `GET /api/claw/mails`

用于读取 Claw 子邮箱邮件缓存，并可按需触发 Claw 同步。

### 4.1 请求字段

字段通过 query string 传递。

| 字段 | 类型 | 必填 | 当前默认值 / 限制 | 说明 |
| --- | --- | --- | --- | --- |
| `mailbox` | string | 否 | 空字符串 | Claw 子邮箱地址。为空且 `sync=true` 时当前实现会同步全部 Claw 子邮箱；读取列表时按邮箱地址过滤。 |
| `sync` | boolean/string | 否 | `false` | 是否先触发同步。当前识别字符串 `true`。 |
| `page` | number | 否 | `1`，最小 `1` | 页码。 |
| `pageSize` | number | 否 | `50`，范围 `1..500` | 每页数量。当前前端传 `100`。 |

示例：

```text
GET /api/claw/mails?mailbox=user@example.com&page=1&pageSize=100&sync=true
```

### 4.2 响应字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `list` | array | Claw 邮件列表，元素为 `MailItem` 兼容对象。当前 Claw 邮件主要使用 `received_at` 表示时间。 |
| `total` | number | 当前 mailbox 下的缓存总数。 |
| `sync` | object | 同步报告。未请求同步时也会返回一个 `requested=false` 的报告对象。 |

`s‍ync` 报告当前常见字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `requested` | boolean | 是否请求同步。 |
| `mailboxEmail` | string | 目标 Claw 子邮箱。 |
| `remoteCount` | number | 远端邮件数量。 |
| `savedCount` | number | 本次保存数量。 |
| `deletedStaleCount` | number | 本次删除的远端已不存在缓存数量。 |
| `source` | string | 来源说明，例如 `cache`。 |
| `message` | string | 同步或缓存读取说明。 |

示例：

```json
{
  "code": 200,
  "message": "ok",
  "data": {
    "list": [],
    "total": 0,
    "sync": {
      "requested": false,
      "mailboxEmail": "user@example.com",
      "remoteCount": 0,
      "savedCount": 0,
      "deletedStaleCount": 0,
      "source": "cache",
      "message": "仅读取本地缓存。"
    }
  }
}
```

## 5. `MailItem` 字段兼容约定

前端 `MailItem` 解析当前兼容 Outlook 缓存邮件与 Claw 缓存邮件。后续后端输出必须保持这些字段可用。

### 5.1 常用字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | number/string | 邮件记录 ID 或可展示唯一标识。 |
| `sender` | string | 发件人邮箱或发件人标识。 |
| `sender_name` | string | 发件人显示名。 |
| `recipients` | string | 收件人信息。 |
| `subject` | string | 邮件主题。 |
| `text_content` | string | 纯文本正文或预览来源。 |
| `html_content` | string | HTML 正文。 |
| `mailbox` | string | Outlook mailbox / folder，例如 `INBOX`、`Junk`。 |
| `mailbox_email` | string | Claw 子邮箱地址。 |
| `mail_date` | string | Outlook 邮件时间字段。 |
| `received_at` | string | Claw 邮件时间字段。 |
| `is_read` | boolean | 是否已读。可能缺省。 |

### 5.2 时间字段兼容

当前前端读取邮件时间时使用以下兼容逻辑：

```text
date = mail_date ?? received_at
```

契约要求：

- Outlook 邮件至少应继续提供 `mail_date`。
- Claw 邮件至少应继续提供 `received_at`。
- 若后续统一邮件模型新增标准字段，例如 `date` 或 `receivedAt`，仍必须在兼容层保留 `mail_date` / `received_at`，直到前端完成迁移。

## 6. `sourceLabel` 来源标签语义

当前前端根据 `protocol`、`cached`、`partialCached` 生成来源标签。阶段 0 重构后必须保持同等语义。

### 6.1 基础来源映射

| 条件 | 语义 | 展示含义 |
| --- | --- | --- |
| `protocol == "cache"` | 本地缓存 | 数据来自本地缓存。 |
| `partialCached == true` | 实时/缓存混合 | 部分数据来自实时收取，部分数据来自缓存 fallback。 |
| `cached == true` | 缓存 | 本次结果使用缓存。 |
| 其他情况 | 实时 | 本次结果来自实时收取。 |

### 6.2 优先级

推荐兼容层按以下优先级解释：

1. `protocol == "cache"`：视为本地缓存来源。
2. `partialCached == true`：视为实时/缓存混合。
3. `cached == true`：视为缓存。
4. 否则：视为实时。

说明：当前前端实现会先按 `protocol` 得出来源名称，再根据 `partialCached` / `cached` 追加“实时/缓存混合”“缓存”或“实时”。本文档冻结的是业务语义：

- `cache` => 本地缓存
- `partialCached` => 实时/缓存混合
- `cached` => 缓存
- 否则 => 实时

## 7. 后续 `/api/sync/jobs` 兼容要求

阶段 0 之后计划将邮件系统从“长请求收信”重构为“同步任务系统”。新接口可以增加任务、状态、进度、诊断、provider 尝试记录等字段，但必须满足以下兼容要求：

1. 旧接口 `/api/mails/fetch`、`/api/mails/cached`、`/api/claw/mails` 在迁移期继续可用。
2. `/api/sync/jobs` 或其兼容层必须能生成等价的旧字段：`mails`、`total`、`protocol`、`cached`、`partialCached`、`savedCount`、`folders`、`warning`、`graphWarning`。
3. 缓存读取仍需支持 `list`、`total`、`page`、`pageSize`。
4. Claw 邮件读取仍需支持 `list`、`total`、`sync`。
5. envelope `{code,message,data}` 与错误 envelope 必须保持向后兼容。
6. `MailItem` 必须继续兼容 `mail_date` / `received_at`。
7. `sourceLabel` 所依赖的 `protocol`、`cached`、`partialCached` 语义必须保持稳定。

本文档即为重构前冻结行为基线。任何后续接口调整都应先以本文为回归检查清单，确保现有前端展示、缓存 fallback、Claw 邮件读取和来源标签不被破坏。
