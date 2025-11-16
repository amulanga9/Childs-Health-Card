# Деплой в Yandex Cloud

Полное руководство по развёртыванию Child's Health Card API в Yandex Cloud.

## Содержание

1. [Подготовка](#подготовка)
2. [Создание Object Storage](#создание-object-storage)
3. [Создание PostgreSQL](#создание-postgresql)
4. [Деплой приложения](#деплой-приложения)
5. [Настройка домена и SSL](#настройка-домена-и-ssl)
6. [Мониторинг](#мониторинг)

---

## Подготовка

### 1. Установка Yandex Cloud CLI

```bash
# macOS / Linux
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

# Перезагрузите shell
exec -l $SHELL

# Инициализация
yc init
```

### 2. Создание платёжного аккаунта

1. Зайдите в [Консоль Yandex Cloud](https://console.cloud.yandex.ru/)
2. Создайте новый платёжный аккаунт
3. Активируйте пробный период (грант 4000₽)

### 3. Создание каталога (folder)

```bash
# Создание каталога
yc resource-manager folder create --name childs-health-prod

# Получение ID каталога
yc resource-manager folder list
```

Сохраните `FOLDER_ID` - он понадобится далее.

---

## Создание Object Storage

### 1. Создание бакета

```bash
# Установка переменных
export FOLDER_ID=<ваш-folder-id>
export BUCKET_NAME=childs-health-files

# Создание бакета через консоль
# https://console.cloud.yandex.ru/folders/<FOLDER_ID>/storage
```

**В веб-консоли:**
1. Перейдите в **Object Storage**
2. Нажмите **Создать бакет**
3. Имя: `childs-health-files`
4. Класс хранилища: **Стандартное**
5. Публичный доступ: **Ограниченный** (настроим позже)
6. Нажмите **Создать**

### 2. Создание сервисного аккаунта

```bash
# Создание сервисного аккаунта
yc iam service-account create --name childs-health-sa \
  --folder-id $FOLDER_ID

# Получение ID сервисного аккаунта
SA_ID=$(yc iam service-account get childs-health-sa \
  --folder-id $FOLDER_ID \
  --format json | jq -r .id)

# Назначение роли storage.admin
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role storage.admin \
  --subject serviceAccount:$SA_ID
```

### 3. Создание статических ключей доступа

```bash
# Создание статического ключа
yc iam access-key create --service-account-name childs-health-sa \
  --folder-id $FOLDER_ID

# Сохраните вывод:
# access_key:
#   id: <KEY_ID>
#   key_id: <ACCESS_KEY_ID>      # ← Это YC_STORAGE_ACCESS_KEY
# secret: <SECRET_ACCESS_KEY>    # ← Это YC_STORAGE_SECRET_KEY
```

**Сохраните эти ключи** - они не будут показаны повторно!

### 4. Настройка CORS для бакета

Создайте файл `cors.json`:

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

Применить конфигурацию:

```bash
aws s3api put-bucket-cors \
  --bucket $BUCKET_NAME \
  --cors-configuration file://cors.json \
  --endpoint-url https://storage.yandexcloud.net
```

---

## Создание PostgreSQL

### Вариант 1: Managed PostgreSQL (рекомендуется)

```bash
# Создание кластера PostgreSQL
yc managed-postgresql cluster create \
  --name childs-health-db \
  --environment production \
  --network-name default \
  --host zone-id=ru-central1-a,subnet-name=default-ru-central1-a \
  --postgresql-version 15 \
  --resource-preset s2.micro \
  --disk-type network-hdd \
  --disk-size 10 \
  --user name=childs_health,password=<STRONG_PASSWORD> \
  --database name=childs_health_db,owner=childs_health \
  --folder-id $FOLDER_ID

# Получение адреса подключения
yc managed-postgresql cluster list-hosts childs-health-db \
  --folder-id $FOLDER_ID
```

**URL подключения:**
```
postgresql://childs_health:<PASSWORD>@<HOST>:6432/childs_health_db
```

### Вариант 2: PostgreSQL в Compute Cloud

Если нужна экономия, можно развернуть PostgreSQL на виртуальной машине.

---

## Деплой приложения

### Способ 1: Container Registry + Compute Instance

#### 1. Создание Container Registry

```bash
# Создание реестра
yc container registry create --name childs-health-registry \
  --folder-id $FOLDER_ID

# Получение ID реестра
REGISTRY_ID=$(yc container registry get childs-health-registry \
  --folder-id $FOLDER_ID \
  --format json | jq -r .id)

# Настройка Docker для работы с реестром
yc container registry configure-docker
```

#### 2. Сборка и push образа

```bash
# Переход в директорию backend
cd backend

# Сборка образа
docker build -t cr.yandex/$REGISTRY_ID/childs-health-api:latest .

# Push в реестр
docker push cr.yandex/$REGISTRY_ID/childs-health-api:latest
```

#### 3. Создание виртуальной машины

```bash
# Создание VM
yc compute instance create \
  --name childs-health-api-vm \
  --zone ru-central1-a \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2004-lts,size=20 \
  --cores 2 \
  --memory 2 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --folder-id $FOLDER_ID

# Получение внешнего IP
VM_IP=$(yc compute instance get childs-health-api-vm \
  --folder-id $FOLDER_ID \
  --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

echo "VM IP: $VM_IP"
```

#### 4. Подключение и настройка VM

```bash
# Подключение к VM
ssh ubuntu@$VM_IP

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Перелогинтесь
exit
ssh ubuntu@$VM_IP

# Настройка Docker для работы с реестром
sudo mkdir -p /root/.docker
sudo yc container registry configure-docker
```

#### 5. Создание .env файла на VM

```bash
# Создайте файл .env
cat > .env << EOF
DATABASE_URL=postgresql://childs_health:<PASSWORD>@<DB_HOST>:6432/childs_health_db
YC_STORAGE_ACCESS_KEY=<YOUR_ACCESS_KEY>
YC_STORAGE_SECRET_KEY=<YOUR_SECRET_KEY>
YC_STORAGE_BUCKET_NAME=childs-health-files
YC_STORAGE_ENDPOINT=https://storage.yandexcloud.net
YC_STORAGE_REGION=ru-central1
JWT_SECRET_KEY=<GENERATE_STRONG_SECRET>
QR_TOKEN_EXPIRE_HOURS=48
API_HOST=0.0.0.0
API_PORT=8000
CORS_ORIGINS=https://yourdomain.com
DEBUG=False
EOF
```

#### 6. Запуск контейнера

```bash
# Pull образа
docker pull cr.yandex/$REGISTRY_ID/childs-health-api:latest

# Запуск контейнера
docker run -d \
  --name childs-health-api \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file .env \
  cr.yandex/$REGISTRY_ID/childs-health-api:latest

# Проверка логов
docker logs -f childs-health-api
```

#### 7. Настройка systemd для автозапуска

```bash
# Создание systemd unit
sudo tee /etc/systemd/system/childs-health-api.service > /dev/null << EOF
[Unit]
Description=Child's Health Card API
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop childs-health-api
ExecStartPre=-/usr/bin/docker rm childs-health-api
ExecStart=/usr/bin/docker run --rm --name childs-health-api \
  -p 8000:8000 \
  --env-file /home/ubuntu/.env \
  cr.yandex/$REGISTRY_ID/childs-health-api:latest

[Install]
WantedBy=multi-user.target
EOF

# Включение и запуск
sudo systemctl enable childs-health-api
sudo systemctl start childs-health-api
sudo systemctl status childs-health-api
```

### Способ 2: Serverless Containers (альтернатива)

```bash
# Создание Serverless Container
yc serverless container create --name childs-health-api \
  --folder-id $FOLDER_ID

# Деплой ревизии
yc serverless container revision deploy \
  --container-name childs-health-api \
  --image cr.yandex/$REGISTRY_ID/childs-health-api:latest \
  --cores 1 \
  --memory 1GB \
  --execution-timeout 30s \
  --service-account-id $SA_ID \
  --environment DATABASE_URL="postgresql://..." \
  --environment YC_STORAGE_ACCESS_KEY="..." \
  --folder-id $FOLDER_ID
```

---

## Настройка домена и SSL

### 1. Создание Application Load Balancer (опционально)

Для продакшена рекомендуется использовать ALB.

```bash
# Создание целевой группы
yc alb target-group create childs-health-tg \
  --target subnet-name=default-ru-central1-a,ip-address=$VM_INTERNAL_IP

# Создание backend group
yc alb backend-group create childs-health-bg \
  --http-backend name=childs-health-backend,target-group-id=<TG_ID>,port=8000

# Создание HTTP router
yc alb http-router create childs-health-router

# Создание Load Balancer
yc alb load-balancer create childs-health-alb \
  --network-name default \
  --listener name=http-listener,external-ipv4-endpoint=port=80,http-router-id=<ROUTER_ID>
```

### 2. Настройка SSL сертификата

```bash
# Запрос сертификата Let's Encrypt
yc certificate-manager certificate request \
  --name childs-health-cert \
  --domains api.yourdomain.com

# Следуйте инструкциям для DNS валидации
```

### 3. Nginx как reverse proxy (простой вариант)

На VM:

```bash
# Установка Nginx
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Настройка Nginx
sudo tee /etc/nginx/sites-available/childs-health-api << EOF
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Активация конфигурации
sudo ln -s /etc/nginx/sites-available/childs-health-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Получение SSL сертификата
sudo certbot --nginx -d api.yourdomain.com
```

---

## Мониторинг

### 1. Настройка логирования

```bash
# Просмотр логов контейнера
docker logs -f childs-health-api

# Настройка ротации логов
sudo tee /etc/logrotate.d/childs-health-api << EOF
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  size 10M
  missingok
  delaycompress
  copytruncate
}
EOF
```

### 2. Мониторинг метрик

Используйте Yandex Monitoring:

1. Перейдите в [Yandex Monitoring](https://console.cloud.yandex.ru/monitoring)
2. Создайте дашборд
3. Добавьте виджеты для:
   - CPU VM
   - Memory VM
   - Disk I/O
   - Network traffic
   - Database connections

### 3. Healthcheck

```bash
# Создание скрипта мониторинга
cat > /home/ubuntu/healthcheck.sh << 'EOF'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ $response != "200" ]; then
  echo "API не отвечает! Код: $response"
  docker restart childs-health-api
fi
EOF

chmod +x /home/ubuntu/healthcheck.sh

# Добавление в crontab (каждые 5 минут)
crontab -l | { cat; echo "*/5 * * * * /home/ubuntu/healthcheck.sh"; } | crontab -
```

---

## Обновление приложения

```bash
# На локальной машине
cd backend
docker build -t cr.yandex/$REGISTRY_ID/childs-health-api:latest .
docker push cr.yandex/$REGISTRY_ID/childs-health-api:latest

# На VM
docker pull cr.yandex/$REGISTRY_ID/childs-health-api:latest
docker restart childs-health-api

# Или через systemd
sudo systemctl restart childs-health-api
```

---

## Резервное копирование

### PostgreSQL

```bash
# Создание бэкапа
yc managed-postgresql cluster backup childs-health-db

# Расписание автоматических бэкапов
yc managed-postgresql cluster update childs-health-db \
  --backup-window-start '02:00:00' \
  --backup-retain-period-days 7
```

### Object Storage

Версионирование бакета:

```bash
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled \
  --endpoint-url https://storage.yandexcloud.net
```

---

## Оценка стоимости (примерная)

**Минимальная конфигурация:**

| Сервис | Конфигурация | Стоимость/мес |
|--------|-------------|---------------|
| Compute (VM) | 2 vCPU, 2GB RAM | ~600₽ |
| PostgreSQL | s2.micro, 10GB HDD | ~1200₽ |
| Object Storage | 10GB хранилище + трафик | ~30₽ |
| **ИТОГО** | | **~1830₽/мес** |

**Оптимизированная конфигурация:**

| Сервис | Конфигурация | Стоимость/мес |
|--------|-------------|---------------|
| Serverless Container | 1GB RAM, ~1000 req/day | ~100₽ |
| PostgreSQL | s2.micro, 10GB HDD | ~1200₽ |
| Object Storage | 10GB + трафик | ~30₽ |
| **ИТОГО** | | **~1330₽/мес** |

---

## Полезные команды

```bash
# Просмотр всех ресурсов
yc resource-manager folder list-operations --folder-id $FOLDER_ID

# Удаление всех ресурсов (осторожно!)
yc compute instance delete childs-health-api-vm --folder-id $FOLDER_ID
yc managed-postgresql cluster delete childs-health-db --folder-id $FOLDER_ID
yc container registry delete childs-health-registry --folder-id $FOLDER_ID

# Мониторинг расходов
yc billing billing-account list
```

---

## Troubleshooting

### Проблема: Контейнер не запускается

```bash
# Проверка логов
docker logs childs-health-api

# Запуск в интерактивном режиме
docker run -it --rm --env-file .env \
  cr.yandex/$REGISTRY_ID/childs-health-api:latest /bin/bash
```

### Проблема: Не работает доступ к Object Storage

```bash
# Проверка ключей
aws s3 ls s3://$BUCKET_NAME --endpoint-url https://storage.yandexcloud.net

# Проверка прав сервисного аккаунта
yc iam service-account list-access-bindings childs-health-sa
```

### Проблема: Не подключается к PostgreSQL

```bash
# Проверка подключения
psql "postgresql://childs_health:<PASSWORD>@<HOST>:6432/childs_health_db"

# Проверка сети
telnet <DB_HOST> 6432
```

---

## Безопасность

1. **Изменить все пароли** из примеров
2. **Ограничить доступ к VM** через Security Groups
3. **Включить 2FA** в Yandex Cloud
4. **Регулярно обновлять** образы и зависимости
5. **Настроить мониторинг** доступа к QR токенам
6. **Включить аудит логи** в PostgreSQL

---

## Контакты для поддержки

- Документация Yandex Cloud: https://cloud.yandex.ru/docs
- Поддержка: https://console.cloud.yandex.ru/support
- Форум: https://cloud.yandex.ru/forum

---

Развёртывание завершено! API доступен по адресу: `https://api.yourdomain.com`
