# Event Hub Kubernetes Deployment

This repository contains the Kubernetes deployment manifests for the Event Hub microservice platform.

## Configuration Management with Kustomize

This project uses [Kustomize](https://kustomize.io/) for managing and customizing Kubernetes manifests. Kustomize is a tool that allows you to customize raw, template-free YAML files for multiple purposes, leaving the original YAML untouched and usable as-is.

The `kustomization.yaml` file in the root directory defines the set of resources to be deployed and any customizations such as namespace overrides, image tags, or patches.

### Prerequisites for Deployment

- `kubectl` installed and configured to access your Kubernetes cluster.
- Kustomize is built into `kubectl` (version 1.14+), so no separate installation is needed.
- External dependencies (MySQL, Keycloak, etc.) must be available as described below.

### Deploying to Kubernetes Cluster

To deploy this project to a Kubernetes cluster:

1. Clone or navigate to this repository.
2. Prepare secrets and config as described in the [Secrets and Config](#secrets-and-config) section.
3. Run the following command from the repository root:

   ```bash
   kubectl apply -k .
   ```

   This command uses Kustomize to apply all manifests, ensuring services start in the correct order and with proper configurations.

For environment-specific deployments, create overlays in subdirectories with their own `kustomization.yaml` files that reference the base resources and apply patches.

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
- `/eureka` -> `eureka-server`
- `/rabbitmq/*` -> `rabbitmq`

## External Dependencies

This repo does not deploy everything. These must already exist or be reachable:

- MySQL
- Keycloak
- MongoDB Atlas or another MongoDB deployment
- AWS S3 bucket and IAM credentials
- Spring Cloud Config Git repository

## Deploy Order

The `kustomization.yaml` file defines the resources in the correct deployment order to ensure dependencies are met. When you run `kubectl apply -k .`, Kustomize applies the manifests in sequence:

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

This order ensures that infrastructure services (like RabbitMQ, Config Server, Eureka) are available before business services start.

## Secrets and Config

Rename `01-secrets.local.example.yaml` to `01-secrets.yaml` and fill in the real values for:

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

### Local Keycloak Setup

This project already includes a Keycloak realm export at [`keyclock/ec7205-realm.json`](./keyclock/ec7205-realm.json), and the local Keycloak distribution available in the workspace is `keycloak-26.5.7`.

Use Keycloak version `26.5.7` for local setup so the imported realm matches the current project setup.

#### Expected Keycloak values after import

- Realm: `ec7205`
- Client ID: `ec7205-client`
- Project roles in realm export: `admin`, `host`, `user`

#### Start Keycloak locally with the realm import

From the project root:

1. Download and extract Keycloak 26.5.7:

```bash
wget https://github.com/keycloak/keycloak/releases/download/26.5.7/keycloak-26.5.7.zip
unzip keycloak-26.5.7.zip
```

2. Copy the realm file into Keycloak's import directory:

```bash
mkdir -p keycloak-26.5.7/data/import
cp ./keyclock/ec7205-realm.json keycloak-26.5.7/data/import/ec7205-realm.json
```

**Note:** Before starting Keycloak, update `keyclock/ec7205-realm.json` with your specific user details (e.g., email, password) if needed.

```json
{
  "id": "9482a854-2a00-4c70-a99e-ca60a945c438",
  "username": "your@gmail.com",
  "firstName": "firstname",
  "lastName": "lastName",
  "email": "your@gmail.com",
  "emailVerified": true,
  "enabled": true,
  "createdTimestamp": 1775365922330,
  "totp": false,
  "credentials": [
    {
      "id": "1dbe5dcc-76af-425d-bddc-cc36e1405dae",
      "type": "password",
      "userLabel": "My password",
      "createdDate": 1776007399750,
      "secretData": "{\"value\":\"G/V3ye8ifqt0FVNOku1zKxPbuBACsDKWlrDM/bKZ0yA=\",\"salt\":\"3RUis2NC1ADi7ZoYXcfs5A==\",\"additionalParameters\":{}}",
      "credentialData": "{\"hashIterations\":5,\"algorithm\":\"argon2\",\"additionalParameters\":{\"hashLength\":[\"32\"],\"memory\":[\"7168\"],\"type\":[\"id\"],\"version\":[\"1.3\"],\"parallelism\":[\"1\"]}}"
    }
  ],
```

3. Start Keycloak in development mode with import enabled:

```bash
cd ../keycloak-26.5.7/bin
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin123
./kc.sh start-dev --http-port=8080 --import-realm
```

3. Verify Keycloak is running:

- Admin console: `http://localhost:8080/admin`
- Realm issuer: `http://localhost:8080/realms/ec7205`

#### Connect local Keycloak to this project

Update [`02-configmap.yaml`](./02-configmap.yaml) for local use:

- `KEYCLOAK_SERVER_URL: "http://host.docker.internal:8080/"` for Docker Desktop Kubernetes on Windows
- or `KEYCLOAK_SERVER_URL: "http://localhost:8080/"` only if your workload can resolve the host loopback correctly
- `KEYCLOAK_ISSUER_URI: "http://host.docker.internal:8080/realms/ec7205"`
- `KEYCLOAK_TOKEN_URI: "http://host.docker.internal:8080/realms/ec7205/protocol/openid-connect/token"`
- `KEYCLOAK_REALM: "ec7205"`
- `KEYCLOAK_CLIENT_ID: "ec7205-client"`

Update `01-secrets.yaml` to match the imported realm:

- `KEYCLOAK_CLIENT_SECRET`
- `KEYCLOAK_CONFIG_NAME`
- `KEYCLOAK_CONFIG_PASSWORD`

The password used by `KEYCLOAK_CONFIG_PASSWORD` must match the imported user password in Keycloak. If you reset that user password in the admin console, update `01-secrets.yaml` to the same value before starting `auth-service` or `gateway-service`.

### Important Local Limitation

[`19-frontend-ticket-backendconfig.yaml`](./19-frontend-ticket-backendconfig.yaml) and [`30-ingress.yaml`](./30-ingress.yaml) are written for GCP GKE with GCE ingress. They are not portable as-is to a generic local cluster.

For local work, the reliable path is:

1. apply secrets
2. apply the manifests
3. reach services through `kubectl port-forward`

### Local Prerequisites

Before deploying locally, ensure you have the following installed:

- **Docker Desktop**: For running Kubernetes locally (or Minikube, kind).
- **Java 17**: Required for running Spring Boot services and Keycloak.
- **Node.js and npm**: For building and running the frontend applications (Angular 20).
- **MySQL**: Database server for the application.
- **MongoDB**: Database server for certain services.
- **MongoDB Compass**: GUI tool for managing MongoDB databases (optional but recommended).

### Local Steps

1. Start external dependencies first:

- MySQL
- MongoDB
- Keycloak `26.5.7`
- any required config repo access

2. Apply secrets:

```bash
kubectl apply -f 01-secrets.yaml
```

3. Deploy the stack using Kustomize:

```bash
kubectl apply -k .
```

4. Verify rollout:

```bash
kubectl get pods -n event-hub
kubectl get svc -n event-hub
kubectl get pvc -n event-hub
```

5. Port-forward the important services:

```bash
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

### External Keycloak on EC2 `t2.micro`

For this architecture, GKE runs the application workloads and Keycloak runs separately on an AWS EC2 instance. This is acceptable for a small demo or test environment, but `t2.micro` is only suitable for very light usage.

Use Keycloak version `26.5.7` here as well.

#### 1. Create the EC2 instance

Recommended minimum setup for the current project request:

- Instance type: `t2.micro`
- OS: Ubuntu 22.04 LTS or Amazon Linux 2023
- Storage: at least `15 GB`
- Open inbound ports:
  - `22` for SSH from your IP only
  - `8080` for Keycloak HTTP access from the internet or at least from your GKE egress ranges

You can create the instance from the AWS Console:

1. Open EC2 in AWS.
2. Launch instance.
3. Choose `t2.micro`.
4. Attach or create a key pair.
5. Configure the security group with `22` and `8080`.
6. Launch and note the public IP or DNS name.

#### 2. Install Keycloak 26.5.7 on EC2

SSH into the instance, then install Java 17 and Keycloak.

Example on Ubuntu:

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk unzip
cd /opt
sudo wget https://github.com/keycloak/keycloak/releases/download/26.5.7/keycloak-26.5.7.zip
sudo unzip keycloak-26.5.7.zip
sudo mv keycloak-26.5.7 keycloak
```

#### 3. Import `ec7205-realm.json`

Copy the realm file from this repo to the EC2 instance, for example:

```bash
scp ec7205-realm.json ubuntu@<EC2_PUBLIC_IP>:/tmp/ec7205-realm.json
```

**Note:** Before importing, update `ec7205-realm.json` with your specific user details (e.g., email, password) if needed.

Then on EC2:

```bash
sudo mkdir -p /opt/keycloak/data/import
sudo mv /tmp/ec7205-realm.json /opt/keycloak/data/import/ec7205-realm.json
cd /opt/keycloak/bin
export KEYCLOAK_ADMIN=admin
export KEYCLOAK_ADMIN_PASSWORD=admin123
./kc.sh start-dev --http-port=8080 --import-realm
```

After startup, verify:

- `http://<EC2_PUBLIC_IP>:8080/admin`
- `http://<EC2_PUBLIC_IP>:8080/realms/ec7205`

#### 4. Verify imported realm values

After importing [`keyclock/ec7205-realm.json`](./keyclock/ec7205-realm.json), confirm:

- Realm exists: `ec7205`
- Client exists: `ec7205-client`
- Roles exist: `admin`, `host`, `user`
  If needed, reset the imported user password in the admin console and keep the same value in `01-secrets.yaml`.

#### 5. Connect EC2 Keycloak to the GKE workloads

Update [`02-configmap.yaml`](./02-configmap.yaml) before deployment:

- `KEYCLOAK_SERVER_URL: "http://<EC2_PUBLIC_IP>:8080/"`
- `KEYCLOAK_ISSUER_URI: "http://<EC2_PUBLIC_IP>:8080/realms/ec7205"`
- `KEYCLOAK_TOKEN_URI: "http://<EC2_PUBLIC_IP>:8080/realms/ec7205/protocol/openid-connect/token"`
- `KEYCLOAK_REALM: "ec7205"`
- `KEYCLOAK_CLIENT_ID: "ec7205-client"`

Update [`01-secrets.yaml`](./01-secrets.yaml):

- `KEYCLOAK_CLIENT_SECRET`
- `KEYCLOAK_CONFIG_NAME`
- `KEYCLOAK_CONFIG_PASSWORD`

At that point:

- `auth-service` can authenticate against the imported Keycloak realm
- `gateway-service` and other JWT resource servers can validate issuer metadata from the EC2-hosted realm
- frontends can continue using the gateway without direct Keycloak browser integration

#### 6. Recommended production improvement

For anything beyond a demo, do not leave Keycloak on public HTTP port `8080`. Put it behind:

- a domain name
- HTTPS termination
- a stronger instance size than `t2.micro`
- persistent database-backed Keycloak storage
- tighter security-group rules

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

```bash
cd <path-to-k8s-directory>
terraform init
```

2. **Review the Terraform plan:**

```bash
terraform plan -out=tfplan
```

This shows all resources that will be created. Review for any unexpected changes.

3. **Apply the Terraform configuration:**

```bash
terraform apply tfplan
```

This provisions:

- VPC network and subnet
- GKE cluster
- Node pool with 2 e2-medium nodes

The provisioning typically takes 5-10 minutes.

4. **Get cluster credentials:**

Once the cluster is created, configure `kubectl` to access it:

```bash
gcloud container clusters get-credentials cluster-1-replicated --zone us-central1-a
```

5. **Verify cluster creation:**

```bash
kubectl cluster-info
kubectl get nodes
```

You should see 2 nodes in Ready state.

### Post-Provisioning

After the GKE cluster is successfully created and nodes are ready, proceed with **GKE Steps** below to deploy the Event Hub services.

### Cleaning Up Infrastructure

To remove the GKE cluster and all related infrastructure:

```bash
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

### GKE Steps

1. Create the GKE cluster.
2. Create and validate the external Keycloak EC2 instance.
3. Prepare `01-secrets.yaml`.
4. Update `02-configmap.yaml` with production endpoints, especially the Keycloak URLs pointing to EC2.
5. Apply secrets:

```bash
kubectl apply -f 01-secrets.yaml
```

6. Apply resources using Kustomize:

```bash
kubectl apply -k .
```

7. Verify:

```bash
kubectl get ingress -n event-hub
kubectl get pods -n event-hub
kubectl get svc -n event-hub
```

8. If you reserve a static global IP in GCP, uncomment this annotation in `30-ingress.yaml`:

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

```bash
cd <path-to-k8s-directory>
terraform init
```

2. **Review the Terraform plan:**

```bash
terraform plan -out=tfplan
```

This shows all resources that will be created. Review for any unexpected changes.

3. **Apply the Terraform configuration:**

```bash
terraform apply tfplan
```

This provisions:

- VPC network and subnet
- GKE cluster
- Node pool with 2 e2-medium nodes

The provisioning typically takes 5-10 minutes.

4. **Get cluster credentials:**

Once the cluster is created, configure `kubectl` to access it:

```bash
gcloud container clusters get-credentials cluster-1-replicated --zone us-central1-a
```

5. **Verify cluster creation:**

```bash
kubectl cluster-info
kubectl get nodes
```

You should see 2 nodes in Ready state.

### Post-Provisioning

After the GKE cluster is successfully created and nodes are ready, proceed with **GKE Steps** above to deploy the Event Hub services.

### Cleaning Up Infrastructure

To remove the GKE cluster and all related infrastructure:

```bash
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

## Health and Troubleshooting

Useful commands:

```bash
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
