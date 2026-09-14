import Foundation
@testable import ShelfCore

struct QuestionQualityFixture {
    let domain: String
    let source: String
    let meaningful: String
    let incidental: [String]
    let allowedIntents: Set<QuestionIntent>
    let invalidProperties = ["unresolved reference", "answer leakage", "malformed subject article", "template artifact", "mixed predicate", "incidental concept"]
}

enum QuestionQualityCorpus {
    // Explicit source facts are evaluation data, never a production technology dictionary.
    // domain | sentence | teaching concept | incidental object nouns | allowed intent
    static let fixtures: [QuestionQualityFixture] = rows.split(separator: "\n").map { row in
        let f = row.components(separatedBy: "|")
        precondition(f.count == 5)
        return QuestionQualityFixture(domain: f[0], source: f[1], meaningful: f[2],
            incidental: f[3].components(separatedBy: ","), allowedIntents: Set(f[4].split(separator: ",").compactMap { QuestionIntent(rawValue: String($0)) }))
    }
    static let rows = """
JavaScript|A closure is a function together with its lexical environment.|closure|function,environment|define
JavaScript|A promise represents an eventual asynchronous result.|promise|result|define
JavaScript|A microtask runs after the current script completes.|microtask|script|sequence
JavaScript|Event delegation depends on propagation through ancestor elements.|Event delegation|elements|prerequisite
JavaScript|Strict equality prevents implicit type conversion.|Strict equality|conversion|constraint
JavaScript|Memoization works by storing results under their input keys.|Memoization|keys|mechanism
JavaScript|An iterator returns successive values from a collection.|iterator|collection|mechanism
TypeScript|A union type represents a value belonging to one of several types.|union type|value|define
TypeScript|Type narrowing works by refining a value type after a guard.|Type narrowing|guard|mechanism
TypeScript|A generic parameter allows reuse across multiple input types.|generic parameter|input|consequence
TypeScript|A readonly property prevents reassignment through a typed reference.|readonly property|reference|constraint
TypeScript|An exhaustive switch requires a branch for every variant.|exhaustive switch|branch|prerequisite
TypeScript|A type predicate enables narrowing by reporting a runtime check result.|type predicate|result|mechanism
TypeScript|A discriminated union depends on a shared literal tag.|discriminated union|tag|prerequisite
React|React effects rerun when a dependency changes identity.|React effects|dependency|debugging
React|Reconciliation is the process of comparing interface descriptions to choose updates.|Reconciliation|descriptions|define
React|useMemo memoizes a calculated value between renders.|useMemo|value|mechanism
React|useCallback memoizes a function definition between renders.|useCallback|function|mechanism
React|An effect cleanup prevents a lingering subscription after unmount.|effect cleanup|subscription|constraint
React|A stable key enables matching by preserving an item identity between renders.|stable key|item|mechanism
React|A render loop happens when an effect updates a dependency on every render.|render loop|dependency|cause
HTTP|An ETag represents a version identifier for a representation.|ETag|representation|define
HTTP|HTTP caching reduces origin requests by reusing fresh responses.|HTTP caching|responses|mechanism
HTTP|A conditional request avoids a full response body by sending a validator.|conditional request|body|mechanism
HTTP|A preflight request runs before the cross-origin request is sent.|preflight request|request|sequence
HTTP|Content negotiation depends on the requested representation preferences.|Content negotiation|preferences|prerequisite
HTTP|An idempotent method guarantees the same intended effect when the request is repeated.|idempotent method|request|constraint
HTTP|A redirect results in a request to a different location.|redirect|location|consequence
Browser internals|The DOM is a tree representation of a document.|DOM|document|define
Browser internals|Layout is the calculation of element sizes and positions.|Layout|positions|define
Browser internals|Style invalidation causes recalculation of affected element styles.|Style invalidation|elements|consequence
Browser internals|A repaint happens when visible pixels need updating.|repaint|pixels|cause
Browser internals|Compositing works by combining already painted layers.|Compositing|layers|mechanism
Browser internals|A layout query causes synchronous layout after a style change.|layout query|style|consequence
Browser internals|A script task runs before the next microtask checkpoint.|script task|checkpoint|sequence
Node|The event loop is a coordinator for asynchronous callbacks.|event loop|callbacks|define
Node|A worker thread enables parallel execution of CPU work.|worker thread|work|consequence
Node|Backpressure prevents an unbounded buffer by slowing the producer.|Backpressure|buffer|mechanism
Node|An unhandled error causes termination of the current process.|unhandled error|process|consequence
Node|A stream pipeline works by connecting producers to consumers.|stream pipeline|consumers|mechanism
Node|A retry loop retries when a request times out.|retry loop|request|debugging
Node|A graceful shutdown requires completion of active requests.|graceful shutdown|requests|prerequisite
Networking|TCP is a reliable ordered byte stream transport.|TCP|stream|define
Networking|DNS works by resolving host names through a hierarchy of servers.|DNS|servers|mechanism
Networking|A retransmission happens when a sender detects missing delivery.|retransmission|sender|cause
Networking|Flow control prevents a sender from overwhelming a receiver.|Flow control|receiver|constraint
Networking|Congestion control reduces traffic because overloaded paths drop packets.|Congestion control|packets|cause
Networking|A TLS handshake runs before application data is exchanged.|TLS handshake|data|sequence
Networking|A connection timeout causes the waiting operation to fail.|connection timeout|operation|consequence
SQL|An index prevents a full table scan on the filtered column.|index|column|constraint
SQL|A join is a combination of rows from related tables.|join|rows|define
SQL|A foreign key requires a matching referenced row.|foreign key|row|prerequisite
SQL|A unique constraint prevents duplicate values in the constrained key.|unique constraint|key|constraint
SQL|A query plan is an ordered strategy for executing a query.|query plan|strategy|define
SQL|Prepared statements prevent SQL injection through parameterization.|Prepared statements|parameterization|mechanism
SQL|A covering index avoids a table lookup by containing every required column.|covering index|column|mechanism
Databases|A transaction is a unit of work committed atomically.|transaction|work|define
Databases|A deadlock happens when two transactions each wait for a lock held by the other.|deadlock|lock|cause
Databases|Write-ahead logging enables recovery by recording changes before data pages are written.|Write-ahead logging|pages|mechanism
Databases|Snapshot isolation depends on a consistent read view.|Snapshot isolation|view|prerequisite
Databases|An exclusive lock prevents conflicting access to a resource.|exclusive lock|resource|constraint
Databases|Indexes accelerate reads but add maintenance work during writes.|Indexes|reads,writes|application
Databases|A checkpoint reduces recovery time by recording a durable restart position.|checkpoint|position|mechanism
Security|Unlike authentication, authorization determines what an identity may access.|authorization|identity|distinguish
Security|A password hash protects against password disclosure by storing a one-way digest.|password hash|digest|mechanism
Security|Input validation prevents malformed values from entering a trusted operation.|Input validation|values|constraint
Security|Least privilege reduces exposure by limiting granted permissions.|Least privilege|permissions|mechanism
Security|An authentication check requires proof of identity.|authentication check|identity|prerequisite
Security|A nonce prevents replay by identifying a single use.|nonce|use|mechanism
Security|Encryption guarantees confidentiality when the key remains secret.|Encryption|key|constraint
Algorithms|Binary search requires the input array to be sorted.|Binary search|array|prerequisite
Algorithms|A loop invariant is a condition preserved by every iteration.|loop invariant|iteration|define
Algorithms|Memoized recursion avoids repeated work by storing solved subproblems.|Memoized recursion|subproblems|mechanism
Algorithms|A greedy choice requires a locally optimal step to preserve an optimal solution.|greedy choice|step|prerequisite
Algorithms|Partitioning works by separating values around a chosen pivot.|Partitioning|pivot|mechanism
Algorithms|Cycle detection prevents traversal from revisiting nodes indefinitely.|Cycle detection|nodes|constraint
Algorithms|Binary search: first inspect the midpoint, then retain the half containing the target.|Binary search|midpoint|reconstruction
Data structures|A stack is a last-in-first-out collection.|stack|collection|define
Data structures|A queue is a first-in-first-out collection.|queue|collection|define
Data structures|A hash table works by mapping keys into buckets.|hash table|buckets|mechanism
Data structures|A balanced tree guarantees logarithmic height when balance invariants hold.|balanced tree|height|constraint
Data structures|A linked list allows insertion without shifting adjacent elements.|linked list|elements|consequence
Data structures|A heap requires each parent to satisfy the ordering rule.|heap|parent|prerequisite
Data structures|A bloom filter avoids unnecessary lookups by rejecting definite nonmembers.|bloom filter|lookups|mechanism
System design|A load balancer works by distributing requests among healthy servers.|load balancer|servers|mechanism
System design|A circuit breaker prevents repeated calls to a failing dependency.|circuit breaker|calls|constraint
System design|Horizontal scaling enables increased capacity by adding service instances.|Horizontal scaling|instances|mechanism
System design|A bulkhead reduces failure propagation by isolating resource pools.|bulkhead|pools|mechanism
System design|A health check is a probe of service readiness.|health check|probe|define
System design|A retry budget prevents runaway retry traffic.|retry budget|traffic|constraint
System design|A deployment rollback requires a previously deployable version.|deployment rollback|version|prerequisite
Caching|A cache accelerates reads but consumes memory for saved entries.|cache|entries|application
Caching|Cache invalidation prevents reuse of a stale entry.|Cache invalidation|entry|constraint
Caching|A cache stampede happens when many clients regenerate the same expired value.|cache stampede|clients|cause
Caching|Request coalescing reduces duplicate work by sharing an in-flight computation.|Request coalescing|computation|mechanism
Caching|A freshness check depends on the age and lifetime of a response.|freshness check|response|prerequisite
Caching|A write-through cache improves consistency by updating storage before acknowledging a write.|write-through cache|storage|mechanism
Caching|A cache key requires every input that affects the stored result.|cache key|input|prerequisite
Distributed systems|A quorum requires agreement from a threshold of replicas.|quorum|replicas|prerequisite
Distributed systems|Leader election is the selection of a coordinator among participants.|Leader election|participants|define
Distributed systems|A network partition prevents communication between groups of nodes.|network partition|nodes|constraint
Distributed systems|Replication improves availability but adds coordination work during updates.|Replication|updates|application
Distributed systems|A fencing token prevents stale owners from performing writes.|fencing token|owners|constraint
Distributed systems|Distributed caching reduces origin load by serving shared cached responses.|Distributed caching|responses|mechanism
Distributed systems|A lease expires when its deadline passes.|lease|deadline|debugging
APIs|An idempotency key prevents duplicate effects by identifying repeated operations.|idempotency key|operations|mechanism
APIs|Pagination reduces response size by returning a bounded subset.|Pagination|subset|mechanism
APIs|A cursor represents a position in an ordered result set.|cursor|position|define
APIs|An API version allows independent evolution of a published contract.|API version|contract|consequence
APIs|Rate limiting prevents overload by bounding accepted requests.|Rate limiting|requests|mechanism
APIs|A schema validation error causes rejection before the handler runs.|schema validation error|handler|consequence
APIs|A webhook requires a reachable callback endpoint.|webhook|endpoint|prerequisite
"""
}
