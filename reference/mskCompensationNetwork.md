# Build Compensation Network

Constructs a compensation-weighted subgraph from compensation detection
results, identifying compensation chains and hub muscles.

## Usage

``` r
mskCompensationNetwork(compensation_result, hg = NULL, emg_mapping = NULL)
```

## Arguments

- compensation_result:

  An `"MSKCompensation"` object.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- adjacency:

  Weighted compensation adjacency matrix

- chains:

  List of compensation chains

- hub_muscles:

  Muscles in multiple compensation chains

- community_involvement:

  MSK communities affected by compensation

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
set.seed(1); emg_base <- matrix(abs(rnorm(300 * 4)), 300, 4)
set.seed(2); emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- colnames(emg_base) <-
  c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
result <- mskDetectCompensation(emg, emg_base, "Biceps Brachii", hg = hg)
net <- mskCompensationNetwork(result, hg = hg)
net
#> $adjacency
#> <0 x 0 matrix>
#> 
#> $chains
#> list()
#> 
#> $hub_muscles
#> character(0)
#> 
#> $community_involvement
#> integer(0)
#> 
```
