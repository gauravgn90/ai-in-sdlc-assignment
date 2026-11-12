I found three defects, ranked by severity. I only had the diff to work from, so I couldn't check the class-level attributes, `ApiControllerBase`, `Handle`, or the repository.

### 1. Delete has no role check, so any authenticated user (or possibly anyone) can delete invoices
**File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`, line 44 (the `[HttpDelete("{id}")]` action)
**Confidence:** High

The `Update` action just below has `[RequireRole("Admin")]`, but `Delete` has no authorization attribute. Deleting is more destructive than updating, yet it is now less protected.
- If the controller has a class-level `[Authorize]`, any logged-in user, not just Admins, can delete any invoice.
- If it doesn't, the endpoint may be open to anonymous callers.

**Fix:** add `[RequireRole("Admin")]`, or whatever role should own deletion.

### 2. Delete skips the controller's `Handle(...)` wrapper, so errors aren't mapped to proper responses
**File:** same file, line 47 (`_repository.Delete(id);`)
**Confidence:** Medium

The action above it returns `Handle(() => _repository.Add(invoice))`, which is presumably where repository exceptions become HTTP results such as 404 or 400. `Delete` calls the repository directly and always returns `NoContent()`. So:
- If the repository throws for an unknown id, the client gets an unhandled 500 instead of a 404.
- If the repository silently ignores unknown ids, the client gets 204 for an invoice that never existed, and the log says it was "deleted".

**Fix:** `return Handle(() => _repository.Delete(id));`, or check whether the invoice exists and return `NotFound()`. Logging should only happen on success.

### 3. `CurrentUser.Name` can throw after the delete has already happened
**File:** same file, line 48 (the `_logger.LogInformation(...)` line)
**Confidence:** Low to medium (depends on how `CurrentUser` is implemented)

If the caller is unauthenticated, which is reachable because of finding 1, `CurrentUser` may be null. The log line would then throw a `NullReferenceException` after the invoice is already gone. The client gets a 500 for a delete that actually succeeded, which can lead to confusing retries, and the audit log entry is lost. This goes away if finding 1 is fixed and `CurrentUser` is guaranteed non-null for authorized requests. Otherwise use `CurrentUser?.Name`.

Not a defect, but worth checking: if invoices are financial records you need to keep, a hard delete may go against an audit or soft-delete policy elsewhere in the codebase.
