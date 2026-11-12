I found no definite bugs, but one likely problem. The working directory is empty, so I reviewed only the diff text. I couldn't check callers, `ServiceFor`, or the `Amount` type.

**1. Wrong exception type for the new check**
- **File:** `backend/src/InvoiceApp.Domain/ApprovalService.cs`, line ~28 (`throw new ArgumentException(...)`)
- **What goes wrong:** The only argument to `Submit` is `invoiceId`, and it is valid. What fails is the invoice's own state (its amount). The check just above it uses `InvalidOperationException` for that kind of failure. If a controller, middleware or caller catches `InvalidOperationException` to return a 400/409 for rejected submissions, a zero or negative invoice will instead get an unhandled `ArgumentException`, probably a 500. Code that maps `ArgumentException` to "bad request input" would also report the wrong cause.
- **Fix:** Throw `InvalidOperationException` (or a domain exception) and change the test's `Assert.Throws<...>` to match.
- **Confidence:** Medium. The type is clearly inconsistent with the code around it. Whether it breaks anything depends on how callers handle exceptions, which I couldn't see.

**2. (Minor) Test doesn't cover negative amounts or the success path**
- **File:** `backend/tests/InvoiceApp.Tests/ApprovalServiceTests.cs`, around line 33
- **What goes wrong:** The test only uses `0m`, so changing `<= 0` to `== 0` would still pass. Nothing checks that a rejected invoice keeps its `Draft` status and that `_repository.Update` isn't called. The code is correct today because the throw comes before the status change, but no test guards that order.
- **Confidence:** High that the gap exists; low impact.

Assumptions I couldn't verify: that the `ServiceFor(...)` helper exists (the test just above uses a local `service` variable instead), and that `Amount` is a settable `decimal`. If either is wrong, the test won't compile.

Nothing else stands out. The check runs after the status check and before the state change, so a rejected invoice is left unchanged.
