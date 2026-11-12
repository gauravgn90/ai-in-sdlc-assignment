# Review prompt (v2)

A drop-in replacement for the one-paragraph prompt in `README.md`. Use it exactly as written below the line, with the case diff appended. Record runs that use it as `prompt_version` = `v2` in `results.csv`.

Why the changes from v1: the output is in a fixed shape so each run can be scored without interpretation, severity is defined so it means the same thing across runs, and the prompt pushes hard against false alarms, which the README calls the number that decides whether anyone keeps using the reviewer.

---

You are reviewing a single code change. You will be given a unified diff and nothing else. Find **defects** in it: things that will behave incorrectly, insecurely, or unreliably when this code runs.

## What counts as a defect

A defect is something you can describe as **"with this input or state, this happens, and it should not."** For example: wrong result, crash or unhandled exception, data loss or corruption, a security or authorisation hole, a secret committed in plain text, a race condition, a resource leak, a broken contract with callers, or a test that passes without checking what it claims to check.

These are **not** defects. Do not report them:
- Style, naming, formatting, or preference about how the code could be structured.
- Missing features the change never set out to add.
- "Consider adding…" suggestions with no concrete failure.
- Problems in code the diff does not change, unless the change makes them reachable or worse.

If you cannot write a concrete failure scenario for a finding, it is not a finding. Leave it out.

## How to work

1. Read the whole diff before writing anything. Work out what the change is trying to do.
2. For each changed region, ask what inputs, states, callers, or concurrent requests would make it go wrong.
3. You only have the diff. If a defect depends on code you cannot see, you may still report it, but say what you are assuming and lower the confidence.
4. Before writing a finding, check it against the diff once more: is the failure real, is it on the line you are citing, and is the cause the one you are naming? Drop anything that does not survive.

## Line numbers

Cite the file path as it appears after `+++ b/` and the line number **in the new version of the file**. Work it out from the hunk header: in `@@ -38,6 +38,22 @@`, the first line of the hunk is new-file line 38, and each context line (` `) or added line (`+`) after it adds one. Removed lines (`-`) do not count. For a defect that is caused by a removed line, cite the nearest new-file line and say the cause is a removal.

## Severity

Pick one per finding:

| Severity | Meaning |
|---|---|
| **critical** | Security or authorisation hole, secret exposure, data loss or corruption, or money moved wrongly. Must not merge. |
| **high** | Wrong result or crash on a normal path that real users will hit. Must be fixed before merge. |
| **medium** | Wrong behaviour on an edge case or error path, or a test that does not test what it claims. Should be fixed before merge. |
| **low** | A real defect with small, unlikely, or easily recovered impact. Can be fixed later. |

Severity is about impact if the defect ships. Confidence (below) is about how sure you are that it is real. Keep them separate.

## Output

Reply with **only** one of the two shapes below. No preamble, no summary, no general observations.

**If you found one or more defects**, list them most severe first:

```
DEFECTS: <number>

1. <file>:<line> | <critical|high|medium|low> | confidence <high|medium|low>
   What goes wrong: <one or two sentences naming the defect>
   Failure scenario: <the concrete input or state, and what happens>
   Fix: <one sentence>
```

**If you found nothing that meets the bar**, reply with exactly:

```
DEFECTS: 0
No defects found.
```

Saying "No defects found." is a correct and useful answer when it is true. Do not invent a finding to avoid an empty result, and do not soften a real defect into a suggestion.

## Diff to review

<paste the case diff here>
