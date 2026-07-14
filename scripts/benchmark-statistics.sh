#!/usr/bin/env bash

benchmark_median() {
  local results_file="$1"
  local column="$2"
  local output_format="$3"
  local count
  count="$(awk 'NF { count += 1 } END { print count + 0 }' "$results_file")"
  ((count > 0))

  LC_ALL=C sort -n -k"${column},${column}" "$results_file" | awk \
    -v column="$column" \
    -v count="$count" \
    -v output_format="$output_format" '
      count % 2 == 1 && NR == (count + 1) / 2 {
        printf output_format "\n", $column
        exit
      }
      count % 2 == 0 && NR == count / 2 {
        lower = $column
      }
      count % 2 == 0 && NR == count / 2 + 1 {
        printf output_format "\n", (lower + $column) / 2
        exit
      }
    '
}

benchmark_nearest_rank_percentile() {
  local results_file="$1"
  local column="$2"
  local percentile="$3"
  local output_format="$4"
  local count
  count="$(awk 'NF { count += 1 } END { print count + 0 }' "$results_file")"
  ((count > 0))
  [[ "$percentile" =~ ^[0-9]+$ ]] && ((percentile >= 1 && percentile <= 100))
  local rank=$(((count * percentile + 99) / 100))

  LC_ALL=C sort -n -k"${column},${column}" "$results_file" | awk \
    -v column="$column" \
    -v rank="$rank" \
    -v output_format="$output_format" '
      NR == rank {
        printf output_format "\n", $column
        exit
      }
    '
}
