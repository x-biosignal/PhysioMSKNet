# Comprehensive Compensation Analysis Summary

Orchestrator that runs all compensation analyses and returns a unified
summary. Uses tryCatch for each sub-analysis so partial results are
available even if some analyses fail.

## Usage

``` r
mskCompensationSummary(
  emg,
  emg_baseline,
  injured_muscles,
  timepoints_emg = NULL,
  hg = NULL,
  sr = NULL,
  z_threshold = 1.96,
  duration_weeks = 0,
  load_intensity = c("low", "moderate", "high")
)
```

## Arguments

- emg:

  Current EMG data (matrix or SummarizedExperiment).

- emg_baseline:

  Baseline/pre-injury EMG data.

- injured_muscles:

  Character vector of injured muscle names or integer indices.

- timepoints_emg:

  Optional named list of EMG matrices for evolution analysis.

- hg:

  An MSKHypergraph object (NULL loads default).

- sr:

  Optional sampling rate override.

- z_threshold:

  Numeric, z-score threshold (default: 1.96).

- duration_weeks:

  Numeric, compensation duration for risk scoring.

- load_intensity:

  Character, load intensity for risk scoring.

## Value

An S3 object of class `"MSKCompensationSummary"` with sub-results and
available_analyses vector.

## Examples

``` r
if (FALSE) { # \dontrun{
summary <- mskCompensationSummary(
  emg = emg_current, emg_baseline = emg_pre,
  injured_muscles = c("Biceps Brachii"),
  duration_weeks = 4, load_intensity = "moderate"
)
} # }
```
