#!/bin/bash

yc iam key create \
  --service-account-name tf-final-project-sa \
  --output sa-key.json

export HELM_EXPERIMENTAL_OCI=1 && \
    cat sa-key.json | helm registry login cr.yandex --username 'json_key' --password-stdin && \
    helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/yc-alb-ingress/yc-alb-ingress-controller-chart \
    --version v0.1.24 \
    --untar && \
    helm install \
    --namespace momo-store \
    --create-namespace \
    --set folderId=b1g1vop54jjodv1ri5uc \
    --set clusterId=catm86lcfq5medmme30i \
    --set-file saKeySecretKey=sa-key.json \
    yc-alb-ingress-controller ./yc-alb-ingress-controller-chart/