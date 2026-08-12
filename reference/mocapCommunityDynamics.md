# Within vs Between Community Movement Synchrony

Computes displacement synchrony (correlation) between matched bones and
tests whether within-community pairs are more synchronized than
between-community pairs using a Wilcoxon test.

## Usage

``` r
mocapCommunityDynamics(
  pe_mocap,
  hg = NULL,
  gamma = 4.3,
  mapping = NULL,
  window_sec = NULL
)
```

## Arguments

- pe_mocap:

  A numeric matrix (frames x segments) with MoCap data.

- hg:

  An MSKHypergraph object (NULL loads default).

- gamma:

  Resolution parameter for community detection (default: 4.3).

- mapping:

  Optional data.frame from
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md).

- window_sec:

  Optional numeric, window size in seconds for time-resolved analysis
  (NULL for global analysis only).

## Value

A list with:

- within_community_sync:

  Mean within-community synchrony

- between_community_sync:

  Mean between-community synchrony

- ratio:

  Within/between ratio

- p_value:

  Wilcoxon test p-value

- time_resolved:

  Data frame with per-window results (if window_sec set)
