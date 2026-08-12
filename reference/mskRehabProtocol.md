# Rehabilitation Protocol Based on Network Topology

Generates a phased rehabilitation protocol using MSK network community
structure and shortest path distances to determine exercise progression.

## Usage

``` r
mskRehabProtocol(injury_muscles, hg = NULL, n_phases = 3L)
```

## Arguments

- injury_muscles:

  Character or integer vector identifying injured muscles.

- hg:

  An MSKHypergraph object (NULL loads default).

- n_phases:

  Integer, number of rehabilitation phases (default: 3).

## Value

An S3 object of class `"MSKRehabProtocol"` with per-phase muscle lists.

## Clinical Validity

Phase ordering is based on network topology (community membership and
shortest path distance), not validated rehabilitation protocols. Use as
a research exploration tool, not clinical guidance.

## Examples

``` r
if (FALSE) { # \dontrun{
protocol <- mskRehabProtocol("Biceps Brachii")
print(protocol)
} # }
```
