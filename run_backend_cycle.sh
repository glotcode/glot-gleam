#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

./build_frontend.sh
./run_backend_env.sh
