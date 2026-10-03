# Annotate MSK Hypergraph with Knowledge Graph Data

Attaches anatomical annotations from PhysioAnnotationHub to an MSK
hypergraph, matching muscle and bone names between the two data sources.
Annotations include body region, innervation, actions, and spinal
levels.

## Usage

``` r
mskAnnotate(hg = NULL, hub = NULL)
```

## Arguments

- hg:

  An MSKHypergraph object. If NULL, loads default 173-bone/270-muscle
  network.

- hub:

  A PhysioAnnotationHub object. If NULL, loads via
  [`PhysioAnnotationHub::loadAnnotationHub()`](https://x-biosignal.github.io/PhysioAnnotationHub//reference/loadAnnotationHub.html).

## Value

An annotated MSKHypergraph with additional fields:

- muscle_annotations:

  Data frame of muscle annotations merged from hub

- bone_annotations:

  Data frame of bone annotations merged from hub

- annotated:

  Logical flag indicating annotations are attached

- annotation_coverage:

  List with muscle and bone match rates

## Clinical Validity

Annotations are derived from PhysioAnnotationHub's curated knowledge
graph. Name matching uses fuzzy matching with a 0.2 edit distance
threshold, which may produce incorrect matches for similarly named
structures. Always verify critical annotations against primary
anatomical references.

## References

Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.

## Examples

``` r
if (requireNamespace("PhysioAnnotationHub", quietly = TRUE)) {
  hg <- mskAnnotate()
  head(hg$muscle_annotations)
}
#> Annotated MSKHypergraph: 270/270 muscles (100.0%), 173/173 bones (100.0%) matched
#>                   muscle_name body_region sub_region      action_primary
#> 1                   Trapezius       trunk       back  scapular_elevation
#> 2            Latissimus Dorsi       trunk       back  shoulder_extension
#> 3 Serratus Posterior Superior       trunk       back       rib_elevation
#> 4 Serratus Posterior Inferior       trunk       back      rib_depression
#> 5            Levator Scapulae       trunk       back  scapular_elevation
#> 6              Rhomboid Minor       trunk       back scapular_retraction
#>           action_secondary                 nerve spinal_level muscle_type
#> 1      scapular_retraction  Accessory Nerve (XI)        C3-C4    skeletal
#> 2       shoulder_adduction   Thoracodorsal Nerve        C6-C8    skeletal
#> 3              respiration    Intercostal Nerves        T2-T5    skeletal
#> 4              respiration    Intercostal Nerves       T9-T12    skeletal
#> 5 cervical_lateral_flexion Dorsal Scapular Nerve        C3-C5    skeletal
#> 6       scapular_elevation Dorsal Scapular Nerve        C4-C5    skeletal
#>   joint_crossed
#> 1      shoulder
#> 2      shoulder
#> 3        thorax
#> 4        thorax
#> 5      shoulder
#> 6      shoulder
```
