I found four likely defects in `InvoicesController.cs`. I only had the diff, not the rest of the controller or the repository, so some of these depend on code I couldn't see. I note that where it matters.

### 1. The delete endpoint has no admin check (high confidence)
**Line 44** (`[HttpDelete("{id}")]`)

`Update` right below it has `[RequireRole("Admin")]`, but `Delete` doesn't. So any user who can reach the controller can permanently delete any invoice. Deleting is at least as risky as updating, so this looks like a missed attribute, not a deliberate choice. If the class has no `[Authorize]` on it either, even users who aren't logged in can delete.

**Fix:** add `[RequireRole("Admin")]`, or whatever role the business rule requires.

### 2. It skips the controller's usual `Handle(...)` wrapper (medium-high confidence)
**Line 47** (`_repository.Delete(id);`)

`Create` uses `return Handle(() => _repository.Add(invoice));`, which presumably turns repository errors (not found, validation, conflicts) into proper HTTP responses. `Delete` calls the repository directly. If `Delete` throws for a missing id, the caller gets a 500 instead of a 404.

### 3. A missing invoice still gets a 204 and a "deleted" log entry (medium confidence)
**Lines 47–49**

If `_repository.Delete` doesn't throw for an unknown id (for example, it returns a `bool` that is ignored here), then:
- A nonexistent id returns `204 NoContent` instead of `404`.
- The log line "Invoice {InvoiceId} deleted by {User}" is written even though nothing was deleted, which makes the audit trail wrong.

**Fix:** check the result and return `NotFound()` when nothing was deleted, and only log after a confirmed delete.

### 4. The log line can crash after the delete has already happened (low-medium confidence)
**Line 48** (`CurrentUser.Name`)

If `CurrentUser` can be null (no authentication on this endpoint, which ties to finding 1, or a service/anonymous call), this line throws a `NullReferenceException` *after* the delete. The client gets a 500 for a delete that succeeded, and nothing records who did it.

### Couldn't verify
- Whether `_logger` and `CurrentUser` exist on `InvoicesController` or `ApiControllerBase`. If they don't, this won't compile.
- Whether the repository's delete is soft or hard, and whether invoices in some states (paid, issued) should be blocked from deletion. That's a business rule I can't check from the diff.
