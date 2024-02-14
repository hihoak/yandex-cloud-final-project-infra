// Используем файловый бэкенд для хранения секретов
storage "file" {
  path    = "/vault/file"
}

// Для учебных целей запустим сервер на HTTP
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 0
  tls_cert_file = "/vault/certs/fullchain.pem"
  tls_key_file = "/vault/certs/privkey.pem"
}


disable_mlock = true

api_addr = "https://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"

// Включим пользовательский Web-интерфейс
ui = true