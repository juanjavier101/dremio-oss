#!/usr/bin/env bash
#
# Copyright (C) 2017 Dremio Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# setup-host.sh — Prepare host directories for the Dremio production cluster.
#
# Creates the data directories mounted into each container and sets ownership
# to UID/GID 999 (the `dremio` system user inside the container).
#
# Usage:
#   sudo ./scripts/setup-host.sh [DATA_ROOT]
#
#   DATA_ROOT defaults to /opt/dremio/data — must match the DATA_ROOT in .env.
#
# Run once before the first `docker compose -f docker-compose.prod.yml up -d`.

set -euo pipefail

# UID/GID of the dremio user inside the container (see Dockerfile).
DREMIO_UID=999
DREMIO_GID=999

DATA_ROOT="${1:-/opt/dremio/data}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: this script must be run as root (use sudo)." >&2
  exit 1
fi

dirs=(
  "$DATA_ROOT/coordinator"
  "$DATA_ROOT/executor-1"
  "$DATA_ROOT/executor-2"
  "$DATA_ROOT/executor-3"
  "$DATA_ROOT/dist"
)

echo "Creating Dremio data directories under: $DATA_ROOT"
for d in "${dirs[@]}"; do
  mkdir -p "$d"
  chown "$DREMIO_UID:$DREMIO_GID" "$d"
  echo "  OK  $d"
done

echo ""
echo "Done. Start the cluster with:"
echo "  docker compose -f docker-compose.prod.yml up -d"
