# Project Audit Report: Child's Health Card
**Date:** 2025-11-16
**Auditor:** Claude Code Assistant
**Project Version:** 1.0.0+1

---

## 📋 Executive Summary

**Overall Status:** ⚠️ **NEEDS FIXES BEFORE PRODUCTION**

**Critical Issues Found:** 3
**Warning Issues Found:** 5
**Recommendations:** 12

**Ready for:** ✅ Local Development, ✅ Testing
**NOT Ready for:** ❌ Production Deployment (without fixes)

---

## 1. ✅ ПРОВЕРКА РАБОТОСПОСОБНОСТИ

### 1.1 Flutter Client Analysis

#### ✅ **PASS: Core Architecture**
```
✓ Drift ORM properly configured
✓ Provider state management implemented
✓ GoRouter navigation setup complete
✓ Multi-language support (RU/UZ/EN) ready
✓ Theme system configured
```

#### ❌ **CRITICAL: Missing Dependencies in pubspec.yaml**

**Problem:** Settings module requires packages NOT in `pubspec.yaml`:

```yaml
# MISSING from pubspec.yaml:
http: ^1.1.2                    # For API calls
archive: ^3.4.9                 # For backup ZIP
permission_handler: ^11.1.0     # For storage access
file_picker: ^6.1.1             # For restore file selection
```

**Impact:**
- App WILL NOT compile
- `import 'package:http/http.dart'` fails
- Backup/restore features crash
- Settings screen crashes on load

**Fix:**
```bash
# Add to pubspec.yaml dependencies:
dependencies:
  http: ^1.1.2
  archive: ^3.4.9
  permission_handler: ^11.1.0
  file_picker: ^6.1.1

# Then run:
flutter pub get
```

#### ⚠️ **WARNING: Duplicate Screen Files**

**Found:**
```
/lib/presentation/screens/settings_screen.dart         ← ACTIVE (imported in router)
/lib/presentation/screens/settings/settings_screen.dart ← DUPLICATE (not used)
/lib/presentation/screens/home_screen.dart             ← ACTIVE
/lib/presentation/screens/home/home_screen.dart        ← DUPLICATE (not used)
```

**Impact:**
- Confusion during development
- Potential merge conflicts
- Unnecessary bloat

**Fix:**
```bash
# Remove duplicates:
rm lib/presentation/screens/settings/settings_screen.dart
rm lib/presentation/screens/home/home_screen.dart
rm lib/presentation/screens/calendar/calendar_screen.dart
rm lib/presentation/screens/illness/illness_detail_screen.dart
rm lib/presentation/screens/children/child_profile_screen.dart
rm lib/presentation/screens/statistics/statistics_screen.dart
rm lib/presentation/screens/episode_detail_screen.dart  # Keep only _new version
```

#### ✅ **PASS: Provider Dependencies**

All providers properly injected:
```dart
✓ SettingsProvider(database, prefs)
✓ HomeProvider(database)
✓ QRProvider(database, apiService)
✓ SyncProvider(database, apiService)
✓ EpisodeDetailProvider(database, apiService)
```

#### ⚠️ **WARNING: Missing Error Boundaries**

**Problem:** No global error handler for uncaught exceptions.

**Impact:** App crashes with red screen instead of graceful error message.

**Fix:** Add to `main.dart`:
```dart
void main() async {
  // ... existing code ...

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // TODO: Log to crash analytics (Firebase Crashlytics)
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    // TODO: Log to analytics
    return true;
  };

  runApp(MyApp(...));
}
```

### 1.2 Database (Drift ORM) Analysis

#### ✅ **PASS: Schema Definition**

All tables properly defined:
```
✓ Children (id, name, birth_date, blood_group, allergies, chronic_conditions, avatar)
✓ Episodes (id, child_id, parent_episode_id, diagnosis, start_date, end_date, status, notes)
✓ Prescriptions (id, episode_id, drug_name, dose, schedule, start_date, end_date)
✓ Intakes (id, prescription_id, at_datetime, taken, reason_skip)
✓ Tests (id, episode_id, kind, at_datetime, result_text, attachment_id)
✓ Procedures (id, episode_id, kind, at_datetime, status, note)
✓ Attachments (id, episode_id, kind, local_path, cloud_key, cloud_url, file_size, at_datetime)
```

#### ✅ **PASS: Foreign Key Relationships**

```
✓ Episodes → Children (child_id)
✓ Episodes → Episodes (parent_episode_id) [Self-referencing for episode chains]
✓ Prescriptions → Episodes (episode_id)
✓ Intakes → Prescriptions (prescription_id)
✓ Tests → Episodes (episode_id)
✓ Procedures → Episodes (episode_id)
✓ Attachments → Episodes (episode_id)
```

#### ✅ **PASS: DAOs (Data Access Objects)**

All DAOs implemented with CRUD operations:
```
✓ ChildDao
✓ EpisodeDao (with chain support)
✓ PrescriptionDao (with daily schedule)
✓ IntakeDao
✓ TestDao
✓ ProcedureDao
✓ AttachmentDao
```

#### ⚠️ **WARNING: Missing Database Migrations**

**Problem:** No Alembic/migration system for schema changes.

**Impact:** Future schema updates will require:
- Manual database deletion
- Data loss for users

**Recommendation:**
```bash
# For future versions, use:
flutter pub add drift_sqflite  # For better migrations
# OR manually version database and handle migrations in code
```

### 1.3 Backend (FastAPI) Analysis

#### ✅ **PASS: API Structure**

```
backend/app/
├── config.py          ✓ Pydantic settings
├── database.py        ✓ SQLAlchemy session
├── models.py          ✓ All 8 models defined
├── schemas.py         ✓ Pydantic validation schemas
├── main.py            ✓ FastAPI app with CORS
├── routers/
│   ├── sync.py        ✓ POST /sync
│   ├── qr.py          ✓ /qr/generate, /qr/{token}
│   └── episodes.py    ✓ /episodes/{id}, /episodes/{id}/upload
└── services/
    ├── s3_service.py  ✓ Yandex Object Storage
    └── qr_service.py  ✓ QR generation
```

#### ✅ **PASS: Endpoint Coverage**

```
✓ POST   /sync                      - Full data sync
✓ POST   /qr/generate                - Generate QR token
✓ GET    /qr/{token}                - Get data by QR token
✓ DELETE /qr/{token}                - Invalidate QR token
✓ GET    /episodes/{id}             - Get episode details
✓ POST   /episodes/{id}/upload      - Upload file to S3
✓ GET    /docs                      - Swagger UI
✓ GET    /                          - Health check
```

#### ⚠️ **WARNING: No Authentication**

**Problem:** ALL endpoints are public (no JWT, no API keys).

**Impact:**
- Anyone can access ANY patient data
- No rate limiting
- Vulnerable to abuse

**Recommendation for Production:**
```python
# Add to main.py:
from fastapi import Security, HTTPException
from fastapi.security import HTTPBearer

security = HTTPBearer()

@app.middleware("http")
async def verify_token(request: Request, call_next):
    if request.url.path.startswith("/qr/"):
        # QR endpoints are public but time-limited
        pass
    else:
        # Require API key for all other endpoints
        api_key = request.headers.get("X-API-Key")
        if api_key != settings.API_KEY:
            raise HTTPException(status_code=401, detail="Invalid API key")
    return await call_next(request)
```

#### ❌ **CRITICAL: Environment Variables Not Validated**

**Problem:** `.env` file required but not checked on startup.

**Impact:**
- App crashes if Yandex credentials missing
- Silent failures with boto3 S3 operations

**Fix in `backend/app/main.py`:**
```python
@app.on_event("startup")
async def startup_validation():
    """Validate critical env vars on startup"""
    required = [
        "DATABASE_URL",
        "YC_STORAGE_ACCESS_KEY",
        "YC_STORAGE_SECRET_KEY",
        "YC_STORAGE_BUCKET_NAME",
    ]

    missing = [var for var in required if not getattr(settings, var.lower(), None)]

    if missing:
        raise ValueError(f"Missing required environment variables: {missing}")

    logger.info("✓ All environment variables validated")
```

### 1.4 Database (PostgreSQL) Analysis

#### ✅ **PASS: Docker Compose Configuration**

```yaml
✓ PostgreSQL 15 image
✓ Persistent volume (postgres_data)
✓ Environment variables configured
✓ Exposed on port 5432
✓ Health check configured
```

#### ⚠️ **WARNING: Default Credentials**

**Problem:** `docker-compose.yml` uses default password `password`.

**Impact:**
- Security risk in production
- Predictable credentials

**Fix:** Update `.env`:
```bash
POSTGRES_PASSWORD=<generate_strong_password>
# Use: openssl rand -base64 32
```

### 1.5 Integration Analysis

#### ✅ **PASS: Flutter ↔ Backend Communication**

```dart
ApiService properly implements:
✓ syncData() → POST /sync
✓ generateQRToken() → POST /qr/generate
✓ uploadFile() → POST /episodes/{id}/upload
✓ invalidateQRToken() → DELETE /qr/{token}
```

#### ✅ **PASS: Backend ↔ Database Communication**

```python
✓ SQLAlchemy models match Pydantic schemas
✓ Upsert logic based on mobile_id
✓ Cascade deletes configured
✓ Foreign key constraints enforced
```

#### ✅ **PASS: Backend ↔ Yandex Object Storage**

```python
✓ S3Service uses boto3 with correct endpoint
✓ Image compression before upload
✓ QR images uploaded to bucket
✓ Presigned URLs generated (if needed)
```

---

## 2. 📋 ЧЕКЛИСТ ДЕПЛОЯ

### 2.1 Local Development Setup

#### Step 1: Backend Setup

```bash
# 1. Navigate to backend
cd /home/user/Childs-Health-Card/backend

# 2. Create .env file
cp .env.example .env
nano .env  # Fill in real values

# 3. Start services with Docker Compose
docker-compose up -d

# 4. Verify services
docker ps  # Should show 2 containers: api, postgres
docker-compose logs -f api  # Check logs

# 5. Test API
curl http://localhost:8000/
# Expected: {"message":"Child's Health Card API is running"}

# 6. Open Swagger docs
open http://localhost:8000/docs
```

#### Step 2: Flutter Setup

```bash
# 1. Navigate to project root
cd /home/user/Childs-Health-Card

# 2. FIX CRITICAL: Add missing dependencies
# Edit pubspec.yaml and add:
#   http: ^1.1.2
#   archive: ^3.4.9
#   permission_handler: ^11.1.0
#   file_picker: ^6.1.1

# 3. Get dependencies
flutter pub get

# 4. Generate Drift code
flutter pub run build_runner build --delete-conflicting-outputs

# 5. Connect device or start emulator
flutter devices

# 6. Run app
flutter run

# For Android emulator, update API URL in main.dart:
# baseUrl: 'http://10.0.2.2:8000'

# For iOS simulator, keep:
# baseUrl: 'http://localhost:8000'
```

#### Step 3: Testing Integration

```bash
# 1. In app: Create a child profile
# Settings → Profiles → Add → "Test Child"

# 2. In app: Create an episode
# Home → + → Add episode → "ОРВИ"

# 3. Test sync
# Home → Cloud icon → Should show "Synced"

# 4. Verify backend received data
docker-compose exec postgres psql -U childs_health -d childs_health_db
SELECT * FROM children;
SELECT * FROM episodes;
\q

# 5. Test QR generation
# Home → QR for Doctor → Generate
# Should display QR code image

# 6. Test backup
# Settings → Backup → Create backup
# Check: /storage/emulated/0/Download/ChildsHealth/
```

### 2.2 Build APK for Android

```bash
# 1. Update API URL to production
# In lib/main.dart, change:
# baseUrl: 'https://api.yourdomain.com'

# 2. Build release APK
flutter build apk --release

# 3. APK location
# build/app/outputs/flutter-apk/app-release.apk

# 4. Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# OR for split APKs (smaller size):
flutter build apk --split-per-abi --release
# Generates: app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk
```

### 2.3 Yandex Cloud Deployment

#### Prerequisites

```bash
# 1. Create Yandex Cloud account
# https://console.cloud.yandex.com

# 2. Install Yandex CLI
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
yc init  # Login and select folder

# 3. Install Docker (if not already)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

#### Deploy Object Storage

```bash
# 1. Create bucket
yc storage bucket create \
  --name childs-health-files \
  --default-storage-class standard

# 2. Generate access keys
yc iam access-key create \
  --service-account-name childs-health-sa \
  --description "For Object Storage access"

# 3. Save keys to .env:
# YC_STORAGE_ACCESS_KEY=<access_key_id>
# YC_STORAGE_SECRET_KEY=<secret_key>

# 4. Configure CORS
cat > cors.json <<EOF
[{
  "AllowedOrigins": ["*"],
  "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
  "AllowedHeaders": ["*"],
  "MaxAgeSeconds": 3600
}]
EOF

aws s3api put-bucket-cors \
  --bucket childs-health-files \
  --cors-configuration file://cors.json \
  --endpoint-url=https://storage.yandexcloud.net

# 5. Make QR folder public-readable
aws s3api put-bucket-acl \
  --bucket childs-health-files \
  --acl public-read \
  --endpoint-url=https://storage.yandexcloud.net
```

#### Deploy PostgreSQL

```bash
# 1. Create Managed PostgreSQL cluster
yc managed-postgresql cluster create \
  --name childs-health-db \
  --environment production \
  --network-name default \
  --resource-preset s2.micro \
  --disk-size 10GB \
  --disk-type network-ssd \
  --postgresql-version 15

# 2. Create database
yc managed-postgresql database create \
  --cluster-name childs-health-db \
  --name childs_health_db \
  --owner childs_health

# 3. Get connection string
yc managed-postgresql cluster get childs-health-db --format json | jq -r '.config.hosts[0].name'

# 4. Update .env:
# DATABASE_URL=postgresql://childs_health:<password>@<host>:6432/childs_health_db
```

#### Deploy Backend (Compute Instance)

```bash
# 1. Create VM
yc compute instance create \
  --name childs-health-api \
  --zone ru-central1-a \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=20GB \
  --ssh-key ~/.ssh/id_rsa.pub

# 2. SSH into VM
yc compute ssh childs-health-api

# 3. Install Docker on VM
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 4. Clone repo (or copy files)
git clone <your-repo> /opt/childs-health-card
cd /opt/childs-health-card/backend

# 5. Create .env with production values
nano .env

# 6. Start backend
docker-compose up -d

# 7. Check logs
docker-compose logs -f api

# 8. Test from outside
curl http://<VM_PUBLIC_IP>:8000/
```

#### Setup SSL with Let's Encrypt

```bash
# 1. Install Nginx
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx -y

# 2. Configure Nginx
sudo nano /etc/nginx/sites-available/childs-health

# Add:
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# 3. Enable site
sudo ln -s /etc/nginx/sites-available/childs-health /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# 4. Get SSL certificate
sudo certbot --nginx -d api.yourdomain.com

# 5. Auto-renewal
sudo certbot renew --dry-run
```

### 2.4 Flutter App Configuration

```dart
// Update lib/main.dart:
final apiService = ApiService(
  baseUrl: 'https://api.yourdomain.com',  // Production URL
);

// Update settings (if using cloud):
// Settings → Cloud Storage → Configure
// Endpoint: https://storage.yandexcloud.net
// Access Key: <from yc iam access-key create>
// Secret Key: <from yc iam access-key create>
// Bucket: childs-health-files
```

### 2.5 Monitoring & Maintenance

```bash
# Check backend logs
docker-compose logs -f api

# Check database size
docker-compose exec postgres psql -U childs_health -d childs_health_db
SELECT pg_size_pretty(pg_database_size('childs_health_db'));

# Check Object Storage usage
aws s3 ls s3://childs-health-files --recursive --human-readable --summarize \
  --endpoint-url=https://storage.yandexcloud.net

# Backup database
docker-compose exec postgres pg_dump -U childs_health childs_health_db > backup_$(date +%Y%m%d).sql

# Restore database
docker-compose exec -T postgres psql -U childs_health childs_health_db < backup_20251116.sql
```

---

## 3. 🛠️ ПРОВЕРКА НА КРАШИ

### Crash Scenario #1: No Internet Connection

**Symptoms:**
```
✗ Sync button shows loading forever
✗ QR generation fails with "Connection error"
✗ File upload times out
✗ App feels frozen
```

**How to Detect:**
```dart
// In ApiService methods, check for SocketException:
try {
  final response = await _client.post(...);
} catch (e) {
  if (e is SocketException) {
    debugPrint('No internet connection');
  }
}
```

**Fix:**

1. **Add connectivity check:**
```bash
# Add to pubspec.yaml:
connectivity_plus: ^5.0.2
```

```dart
// In api_service.dart:
import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> _checkConnectivity() async {
  final connectivity = await Connectivity().checkConnectivity();
  return connectivity != ConnectivityResult.none;
}

Future<Map<String, dynamic>> syncData(...) async {
  if (!await _checkConnectivity()) {
    throw Exception('No internet connection. Please check your network.');
  }
  // ... rest of sync logic
}
```

2. **Update UI to show error:**
```dart
// In sync_provider.dart:
catch (e) {
  _state = SyncState.error;
  if (e.toString().contains('No internet')) {
    _errorMessage = 'Нет подключения к интернету';
  } else {
    _errorMessage = 'Ошибка синхронизации: ${e.toString()}';
  }
  notifyListeners();
}
```

### Crash Scenario #2: Backend Unavailable

**Symptoms:**
```
✗ HTTP 500 errors
✗ "Connection refused" on port 8000
✗ Sync fails with timeout
```

**How to Detect:**
```bash
# Check backend status
curl http://localhost:8000/
# If connection refused → backend is down

# Check Docker containers
docker ps | grep childs_health
# If not running → start it
```

**Fix:**

1. **Restart backend:**
```bash
cd backend
docker-compose restart api
docker-compose logs -f api  # Check for errors
```

2. **Common backend errors:**

**Error: `ModuleNotFoundError: No module named 'fastapi'`**
```bash
# Rebuild Docker image
docker-compose build --no-cache
docker-compose up -d
```

**Error: `FATAL: password authentication failed`**
```bash
# Check .env file
cat .env | grep DATABASE_URL
# Ensure password matches docker-compose.yml
```

**Error: `boto3.exceptions.NoCredentialsError`**
```bash
# Check .env file
cat .env | grep YC_STORAGE
# Ensure all Yandex Cloud credentials are set
```

3. **Add retry logic in Flutter:**
```dart
// In api_service.dart:
Future<Map<String, dynamic>> syncData(...) async {
  int retries = 3;
  int delay = 2; // seconds

  for (int i = 0; i < retries; i++) {
    try {
      final response = await _client.post(...).timeout(
        const Duration(seconds: 30),
      );
      return jsonDecode(response.body);
    } catch (e) {
      if (i == retries - 1) rethrow;  // Last retry, give up

      await Future.delayed(Duration(seconds: delay));
      delay *= 2;  // Exponential backoff
    }
  }
}
```

### Crash Scenario #3: Database Table Missing

**Symptoms:**
```
✗ App crashes on launch
✗ "SqliteException: no such table: children"
✗ White screen / Red error screen
```

**How to Detect:**
```bash
# Check if database file exists
ls -la /data/data/com.example.childs_health_card/databases/
# OR on emulator:
adb shell ls /data/data/com.example.childs_health_card/databases/

# If app_database.sqlite missing → needs initialization
```

**Fix:**

1. **Delete and recreate database:**
```bash
# On device/emulator:
adb shell run-as com.example.childs_health_card
cd databases
rm app_database.sqlite*
exit

# Restart app - database will be recreated
```

2. **Add database initialization check:**
```dart
// In main.dart:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = AppDatabase();

    // Test database connection
    final children = await database.childDao.getAllChildren();
    debugPrint('Database initialized: ${children.length} children');

    runApp(MyApp(database: database, ...));
  } catch (e) {
    debugPrint('Database initialization failed: $e');

    // Show error screen
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Database error: $e'),
        ),
      ),
    ));
  }
}
```

### Crash Scenario #4: Expired QR Token

**Symptoms:**
```
✗ Doctor scans QR → "Token expired or invalid"
✗ GET /qr/{token} returns 404
✗ No data displayed on doctor portal
```

**How to Detect:**
```python
# Check token in database
docker-compose exec postgres psql -U childs_health childs_health_db

SELECT token, expires_at, is_active
FROM qr_tokens
WHERE token = 'xYz123...';

# If expires_at < NOW() → token expired
```

**Fix:**

1. **Backend: Add better error messages:**
```python
# In backend/app/routers/qr.py:
@router.get("/{token}")
async def get_qr_data(token: str, db: Session = Depends(get_db)):
    qr_token = qr_service.get_qr_token(db, token)

    if not qr_token:
        raise HTTPException(
            status_code=404,
            detail="QR код не найден. Возможно, он был удалён."
        )

    if not qr_token.is_active:
        raise HTTPException(
            status_code=403,
            detail="QR код деактивирован. Запросите новый у родителя."
        )

    if qr_token.expires_at < datetime.now():
        raise HTTPException(
            status_code=410,  # Gone
            detail=f"QR код истёк {qr_token.expires_at.strftime('%d.%m.%Y %H:%M')}. Запросите новый."
        )

    # ... rest of logic
```

2. **Flutter: Show expiration warning:**
```dart
// In qr_generator_screen.dart:
Widget _buildQRDisplay(...) {
  final timeRemaining = token.expiresAt.difference(DateTime.now());
  final hoursLeft = timeRemaining.inHours;

  return Column(
    children: [
      // QR code display
      ...

      // Expiration warning
      if (hoursLeft < 6)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'QR код истекает через $hoursLeft ч',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ],
          ),
        ),
    ],
  );
}
```

### Crash Scenario #5: Import Errors / Missing Files

**Symptoms:**
```
✗ Compilation error: "Target of URI doesn't exist"
✗ "Undefined name 'SettingsProvider'"
✗ Red squiggles in IDE
```

**How to Detect:**
```bash
# Try to compile
flutter analyze

# Check for errors:
# - Unused imports
# - Missing imports
# - Undefined classes
```

**Common Import Errors:**

**Error 1: `settings_screen.dart` not found**
```
Target of URI doesn't exist: '../widgets/settings/children_management_section.dart'
```

**Fix:**
```dart
// Check file actually exists:
ls lib/presentation/widgets/settings/children_management_section.dart

// If missing, file was deleted or renamed
// Restore from git or recreate
```

**Error 2: Circular import**
```
Circular dependency detected: A imports B imports A
```

**Fix:**
```dart
// Move shared code to separate file
// lib/models/shared_models.dart

// Or use forward declarations
```

**Error 3: Case sensitivity**
```
import '../providers/SettingsProvider.dart';  // Wrong
import '../providers/settings_provider.dart'; // Correct (lowercase)
```

**Fix:** Always use lowercase filenames with underscores.

### Crash Scenario #6: Out of Memory (Large Backup)

**Symptoms:**
```
✗ Backup fails at 90%
✗ App crashes during ZIP creation
✗ "OutOfMemoryError: Failed to allocate..."
```

**How to Detect:**
```bash
# Check file sizes
du -sh /data/data/com.example.childs_health_card/databases/
du -sh /data/data/com.example.childs_health_card/files/attachments/

# If > 500MB → may cause OOM on low-end devices
```

**Fix:**

1. **Stream ZIP creation instead of loading into memory:**
```dart
// In backup_service.dart:
Future<String?> createBackup() async {
  // Instead of loading all files into memory:
  // encoder.addDirectory(backupTempDir);  // ← May OOM

  // Use streaming:
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  // Add files one by one
  await for (final entity in backupTempDir.list(recursive: true)) {
    if (entity is File) {
      encoder.addFile(entity);  // Streams file instead of loading all
    }
  }

  encoder.close();
  return zipPath;
}
```

2. **Show progress indicator:**
```dart
// In backup_section.dart:
Future<void> _createBackup(BuildContext context) async {
  int progress = 0;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: progress / 100),
              const SizedBox(height: 16),
              Text('Создание резервной копии: $progress%'),
            ],
          ),
        );
      },
    ),
  );

  // Create backup with progress callback
  final zipPath = await backupService.createBackupWithProgress(
    onProgress: (p) {
      progress = p;
      // Update dialog
    },
  );

  Navigator.pop(context);
}
```

### Crash Scenario #7: PIN Code Lost

**Symptoms:**
```
✗ User forgot PIN
✗ Can't access app
✗ No "forgot PIN" option
```

**How to Detect:**
```
User reports: "I can't login, forgot my PIN"
```

**Fix:**

**Option 1: Add "Forgot PIN" feature (RECOMMENDED)**
```dart
// In security_section.dart:
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Забыли PIN?'),
    content: const Text(
      'Для сброса PIN-кода потребуется удалить все данные приложения.\n\n'
      'Сначала создайте резервную копию!'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () async {
          // Clear app data
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          final storage = FlutterSecureStorage();
          await storage.deleteAll();

          // Show restart message
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('PIN удалён'),
              content: const Text('Перезапустите приложение'),
              actions: [
                FilledButton(
                  onPressed: () => exit(0),  // Force close
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          );
        },
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        child: const Text('Сбросить приложение'),
      ),
    ],
  ),
);
```

**Option 2: Manual reset via ADB (for developers)**
```bash
# Clear app data
adb shell pm clear com.example.childs_health_card

# OR delete secure storage manually
adb shell
run-as com.example.childs_health_card
cd shared_prefs
rm flutter.FlutterSecureStorage.xml
exit
```

---

## 4. ✅ ИТОГОВЫЙ ОТЧЁТ

### 4.1 Critical Issues Summary

| # | Issue | Severity | Impact | Status |
|---|-------|----------|--------|--------|
| 1 | Missing dependencies in pubspec.yaml | 🔴 CRITICAL | App won't compile | ❌ NOT FIXED |
| 2 | No environment variable validation | 🔴 CRITICAL | Backend crashes on startup | ❌ NOT FIXED |
| 3 | No authentication on API | 🟠 HIGH | Anyone can access patient data | ❌ NOT FIXED |
| 4 | Default PostgreSQL password | 🟡 MEDIUM | Security risk | ❌ NOT FIXED |
| 5 | Duplicate screen files | 🟡 MEDIUM | Confusion, bloat | ❌ NOT FIXED |
| 6 | No global error handler | 🟡 MEDIUM | Poor UX on crashes | ❌ NOT FIXED |
| 7 | No database migrations | 🟡 MEDIUM | Data loss on schema changes | ⚠️ ACCEPTABLE |
| 8 | No "forgot PIN" feature | 🔵 LOW | User lockout | ⚠️ ACCEPTABLE |

### 4.2 Production Readiness Checklist

#### Must Fix Before Production:
- [ ] **Add missing dependencies** to pubspec.yaml
- [ ] **Add environment validation** to backend startup
- [ ] **Implement API authentication** (JWT or API keys)
- [ ] **Change default PostgreSQL password**
- [ ] **Add global error handler** in Flutter
- [ ] **Remove duplicate screen files**
- [ ] **Add connectivity check** before API calls
- [ ] **Add retry logic** for network requests
- [ ] **Test on real devices** (Android & iOS)
- [ ] **Setup SSL certificate** for production backend
- [ ] **Configure Yandex Object Storage** CORS
- [ ] **Setup monitoring** (logs, analytics)

#### Recommended for Production:
- [ ] Add forgot PIN feature
- [ ] Add database migration system
- [ ] Add crash analytics (Firebase Crashlytics)
- [ ] Add performance monitoring (Firebase Performance)
- [ ] Setup CI/CD pipeline
- [ ] Add automated tests
- [ ] Add rate limiting to API
- [ ] Add API documentation (beyond Swagger)
- [ ] Setup backup automation
- [ ] Add data encryption at rest

### 4.3 Deployment Difficulty

| Component | Difficulty | Time Estimate |
|-----------|------------|---------------|
| Fix critical issues | 🟢 Easy | 2-4 hours |
| Local development | 🟢 Easy | 30 minutes |
| Build APK | 🟢 Easy | 15 minutes |
| Backend on VM | 🟡 Medium | 1-2 hours |
| PostgreSQL setup | 🟡 Medium | 1 hour |
| Object Storage | 🟢 Easy | 30 minutes |
| SSL certificate | 🟡 Medium | 30 minutes |
| Full production deploy | 🟠 Hard | 4-6 hours |

### 4.4 Cost Estimate (Yandex Cloud)

**Monthly costs for production:**

| Service | Configuration | Cost/Month |
|---------|---------------|------------|
| Compute Instance | 2 vCPU, 2GB RAM | ~500₽ |
| Managed PostgreSQL | s2.micro, 10GB SSD | ~600₽ |
| Object Storage | 10GB storage, 10GB traffic | ~50₽ |
| Load Balancer | 1 instance | ~250₽ |
| **TOTAL** | | **~1400₽/month** |

**Additional costs (one-time):**
- Domain name: ~300₽/year
- SSL certificate: FREE (Let's Encrypt)

### 4.5 Scaling Recommendations

**When you reach 100+ users:**
- [ ] Add Application Load Balancer
- [ ] Scale PostgreSQL to s2.medium (4GB RAM)
- [ ] Add Redis cache for QR tokens
- [ ] Separate file uploads to worker queue

**When you reach 1000+ users:**
- [ ] Upgrade to s2.large (8GB RAM)
- [ ] Add database read replicas
- [ ] Use CDN for static assets (Yandex CDN)
- [ ] Implement database partitioning by year

**When you reach 10,000+ users:**
- [ ] Multi-region deployment
- [ ] Kubernetes cluster instead of single VM
- [ ] Database sharding by child_id
- [ ] Consider switching to managed Kubernetes

### 4.6 Final Verdict

**Overall Assessment:**

✅ **Architecture: EXCELLENT**
- Well-designed database schema
- Clean separation of concerns
- Modern tech stack (Flutter + FastAPI + PostgreSQL)
- Comprehensive features

⚠️ **Implementation: NEEDS WORK**
- Missing critical dependencies
- No authentication
- No production hardening
- Missing error handling

❌ **Production Ready: NO**
- Cannot compile without dependency fixes
- Security vulnerabilities
- No monitoring/alerting

🎯 **Recommendation:**
1. **Fix critical issues** (4 hours work)
2. **Test thoroughly** on real devices (2 hours)
3. **Deploy to staging** environment first (4 hours)
4. **Add monitoring** and error tracking (2 hours)
5. **Then deploy to production** (2 hours)

**Total time to production:** ~14-16 hours of focused work

---

## 5. 📝 IMMEDIATE ACTION ITEMS

### Priority 1: Make App Compile (DO THIS FIRST)

```bash
# 1. Add missing dependencies
cd /home/user/Childs-Health-Card

# Edit pubspec.yaml, add under dependencies:
#   http: ^1.1.2
#   archive: ^3.4.9
#   permission_handler: ^11.1.0
#   file_picker: ^6.1.1

flutter pub get

# 2. Remove duplicate files
rm lib/presentation/screens/settings/settings_screen.dart
rm lib/presentation/screens/home/home_screen.dart
rm lib/presentation/screens/calendar/calendar_screen.dart
rm lib/presentation/screens/illness/illness_detail_screen.dart
rm lib/presentation/screens/children/child_profile_screen.dart
rm lib/presentation/screens/statistics/statistics_screen.dart
rm lib/presentation/screens/episode_detail_screen.dart

# 3. Verify compilation
flutter analyze
flutter build apk --debug  # Should succeed now
```

### Priority 2: Secure Backend

```bash
# 1. Add environment validation
# Edit backend/app/main.py, add startup event (see section 1.3)

# 2. Change default password
# Edit backend/.env:
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# 3. Add API key authentication
# Edit backend/app/config.py:
# API_KEY: str = "your-secret-api-key-change-in-production"

# 4. Restart backend
cd backend
docker-compose down
docker-compose up -d
```

### Priority 3: Test Everything

```bash
# 1. Test backend
curl http://localhost:8000/
curl -X POST http://localhost:8000/sync -H "Content-Type: application/json" -d '{}'

# 2. Test Flutter app
flutter run

# 3. Test each feature:
# - Add child profile
# - Create episode
# - Sync data
# - Generate QR
# - Create backup
# - Change language
# - Set PIN
```

---

## 6. 📚 REFERENCES

### Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview |
| `DATABASE.md` | Database schema documentation |
| `FLUTTER_BACKEND_INTEGRATION.md` | API integration guide |
| `SETTINGS_SETUP.md` | Settings module setup |
| `EPISODE_SCREEN_DOCUMENTATION.md` | Episode screen features |
| `YANDEX_CLOUD_DEPLOY.md` | Deployment to Yandex Cloud |
| `backend/README.md` | Backend API documentation |
| **`PROJECT_AUDIT_REPORT.md`** | **This file** |

### Support Resources

- Flutter docs: https://flutter.dev/docs
- Drift ORM docs: https://drift.simonbinder.eu/docs
- FastAPI docs: https://fastapi.tiangolo.com
- Yandex Cloud docs: https://cloud.yandex.com/docs
- PostgreSQL docs: https://www.postgresql.org/docs

---

**Report Generated:** 2025-11-16
**Next Review:** After critical fixes applied
**Status:** ⚠️ PENDING FIXES
