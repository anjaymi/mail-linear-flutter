# Mail Alias Fetch Bug — Bugfix Design

## Overview

Outlook 别名账号（例如 `linda@outlook.com.ar`，其 Microsoft profile primary 可能是 `linda@outlook.com`）在 native-mail-api 的 IMAP 流程里出现两个互相加强的缺陷：

1. **迭代过早终止（Root Cause A）**：`fetch_imap_with_auth` 在第一个 candidate 登录成功但返回 `Ok(vec![])` 时立即 `break`，导致后续可用的别名/primary candidate 永远没有机会被尝试，账号表现为"永远拉不到新邮件"。
2. **身份匹配键过窄（Root Cause B）**：`recipient_identity_warning` 只用 `account.email` 单一 key 构造 `account_keys`，当别名账号的邮件 recipients 实际命中的是 profile primary（例如 `linda@outlook.com`）时，每封邮件都被误判为 mismatch，前端弹出"账号身份可能不一致"橙色警告。

修复策略是 **纯函数/流程级别** 的最小化改动，不新增网络调用：
- 把 candidate 迭代抽取为纯辅助函数 `pick_best_candidate_result`，实现 "prefer first Ok(non_empty); else accept empty from last Ok; else last Err" 的三级优先策略。
- 把 `recipient_identity_warning` 的签名从 `(account_email, mails)` 扩展为 `(account_identities: &[String], mails)`，调用方把 `account.email`、`ImapAuth.candidates`、成功的 `used_login` 去重合并后传入；只要 recipients 命中任一可信身份即视为匹配。
- 显式早返 `None` 当 `mails` 为空或 `visible_count == 0`，锁定"无新邮件不弹警告"。
- 通过 `proptest` 与抽取后的纯函数单测覆盖两个根因；对保留行为先在 unfixed 代码上观察测试，再固化为 preservation 属性。

## Glossary

- **Bug_Condition (C)**：触发缺陷的输入条件——别名账号导致 candidate 迭代提前终止，或 recipients 命中扩展身份集合但被判为 mismatch。
- **Property (P)**：缺陷输入下的期望行为——candidate 迭代返回最优 `(used_login, mails)`，且身份警告在命中可信身份集合时返回 `None`。
- **Preservation**：非别名账号、单 candidate、全部失败、真正 mismatch、编译期 lifetime 等必须保持不变的行为。
- **candidates (`ImapAuth.candidates`)**：IMAP 登录候选用户名列表，顺序为 `[profile_primary, account.email]`（当 `should_probe_profile_for_imap_alias` 成立时），或仅 `[account.email]`。
- **used_login**：实际成功用来登录 IMAP 并读取邮件的 candidate，会写入返回 JSON 的 `"login"` 字段。
- **fetch_imap_with_auth**：`outlook_imap_auth.rs` 中执行 IMAP 登录-拉邮件-缓存-回填的主流程函数。
- **recipient_identity_warning**：`mail_cache_alias.rs` 中基于 account_email 与 mail recipients 判断是否应弹"账号身份可能不一致"的纯函数。
- **account_identities**：本次修复引入的可信身份集合——`account.email ∪ candidates ∪ {used_login}`（大小写不敏感去重）。
- **pick_best_candidate_result**：本次修复引入的纯辅助函数，封装 candidate 迭代与最优结果选择策略。
- **visible_count / mismatch_count**：`recipient_identity_warning` 内部用来统计"非空 recipients 邮件数"与"完全不命中身份集合的邮件数"的计数器。

## Bug Details

### Bug Condition

该 bug 通过两个独立但联动的子条件之一触发，合取成完整的 `isBugCondition`。子条件 A 描述 candidate 迭代被提前终止的情形，子条件 B 描述身份警告被误报的情形。

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input = {
    account_email:  String,
    candidates:     List<String>,     // 候选 IMAP login（含 account.email）
    fetch_outcomes: List<Result<Vec<Mail>, Err>>, // 每个 candidate 的模拟登录结果
    mails:          List<Mail>,       // 最终进入 recipient_identity_warning 的邮件列表
    used_login:     String,           // 实际成功登录的 candidate
  }
  OUTPUT: boolean

  // --- Condition A: candidate 迭代过早终止 ---
  first_ok_empty := EXISTS i SUCH THAT
      fetch_outcomes[i] == Ok(empty)
      AND FOR ALL j < i: fetch_outcomes[j] IS Err
  later_would_be_nonempty := EXISTS k > i SUCH THAT
      fetch_outcomes[k] == Ok(non_empty)
  cond_A := candidates.len() >= 2
            AND first_ok_empty
            AND later_would_be_nonempty

  // --- Condition B: 扩展身份集合下的误报 ---
  identities := dedup_ci(
      [account_email] ++ candidates ++ [used_login]
  )
  cond_B := account_email 是别名（account_email ∉ identities\{account_email} 的大小写变体一致性判定略）
            AND mails.len() >= 2
            AND FOR ALL mail IN mails:
                  extract_email_addresses(mail.recipients) ∩ identities ≠ ∅
            AND current_recipient_identity_warning(account_email, mails) IS Some(_)

  RETURN cond_A OR cond_B
END FUNCTION
```

### Examples

- **Condition A 示例 1**：`account.email = "linda@outlook.com.ar"`，`candidates = ["linda@outlook.com", "linda@outlook.com.ar"]`，第一个 candidate 登录成功但 IMAP 返回空（profile primary 并非真正投递地址），第二个 candidate 能返回 3 封邮件。当前代码在 `Ok(vec![])` 命中 `break`，后续 candidate 永远不会被尝试——新邮件永远拉不到。**期望**：迭代继续，第二个 candidate 返回非空结果，`used_login = "linda@outlook.com.ar"`，3 封邮件入缓存。
- **Condition A 示例 2**：`candidates = ["a@primary.com", "user@alias.com"]`，两者都返回 `Ok(vec![])`（本次真的无新邮件）。当前代码 break 在第一个空结果，`used_login = "a@primary.com"`；**期望**：迭代完全部 candidate，`used_login` 为最后一个成功登录的 candidate（`"user@alias.com"`），`mails` 为空，`saved_count = 0`。
- **Condition B 示例**：`account.email = "linda@outlook.com.ar"`，`candidates = ["linda@outlook.com", "linda@outlook.com.ar"]`，`used_login = "linda@outlook.com"`，`mails` 为 3 封邮件，其 recipients 分别是 `linda@outlook.com`、`"Linda" <linda@outlook.com>`、`linda@outlook.com`。当前 `recipient_identity_warning` 只用 `"linda@outlook.com.ar"` 构造 `account_keys`，3 封全部判 mismatch，`visible_count == mismatch_count == 3 ≥ 2`，返回橙色警告。**期望**：身份集合包含 `{linda@outlook.com.ar, linda@outlook.com}`，3 封邮件全部命中，返回 `None`。
- **边界示例（非 bug，必须保留）**：`account.email = "user@outlook.com"`（非别名），`candidates = ["user@outlook.com"]`，`mails` 为 5 封投递给 `user@outlook.com` 的邮件——`isBugCondition` 为 false，应返回 `None`（Property 2a）。
- **边界示例（真正的 mismatch，必须保留）**：`account.email = "user@alias.com"`，`candidates = ["user@alias.com"]`，`mails` 为 2 封 recipients 全部是 `stranger@other.com` 的邮件——`isBugCondition` 为 false（不满足 cond_B 的"全部命中"），应返回警告（Property 2d）。

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors：**
- 非别名账号（`account.email` 本身即 Microsoft primary）+ recipients 命中 `account.email` → 身份警告保持 `None`（对应 bugfix.md 3.1）。
- 单 candidate + `Ok(non_empty)` → `used_login == candidates[0]`、`mails` 长度一致、`saved_count` 语义（新插入 vs 更新的 `inserted_count` 定义）不变（对应 3.2）。
- 所有 candidate 都返回 `Err` → 返回**最后一个** `Err` 作为 `last_error`（对应 3.3）。
- ≥2 封邮件且 recipients 完全不命中任何身份（`account.email ∪ candidates ∪ {used_login}`）→ 仍然返回身份警告（对应 3.4）。
- Graph 路径（`fetch_graph_with_auth`）调用方没有 `candidates` 可用时退化为 `vec![account.email]`，不新增误报也不丢原有警告（对应 3.5）。
- 编译期 lifetime：`email.trim().to_lowercase()` 之类临时值在 `.split_once('@')` 之前必须绑定到局部 `let`，不能直接对临时引用 `split_once`（对应 3.6）。
- `mails` 为空或 `visible_count == 0` → 显式返回 `None`，不生成任何警告（对应 bugfix.md 2.3 + 保守防御）。

**Scope：**
所有 **不满足 `isBugCondition`** 的输入必须完全不受本次修复影响，包括：
- 非别名 Microsoft 账号（`@outlook.com / @hotmail.com / @live.com / @msn.com`）的 IMAP/Graph 流程；
- 单 candidate IMAP 登录场景；
- 全部 candidate 都认证失败的 error-propagation 路径；
- Graph 路径对身份警告的调用（保持现有语义，只是使用新签名）；
- `outlook_mailbox_helpers.rs` 中 `fetch_outlook_mailboxes` 汇总调用：无 `candidates` 上下文时应退化为 `[account.email]`，不应因签名变更产生新的 false negative。

## Hypothesized Root Cause

两个根因在代码中彼此独立，但在别名账号场景下互相遮蔽与放大。

1. **Root Cause A — Candidate 迭代的"empty-is-terminal"语义（`outlook_imap_auth.rs::fetch_imap_with_auth`）**
   - 当前循环：`Ok(next) => { used_login = candidate; mails = next; break; }` 无视 `next.is_empty()`。
   - profile primary 在某些别名路由下 IMAP 登录成功但 mailbox 为空（邮件实际落到别名投递路径），第一个 candidate 命中这条分支后后续 candidate 永远不被尝试。
   - 没有区分"登录成功且确有非空结果"与"登录成功但空结果"两种 Ok 语义。

2. **Root Cause B — 身份匹配键集合过窄（`mail_cache_alias.rs::recipient_identity_warning`）**
   - `account_keys := single_email_match_keys(account_email)`，集合里只有 `account.email` 本身（及去点变体）。
   - 别名账号的邮件 recipients 是 profile primary，命中不到别名本身，被整批判为 mismatch。
   - 调用方（`fetch_imap_with_auth`、`fetch_graph_with_auth`、`outlook_mailbox_helpers`）都只传 `account.email`，丢失了 `ImapAuth.candidates` 与 `used_login` 这两份可信身份信息。

3. **次要因素 — 空列表的防御缺失**
   - `recipient_identity_warning` 对 `mails.is_empty()` 没有早返，目前靠 `visible_count >= 2` 兜底；一旦未来有调用方传入合成的缓存邮件，语义会漂移。显式早返可以锁定 bugfix.md 2.3。

4. **次要因素 — Graph 路径与 IMAP 路径签名漂移**
   - 如果只改 IMAP 路径的 `recipient_identity_warning` 调用方，Graph 路径仍用旧签名会出现"同一根因在 Graph 下不复现、但签名不一致"的技术债；应在同一次提交统一扩展身份签名。

## Correctness Properties

Property 1: Bug Condition - Alias-Aware Fetch & Identity Recognition

_For any_ 输入 `(account_email, candidates, fetch_outcomes, mails, used_login)` 满足 `isBugCondition` 返回 `true`（即要么命中 Condition A 的"候选迭代过早终止"，要么命中 Condition B 的"recipients 全部命中扩展身份集合但被误报"），修复后的代码 SHALL：
- 对 Condition A：`pick_best_candidate_result(candidates, fetch_fn)` 返回的 `(used_login, mails)` 满足——存在任一 `Ok(non_empty)` 时，`mails` 非空且 `used_login` 等于第一个产生 `Ok(non_empty)` 的 candidate；全部 `Ok(empty)` 时，`mails` 为空且 `used_login` 等于最后一个成功登录的 candidate；全部 `Err` 时返回 `Err(last_error)`。
- 对 Condition B：`recipient_identity_warning(account_identities, mails)` 返回 `None`，其中 `account_identities = dedup_ci([account_email] ++ candidates ++ [used_login])`。

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Non-Alias & Single-Candidate & Error Propagation

_For any_ 输入 `isBugCondition` 返回 `false`（非别名账号、单 candidate 成功、所有 candidate 失败、真正 mismatch、空 mails、Graph 路径退化等），修复后的代码 SHALL 产出与原代码在可观察层面完全等价的结果：
- 单 candidate + `Ok(non_empty)`：`used_login`、`mails`、`saved_count` 与原实现逐字段相等；
- 全部 `Err`：返回的错误即原实现返回的 `last_error`；
- 非别名账号 recipients 命中 `account.email`：`recipient_identity_warning` 返回 `None`；
- ≥2 封邮件且 recipients 完全不命中身份集合：`recipient_identity_warning` 仍返回 `Some(msg)`；
- 空 mails / `visible_count == 0`：`recipient_identity_warning` 返回 `None`；
- Graph 路径调用方传入 `account_identities = vec![account.email]` 时，行为与原实现等价。

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `native-mail-api/src/native_sections/outlook_imap_auth.rs`

**Function**: `fetch_imap_with_auth`

**Specific Changes**:

1. **抽取纯函数 `pick_best_candidate_result`**：
   - 签名：`fn pick_best_candidate_result<F>(candidates: &[String], mut fetch: F) -> Result<(String, Vec<Value>), ApiError> where F: FnMut(&str) -> Result<Vec<Value>, ApiError>`。
   - 策略（按优先级自上而下）：
     1. 记录 `first_nonempty: Option<(String, Vec<Value>)>`；遇到 `Ok(v)` 且 `!v.is_empty()` 立即返回 `Ok((candidate, v))`。
     2. 若该 `Ok(v)` 为空，则更新 `last_ok_empty_login := candidate`，继续迭代。
     3. 若 `Err(e)`，更新 `last_error := Some(e)`，继续迭代。
     4. 迭代结束后：若曾出现任何 `Ok(empty)`，返回 `Ok((last_ok_empty_login.unwrap(), vec![]))`；否则返回 `Err(last_error.expect("candidates non-empty"))`。
   - 不包含任何 I/O——`fetch` 由调用方注入，便于单元测试 mock。

2. **改造 `fetch_imap_with_auth` 调用点**：
   - 调用 `pick_best_candidate_result(&auth.candidates, |c| fetch_imap_mails(c, &auth.access_token, mailbox, top, &known_mail_ids))`。
   - 保留原有 `debug_fetch_stage(...)` 的 before/ok 钩子语义（在 `fetch` 闭包内部发出）。
   - 不新增网络调用，闭包每次调用即原 `fetch_imap_mails` 调用。

3. **构造扩展身份集合**：
   - 在调用 `recipient_identity_warning` 之前构造：
     ```
     let mut identities: Vec<String> = Vec::new();
     identities.push(auth.account.email.clone());
     identities.extend(auth.candidates.iter().cloned());
     identities.push(used_login.clone());
     // dedup_ci：基于 .trim().to_lowercase() 去重，保留首次出现顺序
     ```
   - 将 `recipient_identity_warning(&auth.account.email, &mails)` 改为 `recipient_identity_warning(&identities, &mails)`。

**File**: `native-mail-api/src/native_sections/mail_cache_alias.rs`

**Function**: `recipient_identity_warning`

**Specific Changes**:

4. **扩展签名并重写 account_keys 构造**：
   - 新签名：`fn recipient_identity_warning(account_identities: &[String], mails: &[Value]) -> Option<String>`。
   - `account_keys` 由所有 identity 的 `single_email_match_keys` 并集组成（去重）。
   - 警告消息仍然显示"当前选择"的 primary identity（取 `account_identities[0]` 即 `account.email`），但匹配逻辑走整个集合。
   - 显式早返：`if mails.is_empty() { return None; }`（再加上原有 `if account_keys.is_empty()` 的保护）。
   - 保留 `visible_count >= 2 && mismatch_count == visible_count` 的告警门槛不变，确保空/单封不弹警告。

5. **Lifetime 卫生**：
   - 任何 `foo.trim().to_lowercase()` 需要 `let normalized = foo.trim().to_lowercase();` 这样的持久化 `let` 绑定，随后 `normalized.split_once('@')`，避免临时值借用错误（对应 bugfix.md 3.6）。

**File**: `native-mail-api/src/native_sections/outlook_graph_auth.rs`

**Function**: `fetch_graph_with_auth`

**Specific Changes**:

6. **同步 Graph 路径调用点**：
   - Graph 流程没有 `candidates`，传入 `&[auth.account.email.clone()]` 调用新签名。
   - 行为与原实现等价——集合只含 `account.email`，匹配语义退化到当前版本（对应 3.5）。

**File**: `native-mail-api/src/native_sections/outlook_mailbox_helpers.rs`

**Function**: `fetch_outlook_mailboxes` 的汇总分支

**Specific Changes**:

7. **同步 helpers 调用点**：
   - 目前调用 `recipient_identity_warning(&account.email, &mails)`，改为 `recipient_identity_warning(&[account.email.clone()], &mails)`。
   - 不尝试在此层重新读取 `ImapAuth.candidates`（当前上下文没有此信息），保留现有告警能力同时适配新签名（对应 3.5 退化语义）。

### Non-Goals

- 不修改 `should_probe_profile_for_imap_alias` 的 domain 白名单。
- 不修改 `resolve_profile_email_for_imap`、`refresh_imap_token`、`get_profile_email` 的行为。
- 不修改 `upsert_mails`、`alias_target_account_ids`、`single_email_match_keys` 的实现。
- 不引入新的持久化字段或数据库迁移。
- 不变更 Graph / IMAP 返回 JSON 的 shape（`"login"`、`"savedCount"`、`"warning"` 键保持不变）。

## Testing Strategy

### Validation Approach

Two-phase：先在 unfixed 代码上跑 Exploratory 测试产生可观察的 counterexample（验证根因假设），再在 fixed 代码上跑 Fix + Preservation 测试锁定行为。保留行为的 property test 在 fix 之前先跑一次 unfixed 基线，确保"未改动路径"确实未改动。

### Exploratory Bug Condition Checking

**Goal**：在实现修复之前，产出能稳定复现两个根因的 counterexample；若观察到的失败模式与假设不符，回到 "Hypothesized Root Cause" 重新分析。

**Test Plan**：在 unfixed 代码上跑两组测试：
- 针对 Condition A：先把 candidate 迭代循环抽取成可注入 `fetch` 的纯函数签名（`pick_best_candidate_result`），或通过一个临时 test harness 把原循环复刻到测试模块中（仍操作原始 `break` 语义），模拟 `fetch_outcomes = [Ok(empty), Ok(non_empty)]`，断言最终 `mails` 非空——在 unfixed 实现上此断言 FAIL。
- 针对 Condition B：纯函数 PBT，对 `recipient_identity_warning` 当前签名传入 `account_email = "linda@outlook.com.ar"`、`mails` 的 recipients 全部是 `linda@outlook.com`，断言返回 `None`——在 unfixed 实现上 FAIL（返回 `Some(...)`）。

**Test Cases**:
1. **Candidate Iteration Exploration**：`candidates = ["primary", "alias"]`，`fetch_outcomes = [Ok(empty), Ok(vec![mail1, mail2, mail3])]`，断言最终 mails 长度 == 3 且 used_login == "alias"（will fail on unfixed code）。
2. **Identity Warning Exploration (proptest)**：`account_email = "<alias>@<alias_domain>"`，`identities` 任意包含 primary，`mails` 所有 recipients 随机命中 identities 中任一元素，断言 warning 为 `None`（will fail on unfixed code 对别名场景）。
3. **Identity Warning Empty Mails**：`mails.is_empty()`，断言返回 `None`（may pass on unfixed code 通过 `visible_count >= 2` 兜底，但固化成显式断言为修复提供基线）。
4. **Edge Case — 全 Ok(empty)**：`fetch_outcomes = [Ok(empty), Ok(empty)]`，断言 `used_login` 为最后一个 candidate 且 mails 为空（may fail on unfixed code：当前实现会在第一个 empty 就 break，`used_login` 会是第一个 candidate）。

**Expected Counterexamples**:
- Case 1：`mails.len() == 0`（unfixed 在第一次 `Ok(empty)` 即 break）；
- Case 2：`warning.is_some()`（`account_keys` 只含 alias，recipients 全是 primary）；
- Case 4：`used_login == candidates[0]` 而非 `candidates.last().unwrap()`。
- Possible causes: (a) `Ok(next) => { ... break; }` 不判空；(b) `account_keys` 构造只用 `account_email`；(c) `visible_count == mismatch_count` 条件在 alias 场景下恒真。

### Fix Checking

**Goal**：修复后，对任意满足 `isBugCondition` 的输入，修复后的代码产出 Property 1 描述的期望行为。

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  // Condition A branch:
  IF input 命中 cond_A THEN
    (used, mails) := pick_best_candidate_result(input.candidates, simulated_fetch(input.fetch_outcomes))
    ASSERT mails 符合 "prefer first Ok(non_empty); else last Ok(empty); else Err" 规则
  END IF

  // Condition B branch:
  IF input 命中 cond_B THEN
    identities := dedup_ci([input.account_email] ++ input.candidates ++ [input.used_login])
    result := recipient_identity_warning_fixed(&identities, &input.mails)
    ASSERT result == None
  END IF
END FOR
```

### Preservation Checking

**Goal**：对任意 `isBugCondition` 返回 `false` 的输入，修复后结果与原实现逐字段等价。

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  // 分支 a: 非别名 + recipients 命中 account.email
  ASSERT recipient_identity_warning_original(account_email, mails)
       == recipient_identity_warning_fixed(&[account_email], mails)

  // 分支 b: 单 candidate + Ok(non_empty)
  ASSERT fetch_imap_with_auth_original(input) == fetch_imap_with_auth_fixed(input)

  // 分支 c: 全部 Err
  ASSERT pick_best_candidate_result(candidates, fetch) 返回 Err(last_error)
        == original_loop(candidates, fetch) 返回 Err(last_error)

  // 分支 d: 真正 mismatch
  ASSERT recipient_identity_warning_fixed(&identities, &mails).is_some()

  // 分支 e: 空 mails
  ASSERT recipient_identity_warning_fixed(&identities, &[]).is_none()

  // 分支 f: Graph 退化
  ASSERT recipient_identity_warning_fixed(&[account_email], mails)
       == recipient_identity_warning_original(account_email, mails)
END FOR
```

**Testing Approach**：对 Property 2 采用 **property-based testing（proptest）** 的理由：
- 身份集合、recipients 列表、邮件数量都是组合爆炸维度，PBT 能以生成式方式覆盖大量 ¬C(X) 输入；
- 单测难以枚举的大小写/去点/带尖括号等 recipients 变体，PBT 可以覆盖；
- "fixed == original on ¬C(X)" 的语义天然适合 PBT 的比较式断言。

**Test Plan**：先在 unfixed 代码上跑 Property 2 的每个分支，**确认它们全部通过**（证明这些行为在 fix 前已经正确），再把同样的测试在 fixed 代码上跑，**必须仍然全部通过**；如果哪个分支在 unfixed 上就失败，说明假设错误，需要回设计阶段调整 `isBugCondition` 边界。

**Test Cases**:
1. **Non-Alias Preservation**：在 unfixed 代码上观察 `account_email = "user@outlook.com"` + recipients 全是 `user@outlook.com` 时返回 `None`，然后用 PBT 生成该类输入，在 fixed 代码上断言仍返回 `None`。
2. **Single-Candidate Success Preservation**：unfixed 下 `candidates = ["a@b.com"]` + `Ok(vec![m1, m2])` 产出 `used_login == "a@b.com"`、`mails.len() == 2`；fixed 下断言一致。
3. **All-Err Preservation**：unfixed 下 `candidates = ["a", "b"]` + `[Err(e1), Err(e2)]` 返回 `Err(e2)`；fixed 下 `pick_best_candidate_result` 返回 `Err(e2)`。
4. **True Mismatch Preservation**：unfixed 下 ≥2 封 recipients 全部是陌生地址 → 返回警告；fixed 下 `recipient_identity_warning(&[account_email], &mails)` 仍返回警告。
5. **Empty Mails Preservation**：`mails = []` → 两版实现都返回 `None`（fixed 通过显式早返，unfixed 通过 `visible_count >= 2` 兜底）。
6. **Graph Path Degradation**：`account_identities = [account.email]` 时，fixed 实现应与 unfixed 逐输入等价（通过 proptest 对比）。

### Unit Tests

- `pick_best_candidate_result`：
  - 空 candidates（虽然 fetch_imap_with_auth 不应传入，但防御性断言 `panic` 或返回明确 `Err`）；
  - 单 candidate + Ok(non_empty) / Ok(empty) / Err；
  - 多 candidate 各种 `fetch_outcomes` 排列（Err→Ok(empty)→Ok(non_empty)、Ok(empty)→Ok(empty)→Err 等）。
- `recipient_identity_warning`：
  - 空 `account_identities`、空 `mails`、`visible_count == 1` 等边界；
  - 带尖括号/引号/大小写/去点变体的 recipients 解析；
  - 别名命中 candidates[0]、命中 used_login、命中 account.email 三种场景。
- Lifetime smoke test：对 `should_probe_profile_for_imap_alias` 与任何新增的 normalize 逻辑编译通过即可（由 `cargo check` 保证）。

### Property-Based Tests

（均使用 `proptest` crate）

- **PBT-1 Alias Identity Match**（Property 1 cond_B）：生成任意 alias `account_email`、任意 `candidates`（包含 primary）、任意 `mails`（recipients 从 identities 集合中抽样），断言 `recipient_identity_warning(&identities, &mails) == None`。
- **PBT-2 Candidate Iteration**（Property 1 cond_A）：生成任意 `candidates: Vec<String>`（长度 1..=5）与任意 `fetch_outcomes: Vec<Outcome>`（Err/Ok(empty)/Ok(non_empty) 的枚举），断言 `pick_best_candidate_result` 返回的 `(used, mails)` 符合优先级规则。
- **PBT-3 Preservation for Non-Alias**（Property 2）：生成 `account_email` 与 `mails`，当 recipients 全部命中 `account_email` 时断言 warning 为 `None`；当 ≥2 封全部不命中时断言 warning 为 `Some`。
- **PBT-4 Graph Degradation Equivalence**：对同一 `(account_email, mails)` 输入，断言 `recipient_identity_warning_fixed(&[account_email.clone()], &mails) == recipient_identity_warning_original(&account_email, &mails)`（需要临时保留或 mirror 原实现作为 oracle）。

### Integration Tests

- **IMAP 别名全链路**：用 stub fetch_imap_mails 注入 `[Ok(empty), Ok(vec![m1, m2])]`，驱动 `fetch_imap_with_auth`，断言返回 JSON 的 `"mails"` 长度 ≥ 2、`"login"` 为别名、无 `"warning"` 字段。
- **IMAP 单 candidate 回归**：单 candidate + Ok(non_empty)，断言返回 JSON 与修复前逐字段相同（快照测试）。
- **Graph 回归**：`fetch_graph_with_auth` 对 recipients 全部命中 `account.email` 的邮件，返回 JSON 无 `"warning"`；对 recipients 全部不命中的邮件，仍返回 `"warning"`。
- **Mailbox Helpers 汇总**：`fetch_outlook_mailboxes` 聚合多账号告警时，新签名调用不产生 panic 且告警集合与原实现对 ¬C(X) 输入一致。
