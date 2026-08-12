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
if (FALSE) { # \dontrun{
profile <- mskInjuryRiskProfile(list(age = 45, activity_level = "active"))
} # }
```
