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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
mk <- function(s) { set.seed(s); m <- matrix(abs(rnorm(300 * 4)), 300, 4)
  colnames(m) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii"); m }
tracker <- mskLongitudinalTracker(list(T0 = mk(1), T1 = mk(2), T2 = mk(3)), hg = hg)
status <- mskDetectResponderStatus(tracker)
status
#> MSK Responder Status
#> ====================
#> Overall: non_responder 
#> 
#> Summary:
#>   Responders: 0 
#>   Non-responders: 2 
#>   Deteriorated: 2 
#> 
#> Per-muscle classification:
#>           muscle        status  change threshold effect_size_d
#>   Biceps Brachii non_responder  0.0302    0.0433        0.5572
#>          Deltoid  deteriorated -0.0205    0.0190       -0.8596
#>        Trapezius  deteriorated -0.1226    0.0519       -1.8908
#>  Triceps Brachii non_responder  0.0133    0.0267        0.3971
```
