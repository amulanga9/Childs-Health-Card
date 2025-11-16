# Production Deployment Guide

**Complete step-by-step guide for deploying Child's Health Card to production**

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Security Configuration](#security-configuration)
3. [Backend Deployment (Yandex Cloud)](#backend-deployment-yandex-cloud)
4. [Database Setup (PostgreSQL)](#database-setup-postgresql)
5. [Object Storage Setup](#object-storage-setup)
6. [Flutter App Build](#flutter-app-build)
7. [SSL/TLS Setup](#ssltls-setup)
8. [Monitoring & Logging](#monitoring--logging)
9. [Backup Strategy](#backup-strategy)
10. [Scaling](#scaling)
11. [Testing Checklist](#testing-checklist)
12. [Rollback Plan](#rollback-plan)

---

## Prerequisites

### Required Tools
- [ ] Docker & Docker Compose (latest)
- [ ] Yandex Cloud CLI (`yc`)
- [ ] PostgreSQL client (`psql`)
- [ ] Flutter SDK (3.0+)
- [ ] Git
- [ ] OpenSSL

### Required Accounts
- [ ] Yandex Cloud account with billing enabled
- [ ] Domain name registered (for SSL)
- [ ] Cloud Object Storage bucket created

---

## Security Configuration

### 1. Generate Secure Passwords

```bash
# PostgreSQL password
POSTGRES_PASSWORD=$(openssl rand -base64 32)
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"

# JWT Secret Key
JWT_SECRET_KEY=$(openssl rand -base64 32)
echo "JWT_SECRET_KEY=$JWT_SECRET_KEY"

# API Key for Flutter app
API_KEY=$(openssl rand -base64 32)
echo "API_KEY=$API_KEY"
```

**⚠️ CRITICAL**: Save these values securely! You'll need them for configuration.

### 2. Create Backend .env File

```bash
cd backend
cp .env.example .env
nano .env
```

Update with your generated values:

```env
# PostgreSQL Database
POSTGRES_USER=childs_health
POSTGRES_PASSWORD=<your_generated_password>
POSTGRES_DB=childs_health_db

# Database URL
DATABASE_URL=postgresql://childs_health:<your_generated_password>@postgres:5432/childs_health_db

# Yandex Object Storage
YC_STORAGE_ACCESS_KEY=<from_yandex_console>
YC_STORAGE_SECRET_KEY=<from_yandex_console>
YC_STORAGE_BUCKET_NAME=childs-health-prod
YC_STORAGE_ENDPOINT=https://storage.yandexcloud.net
YC_STORAGE_REGION=ru-central1

# JWT Secret
JWT_SECRET_KEY=<your_generated_jwt_secret>
JWT_ALGORITHM=HS256

# QR Token Settings
QR_TOKEN_EXPIRE_HOURS=48

# API Settings
API_HOST=0.0.0.0
API_PORT=8000
CORS_ORIGINS=https://yourdomain.com

# Application
APP_NAME=Child's Health Card API
APP_VERSION=1.0.0
DEBUG=False  # IMPORTANT: Must be False in production
```

### 3. Verify Configuration

```bash
# Backend startup will validate all critical environment variables
docker-compose up -d
docker-compose logs api

# Look for:
# ✅ No configuration warnings
# ❌ If you see warnings, fix them before proceeding
```

---

## Backend Deployment (Yandex Cloud)

### Option 1: Yandex Compute Cloud (VM)

#### 1. Create VM Instance

```bash
# Login to Yandex Cloud
yc init

# Create VM
yc compute instance create \
  --name childs-health-api \
  --zone ru-central1-a \
  --network-interface subnet-name=default,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-22-04-lts,size=30 \
  --cores 2 \
  --memory 4 \
  --ssh-key ~/.ssh/id_rsa.pub

# Get VM IP
VM_IP=$(yc compute instance get childs-health-api --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
echo "VM IP: $VM_IP"
```

#### 2. Setup VM

```bash
# SSH into VM
ssh ubuntu@$VM_IP

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone repository
git clone https://github.com/your-org/childs-health-card.git
cd childs-health-card/backend

# Create .env file (copy from secure storage)
nano .env  # Paste your production .env

# Start services
docker-compose up -d

# Verify
docker-compose ps
curl http://localhost:8000/health
```

### Option 2: Yandex Container Registry + Serverless Containers

```bash
# Create registry
yc container registry create --name childs-health-registry

# Get registry ID
REGISTRY_ID=$(yc container registry get childs-health-registry --format json | jq -r '.id')

# Build and push image
docker build -t cr.yandex/$REGISTRY_ID/childs-health-api:latest .
docker push cr.yandex/$REGISTRY_ID/childs-health-api:latest

# Create serverless container
yc serverless container create \
  --name childs-health-api \
  --core-fraction 100 \
  --cores 1 \
  --memory 1GB \
  --execution-timeout 30s \
  --concurrency 10 \
  --environment DATABASE_URL=$DATABASE_URL \
  --environment JWT_SECRET_KEY=$JWT_SECRET_KEY \
  --image cr.yandex/$REGISTRY_ID/childs-health-api:latest
```

---

## Database Setup (PostgreSQL)

### Option 1: Managed PostgreSQL (Yandex Managed Service for PostgreSQL)

```bash
# Create PostgreSQL cluster
yc managed-postgresql cluster create \
  --name childs-health-db \
  --environment production \
  --network-name default \
  --resource-preset s2.micro \
  --disk-size 10 \
  --disk-type network-ssd \
  --postgresql-version 15 \
  --user name=childs_health,password=$POSTGRES_PASSWORD \
  --database name=childs_health_db,owner=childs_health

# Get connection string
yc managed-postgresql cluster get childs-health-db --format json | jq -r '.config.hosts[0].name'

# Update DATABASE_URL in .env
# postgresql://childs_health:<password>@<host>:6432/childs_health_db
```

### Option 2: Self-Hosted PostgreSQL (Docker)

Already configured in `docker-compose.yml`. Ensure:

```yaml
volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/data/postgres  # Use persistent storage
```

### Database Migrations

```bash
# Run migrations (if using Alembic)
docker-compose exec api alembic upgrade head

# Verify tables
docker-compose exec postgres psql -U childs_health -d childs_health_db -c "\dt"

# Expected tables:
# - children
# - episodes
# - prescriptions
# - intakes
# - tests
# - procedures
# - attachments
# - qr_tokens
```

---

## Object Storage Setup

### 1. Create Yandex Object Storage Bucket

```bash
# Via CLI
yc storage bucket create \
  --name childs-health-prod \
  --default-storage-class standard \
  --max-size 107374182400  # 100GB limit

# Set CORS policy
cat > cors.json <<EOF
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": ["https://yourdomain.com"],
    "MaxAgeSeconds": 3000
  }
]
EOF

yc storage bucket update childs-health-prod --cors-file cors.json
```

### 2. Create Service Account and Access Keys

```bash
# Create service account
yc iam service-account create --name childs-health-storage

# Get service account ID
SA_ID=$(yc iam service-account get childs-health-storage --format json | jq -r '.id')

# Assign role
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role storage.editor \
  --subject serviceAccount:$SA_ID

# Create access key
yc iam access-key create --service-account-name childs-health-storage

# Output:
# access_key:
#   id: <KEY_ID>
#   service_account_id: <SA_ID>
#   created_at: "..."
#   key_id: <ACCESS_KEY>
# secret: <SECRET_KEY>

# Update .env with these values
```

### 3. Test Upload

```bash
# Upload test file
curl -X POST http://localhost:8000/episodes/1/upload \
  -H "X-API-Key: $API_KEY" \
  -F "file=@test.jpg"

# Verify in Yandex Cloud Console
# Storage > childs-health-prod > attachments/
```

---

## Flutter App Build

### 1. Configure API Endpoint

Update `lib/main.dart`:

```dart
final apiService = ApiService(
  baseUrl: 'https://api.yourdomain.com',  // Production URL
  apiKey: 'YOUR_PRODUCTION_API_KEY',      // From secure config
);
```

### 2. Build Android APK

```bash
# Clean build
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 3. Build Android App Bundle (for Play Store)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 4. Build iOS (macOS required)

```bash
# Install CocoaPods dependencies
cd ios
pod install
cd ..

# Build
flutter build ios --release

# Archive in Xcode:
# 1. Open ios/Runner.xcworkspace in Xcode
# 2. Product → Archive
# 3. Distribute App → App Store Connect
```

### 5. Code Signing

**Android:**
```bash
# Generate keystore
keytool -genkey -v -keystore ~/childs-health-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias childs-health

# Update android/key.properties
storePassword=<password>
keyPassword=<password>
keyAlias=childs-health
storeFile=/path/to/childs-health-key.jks

# Build signed APK
flutter build apk --release
```

**iOS:**
- Configure in Xcode with Apple Developer account
- Use automatic signing or manual certificates

---

## SSL/TLS Setup

### 1. Install Certbot (Let's Encrypt)

```bash
# On VM
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Generate certificate
sudo certbot certonly --standalone -d api.yourdomain.com

# Certificates saved to:
# /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/api.yourdomain.com/privkey.pem
```

### 2. Configure Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt install nginx

# Create config
sudo nano /etc/nginx/sites-available/childs-health
```

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/childs-health /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Auto-renewal
sudo certbot renew --dry-run
```

---

## Monitoring & Logging

### 1. Application Logs

```bash
# View logs
docker-compose logs -f api

# Save logs
docker-compose logs api > /var/log/childs-health/api.log
```

### 2. Setup Log Rotation

```bash
sudo nano /etc/logrotate.d/childs-health
```

```
/var/log/childs-health/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 ubuntu ubuntu
    sharedscripts
}
```

### 3. Yandex Monitoring

```bash
# Install Unified Agent
curl -sSL https://storage.yandexcloud.net/yandexcloud-monitoring-public/install.sh | bash

# Configure metrics collection
sudo nano /etc/yandex/unified_agent/config.yml
```

### 4. Health Checks

```bash
# Create monitoring script
cat > /usr/local/bin/health-check.sh <<'EOF'
#!/bin/bash
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ $RESPONSE -ne 200 ]; then
  echo "API health check failed: $RESPONSE"
  # Send alert (email, Telegram, etc.)
fi
EOF

chmod +x /usr/local/bin/health-check.sh

# Add cron job (every 5 minutes)
crontab -e
*/5 * * * * /usr/local/bin/health-check.sh
```

---

## Backup Strategy

### 1. Database Backups

```bash
# Automated daily backup
cat > /usr/local/bin/backup-db.sh <<'EOF'
#!/bin/bash
BACKUP_DIR=/backups/postgres
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U childs_health childs_health_db | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
EOF

chmod +x /usr/local/bin/backup-db.sh

# Daily cron at 3 AM
crontab -e
0 3 * * * /usr/local/bin/backup-db.sh
```

### 2. Object Storage Backups

Yandex Object Storage has built-in versioning:

```bash
# Enable versioning
yc storage bucket update childs-health-prod --versioning enabled

# Set lifecycle policy (delete old versions after 90 days)
cat > lifecycle.json <<EOF
{
  "rules": [{
    "id": "delete-old-versions",
    "enabled": true,
    "filter": {"prefix": ""},
    "noncurrent_version_expiration": {"noncurrent_days": 90}
  }]
}
EOF

yc storage bucket update childs-health-prod --lifecycle-file lifecycle.json
```

### 3. Application Backups

```bash
# Backup entire application
tar -czf /backups/app_$(date +%Y%m%d).tar.gz \
  /home/ubuntu/childs-health-card \
  /etc/nginx/sites-available/childs-health \
  /etc/letsencrypt
```

---

## Scaling

### Vertical Scaling (Increase Resources)

```bash
# Yandex Compute Cloud
yc compute instance update childs-health-api \
  --cores 4 \
  --memory 8GB

# Docker resource limits
docker-compose.yml:
  services:
    api:
      deploy:
        resources:
          limits:
            cpus: '2'
            memory: 4G
```

### Horizontal Scaling (Load Balancer)

```bash
# Create Application Load Balancer
yc application-load-balancer load-balancer create \
  --name childs-health-lb \
  --network-name default

# Create backend group
yc application-load-balancer backend-group create \
  --name childs-health-backends \
  --http-backend name=backend1,weight=1,port=8000,target-group-id=<TG_ID>

# Add multiple instances
# Instance 1: api-1.yourdomain.com
# Instance 2: api-2.yourdomain.com
# Instance 3: api-3.yourdomain.com
```

### Database Scaling

```bash
# Managed PostgreSQL - add replicas
yc managed-postgresql cluster add-host \
  --cluster-name childs-health-db \
  --zone ru-central1-b \
  --replication-source <master-host>

# Connection pooling with PgBouncer
docker-compose.yml:
  pgbouncer:
    image: pgbouncer/pgbouncer
    environment:
      DATABASES: childs_health_db=host=postgres port=5432
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 25
```

---

## Testing Checklist

### Pre-Deployment Tests

- [ ] All environment variables set correctly
- [ ] Database migrations run successfully
- [ ] Object Storage credentials valid
- [ ] SSL certificates installed
- [ ] API endpoints accessible via HTTPS
- [ ] CORS configured correctly

### API Tests

```bash
# Health check
curl https://api.yourdomain.com/health

# Authentication test (should fail without API key)
curl -X POST https://api.yourdomain.com/sync \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected: 401 Unauthorized

# Authentication test (should succeed with API key)
curl -X POST https://api.yourdomain.com/sync \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"children":[],"episodes":[],"prescriptions":[],"intakes":[],"tests":[],"procedures":[],"attachments":[]}'

# Expected: 200 OK

# QR generation test
curl -X POST https://api.yourdomain.com/qr/generate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"child_id":1,"expire_hours":48}'
```

### Flutter App Tests

- [ ] Install APK on test device
- [ ] App connects to production API
- [ ] Authentication works (API key)
- [ ] Sync functionality works
- [ ] QR generation works
- [ ] File uploads work
- [ ] Offline mode works
- [ ] Error handling works (no internet, backend down)

---

## Rollback Plan

### If Deployment Fails:

1. **Restore Previous Docker Image**
```bash
docker-compose down
git checkout <previous-commit>
docker-compose up -d
```

2. **Restore Database**
```bash
# Find latest backup
ls -lh /backups/postgres/

# Restore
gunzip < /backups/postgres/backup_<timestamp>.sql.gz | \
  docker-compose exec -T postgres psql -U childs_health childs_health_db
```

3. **Rollback Nginx Config**
```bash
sudo git -C /etc/nginx/sites-available checkout HEAD^ childs-health
sudo systemctl reload nginx
```

4. **Notify Users**
- Update status page
- Send push notification via Flutter app

---

## Post-Deployment

### 1. Verify Everything Works

```bash
# Run full test suite
./run-tests.sh

# Monitor logs
docker-compose logs -f --tail=100

# Check metrics
# Yandex Cloud Console → Monitoring
```

### 2. Enable Production Mode

```bash
# Update .env
DEBUG=False

# Restart
docker-compose restart api
```

### 3. Update Documentation

- [ ] Update API docs with production URL
- [ ] Update Flutter app config in README
- [ ] Document any issues encountered

---

## Support & Maintenance

### Regular Tasks

- **Daily**: Check logs for errors
- **Weekly**: Review metrics (CPU, memory, requests)
- **Monthly**: Update dependencies, security patches
- **Quarterly**: Review and optimize database

### Emergency Contacts

- **Backend Issues**: Check `/var/log/childs-health/`
- **Database Issues**: Check PostgreSQL logs
- **Network Issues**: Check Nginx logs `/var/log/nginx/`

---

## Production Ready Checklist

- [ ] All environment variables secured
- [ ] SSL/TLS enabled
- [ ] API authentication enabled
- [ ] Database backups configured
- [ ] Monitoring enabled
- [ ] Logs rotation configured
- [ ] Health checks running
- [ ] Error handling tested
- [ ] Rollback plan tested
- [ ] Documentation updated

**Status**: ✅ Ready for Production

---

**Deployed by**: _____________
**Date**: _____________
**Version**: 1.0.0
