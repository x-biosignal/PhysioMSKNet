# Track Compensation Pattern Evolution Over Time

Tracks changes in compensation patterns across multiple timepoints,
identifying onset, resolution, and trends.

## Usage

``` r
mskCompensationEvolution(
  timepoints_emg,
  injured_muscles,
  hg = NULL,
  emg_mapping = NULL,
  sr = NULL,
  z_threshold = 1.96
)
```

## Arguments

- timepoints_emg:

  Named list of EMG matrices. The first element is treated as baseline.

- injured_muscles:

  Character vector of injured muscle names or integer indices.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr:

  Optional sampling rate override.

- z_threshold:

  Numeric, z-score threshold (default: 1.96).

## Value

An S3 object of class `"MSKCompensationEvolution"` with:

- evolution_table:

  Data.frame of per-timepoint per-muscle z-scores

- onset_timepoint:

  Per-muscle first timepoint of compensation

- resolution_timepoint:

  Per-muscle first timepoint of resolution

- trend:

  Per-muscle trend classification

- summary:

  Data.frame of per-timepoint summary statistics

## Examples

``` r
if (FALSE) { # \dontrun{
evolution <- mskCompensationEvolution(
  timepoints_emg = list(week0 = emg0, week2 = emg2, week4 = emg4),
  injured_muscles = c("Biceps Brachii")
)
} # }
```
