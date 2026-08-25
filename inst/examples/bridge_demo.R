#!/usr/bin/env Rscript
# ===========================================================================
# PhysioMSKNet Bridge Module Demonstration
# ===========================================================================
#
# PhysioMoCapのデモ歩行データ（合成MoCap + EMG + GRF）を用いて、
# 4つのブリッジモジュール全ての解析パイプラインを実証する。
#
# 必要パッケージ: PhysioMSKNet, PhysioMoCap, xml2
# ===========================================================================

library(PhysioMSKNet)
library(PhysioMoCap)

cat("
=============================================================
  PhysioMSKNet Bridge Module Demo
  MSK Network x PhysioMoCap Integration
=============================================================
\n")

# ------------------------------------------------------------------
# 0. データ準備
# ------------------------------------------------------------------

cat("--- 0. デモデータ生成 ---\n\n")

demo <- demoMoCapData(n_frames = 500, n_markers = 8,
                       sampling_rate = 120, emg_sampling_rate = 1000)

cat("MoCap: ", nrow(SummarizedExperiment::assay(demo$mocap, "position_x")),
    " frames x ", ncol(demo$mocap), " markers @ ", demo$sampling_rate, " Hz\n")
cat("  Markers: ", paste(colnames(demo$mocap), collapse = ", "), "\n")
cat("EMG:   ", nrow(demo$emg), " samples x ", ncol(demo$emg),
    " channels @ ", demo$emg_sampling_rate, " Hz\n")
cat("  Channels: ", paste(colnames(demo$emg), collapse = ", "), "\n")
cat("Forces: ", nrow(demo$forces), " frames x ", ncol(demo$forces), " axes\n\n")

# MSK Hypergraph（デフォルト: 173骨 x 270筋）
hg <- MSKHypergraph()
cat("MSK Hypergraph: ", hg$n_bones, " bones x ", hg$n_muscles, " muscles\n")
cat("  Total connections: ", sum(hg$C), "\n\n")


# ==================================================================
# 1. EMGブリッジ: 機能的結合 vs 構造的結合
# ==================================================================

cat("
===================================================
  1. EMG Bridge: 機能的-構造的結合の比較
===================================================
\n")

# 1a. EMGチャンネル → MSK筋肉マッピング
cat("--- 1a. EMG → MSK Mapping ---\n")
emg_mapping <- emgToMSKMapping(colnames(demo$emg), hg = hg, method = "fuzzy")
print(emg_mapping)
cat("\n")

# 1b. EMGコヒーレンス vs MSK構造隣接行列（Mantel検定）
cat("--- 1b. EMG Coherence vs MSK Structure (Mantel Test) ---\n")
emg_signal <- demo$emg
attr(emg_signal, "sr") <- demo$emg_sampling_rate

coh_result <- emgStructuralCoherence(emg_signal, hg = hg,
                                      freq_band = c(20, 50),
                                      mapping = emg_mapping)

cat("  Mapped muscles: ", paste(coh_result$mapped_muscles, collapse = ", "), "\n")
cat("  Mantel correlation: r = ", round(coh_result$correlation, 4), "\n")
cat("  Permutation p-value: p = ", round(coh_result$p_value, 4), "\n")
if (!is.na(coh_result$p_value) && coh_result$p_value < 0.05) {
  cat("  => EMG機能的結合はMSK構造的結合と有意に相関\n")
} else {
  cat("  => 有意な相関なし (合成データのため期待通り)\n")
}
cat("\n")

# 1c. EMGコヒーレンス行列の表示
cat("--- 1c. EMG Coherence Matrix ---\n")
print(round(coh_result$coherence_matrix, 3))
cat("\n")

# 1d. MSKコミュニティごとのEMG活性化
cat("--- 1d. EMG Activation Enrichment by MSK Community ---\n")
enrich <- emgMSKEnrichment(emg_signal, hg = hg, gamma = 4.3,
                            mapping = emg_mapping)
cat("  Communities with mapped muscles:\n")
print(enrich$per_community)
cat("  Kruskal-Wallis test:\n")
cat("    statistic = ", round(enrich$overall_test$statistic, 3),
    ", p = ", round(enrich$overall_test$p_value, 4), "\n\n")


# ==================================================================
# 2. MoCapブリッジ: 運動学的解析
# ==================================================================

cat("
===================================================
  2. MoCap Bridge: 運動学的ネットワーク解析
===================================================
\n")

# 2a. MoCapセグメント → MSK骨マッピング
cat("--- 2a. MoCap Segment → MSK Bone Mapping ---\n")

# demoデータのマーカー名を一般的なセグメント名に変換
segment_names <- c("pelvis", "pelvis", "shank", "shank",
                    "foot", "foot", "foot", "foot")
names(segment_names) <- colnames(demo$mocap)

mocap_mapping <- mocapToMSKMapping(unique(segment_names), hg = hg)
cat("  Mapped segments:\n")
print(mocap_mapping)
cat("\n")

# 2b. 運動カップリング vs MSK構造（Mantel検定）
cat("--- 2b. Kinematic Coupling vs MSK Structure ---\n")

# Position dataをmatrixとして抽出
pos_mat <- SummarizedExperiment::assay(demo$mocap, "position_x")
colnames(pos_mat) <- segment_names
attr(pos_mat, "sr") <- demo$sampling_rate

kin_result <- mocapNetworkKinematics(pos_mat, hg = hg,
                                      mapping = mocap_mapping,
                                      method = "correlation")
cat("  Mantel correlation: r = ", round(kin_result$correlation, 4), "\n")
cat("  p-value: ", round(kin_result$p_value, 4), "\n\n")

# 2c. 運動ストレスに基づく筋肉脆弱性予測
cat("--- 2c. Kinematic Stress → Muscle Vulnerability ---\n")

impact_result <- mocapImpactPrediction(pos_mat, hg = hg,
                                        mapping = mocap_mapping,
                                        stress_metric = "acceleration",
                                        use_proxy = TRUE)

cat("  Bone stress (matched segments):\n")
for (i in seq_along(impact_result$bone_stress)) {
  cat(sprintf("    %-20s: %.4f\n",
              names(impact_result$bone_stress)[i],
              impact_result$bone_stress[i]))
}
cat("\n  Top 10 vulnerable muscles:\n")
top10 <- head(impact_result$ranking, 10)
for (i in seq_len(nrow(top10))) {
  cat(sprintf("    %2d. %-30s vuln = %.4f  stress = %.4f\n",
              i, top10$muscle[i], top10$vulnerability[i],
              top10$stress_exposure[i]))
}
cat("\n")

# 2d. コミュニティ内 vs コミュニティ間の運動同期性
cat("--- 2d. Community Dynamics: Within vs Between Synchrony ---\n")

# Use unique segments for community dynamics
pos_unique <- pos_mat[, !duplicated(colnames(pos_mat)), drop = FALSE]

comm_dyn <- mocapCommunityDynamics(pos_unique, hg = hg, gamma = 4.3,
                                    mapping = mocap_mapping)

cat("  Within-community sync:  ", round(comm_dyn$within_community_sync, 4), "\n")
cat("  Between-community sync: ", round(comm_dyn$between_community_sync, 4), "\n")
if (!is.na(comm_dyn$ratio)) {
  cat("  Ratio (within/between): ", round(comm_dyn$ratio, 4), "\n")
}
if (!is.na(comm_dyn$p_value)) {
  cat("  Wilcoxon p-value:       ", round(comm_dyn$p_value, 4), "\n")
}
cat("\n")


# ==================================================================
# 3. OpenSimブリッジ: .osimモデルからのネットワーク構築
# ==================================================================

cat("
===================================================
  3. OpenSim Bridge: .osimモデルからMSKHypergraph構築
===================================================
\n")

# テスト用の最小.osimファイルを作成
osim_path <- tempfile(fileext = ".osim")
osim_xml <- '<?xml version="1.0" encoding="UTF-8" ?>
<OpenSimDocument Version="40000">
  <Model name="gait_demo">
    <BodySet>
      <objects>
        <Body name="pelvis"/><Body name="femur_r"/><Body name="femur_l"/>
        <Body name="tibia_r"/><Body name="tibia_l"/>
        <Body name="talus_r"/><Body name="talus_l"/>
        <Body name="calcn_r"/><Body name="calcn_l"/>
        <Body name="toes_r"/><Body name="toes_l"/>
        <Body name="torso"/><Body name="humerus_r"/><Body name="humerus_l"/>
      </objects>
    </BodySet>
    <ForceSet>
      <objects>
        <Thelen2003Muscle name="glut_max_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>pelvis</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="glut_max_l">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>pelvis</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>femur_l</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="iliopsoas_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>pelvis</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>torso</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p3"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="rect_fem_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>pelvis</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p3"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="vas_med_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="vas_lat_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="gastroc_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p3"><socket_parent_frame>calcn_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="soleus_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>calcn_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="tib_ant_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>toes_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
        <Thelen2003Muscle name="biceps_fem_r">
          <GeometryPath><PathPointSet><objects>
            <PathPoint name="p1"><socket_parent_frame>pelvis</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p2"><socket_parent_frame>femur_r</socket_parent_frame><location>0 0 0</location></PathPoint>
            <PathPoint name="p3"><socket_parent_frame>tibia_r</socket_parent_frame><location>0 0 0</location></PathPoint>
          </objects></PathPointSet></GeometryPath>
        </Thelen2003Muscle>
      </objects>
    </ForceSet>
  </Model>
</OpenSimDocument>'
writeLines(osim_xml, osim_path)

# 3a. .osim → MSKHypergraph
cat("--- 3a. OpenSim Model → MSKHypergraph ---\n")
osim_hg <- opensimToMSKHypergraph(model_path = osim_path)
print(osim_hg)
cat("\n")

# 3b. ネットワーク解析
cat("--- 3b. Network Analysis on OpenSim Model ---\n")
osim_analysis <- opensimNetworkAnalysis(model_path = osim_path,
                                         gamma = 1.0,
                                         run_simulation = TRUE)
print(osim_analysis)
cat("\n")

# 3c. 筋力データによる重み付きインパクト
cat("--- 3c. Force-weighted Impact Scores ---\n")
force_data <- c(glut_max_r = 800, rect_fem_r = 600, gastroc_r = 500,
                soleus_r = 700, tib_ant_r = 300, vas_med_r = 450,
                vas_lat_r = 400, biceps_fem_r = 350,
                iliopsoas_r = 250, glut_max_l = 750)

force_result <- opensimForceToImpact(osim_path, force_data = force_data,
                                      hg = osim_hg,
                                      method = "weighted_scores")

cat("  Force-weighted impact scores:\n")
sorted_scores <- sort(force_result$weighted_impact_scores, decreasing = TRUE)
for (i in seq_along(sorted_scores)) {
  cat(sprintf("    %-20s: weighted = %8.2f  (unweighted = %8.2f, force = %.2f)\n",
              names(sorted_scores)[i],
              sorted_scores[i],
              force_result$unweighted_scores[names(sorted_scores)[i]],
              force_result$force_weights[names(sorted_scores)[i]]))
}
cat("\n")

unlink(osim_path)


# ==================================================================
# 4. 臨床ブリッジ: 損傷予測 & リハビリプロトコル
# ==================================================================

cat("
===================================================
  4. Clinical Bridge: 損傷予測とリハビリ計画
===================================================
\n")

# 4a. 臨床的予測（デフォルト173x270ネットワーク使用）
cat("--- 4a. Clinical Prediction: Biceps Brachii + Deltoid ---\n")
pred <- mskClinicalPredictor(c("Biceps Brachii", "Deltoid"),
                              hg = hg, verbose = FALSE)
print(pred)
cat("\n")

# 4b. 回復タイムライン
cat("--- 4b. Recovery Timeline ---\n")
sim <- mskSimulate(hg)
timeline <- mskRecoveryTimeline("Trapezius", hg = hg, sim = sim, n_weeks = 12)
cat("  Week  Remaining%  Phase          Milestone\n")
cat("  ----  ----------  -------------  ---------\n")
for (i in seq_len(nrow(timeline))) {
  r <- timeline[i, ]
  cat(sprintf("  %4d  %9.1f%%  %-13s  %s\n",
              r$week, r$remaining_impact_pct, r$phase, r$milestone))
}
cat("\n")

# 4c. 患者リスクプロファイル
cat("--- 4c. Patient-specific Injury Risk Profile ---\n")
profile <- mskInjuryRiskProfile(
  patient_data = list(
    age = 45,
    bmi = 27.5,
    activity_level = "active",
    prior_injuries = c("Gastrocnemius", "Soleus")
  ),
  hg = hg
)
print(profile)
cat("\n")

# 4d. リハビリプロトコル
cat("--- 4d. Rehabilitation Protocol: Rectus Femoris ---\n")
protocol <- mskRehabProtocol("Rectus Femoris", hg = hg)
print(protocol)
cat("\n")

# 4e. 統合アウトカムサマリー
cat("--- 4e. Integrated Outcome Summary ---\n")
summary <- mskOutcomeSummary(
  "Gastrocnemius",
  patient_data = list(age = 35, activity_level = "active"),
  hg = hg, sim = sim
)
print(summary)


# ==================================================================
# 5. クロスモーダル統合パイプライン
# ==================================================================

cat("
===================================================
  5. Cross-modal Integration Pipeline
  EMG + MoCap → MSK Network → 臨床予測
===================================================
\n")

# Step 1: EMGから最も活性化の高い筋肉を特定
cat("--- Step 1: EMG活性化レベル ---\n")
rms_activation <- apply(demo$emg, 2, function(x) sqrt(mean(x^2)))
cat("  RMS activation:\n")
for (nm in names(rms_activation)) {
  cat(sprintf("    %-25s: %.4f\n", nm, rms_activation[nm]))
}
most_active <- names(which.max(rms_activation))
cat("  Most active muscle: ", most_active, "\n\n")

# Step 2: MoCapから最もストレスの高い骨を特定
cat("--- Step 2: MoCap Bone Stress ---\n")
cat("  Highest stress bone: ",
    names(which.max(impact_result$bone_stress)), "\n")
cat("  Stress value: ",
    round(max(impact_result$bone_stress), 4), "\n\n")

# Step 3: ネットワーク解析で脆弱な筋肉を特定
cat("--- Step 3: MSK Network Vulnerability (top 5) ---\n")
top5_vuln <- head(impact_result$ranking, 5)
print(top5_vuln, row.names = FALSE)
cat("\n")

# Step 4: 最も脆弱な筋肉に対する臨床予測
target_muscle <- top5_vuln$muscle[1]
cat("--- Step 4: Clinical prediction for: ", target_muscle, " ---\n")

# 名前のマッチングを試みる
target_pred <- tryCatch({
  mskClinicalPredictor(target_muscle, hg = hg, sim = sim, verbose = FALSE)
}, error = function(e) {
  cat("  (Default networkでマッチせず、代替筋肉で実行)\n")
  mskClinicalPredictor("Gastrocnemius", hg = hg, sim = sim, verbose = FALSE)
})
print(target_pred)


# ==================================================================
# Summary
# ==================================================================

cat("
=============================================================
  Demo Complete - Summary of Analyses Performed
=============================================================

  1. EMG Bridge
     - 4 EMG channels → 270 MSK muscles mapping (fuzzy match)
     - Coherence vs structural connectivity (Mantel test)
     - Community-level activation enrichment (Kruskal-Wallis)

  2. MoCap Bridge
     - 8 MoCap markers → 173 MSK bones mapping (curated lookup)
     - Kinematic coupling vs structural adjacency (Mantel test)
     - Stress-based muscle vulnerability ranking (270 muscles)
     - Within vs between community movement synchrony (Wilcoxon)

  3. OpenSim Bridge
     - .osim XML → MSKHypergraph construction (10 muscles, 13 bodies)
     - Full network analysis (metrics + communities + impact)
     - Force-weighted impact scoring

  4. Clinical Bridge
     - Recovery prediction with 95% CI
     - 12-week recovery timeline with phase assignment
     - Patient-specific risk profile (age, BMI, activity, prior injuries)
     - 3-phase rehabilitation protocol

  5. Cross-modal Integration
     - EMG activation → MoCap stress → MSK vulnerability → Clinical outcome

  All analyses use PhysioMoCap demoMoCapData() (synthetic gait data)
  and PhysioMSKNet built-in 173-bone/270-muscle network.
=============================================================
\n")
