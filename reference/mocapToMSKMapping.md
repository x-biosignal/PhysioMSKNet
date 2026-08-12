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
if (FALSE) { # \dontrun{
mapping <- mocapToMSKMapping(c("upper_arm", "forearm", "thigh"))
} # }
```
