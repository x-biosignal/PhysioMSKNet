# Compare EMG and MSK Communities

Detects functional communities from EMG coherence and compares them with
structural communities from the MSK network.

## Usage

``` r
emgCommunityCompare(pe, hg = NULL, gamma = 4.3, mapping = NULL)
```

## Arguments

- pe:

  A SummarizedExperiment-like object or numeric signal matrix.

- hg:

  An MSKHypergraph object (NULL loads default).

- gamma:

  Resolution parameter for MSK community detection (default: 4.3).

- mapping:

  Optional data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- emg_communities:

  Named integer vector of EMG community assignments

- msk_communities:

  Named integer vector of MSK community assignments

- z_rand:

  z-Rand score comparing the two partitions

- mapping:

  The channel-to-muscle mapping used

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
emgCommunityCompare(emg, hg = hg)
#> $emg_communities
#>  Biceps Brachii         Deltoid       Trapezius Triceps Brachii 
#>               1               1               1               1 
#> 
#> $msk_communities
#>  Biceps Brachii         Deltoid       Trapezius Triceps Brachii 
#>               1               2               3               4 
#> 
#> $z_rand
#> [1] 0
#> 
#> $mapping
#>   channel_idx    channel_name muscle_idx     muscle_name match_quality
#> 1           1  Biceps Brachii          1  Biceps Brachii             1
#> 2           2         Deltoid          2         Deltoid             1
#> 3           3       Trapezius          3       Trapezius             1
#> 4           4 Triceps Brachii          4 Triceps Brachii             1
#> 
```
