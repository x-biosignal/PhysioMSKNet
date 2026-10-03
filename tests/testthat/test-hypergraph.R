library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-hypergraph.R -- Tests for hypergraph construction and projections
# ===========================================================================

test_that("MSKHypergraph() creates a valid S3 object", {
  hg <- MSKHypergraph()

  expect_s3_class(hg, "MSKHypergraph")
  expect_type(hg, "list")

  # Check all required fields
  expect_true("C" %in% names(hg))
  expect_true("n_bones" %in% names(hg))
  expect_true("n_muscles" %in% names(hg))
  expect_true("bone_names" %in% names(hg))
  expect_true("muscle_names" %in% names(hg))
  expect_true("muscle_meta" %in% names(hg))
})

test_that("MSKHypergraph(NULL) loads default data", {
  hg <- MSKHypergraph(NULL)

  expect_s3_class(hg, "MSKHypergraph")
  expect_equal(hg$n_bones, 173)
  expect_equal(hg$n_muscles, 270)
})

test_that("Dimensions match: 173 bones, 270 muscles", {
  hg <- MSKHypergraph()

  expect_equal(hg$n_bones, 173)
  expect_equal(hg$n_muscles, 270)
  expect_equal(nrow(hg$C), 173)
  expect_equal(ncol(hg$C), 270)
  expect_equal(length(hg$bone_names), 173)
  expect_equal(length(hg$muscle_names), 270)
})

test_that("MSKHypergraph works with custom matrix", {
  # Small 3x4 incidence matrix
  C_small <- matrix(c(1, 0, 1,
                       0, 1, 1,
                       1, 1, 0,
                       0, 0, 1), nrow = 3, ncol = 4)
  rownames(C_small) <- paste0("bone_", 1:3)
  colnames(C_small) <- paste0("muscle_", 1:4)


  hg <- MSKHypergraph(C_small)

  expect_s3_class(hg, "MSKHypergraph")
  expect_equal(hg$n_bones, 3)
  expect_equal(hg$n_muscles, 4)
})

test_that("Total connections (sum of C) = 1010", {
  hg <- MSKHypergraph()
  total <- sum(hg$C)
  expect_equal(total, 1010)
})

test_that("projectBoneGraph returns symmetric 173x173 matrix with zero diagonal", {
  hg <- MSKHypergraph()
  A <- projectBoneGraph(hg)

  expect_equal(nrow(A), 173)
  expect_equal(ncol(A), 173)

  # Symmetric
  expect_true(Matrix::isSymmetric(A))

  # Zero diagonal
  expect_equal(sum(Matrix::diag(A)), 0)

  # All entries should be non-negative
  expect_true(all(A >= 0))
})

test_that("projectMuscleGraph returns symmetric 270x270 matrix with zero diagonal", {
  hg <- MSKHypergraph()
  B <- projectMuscleGraph(hg)

  expect_equal(nrow(B), 270)
  expect_equal(ncol(B), 270)

  # Symmetric
  expect_true(Matrix::isSymmetric(B))

  # Zero diagonal
  expect_equal(sum(Matrix::diag(B)), 0)

  # All entries should be non-negative
  expect_true(all(B >= 0))
})

test_that("Bone graph A = t(C) * C relationship holds (with zero diagonal)", {

  hg <- MSKHypergraph()
  A <- projectBoneGraph(hg)

  # Manually compute: tcrossprod(C) with zero diagonal
  A_expected <- Matrix::tcrossprod(hg$C)
  diag(A_expected) <- 0

  expect_equal(as.matrix(A), as.matrix(A_expected))
})

test_that("Muscle graph B = C * t(C) relationship holds (with zero diagonal)", {
  hg <- MSKHypergraph()
  B <- projectMuscleGraph(hg)

  # Manually compute: crossprod(C) with zero diagonal
  B_expected <- Matrix::crossprod(hg$C)
  diag(B_expected) <- 0

  expect_equal(as.matrix(B), as.matrix(B_expected))
})

test_that("hyperedgeDegree range is [1, 30]", {
  hg <- MSKHypergraph()
  deg <- hyperedgeDegree(hg)

  expect_length(deg, 270)
  expect_true(all(deg >= 1))
  expect_true(all(deg <= 30))

  # Check names
  expect_equal(names(deg), colnames(hg$C))
})

test_that("vertexDegree returns all positive values", {
  hg <- MSKHypergraph()
  deg <- vertexDegree(hg)

  expect_length(deg, 173)
  expect_true(all(deg > 0))

  # Check names
  expect_equal(names(deg), rownames(hg$C))
})

test_that("degreeDistribution('muscle') gives heavy-tailed distribution", {
  hg <- MSKHypergraph()
  dd <- degreeDistribution(hg, "muscle")

  expect_s3_class(dd, "data.frame")
  expect_true(all(c("degree", "count", "probability") %in% colnames(dd)))

  # Total probability should sum to 1
  expect_equal(sum(dd$probability), 1.0, tolerance = 1e-10)

  # Heavy-tailed: many low-degree muscles, few high-degree ones
  # The mode should be at a low degree
  mode_idx <- which.max(dd$count)
  expect_true(dd$degree[mode_idx] <= 5,
              label = "Mode of muscle degree distribution should be at low degree")

  # Max degree should be significantly higher than the mode
  expect_gt(max(dd$degree), 10)
})

test_that("degreeDistribution('bone') works", {
  hg <- MSKHypergraph()
  dd <- degreeDistribution(hg, "bone")

  expect_s3_class(dd, "data.frame")
  expect_true(all(c("degree", "count", "probability") %in% colnames(dd)))
  expect_equal(sum(dd$probability), 1.0, tolerance = 1e-10)
  expect_equal(sum(dd$count), 173)
})

test_that("print.MSKHypergraph produces output", {
  hg <- MSKHypergraph()
  expect_output(print(hg), "MSKHypergraph")
  expect_output(print(hg), "Bones")
  expect_output(print(hg), "Muscles")
})
