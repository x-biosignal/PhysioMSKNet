# Load MSK Network Data

Loads the complete musculoskeletal network dataset from Murphy et al.
(2018). Returns a list containing the incidence matrix, muscle metadata,
and validation data for reproducing the paper's results.

## Usage

``` r
loadMSKData()
```

## Value

A list with components:

- incidence:

  Sparse incidence matrix C (bones x muscles)

- muscle_meta:

  Data frame with muscle names, community assignments, homunculus
  categories

- bone_names:

  Character vector of bone/vertex names

- muscle_names:

  Character vector of muscle/hyperedge names

## References

Murphy AC et al. (2018) "Structure, function, and control of the human
musculoskeletal network." PLOS Biology 16(1): e2002811.
