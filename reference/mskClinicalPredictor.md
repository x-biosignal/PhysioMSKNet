# Clinical Prediction from MSK Network Topology

Predicts recovery time, identifies compensatory muscles, and estimates
secondary injury risk based on MSK network impact analysis.

## Usage

``` r
mskClinicalPredictor(injury_muscles, hg = NULL, sim = NULL, verbose = TRUE)
```

## Arguments

- injury_muscles:

  Character or integer vector identifying injured muscles.

- hg:

  An MSKHypergraph object (NULL loads default 173-bone/270-muscle
  network).

- sim:

  An MSKSimulation object (NULL creates one with default parameters).

- verbose:

  Logical, print progress messages (default: TRUE).

## Value

An S3 object of class `"MSKClinicalPrediction"` with:

- recovery:

  Data frame with predicted recovery weeks and CI per muscle

- compensatory:

  List of compensatory muscles per injured muscle

- secondary_risk:

  Data frame of secondary injury risk scores

- injury_muscles:

  Resolved muscle names

- injury_indices:

  Resolved integer indices

## Clinical Validity

The recovery model was validated on 14 aggregate muscle groups, not
individual muscles. Patient factor adjustments are heuristic, not
independently validated. This is a research exploration tool, not a
clinical diagnostic.

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.

## Examples

``` r
# Build a small musculoskeletal hypergraph (bones x muscles incidence)
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
pred <- mskClinicalPredictor("Biceps Brachii", hg = hg, verbose = FALSE)
print(pred)
#> MSK Clinical Prediction
#> =======================
#> Injured muscles: Biceps Brachii 
#> 
#> Recovery Prediction:
#>   Biceps Brachii: 1.8 weeks (95% CI: 1.0-10.5)
#> 
#> Top Compensatory Muscles:
#>   Biceps Brachii: Deltoid, Brachialis
#> 
#> Secondary Injury Risk (top 5):
#>   Deltoid: risk = 1.000
#>   Brachialis: risk = 0.667
```
