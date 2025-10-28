# Publicar o RPubs-style site no GitHub Pages

Este arquivo explica passo-a-passo como publicar o site RPubs-style (RMarkdown) que está neste repositório usando GitHub Actions e GitHub Pages.

Resumo
- O workflow em `.github/workflows/render_and_deploy.yml` renderiza `index.Rmd` no runner do GitHub e publica o resultado em `docs/` usando `peaceiris/actions-gh-pages`, que fará deploy em GitHub Pages (branch `gh-pages`).
- Após o primeiro push, o Actions deve criar/atualizar a branch `gh-pages` e publicar a página em `https://<USERNAME>.github.io/<REPO>/`.

Passos rápidos (copy/paste)
1. Inicialize e envie o repo para o GitHub (substitua `YOUR_USERNAME` e `YOUR_REPO`):

```bash
git init
git add .
git commit -m "Add RPubs-style RMarkdown + Actions deploy"
git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

2. No GitHub: vá em Actions → selecione o workflow "Render and deploy RPubs-style site" e observe a execução. O workflow roda automaticamente no push e também diariamente (cron 06:00 UTC).

3. Após execução bem-sucedida, vá em Settings → Pages no repositório. O site será publicado no URL mostrado (geralmente `https://YOUR_USERNAME.github.io/YOUR_REPO/`).

Como verificar logs e falhas
- Acesse a aba Actions e clique na execução mais recente para ver os passos (instalação de pacotes, render, deploy). As mensagens de erro virão dos passos R (instalação de pacotes ou renderização RMarkdown).
- Se ocorrer falha por pacotes, inspecione o log, corrija eventuais dependências do sistema e reenvie o commit (ou execute manualmente o render localmente para reproduzir o erro).

Como rodar localmente (opcional, para testes)

1. Instale R e Pacotes (exemplo mínimo):

```bash
Rscript -e "install.packages(c('rmarkdown','GetBCBData','rbcb','ipeadatar','sidrar','dplyr','ggplot2','readr','lubridate','WDI','tidyr'), repos='https://cloud.r-project.org')"
```

2. Renderize localmente e verifique `docs/index.html`:

```bash
Rscript scripts/render_site.R
open docs/index.html   # macOS; no Linux use xdg-open
```

Observações importantes
- As chamadas para BCB/SIDRA/IPEA/Foco ocorrem durante a renderização no GitHub Actions. Se algum serviço estiver temporariamente indisponível, o passo de render pode falhar. Recomendo adicionar tratamentos de erro (tryCatch) no Rmd — o `index.Rmd` já usa tryCatch em chamadas principais mas você pode endurecer ainda mais.
- O workflow atual instala pacotes a cada execução. Para acelerar builds, podemos adicionar cache para os pacotes R (actions/cache). Informe se quer que eu configure isso.
- O deploy usa o token automático `${{ secrets.GITHUB_TOKEN }}` — você não precisa adicionar nada extra para publicar no GitHub Pages.
- Se quiser domínio customizado, configure no Settings → Pages (Custom domain) e adicione o arquivo `CNAME` na branch `gh-pages` (posso ajudar a automatizar).

Como forçar execução imediata do workflow
- Push de um commit dispara o workflow automaticamente. Você também pode habilitar `workflow_dispatch` no YAML para permitir execução manual via Actions UI (posso adicionar se preferir).

Próximos passos sugeridos (opcionais)
- Adicionar cache de pacotes ao workflow (caching) — reduz tempo de build.
- Melhorar tratamento de falhas no `index.Rmd` (salvar dados antigos em `docs/data/` e usar como fallback caso falha upstream).
- Incluir `workflow_dispatch` para rodar manualmente o workflow a partir do Actions UI.

Instruções finais
Depois que fizer o push do repositório para o GitHub, me diga o nome do repositório (ou empurre e eu posso verificar aqui se você me der o URL). Eu posso acompanhar a primeira execução do Actions e ajustar onde necessário.

