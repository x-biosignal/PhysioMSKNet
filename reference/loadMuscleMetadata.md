# Load Muscle Metadata

Loads metadata for all 270 muscles including community assignments and
homunculus category labels from the paper.

## Usage

``` r
loadMuscleMetadata()
```

## Value

A data.frame with columns: index, muscle, community, homunculus_category

## References

Murphy AC et al. (2018) PLOS Biology.

## Examples

``` r
meta <- loadMuscleMetadata()
head(meta)
#>   index                      muscle community homunculus_category
#> 1     1                   Trapezius         1                   5
#> 2     2            Latissimus Dorsi         2                   5
#> 3     3 Serratus Posterior Superior         3                   5
#> 4     4 Serratus Posterior Inferior         4                   5
#> 5     5            Levator Scapulae         5                   5
#> 6     6              Rhomboid Minor         6                   5
```
