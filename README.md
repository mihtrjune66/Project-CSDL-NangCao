# Đồ án: Thiết kế CSDL Hệ thống Đấu giá Trực tuyến và Kiểm soát Trả giá Đồng thời

> **Môn học:** Cơ sở dữ liệu Nâng cao (Advanced Database Systems)  
> **Đề tài số:** 19  
> **Hệ quản trị CSDL:** PostgreSQL (khuyến nghị phiên bản 15.x trở lên)  
> **Tài liệu tham khảo chính:** Giáo trình *Database System Concepts* (A. Silberschatz, H. F. Korth, S. Sudarshan) & Chuẩn quốc tế ODMG 3.0.

---

## 📌 Giới thiệu & Mục tiêu Đề tài

### 1. Mục tiêu
Xây dựng một hệ thống cơ sở dữ liệu quan hệ hoàn chỉnh quản lý toàn bộ vòng đời đấu giá trực tuyến: người dùng, danh mục đa cấp, tài sản, phiên đấu giá, đăng ký tham gia, lịch sử trả giá và kết quả chốt phiên.

### 2. Câu hỏi nghiên cứu then chốt
> *Làm thế nào để bảo đảm mỗi lượt trả giá được kiểm tra trên trạng thái hợp lệ, không làm mất cập nhật (Lost Update), chống gian lận và không bao giờ tạo ra hai kết quả thắng cho cùng một phiên đấu giá khi có nhiều giao dịch cạnh tranh đồng thời hoặc khi phiên đang trong quá trình đóng?*

---

## 📁 Cấu trúc Thư mục Dự án

```text
Project-CSDL-Nangcao/
├── .gitignore                          # Quy tắc loại trừ file rác và file tạm
├── README.md                           # Tài liệu tổng quan và hướng dẫn vận hành dự án
├── business_rules.md                   # BƯỚC 1: Đặc tả 6 quy tắc nghiệp vụ đấu giá chi tiết
├── DDL_HeThongDauGia.sql               # BƯỚC 2: Mã nguồn DDL tạo cấu trúc 11 bảng CSDL
├── seed_data.sql                       # BƯỚC 2 & 4: Bộ dữ liệu giả lập mẫu đầy đủ tính toàn vẹn
├── queries.sql                         # BƯỚC 4 & 5: Truy vấn SQL nâng cao, đệ quy & Transaction
├── Chuong5_SoSanh_Transaction.docx     # BƯỚC 5: Báo cáo so sánh chuyên sâu 2 cơ chế Concurrency
└── Chuong6_MoHinhDoiTuong_OQL.docx     # BƯỚC 6: Báo cáo Thiết kế Mô hình Đối tượng (ODL & OQL)
```

---

## ⚙️ Các Điểm Nhấn Kỹ thuật Nổi bật trong CSDL

1. **Chuẩn hóa dữ liệu đạt BCNF / 3NF:**
   - 10/11 bảng đạt chuẩn BCNF tuyệt đối.
   - Bảng `PHIENDAUGIA` chuẩn hóa 3NF có chủ đích khi lưu trữ `GiaHienTai` và `MaLuotDanDau` để tối ưu hóa thao tác đọc trạng thái và kiểm tra bước giá đạt độ phức tạp $O(1)$.
2. **Khóa ngoại kép tham chiếu chéo có trì hoãn (`DEFERRABLE INITIALLY DEFERRED`):**
   - Ràng buộc `fk_phiendaugia_luotdandau` ghép cặp `(MaLuotDanDau, MaPhien)` tham chiếu ngược về `LUOTTRAGIA` đảm bảo lượt dẫn đầu bắt buộc phải thuộc về chính phiên đó, loại bỏ hoàn toàn lỗi gán chéo dữ liệu giữa các phiên.
   - Thuộc tính `DEFERRED` giải quyết triệt để phụ thuộc vòng (Circular Dependency) khi ghi nhận lượt trả giá mới trong cùng một transaction.
3. **Cơ chế Idempotency & Unique Constraints:**
   - Cột `MaYeuCau` (`UUID`) độc nhất ngăn chặn người dùng bị trừ tiền hoặc đặt giá trùng lặp do gửi lại request (Network retry).
   - Ràng buộc `UNIQUE (MaPhien, SoTien)` đảm bảo trong cùng một phiên không bao giờ có 2 lượt trả giá ở cùng một mức tiền.
4. **Truy vấn SQL nâng cao & Đệ quy (`WITH RECURSIVE`):**
   - Duyệt và tổng hợp dữ liệu cây danh mục đa cấp (Roll-up tài sản và phiên đấu giá theo từng nhánh cha - con).
   - Hàm báo cáo động (`Dynamic SQL`) với bộ lọc tham số linh hoạt.
5. **Kiểm soát đồng thời chuyên sâu (Concurrency Control):**
   - **Phương án 1 (Khóa bi quan):** Sử dụng `SELECT ... FOR UPDATE` trên dòng phiên để tuần tự hóa các yêu cầu trả giá cạnh tranh.
   - **Phương án 2 (Mức cô lập Tuần tự hóa):** Sử dụng mức cô lập `SERIALIZABLE` (Serializable Snapshot Isolation - SSI) kết hợp vòng lặp Retry loop tự động bắt mã lỗi `40001 (serialization_failure)`.
   - Phối hợp nguyên tử giữa giao dịch trả giá và thủ tục đóng phiên `fn_DongPhienDauGia`.

---

## 🚀 Hướng dẫn Cài đặt & Chạy Thực nghiệm

### Yêu cầu môi trường
* PostgreSQL version 14.x, 15.x hoặc 16.x.
* Công cụ truy vấn: pgAdmin 4, DBeaver hoặc giao diện dòng lệnh `psql`.

### Thứ tự thực thi script SQL

Để đảm bảo toàn vẹn dữ liệu và tránh vi phạm ràng buộc khóa ngoại, hãy thực thi các file theo đúng thứ tự sau:

#### Bước 1: Khởi tạo Cấu trúc Bảng
Mở file [`DDL_HeThongDauGia.sql`](file:///d:/Project-CSDL-Nangcao/DDL_HeThongDauGia.sql) và chạy toàn bộ mã nguồn để tạo:
* 11 bảng chuẩn (`NGUOIDUNG`, `DANHMUC`, `TAISAN`, 3 bảng lớp con kế thừa, `PHIENDAUGIA`, `DANGKY`, `LUOTTRAGIA`, `KETQUADAUGIA`, `NHATKYTHAYDOI`).
* Các ràng buộc toàn vẹn khóa chính, khóa ngoại, kiểm tra miền giá trị `CHECK` và các chỉ mục `INDEX`.

#### Bước 2: Nạp Dữ liệu Mẫu (Seed Data)
Mở file [`seed_data.sql`](file:///d:/Project-CSDL-Nangcao/seed_data.sql) và thực thi để nạp dữ liệu kiểm thử:
* 15 người dùng đại diện (người bán và người tham gia).
* 21 danh mục phân cấp 3 tầng.
* 18 tài sản đa dạng thuộc 3 nhóm chuyên biệt hóa.
* 20 phiên đấu giá ở các trạng thái khác nhau (`CHUA_MO`, `DANG_DIEN_RA`, `DA_DONG`).
* 50 lượt đăng ký, 45 lượt trả giá lịch sử và kết quả chốt phiên.

#### Bước 3: Cài đặt Thủ tục Nghiệp vụ & Chạy Thử nghiệm
Mở file [`queries.sql`](file:///d:/Project-CSDL-Nangcao/queries.sql) và thực thi để nạp các hàm/thủ tục:
1. **Truy vấn tổng hợp đệ quy danh mục:** `WITH RECURSIVE CayDanhMuc ...`
2. **Hàm báo cáo động:** `fn_BaoCaoPhienDauGiaDong(...)`
3. **Thủ tục trả giá có khóa bi quan:** `fn_TraGia(...)`
4. **Thủ tục đóng phiên đấu giá:** `fn_DongPhienDauGia(...)`
5. **Thủ tục trả giá Tuần tự hóa có Retry loop:** `fn_TraGia_Serializable(...)`

---

## 🧪 Kịch bản Kiểm thử Nghiệp vụ Trả giá

Cuối file [`queries.sql`](file:///d:/Project-CSDL-Nangcao/queries.sql) đã tích hợp sẵn các lệnh gọi thử nghiệm thực tế:

```sql
-- 1. Test trả giá thành công bằng cơ chế Khóa bi quan (Pessimistic Locking)
SELECT fn_TraGia(
    p_MaPhien := 1, 
    p_MaNguoiTraGia := 3, 
    p_SoTien := 13000000.00, 
    p_MaYeuCau := gen_random_uuid()
);

-- 2. Test trả giá bằng cơ chế Tuần tự hóa (SERIALIZABLE có xử lý Retry)
SELECT fn_TraGia_Serializable(
    p_MaPhien := 1, 
    p_MaNguoiTraGia := 4, 
    p_SoTien := 14000000.00, 
    p_MaYeuCau := gen_random_uuid()
);

-- 3. Test đóng phiên đấu giá an toàn và chốt kết quả thắng cuộc
SELECT fn_DongPhienDauGia(
    p_MaPhien := 1, 
    p_MaTacNhan := 1
);
```

---

## 📚 Tóm tắt 7 Bước Đề tài theo Đề cương

1. **Bước 1 - Đặc tả quy tắc đấu giá:** Hoàn thiện 6 quy tắc nghiệp vụ tại [`business_rules.md`](file:///d:/Project-CSDL-Nangcao/business_rules.md).
2. **Bước 2 - Thiết kế mô hình EER:** Sơ đồ thực thể liên kết mở rộng tổng quát hóa/chuyên biệt hóa và chuyển dịch thành [`DDL_HeThongDauGia.sql`](file:///d:/Project-CSDL-Nangcao/DDL_HeThongDauGia.sql).
3. **Bước 3 - Phân tích phụ thuộc hàm & Chuẩn hóa:** Xác định 16 FD, tìm phủ tối tiểu $F_{min}$ và chứng minh chuẩn 3NF/BCNF.
4. **Bước 4 - Xây dựng truy vấn SQL nâng cao:** Đệ quy cây phân cấp, Dynamic SQL, xếp hạng phân tích số liệu tại [`queries.sql`](file:///d:/Project-CSDL-Nangcao/queries.sql).
5. **Bước 5 - Thiết kế và so sánh Transaction:** Hoàn thành 2 giải pháp kiểm soát đồng thời tại [`queries.sql`](file:///d:/Project-CSDL-Nangcao/queries.sql) và biên soạn tài liệu lý thuyết tại [`Chuong5_SoSanh_Transaction.docx`](file:///d:/Project-CSDL-Nangcao/Chuong5_SoSanh_Transaction.docx).
6. **Bước 6 - Thiết kế mô hình đối tượng và OQL:** Đặc tả ODL 5 lớp và 3 truy vấn OQL chuẩn ODMG 3.0 tại [`Chuong6_MoHinhDoiTuong_OQL.docx`](file:///d:/Project-CSDL-Nangcao/Chuong6_MoHinhDoiTuong_OQL.docx).
7. **Bước 7 - Thực nghiệm và phân tích kết quả:** Tổng hợp các kịch bản chạy đua, tranh chấp tài nguyên và đo lường thông lượng.

---
*Dự án phục vụ học tập và nghiên cứu môn Cơ sở dữ liệu Nâng cao.*

