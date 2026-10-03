# Compare EMG Coherence with MSK Structural Connectivity

Computes EMG functional coherence and compares it with structural
adjacency from the MSK muscle graph using a Mantel test.

## Usage

``` r
emgStructuralCoherence(pe, hg = NULL, freq_band = c(20, 50), mapping = NULL)
```

## Arguments

- pe:

  A SummarizedExperiment-like object or a numeric signal matrix (time x
  channels).

- hg:

  An MSKHypergraph object (NULL loads default).

- freq_band:

  Numeric vector of length 2, frequency band in Hz for coherence
  (default: c(20, 50) for EMG beta/gamma).

- mapping:

  Optional data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

## Value

A list with:

- coherence_matrix:

  EMG functional coherence matrix

- structural_matrix:

  MSK structural adjacency (matched subset)

- correlation:

  Mantel correlation coefficient

- p_value:

  Permutation-based p-value

- mapped_muscles:

  Names of matched muscles

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
emgStructuralCoherence(emg, hg = hg, freq_band = c(20, 50))
#> $coherence_matrix
#>                 Biceps Brachii   Deltoid Trapezius Triceps Brachii
#> Biceps Brachii       1.0000000 0.7104451  1.410227        1.840081
#> Deltoid              0.7104451 1.0000000  1.089171        0.889807
#> Trapezius            1.4102271 1.0891706  1.000000        1.749700
#> Triceps Brachii      1.8400814 0.8898070  1.749700        1.000000
#> 
#> $structural_matrix
#>                 Biceps Brachii Deltoid Trapezius Triceps Brachii
#> Biceps Brachii               0       1         0               0
#> Deltoid                      1       0         1               1
#> Trapezius                    0       1         0               1
#> Triceps Brachii              0       1         1               0
#> 
#> $correlation
#> [1] -0.5768419
#> 
#> $p_value
#> [1] 0.921
#> 
#> $mapped_muscles
#> [1] "Biceps Brachii"  "Deltoid"         "Trapezius"       "Triceps Brachii"
#> 
```
