## Репозиторий с кодом инфрастуктуры

Описание каждой папки и что в ней разворачивается в порядке необходимого выполнения

1) terraform - разворачивает основную инфраструктуру проекта
- виртуалку для инфрастурктуры (Nexus и Vault они наливаются позже ansible)
- k8s кластер с одной нодой
2) ansible - наливает Vault и Nexus на виртуалку из п.1
3) scripts - ручные скрипты. В скрипте `create_ingress_controller.sh` деплоится `ingress-controller`
4) terraform-ingress - разворачивет ingress по которому доступен сайт с пельмешками
5) terraform-gitlab - добавляет сервисную учетку `helm` с правами `admin` и разворачивает `gitlab runner`
6) terraform-monitoring - разворачивает `prometheus`, `grafana` и `loki`. Так же разворачивает для них `ingress` по которому они становятся доступны во внешней сети

## Как развернуть инфраструктуру?

1) выполняет terraform из папки `terraform`
2) наливаем Nexus и Vaule ансиблом из папки `ansible`
3) В ручную создаем gitlab в yandex cloud консоли (я не нашел способа через terraform)
4) выполняем terraform по подготовке gitlab в папке `terraform-gitlab`
5) В ручную создаем сертификат с именем `momo-store-cert` в yandex cloud console
6) деплоим `ingress-controller` выполняя скрипт `create_ingress_controller.sh` из папки `scripts`
7) выполняем terraform в папке `terraform-ingress` деплоя ingress для пельменной
8) выполняем terraform в папке `terraform-monitoring` деплоя инфраструктуру для мониторинга

## Основное приложение развертывается в другом репозитории

## Полезные ссылки

1) Grafana - https://infra-grafana.momo-store.artem-mihaylov.ru/
2) Prometheus - https://infra-prometheus.momo-store.artem-mihaylov.ru/
3) Nexus - https://infra.momo-store.artem-mihaylov.ru
4) Vault - https://infra.momo-store.artem-mihaylov.ru:8200
5) Gitlab - https://artemmihaylov.gitlab.yandexcloud.net/
