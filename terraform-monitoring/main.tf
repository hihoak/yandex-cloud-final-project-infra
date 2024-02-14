
locals {
  zone_name = "ru-central1-a"
  folder_id = "b1g1vop54jjodv1ri5uc"
  momo_store_bucket_name = "artemmihaylov-momo-store-bucket"
  terraform_state_bucket_name = "artemmihaylov-terraform-state-bucket"
}

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.12.1"
    }
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.106.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
  }

  # Описание бэкенда хранения состояния
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "artemmihaylov-terraform-state-bucket"
    region     = "ru-central1"
    key        = "terraform.tfstate-monitoring"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  cloud_id  = "b1g7bm2asim62tdmd5j6"
  folder_id = local.folder_id
  zone      = local.zone_name
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "yc-momo-store-k8s-cluster"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "yc-momo-store-k8s-cluster"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  create_namespace = true
  namespace = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  atomic = true
  max_history = 3
  cleanup_on_fail = true
  set {
    name  = "server.service.type"
    value = "NodePort"
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  create_namespace = true
  namespace = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  atomic = true
  max_history = 3
  cleanup_on_fail = true
  set {
    name  = "service.type"
    value = "NodePort"
  }
}

resource "helm_release" "loki" {
  name       = "loki"
  create_namespace = true
  namespace = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  atomic = true
  max_history = 3
  cleanup_on_fail = true
  set {
    name  = "loki.commonConfig.replication_factor"
    value = 1
  }
  set {
    name  = "loki.commonConfig.storage.type"
    value = "filesystem"
  }
  set {
    name  = "singleBinary.replicas"
    value = 1
  }
}

data "yandex_cm_certificate" "momo-store-cert" {
  folder_id = local.folder_id
  description = "manualy created earlier"
  name      = "momo-store-cert"
}

data "yandex_vpc_subnet" "default-ru-central1-a" {
  subnet_id = "e9bdeqtt8m8d5li6nr90"
}

data "yandex_vpc_security_group" "k8s-security-group" {
  security_group_id        = "enp9k2d9f8q38n3416rh"
}

resource "kubernetes_ingress_v1" "prometheus-ingress" {
  metadata {
    name = "alb-prometheus-tls"
    namespace = "monitoring"
    annotations = {
      "ingress.alb.yc.io/subnets" = data.yandex_vpc_subnet.default-ru-central1-a.id
      "ingress.alb.yc.io/security-groups" = data.yandex_vpc_security_group.k8s-security-group.id
      "ingress.alb.yc.io/external-ipv4-address" = "auto"
      "ingress.alb.yc.io/group-name" = "momo-store-alb-group"
    }
  }
  
  spec {
    tls {
        hosts = ["infra-prometheus.momo-store.artem-mihaylov.ru", "infra-grafana.momo-store.artem-mihaylov.ru"]
        secret_name = "yc-certmgr-cert-id-${data.yandex_cm_certificate.momo-store-cert.id}"
    }

  rule {
      host = "infra-prometheus.momo-store.artem-mihaylov.ru"
      http {
        path {
          backend {
            service {
              name = "prometheus-server"
              port {
                number = 80
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
    }
  }
  rule {
      host = "infra-grafana.momo-store.artem-mihaylov.ru"
      http {
        path {
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
          path = "/"
          path_type = "Prefix"
        }
    }
  }
}
}

