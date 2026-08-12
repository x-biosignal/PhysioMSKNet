# Track Longitudinal MSK Metrics Across Timepoints

Computes per-timepoint RMS activation, synergy decomposition (W/H/VAF),
and optionally CMC for a series of EMG measurements taken at different
timepoints during rehabilitation.

## Usage

``` r
mskLongitudinalTracker(
  timepoints,
  hg = NULL,
  emg_mapping = NULL,
  metrics = c("rms", "synergy"),
  sr = NULL
)
```

## Arguments

- timepoints:

  Named list of EMG matrices (time x channels). Names should be
  timepoint labels (e.g., "T0", "T1", "T2").

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- metrics:

  Character vector of metrics to compute (default: c("rms", "synergy")).
  Options: "rms", "synergy", "mean_activation", "peak_activation".

- sr:

  Optional sampling rate in Hz (overrides detected values).

## Value

An S3 object of class `"MSKLongitudinalTracker"` with:

- metrics_table:

  data.frame (timepoint, muscle, metric_name, value)

- timepoint_labels:

  character vector

- n_timepoints:

  integer

- synergy_series:

  list of synergy results per timepoint

- activation_series:

  matrix (n_muscles x n_timepoints)

## Examples

``` r
if (FALSE) { # \dontrun{
emg_t0 <- matrix(abs(rnorm(400)), 100, 4)
emg_t1 <- matrix(abs(rnorm(400)), 100, 4)
colnames(emg_t0) <- colnames(emg_t1) <- paste0("muscle_", 1:4)
tracker <- mskLongitudinalTracker(list(T0 = emg_t0, T1 = emg_t1))
} # }
```
