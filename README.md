# Event Hub K8s Run Guide

This directory contains the Kubernetes manifests for running the full Event Hub stack on Docker Desktop Kubernetes.

## Prerequisites

- Docker Desktop installed
- Kubernetes enabled in Docker Desktop
- `kubectl` available in PowerShell
- Docker images pushed to Docker Hub
- Current manifests point to Docker Hub images under `amiru1234/...:latest`

Check the cluster:

```powershell
kubectl config current-context
kubectl get nodes
```

Expected context is usually `docker-desktop`.

## Key Files

- `01-secrets.yaml`: runtime secrets
- `02-configmap.yaml`: runtime non-secret config
- `06-keycloak.yaml`: Keycloak deployment and realm import
- `keycloak/ec7205-realm.json`: imported Keycloak realm
- `kustomization.yaml`: applies the full stack

## Before Deploying

Update these files with the correct values:

- `01-secrets.yaml`
- `02-configmap.yaml`
- `keycloak/ec7205-realm.json`

Important values to verify:

- `KEYCLOAK_CLIENT_SECRET`
- `KEYCLOAK_CONFIG_PASSWORD`
- `KEYCLOAK_CONFIG_NAME`
- `MONGO_URI`
- `MYSQL_ROOT_PASSWORD`
- AWS and Brevo secrets if those integrations are used

For auth-service startup seeding to work, Keycloak must contain:

- realm `ec7205`
- client `ec7205-client`
- client secret matching `KEYCLOAK_CLIENT_SECRET`
- user `amirumithsara1234@gmail.com`
- that user password matching `KEYCLOAK_CONFIG_PASSWORD`

## Deploy

Apply everything with Kustomize:

```powershell
kubectl apply -k "C:\Users\94717\Desktop\Cloud Project\k8s"
```

Watch pods:

```powershell
kubectl get pods -n event-hub -w
```

Check services:

```powershell
kubectl get svc -n event-hub
```

## Restart A Single Service

Examples:

```powershell
kubectl rollout restart deployment auth-service -n event-hub
kubectl rollout restart deployment gateway-service -n event-hub
kubectl rollout restart deployment frontend-ticket -n event-hub
kubectl rollout restart deployment frontend-admin -n event-hub
```

## Common Port Forwards

Run each command in a separate terminal and keep it open.

```powershell
kubectl port-forward -n event-hub svc/keycloak 8080:8080
kubectl port-forward -n event-hub svc/gateway-service 9090:9090
kubectl port-forward -n event-hub svc/auth-service 9092:9092
kubectl port-forward -n event-hub svc/event-service 9091:9091
kubectl port-forward -n event-hub svc/booking-service 9093:9093
kubectl port-forward -n event-hub svc/notification-service 9094:9094
kubectl port-forward -n event-hub svc/frontend-ticket 3000:3000
kubectl port-forward -n event-hub svc/frontend-admin 4000:4000
kubectl port-forward -n event-hub svc/rabbitmq 15672:15672
kubectl port-forward -n event-hub svc/mysql 3307:3306
kubectl port-forward -n event-hub svc/mongodb 27017:27017
```

Open:

- Frontend ticket: `http://localhost:3000`
- Frontend admin: `http://localhost:4000`
- Gateway: `http://localhost:9090`
- Keycloak: `http://localhost:8080`
- RabbitMQ UI: `http://localhost:15672`
- MySQL local forwarded port: `3307`

## Check Logs

Examples:

```powershell
kubectl logs -n event-hub deployment/auth-service --tail=100 -f
kubectl logs -n event-hub deployment/gateway-service --tail=100 -f
kubectl logs -n event-hub deployment/frontend-ticket --tail=100 -f
kubectl logs -n event-hub deployment/keycloak --tail=100 -f
```

## Check MySQL Data

Open MySQL inside the pod:

```powershell
kubectl exec -it -n event-hub mysql-0 -- mysql -u root -p1234
```

Then run:

```sql
USE ec7205_eventHub_auth;
SHOW TABLES;
SELECT id,email,email_verified FROM system_user;
```

## Scale A Service Down Or Up

Example:

```powershell
kubectl scale deployment auth-service -n event-hub --replicas=0
kubectl scale deployment auth-service -n event-hub --replicas=1
```

## Rebuild And Redeploy After Code Changes

Example for `auth-service-api`:

```powershell
docker build -t auth-service-api:latest "C:\Users\94717\Desktop\Cloud Project\backend\auth-service-api"
docker tag auth-service-api:latest amiru1234/auth-service-api:latest
docker push amiru1234/auth-service-api:latest
kubectl rollout restart deployment auth-service -n event-hub
```

Example for `gateway-service-api`:

```powershell
docker build -t gateway-service-api:latest "C:\Users\94717\Desktop\Cloud Project\backend\gateway-service-api"
docker tag gateway-service-api:latest amiru1234/gateway-service-api:latest
docker push amiru1234/gateway-service-api:latest
kubectl rollout restart deployment gateway-service -n event-hub
```

## Known Notes

- `frontend-ticket` uses `NEXT_PUBLIC_API_BASE_URL=http://gateway-service:9090`
- `frontend-admin` expects the gateway on `http://localhost:9090` in the browser when using port-forward
- `auth-service` startup seeding depends on successful Keycloak login
- if `kubectl port-forward` returns immediately, the tunnel is not active
- if local port `3306` is busy, use `3307:3306`

## Full Reset

Re-apply all manifests:

```powershell
kubectl apply -k "C:\Users\94717\Desktop\Cloud Project\k8s"
```

Delete all pods and let Kubernetes recreate them:

```powershell
kubectl delete pods --all -n event-hub
```
