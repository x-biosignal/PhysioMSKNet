# MSK Outcome Summary Report

Orchestrator function that calls all clinical bridge functions with
shared hypergraph and simulation objects, producing a comprehensive
report.

## Usage

``` r
mskOutcomeSummary(injury_muscles, patient_data = NULL, hg = NULL, sim = NULL)
```

## Arguments

- injury_muscles:

  Character or integer vector identifying injured muscles.

- patient_data:

  Optional list with patient characteristics (see
  [`mskInjuryRiskProfile`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskInjuryRiskProfile.md)).

- hg:

  An MSKHypergraph object (NULL loads default).

- sim:

  An MSKSimulation object (NULL creates default).

## Value

An S3 object of class `"MSKOutcomeSummary"` containing:

- prediction:

  MSKClinicalPrediction object

- timeline:

  Recovery timeline data.frame

- risk_profile:

  MSKInjuryRiskProfile object (if patient_data provided)

- rehab:

  MSKRehabProtocol object

## Clinical Validity

All predictions are model-based estimates using MSK network topology.
Recovery model was validated on 14 aggregate muscle groups. Patient
factors are heuristic. This is a research exploration tool, not a
clinical diagnostic.

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
s <- mskOutcomeSummary("Biceps Brachii", hg = hg)
print(s)
#> === MSK Outcome Summary ===
#> 
#> Injured muscles: Biceps Brachii 
#> 
#> --- Recovery Prediction ---
#>                        muscle impact_deviation predicted_weeks ci_lower
#> Biceps Brachii Biceps Brachii           -0.577             1.8        1
#>                ci_upper
#> Biceps Brachii     10.5
#> 
#> --- Timeline (first 4 weeks) ---
#>  week         muscle remaining_impact_pct      phase        milestone
#>     0 Biceps Brachii                100.0      Acute                 
#>     1 Biceps Brachii                 18.9 Remodeling Enter Remodeling
#>     2 Biceps Brachii                  3.6     Return     Enter Return
#>     3 Biceps Brachii                  0.7     Return                 
#>     4 Biceps Brachii                  0.1     Return                 
#> 
#> --- Rehabilitation Protocol ---
#> Phase 1 (Isolated): 1 muscles
#> Phase 2 (Intra-community): 0 muscles
#> Phase 3 (Cross-community): 2 muscles
```
