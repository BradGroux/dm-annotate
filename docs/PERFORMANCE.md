# Performance checks

## Screenshot pipeline

Run the screenshot benchmark from the repository root:

```bash
scripts/benchmark-screenshot-png.sh
```

The default run compares five separate processes for a 6016×3384 image. It measures both the removed TIFF encoding round trip and a centered 1200×800 region pipeline. Peak RSS comes from `/usr/bin/time -l`; median and p95 are reported from the five samples. The benchmark compiles `ScreenshotPNGTransfer.swift`, so the direct cases exercise the production PNG encoder instead of a copied implementation. Its direct-region process conservatively retains the synthetic full source image; production region capture asks Core Graphics for only the selected display rect.

Reference result from 2026-07-14:

- Hardware: Apple M5 MacBook Air, 10 cores, 32 GB memory
- OS: macOS 26.5.1 (25F80)
- Toolchain: Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`)
- Direct PNG versus TIFF round trip: median 760.01 ms versus 790.81 ms; p95 888.74 ms versus 941.75 ms; median peak RSS 141,770,752 bytes versus 387,776,512 bytes
- Region-first rendering versus full-frame render then crop: median 39.36 ms versus 67.22 ms; p95 43.25 ms versus 84.32 ms; median peak RSS 92,274,688 bytes versus 173,752,320 bytes

Treat results as local diagnostic evidence, not exact cross-machine assertions. On comparable Apple silicon, investigate if the 1200×800 region case exceeds a 75 ms median or 100 ms p95, or if direct PNG peak RSS regresses above 200 MiB. On other hardware, compare before/after results on the same machine and investigate a regression greater than 15%. PNG encoding and file I/O must remain off the main actor regardless of absolute throughput so presentation input is not stalled.

The synthetic benchmark does not replace interactive checks. Before release, verify 1× and 2× full-display, region, and annotation-only screenshots for pixel dimensions, alpha, annotation alignment, chrome restoration, clipboard output, file output, and visible error handling.
