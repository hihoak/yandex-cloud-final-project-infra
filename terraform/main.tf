locals {
  zone_name = "ru-central1-a"
  folder_id = "b1g1vop54jjodv1ri5uc"
  momo_store_bucket_name = "artemmihaylov-momo-store-bucket"
  terraform_state_bucket_name = "artemmihaylov-terraform-state-bucket"
}

terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.106.0"
    }
  }

  # Описание бэкенда хранения состояния
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "artemmihaylov-terraform-state-bucket"
    region     = "ru-central1"
    key        = "terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  cloud_id  = "b1g7bm2asim62tdmd5j6"
  folder_id = local.folder_id
  zone      = local.zone_name
}

// Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = local.folder_id
  name      = "tf-final-project-sa"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// Use keys to create bucket
resource "yandex_storage_bucket" "momo_store_yandex_storage_bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = local.momo_store_bucket_name
}


// NEXUS
data "yandex_vpc_subnet" "default-ru-central1-a" {
  subnet_id = "e9bdeqtt8m8d5li6nr90"
}

resource "yandex_compute_disk" "infra_compute_disk" {
  name     = "infra-compute-disk"
  type     = "network-ssd"
  zone     = local.zone_name
  image_id = "fd8bh0c781u19q50m4kj"
}

resource "yandex_compute_instance" "default" {
  name        = "infra"
  platform_id = "standard-v1"
  zone        = local.zone_name

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.infra_compute_disk.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.default-ru-central1-a.id
    nat = true
  }

  metadata = {
    user-data = "${file("scripts/add-ssh.yaml")}"
  }
}

// K8S

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-admin" {
  folder_id = local.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

data "yandex_vpc_network" "k8s-network" {
  network_id = "enph74p7qmp88s0scagl"
}

data "yandex_vpc_security_group" "k8s-security-group" {
  security_group_id        = "enp9k2d9f8q38n3416rh"
}

resource "yandex_logging_group" "k8s-logging-group" {
  name      = "momo-store-k8s-logging-group"
  folder_id = local.folder_id
}

resource "yandex_kubernetes_cluster" "final_project_k8s_cluster" {
  name        = "momo-store-k8s-cluster"
  description = "k8s cluster for momo store"

  network_id = data.yandex_vpc_network.k8s-network.id

  master {
    version = "1.28"
    zonal {
      zone      = local.zone_name
      subnet_id = data.yandex_vpc_subnet.default-ru-central1-a.id
    }

    public_ip = true

    security_group_ids = [data.yandex_vpc_security_group.k8s-security-group.id]

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        start_time = "00:00"
        duration   = "3h"
      }
    }
    
    master_logging {
      enabled = true
      log_group_id = yandex_logging_group.k8s-logging-group.id
      kube_apiserver_enabled = true
      cluster_autoscaler_enabled = true
      events_enabled = true
      audit_enabled = true
    }
  }

  service_account_id      = yandex_iam_service_account.sa.id
  node_service_account_id = yandex_iam_service_account.sa.id

  release_channel = "RAPID"
  network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "momo-store-k8s-node-group" {
  cluster_id  = "${yandex_kubernetes_cluster.final_project_k8s_cluster.id}"
  name        = "momo-store-k8s-node-group"
  description = "node group for momo store k8s"
  version     = "1.28"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat                = true
      subnet_ids         = [data.yandex_vpc_subnet.default-ru-central1-a.id]
    }

    resources {
      memory = 6
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = local.zone_name
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true

    maintenance_window {
      day        = "monday"
      start_time = "00:00"
      duration   = "3h"
    }

    maintenance_window {
      day        = "friday"
      start_time = "00:00"
      duration   = "4h30m"
    }
  }
}

### grant permissions for service account for ingress controller

resource "yandex_resourcemanager_folder_iam_member" "sa-alb-editor" {
  folder_id = local.folder_id
  role      = "alb.editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-vpc-publicAdmin" {
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-certificate-manager-certificates-downloader" {
  folder_id = local.folder_id
  role      = "certificate-manager.certificates.downloader"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-compute-viewer" {
  folder_id = local.folder_id
  role      = "compute.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

resource "yandex_iam_service_account_key" "sa-auth-key" {
  service_account_id = yandex_iam_service_account.sa.id
}
