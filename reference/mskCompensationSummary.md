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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
set.seed(1); emg_base <- matrix(abs(rnorm(300 * 4)), 300, 4)
set.seed(2); emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- colnames(emg_base) <-
  c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
s <- mskCompensationSummary(emg, emg_base, "Biceps Brachii", hg = hg,
  duration_weeks = 4, load_intensity = "moderate")
s
#> MSK Compensation Analysis Summary
#> ==================================
#> Available analyses: compensation, risk, network 
#> 
#> Compensation: 0 muscles compensating (prevalence: 0.0%)
#> Risk: 0.000 (LOW) - none
#> Network: 0 chains, 0 hub muscles
```
