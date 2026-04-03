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

### 2. Mapbox

MapView đọc token từ dart-define:

- MAPBOX_ACCESS_TOKEN

Nếu thiếu token, màn hình Bản đồ sẽ hiển thị thông báo hướng dẫn.

## Chạy dự án

### Cài dependencies

flutter pub get

### Chạy Web (Chrome)

flutter run -d chrome --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_MAPBOX_TOKEN

### Kiểm tra mã nguồn

flutter analyze

## Ghi chú

- Dự án đang ưu tiên luồng Web và xác thực Firebase.
- Các màn hình hiện tại là khung nền tảng để tiếp tục phát triển tính năng chi tiết kỷ niệm.
