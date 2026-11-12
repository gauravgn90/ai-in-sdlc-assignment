# INC-2041: first-response summary

> Training scenario. All names, hosts and figures in this pack are invented (`ops/README.md:22-23`).

*Prepared from the evidence pack exported 11:14Z on 14 Jan 2026. Claims marked **[GUESS]** are inference and aren't shown directly by the evidence. Paths are relative to `ops/incidents/INC-2041/`.*

## What's broken

Approving invoices is slow and partly failing on **all three instances** (web-01, web-02, web-03) since about **10:03Z**. Release **2.14.0** is still live, and nothing has been rolled back.

## Impact

- **Errors:** from 10:03Z to 11:09Z there were **1,501 5xx responses out of 24,564 requests (6.1%)**, against an alert threshold of 2% (`metrics.csv:25-91`, `alert.md:5`). Before 10:03Z there were none.
- **Latency:** p95 went from about **120 ms to 7–17 s**, peaking at 17,152 ms at 10:44Z (`metrics.csv:2-24`, `:66`). Requests that succeed are slow too, for example a 4,099 ms 200 at `app-logs.txt:264`.
- **Business:** it's the second-to-last working day of the month, the busiest approval window (`README.md:28`). Finance reported the problem at 10:09Z (`alert.md:14-15`).
- **[GUESS] Invoices may be approved but not paid, or paid twice.** 2.14.0 saves the approval **before** calling PayEx (`deploy-diff.patch:84-85`), so a 500 can leave an invoice Approved with no payment. Users also retried failed approvals and later got 200s (INV-41360: `app-logs.txt:169`, `:201`), which may have sent a second payment. Neither is confirmed.

## Likely cause (high confidence, not yet proven)

**2.14.0 runs out of outbound connections because it creates a new `HttpClient` for every PayEx call, and month-end traffic makes it happen fast.**

| Evidence | Where |
|---|---|
| 2.14.0 builds `new HttpClient` on every `SubmitAsync` call | `deploy-diff.patch:46-50` |
| …and removes the pooled, factory-managed client with its 10 s timeout | `deploy-diff.patch:114-119` |
| The deploy finished at 09:58:41Z, just before errors began | `app-logs.txt:70-71` |
| Outbound connections climb steadily from about 370 to about 2,800, much faster than traffic | `metrics.csv:20-62` |
| The errors are port exhaustion: `SocketException (10048): Only one usage of each socket address…` on all 3 instances (81 of 106 PayEx errors) | `app-logs.txt:157` onward; 34/35/37 per instance |
| Timeouts are **100 s**, the .NET default, so the configured 10 s isn't applied | `app-logs.txt:179`; config still says `00:00:10` at `deploy-diff.patch:136` |
| Restarting web-02 at 10:41Z freed its connections: outbound fell from 2,790 to 2,469 and 5xx dipped, then both rose again | `alert.md:23-24`; `metrics.csv:62-66` |
| CPU 25–56% and memory 39–47%: no sign of a CPU or memory limit | `metrics.csv` (whole window) |
| PayEx's status page was green twice | `alert.md:19`, `:25` |

**Contributing factor:** traffic jumped from about 60 to about 350 requests a minute at **09:55Z**, three minutes *before* the deploy (`metrics.csv:17`). This is month-end volume. It didn't cause the failure, but it made connections run out within minutes.

## Probably not the cause

- **`Notifications:LegacyEndpoint` deprecation warnings.** They repeat every 11 minutes, including before the deploy (`app-logs.txt:22`, `:61`).
- **web-03 being recycled for routine maintenance at 10:03:00Z** (`app-logs.txt:88-90`). It lines up exactly with the first latency jump (`metrics.csv:25`), but all three instances degrade, including the two that weren't recycled. **[GUESS]** It's a coincidence; it can't be ruled out that it made things worse locally.

## Evidence gaps (flag before trusting the logs)

- **The log export is sampled or filtered.** It has 24 logged 500s, but the metrics count 1,501. The first PayEx ERROR is at 10:19Z (`app-logs.txt:157`), but 5xx start at 10:04Z. Don't draw conclusions from log counts.
- **PayEx errors are logged under `[Notifications]`** rather than a PayEx category, which makes them easy to miss in searches.
- **[GUESS] Why 500s come back after 11–27 s** (`app-logs.txt:129`, `:373`) when the timeout is 100 s. It may be a load balancer or upstream timeout, but nothing here shows it.

## Suggested next step

1. **Decide: roll back to 2.13.4.** This needs a named approver or the incident commander. 2.13.4 ran cleanly for nine days (`README.md:26-27`). Two things to know before deciding:
   - Rollback also removes the PayEx call from approvals, since 2.14.0 is what added it (`deploy-diff.patch:7`). Payments for invoices approved after the rollback won't be sent automatically, so finance must be told.
   - It also reverts the DTO rename (`DecidedBy` back from `ApprovedBy`, `deploy-diff.patch:94-97`). Check whether the UI or any client already depends on the new name.
2. **Confirm the cause, read-only, in parallel.** On one instance, count connections to the PayEx host by state (`ss -tan | grep <payex-ip>`). Expect a large and growing number in `TIME_WAIT`.
3. **Don't do these:**
   - Restarting instances: it buys about 3 minutes (`alert.md:23-24`).
   - Scaling out: it delays connection exhaustion without fixing it.
   - Turning on PayEx retries: they would add duplicate-payment risk.
4. **After the rollback, start a payment check** for every invoice approved from 09:58Z until the rollback. Find invoices that are Approved with no PayEx receipt, and invoices submitted more than once. Finance owns the result.
5. **Fix forward later:** restore `AddHttpClient<IPayExClient, PayExClient>` with the 10 s timeout, and move the PayEx call out of the approval request (see the outbox comparison).
