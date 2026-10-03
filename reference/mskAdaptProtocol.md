# Adapt Rehabilitation Protocol Based on Reassessment

Modifies a rehabilitation protocol based on patient reassessment
results. Uses decision rules to determine whether to advance, continue,
reduce, or modify the current protocol.

## Usage

``` r
mskAdaptProtocol(reassessment, current_protocol, hg = NULL)
```

## Arguments

- reassessment:

  An `MSKReassessment` object.

- current_protocol:

  An `MSKRehabProtocol` object from
  [`mskRehabProtocol()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskRehabProtocol.md).

- hg:

  An MSKHypergraph object (NULL loads default).

## Value

An S3 object of class `"MSKAdaptedProtocol"` with:

- decision:

  character: "advance", "continue", "reduce", "modify"

- adapted_exercises:

  data.frame with modified exercise prescription

- rationale:

  character explanation

- focus_muscles:

  character vector of muscles needing attention

- removed_exercises:

  exercises to drop

- added_exercises:

  new exercises to add

## Examples

``` r
C <- matrix(c(1,1,0,0,0, 0,1,1,0,0, 0,0,1,1,0, 0,0,0,1,1, 1,0,0,0,1, 0,1,0,1,0),
            nrow = 6, byrow = TRUE,
            dimnames = list(paste0("bone", 1:6),
              c("Biceps Brachii", "Deltoid", "Trapezius",
                "Triceps Brachii", "Brachialis")))
hg <- MSKHypergraph(C)
outcome <- mskPredictFunctionalOutcome("Biceps Brachii", hg = hg)
set.seed(1)
emg <- matrix(abs(rnorm(300 * 4)), 300, 4)
colnames(emg) <- c("Biceps Brachii", "Deltoid", "Trapezius", "Triceps Brachii")
reassessment <- mskReassess(list(emg = emg), outcome, hg = hg)
protocol <- mskRehabProtocol("Biceps Brachii", hg = hg)
adapted <- mskAdaptProtocol(reassessment, protocol, hg = hg)
print(adapted)
#> MSK Adapted Protocol
#> =====================
#> Decision: continue 
#> Rationale: Overall progress 50.0% is within 40-80% range. Continuing current phase. 
#> 
#> Adapted Exercises (1):
#>   Resistance training - Biceps Brachii: 3x12 (moderate)
```
