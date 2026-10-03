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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
mk <- function(s) { set.seed(s); m <- matrix(abs(rnorm(300 * 4)), 300, 4)
  colnames(m) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii"); m }
tracker <- mskLongitudinalTracker(list(T0 = mk(1), T1 = mk(2), T2 = mk(3)), hg = hg)
print(tracker)
#> MSK Longitudinal Tracker
#> ========================
#> Timepoints: 3 ( T0, T1, T2 )
#> Muscles: 4 
#> Metrics recorded: 15 observations
#> Synergy VAF range: 1 - 1 
```
