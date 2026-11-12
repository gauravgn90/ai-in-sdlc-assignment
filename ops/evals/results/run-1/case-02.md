I found two definite defects, both SQL injection, plus a few smaller issues.

## Defects

**1. SQL injection through `customer`**
- **File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`, line 28 (`var sql = $"SELECT * FROM Invoices WHERE CustomerName LIKE '%{customer}%'";`)
- **What goes wrong:** The query-string value goes straight into the SQL text. A request like `GET /invoices/search?customer=x' OR 1=1 --` returns every invoice. With stacked queries (SQL Server allows them by default), `customer='; DROP TABLE Invoices; --` or `'; UPDATE ...` runs any statement the DB account is allowed to run. It can also read other tables with `UNION SELECT`.
- **Confidence:** High.
- **Fix:** Use a parameterized query, e.g. `WHERE CustomerName LIKE @customer` with the parameter set to `"%" + customer + "%"`. If `_queries.Run` only accepts a raw string, it needs an overload that takes parameters, or the query should go through the repository or ORM.

**2. SQL injection through `status`**
- **File:** same, line 32 (`sql += $" AND Status = '{status}'";`)
- **What goes wrong:** It's the same problem as #1, on a separate input. Fixing only `customer` leaves this one exploitable, e.g. `status=' OR '1'='1`.
- **Confidence:** High.
- **Fix:** Parameterize it as `@status`. Better still, bind it to the status enum or check it against an allow-list so bad values get a 400.

## Lower-severity issues

**3. A missing `customer` may not be handled** (line 26)
- `customer` is a non-nullable `string` but nothing validates it. With `[ApiController]` and nullable reference types turned on, a missing value gets an automatic 400. Without that setup, `customer` binds as `null`, the query becomes `LIKE '%%'`, and every invoice comes back.
- **Confidence:** Medium. It depends on project settings and attributes I can't see.

**4. LIKE wildcards aren't escaped** (line 28)
- Even after parameterizing, `%`, `_` and `[` typed by the user act as wildcards. Searching for `_` matches every name. This is a correctness problem, not a security hole.
- **Confidence:** Medium. It only matters if users search for literal wildcard characters.

**5. No limit on result size** (line 35)
- `SELECT *` with no paging can return the whole table. `customer=a` probably matches most rows, so the endpoint is easy to abuse for heavy load and returns every column.
- **Confidence:** Medium. `GetAll()` already returns everything, so this may match how the app works now. Check whether a tenant or user filter should apply here.

**6. Unverified dependency: `_queries`**
- `_queries` doesn't appear anywhere in the diff. If this change doesn't declare and inject it elsewhere, the code won't compile.
- **Confidence:** Low. It's probably defined outside the hunk shown.

The new `search` route sitting next to `{id}` is fine: ASP.NET Core picks the literal segment over the parameter.
