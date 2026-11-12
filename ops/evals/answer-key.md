# Answer key used for scoring (my own reading)

The repository deliberately ships no answers (`ops/README.md`, "No answers here"). This key is my own review of each case, written **before** scoring, so the score can't drift towards whatever the agent said. The runner keeps it out of the reviewer's view: each case runs in an empty temp directory.

Scoring rule (from `ops/evals/README.md`): a case is **caught** only if the review names the actual defect below. A vague "could be improved" near the line doesn't count. On a clean case, a style note is not a false alarm; a **false alarm** is the review asserting a defect that isn't there.

| Case | Verdict | The defect (what a "caught" finding must name) | Also acceptable |
|---|---|---|---|
| case-01 | **Defect** | Bulk approve isn't atomic and has no error mapping. If one id is missing or not pending, `Approve` throws mid-loop: earlier invoices are already approved, and the caller gets a 500, not 404/409. | `request.Ids` is nullable and unchecked, so a missing field gives a NullReferenceException (500). `[RequireRole("Approver")]` locks out Admin, contrary to the convention "approvals are Approver or Admin". |
| case-02 | **Defect** | SQL injection: `customer` and `status` are interpolated straight into the SQL string. | – |
| case-03 | **Defect** | Rounding changed from `AwayFromZero` to double rounding with `ToZero`, so totals change. Example: 0.99 at 15% gives 0.85 instead of 0.84 (the customer is over-charged a cent), and midpoint amounts truncate instead of rounding. | Any finding that names the rounding-mode change as altering the computed amount. |
| case-04 | **Clean** | Pure rename (`_repository` → `_invoices`), no behaviour change. | – |
| case-05 | **Defect** | `Delete` has no `[RequireRole("Admin")]`, so any signed-in user can delete invoices (destructive actions are Admin only). | No `Handle(...)`, so a missing id isn't mapped to 404. Counts only alongside the authorization finding. |
| case-06 | **Clean** | New tests only; the assertions match `ApprovalService` behaviour. | Note: the `Pending(...)` helper isn't in today's test file, but the diff alone doesn't show that. Don't count a "doesn't compile" claim either way. |
| case-07 | **Defect** | Sensitive data in logs: `{@Invoice}` and `{@Session}` destructure the whole invoice (customer data, amount) and the user session into the log. | – |
| case-08 | **Defect** | `ConcurrentDictionary` replaced by `Dictionary` in a singleton repository that serves concurrent requests. That isn't thread-safe, and `ContainsKey` followed by a write is a check-then-act race. | – |
| case-09 | **Clean** (decide before scoring) | README text plus raising the `Microsoft.AspNetCore` log level to Warning. No code change. | Caveat: the new README line "sign out and sign in again resets the sample data" is false (`AuthController.Logout` only removes the session), but you can't see that from the diff. I score a finding that flags that claim as *caught-doc*, not a false alarm, and report it separately. |
| case-10 | **Defect** | The catch-all returns **200 `{"status":"completed"}`** on any unexpected exception, so failures look like success to the client and never show as 5xx in monitoring. | – |
| case-11 *(added)* | **Defect** | The month-end report compares only `.Month`, not the year, so January 2027's total includes January 2026's approvals. | Also comparing a UTC `DecidedAt` against a local-time period, but only alongside the year bug. |
| case-12 *(added, clean)* | **Clean** | A new Domain rule (amount must be > 0 to submit) with a test. It throws `ArgumentException`, which `Handle` maps to 400, and it follows AGENTS.md conventions. | A speculative "what about credit notes?" isn't a defect; nothing in the codebase supports credit notes. Count it as a false alarm only if it's asserted as a bug. |

**Totals:** 8 defect cases (01, 02, 03, 05, 07, 08, 10, 11) and 4 clean cases (04, 06, 09, 12).

**Where the added cases come from:**
- **case-11 (defect):** a pattern I've seen in real reporting code. A month filter that ignores the year passes every test written in the current year and breaks silently at the first January.
- **case-12 (clean):** a correct, convention-following change. It tests whether the reviewer invents a problem when there is none, which is the false-alarm rate the README warns people forget to measure.
