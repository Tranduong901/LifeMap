# LifeMap

LifeMap là ứng dụng Flutter lưu giữ kỷ niệm theo địa điểm, thời gian và hồ sơ cá nhân.

## Chức năng hiện có

- Xác thực người dùng bằng Firebase Authentication:
	- Đăng nhập Email/Mật khẩu
	- Đăng ký Email/Mật khẩu
	- Đăng nhập Google
	- Đăng xuất
- Lưu hồ sơ người dùng vào Firestore collection users khi đăng ký:
	- uid
	- email
	- displayName
	- photoUrl
	- createdAt
- Điều hướng chính bằng BottomNavigationBar + IndexedStack với 3 màn hình:
	- Bản đồ
	- Kỷ niệm (Dòng thời gian)
	- Cá nhân
- Màn hình Bản đồ dùng Mapbox
- Màn hình Kỷ niệm dùng ListView.builder + Card + ListTile
- Màn hình Cá nhân hiển thị thông tin FirebaseAuth.instance.currentUser
- Upload ảnh bằng Cloudinary (không dùng Firebase Storage)

## Cấu trúc chính

- lib/main.dart: khởi tạo Firebase và AuthWrapper
- lib/views/main_screen.dart: khung điều hướng 3 tab
- lib/views/auth/auth_view.dart: giao diện đăng nhập/đăng ký
- lib/views/map/map_view.dart: bản đồ Mapbox + nút thêm kỷ niệm
- lib/views/timeline/timeline_view.dart: danh sách kỷ niệm
- lib/views/profile/profile_view.dart: hồ sơ người dùng + đăng xuất
- lib/services/auth_service.dart: xử lý toàn bộ logic xác thực

## Yêu cầu cấu hình

### 1. Firebase

- Đã thêm cấu hình Web trong main.dart bằng FirebaseOptions.
- Bật Email/Mật khẩu và Google trong Firebase Authentication.
- Đảm bảo Firestore Rules cho phép user ghi tài liệu users/{uid} của chính họ.
- Lưu ý: Firebase chỉ dùng cho Auth + Firestore metadata, không dùng để lưu file ảnh.

### 1.1 Google Sign-In Android (SHA-1)

Chạy script kiểm tra SHA-1 hiện tại có khớp với `google-services.json` hay không:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_sha1.ps1
```

Nếu kết quả `SHA-1 CHUA KHOP`, vào Firebase Console và thêm fingerprint SHA-1 debug, sau đó tải lại file `android/app/google-services.json`.

Kiểm tra SHA-1 release (khi có keystore phát hành):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check_release_sha1.ps1 -KeystorePath .\android\app\upload-keystore.jks -Alias upload -StorePass <store-pass> -KeyPass <key-pass>
```

### 1.2 Cloudinary

- Ảnh được nén và upload trực tiếp lên Cloudinary.
- Service có retry + timeout để tăng độ ổn định khi mạng yếu.

### 2. Bản đồ

- Mặc định app dùng bản đồ miễn phí OpenStreetMap (không cần token).
- Nếu muốn dùng Mapbox, truyền token bằng dart-define:

	- MAPBOX_ACCESS_TOKEN

## Chạy dự án

### Cài dependencies

```powershell
flutter pub get
```

### Chạy Web (Chrome)

```powershell
flutter run -d chrome --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN
```

Hoặc chạy bản miễn phí không cần token:

```powershell
flutter run -d chrome
```

### Chạy Android

```powershell
flutter run
```

### Kiểm tra mã nguồn

```powershell
flutter analyze
```

## Firestore Rules (bảo mật theo userId)

File rules đang dùng: `firestore.rules`.

Deploy rules lên Firebase:

```powershell
firebase deploy --only firestore:rules
```

Nếu chưa đăng nhập Firebase CLI:

```powershell
firebase login
firebase use android-final-2f2ea
firebase deploy --only firestore:rules
```

## Ghi chú

- Dự án đang ưu tiên luồng Web và xác thực Firebase.
- Các màn hình hiện tại là khung nền tảng để tiếp tục phát triển tính năng chi tiết kỷ niệm.

## Bảo mật cấu hình

- Không commit file thật `android/app/google-services.json` và `ios/Runner/GoogleService-Info.plist` lên Git.
- Dùng file mẫu trong repo, còn file thật tự đặt ở máy local hoặc trong pipeline secrets.
- Nếu lỡ commit key/public config, cần xoay (rotate) API key trong Firebase/Cloudinary.

Thiết lập nhanh Android local:

```powershell
Copy-Item android/app/google-services.example.json android/app/google-services.json
# Sau đó thay toàn bộ nội dung bằng file thật tải từ Firebase Console.
```

Lưu ý quan trọng:

- Firebase project ở `lib/main.dart` (Web/Desktop) phải cùng project với `google-services.json` (Android), nếu không sẽ phát sinh lỗi quyền Firestore/Google Sign-In không nhất quán.

## CI cơ bản

Pipeline nên chạy ở mỗi Pull Request:

- `flutter pub get`
- `dart format --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`

## Checklist QA trước merge

- Đăng ký/đăng nhập email.
- Google Sign-In Android và Web.
- Thêm/sửa/xóa kỷ niệm.
- Upload đa ảnh, slideshow hiển thị đúng.
- Map search + lọc theo chủ đề.
- Offline tạo/sửa/xóa, online lại thì đồng bộ.

## Checklist phát hành

- Android:
	- Cấu hình keystore release.
	- Thêm SHA-1 release vào Firebase.
	- Build `flutter build apk --release` hoặc `flutter build appbundle`.
- iOS:
	- Cấu hình Signing & Capabilities trong Xcode.
	- Build bằng `flutter build ipa` khi đã có provisioning profile hợp lệ.
