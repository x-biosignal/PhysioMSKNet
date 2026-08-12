# Profile a MSK Community's Functional Characteristics

Generates a detailed functional profile of a musculoskeletal community
by combining network topology metrics with knowledge graph annotations.
This enables characterization of communities by their anatomical region,
innervation patterns, primary actions, and spinal segment involvement.

## Usage

``` r
mskCommunityProfile(hg = NULL, community_id, hub = NULL, gamma = 4.3)
```

## Arguments

- hg:

  An MSKHypergraph object. If NULL, loads default network.

- community_id:

  Integer, the community to profile (1-based).

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- gamma:

  Numeric, resolution parameter for community detection (default: 4.3,
  as in Murphy et al. 2018).

## Value

An S3 object of class `"MSKCommunityProfile"` with:

- community_id:

  Integer, the profiled community

- muscles:

  Character vector of muscle names in the community

- n_muscles:

  Integer, number of muscles

- action_profile:

  Table of primary action distribution

- nerve_profile:

  Table of innervating nerves distribution

- region_profile:

  Table of body region distribution

- spinal_profile:

  Table of spinal level distribution

- dominant_action:

  Most frequent primary action

- dominant_nerve:

  Most frequent innervating nerve

- dominant_region:

  Most frequent body region

- mean_degree:

  Mean hyperedge degree of community muscles

- mean_impact_deviation:

  Mean impact deviation score

## Clinical Validity

Community membership depends on the resolution parameter gamma and the
stochastic Louvain algorithm. Profile annotations depend on KG
completeness. Community boundaries are network-derived, not anatomical
boundaries.

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.

## Examples

``` r
if (FALSE) { # \dontrun{
profile <- mskCommunityProfile(community_id = 1)
print(profile)
} # }
```
