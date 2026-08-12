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
if (FALSE) { # \dontrun{
protocol <- mskRehabProtocol("Biceps Brachii")
adapted <- mskAdaptProtocol(reassessment, protocol)
print(adapted)
} # }
```
