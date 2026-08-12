# Recovery Timeline with Phase Assignment

Generates a week-by-week recovery timeline based on exponential decay of
network impact, with clinical phase assignments.

## Usage

``` r
mskRecoveryTimeline(injury_muscles, hg = NULL, sim = NULL, n_weeks = 12L)
```

## Arguments

- injury_muscles:

  Character or integer vector identifying injured muscles.

- hg:

  An MSKHypergraph object (NULL loads default).

- sim:

  An MSKSimulation object (NULL creates default).

- n_weeks:

  Integer, number of weeks to project (default: 12).

## Value

A data.frame with columns: week, muscle, remaining_impact_pct, phase,
milestone.

## Clinical Validity

Phase assignments are based on exponential decay of network impact
scores, not empirical clinical data. They should be interpreted as
model-based estimates for research purposes only.

## Examples

``` r
if (FALSE) { # \dontrun{
timeline <- mskRecoveryTimeline("Biceps Brachii")
} # }
```
