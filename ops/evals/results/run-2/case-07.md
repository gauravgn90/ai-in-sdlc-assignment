I could only review the hunk itself. The working directory isn't a git repo and has no source, so I couldn't check what `CurrentUser`, the invoice type or `_logger` actually are.

**1. The whole user session is written to the logs**
`ApprovalsController.cs:36` (`CurrentUser` logged as `{@Session}`)
- **What goes wrong:** `@` tells structured loggers like Serilog to serialize every public property of the object, not call `ToString()`. A "current user" or session object usually holds the user's ID, email, roles and claims. It often also holds bearer or refresh tokens, session IDs or anti-forgery values. All of that ends up in log storage and anything that collects logs from it, which is usually readable by far more people than the auth system. If `CurrentUser` is or wraps a `ClaimsPrincipal`, it also writes every claim and can produce very large log entries.
- **Fix:** log only an identifier, e.g. `"Invoice {InvoiceId} approved by {Approver}", invoice.Id, CurrentUser.Name`.
- **Confidence:** High that this is a defect. Medium on how bad it is, because that depends on fields I can't see.

**2. The whole invoice is written to the logs**
`ApprovalsController.cs:35–36` (`invoice` logged as `{@Invoice}`)
- **What goes wrong:** An invoice usually holds sensitive financial and personal data: vendor or customer names and addresses, tax IDs, bank or payment details, line items and amounts. This copies it into logs on every approval, which can break data-handling and retention rules (GDPR, PCI, SOX-style controls). If the invoice is an ORM entity with navigation properties, serializing it can also pull in related records, and with lazy loading it can trigger extra database queries. The output can get large, though Serilog caps how deep it goes.
- **Fix:** log `invoice.Id` and the new status only.
- **Confidence:** High.

**3. `_logger` might not exist in this controller (unverified)**
`ApprovalsController.cs:34`
- **What goes wrong:** The diff adds a call to `_logger` but doesn't add a field or constructor injection for it. If neither `ApprovalsController` nor `ApiControllerBase` already defines `_logger`, this won't compile.
- **Confidence:** Low, since it's probably defined outside the hunk. Worth a quick check.

**4. Minor: `@` does nothing without Serilog or a similar logger**
- **What goes wrong:** With the default `Microsoft.Extensions.Logging` providers, `@` is ignored and the objects are logged with `ToString()`. The output is then probably just type names, so the log line is useless. That avoids the leak, but it also means the change doesn't do what it was meant to.
- **Confidence:** Medium, depending on which logging provider the app uses.

Fixing issue 1 also fixes issues 2 and 4: log `invoice.Id` and `CurrentUser.Name` (or the user's ID) as plain values instead of destructuring the objects.
