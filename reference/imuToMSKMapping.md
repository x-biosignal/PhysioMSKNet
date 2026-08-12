# Map IMU Sensor Placements to MSK Bones

Matches IMU sensor placement names to bones in the MSK hypergraph using
a curated lookup table with fuzzy matching fallback. Supports naming
conventions from Xsens, APDM, Shimmer, and generic body-segment labels.

## Usage

``` r
imuToMSKMapping(
  sensors,
  hg = NULL,
  method = c("exact", "fuzzy"),
  threshold = 0.7
)
```

## Arguments

- sensors:

  Character vector of IMU sensor placement names (e.g.,
  `c("upper_arm", "thigh", "lumbar")`).

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character, matching method: "exact" or "fuzzy".

- threshold:

  Numeric, fuzzy matching threshold (default: 0.7).

## Value

A data.frame with columns: sensor_name, bone_idx, bone_name,
match_quality, match_method.

## Examples

``` r
if (FALSE) { # \dontrun{
mapping <- imuToMSKMapping(c("upper_arm", "thigh", "lumbar"))
} # }
```
