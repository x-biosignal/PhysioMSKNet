# Force-velocity multiplier

Normalised Hill force-velocity relation. Velocity is normalised fiber
velocity with negative = shortening (concentric), positive = lengthening
(eccentric).

## Usage

``` r
forceVelocity(norm_vel, af = 0.25, f_ecc = 1.8, k_ecc = 0.15)
```

## Arguments

- norm_vel:

  Normalised fiber velocity (concentric \< 0).

- af:

  Hill shape parameter for shortening (default 0.25).

- f_ecc:

  Eccentric force asymptote (default 1.8).

- k_ecc:

  Eccentric saturation constant (default 0.15).

## Value

Multiplier (0 at max shortening, 1 at isometric, up to `f_ecc`).
