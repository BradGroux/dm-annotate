#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/benchmark-statistics.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dm-annotate-png-benchmark.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

RUNS="${1:-5}"
WIDTH="${2:-6016}"
HEIGHT="${3:-3384}"
BINARY="$WORK_DIR/screenshot-png-benchmark"

xcrun swiftc -O \
  "$ROOT_DIR/Sources/DMAnnotate/ScreenshotPNGTransfer.swift" \
  "$ROOT_DIR/Benchmarks/ScreenshotPNGBenchmark.swift" \
  -o "$BINARY"

echo "Screenshot PNG benchmark: ${WIDTH}x${HEIGHT}, ${RUNS} separate processes per mode"
echo "toolchain: $(xcrun swift --version 2>&1 | head -1)"

for mode in legacy-tiff direct legacy-region direct-region; do
  results="$WORK_DIR/$mode.tsv"
  : > "$results"
  for run in $(seq 1 "$RUNS"); do
    timing="$WORK_DIR/$mode-$run.time"
    output="$(/usr/bin/time -l "$BINARY" "$mode" "$WIDTH" "$HEIGHT" 2> "$timing")"
    duration="$(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^duration_ms=/) { split($i, value, "="); print value[2] } }' <<< "$output")"
    rss_bytes="$(awk '/maximum resident set size/ { print $1 }' "$timing")"
    printf '%s\t%s\n' "$duration" "$rss_bytes" >> "$results"
    printf '%s run=%s duration_ms=%s peak_rss_bytes=%s\n' "$mode" "$run" "$duration" "$rss_bytes"
  done

  median_duration="$(benchmark_median "$results" 1 '%.2f')"
  p95_duration="$(benchmark_nearest_rank_percentile "$results" 1 95 '%.2f')"
  median_rss="$(benchmark_median "$results" 2 '%.0f')"
  max_rss="$(benchmark_nearest_rank_percentile "$results" 2 100 '%.0f')"
  printf '%s summary median_ms=%s p95_ms=%s median_peak_rss_bytes=%s max_peak_rss_bytes=%s\n' \
    "$mode" "$median_duration" "$p95_duration" "$median_rss" "$max_rss"
done
