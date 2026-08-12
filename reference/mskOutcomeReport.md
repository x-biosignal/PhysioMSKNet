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
if (FALSE) { # \dontrun{
outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
milestones <- mskFunctionalMilestones(outcome)
report <- mskOutcomeReport(outcome, milestones)
print(report)
} # }
```
