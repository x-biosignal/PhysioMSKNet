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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
ci <- mskOutcomeConfidenceInterval(outcome)
ci
#> $ci
#>                   outcome point_estimate lower upper width
#> 1      rom_Biceps Brachii           81.3  74.6  87.8  13.1
#> 2 strength_Biceps Brachii           80.5  71.5  89.0  17.5
#> 3      function_aggregate           71.9  58.5  70.7  12.3
#> 
#> $method
#> [1] "bootstrap"
#> 
#> $n_boot
#> [1] 100
#> 
#> $overall_uncertainty
#> [1] 14.3
#> 
```
