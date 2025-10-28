#!/usr/bin/env Rscript
## plumber endpoints for on-demand macro data
## Save this as scripts/api_plumber.R

#* @apiTitle Tentativa3 - Dados macro (Plumber)
#* @apiDescription Endpoints que retornam séries em JSON (SELIC, Focus, SIDRA, IPEA)

ensure_pkg <- function(pkgs){
  to_install <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if(length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")
}

# Simple in-memory cache environment with TTL
cacheEnv <- new.env(parent = emptyenv())
set_cache <- function(key, value){
  cacheEnv[[key]] <- list(value = value, ts = as.numeric(Sys.time()))
}
get_cache <- function(key, ttl = 300){
  entry <- cacheEnv[[key]]
  if(is.null(entry)) return(NULL)
  if((as.numeric(Sys.time()) - entry$ts) > ttl) {
    rm(list = key, envir = cacheEnv)
    return(NULL)
  }
  return(entry$value)
}

# helper to run fetches with caching
cached_fetch <- function(key, ttl = 300, fetch_fn){
  cached <- tryCatch(get_cache(key, ttl = ttl), error = function(e) NULL)
  if(!is.null(cached)) return(cached)
  # run fetch
  res <- tryCatch(fetch_fn(), error = function(e) list(error = TRUE, message = as.character(e)))
  # only cache successful data.frames (not error lists)
  if(is.data.frame(res) || (is.list(res) && !isTRUE(res$error))) set_cache(key, res)
  return(res)
}

#* World Bank / WDI endpoint
#* @param country Character country code (default 'BR')
#* @param indicator Character indicator code (e.g. 'NY.GDP.MKTP.CD')
#* @param start:int start year (optional)
#* @param end:int end year (optional)
#* @get /wbank
function(country = 'BR', indicator = 'NY.GDP.MKTP.CD', start = NULL, end = NULL){
  tryCatch({
    start <- if(!is.null(start) && start != '') as.integer(start) else NULL
    end <- if(!is.null(end) && end != '') as.integer(end) else NULL
    fetch_fn <- function(){
      WDI::WDI(country = country, indicator = indicator, start = start, end = end, extra = FALSE)
    }
    # cache World Bank queries for 24h to reduce API pressure
    res <- cached_fetch(paste0('wbank_', country, '_', indicator, '_', start, '_', end), ttl = 86400, fetch_fn = fetch_fn)
    if(is.list(res) && isTRUE(res$error)) return(res)
    if(is.null(res) || nrow(res) == 0) return(list(error = TRUE, message = 'No World Bank data returned'))
    df <- res %>% arrange(year)
    out <- data.frame(date = as.character(df$year), value = as.numeric(df[[indicator]]), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e) list(error = TRUE, message = as.character(e)))
}

#* OECD dataset fetch
#* @param dataset Character dataset id (as used by OECD e.g. 'MEI_PRICES_CPI')
#* @param filter Character filter string (optional) — pass 'all' to request full dataset
#* @get /oecd
function(dataset = NULL, filter = 'all'){
  if(is.null(dataset) || dataset == '') return(list(error = TRUE, message = 'Provide dataset parameter for OECD'))
  tryCatch({
    fetch_fn <- function(){ OECD::get_dataset(dataset, filter = filter) }
    res <- cached_fetch(paste0('oecd_', dataset, '_', digest::digest(filter)), ttl = 3600, fetch_fn = fetch_fn)
    if(is.list(res) && isTRUE(res$error)) return(res)
    raw <- res
    if(is.null(raw) || nrow(raw) == 0) return(list(error = TRUE, message = 'No OECD data returned'))
    time_col <- grep('TIME|time|Year|YEAR', names(raw), ignore.case = TRUE, value = TRUE)[1]
    val_col <- setdiff(names(raw), c(time_col, names(raw)[grepl('country|LOCATION|GEO|SUBJECT', names(raw), ignore.case = TRUE)]))[1]
    out <- data.frame(date = as.character(raw[[time_col]]), value = as.numeric(raw[[val_col]]), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e) list(error = TRUE, message = as.character(e)))
}

## IMF via DBnomics (rdbnomics)
#* IMF/DBnomics fetch
#* @param series Character DBnomics series id (required). Example: 'imf/IFS/...' or other DBnomics id
#* @get /imf
function(series = NULL){
  if(is.null(series) || series == '') return(list(error = TRUE, message = 'Provide series parameter with DBnomics series id'))
  tryCatch({
    # Try several strategies to fetch DBnomics/IMF data:
    # 1) direct rdb(series)
    # 2) rdb(api_link = series) if series looks like a URL
    # 3) normalize case for provider/dataset and try again (DBnomics is case-sensitive)
    fetch_attempt <- function(){
      tryCatch(rdbnomics::rdb(series), error = function(e) e)
    }
    res <- cached_fetch(paste0('imf_', digest::digest(series)), ttl = 86400, fetch_fn = function(){
      # attempt 1: direct
      r1 <- tryCatch(rdbnomics::rdb(series), error = function(e) e)
      if(!inherits(r1, 'error')) return(r1)
      # attempt 2: if series looks like a URL, try as api_link
      if(grepl('^https?://', series)){
        r2 <- tryCatch(rdbnomics::rdb(api_link = series), error = function(e) e)
        if(!inherits(r2, 'error')) return(r2)
      }
      # attempt 3: try uppercasing provider/dataset parts (e.g. imf/ifs -> IMF/IFS)
      parts <- unlist(strsplit(series, '/'))
      if(length(parts) >= 2){
        parts[1] <- toupper(parts[1])
        parts[2] <- toupper(parts[2])
        candidate <- paste(parts, collapse = '/')
        r3 <- tryCatch(rdbnomics::rdb(candidate), error = function(e) e)
        if(!inherits(r3, 'error')) return(r3)
      }
      # all attempts failed: return an error object
      stop('All rdbnomics fetch attempts failed')
    })
      # if cached_fetch returned a structured error list, don't return it immediately —
      # attempt fallback to a cached CSV in docs/data before giving up
      if(is.list(res) && isTRUE(res$error)){
        # try multiple possible doc paths (relative and project absolute) for fallback CSV
        candidates <- c(
          file.path('docs','data', paste0('imf_', digest::digest(series), '.csv')),
          file.path('/Users/manoelacardosocalheiros/Downloads/_includes/Tentativa3','docs','data', paste0('imf_', digest::digest(series), '.csv'))
        )
        for(csv_path in candidates){
          if(file.exists(csv_path)){
            df <- readr::read_csv(csv_path, col_types = readr::cols())
            return(df)
          }
        }
        return(res)
      }
      # if fetch failed with other error types or returned NULL/empty, try CSV fallback
      if(is.null(res) || (is.data.frame(res) && nrow(res) == 0)){
        candidates <- c(
          file.path('docs','data', paste0('imf_', digest::digest(series), '.csv')),
          file.path('/Users/manoelacardosocalheiros/Downloads/_includes/Tentativa3','docs','data', paste0('imf_', digest::digest(series), '.csv'))
        )
        for(csv_path in candidates){
          if(file.exists(csv_path)){
            df <- readr::read_csv(csv_path, col_types = readr::cols())
            return(df)
          }
        }
        return(list(error = TRUE, message = 'No data returned from rdbnomics'))
      }
    time_col <- grep('time|period|date|year', names(res), ignore.case = TRUE, value = TRUE)[1]
    value_col <- setdiff(names(res), c(time_col, grep('country|location|indicator|series', names(res), ignore.case = TRUE, value = TRUE)))[1]
    if(is.null(time_col) || is.null(value_col)){
      return(res)
    }
    out <- data.frame(date = as.character(res[[time_col]]), value = as.numeric(res[[value_col]]), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e) list(error = TRUE, message = as.character(e)))
}

ensure_pkg(c("plumber", "rbcb", "sidrar", "ipeadatar", "httr", "jsonlite", "GetBCBData", "dplyr", "lubridate", "tidyr", "tsibble", "WDI", "OECD", "rdbnomics", "digest"))

library(plumber)
library(rbcb)
library(sidrar)
library(ipeadatar)
library(jsonlite)
library(GetBCBData)
library(dplyr)
library(lubridate)
library(tidyr)
library(tsibble)
library(WDI)
library(OECD)
library(rdbnomics)
library(digest)

#* Health
#* @get /
function(){
  list(status = "ok", time = Sys.time())
}

#* SELIC series (BCB) latest n rows — mirror successful call from fetch_data.R
#* @param n:int Number of rows to return (default 120)
#* @get /selic
function(n = 120){
  n <- as.integer(n)
  tryCatch({
    fetch_fn <- function(){ GetBCBData::gbcbd_get_series(id = 432, first.date = "2018-01-01", last.date = Sys.Date()) }
    dados_sgs <- cached_fetch('selic_full', ttl = 3600, fetch_fn = fetch_fn)
    if(is.list(dados_sgs) && isTRUE(dados_sgs$error)) return(dados_sgs)
    if(is.null(dados_sgs) || nrow(dados_sgs) == 0) return(list(error = TRUE, message = "No SELIC data returned"))
    df <- dados_sgs %>% rename(date = ref.date, selic = value) %>% arrange(date)
    if(nrow(df) > n) df <- tail(df, n)
    out <- data.frame(date = format(df$date, "%Y-%m-%d"), value = as.numeric(df$selic), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e){ list(error = TRUE, message = as.character(e)) })
}

#* Focus (expectativa IPCA) latest n rows — use rbcb::get_market_expectations as in fetch_data.R
#* @param n:int Number of rows to return (default 60)
#* @get /focus
function(n = 60){
  n <- as.integer(n)
  tryCatch({
    fetch_fn <- function(){ rbcb::get_market_expectations(type = "annual", indic = "IPCA", start_date = "2018-01-01") }
    dados_focus <- cached_fetch('focus_full', ttl = 1800, fetch_fn = fetch_fn)
    if(is.list(dados_focus) && isTRUE(dados_focus$error)) return(dados_focus)
    if(is.null(dados_focus) || nrow(dados_focus) == 0) return(list(error = TRUE, message = "No Focus data returned"))
    df_focus <- dados_focus %>%
      dplyr::filter(baseCalculo == 0) %>%
      dplyr::select(data = Data, data_ref = DataReferencia, mediana = Mediana) %>%
      dplyr::group_by(data_ref, ano_mes = tsibble::yearmonth(data)) %>%
      dplyr::summarise(expectativa_mensal = mean(mediana, na.rm = TRUE), .groups = "drop") %>%
      dplyr::arrange(ano_mes)
    df_focus <- df_focus %>% mutate(ano_mes = format(ano_mes, "%Y-%m"))
    if(nrow(df_focus) > n) df_focus <- tail(df_focus, n)
    out <- data.frame(date = df_focus$ano_mes, value = as.numeric(df_focus$expectativa_mensal), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e){ list(error = TRUE, message = as.character(e)) })
}

#* SIDRA IPCA (table 7060 variable 63) — use same api string as fetch_data.R
#* @param n:int Number of rows to return (default 60)
#* @get /sidra
function(n = 60){
  n <- as.integer(n)
  tryCatch({
    cod_sidra <- "/t/7060/n1/all/v/63/p/all/c315/7169/d/v63%202"
    fetch_fn <- function(){ sidrar::get_sidra(api = cod_sidra) }
    dados_sidra <- cached_fetch('sidra_ipca_full', ttl = 3600, fetch_fn = fetch_fn)
    if(is.list(dados_sidra) && isTRUE(dados_sidra$error)) return(dados_sidra)
    if(is.null(dados_sidra) || nrow(dados_sidra) == 0) return(list(error = TRUE, message = "No SIDRA data returned"))
    df_sidra <- dados_sidra %>% mutate(data = lubridate::ym(`Mês (Código)`), ipca = Valor) %>% select(data, ipca) %>% arrange(data)
    if(nrow(df_sidra) > n) df_sidra <- tail(df_sidra, n)
    out <- data.frame(date = format(df_sidra$data, "%Y-%m"), value = as.numeric(df_sidra$ipca), stringsAsFactors = FALSE)
    return(out)
  }, error = function(e){ list(error = TRUE, message = as.character(e)) })
}

#* IPEA sample series (if no series_code provided) or fetch by code
#* @param series_code Character series code (optional)
#* @param n:int Number of rows to return (default 60)
#* @get /ipea
function(series_code = NULL, n = 60){
  n <- as.integer(n)
  tryCatch({
    if(is.null(series_code) || series_code == ""){
      fetch_fn <- function(){ ipeadatar::ipeadata(c("caged" = "CAGED12_SALDON12", "embi_br" = "JPM366_EMBI366")) }
      dados_ipea <- cached_fetch('ipea_sample', ttl = 3600, fetch_fn = fetch_fn)
      if(is.list(dados_ipea) && isTRUE(dados_ipea$error)) return(dados_ipea)
      if(is.null(dados_ipea) || nrow(dados_ipea) == 0) return(list(error = TRUE, message = "No IPEA sample data returned"))
      df_ipea <- dados_ipea %>% tidyr::pivot_wider(id_cols = "date", names_from = "code", values_from = "value") %>% rename(data = date)
      if("CAGED12_SALDON12" %in% names(df_ipea)){
        df <- df_ipea %>% arrange(data)
        if(nrow(df) > n) df <- tail(df, n)
        out <- data.frame(date = format(df$data, "%Y-%m"), value = as.numeric(df$CAGED12_SALDON12), stringsAsFactors = FALSE)
        return(out)
      }
      return(list(error = TRUE, message = "Requested IPEA sample series not found"))
    } else {
      fetch_fn <- function(){ ipeadatar::ipea_series(series_code) }
      df <- cached_fetch(paste0('ipea_series_', digest::digest(series_code)), ttl = 86400, fetch_fn = fetch_fn)
      return(df)
    }
  }, error = function(e){ list(error = TRUE, message = as.character(e)) })
}
