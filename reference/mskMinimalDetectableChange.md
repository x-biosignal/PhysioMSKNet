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
if (FALSE) { # \dontrun{
mdc <- mskMinimalDetectableChange(tracker, confidence = 0.95)
} # }
```
