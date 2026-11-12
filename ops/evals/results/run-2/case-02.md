# Review: `InvoicesController.Search`

I reviewed only the diff you pasted. The working directory isn't a git repo, so I couldn't check `_queries`, the base class, or how the DB layer behaves.

## 1. SQL injection through `customer`: critical, high confidence
**File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs`, line 28 (`var sql = $"... LIKE '%{customer}%'"`)

The query-string value goes straight into the SQL text. A request like `GET /invoices/search?customer=' OR 1=1--` returns every invoice. With `'; DROP TABLE Invoices;--` or a `UNION SELECT` against other tables, an attacker can read or destroy data. How bad it gets depends on the DB user's permissions and whether `_queries.Run` allows multiple statements. Any caller who can reach this endpoint can exploit it.

## 2. SQL injection through `status`: critical, high confidence
**Same file**, line 32 (`sql += $" AND Status = '{status}'"`)

Same bug as #1, reached through the optional parameter. Both need fixing; fixing only `customer` leaves this one open.

**Fix for both:** use parameters and escape LIKE wildcards. For example, with Dapper or ADO.NET:
```csharp
var sql = "SELECT * FROM Invoices WHERE CustomerName LIKE @customer ESCAPE '\\'";
var p = new DynamicParameters();
p.Add("customer", $"%{EscapeLike(customer)}%");
if (!string.IsNullOrEmpty(status))
{
    sql += " AND Status = @status";
    p.Add("status", status);
}
```
If `_queries.Run` only accepts a raw string, its signature needs to change to take parameters. Better still, add this as a repository method next to `_repository.GetAll()`.

## 3. LIKE wildcards in `customer` aren't escaped: medium confidence
**Line 28**

Even after parameterizing, a `%` or `_` in `customer` still acts as a wildcard. `customer=%` or `customer=_` matches every row. That turns the search into a "dump everything" call, made worse by #5. Escape `%`, `_` and `[` (SQL Server), or decide on purpose that wildcards are allowed.

## 4. A missing `customer` may return all invoices: medium confidence
**Line 26** (`[FromQuery] string customer`)

What happens depends on configuration I can't see:
- With `[ApiController]` and nullable reference types on, a missing `customer` gives an automatic 400. That's fine.
- Without them, `customer` binds as `null`, the interpolation produces `LIKE '%%'`, and the query returns every invoice.

Either way, nothing checks that the value isn't empty or whitespace (`customer=` gives `'%%'`). Add an explicit check that returns `BadRequest`.

## 5. No limit on result size: medium confidence
**Line 28** (`SELECT *`, no `TOP`/`LIMIT`, no paging)

Together with #3 and #4, one request can pull the whole Invoices table into memory and serialize it. That's a cheap way to exhaust resources. `SELECT *` also returns every column, possibly including ones the existing DTOs leave out. Add paging and an explicit column list or a DTO.

## 6. `_queries` doesn't appear in the diff: low confidence
**Line 35** (`_queries.Run(sql)`)

`_queries` isn't declared or injected anywhere in the diff, while the rest of the controller uses `_repository`. If the field and its constructor injection aren't elsewhere in the file, this won't compile. Even if it compiles, it's a second, raw-SQL way into the database that skips whatever the repository enforces, such as tenant or user scoping. If the repository scopes invoices per tenant or per user, this endpoint leaks invoices across that boundary.

## Checked and fine
Route ordering: `[HttpGet("search")]` won't be captured by `[HttpGet("{id}")]`, because attribute routing ranks literal segments above parameters.

**Bottom line:** #1 and #2 block the merge, so don't ship this as written.
