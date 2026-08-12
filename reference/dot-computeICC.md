# Compute ICC(2,1) from a values matrix

Uses one-way random ANOVA decomposition: ICC = (BMS - WMS) / (BMS +
(k-1)\*WMS)

## Usage

``` r
.computeICC(values_matrix)
```

## Arguments

- values_matrix:

  Numeric matrix (subjects x timepoints).

## Value

Numeric ICC value clamped to the range 0 to 1.
