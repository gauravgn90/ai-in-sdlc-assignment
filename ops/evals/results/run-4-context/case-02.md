I couldn't check this against the code: the working directory only contains `CLAUDE.md`, with no `backend/` folder. So these findings come from the diff and the project conventions alone. Line numbers are in the new `InvoicesController.cs`, counted from the hunk header (`+22`).

## Findings

**1. SQL injection through `customer`: line 28. Confidence: high.**
`customer` is pasted straight into the SQL string. A request like `GET /api/invoices/search?customer=x' OR '1'='1` returns every invoice. Something like `customer=';DROP TABLE Invoices;--` could change or destroy data, depending on what `_queries.Run` connects to and what permissions it has. Any signed-in user, at any role, can reach this.

**2. SQL injection through `status`: line 32. Confidence: high.**
Same problem with the optional `status` filter: `status=Approved' OR '1'='1` gets past the filter. Escaping input or checking it against a block list won't fix 1 or 2. The fix is to use parameters, or better, not to build SQL at all (see 3).

**3. `_queries` / raw SQL doesn't match this system: line 35. Confidence: medium.**
`CLAUDE.md` says storage is an in-memory repository. It also says the database exists only in the *planned* deployment described under `ops/`. The diff never declares or injects `_queries`, so this either won't compile, or it relies on a query service with no real `Invoices` table behind it. The likely fix is to add a search method to the repository interface in Domain (e.g. `Search(string customer, InvoiceStatus? status)`), implement it in the in-memory repository, and call it from the controller.

**4. Business logic in the controller: lines 28–33. Confidence: high (convention breach).**
Building the filter and its matching rules in the controller breaks "Business rules go in the Domain project, never in controllers." The endpoint also doesn't go through `Handle(...)`, so errors won't map to 404, 409 or 400 like the other endpoints.

**5. `status` is never validated: line 26 / 32. Confidence: medium.**
`status` is a free string, not the lifecycle enum (Draft, PendingApproval, Approved, Rejected). Even after the injection is fixed, a typo like `status=aproved` silently returns no results instead of a 400. Binding it as a nullable enum (`InvoiceStatus? status`) fixes both.

**6. `customer` handling is unclear: line 26 / 28. Confidence: low.**
If nullable reference types are on, the non-nullable `customer` makes the parameter required, so a request without it gets a 400. If they're off, a missing `customer` becomes `LIKE '%%'` and returns everything. Either way, `%` and `_` inside `customer` act as wildcards, even once the query uses parameters.

**7. No tests: whole diff. Confidence: high (convention breach).**
`CLAUDE.md` says every new endpoint needs tests using `FakeInvoiceRepository`. The diff has none: no `InvoicesControllerTests` cases for search, filtering by status, or bad input.

## Not a problem
- **Route clash between `search` and `{id}`:** the fixed `search` route takes priority over `{id}`, so `GET /api/invoices/search` won't be read as an id.
- **Role restriction:** search only reads data, so the sign-in that covers every endpoint is enough. It doesn't need Approver or Admin.

Findings 1–3 should block the merge. I'd recommend rewriting the search as a repository method rather than patching the SQL.
