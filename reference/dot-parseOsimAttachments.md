# Parse muscle-bone attachments from .osim XML

Extracts PathPoint body references per muscle from an OpenSim .osim
file.

## Usage

``` r
.parseOsimAttachments(model_path)
```

## Arguments

- model_path:

  Character, path to .osim file.

## Value

A data.frame with columns: muscle_name, body_name (deduplicated pairs).
