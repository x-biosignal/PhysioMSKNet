# Query Anatomical Pathway Between Entities

Finds the shortest anatomical pathway between two entities (muscles,
bones, nerves, etc.) in the knowledge graph. Useful for tracing
innervation chains, biomechanical linkages, and anatomical
relationships.

## Usage

``` r
mskPathwayQuery(from, to, hub = NULL, max_depth = 5L)
```

## Arguments

- from:

  Character, the source entity name (e.g., "Biceps Brachii").

- to:

  Character, the target entity name (e.g., "C5").

- hub:

  A PhysioAnnotationHub object (NULL loads default).

- max_depth:

  Integer, maximum BFS depth (default: 5).

## Value

A list with:

- path:

  Character vector of entities along the path

- predicates:

  Character vector of relationship types between entities

- depth:

  Integer, path length

- description:

  Human-readable path description

- found:

  Logical, whether a path was found

## Clinical Validity

Pathways reflect relationships encoded in the knowledge graph. The
shortest path in the KG may not correspond to the most clinically
relevant connection. Always verify pathway interpretations against
anatomical references.

## Examples

``` r
if (FALSE) { # \dontrun{
path <- mskPathwayQuery("Biceps Brachii", "C5")
cat(path$description, "\n")
} # }
```
