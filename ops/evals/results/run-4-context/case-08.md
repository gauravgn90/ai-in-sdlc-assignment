I found two defects in this diff, and they share one root cause. I couldn't check them against the code itself: the working directory only has `CLAUDE.md`, and `backend/` isn't there. So everything below comes from the diff alone.

**1. `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs`, line 9: a plain `Dictionary` is now shared across concurrent requests**

- **What goes wrong:** An in-memory repository only keeps its data between requests if it's registered as a singleton in `Program.cs`. That means one instance serves every request, and ASP.NET Core runs requests in parallel. `Dictionary<TKey,TValue>` is not safe when another thread writes to it while it is being read or written (`Add`, `Update` or the indexer). Under concurrent load this can:
  - corrupt the dictionary's internal storage, so entries are silently lost or `GetById` returns null for invoices that exist;
  - throw `InvalidOperationException` ("Operations that change non-concurrent collections must have exclusive access…");
  - in the worst case, leave a thread spinning in a corrupted bucket chain.
- **Collateral damage:** Any method that loops over `_invoices` (probably the list method on the lines the diff doesn't show) can throw "Collection was modified" if an `Add` lands mid-loop. `ConcurrentDictionary` never throws there.
- **Confidence:** High that this is a real defect. Medium on whether it's reachable today, because I couldn't see that `Program.cs` registers the repository as a singleton (it almost has to, for data to persist).

**2. Same file, lines 19–24 (`Add`): the duplicate-ID check is no longer atomic**

- **What goes wrong:** `TryAdd` checked for the ID and inserted in one atomic step. The new code calls `ContainsKey` and then assigns with `_invoices[invoice.Id] = invoice`. If two requests add the same ID at the same time, both can pass `ContainsKey`. The second assignment then silently overwrites the first invoice instead of throwing "already exists". The duplicate guard fails exactly when it's needed, and the first caller gets a success response for an invoice that no longer exists.
- **Also:** The indexer assignment is itself an upsert, so even without a race the code no longer says "insert only".
- **Confidence:** High that the race exists. How likely it is in practice depends on where IDs come from: client-supplied or sequential IDs make it likely, server-generated GUIDs make collisions rare. Finding 1 still applies either way.

**Fix:** Revert to `ConcurrentDictionary` with `TryAdd`. If a plain `Dictionary` is needed for some reason, wrap every read, write and enumeration in a single `lock`.

**Tests:** Existing tests are unlikely to catch either problem, because they use `FakeInvoiceRepository` and run on a single thread. The diff also doesn't touch the hidden lines 10–15, which is where I'd look for the enumeration issue in finding 1.
