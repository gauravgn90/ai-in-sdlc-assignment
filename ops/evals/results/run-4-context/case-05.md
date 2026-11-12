I found four problems in this diff. The working directory only contains `CLAUDE.md`, with no backend source, so I couldn't open `InvoicesController`, `ApiControllerBase` or the repository. These findings are based on the diff and the project conventions in `CLAUDE.md`.

### 1. Delete has no Admin restriction (high confidence)
**File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`, line 44 (`[HttpDelete("{id}")]`)

**What goes wrong:** The new action has no `[RequireRole("Admin")]`. The project rule says "destructive actions are Admin only." Because it inherits only the default sign-in requirement, any signed-in user can delete any invoice, including an Approver (e.g. `demo.approver`) or any future lower-privilege role. The `Update` action directly below has `[RequireRole("Admin")]`, so this looks like it was left out by mistake.

**Fix:** Add `[RequireRole("Admin")]` above `[HttpDelete("{id}")]`.

### 2. Errors skip `Handle(...)`, so a missing invoice doesn't return 404 (medium-high confidence)
**File:** same, line 47 (`_repository.Delete(id);`)

**What goes wrong:** The convention is that controllers go through `Handle(...)` so service errors become 404, 409 or 400. The `Create` action just above uses `Handle(...)`, but this action calls the repository directly. What happens with an unknown id depends on how `Delete` behaves, which I couldn't check:
- **If it throws a not-found error:** the error escapes and the client gets a 500 instead of a 404.
- **If it does nothing:** the endpoint returns 204 anyway, and the log line at line 48 records a deletion that never happened, which makes the audit trail wrong.

**Fix:** Wrap the delete in `Handle(...)` and log only after it succeeds.

### 3. The delete bypasses the invoice lifecycle (medium confidence)
**File:** same, line 47

**What goes wrong:** `ApprovalService` in Domain owns the invoice lifecycle (Draft, PendingApproval, Approved, Rejected). Here the controller deletes straight from the repository with no state check, so an invoice that is already Approved, or waiting for approval, can be deleted silently. The project says business rules must live in Domain, not controllers. Whether a delete should be allowed in a given state is one of those rules, and it would normally return a 409 through `Handle`. I'm less sure about this one because I couldn't see whether a deletion rule was intended. Even if every state should be deletable, the call should still go through a Domain service.

### 4. No tests for the new endpoint (high confidence for this diff)
**What goes wrong:** The project requires tests for every new endpoint, using `FakeInvoiceRepository`. The diff adds none. At minimum it needs tests for: Admin can delete, Approver is refused, unknown id returns 404, and the lifecycle rule if one is added.

### Not checked
I couldn't confirm that `_logger`, `CurrentUser` and `IInvoiceRepository.Delete` exist, because the source isn't here. If any of them were added outside this diff, or don't exist, the build will fail.
