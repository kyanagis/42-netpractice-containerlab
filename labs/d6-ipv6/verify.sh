#!/usr/bin/env bash
# ipv6 の検証(v6到達性。初回NDP分 -c2)。containerlab: https://containerlab.dev/
set -euo pipefail
LAB=ipv6
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_verify_lib.sh"
CHECKS=(
  "1|h1->r(near v6)|h1|ping -6 -c2 -W2 2001:db8:1::1"
  "2|h1->h2 (ルータ越えv6)|h1|ping -6 -c2 -W2 2001:db8:2::10"
  "3|h2->h1 (復路v6)|h2|ping -6 -c2 -W2 2001:db8:1::10"
)
run_checks
