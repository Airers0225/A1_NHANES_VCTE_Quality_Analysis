# Run from repository root. Optional argument: a new output CSV path.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 1L, requireNamespace("foreign"), requireNamespace("survey"))
target <- if (length(args)) args[1L] else "demographic_output/A1_Demographic_Table.csv"
stopifnot(!file.exists(target))
dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
options(survey.lonely.psu = "fail", survey.adjust.domain.lonely = FALSE)
manifest <- read.csv("audit_download_manifest.csv")
baseline <- read.csv("audit_counts.csv")
frozen <- read.csv("expected/A1_design.csv")
cycles <- list(
  list(year=2017, id="2017-Mar2020", label="2017–March 2020", files=c("P_DEMO","P_BMX","P_LUX"),
       wt="WTMECPRP", n=c(7792,4439,3353), df=25L),
  list(year=2021, id="2021-2023", label="August 2021–August 2023", files=c("DEMO_L","BMX_L","LUX_L"),
       wt="WTMEC2YR", n=c(5580,3275,2305), df=15L)
)
fields <- c("RIDAGEYR","BMXBMI","RIAGENDR","RIDRETH3")
groups <- c("D","BMI 18.5–<30","BMI ≥30")
race_labels <- c("Mexican American","Other Hispanic","Non-Hispanic White",
                 "Non-Hispanic Black","Non-Hispanic Asian","Other race, including multiracial")
race_codes <- c(1,2,3,4,6,7)
read_xpt <- function(cycle, stem, vars) {
  path <- file.path("public_nhanes", cycle$year, paste0(stem, ".xpt"))
  entry <- manifest[manifest$cycle_start == cycle$year & manifest$file == stem, ]
  stopifnot(nrow(entry)==1L, file.info(path)$size==entry$bytes,
            identical(tolower(unname(tools::sha256sum(path))), entry$sha256))
  x <- foreign::read.xport(path)[vars]
  stopifnot(nrow(x)==entry$rows, !anyNA(x$SEQN), !anyDuplicated(x$SEQN))
  x
}
prepare <- function(cycle) {
  demo <- read_xpt(cycle, cycle$files[1], c("SEQN","RIDAGEYR","RIAGENDR","RIDRETH3",
                                           cycle$wt,"SDMVSTRA","SDMVPSU"))
  bmx <- read_xpt(cycle, cycle$files[2], c("SEQN","BMXBMI"))
  lux <- read_xpt(cycle, cycle$files[3], c("SEQN","LUAXSTAT"))
  stopifnot(all(bmx$SEQN %in% demo$SEQN), all(lux$SEQN %in% demo$SEQN))
  demo$BMXBMI <- bmx$BMXBMI[match(demo$SEQN,bmx$SEQN)]
  demo$LUAXSTAT <- lux$LUAXSTAT[match(demo$SEQN,lux$SEQN)]
  demo$weight <- demo[[cycle$wt]]
  full <- demo[which(!is.na(demo$weight) & demo$weight>0 &
                       complete.cases(demo[c("SDMVSTRA","SDMVPSU")])), ]
  attempts <- !is.na(full$RIDAGEYR) & full$RIDAGEYR>=20 & full$LUAXSTAT %in% c(1,2)
  old_missing <- vapply(fields, function(field) {
    count <- baseline$n[baseline$cycle_start==cycle$year &
                          baseline$stage=="attempt_missing" & baseline$metric==field]
    stopifnot(length(count)==1L)
    as.integer(count)
  }, integer(1))
  observed_missing <- colSums(is.na(full[attempts,fields]))
  stopifnot(identical(names(observed_missing), names(old_missing)),
            all(observed_missing == old_missing))
  full$D <- attempts & !is.na(full$BMXBMI) & full$BMXBMI>=18.5
  full$nonobese <- full$D & full$BMXBMI<30
  full$obese <- full$D & full$BMXBMI>=30
  n <- unname(colSums(full[c("D","nonobese","obese")]))
  f <- frozen[frozen$cycle==cycle$id, ]
  frozen_n <- f$n[match(c("D","D_nonobese","D_obese"),f$domain)]
  if (!all(n==cycle$n) || !all(n==frozen_n)) {
    stop(cycle$label, " counts mismatch. Observed: ", paste(n,collapse="/"),
         "; expected: ",paste(cycle$n,collapse="/"))
  }
  stopifnot(!anyNA(full[full$D,fields]),
            all(full$RIAGENDR[full$D] %in% c(1,2)),
            all(full$RIDRETH3[full$D] %in% race_codes))
  full$sex <- factor(full$RIAGENDR,levels=c(1,2),labels=c("Male","Female"))
  full$race <- factor(full$RIDRETH3,levels=race_codes,labels=race_labels)
  design <- survey::svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~weight,nest=TRUE,data=full)
  stopifnot(survey::degf(design)==cycle$df)
  cat(cycle$id, " | full design:", nrow(full), "df:",survey::degf(design),
      "| D / BMI layers:",paste(n,collapse="/"),"| pre-BMI n:",sum(attempts),
      "| pre-BMI missing:",paste(old_missing,collapse="/"),"\n")
  list(design=design, n=n)
}
# Validate both periods before generating any final result.
designs <- lapply(cycles, prepare)
summarize <- function(cycle, prepared) {
  design <- prepared$design
  domains <- list(subset(design,D),subset(design,nonobese),subset(design,obese))
  rows <- lapply(seq_along(domains), function(i) {
    domain <- domains[[i]]
    vars <- domain$variables
    n <- nrow(vars)
    stopifnot(n==prepared$n[i])
    entry <- function(variable, level, code=NA_integer_, count=NA_integer_,
                      mean=NA_real_, se=NA_real_, percent=NA_real_) {
      data.frame(period=cycle$label,domain=groups[i],domain_n=n,variable=variable,
                 category=level,code=code,unweighted_n=count,weighted_mean=mean,
                 mean_se=se,weighted_percent=percent)
    }
    means <- survey::svymean(~RIDAGEYR+BMXBMI,domain)
    sex <- survey::svymean(~sex,domain)
    race <- survey::svymean(~race,domain)
    stopifnot(sum(table(vars$sex))==n,sum(table(vars$race))==n,
              abs(sum(coef(sex))-1)<1e-10,abs(sum(coef(race))-1)<1e-10)
    rbind(entry("Sample","Unweighted total",count=n),
          entry("RIDAGEYR","Age, years",mean=unname(coef(means)[1]),se=unname(survey::SE(means)[1])),
          entry("BMXBMI","BMI, kg/m²",mean=unname(coef(means)[2]),se=unname(survey::SE(means)[2])),
          do.call(rbind,lapply(seq_along(levels(vars$sex)), function(j)
            entry("RIAGENDR",levels(vars$sex)[j],j,unname(table(vars$sex)[j]),
                  percent=100*unname(coef(sex)[j])))),
          do.call(rbind,lapply(seq_along(race_codes), function(j)
            entry("RIDRETH3",race_labels[j],race_codes[j],unname(table(vars$race)[j]),
                  percent=100*unname(coef(race)[j])))),
          do.call(rbind,lapply(fields, function(f) entry(f,"Missing",count=sum(is.na(vars[[f]]))))))
  })
  do.call(rbind,rows)
}
result <- do.call(rbind,Map(summarize,cycles,designs))
stopifnot(nrow(result)==90,all(result$unweighted_n[result$category=="Missing"]==0))
write.csv(result,target,row.names=FALSE,na="",fileEncoding="UTF-8")
cat("R:", R.version.string, "| survey:", as.character(packageVersion("survey")),
    "| foreign:", as.character(packageVersion("foreign")), "\n")

