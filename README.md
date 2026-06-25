# casino-backend

API REST del casino VidalCasino (Node.js/Express + PostgreSQL). Es el único servicio
que **emite JWT** (HS256); todos los demás microservicios solo lo validan. Gestiona
autenticación, usuarios, juegos y transacciones. Se expone como `ClusterIP` dentro
del clúster, por lo que nunca es accesible directamente desde Internet. [cite:38][file:26]

- **Puerto:** `3000`
- **Prefijos de rutas:** `/api/auth`, `/api/usuarios`, `/api/juegos`, `/api/transacciones`

---

## Estructura del repositorio

```text
backend_intro_devops_casino/
├── src/
│   ├── server.js
│   ├── db/
│   │   ├── pool.js
│   │   └── seed.js
│   └── routes/
│       ├── auth.js
│       ├── users.js
│       ├── games.js
│       └── transactions.js
├── db/
├── k8s/
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   └── casino-secrets.yaml
├── .github/
│   └── workflows/
│       └── deploy-backend.yml
├── .dockerignore
├── .env.example
├── .gitignore
├── Dockerfile
├── package.json
└── README.md
```

Mantén el repo limpio: sin `.env`, sin `node_modules` y eliminando `.DS_Store`, porque el PDF exige estructura ordenada y sin archivos basura o secretos en el repositorio. [file:26][cite:30]

---

## Variables de entorno

Copia `.env.example` a `.env` y ajusta los valores reales. **No commitees** `.env`. [cite:38][file:26]

| Variable | Descripción | Ejemplo |
|---|---|---|
| `PORT` | Puerto del servidor | `3000` [cite:38] |
| `JWT_SECRET` | Clave de firma JWT compartida con todos los servicios | `cambiame-en-produccion` [cite:38] |
| `JWT_EXPIRES_IN` | Tiempo de expiración del token | `8h` [cite:38] |
| `DB_HOST` | Host de PostgreSQL | `localhost` [cite:38] |
| `DB_PORT` | Puerto de PostgreSQL | `5432` [cite:38] |
| `DB_USER` | Usuario de BD | `casino` [cite:38] |
| `DB_PASSWORD` | Contraseña de BD | `casino` [cite:38] |
| `DB_NAME` | Nombre de la base | `casino_db` [cite:38] |
| `CORS_ORIGIN` | Orígenes CORS permitidos | `*` [cite:38] |

---

## Cómo construir

### Local

```bash
cp .env.example .env
npm install
npm start
```

Eso levanta el backend en `http://localhost:3000` usando las variables del `.env`. [cite:38]

### Docker

```bash
docker build -t casino-backend:local .
docker run --env-file .env -p 3000:3000 casino-backend:local
```

El `Dockerfile` ya usa una imagen Node 20 Alpine, corre como usuario `node` y expone el puerto `3000`. [cite:31]

---

## Endpoints principales

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/api/auth/register` | No | Registro de usuario |
| POST | `/api/auth/login` | No | Login y emisión de JWT |
| GET | `/api/usuarios/me` | Sí | Perfil del usuario autenticado |
| GET | `/api/juegos` | No | Juegos disponibles |
| POST | `/api/juegos/:id/jugar` | Sí | Registrar partida |
| GET | `/api/transacciones` | Sí | Historial de transacciones |
| GET | `/livez` | No | Liveness probe de Kubernetes |
| GET | `/readyz` | No | Readiness probe de Kubernetes |
| GET | `/health` | No | Health legacy existente |

El backend actual ya tiene `/health`, y para cumplir el PDF debes agregar además `/livez` y `/readyz` como rutas separadas para probes de Kubernetes. [cite:32][file:26]

---

## Health probes

### `GET /livez`
Debe responder `200` sin depender de PostgreSQL, porque Kubernetes lo usa para decidir si reinicia el pod. [file:26]

```json
{ "status": "ok", "uptime": 42.3 }
```

### `GET /readyz`
Debe verificar conexión a PostgreSQL con `SELECT 1`; si la BD está caída responde `503` para que Kubernetes saque el pod del balanceo sin reiniciarlo. [file:26]

```json
// 200 OK
{ "ready": true, "db": "up", "uptime": 42.3 }

// 503 Service Unavailable
{ "ready": false, "db": "down", "error": "connection refused" }
```

---

## Cómo desplegar

### Pipeline automático

```bash
git push origin deploy
git tag v1.2.3
git push origin v1.2.3
```

El workflow del repo debe hacer las tres etapas exigidas: build de imagen Docker, push a Amazon ECR y deploy en EKS. Además debe usar tres tags simultáneos: `latest`, `${{ github.sha }}` y `vX.Y.Z` cuando el trigger venga desde un tag Git. [file:26][cite:37]

### Manual en EKS

```bash
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <AWS_REGION>
kubectl apply -f k8s/casino-secrets.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl get pods -l app=casino-backend
```

El manifiesto del backend debe consumir credenciales desde `casino-secrets` mediante `secretKeyRef`, sin credenciales en texto plano. [file:26]

---

## CI/CD y secrets

### GitHub Secrets requeridos

| Secret | Uso |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial temporal AWS Academy [file:26] |
| `AWS_SECRET_ACCESS_KEY` | Credencial temporal AWS Academy [file:26] |
| `AWS_SESSION_TOKEN` | Token de sesión temporal AWS Academy [file:26] |
| `AWS_REGION` | Región de AWS [file:26] |
| `ECR_REPOSITORY` | `casino-backend` |
| `EKS_CLUSTER` | Nombre del clúster EKS |

El workflow actual del repo todavía despliega a EC2 por SSH, así que debes reemplazarlo por uno orientado a EKS para cumplir el PDF. [cite:37][file:26]

---

## Comandos útiles

```bash
kubectl get pods -l app=casino-backend
kubectl logs -f deployment/casino-backend
kubectl describe deployment casino-backend
kubectl top pods -l app=casino-backend
kubectl rollout restart deployment/casino-backend
kubectl rollout history deployment/casino-backend
kubectl delete pod <nombre-del-pod>
kubectl get pods -l app=casino-backend -w
```

Estos comandos sirven para demostrar autorecuperación, revisar logs y validar que el Deployment recrea pods al borrarlos. [file:26]

---

## Troubleshooting

### `CrashLoopBackOff`
Revisa logs y eventos del pod:

```bash
kubectl logs <nombre-del-pod> --previous
kubectl describe pod <nombre-del-pod>
```

Las causas más comunes son `JWT_SECRET` vacío, credenciales de BD incorrectas en `casino-secrets` o PostgreSQL no disponible al arranque. [cite:38][file:26]

### `0/1 READY`
Si falla la readiness probe, valida la conectividad a PostgreSQL desde dentro del pod. [file:26]

```bash
kubectl exec -it <nombre-del-pod> -- \
  node -e "const {Pool}=require('pg'); new Pool({host:process.env.DB_HOST}).query('SELECT 1').then(()=>console.log('OK')).catch(console.error)"
```

### Error de CORS
Ajusta `CORS_ORIGIN` al dominio o URL pública real del frontend cuando el LoadBalancer ya esté creado. [cite:38][file:26]

### `.DS_Store` en el repo
El repo actual tiene `.DS_Store` en la raíz, por lo que debes eliminarlo y agregarlo al `.gitignore` para no descontar por estructura. [cite:30][file:26]

```bash
git rm --cached .DS_Store
echo ".DS_Store" >> .gitignore
git commit -m "chore: eliminar .DS_Store y agregar a .gitignore"
```

---

## Convención de commits

```text
feat:  nueva funcionalidad
fix:   corrección de bug
chore: mantenimiento o limpieza
ci:    cambios en pipeline o workflows
docs:  cambios en documentación
test:  agregar o corregir tests
```

Ejemplos correctos:

```text
feat: agregar /livez y /readyz como health probes
ci: migrar deploy-backend.yml de EC2 a EKS
feat: agregar manifiestos k8s para casino-backend
docs: actualizar README con despliegue en EKS
chore: eliminar .DS_Store y limpiar .gitignore
```

El PDF pide explícitamente commits descriptivos con prefijos y descarta mensajes vagos como `asdf` o `fix` solo. [file:26]