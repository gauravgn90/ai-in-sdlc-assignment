I found one serious defect (SQL injection) and two smaller ones. All line numbers refer to the new version of `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`. I could only see the diff, not the rest of the repo.

### 1. SQL injection through `customer` and `status`: high confidence
**Lines 28 and 32**

Both query-string values are placed directly into the SQL string. Anyone who can call the endpoint can run their own SQL. For example:

```
GET /invoices/search?customer=x' OR 1=1 --
GET /invoices/search?customer=x&status=' ; DROP TABLE Invoices; --
```

The first returns every invoice, which may include other tenants' or customers' data. The second can delete or change data, depending on the database permissions and whether `_queries.Run` allows several statements in one call. UNION-based queries could also read other tables, such as users or credentials.

**Fix:** use parameters, and put the wildcards in the parameter value rather than in the SQL text:

```csharp
var sql = "SELECT * FROM Invoices WHERE CustomerName LIKE @customer";
// parameter: @customer = "%" + EscapeLike(customer) + "%"
if (!string.IsNullOrEmpty(status)) sql += " AND Status = @status";
```

Even better, go through the repository or EF Core instead of passing raw SQL to `_queries.Run`.

### 2. LIKE wildcards in `customer` are not escaped: medium confidence
**Line 28**

This is still a problem after you add parameters. `%`, `_` and `[` (on SQL Server) in user input are treated as wildcards. Searching for `customer=%` or `customer=_` returns every row, and real names containing `_` match the wrong rows. Escape these characters, or use `ESCAPE`, before adding the surrounding `%`.

### 3. Missing `customer` may return every invoice: low to medium confidence
**Lines 26 and 28**

`customer` is declared as a non-nullable `string`, but nothing checks it. What happens depends on code I can't see:
- If nullable reference types are on and `ApiControllerBase` has `[ApiController]`, a missing `customer` gets an automatic 400. That's fine.
- Otherwise `customer` is `null`, the SQL becomes `LIKE '%%'`, and the endpoint returns the whole table with no limit. `customer=` (empty) does the same in every case.

If a search term is meant to be required, reject null or empty input explicitly. Either way, add a limit or paging.

### Couldn't verify
- **`_queries` (line 35):** it isn't declared or injected anywhere in the diff. If this change doesn't add it to the constructor elsewhere, the build will fail. I can't confirm this from the diff alone.

The route itself is fine: `"search"` is a literal segment, so ASP.NET Core matches it before `{id}`.
