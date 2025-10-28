#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
# default to current working directory (repo root) unless a path is provided
base_dir <- if(length(args) >= 1) args[1] else normalizePath(".")
setwd(base_dir)
cat("Base dir:", getwd(), "\n")

dir.create("data", recursive = TRUE, showWarnings = FALSE)
dir.create("static_site/data", recursive = TRUE, showWarnings = FALSE)
dir.create("static_site/js", recursive = TRUE, showWarnings = FALSE)
dir.create("docs/data", recursive = TRUE, showWarnings = FALSE)

library(GetBCBData)
library(rbcb)
library(ipeadatar)
library(sidrar)
library(dplyr)
library(tidyr)
library(lubridate)
library(WDI)
library(rdbnomics)
library(readr)

write_js_array <- function(name, vec){
  if(is.character(vec)){
    vals <- paste0("\'", vec, "\'", collapse = ",")
  } else {
    vals <- paste0(as.character(vec), collapse = ",")
  }
  sprintf("window.%s = [%s];", name, vals)
}

js_lines <- c()

# 1) BCB - SELIC (id 432)
cat("Fetching BCB SELIC...\n")
dados_sgs <- tryCatch(
  GetBCBData::gbcbd_get_series(id = 432, first.date = "2018-01-01", last.date = Sys.Date()),
  error = function(e) { message("BCB fetch error: ", e$message); NULL }
)
if(!is.null(dados_sgs)){
  df <- dados_sgs %>% rename(date = ref.date, selic = value) %>% arrange(date)
  write.csv(df, file = "data/selic.csv", row.names = FALSE)
  write.csv(df, file = "static_site/data/selic.csv", row.names = FALSE)
  write.csv(df, file = "docs/data/selic.csv", row.names = FALSE)
  js_lines <- c(js_lines, write_js_array("SELIC_LABELS", format(df$date, "%Y-%m")), write_js_array("SELIC_VALUES", df$selic))
}

# 1b) BCB - multiple series (Dólar, IBC-Br, Resultado Primário)
cat("Fetching BCB multi-series (Dólar, IBC-Br, Resultado Primário)...\n")
dados_multi <- tryCatch(
  GetBCBData::gbcbd_get_series(id = c("Dolar" = 3698, "IBC_Br" = 24363, "Resultado_Primario" = 5793), first.date = "2020-01-01", last.date = Sys.Date(), format.data = "wide"),
  error = function(e) { message("BCB multi fetch error: ", e$message); NULL }
)
if(!is.null(dados_multi)){
  # dados_multi is wide by ref.date
  dfm <- dados_multi %>% rename(date = ref.date) %>% arrange(date)
  # write each series to its own CSV and add to js
  series_names <- setdiff(names(dfm), c("date"))
  for(s in series_names){
    outdf <- dfm %>% select(date, all_of(s)) %>% rename(value = all_of(s))
  fname <- paste0("data/", tolower(s), ".csv")
  fname_static <- paste0("static_site/data/", tolower(s), ".csv")
  fname_docs <- paste0("docs/data/", tolower(s), ".csv")
  write.csv(outdf, file = fname, row.names = FALSE)
  write.csv(outdf, file = fname_static, row.names = FALSE)
  write.csv(outdf, file = fname_docs, row.names = FALSE)
    lab_name <- toupper(paste0(s, "_LABELS"))
    val_name <- toupper(paste0(s, "_VALUES"))
    js_lines <- c(js_lines, write_js_array(lab_name, format(outdf$date, "%Y-%m")), write_js_array(val_name, outdf$value))
  }
}

# 2) Focus - Expectativa IPCA
cat("Fetching Focus expectations...\n")
dados_focus <- tryCatch(
  rbcb::get_market_expectations(type = "annual", indic = "IPCA", start_date = "2018-01-01"),
  error = function(e) { message("Focus fetch error: ", e$message); NULL }
)
if(!is.null(dados_focus)){
  df_focus <- dados_focus %>%
    dplyr::filter(baseCalculo == 0) %>%
    dplyr::select(data = Data, data_ref = DataReferencia, mediana = Mediana) %>%
    dplyr::group_by(data_ref, ano_mes = tsibble::yearmonth(data)) %>%
    dplyr::summarise(expectativa_mensal = mean(mediana, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(ano_mes)
  # convert ano_mes to character
  df_focus <- df_focus %>% mutate(ano_mes = format(ano_mes, "%Y-%m"))
  write.csv(df_focus, file = "data/focus_ipca.csv", row.names = FALSE)
  write.csv(df_focus, file = "static_site/data/focus_ipca.csv", row.names = FALSE)
  write.csv(df_focus, file = "docs/data/focus_ipca.csv", row.names = FALSE)
  js_lines <- c(js_lines, write_js_array("FOCUS_LABELS", df_focus$ano_mes), write_js_array("FOCUS_VALUES", df_focus$expectativa_mensal))
}

# 3) SIDRA - IPCA (table 7060 variable 63)
cat("Fetching SIDRA IPCA...\n")
cod_sidra <- "/t/7060/n1/all/v/63/p/all/c315/7169/d/v63%202"
dados_sidra <- tryCatch(sidrar::get_sidra(api = cod_sidra), error = function(e) { message("SIDRA fetch error: ", e$message); NULL })
if(!is.null(dados_sidra)){
  df_sidra <- dados_sidra %>% mutate(data = lubridate::ym(`Mês (Código)`), ipca = Valor) %>% select(data, ipca) %>% arrange(data)
  write.csv(df_sidra, file = "data/sidra_ipca.csv", row.names = FALSE)
  write.csv(df_sidra, file = "static_site/data/sidra_ipca.csv", row.names = FALSE)
  write.csv(df_sidra, file = "docs/data/sidra_ipca.csv", row.names = FALSE)
  js_lines <- c(js_lines, write_js_array("SIDRA_LABELS", format(df_sidra$data, "%Y-%m")), write_js_array("SIDRA_VALUES", df_sidra$ipca))
}

# 4) IPEA (CAGED, EMBI example)
cat("Fetching IPEA sample series...\n")
dados_ipea <- tryCatch(ipeadatar::ipeadata(c("caged" = "CAGED12_SALDON12", "embi_br" = "JPM366_EMBI366")), error = function(e) { message("IPEA fetch error: ", e$message); NULL })
if(!is.null(dados_ipea)){
  df_ipea <- dados_ipea %>% tidyr::pivot_wider(id_cols = "date", names_from = "code", values_from = "value") %>% rename(data = date)
  write.csv(df_ipea, file = "data/ipeadata.csv", row.names = FALSE)
  write.csv(df_ipea, file = "static_site/data/ipeadata.csv", row.names = FALSE)
  write.csv(df_ipea, file = "docs/data/ipeadata.csv", row.names = FALSE)
  # use first series for demo
  if("CAGED12_SALDON12" %in% names(df_ipea)){
    js_lines <- c(js_lines, write_js_array("IPEA_LABELS", format(df_ipea$data, "%Y-%m")), write_js_array("IPEA_VALUES", df_ipea$CAGED12_SALDON12))
  }
}

# 5) World Bank GDP (annual)
cat("Fetching World Bank GDP (BR)...\n")
wb <- tryCatch(WDI(country = 'BR', indicator = 'NY.GDP.MKTP.CD', start = 2000, end = as.integer(format(Sys.Date(), "%Y"))), error = function(e) { message('WDI fetch error: ', e$message); NULL })
if(!is.null(wb) && nrow(wb) > 0){
  wb2 <- wb %>% arrange(year) %>% mutate(date = as.character(year))
  write.csv(wb2, file = "data/wb_gdp_br.csv", row.names = FALSE)
  write.csv(wb2, file = "static_site/data/wb_gdp_br.csv", row.names = FALSE)
  write.csv(wb2, file = "docs/data/wb_gdp_br.csv", row.names = FALSE)
  js_lines <- c(js_lines, write_js_array("WB_GDP_LABELS", wb2$date), write_js_array("WB_GDP_VALUES", wb2$NY.GDP.MKTP.CD))
}

# 6) Try a few rdbnomics fetches for OECD / IMF examples as best-effort placeholders
cat("Attempting rdbnomics fetches (OECD/IMF) as available...\n")
try({
  # example OECD: unemployment harmonized (may fail)
  oecd_try <- tryCatch(rdbnomics::rdb(api_link = 'https://api.db.nomics.world/v22/series/OECD/MEI?dimensions=%7B%22SUBJECT%22%3A%5B%22LRHUTTTT%22%5D%2C%22MEASURE%22%3A%5B%22STSA%22%5D%2C%22FREQUENCY%22%3A%5B%22M%22%5D%7D&observations=1'), error = function(e) NULL)
  if(!is.null(oecd_try) && nrow(oecd_try)>0){
  o2 <- oecd_try %>% dplyr::select(period, value) %>% rename(date = period)
  write.csv(o2, file = 'data/oecd_unemp.csv', row.names = FALSE)
  write.csv(o2, file = 'static_site/data/oecd_unemp.csv', row.names = FALSE)
  write.csv(o2, file = 'docs/data/oecd_unemp.csv', row.names = FALSE)
  js_lines <- c(js_lines, write_js_array('OECD_UNEMP_LABELS', o2$date), write_js_array('OECD_UNEMP_VALUES', o2$value))
  }
}, silent = TRUE)

# Write JS data file if any lines
if(length(js_lines) > 0){
  cat("Writing JS data to static_site/js/data.js\n")
  writeLines(c("// Generated data file — do not edit", js_lines), con = "static_site/js/data.js")
} else {
  cat("No data fetched; skipping JS data generation.\n")
}

cat("Fetch script finished.\n")
