# EMG Activation Enrichment by MSK Community

Tests whether EMG activation levels differ across MSK community
assignments using a Kruskal-Wallis test.

## Usage

``` r
emgMSKEnrichment(pe, hg = NULL, gamma = 4.3, mapping = NULL)
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

- per_community:

  Data frame with community, mean/median activation

- overall_test:

  Kruskal-Wallis test result

- activation_values:

  Named numeric vector of RMS activation

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
emgMSKEnrichment(emg, hg = hg)
#> $per_community
#>   community n_muscles mean_activation median_activation
#> 1         1         1       0.9626744         0.9626744
#> 2         2         1       1.0421523         1.0421523
#> 3         3         1       1.0895216         1.0895216
#> 4         4         1       1.0226364         1.0226364
#> 
#> $overall_test
#> $overall_test$statistic
#> Kruskal-Wallis chi-squared 
#>                          3 
#> 
#> $overall_test$p_value
#> [1] 0.3916252
#> 
#> $overall_test$df
#> df 
#>  3 
#> 
#> $overall_test$method
#> [1] "Kruskal-Wallis rank sum test"
#> 
#> 
#> $activation_values
#>  Biceps Brachii         Deltoid       Trapezius Triceps Brachii 
#>       0.9626744       1.0421523       1.0895216       1.0226364 
#> 
```
