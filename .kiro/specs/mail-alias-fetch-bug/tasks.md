# Implementation Plan

> Crate: `outlook-mail-native` (see `native-mail-api/Cargo.toml`).
> Tests live in in-crate `#[cfg(test)] mod tests` blocks.
> `proptest` is not yet a dev-dependency and is added in Task 1 before any property-based test is written.

- [x] 1. Write bug condition exploration tests (MUST FAIL on unfixed code)
  - **Property 1: Bug Condition** — Alias-Aware Fetch & Identity Recognition
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms the bug exists (design §Bug Details, Property 1).
  - **DO NOT attempt to fix the test or the production code when it fails.** Document the failure modes instead.
  - **GOAL**: Surface two independent counterexamples that map 1:1 to `cond_A` (candidate iteration terminates too early) and `cond_B` (identity warning false positive for aliases).
  - **Scoped PBT Approach**: For deterministic bugs, scope each property to the concrete failing case(s) for reproducibility, then widen once the shape is confirmed.
  - Preparation (one-time, bundled here so Task 1 is self-contained):
    - In `native-mail-api/Cargo.toml`, add a `[dev-dependencies]` section and pin `proptest = "1"` (or the latest compatible 1.x). Do not touch `[dependencies]`.
    - Run `cargo build --tests -p outlook-mail-native` to confirm the dev-dependency resolves before writing any test.
  - _Requirements: 1.1, 1.2, 2.1, 2.2_
  - _Design: Property 1 (cond_A + cond_B), §Exploratory Bug Condition Checking Cases 1 & 2_

  - [x] 1.1 Pure-function PBT for `recipient_identity_warning` (cond_B)
    - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs` (add test in the module's `#[cfg(test)] mod tests` block, creating the block if absent).
    - Target function under test: `recipient_identity_warning(account_email: &str, mails: &[Value]) -> Option<String>` (current / unfixed signature).
    - Strategy (use `proptest!`):
      - Generate an alias local-part `local` from `[a-z]{3,10}`.
      - Fix `account_email = format!("{local}@outlook.com.ar")` (alias form).
      - Build a candidate primary `primary = format!("{local}@outlook.com")` (differs from `account_email` only by domain, representing the Microsoft profile primary).
      - Generate `n` in `2..=5` and build `mails: Vec<serde_json::Value>` where every mail has a `recipients` array containing exactly one entry whose email equals `primary`. Use helper JSON shape that matches what `extract_email_addresses` currently parses (e.g. `{"emailAddress": {"address": primary}}` or the existing recipients shape used by the module — mirror whatever shape production code produces).
      - Mix in at least one recipient rendered with display name + angle brackets (e.g. `"\"Linda\" <primary>"`) and one bare-address form to exercise parsing.
    - Assertion: `recipient_identity_warning(&account_email, &mails).is_none()` (i.e. warning must be `None` because every recipient hits the alias's profile primary).
    - **Expected result on UNFIXED code**: FAIL — current implementation builds `account_keys` from `account_email` only, so `mismatch_count == visible_count >= 2` and it returns `Some(warning)`.
    - Document in task comments: the first observed counterexample (inputs, returned `Some(_)` value) and a pointer to the `mismatch_count == visible_count` branch in `mail_cache_alias.rs`.
    - _Requirements: 1.2, 2.2_
    - _Design: Property 1 cond_B, §Testing Strategy Case 2 "Identity Warning Exploration (proptest)"_

  - [x] 1.2 Refactor-for-testability + unit test for candidate iteration (cond_A)
    - **LABEL**: "extract helper, do NOT change behavior" — this sub-task is a mechanical extraction that mirrors the current loop semantics exactly so that the behavior bug is observable through the extracted function.
    - Target file: `native-mail-api/src/native_sections/outlook_imap_auth.rs`.
    - Extract a pure helper adjacent to `fetch_imap_with_auth`:
      - Signature: `fn pick_best_candidate_result<F>(candidates: &[String], mut fetch: F) -> Result<(String, Vec<serde_json::Value>), ApiError> where F: FnMut(&str) -> Result<Vec<serde_json::Value>, ApiError>`.
      - **Body for this sub-task only** (behavior-preserving): replicate the CURRENT loop in `fetch_imap_with_auth` verbatim — on the first `Ok(next)` return `Ok((candidate.clone(), next))` regardless of emptiness; on `Err(e)` record `last_error` and continue; if the loop exits with no `Ok`, return `Err(last_error)`.
      - Do NOT yet call the helper from `fetch_imap_with_auth`; leave the production call site untouched (the behavioral switch happens in Task 3).
    - Unit test (in `#[cfg(test)] mod tests` at the bottom of the file):
      - Inject a `fetch` closure backed by a `RefCell<Vec<Result<Vec<Value>, ApiError>>>` queue returning `[Ok(vec![]), Ok(vec![json!({"id":"m1"}), json!({"id":"m2"})])]` in order.
      - Call with `candidates = vec!["primary@outlook.com".into(), "alias@outlook.com.ar".into()]`.
      - Assertions the fixed contract REQUIRES (and which MUST fail against the current-behavior helper body extracted above):
        - `used_login == "alias@outlook.com.ar"`.
        - `mails.len() == 2`.
    - **Expected result on UNFIXED code**: FAIL — the mirrored loop breaks on the first `Ok(vec![])`, so `used_login == "primary@outlook.com"` and `mails.is_empty()`. Failure demonstrates the bug condition `cond_A` in the extracted helper.
    - Document in task comments: exact counterexample (`candidates`, `fetch_outcomes`, observed `(used_login, mails.len())`) and reference the `break` statement inside the `Ok(next) => { ... break; }` branch.
    - **Scoped PBT note**: This sub-task scopes the property to a single deterministic pair to keep the exploration reproducible; broader PBT coverage (all outcome permutations) is deferred to Task 4 PBT-2 once the helper behavior is corrected in Task 3.
    - _Requirements: 1.1, 2.1_
    - _Design: Property 1 cond_A, §Testing Strategy Case 1 "Candidate Iteration Exploration"_

- [x] 2. Apply `recipient_identity_warning` widening (do not touch iteration yet)
  - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs`.
  - Target function: `recipient_identity_warning`.
  - Signature change:
    - From: `fn recipient_identity_warning(account_email: &str, mails: &[Value]) -> Option<String>`.
    - To:   `fn recipient_identity_warning(account_identities: &[String], mails: &[Value]) -> Option<String>`.
  - Body changes:
    - Build `account_keys` as the union of `single_email_match_keys(identity)` for every `identity` in `account_identities`, deduplicated (case-insensitive / trim-normalised). Preserve the existing semantics of `single_email_match_keys` — do NOT modify that helper.
    - Add an explicit early return at the top: `if mails.is_empty() { return None; }`. Keep the existing `account_keys.is_empty()` guard as-is.
    - Keep the `visible_count >= 2 && mismatch_count == visible_count` threshold unchanged.
    - For the warning message body, select a display primary via `account_identities.first()` (i.e. `account.email`) so the user-facing string is unchanged for the non-alias case.
  - Lifetime hygiene: any `foo.trim().to_lowercase()` used before `.split_once('@')` MUST be bound to a local `let normalized = foo.trim().to_lowercase();` first — no calling `.split_once('@')` on a temporary borrowed from a chain.
  - Update ALL call sites in this same task so the crate compiles:
    - `native-mail-api/src/native_sections/outlook_imap_auth.rs::fetch_imap_with_auth`:
      - Build `let identities = dedup_ci([account.email] ++ candidates ++ [used_login])` just before the warning call. Implement `dedup_ci` inline (or as a private fn in the same module) as: iterate, push the original string if its `trim().to_lowercase()` has not been seen, track seen keys in a `HashSet<String>`.
      - Replace `recipient_identity_warning(&auth.account.email, &mails)` with `recipient_identity_warning(&identities, &mails)`.
    - `native-mail-api/src/native_sections/outlook_graph_auth.rs::fetch_graph_with_auth`:
      - Replace the call with `recipient_identity_warning(&[account.email.clone()], &mails)` (Graph has no `candidates` context — intentional degradation per design §Fix Implementation step 6).
    - `native-mail-api/src/native_sections/outlook_mailbox_helpers.rs` (the aggregation branch inside `fetch_outlook_mailboxes`):
      - Replace the call with `recipient_identity_warning(&[account.email.clone()], &mails)`.
  - Do NOT yet switch `fetch_imap_with_auth` over to `pick_best_candidate_result` — that happens in Task 3. Task 2 must leave the iteration logic untouched so the exploration test 1.2 still fails for the same reason until Task 3.
  - Run `cargo build -p outlook-mail-native` and `cargo test -p outlook-mail-native --no-run` after this task to confirm the crate compiles end-to-end with the new signature.
  - _Bug_Condition: `isBugCondition(input)` cond_B from design §Bug Condition_
  - _Expected_Behavior: `recipient_identity_warning(account_identities, mails) == None` when recipients hit any identity (Property 1 cond_B, Property 2 branches a/d/e/f)_
  - _Preservation: Requirements 3.1, 3.4, 3.5, 3.6 — non-alias, real-mismatch, Graph degradation, lifetime hygiene all unchanged_
  - _Requirements: 2.2, 2.3, 3.1, 3.4, 3.5, 3.6_
  - _Design: Property 1 cond_B + Property 2, §Fix Implementation steps 4, 5, 6, 7_

- [x] 3. Switch `fetch_imap_with_auth` to use `pick_best_candidate_result`
  - Target file: `native-mail-api/src/native_sections/outlook_imap_auth.rs`.
  - Target function: `fetch_imap_with_auth`.
  - Replace the in-place `for candidate in &auth.candidates { ... }` loop with a single call to the helper extracted in Task 1.2, and **update the helper body** to implement the corrected strategy:
    - Preference order (top to bottom):
      1. First `Ok(v)` with `!v.is_empty()` → return `Ok((candidate.clone(), v))` immediately.
      2. On `Ok(v)` with `v.is_empty()` → remember `last_ok_empty_login = Some(candidate.clone())` and continue.
      3. On `Err(e)` → set `last_error = Some(e)` and continue.
      4. After loop: if `last_ok_empty_login.is_some()` return `Ok((last_ok_empty_login.unwrap(), vec![]))`; else return `Err(last_error.expect("candidates non-empty"))`.
  - Hook preservation:
    - Move `debug_fetch_stage("imap_fetch.candidate.start", ...)` and `debug_fetch_stage("imap_fetch.candidate.ok", ...)` (and any analogous `err` stage) INSIDE the `fetch` closure passed to the helper, so per-candidate start/ok/err stages fire exactly as before. Do NOT emit stages from inside the helper itself — keep the helper I/O-free and side-effect-free apart from the injected closure.
  - Do NOT introduce new network calls. The `fetch` closure must invoke the existing `fetch_imap_mails(candidate, &auth.access_token, mailbox, top, &known_mail_ids)` call once per candidate, same arguments as before.
  - `auth.candidates` invariants: assume non-empty (upheld by the caller); add a `debug_assert!(!candidates.is_empty())` inside the helper for defensive coverage.
  - After switching, confirm:
    - The existing single-candidate and all-`Err` code paths still return the same observable result (Preservation 3.2, 3.3 — will be asserted by Task 4).
    - The exploration unit test from Task 1.2 now passes (this will be re-run explicitly in Task 5).
  - _Bug_Condition: `isBugCondition(input)` cond_A from design §Bug Condition_
  - _Expected_Behavior: `pick_best_candidate_result` returns `(used_login, mails)` matching "prefer first Ok(non_empty); else accept empty from last successfully-logged-in candidate; else last Err" (Property 1 cond_A)_
  - _Preservation: Requirements 3.2, 3.3 — single-candidate success and all-Err propagation unchanged_
  - _Requirements: 2.1, 3.2, 3.3_
  - _Design: Property 1 cond_A, §Fix Implementation steps 1, 2_

- [x] 4. Write preservation property tests (observation-first)
  - **Property 2: Preservation** — Non-Alias & Single-Candidate & Error Propagation & Graph Degradation
  - **IMPORTANT**: Observation-first methodology. For every test below, FIRST run it against the unfixed baseline (checkpoint `git stash` of Tasks 2+3 if needed, or run before Tasks 2+3 are merged) and confirm it PASSES on unfixed code, THEN confirm it still PASSES on fixed code. Both states must be recorded.
  - Property-based testing is used for preservation because the input domain (alias/non-alias strings, recipient shapes, candidate counts) is combinatorial; PBT gives stronger "unchanged for all ¬C(X)" guarantees than enumerated unit cases.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - _Design: Property 2, §Preservation Checking, §Property-Based Tests PBT-3 + PBT-4_

  - [x] 4.1 PBT-3 non-alias preservation (Requirement 3.1)
    - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs` (extend the existing tests module).
    - Strategy: generate `account_email` as `format!("{local}@outlook.com", local=…)` (non-alias, Microsoft primary form). Generate `n in 2..=6` mails whose recipients all resolve to `account_email` (mix of bare address, `"Display" <addr>`, and case-variant forms).
    - Assert: `recipient_identity_warning(&[account_email.clone()], &mails).is_none()`.
    - Baseline: run on unfixed code first (call site still passes `&account_email` there — use an `#[cfg(test)]` wrapper or temporarily adapt the test so the baseline is recorded). Confirm PASS on unfixed before Tasks 2+3, and PASS on fixed after.
    - _Requirements: 3.1_
    - _Design: Property 2 branch a, §Property-Based Tests PBT-3_

  - [x] 4.2 Single-candidate success preservation (Requirement 3.2)
    - Target file: `native-mail-api/src/native_sections/outlook_imap_auth.rs` (tests module).
    - Inject `fetch` returning `Ok(vec![json!({"id":"m1"}), json!({"id":"m2"})])` for a single candidate `"a@b.com"`.
    - Call `pick_best_candidate_result(&vec!["a@b.com".into()], fetch)`.
    - Assert: `used_login == "a@b.com"` and `mails.len() == 2` and each mail JSON equals the original input by value.
    - _Requirements: 3.2_
    - _Design: Property 2 branch b, §Testing Strategy Case 2 "Single-Candidate Success Preservation"_

  - [x] 4.3 All-Err error propagation (Requirement 3.3)
    - Target file: `native-mail-api/src/native_sections/outlook_imap_auth.rs` (tests module).
    - Inject `fetch` returning `[Err(ApiError::from("e1")), Err(ApiError::from("e2"))]` (use whatever constructor `ApiError` exposes for a message-only variant; if no public constructor exists, pick the minimal existing variant used by `fetch_imap_mails` on auth failure).
    - Call `pick_best_candidate_result(&vec!["a".into(), "b".into()], fetch)`.
    - Assert: result is `Err(e)` and `e`'s user-visible message / variant matches the second error (`"e2"`), not the first.
    - _Requirements: 3.3_
    - _Design: Property 2 branch c, §Testing Strategy Case 3 "All-Err Preservation"_

  - [x] 4.4 True mismatch still warns (Requirement 3.4)
    - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs` (tests module).
    - Unit test with deterministic input: `account_email = "user@alias.com"`, `identities = vec![account_email.clone()]`, `mails = [recipients = ["stranger@other.com"]; recipients = ["another@other.com"]]` (at least 2 mails, recipients fully disjoint from every entry in `identities`).
    - Assert: `recipient_identity_warning(&identities, &mails).is_some()`.
    - _Requirements: 3.4_
    - _Design: Property 2 branch d, §Testing Strategy "True Mismatch Preservation"_

  - [x] 4.5 Empty mails returns None (Requirement 2.3 preservation under new explicit early return)
    - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs` (tests module).
    - Unit test: `recipient_identity_warning(&["user@alias.com".into()], &[])` must return `None`.
    - Also assert for `recipient_identity_warning(&[], &[])` → `None` (defensive — empty identities).
    - _Requirements: 3.5 (and preserves 2.3 bound)_
    - _Design: Property 2 branch e, §Testing Strategy "Empty Mails Preservation"_

  - [x] 4.6 PBT-4 Graph degradation equivalence (Requirement 3.5)
    - Target file: `native-mail-api/src/native_sections/mail_cache_alias.rs` (tests module).
    - Before Tasks 2+3 are merged: capture a pre-fix oracle by copying the pre-fix `recipient_identity_warning(account_email: &str, mails: &[Value])` into a `#[cfg(test)] fn recipient_identity_warning_oracle(account_email: &str, mails: &[Value]) -> Option<String>` inside the test module. This snapshot IS the oracle.
    - `proptest` strategy: generate arbitrary `account_email` and arbitrary `mails` (any recipient shape). Assert:
      - `recipient_identity_warning(&[account_email.clone()], &mails) == recipient_identity_warning_oracle(&account_email, &mails)`.
    - Must hold for every generated input — this pins Graph path equivalence (which always calls with `&[account.email.clone()]`) to the pre-fix behavior.
    - Baseline: run once on unfixed code (oracle == production); must pass trivially. Then run on fixed code; must continue to pass.
    - _Requirements: 3.5_
    - _Design: Property 2 branch f, §Property-Based Tests PBT-4_

- [x] 5. Re-run exploratory tests + full verification
  - _Requirements: full spec gate — 1.1, 1.2, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  - _Design: Property 1 + Property 2 end-to-end_

  - [x] 5.1 Re-run Task 1 exploration tests on fixed code
    - **Property 1: Expected Behavior** — Alias-Aware Fetch & Identity Recognition (post-fix)
    - **IMPORTANT**: Re-run the SAME tests from Task 1 — do NOT write new tests.
    - Run `cargo test -p outlook-mail-native recipient_identity_warning` and `cargo test -p outlook-mail-native pick_best_candidate_result`.
    - **EXPECTED OUTCOME**: Both tests PASS (Task 1.1 PBT returns `None`; Task 1.2 helper unit test yields `used_login == "alias@outlook.com.ar"` and `mails.len() == 2`).
    - Record in task comments the transition "failed on unfixed / passes on fixed" with commit hashes.
    - _Requirements: 2.1, 2.2_

  - [x] 5.2 Re-run Task 4 preservation tests on fixed code
    - **Property 2: Preservation** — Non-Alias & Single-Candidate & Error Propagation & Graph Degradation
    - **IMPORTANT**: Re-run the SAME tests from Task 4 — do NOT write new tests.
    - Run `cargo test -p outlook-mail-native` with the full test suite.
    - **EXPECTED OUTCOME**: All six sub-tests from Task 4 still PASS (no regressions).
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 5.3 Static + build + full test gate
    - Run `cargo fmt --manifest-path native-mail-api/Cargo.toml --all` (no code drift expected — fix any formatting diffs).
    - Run `cargo build --release -p outlook-mail-native`. Must succeed with no warnings introduced by this spec's changes (baseline warnings unchanged).
    - Run `cargo test -p outlook-mail-native`. Must be all green.
    - Confirm compilation of lifetime-sensitive sites (Requirement 3.6) by inspecting any `.trim().to_lowercase().split_once('@')` chain — each MUST bind to a local `let` first.
    - _Requirements: 3.6 + full gate_

  - [x] 5.4 (Optional) Smoke test against a real alias account
    - Mark as OPTIONAL — only run if a real Outlook alias account (e.g. `@outlook.com.ar`) is available in the dev environment.
    - Start the release binary produced in 5.3.
    - Hit the accounts / mailbox fetch endpoint (IMAP path) for the alias account.
    - Confirm:
      - New mails are actually fetched (no empty response while the mailbox has unread mail).
      - No "账号身份可能不一致" orange warning is raised for mails whose recipients are the Microsoft profile primary.
      - Hitting the endpoint when there are truly no new mails returns cleanly without an identity warning (Requirement 2.3).
    - If no alias account is available, document "smoke test skipped — environment constraint" and mark complete.
    - **Outcome**: smoke test skipped — environment constraint. No real Outlook alias account (`@outlook.com.ar` or equivalent) is provisioned in the automated dev environment handling this spec: no live credentials, no running release binary session, and no network path to Microsoft IMAP for interactive verification. Automated coverage for Requirements 2.1, 2.2, and 2.3 is provided by Tasks 1.1, 1.2, 4.1–4.6, and the full-suite gate in 5.1–5.3, all of which are green on the fixed code. Manual confirmation is deferred to a human operator who has a real alias account — see 5.4 checklist above.
    - _Requirements: 2.1, 2.2, 2.3 (manual confirmation — deferred; automated equivalents covered by Tasks 1 + 4)_
