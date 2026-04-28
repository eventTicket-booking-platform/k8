# Network configuration for VPC-native GKE
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/16"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# GKE Cluster Control Plane
resource "google_container_cluster" "primary" {
  name     = "cluster-1-replicated"
  location = "us-central1-a"

  # Networking
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id
  
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Separation of cluster and node pool management
  remove_default_node_pool = true
  initial_node_count       = 1

  # Feature parity with cluster-1
  release_channel {
    channel = "REGULAR"
  }

  enable_shielded_nodes = true

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS", 
      "STORAGE", 
      "POD", 
      "DEPLOYMENT", 
      "STATEFULSET", 
      "DAEMONSET", 
      "HPA", 
      "JOBSET", 
      "CADVISOR", 
      "KUBELET"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # Set to false for easier cleanup in test environments
  deletion_protection = false
}

# GKE Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "default-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-medium"
    image_type   = "COS_CONTAINERD"
    disk_type    = "pd-balanced"
    disk_size_gb = 15

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Recommended best-practice scope for GKE nodes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}
