The working directory is empty, so I reviewed only the diff. I couldn't check how the repository is registered with dependency injection or see the lines the diff hides.

## Findings

### 1. `Dictionary` is not thread-safe, but the repository is shared across requests
**File:** `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs`, line 9 (`private readonly Dictionary<string, Invoice> _invoices = new();`)

**What goes wrong:** An in-memory repository has to be registered as a singleton, or its data would vanish after every request. Kestrel handles requests at the same time on thread-pool threads, so `Add`, `Update` and `GetById` will run in parallel against one `Dictionary`. `Dictionary<TKey,TValue>` only allows parallel *reads*. A write that overlaps any other access can:
- corrupt the internal buckets, which in practice can leave a later `TryGetValue` or insert stuck in an infinite loop at 100% CPU (a well-known .NET failure);
- throw `IndexOutOfRangeException` or `InvalidOperationException` while the dictionary is resizing;
- lose writes without any error.

The old `ConcurrentDictionary` was there to prevent exactly this, so the change is a regression.

**Confidence:** High. The only exception would be a scoped or transient registration, and that would be its own bug because data wouldn't persist between requests.

### 2. `Add` checks and then writes, so duplicates aren't detected reliably
**File:** same file, lines 19–24 (`ContainsKey` followed by `_invoices[invoice.Id] = invoice`)

**What goes wrong:** `TryAdd` checked for the key and inserted in one atomic step. Now there are two separate steps. If two requests add the same `Id` at once, both pass the `ContainsKey` check, and the second indexer assignment overwrites the first invoice. Neither caller gets the "already exists" exception. Using the indexer for the write also hides the problem: `_invoices.Add(...)` would at least throw on a duplicate key.

**Confidence:** High, given concurrent access (see finding 1).

### 3. Listing invoices can fail while another request writes (likely, but those lines aren't shown)
**File:** same file, around lines 13–15 (the hidden part between the two hunks, probably something like `GetAll() => _invoices.Values...`)

**What goes wrong:** `ConcurrentDictionary` can be enumerated safely while other threads write to it. `Dictionary` can't: if an `Add` or `Update` happens while a list endpoint is reading the values, it throws `InvalidOperationException: Collection was modified`, which the client sees as a 500.

**Confidence:** Medium. It depends on that hidden code enumerating the dictionary, which is the usual pattern but I can't see it.

### Minor, not a defect
`using System.Collections.Concurrent;` is probably unused now. That only produces a warning, unless the build treats warnings as errors (IDE0005).

## Recommendation
Revert to `ConcurrentDictionary` and `TryAdd`. If the change was made for some other reason, such as needing a non-concurrent API, wrap every access in a single `lock` and have `Add` use `_invoices.Add`, or `TryAdd` inside the lock.
