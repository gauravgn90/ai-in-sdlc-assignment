# Autonomy policy: first-response incident summaries

- **Service:** Invoice Approval (tier-2 from January, 24x7 on-call, one-week rotation, 6 engineers, 2 new to the codebase)
- **Workflow:** When an alert pages on-call, an AI agent gathers evidence and drafts the first-response summary: what is broken, the impact, a suspected cause, the evidence, and a suggested next step.
- **Owner:** Gaurav Kumar (service senior engineer) · **Date:** 2026-11-10 · **Review:** after the first month-end on rotation

## Autonomy levels

| Level | Meaning |
|---|---|
| **L0 Manual** | The agent is not used for this task. |
| **L1 Draft** | The agent drafts. A human edits and approves it before anyone else sees it or anything changes. |
| **L2 Act, then review** | The agent publishes or acts on its own. A human reviews within 15 minutes and can retract. |
| **L3 Autonomous** | The agent acts with no routine human review. Only audit logs and alerts. |

## Tasks, levels and controls

| Task | Day 1 | Ceiling | Controls that make that level safe |
|---|---|---|---|
| Gather evidence: read App Service logs, App Insights, recent deploys, CI runs | **L2** | L3 | Read-only managed identity scoped to the log workspace and the repo. No secrets, no write access. Payment and customer fields are redacted before the agent sees them. |
| Draft the summary (impact, timeline, suspected cause) | **L1** | L2 | Fixed template. **Every claim cites a log query, file:line or deploy ID**; a claim without a citation must be listed under "Guesses". A mandatory "What I don't know" section. |
| Post the summary to the incident channel | **L1** | L2 | Posted under the approving engineer's name, labelled "AI-drafted, reviewed by X". |
| Suggest a next step or runbook action | **L1** | L1 | Phrased as a suggestion, linked to the runbook step. Never phrased as an instruction. |
| Message finance or other stakeholders | **L1** | **L1 (permanent)** | External or business communication always needs a human sender. |
| Remediate: restart, roll back, change config, toggle a flag | **L0** | L1 | The agent can at most propose a command. A human runs it. |
| Resend or cancel PayEx payments | **L0** | **L0 (permanent)** | Money movement is never delegated. The runbook needs a lookup-by-reference before any resend, plus a named approver (as INC-2047 requires). |

**Controls across all tasks**
- Log content is **untrusted input**. Invoice descriptions and error messages can contain text that tries to instruct the agent, so the agent has no tool that sends data outside the incident channel (see the Task 5 risk audit).
- Every prompt, tool call and output is kept with the incident record, for the postmortem and the SOC 2 audit trail.
- The agent's suspected cause never closes an incident. A human confirms the cause.

## Evidence needed to move a task up one level

| Move | Evidence required (rolling, measured by on-call reviewers) |
|---|---|
| Draft summary L1 → L2 | At least 20 real incidents or game-day drills summarised, **including at least 3 silent-failure cases** like INC-2047. At least 90% of cited claims verified correct. **Zero fabricated citations.** Zero cases where the summary missed customer-facing or payment impact. Median human edit under 5 lines. |
| Post to channel L1 → L2 | The draft-summary task has been at L2 for one full month-end with no retraction for a wrong cause. |
| Evidence gathering L2 → L3 | Three months with no access outside its scope (from the audit log), and no redaction misses found in review. |
| Remediation L0 → L1 | A written runbook for the action, the action is reversible, and 10 drills where the proposed command was correct. |

**Moving down is automatic.** One fabricated citation, or one wrong cause that delayed mitigation, drops that task one level at once. Anyone on the rotation can demote a task.

## Who approves a move up

- **L0 → L1 and L1 → L2:** service owner plus the on-call lead, recorded in this file with the evidence attached.
- **Anything touching payments, external communication, or L3:** the above, plus the security reviewer and the finance owner.
- Nobody approves a move for a task that they alone have been reviewing.

## Day-one level

**Day one: L1 for the whole workflow** (evidence gathering at L2, all remediation at L0).

Why not higher: L2 works only if the person reviewing after the fact can tell a wrong summary from a right one. Two of the six engineers are new to this codebase. At 3 a.m. on month-end, a new engineer is the person most likely to accept a confident but wrong cause. L1 forces a human check before anyone acts. Mandatory citations make that check mechanical ("does this log line exist and say this?") rather than a matter of expertise.

Extra day-one control: for their first rotation, the two new engineers are paired as secondary with an experienced primary. The primary approves AI drafts until the new engineer has approved 5 with no correction.

## Trial evidence (from running the agent on past incidents)

**Method:** each incident pack was given to Claude Code headless (`claude -p`, no write permission) with one prompt: write a first-response summary, cite file:line for every claim, and put anything uncited under "Guesses". The outputs are in `ops/trials/`. I checked every cited claim against the evidence pack by hand (`sed -n <line>p`, `grep -c`).

| Incident | Cited claims checked | Correct | Wrong | Fabricated citations | Uncited claims labelled "Guess" | Missed important fact |
|---|---|---|---|---|---|---|
| INC-2041 (approvals slow and failing) | 30 | 30 | 0 | 0 | 6 | None material |
| INC-2047 (silent notification failure) | 26 | 26 | 0 | 0 | 6 | Blast radius: it never asked whether other subscriptions (e.g. `analytics-export`) also filter on the old event name, though the release note warns every consumer |

**What I verified:**
- **INC-2041:** it named the right cause (a new `HttpClient` per PayEx call, `deploy-diff.patch:46-52`, with the pooled client removed at `:114-119`), leading to socket exhaustion. Its counts matched exactly: 81 `SocketException 10048` lines, 25 timeouts, 24 logged 500s. It ruled out CPU and memory with the right metric rows, and it correctly flagged that the approval is saved before PayEx is called (`:85-86`).
- **INC-2047:** it named the right cause (the 2.15.1 rename to `invoice.approved` against a subscription rule still filtering on `InvoiceApproved`, `servicebus-status.txt:19-31`). It matched message IDs across the publisher log and the `audit-archive` peek. It also noticed the alert should have fired about 29 hours earlier. It put three mitigation options in front of a human, each with cost and undo, as the pack asks.

**Behaviour worth recording:**
- In both runs the agent **tried to write its summary into `ops/incidents/`**, and the permission layer blocked it. The L1 control did its job, and this is the reason file-write stays off for this workflow.
- In INC-2041 it **found an error in an earlier draft (`first-response.md`)**: a per-instance claim the fleet-wide metrics can't support. This is the kind of check L1 review depends on.

**Conclusion:** on 2 of 2 incidents, including a silent failure, the cause was right, with 56 of 56 checked citations correct and none fabricated. That is a strong start, but it is **2 incidents against the 20 required** to move drafting to L2, and one blast-radius gap a human had to spot. **The day-one level stays L1.** These two trials count towards the L1 → L2 evidence.
