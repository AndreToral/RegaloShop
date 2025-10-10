# RegaloShop – Plataforma E-commerce lista para producción

RegaloShop es una solución full-stack para lanzar una tienda de regalos y ropa con catálogo, carrito y flujo básico de checkout. Incluye infraestructura lista para AWS (VPC, ALB, ECS Fargate, autoscaling) y un pipeline reproducible para construir imágenes y desplegarlas de extremo a extremo.

## Arquitectura y componentes
- **Frontend**: SPA React + Vite servida por Nginx (`frontend/`), comunica con la API usando `/api`.
- **Backend**: API REST Express.js con PostgreSQL (`backend/`), incluye seeds y migraciones.
- **Infraestructura**: Terraform (`infra/terraform/`) define VPC privada con dos AZ, NAT Gateway, ALB público, ECS Fargate para frontend/backend, políticas de autoscaling por CPU y Requests.
- **Contenedores & despliegue**: Ansible (`infra/ansible/`) construye imágenes Docker, las publica en ECR y, opcionalmente, fuerza despliegues en ECS.

## Estructura del repositorio
```
RegaloShop/
├── backend/                 # API Express + PostgreSQL
│   ├── db/                  # Migraciones y datos de ejemplo
│   ├── scripts/             # Scripts auxiliares
│   └── src/                 # Código fuente (controllers, services, routes, etc.)
├── frontend/                # SPA React/Vite
│   └── src/                 # Componentes, hooks, estilos y consumo de API
├── infra/
│   ├── ansible/             # Playbook para construir/push imágenes y actualizar ECS
│   └── terraform/           # IaC para AWS (VPC, ALB, ECS, autoscaling, IAM, etc.)
└── README.md
```

## Requisitos previos
- Node.js 18+ y npm 9+
- Docker 24+ (para build local y push a ECR)
- PostgreSQL 14+ (local o gestionado)
- Terraform 1.5+
- Ansible 2.14+
- AWS CLI v2 con credenciales que permitan administrar ECR/ECS/VPC/ALB

## Configuración local
1. **Instalar dependencias**
   ```bash
   cd backend && npm install
   cd ../frontend && npm install
   ```
2. **Configurar PostgreSQL**
   - Crear base de datos (por defecto `regaloshop`).
   - Ejecutar migraciones:
     ```bash
     cd backend
     psql "$DATABASE_URL" -f db/migrations/001_init.sql
     ```
   - Copiar `.env.example` a `.env` y completar variables (o usar `DATABASE_URL`).
   - (Opcional) popular datos:
     ```bash
     npm run db:seed            # datos base
     npm run db:seed -- --with-orders
     ```
3. **Levantar servicios en desarrollo**
   - API: `cd backend && npm run dev` (puerto 4000).
   - Frontend: `cd frontend && npm run dev` (puerto 5173 con proxy a `/api`).

## Variables de entorno backend (principales)
- `PORT` (default 4000)
- `FRONTEND_URL` (CORS, múltiples separados por coma)
- `DATABASE_URL` o bien `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- `DB_SSL`, `DB_SSL_STRICT` para entornos gestionados
- Opcionales de pool: `DB_POOL_MAX`, `DB_POOL_IDLE`, `DB_STATEMENT_TIMEOUT`
- `DISABLE_DB_HEALTHCHECK=true` se usa en ECS para permitir healthchecks sin DB disponible

## API REST disponible
Base `http://localhost:4000/api`
- `GET /products`, `/products/:id`
- `GET /categories`
- `POST /orders` (valida stock y persiste orden + items)
- Endpoints auxiliares: `/orders`, `/health`

## Flujo de despliegue en AWS
> La infraestructura asume región `us-east-1` y crea recursos bajo el prefijo definido en `project_name`.

1. **Configurar variables de Terraform**
   - Editar `infra/terraform/terraform.tfvars`:
     - `frontend_image_tag`, `backend_image_tag` (tags a publicar en ECR, ej. `v1.0.0`) y asegúrate de que coincidan exactamente con los definidos en Ansible (`infra/ansible/deploy.yml`).
     - Rango CIDR, subredes, límites de autoscaling, thresholds de CPU/requests, etc.
   - Inicializar Terraform:
     ```bash
     cd infra/terraform
     terraform init
     ```

2. **Construir y publicar imágenes en ECR (Ansible)**
   - Ajustar variables en `infra/ansible/deploy.yml` (tags, cluster/servicios ECS).
   - Antes de ejecutar el playbook, configura tus credenciales con `aws configure` (o variables de entorno equivalentes) para que el CLI pueda autenticarse contra ECR.
   - Ejecutar:
     ```bash
     cd infra
     ansible-playbook -i localhost, ansible/deploy.yml
     ```
   - El playbook asegura los repos ECR, construye las imágenes, hace `docker push` y opcionalmente llama a `aws ecs update-service`.

3. **Aprovisionar / actualizar infraestructura**
   ```bash
   cd terraform
   terraform plan
   terraform apply
   ```
   - Terraform crea/actualiza VPC, NAT, ALB, target groups, cluster ECS, servicios y políticas de autoscaling. Las imágenes se apuntan usando los tags configurados.

4. **Verificar despliegue**
   - Obtener DNS del ALB:
     ```bash
     terraform output alb_url
     ```
   - Frontend: visitar `http://<alb_url>`.
   - Backend: `curl http://<alb_url>/health` y `curl http://<alb_url>/api/products`.
   - ECS: `aws ecs describe-services --cluster tienda-cluster --services tienda-frontend tienda-backend`.

5. **Publicar una nueva versión**
   1. Actualizar código.
   2. Incrementar tags en `deploy.yml` (ej. `frontend_image_tag = "v1.0.1"`).
   3. Ejecutar nuevamente el playbook de Ansible para construir y subir imágenes.
   4. Forzar despliegue (opcional) directamente:
      ```bash
      aws ecs update-service --cluster tienda-cluster --service tienda-frontend --force-new-deployment
      aws ecs update-service --cluster tienda-cluster --service tienda-backend --force-new-deployment
      ```
      o ejecutar `terraform apply` si hay cambios de infraestructura.

## Autoscaling
- **CPU TargetTracking**: objetivo 60 % (`frontend_cpu_target`, `backend_cpu_target`) con cooldowns `scale_out_cooldown = 90 s`, `scale_in_cooldown = 180 s`.
- **ALB RequestCountPerTarget**: thresholds (`frontend_requests_per_target = 100`, `backend_requests_per_target = 60`) para escalar según RPS.
- Límites configurables en `terraform.tfvars` (`*_min_count`, `*_max_count`).

## Solución de problemas
- `CannotPullContainerError`: confirmar que el tag configurado existe en ECR (`aws ecr list-images ...`).
- `connect ECONNREFUSED 127.0.0.1:5432`: el backend necesita una base PostgreSQL accesible. Define `DATABASE_URL` apuntando a RDS/Aurora y habilita la SG correspondiente.
- Terraform sin estado: si se pierde `terraform.tfstate`, importa recursos con `terraform import` antes de destruir o reprovisionar.

## Próximos pasos sugeridos
1. Integrar un gestor de migraciones (Prisma, Knex, Umzug).
2. Implementar autenticación, panel administrativo y pasarela de pagos.
3. Añadir observabilidad (CloudWatch dashboards, Alarmas, X-Ray).
4. Incorporar CI/CD (GitHub Actions, CodeBuild) que ejecute linters, pruebas y pipeline de despliegue automatizado.

---

¿Dudas o mejoras? Revisa los módulos en `infra/`, ajusta variables en `terraform.tfvars` e itera en `ansible/deploy.yml` para adaptar el flujo a tus procesos. ¡Buen despliegue!***
