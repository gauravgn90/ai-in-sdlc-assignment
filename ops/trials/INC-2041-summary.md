I couldn't save the summary as a file because the write to `ops/incidents/INC-2041/first-response-summary.md` was blocked by permissions, so it's below instead. I used a new filename on purpose: there's already an untracked `first-response.md` in that folder and I didn't want to overwrite it. Paths are relative to `ops/incidents/INC-2041/`. One caveat: under `AGENTS.md`, `ops/` describes a *planned* deployment, so PayEx and the three instances don't exist in this repo's code.

---

# INC-2041: first-response summary

## What is broken
- **Invoice approval** (`POST /api/invoices/{id}/approve`) is slow and returning 500s on all three instances: web-01 (`app-logs.txt:129`), web-02 (`:167`) and web-03 (`:173`).
- **The PayEx call inside approval fails in two ways:**
  - "Only one usage of each socket address" errors (`SocketException 10048`): 81 lines, starting at `app-logs.txt:157`, on all three instances (`:157`, `:180`, `:185`).
  - Timeouts (`HttpClient.Timeout of 100 seconds`): 25 lines, starting at `app-logs.txt:179`.
- **Release 2.14.0 is still live.** It hasn't been rolled back (`alert.md:28`).

## Customer and business impact
- **Errors:** the 5xx-rate alert fired at 10:12Z at 4.1%, against a 2% threshold (`alert.md:3-6`). There were no 5xx before 10:04Z (`metrics.csv:2-25`). Later it reached 30–47 per minute, for example 47 at 10:49Z (`metrics.csv:71`).
- **Latency:** p95 was 111–148 ms before the incident (`metrics.csv:2-24`). It peaked at 18,565 ms at 10:48Z (`metrics.csv:70`) and was still 14 s at 11:09Z (`:91`).
  - Successful approvals are slow too, for example 8.9 s (`app-logs.txt:302`).
  - Failed ones take 11–27 s to return the 500 (`app-logs.txt:193`, `:373`).
- **Finance noticed first.** They reported it at 10:09Z, before the alert (`alert.md:14-15`).
- **It's the busiest time of the month.** This is the second-to-last working day, the heaviest approval window (`README.md:28-29`). 5-minute approval volume was 384 against a 7-day average of 96 (`app-logs.txt:79`).
- **Payments may be wrong.** The invoice is approved *before* PayEx is called (`deploy-diff.patch:85-86`). The PayEx call can throw (`:52-53`) and nothing catches the error (`:80-90`). So a 500 can come back after the approval has already been saved.

## Most likely cause
**2.14.0 creates a new `HttpClient` for every PayEx call. Under month-end load, the instances run out of outbound sockets.**

| Evidence | Citation |
|---|---|
| A new `HttpClient` is built on every `SubmitAsync` call | `deploy-diff.patch:46-52` |
| The pooled `AddHttpClient` with its 10 s timeout was removed and replaced with a singleton | `deploy-diff.patch:114-119` |
| No timeout is set, so the .NET default of 100 s applies. The configured 10 s is never read | `deploy-diff.patch:46-49`, `:136`; `app-logs.txt:179` |
| The deploy finished at 09:58:41Z and latency started rising at 10:03Z | `app-logs.txt:70-71`; `metrics.csv:25` |
| Outbound connections matched requests until 10:02Z (373/371), then reached 2,882 at 421 requests/min | `metrics.csv:24`, `:61` |
| CPU peaked at 56% and memory at 47%, so this isn't resource exhaustion | `metrics.csv:61`, `:67` |
| PayEx's status page was green at both checks | `alert.md:18`, `:24` |
| Restarting web-02 helped for only about 3 minutes, which fits a leak that refills | `alert.md:22-23` |

**Contributing factor:** traffic jumped about 6× at 09:55Z, before the deploy (`metrics.csv:16-17`). 2.13.4 handled that load fine, but 2.13.4 didn't call PayEx from approvals (`deploy-diff.patch:7`).

**Unlikely causes:**
- **The `LegacyEndpoint` warning** also appears before the deploy (`app-logs.txt:22`, `:61`).
- **The web-03 recycle at 10:03Z** (`app-logs.txt:88-90`) doesn't explain it, because web-01 and web-02 degrade too (`:94-97`, `:129`).
- **The DTO rename** doesn't explain it, because 200s continue after the deploy (`app-logs.txt:72-87`).

## Suggested next step
1. **Roll back to 2.13.4.** The incident commander should approve this. 2.13.4 ran cleanly for nine days (`README.md:26-27`). Two things to know first:
   - Rollback also removes automatic PayEx submission (`deploy-diff.patch:7`), so finance must be told.
   - It reverts the `DecidedBy`/`ApprovedBy` field rename (`:102-105`).
2. **Confirm the cause read-only while the rollback runs.** Count sockets to the PayEx host by state on one instance. After the rollback, check that outbound connections go back to tracking request rate (compare `metrics.csv:2-24`).
3. **Don't restart instances in a loop or scale out.** It only buys time (`alert.md:22-23`).
4. **Check payments** for every approval from 09:58Z until the rollback. Look for invoices that are Approved but have no PayEx receipt, and invoices sent to PayEx more than once.
5. **Fix forward later.** Restore `AddHttpClient` with the 10 s timeout (`deploy-diff.patch:114-118`), and move the PayEx call out of the approve request.

## Evidence gaps
- **The logs are much thinner than the metrics.** There are only 24 logged 500s. The first is at 10:13Z (`app-logs.txt:129`), but 5xx start at 10:04Z (`metrics.csv:26`).
- **The web-02 restart isn't in the logs.** The only `[Platform]` lines are about web-03 (`app-logs.txt:88`, `:90`).
- **Metrics are for the whole fleet only** (`metrics.csv:1`), so the restart's effect on web-02 can't be isolated.
- **PayEx errors are logged under `[Notifications]`** (`app-logs.txt:157`), which makes them easy to miss.

## Guesses
- **Why errors started about 5 minutes after the deploy:** probably closed sockets building up in `TIME_WAIT` until the port range ran out. Nothing in the pack shows socket state.
- **Invoices approved but never paid:** likely for every 500 caused by a PayEx failure.
- **Possible double payments.** Some invoices got a 500 and then a later 200:
  - INV-41360 (`app-logs.txt:169` → `:201`)
  - INV-41988 (`:167` → `:183`)
  - INV-41711 went the other way, 200 then 500 (`:215` → `:217`)

  This is weak evidence: the same invoice ID repeats under 2.13.4 too (INV-41639 at `:12`, `:48`).
- **Why 500s return after 11–27 s when the timeout is 100 s:** maybe a load balancer or server timeout. The pack doesn't show which.
- **What made outbound connections before 2.14.0,** when approvals didn't call PayEx (`metrics.csv:2-20`). Unknown.
- **Whether the DTO rename quietly broke clients** that read `DecidedBy`. Not tested.

---

My summary disagrees with the existing `first-response.md` on one claim. That file says the web-02 restart dropped *web-02's* connections from 2,790 to 2,469. The metrics are fleet-wide only, so they can't show that. If you approve the write, I can save this as `first-response-summary.md`, or overwrite `first-response.md` if you'd rather replace it.
