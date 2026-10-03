library(testthat)
library(PhysioMSKNet)

# ===========================================================================
# test-bridge-kg.R -- Tests for Knowledge Graph bridge functions
# ===========================================================================

# ---- Helper: small hypergraph for fast tests ----

.make_small_hg <- function() {
  C <- matrix(c(
    1, 0, 1, 0, 0,
    1, 1, 0, 0, 0,
    0, 1, 1, 1, 0,
    0, 0, 0, 1, 1,
    0, 0, 0, 0, 1,
    0, 0, 1, 0, 1
  ), nrow = 6, ncol = 5, byrow = TRUE)
  rownames(C) <- c("Humerus", "Scapula", "Clavicle", "Femur", "Tibia", "Radius")
  colnames(C) <- c("Biceps Brachii", "Deltoid", "Trapezius",
                    "Quadriceps", "Gastrocnemius")
  MSKHypergraph(C)
}


# ---- Helper: mock PhysioAnnotationHub ----

.make_mock_hub <- function() {
  muscles <- data.frame(
    muscle_name = c("Biceps Brachii", "Triceps Brachii", "Deltoid",
                    "Trapezius", "Quadriceps", "Gastrocnemius"),
    body_region = c("upper_limb", "upper_limb", "upper_limb",
                    "trunk", "lower_limb", "lower_limb"),
    sub_region = c("arm", "arm", "shoulder", "back", "thigh", "leg"),
    action_primary = c("elbow_flexion", "elbow_extension", "shoulder_abduction",
                       "scapular_elevation", "knee_extension",
                       "ankle_plantarflexion"),
    nerve = c("Musculocutaneous", "Radial", "Axillary",
              "Accessory", "Femoral", "Tibial"),
    spinal_level = c("C5-C6", "C6-C8", "C5-C6", "C3-C4", "L2-L4", "S1-S2"),
    stringsAsFactors = FALSE
  )

  bones <- data.frame(
    bone_name = c("Humerus", "Scapula", "Clavicle", "Femur", "Tibia", "Radius"),
    body_region = c("upper_limb", "upper_limb", "upper_limb",
                    "lower_limb", "lower_limb", "upper_limb"),
    bone_type = c("long", "flat", "long", "long", "long", "long"),
    stringsAsFactors = FALSE
  )

  nerves <- data.frame(
    nerve_name = c("Musculocutaneous", "Radial", "Axillary",
                   "Accessory", "Femoral", "Tibial"),
    spinal_root = c("C5-C7", "C5-T1", "C5-C6", "C3-C4", "L2-L4", "L4-S3"),
    plexus = c("Brachial", "Brachial", "Brachial",
               "Cervical", "Lumbar", "Sacral"),
    stringsAsFactors = FALSE
  )

  triples <- data.frame(
    subject = c("Biceps Brachii", "Biceps Brachii", "Biceps Brachii",
                "Deltoid", "Deltoid", "Quadriceps",
                "Biceps Brachii", "Deltoid",
                "Musculocutaneous", "Axillary"),
    predicate = c("innervated_by", "attaches_to", "synergist_of",
                  "innervated_by", "antagonist_of", "innervated_by",
                  "action", "action",
                  "spinal_level", "spinal_level"),
    object = c("Musculocutaneous", "Humerus", "Deltoid",
               "Axillary", "Trapezius", "Femoral",
               "elbow_flexion", "shoulder_abduction",
               "C5-C6", "C5-C6"),
    stringsAsFactors = FALSE
  )

  icd10 <- data.frame(
    muscle_name = c("Biceps Brachii", "Biceps Brachii", "Deltoid",
                    "Quadriceps", "Gastrocnemius"),
    code = c("M62.12", "S46.1", "M62.11", "M62.15", "M62.16"),
    description = c("Biceps strain", "Biceps tendon injury",
                    "Deltoid strain", "Quadriceps strain",
                    "Gastrocnemius strain"),
    stringsAsFactors = FALSE
  )

  icf <- data.frame(
    muscle_name = c("Biceps Brachii", "Deltoid", "Quadriceps"),
    code = c("b7300", "b7301", "b7303"),
    description = c("Power of upper arm muscles",
                    "Power of shoulder muscles",
                    "Power of thigh muscles"),
    stringsAsFactors = FALSE
  )

  hub <- list(
    muscles = muscles,
    bones = bones,
    nerves = nerves,
    triples = triples,
    icd10 = icd10,
    icf = icf
  )
  class(hub) <- "PhysioAnnotationHub"
  hub
}


# ---- .matchMuscleNames ----

test_that(".matchMuscleNames performs exact matching", {
  hub <- .make_mock_hub()
  result <- PhysioMSKNet:::.matchMuscleNames(
    c("Biceps Brachii", "Deltoid"),
    hub$muscles$muscle_name
  )
  expect_true(all(result$matched))
  expect_equal(result$hub_name[1], "Biceps Brachii")
  expect_equal(result$hub_name[2], "Deltoid")
})

test_that(".matchMuscleNames handles unmatched names", {
  hub <- .make_mock_hub()
  result <- PhysioMSKNet:::.matchMuscleNames(
    c("Biceps Brachii", "NonexistentMuscle123"),
    hub$muscles$muscle_name
  )
  expect_true(result$matched[1])
  expect_false(result$matched[2])
  expect_true(is.na(result$hub_name[2]))
})

test_that(".matchMuscleNames uses fuzzy matching", {
  hub <- .make_mock_hub()
  result <- PhysioMSKNet:::.matchMuscleNames(
    "Biceps Brachi",
    hub$muscles$muscle_name
  )
  expect_true(result$matched[1])
})


# ---- .matchBoneNames ----

test_that(".matchBoneNames performs exact matching", {
  hub <- .make_mock_hub()
  result <- PhysioMSKNet:::.matchBoneNames(
    c("Humerus", "Femur"),
    hub$bones$bone_name
  )
  expect_true(all(result$matched))
})


# ---- .internalEnrichment ----

test_that(".internalEnrichment computes enrichment correctly", {
  # Query: 3 muscles all with "upper_limb"

# Background: 3 upper_limb + 2 lower_limb + 1 trunk = 6
  query <- c("upper_limb", "upper_limb", "upper_limb")
  bg <- c("upper_limb", "upper_limb", "upper_limb",
          "lower_limb", "lower_limb", "trunk")

  result <- PhysioMSKNet:::.internalEnrichment(query, bg)

  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) >= 1)
  expect_true("upper_limb" %in% result$term)
  expect_true(all(c("term", "count", "expected", "fold_enrichment",
                     "p_value", "significant") %in% names(result)))

  # Upper limb should be enriched (3/3 vs 3/6)
  ul_row <- result[result$term == "upper_limb", ]
  expect_equal(ul_row$count, 3)
  expect_true(ul_row$fold_enrichment >= 1)
})

test_that(".internalEnrichment returns empty df for empty input", {
  result <- PhysioMSKNet:::.internalEnrichment(character(0), character(0))
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})


# ---- .ensureHub ----

test_that(".ensureHub passes through existing hub", {
  hub <- .make_mock_hub()
  result <- PhysioMSKNet:::.ensureHub(hub)
  expect_identical(result, hub)
})

test_that(".ensureHub errors when PhysioAnnotationHub not installed and hub is NULL", {
  # Since PhysioAnnotationHub is likely not installed in test environment,
  # we check the error message (unless it IS installed)
  if (!requireNamespace("PhysioAnnotationHub", quietly = TRUE)) {
    expect_error(PhysioMSKNet:::.ensureHub(NULL), "PhysioAnnotationHub")
  }
})


# ---- mskAnnotate ----

test_that("mskAnnotate adds muscle annotations", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  expect_message(
    annotated_hg <- mskAnnotate(hg, hub),
    "Annotated MSKHypergraph"
  )

  expect_s3_class(annotated_hg, "MSKHypergraph")
  expect_true(annotated_hg$annotated)
  expect_true("muscle_annotations" %in% names(annotated_hg))
  expect_true("bone_annotations" %in% names(annotated_hg))
})

test_that("mskAnnotate muscle_annotations has correct structure", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()
  annotated_hg <- suppressMessages(mskAnnotate(hg, hub))

  ma <- annotated_hg$muscle_annotations
  expect_s3_class(ma, "data.frame")
  expect_equal(nrow(ma), hg$n_muscles)
  expect_true("muscle_name" %in% names(ma))
  expect_true("body_region" %in% names(ma))
  expect_true("nerve" %in% names(ma))
})

test_that("mskAnnotate correctly matches known muscles", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()
  annotated_hg <- suppressMessages(mskAnnotate(hg, hub))

  ma <- annotated_hg$muscle_annotations
  # Biceps Brachii should be matched
  biceps_row <- ma[ma$muscle_name == "Biceps Brachii", ]
  expect_equal(biceps_row$body_region, "upper_limb")
  expect_equal(biceps_row$nerve, "Musculocutaneous")
})

test_that("mskAnnotate bone_annotations has correct structure", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()
  annotated_hg <- suppressMessages(mskAnnotate(hg, hub))

  ba <- annotated_hg$bone_annotations
  expect_s3_class(ba, "data.frame")
  expect_equal(nrow(ba), hg$n_bones)
  expect_true("bone_name" %in% names(ba))
})

test_that("mskAnnotate reports coverage statistics", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()
  annotated_hg <- suppressMessages(mskAnnotate(hg, hub))

  cov <- annotated_hg$annotation_coverage
  expect_true(is.list(cov))
  expect_true("muscle_matched" %in% names(cov))
  expect_true("bone_matched" %in% names(cov))
  expect_true(cov$muscle_matched > 0)
  expect_true(cov$bone_matched > 0)
})

test_that("mskAnnotate preserves MSKHypergraph class", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()
  annotated_hg <- suppressMessages(mskAnnotate(hg, hub))

  expect_s3_class(annotated_hg, "MSKHypergraph")
  expect_equal(annotated_hg$n_bones, hg$n_bones)
  expect_equal(annotated_hg$n_muscles, hg$n_muscles)
})


# ---- mskEnrichKG ----

test_that("mskEnrichKG returns enrichment data frame", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  result <- suppressMessages(
    mskEnrichKG(c("Biceps Brachii", "Deltoid", "Trapezius"),
                annotation_type = "body_region", hub = hub, hg = hg)
  )

  expect_s3_class(result, "data.frame")
  expect_true(all(c("term", "count", "p_value", "significant") %in%
                    names(result)))
})

test_that("mskEnrichKG upper_limb enrichment for arm muscles", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  # Biceps and Deltoid are both upper_limb
  result <- suppressMessages(
    mskEnrichKG(c("Biceps Brachii", "Deltoid"),
                annotation_type = "body_region", hub = hub, hg = hg)
  )

  if (nrow(result) > 0 && "upper_limb" %in% result$term) {
    ul_row <- result[result$term == "upper_limb", ]
    expect_true(ul_row$fold_enrichment >= 1)
  }
})

test_that("mskEnrichKG works with nerve annotation", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  result <- suppressMessages(
    mskEnrichKG(c("Biceps Brachii", "Deltoid"),
                annotation_type = "nerve", hub = hub, hg = hg)
  )

  expect_s3_class(result, "data.frame")
})

test_that("mskEnrichKG works with action annotation", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  result <- suppressMessages(
    mskEnrichKG(c("Biceps Brachii"),
                annotation_type = "action", hub = hub, hg = hg)
  )

  expect_s3_class(result, "data.frame")
})

test_that("mskEnrichKG works with spinal_level annotation", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  result <- suppressMessages(
    mskEnrichKG(c("Biceps Brachii", "Deltoid"),
                annotation_type = "spinal_level", hub = hub, hg = hg)
  )

  expect_s3_class(result, "data.frame")
})

test_that("mskEnrichKG validates annotation_type", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  expect_error(
    mskEnrichKG(c("Biceps Brachii"), annotation_type = "invalid",
                hub = hub, hg = hg),
    "arg"
  )
})

test_that("mskEnrichKG works with integer muscle indices", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  result <- suppressMessages(
    mskEnrichKG(c(1, 2), annotation_type = "body_region", hub = hub, hg = hg)
  )

  expect_s3_class(result, "data.frame")
})


# ---- mskPathwayQuery ----

test_that("mskPathwayQuery finds direct path in triples", {
  hub <- .make_mock_hub()

  result <- mskPathwayQuery("Biceps Brachii", "Musculocutaneous", hub = hub)

  expect_true(is.list(result))
  expect_true(result$found)
  expect_true(length(result$path) >= 2)
  expect_true(result$depth >= 1)
  expect_true(nchar(result$description) > 0)
})

test_that("mskPathwayQuery returns path entities and predicates", {
  hub <- .make_mock_hub()

  result <- mskPathwayQuery("Biceps Brachii", "Musculocutaneous", hub = hub)

  expect_true("path" %in% names(result))
  expect_true("predicates" %in% names(result))
  expect_true("depth" %in% names(result))
  expect_true("description" %in% names(result))
  expect_true("found" %in% names(result))
})

test_that("mskPathwayQuery returns not found for unconnected entities", {
  hub <- .make_mock_hub()

  result <- mskPathwayQuery("Biceps Brachii", "NonexistentEntity999",
                             hub = hub)

  expect_false(result$found)
  expect_equal(length(result$path), 0)
})

test_that("mskPathwayQuery respects max_depth", {
  hub <- .make_mock_hub()

  result <- mskPathwayQuery("Biceps Brachii", "C5-C6", hub = hub,
                             max_depth = 5)

  expect_true(is.list(result))
  if (result$found) {
    expect_true(result$depth <= 5)
  }
})

test_that("mskPathwayQuery description is human-readable", {
  hub <- .make_mock_hub()

  result <- mskPathwayQuery("Biceps Brachii", "Musculocutaneous", hub = hub)

  if (result$found) {
    expect_true(grepl("Biceps Brachii", result$description))
    expect_true(grepl("Musculocutaneous", result$description))
    expect_true(grepl("-\\[", result$description))  # Contains -[predicate]->
  }
})

test_that("mskPathwayQuery validates inputs", {
  hub <- .make_mock_hub()

  expect_error(mskPathwayQuery(123, "B", hub = hub))
  expect_error(mskPathwayQuery(c("A", "B"), "C", hub = hub))
})

test_that("mskPathwayQuery handles empty triples gracefully", {
  hub <- .make_mock_hub()
  hub$triples <- data.frame(
    subject = character(0), predicate = character(0),
    object = character(0), stringsAsFactors = FALSE
  )

  result <- mskPathwayQuery("Biceps Brachii", "Musculocutaneous", hub = hub)
  expect_false(result$found)
})


# ---- mskCommunityProfile ----

test_that("mskCommunityProfile returns MSKCommunityProfile", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
  valid_id <- comm$membership[1]

  profile <- suppressMessages(
    mskCommunityProfile(hg = hg, community_id = valid_id, hub = hub)
  )

  expect_s3_class(profile, "MSKCommunityProfile")
  expect_true(all(c("community_id", "muscles", "n_muscles",
                     "action_profile", "nerve_profile", "region_profile",
                     "spinal_profile", "dominant_action", "dominant_nerve",
                     "dominant_region", "mean_degree",
                     "mean_impact_deviation") %in% names(profile)))
})

test_that("mskCommunityProfile muscles are from correct community", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
  valid_id <- comm$membership[1]
  expected_muscles <- hg$muscle_names[comm$membership == valid_id]

  profile <- suppressMessages(
    mskCommunityProfile(hg = hg, community_id = valid_id, hub = hub)
  )

  expect_equal(sort(profile$muscles), sort(expected_muscles))
})

test_that("mskCommunityProfile errors for invalid community_id", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  expect_error(
    suppressMessages(
      mskCommunityProfile(hg = hg, community_id = 999, hub = hub)
    ),
    "not found"
  )
})

test_that("mskCommunityProfile has correct n_muscles", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
  valid_id <- comm$membership[1]

  profile <- suppressMessages(
    mskCommunityProfile(hg = hg, community_id = valid_id, hub = hub)
  )

  expect_equal(profile$n_muscles, length(profile$muscles))
})

test_that("print.MSKCommunityProfile produces output", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  comm <- mskCommunityDetect(hg, gamma = 4.3, type = "muscle")
  valid_id <- comm$membership[1]

  profile <- suppressMessages(
    mskCommunityProfile(hg = hg, community_id = valid_id, hub = hub)
  )

  expect_output(print(profile), "MSK Community Profile")
  expect_output(print(profile), "Community ID")
})


# ---- mskClinicalEvidence ----

test_that("mskClinicalEvidence returns MSKClinicalEvidence", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence(c("Biceps Brachii", "Deltoid"), hub = hub, hg = hg)
  )

  expect_s3_class(evidence, "MSKClinicalEvidence")
  expect_true(all(c("muscles", "icd10_codes", "icf_codes",
                     "affected_nerves", "affected_spinal_levels",
                     "functional_impact", "synergists", "antagonists")
                   %in% names(evidence)))
})

test_that("mskClinicalEvidence finds ICD-10 codes", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_s3_class(evidence$icd10_codes, "data.frame")
  expect_true(nrow(evidence$icd10_codes) > 0)
  expect_true("M62.12" %in% evidence$icd10_codes$icd10_code ||
              "S46.1" %in% evidence$icd10_codes$icd10_code)
})

test_that("mskClinicalEvidence finds ICF codes", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_s3_class(evidence$icf_codes, "data.frame")
  expect_true(nrow(evidence$icf_codes) > 0)
})

test_that("mskClinicalEvidence identifies affected nerves", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_true("Musculocutaneous" %in% evidence$affected_nerves)
})

test_that("mskClinicalEvidence identifies affected spinal levels", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_true(length(evidence$affected_spinal_levels) > 0)
  expect_true("C5-C6" %in% evidence$affected_spinal_levels)
})

test_that("mskClinicalEvidence identifies functional impact", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_true(length(evidence$functional_impact) > 0)
  expect_true("elbow_flexion" %in% evidence$functional_impact)
})

test_that("mskClinicalEvidence finds synergists from triples", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  # Biceps Brachii has synergist_of Deltoid in our mock triples
  expect_true("Deltoid" %in% evidence$synergists)
})

test_that("mskClinicalEvidence finds antagonists from triples", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Deltoid", hub = hub, hg = hg)
  )

  # Deltoid has antagonist_of Trapezius in mock triples
  expect_true("Trapezius" %in% evidence$antagonists)
})

test_that("mskClinicalEvidence works with integer indices", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence(c(1, 2), hub = hub, hg = hg)
  )

  expect_s3_class(evidence, "MSKClinicalEvidence")
})

test_that("mskClinicalEvidence handles muscles without clinical codes", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  # Trapezius has no ICD-10 code in our mock
  evidence <- suppressMessages(
    mskClinicalEvidence("Trapezius", hub = hub, hg = hg)
  )

  expect_s3_class(evidence, "MSKClinicalEvidence")
  # Should still have the other fields
  expect_true(is.data.frame(evidence$icd10_codes))
})

test_that("print.MSKClinicalEvidence produces output", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  evidence <- suppressMessages(
    mskClinicalEvidence("Biceps Brachii", hub = hub, hg = hg)
  )

  expect_output(print(evidence), "MSK Clinical Evidence Report")
  expect_output(print(evidence), "Biceps Brachii")
})


# ---- mskKGSummary ----

test_that("mskKGSummary returns MSKKGSummary", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  summary <- suppressMessages(mskKGSummary(hg = hg, hub = hub))

  expect_s3_class(summary, "MSKKGSummary")
  expect_true(all(c("hg", "community_profiles", "n_communities",
                     "cross_community_nerves", "annotation_coverage")
                   %in% names(summary)))
})

test_that("mskKGSummary annotated hypergraph has annotations", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  summary <- suppressMessages(mskKGSummary(hg = hg, hub = hub))

  expect_true(summary$hg$annotated)
})

test_that("mskKGSummary community_profiles is a list", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  summary <- suppressMessages(mskKGSummary(hg = hg, hub = hub))

  expect_true(is.list(summary$community_profiles))
  expect_true(length(summary$community_profiles) >= 1)
})

test_that("mskKGSummary annotation_coverage is populated", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  summary <- suppressMessages(mskKGSummary(hg = hg, hub = hub))

  cov <- summary$annotation_coverage
  expect_true(is.list(cov))
  expect_true(cov$muscle_matched > 0)
})

test_that("print.MSKKGSummary produces output", {
  hg <- .make_small_hg()
  hub <- .make_mock_hub()

  summary <- suppressMessages(mskKGSummary(hg = hg, hub = hub))

  expect_output(print(summary), "MSK Knowledge Graph Summary")
  expect_output(print(summary), "Annotation Coverage")
})


# ---- Graceful handling when PhysioAnnotationHub not installed ----

test_that("functions error gracefully without hub and without PhysioAnnotationHub", {
  skip_if(requireNamespace("PhysioAnnotationHub", quietly = TRUE),
          "PhysioAnnotationHub is installed; skip missing-package test")

  hg <- .make_small_hg()

  expect_error(mskAnnotate(hg, hub = NULL), "PhysioAnnotationHub")
  expect_error(
    mskEnrichKG("Biceps Brachii", hub = NULL, hg = hg),
    "PhysioAnnotationHub"
  )
  expect_error(mskPathwayQuery("A", "B", hub = NULL), "PhysioAnnotationHub")
  expect_error(
    mskCommunityProfile(hg = hg, community_id = 1, hub = NULL),
    "PhysioAnnotationHub"
  )
  expect_error(
    mskClinicalEvidence("Biceps Brachii", hub = NULL, hg = hg),
    "PhysioAnnotationHub"
  )
  expect_error(mskKGSummary(hg = hg, hub = NULL), "PhysioAnnotationHub")
})
