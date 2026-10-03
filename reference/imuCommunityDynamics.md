# IMU-based Community Dynamics

Analyzes movement synchrony from IMU sensors in the context of MSK
network communities. Computes within-community vs between-community
sensor synchrony and tests for significance.

## Usage

``` r
imuCommunityDynamics(
  imu_data,
  hg = NULL,
  gamma = 4.3,
  mapping = NULL,
  window_sec = NULL
)
```

## Arguments

- imu_data:

  Named list of per-sensor data (see `imuNetworkKinematics`).

- hg:

  An MSKHypergraph object (NULL loads default).

- gamma:

  Numeric, resolution parameter for community detection (default 4.3).

- mapping:

  Pre-computed mapping (optional).

- window_sec:

  Numeric or NULL. If provided, computes time-resolved synchrony in
  sliding windows of this duration (seconds). Requires `sampling_rate`
  attribute on sensor data.

## Value

A list with:

- within_community_sync:

  Mean synchrony within communities

- between_community_sync:

  Mean synchrony between communities

- ratio:

  Within/between ratio

- p_value:

  Wilcoxon test p-value

- time_resolved:

  Data frame if window_sec provided, NULL otherwise

## Examples

``` r
set.seed(1)
n <- 200
imu <- list(
  thigh  = matrix(rnorm(n * 3), n, 3),
  shank  = matrix(rnorm(n * 3), n, 3),
  foot   = matrix(rnorm(n * 3), n, 3),
  pelvis = matrix(rnorm(n * 3), n, 3))
res <- imuCommunityDynamics(imu)
res$ratio
#> [1] 2.746358
```
