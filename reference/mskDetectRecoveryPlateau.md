# Detect Recovery Plateau in Longitudinal Data

Identifies when recovery has plateaued using rolling window slope
analysis or change rate assessment.

## Usage

``` r
mskDetectRecoveryPlateau(
  tracker,
  window = 3L,
  min_slope = NULL,
  method = c("slope", "change_rate")
)
```

## Arguments

- tracker:

  An `MSKLongitudinalTracker` object.

- window:

  Integer, number of consecutive timepoints to assess (default: 3).

- min_slope:

  Numeric, minimum slope to be considered "improving" (default: NULL,
  auto-computed from data variability).

- method:

  Character, "slope" (default) or "change_rate".

## Value

An S3 object of class `"MSKRecoveryPlateau"` with:

- plateau_detected:

  logical per muscle

- plateau_onset:

  timepoint index where plateau begins (NA if none)

- details:

  data.frame with per-window slopes

- recommendation:

  character ("continue", "modify_protocol", "reassess")

## Examples

``` r
if (FALSE) { # \dontrun{
plateau <- mskDetectRecoveryPlateau(tracker, window = 3)
} # }
```
