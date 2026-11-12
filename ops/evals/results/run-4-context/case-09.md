I found one probable defect and one minor one. I couldn't check either against the code: the working directory has only `CLAUDE.md`. There's no `README.md`, `backend/` or `AGENTS.md`, so this review is based on the diff and the project conventions alone.

**1. `README.md`, about line 25: "To reset the sample data without restarting, sign out and sign in again." Confidence: medium-high that this is wrong.**
- **What goes wrong:** this contradicts the sentence just before it. That sentence says the data lives in the in-memory store and only resets when the process restarts. `CLAUDE.md` describes the repository as an in-memory implementation registered in `Program.cs`, which normally means it's created once and kept for the life of the process. Signing out only clears the sign-in session. It doesn't clear or reseed the repository.
- **Effect:** someone who follows the instruction will still see their earlier invoices after signing back in, so the documented reset doesn't work.
- **Fix:** delete the line, or say "restart the app to reset the sample data". If a reset on sign-out really is wanted, it would need a real reset feature with tests, which belongs in the code, not the README.
- **To confirm:** check whether the sign-out handler under `Auth/` touches the invoice repository. If it doesn't, this is definitely a bug.

**2. `README.md`, line 21: "listed in AGENTS.md". Confidence: low-medium.**
- **What goes wrong:** this part of the line was already there, but the edit keeps it. The demo accounts are listed in `CLAUDE.md`, and there's no `AGENTS.md` here, so the reader may be pointed at a file that doesn't exist.
- **Fix:** if the full repo has no `AGENTS.md`, point to `CLAUDE.md` or list the two demo accounts in the README.
- **Related, also unchecked:** the new claim that the accounts "exist only in the in-memory store" is only true if they're seeded in code. If they come from configuration, the wording is slightly off.

**`appsettings.json`: no defects.** The JSON is valid, and `"Microsoft.AspNetCore": "Warning"` is the standard ASP.NET Core default. It does hide the framework's Information-level request and routing logs. That's expected behaviour, not a bug, but worth knowing if anyone used those logs while debugging locally.
