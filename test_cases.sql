-- ĐỒ ÁN 19: HỆ THỐNG ĐẤU GIÁ TRỰC TUYẾN VÀ KIỂM SOÁT TRẢ GIÁ ĐỒNG THỜI
-- KỊCH BẢN THỰC NGHIỆM VÀ PHÂN TÍCH KẾT QUẢ (BƯỚC 7)
-- Thứ tự chạy trước khi test: DDL_HeThongDauGia.sql -> seed_data.sql -> queries.sql.


-- BƯỚC 0: CHUẨN BỊ MÔI TRƯỜNG (Gia hạn thời gian mở cho Phiên 1 và Phiên 4)
UPDATE PHIENDAUGIA 
SET TrangThaiPhien = 'DANG_DIEN_RA',
    ThoiDiemMo = LEAST(ThoiDiemMo, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
    ThoiDiemDong = CURRENT_TIMESTAMP + INTERVAL '2 hours' 
WHERE MaPhien IN (1, 4);

SELECT MaPhien, GiaKhoiDiem, BuocGia, GiaHienTai, MaLuotDanDau, PhienBan, ThoiDiemMo, ThoiDiemDong, TrangThaiPhien
FROM PHIENDAUGIA
WHERE TrangThaiPhien = 'DANG_DIEN_RA'
ORDER BY MaPhien;


-- KỊCH BẢN 1: NHIỀU NGƯỜI TRẢ GIÁ CÙNG LÚC (CONCURRENT BIDDING)

-- Cách 1: Chạy trực tiếp khối dưới đây trên 1 Tab để xem bảng kết quả khi Người dùng 8 và Người dùng 7 cùng đặt mức 6,250,000
BEGIN ISOLATION LEVEL SERIALIZABLE;

CREATE TEMP TABLE kq_tranh_chap_dong_thoi (
    ThuTuXuLy INT,
    NguoiThamGia TEXT,
    MucGiaDat NUMERIC(16,2),
    TrangThaiKetQua TEXT,
    MaLuotHoacThongBao TEXT,
    GiaHienTaiSauXuLy NUMERIC(16,2),
    PhienBanSauXuLy INT
) ON COMMIT DROP;

DO $$
DECLARE
    v_ma_luot BIGINT;
    v_gia NUMERIC;
    v_pb INT;
BEGIN
    v_ma_luot := fn_TraGia_Serializable(1, 8, 6250000, gen_random_uuid());
    SELECT GiaHienTai, PhienBan INTO v_gia, v_pb FROM PHIENDAUGIA WHERE MaPhien = 1;
    INSERT INTO kq_tranh_chap_dong_thoi VALUES (
        1, 'Người dùng 8 (Bùi Quốc Nam)', 6250000, 'THANH_CONG',
        'Chấp nhận lượt trả giá #' || v_ma_luot, v_gia, v_pb
    );

    BEGIN
        v_ma_luot := fn_TraGia_Serializable(1, 7, 6250000, gen_random_uuid());
    EXCEPTION WHEN OTHERS THEN
        SELECT GiaHienTai, PhienBan INTO v_gia, v_pb FROM PHIENDAUGIA WHERE MaPhien = 1;
        INSERT INTO kq_tranh_chap_dong_thoi VALUES (
            2, 'Người dùng 7 (Đỗ Mỹ Linh)', 6250000, 'BI_TU_CHOI_DO_XUNG_DOT',
            SQLERRM, v_gia, v_pb
        );
    END;
END $$;

SELECT * FROM kq_tranh_chap_dong_thoi ORDER BY ThuTuXuLy;

ROLLBACK;

-- Cách 2: Chạy song song trên 2 Tab Query Tool độc lập (Mức cô lập SERIALIZABLE)
-- [Tab A] Người dùng 8 trả 6,500,000 nhưng chưa COMMIT:
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT fn_TraGia_Serializable(1, 8, 6500000, '19000000-0000-4000-8000-0000000004a1'::uuid);
-- [Tab B] Người dùng 7 nhìn giá cũ và trả 6,250,000 (Tab B sẽ tạm chờ Tab A):
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT fn_TraGia_Serializable(1, 7, 6250000, '19000000-0000-4000-8000-0000000004b1'::uuid);
-- [Tab A] Chốt giao dịch:
--   COMMIT;  --> Tab A thành công (6,500,000); Tab B nhận lỗi 40001 (serialization_failure).
-- [Tab B] Hủy giao dịch cũ và thử lại (Retry) trên snapshot mới:
--   ROLLBACK;
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT fn_TraGia_Serializable(1, 7, 6250000, '19000000-0000-4000-8000-0000000004b1'::uuid);
--   COMMIT;  --> Thấy GiaHienTai = 6,500,000 nên từ chối mức giá 6,250,000.


-- KỊCH BẢN 2: YÊU CẦU ĐƯỢC GỬI LẠI (MINH CHỨNG 3: KHÔNG TẠO LƯỢT TRẢ GIÁ TRÙNG)

-- 2.1. Người dùng 8 trả giá hợp lệ 5,750,000 cho Phiên 1 (giá hiện tại 5,500,000, bước giá 250,000)
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

SELECT * FROM LUOTTRAGIA WHERE MaYeuCau = '19000000-0000-4000-8000-000000000101'::uuid;

-- 2.2. Gửi lại yêu cầu với cùng mã UUID -> Không tạo lượt mới, trả về đúng mã lượt cũ (46)
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

-- Kiểm tra số bản ghi của mã yêu cầu trên (Kết quả = 1 dòng duy nhất)
SELECT COUNT(*) AS SoLuongBanGhi, MIN(MaLuotTraGia) AS MaLuotDuyNhat
FROM LUOTTRAGIA 
WHERE MaYeuCau = '19000000-0000-4000-8000-000000000101'::uuid;

-- 2.3. Kiểm tra giá hiện tại và nhật ký của Phiên 1 sau khi trả giá
SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;

SELECT * FROM NHATKYTHAYDOI 
WHERE MaPhien = 1 
ORDER BY ThoiDiemGhi DESC LIMIT 3;


-- KỊCH BẢN 3: TRẢ GIÁ CẠNH TRANH VỚI ĐÓNG PHIÊN (MINH CHỨNG 1: TỐI ĐA MỘT KẾT QUẢ THẮNG)

-- 3.1. Đóng Phiên 2 và kiểm tra kết quả thắng duy nhất trong KETQUADAUGIA (MaLuotThang = 4, GiaThang = 2,100,000)
SELECT fn_DongPhienDauGia(2);

SELECT k.MaPhien, k.MaLuotThang, k.ThoiDiemChot, l.SoTien AS GiaThang, nd.HoTen AS NguoiThang
FROM KETQUADAUGIA k
LEFT JOIN LUOTTRAGIA l ON k.MaLuotThang = l.MaLuotTraGia AND k.MaPhien = l.MaPhien
LEFT JOIN NGUOIDUNG nd ON l.MaNguoiTraGia = nd.MaNguoiDung
WHERE k.MaPhien = 2;

SELECT MaPhien, TrangThaiPhien, GiaHienTai, MaLuotDanDau, PhienBan
FROM PHIENDAUGIA 
WHERE MaPhien = 2;

-- 3.2. Trả giá cạnh tranh với đóng phiên (Trên Phiên 4)
-- Bước A: Người dùng 7 trả giá hợp lệ 3,000,000 khi Phiên 4 đang mở
SELECT fn_TraGia(4, 7, 3000000, '19000000-0000-4000-8000-000000000104'::uuid);

-- Bước B: Phiên 4 chạm mốc giờ đóng và kích hoạt hàm đóng phiên
UPDATE PHIENDAUGIA SET ThoiDiemDong = clock_timestamp() - INTERVAL '1 second' WHERE MaPhien = 4;
SELECT fn_DongPhienDauGia(4);

-- Bước C: Người dùng 8 gửi lệnh trả giá cạnh tranh 3,200,000 ngay lúc phiên vừa đóng -> Bị từ chối
SELECT fn_TraGia(4, 8, 3200000, gen_random_uuid());

-- Bước D: Kiểm tra kết quả chốt Phiên 4 (Chỉ có duy nhất 1 kết quả thắng của Người dùng 7)
SELECT k.MaPhien, p.TrangThaiPhien, k.MaLuotThang, l.SoTien AS GiaThang, nd.HoTen AS NguoiThang
FROM KETQUADAUGIA k
JOIN PHIENDAUGIA p ON p.MaPhien = k.MaPhien
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
WHERE k.MaPhien = 4;


-- KỊCH BẢN 4: LỖI XẢY RA SAU KHI GHI LƯỢT TRẢ NHƯNG TRƯỚC KHI CẬP NHẬT GIÁ HIỆN TẠI (MINH CHỨNG 4)

-- 4.1. Bước A: Xem số lượt trả giá của Phiên 1 trước khi gặp sự cố
SELECT COUNT(*) AS SoLuotTruocSuCo, MAX(SoTien) AS GiaCaoNhatTruocSuCo
FROM LUOTTRAGIA WHERE MaPhien = 1;

-- 4.2. Bước B: Ghi vào LUOTTRAGIA thành công nhưng gặp lỗi chia cho 0 trước khi UPDATE PHIENDAUGIA
BEGIN;
INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
VALUES (1, 7, 9500000, '19000000-0000-4000-8000-000000000999'::uuid, clock_timestamp());

SELECT 1 / 0;
-- Sau khi báo lỗi division by zero, bôi đen dòng ROLLBACK; bên dưới và nhấn F5:
ROLLBACK;

-- 4.3. Bước C: Đối soát lại sau khi Rollback (Không còn lượt 9,500,000 dở dang, GiaHienTai giữ nguyên)
SELECT COUNT(*) AS SoLuotSauRollback,
       COUNT(*) FILTER (WHERE MaYeuCau = '19000000-0000-4000-8000-000000000999'::uuid) AS SoLuotDoDang,
       (SELECT GiaHienTai FROM PHIENDAUGIA WHERE MaPhien = 1) AS GiaHienTaiPhien1
FROM LUOTTRAGIA WHERE MaPhien = 1;

-- 4.4. Kiểm thử bổ sung các ca vi phạm quy tắc nghiệp vụ (tự động Rollback)
SELECT fn_TraGia(1, 1, 6000000, gen_random_uuid());  -- Người bán tự trả giá tài sản của mình
SELECT fn_TraGia(1, 12, 6000000, gen_random_uuid()); -- Người dùng chưa được duyệt đăng ký ('CHO_DUYET')
SELECT fn_TraGia(1, 8, 5800000, gen_random_uuid());  -- Trả giá lệch lưới bước giá (bước giá 250,000)


-- KỊCH BẢN 5: ĐO THỜI GIAN PHẢN HỒI, SO SÁNH 2 PHƯƠNG ÁN & ĐỐI SOÁT NHẤT QUÁN (MINH CHỨNG 5 & MINH CHỨNG 2)

-- 5.1. Người dùng 7 trả giá mức 6,000,000 cho Phiên 1 trong giao dịch SERIALIZABLE
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT fn_TraGia_Serializable(
    1, 
    7, 
    6000000, 
    '19000000-0000-4000-8000-000000000102'::uuid
);
COMMIT;

SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;

-- 5.2. Đo thời gian phản hồi của 2 phương án trên cùng dữ liệu Phiên 1 (Mức giá 6,250,000 - Minh chứng 5)
-- Phương án 1: Khóa bi quan dòng (SELECT ... FOR UPDATE)
BEGIN;
EXPLAIN ANALYZE 
SELECT fn_TraGia(1, 8, 6250000, gen_random_uuid());
ROLLBACK;

-- Phương án 2: Mức cô lập tuần tự hóa (SERIALIZABLE)
BEGIN ISOLATION LEVEL SERIALIZABLE;
EXPLAIN ANALYZE 
SELECT fn_TraGia_Serializable(1, 8, 6250000, gen_random_uuid());
ROLLBACK;

-- 5.3. Đối soát GiaHienTai luôn khớp với lịch sử trả giá MAX(SoTien) trên toàn bộ 20 phiên (Minh chứng 2)
SELECT p.MaPhien, p.TrangThaiPhien, p.GiaHienTai, MAX(l.SoTien) AS GiaCaoNhatTrongLichSu,
       CASE 
           WHEN p.GiaHienTai IS NOT DISTINCT FROM MAX(l.SoTien) THEN 'NHAT_QUAN'
           ELSE 'SAI_LECH'
       END AS KetQuaDoiSoat
FROM PHIENDAUGIA p
LEFT JOIN LUOTTRAGIA l ON p.MaPhien = l.MaPhien
GROUP BY p.MaPhien, p.TrangThaiPhien, p.GiaHienTai
ORDER BY p.MaPhien;


-- KIỂM THỬ BỔ SUNG: HÀM BÁO CÁO CÓ BỘ LỌC ĐỘNG (fn_BaoCaoPhienDauGiaDong - BƯỚC 4)

-- Lấy toàn bộ các phiên đấu giá (không truyền bộ lọc)
SELECT * FROM fn_BaoCaoPhienDauGiaDong();

-- Lọc theo nhánh Danh mục 1 ("Thiết bị công nghệ & Điện tử" và các danh mục con)
SELECT * FROM fn_BaoCaoPhienDauGiaDong(p_MaDanhMucGoc => 1);

-- Lọc theo loại tài sản 'DOSUUTAM' trong khoảng giá từ 1,000,000 đến 50,000,000
SELECT * FROM fn_BaoCaoPhienDauGiaDong(
    p_LoaiTaiSan => 'DOSUUTAM',
    p_GiaTu      => 1000000,
    p_GiaDen     => 50000000
);

-- Tìm kiếm gần đúng theo từ khóa tên tài sản
SELECT * FROM fn_BaoCaoPhienDauGiaDong(p_TuKhoa => 'macbook');



