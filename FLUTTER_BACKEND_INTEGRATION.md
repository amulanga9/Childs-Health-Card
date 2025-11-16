# Flutter Backend Integration Guide

Complete guide for integrating the Child's Health Card Flutter app with the FastAPI backend.

## Overview

This document describes the integration between the Flutter mobile application and the FastAPI backend, including data synchronization, QR code generation for doctor access, and file uploads to Yandex Object Storage.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Flutter App (Mobile Client)                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Local Database (Drift/SQLite)                   │  │
│  │  - Child, Episode, Prescription, Intake          │  │
│  │  - Test, Procedure, Attachment                   │  │
│  └──────────────────────────────────────────────────┘  │
│                        ▲                                 │
│                        │                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Providers (State Management)                    │  │
│  │  - HomeProvider, QRProvider, SyncProvider        │  │
│  │  - EpisodeDetailProvider                         │  │
│  └──────────────────────────────────────────────────┘  │
│                        ▲                                 │
│                        │                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  API Service (HTTP Client)                       │  │
│  │  - syncData(), generateQRToken()                 │  │
│  │  - uploadFile(), invalidateQRToken()             │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP/REST
                      │ JSON
                      ▼
┌─────────────────────────────────────────────────────────┐
│          FastAPI Backend (Server)                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Routers                                         │  │
│  │  - /sync (POST)                                  │  │
│  │  - /qr/generate (POST)                           │  │
│  │  - /qr/{token} (GET, DELETE)                     │  │
│  │  - /episodes/{id}/upload (POST)                  │  │
│  └──────────────────────────────────────────────────┘  │
│                        ▲                                 │
│                        │                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Services                                        │  │
│  │  - S3Service (Object Storage)                    │  │
│  │  - QRService (Token & QR generation)             │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────┬───────────────┬───────────────────┘
                      │               │
                      ▼               ▼
            ┌──────────────┐  ┌──────────────────┐
            │  PostgreSQL  │  │ Yandex Object    │
            │  (Data)      │  │ Storage (Files)  │
            └──────────────┘  └──────────────────┘
```

## Features Implemented

### 1. Data Synchronization

The app can sync all local data to the backend server.

#### Flutter Side

**Provider: `SyncProvider`**
- Location: `lib/presentation/providers/sync_provider.dart`
- Methods:
  - `syncAll()`: Syncs all data from local Drift database to backend
  - Collects: Children, Episodes, Prescriptions, Intakes, Tests, Procedures, Attachments
  - Returns: `bool` (success/failure)

**API Service Method:**
```dart
Future<Map<String, dynamic>> syncData({
  required List<Child> children,
  required List<Episode> episodes,
  required List<Prescription> prescriptions,
  required List<Intake> intakes,
  required List<Test> tests,
  required List<Procedure> procedures,
  required List<Attachment> attachments,
}) async
```

**UI Integration:**
- Home screen has a sync button in the app bar
- Location: `lib/presentation/screens/home_screen.dart:100-118`
- Shows sync status with loading indicator
- Displays last sync time in tooltip
- Shows success/error snackbar after sync

#### Backend Side

**Endpoint: `POST /sync`**
- Location: `backend/app/routers/sync.py`
- Accepts all entity types in JSON format
- Uses upsert logic based on `mobile_id` field
- Returns sync statistics

**Upsert Logic:**
```python
def upsert_model(db: Session, model_class, data: dict) -> int:
    mobile_id = data.get("mobile_id")
    existing = db.query(model_class).filter(
        model_class.mobile_id == mobile_id
    ).first()

    if existing:
        # Update existing record
        for key, value in data.items():
            setattr(existing, key, value)
    else:
        # Insert new record
        new_obj = model_class(**data)
        db.add(new_obj)

    db.commit()
    return existing.id if existing else new_obj.id
```

### 2. QR Code Generation for Doctors

Parents can generate temporary QR codes that give doctors access to medical data.

#### Flutter Side

**Provider: `QRProvider`**
- Location: `lib/presentation/providers/qr_provider.dart`
- Features:
  - Child selection
  - Episode selection (optional, defaults to latest)
  - Configurable expiration time (24h, 48h, 72h)
  - QR token generation
  - Token invalidation

**Screen: `QRGeneratorScreen`**
- Location: `lib/presentation/screens/qr_generator_screen.dart`
- Flow:
  1. User selects child
  2. Optionally selects specific episode
  3. Sets expiration time
  4. Generates QR code
  5. Displays QR image with web URL
  6. Can copy URL or invalidate token

**Navigation:**
- Route: `/qr-generator`
- Accessible from bottom navigation bar in home screen

#### Backend Side

**Endpoint: `POST /qr/generate`**
- Request body:
```json
{
  "child_id": 1,
  "episode_id": 5,
  "description": "For pediatrician visit",
  "expire_hours": 48
}
```
- Response:
```json
{
  "token": "xYz123...",
  "qr_image_url": "https://storage.yandexcloud.net/.../qr_xYz123.png",
  "expires_at": "2025-11-18T12:00:00Z",
  "web_url": "https://yourdomain.com/doctor/view/xYz123..."
}
```

**Endpoint: `GET /qr/{token}`**
- Returns complete medical data for the token
- Includes:
  - Child information (name, birth date, blood group, allergies)
  - Latest episode details
  - Prescriptions with intake history
  - Tests and procedures
  - Attachments (with cloud URLs)
  - Yearly statistics

**Endpoint: `DELETE /qr/{token}`**
- Invalidates the token
- Doctor can no longer access data

**QR Service:**
- Location: `backend/app/services/qr_service.py`
- Features:
  - Token generation (128-character random string)
  - QR image generation using `qrcode` library
  - Upload QR image to Yandex Object Storage
  - Token validation and expiration checking
  - Access tracking (count, last accessed time)

### 3. File Upload to Cloud Storage

Medical documents (photos, PDFs) are automatically uploaded to Yandex Object Storage.

#### Flutter Side

**Enhanced Method in `EpisodeDetailProvider`:**
```dart
Future<bool> addAttachmentWithUpload({
  required File file,
  required String kind,
}) async
```

**Process:**
1. User selects file (image/PDF)
2. File is uploaded to backend via multipart request
3. Backend compresses images (max 1MB) and stores in S3
4. Backend returns `cloud_key` and `cloud_url`
5. Attachment record is created in local database with cloud reference
6. If upload fails, file is saved locally only

**API Service Method:**
```dart
Future<FileUploadResponse> uploadFile({
  required int episodeId,
  required File file,
}) async
```

#### Backend Side

**Endpoint: `POST /episodes/{episode_id}/upload`**
- Accepts multipart/form-data with file
- Validates file type
- Compresses images if needed
- Uploads to Yandex Object Storage
- Returns:
```json
{
  "success": true,
  "cloud_key": "episodes/5/photo_20251116_123456.jpg",
  "cloud_url": "https://storage.yandexcloud.net/bucket/episodes/5/photo_20251116_123456.jpg",
  "file_size": 524288
}
```

**S3 Service:**
- Location: `backend/app/services/s3_service.py`
- Features:
  - Automatic image compression (PIL/Pillow)
  - Quality reduction loop until < 1MB
  - Organized folder structure in S3
  - Presigned URL generation (optional, for temporary access)
  - S3-compatible API (works with Yandex Object Storage)

**Image Compression Logic:**
```python
def compress_image(self, image_data: bytes, max_size: int = 1024 * 1024) -> bytes:
    if len(image_data) <= max_size:
        return image_data

    image = Image.open(io.BytesIO(image_data))
    quality = 85

    while quality > 20:
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG', quality=quality, optimize=True)
        compressed = buffer.getvalue()

        if len(compressed) <= max_size:
            return compressed

        quality -= 5

    return compressed
```

## Configuration

### Flutter App Configuration

**API Base URL:**
- Location: `lib/main.dart:29`
- Default: `http://localhost:8000`
- **TODO:** Change to production URL before deployment

```dart
final apiService = ApiService(
  baseUrl: 'http://localhost:8000', // Change this to production URL
);
```

**For Android Emulator:**
```dart
baseUrl: 'http://10.0.2.2:8000', // localhost from Android emulator
```

**For iOS Simulator:**
```dart
baseUrl: 'http://localhost:8000', // Works directly
```

**For Production:**
```dart
baseUrl: 'https://api.yourdomain.com',
```

### Backend Configuration

**Environment Variables:**
- Location: `backend/.env`
- Template: `backend/.env.example`

Required variables:
```bash
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/childs_health_db

# Yandex Object Storage (S3-compatible)
YC_STORAGE_ACCESS_KEY=your_access_key
YC_STORAGE_SECRET_KEY=your_secret_key
YC_STORAGE_BUCKET_NAME=childs-health-files
YC_STORAGE_ENDPOINT=https://storage.yandexcloud.net
YC_STORAGE_REGION=ru-central1

# JWT for future authentication
JWT_SECRET_KEY=your-super-secret-key-change-in-production
JWT_ALGORITHM=HS256

# QR Token settings
QR_TOKEN_EXPIRE_HOURS=48

# CORS (adjust for production)
CORS_ORIGINS=http://localhost:3000,https://yourdomain.com

# App settings
APP_NAME="Child's Health Card API"
APP_VERSION=1.0.0
DEBUG=false
```

## Deployment

### Backend Deployment

See `backend/README.md` and `YANDEX_CLOUD_DEPLOY.md` for complete deployment instructions.

**Quick Docker Deployment:**
```bash
cd backend
docker-compose up -d
```

**Production Deployment to Yandex Cloud:**
1. Create Object Storage bucket
2. Setup Managed PostgreSQL
3. Deploy to Compute Instance or Serverless Containers
4. Configure Application Load Balancer
5. Setup SSL/TLS certificates

Estimated monthly cost: **1330-1830₽** (~$14-19 USD)

### Flutter App Deployment

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

**Important:** Update API base URL before building for production!

## Testing

### Local Testing Setup

1. **Start Backend:**
```bash
cd backend
docker-compose up -d
# API available at http://localhost:8000
# Docs at http://localhost:8000/docs
```

2. **Configure Flutter App:**
```dart
// In lib/main.dart
final apiService = ApiService(
  baseUrl: 'http://10.0.2.2:8000', // For Android emulator
  // or 'http://localhost:8000' for iOS simulator
);
```

3. **Run Flutter App:**
```bash
flutter run
```

### Testing Data Sync

1. Create test data in the Flutter app (children, episodes)
2. Tap the sync button in home screen app bar
3. Check backend database:
```bash
docker exec -it childs_health_db psql -U childs_health -d childs_health_db
SELECT * FROM children;
SELECT * FROM episodes;
```

### Testing QR Generation

1. Navigate to QR Generator screen from bottom nav
2. Select a child
3. Select an episode (or use default)
4. Set expiration time
5. Generate QR code
6. Verify QR image displays correctly
7. Test web URL access:
```bash
curl http://localhost:8000/qr/{token}
```

### Testing File Upload

1. Open an episode detail screen
2. Add an attachment (photo or PDF)
3. Check upload progress
4. Verify file appears in Yandex Object Storage:
```bash
aws s3 ls s3://your-bucket/episodes/ --endpoint-url https://storage.yandexcloud.net
```

## API Reference

### Complete Endpoint List

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/sync` | Sync all data from mobile to server |
| POST | `/qr/generate` | Generate QR token for doctor access |
| GET | `/qr/{token}` | Get medical data by QR token |
| DELETE | `/qr/{token}` | Invalidate QR token |
| GET | `/episodes/{id}` | Get episode details |
| POST | `/episodes/{id}/upload` | Upload file to episode |

### Authentication

**Current:** No authentication required (development)

**Production TODO:**
- Implement user authentication (JWT)
- Add API key for mobile app
- Secure QR endpoints with additional verification
- Rate limiting for all endpoints

## Security Considerations

### Current Implementation

✅ **Implemented:**
- QR token expiration (configurable, default 48h)
- Token invalidation support
- HTTPS-ready backend
- Environment variable configuration
- SQL injection protection (SQLAlchemy ORM)

⚠️ **TODO for Production:**
- Add user authentication (JWT)
- Implement API rate limiting
- Add CAPTCHA for QR generation
- Encrypt sensitive data at rest
- Add audit logging
- Implement HIPAA/GDPR compliance measures
- Add file type validation and virus scanning
- Limit file upload sizes
- Add input validation middleware

### Recommended Security Headers

Add to FastAPI app:
```python
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware

app.add_middleware(HTTPSRedirectMiddleware)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["yourdomain.com"])
```

## Troubleshooting

### Common Issues

**1. Connection Refused (Android Emulator)**
- Problem: `http://localhost:8000` doesn't work
- Solution: Use `http://10.0.2.2:8000` instead

**2. CORS Errors**
- Problem: Browser shows CORS policy error
- Solution: Add your domain to `CORS_ORIGINS` in `.env`

**3. File Upload Fails**
- Problem: Large files fail to upload
- Solution: Check Yandex Storage credentials and bucket permissions

**4. QR Image Not Loading**
- Problem: QR image URL returns 404
- Solution: Verify Object Storage bucket is public-readable for QR images

**5. Sync Takes Too Long**
- Problem: Sync timeout on large datasets
- Solution: Implement batch sync or pagination in future version

### Debug Mode

Enable debug output in Flutter:
```dart
// In api_service.dart
debugPrint('API Request: $url');
debugPrint('API Response: ${response.body}');
```

Enable debug output in FastAPI:
```bash
# In .env
DEBUG=true
```

## Future Enhancements

### Planned Features

- [ ] Real-time sync using WebSockets
- [ ] Offline-first architecture with conflict resolution
- [ ] Push notifications for medication reminders
- [ ] Multi-language support (RU/UZ/EN already in Flutter)
- [ ] PDF export of medical history
- [ ] Integration with medical systems (FHIR)
- [ ] Biometric authentication
- [ ] Family sharing (multiple parents accessing same child data)
- [ ] Doctor portal (web interface for QR access)
- [ ] Analytics and insights dashboard

### Performance Optimizations

- [ ] Implement delta sync (only changed records)
- [ ] Add pagination for large datasets
- [ ] Cache frequently accessed data
- [ ] Compress JSON payloads
- [ ] Use GraphQL for flexible queries
- [ ] Implement CDN for static assets

## Support & Documentation

### Additional Resources

- **Backend API Docs:** http://localhost:8000/docs (Swagger UI)
- **Backend README:** `backend/README.md`
- **Deployment Guide:** `YANDEX_CLOUD_DEPLOY.md`
- **Database Schema:** `DATABASE.md`
- **Episode Screen Docs:** `EPISODE_SCREEN_DOCUMENTATION.md`

### Getting Help

1. Check the documentation above
2. Review error logs:
   - Flutter: Run with `flutter run --verbose`
   - Backend: `docker-compose logs -f api`
3. Test endpoints with Swagger UI: http://localhost:8000/docs
4. Check database state directly using psql

## License

Proprietary software. All rights reserved.

## Contributors

Development by Anthropic Claude Code Assistant (2025)
