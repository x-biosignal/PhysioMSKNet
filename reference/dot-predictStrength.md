# Predict strength as percentage of normal

Uses activation deficit if EMG available, otherwise impact deviation.

## Usage

``` r
.predictStrength(impact_dev, activation_deficit = NULL, patient_factors = NULL)
```

## Arguments

- impact_dev:

  Numeric vector of impact deviations.

- activation_deficit:

  Numeric vector of activation deficits (0-1) or NULL.

- patient_factors:

  List with optional patient characteristics.

## Value

Numeric vector of predicted strength percentages (0-100).
