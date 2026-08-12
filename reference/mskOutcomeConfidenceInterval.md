# Confidence Intervals for Outcome Predictions

Computes confidence intervals for functional outcome predictions using
bootstrap resampling or analytical delta method.

## Usage

``` r
mskOutcomeConfidenceInterval(
  predictions,
  method = c("bootstrap", "analytical"),
  n_boot = 100L,
  confidence_level = 0.95
)
```

## Arguments

- predictions:

  An `MSKFunctionalOutcome` object.

- method:

  Character: "bootstrap" (default) or "analytical".

- n_boot:

  Integer, number of bootstrap resamples (default: 100).

- confidence_level:

  Numeric, confidence level (default: 0.95).

## Value

A list with:

- ci:

  data.frame with outcome, point_estimate, lower, upper, width

- method:

  character

- n_boot:

  integer (for bootstrap)

- overall_uncertainty:

  numeric, mean CI width

## Examples

``` r
if (FALSE) { # \dontrun{
outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
ci <- mskOutcomeConfidenceInterval(outcome)
} # }
```
