#!/usr/bin/env Rscript
# Interactive helper to prepare RPubs credentials for GitHub Actions
# This script does NOT send your secrets anywhere — it helps you obtain
# the RPubs token/secret and prints the exact commands (and UI steps)
# to add them as GitHub Actions secrets.

if(!interactive()){
  message('Run this script interactively in R (RStudio or R terminal).')
}

if(!requireNamespace('rsconnect', quietly = TRUE)){
  message('Installing rsconnect (needed to help with RPubs interactions)...')
  install.packages('rsconnect', repos = 'https://cloud.r-project.org')
}

cat('\n==== Guia rápido para criar credenciais RPubs e adicioná-las ao GitHub Actions ====\n')
cat('\nPasso 1: entrar no RPubs e criar um token/secret\n')
cat('  - Abra no navegador: https://rpubs.com/ e faça login com sua conta.\n')
cat('  - Vá para as configurações da conta (provavelmente https://rpubs.com/account) e procure por "API token" ou "Publish credentials".\n')
cat('  - Crie um novo token/secret. Você receberá duas strings: token e secret (guarde-as).\n')

cat('\nPasso 2: executar este script e colar os valores quando solicitado\n')
account <- readline(prompt = 'RPubs username (ex: seu_usuario): ')
token <- readline(prompt = 'RPubs token (cole aqui): ')
secret <- readline(prompt = 'RPubs secret (cole aqui): ')

if(nchar(account) == 0 || nchar(token) == 0 || nchar(secret) == 0){
  cat('\nAlguma informação está vazia. Saindo sem gravar nada.\n')
  quit(save = 'no', status = 1)
}

cat('\nOk — pronto. Agora você tem as credenciais.\n')
cat('\nOpção A (recomendada): usar o GitHub UI para adicionar os secrets (mais simples e segura)\n')
cat('  1) Vá em: https://github.com/<seu-usuario>/<seu-repo>/settings/secrets/actions\n')
cat('  2) Crie 3 secrets com os nomes e valores abaixo:\n')
cat(sprintf('     - RPUBS_ACCOUNT = %s\n', account))
cat(sprintf('     - RPUBS_TOKEN   = %s\n', token))
cat(sprintf('     - RPUBS_SECRET  = %s\n', secret))

cat('\nOpção B (avançado): usar o GitHub CLI (gh) para definir os secrets via terminal)\n')
cat('  - Se tiver o gh instalado e autenticado, rode estes comandos localmente (substitua owner/repo):\n')
cat(sprintf("\n  gh secret set RPUBS_ACCOUNT --body '%s' --repo %s/%s\n", account, Sys.getenv('GITHUB_ACTOR', 'your-username'), basename(normalizePath('.'))))
cat(sprintf("  gh secret set RPUBS_TOKEN   --body '%s' --repo %s/%s\n", token, Sys.getenv('GITHUB_ACTOR', 'your-username'), basename(normalizePath('.'))))
cat(sprintf("  gh secret set RPUBS_SECRET  --body '%s' --repo %s/%s\n", secret, Sys.getenv('GITHUB_ACTOR', 'your-username'), basename(normalizePath('.'))))

cat('\nAviso de segurança:\n')
cat(' - Não compartilhe estes valores em canais públicos.\n')
cat(' - O GitHub Actions armazena secrets com segurança quando adicionados via UI/gh.\n')

cat('\nApós adicionar os secrets no repositório, faça um novo push no branch main ou re-run no GitHub Actions para que o passo RPubs seja executado.\n')
cat('\nFim.\n')
