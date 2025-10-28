#!/usr/bin/env Rscript
# Instala pacotes (se necessário) e renderiza index.Rmd para docs/
pkgs <- c('rmarkdown','GetBCBData','rbcb','ipeadatar','sidrar','dplyr','ggplot2','readr','lubridate','WDI','tidyr')
to_install <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
if(length(to_install)) install.packages(to_install, repos = 'https://cloud.r-project.org')

dir.create('docs/data', recursive = TRUE, showWarnings = FALSE)
library(rmarkdown)

# Render inside a tryCatch so the script exits gracefully and preserves any existing docs/data files
tryCatch({
	render('index.Rmd', output_file = file.path('docs','index.html'), envir = new.env())
	cat('Rendered docs/index.html and CSVs under docs/data\n')
}, error = function(e){
	cat('Render failed:', conditionMessage(e), '\n')
	# leave existing docs/ content intact if present
	quit(status = 0)
})
