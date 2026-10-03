# Map EMG Channels to MSK Muscles

Matches EMG channel names from a PhysioExperiment/SummarizedExperiment
object to muscles in an MSK hypergraph.

## Usage

``` r
emgToMSKMapping(pe, hg = NULL, method = c("exact", "fuzzy"), threshold = 0.8)
```

## Arguments

- pe:

  A SummarizedExperiment-like object with channel names in
  `colData(pe)$name` or `colnames(assay(pe))`.

- hg:

  An MSKHypergraph object (NULL loads default).

- method:

  Character, matching method: "exact" or "fuzzy".

- threshold:

  Numeric, fuzzy matching threshold (default: 0.8).

## Value

A data.frame with columns: channel_idx, channel_name, muscle_idx,
muscle_name, match_quality.

## Examples

``` r
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
mapping <- emgToMSKMapping(emg, method = "fuzzy")
mapping
#>   channel_idx    channel_name muscle_idx     muscle_name match_quality
#> 1           1  Biceps Brachii         19  Biceps Brachii             1
#> 2           2         Deltoid          9         Deltoid             1
#> 3           3       Trapezius          1       Trapezius             1
#> 4           4 Triceps Brachii         21 Triceps Brachii             1
```
