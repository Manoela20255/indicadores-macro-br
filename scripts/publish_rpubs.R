#!/usr/bin/env Rscript
# Publish the RMarkdown to RPubs if RPubs credentials are available as env vars
args <- commandArgs(trailingOnly = TRUE)
account <- Sys.getenv('RPUBS_ACCOUNT', '')
token <- Sys.getenv('RPUBS_TOKEN', '')
secret <- Sys.getenv('RPUBS_SECRET', '')

if(account == '' || token == '' || secret == ''){
  message('RPubs credentials not found in environment. Skipping RPubs publish.')
  quit(status = 0)
}

if(!requireNamespace('rsconnect', quietly = TRUE)) install.packages('rsconnect', repos = 'https://cloud.r-project.org')
library(rsconnect)

tryCatch({
  # register account for this session
  rsconnect::setAccountInfo(name = account, token = token, secret = secret, server = 'rpubs')
  message('Publishing index.Rmd to RPubs (account: ', account, ')')
  # deploy the R Markdown document (will render if needed)
  rsconnect::deployDoc('index.Rmd', account = account, server = 'rpubs', launch.browser = FALSE, force = TRUE)
  message('RPubs publish completed (or updated).')
}, error = function(e){
  message('RPubs publish failed: ', conditionMessage(e))
  quit(status = 1)
})
