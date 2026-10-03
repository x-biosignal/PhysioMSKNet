# Detect Recovery Plateau in Longitudinal Data

Identifies when recovery has plateaued using rolling window slope
analysis or change rate assessment.

## Usage

``` r
mskDetectRecoveryPlateau(
  tracker,
  window = 3L,
  min_slope = NULL,
  method = c("slope", "change_rate")
)
```

## Arguments

- tracker:

  An `MSKLongitudinalTracker` object.

- window:

  Integer, number of consecutive timepoints to assess (default: 3).

- min_slope:

  Numeric, minimum slope to be considered "improving" (default: NULL,
  auto-computed from data variability).

- method:

  Character, "slope" (default) or "change_rate".

## Value

An S3 object of class `"MSKRecoveryPlateau"` with:

- plateau_detected:

  logical per muscle

- plateau_onset:

  timepoint index where plateau begins (NA if none)

- details:

  data.frame with per-window slopes

- recommendation:

  character ("continue", "modify_protocol", "reassess")

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
mk <- function(s) { set.seed(s); m <- matrix(abs(rnorm(300 * 4)), 300, 4)
  colnames(m) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii"); m }
tracker <- mskLongitudinalTracker(list(T0 = mk(1), T1 = mk(2), T2 = mk(3)), hg = hg)
plateau <- mskDetectRecoveryPlateau(tracker, window = 2)
plateau
#> MSK Recovery Plateau Detection
#> ===============================
#> Plateau detected: 0 of 4 muscles
#> Recommendation: continue 
```
