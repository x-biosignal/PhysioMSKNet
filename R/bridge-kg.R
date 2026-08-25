# ===========================================================================
# bridge-kg.R -- Knowledge Graph integration via PhysioAnnotationHub
# ===========================================================================

# ---- Internal helpers ----

#' Check and load PhysioAnnotationHub
#' @param hub An existing hub object or NULL.
#' @return A PhysioAnnotationHub object.
#' @keywords internal
.ensureHub <- function(hub) {
  if (!is.null(hub)) return(hub)
  if (!requireNamespace("PhysioAnnotationHub", quietly = TRUE)) {
    stop(
      "PhysioAnnotationHub is required for KG integration but not installed.\n",
      "Install it with: install.packages('PhysioAnnotationHub', repos = c('https://x-biosignal.r-universe.dev', 'https://cloud.r-project.org'))\n",
      "Or supply a pre-built hub object via the 'hub' parameter.",
      call. = FALSE
    )
  }
  PhysioAnnotationHub::loadAnnotationHub()
}

#' Match muscle names between hypergraph and hub
#'
#' Uses case-insensitive exact matching, then fuzzy matching for unmatched names.
#'
#' @param hg_names Character vector of muscle names from hypergraph.
#' @param hub_names Character vector of muscle names from hub.
#' @return A data.frame with columns: hg_name, hub_name, matched (logical).
#' @keywords internal
.matchMuscleNames <- function(hg_names, hub_names) {
  hg_lower <- tolower(trimws(hg_names))
  hub_lower <- tolower(trimws(hub_names))

  matched_hub <- character(length(hg_names))
  is_matched <- logical(length(hg_names))

  for (i in seq_along(hg_names)) {
    exact <- which(hub_lower == hg_lower[i])
    if (length(exact) >= 1L) {
      matched_hub[i] <- hub_names[exact[1L]]
      is_matched[i] <- TRUE
    } else {
      fuzzy <- agrep(hg_lower[i], hub_lower, max.distance = 0.2,
                     ignore.case = TRUE)
      if (length(fuzzy) >= 1L) {
        matched_hub[i] <- hub_names[fuzzy[1L]]
        is_matched[i] <- TRUE
      } else {
        matched_hub[i] <- NA_character_
        is_matched[i] <- FALSE
      }
    }
  }

  data.frame(
    hg_name = hg_names,
    hub_name = matched_hub,
    matched = is_matched,
    stringsAsFactors = FALSE
  )
}

#' Match bone names between hypergraph and hub
#'
#' Uses case-insensitive exact matching, then fuzzy matching for unmatched names.
#'
#' @param hg_names Character vector of bone names from hypergraph.
#' @param hub_names Character vector of bone names from hub.
#' @return A data.frame with columns: hg_name, hub_name, matched (logical).
#' @keywords internal
.matchBoneNames <- function(hg_names, hub_names) {
  hg_lower <- tolower(trimws(hg_names))
  hub_lower <- tolower(trimws(hub_names))

  matched_hub <- character(length(hg_names))
  is_matched <- logical(length(hg_names))

  for (i in seq_along(hg_names)) {
    exact <- which(hub_lower == hg_lower[i])
    if (length(exact) >= 1L) {
      matched_hub[i] <- hub_names[exact[1L]]
      is_matched[i] <- TRUE
    } else {
      fuzzy <- agrep(hg_lower[i], hub_lower, max.distance = 0.2,
                     ignore.case = TRUE)
      if (length(fuzzy) >= 1L) {
        matched_hub[i] <- hub_names[fuzzy[1L]]
        is_matched[i] <- TRUE
      } else {
        matched_hub[i] <- NA_character_
        is_matched[i] <- FALSE
      }
    }
  }

  data.frame(
    hg_name = hg_names,
    hub_name = matched_hub,
    matched = is_matched,
    stringsAsFactors = FALSE
  )
}

#' Internal enrichment test (hypergeometric / Fisher's exact)
#'
#' Tests enrichment of a set of muscles for a given annotation term
#' using Fisher's exact test.
#'
#' @param query_terms Character vector of annotation terms for query muscles.
#' @param bg_terms Character vector of annotation terms for background muscles.
#' @return A data.frame with columns: term, count, background_count,
#'   expected, fold_enrichment, p_value, significant.
#' @keywords internal
.internalEnrichment <- function(query_terms, bg_terms) {
  query_terms <- query_terms[!is.na(query_terms)]
  bg_terms <- bg_terms[!is.na(bg_terms)]

  if (length(query_terms) == 0L || length(bg_terms) == 0L) {
    return(data.frame(
      term = character(0),
      count = integer(0),
      background_count = integer(0),
      expected = numeric(0),
      fold_enrichment = numeric(0),
      p_value = numeric(0),
      significant = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  n_query <- length(query_terms)
  n_bg <- length(bg_terms)
  all_terms <- unique(bg_terms)

  results <- lapply(all_terms, function(term) {
    k <- sum(query_terms == term)  # successes in query
    if (k == 0L) return(NULL)
    K <- sum(bg_terms == term)     # successes in background
    expected <- n_query * K / n_bg
    fold <- if (expected > 0) k / expected else Inf

    # Fisher's exact test via hypergeometric
    p_val <- stats::phyper(k - 1L, K, n_bg - K, n_query, lower.tail = FALSE)

    data.frame(
      term = term,
      count = k,
      background_count = K,
      expected = round(expected, 3),
      fold_enrichment = round(fold, 3),
      p_value = signif(p_val, 4),
      significant = p_val < 0.05,
      stringsAsFactors = FALSE
    )
  })

  results <- results[!vapply(results, is.null, logical(1))]
  if (length(results) == 0L) {
    return(data.frame(
      term = character(0),
      count = integer(0),
      background_count = integer(0),
      expected = numeric(0),
      fold_enrichment = numeric(0),
      p_value = numeric(0),
      significant = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  result_df <- do.call(rbind, results)
  result_df[order(result_df$p_value), ]
}


# ---- Exported functions ----

#' Annotate MSK Hypergraph with Knowledge Graph Data
#'
#' Attaches anatomical annotations from PhysioAnnotationHub to an MSK
#' hypergraph, matching muscle and bone names between the two data sources.
#' Annotations include body region, innervation, actions, and spinal levels.
#'
#' @param hg An MSKHypergraph object. If NULL, loads default 173-bone/270-muscle
#'   network.
#' @param hub A PhysioAnnotationHub object. If NULL, loads via
#'   \code{PhysioAnnotationHub::loadAnnotationHub()}.
#' @return An annotated MSKHypergraph with additional fields:
#'   \describe{
#'     \item{muscle_annotations}{Data frame of muscle annotations merged from hub}
#'     \item{bone_annotations}{Data frame of bone annotations merged from hub}
#'     \item{annotated}{Logical flag indicating annotations are attached}
#'     \item{annotation_coverage}{List with muscle and bone match rates}
#'   }
#'
#' @section Clinical Validity:
#' Annotations are derived from PhysioAnnotationHub's curated knowledge graph.
#' Name matching uses fuzzy matching with a 0.2 edit distance threshold, which
#' may produce incorrect matches for similarly named structures. Always verify
#' critical annotations against primary anatomical references.
#'
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
#' @examples
#' \dontrun{
#' hg <- mskAnnotate()
#' head(hg$muscle_annotations)
#' }
mskAnnotate <- function(hg = NULL, hub = NULL) {
  hg <- .ensureHypergraph(hg)
  hub <- .ensureHub(hub)

  # Match muscles
  muscle_match <- .matchMuscleNames(hg$muscle_names, hub$muscles$muscle_name)
  n_muscle_matched <- sum(muscle_match$matched)

  # Build muscle annotations for all hypergraph muscles
  muscle_annot <- data.frame(
    muscle_name = hg$muscle_names,
    stringsAsFactors = FALSE
  )

  hub_muscle_cols <- setdiff(names(hub$muscles), "muscle_name")
  for (col in hub_muscle_cols) {
    muscle_annot[[col]] <- NA_character_
  }

  for (i in seq_len(nrow(muscle_match))) {
    if (muscle_match$matched[i]) {
      hub_row <- which(hub$muscles$muscle_name == muscle_match$hub_name[i])
      if (length(hub_row) >= 1L) {
        hub_row <- hub_row[1L]
        for (col in hub_muscle_cols) {
          muscle_annot[[col]][i] <- as.character(hub$muscles[[col]][hub_row])
        }
      }
    }
  }

  # Match bones
  bone_match <- .matchBoneNames(hg$bone_names, hub$bones$bone_name)
  n_bone_matched <- sum(bone_match$matched)

  bone_annot <- data.frame(
    bone_name = hg$bone_names,
    stringsAsFactors = FALSE
  )

  hub_bone_cols <- setdiff(names(hub$bones), "bone_name")
  for (col in hub_bone_cols) {
    bone_annot[[col]] <- NA_character_
  }

  for (i in seq_len(nrow(bone_match))) {
    if (bone_match$matched[i]) {
      hub_row <- which(hub$bones$bone_name == bone_match$hub_name[i])
      if (length(hub_row) >= 1L) {
        hub_row <- hub_row[1L]
        for (col in hub_bone_cols) {
          bone_annot[[col]][i] <- as.character(hub$bones[[col]][hub_row])
        }
      }
    }
  }

  # Attach annotations to hypergraph
  hg$muscle_annotations <- muscle_annot
  hg$bone_annotations <- bone_annot
  hg$annotated <- TRUE
  hg$annotation_coverage <- list(
    muscle_matched = n_muscle_matched,
    muscle_total = hg$n_muscles,
    muscle_pct = round(100 * n_muscle_matched / hg$n_muscles, 1),
    bone_matched = n_bone_matched,
    bone_total = hg$n_bones,
    bone_pct = round(100 * n_bone_matched / hg$n_bones, 1)
  )

  message(sprintf(
    "Annotated MSKHypergraph: %d/%d muscles (%.1f%%), %d/%d bones (%.1f%%) matched",
    n_muscle_matched, hg$n_muscles, hg$annotation_coverage$muscle_pct,
    n_bone_matched, hg$n_bones, hg$annotation_coverage$bone_pct
  ))

  # Preserve class
  class(hg) <- "MSKHypergraph"
  hg
}


#' Functional Enrichment of Muscles via Knowledge Graph
#'
#' Tests whether a set of muscles is enriched for specific anatomical or
#' functional annotations (actions, nerves, body regions, spinal levels)
#' compared to the full background set of muscles in the hypergraph.
#'
#' @param muscles Character or integer vector identifying muscles to test.
#' @param annotation_type Character, one of \code{"action"}, \code{"nerve"},
#'   \code{"body_region"}, or \code{"spinal_level"}. Partial matching is
#'   supported.
#' @param hub A PhysioAnnotationHub object (NULL loads default).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @return A data.frame with columns:
#'   \describe{
#'     \item{term}{Annotation term}
#'     \item{count}{Number of query muscles with this term}
#'     \item{background_count}{Number of background muscles with this term}
#'     \item{expected}{Expected count under null}
#'     \item{fold_enrichment}{Ratio of observed to expected}
#'     \item{p_value}{P-value from hypergeometric test}
#'     \item{significant}{Logical, TRUE if p < 0.05}
#'   }
#'
#' @section Clinical Validity:
#' Enrichment analysis depends on the completeness and accuracy of the
#' underlying knowledge graph annotations. P-values are not adjusted for
#' multiple testing; consider applying Bonferroni or FDR correction when
#' testing multiple annotation types simultaneously.
#'
#' @export
#' @examples
#' \dontrun{
#' # Test enrichment of upper limb muscles for nerve innervation
#' enrichment <- mskEnrichKG(
#'   c("Biceps Brachii", "Deltoid", "Trapezius"),
#'   annotation_type = "nerve"
#' )
#' enrichment[enrichment$significant, ]
#' }
mskEnrichKG <- function(muscles,
                         annotation_type = c("action", "nerve",
                                             "body_region", "spinal_level"),
                         hub = NULL, hg = NULL) {
  annotation_type <- match.arg(annotation_type)
  hg <- .ensureHypergraph(hg)
  hub <- .ensureHub(hub)

  # Resolve query muscle indices
  muscle_idx <- .resolveMuscleIndices(muscles, hg)
  query_names <- hg$muscle_names[muscle_idx]

  # Map annotation_type to hub column
  col_map <- c(
    action = "action_primary",
    nerve = "nerve",
    body_region = "body_region",
    spinal_level = "spinal_level"
  )
  annot_col <- col_map[[annotation_type]]

  # Try PhysioAnnotationHub::kgEnrichment if available
  if (requireNamespace("PhysioAnnotationHub", quietly = TRUE) &&
      exists("kgEnrichment", where = asNamespace("PhysioAnnotationHub"),
             mode = "function")) {
    tryCatch({
      result <- PhysioAnnotationHub::kgEnrichment(query_names, annotation_type)
      if (is.data.frame(result) && nrow(result) > 0) {
        # Ensure 'significant' column exists
        if (!"significant" %in% names(result) && "p_value" %in% names(result)) {
          result$significant <- result$p_value < 0.05
        }
        return(result)
      }
    }, error = function(e) NULL)
  }

  # Fallback: do enrichment internally using hub data
  # Match all hypergraph muscles to hub annotations
  all_match <- .matchMuscleNames(hg$muscle_names, hub$muscles$muscle_name)

  # Build annotation vectors for background and query
  bg_terms <- character(hg$n_muscles)
  for (i in seq_len(hg$n_muscles)) {
    if (all_match$matched[i]) {
      hub_row <- which(hub$muscles$muscle_name == all_match$hub_name[i])
      if (length(hub_row) >= 1L && annot_col %in% names(hub$muscles)) {
        bg_terms[i] <- as.character(hub$muscles[[annot_col]][hub_row[1L]])
      } else {
        bg_terms[i] <- NA_character_
      }
    } else {
      bg_terms[i] <- NA_character_
    }
  }

  query_terms <- bg_terms[muscle_idx]

  .internalEnrichment(query_terms, bg_terms)
}


#' Query Anatomical Pathway Between Entities
#'
#' Finds the shortest anatomical pathway between two entities (muscles, bones,
#' nerves, etc.) in the knowledge graph. Useful for tracing innervation chains,
#' biomechanical linkages, and anatomical relationships.
#'
#' @param from Character, the source entity name (e.g., "Biceps Brachii").
#' @param to Character, the target entity name (e.g., "C5").
#' @param hub A PhysioAnnotationHub object (NULL loads default).
#' @param max_depth Integer, maximum BFS depth (default: 5).
#' @return A list with:
#'   \describe{
#'     \item{path}{Character vector of entities along the path}
#'     \item{predicates}{Character vector of relationship types between entities}
#'     \item{depth}{Integer, path length}
#'     \item{description}{Human-readable path description}
#'     \item{found}{Logical, whether a path was found}
#'   }
#'
#' @section Clinical Validity:
#' Pathways reflect relationships encoded in the knowledge graph. The shortest
#' path in the KG may not correspond to the most clinically relevant connection.
#' Always verify pathway interpretations against anatomical references.
#'
#' @export
#' @examples
#' \dontrun{
#' path <- mskPathwayQuery("Biceps Brachii", "C5")
#' cat(path$description, "\n")
#' }
mskPathwayQuery <- function(from, to, hub = NULL, max_depth = 5L) {
  stopifnot(is.character(from) && length(from) == 1L)
  stopifnot(is.character(to) && length(to) == 1L)
  stopifnot(is.numeric(max_depth) && max_depth >= 1L)

  hub <- .ensureHub(hub)

  # Try PhysioAnnotationHub::kgShortestPath if available
  if (requireNamespace("PhysioAnnotationHub", quietly = TRUE) &&
      exists("kgShortestPath", where = asNamespace("PhysioAnnotationHub"),
             mode = "function")) {
    tryCatch({
      result <- PhysioAnnotationHub::kgShortestPath(from, to)
      if (is.list(result) && !is.null(result$path) && length(result$path) > 0) {
        # Format the result
        path_entities <- result$path
        path_preds <- if (!is.null(result$predicates)) {
          result$predicates
        } else {
          rep("related_to", length(path_entities) - 1L)
        }
        depth <- length(path_entities) - 1L

        # Build human-readable description
        desc_parts <- character(0)
        for (k in seq_along(path_preds)) {
          desc_parts <- c(desc_parts,
                          paste0(path_entities[k], " -[", path_preds[k], "]-> "))
        }
        desc <- paste0(paste0(desc_parts, collapse = ""),
                        path_entities[length(path_entities)])

        return(list(
          path = path_entities,
          predicates = path_preds,
          depth = depth,
          description = desc,
          found = TRUE
        ))
      }
    }, error = function(e) NULL)
  }

  # Fallback: BFS through hub triples
  if (is.null(hub$triples) || nrow(hub$triples) == 0L) {
    return(list(
      path = character(0),
      predicates = character(0),
      depth = 0L,
      description = paste("No path found between", from, "and", to),
      found = FALSE
    ))
  }

  triples <- hub$triples
  from_lower <- tolower(trimws(from))
  to_lower <- tolower(trimws(to))

  # BFS
  visited <- character(0)
  # Queue entries: list(entity, path_so_far, predicates_so_far)
  queue <- list(list(entity = from_lower, path = from, preds = character(0)))
  visited <- c(visited, from_lower)

  while (length(queue) > 0) {
    current <- queue[[1]]
    queue <- queue[-1]

    if (length(current$path) - 1L >= max_depth) next

    # Find neighbors in triples
    subj_lower <- tolower(trimws(triples$subject))
    obj_lower <- tolower(trimws(triples$object))

    # Forward: current entity is subject
    fwd_idx <- which(subj_lower == current$entity)
    # Backward: current entity is object
    bwd_idx <- which(obj_lower == current$entity)

    neighbors <- list()
    for (fi in fwd_idx) {
      neighbor <- tolower(trimws(triples$object[fi]))
      if (!neighbor %in% visited) {
        neighbors[[length(neighbors) + 1L]] <- list(
          entity = neighbor,
          display = triples$object[fi],
          predicate = triples$predicate[fi]
        )
      }
    }
    for (bi in bwd_idx) {
      neighbor <- tolower(trimws(triples$subject[bi]))
      if (!neighbor %in% visited) {
        neighbors[[length(neighbors) + 1L]] <- list(
          entity = neighbor,
          display = triples$subject[bi],
          predicate = paste0("inv_", triples$predicate[bi])
        )
      }
    }

    for (nb in neighbors) {
      new_path <- c(current$path, nb$display)
      new_preds <- c(current$preds, nb$predicate)

      if (nb$entity == to_lower) {
        # Build description
        desc_parts <- character(0)
        for (k in seq_along(new_preds)) {
          desc_parts <- c(desc_parts,
                          paste0(new_path[k], " -[", new_preds[k], "]-> "))
        }
        desc <- paste0(paste0(desc_parts, collapse = ""),
                        new_path[length(new_path)])

        return(list(
          path = new_path,
          predicates = new_preds,
          depth = length(new_preds),
          description = desc,
          found = TRUE
        ))
      }

      visited <- c(visited, nb$entity)
      queue[[length(queue) + 1L]] <- list(
        entity = nb$entity,
        path = new_path,
        preds = new_preds
      )
    }
  }

  # No path found
  list(
    path = character(0),
    predicates = character(0),
    depth = 0L,
    description = paste("No path found between", from, "and", to,
                        "(max depth:", max_depth, ")"),
    found = FALSE
  )
}


#' Profile a MSK Community's Functional Characteristics
#'
#' Generates a detailed functional profile of a musculoskeletal community by
#' combining network topology metrics with knowledge graph annotations. This
#' enables characterization of communities by their anatomical region,
#' innervation patterns, primary actions, and spinal segment involvement.
#'
#' @param hg An MSKHypergraph object. If NULL, loads default network.
#' @param community_id Integer, the community to profile (1-based).
#' @param hub A PhysioAnnotationHub object (NULL loads default).
#' @param gamma Numeric, resolution parameter for community detection
#'   (default: 4.3, as in Murphy et al. 2018).
#' @return An S3 object of class \code{"MSKCommunityProfile"} with:
#'   \describe{
#'     \item{community_id}{Integer, the profiled community}
#'     \item{muscles}{Character vector of muscle names in the community}
#'     \item{n_muscles}{Integer, number of muscles}
#'     \item{action_profile}{Table of primary action distribution}
#'     \item{nerve_profile}{Table of innervating nerves distribution}
#'     \item{region_profile}{Table of body region distribution}
#'     \item{spinal_profile}{Table of spinal level distribution}
#'     \item{dominant_action}{Most frequent primary action}
#'     \item{dominant_nerve}{Most frequent innervating nerve}
#'     \item{dominant_region}{Most frequent body region}
#'     \item{mean_degree}{Mean hyperedge degree of community muscles}
#'     \item{mean_impact_deviation}{Mean impact deviation score}
#'   }
#'
#' @section Clinical Validity:
#' Community membership depends on the resolution parameter gamma and the
#' stochastic Louvain algorithm. Profile annotations depend on KG completeness.
#' Community boundaries are network-derived, not anatomical boundaries.
#'
#' @references Murphy AC et al. (2018) PLOS Biology 16(1): e2002811.
#' @export
#' @examples
#' \dontrun{
#' profile <- mskCommunityProfile(community_id = 1)
#' print(profile)
#' }
mskCommunityProfile <- function(hg = NULL, community_id, hub = NULL,
                                 gamma = 4.3) {
  stopifnot(is.numeric(community_id) && length(community_id) == 1L)

  hg <- .ensureHypergraph(hg)
  hub <- .ensureHub(hub)

  # Detect communities
  comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")

  if (!community_id %in% comm$membership) {
    stop(sprintf(
      "Community %d not found. Available communities: %s",
      community_id, paste(sort(unique(comm$membership)), collapse = ", ")
    ), call. = FALSE)
  }

  # Get community muscles
  comm_idx <- which(comm$membership == community_id)
  comm_muscles <- hg$muscle_names[comm_idx]

  # Get annotations for community muscles
  # Annotate hypergraph if not already done
  if (!isTRUE(hg$annotated)) {
    hg <- mskAnnotate(hg, hub)
  }

  annot <- hg$muscle_annotations
  comm_annot <- annot[comm_idx, , drop = FALSE]

  # Build profiles for each annotation type
  .safe_table <- function(x) {
    x <- x[!is.na(x) & x != "" & x != "NA"]
    if (length(x) == 0L) return(table(character(0)))
    sort(table(x), decreasing = TRUE)
  }

  .dominant <- function(tab) {
    if (length(tab) == 0L) return(NA_character_)
    names(tab)[1L]
  }

  action_profile <- .safe_table(comm_annot$action_primary)
  nerve_profile <- .safe_table(comm_annot$nerve)
  region_profile <- .safe_table(comm_annot$body_region)
  spinal_profile <- .safe_table(comm_annot$spinal_level)

  # Network metrics for community
  deg <- hyperedgeDegree(hg)
  comm_deg <- deg[comm_idx]
  mean_deg <- mean(comm_deg)

  # Impact deviation: simplified (based on degree deviation from mean)
  all_deg <- deg
  global_mean_deg <- mean(all_deg)
  global_sd_deg <- sd(all_deg)
  if (global_sd_deg > 0) {
    impact_dev <- (comm_deg - global_mean_deg) / global_sd_deg
    mean_impact_dev <- mean(impact_dev)
  } else {
    mean_impact_dev <- 0
  }

  result <- structure(
    list(
      community_id = as.integer(community_id),
      muscles = comm_muscles,
      n_muscles = length(comm_muscles),
      action_profile = action_profile,
      nerve_profile = nerve_profile,
      region_profile = region_profile,
      spinal_profile = spinal_profile,
      dominant_action = .dominant(action_profile),
      dominant_nerve = .dominant(nerve_profile),
      dominant_region = .dominant(region_profile),
      mean_degree = round(mean_deg, 2),
      mean_impact_deviation = round(mean_impact_dev, 3)
    ),
    class = "MSKCommunityProfile"
  )

  result
}

#' @export
print.MSKCommunityProfile <- function(x, ...) {
  cat("MSK Community Profile\n")
  cat("=====================\n")
  cat("Community ID:", x$community_id, "\n")
  cat("Muscles:", x$n_muscles, "\n")
  cat("Mean degree:", x$mean_degree, "\n")
  cat("Mean impact deviation:", x$mean_impact_deviation, "\n\n")

  if (!is.na(x$dominant_region)) {
    cat("Dominant region:", x$dominant_region, "\n")
  }
  if (!is.na(x$dominant_action)) {
    cat("Dominant action:", x$dominant_action, "\n")
  }
  if (!is.na(x$dominant_nerve)) {
    cat("Dominant nerve:", x$dominant_nerve, "\n")
  }

  cat("\nMuscles:", paste(head(x$muscles, 10), collapse = ", "))
  if (x$n_muscles > 10) cat(" ... and", x$n_muscles - 10, "more")
  cat("\n")

  if (length(x$region_profile) > 0) {
    cat("\nBody Region Distribution:\n")
    top_regions <- head(x$region_profile, 5)
    for (i in seq_along(top_regions)) {
      cat(sprintf("  %-25s %d\n", names(top_regions)[i], top_regions[i]))
    }
  }

  if (length(x$nerve_profile) > 0) {
    cat("\nNerve Distribution:\n")
    top_nerves <- head(x$nerve_profile, 5)
    for (i in seq_along(top_nerves)) {
      cat(sprintf("  %-25s %d\n", names(top_nerves)[i], top_nerves[i]))
    }
  }

  invisible(x)
}


#' Map Injured Muscles to Clinical Codes and Evidence
#'
#' Generates a clinical evidence report for a set of injured muscles by
#' querying the knowledge graph for ICD-10 codes, ICF codes, innervation,
#' functional impact, and related muscles (synergists and antagonists).
#'
#' @param injury_muscles Character or integer vector identifying injured muscles.
#' @param hub A PhysioAnnotationHub object (NULL loads default).
#' @param hg An MSKHypergraph object (NULL loads default).
#' @return An S3 object of class \code{"MSKClinicalEvidence"} with:
#'   \describe{
#'     \item{muscles}{Data frame of injury muscle annotations}
#'     \item{icd10_codes}{Matching ICD-10 entries}
#'     \item{icf_codes}{Matching ICF entries}
#'     \item{affected_nerves}{Nerves innervating injured muscles}
#'     \item{affected_spinal_levels}{Spinal segments involved}
#'     \item{functional_impact}{Affected actions/movements}
#'     \item{synergists}{Synergistic muscles from KG}
#'     \item{antagonists}{Antagonistic muscles from KG}
#'   }
#'
#' @section Clinical Validity:
#' ICD-10 and ICF code mappings are based on knowledge graph associations and
#' may not capture all valid codes for a clinical scenario. This tool provides
#' evidence aggregation for research; clinical coding should follow local
#' guidelines and be reviewed by qualified professionals.
#'
#' @export
#' @examples
#' \dontrun{
#' evidence <- mskClinicalEvidence(c("Biceps Brachii", "Deltoid"))
#' print(evidence)
#' }
mskClinicalEvidence <- function(injury_muscles, hub = NULL, hg = NULL) {
  hg <- .ensureHypergraph(hg)
  hub <- .ensureHub(hub)

  injury_idx <- .resolveMuscleIndices(injury_muscles, hg)
  injury_names <- hg$muscle_names[injury_idx]

  # Annotate hypergraph if not already done
  if (!isTRUE(hg$annotated)) {
    hg <- mskAnnotate(hg, hub)
  }

  # Extract muscle info
  muscle_info <- hg$muscle_annotations[injury_idx, , drop = FALSE]

  # ---- ICD-10 codes ----
  icd10_codes <- data.frame(
    muscle = character(0), icd10_code = character(0),
    description = character(0), stringsAsFactors = FALSE
  )
  if (!is.null(hub$icd10) && nrow(hub$icd10) > 0) {
    for (nm in injury_names) {
      nm_lower <- tolower(trimws(nm))
      # Search icd10 for matching entries
      if ("muscle_name" %in% names(hub$icd10)) {
        match_rows <- which(tolower(trimws(hub$icd10$muscle_name)) == nm_lower)
        if (length(match_rows) == 0L) {
          match_rows <- agrep(nm_lower, tolower(trimws(hub$icd10$muscle_name)),
                              max.distance = 0.2, ignore.case = TRUE)
        }
        if (length(match_rows) > 0) {
          icd10_codes <- rbind(icd10_codes, data.frame(
            muscle = nm,
            icd10_code = hub$icd10$code[match_rows],
            description = hub$icd10$description[match_rows],
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }

  # ---- ICF codes ----
  icf_codes <- data.frame(
    muscle = character(0), icf_code = character(0),
    description = character(0), stringsAsFactors = FALSE
  )
  if (!is.null(hub$icf) && nrow(hub$icf) > 0) {
    for (nm in injury_names) {
      nm_lower <- tolower(trimws(nm))
      if ("muscle_name" %in% names(hub$icf)) {
        match_rows <- which(tolower(trimws(hub$icf$muscle_name)) == nm_lower)
        if (length(match_rows) == 0L) {
          match_rows <- agrep(nm_lower, tolower(trimws(hub$icf$muscle_name)),
                              max.distance = 0.2, ignore.case = TRUE)
        }
        if (length(match_rows) > 0) {
          icf_codes <- rbind(icf_codes, data.frame(
            muscle = nm,
            icf_code = hub$icf$code[match_rows],
            description = hub$icf$description[match_rows],
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }

  # ---- Affected nerves and spinal levels ----
  affected_nerves <- unique(muscle_info$nerve[!is.na(muscle_info$nerve)])
  affected_spinal <- unique(muscle_info$spinal_level[
    !is.na(muscle_info$spinal_level)
  ])

  # ---- Functional impact ----
  functional_impact <- unique(muscle_info$action_primary[
    !is.na(muscle_info$action_primary)
  ])

  # ---- Synergists and Antagonists from KG triples ----
  synergists <- character(0)
  antagonists <- character(0)

  if (!is.null(hub$triples) && nrow(hub$triples) > 0) {
    for (nm in injury_names) {
      nm_lower <- tolower(trimws(nm))

      # Synergists: subject=muscle, predicate contains "synerg"
      syn_idx <- which(
        tolower(trimws(hub$triples$subject)) == nm_lower &
        grepl("synerg", tolower(hub$triples$predicate))
      )
      if (length(syn_idx) > 0) {
        synergists <- c(synergists, hub$triples$object[syn_idx])
      }
      # Also check reverse
      syn_idx_rev <- which(
        tolower(trimws(hub$triples$object)) == nm_lower &
        grepl("synerg", tolower(hub$triples$predicate))
      )
      if (length(syn_idx_rev) > 0) {
        synergists <- c(synergists, hub$triples$subject[syn_idx_rev])
      }

      # Antagonists: subject=muscle, predicate contains "antag"
      ant_idx <- which(
        tolower(trimws(hub$triples$subject)) == nm_lower &
        grepl("antag", tolower(hub$triples$predicate))
      )
      if (length(ant_idx) > 0) {
        antagonists <- c(antagonists, hub$triples$object[ant_idx])
      }
      ant_idx_rev <- which(
        tolower(trimws(hub$triples$object)) == nm_lower &
        grepl("antag", tolower(hub$triples$predicate))
      )
      if (length(ant_idx_rev) > 0) {
        antagonists <- c(antagonists, hub$triples$subject[ant_idx_rev])
      }
    }
  }

  synergists <- unique(synergists)
  antagonists <- unique(antagonists)

  result <- structure(
    list(
      muscles = muscle_info,
      icd10_codes = icd10_codes,
      icf_codes = icf_codes,
      affected_nerves = affected_nerves,
      affected_spinal_levels = affected_spinal,
      functional_impact = functional_impact,
      synergists = synergists,
      antagonists = antagonists,
      injury_names = injury_names
    ),
    class = "MSKClinicalEvidence"
  )

  result
}

#' @export
print.MSKClinicalEvidence <- function(x, ...) {
  cat("MSK Clinical Evidence Report\n")
  cat("============================\n")
  cat("Injured muscles:", paste(x$injury_names, collapse = ", "), "\n\n")

  if (nrow(x$icd10_codes) > 0) {
    cat("ICD-10 Codes:\n")
    for (i in seq_len(min(nrow(x$icd10_codes), 10))) {
      cat(sprintf("  %s: %s - %s\n",
                  x$icd10_codes$muscle[i],
                  x$icd10_codes$icd10_code[i],
                  x$icd10_codes$description[i]))
    }
    if (nrow(x$icd10_codes) > 10)
      cat("  ... and", nrow(x$icd10_codes) - 10, "more\n")
    cat("\n")
  }

  if (nrow(x$icf_codes) > 0) {
    cat("ICF Codes:\n")
    for (i in seq_len(min(nrow(x$icf_codes), 10))) {
      cat(sprintf("  %s: %s - %s\n",
                  x$icf_codes$muscle[i],
                  x$icf_codes$icf_code[i],
                  x$icf_codes$description[i]))
    }
    if (nrow(x$icf_codes) > 10)
      cat("  ... and", nrow(x$icf_codes) - 10, "more\n")
    cat("\n")
  }

  if (length(x$affected_nerves) > 0) {
    cat("Affected Nerves:", paste(x$affected_nerves, collapse = ", "), "\n")
  }
  if (length(x$affected_spinal_levels) > 0) {
    cat("Affected Spinal Levels:", paste(x$affected_spinal_levels,
                                          collapse = ", "), "\n")
  }
  if (length(x$functional_impact) > 0) {
    cat("Functional Impact:", paste(x$functional_impact, collapse = ", "), "\n")
  }

  if (length(x$synergists) > 0) {
    cat("\nSynergistic Muscles:", paste(x$synergists, collapse = ", "), "\n")
  }
  if (length(x$antagonists) > 0) {
    cat("Antagonistic Muscles:", paste(x$antagonists, collapse = ", "), "\n")
  }

  invisible(x)
}


#' KG-Enriched Summary of MSK Network
#'
#' Produces a comprehensive summary of the MSK network annotated with
#' knowledge graph data. Profiles all communities, identifies cross-community
#' nerve pathways, and summarizes annotation coverage.
#'
#' @param hg An MSKHypergraph object (NULL loads default).
#' @param hub A PhysioAnnotationHub object (NULL loads default).
#' @param gamma Numeric, resolution parameter for community detection
#'   (default: 4.3).
#' @return An S3 object of class \code{"MSKKGSummary"} with:
#'   \describe{
#'     \item{hg}{Annotated MSKHypergraph}
#'     \item{community_profiles}{List of MSKCommunityProfile objects}
#'     \item{n_communities}{Number of detected communities}
#'     \item{cross_community_nerves}{Data frame of nerves spanning communities}
#'     \item{annotation_coverage}{Annotation match statistics}
#'   }
#'
#' @section Clinical Validity:
#' This is a summary tool combining network topology with knowledge graph
#' annotations. Community boundaries and annotation mappings are model-derived.
#' Use as a research exploration tool, not for clinical decision-making.
#'
#' @export
#' @examples
#' \dontrun{
#' summary <- mskKGSummary()
#' print(summary)
#' }
mskKGSummary <- function(hg = NULL, hub = NULL, gamma = 4.3) {
  hg <- .ensureHypergraph(hg)
  hub <- .ensureHub(hub)

  # Annotate
  hg <- mskAnnotate(hg, hub)

  # Detect communities
  comm <- mskCommunityDetect(hg, gamma = gamma, type = "muscle")
  community_ids <- sort(unique(comm$membership))

  # Profile each community
  profiles <- lapply(community_ids, function(cid) {
    tryCatch(
      mskCommunityProfile(hg = hg, community_id = cid, hub = hub,
                           gamma = gamma),
      error = function(e) NULL
    )
  })
  names(profiles) <- paste0("community_", community_ids)
  profiles <- profiles[!vapply(profiles, is.null, logical(1))]

  # Cross-community nerve analysis
  annot <- hg$muscle_annotations
  cross_nerves <- data.frame(
    nerve = character(0),
    communities = character(0),
    n_communities = integer(0),
    n_muscles = integer(0),
    stringsAsFactors = FALSE
  )

  if ("nerve" %in% names(annot)) {
    nerve_vals <- annot$nerve[!is.na(annot$nerve)]
    unique_nerves <- unique(nerve_vals)

    for (nrv in unique_nerves) {
      muscle_mask <- which(!is.na(annot$nerve) & annot$nerve == nrv)
      muscle_comms <- unique(comm$membership[muscle_mask])
      if (length(muscle_comms) > 1L) {
        cross_nerves <- rbind(cross_nerves, data.frame(
          nerve = nrv,
          communities = paste(sort(muscle_comms), collapse = ","),
          n_communities = length(muscle_comms),
          n_muscles = length(muscle_mask),
          stringsAsFactors = FALSE
        ))
      }
    }

    if (nrow(cross_nerves) > 0) {
      cross_nerves <- cross_nerves[order(cross_nerves$n_communities,
                                          decreasing = TRUE), ]
    }
  }

  result <- structure(
    list(
      hg = hg,
      community_profiles = profiles,
      n_communities = comm$n_communities,
      modularity = comm$modularity,
      gamma = gamma,
      cross_community_nerves = cross_nerves,
      annotation_coverage = hg$annotation_coverage
    ),
    class = "MSKKGSummary"
  )

  result
}

#' @export
print.MSKKGSummary <- function(x, ...) {
  cat("MSK Knowledge Graph Summary\n")
  cat("===========================\n")
  cat("Communities:", x$n_communities, "\n")
  cat("Modularity:", round(x$modularity, 4), "(gamma =", x$gamma, ")\n\n")

  cat("Annotation Coverage:\n")
  cov <- x$annotation_coverage
  cat(sprintf("  Muscles: %d/%d (%.1f%%)\n",
              cov$muscle_matched, cov$muscle_total, cov$muscle_pct))
  cat(sprintf("  Bones:   %d/%d (%.1f%%)\n",
              cov$bone_matched, cov$bone_total, cov$bone_pct))
  cat("\n")

  cat("Community Profiles:\n")
  for (nm in names(x$community_profiles)) {
    p <- x$community_profiles[[nm]]
    region <- if (!is.na(p$dominant_region)) p$dominant_region else "unknown"
    action <- if (!is.na(p$dominant_action)) p$dominant_action else "unknown"
    cat(sprintf("  %s: %d muscles, region=%s, action=%s\n",
                nm, p$n_muscles, region, action))
  }

  if (nrow(x$cross_community_nerves) > 0) {
    cat("\nCross-Community Nerves (top 5):\n")
    top <- head(x$cross_community_nerves, 5)
    for (i in seq_len(nrow(top))) {
      cat(sprintf("  %s: spans %d communities (%s)\n",
                  top$nerve[i], top$n_communities[i], top$communities[i]))
    }
  }

  invisible(x)
}
