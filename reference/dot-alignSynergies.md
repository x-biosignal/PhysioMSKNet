# Greedy cosine alignment of two synergy weight matrices

Aligns columns of W2 to best match columns of W1 using greedy maximum
cosine similarity (Hungarian algorithm approximation).

## Usage

``` r
.alignSynergies(W1, W2)
```

## Arguments

- W1:

  Numeric matrix (muscles x synergies).

- W2:

  Numeric matrix (muscles x synergies, same dimensions as W1).

## Value

A list with: permutation (integer vector), cosine_similarities (numeric
vector per aligned pair), mean_cosine (scalar).
