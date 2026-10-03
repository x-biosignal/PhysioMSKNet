# Track Compensation Pattern Evolution Over Time

Tracks changes in compensation patterns across multiple timepoints,
identifying onset, resolution, and trends.

## Usage

``` r
mskCompensationEvolution(
  timepoints_emg,
  injured_muscles,
  hg = NULL,
  emg_mapping = NULL,
  sr = NULL,
  z_threshold = 1.96
)
```

## Arguments

- timepoints_emg:

  Named list of EMG matrices. The first element is treated as baseline.

- injured_muscles:

  Character vector of injured muscle names or integer indices.

- hg:

  An MSKHypergraph object (NULL loads default).

- emg_mapping:

  Optional pre-computed data.frame from
  [`emgToMSKMapping()`](https://x-biosignal.github.io/PhysioMSKNet/reference/emgToMSKMapping.md).

- sr:

  Optional sampling rate override.

- z_threshold:

  Numeric, z-score threshold (default: 1.96).

## Value

An S3 object of class `"MSKCompensationEvolution"` with:

- evolution_table:

  Data.frame of per-timepoint per-muscle z-scores

- onset_timepoint:

  Per-muscle first timepoint of compensation

- resolution_timepoint:

  Per-muscle first timepoint of resolution

- trend:

  Per-muscle trend classification

- summary:

  Data.frame of per-timepoint summary statistics

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
mk <- function(s) { set.seed(s); m <- matrix(abs(rnorm(300 * 4)), 300, 4)
  colnames(m) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii"); m }
tps <- list(week0 = mk(1), week2 = mk(2), week4 = mk(3))
evolution <- mskCompensationEvolution(tps, "Biceps Brachii", hg = hg)
evolution
#> MSK Compensation Evolution
#> ==========================
#> Timepoint summary:
#>   week2: 0 compensating, mean z = -0.10
#>   week4: 0 compensating, mean z = -0.07
#> 
#> Muscle trends:
#>   Deltoid: absent (onset: none, resolution: ongoing)
#>   Trapezius: absent (onset: none, resolution: ongoing)
#>   Triceps Brachii: absent (onset: none, resolution: ongoing)
```
