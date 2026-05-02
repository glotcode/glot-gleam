#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

exec watchexec \
  --restart \
  --stop-signal SIGTERM \
  --stop-timeout 35s \
  --watch glot_backend/src \
  --watch glot_core/src \
  --watch glot_backend/gleam.toml \
  --watch glot_core/gleam.toml \
  --exts gleam,toml \
  -- ./run_backend_cycle.sh
