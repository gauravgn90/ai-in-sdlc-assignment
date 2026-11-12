I found two defects and one possible defect in `backend/src/InvoiceApp.Domain/MonthEndReport.cs`. I reviewed the diff only: the working directory has no other source files, so I couldn't check `Invoice`, `IInvoiceRepository` or the callers.

### 1. The filter ignores the year, so other years' invoices get counted (line 18). Confidence: high

```csharp
&& invoice.DecidedAt.Value.Month == period.Month)
```

The code checks only the month number. `ApprovedTotal(new DateTime(2026, 11, 1))` adds up every approved invoice decided in any November: 2024, 2025, 2026 and so on. The month-end close total is too high once the system holds more than a year of data. This is easy to miss because tests usually seed only one year.

**Fix:** compare the year as well, or better, use a half-open date range:
```csharp
var start = new DateTime(period.Year, period.Month, 1);
var end = start.AddMonths(1);
... && invoice.DecidedAt.Value >= start && invoice.DecidedAt.Value < end
```

### 2. Every invoice is loaded into memory and filtered there (lines 15–19). Confidence: medium

`_invoices.GetAll()` loads the full invoice table on every call, and the filter and sum then run in memory. That cost grows with all invoices ever stored, not with one month's worth. The output is still correct, so this is a performance and scaling problem rather than a wrong-number bug. Whether it matters depends on `GetAll()`. If it returns a materialized list (likely, given the name), it's a real problem. If it returns an `IQueryable` that EF translates to SQL, it doesn't apply.

**Fix:** add a repository method that filters by status and date range in the query, such as `GetApproved(from, to)`.

### 3. Time zones may put invoices in the wrong month (line 18). Confidence: low to medium, depends on code I can't see

If `DecidedAt` is stored in UTC, which is common, and `period` is in local or business time, invoices decided near midnight at the turn of a month land in the wrong month. For example, an invoice approved at 23:30 local time on Oct 31 in UTC−5 is stored as Nov 1 04:30 UTC. It then counts toward November instead of October. If `DecidedAt` is a `DateTimeOffset`, `.Month` uses the stored offset, which may not be the business's time zone either. You need to decide which time zone defines the finance month and convert to it before comparing.

### Minor
- **No null check on the constructor argument (line 10).** A null `invoices` doesn't fail when the object is built; it fails later as a `NullReferenceException` inside `ApprovedTotal`. Consider `?? throw new ArgumentNullException(nameof(invoices))`.
- **Missing `using` lines (lines 15–19):** `Where` and `Sum` need `System.Linq`, and `DateTime` needs `System`. These compile only if implicit usings are turned on in the project, which is the default for SDK-style projects on .NET 6 and later, so I don't count this as a defect.

Issue #1 is the one to fix before merging: it gives the wrong total as soon as there's more than one year of data.
