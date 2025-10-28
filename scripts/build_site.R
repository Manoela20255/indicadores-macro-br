## Renderiza o site RMarkdown em modo não interativo
args <- commandArgs(trailingOnly = TRUE)
base_dir <- if(length(args)>=1) args[1] else "."
setwd(base_dir)
message("Diretório de trabalho: ", getwd())

if(!requireNamespace("rmarkdown", quietly = TRUE)){
  stop("Pacote 'rmarkdown' não encontrado. Rode scripts/install_packages.R primeiro.")
}

message("Iniciando renderização do site com rmarkdown::render_site()...")
if(rmarkdown::pandoc_available()){
  rmarkdown::render_site(encoding = "UTF-8")
  message("Renderização concluída.")
} else {
  # Pandoc não disponível localmente: criar fallback copiando static_site/ para docs/
  message("Pandoc não disponível localmente — criando fallback copiando static_site/ -> docs/")
  if(dir.exists("docs")) unlink("docs", recursive = TRUE)
  dir.create("docs", recursive = TRUE)
  # copy files
  if(dir.exists("static_site")){
    file.copy(list.files("static_site", full.names = TRUE, recursive = TRUE), "docs", recursive = TRUE)
    message("Fallback concluído: arquivos estáticos copiados para docs/")
  } else {
    message("Pasta static_site/ não encontrada — nada a copiar")
  }
}
