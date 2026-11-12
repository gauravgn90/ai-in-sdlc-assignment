I found one defect in this diff, and it's serious.

### Catch-all reports every unexpected failure as success
**File:** `backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs`, the added lines (`catch (Exception)` → `return Ok(new { status = "completed" });`)
**Confidence:** Very high. This follows directly from the code.

**What goes wrong:**
- Any exception the three typed handlers don't catch now returns **HTTP 200** with `{ status: "completed" }`. That includes `NullReferenceException`, database or EF exceptions, timeouts, `OperationCanceledException`, and `IOException`. Before this change, those surfaced as a 500 through the framework's exception handling.
- **Failed writes look like successes.** Say creating, updating or paying an invoice throws halfway, for example on a DB constraint or a deadlock. The client gets 200 and assumes it worked. It won't retry and won't alert anyone, and the user believes an invoice was saved or paid when it wasn't. In an invoicing app that means lost or wrong financial records.
- **The response shape breaks clients.** On the success path the body is whatever `action()` returns, such as an invoice DTO. The fallback returns `{ status }` instead. Typed clients will fail to deserialize it, or will quietly fill a default object with empty fields (id 0, null amounts) and carry on with bad data.
- **Errors become invisible.** The exception isn't bound to a variable and isn't logged. It also never reaches the exception middleware, so logging, APM, Sentry and ProblemDetails all miss it. Monitoring that watches 5xx rates will show nothing while requests fail.
- **Cancellation is swallowed.** A client disconnect or request abort (`OperationCanceledException`) also comes back as "completed".

**Fix:** Remove the catch-all and let unhandled exceptions reach the global exception handler (`UseExceptionHandler` or ProblemDetails), which returns 500. If you do want a local fallback, log the exception and return a 500 status:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Unhandled error");
    return StatusCode(StatusCodes.Status500InternalServerError, new { error = "An unexpected error occurred." });
}
```

Don't put the raw `ex.Message` in the response body for 500s.

I found nothing else wrong in the lines this diff adds.
