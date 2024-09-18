#!/bin/bash

# This script is used by GitHub actions to open a new modeling round.
# It should be run from the root of the repository.

set -euo pipefail

echo "===================="
echo "Creating clade list"
echo "===================="
uv run src/get_clades_to_model.py > /dev/stdout

echo "===================="
echo "Updating tasks.json"
echo "===================="
Rscript src/make_round_config.R > /dev/stdout
