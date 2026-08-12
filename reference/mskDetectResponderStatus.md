# Classify Muscles as Responders, Non-Responders, or Deteriorated

Compares first and last timepoint to determine if each muscle shows
clinically meaningful change beyond the MDC threshold.

## Usage

``` r
mskDetectResponderStatus(
  tracker,
  mdc_result = NULL,
  threshold_type = c("mdc", "effect_size"),
  instrument = NULL,
  population = NULL,
  direction = c("increase", "decrease")
)
```

## Arguments

- tracker:

  An `MSKLongitudinalTracker` object.

- mdc_result:

  An `MSKMinimalDetectableChange` object (or NULL to use effect size
  threshold).

- threshold_type:

  Character, "mdc" (default) or "effect_size" (Cohen's d \> 0.8).

- instrument:

  Optional validated instrument id (e.g. `"fma_ue"`) to delegate dual
  MDC-vs-MCID classification to PhysioClinical.

- population:

  Optional population stratum for the instrument's clinimetric lookup
  (used only with `instrument`).

- direction:

  `"increase"` (default) or `"decrease"` — the direction of clinical
  benefit, passed to the clinimetric classifier.

## Value

An S3 object of class `"MSKResponderStatus"` with:

- classification:

  data.frame (muscle, status, change, threshold, effect_size_d; plus
  clinical_class when delegated)

- summary:

  counts of responders/non-responders/deteriorated

- overall_status:

  "responder" if majority of muscles improve

- method:

  "clinimetric" (delegated) or "threshold"

## Details

When a validated `instrument` and `population` are supplied and the
PhysioClinical package is available, classification is delegated to
[`PhysioClinical::classifyResponder()`](https://x-biosignal.github.io/PhysioClinical/reference/classifyResponder.html),
which applies the published dual MDC-vs-MCID rule (adding a
`clinical_class` column). Otherwise the single-threshold path (MDC or
effect size) is used.

## Examples

``` r
if (FALSE) { # \dontrun{
status <- mskDetectResponderStatus(tracker, mdc_result)
status <- mskDetectResponderStatus(tracker, instrument = "fma_ue",
                                   population = "stroke")
} # }
```
