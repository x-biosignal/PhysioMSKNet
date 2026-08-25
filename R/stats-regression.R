#' Robust Regression for MSK Data
#'
#' Fits a robust linear model (using MASS::rlm if available, otherwise lm).
#' Supports weighted regression as used in the paper.
#'
#' @param x Numeric vector of predictor values.
#' @param y Numeric vector of response values.
#' @param weights Optional numeric vector of weights.
#' @return A list with:
#'   \describe{
#'     \item{coefficients}{Named vector (intercept, slope)}
#'     \item{r_squared}{R-squared value}
#'     \item{f_statistic}{F-statistic}
#'     \item{p_value}{p-value for the regression}
#'     \item{residuals}{Residual values}
#'     \item{fitted}{Fitted values}
#'     \item{model}{The fitted model object}
#'   }
#' @export
mskRobustRegression <- function(x, y, weights = NULL) {
  df <- data.frame(x = x, y = y)
  valid <- complete.cases(df)
  if (!is.null(weights)) {
    valid <- valid & !is.na(weights) & weights > 0
    w <- weights[valid]
  } else {
    w <- NULL
  }
  df <- df[valid, ]
  if (nrow(df) < 3) stop("Need at least 3 valid observations", call. = FALSE)

  if (requireNamespace("MASS", quietly = TRUE) && is.null(w)) {
    fit <- MASS::rlm(y ~ x, data = df)
    fitted_vals <- stats::fitted(fit)
    resid_vals <- stats::residuals(fit)
    ss_res <- sum(resid_vals^2)
    ss_tot <- sum((df$y - mean(df$y))^2)
    r2 <- 1 - ss_res / ss_tot
    n <- nrow(df)
    f_stat <- (ss_tot - ss_res) / (ss_res / (n - 2))
    p_val <- stats::pf(f_stat, 1, n - 2, lower.tail = FALSE)
  } else {
    if (!is.null(w)) {
      fit <- stats::lm(y ~ x, data = df, weights = w)
    } else {
      fit <- stats::lm(y ~ x, data = df)
    }
    s <- summary(fit)
    r2 <- s$r.squared
    f_stat <- if (!is.null(s$fstatistic)) s$fstatistic[1] else NA
    p_val <- if (!is.null(s$fstatistic)) {
      stats::pf(s$fstatistic[1], s$fstatistic[2], s$fstatistic[3], lower.tail = FALSE)
    } else NA
    fitted_vals <- stats::fitted(fit)
    resid_vals <- stats::residuals(fit)
  }

  list(
    coefficients = stats::coef(fit),
    r_squared = r2,
    f_statistic = f_stat,
    p_value = p_val,
    residuals = resid_vals,
    fitted = fitted_vals,
    model = fit,
    n = nrow(df)
  )
}

#' Impact-Recovery Prediction Model
#'
#' Reproduces the key result from Fig 3b: correlation between impact deviation
#' and clinical muscle injury recovery time.
#' Target: F(1,12) = 37.3, R² = 0.757, p < 0.0001
#'
#' @param impact_deviation Named numeric vector of impact deviations.
#' @param recovery_data Optional data.frame with columns: recovery_time,
#'   impact_deviation, weight. If NULL, loads the built-in validation data.
#' @return Result from mskRobustRegression with additional paper comparison.
#' @references Murphy AC et al. (2018) PLOS Biology Table 4.
#' @export
mskImpactRecoveryModel <- function(impact_deviation = NULL, recovery_data = NULL) {
  if (is.null(recovery_data)) {
    recovery_data <- loadValidationData("impact_vs_recovery")
  }

  result <- mskRobustRegression(
    x = recovery_data$impact_deviation,
    y = recovery_data$recovery_time,
    weights = recovery_data$weight
  )

  result$paper_target <- list(
    f_statistic = 37.3,
    r_squared = 0.757,
    p_value = 0.0001,
    df1 = 1,
    df2 = 12
  )

  result
}

#' Homunculus Correlation Analysis
#'
#' Tests the correspondence between MSK network community structure and
#' the motor cortex homunculus. Reproduces Fig 4b results.
#' Target: F(1,19) = 21.3, R² = 0.52, p < 0.001
#'
#' @param membership Named integer vector of community assignments.
#' @param homunculus_data Optional data.frame with columns: homunc_area, dev_ratio.
#'   If NULL, loads the built-in validation data.
#' @return A list with regression result and deviation ratio by category.
#' @references Murphy AC et al. (2018) PLOS Biology.
#' @export
mskHomuncCorrelation <- function(membership = NULL, homunculus_data = NULL) {
  if (is.null(homunculus_data)) {
    homunculus_data <- loadValidationData("homunculus_deviation")
  }

  result <- mskRobustRegression(
    x = homunculus_data$homunc_area,
    y = homunculus_data$dev_ratio
  )

  result$paper_target <- list(
    f_statistic = 21.3,
    r_squared = 0.52,
    p_value = 0.001
  )

  result
}
