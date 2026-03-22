#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
git config core.hooksPath "$REPO_ROOT/.githooks"
printf "\033[1;32m✓ Git hooks configured from .githooks/\033[0m\n"
