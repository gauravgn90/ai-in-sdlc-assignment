I found one definite defect and one possible one. A couple of lower-confidence concerns follow.

### 1. The year is never checked, so months from different years are added together
**File:** `backend/src/InvoiceApp.Domain/MonthEndReport.cs`, line 18
**Confidence:** High

```csharp
&& invoice.DecidedAt.Value.Month == period.Month
```

The filter only compares the month number. For `period = 2026-10-01`, the total includes invoices approved in October 2026, October 2025, October 2024, and every other October. The month-end close total grows wrong each year and is already wrong once there is more than a year of data. This won't throw an error, so it's easy to miss in finance numbers.

**Fix:** also compare the year, or better, use a half-open range:
```csharp
var start = new DateTime(period.Year, period.Month, 1);
var end = start.AddMonths(1);
... && invoice.DecidedAt.Value >= start && invoice.DecidedAt.Value < end
```

### 2. Time-zone and `DateTimeKind` mismatches at month boundaries
**File:** same file, lines 13 and 18
**Confidence:** Medium. It depends on how `DecidedAt` is stored, which the diff doesn't show.

If `DecidedAt` is stored in UTC but `period` (or the business's idea of the month) is local time, an approval at 23:30 local time on 31 October can have a UTC timestamp in November and land in the wrong month's report. Nothing in the method normalizes the two values or states which kind it expects. Check the time zone the finance close is defined in and convert `DecidedAt` to it before comparing.

### Lower-confidence concerns

- **Line 16, the filter uses the current status:** `invoice.Status == InvoiceStatus.Approved` checks the invoice's status now, not its status at month end. If invoices can move on from `Approved` (for example to `Paid` or `Archived`), they drop out of earlier months' totals and a past report can't be reproduced. I'd put this at low-to-medium confidence because it depends on your status lifecycle. If statuses after `Approved` exist, this is a real bug.
- **Line 15, all invoices are loaded:** if `GetAll()` returns `IEnumerable<T>` and not `IQueryable<T>`, every invoice is pulled into memory and filtered there. That's a performance problem rather than a wrong result, but it grows with the size of the invoice table.

Nothing else stood out. `Sum` over an empty set returns `0m` correctly, and the `HasValue` guard prevents a null dereference.
