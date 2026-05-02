#!/bin/bash
set -euo pipefail

(
    cd glot_frontend
    gleam build
    bun run build
)
