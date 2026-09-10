# The architecture behind the SeaweedFS Object Storage PoC

_Note: It is recommended to open `diagram.svg` or `diagram.png` alongside this document to easily visualize the network boundaries and data flows._

### Core Architectural Decisions

##### Network Segregation

Three strictly isolated Docker networks (client-net, cluster-net, management-net) form a Zero Trust Model. The stateless S3 Gateway physically prevents external clients from routing to the internal control plane, minimizing the blast radius of a compromised endpoint.

##### Data Plane Cluster

Storage spans three independent volume nodes using a `002` replication strategy. This ensures data-layer HA, allowing the cluster to survive a node loss without dropping payloads (demonstrated via `test-volume-replication`).

##### Single Master and Filer Node

To keep the PoC lightweight, a single master and filer were deployed. To prevent metadata amnesia on restart, the Filer's LevelDB is mounted to a persistent volume, ensuring bucket states are permanently maintained.

##### Supply Chain Security & Bastion

Images are cryptographically pinned via SHA256 digests in `.env` to ensure reproducible builds and mitigate upstream tampering. A dedicated `netshoot` container (`admin-bastion`) handles internal debugging, preventing host port exposure.

### Trade-Offs

##### Single Points Of Failure (SPOF)

Lacking control plane redundancy, several critical SPOFs exist:

- **Master:** Lacks Raft consensus. A crash blocks new volume ID assignments, making the cluster read-only.
- **Filer:** A crash severs S3 path translations to raw chunks, breaking the API.
- **Gateway:** A crash results in total loss of client access.

##### Internal Authentication

Internal gRPC/HTTP traffic remains unauthenticated. The PoC prioritizes network routing boundaries and isolation over Layer 7 security.

##### Observability Void

The PoC operates as a black box. Lacking centralized logging or metrics scraping, component degradation or replication lag cannot be proactively detected.

### Path To Production

Elevating to production requires migrating to a declarative orchestration platform with centralized monitoring. All SPOFs must be eliminated via a multi-node Raft Master cluster and load-balanced S3 Gateways. Additionally, the local LevelDB must be replaced by a distributed database (e.g., Cassandra or Redis Cluster) for metadata HA, paired with a topology-aware `123` replication strategy (distributing replicas across data centers, racks, and servers) to maximize fault tolerance.
