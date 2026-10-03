# Community Detection on MSK Network

Detects communities in the projected muscle-muscle graph using the
Louvain algorithm with a resolution parameter gamma.

## Usage

``` r
mskCommunityDetect(hg = NULL, gamma = 4.3, type = c("muscle", "bone"))
```

## Arguments

- hg:

  An MSKHypergraph object. If NULL, loads built-in data.

- gamma:

  Resolution parameter for modularity (default: 4.3, as in paper).
  Higher values produce more, smaller communities.

- type:

  Projection type: "muscle" (default, as in paper) or "bone".

## Value

A list with:

- membership:

  Named integer vector of community assignments

- n_communities:

  Number of communities detected

- modularity:

  Modularity value Q

- gamma:

  Resolution parameter used

- sizes:

  Table of community sizes

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.

## Examples

``` r
C <- matrix(c(1, 1, 0, 0,  0, 1, 1, 0,  0, 0, 1, 1,  1, 0, 0, 1),
            nrow = 4, dimnames = list(paste0("b", 1:4), paste0("m", 1:4)))
cm <- mskCommunityDetect(MSKHypergraph(C), gamma = 1)
cm$membership
#> m1 m2 m3 m4 
#>  1  1  2  2 
```
