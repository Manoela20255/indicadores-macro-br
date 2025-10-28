#!/usr/bin/env Rscript
# Small runner to start the plumber API created in api_plumber.R
ensure_pkg <- function(pkgs){
  to_install <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if(length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")
}
ensure_pkg(c("plumber"))
library(plumber)

api_file <- file.path("/Users/manoelacardosocalheiros/Downloads/_includes/Tentativa3/scripts","api_plumber.R")
if(!file.exists(api_file)) stop("api_plumber.R not found at: ", api_file)
pr <- plumb(api_file)
cat(sprintf("Starting API on http://127.0.0.1:8000 (api file: %s)\n", api_file))
pr$run(host = "127.0.0.1", port = 8000)
