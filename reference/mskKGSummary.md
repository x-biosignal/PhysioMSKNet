# KG-Enriched Summary of MSK Network

Produces a comprehensive summary of the MSK network annotated with
knowledge graph data. Profiles all communities, identifies
cross-community nerve pathways, and summarizes annotation coverage.

## Usage

``` r
mskKGSummary(hg = NULL, hub = NULL, gamma = 4.3)
```

## Arguments

- hg:

  An MSKHypergraph object (NULL loads default).

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- gamma:

  Numeric, resolution parameter for community detection (default: 4.3).

## Value

An S3 object of class `"MSKKGSummary"` with:

- hg:

  Annotated MSKHypergraph

- community_profiles:

  List of MSKCommunityProfile objects

- n_communities:

  Number of detected communities

- cross_community_nerves:

  Data frame of nerves spanning communities

- annotation_coverage:

  Annotation match statistics

## Clinical Validity

This is a summary tool combining network topology with knowledge graph
annotations. Community boundaries and annotation mappings are
model-derived. Use as a research exploration tool, not for clinical
decision-making.

## Examples

``` r
if (requireNamespace("PhysioAnnotationHub", quietly = TRUE)) {
  s <- mskKGSummary()
  print(s)
}
#> Annotated MSKHypergraph: 270/270 muscles (100.0%), 173/173 bones (100.0%) matched
#> MSK Knowledge Graph Summary
#> ===========================
#> Communities: 28 
#> Modularity: 0.1958 (gamma = 4.3 )
#> 
#> Annotation Coverage:
#>   Muscles: 270/270 (100.0%)
#>   Bones:   173/173 (100.0%)
#> 
#> Community Profiles:
#>   community_1: 1 muscles, region=trunk, action=scapular_elevation
#>   community_2: 13 muscles, region=trunk, action=trunk_lateral_flexion
#>   community_3: 19 muscles, region=thorax, action=rib_depression
#>   community_4: 14 muscles, region=thorax, action=rib_depression
#>   community_5: 15 muscles, region=neck, action=cervical_lateral_flexion
#>   community_6: 7 muscles, region=trunk, action=cervical_extension
#>   community_7: 6 muscles, region=neck, action=cervical_rotation
#>   community_8: 10 muscles, region=upper_limb, action=shoulder_abduction
#>   community_9: 21 muscles, region=upper_limb, action=wrist_flexion
#>   community_10: 19 muscles, region=upper_limb, action=MCP_flexion
#>   community_11: 18 muscles, region=upper_limb, action=MCP_flexion
#>   community_12: 1 muscles, region=neck, action=head_extension
#>   community_13: 4 muscles, region=trunk, action=trunk_extension
#>   community_14: 1 muscles, region=trunk, action=trunk_extension
#>   community_15: 1 muscles, region=trunk, action=head_extension
#>   community_16: 1 muscles, region=trunk, action=cervical_extension
#>   community_17: 1 muscles, region=trunk, action=head_extension
#>   community_18: 3 muscles, region=trunk, action=cervical_rotation
#>   community_19: 1 muscles, region=neck, action=cervical_extension
#>   community_20: 9 muscles, region=neck, action=cervical_lateral_flexion
#>   community_21: 9 muscles, region=neck, action=cervical_lateral_flexion
#>   community_22: 22 muscles, region=head, action=hyoid_depression
#>   community_23: 7 muscles, region=neck, action=cervical_lateral_flexion
#>   community_24: 22 muscles, region=head, action=hyoid_depression
#>   community_25: 10 muscles, region=neck, action=vocal_cord_adduction
#>   community_26: 10 muscles, region=neck, action=vocal_cord_adduction
#>   community_27: 28 muscles, region=lower_limb, action=hip_external_rotation
#>   community_28: 13 muscles, region=thorax, action=rib_depression
#> 
#> Cross-Community Nerves (top 5):
#>   Posterior Rami Spinal Nerves: spans 16 communities (2,3,5,6,7,9,13,14,15,16,17,18,19,20,21,22)
#>   Anterior Rami Spinal Nerves: spans 6 communities (2,5,6,17,21,22)
#>   Anterior Rami Cervical Nerves: spans 4 communities (5,6,21,22)
#>   Intercostal Nerves: spans 3 communities (3,4,28)
#>   Dorsal Scapular Nerve: spans 3 communities (5,6,7)
```
