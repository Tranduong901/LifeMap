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
