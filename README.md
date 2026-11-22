# Đồ án: Thiết kế CSDL Hệ thống Đấu giá Trực tuyến và Kiểm soát Trả giá Đồng thời

> **Môn học:** Cơ sở dữ liệu Nâng cao (Advanced Database Systems)  
> **Đề tài số:** 19  
> **Hệ quản trị CSDL:** PostgreSQL (khuyến nghị phiên bản 15.x – 18.x)  
> **Tài liệu tham khảo chính:** Giáo trình *Database System Concepts* (A. Silberschatz, H. F. Korth, S. Sudarshan) & Chuẩn quốc tế ODMG 3.0.

---

## 📌 Giới thiệu & Mục tiêu Đề tài

### 1. Mục tiêu
Xây dựng hệ thống cơ sở dữ liệu quan hệ hoàn chỉnh quản lý toàn bộ vòng đời đấu giá trực tuyến: người dùng, danh mục đa cấp, tài sản, phiên đấu giá, đăng ký tham gia, lịch sử trả giá, kết quả chốt phiên và nhật ký thay đổi; bảo đảm kết quả chính xác khi nhiều người cùng trả giá đồng thời hoặc khi phiên đang đóng.

### 2. Câu hỏi nghiên cứu then chốt
> *Làm thế nào để bảo đảm mỗi lượt trả giá được kiểm tra trên trạng thái hợp lệ, không làm mất cập nhật (Lost Update), chống gian lận và không bao giờ tạo ra hai kết quả thắng cho cùng một phiên đấu giá khi có nhiều giao dịch cạnh tranh đồng thời hoặc khi phiên đang trong quá trình đóng?*

---

## 📁 Cấu trúc Thư mục Mã nguồn CSDL

```text
Project-CSDL-Nangcao/
├── .gitignore                # Quy tắc loại trừ file tạm
├── README.md                 # Tài liệu tổng quan và hướng dẫn chạy lại script
├── business_rules.md         # BƯỚC 1: Đặc tả 6 quy tắc nghiệp vụ cốt lõi
├── DDL_HeThongDauGia.sql     # BƯỚC 2 & 3: Script DDL khởi tạo 11 bảng, khóa và ràng buộc
├── seed_data.sql             # BƯỚC 2 & 4: Script nạp bộ dữ liệu mẫu cho 11 bảng
├── queries.sql               # BƯỚC 4 & 5: Script 4 hàm/thủ tục PL/pgSQL và 11 truy vấn nâng cao
└── test_cases.sql            # BƯỚC 7: Script 5 kịch bản thực nghiệm transaction và đối soát
```

---

## ⚙️ Các Điểm Nhấn Kỹ thuật Nổi bật trong CSDL

1. **Chuẩn hóa dữ liệu đạt BCNF & Phi chuẩn hóa có kiểm soát:**
   - Các lược đồ quan hệ cốt lõi đạt chuẩn BCNF.
   - Bảng `PHIENDAUGIA` lưu riêng `GiaHienTai` và `MaLuotDanDau` (phi chuẩn hóa có kiểm soát) để đọc trạng thái phiên với chi phí $O(1)$ và làm điểm tuần tự hóa chung cho các giao dịch trả giá/đóng phiên.
2. **Khóa ngoại kép tham chiếu chéo có trì hoãn (`DEFERRABLE INITIALLY DEFERRED`):**
   - Ràng buộc `fk_phiendaugia_luotdandau` ghép cặp `(MaLuotDanDau, MaPhien)` tham chiếu ngược về `LUOTTRAGIA(MaLuotTraGia, MaPhien)` bảo đảm lượt dẫn đầu bắt buộc thuộc về chính phiên đó.
   - Thuộc tính `DEFERRABLE INITIALLY DEFERRED` giải quyết phụ thuộc vòng (Circular Dependency) khi ghi nhận lượt trả giá mới và cập nhật phiên trong cùng một giao dịch.
3. **Cơ chế Idempotency & Unique Constraints:**
   - Cột `MaYeuCau` (`UUID`) có ràng buộc `UNIQUE` ngăn chặn tạo lượt trả giá trùng lặp khi client gửi lại yêu cầu do gián đoạn mạng.
   - Ràng buộc `UNIQUE (MaPhien, SoTien)` bảo đảm trong cùng một phiên không bao giờ có hai lượt trả giá cùng một mức tiền.
4. **Truy vấn SQL nâng cao & Đệ quy (`WITH RECURSIVE`):**
   - Duyệt và tổng hợp dữ liệu cây danh mục đa cấp (Roll-up dồn tài sản và phiên đấu giá từ danh mục con lên danh mục cha).
   - Hàm báo cáo động (`Dynamic SQL`) với bộ lọc đa tham số sử dụng `EXECUTE ... USING` chống SQL Injection.
5. **Kiểm soát đồng thời chuyên sâu (Concurrency Control):**
   - **Phương án 1 (Khóa dòng phiên):** Sử dụng `SELECT ... FOR UPDATE` trên dòng `PHIENDAUGIA` để tuần tự hóa các giao dịch trả giá cạnh tranh.
   - **Phương án 2 (Mức cô lập SERIALIZABLE có xử lý thử lại):** Chạy giao dịch ở mức `SERIALIZABLE` (Serializable Snapshot Isolation - SSI), không khóa dòng khi đọc. Khi xảy ra xung đột tuần tự hóa (`SQLSTATE 40001`), phía gọi thực hiện `ROLLBACK` và chạy lại cả giao dịch trên snapshot mới với cùng `MaYeuCau`.
   - Giao dịch đóng phiên `fn_DongPhienDauGia` phối hợp nguyên tử với giao dịch trả giá theo cùng quy tắc đồng thời.

---

## 🚀 Hướng dẫn Cài đặt & Chạy lại từ Đầu (Theo đúng thứ tự)

Thực hiện lần lượt 4 bước sau trong **pgAdmin 4** (hoặc `psql` / DBeaver):

### Bước 1: Khởi tạo Cấu trúc Bảng CSDL
* **File thực thi:** [`DDL_HeThongDauGia.sql`](DDL_HeThongDauGia.sql)
* **Thao tác:** Mở file và nhấn **F5 (Execute)**.
* **Kết quả:** Xóa sạch các bảng cũ (`DROP TABLE ... CASCADE`) và tạo mới 11 bảng, khóa chính, khóa ngoại kép `DEFERRABLE`, các ràng buộc `UNIQUE` và `CHECK`.

### Bước 2: Nạp Dữ liệu Mẫu (Seed Data)
* **File thực thi:** [`seed_data.sql`](seed_data.sql)
* **Thao tác:** Mở file và nhấn **F5 (Execute)**.
* **Kết quả:** Nạp bộ dữ liệu mẫu cho 11 bảng (15 người dùng, 21 danh mục 3 cấp, 18 tài sản chia đều 3 lớp con, 20 phiên đấu giá, 50 đăng ký, 45 lượt trả giá, 11 kết quả chốt phiên và 57 dòng nhật ký).

### Bước 3: Cài đặt Hàm Nghiệp vụ & Khảo sát Truy vấn Nâng cao
* **File thực thi:** [`queries.sql`](queries.sql)
* **Cấu trúc file gồm 2 phần:**
  * **Phần I – 4 Hàm PL/pgSQL:**
    1. `fn_BaoCaoPhienDauGiaDong` (Dynamic SQL lọc phiên đa tiêu chí)
    2. `fn_TraGia` (Phương án 1: Khóa bi quan `SELECT ... FOR UPDATE`)
    3. `fn_DongPhienDauGia` (Đóng phiên và chốt kết quả thắng duy nhất)
    4. `fn_TraGia_Serializable` (Phương án 2: Mức cô lập `SERIALIZABLE` có thử lại ở phía gọi)
  * **Phần II – 11 Truy vấn SQL nâng cao:**
    * Truy vấn 1–2: Đệ quy cây danh mục (`WITH RECURSIVE`) và Roll-up theo nhánh.
    * Truy vấn 3–4: Phiên sắp kết thúc trong 1 giờ và người đang dẫn đầu từng phiên.
    * Truy vấn 5: Biến động giá và mức tăng qua từng lượt (`LAG`).
    * Truy vấn 6–7: Phễu tương tác phiên (tách CTE) và tỷ lệ phiên thành công.
    * Truy vấn 8: Xếp hạng người trả giá (`ROW_NUMBER`, `LEAD`) và đối soát `MaLuotDanDau`.
    * Truy vấn 9–10: Thống kê theo nhánh danh mục gốc (`ROLLUP`, `GROUPING`) và xếp hạng người mua (`DENSE_RANK`).
    * Truy vấn 11: Kiểm toán toàn vẹn dữ liệu toàn hệ thống (`CROSS JOIN LATERAL`).

### Bước 4: Chạy Kịch bản Kiểm thử & Thực nghiệm Transaction
* **File thực thi:** [`test_cases.sql`](test_cases.sql)
* **Các kịch bản trong file:**
  * **Bước 0:** Làm mới khung thời gian mở cho Phiên 1 và Phiên 4.
  * **Kịch bản 1:** Nhiều người trả giá cùng lúc (chạy 1 Tab và chạy song song 2 Tab độc lập).
  * **Kịch bản 2 (Minh chứng 3):** Yêu cầu gửi lại cùng `MaYeuCau` (`UUID`) không tạo lượt trả giá trùng.
  * **Kịch bản 3 (Minh chứng 1):** Trả giá cạnh tranh với đóng phiên – bảo đảm tối đa một kết quả thắng.
  * **Kịch bản 4 (Minh chứng 4):** Lỗi xảy ra giữa giao dịch (`1 / 0`) và các ca vi phạm quy tắc nghiệp vụ đều được `ROLLBACK` hoàn toàn, không để lại dữ liệu dở dang.
  * **Kịch bản 5 (Minh chứng 5 & Minh chứng 2):** Đo thời gian phản hồi bằng `EXPLAIN ANALYZE` giữa hai phương án trên cùng dữ liệu và đối soát `GiaHienTai` khớp 100% với `MAX(SoTien)` trong lịch sử trả giá.

---
*Đồ án môn Cơ sở dữ liệu Nâng cao – Nhóm 19 – Trường Đại học Sài Gòn (SGU).*
