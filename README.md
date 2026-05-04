# Open Driver - Producao

Infraestrutura de producao do Open Driver, seguindo o mesmo formato operacional do `exsinov-prod`.

## Stack

- Docker Compose
- SQL Server 2022
- API Node.js/TypeScript
- Web React/Vite
- Nginx
- Cloudflare Tunnel para `opendriver.com.br`

## Primeiro setup no Ubuntu

```bash
apt-get update
apt-get install -y git ca-certificates
cd /root
git clone https://github.com/murilogillbert/opendriver-prod.git
cd opendriver-prod
cp .env.example .env
nano .env
bash bootstrap-ubuntu.sh
```

Edite pelo menos:

- `OPEN_DRIVER_REPO_URL`
- `SQLSERVER_PASSWORD`
- `JWT_SECRET`
- `CORS_ORIGIN`
- `MERCADO_PAGO_ACCESS_TOKEN`
- `MERCADO_PAGO_PUBLIC_KEY`
- `MERCADO_PAGO_WEBHOOK_SECRET`
- `GIT_USER_NAME`
- `GIT_USER_EMAIL`

O bootstrap faz:

1. instala Git, Docker, UFW, Fail2ban, cloudflared e utilitarios
2. configura Git global
3. adiciona aliases Open Driver no `/root/.bashrc`
4. clona ou atualiza `/root/opendriver`
5. executa `update.sh`

## Configurar Cloudflare

Pre-requisito: o dominio `opendriver.com.br` precisa estar adicionado na sua conta Cloudflare e usando os nameservers da Cloudflare.

Depois do bootstrap:

```bash
cd /root/opendriver-prod
bash cloudflare-tunnel-init.sh
```

O script:

1. roda `cloudflared tunnel login` se ainda nao houver login
2. cria ou reaproveita o tunnel `opendriver`
3. gera `/root/.cloudflared/config.yml`
4. cria rotas DNS para `opendriver.com.br` e `www.opendriver.com.br`
5. instala/reinicia o servico `cloudflared`

## Atualizar tudo depois do deploy inicial

```bash
cd /root/opendriver-prod && bash update.sh
```

O comando faz:

1. `git pull` do projeto Open Driver
2. build dos containers
3. sobe SQL Server, API, Web e Nginx
4. reinicia o Nginx para renovar a resolucao dos containers internos
5. executa migrations SQL pendentes
6. mostra o status dos containers

## Banco

As migrations ficam no projeto principal:

```text
/root/opendriver/sql/migrations
```

O runner consulta `dbo.schema_migrations` e pula arquivos ja aplicados. Cada migration deve ser idempotente e registrar sua execucao em `dbo.schema_migrations`.

## Uploads

Arquivos enviados pelo admin sao salvos no volume `api-uploads` e expostos em `/uploads/...` pelo Nginx, apontando para a API. O limite de upload no Nginx acompanha o limite padrao da API: `200m`.

## Mercado Pago

Configure o webhook no painel do Mercado Pago apontando para:

```text
https://opendriver.com.br/api/webhooks/mercado-pago?secret=VALOR_DE_MERCADO_PAGO_WEBHOOK_SECRET
```

O webhook registra eventos em `payment_events`, reconcilia pedidos e libera beneficios quando o pagamento e aprovado.

## Comandos uteis

```bash
od-update
od-ps
docker logs -f opendriver-api
docker logs -f opendriver-sqlserver
bash sql/run-migrations.sh
systemctl status cloudflared
journalctl -u cloudflared -f
```

## Checklist rapido

```bash
docker --version
docker compose version
git config --global --list
docker ps
curl -I http://localhost
curl -I https://opendriver.com.br
```
