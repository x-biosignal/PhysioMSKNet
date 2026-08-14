# EMG envelope to neural excitation

Rectifies and normalises an EMG envelope to `[0, 1]`, with an optional
A-shape (exponential) EMG-to-activation non-linearity.

## Usage

``` r
emgToExcitation(emg, max_emg = NULL, nonlin = 0)
```

## Arguments

- emg:

  EMG envelope (already rectified/smoothed, or raw — abs is taken).

- max_emg:

  Normalising maximum (default: the signal maximum).

- nonlin:

  Non-linearity coefficient `A` (0 = linear; typical -3..0 or positive
  for a convex map).

## Value

Excitation in `[0, 1]`.
