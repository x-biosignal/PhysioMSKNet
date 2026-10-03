# Link a network-derived outcome prediction to a clinical outcome measure

Maps an MSK-network functional-outcome prediction to a validated
clinical outcome measure (COM) instrument and its WHO ICF category tags
(via
[`PhysioAnnotationHub::tagICF()`](https://x-biosignal.github.io/PhysioAnnotationHub//reference/tagICF.html),
when that package is installed). This bridges an abstract network
prediction to a documented, ICF-anchored clinical instrument.

## Usage

``` r
mskLinkOutcomeMeasure(
  outcome,
  instrument_id,
  measure = c("function", "rom", "strength"),
  hub = NULL
)
```

## Arguments

- outcome:

  An `MSKFunctionalOutcome` (from
  [`mskPredictFunctionalOutcome()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPredictFunctionalOutcome.md))
  or a single numeric prediction.

- instrument_id:

  A clinical outcome-measure instrument id (e.g. `"fma_ue"`, `"berg"`).

- measure:

  Which aggregate prediction to link when `outcome` is an
  `MSKFunctionalOutcome`: `"function"` (default), `"rom"`, or
  `"strength"`.

- hub:

  Optional `PhysioAnnotationHub` passed to `tagICF()`.

## Value

A data.frame with `instrument_id`, `measure`, `predicted_value`, and
`icf_code` (one row per ICF tag; a single `NA` `icf_code` when no ICF
link is available).

## See also

[`mskPredictFunctionalOutcome()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPredictFunctionalOutcome.md)

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
mskLinkOutcomeMeasure(outcome, "fma_ue", measure = "strength")
#>   instrument_id  measure predicted_value icf_code
#> 1        fma_ue strength            88.5     b730
#> 2        fma_ue strength            88.5     b760
```
