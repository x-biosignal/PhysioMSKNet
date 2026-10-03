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
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
protocol <- mskRehabProtocol("Biceps Brachii", hg = hg)
print(protocol)
#> MSK Rehabilitation Protocol
#> ===========================
#> Injured muscles: Biceps Brachii 
#> Injury communities: 1 
#> 
#> Phase 1 - Isolated (1 muscles):
#>   Biceps Brachii [injured, comm 1]
#> 
#> Phase 2 - Intra-community (0 muscles):
#> 
#> Phase 3 - Cross-community (2 muscles):
#>   Brachialis [deg=2, comm 5]
#>   Deltoid [deg=3, comm 2]
```
