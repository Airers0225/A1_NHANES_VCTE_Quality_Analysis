# A1_NHANES_VCTE_Quality_Analysis

Companion code for **Sensitivity of Obesity-Stratified Estimates of Elevated Liver Stiffness to VCTE Examination-Quality Criteria: A Repeated Cross-Sectional Analysis of Two NHANES Survey Periods**.

The workflow analyzes the 2017–March 2020 prepandemic and August 2021–August 2023 NHANES releases separately. It estimates how an examination inclusion rule changes the BMI-stratified weighted proportion with a recorded median liver stiffness measurement (LSM) ≥8 kPa. The thresholds classify recorded stiffness. The all-unknown bounds hold strict-sample classifications fixed and leave all others in the target domain unknown.

**Authors:** Yiheng Jiang and Wenyan Yang  
**Affiliation:** The Affiliated Hospital of Guizhou Medical University, Guiyang, Guizhou, China.

## Data and setup

Use R **4.6.1** with **foreign 0.8-91**, **survey 4.5**, and PNG/Cairo graphics support. See [requirements_R.txt](environment/requirements_R.txt) and the verified [sessionInfo.txt](environment/sessionInfo.txt). From the repository root, choose one input method.

- **Automatic download.** Run `Rscript --vanilla run_all.R --download`. It retrieves missing XPTs from the URLs in [the CDC download manifest](audit_download_manifest.csv), verifies the pinned byte counts and SHA-256 digests, then runs the full workflow.
- **Manual download or cached files.** Use the official URL in each manifest row. Put the four files from each release in the indicated subdirectory and run `Rscript --vanilla run_all.R`. Existing files must match the manifest. If a CDC release has changed, review the provenance before substituting inputs.

| NHANES release | Local subdirectory | Required XPTs | MEC weight |
| --- | --- | --- | --- |
| 2017–March 2020 prepandemic | `public_nhanes/2017/` | `P_DEMO.xpt`, `P_LUX.xpt`, `P_BMX.xpt`, `P_DIQ.xpt` | `WTMECPRP` |
| August 2021–August 2023 | `public_nhanes/2021/` | `DEMO_L.xpt`, `LUX_L.xpt`, `BMX_L.xpt`, `DIQ_L.xpt` | `WTMEC2YR` |

The XPT files are distributed by CDC and stay out of this repository. The diabetes questionnaire files are read by the historical count reconciliation. No diabetes or laboratory value is used to define the main sample or outcome. [CDC NHANES public portal](https://wwwn.cdc.gov/nchs/nhanes/) · [2017–March 2020 VCTE codebook](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_LUX.htm) · [2021–2023 VCTE codebook](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/LUX_L.htm)

The workflow was verified in a new Windows directory using R 4.6.1, an isolated library of existing R packages and cached CDC files. All eight XPTs passed SHA-256 verification, and all eight regenerated aggregate CSVs matched the frozen results byte for byte. Automated download and installation of the full set of dependencies in a fresh environment remain unverified. See [RESULTS_CHECK.md](documentation/RESULTS_CHECK.md).

## What runs and what it creates

Run the commands from the repository root. Analysis scripts are in `R/`, the frozen aggregate comparison tables are in `expected/`, and the run order is:

1. `run_all.R` validates the input files. `R/A1_analysis.R` calls `R/audit_nhanes.R` to check historical counts and writes `audit_counts_R.csv`.
2. `R/A1_analysis.R` fits the two survey designs with masked strata and nested PSUs. It obtains joint totals, uses Taylor linearization for the ratio contrasts and derives design-based t intervals. It generates the main analysis, sensitivity estimates, bounds and quality audit counts.
3. The runner calls the reusable function in `R/A1_ReasonCode_Audit_Code.R` to verify reason code 2 against both full VCTE releases and the frozen analysis outputs. The runner keeps record-level results in memory. Calling the audit script directly exports a participant-keyed CSV locally. Keep that export and its console log out of commits and releases.
4. `R/plot_sample_flow.R` makes an independent reconstruction of the participant flow from the generated counts. `R/A1_plot.R` draws the six principal contrasts and their confidence intervals in Figure 2.
5. `R/check_results.R` compares the eight generated CSVs with the frozen aggregate copies in `expected/`. See [RESULTS_CHECK.md](documentation/RESULTS_CHECK.md) for the observed check and [DATA_DICTIONARY.md](documentation/DATA_DICTIONARY.md) for input and output fields.

The output directory `A1_results/` contains `A1_primary_results.csv`, `A1_bounds.csv`, `A1_sensitivity.csv`, `A1_sample_flow.csv`, `A1_quality_crosstab.csv`, `A1_at_8_kpa.csv`, `A1_design.csv`, `A1_count_reconciliation.csv`, `A1_sessionInfo.txt`, `A1_sample_flow_figure.png`, `A1_delta_figure.png` and `A1_delta_figure.pdf`. The reconstructed flow graphic uses a different layout from submission Figure 1. The verified submission graphics remain in the separate submission package.

## Key results for verification

Strict and relaxed values are percentages. Differences and confidence limits are percentage points.

| Survey period | BMI, kg/m² | Strict | Relaxed | Difference (95% CI) |
| --- | --- | ---: | ---: | --- |
| 2017–March 2020 | 18.5 to <30 | 4.26 | 4.52 | 0.27 (−0.01 to 0.54) |
| 2017–March 2020 | ≥30 | 16.70 | 18.95 | 2.25 (1.27 to 3.23) |
| 2017–March 2020 | Between-BMI contrast | — | — | 1.98 (1.11 to 2.85) |
| August 2021–August 2023 | 18.5 to <30 | 5.83 | 6.17 | 0.35 (0.09 to 0.60) |
| August 2021–August 2023 | ≥30 | 21.52 | 23.26 | 1.74 (1.07 to 2.40) |
| August 2021–August 2023 | Between-BMI contrast | — | — | 1.39 (0.77 to 2.02) |

Target-domain counts are 7,792 and 5,580. Strict counts are 7,228 and 5,169. Relaxed counts are 7,498 and 5,397. In the primary domain among adults with obesity, all-unknown bound widths are 8.92 and 9.35 percentage points.

## Citation and release

Citation metadata are in [CITATION.cff](CITATION.cff). Yiheng Jiang and Wenyan Yang hold the copyright (2026). The [MIT License](LICENSE) covers repository code and materials the authors have the right to license. CDC distributes the original NHANES data separately under its own terms. The MIT License does not apply to those data.
