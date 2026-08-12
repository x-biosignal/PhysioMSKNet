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
  [`PhysioAnnotationHub::loadAnnotationHub()`](https://x-biosignal.r-universe.dev/PhysioAnnotationHub/reference/loadAnnotationHub.html).

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
if (FALSE) { # \dontrun{
hg <- mskAnnotate()
head(hg$muscle_annotations)
} # }
```
