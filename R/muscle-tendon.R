# Muscle-tendon kinematics: moment arms, MTU length/velocity and optional
# Hill-type normalized fiber length/velocity from joint angles.
#
# Moment arm is defined as r_j = -dL/dtheta_j for a muscle-tendon-unit (MTU)
# length model L(theta) (OpenSim GeometryPath convention), so the MTU
# lengthening velocity is
#     dL/dt = sum_j (dL/dtheta_j) * omega_j = -sum_j r_j * omega_j,
# which the implementation preserves exactly by deriving the moment arms from
# the same polynomial path model used for the length.

#' Muscle moment arms
#'
#' Returns muscle moment arms. With no `model`, this is the anatomical lookup
#' table promoted from the package's internal reference values (signed by the
#' agonist/antagonist direction); with a [musclePath()] `model`, the moment arm
#' is the joint-angle-dependent value `-dL/dtheta` evaluated at `angles`.
#'
#' @param muscle Optional muscle name to filter the lookup table (case
#'   insensitive). Ignored when `model` is supplied.
#' @param joint Optional joint name to filter the lookup table.
#' @param model Optional [musclePath()] model; when supplied, moment arms are
#'   computed from the path derivative at `angles`.
#' @param angles Named numeric vector of joint angles in radians (one per joint
#'   the `model` crosses); required when `model` is supplied.
#'
#' @return Without `model`: a data frame with `muscle_name`, `joint_name`,
#'   `moment_arm_m` (magnitude), `direction`, and `signed_moment_arm_m`. With
#'   `model`: a named numeric vector of signed moment arms (m) per joint.
#'
#' @references
#' Sherman MA, Seth A, Delp SL (2013). "What is a moment arm? Calculating muscle
#' effectiveness in biomechanical models using generalized coordinates."
#' @seealso [musclePath()], [muscleTendonKinematics()]
#' @export
#' @examples
#' momentArm("Gastrocnemius")
#' mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05)))
#' momentArm(model = mp, angles = c(ankle = 0.2))
momentArm <- function(muscle = NULL, joint = NULL, model = NULL,
                      angles = NULL) {
  if (!is.null(model)) {
    if (!inherits(model, "muscle_path")) {
      stop("`model` must be a muscle_path object from musclePath().",
           call. = FALSE)
    }
    ang <- .mtu_angle_vector(angles, model$joints)
    return(.mtu_moment_arms(model, ang))
  }

  tab <- .momentArmLookup()
  tab$signed_moment_arm_m <- tab$moment_arm_m * tab$direction
  if (!is.null(muscle)) {
    keep <- tolower(trimws(tab$muscle_name)) %in% tolower(trimws(muscle))
    tab <- tab[keep, , drop = FALSE]
  }
  if (!is.null(joint)) {
    tab <- tab[tolower(trimws(tab$joint_name)) %in% tolower(trimws(joint)),
               , drop = FALSE]
  }
  tab[, c("muscle_name", "joint_name", "moment_arm_m", "direction",
          "signed_moment_arm_m")]
}

#' Define a polynomial muscle-tendon path model
#'
#' Describes muscle-tendon-unit (MTU) length as a polynomial in the joint angles
#' the muscle crosses:
#' \deqn{L(\theta) = L_{slack} + \sum_j \sum_k c_{jk}\,\theta_j^{k}.}
#' Moment arms follow as `-dL/dtheta_j` (Menegaldo et al. 2004). Supply `hill`
#' parameters to enable normalized fiber length/velocity in
#' [muscleTendonKinematics()].
#'
#' @param joints Character vector of joint names the muscle crosses.
#' @param coefficients Named list (by joint) of polynomial coefficient vectors
#'   `c(c1, c2, ...)`; the term of order `k` is `c_k * theta^k` (no constant
#'   term -- put the length offset in `slack_length`). Angles are in radians, so
#'   coefficients carry units of m / rad^k.
#' @param slack_length MTU length (m) at all-zero joint angles (default 0).
#' @param hill Optional list with `optimal_fiber_length`, `tendon_slack_length`,
#'   `pennation` (rad, default 0) and `max_contraction_velocity` (optimal fiber
#'   lengths per second, default 10) for Hill-type fiber kinematics.
#' @param muscle Optional muscle name (metadata).
#'
#' @return A `muscle_path` object.
#' @references Menegaldo LL, et al. (2004). J Biomech 37(9):1447-1453.
#' @seealso [muscleTendonKinematics()], [defaultMusclePath()]
#' @export
#' @examples
#' # gastrocnemius crosses knee and ankle
#' musclePath(c("knee", "ankle"),
#'            coefficients = list(knee = c(0.03), ankle = c(-0.05, 0.01)),
#'            slack_length = 0.42)
musclePath <- function(joints, coefficients, slack_length = 0,
                       hill = NULL, muscle = NULL) {
  if (!is.character(joints) || length(joints) < 1L || anyNA(joints)) {
    stop("`joints` must be a non-empty character vector.", call. = FALSE)
  }
  if (anyDuplicated(joints)) {
    stop("`joints` must be unique.", call. = FALSE)
  }
  if (!is.list(coefficients) || is.null(names(coefficients)) ||
      !all(joints %in% names(coefficients))) {
    stop("`coefficients` must be a named list with an entry per joint.",
         call. = FALSE)
  }
  for (j in joints) {
    if (!is.numeric(coefficients[[j]]) || length(coefficients[[j]]) < 1L ||
        anyNA(coefficients[[j]])) {
      stop(sprintf("coefficients[['%s']] must be a non-empty numeric vector.",
                   j), call. = FALSE)
    }
  }
  if (!is.numeric(slack_length) || length(slack_length) != 1L ||
      !is.finite(slack_length)) {
    stop("`slack_length` must be a single finite number.", call. = FALSE)
  }
  if (!is.null(hill)) {
    hill <- .mtu_check_hill(hill)
  }

  out <- list(
    muscle = muscle,
    joints = joints,
    coefficients = coefficients[joints],
    slack_length = slack_length,
    hill = hill
  )
  class(out) <- "muscle_path"
  out
}

#' Build a linear muscle-path model from the moment-arm lookup
#'
#' Constructs a [musclePath()] with a constant (angle-independent) moment arm
#' taken from the anatomical lookup table, i.e. a linear MTU length
#' `L(theta) = slack_length - r * theta`. Useful as a default path when no
#' subject-specific polynomial model is available.
#'
#' @param muscle Muscle name (as in [momentArm()]).
#' @param joint Optional joint name (required only if the muscle appears for
#'   more than one joint).
#' @param slack_length MTU slack length (m) offset (default 0.3).
#' @param hill Optional Hill parameters (see [musclePath()]).
#' @return A `muscle_path` object with a constant moment arm.
#' @seealso [musclePath()], [muscleTendonKinematics()]
#' @export
#' @examples
#' defaultMusclePath("Soleus")
defaultMusclePath <- function(muscle, joint = NULL, slack_length = 0.3,
                              hill = NULL) {
  if (!is.character(muscle) || length(muscle) != 1L || is.na(muscle)) {
    stop("`muscle` must be a single muscle name.", call. = FALSE)
  }
  tab <- momentArm(muscle = muscle, joint = joint)
  if (nrow(tab) == 0L) {
    stop("muscle '", muscle, "' not found in the moment-arm lookup.",
         call. = FALSE)
  }
  if (nrow(tab) > 1L) {
    stop("muscle '", muscle, "' spans multiple joints; specify `joint`.",
         call. = FALSE)
  }
  j <- tab$joint_name[1]
  # constant moment arm r = signed value => L = slack - r*theta (dL/dtheta = -r)
  musclePath(joints = j,
             coefficients = stats::setNames(list(-tab$signed_moment_arm_m[1]), j),
             slack_length = slack_length, hill = hill, muscle = tab$muscle_name[1])
}

#' Muscle-tendon length, velocity and moment arms from joint angles
#'
#' Evaluates a [musclePath()] over one or more poses: MTU length `L(theta)`,
#' moment arms `-dL/dtheta_j`, and MTU lengthening velocity
#' `dL/dt = -sum_j r_j * omega_j`. When the model carries `hill` parameters,
#' rigid-tendon normalized fiber length and velocity are also returned.
#'
#' @param model A [musclePath()] model.
#' @param angles Joint angles in radians: a named numeric vector (single pose),
#'   or an `n_frames x n_joints` matrix / data frame / named list of curves with
#'   columns/names matching the model's joints.
#' @param angular_velocities Joint angular velocities (rad/s), same shape as
#'   `angles`. If `NULL` for a trajectory, they are estimated from `angles` by
#'   central differences (requires `sampling_rate`); for a single pose they
#'   default to zero.
#' @param sampling_rate Sampling rate (Hz) used to differentiate `angles` when
#'   `angular_velocities` is `NULL`.
#'
#' @return A `muscle_tendon_kinematics` object: a list with `length` (m),
#'   `velocity` (m/s), `moment_arms` (`n_frames x n_joints`, m), `joints`, and,
#'   when `hill` is set, `norm_fiber_length` and `norm_fiber_velocity`.
#'
#' @references
#' Zajac FE (1989). "Muscle and tendon: properties, models, scaling, and
#' application to biomechanics and motor control." Thelen DG (2003).
#' @seealso [musclePath()], [momentArm()]
#' @export
#' @examples
#' mp <- musclePath("ankle", coefficients = list(ankle = c(-0.05, 0.01)),
#'                  slack_length = 0.3)
#' muscleTendonKinematics(mp, angles = c(ankle = 0.1),
#'                        angular_velocities = c(ankle = 2))
muscleTendonKinematics <- function(model, angles, angular_velocities = NULL,
                                   sampling_rate = NULL) {
  if (!inherits(model, "muscle_path")) {
    stop("`model` must be a muscle_path object from musclePath().",
         call. = FALSE)
  }
  A <- .mtu_angle_matrix(angles, model$joints)
  n_frames <- nrow(A)

  V <- .mtu_velocity_matrix(angular_velocities, model$joints, A, sampling_rate)

  # length and per-joint dL/dtheta over all frames
  length_out <- rep(model$slack_length, n_frames)
  dLdq <- matrix(0, n_frames, length(model$joints),
                 dimnames = list(NULL, model$joints))
  for (j in model$joints) {
    cj <- model$coefficients[[j]]
    length_out <- length_out + .poly_eval(cj, A[, j])
    dLdq[, j] <- .poly_deriv(cj, A[, j])
  }
  moment_arms <- -dLdq
  # dL/dt = sum_j (dL/dtheta_j) * omega_j = -sum_j r_j * omega_j
  velocity <- -rowSums(moment_arms * V)

  out <- list(
    length = unname(length_out),
    velocity = unname(velocity),
    moment_arms = moment_arms,
    joints = model$joints,
    n_frames = n_frames
  )

  if (!is.null(model$hill)) {
    h <- model$hill
    cosp <- cos(h$pennation)
    fiber_length <- (out$length - h$tendon_slack_length) / cosp
    fiber_velocity <- out$velocity / cosp
    out$norm_fiber_length <- fiber_length / h$optimal_fiber_length
    out$norm_fiber_velocity <- fiber_velocity /
      (h$optimal_fiber_length * h$max_contraction_velocity)
    if (any(out$norm_fiber_length <= 0)) {
      warning("MTU length falls to or below the tendon slack length for some ",
              "frames; the rigid-tendon normalized fiber length is non-physical ",
              "(<= 0). Check slack_length vs hill$tendon_slack_length.",
              call. = FALSE)
    }
  }

  class(out) <- "muscle_tendon_kinematics"
  out
}

# --- internal helpers --------------------------------------------------------

#' @keywords internal
#' @noRd
.poly_eval <- function(coef, theta) {
  # sum_k coef[k] * theta^k, k = 1..length(coef)
  out <- numeric(length(theta))
  for (k in seq_along(coef)) {
    out <- out + coef[k] * theta^k
  }
  out
}

#' @keywords internal
#' @noRd
.poly_deriv <- function(coef, theta) {
  # d/dtheta sum_k coef[k] theta^k = sum_k k*coef[k]*theta^(k-1)
  out <- numeric(length(theta))
  for (k in seq_along(coef)) {
    out <- out + k * coef[k] * theta^(k - 1L)
  }
  out
}

#' Signed moment arms (-dL/dtheta_j) at a single pose (named angle vector)
#' @keywords internal
#' @noRd
.mtu_moment_arms <- function(model, angles) {
  ma <- vapply(model$joints, function(j) {
    -.poly_deriv(model$coefficients[[j]], angles[[j]])
  }, numeric(1))
  names(ma) <- model$joints
  ma
}

#' @keywords internal
#' @noRd
.mtu_angle_vector <- function(angles, joints) {
  if (is.null(angles) || is.null(names(angles))) {
    stop("`angles` must be a named numeric vector covering: ",
         paste(joints, collapse = ", "), ".", call. = FALSE)
  }
  miss <- setdiff(joints, names(angles))
  if (length(miss) > 0) {
    stop("angles missing joints: ", paste(miss, collapse = ", "), ".",
         call. = FALSE)
  }
  a <- angles[joints]
  if (!is.numeric(a) || !all(is.finite(a))) {
    stop("angles must be finite numeric.", call. = FALSE)
  }
  a
}

#' @keywords internal
#' @noRd
.mtu_angle_matrix <- function(angles, joints) {
  if (is.list(angles) && !is.data.frame(angles) && !is.matrix(angles)) {
    if (is.null(names(angles))) {
      stop("a list of angle curves must be named by joint.", call. = FALSE)
    }
    lens <- vapply(angles, length, integer(1))
    if (length(unique(lens)) != 1L) {
      stop("all angle curves must have the same length.", call. = FALSE)
    }
    angles <- do.call(cbind, angles)
  }
  if (is.null(dim(angles))) {
    # single pose: a named numeric vector
    return(matrix(.mtu_angle_vector(angles, joints), nrow = 1,
                  dimnames = list(NULL, joints)))
  }
  m <- as.matrix(angles)
  if (is.null(colnames(m))) {
    if (ncol(m) != length(joints)) {
      stop("angles matrix has no column names and the wrong number of ",
           "columns.", call. = FALSE)
    }
    colnames(m) <- joints
  }
  miss <- setdiff(joints, colnames(m))
  if (length(miss) > 0) {
    stop("angles missing joints: ", paste(miss, collapse = ", "), ".",
         call. = FALSE)
  }
  m <- m[, joints, drop = FALSE]
  if (!is.numeric(m) || !all(is.finite(m))) {
    stop("angles must be finite numeric.", call. = FALSE)
  }
  m
}

#' @keywords internal
#' @noRd
.mtu_velocity_matrix <- function(angular_velocities, joints, A, sampling_rate) {
  n_frames <- nrow(A)
  if (!is.null(angular_velocities)) {
    V <- .mtu_angle_matrix(angular_velocities, joints)
    if (nrow(V) != n_frames) {
      stop("angular_velocities must have the same number of frames as angles.",
           call. = FALSE)
    }
    return(V)
  }
  if (n_frames == 1L) {
    return(matrix(0, 1, length(joints), dimnames = list(NULL, joints)))
  }
  if (is.null(sampling_rate) || !is.numeric(sampling_rate) ||
      length(sampling_rate) != 1L || !is.finite(sampling_rate) ||
      sampling_rate <= 0) {
    stop("provide `angular_velocities`, or a positive finite `sampling_rate` ",
         "to differentiate the angle trajectory.", call. = FALSE)
  }
  dt <- 1 / sampling_rate
  V <- apply(A, 2, function(x) {
    n <- length(x)
    g <- numeric(n)
    g[2:(n - 1L)] <- (x[3:n] - x[1:(n - 2L)]) / (2 * dt)     # central
    g[1] <- (x[2] - x[1]) / dt                                # forward
    g[n] <- (x[n] - x[n - 1L]) / dt                           # backward
    g
  })
  dim(V) <- c(n_frames, length(joints))
  colnames(V) <- joints
  V
}

#' @keywords internal
#' @noRd
.mtu_check_hill <- function(hill) {
  if (!is.list(hill) || is.null(hill$optimal_fiber_length) ||
      is.null(hill$tendon_slack_length)) {
    stop("`hill` must provide optimal_fiber_length and tendon_slack_length.",
         call. = FALSE)
  }
  hill$pennation <- hill$pennation %||% 0
  hill$max_contraction_velocity <- hill$max_contraction_velocity %||% 10

  finite_scalar <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
      stop(sprintf("hill$%s must be a single finite number.", name),
           call. = FALSE)
    }
  }
  finite_scalar(hill$optimal_fiber_length, "optimal_fiber_length")
  finite_scalar(hill$tendon_slack_length, "tendon_slack_length")
  finite_scalar(hill$pennation, "pennation")
  finite_scalar(hill$max_contraction_velocity, "max_contraction_velocity")

  if (hill$optimal_fiber_length <= 0) {
    stop("hill$optimal_fiber_length must be positive.", call. = FALSE)
  }
  if (hill$tendon_slack_length < 0) {
    stop("hill$tendon_slack_length must be non-negative.", call. = FALSE)
  }
  if (abs(hill$pennation) >= pi / 2) {
    stop("hill$pennation must be within (-pi/2, pi/2).", call. = FALSE)
  }
  if (hill$max_contraction_velocity <= 0) {
    stop("hill$max_contraction_velocity must be positive.", call. = FALSE)
  }
  hill
}

#' @export
print.muscle_path <- function(x, ...) {
  cat("<muscle_path>",
      if (!is.null(x$muscle)) x$muscle else "(unnamed)", "\n")
  cat("  joints      :", paste(x$joints, collapse = ", "), "\n")
  cat("  slack length:", x$slack_length, "m\n")
  cat("  hill        :", if (is.null(x$hill)) "no" else "yes", "\n")
  invisible(x)
}

#' @export
print.muscle_tendon_kinematics <- function(x, ...) {
  cat("<muscle_tendon_kinematics>", x$n_frames, "frame(s)\n")
  cat("  joints  :", paste(x$joints, collapse = ", "), "\n")
  cat(sprintf("  length  : %.4f .. %.4f m\n",
              min(x$length), max(x$length)))
  cat(sprintf("  velocity: %.4f .. %.4f m/s\n",
              min(x$velocity), max(x$velocity)))
  if (!is.null(x$norm_fiber_length)) {
    cat(sprintf("  norm fiber length: %.3f .. %.3f\n",
                min(x$norm_fiber_length), max(x$norm_fiber_length)))
  }
  invisible(x)
}
