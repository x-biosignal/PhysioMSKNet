# Map MoCap Segments to MSK Bones

Matches MoCap segment names from a SkeletonModel or character vector to
bones in an MSK hypergraph using a curated lookup table with fuzzy
matching fallback.

## Usage

``` r
mocapToMSKMapping(
  skeleton,
  hg = NULL,
  method = c("exact", "fuzzy"),
  threshold = 0.7
)
```

## Arguments

- skeleton:

  A PhysioMoCap SkeletonModel object or character vector of segment
  names.

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character, matching method: "exact" or "fuzzy".

- threshold:

  Numeric, fuzzy matching threshold (default: 0.7).

## Value

A data.frame with columns: segment_name, bone_idx, bone_name,
match_quality, match_method.

## Examples

``` r
mapping <- mocapToMSKMapping(c("humerus", "radius", "femur"))
mapping
#>   segment_name bone_idx bone_name match_quality match_method
#> 1      humerus       45   Humerus             1       lookup
#> 2       radius       50    Radius             1        exact
#> 3        femur      121     Femur             1       lookup
```
