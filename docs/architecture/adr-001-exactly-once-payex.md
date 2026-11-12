# ADR-001: Exactly-once submission of approved invoices to PayEx

- **Status:** Proposed. Becomes Accepted once PayEx confirms idempotency-key support (see "Open questions")
- **Date:** 2026-11-10
- **Owner:** Gaurav Kumar, senior engineer, Invoice Approval service
- **Related:** `docs/architecture/c4-container-target.md`, `docs/architecture/approval-sequence.md`, `ops/incidents/INC-2041`, `ops/incidents/INC-2047`

## Context

In January the Invoice Approval service becomes tier-2: 24x7 on-call, a published SLO, and a new integration that submits every approved invoice to PayEx, an external payment provider.

These facts constrain the design:

| Fact | Why it matters |
|---|---|
| A PayEx timeout (30 s) does not reliably mean the submission failed | After a timeout we can't tell whether the payment happened. Retrying blindly can pay twice, and not retrying can leave the invoice unpaid. This is the core problem. |
| About 40,000 invoices a month, 60% in the last three working days, peaking near 80 approvals a minute | Failures cluster at month-end, when finance has the least time to fix them by hand. |
| Three app instances behind a load balancer (`INC-2041/README.md:32`) | Double-clicks and user retries can land on different instances, so an in-process lock is not enough. |
| Users already retry after errors | The logs show a 500 followed by a successful retry on another instance (INV-41360, INV-41454), and one invoice approved four times (INV-41340) (`INC-2041/app-logs.txt`). |
| The planned code approves first, then calls PayEx synchronously in the controller (`deploy-diff.patch:84-85`) | If PayEx fails, the invoice is Approved but unpaid and the user sees a 500. INC-2041 ("approvals slow and failing") is this failure. |
| A retry policy was added in 2.14.3 (`INC-2047/recent-changes.md:7`) | Retrying a non-idempotent POST turns "unknown outcome" into "possible double payment". |
| SOC 2 Type II audit in six months; approval actions auditable for 7 years | Every submission attempt and its outcome must be recorded and kept, not just the final state. |
| Azure SQL is planned; Azure Service Bus is provisioned but unused | The database is part of going live anyway. Service Bus is available, but using it is not free in complexity. |

No mechanism gives true exactly-once delivery to an external HTTP API. What we can achieve is **effectively-once**: at-least-once sending, plus deduplication on the receiving side, plus detection of anything that slips through.

## Options considered

**A. Idempotency key + dedupe table, in the request.** Insert a `PaymentSubmission(InvoiceId UNIQUE, IdempotencyKey, State)` row, call PayEx with the key, then mark the row Submitted.
- Pro: cheap. The unique constraint blocks duplicates from double-clicks, retries and other instances.
- Con: approval is still coupled to PayEx latency, so INC-2041 can happen again. If the process dies between saving the approval and calling PayEx, the invoice stays approved but unpaid.

**B. Transactional outbox + background worker.** In one SQL transaction, set the invoice to Approved and insert an outbox row. A background worker claims rows and sends them to PayEx with a fixed idempotency key, retrying with backoff.
- Pro: the approval and the intent to pay commit together, so an approved invoice can't be left without a payment record. Approvals no longer depend on PayEx being fast. Retries are safe if PayEx deduplicates.
- Con: more to build: a unit of work, row claiming across 3 instances, a poison-row path. It can also fail *silently*: approvals return 200 while rows pile up unsent.

**C. Optimistic submit + nightly reconciliation.** Call PayEx in the request. Each night, compare Approved invoices against PayEx's records.
- Pro: least new code.
- Con: detects duplicates and misses up to 24 h later instead of preventing them. A duplicate is money already sent and must be recovered by hand. It also needs a PayEx list or report API that we haven't confirmed exists.

**Also considered: Azure Service Bus as the transport (outbox → Service Bus queue → worker).** Rejected for v1. We can't write to SQL and Service Bus in one atomic transaction, so an outbox would still be needed in front of it. Service Bus duplicate detection dedupes messages, not PayEx calls, so the PayEx idempotency key is still required. It adds a hop, a second backlog to monitor, and a new dependency for an on-call team with two engineers new to the codebase. Revisit if more consumers need the "approved" event (INC-2047 already shows a planned `invoice-events` topic).

## Decision

**Option B, with A built into it, and C as an alert-only safety net.**

1. **Outbox.** `ApprovalService.Approve` updates the invoice and inserts a `PaymentSubmission` row in one transaction. The row is unique per `InvoiceId`, so it is also the dedupe record. The status update is conditional (`UPDATE … WHERE Status = 'PendingApproval'`), which closes the race the sequence diagram identified, where two concurrent approvals could both pass `EnsurePending`.
2. **Stable idempotency key.** `invoice:{InvoiceId}:payment:v1` is generated once and sent on every attempt, so a resend after a timeout or crash is a no-op at PayEx.
3. **Worker.** A `BackgroundService` in the existing API instances claims rows with a lease. The lease timeout is longer than the PayEx timeout plus a margin, so two instances never send the same row concurrently.
4. **Client timeout above PayEx's own.** The HTTP client timeout is **35 s**, above PayEx's 30 s, so we receive PayEx's answer instead of cutting it off and creating more unknown outcomes. This is possible only because the call is off the user's request path.
5. **Classified failures.**
   - Timeouts and 5xx: retry with backoff, same key.
   - 401/403: not retried; page on-call immediately (for example after a key rotation).
   - Other 4xx: retried up to N times, then set aside so one bad invoice never blocks the rest.
6. **Concurrency sized for peak.** At 80 approvals/min and a worst-case 30 s per call, up to 80/60 × 30 = **40 calls in flight** (Little's law). The worker runs with bounded parallelism (for example 15 per instance × 3 instances), not one row at a time.
7. **Audit.** Every attempt is written to an append-only `PaymentAttempt` table: time, instance, key, HTTP status, PayEx reference, error. It is kept for 7 years alongside the approval record, for SOC 2.
8. **Monitoring ships with the feature, not after.** Two alerts page the 24x7 on-call:
   - the oldest unsent row is older than 15 minutes
   - any row has been set aside after repeated failures
9. **Reconciliation only alerts.** A daily job matches our Submitted rows against PayEx by reference and raises mismatches. It never sends payments, and it ignores rows younger than the current backlog age.
10. **User-facing state.** The API and UI show "Approved, payment pending" until PayEx confirms. Finance has agreed to this (see open question 2).

## Defending the decision against its strongest objection

**Objection: "B fails silently. Today a PayEx outage shows up as 5xx and pages someone. With an outbox, approvals return 200 while nothing gets paid, and finance finds out at 9 a.m. on the 1st."**

This is true, and it is the main risk of B. INC-2047 is already a silent failure of this kind: the publisher logged success while notifications stopped. My response:
- Alert on the **age of the oldest unsent row**, not on error rate. That signal fires within 15 minutes whatever the cause: PayEx down, key expired, or a worker that never started.
- Treat these alerts as release blockers. B does not ship without them.
- A runbook forbids "resend everything pending". On-call looks each payment up by reference first and resends only confirmed misses, with a named approver, as INC-2047 already requires.

The second objection is **"it all depends on PayEx honouring the key."** Also true. If PayEx neither deduplicates nor supports lookup by reference, no option gives exactly-once. In that case: after a timeout, mark the payment `Unknown`, don't retry automatically, and let reconciliation and a person resolve it. That makes B behave like A + C, but approvals still stay decoupled from PayEx.

## Consequences

- Approval latency no longer depends on PayEx, which removes the INC-2041 failure mode.
- `IInvoiceRepository` needs a unit-of-work or transaction concept, which it doesn't have today.
- On-call gets two new alerts and a runbook. That is a real ongoing cost for a 6-person rotation.
- Finance reports must treat "payment pending" as a normal state, not as a loss.

## Cost

- **Build:** B costs more than A + C. The extra work is the unit-of-work change, the worker with leasing and backoff, and failure tests (kill mid-send, two instances claiming one row, a row PayEx always rejects). The agent estimated 21–33 engineer-days for B against 13–20 for A + C. I treat those figures as unvalidated and trust only the ratio (roughly 1.5×).
- **Run:** no new Azure resources. The worker runs in the existing App Service instances, and the outbox and attempt tables hold tens of thousands of small rows a month. One caveat: if Azure SQL is on the serverless tier, the worker's polling stops it from auto-pausing, so use the provisioned tier, which production needs anyway.
- **People:** B shifts cost from finance's manual fixes to on-call alerts. On a day like INC-2041 (about 106 PayEx errors in 90 minutes), A + C would leave dozens of Unknown payments to resolve by hand.

## Open questions (must be answered before Accepted)

1. Does PayEx accept an idempotency key or deduplicate on our invoice reference? Does it support lookup by reference, and a list or report API? Verify in the PayEx sandbox.
2. Do finance and product accept "Approved, payment pending" as a visible state? Which accounting period does a payment belong to if it's approved at 23:58 on the last day and sent at 00:20?
3. What is the published SLO for approval latency and for time-to-payment?

## What would make me revisit this decision

- PayEx confirms it does **not** deduplicate and has no lookup by reference: fall back to A + C with `Unknown` state handling.
- The oldest-unsent-row alert fires more than twice in a month-end window, or rows are set aside more than about 0.1% of the time.
- Reconciliation finds **any** duplicate payment in production.
- A second consumer needs the "invoice approved" event: move the transport to the provisioned Service Bus.
- Peak load rises well above 80 approvals/min, or PayEx p95 latency rises above about 10 s, so that the worker's parallelism needs resizing.

## Where the agent was wrong or useless

1. **It used the wrong load figure.** It assumed peak load of "about 320 approvals in 90 minutes, roughly 3–4 a minute", taken from one incident's log window. The scenario states a peak near **80 approvals a minute**, about 20× higher. Its cost and sizing reasoning rested on that number, and it never sized worker concurrency at all. I did that myself (40 calls in flight at peak).
2. **Its timeout advice would have made the core problem worse.** It recommended a **10 s** client timeout as a fix needed "either way". PayEx can take up to 30 s, and a timeout means an unknown outcome. Cutting the call at 10 s would turn calls that would have succeeded into unknown outcomes. With the call moved to a worker, the right setting is above PayEx's own timeout (35 s).
3. **It ignored provisioned infrastructure.** Azure Service Bus is provisioned and unused, yet the agent never considered it as the transport for the worker. I evaluated it and rejected it for v1, with a trigger to revisit.
4. **It ignored compliance.** Neither the comparison nor the recommendation mentioned the SOC 2 audit or 7-year auditability, although the design choice affects what gets recorded. The `PaymentAttempt` audit table is my addition.
5. **It presented guesses as figures.** "Approve stays at about 100 ms" had no citation or measurement. The engineer-day estimates were precise-looking ranges with no basis. The assignment asks for measured numbers, so I kept only the relative comparison.
6. **The pushback test was partly informative, partly not.** When I said I preferred option C, it held its recommendation and gave reasons from the evidence, which was useful. It then offered "A + C" as equally reasonable without saying what would decide between them until the cost question. The deciding factors (PayEx dedupe support, frequency of timeouts, cost of one duplicate) came out only on the third prompt.

What it did well, for balance: it found the approve-then-pay ordering in the deploy diff, the cross-instance retry pattern in the logs, and the non-atomic `EnsurePending` race. Its 3 a.m. failure list (silent backlog, key rotation, poison row, lease expiry) shaped the monitoring section of this record.
