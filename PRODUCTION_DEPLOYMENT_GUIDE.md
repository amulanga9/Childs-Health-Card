# 🚀 Production Deployment Guide

## Child's Health Card - Production-Ready Deployment

Этот документ содержит полное руководство по развертыванию приложения Child's Health Card в production среде.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Backend Deployment (FastAPI)](#backend-deployment-fastapi)
3. [Database Setup (PostgreSQL)](#database-setup-postgresql)
4. [File Storage (AWS S3)](#file-storage-aws-s3)
5. [Frontend Deployment (Flutter)](#frontend-deployment-flutter)
6. [Security Checklist](#security-checklist)
7. [Monitoring & Logging](#monitoring--logging)
8. [CI/CD Setup](#cicd-setup)
9. [Scaling Considerations](#scaling-considerations)

---

## Prerequisites

### Required Software

- **Python**: 3.11+ (для backend)
- **PostgreSQL**: 14+ (для основной БД)
- **Docker & Docker Compose**: Latest (recommended)
- **Flutter SDK**: 3.0+ (для мобильного приложения)
- **Nginx**: Latest (для reverse proxy)
- **Certbot**: Latest (для SSL certificates)

### Cloud Services

- **AWS Account** (для S3 file storage)
- **Domain Name** (для HTTPS)
- **Server** (VPS/Cloud: минимум 2GB RAM, 2 CPU cores)

---

## Backend Deployment (FastAPI)

### 1. Environment Variables

Создайте файл `.env` в корне backend директории:

```bash
# Database Configuration
DATABASE_URL=postgresql://user:password@localhost:5432/childs_health_card

# Security Keys
JWT_SECRET_KEY=<generate-random-256-bit-key>
API_KEY=<generate-random-api-key>

# IMPORTANT: JWT_SECRET_KEY и API_KEY ДОЛЖНЫ быть разными!
# Генерация ключей:
# python -c "import secrets; print(secrets.token_urlsafe(32))"

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
AWS_REGION=us-east-1
S3_BUCKET_NAME=childs-health-card-files

# Application Settings
APP_ENV=production
DEBUG=False
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Admin Settings
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=<bcrypt-hash-of-admin-password>
```

### 2. Docker Deployment (Recommended)

Создайте `backend/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Security: Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Run with Gunicorn for production
CMD ["gunicorn", "app.main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-"]
```

Создайте `docker-compose.yml`:

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: childs_health_backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    env_file:
      - ./backend/.env
    depends_on:
      - db
    networks:
      - app-network
    volumes:
      - ./backend/logs:/app/logs

  db:
    image: postgres:14-alpine
    container_name: childs_health_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: childs_health_user
      POSTGRES_PASSWORD: <strong-password>
      POSTGRES_DB: childs_health_card
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network
    ports:
      - "5432:5432"

  nginx:
    image: nginx:alpine
    container_name: childs_health_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### 3. Nginx Configuration

Создайте `nginx/nginx.conf`:

```nginx
upstream backend {
    server backend:8000;
}

server {
    listen 80;
    server_name api.yourdomain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req zone=api_limit burst=20 nodelay;

    # Client body size limit (for file uploads)
    client_max_body_size 100M;

    # Proxy settings
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint (no rate limiting)
    location /health {
        proxy_pass http://backend;
        limit_req off;
    }
}
```

### 4. Deploy Backend

```bash
# 1. Clone repository
git clone https://github.com/yourusername/Childs-Health-Card.git
cd Childs-Health-Card

# 2. Set up environment variables
cp backend/.env.example backend/.env
nano backend/.env  # Edit with your values

# 3. Generate secret keys
python3 -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_urlsafe(32))"
python3 -c "import secrets; print('API_KEY=' + secrets.token_urlsafe(32))"

# 4. Start services
docker-compose up -d

# 5. Run database migrations
docker-compose exec backend alembic upgrade head

# 6. Verify deployment
curl https://api.yourdomain.com/health
```

---

## Database Setup (PostgreSQL)

### 1. Initial Setup

```sql
-- Create database
CREATE DATABASE childs_health_card;

-- Create user
CREATE USER childs_health_user WITH PASSWORD '<strong-password>';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE childs_health_card TO childs_health_user;

-- Connect to database
\c childs_health_card

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### 2. Database Backup Strategy

Создайте скрипт автоматического backup `scripts/backup_db.sh`:

```bash
#!/bin/bash

# Configuration
DB_NAME="childs_health_card"
DB_USER="childs_health_user"
BACKUP_DIR="/backups/postgresql"
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

# Create backup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

pg_dump -U $DB_USER -d $DB_NAME | gzip > $BACKUP_FILE

# Remove old backups
find $BACKUP_DIR -name "${DB_NAME}_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $BACKUP_FILE"
```

Настройте cron для ежедневного backup:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/scripts/backup_db.sh
```

### 3. Database Indexes (Already Applied)

Все необходимые индексы уже созданы через Drift migrations (Flutter) и SQLAlchemy migrations (Backend).

---

## File Storage (AWS S3)

### 1. Create S3 Bucket

```bash
# Using AWS CLI
aws s3 mb s3://childs-health-card-files --region us-east-1

# Configure bucket policy (PRIVATE access only)
aws s3api put-bucket-encryption \
  --bucket childs-health-card-files \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. S3 Bucket Policy (CRITICAL SECURITY)

Создайте bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::childs-health-card-files/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalAccount": ["YOUR_AWS_ACCOUNT_ID"]
        }
      }
    }
  ]
}
```

### 3. IAM Policy for Application

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::childs-health-card-files/*"
    }
  ]
}
```

---

## Frontend Deployment (Flutter)

### 1. Build Release APK (Android)

```bash
# Navigate to Flutter project
cd flutter_app

# Build release APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release

# Output:
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/bundle/release/app-release.aab
```

### 2. Build iOS (if applicable)

```bash
# Build iOS
flutter build ios --release

# Archive for App Store
open ios/Runner.xcworkspace
# Then: Product -> Archive in Xcode
```

### 3. Environment Configuration

Создайте `lib/config/environment.dart`:

```dart
class Environment {
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.yourdomain.com',
  );
}
```

Build с production флагом:

```bash
flutter build apk --release --dart-define=PRODUCTION=true --dart-define=API_URL=https://api.yourdomain.com
```

### 4. Code Signing

#### Android

Создайте `android/key.properties`:

```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=upload
storeFile=/path/to/keystore.jks
```

**ВАЖНО**: Не коммитьте `key.properties` в git! Добавьте в `.gitignore`.

---

## Security Checklist

### ✅ Backend Security

- [ ] **JWT_SECRET_KEY** и **API_KEY** разные и случайные (256-bit)
- [ ] **HTTPS** везде (TLS 1.2+)
- [ ] **CORS** настроен только для нужных доменов
- [ ] **Rate Limiting** настроен (10 req/sec per IP)
- [ ] **SQL Injection** защита через ORM
- [ ] **XSS Protection** через Pydantic validation
- [ ] **CSRF Protection** (если есть web UI)
- [ ] **S3 Files** с приватным доступом (presigned URLs)
- [ ] **Password Hashing** через bcrypt/SHA-256
- [ ] **Environment Variables** не в git
- [ ] **Database Backups** настроены
- [ ] **Logging** без sensitive data

### ✅ Frontend Security

- [ ] **API Keys** не в коде (используйте secure storage)
- [ ] **PIN Code** хэшируется перед сохранением
- [ ] **Backup Files** шифруются AES-256
- [ ] **Test Data** только в debug режиме (`kDebugMode`)
- [ ] **SSL Pinning** для API запросов (опционально)
- [ ] **Code Obfuscation** в release build
- [ ] **Root Detection** (опционально)

### ✅ Infrastructure Security

- [ ] **Firewall** настроен (только 80, 443, 22 порты)
- [ ] **SSH Keys** вместо паролей
- [ ] **Automatic Updates** включены
- [ ] **Fail2Ban** установлен
- [ ] **Database** не доступна из интернета напрямую
- [ ] **Secrets** в environment variables, не в коде

---

## Monitoring & Logging

### 1. Application Logging

Backend уже использует Python `logging` модуль. Настройте log rotation:

Создайте `/etc/logrotate.d/childs-health`:

```
/path/to/backend/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    missingok
    create 0640 appuser appuser
}
```

### 2. Error Tracking

Рекомендуемые сервисы:
- **Sentry** (https://sentry.io) - error tracking
- **DataDog** (https://datadoghq.com) - APM
- **New Relic** (https://newrelic.com) - monitoring

Пример интеграции Sentry в FastAPI:

```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

sentry_sdk.init(
    dsn="https://your-sentry-dsn",
    environment="production",
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1,
)
```

### 3. Health Checks

Backend уже имеет `/health` endpoint. Настройте мониторинг:

```bash
# Простой health check скрипт
#!/bin/bash

URL="https://api.yourdomain.com/health"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $URL)

if [ $STATUS -ne 200 ]; then
    echo "Backend is DOWN! Status: $STATUS"
    # Send alert (email, Slack, PagerDuty)
fi
```

### 4. Database Monitoring

```sql
-- Slow query monitoring
ALTER DATABASE childs_health_card SET log_min_duration_statement = 1000;

-- Connection monitoring
SELECT count(*) FROM pg_stat_activity WHERE datname = 'childs_health_card';

-- Table size monitoring
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## CI/CD Setup

### GitHub Actions Example

Создайте `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt
          pip install pytest

      - name: Run tests
        run: |
          cd backend
          pytest

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v3

      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /path/to/Childs-Health-Card
            git pull origin main
            docker-compose down
            docker-compose up -d --build
            docker-compose exec -T backend alembic upgrade head
```

---

## Scaling Considerations

### Horizontal Scaling

Для масштабирования при росте нагрузки:

1. **Load Balancer**: Добавьте несколько backend инстансов за Nginx
2. **Database**: Используйте PostgreSQL replicas для read operations
3. **Redis**: Добавьте Redis для caching и sessions
4. **CDN**: Используйте CloudFlare для static files

### Vertical Scaling

Рекомендуемые характеристики сервера:

| Пользователи | CPU  | RAM  | Disk    |
|--------------|------|------|---------|
| < 1000       | 2    | 4GB  | 50GB    |
| 1000-10000   | 4    | 8GB  | 100GB   |
| 10000+       | 8+   | 16GB | 200GB+  |

---

## Production Checklist

### Pre-Deployment

- [ ] Все environment variables настроены
- [ ] SSL certificates получены (Let's Encrypt)
- [ ] Database создана и настроена
- [ ] S3 bucket создан с правильными permissions
- [ ] Backup стратегия настроена
- [ ] Firewall правила применены
- [ ] Security checklist пройден

### Post-Deployment

- [ ] Health checks работают
- [ ] Logs пишутся корректно
- [ ] Monitoring настроен
- [ ] Backup тестировались (restore test)
- [ ] Load testing проведен
- [ ] Security scan выполнен
- [ ] Documentation обновлена

---

## Support & Maintenance

### Regular Tasks

- **Daily**: Проверка logs на errors
- **Weekly**: Review security alerts
- **Monthly**: Database backup test restore
- **Quarterly**: Dependency updates
- **Annually**: SSL certificate renewal (if not auto)

### Emergency Contacts

- **DevOps Lead**: [contact]
- **Security Team**: [contact]
- **Database Admin**: [contact]

---

## Appendix: Useful Commands

```bash
# View backend logs
docker-compose logs -f backend

# Connect to PostgreSQL
docker-compose exec db psql -U childs_health_user -d childs_health_card

# Restart services
docker-compose restart

# Check disk usage
df -h

# Check memory usage
free -h

# Check active connections
docker-compose exec db psql -U childs_health_user -d childs_health_card -c "SELECT count(*) FROM pg_stat_activity;"

# Create database backup manually
docker-compose exec db pg_dump -U childs_health_user childs_health_card > backup_$(date +%Y%m%d).sql

# Restore from backup
docker-compose exec -T db psql -U childs_health_user childs_health_card < backup_20241119.sql
```

---

## 📞 Additional Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **Flutter Deployment**: https://docs.flutter.dev/deployment
- **PostgreSQL Best Practices**: https://wiki.postgresql.org/wiki/Don%27t_Do_This
- **AWS S3 Security**: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html
- **OWASP Top 10**: https://owasp.org/www-project-top-ten/

---

**Last Updated**: 2024-11-19
**Version**: 1.0
**Maintained by**: Development Team

