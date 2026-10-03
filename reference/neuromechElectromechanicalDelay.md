# Electromechanical Delay via Cross-Correlation

Computes the electromechanical delay (EMD) between EMG and kinematic
signals for muscle-bone pairs connected in the MSK hypergraph.
Optionally correlates EMD with MSK network distance.

## Usage

``` r
neuromechElectromechanicalDelay(
  emg,
  kinematics,
  hg = NULL,
  emg_mapping = NULL,
  kin_mapping = NULL,
  sr = NULL,
  max_lag_ms = 200,
  window_sec = NULL,
  n_perm = 999L
)
```

## Arguments

- emg:

  EMG data: SummarizedExperiment, matrix (time x channels), or vector.

- kinematics:

  Kinematic data: matrix (time x segments) or SummarizedExperiment.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- kin_mapping:

  Optional pre-computed data.frame from
  [`mocapToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mocapToMSKMapping.md)
  or
  [`imuToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/imuToMSKMapping.md).

- sr:

  Optional sampling rate (overrides detected value).

- max_lag_ms:

  Numeric, maximum lag in milliseconds (default: 200).

- window_sec:

  Optional numeric, window size in seconds for sliding window EMD
  analysis (NULL for global only).

- n_perm:

  Integer, number of permutations for correlation test (default: 999).

## Value

A list with:

- emd:

  Data.frame with muscle, bone, emd_ms, peak_correlation per pair

- network_distance:

  Corresponding MSK shortest path distance

- correlation:

  Pearson correlation between EMD and network distance

- p_value:

  Permutation p-value for the correlation

- time_varying:

  Data.frame with per-window EMD (if window_sec set)

## Examples

``` r
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
set.seed(4)
kin <- matrix(cumsum(rnorm(300)) + sin(seq(0, 6, length.out = 300)), 300, 1)
colnames(kin) <- "elbow"
result <- neuromechElectromechanicalDelay(emg, kin, sr = 1000, n_perm = 19)
result
#> $emd
#> [1] muscle           bone             muscle_idx       bone_idx        
#> [5] emd_ms           peak_correlation
#> <0 rows> (or 0-length row.names)
#> 
#> $network_distance
#> numeric(0)
#> 
#> $correlation
#> [1] NA
#> 
#> $p_value
#> [1] NA
#> 
#> $time_varying
#> NULL
#> 
```
