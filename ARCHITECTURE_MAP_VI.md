# 🗺️ BẢN ĐỒ DỰ ÁN LIFEMAP - HƯỚNG DẪN KIẾN TRÚC CHI TIẾT

**Dự án:** LifeMap - Ứng dụng Lưu trữ Kỷ niệm trên Bản đồ  
**Nhóm:** Nhóm 7 - Thủy Lợi  
**Ngôn ngữ:** Dart/Flutter  
**Cấu trúc:** MVC + Provider Pattern + Firestore Real-time  

---

## 📋 MỤC LỤC

1. [Sơ đồ Luồng Màn hình](#sơ-đồ-luồng-màn-hình)
2. [Chi tiết Từng Màn hình](#chi-tiết-từng-màn-hình)
3. [Danh sách Widget Dùng Chung](#danh-sách-widget-dùng-chung)
4. [Tóm tắt hệ thống Thiết kế](#tóm-tắt-hệ-thống-thiết-kế)
5. [Luồng Dữ liệu Firestore](#luồng-dữ-liệu-firestore)
6. [Hướng dẫn Bảo trì & Chỉnh sửa](#hướng-dẫn-bảo-trì--chỉnh-sửa)

---

## 🔄 SƠ ĐỒ LUỒNG MÀNG HÌNH

### Kiến trúc Tổng thể

```
┌─────────────────────────────────────────────────┐
│           lib/main.dart (AuthWrapper)           │
│   StreamBuilder(FirebaseAuth.authStateChanges)  │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    [AuthView]      [MainScreen]
    (Chưa đăng      (Đã đăng nhập)
     nhập)          - MapView
                    - TimelineView
                    - ProfileView
```

### Chuyển màn hình Chi tiết

| Từ Màn hình | Nhấn nút/hành động | Tới Màn hình | Loại Chuyển | Ghi chú |
|-----------|-----------|-----------|-----------|-----------|
| **AuthView** | Đăng ký thành công | MainScreen | pushReplacement | Qua FirebaseAuth stream |
| **AuthView** | Đăng nhập thành công | MainScreen | (stream reroute) | Không push, stream listener xử lý |
| **Main Screen** | Tab Bản đồ ↔ Kỷ niệm ↔ Cá nhân | Giữa các tab | Tab switching (không push) | Provider state quản lý |
| **MapView** | Nhấn nút cộng (+) | AddMemoryView | push | Tạo kỷ niệm mới |
| **MapView** | Nhấn marker → "Xem chi tiết" | MemoryDetailView | push | Qua BottomSheet CTA |
| **TimelineView** | Nhấn memory card | MemoryDetailView | push | Xem chi tiết kỷ niệm |
| **TimelineView** | Nhấn nút Edit (ba chấm) | AddMemoryView | push | Sửa kỷ niệm (preload initialMemory) |
| **MemoryDetailView** | Nhấn nút Edit (app bar) | AddMemoryView | push | Sửa kỷ niệm (preload initialMemory) |
| **AddMemoryView** | Nhấn nút Camera | CameraCaptureView | push | Chụp/chọn ảnh |
| **AddMemoryView** | Nhấn Save | (pop true) | pop | Return to caller nếu edit |
| **CameraCaptureView** | Chụp ảnh hoặc chọn Gallery | (pop XFile) | pop | Return XFile to AddMemory |
| **ProfileView** | Nhấn Logout | AuthView | (stream reroute) | signOut() trigger auth stream |

---

## 🎨 CHI TIẾT TỪ TỪNG MÀN HÌNH

### 1. **AuthView** - Đăng nhập / Đăng ký

**📍 Đường dẫn:** `lib/views/auth/auth_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Cấu trúc UI

```
┌─────────────────────────┐
│   Gradient Background    │
│  (#FFF8EE → #E7F1FF)    │
├─────────────────────────┤
│   AnimatedSwitcher      │
│   ├─ Login Form OR      │
│   └─ Signup Form        │
│      - Email field      │
│      - Password field   │
│      - Confirm pwd field│
│   ├─ Google button      │
│   └─ Switch/Forgot link │
└─────────────────────────┘
```

#### Các trường dữ liệu chính

| Trường | Loại | Mục đích |
|-------|------|---------|
| `_isLogin` | bool | Chuyển đổi giữa login/signup form |
| `_emailController` | TextEditingController | Nhập email |
| `_passwordController` | TextEditingController | Nhập password |
| `_confirmPasswordController` | TextEditingController | Xác nhận password (signup) |
| `_isLoading` | bool | Hiển thị loading state |

#### Hàm quan trọng

- `_signInWithEmail()` - Đăng nhập email/password qua AuthService
- `_signUpWithEmail()` - Đăng ký email/password mới qua AuthService
- `_signInWithGoogle()` - Đăng nhập Google qua AuthService
- `_showMessage(String msg)` - Hiển thị SnackBar

---

### 2. **MainScreen** - Màn hình chính (Tab bar)

**📍 Đường dẫn:** `lib/views/main_screen.dart`  
**Loại Widget:** `StatelessWidget`

#### Cấu trúc UI

```
┌───────────────────────────┐
│ IndexedStack (index: 0/1/2)│
│ ├─ MapView                │
│ ├─ TimelineView           │
│ └─ ProfileView            │
├───────────────────────────┤
│ NavigationBar (3 tab)      │
│ ├─ 📍 Bản đồ             │
│ ├─ 📅 Kỷ niệm           │
│ └─ 👤 Cá nhân            │
└───────────────────────────┘
```

#### Liên kết với Provider

```dart
final MainNavigationProvider navigationProvider = 
    context.watch<MainNavigationProvider>();
// selectedIndex: 0 (Map) / 1 (Timeline) / 2 (Profile)
```

---

### 3. **MapView** - Bản đồ chính

**📍 Đường dẫn:** `lib/views/map/map_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Cấu trúc UI - Stack Layer

```
┌─────────────────────────────┐
│ Stack                       │
├─────────────────────────────┤
│ Layer 1: Bản đồ cồn         │
│ ├─ Mapbox (nếu có token)    │
│ └─ FlutterMap + OSM         │
│    ├─ TileLayer             │
│    │  URL: CartoDB Positron │
│    └─ MarkerLayer           │
│       └─ Polaroid Markers   │
├─────────────────────────────┤
│ Layer 2: Top Search Panel   │
│ ├─ TextField (search)       │
│ └─ FilterChip (topics)      │
├─────────────────────────────┤
│ Layer 3: FABs               │
│ ├─ GPS button (bottom-left) │
│ └─ Add button (bottom-right)│
└─────────────────────────────┘
```

#### Thông số Bản đồ

| Thông số | Giá trị | Ghi chú |
|---------|--------|---------|
| Tập trung mặc định | Hà Nội (21.0285, 105.8542) | Từ `_defaultPosition` |
| Zoom mặc định | 12 | Mức phóng to ban đầu |
| Tile Layer URL | `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png` | CartoDB Positron (giấy trắng) |
| Tile subdomains | `['a', 'b', 'c', 'd']` | Cân bằng tải server |
| Marker kích thước | 90x130 | Polaroid style width × height |

#### Marker Design - Polaroid

```
┌────────────────────┐
│   White Card       │
│ ┌────────────────┐ │
│ │   Image (80x60)│ │
│ │ [NetworkImage] │ │
│ └────────────────┘ │
│ ┌────────────────┐ │
│ │   Date (10pt) │ │
│ │   "DD/MM"     │ │
│ └────────────────┘ │
└────────────────────┘
      ▼
   [Pointer]
```

#### Hàm chính

| Hàm | Mục đích |
|-----|---------|
| `_buildPolaroidMarker(MemoryModel)` | Render marker Polaroid từ data |
| `_showMemoryBottomSheet(MemoryModel)` | Hiển thị modal chi tiết |
| `_moveToCurrentLocation()` | Di chuyển bản đồ tới vị trí GPS |
| `_filterMapMemories(List)` | Lọc markers theo search + topic |
| `_availableTopics(List)` | Trích xuất list topics từ data |

---

### 4. **TimelineView** - Danh sách Kỷ niệm

**📍 Đường dẫn:** `lib/views/timeline/timeline_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Cấu trúc UI

```
┌────────────────────────────────┐
│ AppBar (gradient blue-purple)  │
│ "Kỷ Niệm"                      │
├────────────────────────────────┤
│ Utility Bar                    │
│ ├─ Search TextField            │
│ ├─ Date Range Filter           │
│ └─ Grouping Mode (segmented)   │
│    ├─ Tuần (Week)              │
│    ├─ Tháng (Month)            │
│    └─ Năm (Year)               │
├────────────────────────────────┤
│ Timeline Content               │
│ ├─ ExpansionTile Group 1       │
│ │  ├─ Memory Card 1            │
│ │  ├─ Memory Card 2            │
│ │  └─ ...                      │
│ ├─ ExpansionTile Group 2       │
│ └─ ...                         │
└────────────────────────────────┘
```

#### Memory Card Layout

```
┌──────────────────────────┐
│ Row Layout               │
├──────────────────────────┤
│ [1]        [2]    [3]   │
│Thumbnail  Title   Menu  │
│(92x92)    & Date  (⋮)   │
│           Address       │
│           Topic Chip    │
└──────────────────────────┘
```

#### Cơ chế Grouping

| Mode | Khóa grouping | Ví dụ |
|------|---------|---------|
| **Tuần** | `'${date.year}-W${weekNum}'` | "2026-W14" |
| **Tháng** | `'${date.year}-${date.month}'` | "2026-04" |
| **Năm** | `'${date.year}'` | "2026" |

#### Hàm chính

| Hàm | Mục đích |
|-----|---------|
| `_applyFilters(List)` | Lọc theo date range + search |
| `_groupMemories(List)` | Nhóm memories theo mode |
| `_groupKey(DateTime, String)` | Sinh khóa grouping |
| `_deleteMemory(MemoryModel)` | Xóa kỷ niệm qua MemoryService |
| `_onSearchChanged(String)` | Debounce search input |

---

### 5. **AddMemoryView** - Tạo / Sửa Kỷ niệm

**📍 Đường dẫn:** `lib/views/timeline/add_memory_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Cấu trúc Form

```
┌──────────────────────────────┐
│ AppBar                       │
│ "Tạo Kỷ Niệm" / "Sửa K.N"  │
├──────────────────────────────┤
│ [Card 1] Nội dung            │
│ ├─ Title TextField           │
│ ├─ Description (multi-line)  │
│ ├─ Topic Dropdown            │
│ ├─ Date Picker               │
│ └─ Address display           │
├──────────────────────────────┤
│ [Card 2] Vị trí GPS          │
│ ├─ Current Location btn      │
│ ├─ AddressFromCoordsWidget   │
│ └─ Coordinates display       │
├──────────────────────────────┤
│ [Card 3] Ảnh                 │
│ ├─ Preview (190h)            │
│ ├─ Thumbnail strip (66x66)   │
│ ├─ Camera button             │
│ └─ Gallery button            │
├──────────────────────────────┤
│ Save Button                  │
└──────────────────────────────┘
```

#### Validations

```dart
bool get isFormValid =>
    _titleController.text.isNotEmpty &&
    _descriptionController.text.isNotEmpty &&
    _selectedTopic.isNotEmpty &&
    _selectedImageUrls.isNotEmpty &&
    _isGpsFresh();
```

#### Hàm chính

| Hàm | Mục đích |
|-----|---------|
| `_detectCurrentLocation()` | Lấy GPS từ Geolocator |
| `_uploadFromXFile(XFile)` | Upload ảnh qua CloudinaryService |
| `_captureAndUploadImage()` | Chụp ảnh qua CameraCaptureView |
| `_pickFromGalleryAndUpload()` | Chọn ảnh từ thư viện |
| `_isGpsFresh()` | Kiếm GPS không quá 1 giờ |
| `_saveMemory()` | Lưu/Update qua MemoryService |

---

### 6. **MemoryDetailView** - Chi tiết Kỷ niệm

**📍 Đường dẫn:** `lib/views/timeline/memory_detail_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Cấu trúc UI

```
┌────────────────────────────┐
│ AppBar + Edit button       │
├────────────────────────────┤
│ PageView (swipeable images)│
│ ├─ Image 1 (hero)         │
│ ├─ Image 2                │
│ └─ Image N                │
│ Index badge (1/N)         │
├────────────────────────────┤
│ Detail Form (read-only)    │
│ ├─ Title                  │
│ ├─ Description            │
│ ├─ Topic chip             │
│ ├─ Date                   │
│ ├─ Address                │
│ └─ Coordinates            │
└────────────────────────────┘
```

---

### 7. **ProfileView** - Thông tin Cá nhân

**📍 Đường dẫn:** `lib/views/profile/profile_view.dart`  
**Loại Widget:** `StatefulWidget`

#### Phần Avatar & Info

```
┌────────────────────────────┐
│ Gradient AppBar            │
│ (blue-purple)              │
├────────────────────────────┤
│ Avatar Section             │
│ [Avatar]    [Username]     │
│ (editable)  [Email]        │
│             [Logout BTN]   │
└────────────────────────────┘
```

#### Phần Analytics

```
┌────────────────────────────┐
│ Month/Year Selector        │
│ [< Prev] [Tháng 4] [Next >]│
├────────────────────────────┤
│ Monthly Bar Chart          │
│ (fl_chart LineChart)       │
├────────────────────────────┤
│ Stats Cards                │
│ ├─ Total memories: X       │
│ ├─ Top topic: (emoji)      │
│ └─ This month: Y           │
├────────────────────────────┤
│ Topic Pie Chart            │
│ (Category distribution)    │
└────────────────────────────┘
```

#### Hàm chính

| Hàm | Mục đích |
|-----|---------|
| `_pickAndUploadAvatar()` | Chọn ảnh avatar + upload |
| `_buildMonthlyBars(List)` | Render bar chart tháng |
| `_countsForMonth(Int, Int)` | Tính tổng memories trong tháng |
| `_countsForYear(Int)` | Tính tổng memories trong năm |
| `_buildCategoryPieFromCounts()` | Render pie chart topics |
| `_safePhotoUrl(String?)` | Filter ảnh không hợp lệ |

---

## 🧩 DANH SÁCH WIDGET DÙNG CHUNG

### Custom Widgets

| Widget | Đường dẫn | Mục đích | Sử dụng ở |
|--------|----------|---------|----------|
| **AppPrimaryButton** | `lib/widgets/app_primary_button.dart` | Nút action chuẩn (FilledButton wrapper) | AuthView, AddMemoryView, Dialog |
| **AppInfoCard** | `lib/widgets/app_info_card.dart` | Card title + description tái sử dụng | Empty state, Info section |
| **AddressFromCoordsWidget** | `lib/widgets/address_from_coords_widget.dart` | Async address resolver display | AddMemoryView (GPS card) |

### Custom Renderers

| Component | Phước dẫn | Mục đích |
|-----------|----------|---------|
| **_PolaroidMarker** | Inline in MapView | Render Polaroid-style ảnh marker |
| **_PolaroidPointerPainter** | Inline in MapView | CustomPaint triangular pointer |
| **MemoryCard** | Inline in TimelineView | Timeline card layout |

---

## 🎨 TÓM TẮT HỆ THỐNG THIẾT KẾ

### Palettes & Colors

#### Global Theme (lib/main.dart)

| Thành phần | Giá trị | Hex/Code |
|----------|--------|---------|
| Primary | Indigo sâu | #1A237E |
| Secondary | Amber | #FFC107 |
| Background | Grey nhạt | #F5F5F7 |
| Surface | White | #FFFFFF |

#### Screen-Level Overrides

| Màn hình | Gradient / BG | Accent | Ghi chú |
|---------|---------|--------|---------|
| **AuthView** | #FFF8EE → #E7F1FF | Teal (#0F766E) | Warm-cool gradient |
| **MapView** | White (semi) | Sage Green (#7FB3A0) | Cream overlay #FEF9F0 |
| **TimelineView** | Blue-Purple | - | Gradient AppBar #2196F3 → #7C4DFF |
| **ProfileView** | Blue-Purple | - | Gradient AppBar #3B82F6 → #7C3AED |
| **AddMemoryView** | Indigo-first | - | - |

#### Topic Colors (MemoryTopic)

| Topic | Color | Hex |
|-------|-------|-----|
| citywalk | Blue | #2D6CDF |
| food | Orange | #E67E22 |
| trekking | Green | #16A085 |
| beach | Cyan | #3498DB |
| culture | Purple | #8E44AD |

### Typography

| Loại | Font Family | Size | Weight | Sử dụng |
|------|----------|------|--------|--------|
| **Heading 1** | Roboto | 24-28 | W700 | App title, Screen header |
| **Heading 2** | Roboto | 18-20 | W600 | Card title, Dialog header |
| **Body (chính)** | Roboto | 14-16 | W400/W500 | Content text |
| **Caption** | Roboto | 12 | W400 | Subtitle, meta info |
| **Special (Marker)** | Courier | 10 | W500 | Date on Polaroid |

### Spacing Rhythm

```
Standard increments: 4, 6, 8, 10, 12, 14, 16, 20, 24, 32, 48

Card padding:        12-16
Button padding:      12-16 vertical, 24-32 horizontal
ListTile spacing:    8-12
Section margin:      16-24
```

### Border Radius Convention

```
Small (micro UI):     4, 6, 8
Medium (cards):       12, 14
Large (modal):        20, 22, 24
Full circle:          BorderRadius.circular(999)
```

---

## 📊 LUỒNG DỮ LIỆU FIRESTORE

### Memory Pipeline

```
┌───────────────────────────────────────────────────────────────┐
│                      MEMORY PIPELINE                           │
└───────────────────────────────────────────────────────────────┘

[UI Layer]
   └─ TimelineView / MapView
      └─ Call: MemoryService.getMemoriesStream()

[Service Layer]
   └─ MemoryService (lib/services/memory_service.dart)
      ├─ Read Firestore: memories/{uid}/*
      ├─ Filter by currentUser (auth state)
      ├─ Apply pending local queue
      └─ Stream<List<MemoryModel>>

[Data Transformation]
   └─ MemoryModel.fromMap(doc.data(), doc.id)
      ├─ Sanitize URLs (reject "gggggg", "null", "undefined")
      ├─ Parse date field (Timestamp → DateTime)
      ├─ Merge imageUrls + imageUrl
      └─ Output: MemoryModel object

[Caching & Offline]
   └─ MemoryService._applyPendingPreview()
      ├─ Read SharedPreferences queue
      ├─ Merge pending ops with stream
      ├─ Show local changes immediately
      └─ Flush when connectivity restored

[Browser]
   └─ StreamBuilder/FutureBuilder → UI rebuild
```

### Auth Pipeline

```
┌───────────────────────────────────────────────────────────────┐
│                    AUTH PIPELINE                              │
└───────────────────────────────────────────────────────────────┘

[AuthView / AuthService]
   ├─ signUpWithEmail(email, password)
   │  ├─ FirebaseAuth.createUserWithEmailAndPassword
   │  ├─ Create users/{uid} profile doc
   │  └─ Return User object
   │
   ├─ signInWithEmailPassword(email, password)
   │  ├─ FirebaseAuth.signInWithEmailAndPassword
   │  └─ Return User object
   │
   └─ signInWithGoogle()
      ├─ GoogleSignIn.signIn()
      ├─ FirebaseAuth.signInWithCredential()
      ├─ Create users/{uid} profile doc
      └─ Return User object

[Global Auth Listener]
   └─ AuthWrapper (lib/main.dart)
      ├─ StreamBuilder(FirebaseAuth.authStateChanges())
      ├─ User != null → MainScreen
      └─ User == null → AuthView
```

### Media Upload Pipeline

```
┌───────────────────────────────────────────────────────────────┐
│                 MEDIA UPLOAD PIPELINE                         │
└───────────────────────────────────────────────────────────────┘

[AddMemoryView]
   └─ User tap Camera / Gallery
      ├─ CameraCaptureView / image_picker
      └─ Return XFile

[CloudinaryService.uploadImageFile(XFile)]
   ├─ _compressFile(XFile) → smaller file
   ├─ POST to Cloudinary API
   ├─ Retry x3 if fail
   └─ Return image URL string

[MemoryModel]
   ├─ Add URL to imageUrls list
   └─ Ready for save/update

[MemoryService.saveMemory(MemoryModel)]
   ├─ Add record to Firestore
   └─ Or queue if offline
```

### Location Pipeline

```
┌───────────────────────────────────────────────────────────────┐
│               LOCATION & GEOCODING PIPELINE                   │
└───────────────────────────────────────────────────────────────┘

[AddMemoryView]
   └─ _detectCurrentLocation()
      └─ Geolocator.getCurrentPosition()
         ├─ Check location enabled
         ├─ Check permission
         └─ Return Position (lat, lng)

[LocationService.getAddressFromLatLng(lat, lng)]
   ├─ Platform == "web"?
   │  └─ Call Nominatim HTTP (reverse geocode)
   │
   └─ Platform == "mobile"
      └─ Call geocoding plugin
         └─ Return address string

[UI]
   └─ AddressFromCoordsWidget
      └─ Display address text
```

---

## 📖 HƯỚNG DẪN BẢO TRÌ & CHỈNH SỬA

### Câu hỏi Thường gặp & Câu trả lời

#### Q1: Nếu muốn đổi màu chủ đạo của toàn app thì sửa ở đâu?

**A:** Sửa 2 nơi:

1. **Global Theme** - `lib/main.dart` (dòng ~45-60)
   ```dart
   ThemeData(
     useMaterial3: true,
     colorScheme: ColorScheme.fromSeed(
       seedColor: Colors.indigo,        // ← ĐỔI SỐ NÀY
       brightness: Brightness.light,
     ),
   )
   ```

2. **Screen-Level Overrides** - Tìm từng file view (MapView, TimelineView, etc.)
   - MapView: tìm `Color(0xFFFEF9F0)` và `Color(0xFF7FB3A0)`
   - TimelineView: tìm gradient colors trong AppBar
   - ProfileView: tùy chỉnh trong gradient AppBar

#### Q2: Nếu muốn thêm một trường dữ liệu mới (ví dụ: "Cảm xúc") thì phải sửa những file nào?

**A:** Sửa theo thứ tự:

| Bước | File | Sửa gì |
|-----|------|--------|
| 1 | `lib/models/memory_model.dart` | Thêm field `final String emotion;` |
| 2 | (same) | Update `fromMap()` factory → parse `data['emotion']` |
| 3 | (same) | Update `toMap()` → return `'emotion': emotion` |
| 4 | (same) | Update `copyWith()` → add `String? emotion` param |
| 5 | `lib/views/timeline/add_memory_view.dart` | Thêm emotion dropdown/selector |
| 6 | `lib/views/timeline/memory_detail_view.dart` | Hiển thị emotion field (read-only) |
| 7 | `lib/views/profile/profile_view.dart` | (Nếu cần thêm vào analytics) |
| 8 | `lib/services/memory_service.dart` | _buildCreateData() / _buildUpdateData() |

#### Q3: Nếu muốn đổi bản đồ từ OSM sang một provider khác?

**A:** Sửa `lib/views/map/map_view.dart` - dòng TileLayer:

```dart
// Hiện tại (CartoDB Positron light):
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
  subdomains: const <String>['a', 'b', 'c', 'd'],
)

// Đổi sang OpenStreetMap:
TileLayer(
  urlTemplate: 'https://{z}.tile.openstreetmap.org/{z}/{x}/{y}.png',
)

// Đổi sang Mapbox (cần access token):
// Đã có logic - set MAPBOX_ACCESS_TOKEN env var
```

#### Q4: Tốc độ zoom bản đồ được kiểm soát ở đâu?

**A:** Có 2 hàm:

1. **Zoom mặc định khi load:**
   ```dart
   // lib/views/map/map_view.dart, dòng ~440
   MapOptions(
     initialCenter: _osmCenter,
     initialZoom: 12,    // ← ĐỔI SỐ NÀY (1-18)
   )
   ```

2. **Zoom khi nhấn GPS button:**
   ```dart
   // lib/views/map/map_view.dart, _moveToCurrentLocation()
   _osmMapController.move(currentPoint, 13);
   //                                        ↑ zoom level
   ```

3. **Cinematic zoom animation:**
   ```dart
   // lib/views/map/map_view.dart, _performCinematicZoom()
   _osmMapController.move(targetLocation, 15.0);
   //                                      ↑ target zoom
   ```

#### Q5: Nếu muốn bỏ quyền truy cập GPS được yêu cầu?

**A:** Sửa `lib/views/timeline/add_memory_view.dart`:

```dart
// Dòng trong _detectCurrentLocation():
geo.LocationPermission permission = await geo.Geolocator.checkPermission();
if (permission == geo.LocationPermission.denied) {
    // ↓ bỏ request này nếu không muốn yêu cầu:
    permission = await geo.Geolocator.requestPermission();
}

// Hoặc uncomment validation GPS trong _saveMemory():
// if (!_isGpsFresh()) return; // ← bỏ dòng này
```

#### Q6: Nếu muốn thay đổi cách Marker được render?

**A:** Sửa `lib/views/map/map_view.dart`:

- **Marker layout:** `_buildPolaroidMarker(MemoryModel memory)` (dòng ~170)
- **Marker size:** trong MarkerLayer `width: 90, height: 130` (dòng ~708)
- **Pointer shape:** `_PolaroidPointerPainter` class (dòng ~710)

#### Q7: Nếu muốn cho phép offline editing (sửa kỷ niệm khi không có mạng)?

**A:** Logic đã có trong `MemoryService`:
- Queue mechanism tự động lưu pending ops
- Nhưng `AddMemoryView` chưa che phủ offline mode
- Sửa: thêm check connectivity trước khi save:

```dart
bool isOnline = await connectivity_plus.checkConnectivity() != ConnectivityResult.none;
if (!isOnline) {
    // Vẫn cho save, nhưng thêm warning toast
    _showMessage('Lưu offline - sẽ đồng bộ khi có mạng');
}
```

#### Q8: Những hàm nào là "critical" (nguy hiểm nếu sửa)?

**A:** Các hàm **cần thận trọng** khi chỉnh sửa:

| Hàm | File | Lý do |
|-----|------|-------|
| `MemoryModel.fromMap()` | memory_model.dart | Lỗi parse → crash toàn app |
| `MemoryService.getMemoriesStream()` | memory_service.dart | Nếu lỗi → timeline/map trôi nổi |
| `_applyPendingPreview()` | memory_service.dart | Offline logic - dữ liệu mất nếu sai |
| `AuthService.signUpWithEmail()` | auth_service.dart | Tạo user doc → verify path Firestore |
| `_buildPolaroidMarker()` | map_view.dart | Marker crash → bản đồ không vẽ |
| `_performCinematicZoom()` | map_view.dart | Animation freeze → UI không response |

---

### Troubleshooting Nhanh

#### Vấn đề: Bản đồ không hiển thị markers

**Giải pháp:**
1. Check `_filterMapMemories()` - có lọc quá chặt?
2. Check Firestore có data không: `collection(memories)`
3. Check `MemoryModel.fromMap()` - có sanitize URL quá mạnh?
4. Check marker render: `_buildPolaroidMarker()` có error không?

#### Vấn đề: Timeline load chậm

**Giải pháp:**
1. Check `FutureBuilder` vs `StreamBuilder` - thay StreamBuilder nếu cần real-time
2. Giảm số memory lấy: thêm pagination
3. Check `_groupMemories()` - logic grouping có O(n²)?

#### Vấn đề: Ảnh không upload

**Giải pháp:**
1. Check CloudinaryService URL & API key
2. Check file size - CloudinaryService có compress chưa?
3. Check permission đọc file: `imagePickerOptions`
4. Check `_uploadFromXFile()` error handling

#### Vấn đề: GPS không chính xác

**Giải pháp:**
1. Check `_isGpsFresh()` - có yêu cầu quá gần đây?
2. Check emulator GPS settings
3. Check Geolocator timeout: `desiredAccuracy: LocationAccuracy.high`

---

### Checklist Trước khi Deploy

- [ ] Thay `google-services.json` (test project → prod)
- [ ] Thay Mapbox token (nếu dùng)
- [ ] Thay Cloudinary URL (nếu backup cloud ảnh)
- [ ] Kiểm tra Firebase Firestore rules (public? auth-only?)
- [ ] Test offline flow (quay off WiFi, xem queue work)
- [ ] Test auth flow (logout → login, thay email)
- [ ] Kiểm tra responsive design (test khác screen sizes)
- [ ] Run `flutter analyze` & `flutter test` (nếu có)
- [ ] Build APK/IPA cuối cùng: `flutter build apk --release`

---

## 📝 GHI CHÚ THÊM

### Cấu trúc Firestore Collection

```
firestore
├─ memories/ (collection)
│  └─ {memoryId}/ (document)
│     ├─ userId: string
│     ├─ title: string
│     ├─ description: string
│     ├─ imageUrl: string (main thumbnail)
│     ├─ imageUrls: array<string>
│     ├─ topic: string
│     ├─ lat: number
│     ├─ lng: number
│     ├─ date: timestamp
│     ├─ address: string
│     └─ (queue meta fields when offline)
│
└─ users/ (collection)
   └─ {uid}/ (document)
      ├─ email: string
      ├─ displayName: string
      ├─ photoUrl: string
      ├─ createdAt: timestamp
      └─ lastUpdatedAt: timestamp
```

### Offline Queue Format (SharedPreferences)

```dart
// Key: "memory_queue_{uid}"
// Value: JSON của List<Map<String, dynamic>>
[
  {
    "id": "local-{uuid}",
    "action": "create", // "create" || "update" || "delete"
    "data": {...memory_map...},
    "timestamp": 1712425200000
  },
  ...
]
```

### Magic Values Cần Nhớ

| Giá trị | Ý nghĩa | File |
|-------|--------|------|
| `105.8542, 21.0285` | Default Ha Noi coords | map_view.dart |
| `3600000` | GPS fresh window (1 hour, ms) | add_memory_view.dart |
| `1` | Map tab index | main_screen.dart |
| `#2D6CDF` | citywalk topic color | memory_topic.dart |
| `CartoDB Positron` | Tile layer style | map_view.dart |

---

**Tài liệu này được tạo bởi AI Architecture Analysis - Ngày 06/04/2026**

Để cập nhật tài liệu này, hãy chỉnh sửa file này hoặc yêu cầu phân tích lại sau khi thay đổi cấu trúc dự án.
