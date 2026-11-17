# Historical reproducibility check

The full run summarized below predates v1.0.2. The v1.0.2 tests covered
hash verification, the result comparator using frozen inputs, the reason-code
audit and figures against frozen main results, and an independent demographic
rerun. The main analysis was not rerun for v1.0.2.

The final release candidate's full local analysis entry point ran in a fresh Windows directory with R 4.6.1, an isolated copy of the existing R package library and `--vanilla`. The release code, aggregate comparison files and eight cached public-use XPTs were staged in that directory. All eight XPT byte counts and SHA-256 checks passed before analysis. The source scripts, source XPTs and frozen outputs remained in place.

| Check | Observed result |
| --- | --- |
| Historical audit | 168/168 rows reconciled with the archived count baseline |
| Survey setup | `WTMECPRP` and `WTMEC2YR` used in their respective periods, `SDMVSTRA` and nested `SDMVPSU` verified, full-design df 25 and 15 |
| Domain and sample counts | D 7,792 and 5,580. S 7,228 and 5,169. R 7,498 and 5,397 |
| Reason code 2 | Full-component counts 179 and 138. One record in the first period and zero in the second also had a retained valid count ≥10. The 13 other questioned rows had IQR/median <30% but retained count <10. Classification unchanged. The standalone entry point also ran in the private test directory, where its export contained 14 reviewed rows and one confirmed combination |
| Main and sensitivity estimates | All eight regenerated CSVs byte-identical to the frozen comparisons, including all point estimates, denominators, bounds and intervals |
| Algebra checks | Joint-total decomposition and bound-width identities passed in both periods |
| Figures | Flow reconstruction and Figure 2 PNG/PDF generated from regenerated aggregate CSVs. Figure 2 values were independently checked against the submitted PDF. Figure 1 artwork is kept with the submission |
| Scope | Local run verified with cached, hash-pinned inputs and existing package binaries. Automated CDC download and installation of all dependencies in a fresh environment were not tested. Other operating systems were outside the tested path |

The eight CSVs under `expected/` are verified aggregate results. `audit_counts.csv` is the verified historical aggregate count baseline. The runner leaves record-level audit data in memory. No source XPT, participant-keyed audit export, local log, or credentials are shipped. 
