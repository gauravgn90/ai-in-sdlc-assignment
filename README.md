# Submission: AI in SDLC home assignment

- **Author:** Gaurav Kumar
- **Agent used:** Claude Code (with the Mermaid MCP), plus Claude chat for planning and drafting
- **Demo video:** <paste video link here>

| # | Deliverable | Where |
|---|---|---|
| 1 | Mermaid source for the as-built and target diagrams, with citation list and inferred-items list | [`docs/architecture/c4-container.md`](docs/architecture/c4-container.md), [`approval-sequence.md`](docs/architecture/approval-sequence.md) (as-built); [`c4-container-target.md`](docs/architecture/c4-container-target.md) (target). Rendered PNGs sit alongside. |
| 2 | One architecture test, with the command that runs it | [`backend/tests/InvoiceApp.Tests/ArchitectureTests.cs`](backend/tests/InvoiceApp.Tests/ArchitectureTests.cs). Run with `dotnet test backend/InvoiceApp.sln` (8 passed). |
| 3 | Exactly-once decision record, including "Where the agent was wrong or useless" | [`docs/architecture/adr-001-exactly-once-payex.md`](docs/architecture/adr-001-exactly-once-payex.md) |
| 4 | One-page autonomy policy, with the day-one level stated | [`docs/autonomy-policy-incident-summaries.md`](docs/autonomy-policy-incident-summaries.md). **Day-one level: L1.** Trial evidence: [`ops/trials/`](ops/trials/) |
| 5 | Two added evaluation cases, and a results table covering three runs plus the changed-variable run | Cases: [`ops/evals/cases/case-11.diff`](ops/evals/cases/case-11.diff), [`case-12.diff`](ops/evals/cases/case-12.diff). Results: [`ops/evals/RESULTS.md`](ops/evals/RESULTS.md). Runner: [`run-eval.sh`](ops/evals/run-eval.sh). Answer key: [`answer-key.md`](ops/evals/answer-key.md). Raw outputs: [`ops/evals/results/`](ops/evals/results/) |
| 6 | Risk audit, with a decision recorded | [`docs/risk-audit-and-measurement-plan.md`](docs/risk-audit-and-measurement-plan.md), Part A. **Decision: redesign by removing the external-communication leg.** |
| 7 | Measurement plan, with the two numbers captured | Same file, Part B. **CI pipeline median 31.3 min; change failure rate 2 of 4 releases (50%).** |
| 8 | 8-to-10-minute demo video, uploaded and linked | <paste video link here> |
| 9 | AI Augmentation logs | [`logs/`](logs/) (see [`logs/README.md`](logs/README.md)) |
