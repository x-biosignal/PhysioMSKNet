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
if (FALSE) { # \dontrun{
summary <- mskOutcomeSummary("Trapezius")
print(summary)
} # }
```
