
############ SETUP Gitlab
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.12.1"
    }
  }

  # Описание бэкенда хранения состояния
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "artemmihaylov-terraform-state-bucket"
    region     = "ru-central1"
    key        = "terraform.tfstate-gitlab"

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "yc-momo-store-k8s-cluster"
}

## prepare service account to CI/CD

resource "kubernetes_secret" "helm-sa" {
  metadata {
    name = "helm-sa"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = "helm-sa"
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_service_account" "helm-sa" {
  metadata {
    name = "helm-sa"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "helm-sa" {
  metadata {
    name = "helm-sa"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "helm-sa"
    namespace = "kube-system"
  }
}

###

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "yc-momo-store-k8s-cluster"
  }
}

variable "gitlab_url" {
  type = string
  description = "URL to Gitlab instance in format ('https://artemmihaylov.gitlab.yandexcloud.net')"
  default = "https://artemmihaylov.gitlab.yandexcloud.net"
}

variable "runner_token" {
  type = string
  description = "runner token which you need to create in admin space of gitlab"
}

resource "helm_release" "gitlab_runner" {
  name       = "gitlab-runner"
  create_namespace = true
  namespace = "gitlab-runners"
  repository = "https://charts.gitlab.io"
  chart      = "gitlab-runner"
  atomic = true
  max_history = 3
  cleanup_on_fail = true
  set {
    name  = "gitlabUrl"
    value = var.gitlab_url
  }

  set {
    name  = "rbac.create"
    value = true
  }

  set {
    name  = "runnerToken"
    value = var.runner_token
  }
}
