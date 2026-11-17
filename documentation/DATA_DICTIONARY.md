# Data dictionary

All source files are CDC public-use XPTs. SAS missing values read as `NA` in R. Merge by `SEQN` within each release and check key uniqueness. For file versions, rows, URLs and checksums see [the download manifest](../audit_download_manifest.csv).

| Component | Field | Meaning and role |
| --- | --- | --- |
| All files | `SEQN` | Respondent sequence number. Used to link component files within one period. |
| DEMO | `RIDAGEYR` | Age in years. Main domain starts at age 20. |
| DEMO | `RIDSTATR` | Interview/examination status. Code 2 corresponds to an examined participant, cross-checked against positive MEC weight. |
| DEMO | `WTMECPRP`, `WTMEC2YR` | MEC examination weights for the prepandemic and 2021–2023 releases, respectively. Full survey designs use positive weights. |
| DEMO | `SDMVSTRA`, `SDMVPSU` | Masked stratum and PSU. PSUs are nested within strata. |
| DEMO | `RIAGENDR`, `RIDRETH3` | Released sex and race/Hispanic-origin codes. Used in legacy count reconciliation only. |
| BMX | `BMXBMI` | Measured BMI in kg/m². Main strata are 18.5 to <30 and ≥30. |
| LUX | `LUAXSTAT` | CDC examination status. 1 complete, 2 partial, 3 ineligible, 4 not done. |
| LUX | `LUARXNC` | Released partial-exam reason. Code 1 for fasting <3 hours, code 2 with CDC label “Unable to obtain 10 valid measures,” and code 3 for the elevated IQR-to-median ratio. Code 2 is checked separately against the recorded count. |
| LUX | `LUANMVGP` | Retained valid measurement count from the final probe, grouped at 20–29 and ≥30 using codes 20 and 30. Values are used for the ≥10 check. |
| LUX | `LUANMTGP` | Grouped count of measurement attempts on the final probe. Used in the reason-code audit. |
| LUX | `LUXSMED` | Recorded median LSM, in kPa. Primary threshold ≥8. Sensitivity thresholds ≥12 and >8. |
| LUX | `LUXSIQRM` | Stiffness IQR-to-median ratio, expressed in percent. Quality check <30%. |
| LUX | `LUXCAPM` | Recorded median controlled attenuation parameter, in dB/m. Availability audited, with no eligibility restriction. |
| LUX | `LUAPNME` | Probe type used in the examination quality audit. Blank values can occur. |
| LUX | `LUARXIN`, `LUARXND` | Released reasons for ineligibility and examination not done, respectively. Used for flow counts. |
| DIQ | `DIQ010` | Self-reported diabetes item. Codes 7 and 9 are refusal and unknown. Used only to reconcile historical counts. |

[CDC NHANES public data portal](https://wwwn.cdc.gov/nchs/nhanes/) · [P_LUX](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_LUX.htm) · [LUX_L](https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2021/DataFiles/LUX_L.htm)

## Derived populations and results

- **D** includes adults aged ≥20 with positive MEC weight, valid design fields, BMI ≥18.5 and status 1 or 2. **D4** adds otherwise eligible adults with status 4.
- **S** is the subset of D with status 1 and recorded LSM. **T** is the subset with status 2, reason 2 or 3 and recorded LSM. **R** is the union of S and T. Status 2 records without LSM still contribute to D.
- **pS** and **pR** are weighted percentages with threshold-positive LSM in S and R. **Delta** is pR minus pS in percentage points. The **BMI contrast** subtracts Delta for BMI 18.5 to <30 from Delta for BMI ≥30. **T_share_R** and **T_share_D** are weighted percentages of T within R and D. **T_positive** is the weighted positive percentage in T.
- **Bounds** keep classifications in S fixed. The lower endpoint counts S positives over D or D4. The upper endpoint adds the weight of everyone outside S in that domain. The width, in percentage points, equals the weighted share outside S. Endpoint intervals describe the sampling uncertainty of each endpoint.
- **Estimate files** use `cycle`, `bmi_group`, `scenario` and `metric` as keys. `n_denominator`, `n_numerator` and `n_strict_comparator` are unweighted counts as applicable. `estimate`, `se`, `ci_low`, `ci_high` and `df` give the point estimate, design-based standard error, 95% interval and survey degrees of freedom. Estimates, standard errors and CI endpoints are on the percentage or percentage-point scale for the relevant metric.
- **Quality and flow files** report unweighted counts. `valid_count_ge10` and `iqr_pct_lt30` have yes, no or missing categories. `lsm_available` is a separate indicator. `A1_at_8_kpa.csv` counts readings exactly at the boundary. `A1_design.csv` records sample design and weight summaries.
