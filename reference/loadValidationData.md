# Load Validation Data

Loads validation datasets used to reproduce key figures from the paper.

## Usage

``` r
loadValidationData(
  dataset = c("degree_distribution", "impact_vs_recovery", "homunculus_deviation",
    "fmri_activation", "homunculus_coordinates", "impact_vs_path", "impact_scores")
)
```

## Arguments

- dataset:

  Character string specifying which dataset to load:

  "degree_distribution"

  :   Degree probability for real vs null hypergraphs (fig2e)

  "impact_vs_recovery"

  :   Recovery time vs impact deviation (fig3b)

  "homunculus_deviation"

  :   Homunculus area vs deviation ratio (fig4b)

  "fmri_activation"

  :   Impact deviation vs fMRI activation volume (fig4c)

  "homunculus_coordinates"

  :   Homunculus area vs muscle MDS coordinate (fig4d)

  "impact_vs_path"

  :   Average shortest path vs impact score (figS11)

## Value

A data.frame with the requested validation data

## References

Murphy AC et al. (2018) PLOS Biology.
