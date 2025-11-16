# API Authentication Guide

**How to authenticate requests to Child's Health Card API**

---

## Overview

The Child's Health Card API uses **API Key authentication** to secure endpoints.

### Protected Endpoints

| Endpoint | Method | Authentication Required |
|----------|--------|-------------------------|
| `/sync` | POST | ✅ Yes |
| `/qr/generate` | POST | ✅ Yes |
| `/qr/{token}` | GET | ❌ No (public for doctors) |
| `/qr/{token}` | DELETE | ✅ Yes |
| `/episodes/{id}/upload` | POST | ✅ Yes |
| `/health` | GET | ❌ No |
| `/` | GET | ❌ No |

---

## Getting an API Key

### Development Environment

For development and testing, use the test API key:

```
test-api-key
```

### Production Environment

Generate a secure API key:

```bash
# Generate secure random key
openssl rand -base64 32

# Example output:
# K3JlZGVudGlhbHNfaGVyZV9jaGFuZ2VfbWVfcHJvZHVjdGlvbg==
```

Set this as your `JWT_SECRET_KEY` in backend `.env` file:

```env
JWT_SECRET_KEY=K3JlZGVudGlhbHNfaGVyZV9jaGFuZ2VfbWVfcHJvZHVjdGlvbg==
```

**⚠️ IMPORTANT**: The API key is the same as `JWT_SECRET_KEY` in development. In production, you should implement a proper API key management system with database storage.

---

## Using the API Key

### HTTP Header

Add the API key to every request in the `X-API-Key` header:

```http
POST /sync HTTP/1.1
Host: api.yourdomain.com
Content-Type: application/json
X-API-Key: test-api-key

{
  "children": [...],
  "episodes": [...]
}
```

### cURL Example

```bash
curl -X POST https://api.yourdomain.com/sync \
  -H "Content-Type: application/json" \
  -H "X-API-Key: test-api-key" \
  -d '{"children":[],"episodes":[],"prescriptions":[],"intakes":[],"tests":[],"procedures":[],"attachments":[]}'
```

### Flutter (Dart) Example

```dart
import 'package:http/http.dart' as http;

final response = await http.post(
  Uri.parse('https://api.yourdomain.com/sync'),
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': 'test-api-key',
  },
  body: jsonEncode({
    'children': [],
    'episodes': [],
    // ...
  }),
);
```

### JavaScript Example

```javascript
fetch('https://api.yourdomain.com/sync', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': 'test-api-key',
  },
  body: JSON.stringify({
    children: [],
    episodes: [],
    // ...
  }),
});
```

### Python Example

```python
import requests

response = requests.post(
    'https://api.yourdomain.com/sync',
    headers={
        'Content-Type': 'application/json',
        'X-API-Key': 'test-api-key',
    },
    json={
        'children': [],
        'episodes': [],
        # ...
    }
)
```

---

## Flutter App Configuration

### 1. Update API Service

In `lib/services/api_service.dart`:

```dart
final apiService = ApiService(
  baseUrl: 'https://api.yourdomain.com',
  apiKey: 'YOUR_PRODUCTION_API_KEY',
);
```

### 2. Secure Storage (Recommended)

Store API key securely using `flutter_secure_storage`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Save API key
await storage.write(key: 'api_key', value: 'YOUR_API_KEY');

// Read API key
final apiKey = await storage.read(key: 'api_key');

// Use in ApiService
final apiService = ApiService(
  baseUrl: 'https://api.yourdomain.com',
  apiKey: apiKey ?? 'default-key',
);
```

### 3. Environment Variables (Alternative)

Create `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'test-api-key',
  );
}
```

Build with environment variables:

```bash
flutter build apk \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=API_KEY=your_production_key
```

---

## Error Responses

### Missing API Key

**Request:**
```bash
curl -X POST https://api.yourdomain.com/sync \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Response:**
```json
{
  "detail": "API ключ отсутствует. Добавьте заголовок: X-API-Key"
}
```

**HTTP Status:** `401 Unauthorized`

**Solution:** Add `X-API-Key` header to your request.

---

### Invalid API Key

**Request:**
```bash
curl -X POST https://api.yourdomain.com/sync \
  -H "Content-Type: application/json" \
  -H "X-API-Key: wrong-key" \
  -d '{}'
```

**Response:**
```json
{
  "detail": "Невалидный API ключ"
}
```

**HTTP Status:** `403 Forbidden`

**Solution:** Verify your API key matches the one in backend `.env` file.

---

## Backend Implementation

### Authentication Dependency

The authentication is implemented in `backend/app/auth.py`:

```python
async def verify_api_key_header(
    x_api_key: Optional[str] = Header(None)
) -> str:
    """Verify API key from X-API-Key header"""
    if not x_api_key:
        raise HTTPException(
            status_code=401,
            detail="API ключ отсутствует. Добавьте заголовок: X-API-Key"
        )

    if not APIKeyAuth.verify_api_key(x_api_key):
        raise HTTPException(
            status_code=403,
            detail="Невалидный API ключ"
        )

    return x_api_key
```

### Protecting Endpoints

Add the dependency to route handlers:

```python
from ..auth import verify_api_key_header

@router.post("/sync")
async def sync_data(
    request: SyncRequest,
    db: Session = Depends(get_db),
    api_key: str = Depends(verify_api_key_header),  # Add this
):
    # API key is validated automatically
    # Proceed with business logic
    pass
```

### Public Endpoints

For public endpoints (like QR data access), don't add the dependency:

```python
@router.get("/qr/{token}")
async def get_qr_data(
    token: str,
    db: Session = Depends(get_db),
    # No api_key dependency
):
    # Public endpoint - no authentication required
    pass
```

---

## Security Best Practices

### 1. Never Hardcode API Keys

❌ **Bad:**
```dart
final apiKey = 'sk_live_abc123def456';
```

✅ **Good:**
```dart
final apiKey = await storage.read(key: 'api_key');
```

### 2. Use HTTPS in Production

❌ **Bad:**
```dart
final baseUrl = 'http://api.yourdomain.com';
```

✅ **Good:**
```dart
final baseUrl = 'https://api.yourdomain.com';
```

### 3. Rotate API Keys Regularly

```bash
# Generate new key
NEW_KEY=$(openssl rand -base64 32)

# Update backend .env
sed -i "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$NEW_KEY/" .env

# Restart backend
docker-compose restart api

# Update Flutter app
# Deploy new version with updated API key
```

### 4. Monitor API Key Usage

```bash
# Check API logs for authentication failures
docker-compose logs api | grep "Невалидный API ключ"

# If you see many failures, key may be compromised
```

### 5. Implement Rate Limiting (Future)

```python
# Future enhancement
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/sync")
@limiter.limit("100/hour")  # Max 100 requests per hour
async def sync_data(...):
    pass
```

---

## Testing Authentication

### 1. Test Without API Key

```bash
curl -X POST http://localhost:8000/sync \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected: 401 Unauthorized
```

### 2. Test With Invalid API Key

```bash
curl -X POST http://localhost:8000/sync \
  -H "X-API-Key: invalid-key" \
  -d '{}'

# Expected: 403 Forbidden
```

### 3. Test With Valid API Key

```bash
curl -X POST http://localhost:8000/sync \
  -H "X-API-Key: test-api-key" \
  -H "Content-Type: application/json" \
  -d '{"children":[],"episodes":[],"prescriptions":[],"intakes":[],"tests":[],"procedures":[],"attachments":[]}'

# Expected: 200 OK
```

### 4. Test Public Endpoints

```bash
# Health check (no auth required)
curl http://localhost:8000/health

# Expected: 200 OK

# QR data access (no auth required)
curl http://localhost:8000/qr/<some-valid-token>

# Expected: 200 OK
```

---

## Troubleshooting

### Problem: "API ключ отсутствует"

**Cause:** Request missing `X-API-Key` header

**Solution:**
```dart
// Ensure headers include API key
headers: {
  'Content-Type': 'application/json',
  'X-API-Key': apiKey,  // Add this
}
```

### Problem: "Невалидный API ключ"

**Cause:** API key doesn't match backend configuration

**Solutions:**
1. Check backend `.env` file:
   ```bash
   cat backend/.env | grep JWT_SECRET_KEY
   ```

2. Verify Flutter app API key:
   ```dart
   print('Using API key: $apiKey');
   ```

3. Ensure they match

### Problem: CORS Error in Browser

**Cause:** CORS not configured for your domain

**Solution:**
Update `backend/.env`:
```env
CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

Restart backend:
```bash
docker-compose restart api
```

### Problem: Request Works in Development, Fails in Production

**Cause:** Different API keys or HTTPS issues

**Solutions:**
1. Check production API key is set correctly
2. Verify HTTPS is working
3. Check backend logs:
   ```bash
   docker-compose logs api | tail -50
   ```

---

## Migration from No Authentication

If you're migrating from the old version without authentication:

### 1. Update Backend

✅ Already done - authentication is now required

### 2. Update Flutter App

**Before:**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/sync'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(data),
);
```

**After:**
```dart
final response = await http.post(
  Uri.parse('$baseUrl/sync'),
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,  // Add this
  },
  body: jsonEncode(data),
);
```

### 3. Deploy Updates

1. Deploy new backend with authentication
2. Update Flutter app API key
3. Build and release new app version
4. Users update app
5. Old app versions will get 401 errors → prompt users to update

---

## FAQ

**Q: Can I use multiple API keys?**

A: Currently, the system supports one API key. In the future, you can implement per-user API keys stored in the database.

**Q: What if my API key is compromised?**

A: Generate a new key, update backend `.env`, restart backend, and deploy new app version.

**Q: Can I disable authentication for testing?**

A: Not recommended. Use the test API key `test-api-key` for local development.

**Q: How do I implement per-user API keys?**

A: Create a `api_keys` table in PostgreSQL:
```sql
CREATE TABLE api_keys (
  id SERIAL PRIMARY KEY,
  key VARCHAR(64) UNIQUE NOT NULL,
  user_id INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,
  active BOOLEAN DEFAULT TRUE
);
```

Update `verify_api_key()` to query this table.

---

## Reference

### Backend Files
- `backend/app/auth.py` - Authentication logic
- `backend/app/routers/sync.py` - Protected sync endpoint
- `backend/app/routers/qr.py` - QR endpoints (mixed)
- `backend/app/config.py` - Environment validation

### Flutter Files
- `lib/services/api_service.dart` - API client with authentication
- `lib/core/error_handler.dart` - Error handling for auth failures

### Configuration Files
- `backend/.env` - Backend environment variables
- `backend/docker-compose.yml` - Docker configuration

---

**Last Updated**: 2025-11-16
**API Version**: 1.0.0
**Authentication Method**: API Key (X-API-Key header)
