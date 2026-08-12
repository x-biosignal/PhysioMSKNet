# Build MSKHypergraph from OpenSim Model

Parses an OpenSim .osim file to extract muscle-bone attachment points
and constructs a subject-specific MSKHypergraph.

## Usage

``` r
opensimToMSKHypergraph(model = NULL, model_path = NULL)
```

## Arguments

- model:

  An optional PhysioOpenSimModel object. If provided, the model's path
  is used and results are cross-validated.

- model_path:

  Character, path to a .osim file. Required if `model` is NULL.

## Value

An `MSKHypergraph` object with subject-specific anatomy.

## Note

Requires the `xml2` package.

## Examples

``` r
if (FALSE) { # \dontrun{
hg <- opensimToMSKHypergraph(model_path = "gait2392.osim")
print(hg)
} # }
```
