# LifeMap

LifeMap là ứng dụng Flutter lưu giữ kỷ niệm theo địa điểm, thời gian và hồ sơ cá nhân.

## Chức năng hiện có

### 🔐 Xác thực & Tài khoản
- **Xác thực người dùng bằng Firebase Authentication:**
	- Đăng nhập Email/Mật khẩu
	- Đăng ký Email/Mật khẩu
	- Đăng nhập Google
	- Liên kết tài khoản Google
	- Đăng xuất
- **Quản lý hồ sơ người dùng (Firestore):**
	- uid, email, displayName, photoUrl, createdAt
	- Upload & cập nhật ảnh đại diện công khai
	- Xem thông tin hồ sơ cá nhân

### 📍 Quản lý Kỷ niệm
- **Thêm kỷ niệm mới:**
	- Tiêu đề, mô tả chi tiết
	- Chụp/tải lên nhiều ảnh (qua camera hoặc thư viện)
	- Tự động lấy vị trí GPS hiện tại + độ chính xác
	- Tự động lấy địa chỉ từ toạ độ (reverse geocoding)
	- Chỉnh sửa thủ công địa chỉ nếu cần
	- Chọn ngày/giờ kỷ niệm
	- Gắn tag chủ đề (topic) cho từng kỷ niệm
- **Xem & quản lý kỷ niệm:**
	- Danh sách kỷ niệm theo thời gian (Timeline)
	- Xem chi tiết từng kỷ niệm
	- Chỉnh sửa kỷ niệm đã lưu
	- Xóa kỷ niệm
- **Hỗ trợ offline:**
	- Lưu queue các thao tác khi mất kết nối
	- Tự động đồng bộ khi kết nối lại
	- Sử dụng SharedPreferences cho bộ nhớ cache

### 🗺️ Bản đồ & Vị trí
- **Hiển thị kỷ niệm trên bản đồ:**
	- Hỗ trợ Mapbox (nâng cao, cần token) hoặc OpenStreetMap (miễn phí)
	- Hiển thị markers cho từng kỷ niệm
	- Zoom động đến vị trí
	- Kéo & zoom trên bản đồ
- **Chức năng tìm kiếm:**
	- Tìm kỷ niệm theo tiêu đề
	- Lọc theo các chủ đề (topic)
	- Kết quả hiển thị trực tiếp trên bản đồ
- **Xác định vị trí:**
	- GPS (geolocator)
	- Reverse geocoding cho web (OpenStreetMap Nominatim) và mobile
	- Hiển thị độ chính xác GPS

### 👤 Trang Cá nhân & Thống kê
- **Quản lý tài khoản:**
	- Hiển thị thông tin người dùng
	- Đổi ảnh đại diện
	- Đăng xuất
- **Thống kê & Biểu đồ:**
	- Xem số lượng kỷ niệm theo tháng/năm
	- Biểu đồ cột, biểu đồ tròn (sử dụng fl_chart)
	- Xem tổng số kỷ niệm, số ảnh đã tải lên

### 🖼️ Quản lý Hình ảnh
- **Tải lên ảnh:**
	- Upload lên Cloudinary (không sử dụng Firebase Storage)
	- Tự động nén ảnh trước khi upload
	- Hỗ trợ chụp trực tiếp từ camera
	- Hỗ trợ chọn từ thư viện hình ảnh
	- Hỗ trợ upload nhiều ảnh cho 1 kỷ niệm
- **Hiệu suất:**
	- Cache ảnh (cached_network_image)
	- Retry + timeout cho upload

### 📱 Giao diện
- **Điều hướng chính:**
	- BottomNavigationBar với 3 tab chính
	- IndexedStack để lưu trạng thái mỗi tab
- **Màn hình chính:**
	1. Bản đồ (Map)
	2. Kỷ niệm / Dòng thời gian (Timeline)
	3. Cá nhân (Profile)

### 🔧 Tính năng Kỹ thuật
- **Xử lý kết nối:**
	- Theo dõi trạng thái mạng (connectivity_plus)
	- Queue các thao tác khi offline
	- Tự động đồng bộ khi online
	- Retry thông minh cho các thao tác thất bại
- **Bảo mật:**
	- Firestore Rules: chỉ cho phép user truy cập dữ liệu của chính họ
- **Hỗ trợ đa nền tảng:**
	- Web (Flutter Web)
	- Android (Mapbox + OpenStreetMap)
	- iOS (Mapbox + OpenStreetMap)

## Cấu trúc chính

### Services (Dịch vụ)
- `lib/services/auth_service.dart` - Xách toàn bộ logic xác thực (đăng nhập, đăng ký, Google Sign-In)
- `lib/services/memory_service.dart` - CRUD kỷ niệm, queue offline, theo dõi kết nối
- `lib/services/cloudinary_service.dart` - Upload & quản lý ảnh trên Cloudinary
- `lib/services/location_service.dart` - Cấp tọa độ GPS, reverse geocoding
- `lib/services/database_service.dart` - Truy vấn database Firestore
- `lib/services/firebase_service.dart` - Cấu hình Firebase
- `lib/services/map_service.dart` - Hỗ trợ bản đồ

### Models (Mô hình dữ liệu)
- `lib/models/memory_model.dart` - Mô hình kỷ niệm (id, userId, title, description, imageUrl, topic, location, date, address)
- `lib/models/memory_topic.dart` - Mô hình chủ đề/tag

### Views (Giao diện)
- `lib/views/main_screen.dart` - Khung chính với BottomNavigationBar + 3 tab
- `lib/views/auth/auth_view.dart` - Giao diện đăng nhập/đăng ký
- `lib/views/map/map_view.dart` - Bản đồ với markers, tìm kiếm, lọc chủ đề
- `lib/views/timeline/timeline_view.dart` - Danh sách kỷ niệm dạng timeline
- `lib/views/timeline/add_memory_view.dart` - Form thêm/chỉnh sửa kỷ niệm
- `lib/views/timeline/memory_detail_view.dart` - Xem chi tiết kỷ niệm
- `lib/views/timeline/camera_capture_view.dart` - Chụp ảnh từ camera
- `lib/views/profile/profile_view.dart` - Hồ sơ người dùng, thống kê, đổi avatar

### Providers
- `lib/providers/main_navigation_provider.dart` - Quản lý trạng thái điều hướng chính

### Main Entry Point
- `lib/main.dart` - Khởi tạo Firebase, AuthWrapper, Theme

## Tech Stack

### Backend & Database
- **Firebase Core** (^3.15.0) - Cấu hình Firebase
- **Firebase Auth** (^5.6.0) - Xác thực người dùng
- **Cloud Firestore** (^5.6.0) - Database thời gian thực
- **Google Sign-In** (^6.3.0) - Đăng nhập Google

### Bản đồ
- **Mapbox Maps Flutter** (^2.8.0) - Bản đồ nâng cao (tùy chọn)
- **Flutter Map** (^7.0.2) - Bản đồ OpenStreetMap (miễn phí)
- **Latlong2** (^0.9.1) - Xử lý tọa độ

### Vị trí & Địa chỉ
- **Geolocator** (^13.0.2) - Lấy GPS hiện tại
- **Geocoding** (^4.0.0) - Reverse geocoding (mobile)
- **HTTP** (^1.6.0) - Gọi API Nominatim (web)

### Ảnh & Camera
- **Camera** (^0.11.1) - Chụp ảnh từ camera
- **Image Picker** (^0.8.7+5) - Chọn ảnh từ thư viện
- **Flutter Image Compress** (^2.4.0) - Nén ảnh
- **Cloudinary Public** (^0.23.1) - Upload ảnh lên Cloudinary
- **Cached Network Image** (^3.4.1) - Cache ảnh từ URL

### Trạng thái & UI
- **Provider** (^6.1.5) - Quản lý trạng thái
- **FL Chart** (^0.69.2) - Biểu đồ thống kê
- **Cupertino Icons** (^1.0.8) - Icon iOS

### Lưu trữ & Offline
- **Shared Preferences** (^2.3.2) - Lưu dữ liệu cục bộ (queue offline)
- **Path Provider** (^2.0.15) - Truy cập đường dẫn hệ thống

### Kết nối
- **Connectivity Plus** (^6.1.1) - Theo dõi trạng thái mạng

### Quốc tế hóa
- **Intl** (^0.20.2) - Định dạng ngày/giờ, ngôn ngữ

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
