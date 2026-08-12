# Predict ROM (range of motion) as percentage of normal

Evidence-based regression: higher impact deviation leads to greater ROM
loss.

## Usage

``` r
.predictROM(impact_dev, patient_factors = NULL)
```

## Arguments

- impact_dev:

  Numeric vector of impact deviations.

- patient_factors:

  List with optional age, sex, bmi, injury_severity.

## Value

Numeric vector of predicted ROM percentages (0-100).
