-- ĐỒ ÁN 19: HỆ THỐNG ĐẤU GIÁ TRỰC TUYẾN VÀ KIỂM SOÁT TRẢ GIÁ ĐỒNG THỜI
-- TÀI LIỆU KỊCH BẢN KIỂM THỬ TOÀN DIỆN (TEST CASES & SCRIPTS - BƯỚC 7)

-- Hướng dẫn:
-- 1. Đảm bảo đã chạy lần lượt: DDL_HeThongDauGia.sql -> seed_data.sql -> queries.sql.
-- 2. Mở file này trong pgAdmin/DBeaver, bôi đen và nhấn F5 từng kịch bản để quan sát kết quả.

-- =============================================================================
-- BƯỚC 0: CHUẨN BỊ MÔI TRƯỜNG & GIA HẠN THỜI GIAN ĐÓNG PHIÊN ĐẤU GIÁ
-- Mục đích: Đảm bảo Phiên 1 và Phiên 4 luôn ở trạng thái 'DANG_DIEN_RA' 
-- và thời gian đóng kéo dài thêm 2 giờ kể từ thời điểm test hiện tại.
-- Lưu ý: Giữ nguyên ThoiDiemMo gốc bằng LEAST(...) để các lượt trả giá lịch sử 
-- trong seed_data không bị rơi ra ngoài khung giờ mở phiên.
-- =============================================================================

UPDATE PHIENDAUGIA 
SET TrangThaiPhien = 'DANG_DIEN_RA',
    ThoiDiemMo = LEAST(ThoiDiemMo, CURRENT_TIMESTAMP - INTERVAL '1 hour'),
    ThoiDiemDong = CURRENT_TIMESTAMP + INTERVAL '2 hours' 
WHERE MaPhien IN (1, 4);

-- Kiểm tra trạng thái các phiên đang mở:
SELECT MaPhien, GiaKhoiDiem, BuocGia, GiaHienTai, MaLuotDanDau, PhienBan, ThoiDiemMo, ThoiDiemDong, TrangThaiPhien
FROM PHIENDAUGIA
WHERE TrangThaiPhien = 'DANG_DIEN_RA'
ORDER BY MaPhien;


-- =============================================================================
-- TEST CASE 1: KIỂM THỬ HÀM BÁO CÁO CÓ BỘ LỌC ĐỘNG (Dynamic SQL)
-- =============================================================================
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


-- =============================================================================
-- TEST CASE 2: KIỂM THỬ HÀM TRẢ GIÁ KHÓA BI QUAN & YÊU CẦU GỬI LẠI (MINH CHỨNG 3)
-- Kịch bản đề bài: "Yêu cầu được gửi lại -> Yêu cầu gửi lại không tạo lượt trả giá trùng"
-- =============================================================================
-- 2.1. Trả giá hợp lệ cho Phiên 1 (Người dùng 8 đã duyệt đăng ký, giá khởi điểm 5tr, bước 250k, giá hiện tại 5.5tr)
-- Giá trả hợp lệ tiếp theo: 5,750,000
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

-- 2.1.1. Xem chi tiết lượt trả giá vừa tạo:
SELECT * FROM LUOTTRAGIA WHERE MaYeuCau = '19000000-0000-4000-8000-000000000101'::uuid;

-- 2.2. Kiểm thử tính Idempotency (Gửi lại y hệt cùng mã UUID -> Không tạo lượt mới, trả về đúng mã lượt cũ = 46)
SELECT fn_TraGia(
    1, 
    8, 
    5750000, 
    '19000000-0000-4000-8000-000000000101'::uuid
);

-- Đếm số lượng bản ghi theo MaYeuCau để chứng minh không bị nhân đôi (Kết quả = 1):
SELECT COUNT(*) AS SoLuongBanGhi, MIN(MaLuotTraGia) AS MaLuotDuyNhat
FROM LUOTTRAGIA 
WHERE MaYeuCau = '19000000-0000-4000-8000-000000000101'::uuid;

-- 2.3. Kiểm tra nhật ký và giá hiện tại của Phiên 1 sau khi trả giá:
SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;

SELECT * FROM NHATKYTHAYDOI 
WHERE MaPhien = 1 
ORDER BY ThoiDiemGhi DESC LIMIT 3;


-- =============================================================================
-- TEST CASE 3: KIỂM THỬ RÀNG BUỘC NGHIỆP VỤ & LỖI GIỮA GIAO DỊCH (MINH CHỨNG 4)
-- Kịch bản đề bài: "Lỗi xảy ra sau khi ghi lượt trả nhưng trước khi cập nhật giá hiện tại.
--                   Lỗi giữa giao dịch không để lại dữ liệu dở dang."
-- =============================================================================
-- 3.1. Ca vi phạm 1: Người bán tự trả giá cho tài sản của mình (Phiên 1 do Người dùng 1 bán)
-- Kỳ vọng: Bị chặn với thông báo lỗi 'Người bán không được trả giá tài sản của mình'
SELECT fn_TraGia(1, 1, 6000000, gen_random_uuid());

-- 3.2. Ca vi phạm 2: Người dùng chưa có đăng ký được duyệt (Người dùng 12 đang ở trạng thái 'CHO_DUYET')
-- Kỳ vọng: Bị chặn với thông báo lỗi 'Người trả giá chưa có đăng ký được duyệt cho phiên này'
SELECT fn_TraGia(1, 12, 6000000, gen_random_uuid());

-- 3.3. Ca vi phạm 3: Trả giá sai lưới bước giá (Bước giá phiên 1 là 250,000 nhưng trả 5,800,000)
-- Kỳ vọng: Bị chặn do vi phạm điều kiện bước giá
SELECT fn_TraGia(1, 8, 5800000, gen_random_uuid());

-- -----------------------------------------------------------------------------
-- 3.4. MINH CHỨNG 4 (CHUẨN ĐỀ BÀI): LỖI XẢY RA SAU KHI GHI LƯỢT TRẢ NHƯNG TRƯỚC KHI CẬP NHẬT GIÁ HIỆN TẠI
-- Cách 1 (Chạy từng lệnh để quan sát Rollback trực tiếp):
--   Bước A: Xem số lượt trả giá hiện tại của Phiên 1 trước khi xảy ra sự cố
SELECT COUNT(*) AS SoLuotTruocSuCo, MAX(SoTien) AS GiaCaoNhatTruocSuCo
FROM LUOTTRAGIA WHERE MaPhien = 1;

--   Bước B: Mở giao dịch, INSERT thành công vào LUOTTRAGIA nhưng gặp sự cố trước khi UPDATE PHIENDAUGIA
BEGIN;
INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
VALUES (1, 7, 9500000, '19000000-0000-4000-8000-000000000999'::uuid, clock_timestamp());

-- Giả lập sự cố nghiêm trọng xảy ra NGAY SAU KHI ghi LUOTTRAGIA nhưng TRƯỚC KHI cập nhật GiaHienTai:
SELECT 1 / 0;
-- (Sau khi pgAdmin báo lỗi division by zero, bôi đen dòng ROLLBACK; bên dưới và nhấn F5)
ROLLBACK;

--   Bước C: Kiểm tra lại sau sự cố -> Lượt trả giá 9,500,000 đã bị hủy hoàn toàn, không còn dữ liệu dở dang!
SELECT COUNT(*) AS SoLuotSauRollback,
       COUNT(*) FILTER (WHERE MaYeuCau = '19000000-0000-4000-8000-000000000999'::uuid) AS SoLuotDoDang,
       (SELECT GiaHienTai FROM PHIENDAUGIA WHERE MaPhien = 1) AS GiaHienTaiPhien1
FROM LUOTTRAGIA WHERE MaPhien = 1;


-- =============================================================================
-- TEST CASE 4: KIỂM THỬ PHƯƠNG ÁN 2 (SERIALIZABLE CÓ THỬ LẠI) & NHIỀU NGƯỜI TRẢ GIÁ CÙNG LÚC
-- Lưu ý: fn_TraGia_Serializable phải chạy trong BEGIN ISOLATION LEVEL SERIALIZABLE.
-- Nếu gặp lỗi 40001 thì ROLLBACK rồi chạy lại cả khối với cùng mã yêu cầu.
-- Kịch bản đề bài: "Nhiều người trả giá cùng lúc" (Concurrent Bidding)
-- =============================================================================
-- 4.1. Trả giá mức hợp lệ tiếp theo cho Phiên 1 (6,000,000) bằng fn_TraGia_Serializable
--      (bôi đen từ BEGIN tới COMMIT rồi nhấn F5)
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT fn_TraGia_Serializable(
    1, 
    7,                          -- Người dùng 7 (đã được duyệt đăng ký phiên 1)
    6000000,                    -- Giá trả hợp lệ tiếp theo (5,750,000 + 250,000)
    '19000000-0000-4000-8000-000000000102'::uuid
);
COMMIT;

-- Kiểm tra lại thông tin Phiên 1 sau giao dịch (GiaHienTai = 6,000,000, PhienBan = 5):
SELECT MaPhien, GiaHienTai, MaLuotDanDau, PhienBan 
FROM PHIENDAUGIA 
WHERE MaPhien = 1;

-- -----------------------------------------------------------------------------
-- 4.2. KỊCH BẢN THỰC NGHIỆM: NHIỀU NGƯỜI TRẢ GIÁ CÙNG LÚC (CONCURRENT BIDDING)
-- Mục đích: Kiểm chứng khi Người dùng 8 và Người dùng 7 cùng nhìn thấy mức giá 
--           hiện tại là 6,000,000 và cùng gửi lệnh trả giá 6,250,000 vào Phiên 1:
--   + Yêu cầu đến trước (Người dùng 8) được chấp nhận, đẩy GiaHienTai lên 6,250,000.
--   + Yêu cầu đồng thời đến ngay sau (Người dùng 7) phát hiện xung đột, bị từ chối 
--     chính xác, không xảy ra Lost Update hay trùng mức giá.
-- Cách 1 (Bôi đen từ BEGIN đến ROLLBACK bên dưới và nhấn F5 để xem bảng kết quả ngay):
--   Cách này chạy tuần tự trong một giao dịch (yêu cầu sau thấy giá mới nên bị từ chối).
--   Muốn chạy song song thật thì làm theo Cách 2 bên dưới.
-- -----------------------------------------------------------------------------
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
    -- Giao dịch 1 (Người dùng 8 đặt mức 6,250,000): Chiếm quyền cập nhật trước
    v_ma_luot := fn_TraGia_Serializable(1, 8, 6250000, gen_random_uuid());
    SELECT GiaHienTai, PhienBan INTO v_gia, v_pb FROM PHIENDAUGIA WHERE MaPhien = 1;
    INSERT INTO kq_tranh_chap_dong_thoi VALUES (
        1, 'Người dùng 8 (Bùi Quốc Nam)', 6250000, 'THANH_CONG',
        'Chấp nhận lượt trả giá #' || v_ma_luot, v_gia, v_pb
    );

    -- Giao dịch 2 (Người dùng 7 cùng đặt mức 6,250,000 dựa trên ảnh chụp cũ 6,000,000):
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

-- -----------------------------------------------------------------------------
-- Cách 2 (Chạy song song trên 2 Tab Query Tool, cả 2 tab đều SERIALIZABLE):
-- * Tại TAB A (Người dùng 8 đặt mức 6,500,000 nhưng giữ giao dịch chưa COMMIT):
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT fn_TraGia_Serializable(1, 8, 6500000, '19000000-0000-4000-8000-0000000004a1'::uuid);
--
-- * Tại TAB B (Cùng lúc đó, Người dùng 7 nhìn giá cũ 6,000,000 và đặt mức 6,250,000):
--   BEGIN ISOLATION LEVEL SERIALIZABLE;
--   SELECT fn_TraGia_Serializable(1, 7, 6250000, '19000000-0000-4000-8000-0000000004b1'::uuid);
--   --> Tab B phải chờ vì Tab A đang ghi cùng dòng phiên.
--
-- * Quay lại TAB A và nhấn F5 lệnh:
--   COMMIT;
--   --> Tab A thành công (GiaHienTai = 6,500,000).
--   --> Tab B nhận lỗi 40001 "could not serialize access due to concurrent update",
--       tức là Tab B đọc giá cũ nên không được ghi đè (không bị mất cập nhật).
--
-- * Tại TAB B: ROLLBACK; rồi chạy lại đúng khối BEGIN ... SELECT ... (cùng mã yêu cầu) và COMMIT;
--   --> Lần chạy lại thấy GiaHienTai = 6,500,000 nên từ chối mức 6,250,000
--       ("Giá trả phải từ 6750000.00 ...").
-- -----------------------------------------------------------------------------


-- =============================================================================
-- TEST CASE 5: KIỂM THỬ ĐÓNG PHIÊN & TRẢ GIÁ CẠNH TRANH VỚI ĐÓNG PHIÊN (MINH CHỨNG 1)
-- Kịch bản đề bài: "Trả giá cạnh tranh với đóng phiên; 
--                   Mỗi phiên kết thúc có tối đa một kết quả thắng theo quy tắc đã công bố."
-- =============================================================================
-- 5.1. Đóng Phiên 2 (Phiên này đã hết thời gian và có 2 lượt trả giá: 2,000,000 và 2,100,000)
SELECT fn_DongPhienDauGia(2);

-- 5.2. Kiểm tra kết quả chốt phiên trong KETQUADAUGIA (Chốt duy nhất 1 dòng, MaLuotThang = 5, GiaThang = 2,100,000):
SELECT k.MaPhien, k.MaLuotThang, k.ThoiDiemChot, l.SoTien AS GiaThang, nd.HoTen AS NguoiThang
FROM KETQUADAUGIA k
LEFT JOIN LUOTTRAGIA l ON k.MaLuotThang = l.MaLuotTraGia AND k.MaPhien = l.MaPhien
LEFT JOIN NGUOIDUNG nd ON l.MaNguoiTraGia = nd.MaNguoiDung
WHERE k.MaPhien = 2;

-- 5.3. Kiểm tra trạng thái Phiên 2 sau khi đóng:
SELECT MaPhien, TrangThaiPhien, GiaHienTai, MaLuotDanDau, PhienBan
FROM PHIENDAUGIA 
WHERE MaPhien = 2;

-- -----------------------------------------------------------------------------
-- 5.4. KỊCH BẢN THỰC NGHIỆM: TRẢ GIÁ CẠNH TRANH VỚI ĐÓNG PHIÊN (TRÊN PHIÊN 4)
-- Mục đích: Chứng minh giao dịch đóng phiên phối hợp chặt chẽ với giao dịch trả giá,
--           loại trừ lẫn nhau (Mutual Exclusion) và mọi lượt trả giá đến sau khi
--           phiên đóng đều bị từ chối chính xác.
--
-- Bước A: Người dùng 7 trả giá hợp lệ vào Phiên 4 lúc phiên đang mở (Giá khởi điểm 3,000,000)
SELECT fn_TraGia(4, 7, 3000000, '19000000-0000-4000-8000-000000000104'::uuid);

-- Bước B: Giả lập thời điểm hiện tại vừa chạm mốc ThoiDiemDong của Phiên 4 và tiến trình đóng phiên kích hoạt
UPDATE PHIENDAUGIA SET ThoiDiemDong = clock_timestamp() - INTERVAL '1 second' WHERE MaPhien = 4;
SELECT fn_DongPhienDauGia(4);

-- Bước C: Đúng lúc đó, Người dùng 8 gửi lệnh trả giá cạnh tranh (3,200,000) vào Phiên 4
-- Kỳ vọng: Bị chặn ngay lập tức với lỗi "ERROR: Phiên không nhận trả giá" (do phiên đã chuyển sang DA_DONG)
SELECT fn_TraGia(4, 8, 3200000, gen_random_uuid());

-- Bước D: Kiểm tra bảng KETQUADAUGIA của Phiên 4 -> Chỉ có duy nhất 1 kết quả thắng của Người dùng 7 (3,000,000)
SELECT k.MaPhien, p.TrangThaiPhien, k.MaLuotThang, l.SoTien AS GiaThang, nd.HoTen AS NguoiThang
FROM KETQUADAUGIA k
JOIN PHIENDAUGIA p ON p.MaPhien = k.MaPhien
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
WHERE k.MaPhien = 4;


-- =============================================================================
-- TEST CASE 6: KIỂM TRA TÍNH NHẤT QUÁN TOÀN BỘ CƠ SỞ DỮ LIỆU (MINH CHỨNG 2)
-- Kịch bản đề bài: "Giá cao nhất lưu riêng luôn khớp với lịch sử trả giá được chấp nhận."
-- =============================================================================
-- 6.1. Truy vấn đối soát: Hiển thị trạng thái so khớp của toàn bộ 20 phiên đấu giá (Tất cả đều NHAT_QUAN)
SELECT p.MaPhien, p.TrangThaiPhien, p.GiaHienTai, MAX(l.SoTien) AS GiaCaoNhatTrongLichSu,
       CASE 
           WHEN p.GiaHienTai IS NOT DISTINCT FROM MAX(l.SoTien) THEN 'NHAT_QUAN'
           ELSE 'SAI_LECH'
       END AS KetQuaDoiSoat
FROM PHIENDAUGIA p
LEFT JOIN LUOTTRAGIA l ON p.MaPhien = l.MaPhien
GROUP BY p.MaPhien, p.TrangThaiPhien, p.GiaHienTai
ORDER BY p.MaPhien;


-- =============================================================================
-- TEST CASE 7: ĐO LƯỜNG VÀ SO SÁNH ĐỊNH LƯỢNG 2 PHƯƠNG ÁN TRÊN CÙNG DỮ LIỆU (MINH CHỨNG 5)
-- Kịch bản đề bài: "Có bảng so sánh hai giải pháp kiểm soát đồng thời trên cùng dữ liệu và cấu hình."
-- Lưu ý: Bọc trong BEGIN ... ROLLBACK để cả 2 phương án đều chạy trên cùng một trạng thái 
--        dữ liệu hệt nhau của Phiên 1 (mức giá 6,250,000) và không làm thay đổi dữ liệu thật.
-- =============================================================================

-- 7.1. Đo thời gian thực thi của Phương án 1 (Khóa bi quan SELECT ... FOR UPDATE):
BEGIN;
EXPLAIN ANALYZE 
SELECT fn_TraGia(1, 8, 6250000, gen_random_uuid());
ROLLBACK;

-- 7.2. Đo thời gian thực thi của Phương án 2 (SERIALIZABLE):
BEGIN ISOLATION LEVEL SERIALIZABLE;
EXPLAIN ANALYZE 
SELECT fn_TraGia_Serializable(1, 8, 6250000, gen_random_uuid());
ROLLBACK;
