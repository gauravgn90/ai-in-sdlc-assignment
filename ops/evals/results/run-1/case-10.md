I found one real defect. It's serious, and a few smaller problems come from it.

### 1. A catch-all turns every unexpected failure into "200 OK / completed" (high confidence)

**File:** `backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs`, the new `catch (Exception)` block at about lines 35–38, with the `return Ok(new { status = "completed" });` line.

**What goes wrong:** Any exception that isn't one of the three handled types now produces an HTTP 200 that says the work completed. That covers a database timeout, a `NullReferenceException`, a failed external call, `DbUpdateException` and similar errors. The client is told the operation succeeded when it didn't.

**Concrete scenario:** A "create invoice" or "record payment" action throws `DbUpdateException` partway through. The caller gets `200 {"status":"completed"}` and doesn't retry. The invoice or payment was never saved, or was only partly saved, and nobody is told. For an invoicing app, that means lost or inconsistent financial records.

**Fix:** Remove the block. Let unexpected exceptions reach the framework's exception handling or middleware so they return a 500 (ideally a `ProblemDetails` response) and get logged. If a catch-all is really needed here, log the exception and `return StatusCode(500, new { error = "An unexpected error occurred." })`.

### 2. Problems caused by the same block (high confidence)

- **The exception is lost without a trace.** `catch (Exception)` doesn't bind the exception, log it or rethrow it. Global exception middleware and APM/telemetry won't see these failures, so you'll have production bugs with no log entries.
- **The response doesn't match the success response.** On real success, `Ok(action())` returns the action's result. The fallback returns `{ status: "completed" }` instead. A client that reads fields from a 200 response will either fail to deserialize it or quietly get empty/default values. That pushes the failure further from where it actually happened.
- **Cancellation is reported as success.** `OperationCanceledException`/`TaskCanceledException`, for example when the client disconnects or a request times out, are also caught and returned as a completed 200.

Nothing else in the diff is defective. The three catch blocks that were already there are unchanged.

Side note: the hunk header (`-20,9 +20,13`) doesn't match the number of lines shown, so the line numbers above are estimated from the hunk's starting line.
