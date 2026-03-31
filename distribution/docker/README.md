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

---

## Production Cluster Deployment (single VM)

Use `docker-compose.prod.yml` when running on an Ubuntu Server VM.
Key differences from the dev setup:

| | Dev (`docker-compose.yml`) | Prod (`docker-compose.prod.yml`) |
|---|---|---|
| Image | Built inline via `build:` | Pre-built, tagged, referenced by `image:` |
| Data storage | Docker-managed named volumes | Bind mounts to `/opt/dremio/data` on the host |
| Log rotation | None | json-file, 100 MB × 5 files per container |
| Auto-restart | No | `unless-stopped` (survives VM reboot) |
| File descriptors | Default | Hard limit 65536 (`ulimits.nofile`) |
| Memory tuning | Auto-detected | Explicit via env vars in `.env` |

### Prerequisites

- Docker Engine 20.10+ with Compose V2
- `sudo` access to create host directories

### Steps

**1. Build the image once**

```bash
# In distribution/docker/
cp .env.example .env
# Edit .env: set DOWNLOAD_URL to a Dremio OSS tarball URL
docker build --build-arg DOWNLOAD_URL=$(grep DOWNLOAD_URL .env | cut -d= -f2) \
  -t dremio-oss:local .
```

**2. Prepare host data directories**

```bash
sudo ./scripts/setup-host.sh
# Creates /opt/dremio/data/{coordinator,executor-1,executor-2,executor-3,dist}
# with ownership set to the dremio container user (UID 999).
```

To use a different root path, pass it as an argument and set `DATA_ROOT` in `.env`:

```bash
sudo ./scripts/setup-host.sh /data/dremio
# Then add DATA_ROOT=/data/dremio to .env
```

**3. Tune memory in `.env`**

Edit `.env` and adjust the memory variables to fit your VM's RAM.
As a starting point, the defaults reserve ~12 GB for the coordinator and ~12 GB per executor.
Leave at least 2 GB headroom for the OS.

| Variable | Default | Purpose |
|---|---|---|
| `COORDINATOR_HEAP_MB` | 8192 | Coordinator JVM heap |
| `COORDINATOR_DIRECT_MB` | 4096 | Coordinator off-heap (direct) |
| `EXECUTOR_HEAP_MB` | 4096 | Executor JVM heap (per node) |
| `EXECUTOR_DIRECT_MB` | 8192 | Executor off-heap (per node) |

**4. Start the cluster**

```bash
docker compose -f docker-compose.prod.yml up -d
```

The coordinator starts first and initialises the embedded ZooKeeper.
The three executors start once the coordinator passes its health check (up to ~2 minutes).

**5. Verify**

```bash
# Container status
docker compose -f docker-compose.prod.yml ps

# Coordinator logs
docker logs -f dremio-coordinator

# Open the Web UI
# http://<vm-ip>:9047
```

### Stopping and cleanup

```bash
# Stop containers (data on host is preserved)
docker compose -f docker-compose.prod.yml down

# Restart a single node without stopping others
docker restart dremio-executor-2
```

### Backups

Because data lives on the host under `DATA_ROOT`, back up with standard tools:

```bash
# Example: snapshot coordinator data (catalog, ZooKeeper state)
sudo tar -czf dremio-coordinator-$(date +%F).tar.gz /opt/dremio/data/coordinator
```

### Firewall

Restrict external access on the coordinator's published ports using `ufw`:

```bash
# Allow only trusted IPs to reach the Web UI and client endpoints
sudo ufw allow from <trusted-ip> to any port 9047
sudo ufw allow from <trusted-ip> to any port 31010
sudo ufw allow from <trusted-ip> to any port 32010
# Fabric RPC (45678) should not be exposed externally
sudo ufw deny 45678
```

