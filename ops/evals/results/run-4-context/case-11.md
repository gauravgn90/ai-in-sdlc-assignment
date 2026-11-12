I found one real defect and one convention gap. The working directory only has `CLAUDE.md` (no `backend/` source), so I reviewed from the diff alone and couldn't check `Invoice`, `IInvoiceRepository` or how `DecidedAt` gets set.

### 1. The filter ignores the year, so totals include the same month from other years
**File:** `backend/src/InvoiceApp.Domain/MonthEndReport.cs`, line 18
**Confidence:** High

```csharp
&& invoice.DecidedAt.Value.Month == period.Month
```

The filter only compares the month number (1–12). Calling `ApprovedTotal(new DateTime(2026, 11, 1))` adds up invoices approved in November 2026, November 2025, November 2024 and so on. The figure is too high whenever the data covers more than 12 months, and nothing fails, so nobody notices. For a finance close report, that's a wrong number.

**Fix:** compare the year too:
```csharp
&& invoice.DecidedAt.Value.Year == period.Year
&& invoice.DecidedAt.Value.Month == period.Month
```
A half-open range (`>= monthStart && < monthStart.AddMonths(1)`) also works. Passing a year and month, or a `DateOnly`, would be clearer than a `DateTime` whose day and time get ignored.

### 2. No tests for the new rule
**File:** `backend/tests/InvoiceApp.Tests/MonthEndReportTests.cs` (missing from the diff)
**Confidence:** High that the diff has none

`CLAUDE.md` says "Every new rule or endpoint needs tests. Use `FakeInvoiceRepository`," with one test class per class under test. This diff adds a business rule without `MonthEndReportTests`. A test with two invoices approved in the same month of different years would have caught defect 1. Other cases to cover:
- Excluding invoices that aren't approved.
- Excluding invoices where `DecidedAt` is null.
- An empty repository returning 0.

### 3. Possible time-zone mismatch at month edges
**File:** `MonthEndReport.cs`, line 18
**Confidence:** Low (I couldn't check how `DecidedAt` is set)

If `DecidedAt` is stored in UTC (for example from `DateTime.UtcNow`) and callers pass a local-time `period`, an invoice approved late on the last day of the month locally can fall into the next month's total. It's worth checking how `ApprovalService` sets `DecidedAt` and writing down which time zone the month boundaries use.

Apart from these, the diff follows the layout rules: the logic sits in Domain and depends on the repository interface.
