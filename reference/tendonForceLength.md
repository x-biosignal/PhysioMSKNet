# Tendon force-length curve

Normalised tendon force as a function of normalised tendon length
(`tendon length / tendon slack length`): zero below slack, rising
steeply to one maximum-isometric-force at the reference strain.

## Usage

``` r
tendonForceLength(norm_tendon_length, e0t = 0.04, kt = 3)
```

## Arguments

- norm_tendon_length:

  Tendon length divided by tendon slack length.

- e0t:

  Tendon strain at maximum isometric force (default 0.04).

- kt:

  Exponential stiffness shape (default 3).

## Value

Normalised tendon force (\>= 0).

## Examples

``` r
tendonForceLength(c(1.0, 1.02, 1.04))
#> [1] 0.0000000 0.1824255 1.0000000
```
