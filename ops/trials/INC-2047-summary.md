I wasn't given permission to save the summary as `ops/incidents/INC-2047/first-response.md`, so here it is. I read all six files in the pack. Paths are relative to `ops/incidents/INC-2047/`.

# INC-2047: first-response summary

## What's broken

Approved invoices no longer trigger supplier notifications.
- **Approval itself works.** Invoice status and the audit trail are correct, and the approval request returns 200 (`alert.md:22-24`).
- **The approval service is still publishing events,** with no errors or warnings (`publisher-logs.txt:15-30`, `:32`).
- **The notification worker is running and hasn't restarted** (`worker-logs.txt:25`). But it has received nothing since 2026-01-27 16:55Z (`worker-logs.txt:15-16`, `:19-23`).

## Customer and business impact

- **Suppliers aren't getting confirmations.** Finance approved "about forty invoices this morning" and none of the suppliers got a confirmation (`alert.md:16-18`). The last notification anyone can confirm was on 27 Jan (`alert.md:26`).
- **Duration:** about 29 hours so far. It started with the first event after the deploy, at 28 Jan 09:03Z (`publisher-logs.txt:15`), and is still going at the export time (`publisher-logs.txt:4`).
- **How many:** the publisher log shows 15 approvals with no notification. That's 6 on 28 Jan (`publisher-logs.txt:15-20`) and 9 on 29 Jan (`:22-30`). Finance hasn't been given a number yet (`alert.md:31-32`).
- **Timing:** this is the month-end window (`README.md:30`). Fixing the flow from now on won't send the notifications that were missed (`README.md:32-33`).
- **Detection was late.** The worker's health check said "ok" with 0 messages processed four times in a row (`worker-logs.txt:19-23`). Finance reported the problem at 13:48Z (`alert.md:14`), before the alert fired at 14:06Z on 29 Jan (`alert.md:3`).

## Most likely cause (high confidence)

**Release 2.15.1 renamed the event type from `InvoiceApproved` to `invoice.approved`. The `notification-worker` subscription still filters on the old name, so no approval events reach it.**

| Evidence | Where |
|---|---|
| Events before the deploy use `eventType=InvoiceApproved` | `publisher-logs.txt:6-10` |
| 2.15.1 was deployed at 08:41–08:42Z on 28 Jan | `publisher-logs.txt:12-13` |
| Every event after the deploy uses `invoice.approved` | `publisher-logs.txt:15-30` |
| The rename was deliberate, and the release notes say consumers must update their subscriptions | `recent-changes.md:15-18`, `:24-26` |
| No subscription or subscription rule was changed | `recent-changes.md:36` |
| The worker's only rule filters on `eventType = "InvoiceApproved"` | `servicebus-status.txt:19-31` |
| The worker's subscription has 0 active and 0 dead-lettered messages, so the events never arrive at all | `servicebus-status.txt:15` |
| The catch-all `audit-archive` subscription does get the new events, with the same message IDs | `servicebus-status.txt:33-43`, `:56-73` vs `publisher-logs.txt:28-30` |

**Ruled out:**
- **The worker isn't broken.** It hasn't restarted and logs no errors (`worker-logs.txt:25-26`).
- **The topic is healthy.** It is Active and about 0.4 MB of 1,024 MB (`servicebus-status.txt:7-9`, `:47`).
- **The earlier changes aren't the cause.** These are the 19, 23 and 26 Jan changes (`recent-changes.md:32-34`), and notifications kept working after all of them until 27 Jan (`worker-logs.txt:16`).

## Evidence gaps

- **The three counts don't agree.** The publisher log shows 15, finance says about 40, and the `audit-archive` subscription holds 54 messages (`publisher-logs.txt:15-30`, `alert.md:16`, `servicebus-status.txt:17`). The publisher log export was filtered (`publisher-logs.txt:3`). The approval audit trail (`alert.md:22-23`) is the best source for the real list.
- **The 54 `audit-archive` messages haven't been consumed** (`servicebus-status.txt:17`). Only the newest 3 were looked at (`:54-74`).

## Suggested next step

Nothing has been changed yet (`alert.md:30`). Any production change needs a named approver, and out of hours that's the incident commander (`README.md:28-29`).

1. **Count the affected invoices now, read-only.** From the audit trail, list every invoice approved since 28 Jan 08:42Z and give the list to finance.
2. **Ask the approver to choose one of these options:**

| Option | What it changes | Cost | How to undo it |
|---|---|---|---|
| **A. (Recommended)** Add a second rule to `notification-worker` matching `invoice.approved` | One subscription rule, no deploy | Smallest change. Only fixes new approvals. | Delete the rule |
| **B.** Roll back to 2.15.0 | The whole release | Also reverts the audit export fields and dependency bumps (`recent-changes.md:19-20`) and undoes the audit-archive alignment (`:15-17`). Risky during month-end (`README.md:30-31`). | Redeploy 2.15.1 |
| **C.** Change the worker to accept both names, plus option A | Worker code | Slowest: needs a build and a deploy during month-end | Redeploy the previous worker |

3. **Recovering the missed notifications is a separate step, and finance must sign off.** The missed events never reached the worker's subscription (`servicebus-status.txt:15`), so they have to be re-sent from the list in step 1. **Don't pull them off `audit-archive`:** that would take them away from the audit system. Peeking at them is safe (`:51-52`).
4. **Post-mortem follow-ups:**
   - The health check reports "ok" when nothing has been processed (`worker-logs.txt:19-23`).
   - The release note warned that subscriptions needed updating (`recent-changes.md:25-26`), but nobody updated them (`:36`).

## Guesses

- **Option A may not be enough** if the worker's own code also checks for `InvoiceApproved`. The worker's code isn't in the pack. To check, approve one test invoice after the change and look for "Received" and then "Notification sent" in the worker log.
- **I'm assuming the subscription accepts a message when either rule matches.** That's how Azure Service Bus normally works, but the pack doesn't show it.
- **I don't know why the alert fired about 29 hours late** when the rule (`alert.md:5`) should have triggered on 28 Jan. It may be disabled, or its business-hours window may be set up wrong.
- **What the 54 `audit-archive` messages are:**
  - They might include other event types, or a backlog from before 28 Jan if the audit consumer is behind.
  - If nothing reads them, they will expire after 14 days (`servicebus-status.txt:48`), so around 11 Feb for the earliest ones.
- **The ~40 vs 9 gap for today** could be an incomplete log export, or an estimate by finance.
- **Effect on suppliers:** they may start chasing finance. That's an assumption, as there are no supplier complaints in the pack.
