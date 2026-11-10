# Run from the project root with Rscript R/audit_nhanes.R.
# Base R plus the recommended foreign package. Counts only.
rows <- list()
for (year in c(2017, 2021)) {
  weight <- if (year == 2017) "WTMECPRP" else "WTMEC2YR"
  columns <- list(
    DEMO = c("RIDAGEYR", "RIDSTATR", "RIAGENDR", "RIDRETH3", weight, "SDMVSTRA", "SDMVPSU"),
    LUX = c("LUAXSTAT", "LUARXNC", "LUARXND", "LUARXIN", "LUAPNME", "LUANMVGP",
            "LUXSIQRM", "LUXSMED", "LUXCAPM"),
    BMX = "BMXBMI", DIQ = "DIQ010"
  )
  emit <- function(stage, metric, n) {
    rows[[length(rows) + 1L]] <<- data.frame(cycle_start = year, stage = stage, metric = metric, n = n)
  }
  keep <- function(d, mask) d[which(mask), , drop = FALSE]
  flow <- function(label, d) {
    emit("flow", label, nrow(d))
    d
  }
  tally <- function(stage, d, col) {
    values <- table(ifelse(is.na(d[[col]]), "missing", as.character(d[[col]])))
    for (v in names(values)) emit(stage, paste0(col, "=", v), unname(values[[v]]))
  }
  psu <- function(d) nrow(unique(d[c("SDMVSTRA", "SDMVPSU")]))
  for (module in names(columns)) {
    name <- if (year == 2017) paste0("P_", module) else paste0(module, "_L")
    file <- file.path("public_nhanes", year, paste0(name, ".xpt"))
    part <- foreign::read.xport(file)[c("SEQN", columns[[module]])]
    if (module == "LUX") part$LUAPNME[which(trimws(part$LUAPNME) == "")] <- NA
    stopifnot(!anyNA(part$SEQN), !anyDuplicated(part$SEQN))
    if (module == "DEMO") {
      d <- part
    } else {
      stopifnot(all(part$SEQN %in% d$SEQN))
      index <- match(d$SEQN, part$SEQN)
      emit("merge", paste0(module, "_matched"), sum(!is.na(index)))
      emit("merge", paste0(module, "_not_matched"), sum(is.na(index)))
      d[columns[[module]]] <- part[index, columns[[module]], drop = FALSE]
    }
  }
  d <- flow("DEMO", d)
  adults <- flow("age_20_plus", keep(d, d$RIDAGEYR >= 20))
  emit("design", "adult_weight_missing_or_nonpositive", sum(is.na(adults[[weight]]) | adults[[weight]] <= 0))
  mec <- flow("positive_MEC_weight", keep(adults, adults$RIDSTATR == 2 & adults[[weight]] > 0))
  tally("adult_MEC", mec, "LUAXSTAT")
  emit("design", "MEC_design_missing", sum(!complete.cases(mec[c("SDMVSTRA", "SDMVPSU")])))
  lux <- flow("LUX_status_available", keep(mec, !is.na(mec$LUAXSTAT)))
  tally("ineligible", keep(lux, lux$LUAXSTAT == 3), "LUARXIN")
  tally("not_done", keep(lux, lux$LUAXSTAT == 4), "LUARXND")
  eligible <- flow("status_1_2_4", keep(lux, lux$LUAXSTAT %in% c(1, 2, 4)))
  attempts <- flow("attempt_status_1_2", keep(eligible, eligible$LUAXSTAT %in% c(1, 2)))
  for (col in unlist(columns)) emit("attempt_missing", col, sum(is.na(attempts[[col]])))
  emit("attempt_missing", "DIQ010_refused_or_unknown", sum(attempts$DIQ010 %in% c(7, 9)))
  bmi <- flow("attempt_BMI_available", keep(attempts, !is.na(attempts$BMXBMI)))
  cohort <- flow("attempt_BMI_ge_18_5", keep(bmi, bmi$BMXBMI >= 18.5))
  groups <- list(BMI_18_5_to_lt30 = cohort$BMXBMI < 30, BMI_30_plus = cohort$BMXBMI >= 30)
  for (label in names(groups)) {
    g <- keep(cohort, groups[[label]])
    complete <- keep(g, g$LUAXSTAT == 1)
    partial <- keep(g, g$LUAXSTAT == 2)
    emit(label, "total", nrow(g))
    emit(label, "complete", nrow(complete))
    emit(label, "partial", nrow(partial))
    emit(label, "complete_LSM_available", sum(!is.na(complete$LUXSMED)))
    emit(label, "complete_LSM_ge8", sum(complete$LUXSMED >= 8, na.rm = TRUE))
    emit(label, "complete_CAP_available", sum(!is.na(complete$LUXCAPM)))
    emit(label, "partial_LSM_available", sum(!is.na(partial$LUXSMED)))
    tally(label, partial, "LUARXNC")
    for (reason in 1:3) {
      emit(label, paste0("partial_reason_", reason, "_LSM_available"),
           sum(partial$LUARXNC == reason & !is.na(partial$LUXSMED), na.rm = TRUE))
    }
    relaxed <- keep(g, g$LUAXSTAT == 1 | (g$LUARXNC %in% c(2, 3) & g$LUXSMED > 0))
    emit(label, "relaxed_technical_with_LSM", nrow(relaxed))
    emit(label, "relaxed_technical_LSM_ge8", sum(relaxed$LUXSMED >= 8, na.rm = TRUE))
    emit(label, "LSM_ge8_complete_PSU_count", psu(keep(complete, complete$LUXSMED >= 8)))
    emit(label, "partial_PSU_count", psu(partial))
  }
  complete <- keep(cohort, cohort$LUAXSTAT == 1)
  emit("quality", "complete", nrow(complete))
  emit("quality", "complete_LSM_CAP_both", sum(complete.cases(complete[c("LUXSMED", "LUXCAPM")])))
  emit("quality", "complete_count_ge10_and_IQR_ratio_lt30",
       sum(complete$LUANMVGP >= 10 & complete$LUXSIQRM < 30, na.rm = TRUE))
  emit("quality", "partial_with_any_LSM", sum(cohort$LUAXSTAT == 2 & !is.na(cohort$LUXSMED)))
  emit("design", "strata", length(unique(cohort$SDMVSTRA)))
  emit("design", "strata_PSU_pairs", psu(cohort))
}
write.csv(do.call(rbind, rows), "audit_counts_R.csv", row.names = FALSE)
if (file.exists("audit_counts.csv")) {
  reference <- read.csv("audit_counts.csv")
  actual <- read.csv("audit_counts_R.csv")
  sort_rows <- function(d) {
    d <- d[do.call(order, d[c("cycle_start", "stage", "metric")]), ]
    rownames(d) <- NULL
    d
  }
  stopifnot(identical(sort_rows(reference), sort_rows(actual)))
}
