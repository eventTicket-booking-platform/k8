# Event Hub Kubernetes

Kustomize manifests for Event Hub. MySQL, Keycloak, MongoDB, AWS S3 and Brevo remain external dependencies. These manifests do not provision them.

## Kubernetes Environments

```text
base/                  Shared namespace, ConfigMap, Services, Deployments and RabbitMQ PVC
overlays/local/        Docker Desktop Kubernetes; Windows-host MySQL and Keycloak
overlays/gke/          Existing GKE configuration, BackendConfig and GCE ingress
gke-cluster.tf         Existing infrastructure definition (unchanged)
keyclock/              Existing Keycloak realm export (see security note)
```

Both overlays reference `../../base` and target `event-hub`. Use an overlay for deployment; the base deliberately omits environment-specific database/Keycloak settings and Spring profiles. There is no root deployment entry point.

- **Local:** MySQL uses `host.docker.internal:3306`; Keycloak uses `http://host.docker.internal:8080/`, realm `ec7205`, client `ec7205-client`. Application Spring services and Eureka use `local`. Frontends use their existing API proxies; the admin proxy targets `http://gateway-service:9090/api`. All Services are ClusterIP; no ingress controller is required.
- **GKE:** preserves the previous cloud endpoints, image references, frontend annotations, BackendConfig, ingress routes and RabbitMQ management LoadBalancer. Application Spring services and Eureka use `prod`.
- **Shared:** Config Server retains its `git` profile in both environments because that enables its Git backend. The public config repository URI and label are unchanged. RabbitMQ keeps its existing 5 GiB ReadWriteOnce PVC with no explicit StorageClass; a default provisioner is required. Existing S3 region/bucket settings remain shared; provide credentials authorized for that bucket.

Kustomize uses the modern `patches` field. Use a recent `kubectl` with embedded Kustomize (validated with Kustomize v5.8.1).

## Local deployment

1. Start MySQL and Keycloak on Windows. Make their ports reachable from Docker Desktop Kubernetes. Provide a reachable MongoDB instance for notifications, plus the external credentials required by the services. A MongoDB instance on Windows can be addressed using `host.docker.internal` in the private `MONGO_URI`.
2. Confirm the intended Docker Desktop context and nodes:

   ```powershell
   kubectl config current-context
   kubectl get nodes
   ```

3. Create the private secret file, then replace **every placeholder** with your own local values. Git credentials can be empty when anonymous access to the public config repository is sufficient. The Mongo root keys are retained for compatibility; these manifests do not deploy MongoDB.

   ```powershell
   Copy-Item overlays/local/01-secrets.local.example.yaml overlays/local/01-secrets.yaml
   ```

   Review `overlays/local/configmap-patch.yaml`. Its public key was reused from the existing local application configuration: replace `PUBLIC_KEY_STRING` with your local realm's signing public key if different. JWT `iss` must match the configured `http://host.docker.internal:8080/realms/ec7205` issuer; a token issued for `localhost` is not interchangeable. Configure the external Keycloak instance accordingly. Local Keycloak management username/password come from the private Secret.

4. Create the namespace before applying its Secret, then deploy the local overlay:

   ```powershell
   kubectl apply -f base/namespace.yaml
   kubectl apply -f overlays/local/01-secrets.yaml
   kubectl apply -k overlays/local
   kubectl get pods -n event-hub
   kubectl get svc -n event-hub
   kubectl get pvc -n event-hub
   ```

5. For frontend access, run each port-forward in a separate terminal:

   ```powershell
   kubectl port-forward -n event-hub svc/frontend-ticket 3000:3000
   kubectl port-forward -n event-hub svc/frontend-admin 4000:4000
   ```

   Open `http://localhost:3000/` and `http://localhost:4000/admin/`. For direct Gateway API access or RabbitMQ management, optionally run:

   ```powershell
   kubectl port-forward -n event-hub svc/gateway-service 9090:9090
   kubectl port-forward -n event-hub svc/rabbitmq-management 15672:15672
   ```

Images/tags are unchanged. Port forwarding assumes the existing images contain the current frontend proxy implementation; this refactor does not rebuild images or validate runtime connectivity. Kustomize rendering does not ensure application readiness or startup ordering.

## GKE deployment

Confirm your GKE context. Supply a private Secret named `event-hub-secrets` in namespace `event-hub`, with the keys shown in the local example but appropriate GKE values. Keep it outside Git. For example, prepare the ignored `overlays/gke/01-secrets.yaml`, then run:

```powershell
kubectl config current-context
kubectl apply -f base/namespace.yaml
kubectl apply -f overlays/gke/01-secrets.yaml
kubectl apply -k overlays/gke
kubectl get pods,svc,pvc,ingress -n event-hub
```

The GKE overlay requires the existing GKE ingress/BackendConfig support. The former private root `01-secrets.yaml`, if present, can still be applied separately instead of the GKE path above. Private Secrets are intentionally excluded from both Kustomizations, so rendering works without them. No infrastructure or networking changes are included.

## Render validation without deployment

From this repository root:

```powershell
kubectl kustomize base
kubectl kustomize overlays/local
kubectl kustomize overlays/gke
```

The refactor was checked for duplicate resources, namespace consistency, local endpoints/profiles and absence of GKE resources locally. The GKE render was compared structurally with the original root render; all 26 resources matched, ignoring environment-variable list order. Base and local each render 24 resources. These are render checks, not a cluster deployment or smoke test.

## Secrets and existing security concerns

The local example contains placeholders only. Both environment Secret files are ignored and must never be committed. Kubernetes Secret YAML/base64 does not encrypt credentials.

The existing `keyclock/ec7205-realm.json` contains credential-like values, and `01-secrets.yaml` exists in Git history. Rotation may be required. Neither the realm export nor Git history was changed in this configuration refactor. Do not treat the realm export as a safe template for sharing credentials.
