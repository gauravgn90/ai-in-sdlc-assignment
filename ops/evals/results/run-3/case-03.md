I reviewed this from the diff alone. I couldn't open `DiscountCalculator.cs`, its callers or its tests, because the command to look for it needed approval and wasn't run. There are three findings.

### 1. The discount is now cut down instead of rounded, so totals can come out one cent higher
**File:** `backend/src/InvoiceApp.Domain/DiscountCalculator.cs`, line 16 (`Math.Round(discount, 2, MidpointRounding.ToZero)`)
**Confidence:** High that the behavior changed; medium that it's a bug, since this could be a deliberate business rule.

In .NET Core 3.0 and later, `MidpointRounding.ToZero` doesn't round to the nearest cent. Despite the name, it always drops the extra digits (like `Math.Truncate` to 2 places). So the discount is always cut down, never rounded up.

- `Apply(19.99m, 15m)`: the discount is 2.9985, which becomes 2.99, so the result is **17.00**. The old code gave **16.99**.
- `Apply(9.99m, 33.33m)`: the discount is 3.329667, which becomes 3.32, so the result is **6.67**. The old code gave **6.66**.

The customer gets up to a cent less discount, consistently in the merchant's favor. Calling the old and new code on many amounts would show changed results, and any existing tests with expected values like these would break. If the goal was "total = amount − displayed discount", the usual way is `Math.Round(discount, 2, MidpointRounding.AwayFromZero)`, which keeps rounding to the nearest cent.

### 2. The outer `ToZero` cuts down amounts that have more than 2 decimal places
**File:** same file, lines 16–17 (the outer `Math.Round(..., 2, MidpointRounding.ToZero)`)
**Confidence:** Medium. It only matters if `amount` can have more than 2 decimals, for example unit price × quantity, or a 4-decimal unit price.

When `amount` already has 2 decimals, the outer call changes nothing. When it has more, the result is cut down instead of rounded to the nearest cent:
- `Apply(10.999m, 0m)` now returns **10.99**. The old code returned **11.00**.
- `Apply(100.005m, 10m)`: the discount 10.0005 becomes 10.00, then 90.005 becomes **90.00**. The old code gave 90.0045, which rounds to **90.00**. These match, but other inputs won't.

Even with 0% discount, the result is no longer the amount rounded to the nearest cent. That's an unexpected effect of what looks like a change only to how the discount is handled.

### 3. Possible build failure if the Domain project targets an older framework
**File:** same file, lines 16–17
**Confidence:** Low. It depends on the `TargetFramework` setting in `InvoiceApp.Domain.csproj`, which I couldn't see.

`MidpointRounding.ToZero` only exists in .NET Core 3.0+ / .NET 5+. Domain libraries sometimes target `netstandard2.0` or .NET Framework so other projects can use them. If this one does, the change won't compile.

### Smaller point (not a defect)
For negative amounts such as credit notes, `ToZero` cuts down the size of the number, so −19.99 at 15% gives −17.00, the mirror of the positive case. That matches finding 1 and creates no extra inconsistency.

**Recommendation:** Unless the product deliberately wants "discounts are always cut down to the cent", keep `AwayFromZero` for both calls. If cutting down is intended, document it, check that every place that shows or stores the discount uses the same rule, and update or add tests for the examples above.
