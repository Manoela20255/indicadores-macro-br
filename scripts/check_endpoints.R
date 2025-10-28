#!/usr/bin/env Rscript
# sanity check for local Plumber API endpoints
pkgs <- c('httr','jsonlite')
inst <- pkgs[!(pkgs %in% installed.packages()[,'Package'])]
if(length(inst)) install.packages(inst, repos = 'https://cloud.r-project.org')
library(httr)
library(jsonlite)

base <- 'http://127.0.0.1:8000'
endpoints <- list(
  selic = '/selic?n=5',
  focus = '/focus?n=5',
  sidra = '/sidra?n=5',
  ipea = '/ipea?n=5',
  wbank = '/wbank?country=BR&indicator=NY.GDP.MKTP.CD&start=2020&end=2022',
  imf = '/imf?series=imf/ifs/BRA.NGDP_R'
)

results <- list()
exit_code <- 0
for(name in names(endpoints)){
  url <- paste0(base, endpoints[[name]])
  cat(sprintf('Checking %-6s %s\n', name, url))
  res <- tryCatch({
    r <- httr::GET(url, httr::timeout(15))
    list(ok = TRUE, status = httr::status_code(r), text = httr::content(r, as = 'text', encoding = 'UTF-8'))
  }, error = function(e) list(ok = FALSE, error = as.character(e)))

  if(!isTRUE(res$ok)){
    cat(sprintf('  ERROR: request failed: %s\n', res$error))
    results[[name]] <- list(ok = FALSE, message = res$error)
    exit_code <- max(exit_code, 2)
    next
  }
  if(res$status >= 400){
    cat(sprintf('  HTTP %d\n', res$status))
    results[[name]] <- list(ok = FALSE, status = res$status)
    exit_code <- max(exit_code, 3)
    next
  }
  parsed <- tryCatch(jsonlite::fromJSON(res$text, flatten = TRUE), error = function(e) e)
  if(inherits(parsed, 'error')){
    cat('  ERROR: invalid JSON response\n')
    results[[name]] <- list(ok = FALSE, message = parsed$message)
    exit_code <- max(exit_code, 4)
    next
  }
  # check structure: prefer data.frame with date/value
  good <- FALSE
  rows <- NA
  if(is.data.frame(parsed)){
    rows <- nrow(parsed)
    if(all(c('date','value') %in% names(parsed))) good <- TRUE
  } else if(is.list(parsed) && !is.null(parsed$error) && isTRUE(parsed$error)){
    cat(sprintf('  UPSTREAM ERROR: %s\n', parsed$message))
    results[[name]] <- list(ok = FALSE, upstream_error = parsed$message)
    exit_code <- max(exit_code, 5)
    next
  } else if(is.list(parsed)){
    # try to coerce
    df <- tryCatch(as.data.frame(parsed), error = function(e) NULL)
    if(!is.null(df) && all(c('date','value') %in% names(df))){
      good <- TRUE
      rows <- nrow(df)
    }
  }
  if(good){
    cat(sprintf('  OK: %d rows, structure date/value\n', rows))
    results[[name]] <- list(ok = TRUE, rows = rows)
  } else {
    cat('  WARNING: unexpected structure (not date/value table)\n')
    results[[name]] <- list(ok = FALSE, structure = names(parsed))
    exit_code <- max(exit_code, 6)
  }
}

cat('\nSummary:\n')
print(results)

quit(status = exit_code)
