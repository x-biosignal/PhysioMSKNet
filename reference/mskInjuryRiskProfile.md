# Patient-specific Injury Risk Profile

Computes a personalized injury risk profile for all muscles based on MSK
network topology and patient characteristics.

## Usage

``` r
mskInjuryRiskProfile(patient_data, hg = NULL, sim = NULL)
```

## Arguments

- patient_data:

  A list with patient characteristics:

  age

  :   Numeric, patient age in years (required)

  bmi

  :   Numeric, body mass index (optional)

  activity_level

  :   Character: "sedentary", "moderate", "active", "elite" (optional)

  prior_injuries

  :   Character vector of previously injured muscle names (optional)

- hg:

  An MSKHypergraph object (NULL loads default).

- sim:

  An MSKSimulation object (NULL creates default).

## Value

An S3 object of class `"MSKInjuryRiskProfile"` with:

- risk_scores:

  Data frame with muscle name, base risk, adjusted risk

- patient_data:

  Input patient data

- factors:

  Applied adjustment factors

## Clinical Validity

Patient factor adjustments (age, BMI, activity level) are heuristic
multipliers, not derived from validated epidemiological models. This is
a research exploration tool, not a clinical diagnostic.

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
profile <- mskInjuryRiskProfile(list(age = 45, activity_level = "active"), hg = hg)
profile
#> MSK Injury Risk Profile
#> =======================
#> Patient: age = 45, activity = active
#> Adjustment factors: age = 1.2 , activity = 1.2 , BMI = 1 
#> 
#> Top 10 Risk Muscles:
#>    1. Deltoid                        risk = 1.0000
#>    2. Triceps Brachii                risk = 1.0000
#>    3. Biceps Brachii                 risk = 0.1667
#>    4. Brachialis                     risk = 0.1667
#>    5. Trapezius                      risk = 0.0000
```
