# Comprehensive Outcome Report

Orchestrator function that combines functional outcome prediction,
milestones, and optional reassessment into a comprehensive report.

## Usage

``` r
mskOutcomeReport(outcome, milestones = NULL, reassessment = NULL, hg = NULL)
```

## Arguments

- outcome:

  An `MSKFunctionalOutcome` object.

- milestones:

  Optional `MSKFunctionalMilestones` object.

- reassessment:

  Optional `MSKReassessment` object.

- hg:

  An MSKHypergraph object (NULL loads default).

## Value

An S3 object of class `"MSKOutcomeReport"` with all sub-results.

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
milestones <- mskFunctionalMilestones(outcome)
report <- mskOutcomeReport(outcome, milestones)
print(report)
#> === MSK Outcome Report ===
#> Generated: 2026-10-03 13:27:04 
#> Injured muscles: Biceps Brachii 
#> Available analyses: outcome_prediction, milestones, confidence_intervals 
#> 
#> --- Outcome Prediction ---
#>   ROM:      91.3% of normal
#>   Strength: 88.5% of normal
#>   Function: 71.9 / 80
#> 
#> --- Milestones ---
#>   Type: clinical, Timeline: 14 weeks, Phases: 4
#> 
#> --- Confidence Intervals ---
#>   Method: analytical, Overall uncertainty: 19.60
```
