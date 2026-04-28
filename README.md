# Event Hub Kubernetes Deployment

This repository contains the Kubernetes deployment manifests for the Event Hub microservice platform.

## Deployed Components

Infrastructure and platform services:

- `config-server`
- `eureka-server`
- `rabbitmq`

Business services:

- `auth-service`
- `event-service`
- `booking-service`
- `notification-service`
- `gateway-service`

Frontends:

- `frontend-ticket`
- `frontend-admin`

Ingress routes:

- `/` -> `frontend-ticket`
- `/admin` -> `frontend-admin`
- `/api` -> `gateway-service`
- `/user-service` -> `gateway-service`
- `/event-service` -> `gateway-service`
- `/booking-service` -> `gateway-service`
- `/notification-service` -> `gateway-service`

## External Dependencies

This repo does not deploy everything. These must already exist or be reachable:

- MySQL
- Keycloak
- MongoDB Atlas or another MongoDB deployment
- AWS S3 bucket and IAM credentials
- Spring Cloud Config Git repository

## Deploy Order

To have every service come up cleanly, use this order:

1. namespace
2. secrets
3. config map
4. rabbitmq
5. config-server
6. eureka-server
7. auth-service
8. event-service
9. booking-service
10. notification-service
11. gateway-service
12. frontend-ticket
13. frontend-admin
14. ingress

## Secrets and Config

Start from the safe template:

```powershell
Copy-Item 01-secrets.local.example.yaml 01-secrets.yaml
```

Then fill real values for:

- MySQL password
- MongoDB credentials and URI
- RabbitMQ credentials
- Keycloak client secret and bootstrap credentials
- Config repo username and password if the repo is private
- AWS credentials
- Brevo credentials

Review [`02-configmap.yaml`](./02-configmap.yaml) before deploy, especially:

- `MYSQL_HOST`
- `CONFIG_GIT_URI`
- `KEYCLOAK_SERVER_URL`
- `KEYCLOAK_ISSUER_URI`
- `AWS_BUCKET_NAME`
- `NEXT_PUBLIC_API_BASE_URL`
- `SERVER_API_BASE_URL`
- `API_BASE_URL`

## Local Deployment

This path is for Docker Desktop Kubernetes, Minikube, or kind.

### Important Local Limitation

[`19-frontend-ticket-backendconfig.yaml`](./19-frontend-ticket-backendconfig.yaml) and [`30-ingress.yaml`](./30-ingress.yaml) are written for GCP GKE with GCE ingress. They are not portable as-is to a generic local cluster.

For local work, the reliable path is:

1. apply secrets
2. apply the manifests
3. reach services through `kubectl port-forward`

### Local Steps

1. Apply secrets:

```powershell
kubectl apply -f 01-secrets.yaml
```

2. Deploy the stack:

```powershell
kubectl apply -k .
```

3. Verify rollout:

```powershell
kubectl get pods -n event-hub
kubectl get svc -n event-hub
kubectl get pvc -n event-hub
```

4. Port-forward the important services:

```powershell
kubectl port-forward -n event-hub svc/frontend-ticket 3000:3000
kubectl port-forward -n event-hub svc/frontend-admin 4000:4000
kubectl port-forward -n event-hub svc/gateway-service 9090:9090
kubectl port-forward -n event-hub svc/auth-service 9092:9092
kubectl port-forward -n event-hub svc/event-service 9091:9091
kubectl port-forward -n event-hub svc/booking-service 9093:9093
kubectl port-forward -n event-hub svc/notification-service 9094:9094
kubectl port-forward -n event-hub svc/rabbitmq 15672:15672
```

Local URLs:

- ticket frontend: `http://localhost:3000`
- admin frontend: `http://localhost:4000`
- gateway: `http://localhost:9090`
- rabbitmq management: `http://localhost:15672`

## GCP GKE Deployment

Your manifests are aligned with GKE, not EKS. The repo uses:

- `ingressClassName: gce`
- GKE `BackendConfig`
- GCE-style ingress annotations

### GKE Prerequisites

- GKE cluster with a default storage class
- GCE ingress enabled
- public reachability from the cluster to MySQL, Keycloak, MongoDB, Git config repo, AWS, and Brevo

### GKE Steps

1. Prepare `01-secrets.yaml`.
2. Update `02-configmap.yaml` with production endpoints.
3. Apply secrets:

```powershell
kubectl apply -f 01-secrets.yaml
```

4. Apply resources:

```powershell
kubectl apply -k .
```

5. Verify:

```powershell
kubectl get ingress -n event-hub
kubectl get pods -n event-hub
kubectl get svc -n event-hub
```

6. If you reserve a static global IP in GCP, uncomment this annotation in `30-ingress.yaml`:

```yaml
kubernetes.io/ingress.global-static-ip-name: event-hub-ip
```

## GKE Cluster Infrastructure (Terraform)

The `gke-cluster.tf` file provisions a production-ready GKE cluster using Terraform. This infrastructure must be created before deploying the Kubernetes manifests.

### GKE Cluster Specifications

The Terraform configuration creates a GKE cluster with the following specifications:

**Cluster Configuration:**

- **Cluster Name:** `cluster-1-replicated`
- **Region/Zone:** `us-central1-a`
- **Networking Mode:** VPC Native (recommended for GKE)
- **Release Channel:** REGULAR (automatic, non-disruptive updates)
- **Deletion Protection:** Disabled (for easier cleanup in test environments)

**Network Configuration:**

- **VPC Network:** `gke-vpc`
- **Subnet:** `gke-subnet`
- **VPC CIDR:** `10.0.0.0/16`
- **Pod IP Range:** `10.1.0.0/16` (secondary range)
- **Service IP Range:** `10.2.0.0/20` (secondary range)

**Node Pool:**

- **Name:** `default-pool`
- **Node Count:** 2
- **Machine Type:** `e2-medium` (2 vCPU, 4 GB memory per node)
- **Image Type:** `COS_CONTAINERD` (Container-Optimized OS with containerd)
- **Disk Configuration:**
  - **Type:** `pd-balanced` (balanced performance and cost)
  - **Size:** 15 GB per node
- **Security Features:**
  - Shielded nodes enabled (secure boot and integrity monitoring)
  - Auto-upgrade enabled
  - Auto-repair enabled
- **Monitoring & Logging:**
  - System components and workload logging enabled
  - Comprehensive monitoring (pods, deployments, statefulsets, daemonsets, HPA, storage, kubelet, cAdvisor)
  - Managed Prometheus enabled

### Prerequisites for Terraform Provisioning

Before running Terraform, ensure you have:

1. **GCP Project Setup:**
   - Active GCP project with billing enabled
   - GCP CLI (`gcloud`) installed and authenticated: `gcloud auth application-default login`
   - Project ID set: `gcloud config set project YOUR_PROJECT_ID`

2. **Terraform Installation:**
   - Terraform CLI v1.0+ installed
   - GCP provider access

3. **Required GCP Permissions:**
   - `compute.networks.create`
   - `compute.subnetworks.create`
   - `container.clusters.create`
   - `container.nodePools.create`

### Terraform Provisioning Steps

1. **Initialize Terraform:**

```powershell
cd <path-to-k8s-directory>
terraform init
```

2. **Review the Terraform plan:**

```powershell
terraform plan -out=tfplan
```

This shows all resources that will be created. Review for any unexpected changes.

3. **Apply the Terraform configuration:**

```powershell
terraform apply tfplan
```

This provisions:

- VPC network and subnet
- GKE cluster
- Node pool with 2 e2-medium nodes

The provisioning typically takes 5-10 minutes.

4. **Get cluster credentials:**

Once the cluster is created, configure `kubectl` to access it:

```powershell
gcloud container clusters get-credentials cluster-1-replicated --zone us-central1-a
```

5. **Verify cluster creation:**

```powershell
kubectl cluster-info
kubectl get nodes
```

You should see 2 nodes in Ready state.

### Post-Provisioning

After the GKE cluster is successfully created and nodes are ready, proceed with **GKE Steps** above to deploy the Event Hub services.

### Cleaning Up Infrastructure

To remove the GKE cluster and all related infrastructure:

```powershell
terraform destroy
```

⚠️ **Warning:** This will delete the cluster, all running services, and associated data. Ensure backups exist before running this command.

### Customizing the Cluster

To modify cluster specifications, edit `gke-cluster.tf` before provisioning:

- **Change node count:** Update `node_count` in the `google_container_node_pool` resource
- **Change machine type:** Modify `machine_type` (e.g., `e2-standard-4` for larger nodes)
- **Change region/zone:** Update `location` fields (must be consistent)
- **Adjust disk size:** Modify `disk_size_gb`
- **Enable deletion protection:** Set `deletion_protection = true` for production

After changes, run `terraform plan` and `terraform apply` to update the cluster.

## Health and Troubleshooting

Useful commands:

```powershell
kubectl logs -n event-hub deploy/config-server
kubectl logs -n event-hub deploy/eureka-server
kubectl logs -n event-hub deploy/gateway-service
kubectl logs -n event-hub deploy/notification-service
```

Common issues:

- `ImagePullBackOff`: image tag missing or registry access issue
- `CrashLoopBackOff` on Spring services: Config Server, Keycloak, MySQL, or secret mismatch
- RabbitMQ pod stuck: PVC or storage class problem
- frontend loads but API fails: wrong `/api` routing or base URL config
- notification failures: bad MongoDB URI, RabbitMQ config, or Brevo key

## Security Note

`01-secrets.yaml` is intentionally ignored by Git. Keep it local and generate it from `01-secrets.local.example.yaml`.
