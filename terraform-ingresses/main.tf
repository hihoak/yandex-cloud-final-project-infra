locals {
  zone_name = "ru-central1-a"
  folder_id = "b1g1vop54jjodv1ri5uc"
  momo_store_bucket_name = "artemmihaylov-momo-store-bucket"
  terraform_state_bucket_name = "artemmihaylov-terraform-state-bucket"
}

############ SETUP Gitlab
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
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
    key        = "terraform.tfstate-terraform-1"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "yc-momo-store-k8s-cluster"
}

provider "yandex" {
  cloud_id  = "b1g7bm2asim62tdmd5j6"
  folder_id = local.folder_id
  zone      = local.zone_name
}

data "yandex_vpc_subnet" "default-ru-central1-a" {
  subnet_id = "e9bdeqtt8m8d5li6nr90"
}

data "yandex_vpc_security_group" "k8s-security-group" {
  security_group_id        = "enp9k2d9f8q38n3416rh"
}

data "yandex_cm_certificate" "momo-store-cert" {
  folder_id = local.folder_id
  description = "manualy created earlier"
  name      = "momo-store-cert"
}

resource "kubernetes_ingress_v1" "momo-store-ingress" {
  metadata {
    name = "alb-momo-store-tls"
    namespace = "momo-store"
    annotations = {
      "ingress.alb.yc.io/subnets" = data.yandex_vpc_subnet.default-ru-central1-a.id
      "ingress.alb.yc.io/security-groups" = data.yandex_vpc_security_group.k8s-security-group.id
      "ingress.alb.yc.io/external-ipv4-address" = "auto"
      "ingress.alb.yc.io/group-name" = "momo-store-alb-group"
    }
  }
  
  spec {
    tls {
        hosts = ["momo-store.artem-mihaylov.ru", "api.momo-store.artem-mihaylov.ru"]
        secret_name = "yc-certmgr-cert-id-${data.yandex_cm_certificate.momo-store-cert.id}"
    }

  rule {
      host = "momo-store.artem-mihaylov.ru"
      http {
        path {
          backend {
            service {
              name = "frontend"
              port {
                number = 8080
              }
            }
          }
          path = "/momo-store"
          path_type = "Prefix"
        }
    }
  }
  rule {
      host = "api.momo-store.artem-mihaylov.ru"
      http {
        path {
          backend {
            service {
              name = "backend"
              port {
                number = 8081
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
