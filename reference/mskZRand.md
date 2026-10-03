# Adjusted Rand Index (z-score)

Computes the z-scored Rand index between two partitions. Used to compare
community structure with homunculus categories.

## Usage

``` r
mskZRand(partition1, partition2)
```

## Arguments

- partition1:

  Integer vector of community assignments.

- partition2:

  Integer vector of category assignments.

## Value

Numeric z-Rand score. Values \> 1.96 indicate significant similarity.

## References

Traud et al. (2011) Physical Review E.

## Examples

``` r
p1 <- c(1, 1, 1, 2, 2, 2)
p2 <- c(1, 1, 2, 2, 2, 2)
mskZRand(p1, p2)
#> [1] 1.412089
```
