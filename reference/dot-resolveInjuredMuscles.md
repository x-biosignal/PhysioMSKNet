# Resolve injured muscle names/indices with fuzzy matching

Resolves muscle identifiers (names or indices) against hypergraph,
delegating to `.resolveMuscleIndices` from bridge-clinical.R.

## Usage

``` r
.resolveInjuredMuscles(injured_muscles, hg)
```

## Arguments

- injured_muscles:

  Character or integer vector of muscle names/indices.

- hg:

  An MSKHypergraph object.

## Value

Integer vector of validated muscle indices.
