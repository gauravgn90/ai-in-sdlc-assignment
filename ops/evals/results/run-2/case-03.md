I found two defects in the diff. The working directory is empty, so I couldn't see the callers, the tests or the rest of the file. The findings are based only on the diff.

### 1. The discount is now cut short, so customers are overcharged by up to 1 cent. High confidence.
**File:** `backend/src/InvoiceApp.Domain/DiscountCalculator.cs`, new line 16 (the inner `Math.Round(discount, 2, MidpointRounding.ToZero)`)

The old code worked out the exact discounted price and rounded it to the nearest cent. The new code cuts the discount down to whole cents first and then subtracts it. For positive amounts, that always rounds the final price **up**, not to the nearest cent.

- `Apply(1.00m, 33.7m)`: the discount is 0.337.
  - Old: 1.00 − 0.337 = 0.663, which rounds to **0.66**.
  - New: the discount is cut to 0.33, so 1.00 − 0.33 = **0.67**.

Any discount with a non-zero third decimal place charges 1 cent more than the old code did. Exact half-cent cases give the same result in both versions: 0.505 gave 0.51 before and still does. So the bug only shows up when the third decimal isn't 5, which is easy to miss in tests that use round percentages. On an invoice system, this is a steady overcharge that adds up across line items. If the change was meant to "never over-discount", the result is a price rounded up, not rounded to the nearest cent. That is a business-rule change and needs to be explicit, not slipped in with a refactor.

### 2. The outer rounding now cuts the final amount instead of rounding it, so it pushes the other way. Medium confidence.
**File:** same file, new line 17 (`2, MidpointRounding.ToZero`)

When `amount` has at most 2 decimal places, the outer `Math.Round` does nothing, because amount minus a whole-cent discount is already whole cents. But if `amount` can have more than 2 decimals, for example unit price × quantity or prices to 4 decimal places, the result is now cut off rather than rounded:

- `Apply(19.999m, 0m)`: old **20.00**, new **19.99**.
- `Apply(10.005m, 0m)`: old **10.01**, new **10.00**.

So the inner rounding favours the seller and the outer rounding favours the customer. The overall result depends on how precise the input is. My confidence is medium only because I can't see whether `amount` is ever more precise than 2 decimal places.

### Checked and fine
- **Negative amounts (credit notes):** `ToZero` treats both signs the same way, so `Apply(-x, p) == -Apply(x, p)`. That held before the change too. A refund mirrors its invoice, nothing more.
- **`MidpointRounding.ToZero`:** it exists in .NET Core 3.0 and later, so the code compiles on any modern target.

**Suggested fix:** if nothing requires truncation, go back to the previous single rounding step. If a rule really does require rounding the discount down, document it and add tests with prices like `1.00m` at 33.7% and amounts with more than 2 decimals.
