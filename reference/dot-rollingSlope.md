# Rolling linear regression slope

Computes the slope of a linear fit over a sliding window.

## Usage

``` r
.rollingSlope(x, window)
```

## Arguments

- x:

  Numeric vector of values.

- window:

  Integer, window size.

## Value

Numeric vector of slopes (length = length(x) - window + 1). Returns
empty numeric if window \> length(x).
