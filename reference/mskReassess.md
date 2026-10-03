# Reassess Patient Progress

Compares current physiological measurements to a previous assessment,
computing progress metrics and generating recommendations.

## Usage

``` r
mskReassess(
  current_data,
  previous_assessment,
  hg = NULL,
  emg_mapping = NULL,
  sr = NULL
)
```

## Arguments

- current_data:

  A list with: emg (required, matrix or SummarizedExperiment), and
  optional eeg, kinematics, force.

- previous_assessment:

  A previous `MSKFunctionalOutcome` or `MSKReassessment` object.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed EMG-to-MSK mapping.

- sr:

  Optional numeric sampling rate.

## Value

An S3 object of class `"MSKReassessment"` with:

- current_metrics:

  data.frame of current activation/synergy metrics

- previous_metrics:

  data.frame from previous assessment

- change:

  data.frame with metric, previous, current, change, pct_change,
  significant

- progress_summary:

  character vector per metric

- overall_progress:

  weighted average progress score (0-100)

- recommendation:

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
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
reassessment <- mskReassess(list(emg = emg), outcome, hg = hg)
print(reassessment)
#> MSK Reassessment
#> =================
#> Overall progress: 50 / 100
#> Recommendation: modify_protocol 
#> 
```
