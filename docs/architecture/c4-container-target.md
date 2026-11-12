# C4 container diagram: target state (Azure SQL + PayEx)

**This is a plan, not a description of the running system.** For what exists today, see [c4-container.md](c4-container.md).

![Target-state container diagram](c4-container-target.png)

**Legend**

| Style | Meaning |
|---|---|
| Solid blue | Built today. Same as the as-built diagram |
| Solid blue with **orange border** | Built today, but must change or be replaced before the target state works |
| **Dashed red border, `[NOT BUILT]`** | Does not exist in the code |
| Dashed grey border | External system with no integration yet |
| Dotted arrow | The relationship doesn't exist yet |

Rendered with the Mermaid MCP server.

```mermaid
flowchart TB
    approver["<b>Approver</b><br/>[Person]"]
    admin["<b>Admin</b><br/>[Person]"]

    lb["<b>Load balancer</b><br/>[NOT BUILT]<br/>fronts 3 API instances"]

    subgraph app["Invoice Approval Service: target state"]
        direction TB
        webui["<b>Web UI</b><br/>[BUILT: HTML, CSS, JS]<br/>wwwroot/"]
        api["<b>InvoiceApp.Api x3</b><br/>[BUILT: ASP.NET Core 8]<br/>Controllers, SessionAuthMiddleware, RequireRole"]
        domain["<b>InvoiceApp.Domain</b><br/>[BUILT: class library]<br/>ApprovalService, IInvoiceRepository"]
        sessions["<b>SessionStore</b><br/>[BUILT, MUST CHANGE]<br/>in-memory, per instance:<br/>breaks behind a load balancer"]
        sqlrepo["<b>SqlInvoiceRepository</b><br/>[NOT BUILT]<br/>implements IInvoiceRepository"]
        payport["<b>IPaymentGateway + PayExClient</b><br/>[NOT BUILT]<br/>HttpClient, timeout, retry"]
        publisher["<b>EventPublisher</b><br/>[NOT BUILT]<br/>invoice events"]
        memrepo[("<b>InMemoryInvoiceRepository</b><br/>[BUILT, REPLACED]<br/>kept for dev and tests")]
    end

    sql[("<b>Azure SQL Database</b><br/>[NOT BUILT]<br/>Invoices")]
    payex["<b>PayEx</b><br/>[External system, NOT INTEGRATED]<br/>payment provider, HTTPS"]
    topic[["<b>Azure Service Bus</b><br/>[NOT BUILT]<br/>topic invoice-events"]]

    subgraph subs["Downstream subscribers: NOT BUILT"]
        direction LR
        notify["<b>notification-worker</b><br/>[NOT BUILT]<br/>emails on approval"]
        audit["<b>audit-archive</b><br/>[NOT BUILT]"]
        analytics["<b>analytics-export</b><br/>[NOT BUILT]"]
    end

    approver -->|"HTTPS"| lb
    admin -->|"HTTPS"| lb
    lb -.->|"routes to"| api
    api -->|"serves"| webui
    webui -->|"fetch /api/*, Bearer"| api
    api -->|"validate token"| sessions
    api -->|"Submit, Approve, Reject"| domain
    domain -.->|"IInvoiceRepository"| sqlrepo
    domain -.->|"approve: submit payment"| payport
    domain -.->|"invoice.approved etc."| publisher
    domain -.->|"today only"| memrepo
    sqlrepo -.->|"EF Core or ADO.NET, TDS"| sql
    payport -.->|"HTTPS, JSON"| payex
    publisher -.->|"AMQP"| topic
    topic -.-> notify
    topic -.-> audit
    topic -.-> analytics

    classDef person fill:#08427b,stroke:#052e56,color:#fff
    classDef built fill:#1168bd,stroke:#0b4884,color:#fff
    classDef change fill:#1168bd,stroke:#f0a30a,stroke-width:4px,color:#fff
    classDef notbuilt fill:#ffffff,stroke:#c0392b,stroke-width:2px,stroke-dasharray: 6 4,color:#333
    classDef external fill:#ffffff,stroke:#6b6b6b,stroke-width:2px,stroke-dasharray: 6 4,color:#333
    class approver,admin person
    class webui,api,domain built
    class sessions,memrepo change
    class lb,sqlrepo,payport,publisher,sql,topic,notify,audit,analytics notbuilt
    class payex external
    style app fill:none,stroke:#444,stroke-dasharray: 5 5
    style subs fill:none,stroke:#c0392b,stroke-dasharray: 5 5
```

## Where each element comes from

Built elements are cited from the code, the same as in [c4-container.md](c4-container.md). Planned elements are cited from `ops/`. Under AGENTS.md, that folder describes the planned production deployment and not current behaviour, which is exactly why it's the right source for a target state.

| Element | Status | Source |
|---|---|---|
| Web UI, InvoiceApp.Api, InvoiceApp.Domain | Built | `backend/src/InvoiceApp.Api/`, `backend/src/InvoiceApp.Domain/` (see as-built doc) |
| SessionStore | Built, must change | `Auth/SessionStore.cs` holds sessions in a `ConcurrentDictionary`, registered as a singleton at `Program.cs:13`. Must change because of the three-instance row below |
| InMemoryInvoiceRepository | Built, to be replaced | `InMemoryInvoiceRepository.cs`, `Program.cs:14` |
| Three API instances behind a load balancer | Not built | `ops/incidents/INC-2041/README.md:32` |
| Azure SQL Database | Not built | **Your request.** `ops/README.md:17` only says "a database" and names no product |
| SqlInvoiceRepository | Not built | Name inferred. AGENTS.md rule: "Repositories are interfaces in Domain with an in-memory implementation in Api"; the interface is `IInvoiceRepository.cs` |
| PayEx (external) | Not integrated | `ops/README.md:17-18`, `ops/incidents/INC-2041/README.md:30-31` ("calls it over HTTPS") |
| PayExClient: HttpClient, timeout, retry | Not built | `ops/incidents/INC-2041/deploy-diff.patch:114-117` (typed `AddHttpClient<IPayExClient, PayExClient>`, base URL, 10 s timeout: the pre-2.14.0 registration, which that diff *removes*), `:136` (config), `ops/incidents/INC-2047/recent-changes.md:7` (retry policy) |
| Azure Service Bus topic `invoice-events` | Not built | `ops/incidents/INC-2047/servicebus-status.txt:5` (`az servicebus topic show … sb-invoice-prod --name invoice-events`) |
| EventPublisher | Not built | `ops/incidents/INC-2047/publisher-logs.txt:2` (`Component: EventPublisher`) |
| Event names `invoice.approved` | Not built | `ops/incidents/INC-2047/recent-changes.md:15,24`, `servicebus-status.txt:59` |
| notification-worker, analytics-export, audit-archive | Not built | `ops/incidents/INC-2047/servicebus-status.txt:12-17` (subscription list), `worker-logs.txt:2,6` |

## Inferred, with no direct citation

- **PayEx goes behind a Domain port (`IPaymentGateway`), not in the controller.** The `ops` diff calls `_payEx.SubmitAsync` from `ApprovalsController.Approve` (`deploy-diff.patch:85`). AGENTS.md forbids business logic in controllers, so I drew a Domain interface with the PayEx adapter in Api, the same pattern as `IInvoiceRepository`. The interface name is mine.
- **The order of approve, pay and publish isn't decided.** The `ops` diff saves the approval first and then calls PayEx synchronously (`deploy-diff.patch:84-85`), and INC-2041 is "approvals slow and failing" after that change. Whether payment is sync or async, and whether to use an outbox so that saving to the database and publishing to the topic either both happen or neither does, are open decisions. The diagram doesn't settle them.
- **Sessions must be shared or stateless.** With three instances, a token issued by one instance is unknown to the others. That follows from `SessionStore` being an in-memory singleton combined with INC-2041:32. The fix isn't chosen: Redis, SQL, signed JWTs, or sticky sessions.
- **Demo users in `appsettings.json` would also need replacing** for production, with real identity and secrets. Not drawn, because `ops/` doesn't name a provider.
- **A secrets store (e.g. Key Vault) for the PayEx key and the SQL connection.** Implied by "Rotated the PayEx API key" (`recent-changes.md:33`), but no store is named, so it isn't drawn.
- **Data access technology:** "EF Core or ADO.NET" is a placeholder; nothing chooses it.
- **The legacy notification endpoint** (`deploy-diff.patch:135`, `Notifications.LegacyEndpoint`) is left out because its role relative to the worker is unclear.
- **Incident details aren't architecture.** Everything in `ops/` is invented scenario data (`ops/README.md:22-23`). Instance counts, host names and subscriber names show intent, not a confirmed design.
