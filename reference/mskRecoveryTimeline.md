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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
timeline <- mskRecoveryTimeline("Biceps Brachii", hg = hg)
timeline
#>    week         muscle remaining_impact_pct      phase        milestone
#> 1     0 Biceps Brachii                100.0      Acute                 
#> 2     1 Biceps Brachii                 18.9 Remodeling Enter Remodeling
#> 3     2 Biceps Brachii                  3.6     Return     Enter Return
#> 4     3 Biceps Brachii                  0.7     Return                 
#> 5     4 Biceps Brachii                  0.1     Return                 
#> 6     5 Biceps Brachii                  0.0     Return                 
#> 7     6 Biceps Brachii                  0.0     Return                 
#> 8     7 Biceps Brachii                  0.0     Return                 
#> 9     8 Biceps Brachii                  0.0     Return                 
#> 10    9 Biceps Brachii                  0.0     Return                 
#> 11   10 Biceps Brachii                  0.0     Return                 
#> 12   11 Biceps Brachii                  0.0     Return                 
#> 13   12 Biceps Brachii                  0.0     Return                 
```
