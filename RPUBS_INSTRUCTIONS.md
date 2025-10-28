Como publicar automaticamente no RPubs

O repositório agora contém um passo opcional no workflow do GitHub Actions que publica o `index.Rmd` no RPubs automaticamente após a renderização.

Para ativar o publish automático você precisa:

1) Ter uma conta no RPubs (https://rpubs.com/). Use seu usuário existente ou crie um.

2) Obter token e secret (chave) para a sua conta RPubs. No RPubs, você precisa criar _deploy keys_ via o pacote `rsconnect` ou via o painel de administração do seu perfil (siga as instruções do site). Uma forma comum é gerar as credenciais no R local:

```r
install.packages('rsconnect')
library(rsconnect)
# isto abrirá um fluxo para autenticação e criará token/secret localmente
rsconnect::connectApi()
```

3) Adicionar os segredos no GitHub do repositório:

- Vá a: https://github.com/<seu-usuario>/<seu-repo>/settings/secrets/actions
- Crie 3 secrets:
  - `RPUBS_ACCOUNT` = seu nome de usuário RPubs
  - `RPUBS_TOKEN` = token gerado (string)
  - `RPUBS_SECRET` = secret/secret key gerada (string)

4) Depois de adicionar os secrets, qualquer push ao branch `main` (ou uma execução manual do workflow) vai executar o passo Publish to RPubs e tentará publicar o `index.Rmd` no RPubs.

Notas de segurança
- Não compartilhe `RPUBS_TOKEN`/`RPUBS_SECRET` publicamente.
- Você pode revogar o token a qualquer momento nas configurações do RPubs/rsconnect.

Se preferir, eu posso gerar um script para guiá-lo passo-a-passo no R local para criar as credenciais que você depois cola nos secrets — me avise se quer esse script.