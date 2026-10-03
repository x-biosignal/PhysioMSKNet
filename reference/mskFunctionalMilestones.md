# Generate Functional Milestones for Rehabilitation

Takes the output of `mskPredictFunctionalOutcome` and generates
time-based milestones for tracking rehabilitation progress.

## Usage

``` r
mskFunctionalMilestones(
  outcome_prediction,
  n_milestones = 4L,
  milestone_type = c("clinical", "linear", "accelerating")
)
```

## Arguments

- outcome_prediction:

  An `MSKFunctionalOutcome` object.

- n_milestones:

  Integer, number of milestones to generate (default: 4).

- milestone_type:

  Character: "linear" (evenly spaced), "accelerating" (front-loaded), or
  "clinical" (based on standard rehab phases).

## Value

An S3 object of class `"MSKFunctionalMilestones"` with:

- milestones:

  data.frame with milestone_id, week, target_rom, target_strength,
  target_function, phase_name, description

- timeline_weeks:

  total timeline in weeks

- milestone_type:

  character

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
milestones <- mskFunctionalMilestones(outcome, milestone_type = "clinical")
print(milestones)
#> MSK Functional Milestones
#> =========================
#> Type: clinical 
#> Total timeline: 14 weeks
#> 
#>   Milestone 1 (Week 2) - Pain Control:
#>     ROM: 27.4%  Strength: 17.7%  Function: 18.0/80
#>     Pain control, protect repair (target: 25% function)
#>   Milestone 2 (Week 6) - Restore ROM:
#>     ROM: 63.9%  Strength: 44.2%  Function: 36.0/80
#>     Restore ROM (target: 50% function, 70% ROM)
#>   Milestone 3 (Week 12) - Strengthen:
#>     ROM: 77.6%  Strength: 70.8%  Function: 53.9/80
#>     Strengthen (target: 75% function, 80% strength)
#>   Milestone 4 (Week 14) - Return to Activity:
#>     ROM: 86.7%  Strength: 84.1%  Function: 64.7/80
#>     Return to activity (target: 90% function)
```
