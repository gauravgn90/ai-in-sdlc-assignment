I found one real defect and one smaller related problem. The working directory is empty, so I reviewed only the diff and couldn't see the DI registration or the hidden lines 13–15.

### 1. `Dictionary` replaces `ConcurrentDictionary` in a shared store (high confidence)
**File:** `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs`, line 9

An in-memory repository like this only keeps data between requests if it is registered as a singleton (`AddSingleton<IInvoiceRepository, InMemoryInvoiceRepository>()`). If it were scoped or transient, every request would start with an empty store. So one instance is almost certainly shared by every request, and ASP.NET Core runs requests on many threads at once. `Dictionary<TKey,TValue>` is not safe when one thread writes while others read or write:

- **Two writes at once** (two `Add`s, or `Add` plus `Update`) can corrupt the internal buckets when the dictionary resizes. You can get lost entries, `IndexOutOfRangeException`, or a thread stuck in an endless loop inside `TryGetValue` or `FindValue` with the CPU at 100%. That last one is a known failure mode of `Dictionary` used across threads, and it hangs the request for good.
- **A read during a write**: `GetById` running while `Add` or `Update` resizes the dictionary can throw or give a wrong result.

Load testing makes this show up; single-user manual testing usually won't.

**Fix:** Go back to `ConcurrentDictionary` and `TryAdd`. If there's a reason to want `Dictionary`, guard every access with a `lock`, including reads.

### 2. `Add` checks then writes in two separate steps (high confidence; follows from #1)
**File:** same file, lines 19–24

The old `TryAdd` checked and inserted in one atomic step. Now `ContainsKey` and the write through the indexer are separate. Two requests adding the same `invoice.Id` can both pass the check, and the second one silently overwrites the first instead of getting the "already exists" error. Using the indexer (`_invoices[id] = ...`) rather than `Add(id, ...)` also removes the last safeguard, because `Dictionary.Add` would at least throw on a duplicate key.

Even with a lock added, the check and the write need to be inside the same lock.

### Possible, but outside the visible lines (medium confidence)
Lines 13–15 aren't in the diff. If they contain something like `GetAll() => _invoices.Values` (or a LINQ query over it), that was safe before, because enumerating a `ConcurrentDictionary` never throws. With `Dictionary`, enumerating while another request calls `Add` or `Update` throws `InvalidOperationException: Collection was modified`. If the method returns the live `Values` collection without copying it, the caller can hit that exception later, while it serializes the response.

### Minor
`using System.Collections.Concurrent;` is probably unused now and will trigger a warning. It's not a defect.

**Bottom line:** this change makes the repository unsafe to use from more than one request at a time and gives no benefit in return. I'd reject it unless there's a reason for it that the diff doesn't show.
