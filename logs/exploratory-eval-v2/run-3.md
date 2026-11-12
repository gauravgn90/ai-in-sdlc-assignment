# Review eval: run 3 (raw, not yet scored)

**Status: NOT SCORED.** The answer key is not in this repository (`ops/evals/README.md:4-5`, `ops/README.md:27-30`); it is in the facilitator's session runbook. This file records what each reviewer reported. The verdict column and the counts and rates below stay blank until someone fills them in from the key.

This completes the three runs the README asks for (`README.md:27-28`). The section [Across all three runs](#across-all-three-runs) brings them together.

## Run setup

Same as [run 1](run-1.md) and [run 2](run-2.md). Nothing was changed between runs.

| Field | Value |
|---|---|
| Run | 3 (of 3) |
| Date | 2026-11-10 |
| Prompt | `ops/evals/review-prompt.md`, **v2** (body below the line, verbatim) |
| Reviewer | A fresh general-purpose Claude Code subagent per case. Model: the session default, not separately recorded |
| Input given | The v2 prompt and that case's diff, inline. Nothing else: no repo access, no README, no other cases, no answer key, no earlier run output |
| Isolation | Each reviewer was told not to use tools. Each made exactly one tool call, its hand-back, so none read any files |
| Order | All 10 started in parallel and shared no context with each other or with earlier runs |

## Results by case

The **Verdict** column takes one of: `caught`, `missed`, `false alarm`, or `correct pass`. Score by the rules in `ops/evals/README.md:38-47`.

| Case | Reported | Findings (file:line · severity · confidence: summary) | Verdict |
|---|---|---|---|
| case-01 | 3 defects | `ApprovalsController.cs:51` · high · med: `Approve` called outside `Handle(...)`, so service errors become 500 instead of 404/409<br>`ApprovalsController.cs:49` · high · med: the loop isn't atomic; earlier approvals stay committed when a later id fails, and the caller can't tell which ones succeeded<br>`ApprovalsController.cs:49` · medium · high: nullable `Ids` (and the body) used without a null check, so a NullReferenceException and a 500 | |
| case-02 | 3 defects | `InvoicesController.cs:28` · critical · high: SQL injection through `customer`<br>`InvoicesController.cs:32` · critical · high: SQL injection through `status`<br>`InvoicesController.cs:35` · high · low: `_queries` isn't declared or registered, so the build or DI can break | |
| case-03 | 2 defects | `DiscountCalculator.cs:16` · high · med: the discount is truncated (`ToZero`) before subtracting, so customers are overcharged by one cent when the discount's third decimal is ≥ 5<br>`DiscountCalculator.cs:16-17` · medium · med: `ToZero` is asymmetric, so negative amounts (credit notes) err the other way, and inputs with more than 2 decimals are truncated | |
| case-04 | none | `DEFECTS: 0` / `No defects found.` | |
| case-05 | 3 defects | `InvoicesController.cs:44` · critical · high: the new `Delete` has no `[RequireRole("Admin")]`, so any signed-in user can delete invoices<br>`InvoicesController.cs:47` · medium · med: not wrapped in `Handle(...)`, so a missing id gives 500 or a false 204 and a misleading log line<br>`InvoicesController.cs:47` · medium · med: skips the domain lifecycle, so Approved or Pending invoices can be deleted | |
| case-06 | none | `DEFECTS: 0` / `No defects found.` | |
| case-07 | 2 defects | `ApprovalsController.cs:35` · critical · high: `{@Invoice}` and `{@Session}` put customer data and the user's session details in the logs<br>`ApprovalsController.cs:34` · low · low: `_logger` may not be injected, so the build could break | |
| case-08 | 2 defects | `InMemoryInvoiceRepository.cs:9` · high · med: `Dictionary` shared across requests isn't thread-safe; it can corrupt, throw, or loop forever<br>`InMemoryInvoiceRepository.cs:24` · medium · med: a check followed by a write isn't atomic; a concurrent duplicate add silently overwrites | |
| case-09 | 1 defect | `README.md:25` · low · med: the README says signing out and back in resets the sample data; only a restart does | |
| case-10 | 1 defect | `ApiControllerBase.cs:37` · critical · high: the catch-all turns every unexpected exception into 200 `{status:"completed"}`, unlogged | |

The reviewers' full text is in the [Full reviewer output](#full-reviewer-output) section below.

## Reviewer behaviour (unscored facts)

| Measure | Run 3 | Run 2 | Run 1 |
|---|---|---|---|
| Cases where the reviewer reported at least one defect | 8 of 10 | 8 of 10 | 8 of 10 |
| Cases where the reviewer said "No defects found." | 2 of 10 (04, 06) | 2 of 10 (04, 06) | 2 of 10 (04, 06) |
| Total findings | 17 | 15 | 18 |
| Findings by severity | critical 5 · high 5 · medium 5 · low 2 | critical 5 · high 4 · medium 4 · low 2 | critical 7 · high 5 · medium 5 · low 1 |
| Findings by confidence | high 6 · medium 9 · low 2 | high 5 · medium 9 · low 1 | high 7 · medium 8 · low 3 |
| Reviews that followed the required output format | 10 of 10 | 10 of 10 | 10 of 10 |

## Across all three runs

### Did the reviewer flag the case?

The same 8 cases were flagged and the same 2 passed in every run. However the key falls, each case's verdict is likely to be the same in all three runs, so the three-run rates will probably equal the single-run rates.

| Case | Run 1 | Run 2 | Run 3 | Main finding (same in all three runs) | Main finding's severity, runs 1/2/3 |
|---|---|---|---|---|---|
| case-01 | defect | defect | defect | `Approve` outside `Handle`, so errors become 500; batch not atomic | high / high / high |
| case-02 | defect | defect | defect | SQL injection through `customer` and `status` | critical / critical / critical |
| case-03 | defect | defect | defect | `ToZero` truncation of the discount overcharges by a cent | high / high / high |
| case-04 | none | none | none | none | none |
| case-05 | defect | defect | defect | `Delete` is missing `[RequireRole("Admin")]` | critical / critical / critical |
| case-06 | none | none | none | none | none |
| case-07 | defect | defect | defect | Destructuring `{@Session}` and `{@Invoice}` into the logs | critical / critical / critical |
| case-08 | defect | defect | defect | `Dictionary` replaced `ConcurrentDictionary` in a shared store | critical / high / high |
| case-09 | defect | defect | defect | The README's sign-out-resets-data claim is false | low / low / low |
| case-10 | defect | defect | defect | The catch-all returns 200 "completed" on any exception | critical / critical / critical |

### Extra findings: which recur and which don't

When the key is applied, these decide whether a flagged case also carries extra false claims (see the scoring conventions in [run-1.md](run-1.md#score-fill-in-from-the-answer-key)).

| Case | Extra finding | Runs it appeared in |
|---|---|---|
| case-01 | Nullable `Ids` iterated without a null check | 3 of 3 |
| case-01 | No limit on the number of ids | 1 of 3 (run 2) |
| case-02 | `_queries` isn't declared or registered | 3 of 3 |
| case-03 | Asymmetric for negative amounts (credit notes), or truncation of inputs with more than 2 decimals | 3 of 3 (separate finding in run 3; inside the main finding in runs 1 and 2) |
| case-05 | Not wrapped in `Handle`, so a missing id gives 500 or a false 204 | 3 of 3 |
| case-05 | Skips the domain lifecycle checks | 3 of 3 (merged into the `Handle` finding in run 2) |
| case-07 | `_logger` may not be injected | 2 of 3 (runs 1 and 3) |
| case-08 | Check followed by a write isn't atomic | 3 of 3 |
| case-10 | Error path returns a different response shape | 3 of 3 (separate finding in run 1; inside the main finding in runs 2 and 3) |

### How stable each field is

| Field | Stable across runs? |
|---|---|
| Whether the case has a defect | **Yes**: identical in 10 of 10 cases |
| Main finding | **Yes**: the same defect in every flagged case |
| File and line of the main finding | Mostly; varies by 1–2 lines in cases 07, 08 and 10 |
| Severity of the main finding | Mostly; case-08 changed (critical, then high, high) and case-07's invoice-logging finding changed when it was reported separately |
| Extra findings | **No**: they are dropped, merged or added from run to run (15–18 findings in total) |
| Confidence | Somewhat; it varies by one level for the same finding |

## Score (fill in from the answer key)

Let **D** be the number of defect cases in the key and **C** the number of clean cases (D + C = 10).

| Measure | Run 3 count | Run 3 rate | All 3 runs count | All 3 runs rate | Formula (all runs) |
|---|---|---|---|---|---|
| Caught | | | | | caught ÷ (D × 3) |
| Missed | | | | | missed ÷ (D × 3) |
| False alarm | | | | | false alarms ÷ (C × 3) |
| Correct pass | | | | | correct passes ÷ (C × 3) |

Use the same scoring conventions as run 1 (see [run-1.md](run-1.md#score-fill-in-from-the-answer-key)).

## Full reviewer output

<details><summary>case-01</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:51 | high | confidence medium
   What goes wrong: `_approvals.Approve` is called directly, not through `Handle(...)`. Any service error therefore escapes as an unhandled exception (500) instead of being mapped to 404, 409 or 400.
   Failure scenario: An Approver posts `{"ids":["INV-1","does-not-exist"]}`. The second id throws a not-found error from the service, and the caller gets a 500 instead of a 404. Assumption: `Approve` throws for unknown or non-pending invoices, as the `Handle` convention implies.
   Fix: Wrap the bulk operation in `Handle(...)` the same way the single-invoice endpoints do.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49 | high | confidence medium
   What goes wrong: The loop is not atomic. Approvals made before a failing id stay committed, but the request still fails, so the caller cannot tell which invoices were approved.
   Failure scenario: `{"ids":["INV-1","INV-2","INV-1"]}`. INV-1 and INV-2 are approved. The repeated INV-1 is no longer pending, so it throws (409 or 500). The client sees an error and may retry, while two invoices are already approved. An already-approved or rejected id in the middle of the list behaves the same way.
   Fix: Check every id first (it exists, it is pending, no duplicates) before approving any, or return a result for each id. Put that logic in the Domain service, not the controller.

3. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49 | medium | confidence high
   What goes wrong: `Ids` is declared nullable (`List<string>?`), but it is iterated without a null check, and the request body itself can also be null.
   Failure scenario: An Approver posts `{}` or `{"ids":null}`. `foreach` over the null `request.Ids` throws a NullReferenceException, and the caller gets a 500 instead of a 400.
   Fix: Return 400 (BadRequest) when `request?.Ids` is null or empty, before the loop.
```
</details>

<details><summary>case-02</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:28 | critical | confidence high
   What goes wrong: The `customer` query parameter goes straight into the SQL text through string interpolation, which allows SQL injection.
   Failure scenario: A signed-in user calls `GET /api/invoices/search?customer=%' OR '1'='1' --`. The query becomes `... LIKE '%%' OR '1'='1' --%'` and returns every invoice. A payload such as `x'; DELETE FROM Invoices; --` could also destroy data if the query runner allows multiple statements.
   Fix: Use a parameterised query (for example `LIKE @customer` with the value `"%" + customer + "%"` bound as a parameter), or filter through the repository instead of building raw SQL.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:32 | critical | confidence high
   What goes wrong: The optional `status` query parameter is also interpolated directly into the SQL, which is a second injection point.
   Failure scenario: `GET /api/invoices/search?customer=a&status=' OR '1'='1` turns the filter into `Status = '' OR '1'='1'`. That bypasses the filter and allows any arbitrary SQL to be appended.
   Fix: Bind `status` as a parameter, or parse it into the invoice status enum and reject values that do not match.

3. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:35 | high | confidence low
   What goes wrong: The diff calls `_queries.Run(sql)`, but it never declares, injects or registers a `_queries` dependency. The rest of the controller uses `_repository`, which is in-memory, so there is probably no SQL backend to run this against.
   Failure scenario: If no `_queries` field exists outside the hunk, the project fails to compile. If it exists but is not registered in `Program.cs`, the controller fails to construct on every request, which breaks all invoice endpoints. This assumes code I cannot see in the diff.
   Fix: Search through the existing `IInvoiceRepository`, with the filter logic in the Domain project, instead of an unregistered raw-SQL query runner.
```
</details>

<details><summary>case-03</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Domain/DiscountCalculator.cs:16 | high | confidence medium
   What goes wrong: The discount is now cut off to 2 decimals (`MidpointRounding.ToZero` truncates; it does not round) before it is subtracted. When the discount's third decimal is 5 or more, the customer gets up to 0.01 less discount, and the totals no longer match the old `AwayFromZero` result.
   Failure scenario: amount = 1.00, discountPercent = 0.6. The discount is 0.006. The old code returned Round(0.994, AwayFromZero) = 0.99. The new code truncates the discount to 0.00 and returns 1.00. In the same way, amount = 100.00 at 12.346% gives a discount of 12.346: the old result was 87.65, the new one is 87.66. Every invoice whose discount has a third decimal of 5 or more is overcharged by one cent.
   Fix: Keep a single round-half-away-from-zero on the final value (`Math.Round(amount - discount, 2, MidpointRounding.AwayFromZero)`), or round the discount with `AwayFromZero` instead of truncating it, if the discount has to be rounded on its own.

2. backend/src/InvoiceApp.Domain/DiscountCalculator.cs:16-17 | medium | confidence medium
   What goes wrong: `ToZero` truncates toward zero, so the result changes direction with the sign. For negative amounts (credit notes or refunds), truncating the discount and the result moves the value toward zero. That shrinks the credit, which is the opposite of the error on positive amounts. Amounts with more than 2 decimals are also cut off instead of rounded.
   Failure scenario: amount = -1.00, discountPercent = 0.6. The discount is -0.006, truncated to 0.00, so the result is -1.00. The old code gave Round(-0.994, AwayFromZero) = -0.99. Separately, amount = 10.009 with 0% discount now returns 10.00 instead of 10.01.
   Fix: Use one symmetric midpoint mode (`AwayFromZero` or `ToEven`) on the final result instead of directed truncation.
```
</details>

<details><summary>case-04</summary>

```
DEFECTS: 0
No defects found.
```
</details>

<details><summary>case-05</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:44 | critical | confidence high
   What goes wrong: The new `Delete` endpoint has no `[RequireRole("Admin")]` attribute. The project convention says destructive actions are Admin only, and the neighbouring `Update` action has that attribute.
   Failure scenario: A user signed in as `demo.approver` (role Approver) sends `DELETE /api/invoices/{id}`. The request passes only the global sign-in check, the invoice is permanently removed, and the response is 204.
   Fix: Add `[RequireRole("Admin")]` to the `Delete` action.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47 | medium | confidence medium
   What goes wrong: The call is not wrapped in `Handle(...)`, so repository or service errors are not mapped to 404, 409 or 400. The log line and the 204 response run whatever the outcome. (This assumes `Delete` either throws or quietly does nothing for an unknown id; the repository code is not in the diff.)
   Failure scenario: A client sends `DELETE /api/invoices/does-not-exist`. Either the repository throws and the client gets an unhandled 500 instead of 404, or it does nothing and the client gets 204 plus an audit log entry saying "Invoice does-not-exist deleted", which is false.
   Fix: Use `return Handle(() => _repository.Delete(id));` (or an equivalent that returns 404 when the id is missing) and write the log entry only after the delete succeeds.

3. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47 | medium | confidence medium
   What goes wrong: The endpoint calls the repository directly and skips `ApprovalService`, which owns the invoice lifecycle. Invoices in any state can be deleted with no domain rule checked.
   Failure scenario: An invoice that is `Approved` (or `PendingApproval`) gets a DELETE request. It is removed with no 409, so the record of an approval decision disappears with no lifecycle check.
   Fix: Put the deletion rule (which states allow deletion) in the Domain service, call it through `Handle(...)`, and add tests that use `FakeInvoiceRepository`.
```
</details>

<details><summary>case-06</summary>

```
DEFECTS: 0
No defects found.
```
</details>

<details><summary>case-07</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:35 | critical | confidence high
   What goes wrong: The `{@Invoice}` and `{@Session}` placeholders destructure the whole invoice object and the whole `CurrentUser` object into the application log. That writes customer and invoice data, plus the signed-in user's session details, to plain-text logs. The session details may include claims, a session id or a token.
   Failure scenario: An Approver approves any invoice. The log sink receives the full invoice (customer name, amounts, any bank or payment fields) and the serialised current-user object. Anyone who can read the logs, or any downstream log aggregator, can then see customer data and could reuse session identifiers to impersonate the approver.
   Fix: Log only non-sensitive scalar fields, such as `invoice.Id`, the new status and `CurrentUser.Name`, and never destructure the invoice or the session object.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:34 | low | confidence low
   What goes wrong: The code uses `_logger`, but the diff shows no field declaration or constructor injection for it. The hunk header claims 6 added lines and only 4 are shown, so the declaration may be in the missing lines. I am assuming it is not in the existing code.
   Failure scenario: If `ApprovalsController` has no `ILogger<ApprovalsController> _logger` injected, the project fails to compile and the approve endpoint cannot ship.
   Fix: Inject `ILogger<ApprovalsController>` through the constructor and assign it to a readonly `_logger` field, or confirm one already exists.
```
</details>

<details><summary>case-08</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:9 | high | confidence medium
   What goes wrong: The thread-safe `ConcurrentDictionary` is swapped for a plain `Dictionary`, but this repository is shared across concurrent web requests. `Dictionary` is not safe when one thread writes while others read or write.
   Failure scenario: I'm assuming the repository is registered as a singleton in `Program.cs`, which is not shown in the diff. Two users create or approve invoices at the same moment, so `Add`/`Update` writes overlap with each other or with `GetById` and any listing. The dictionary's internal state can then be corrupted, which shows up as lost entries, `InvalidOperationException` ("Collection was modified") while a listing enumerates, `IndexOutOfRangeException`, or a thread stuck in an endless loop.
   Fix: Go back to `ConcurrentDictionary<string, Invoice>`, or wrap every access, including enumeration, in a lock.

2. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:24 | medium | confidence medium
   What goes wrong: The duplicate check is no longer atomic. `ContainsKey` (line 19) and the indexer assignment (line 24) are two separate steps, and the indexer silently overwrites an existing key. Before this change, `TryAdd` did both in one step.
   Failure scenario: Two concurrent `Add` calls use the same invoice Id, for example a client retry or a double-submit. Both pass `ContainsKey`, both assign, and the second invoice silently replaces the first. That is lost data, and neither caller gets the "already exists" error.
   Fix: Use `ConcurrentDictionary.TryAdd` again, or do the check and the insert under one lock using `Dictionary.TryAdd`.
```
</details>

<details><summary>case-09</summary>

```
DEFECTS: 1

1. README.md:25 | low | confidence medium
   What goes wrong: The README says signing out and back in resets the sample data. The diff does not change any code to do that, and an in-memory repository registered for the life of the process is not tied to a user's sign-in.
   Failure scenario: A user creates or approves invoices, signs out and signs back in expecting fresh sample data. The old invoices and their states are still there, because only restarting the process clears the in-memory store, as line 22-23 of the same README says. This assumes the repository is a singleton that sign-out does not touch, which is the usual setup but cannot be seen in the diff.
   Fix: Remove the sign-out reset sentence, or say that restarting the app is the only way to reset the data.
```
</details>

<details><summary>case-10</summary>

```
DEFECTS: 1

1. backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:37 | critical | confidence high
   What goes wrong: The new `catch (Exception)` catches every unexpected failure and returns HTTP 200 with `{ status = "completed" }`. The exception is also discarded without being logged. Callers are told the operation succeeded when it actually failed.
   Failure scenario: An approver calls the approve endpoint, and the action throws an unexpected exception partway through, for example a `NullReferenceException` from a missing field or a repository/storage error. The client gets 200 "completed", so the UI shows the invoice as approved or saved. The change was never stored, or was only partly applied. The user and any downstream process act on a false success, the data is silently lost or inconsistent, and there is no log or 500 that would let anyone notice. The 200 body also lacks the action's real return value, so callers that read the response get the wrong shape.
   Fix: Remove the catch-all so unexpected exceptions reach the framework's 500 handling. If a catch-all is needed, log the exception and return a 500 problem response, never `Ok`.
```
</details>
