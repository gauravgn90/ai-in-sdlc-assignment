# Review eval: run 2 (raw, not yet scored)

**Status: NOT SCORED.** The answer key is not in this repository (`ops/evals/README.md:4-5`, `ops/README.md:27-30`); it is in the facilitator's session runbook. This file records what each reviewer reported. The verdict column and the counts and rates below stay blank until someone fills them in from the key.

## Run setup

Same as [run 1](run-1.md). Exactly one thing would change between runs, and nothing did: this is a repeat to measure how much the results vary.

| Field | Value |
|---|---|
| Run | 2 (of 3 planned) |
| Date | 2026-11-10 |
| Prompt | `ops/evals/review-prompt.md`, **v2** (body below the line, verbatim) |
| Reviewer | A fresh general-purpose Claude Code subagent per case. Model: the session default, not separately recorded |
| Input given | The v2 prompt and that case's diff, inline. Nothing else: no repo access, no README, no other cases, no answer key, no run-1 output |
| Isolation | Each reviewer was told not to use tools. Each made exactly one tool call, its hand-back, so none read any files |
| Order | All 10 started in parallel and shared no context with each other or with run 1 |

## Results by case

The **Verdict** column takes one of: `caught`, `missed`, `false alarm`, or `correct pass`. Score by the rules in `ops/evals/README.md:38-47`.

| Case | Reported | Findings (file:line · severity · confidence: summary) | Verdict |
|---|---|---|---|
| case-01 | 3 defects | `ApprovalsController.cs:51` · high · med: `Approve` called outside `Handle(...)` and the batch isn't atomic; a bad id midway gives a 500 after earlier ids were approved<br>`ApprovalsController.cs:49` · medium · high: nullable `Ids` is iterated without a null check; `{}` or `{"ids":null}` causes a NullReferenceException and a 500<br>`ApprovalsController.cs:41` · low · med: no limit on how many ids a request can contain | |
| case-02 | 3 defects | `InvoicesController.cs:28` · critical · high: SQL injection through `customer`<br>`InvoicesController.cs:32` · critical · high: SQL injection through `status`<br>`InvoicesController.cs:35` · high · low: `_queries` isn't declared or injected, so the build or DI can break | |
| case-03 | 1 defect | `DiscountCalculator.cs:16` · high · med: the discount is truncated (`ToZero`) before subtracting, so customers are overcharged by up to 0.01, and the rounding is asymmetric for negative amounts | |
| case-04 | none | `DEFECTS: 0` / `No defects found.` | |
| case-05 | 2 defects | `InvoicesController.cs:44` · critical · high: the new `Delete` has no `[RequireRole("Admin")]`, so any signed-in user can delete invoices<br>`InvoicesController.cs:47` · medium · med: not wrapped in `Handle(...)`, so a missing id gives 500 or a false 204, and the domain's status checks are skipped | |
| case-06 | none | `DEFECTS: 0` / `No defects found.` | |
| case-07 | 2 defects | `ApprovalsController.cs:36` · critical · med: `{@Session}` destructures the whole `CurrentUser` object, so token or claims data ends up in the logs<br>`ApprovalsController.cs:35` · medium · med: `{@Invoice}` puts customer and financial data in the logs | |
| case-08 | 2 defects | `InMemoryInvoiceRepository.cs:9` · high · med: `Dictionary` in a shared singleton isn't thread-safe; it can corrupt, throw, or spin forever<br>`InMemoryInvoiceRepository.cs:24` · medium · med: a check followed by a write isn't atomic; two concurrent adds with the same id overwrite each other silently | |
| case-09 | 1 defect | `README.md:25` · low · med: the README says signing out and back in resets the sample data; it doesn't, because the in-memory repository is reseeded only at startup | |
| case-10 | 1 defect | `ApiControllerBase.cs:35` · critical · high: the catch-all turns every unexpected exception into 200 `{status:"completed"}`, unlogged, so failures look like success | |

The reviewers' full text is in the [Full reviewer output](#full-reviewer-output) section below.

## Reviewer behaviour (unscored facts)

| Measure | Run 2 | Run 1 |
|---|---|---|
| Cases where the reviewer reported at least one defect | 8 of 10 (01, 02, 03, 05, 07, 08, 09, 10) | 8 of 10 (same cases) |
| Cases where the reviewer said "No defects found." | 2 of 10 (04, 06) | 2 of 10 (04, 06) |
| Total findings | 15 | 18 |
| Findings by severity | critical 5 · high 4 · medium 4 · low 2 | critical 7 · high 5 · medium 5 · low 1 |
| Findings by confidence | high 5 · medium 9 · low 1 | high 7 · medium 8 · low 3 |
| Reviews that followed the required output format | 10 of 10 | 10 of 10 |

## Consistency with run 1

**On whether each case has a defect, the reviewer agreed in all 10 cases.** It flagged the same 8 cases and passed the same 2. The main finding in every flagged case is the same in both runs. What varies is the extra findings and the severity given.

| Case | Main finding, same in both runs? | What changed in run 2 |
|---|---|---|
| case-01 | Yes (outside `Handle`, not atomic, null `Ids`) | Run 1's separate atomicity finding is folded into finding 1; a new **low** finding about an unbounded id list |
| case-02 | Yes (SQL injection ×2) | Same three findings; `_queries` confidence fell from medium to low |
| case-03 | Yes (truncation overcharges) | Same finding, different worked example |
| case-04 | Yes (no defects) | none |
| case-05 | Yes (missing `[RequireRole("Admin")]`) | Run 1's two medium findings merged into one; 3 findings became 2 |
| case-06 | Yes (no defects) | none |
| case-07 | Yes (`{@Session}` logs session data) | Invoice-logging finding **dropped from critical to medium**; run 1's "`_logger` may not be injected" finding gone |
| case-08 | Yes (`Dictionary` isn't thread-safe; the check and write aren't atomic) | **Both severities one level lower** (critical→high, high→medium); the second finding cited at line 24 instead of 19 |
| case-09 | Yes (the sign-out reset claim is wrong) | Confidence rose from low to medium |
| case-10 | Yes (catch-all returns 200) | Run 1's response-shape finding dropped; cited at line 35 (the `catch`) instead of 37 (the `return`) |

**What this means for scoring.** Because the verdict on each case hasn't changed, the per-case verdicts will probably match between runs once the key is applied. Severity varies by one level on the same defect (cases 07 and 08), so don't use severity to compare prompts on fewer than three runs. Line numbers differ by a line or two for the same defect, and the strict rule (`README.md:40-43`) is about naming the right defect, not the exact line, so both citations should count.

## Score (fill in from the answer key)

Let **D** be the number of defect cases in the key and **C** the number of clean cases (D + C = 10).

| Measure | Count | Rate | Formula |
|---|---|---|---|
| Caught | | | caught ÷ D |
| Missed | | | missed ÷ D |
| False alarm | | | false alarms ÷ C |
| Correct pass | | | correct passes ÷ C |

Use the same scoring conventions as run 1 (see [run-1.md](run-1.md#score-fill-in-from-the-answer-key)).

## Full reviewer output

<details><summary>case-01</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:51 | high | confidence medium
   What goes wrong: The loop calls `_approvals.Approve` directly instead of going through `Handle(...)`. Each approval is saved as it happens, so the batch is not atomic, and a service error in the middle comes back as an unhandled exception instead of the 404/409/400 that `Handle` would give.
   Failure scenario: Ids `["INV-1", "INV-2", "INV-404"]`, or a list with the same id twice or an invoice that is already Approved. INV-1 and INV-2 are approved and saved. Then `Approve` throws for the bad id, the caller gets a 500 with no list of what succeeded, and two invoices are approved that the client thinks failed. If they retry, the already-approved ids throw too. This assumes `Approve` throws on not-found or invalid-state errors, which is what `Handle` exists to map.
   Fix: Check every id before approving any of them (or approve in a single domain-level batch operation), wrap the call in `Handle(...)`, and return the result for each id.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49 | medium | confidence high
   What goes wrong: `Ids` is declared nullable (`List<string>?`), but the loop reads it without a null check.
   Failure scenario: A request body of `{}` or `{"ids": null}` sets `Ids` to null, so `foreach` throws a NullReferenceException and the client gets a 500 instead of a 400.
   Fix: Return `BadRequest` when `request.Ids` is null or empty, or make the property non-nullable and required.

3. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:41 | low | confidence medium
   What goes wrong: There is no limit on how many ids one request can contain, so one call can run an unbounded number of approvals.
   Failure scenario: An Approver posts a request with tens of thousands of ids. The request ties up the server for a long time and approves invoices in bulk with no limit, and combined with defect 1 it can leave a large set of invoices partly approved.
   Fix: Reject requests whose `Ids` count is above a small fixed maximum.
```
</details>

<details><summary>case-02</summary>

```
DEFECTS: 3

1. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:28 | critical | confidence high
   What goes wrong: The `customer` query parameter goes straight into the SQL text through string interpolation, so this is SQL injection.
   Failure scenario: A signed-in user calls `GET /api/invoices/search?customer=' OR 1=1 --`. The query becomes `... LIKE '%' OR 1=1 --%'` and returns every invoice. A payload like `'; DROP TABLE Invoices; --` or a `UNION SELECT` against other tables could delete data or read it, if `_queries.Run` allows more than one statement.
   Fix: Use a parameterized query (`LIKE @customer`, with the value `"%" + customer + "%"` bound as a parameter, escaping `%` and `_` if they should match literally), or filter through the repository instead of raw SQL.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:32 | critical | confidence high
   What goes wrong: The optional `status` query parameter is also interpolated into the SQL, so it is a second injection point.
   Failure scenario: `GET /api/invoices/search?customer=x&status=' OR '1'='1` gives `... AND Status = '' OR '1'='1'`, which skips both filters and returns all rows. Other payloads can run any SQL.
   Fix: Bind `status` as a parameter, or better, parse it to the invoice status enum (Draft, PendingApproval, Approved, Rejected), return 400 if it is not valid, and then bind it.

3. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:35 | high | confidence low
   What goes wrong: The new code calls `_queries.Run(sql)`, but the diff does not declare, inject or register any `_queries` field. I am assuming the controller only has `_repository`, as the context lines suggest.
   Failure scenario: If `_queries` is not declared somewhere outside the diff, the project fails to compile. If it is declared but has no implementation registered in `Program.cs`, the controller cannot be created and every invoices endpoint fails, not just search.
   Fix: Declare the query dependency, inject it through the constructor and register it in `Program.cs`, or do the search through the existing repository instead.
```
</details>

<details><summary>case-03</summary>

```
DEFECTS: 1

1. backend/src/InvoiceApp.Domain/DiscountCalculator.cs:16 | high | confidence medium
   What goes wrong: The change truncates the discount (`MidpointRounding.ToZero`) before subtracting it, where the old code rounded the final discounted amount half away from zero. Cutting fractions of a cent off the discount makes the discounted total higher, by up to 0.01 per call. Because the rounding is now toward zero, it is also not symmetric for negative amounts such as credit notes.
   Failure scenario: `Apply(19.99m, 15m)` gives a discount of 2.9985. The old code returned round(16.9915) = 16.99. The new code truncates the discount to 2.99 and returns 19.99 - 2.99 = 17.00, so the customer is overcharged by 0.01. This happens on any amount and percent pair where the exact discount has a fraction of a cent. Existing tests or stored totals that assume the old rounding will no longer match. (Assumption: the diff does not say whether this change in rounding was intended. If it was, it still breaks what existing callers expect.)
   Fix: Compute `amount - discount` at full precision and round once with `MidpointRounding.AwayFromZero`, as before. If the rounding rule really needs to change, make it an explicit rule and cover it with tests.
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
DEFECTS: 2

1. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:44 | critical | confidence high
   What goes wrong: The new `Delete` endpoint has no `[RequireRole("Admin")]` attribute, so any signed-in user can delete invoices. The project rules say destructive actions are Admin only, and the `Update` action right below it does carry this attribute.
   Failure scenario: A user signed in as `demo.approver` (role Approver) sends `DELETE /api/invoices/{id}`. The invoice is deleted and the server returns 204, even though only Admins should be able to do this.
   Fix: Add `[RequireRole("Admin")]` to the `Delete` action.

2. backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47 | medium | confidence medium
   What goes wrong: The action calls `_repository.Delete(id)` directly instead of going through `Handle(...)`, which skips the error mapping the other actions use. It also skips any lifecycle rule in the Domain layer. (Assumption: I can't see the repository or `ApprovalService`, so I am guessing at how they behave.)
   Failure scenario: Someone sends `DELETE` with an id that doesn't exist. If the repository throws a not-found error, the caller gets an unhandled 500 instead of 404. If the repository silently does nothing, the caller gets 204 and the log line says the invoice was deleted when it wasn't. Either way, an Approved or PendingApproval invoice can be deleted with no Domain check.
   Fix: Move the delete into a Domain service method that checks the invoice exists and is in a deletable state, and call it through `Handle(...)` so missing invoices return 404 and conflicts return 409.
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

1. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:36 | critical | confidence medium
   What goes wrong: The `{@Session}` placeholder with the `@` destructuring operator serialises the whole `CurrentUser` object into the log at Information level. I'm assuming `CurrentUser` is the signed-in user's session or principal object. If so, it most likely holds a session token, an auth cookie or ticket value, claims, or other credentials, and every one of them gets written to the logs.
   Failure scenario: An Approver approves any invoice, and the log sink (console, file or an aggregator) receives the serialised session object, including its token or claims. Anyone who can read the logs can then copy that value and act as the approver.
   Fix: Log only safe identifiers, such as `CurrentUser.Name` and the invoice id, and never destructure the session or user object.

2. backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:35 | medium | confidence medium
   What goes wrong: `{@Invoice}` destructures the whole invoice domain object into the log on every approval. Any customer or financial data on the invoice (supplier details, amounts, bank or contact fields) ends up in the logs. The project rules forbid exposing customer data.
   Failure scenario: Approving an invoice whose supplier record holds contact or payment details writes all of those fields in plain text to the log at Information level, where they are kept and can be seen beyond the app's own access controls.
   Fix: Log the invoice id and the new status only, not the whole object.
```
</details>

<details><summary>case-08</summary>

```
DEFECTS: 2

1. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:9 | high | confidence medium
   What goes wrong: The thread-safe `ConcurrentDictionary` is replaced with a plain `Dictionary`, which is not safe for concurrent writes, or for reads that run alongside a write. I am assuming the repository is registered as a singleton in `Program.cs`, as in-memory repositories usually must be to keep their data, so every request shares this one instance.
   Failure scenario: Two users create or approve invoices at the same moment. `Add` or `Update` runs on two request threads at once, or a `GetById` or list read runs during a write. The dictionary's internal state can be corrupted. Possible results are `InvalidOperationException` ("Operations that change non-concurrent collections must have exclusive access"), lost entries, or a read that spins forever and pins a CPU thread.
   Fix: Go back to `ConcurrentDictionary<string, Invoice>`, or wrap every access to the dictionary in a lock.

2. backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs:24 | medium | confidence medium
   What goes wrong: `Add` now checks for an existing key (line 19) and writes (line 24) as two separate steps instead of one atomic `TryAdd`. Two concurrent adds with the same Id can both pass the check, so the duplicate guard no longer holds.
   Failure scenario: Two requests add an invoice with the same Id at the same time (for example a double-submitted create). Both see `ContainsKey` return false. Both write, and the second silently overwrites the first instead of throwing "already exists". The first invoice is lost without any error.
   Fix: Use `ConcurrentDictionary.TryAdd`, or do the check and the write under one lock.
```
</details>

<details><summary>case-09</summary>

```
DEFECTS: 1

1. README.md:25 | low | confidence medium
   What goes wrong: The new README line says that signing out and signing back in resets the sample data. In an app that keeps its data in memory, the repository is normally a singleton registered once at startup, and signing out only clears the auth session. The repository is never reseeded, so the documented reset does not happen.
   Failure scenario: A user creates or approves invoices, signs out, then signs in as demo.approver expecting fresh sample data. Their earlier changes are still there, which contradicts the README. This assumes sign-out does not reseed the in-memory repository; that code is not in the diff.
   Fix: Remove the sentence, or change it to say that only restarting the process resets the data (or add a real reset endpoint and document that instead).
```
</details>

<details><summary>case-10</summary>

```
DEFECTS: 1

1. backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:35 | critical | confidence high
   What goes wrong: The new catch-all `catch (Exception)` turns every unexpected failure into HTTP 200 `{ status = "completed" }`. It also throws the exception away without logging or rethrowing it, so callers and operators are told the operation worked when it did not.
   Failure scenario: An approve, reject or delete call hits an unexpected exception, such as a NullReferenceException, a repository fault, or a throw after part of the state was already changed. The client gets 200 "completed" and the UI shows the invoice as approved or deleted, but nothing was saved, or only half of it was. Nothing is logged and no 500 is sent, so the failure goes unnoticed and nobody retries. Any caller expecting `Handle` to return the action's result also gets a different response body.
   Fix: Remove the catch-all so unexpected exceptions reach the framework's 500 handling, or log the exception and return a 500 problem response rather than `Ok`.
```
</details>
