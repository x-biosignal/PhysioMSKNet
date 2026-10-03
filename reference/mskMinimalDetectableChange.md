# Compute Minimal Detectable Change from Longitudinal Tracker

Computes ICC (intraclass correlation coefficient) across timepoints for
each metric, then derives SEM and MDC values for clinimetric assessment.

## Usage

``` r
mskMinimalDetectableChange(
  tracker,
  method = "standard",
  confidence = 0.95,
  icc_method = "ICC(2,1)"
)
```

## Arguments

- tracker:

  An `MSKLongitudinalTracker` object.

- method:

  Character, method for MDC computation (default: "standard").

- confidence:

  Numeric, confidence level for MDC (default: 0.95).

- icc_method:

  Character, ICC formula variant (default: "ICC(2,1)").

## Value

An S3 object of class `"MSKMinimalDetectableChange"` with:

- mdc_table:

  data.frame (muscle, metric, ICC, SEM, MDC, pooled_SD)

- confidence_level:

  numeric

- method:

  character

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
mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)
mdc
#> MSK Minimal Detectable Change
#> ==============================
#> Confidence level: 0.95 
#> Method: standard 
#> 
#> MDC Table:
#>           muscle metric ICC    SEM    MDC pooled_SD
#>   Biceps Brachii    rms   0 0.0541 0.1500    0.0541
#>          Deltoid    rms   0 0.0238 0.0660    0.0238
#>        Trapezius    rms   0 0.0648 0.1797    0.0648
#>  Triceps Brachii    rms   0 0.0334 0.0927    0.0334
```
