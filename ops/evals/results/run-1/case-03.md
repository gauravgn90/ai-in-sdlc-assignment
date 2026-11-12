I found two defects. The working directory is empty, so I reviewed the diff by itself and couldn't check callers, tests or the spec.

### 1. The discount is now truncated, so customers get charged up to 1¢ more
**File:** `backend/src/InvoiceApp.Domain/DiscountCalculator.cs`, line 16 (`Math.Round(discount, 2, MidpointRounding.ToZero)`)

**What goes wrong:** The discount is cut down to 2 decimals before it's subtracted. Any fractional cent of discount is dropped, never rounded up. The old code subtracted the exact discount and rounded once, half away from zero. So the new code charges up to 1¢ more whenever the discount's fractional cent is at or above half a cent.

- `Apply(10.05m, 15m)`: discount = 1.5075
  - Old: 10.05 − 1.5075 = 8.5425 → **8.54**
  - New: 10.05 − 1.50 = **8.55**
- `Apply(19.99m, 12.5m)`: discount = 2.49875
  - Old: 17.49125 → **17.49**
  - New: 19.99 − 2.49 = **17.50**

Every line item can drift this way, so invoice totals will differ from earlier results. Any tests or stored totals that assume the old rounding will break, and totals may no longer match other parts of the system that still round half away from zero.

**Confidence:** High that the behavior changed. Medium that it's a bug: it would be intentional only if the business explicitly wants discounts rounded down, and nothing in the diff says so.

### 2. The final total is now truncated instead of rounded
**File:** `backend/src/InvoiceApp.Domain/DiscountCalculator.cs`, line 17 (outer `MidpointRounding.ToZero`)

**What goes wrong:** `amount − discount` is truncated toward zero instead of rounded. When `amount` already has 2 decimals, this changes nothing. When `amount` has more than 2 (for example, computed from a 4-decimal unit price times a quantity), the result is always biased toward zero:
- `Apply(10.009m, 0m)`: old **10.01**, new **10.00**
- `Apply(10.019m, 10m)`: discount 1.0019 → 1.00. Old: 9.0171 → **9.02**. New: 9.019 → **9.01**

So even a 0% discount can change the amount. A function that applies no discount shouldn't change the price.

**Confidence:** High that the bias exists. Medium that it matters in practice, since that depends on whether callers ever pass amounts with more than 2 decimals, which I couldn't check.

### Not a defect
Rounding the discount first does guarantee that `discount + discounted == amount` for 2-decimal amounts. If that was the goal, keep the separate discount rounding but use `MidpointRounding.AwayFromZero` in both calls. That keeps the guarantee and matches the old rounding.

The PR should state which rounding rule is intended, and add tests for cases like `10.05 @ 15%` and `10.009 @ 0%`.
