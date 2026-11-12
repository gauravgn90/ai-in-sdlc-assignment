# Review eval: run 1 (raw, not yet scored)

**Status: NOT SCORED.** The answer key is not in this repository (`ops/evals/README.md:4-5`, `ops/README.md:27-30`); it is in the facilitator's session runbook. This file records what each reviewer reported. The verdict column and the counts and rates below stay blank until someone fills them in from the key.

## Run setup

| Field | Value |
|---|---|
| Run | 1 (of 3 planned) |
| Date | 2026-11-10 |
| Prompt | `ops/evals/review-prompt.md`, **v2** (body below the line, verbatim) |
| Reviewer | A fresh general-purpose Claude Code subagent per case. Model: the session default, not separately recorded |
| Input given | The v2 prompt and that case's diff, inline. Nothing else: no repo access, no README, no other cases, no answer key |
| Isolation | Each reviewer was told not to use tools. Each made exactly one tool call, its hand-back, so none read any files |
| Order | All 10 started in parallel and shared no context with each other |

## Results by case

The **Verdict** column takes one of: `caught` (named the actual defect), `missed`, `false alarm` (claimed a defect in a clean case), or `correct pass` (clean case, no defect claimed). Score by the rules in `ops/evals/README.md:38-47`: be strict, and remember that style notes on a clean case are not false alarms.

| Case | Reported | Findings (file:line · severity · confidence: summary) | Verdict |
|---|---|---|---|
| case-01 | 3 defects | `ApprovalsController.cs:51` · high · med: `Approve` called outside `Handle(...)`, so not-found and wrong-state errors become 500 instead of 404/409<br>`ApprovalsController.cs:49` · high · med: the batch isn't atomic; a failure partway leaves earlier invoices approved with no per-id result, and a retry fails<br>`ApprovalsController.cs:49` · medium · high: nullable `Ids` is iterated without a null check; `{}` or `{"ids":null}` causes a NullReferenceException and a 500 | |
| case-02 | 3 defects | `InvoicesController.cs:28` · critical · high: SQL injection through `customer`, interpolated into the query<br>`InvoicesController.cs:32` · critical · high: SQL injection through `status`<br>`InvoicesController.cs:35` · high · med: `_queries` isn't declared in the diff, and there's no SQL `Invoices` table in an in-memory app | |
| case-03 | 1 defect | `DiscountCalculator.cs:16` · high · med: `MidpointRounding.ToZero` truncates rather than rounds, applied twice; the discount is under-applied, so customers are overcharged by up to 0.01, and the old rounding behaviour changes | |
| case-04 | none | `DEFECTS: 0` / `No defects found.` | |
| case-05 | 3 defects | `InvoicesController.cs:44` · critical · high: the new `Delete` has no `[RequireRole("Admin")]`, so any signed-in user can delete invoices<br>`InvoicesController.cs:47` · medium · med: not wrapped in `Handle(...)`, so a missing id gives 500 or a false 204 instead of 404<br>`InvoicesController.cs:47` · medium · low: skips the domain layer, so there's no check on the invoice's status before deleting | |
| case-06 | none | `DEFECTS: 0` / `No defects found.` | |
| case-07 | 3 defects | `ApprovalsController.cs:36` · critical · med: logs the whole `CurrentUser` session object (`{@Session}`), so session or token data ends up in the logs<br>`ApprovalsController.cs:36` · critical · med: logs the whole invoice (`{@Invoice}`), putting customer and financial data in the logs<br>`ApprovalsController.cs:34` · medium · low: `_logger` may not be injected, so the build could break | |
| case-08 | 2 defects | `InMemoryInvoiceRepository.cs:9` · critical · high: `ConcurrentDictionary` replaced with `Dictionary` in a singleton store; concurrent requests can corrupt it, hang, or throw<br>`InMemoryInvoiceRepository.cs:19` · high · high: the atomic `TryAdd` becomes a check followed by a write; two concurrent adds of the same id silently overwrite each other | |
| case-09 | 1 defect | `README.md:25` · low · low: the README says signing out and back in resets the sample data, which contradicts the line above it (data is reset only on restart); likely misleads users | |
| case-10 | 2 defects | `ApiControllerBase.cs:37` · critical · high: the catch-all turns every unexpected exception into 200 `{status:"completed"}`, so failures are reported as success and never logged<br>`ApiControllerBase.cs:37` · medium · med: the error path returns 200 with a different body shape, breaking callers' expectations of a success response | |

The reviewers' full text, including failure scenarios and fixes, is in the [Full reviewer output](#full-reviewer-output) section below.

## Reviewer behaviour (unscored facts)

These describe what the reviewers did, not whether they were right.

| Measure | Value |
|---|---|
| Cases where the reviewer reported at least one defect | 8 of 10 (01, 02, 03, 05, 07, 08, 09, 10) |
| Cases where the reviewer said "No defects found." | 2 of 10 (04, 06) |
| Total findings | 18 |
| Findings by severity | critical 7 · high 5 · medium 5 · low 1 |
| Findings by confidence | high 7 · medium 8 · low 3 |
| Reviews that followed the required output format | 10 of 10 |

## Score (fill in from the answer key)

Let **D** be the number of defect cases in the key and **C** the number of clean cases (D + C = 10).

| Measure | Count | Rate | Formula |
|---|---|---|---|
| Caught | | | caught ÷ D |
| Missed | | | missed ÷ D |
| False alarm | | | false alarms ÷ C |
| Correct pass | | | correct passes ÷ C |

**Agree these conventions before scoring, since the README doesn't cover them:**
- A defect case where the review names the real defect and also claims something that isn't a defect is scored **caught**. Record the extra claim in Notes and count it separately as an extra false claim.
- A correct finding at the wrong line, or for the wrong reason, is scored **missed** (`README.md:40-43`).
- Run 1 alone gives only one result per case. The README asks for three runs before treating these as rates (`README.md:27-28`).

## Full reviewer output

<details><summary>case-01</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:51 | high | confidence medium
   What goes wrong: The bulk loop calls `_approvals.Approve` directly instead of going through `Handle(...)`. Service errors therefore never become 404/409/400. They escape as unhandled exceptions and the client gets a 500.
   Failure scenario: A POST with `{"ids":["unknown-id"]}`, or with the id of an invoice that is already Approved or Rejected, makes `Approve` throw its not-found or invalid-state error. The single-approve endpoint would return 404 or 409 for that, but this endpoint returns 500. (Assumption: `Approve` throws for these cases, as the `Handle` convention suggests.)
   Fix: Wrap the operation in `Handle(...)`, like the other endpoints do, so service errors map to the proper status codes.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49 | high | confidence medium
   What goes wrong: Approvals are applied one at a time and are not atomic. If one id fails partway through, the earlier invoices stay approved, but the request returns an error with no list of what succeeded.
   Failure scenario: The request is `{"ids":["A","B","A"]}` (a duplicate), or `["A","bad-id","C"]`. A is approved and saved, then the next `Approve` throws. The caller gets an error response even though A is now Approved and C was skipped. A retry then fails on A because it is already approved, so the batch can never complete cleanly.
   Fix: Validate all ids first (they must exist, be distinct and be PendingApproval) in a Domain bulk-approve method before changing any invoice. Otherwise, return a result for each id saying whether it succeeded or failed.

3. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49 | medium | confidence high
   What goes wrong: `Ids` is declared nullable (`List<string>?`), but `request.Ids` is used in `foreach` without a null check. A missing or null `ids` field, or an empty body that leaves `request` null, throws NullReferenceException.
   Failure scenario: A POST to `api/approvals/bulk-approve` with `{}` or `{"ids":null}` makes `foreach` throw a NullReferenceException, and the client gets a 500 instead of a 400.
   Fix: Return 400 (BadRequest) when `request` or `request.Ids` is null, or make `Ids` non-nullable so model validation rejects the request.
```
</details>

<details><summary>case-02</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:28 | critical | confidence high
   What goes wrong: The `customer` query parameter goes straight into the SQL text through string interpolation, so this is SQL injection.
   Failure scenario: `GET /api/invoices/search?customer=' OR 1=1; DROP TABLE Invoices; --` turns into `... LIKE '%' OR 1=1; DROP TABLE Invoices; --%'`. Any signed-in user could read every invoice or change and delete data, whatever their role.
   Fix: Use a parameterised query (`LIKE @customer` with the value `%` + customer + `%` bound as a parameter), or filter through the repository instead of raw SQL.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:32 | critical | confidence high
   What goes wrong: The optional `status` parameter is also put into the SQL text without escaping, which is a second injection point.
   Failure scenario: `GET /api/invoices/search?customer=a&status=x' UNION SELECT * FROM Users --` adds attacker-controlled SQL and returns data from other tables.
   Fix: Bind `status` as a parameter, or parse it into the `InvoiceStatus` enum first and reject values that do not match.

3. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:35 | high | confidence medium
   What goes wrong: `_queries` is not declared or injected anywhere in this diff. The project stores invoices in an in-memory repository, so there is no `Invoices` SQL table for this query to run against.
   Failure scenario: Assuming no `_queries` field exists outside the diff, the controller does not compile and the build breaks. If some query runner does exist, it has no `Invoices` table to read, so every search request fails at runtime.
   Fix: Do the search through `_repository` (for example a `Search(customer, status)` method on the repository interface in Domain), with tests that use `FakeInvoiceRepository`.
```
</details>

<details><summary>case-03</summary>

```
DEFECTS: 1

1. backend/src/InvoiceApp.Domain/DiscountCalculator.cs:16 | high | confidence medium
   What goes wrong: The change replaces the old single round-half-away-from-zero on the final amount with truncation applied twice. On decimals, `MidpointRounding.ToZero` truncates every value, not just midpoints. So the discount is cut down to whole cents before it is subtracted. The discount is under-applied and the customer is overcharged by up to 0.01 on any discount that is not a whole number of cents. The old rounding rule is also silently broken for existing callers and tests.
   Failure scenario: Apply(20.00m, 16.685m) gives a discount of 3.337. The old code returned round(16.663) = 16.66. The new code truncates the discount to 3.33 and returns 16.67, one cent more than before. Inputs with more than 2 decimal places are also truncated instead of rounded: Apply(10.009m, 0m) used to return 10.01 and now returns 10.00. For negative amounts such as credit notes, the outer ToZero rounds toward zero, so those also differ from the AwayFromZero results.
   Fix: Restore `Math.Round(amount - discount, 2, MidpointRounding.AwayFromZero)`. If the discount must be rounded on its own, round it with AwayFromZero, and update the tests to match whichever rule is intended.
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
   What goes wrong: The new `Delete` endpoint has no `[RequireRole("Admin")]` attribute, so sign-in is the only check. Any signed-in user can permanently delete invoices. The project rule says destructive actions are Admin only, and the neighbouring `Update` action carries the attribute.
   Failure scenario: `demo.approver` (role Approver) sends `DELETE /api/invoices/{id}` and gets 204. The invoice is removed, which is unauthorised data loss.
   Fix: Add `[RequireRole("Admin")]` to the `Delete` action.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47 | medium | confidence medium
   What goes wrong: `_repository.Delete(id)` is called directly instead of through `Handle(...)`, so the not-found case does not map to 404. I am assuming the repository either throws or returns a bool for a missing id; the diff does not show which.
   Failure scenario: A client deletes an id that does not exist. If the repository throws, the client gets an unhandled 500. If it returns false, the result is ignored and the client still gets 204 and is told the delete worked.
   Fix: Wrap the call in `Handle(...)`, the way the other actions do, so a missing invoice returns 404.

3. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47 | medium | confidence low
   What goes wrong: The delete goes straight to the repository and skips the domain layer (`ApprovalService`, which owns the lifecycle). Nothing checks the invoice's state before it is removed. I am assuming the domain does not allow deleting invoices once they are past Draft.
   Failure scenario: An invoice that is PendingApproval or Approved is deleted mid-workflow, and the record of the approval is lost.
   Fix: Move the delete into a Domain service method that enforces the allowed states, and call that method from the controller through `Handle(...)`.
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
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:36 | critical | confidence medium
   What goes wrong: The whole `CurrentUser` object is logged with structured destructuring (`{@Session}`). This writes session and identity data, such as claims, the auth cookie or ticket, and possibly a token, into the application logs.
   Failure scenario: An Approver approves any invoice. With Serilog or any other destructuring sink, every public property of `CurrentUser` goes to the log store. Anyone who can read the logs can then collect that session data and may be able to replay or impersonate the session. (This assumes `CurrentUser` carries more than a display name. Its type is not in the diff.)
   Fix: Log only a non-sensitive identifier such as `CurrentUser.Name`, never the session or user object.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:36 | critical | confidence medium
   What goes wrong: The entire invoice is destructured into the log (`{@Invoice}`). Customer and financial data (supplier or customer names, amounts, and any bank or payment details) leaves the controlled data store and is copied into logs that usually have wider access and longer retention.
   Failure scenario: Each successful approval writes the full invoice record to the logs, which leaks customer data to everyone who has log access and to every downstream log sink.
   Fix: Log only the invoice ID and the new status, for example `"Invoice {InvoiceId} approved by {Approver}"`.

3. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:34 | medium | confidence low
   What goes wrong: The new code uses `_logger`, but the diff adds no `ILogger<ApprovalsController>` field and no constructor injection for it.
   Failure scenario: If the controller does not already declare and inject `_logger` (outside the visible hunk), the project fails to compile and the API cannot be built or deployed.
   Fix: Inject `ILogger<ApprovalsController>` through the constructor and assign it to a readonly `_logger` field, or confirm one already exists.
```
</details>

<details><summary>case-08</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:9 | critical | confidence high
   What goes wrong: The shared, thread-safe `ConcurrentDictionary` is replaced with a plain `Dictionary`. This repository is used by concurrent web requests (I am assuming it is registered as a singleton in `Program.cs`, which an in-memory store needs in order to keep its data). `Dictionary` is not safe when several threads write to it, or when one thread writes while another reads.
   Failure scenario: Two requests call `Add` or `Update` (line 27) at the same moment, or one request lists invoices while another adds one. Concurrent writes can corrupt the dictionary's internal buckets. After that, invoices can be lost, lookups can return wrong results, or a read can loop forever and hang the request thread. A listing that runs during a write can also throw `InvalidOperationException: Collection was modified` and return a 500.
   Fix: Restore `ConcurrentDictionary<string, Invoice>`, or guard every read and write with a lock.

2. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:19 | high | confidence high
   What goes wrong: The atomic `TryAdd` is replaced with a separate check (`ContainsKey` on line 19) followed by a write (the indexer on line 24). The indexer overwrites an existing entry, so the duplicate-ID guard is no longer reliable.
   Failure scenario: Two concurrent `Add` calls use the same invoice ID. Both see `ContainsKey` return false, and both write on line 24. The second invoice silently replaces the first. Neither caller gets the "already exists" exception, and the first invoice is lost.
   Fix: Use `ConcurrentDictionary.TryAdd` again, or do the check and the insert inside one lock using `Dictionary.TryAdd`.
```
</details>

<details><summary>case-09</summary>

```
DEFECTS: 1

1. README.md:25 | low | confidence low
   What goes wrong: The new README line says signing out and back in resets the sample data. Nothing in this diff adds a reset, and the line just above says the in-memory store is only recreated when the process starts. So signing out most likely does not reset anything. (I'm assuming the existing sign-out code only ends the session and leaves the repository alone; I can't see that code.)
   Failure scenario: A user changes or approves invoices, signs out and signs back in to get clean data, as the README says. The changed invoices are still there. They have to restart the process instead, and they may think the app has a bug.
   Fix: Remove the sentence, or change it to say that restarting the process is the only way to reset the sample data.
```
</details>

<details><summary>case-10</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:37 | critical | confidence high
   What goes wrong: The new catch-all `catch (Exception)` turns every unexpected failure into HTTP 200 with `{ status = "completed" }`. Failed operations get reported as successes, and the exception is never logged or passed on.
   Failure scenario: An approver calls the approve endpoint and `ApprovalService` or the repository throws an unexpected exception, such as a `NullReferenceException` or `FormatException`, partway through. That could be after one invoice field changed but before the save finished. The client gets 200 "completed" and the UI shows the invoice as approved, but it is still pending or only half updated. No 500 is returned and nothing is logged, so the corruption cannot be seen or traced. The same happens for a destructive Admin action that never actually deleted anything.
   Fix: Remove the catch-all so unexpected exceptions go to ASP.NET Core's error handling, which logs them and returns 500. If a generic handler is needed, log the exception and return `StatusCode(500, ...)`.

2. backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:37 | medium | confidence medium
   What goes wrong: On a successful call, `Handle` returns the action's result, such as an invoice object. On this new path it returns 200 with a different body, `{ status: "completed" }`. That breaks the contract for any caller that relies on a 200 response having the normal payload shape.
   Failure scenario: The web UI or an API client calls GET or approve on an invoice and an unexpected exception is caught here. The client sees 200, reads the body as an invoice, and gets undefined fields or crashes during deserialisation. The real error never shows up.
   Fix: Never return a success status from an exception path. Return a non-2xx error response, or let the exception propagate.
```
</details>
