# Passive force-length multiplier

Exponential passive element (Thelen 2003): zero below optimal length,
rising as the fiber is stretched beyond it.

## Usage

``` r
forceLengthPassive(norm_len, k_pe = 4, e0 = 0.6)
```

## Arguments

- norm_len:

  Normalised fiber length.

- k_pe:

  Exponential shape (default 4).

- e0:

  Passive strain at maximum isometric force (default 0.6).

## Value

Passive multiplier (\>= 0).
