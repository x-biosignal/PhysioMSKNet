# Compute Impact Deviation

Computes the impact deviation for each muscle, which is the difference
between the observed impact score and the expected impact score for a
muscle of that degree, expressed in standard deviations.

## Usage

``` r
mskImpactDeviation(impact_scores, hg, null_scores = NULL)
```

## Arguments

- impact_scores:

  Named numeric vector of impact scores (from mskImpactScoreAll).

- hg:

  An MSKHypergraph object.

- null_scores:

  Optional matrix of null model impact scores (muscles x null_runs). If
  NULL, deviation is computed relative to a degree-based regression.

## Value

A named numeric vector of impact deviations.

## Details

The expected impact score is estimated from null model simulations or
from a regression of impact score vs. degree.

## References

Murphy AC et al. (2018) PLOS Biology.
