#!/usr/bin/env Rscript
# ===========================================================================
# PhysioMSKNet × PhysioAnnotationHub 知識グラフ統合デモ
# ===========================================================================
#
# MSK ネットワーク解析に解剖学的知識グラフを統合し、
# 解釈可能な臨床・機能的結果を得るデモンストレーション
#
# 必要パッケージ: PhysioMSKNet, PhysioAnnotationHub
# ===========================================================================

library(PhysioMSKNet)
library(PhysioAnnotationHub)

cat("\n")
cat("=============================================================\n")
cat("  PhysioMSKNet × PhysioAnnotationHub\n")
cat("  知識グラフ統合デモ\n")
cat("=============================================================\n\n")

# ---- 0. データ準備 ----
cat("--- 0. データ準備 ---\n\n")

hg <- MSKHypergraph()
hub <- loadAnnotationHub()

cat("MSK Hypergraph:", hg$n_bones, "bones ×", hg$n_muscles, "muscles\n")
cat("KG Hub:\n")
cat("  Muscle annotations:", nrow(hub$muscles), "\n")
cat("  Bone annotations:  ", nrow(hub$bones), "\n")
cat("  Nerve records:     ", nrow(hub$nerves), "\n")
cat("  KG Triples:        ", nrow(hub$triples), "\n")
cat("  ICD-10 Codes:      ", nrow(hub$icd10), "\n")
cat("  ICF Codes:         ", nrow(hub$icf), "\n\n")

# ---- 1. ハイパーグラフのアノテーション ----
cat("===================================================\n")
cat("  1. MSKHypergraph のアノテーション\n")
cat("===================================================\n\n")

hg_ann <- mskAnnotate(hg, hub)

cat("アノテーション結果:\n")
cat("  筋アノテーション: ", nrow(hg_ann$muscle_annotations), "筋\n")
cat("  骨アノテーション: ", nrow(hg_ann$bone_annotations), "骨\n")
cat("  カバレッジ:\n")
cat("    筋マッチ:", sprintf("%.1f%%", hg_ann$annotation_coverage$muscle_pct), "\n")
cat("    骨マッチ:", sprintf("%.1f%%", hg_ann$annotation_coverage$bone_pct), "\n\n")

# 体部位別筋数
cat("--- 体部位別筋数 ---\n")
region_table <- table(hg_ann$muscle_annotations$body_region)
region_table <- sort(region_table, decreasing = TRUE)
for (r in names(region_table)) {
  cat(sprintf("  %-15s: %3d muscles\n", r, region_table[r]))
}
cat("\n")

# ---- 2. 機能的エンリッチメント解析 ----
cat("===================================================\n")
cat("  2. 機能的エンリッチメント解析\n")
cat("===================================================\n\n")

# 肩関節損傷シナリオ: 回旋筋腱板
rotator_cuff <- c("Supraspinatus", "Infraspinatus", "Teres Minor", "Subscapularis")

cat("--- 2a. 回旋筋腱板の神経エンリッチメント ---\n")
cat("  Query: ", paste(rotator_cuff, collapse = ", "), "\n\n")

nerve_enrich <- mskEnrichKG(rotator_cuff, annotation_type = "nerve", hub = hub, hg = hg)
if (nrow(nerve_enrich) > 0) {
  cat("  結果:\n")
  for (i in seq_len(min(5, nrow(nerve_enrich)))) {
    sig <- if (!is.null(nerve_enrich$significant) && nerve_enrich$significant[i]) " ***" else ""
    cat(sprintf("    %-30s  count=%d  fold=%.1f  p=%.4f%s\n",
                nerve_enrich$term[i], nerve_enrich$count[i],
                nerve_enrich$fold_enrichment[i], nerve_enrich$p_value[i], sig))
  }
} else {
  cat("  (エンリッチメント結果なし)\n")
}
cat("\n")

cat("--- 2b. 回旋筋腱板のアクション エンリッチメント ---\n")
action_enrich <- mskEnrichKG(rotator_cuff, annotation_type = "action", hub = hub, hg = hg)
if (nrow(action_enrich) > 0) {
  cat("  結果:\n")
  for (i in seq_len(min(5, nrow(action_enrich)))) {
    sig <- if (!is.null(action_enrich$significant) && action_enrich$significant[i]) " ***" else ""
    cat(sprintf("    %-30s  count=%d  fold=%.1f  p=%.4f%s\n",
                action_enrich$term[i], action_enrich$count[i],
                action_enrich$fold_enrichment[i], action_enrich$p_value[i], sig))
  }
} else {
  cat("  (エンリッチメント結果なし)\n")
}
cat("\n")

# ハムストリングのエンリッチメント
hamstrings <- c("Semitendinosus", "Semimembranosus", "Biceps Femoris")
cat("--- 2c. ハムストリングの体部位エンリッチメント ---\n")
cat("  Query: ", paste(hamstrings, collapse = ", "), "\n\n")

region_enrich <- mskEnrichKG(hamstrings, annotation_type = "body_region", hub = hub, hg = hg)
if (nrow(region_enrich) > 0) {
  cat("  結果:\n")
  for (i in seq_len(min(5, nrow(region_enrich)))) {
    sig <- if (!is.null(region_enrich$significant) && region_enrich$significant[i]) " ***" else ""
    cat(sprintf("    %-30s  count=%d  fold=%.1f  p=%.4f%s\n",
                region_enrich$term[i], region_enrich$count[i],
                region_enrich$fold_enrichment[i], region_enrich$p_value[i], sig))
  }
}
cat("\n")

# ---- 3. 知識グラフ パスウェイ探索 ----
cat("===================================================\n")
cat("  3. 知識グラフ パスウェイ探索\n")
cat("===================================================\n\n")

# Biceps Brachii → Triceps Brachii (拮抗筋パス)
cat("--- 3a. Biceps Brachii → Triceps Brachii ---\n")
path1 <- mskPathwayQuery("Biceps Brachii", "Triceps Brachii", hub = hub)
if (path1$found) {
  cat("  パス発見 (depth =", path1$depth, "):\n")
  cat("  ", path1$description, "\n")
} else {
  cat("  パスなし\n")
}
cat("\n")

# 上肢筋 → 脊髄レベル (神経経路トレース)
cat("--- 3b. Deltoid → 脊髄レベルへの神経経路 ---\n")
path2 <- mskPathwayQuery("Deltoid", "C5", hub = hub)
if (path2$found) {
  cat("  パス発見 (depth =", path2$depth, "):\n")
  cat("  ", path2$description, "\n")
} else {
  cat("  パスなし\n")
}
cat("\n")

# Gastrocnemius → Rectus Femoris (下肢クロス)
cat("--- 3c. Gastrocnemius → Rectus Femoris ---\n")
path3 <- mskPathwayQuery("Gastrocnemius", "Rectus Femoris", hub = hub)
if (path3$found) {
  cat("  パス発見 (depth =", path3$depth, "):\n")
  cat("  ", path3$description, "\n")
} else {
  cat("  パスなし\n")
}
cat("\n")

# ---- 4. コミュニティ機能プロファイリング ----
cat("===================================================\n")
cat("  4. コミュニティ機能プロファイリング\n")
cat("===================================================\n\n")

# コミュニティ検出
comm_result <- mskCommunityDetect(hg, gamma = 4.3)
membership <- comm_result$membership
n_communities <- comm_result$n_communities
cat("コミュニティ数:", n_communities, "(gamma = 4.3)\n\n")

# 主要コミュニティのプロファイル (上位3つ)
comm_sizes <- sort(table(membership), decreasing = TRUE)
top_comms <- as.integer(names(comm_sizes)[seq_len(min(3, length(comm_sizes)))])

for (cid in top_comms) {
  cat(sprintf("--- Community %d (n = %d muscles) ---\n", cid, comm_sizes[as.character(cid)]))

  profile <- tryCatch(
    mskCommunityProfile(hg, cid, hub = hub, gamma = 4.3),
    error = function(e) {
      cat("  プロファイル生成エラー:", conditionMessage(e), "\n\n")
      NULL
    }
  )

  if (!is.null(profile)) {
    cat("  優勢アクション: ", profile$dominant_action, "\n")
    cat("  優勢神経:       ", profile$dominant_nerve, "\n")
    cat("  優勢体部位:     ", profile$dominant_region, "\n")
    cat("  平均次数:       ", sprintf("%.1f", profile$mean_degree), "\n")

    # 上位アクション分布
    top_actions <- sort(profile$action_profile, decreasing = TRUE)
    cat("  アクション分布: ")
    for (j in seq_len(min(3, length(top_actions)))) {
      if (j > 1) cat(", ")
      cat(sprintf("%s(%d)", names(top_actions)[j], top_actions[j]))
    }
    cat("\n")

    # 所属筋 (最初の5つ)
    cat("  所属筋 (例):    ", paste(head(profile$muscles, 5), collapse = ", "))
    if (length(profile$muscles) > 5) cat(", ...")
    cat("\n")
  }
  cat("\n")
}

# ---- 5. 臨床エビデンスマッピング ----
cat("===================================================\n")
cat("  5. 臨床エビデンスマッピング\n")
cat("===================================================\n\n")

# ACL損傷関連筋群
cat("--- 5a. 前十字靱帯 (ACL) 損傷関連筋群 ---\n")
acl_muscles <- c("Rectus Femoris", "Vastus Lateralis", "Vastus Medialis",
                 "Semitendinosus", "Gastrocnemius")
cat("  対象筋:", paste(acl_muscles, collapse = ", "), "\n\n")

evidence <- mskClinicalEvidence(acl_muscles, hub = hub, hg = hg)

cat("  ICD-10 コード:\n")
if (nrow(evidence$icd10_codes) > 0) {
  for (i in seq_len(min(5, nrow(evidence$icd10_codes)))) {
    cat(sprintf("    %s  %s\n",
                evidence$icd10_codes$icd10_code[i],
                evidence$icd10_codes$description[i]))
  }
} else {
  cat("    (該当コードなし)\n")
}
cat("\n")

cat("  ICF コード:\n")
if (nrow(evidence$icf_codes) > 0) {
  for (i in seq_len(min(5, nrow(evidence$icf_codes)))) {
    cat(sprintf("    %s  %s\n",
                evidence$icf_codes$icf_code[i],
                evidence$icf_codes$description[i]))
  }
} else {
  cat("    (該当コードなし)\n")
}
cat("\n")

cat("  影響を受ける神経:\n")
if (length(evidence$affected_nerves) > 0) {
  for (nerve in evidence$affected_nerves) {
    cat("    -", nerve, "\n")
  }
} else {
  cat("    (該当神経なし)\n")
}
cat("\n")

cat("  影響を受ける脊髄レベル:\n")
if (length(evidence$affected_spinal_levels) > 0) {
  cat("    ", paste(evidence$affected_spinal_levels, collapse = ", "), "\n")
} else {
  cat("    (該当レベルなし)\n")
}
cat("\n")

cat("  機能的影響 (障害されるアクション):\n")
if (length(evidence$functional_impact) > 0) {
  for (action in evidence$functional_impact) {
    cat("    -", action, "\n")
  }
} else {
  cat("    (該当アクションなし)\n")
}
cat("\n")

cat("  共同筋 (synergists):\n")
if (length(evidence$synergists) > 0) {
  cat("    ", paste(head(evidence$synergists, 8), collapse = ", "), "\n")
} else {
  cat("    (該当なし)\n")
}
cat("\n")

cat("  拮抗筋 (antagonists):\n")
if (length(evidence$antagonists) > 0) {
  cat("    ", paste(head(evidence$antagonists, 8), collapse = ", "), "\n")
} else {
  cat("    (該当なし)\n")
}
cat("\n")

# ---- 6. KG統合 + MSKインパクト解析 ----
cat("===================================================\n")
cat("  6. KG統合 + MSKインパクト解析\n")
cat("     回旋筋腱板損傷の総合評価\n")
cat("===================================================\n\n")

cat("--- 6a. 回旋筋腱板のネットワーク指標 ---\n")
# Impact scores (proxy)
deg <- hyperedgeDegree(hg)
rot_idx <- which(hg$muscle_names %in% rotator_cuff)
rot_deg <- deg[rot_idx]

cat("  筋名                       次数  体部位     神経\n")
cat("  ----                       ----  --------   ----\n")
for (i in seq_along(rot_idx)) {
  m_name <- hg$muscle_names[rot_idx[i]]
  m_ann <- getMuscleAnnotation(m_name, hub)
  nerve_str <- if (nrow(m_ann) > 0) m_ann$nerve[1] else "N/A"
  region_str <- if (nrow(m_ann) > 0) m_ann$sub_region[1] else "N/A"
  cat(sprintf("  %-28s %3d   %-10s %s\n",
              m_name, rot_deg[i], region_str, nerve_str))
}
cat("\n")

# 臨床予測
cat("--- 6b. 回旋筋腱板損傷の臨床予測 ---\n")
clinical <- mskClinicalPredictor(rotator_cuff, hg = hg, verbose = FALSE)

cat("\n  回復予測:\n")
for (i in seq_len(nrow(clinical$recovery))) {
  cat(sprintf("    %-20s: %.1f 週 (95%% CI: %.1f-%.1f)\n",
              clinical$recovery$muscle[i],
              clinical$recovery$predicted_weeks[i],
              clinical$recovery$ci_lower[i],
              clinical$recovery$ci_upper[i]))
}
cat("\n")

# 二次損傷リスク + KGアノテーション
cat("  二次損傷リスク (上位5筋 + KGアノテーション):\n")
top_risk <- head(clinical$secondary_risk, 5)
cat("  筋名                       リスク  神経              アクション\n")
cat("  ----                       ------  ----              ----------\n")
for (i in seq_len(nrow(top_risk))) {
  m_ann <- getMuscleAnnotation(top_risk$muscle[i], hub)
  nerve_str <- if (nrow(m_ann) > 0) m_ann$nerve[1] else "N/A"
  action_str <- if (nrow(m_ann) > 0) m_ann$action_primary[1] else "N/A"
  cat(sprintf("    %-25s %.3f   %-18s %s\n",
              top_risk$muscle[i], top_risk$risk[i],
              nerve_str, action_str))
}
cat("\n")

# リハビリプロトコル + KGアノテーション
cat("--- 6c. リハビリプロトコル (KG強化) ---\n")
rehab <- mskRehabProtocol(rotator_cuff, hg = hg)

phase_names <- c("Isolated", "Intra-community", "Cross-community")
for (phase in seq_len(min(3, length(rehab$phases)))) {
  p <- rehab$phases[[phase]]
  p_name <- if (phase <= length(phase_names)) phase_names[phase] else paste("Phase", phase)
  n_muscles <- nrow(p)
  cat(sprintf("\n  Phase %d - %s (%d muscles):\n", phase, p_name, n_muscles))

  show_n <- min(6, n_muscles)
  if (show_n > 0) {
    role_col <- if ("type" %in% names(p)) "type" else if ("role" %in% names(p)) "role" else NULL
    for (j in seq_len(show_n)) {
      m_name <- p$muscle[j]
      m_ann <- getMuscleAnnotation(m_name, hub)
      nerve_str <- if (nrow(m_ann) > 0) m_ann$nerve[1] else ""
      action_str <- if (nrow(m_ann) > 0) m_ann$action_primary[1] else ""
      role_str <- if (!is.null(role_col)) p[[role_col]][j] else ""
      cat(sprintf("    %-25s [%s] nerve=%-20s action=%s\n",
                  m_name, role_str, nerve_str, action_str))
    }
    if (show_n < n_muscles) {
      cat(sprintf("    ... and %d more\n", n_muscles - show_n))
    }
  }
}
cat("\n")

# ---- 7. 全体KGサマリー (上位コミュニティ) ----
cat("===================================================\n")
cat("  7. KG統合サマリー\n")
cat("===================================================\n\n")

# Quick summary without full simulation
cat("--- 体部位別ネットワーク特性 ---\n\n")
cat("  体部位          筋数   平均次数   主要アクション\n")
cat("  --------        ----   --------   --------------\n")

regions <- unique(hg_ann$muscle_annotations$body_region)
regions <- regions[!is.na(regions) & regions != ""]
for (reg in sort(regions)) {
  reg_muscles <- hg_ann$muscle_annotations$muscle_name[
    hg_ann$muscle_annotations$body_region == reg & hg_ann$muscle_annotations$matched]
  reg_idx <- which(hg$muscle_names %in% reg_muscles)
  if (length(reg_idx) == 0) next
  mean_deg <- mean(deg[reg_idx])

  # Most common action in this region
  actions <- hg_ann$muscle_annotations$action_primary[
    hg_ann$muscle_annotations$body_region == reg & hg_ann$muscle_annotations$matched]
  actions <- actions[!is.na(actions)]
  if (length(actions) > 0) {
    top_action <- names(sort(table(actions), decreasing = TRUE))[1]
  } else {
    top_action <- "N/A"
  }

  cat(sprintf("  %-16s %3d    %5.1f      %s\n",
              reg, length(reg_idx), mean_deg, top_action))
}
cat("\n")

# ---- 8. 解釈可能なインサイト ----
cat("===================================================\n")
cat("  8. 解釈可能なインサイト (結論)\n")
cat("===================================================\n\n")

cat("【回旋筋腱板損傷の知識グラフ統合解析結果】\n\n")

cat("1. 神経学的知見:\n")
rot_nerves <- unique(unlist(lapply(rotator_cuff, function(m) {
  ann <- getMuscleAnnotation(m, hub)
  if (nrow(ann) > 0) ann$nerve else character(0)
})))
rot_spinal <- unique(unlist(lapply(rotator_cuff, function(m) {
  ann <- getMuscleAnnotation(m, hub)
  if (nrow(ann) > 0) ann$spinal_level else character(0)
})))
cat("   - 支配神経:", paste(rot_nerves, collapse = ", "), "\n")
cat("   - 脊髄レベル:", paste(rot_spinal, collapse = ", "), "\n")
cat("   → 上腕神経叢 (C5-C6) の評価が臨床的に重要\n\n")

cat("2. 機能的影響:\n")
rot_actions <- unique(unlist(lapply(rotator_cuff, function(m) {
  triples <- queryKG(subject = m, predicate = "has_action", hub = hub)
  if (nrow(triples) > 0) triples$object else character(0)
})))
cat("   - 障害されるアクション:", paste(head(rot_actions, 5), collapse = ", "), "\n")
cat("   → 肩関節の安定化と外旋/外転が主に障害される\n\n")

cat("3. 二次損傷リスク:\n")
cat("   - Trapezius (risk=", sprintf("%.3f", top_risk$risk[1]), ") が最高リスク\n")
cat("   - 同一コミュニティ内の代償筋が過負荷になる可能性\n")
cat("   → 代償パターンのモニタリングが重要\n\n")

cat("4. リハビリ戦略:\n")
cat("   - Phase 1: 損傷筋の安静 + 同コミュニティ非隣接筋の維持運動\n")
cat("   - Phase 2: コミュニティ内の段階的負荷増加\n")
cat("   - Phase 3: 隣接コミュニティへの機能統合\n")
cat("   → MSKネットワーク構造に基づく段階的リハビリテーション\n\n")

# ICD-10 mapping
cat("5. 臨床コードマッピング:\n")
rot_icd <- getClinicalCodes(rotator_cuff, system = "icd10", hub = hub)
if (nrow(rot_icd) > 0) {
  for (i in seq_len(min(3, nrow(rot_icd)))) {
    cat(sprintf("   - %s: %s\n", rot_icd$icd10_code[i], rot_icd$description[i]))
  }
}
cat("\n")

cat("=============================================================\n")
cat("  デモ完了 - 知識グラフ統合により以下が可能に:\n")
cat("  - 解剖学的アノテーション (270筋×神経/アクション/部位)\n")
cat("  - 機能的エンリッチメント解析 (超幾何検定)\n")
cat("  - KGパスウェイ探索 (BFS最短経路)\n")
cat("  - コミュニティ機能プロファイリング\n")
cat("  - 臨床エビデンスマッピング (ICD-10/ICF)\n")
cat("  - MSKネットワーク指標 + KGの統合解釈\n")
cat("=============================================================\n")
