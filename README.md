# SeaweedFS Proof of Concept: Secure Object Storage

This repository contains an automated, containerized Proof of Concept (PoC) for a SeaweedFS object storage cluster. It is engineered with a focus on DevSecOps best practices, featuring strict network segregation (Zero Trust), immutable image digests, and an automated End-to-End (E2E) testing suite for high availability and network isolation.

## Prerequisites

To execute this PoC, ensure the following tools are installed on your host machine:

- **Docker** (v24.0+ recommended, I use 29.3.0)
- **Docker Compose** (v2.20+ recommended, I use v5.1.0)
- **GNU Make** (v4.0+ recommended, I use 4.4.1)
- _(Optional)_ `curl` and `jq` installed locally if you wish to query the APIs outside the provided Bastion container.

## Getting Started

The environment setup and tests are automated via `make`. To get started:

**1. Clone the repo**

**2. Initialize the env variables:**

```bash
cp .env.example .env
```

**3. Create SeaweedFS cluster**

```bash
make create
```

**4. Run the provided tests**

```bash
make test-volume-replication
```

```bash
make test-network-isolation
```

**5. Clean up**

```bash
make destroy
```
