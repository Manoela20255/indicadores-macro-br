# Indicadores Macroeconômicos do Brasil — Tentativa3

Arquivos gerados:

- `index.Rmd` — documento RMarkdown principal que coleta dados de várias fontes (BCB, Ipeadata, SIDRA, OECD, FMI, Banco Mundial) e gera gráficos e tabelas.
- `data/` — pasta onde os CSV/XLSX resultantes são salvos quando você renderiza o `index.Rmd`.

Como usar

1. Abra o projeto no RStudio ou outro ambiente R.
2. Instale os pacotes necessários (exemplo):

```r
install.packages(c("GetBCBData","rbcb","ipeadatar","sidrar","rdbnomics","WDI",
                   "dplyr","stringr","tidyr","magrittr","tsibble","ggplot2","writexl","lubridate","readr"))
```

3. Renderize o documento:

```r
rmarkdown::render("index.Rmd")
```

4. Os arquivos CSV/XLSX serão gravados na pasta `data/`. Você pode abrir/baixar esses arquivos diretamente.

Próximos passos recomendados

- Integrar uma interface Shiny para filtros dinâmicos e downloads sob demanda.
- Melhorar tratamento de erros e mensagens quando uma fonte estiver inacessível.
- Adicionar gráficos interativos (plotly) e um layout mais elaborado (bootstrap ou pkgdown).
