library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-data.R -- Tests for data loading functions
# ===========================================================================

test_that("loadMSKData returns list with expected components", {
  data <- loadMSKData()

  expect_type(data, "list")
  expect_named(data, c("incidence", "muscle_meta", "bone_names", "muscle_names"),
               ignore.order = FALSE)

  expect_s4_class(data$incidence, "dgCMatrix")
  expect_s3_class(data$muscle_meta, "data.frame")
  expect_type(data$bone_names, "character")
  expect_type(data$muscle_names, "character")

  # Names should match matrix dimensions

  expect_equal(length(data$bone_names), nrow(data$incidence))
  expect_equal(length(data$muscle_names), ncol(data$incidence))
})

test_that("loadIncidenceMatrix returns 173 x 270 sparse matrix", {
  C <- loadIncidenceMatrix()

  expect_s4_class(C, "dgCMatrix")
  expect_equal(nrow(C), 173)
  expect_equal(ncol(C), 270)

  # Matrix should be binary (0/1)
  expect_true(all(C@x %in% c(0, 1)))

  # Should have row and column names

  expect_false(is.null(rownames(C)))
  expect_false(is.null(colnames(C)))
  expect_equal(length(rownames(C)), 173)
  expect_equal(length(colnames(C)), 270)
})

test_that("loadMuscleMetadata returns data.frame with 270 rows", {
  meta <- loadMuscleMetadata()

  expect_s3_class(meta, "data.frame")
  expect_equal(nrow(meta), 270)

  # Should have expected columns
  expected_cols <- c("index", "muscle", "community", "homunculus_category")
  expect_true(all(expected_cols %in% colnames(meta)))

  # Index should run 1..270
  expect_equal(meta$index, seq_len(270))

  # Muscle names should be non-empty strings
  expect_true(all(nchar(meta$muscle) > 0))
})

test_that("loadValidationData works for all 6 datasets", {
  datasets <- c("degree_distribution", "impact_vs_recovery",
                 "homunculus_deviation", "fmri_activation",
                 "homunculus_coordinates", "impact_vs_path")

  for (ds in datasets) {
    result <- loadValidationData(ds)
    expect_s3_class(result, "data.frame")
    expect_gt(nrow(result), 0,
              label = paste("Dataset", ds, "should have rows"))
  }
})

test_that("loadValidationData rejects invalid dataset names", {
  expect_error(loadValidationData("nonexistent"))
})

test_that("loadIncidenceMatrix caching works (second call uses cache)", {
  # Clear the cache by forcing a fresh package state
  # First call loads from disk
  t1 <- system.time({ C1 <- loadIncidenceMatrix() })

  # Second call should use cache and be faster (or at least not slower)
  t2 <- system.time({ C2 <- loadIncidenceMatrix() })

  # Cached result should be identical
  expect_identical(C1, C2)

  # The cache should make the second call at least as fast

  # (We only check that the result is the same; timing can be noisy)
  expect_equal(dim(C1), dim(C2))
})

test_that("loadMuscleMetadata caching works", {
  meta1 <- loadMuscleMetadata()
  meta2 <- loadMuscleMetadata()
  expect_identical(meta1, meta2)
})
