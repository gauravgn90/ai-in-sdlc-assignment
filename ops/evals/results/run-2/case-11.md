I found one definite bug and two possible issues.

### 1. Filter ignores the year — **high confidence**
**File:** `backend/src/InvoiceApp.Domain/MonthEndReport.cs`, line 18

```csharp
&& invoice.DecidedAt.Value.Month == period.Month)
```

The filter checks only the month number. It never checks the year. Running the report for November 2026 also counts invoices approved in November 2025, November 2024, and so on. The total is too high whenever there is more than one year of data, so the month-end close figure will be wrong.

**Fix:**
```csharp
&& invoice.DecidedAt.Value.Year == period.Year
&& invoice.DecidedAt.Value.Month == period.Month
```
A cleaner option is a half-open range: `start = new DateTime(period.Year, period.Month, 1)`, `end = start.AddMonths(1)`, then `DecidedAt >= start && DecidedAt < end`.

### 2. Possible time-zone mismatch at the month boundary — **medium-low confidence**
**File:** same file, line 18

`DecidedAt` and `period` are compared without regard to `DateTimeKind`. If `DecidedAt` is stored in UTC but finance closes the month in local time (or the other way around), an invoice approved late on the 31st local time can land in the next month. The diff doesn't show how `DecidedAt` is stored, so I can't confirm this. Check it if the business has a defined close time zone.

### 3. Loads every invoice into memory — **medium confidence, depending on the repository**
**File:** same file, line 15

`_invoices.GetAll()` pulls back every invoice, and the filtering happens in memory. If `GetAll()` returns an `IEnumerable` from a database-backed repository, this does a full table load on every report run. That's a performance problem rather than a wrong answer, but it will get worse as invoice history grows. A repository method that filters by status and date range in the query would avoid it.

I didn't flag a missing `using System.Linq;`: projects on .NET 6 or later usually have implicit usings enabled. If this project doesn't, the file won't compile.
