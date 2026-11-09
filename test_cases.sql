-- ĐỒ ÁN 19: HỆ THỐNG ĐẤU GIÁ TRỰC TUYẾN VÀ KIỂM SOÁT TRẢ GIÁ ĐỒNG THỜI
-- TÀI LIỆU KỊCH BẢN KIỂM THỬ TOÀN DIỆN (TEST CASES & SCRIPTS)

-- Hướng dẫn:
-- 1. Đảm bảo đã chạy lần lượt: DDL_HeThongDauGia.sql -> seed_data.sql -> queries.sql.
-- 2. Mở file này trong pgAdmin/DBeaver, bôi đen và nhấn F5 từng kịch bản để quan sát kết quả.

-- BƯỚC 0: CHUẨN BỊ MÔI TRƯỜNG & LÀM MỚI THỜI GIAN PHIÊN ĐẤU GIÁ
-- Mục đích: Đảm bảo Phiên 1 và Phiên 4 luôn ở trạng thái 'DANG_DIEN_RA' 
-- và thời gian đóng kéo dài thêm 2 giờ kể từ thời điểm test hiện tại.

UPDATE PHIENDAUGIA 
SET TrangThaiPhien = 'DANG_DIEN_RA',
    ThoiDiemMo = CURRENT_TIMESTAMP - INTERVAL '1 hour',
    ThoiDiemDong = CURRENT_TIMESTAMP + INTERVAL '2 hours' 
WHERE MaPhien IN (1, 4);

-- Kiểm tra trạng thái các phiên đang mở:
SELECT MaPhien, GiaKhoiDiem, GiaHienTai, ThoiDiemMo, ThoiDiemDong, TrangThaiPhien
FROM PHIENDAUGIA
WHERE TrangThaiPhien = 'DANG_DIEN_RA';


-- TEST CASE 1: KIỂM THỬ HÀM BÁO CÁO CÓ BỘ LỌC ĐỘNG (Dynamic SQL)
-- 1.1. Gọi báo cáo mặc định (không truyền tham số -> trả về tất cả các phiên)
SELECT * FROM fn_BaoCaoPhienDauGiaDong();

-- 1.2. Lọc tất cả phiên thuộc nhánh Danh mục 1 ("Thiết bị công nghệ & Điện tử" và các cấp con)
SELECT * FROM fn_BaoCaoPhienDauGiaDong(p_MaDanhMucGoc => 1);

-- 1.3. Lọc theo loại tài sản 'DOSUUTAM' và khoảng giá từ 1,000,000 đến 50,000,000
SELECT * FROM fn_BaoCaoPhienDauGiaDong(
    p_LoaiTaiSan => 'DOSUUTAM',
    p_GiaTu      => 1000000,
    p_GiaDen     => 50000000
);

-- 1.4. Lọc tìm kiếm gần đúng theo từ khóa tên tài sản
SELECT * FROM fn_BaoCaoPhienDauGiaDong(p_TuKhoa => 'macbook');


-- TEST CASE 2: KIỂM THỬ HÀM TRẢ GIÁ KHÓA BI QUAN (Pessimistic Locking - FOR UPDATE)
-- 2.1. Trả giá hợp lệ cho Phiên 1 (Người dùng 8 đã duyệt đăng ký, giá khởi điểm 5tr, bước 250k, giá hiện tại 5.5tr)
-- Giá trả hợp lệ: 5,750,000
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

-- 2.1.1 Xem chi tiết lượt trả giá số 46 vừa tạo:
SELECT * FROM LUOTTRAGIA WHERE MaLuotTraGia = 46;

-- 2.2. Kiểm thử tính Idempotency (Gửi lại y hệt cùng mã UUID -> Không tạo lượt mới, trả về đúng mã cũ)
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

-- Đếm số lượng bản ghi để test
SELECT COUNT(*) AS SoLuongBanGhi 
FROM LUOTTRAGIA 
WHERE MaYeuCau = '19000000-0000-4000-8000-000000000101'::uuid;

-- 2.3. Kiểm tra nhật ký và giá hiện tại sau khi trả giá:
SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;

SELECT * FROM NHATKYTHAYDOI 
WHERE MaPhien = 1 
ORDER BY ThoiDiemGhi DESC LIMIT 3;


-- TEST CASE 3: KIỂM THỬ RÀNG BUỘC NGHIỆP VỤ & BẢO MẬT (Các ca thất bại hợp lệ)
-- 3.1. Ca vi phạm: Người bán tự trả giá cho tài sản của mình (Phiên 1 do Người dùng 1 bán)
-- Kỳ vọng: Bị chặn với thông báo lỗi 'Người bán không được trả giá tài sản của mình'
SELECT fn_TraGia(1, 1, 6000000, gen_random_uuid());

-- 3.2. Ca vi phạm: Người dùng chưa có đăng ký được duyệt (Người dùng 12 đang ở trạng thái 'CHO_DUYET')
-- Kỳ vọng: Bị chặn với thông báo lỗi 'Người trả giá chưa có đăng ký được duyệt cho phiên này'
SELECT fn_TraGia(1, 12, 6000000, gen_random_uuid());

-- 3.3. Ca vi phạm: Trả giá sai lưới bước giá (Bước giá phiên 1 là 250,000 nhưng trả 5,800,000)
-- Kỳ vọng: Bị chặn do vi phạm điều kiện bước giá
SELECT fn_TraGia(1, 8, 5800000, gen_random_uuid());


-- TEST CASE 4: KIỂM THỬ TRẢ GIÁ MỨC CÔ LẬP TUẦN TỰ HÓA CÓ RETRY LOOP (SERIALIZABLE)
-- 4.1. Trả giá mức tiếp theo cho Phiên 1 (6,000,000) bằng fn_TraGia_Serializable
SELECT fn_TraGia_Serializable(
    1, 
    7,                          -- Người dùng 7 (đã được duyệt đăng ký phiên 1)
    5750000,                    -- Giá trả hợp lệ tiếp theo
    gen_random_uuid()           -- Sinh ngẫu nhiên mã yêu cầu
);

-- 4.2. Kiểm tra lại thông tin phiên sau giao dịch Serializable:
SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;


-- TEST CASE 5: KIỂM THỬ HÀM ĐÓNG PHIÊN ĐẤU GIÁ (fn_DongPhienDauGia)
-- 5.1. Đóng Phiên 2 (Phiên này trong seed data đã hết thời gian và có lượt trả giá)
SELECT fn_DongPhienDauGia(2);

-- 5.2. Kiểm tra kết quả chốt phiên trong KETQUADAUGIA:
SELECT k.MaPhien, k.MaLuotThang, k.ThoiDiemChot, l.SoTien AS GiaThang, nd.HoTen AS NguoiThang
FROM KETQUADAUGIA k
LEFT JOIN LUOTTRAGIA l ON k.MaLuotThang = l.MaLuotTraGia
LEFT JOIN NGUOIDUNG nd ON l.MaNguoiTraGia = nd.MaNguoiDung
WHERE k.MaPhien = 2;

-- 5.3. Kiểm tra trạng thái phiên số 2 sau khi đóng:
SELECT MaPhien, TrangThaiPhien, GiaHienTai, MaLuotDanDau 
FROM PHIENDAUGIA 
WHERE MaPhien = 2;


-- TEST CASE 6: KIỂM TRA TÍNH NHẤT QUÁN TOÀN BỘ CƠ SỞ DỮ LIỆU
-- Truy vấn đối soát: Hiển thị trạng thái so khớp của toàn bộ 20 phiên đấu giá
SELECT p.MaPhien, p.GiaHienTai, MAX(l.SoTien) AS GiaCaoNhatTrongLichSu,
       CASE 
           WHEN p.GiaHienTai IS NOT DISTINCT FROM MAX(l.SoTien) THEN 'NHAT_QUAN'
           ELSE 'SAI_LECH'
       END AS KetQuaDoiSoat
FROM PHIENDAUGIA p
LEFT JOIN LUOTTRAGIA l ON p.MaPhien = l.MaPhien
GROUP BY p.MaPhien, p.GiaHienTai
ORDER BY p.MaPhien;


-- Hỗ trợ cho minh chứng 5: Đo lường và so sánh thời gian thực thi

-- 1. Đo thời gian thực thi của Phương án 1 (Khóa bi quan FOR UPDATE):
EXPLAIN ANALYZE 
SELECT fn_TraGia(1, 8, 5750000, gen_random_uuid());


-- 2. Đo thời gian thực thi của Phương án 2 (Mức cô lập SERIALIZABLE có Retry Loop):
EXPLAIN ANALYZE 
SELECT fn_TraGia_Serializable(1, 7, 6250000, gen_random_uuid());

