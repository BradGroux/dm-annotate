#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/benchmark-statistics.sh"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dm-annotate-statistics-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

cat > "$WORK_DIR/even.tsv" <<'EOF'
10	100
20	200
30	300
40	400
EOF

[[ "$(benchmark_median "$WORK_DIR/even.tsv" 1 '%.2f')" == "25.00" ]]
[[ "$(benchmark_median "$WORK_DIR/even.tsv" 2 '%.0f')" == "250" ]]
[[ "$(benchmark_nearest_rank_percentile "$WORK_DIR/even.tsv" 1 95 '%.2f')" == "40.00" ]]

for value in $(seq 1 20); do
  printf '%s\t%s\n' "$value" "$((value * 10))" >> "$WORK_DIR/twenty.tsv"
done

[[ "$(benchmark_median "$WORK_DIR/twenty.tsv" 1 '%.2f')" == "10.50" ]]
[[ "$(benchmark_nearest_rank_percentile "$WORK_DIR/twenty.tsv" 1 95 '%.2f')" == "19.00" ]]
[[ "$(benchmark_nearest_rank_percentile "$WORK_DIR/twenty.tsv" 2 50 '%.0f')" == "100" ]]

head -5 "$WORK_DIR/twenty.tsv" > "$WORK_DIR/odd.tsv"
[[ "$(benchmark_median "$WORK_DIR/odd.tsv" 1 '%.2f')" == "3.00" ]]
[[ "$(benchmark_nearest_rank_percentile "$WORK_DIR/odd.tsv" 1 95 '%.2f')" == "5.00" ]]

echo "benchmark statistics tests OK"
