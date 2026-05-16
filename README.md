# OpenDriverHub - Produção

Infraestrutura de produção do **OpenDriverHub** (deploy do repositório `hub`).

## Stack

- Docker Compose
- SQL Server 2022
- API **.NET 10** (ASP.NET Core, EF Core code-first)
- Web **React/Vite** (servido por Nginx)
- Nginx (reverse proxy)
- Cloudflare Tunnel (já configurado no servidor)

> Diferente da versão anterior (Node): **não há passo de migração SQL manual**.
> A API aplica as migrations do EF Core automaticamente no boot.

## Primeiro setup no Ubuntu

```bash
apt-get update && apt-get install -y git ca-certificates
cd /root
git clone <URL_DO_REPO_opendriver-prod> opendriver-prod
cd opendriver-prod
cp .env.example .env
nano .env
bash bootstrap-ubuntu.sh
```

Edite no `.env` pelo menos:

- `HUB_REPO_URL` (repositório do `hub`)
- `SQLSERVER_PASSWORD`
- `Jwt__Secret` (use `odh-gen-secret`)
- `Cors__Origins` e `HUB_DOMAIN`
- `Seed__Enabled=false` (mantenha falso em produção)

O `bootstrap-ubuntu.sh`:

1. instala Git, Docker, UFW, Fail2ban, cloudflared e utilitários
2. configura Git global
3. adiciona aliases `odh-*` no `/root/.bashrc`
4. clona/atualiza `/root/hub`
5. executa `update.sh`

> **Cloudflare já está configurado neste servidor** — não rode novamente o
> `cloudflare-tunnel-init.sh` nem altere o túnel.

## Atualizar / redeploy

```bash
cd /root/opendriver-prod && bash update.sh
# ou, com os aliases:
odh-update
```

`update.sh`:

1. `git pull` do `hub`
2. `docker compose build` (imagens API .NET + Web Vite)
3. `up -d` — a **API aplica as migrations do EF Core no boot**
4. reinicia o Nginx
5. aguarda `GET /health` ficar OK
6. mostra o status dos containers

## Banco de dados

Migrations são **code-first (EF Core)** e ficam no próprio app
(`hub/backend/src/OpenDriverHub.Infrastructure/Migrations`). São aplicadas
automaticamente quando o container `opendriverhub-api` sobe. Não há scripts
`.sql` nem `schema_migrations` neste repositório.

O **seed de dados demo** (contas `*@demo.com`) só roda se `Seed__Enabled=true`.
Em produção isso fica **desligado** — apenas a estrutura é criada.

## Credenciais de integração (WhatsApp / Mercado Pago / Gmail)

Não precisam ficar no `.env`. São **editáveis em runtime** em
**Admin → Integrações** (o valor salvo no banco sobrepõe o `.env`).
Opcionalmente é possível pré-popular os defaults no `.env`
(`MercadoPago__AccessToken`, etc.).

### Webhook Mercado Pago

Configure no painel do Mercado Pago apontando para:

```text
https://SEU_DOMINIO/api/v1/payments/webhook/mercadopago
```

A verificação é por **assinatura HMAC no header** (`x-signature`), com o
segredo definido em Admin → Integrações (`MercadoPago:WebhookSecret`).
Não se usa `?secret=` na URL.

## Uploads

Imagens enviadas pelo parceiro/admin ficam no volume `api-uploads`
(`/app/uploads` no container) e são expostas em `/uploads/...` pelo Nginx.
Limite no Nginx: `12m` (acompanha `Storage__MaxImageBytes`, 5 MB).

## Comandos úteis

```bash
odh-update
odh-ps
docker logs -f opendriverhub-api
docker logs -f opendriverhub-sqlserver
curl -I http://localhost
curl -fsS http://localhost/health
```

## Checklist rápido

```bash
docker --version
docker compose version
docker ps
curl -fsS http://localhost/health
```
