I found one real defect. The diff should not be merged as written.

I only had the diff to go on. The workspace contains just `CLAUDE.md`, so I couldn't check `Handle(...)`'s full signature, its callers, or which exceptions the Domain layer throws. The line numbers below are counted from the hunk.

### 1. Unexpected exceptions are reported as success
**File:** `backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs`, lines 35–38 (`catch (Exception) { return Ok(new { status = "completed" }); }`)
**Confidence:** High

**What goes wrong:** Every exception other than the three mapped ones now returns **200 OK** with `{ status: "completed" }`. Examples include a `NullReferenceException`, a repository failure, or a bug in `ApprovalService`. Before this change, these reached ASP.NET Core's default handling and became a 500.

**Concrete failure:** An approver clicks Approve. Something inside `ApprovalService` throws an `InvalidCastException` or a `NullReferenceException`. The API answers 200 "completed", so the UI and any client think the invoice was approved. In fact it is still `PendingApproval`, or partly changed if the error came halfway through an update. The same happens with Admin-only delete: the user is told the invoice is gone when it isn't. In an approval workflow, a false success is worse than a visible error.

**Related effects of the same line:**
- **Wrong response shape:** On success, callers get whatever `action()` returns, such as an invoice object. On this path they get `{ status }`. Anything reading the response, like `wwwroot` JS or Playwright tests that check status or fields, will see missing data on a request marked as successful.
- **Errors disappear from view:** The exception is discarded without logging (`catch (Exception)` with no variable), and it never reaches the developer exception page or any exception middleware. Real bugs leave no trace.
- **Too broad:** It also catches `OperationCanceledException` (client disconnected or request aborted) and turns it into a 200.

**Fix:** Delete the catch-all and let unexpected exceptions become 500s. If a uniform error body is wanted, add exception-handling middleware, e.g. `app.UseExceptionHandler` returning `ProblemDetails` with status 500, and log the exception. Don't do it in `Handle`.

### 2. No tests for the new behaviour (convention, not a runtime bug)
**Confidence:** Medium. I couldn't see the test project to confirm none were added.

`CLAUDE.md` requires tests for every new rule. The diff adds no test of what `Handle` does with an unmapped exception. Such a test would have shown that it returns 200 instead of 500.

### Minor: malformed hunk header
The hunk header says `@@ -20,9 +20,13 @@`, but the hunk shows 15 context lines plus 4 added lines. It looks hand-edited or truncated, so `git apply` may reject it. It doesn't affect behaviour, but check that the patch you actually commit is the one reviewed here.
