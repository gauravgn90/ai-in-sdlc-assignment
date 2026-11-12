# Review eval results

- **Review prompt (v1):** the prompt in `ops/evals/README.md`, unchanged
- **Runner:** `ops/evals/run-eval.sh`, one fresh headless Claude Code session per case, run in an empty directory
- **Model:** Claude Code 2.1.304, session default model, the same for all four runs (`results/<run>/_run-info.txt`)
- **Cases:** 12 (the 10 provided plus case-11 and case-12); 8 with a defect, 4 clean (see `answer-key.md`, written before scoring)
- **Changed variable (run 4):** the context file. `AGENTS.md` is given to the reviewer as `CLAUDE.md`. Prompt and model are unchanged.
- **Dates:** runs 1–2 on 2026-11-10. Run 2 case-12, run 3 and run 4 on 2026-11-12, re-run after the first attempt hit the Claude session limit.

## Result

**The reviewer caught all 8 defects in every run. Its one consistent error was a false alarm on the clean case-12, which appeared in all three baseline runs and disappeared when `AGENTS.md` was supplied as context.** I treat that as a likely improvement on one specific failure mode, not a proven improvement in general (see the end of this file).

## Per-case verdicts

C = caught, M = missed, FA = false alarm, OK = clean and correctly passed.

| Case | Truth | Run 1 | Run 2 | Run 3 | Run 4 (context) |
|---|---|---|---|---|---|
| case-01 | Defect | C | C | C | C |
| case-02 | Defect | C | C | C | C |
| case-03 | Defect | C | C | C | C |
| case-04 | Clean | OK | OK | OK | OK |
| case-05 | Defect | C | C | C | C |
| case-06 | Clean | OK¹ | OK | OK | OK¹ |
| case-07 | Defect | C | C | C | C |
| case-08 | Defect | C | C | C | C |
| case-09 | Clean | OK² | OK² | OK² | OK²,⁵ |
| case-10 | Defect | C | C | C | C |
| case-11 | Defect | C | C | C | C |
| case-12 | Clean | **FA³** | **FA³** | **FA³** | **OK⁴** |

## Rates

| Run | Caught (of 8) | Missed (of 8) | False alarms (of 4 clean) | Catch rate | False-alarm rate |
|---|---|---|---|---|---|
| 1 | 8 | 0 | 1 | 100% | 25% |
| 2 | 8 | 0 | 1 | 100% | 25% |
| 3 | 8 | 0 | 1 | 100% | 25% |
| **Baseline (1–3)** | **8.0** | **0** | **1.0** (range 1–1) | **100%** | **25%** |
| 4 (AGENTS.md as context) | 8 | 0 | 0 | 100% | 0% |

## Notes on the scoring

1. **case-06 (runs 1 and 4):** the reviewer said the hunk header is malformed. That's true (`git apply --check` reports "corrupt patch at line 41"), but it's a fault in the eval artifact, not in the code under review, so it isn't counted as a false alarm.
2. **case-09:** every run flagged the README claim that signing out resets the sample data. That claim is false (`AuthController.Logout` only removes the session), so it's a correct finding, not a false alarm.
3. **case-12 (runs 1–3):** each time, the reviewer asserted that the new `ArgumentException` was the "wrong exception type" and would probably surface as a 500. In this codebase `ApiControllerBase.Handle` maps `ArgumentException` to **400**, so the claimed failure doesn't exist. Run 3 added a second wrong claim: that existing tests would fail because `InvoiceWith` leaves `Amount` at 0. In fact it sets `Amount = 100m`.
4. **case-12 (run 4):** "no definite defects". It explicitly reasoned that `ArgumentException` "presumably maps to 400 through `Handle(...)`", the fact it got from `AGENTS.md`. It kept a low-to-medium note asking for that mapping to be confirmed. That's a request to check, not an asserted defect.
5. **case-09 (run 4), a side effect of my runner:** the reviewer added a low-confidence note that the README points to an `AGENTS.md` "that doesn't exist here". It said that because my runner copies `AGENTS.md` into the sandbox under the name `CLAUDE.md`. This is noise I introduced, not the reviewer's fault. The fix is to copy the file under both names, as the repo does (`CLAUDE.md` contains `@AGENTS.md`).

**Other effect of the context file:** with `AGENTS.md`, the reviewer also reported convention breaches on the defect cases: "no tests for the new endpoint" (01, 02, 03, 05, 10, 11) and "business logic in the controller" (01, 02, 05). Those are real breaches of the project rules, so they aren't false alarms, but each review got longer. If reviewers start skimming, that cost won't show up in these rates.

## Was the change an improvement, and how sure am I?

**Likely yes, for this failure mode. Moderate confidence. Not proven in general.**

- **Signal:** the change flipped a case that **all three** baseline runs got wrong (case-12), with no loss in catch rate. That meets the bar I set before running it. The mechanism is also clear: the false alarm came from not knowing how `Handle` maps exceptions, and `AGENTS.md` states that mapping. So the result is explained, not just observed.
- **Why only moderate:** it's one run of the variant against three baseline runs, and one case. With only 4 clean cases, one case moves the false-alarm rate by 25 points. The catch rate can't show any improvement, because the baseline was already 8/8 (a ceiling effect).
- **What would raise confidence:**
  - two more runs of the variant
  - more clean cases that depend on project conventions, so the false-alarm rate has room to move
  - harder defect cases, so the catch rate isn't stuck at the ceiling
  - roughly 30+ cases to detect a 10-point difference
