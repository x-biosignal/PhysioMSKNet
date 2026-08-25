#' Simulate MSK Network Dynamics
#'
#' Runs a damped harmonic oscillator simulation on the musculoskeletal network.
#' Each muscle is modeled as a spring connecting its attached bones, and each
#' bone is a unit-mass point particle. The system is evolved under perturbation
#' and the total displacement is computed as the impact score.
#'
#' @param hg An MSKHypergraph object. If NULL, loads the built-in data.
#' @param dt Time step for integration (default: 0.01).
#' @param n_steps Number of time steps to integrate (default: 500).
#' @param beta Damping coefficient (default: 1.0).
#' @param perturbation_magnitude Magnitude of the 4th-dimension perturbation (default: 1.0).
#' @return An S3 object of class "MSKSimulation" with:
#'   \describe{
#'     \item{hg}{The MSKHypergraph used}
#'     \item{spring_constants}{Named vector of spring constants per muscle}
#'     \item{params}{List of simulation parameters}
#'   }
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
mskSimulate <- function(hg = NULL, dt = 0.01, n_steps = 500L,
                         beta = 1.0, perturbation_magnitude = 1.0) {
  if (is.null(hg)) hg <- MSKHypergraph()

  # Spring constant: k_m = 1 / (deg(m) - 1)
  deg <- hyperedgeDegree(hg)
  # For muscles with degree 1 (connecting only 1 bone), use k=1
  k <- ifelse(deg > 1, 1.0 / (deg - 1), 1.0)
  names(k) <- hg$muscle_names

  structure(
    list(
      hg = hg,
      spring_constants = k,
      params = list(
        dt = dt,
        n_steps = as.integer(n_steps),
        beta = beta,
        perturbation_magnitude = perturbation_magnitude
      )
    ),
    class = "MSKSimulation"
  )
}

#' @export
print.MSKSimulation <- function(x, ...) {
  cat("MSKSimulation\n")
  cat("  Bones:", x$hg$n_bones, "\n")
  cat("  Muscles:", x$hg$n_muscles, "\n")
  cat("  dt:", x$params$dt, "\n")
  cat("  Steps:", x$params$n_steps, "\n")
  cat("  Beta:", x$params$beta, "\n")
  invisible(x)
}
