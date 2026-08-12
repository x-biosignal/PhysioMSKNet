# Robust Regression for MSK Data

Fits a robust linear model (using MASS::rlm if available, otherwise lm).
Supports weighted regression as used in the paper.

## Usage

``` r
mskRobustRegression(x, y, weights = NULL)
```

## Arguments

- x:

  Numeric vector of predictor values.

- y:

  Numeric vector of response values.

- weights:

  Optional numeric vector of weights.

## Value

A list with:

- coefficients:

  Named vector (intercept, slope)

- r_squared:

  R-squared value

- f_statistic:

  F-statistic

- p_value:

  p-value for the regression

- residuals:

  Residual values

- fitted:

  Fitted values

- model:

  The fitted model object
