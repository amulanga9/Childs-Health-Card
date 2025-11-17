# Quick Start Guide

Get the Child's Health Card app running in under 5 minutes.

## Prerequisites

- Flutter 3.0+ ([Install](https://flutter.dev/docs/get-started/install))
- Android Studio or Xcode (for emulators)
- Git

## 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/amulanga9/Childs-Health-Card.git
cd Childs-Health-Card

# Install Flutter dependencies
flutter pub get

# Generate database code
flutter pub run build_runner build --delete-conflicting-outputs
```

## 2. Run the App (Flutter Only)

The app works standalone without the backend:

```bash
# Run on connected device/emulator
flutter run

# Or specify a device
flutter devices
flutter run -d <device-id>
```

**Default Language:** Russian (Русский)
- Change in: Settings → Language → Select English/Uzbek

## 3. First Time Setup

### Create a Child Profile
1. Tap **"+ Добавить ребёнка"** on home screen
2. Fill in child's information:
   - Name (required)
   - Date of birth (required)
   - Gender
   - Photo (optional)
3. Tap **"Сохранить"**

### Add Health Episodes
1. Select a child from home screen
2. Tap **"+ Новый эпизод"**
3. Record illness details:
   - Diagnosis
   - Start/End dates
   - Symptoms
   - Treatment
   - Prescriptions
4. Tap **"Сохранить"**

## 4. Admin Panel Access

### Login
1. Navigate to Admin section (add to app or use direct route)
2. Default credentials:
   - **Password:** `0000`
3. **⚠️ IMPORTANT:** Change password immediately in Admin Settings

### Admin Features
- **Dashboard:** View statistics and recent activity
- **Children:** Manage all child profiles
- **Episodes:** View and manage health episodes
- **Logs:** Audit trail of all admin actions
- **Settings:** Change admin password and name

## 5. Optional: Run with Backend

If you want full cloud sync and QR code features:

### Backend Quick Start

```bash
# Navigate to backend
cd backend

# Create environment file
cp .env.example .env

# Edit .env with your credentials
nano .env

# Start with Docker Compose
docker-compose up -d

# Check status
docker-compose ps
```

### Configure App for Backend

Update `lib/main.dart` line 37-39:

```dart
final apiService = ApiService(
  baseUrl: 'http://YOUR_IP:8000',  // Change from localhost
);
```

**Finding Your IP:**
- Linux/Mac: `ifconfig | grep inet`
- Windows: `ipconfig`

## 6. Common Commands

```bash
# Clean build
flutter clean && flutter pub get

# Regenerate database
flutter pub run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Check for issues
flutter doctor
```

## 7. Troubleshooting

### App won't start?
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Database errors?
- Delete app data on device
- Rebuild with `flutter clean && flutter pub get`

### Backend connection fails?
- Check `baseUrl` in `lib/main.dart`
- Use device IP, not `localhost`
- Verify backend is running: `curl http://YOUR_IP:8000/api/health`

### Build runner issues?
```bash
# Force rebuild
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

## 8. Next Steps

- Read [README.md](README.md) for comprehensive documentation
- Check [ADMIN_GUIDE.md](ADMIN_GUIDE.md) for admin panel details
- Review [API_INTEGRATION.md](API_INTEGRATION.md) for backend setup
- See [SECURITY.md](SECURITY.md) for production security guidelines

## Getting Help

- **Issues:** [GitHub Issues](https://github.com/amulanga9/Childs-Health-Card/issues)
- **Documentation:** See `/docs` folder for detailed guides
- **Email:** contact@childhealthcard.com

---

**Ready in 5 minutes!** 🚀
