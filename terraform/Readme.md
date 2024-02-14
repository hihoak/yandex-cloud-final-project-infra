### Работа с terraform

здесь используется описание и создание сущностей в yandex-cloud

спецификацию какие сущности и какие есть настройки можно посмотреть здесь https://terraform-provider.yandexcloud.net/

## Как запускать?

1) сначала объявите 3 переменные среды

```
export YC_TOKEN=<токен для yandex-cloud> # yc iam create-token
export AWS_ACCESS_KEY_ID=<идентификатор статического ключа> # можно найти в vaule
export AWS_SECRET_ACCESS_KEY=<секретный ключ> 
```

2) 