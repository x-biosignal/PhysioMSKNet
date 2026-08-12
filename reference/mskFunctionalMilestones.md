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
if (FALSE) { # \dontrun{
outcome <- mskPredictFunctionalOutcome("Biceps Brachii")
milestones <- mskFunctionalMilestones(outcome, milestone_type = "clinical")
print(milestones)
} # }
```
