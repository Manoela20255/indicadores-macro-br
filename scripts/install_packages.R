## Instala pacotes R necessários se não estiverem instalados
pkgs <- c(
  "rmarkdown","GetBCBData","rbcb","ipeadatar","sidrar","rdbnomics","WDI",
  "dplyr","stringr","tidyr","magrittr","tsibble","ggplot2",
  "writexl","lubridate","readr"
)

to_install <- pkgs[!(pkgs %in% installed.packages()[,"Package"]) ]
if(length(to_install) > 0){
  message("Instalando pacotes: ", paste(to_install, collapse = ", "))
  install.packages(to_install, repos = "https://cloud.r-project.org")
} else {
  message("Todos os pacotes já estão instalados.")
}

message("Verificando carregamento dos pacotes...")
failed <- character()
for(p in pkgs){
  if(!requireNamespace(p, quietly = TRUE)) failed <- c(failed, p)
}
if(length(failed)>0){
  message("Pacotes que não puderam ser carregados: ", paste(failed, collapse = ", "))
  quit(status = 1)
}
message("Instalação/cheque concluídos com sucesso.")
