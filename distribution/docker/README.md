# Dremio Docker Image
## Image Build

You can build this image by identifying a Dremio download tarball download URL and then running the following command:

``` bash
docker build --build-arg DOWNLOAD_URL=<URL> -t "dremio-oss:2.0.5" .
```

Note: This should work for both Community and Enterprise editions of Dremio.

---

## Single Node Deployment

```bash
docker run -p 9047:9047 -p 31010:31010 -p 32010:32010 -p 45678:45678 dremio/dremio-oss
```
This includes a single node deployment that starts up a single daemon that includes:
* Embedded Zookeeper
* Master Coordinator
* Executor

---

## Multi-node Deployment

Use containers in a Kubernetes environment to deploy multi-node Dremio. See the published [helm chart](https://github.com/dremio/dremio-cloud-tools/tree/master/charts/dremio) for instructions.

---

## Docker Compose Cluster Deployment

Spin up a local 4-node cluster (1 coordinator + 3 executors) using Docker Compose.
This is suitable for development and testing.

### Prerequisites

- Docker Engine 20.10+ with Compose V2 (`docker compose`)

### Steps

1. Copy `.env.example` to `.env` and set `DOWNLOAD_URL` to a Dremio OSS release tarball URL:

   ```bash
   cp .env.example .env
   # Edit .env and set DOWNLOAD_URL=<tarball URL>
   ```

2. Build the image:

   ```bash
   docker compose build
   ```

3. Start the cluster:

   ```bash
   docker compose up -d
   ```

   The coordinator starts first. The three executors wait until the coordinator is healthy
   before joining the cluster (up to ~5 minutes on first start).

4. Open the Web UI at **http://localhost:9047**

### Stopping and cleanup

```bash
# Stop all containers (preserves data volumes)
docker compose down

# Stop and remove all data volumes
docker compose down -v
```

### Cluster topology

| Service | Role | Ports (host) |
|---------|------|--------------|
| `coordinator` | Master coordinator + embedded ZooKeeper | 9047, 31010, 32010, 45678 |
| `executor-1` | Executor | — |
| `executor-2` | Executor | — |
| `executor-3` | Executor | — |

Node roles are configured via `cluster/coordinator/dremio.conf` and
`cluster/executor/dremio.conf` (shared by all three executors).

### Notes

- `paths.dist` uses a shared Docker named volume (`shared-dist`) mounted on all nodes
  at `/opt/dremio/dist`. This is a local `file://` path suitable for development only.
  For production, replace it with an object store URI (S3, ADLS, GCS) in both conf files.
- Only the coordinator's ports are published to the host.
