I found three issues in `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`. I only had the diff to work from, not the rest of the codebase, so I couldn't check `ApiControllerBase`, `Handle`, `CurrentUser` or the repository.

### 1. Delete has no role check (high confidence)
**Line 44–45** (`[HttpDelete("{id}")]` / `public IActionResult Delete`)

`Update` right below it has `[RequireRole("Admin")]`, but `Delete` doesn't. Since `Update` needs its own attribute, the class probably doesn't apply an Admin check to every action. That means any user who can reach the controller can delete any invoice, while the same user can't edit one. Deleting is the more damaging of the two, so this is almost certainly a mistake.
**Fix:** add `[RequireRole("Admin")]`, or whatever role is meant to be allowed to delete.

### 2. Delete skips the `Handle(...)` wrapper, so errors and missing invoices aren't handled (medium confidence)
**Line 47** (`_repository.Delete(id);`)

The other actions go through `Handle(() => ...)`, which presumably turns repository results or exceptions into proper HTTP responses (404, 400, and so on). `Delete` calls the repository directly, so:
- If `Delete` throws for an unknown id, the client gets an unhandled 500 instead of a 404.
- If `Delete` fails quietly for an unknown id (returns false or does nothing), the endpoint still returns **204 No Content**. The client is told the delete worked when no invoice existed.

**Fix:** use `Handle(...)` like the other actions, or check the repository's result and return `NotFound()` when nothing was deleted.

### 3. The audit log runs even when nothing was deleted, and can fail after the delete (medium–low confidence)
**Line 48** (`_logger.LogInformation(... CurrentUser.Name)`)

- The log line runs no matter what the repository did. If the repository fails quietly for an unknown id (see #2), you get "Invoice X deleted by Y" entries for deletions that never happened, which makes the audit trail wrong.
- If `CurrentUser` can be null (for example, no authenticated principal), this line throws a `NullReferenceException` after the delete has already gone through. The client then gets a 500 for a delete that succeeded, and nothing is logged.

**Fix:** log only after confirming something was deleted, and access the user null-safely (`CurrentUser?.Name`).

To confirm #2 and #3, the code to check is what `_repository.Delete` does with an unknown id and whether `CurrentUser` can be null. Neither is visible in this diff.
