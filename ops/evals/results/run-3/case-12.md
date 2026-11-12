I only had the diff to work from. The working directory has no `.cs` files, so I couldn't check the rest of `ApprovalService`, the `Invoice` type, the test helpers or the callers. The new check works: zero and negative amounts are rejected before the status changes and before `_repository.Update` runs. There are two likely defects and two smaller issues.

### 1. Wrong exception type for a state check — `ApprovalService.cs:28` — medium-high confidence
The new guard throws `ArgumentException`. But the caller only passes `invoiceId`, and that argument is valid. What's wrong is the stored invoice's amount, which is the same kind of problem as the status check just above it, and that check throws `InvalidOperationException`.
- **What goes wrong:** if the API layer or middleware turns `InvalidOperationException` into a 409/422 business-rule error, this new error won't match that mapping. It will probably come back as a 400 that blames the request, or as an unhandled 500. Any caller that catches `InvalidOperationException` from `Submit` will also miss it.
- **Fix:** throw `InvalidOperationException`, or your domain's validation exception if one exists, and update the test to match.

### 2. Existing Submit tests may now fail — `ApprovalServiceTests.cs` (helper `InvoiceWith`) — medium confidence, needs checking
If `InvoiceWith(id, status)` doesn't set `Amount`, it defaults to `0m`. Every existing test that submits a draft and expects success would then throw `ArgumentException`. That includes the happy-path Submit test and any Approve/Reject tests that call `Submit` first. Setting `invoice.Amount = 0m` explicitly in the new test hints that the helper sets a non-zero amount, but the diff doesn't show it. Check the helper, or just run the test suite.

### 3. Smaller issues
- **No test for negative amounts** — high confidence it's missing, low severity. The rule is `<= 0`, but only `0` is tested, so a later change to `== 0` would still pass. Make it a `[Theory]` with `0` and a negative value.
- **The test doesn't check for side effects** — low severity. It doesn't assert that the status stays `Draft` or that `_repository.Update` is never called. The code is correct now, but a refactor that changes the status before validating would go unnoticed.

### Business rule to confirm (not a code defect)
If the system has credit notes or other invoices that are allowed to be negative or zero, this change blocks them from approval. If the rule is meant to apply to every invoice type, ignore this. Also, if `Amount` is `decimal?`, a null amount passes the check, because `null <= 0` is false.

Nothing else in the diff looks wrong. The two checks run in a sensible order, and the error message is clear.
