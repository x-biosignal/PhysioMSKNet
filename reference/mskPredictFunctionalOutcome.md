# Predict Functional Outcome from MSK Network Analysis

Predicts clinical functional outcomes (ROM, strength, composite function
score) for injured muscles based on MSK network topology, impact
analysis, and optional EMG activation data. Provides evidence-based
regression models with confidence intervals.

## Usage

``` r
mskPredictFunctionalOutcome(
  injured_muscles,
  hg = NULL,
  outcome_type = c("all", "rom", "strength", "function"),
  patient_factors = NULL,
  emg = NULL,
  emg_mapping = NULL,
  confidence_level = 0.95
)
```

## Arguments

- injured_muscles:

  Character or integer vector identifying injured muscles.

- hg:

  An MSKHypergraph object (NULL loads default 173-bone/270-muscle
  network).

- outcome_type:

  Character: "rom" (range of motion), "strength", "function" (composite
  functional score), or "all" (default).

- patient_factors:

  Optional list with: age (numeric), sex (character), bmi (numeric),
  activity_level (character), injury_severity
  ("mild"/"moderate"/"severe").

- emg:

  Optional EMG data (SummarizedExperiment, matrix, or numeric vector)
  for activation-based prediction refinement.

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- confidence_level:

  Numeric, confidence level for CIs (default: 0.95).

## Value

An S3 object of class `"MSKFunctionalOutcome"` with:

- predictions:

  data.frame with muscle, outcome_type, predicted_value, lower_ci,
  upper_ci, unit

- aggregate:

  list with overall_rom, overall_strength, overall_function

- recovery_weeks:

  estimated weeks to reach 90 percent of predicted outcome

- confidence_level:

  numeric

- model_type:

  character

- patient_factors_used:

  list

## Clinical Validity

The prediction models are based on MSK network topology and heuristic
adjustments. They are not independently validated clinical tools. Use as
a research exploration tool, not a clinical diagnostic.

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
print(outcome)
#> MSK Functional Outcome Prediction
#> ==================================
#> Injured muscles: Biceps Brachii 
#> Model type: network_topology 
#> Confidence level: 0.95 
#> 
#> Aggregate Outcomes:
#>   ROM:      91.3% of normal
#>   Strength: 88.5% of normal
#>   Function: 71.9 / 80 (LEFS-like)
#> 
#> Per-Muscle Predictions:
#>   Biceps Brachii [rom]: 91.3 (% of normal, 95% CI: 81.5-100.0)
#>   Biceps Brachii [strength]: 88.5 (% of normal, 95% CI: 76.7-100.0)
#>   aggregate [function]: 71.9 (LEFS-like (0-80), 95% CI: 64.1-79.8)
#> 
#> Estimated Recovery (to 90% of predicted):
#>   Biceps Brachii: 6.9 weeks
```
