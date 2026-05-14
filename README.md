# casino-backend — VidalCasino

Backend Node.js + Express + PostgreSQL para el casino online.

## Levantar en local

```bash
cp .env.example .env
# Edita .env con tus valores
docker compose up -d --build
```

## Endpoints principales

- `POST /api/auth/login`
- `GET /api/games/*`
- `GET /api/transactions`
- `GET /health`

## Variables de entorno

| Variable | Descripción |
|---|---|
| `DB_HOST` | Host de PostgreSQL |
| `DB_USER` | Usuario de la BD |
| `DB_PASSWORD` | Contraseña de la BD |
| `DB_NAME` | Nombre de la base de datos |
| `JWT_SECRET` | Clave para firmar tokens JWT |
| `CORS_ORIGIN` | Origen permitido por CORS |

## CI/CD

El pipeline se dispara con `push` a la rama `deploy`. Flujo: build → push a ECR → deploy en EC2 (subnet privada via ProxyJump desde EC2-frontend).

## Ramas

- `main`: referencia estable, no se hace push directo
- `dev`: desarrollo diario
- `deploy`: gatilla el pipeline CI/CD
