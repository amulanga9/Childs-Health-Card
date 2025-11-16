# Settings Module Setup Guide

Complete guide for setting up and using the Settings module in Child's Health Card app.

## Required Dependencies

Add these packages to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  provider: ^6.1.1

  # Secure storage for PIN and cloud credentials
  flutter_secure_storage: ^9.0.0

  # Persistent settings storage
  shared_preferences: ^2.2.2

  # File operations
  path: ^1.8.3
  path_provider: ^2.1.1

  # Archive operations for backup/restore
  archive: ^3.4.9

  # Permissions
  permission_handler: ^11.1.0

  # File picker for restore
  file_picker: ^6.1.1

  # Routing
  go_router: ^13.0.0

  # Localization
  intl: ^0.18.1

  # Database
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0

  # HTTP
  http: ^1.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter

  build_runner: ^2.4.7
  drift_dev: ^2.14.0
```

## Installation Steps

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Platform-Specific Setup

#### Android Setup

**File: `android/app/src/main/AndroidManifest.xml`**

Add permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.childs_health_card">

    <!-- Storage permissions for backup/restore -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
        tools:ignore="ScopedStorage" />

    <!-- Biometric permission for fingerprint/face unlock -->
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.USE_FINGERPRINT"/>

    <application>
        <!-- ... -->
    </application>
</manifest>
```

**File: `android/app/build.gradle`**

Update minimum SDK version:

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Required for flutter_secure_storage
        targetSdkVersion flutter.targetSdkVersion
    }
}
```

#### iOS Setup

**File: `ios/Runner/Info.plist`**

Add required keys:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to attach medical documents</string>

<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos of medical documents</string>

<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock the app</string>
```

### 3. Verify Installation

Run the app to ensure all dependencies are correctly installed:

```bash
flutter run
```

## Features Overview

### 1. Child Profile Management (up to 5 profiles)

**Access:** Settings → Child Profiles

- ✅ Add child profiles (max 5)
- ✅ Edit profile information:
  - Name
  - Birth date
  - Blood group
  - Allergies
  - Chronic conditions
- ✅ Delete profiles (with confirmation)
- ✅ Automatic age calculation

### 2. Language Switcher

**Access:** Settings → Language

- ✅ Russian (Русский)
- ✅ Uzbek (Oʻzbekcha)
- ✅ English

Language changes apply immediately to the entire app.

### 3. PIN Code Security

**Access:** Settings → Security

**Features:**
- ✅ 4-6 digit PIN code
- ✅ Secure storage using `flutter_secure_storage`
- ✅ PIN verification before removal
- ✅ Biometric authentication (fingerprint/Face ID)
- ✅ Option to require PIN on app start

**Setup:**
1. Toggle "PIN-код" switch
2. Enter 4-6 digit PIN
3. Confirm PIN
4. (Optional) Enable biometrics

**Security:**
- PIN is stored encrypted in system keychain
- Never stored in plain text or SharedPreferences
- Separate from app data

### 4. Backup & Restore

**Access:** Settings → Backup

**Features:**
- ✅ Full database backup to ZIP archive
- ✅ Includes all attachments (photos, PDFs)
- ✅ Metadata file for validation
- ✅ Restore from ZIP file
- ✅ Automatic backup scheduling
- ✅ Last backup timestamp

**Backup Contents:**
```
childs_health_backup_[timestamp].zip
├── database.db (SQLite database)
├── database.db-wal (Write-Ahead Log)
├── database.db-shm (Shared Memory)
├── attachments/
│   ├── episode_1_photo.jpg
│   ├── episode_2_document.pdf
│   └── ...
└── metadata.json (backup info)
```

**Backup Location:**
- **Android:** `/storage/emulated/0/Download/ChildsHealth/`
- **iOS:** `Application Documents/Backups/`

**Creating Backup:**
1. Tap "Create Backup"
2. Wait for completion
3. Backup file saved to Downloads folder

**Restoring Backup:**
1. Tap "Restore from Backup"
2. Select ZIP file
3. Confirm replacement of current data
4. Restart app after restore

⚠️ **Warning:** Restore replaces ALL current data!

### 5. Cloud Storage Configuration

**Access:** Settings → Cloud Storage

**Supported:** Yandex Object Storage (S3-compatible)

**Required Credentials:**
- Endpoint: `https://storage.yandexcloud.net`
- Access Key ID
- Secret Access Key
- Bucket Name

**Setup:**
1. Create Yandex Object Storage bucket
2. Generate access keys in Yandex Cloud Console
3. Enter credentials in Settings
4. Tap "Save"

**Security:**
- Credentials stored encrypted
- Never logged or exposed
- Can be removed anytime

**Getting Yandex Cloud Credentials:**

1. Go to https://console.cloud.yandex.com
2. Create Service Account
3. Assign role: `storage.editor`
4. Generate static access keys
5. Copy Access Key ID and Secret Key
6. Create bucket in Object Storage
7. Enter all values in app settings

### 6. Privacy Settings

**Access:** Settings → Privacy

**Features:**
- ✅ **PIN on Start:** Require PIN every time app opens
- ✅ **Hide in Multitasking:** Blur screen when switching apps

**Recommendations:**
- Enable "PIN on Start" if device is shared
- Enable "Hide in Multitasking" for maximum privacy

### 7. Notifications

**Access:** Settings → Notifications

**Features:**
- ✅ Enable/disable all notifications
- ✅ Medication reminders
- ✅ Upcoming appointment alerts (future)

## Usage Examples

### Example 1: Adding a Child

```dart
// Navigate to settings
context.push('/settings');

// In ChildrenManagementSection:
// 1. Tap "+" button
// 2. Fill in form:
//    - Name: "Иван Петров"
//    - Birth Date: 15.05.2020
//    - Blood Group: "I (O)+"
//    - Allergies: "пенициллин, цитрусовые"
// 3. Tap "Add"
```

### Example 2: Setting up PIN

```dart
// Navigate to Settings → Security
// Toggle "PIN-код" switch

// In dialog:
// 1. Enter PIN: "1234"
// 2. Confirm PIN: "1234"
// 3. Tap "Set"

// Optional: Enable biometrics
// Toggle "Biometry" switch
```

### Example 3: Creating Backup

```dart
final backupService = BackupService(database: database);
final zipPath = await backupService.createBackup();

if (zipPath != null) {
  print('Backup created: $zipPath');
  // ZIP contains: database + all attachment files
}
```

### Example 4: Changing Language

```dart
final settings = context.read<SettingsProvider>();
await settings.setLanguage('uz'); // Switch to Uzbek

// App immediately rebuilds with new locale
// All text updates to Uzbek
```

## Architecture

### Settings Provider

**File:** `lib/presentation/providers/settings_provider.dart`

Manages all settings with `ChangeNotifier`:

```dart
class SettingsProvider with ChangeNotifier {
  final AppDatabase database;
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  // Language
  String _languageCode = 'ru';
  Future<void> setLanguage(String code);

  // PIN
  bool _isPinEnabled = false;
  Future<bool> setPinCode(String pin);
  Future<bool> verifyPinCode(String pin);

  // Cloud
  bool _isCloudEnabled = false;
  Future<bool> setCloudCredentials(...);

  // Children
  List<Child> _children = [];
  Future<bool> addChild(ChildrenCompanion child);

  // ... and more
}
```

### Backup Service

**File:** `lib/services/backup_service.dart`

Handles backup/restore operations:

```dart
class BackupService {
  final AppDatabase database;

  Future<String?> createBackup();        // Create ZIP archive
  Future<bool> restoreBackup(String path); // Restore from ZIP
  Future<List<FileSystemEntity>> getBackupFiles(); // List backups
  Future<bool> deleteBackup(String path);  // Delete old backup
}
```

### Screen Structure

```
SettingsScreen (main container)
├── ChildrenManagementSection
├── LanguageSection
├── SecuritySection
├── PrivacySection
├── BackupSection
├── CloudSection
├── NotificationsSection
├── AboutSection
└── Reset Section (danger zone)
```

## Data Storage

### SharedPreferences (non-sensitive)

```dart
// Stored in SharedPreferences:
- language_code: 'ru'|'uz'|'en'
- pin_enabled: bool
- cloud_enabled: bool
- notifications_enabled: bool
- medication_reminders: bool
- auto_backup: bool
- last_backup_time: int (milliseconds)
- require_pin_on_start: bool
- hide_data_multitasking: bool
- use_biometrics: bool
```

### FlutterSecureStorage (sensitive)

```dart
// Stored encrypted in system keychain:
- pin_code: string
- cloud_endpoint: string
- cloud_access_key: string
- cloud_secret_key: string
- cloud_bucket: string
```

## Security Best Practices

### 1. PIN Code

- ✅ Minimum 4 digits, maximum 6
- ✅ Stored encrypted in system keychain
- ✅ Never exposed in logs
- ✅ Requires current PIN to remove

### 2. Cloud Credentials

- ✅ Encrypted storage
- ✅ Never transmitted unencrypted
- ✅ Separate from backup files
- ✅ Can be removed without data loss

### 3. Backup Files

- ⚠️ ZIP files are **not encrypted**
- ⚠️ Contains full database and attachments
- ⚠️ Store securely
- ✅ Recommended: Encrypt before cloud upload

### 4. Permissions

```dart
// Request only when needed:
- Storage: For backup/restore
- Biometric: For fingerprint/Face ID
- Notifications: For medication reminders
```

## Troubleshooting

### Issue: flutter_secure_storage not working on Android

**Solution:**
```bash
# Update Android SDK version
# In android/app/build.gradle:
minSdkVersion 23  # Required for secure storage
```

### Issue: Backup fails with "Permission Denied"

**Solution:**
```dart
// Request storage permission first
final status = await Permission.storage.request();
if (status.isGranted) {
  await backupService.createBackup();
}
```

### Issue: Restore crashes app

**Solution:**
1. Close database before restore
2. Copy files
3. Restart app

```dart
await database.close();         // Close first
await backupService.restoreBackup(path);
// Restart app required
```

### Issue: Language doesn't change

**Solution:**
Ensure `locale: settings.locale` is set in MaterialApp:

```dart
Consumer<SettingsProvider>(
  builder: (context, settings, _) {
    return MaterialApp(
      locale: settings.locale,  // Dynamic locale
      // ...
    );
  },
)
```

### Issue: Biometrics not available

**Solution:**
Check device capabilities:

```dart
import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();
final canUseBiometrics = await auth.canCheckBiometrics;
final isDeviceSupported = await auth.isDeviceSupported();

if (canUseBiometrics && isDeviceSupported) {
  // Show biometric option
}
```

## Testing

### Unit Tests

```dart
test('Settings provider sets language', () async {
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(
    database: database,
    prefs: prefs,
  );

  await settings.setLanguage('uz');

  expect(settings.languageCode, 'uz');
  expect(settings.locale, Locale('uz'));
});
```

### Integration Tests

```dart
testWidgets('Can add child profile', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.add_circle_outline));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'Test Child');
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();

  expect(find.text('Test Child'), findsOneWidget);
});
```

## API Reference

### SettingsProvider Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `setLanguage` | `String code` | `Future<void>` | Change app language |
| `setPinCode` | `String pin` | `Future<bool>` | Set new PIN code |
| `verifyPinCode` | `String pin` | `Future<bool>` | Verify PIN code |
| `removePinCode` | - | `Future<bool>` | Remove PIN code |
| `setBiometrics` | `bool enabled` | `Future<void>` | Enable/disable biometrics |
| `setCloudCredentials` | `endpoint, accessKey, secretKey, bucket` | `Future<bool>` | Set cloud credentials |
| `removeCloudCredentials` | - | `Future<bool>` | Remove cloud credentials |
| `addChild` | `ChildrenCompanion child` | `Future<bool>` | Add child profile |
| `updateChild` | `Child child` | `Future<bool>` | Update child profile |
| `deleteChild` | `int id` | `Future<bool>` | Delete child profile |
| `setAutoBackup` | `bool enabled` | `Future<void>` | Enable auto backup |
| `setNotifications` | `bool enabled` | `Future<void>` | Enable notifications |
| `resetToDefaults` | - | `Future<void>` | Reset all settings |

### BackupService Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `createBackup` | - | `Future<String?>` | Create ZIP backup |
| `restoreBackup` | `String zipPath` | `Future<bool>` | Restore from ZIP |
| `getBackupFiles` | - | `Future<List<FileSystemEntity>>` | List backups |
| `deleteBackup` | `String path` | `Future<bool>` | Delete backup file |
| `getBackupSize` | `String path` | `Future<int>` | Get backup file size |

## Future Enhancements

- [ ] Cloud backup sync (automatic upload to Object Storage)
- [ ] Biometric authentication for specific features
- [ ] Export to PDF format
- [ ] Import from other apps
- [ ] Multiple backup locations
- [ ] Encrypted backups with password
- [ ] Backup scheduling (daily/weekly)
- [ ] Backup retention policy
- [ ] Multi-language support expansion
- [ ] Theme customization

## Support

For issues or questions:
- GitHub: [Create Issue](https://github.com/yourorg/childs-health-card/issues)
- Email: support@example.com

## License

Proprietary Software. All rights reserved © 2025
