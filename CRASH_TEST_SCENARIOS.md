# Crash Test Scenarios & Solutions

**Complete guide for testing failure modes and their solutions**

---

## Table of Contents

1. [Network Failures](#network-failures)
2. [Backend Failures](#backend-failures)
3. [Database Failures](#database-failures)
4. [Authentication Failures](#authentication-failures)
5. [QR Token Failures](#qr-token-failures)
6. [File Upload Failures](#file-upload-failures)
7. [Data Corruption](#data-corruption)
8. [Resource Exhaustion](#resource-exhaustion)

---

## Network Failures

### Scenario 1: No Internet Connection

**Test:**
```bash
# Disable WiFi/Mobile data on device
# Try to sync data in app
```

**Expected Behavior:**
- ✅ App shows "Нет подключения к интернету" message
- ✅ Sync fails gracefully
- ✅ Local data remains intact
- ✅ Retry button available

**Implementation:**
```dart
// lib/services/api_service.dart
Future<bool> _checkConnectivity() async {
  final connectivityResult = await _connectivity.checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

// Before API call
if (!hasConnection) {
  throw Exception('Нет подключения к интернету');
}
```

**User Experience:**
```
┌─────────────────────────────┐
│  ⚠️  Нет интернета          │
│                             │
│  Проверьте соединение и     │
│  попробуйте снова           │
│                             │
│  [Повторить]  [Отмена]      │
└─────────────────────────────┘
```

**Solution:**
1. User checks WiFi/mobile connection
2. Taps "Повторить" button
3. App retries sync

---

### Scenario 2: Intermittent Network (Timeout)

**Test:**
```bash
# Simulate slow network
# On Linux VM:
sudo tc qdisc add dev eth0 root netem delay 5000ms

# In app, try to sync
```

**Expected Behavior:**
- ✅ Request times out after 30 seconds
- ✅ App shows "Превышено время ожидания" error
- ✅ App retries automatically (3 attempts)
- ✅ Exponential backoff (1s, 2s, 4s delays)

**Implementation:**
```dart
// lib/services/api_service.dart
final response = await _client
  .post(Uri.parse('$baseUrl/sync'), ...)
  .timeout(const Duration(seconds: 30));

// Retry logic
Future<T> _executeWithRetry<T>(...) async {
  int attempt = 0;
  Duration delay = Duration(seconds: 1);

  while (attempt < 3) {
    try {
      return await request();
    } catch (e) {
      attempt++;
      if (attempt >= 3) rethrow;
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
  }
}
```

**Logs:**
```
Retry attempt 1/3 after 1s
Retry attempt 2/3 after 2s
Retry attempt 3/3 after 4s
Error: Превышено время ожидания
```

**Solution:**
- Automatic retries handle temporary issues
- If all retries fail, user can manually retry later

---

## Backend Failures

### Scenario 3: Backend Server Down

**Test:**
```bash
# Stop backend
docker-compose down

# Try to sync in app
```

**Expected Behavior:**
- ✅ Connection refused error
- ✅ App shows "Сервер недоступен" message
- ✅ Retry with exponential backoff
- ✅ Falls back to local-only mode

**Implementation:**
```dart
try {
  await apiService.syncData(...);
} on SocketException {
  ErrorHandler.showErrorSnackBar(
    context,
    'Сервер недоступен. Данные сохранены локально.'
  );
  // Continue working offline
} catch (e) {
  ErrorHandler.showErrorSnackBar(
    context,
    ErrorHandler.handleNetworkError(e),
  );
}
```

**Backend Health Check:**
```bash
# Automated monitoring script
#!/bin/bash
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
if [ $RESPONSE -ne 200 ]; then
  echo "Backend down! Restarting..."
  docker-compose restart api
  # Send alert to admin
fi
```

**Solution:**
1. Admin receives alert
2. Admin checks logs: `docker-compose logs api`
3. Admin restarts service: `docker-compose restart api`
4. User retries sync

---

### Scenario 4: Backend Returns 500 Error

**Test:**
```bash
# Cause database connection error in backend
docker-compose stop postgres

# Try to sync
```

**Expected Behavior:**
- ✅ App receives 500 status code
- ✅ Shows "Ошибка сервера. Попробуйте позже"
- ✅ Does not corrupt local data
- ✅ Logs error for debugging

**Backend Logs:**
```
ERROR:    Exception in ASGI application
sqlalchemy.exc.OperationalError: could not connect to server: Connection refused
```

**Implementation:**
```dart
if (response.statusCode >= 500) {
  throw Exception('Ошибка сервера. Попробуйте позже.');
}
```

**Solution:**
1. Backend admin checks logs
2. Identifies database connection issue
3. Restarts PostgreSQL: `docker-compose restart postgres`
4. Verifies health check

---

## Database Failures

### Scenario 5: Database Connection Lost

**Test:**
```bash
# While backend is running, stop database
docker-compose stop postgres

# Try API request
curl -X POST http://localhost:8000/sync \
  -H "X-API-Key: test-api-key" \
  -d '{"children":[],...}'
```

**Expected Behavior:**
- ✅ Backend catches database error
- ✅ Returns 500 with error message
- ✅ Does not crash
- ✅ Logs detailed error

**Backend Error Handling:**
```python
# backend/app/routers/sync.py
try:
    # Database operations
    pass
except Exception as e:
    db.rollback()
    raise HTTPException(
        status_code=500,
        detail=f"Ошибка синхронизации: {str(e)}"
    )
```

**Solution:**
1. Restart database: `docker-compose restart postgres`
2. Check database logs: `docker-compose logs postgres`
3. Verify connectivity: `docker-compose exec postgres psql -U childs_health`

---

### Scenario 6: Database Disk Full

**Test:**
```bash
# Fill disk space
docker-compose exec postgres dd if=/dev/zero of=/tmp/fill bs=1M count=10000

# Try to insert data
```

**Expected Behavior:**
- ✅ PostgreSQL returns "disk full" error
- ✅ Backend returns 500 error
- ✅ App shows error to user
- ✅ No data corruption

**Monitoring:**
```bash
# Check disk usage
df -h

# PostgreSQL disk usage
docker-compose exec postgres du -sh /var/lib/postgresql/data
```

**Solution:**
1. Clean old backups: `find /backups -mtime +30 -delete`
2. Increase disk size
3. Archive old data to Object Storage

---

## Authentication Failures

### Scenario 7: Invalid API Key

**Test:**
```bash
# Flutter app with wrong API key
final apiService = ApiService(
  baseUrl: 'http://localhost:8000',
  apiKey: 'wrong-key',
);

# Try to sync
```

**Expected Behavior:**
- ✅ Backend returns 403 Forbidden
- ✅ App shows "Ошибка аутентификации. Проверьте API ключ"
- ✅ Does not retry indefinitely
- ✅ Logs authentication failure

**Backend Validation:**
```python
# backend/app/auth.py
async def verify_api_key_header(x_api_key: Optional[str] = Header(None)):
    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API ключ отсутствует"
        )
    if not APIKeyAuth.verify_api_key(x_api_key):
        raise HTTPException(
            status_code=403,
            detail="Невалидный API ключ"
        )
```

**Flutter Handling:**
```dart
if (response.statusCode == 401 || response.statusCode == 403) {
  throw Exception('Ошибка аутентификации: проверьте API ключ');
}
```

**Solution:**
1. Check API key in Flutter app configuration
2. Verify API key matches backend `.env` file
3. Regenerate API key if compromised

---

### Scenario 8: Missing API Key Header

**Test:**
```bash
# Request without X-API-Key header
curl -X POST http://localhost:8000/sync \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Response:**
```json
{
  "detail": "API ключ отсутствует. Добавьте заголовок: X-API-Key"
}
```

**HTTP Status:** 401 Unauthorized

**Solution:**
- Update Flutter app to always include API key
- Check `_getHeaders()` method in `api_service.dart`

---

## QR Token Failures

### Scenario 9: Expired QR Token

**Test:**
```bash
# Generate QR token with 1-hour expiry
curl -X POST http://localhost:8000/qr/generate \
  -H "X-API-Key: test-api-key" \
  -H "Content-Type: application/json" \
  -d '{"child_id":1,"expire_hours":0.01}'

# Wait 1 minute

# Try to access QR data
curl http://localhost:8000/qr/<token>
```

**Expected Response:**
```json
{
  "detail": "QR токен истёк"
}
```

**HTTP Status:** 401 Unauthorized

**Backend Validation:**
```python
# backend/app/services/qr_service.py
def validate_token(db: Session, token: str) -> QRToken:
    qr_token = db.query(QRToken).filter(QRToken.token == token).first()

    if not qr_token:
        raise ValueError("QR токен не найден")

    if not qr_token.active:
        raise ValueError("QR токен деактивирован")

    if qr_token.expires_at < datetime.utcnow():
        raise ValueError("QR токен истёк")

    return qr_token
```

**User Experience:**
```
┌─────────────────────────────┐
│  ⚠️  QR код истёк            │
│                             │
│  Срок действия: 48 часов    │
│  Истёк: 12.11.2025 14:30    │
│                             │
│  [Создать новый QR]         │
└─────────────────────────────┘
```

**Solution:**
- User generates new QR token in app
- Default expiry: 48 hours

---

### Scenario 10: Invalid QR Token

**Test:**
```bash
# Access with random token
curl http://localhost:8000/qr/invalid-token-12345
```

**Expected Response:**
```json
{
  "detail": "QR токен не найден"
}
```

**HTTP Status:** 401 Unauthorized

**Solution:**
- User scans QR code again
- Ensures QR code is not damaged
- Generates new QR if needed

---

## File Upload Failures

### Scenario 11: File Too Large

**Test:**
```bash
# Create large file (>10MB)
dd if=/dev/urandom of=large.jpg bs=1M count=15

# Try to upload
curl -X POST http://localhost:8000/episodes/1/upload \
  -H "X-API-Key: test-api-key" \
  -F "file=@large.jpg"
```

**Expected Behavior:**
- ✅ Backend rejects file >10MB
- ✅ Returns 413 Payload Too Large
- ✅ App shows "Файл слишком большой (макс. 10MB)"

**Backend Validation:**
```python
# backend/app/routers/episodes.py
@router.post("/{episode_id}/upload")
async def upload_file(
    episode_id: int,
    file: UploadFile = File(...),
):
    # Check file size (10MB limit)
    if file.size > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Файл слишком большой (максимум 10MB)"
        )
```

**Flutter Handling:**
```dart
final file = File(filePath);
final fileSize = await file.length();

if (fileSize > 10 * 1024 * 1024) {
  throw Exception('Файл слишком большой (максимум 10MB)');
}
```

**Solution:**
- Compress image before upload
- Use lower resolution
- Split large files

---

### Scenario 12: Object Storage Unavailable

**Test:**
```bash
# Wrong Yandex credentials in .env
YC_STORAGE_ACCESS_KEY=wrong_key
YC_STORAGE_SECRET_KEY=wrong_secret

# Restart backend
docker-compose restart api

# Try to upload file
```

**Expected Behavior:**
- ✅ S3 client returns authentication error
- ✅ Backend catches error
- ✅ Returns 500 with message
- ✅ File saved locally as fallback

**Backend Error Handling:**
```python
try:
    cloud_url = s3_service.upload_image(file, episode_id)
except Exception as e:
    logger.error(f"S3 upload failed: {e}")
    # Save locally as fallback
    local_path = save_file_locally(file)
    return {"success": False, "local_path": local_path}
```

**Solution:**
1. Check Yandex credentials in `.env`
2. Verify bucket exists and accessible
3. Re-upload failed files

---

## Data Corruption

### Scenario 13: Invalid JSON in Sync Request

**Test:**
```bash
# Send malformed JSON
curl -X POST http://localhost:8000/sync \
  -H "X-API-Key: test-api-key" \
  -H "Content-Type: application/json" \
  -d '{invalid json}'
```

**Expected Response:**
```json
{
  "detail": [
    {
      "type": "json_invalid",
      "loc": ["body"],
      "msg": "JSON decode error"
    }
  ]
}
```

**HTTP Status:** 422 Unprocessable Entity

**Solution:**
- FastAPI validates JSON automatically
- Pydantic schemas ensure data integrity

---

### Scenario 14: Database Constraint Violation

**Test:**
```bash
# Insert episode without child_id
curl -X POST http://localhost:8000/sync \
  -H "X-API-Key: test-api-key" \
  -d '{"episodes":[{"diagnosis":"test","child_id":null}]}'
```

**Expected Behavior:**
- ✅ PostgreSQL raises NOT NULL constraint error
- ✅ Backend rolls back transaction
- ✅ Returns 500 error
- ✅ No partial data inserted

**Backend Transaction:**
```python
try:
    # All operations in transaction
    upsert_model(db, Child, child_data)
    upsert_model(db, Episode, episode_data)
    db.commit()
except Exception as e:
    db.rollback()  # Rollback everything
    raise HTTPException(status_code=500, detail=str(e))
```

**Solution:**
- Flutter validates data before sending
- Backend validates with Pydantic schemas

---

## Resource Exhaustion

### Scenario 15: Memory Leak

**Test:**
```bash
# Monitor memory usage
watch -n 1 'docker stats childs_health_api'

# Send many large sync requests
for i in {1..100}; do
  curl -X POST http://localhost:8000/sync ...
done
```

**Expected Behavior:**
- ✅ Memory usage stays below 500MB
- ✅ No continuous growth
- ✅ Garbage collection works

**Monitoring:**
```bash
# Check container memory
docker stats --no-stream childs_health_api

# If memory grows:
docker-compose restart api
```

**Solution:**
- Set memory limits in `docker-compose.yml`:
```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 512M
```

---

### Scenario 16: Database Connection Pool Exhausted

**Test:**
```bash
# Simulate many concurrent requests
ab -n 1000 -c 100 http://localhost:8000/health
```

**Expected Behavior:**
- ✅ Connection pooling limits connections
- ✅ Requests queue gracefully
- ✅ No database crashes

**Configuration:**
```python
# backend/app/database.py
engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
)
```

**Solution:**
- Increase pool size if needed
- Use connection pooler like PgBouncer

---

## Summary Table

| Scenario | Symptom | Solution | Priority |
|----------|---------|----------|----------|
| No Internet | "Нет подключения" | Enable WiFi/data | High |
| Network Timeout | "Превышено время" | Automatic retry | High |
| Backend Down | "Сервер недоступен" | Admin restarts service | Critical |
| Database Error | 500 error | Admin checks DB | Critical |
| Invalid API Key | 403 Forbidden | Update API key | High |
| Expired QR | "QR истёк" | Generate new QR | Medium |
| Large File | "Файл большой" | Compress file | Medium |
| Object Storage | Upload fails | Check credentials | Medium |
| Invalid JSON | 422 error | Fix client code | Low |
| Memory Leak | High memory | Restart service | Medium |

---

## Testing Procedure

### 1. Automated Tests

```bash
# Run backend tests
cd backend
pytest tests/

# Run Flutter tests
flutter test
```

### 2. Manual Tests

Follow each scenario above with:
1. Test setup
2. Execute action
3. Verify expected behavior
4. Apply solution
5. Verify fix

### 3. Load Testing

```bash
# Install Apache Bench
sudo apt install apache2-utils

# Test sync endpoint
ab -n 1000 -c 50 \
  -H "X-API-Key: test-api-key" \
  -p sync_payload.json \
  -T application/json \
  http://localhost:8000/sync

# Analyze results
# - Requests per second
# - Time per request
# - Failed requests (should be 0)
```

---

## Monitoring Checklist

- [ ] Set up health check monitoring
- [ ] Configure log aggregation
- [ ] Set up alerts for errors
- [ ] Monitor disk space
- [ ] Monitor memory usage
- [ ] Monitor API response times
- [ ] Set up database backup verification

---

**Last Updated**: 2025-11-16
**Tested By**: _____________
**All Scenarios Passed**: ⬜ Yes  ⬜ No
