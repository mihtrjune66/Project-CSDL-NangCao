-- Truy vấn: Xây dựng cây phân cấp danh mục và thống kê cộng dồn 
-- (Roll-up) tổng số tài sản & phiên đấu giá từ danh mục con lên danh mục cha

WITH RECURSIVE CayDanhMuc AS (
    -- Bước cơ sở: Lấy các danh mục gốc (Cấp 1)
    SELECT 
        dm.MaDanhMuc,
        dm.TenDanhMuc,
        dm.MaDanhMucCha,
        1 AS CapDo,
        dm.TenDanhMuc::TEXT AS DuongDanPhanCap,
        LPAD('', 0, ' ') || dm.TenDanhMuc AS TenHienThiCay
    FROM DANHMUC dm
    WHERE dm.MaDanhMucCha IS NULL

    UNION ALL

    -- Bước đệ quy: Nối các danh mục con vào danh mục cha
    SELECT 
        con.MaDanhMuc,
        con.TenDanhMuc,
        con.MaDanhMucCha,
        cha.CapDo + 1 AS CapDo,
        (cha.DuongDanPhanCap || ' - ' || con.TenDanhMuc)::TEXT AS DuongDanPhanCap,
        (REPEAT('    ', cha.CapDo) || '|-- ' || con.TenDanhMuc)::VARCHAR(255) AS TenHienThiCay
    FROM DANHMUC con
    INNER JOIN CayDanhMuc cha ON con.MaDanhMucCha = cha.MaDanhMuc
),
-- CTE phụ: Tìm mọi cặp (Danh mục Tổ tiên, Danh mục Con cháu bao gồm chính nó)
-- để tính tổng cộng dồn từ các nhánh lá lên nhánh gốc
QuanHeToTienConChau AS (
    SELECT MaDanhMuc AS MaToTien, MaDanhMuc AS MaConChau
    FROM DANHMUC
    
    UNION ALL
    
    SELECT qh.MaToTien, dm.MaDanhMuc AS MaConChau
    FROM QuanHeToTienConChau qh
    INNER JOIN DANHMUC dm ON dm.MaDanhMucCha = qh.MaConChau
),
ThongKeCongDon AS (
    SELECT 
        qh.MaToTien AS MaDanhMuc,
        COUNT(DISTINCT ts.MaTaiSan) AS TongSoTaiSanTrongNhanh,
        COUNT(DISTINCT pdg.MaPhien) AS TongSoPhienTrongNhanh
    FROM QuanHeToTienConChau qh
    LEFT JOIN TAISAN ts ON ts.MaDanhMuc = qh.MaConChau
    LEFT JOIN PHIENDAUGIA pdg ON pdg.MaTaiSan = ts.MaTaiSan
    GROUP BY qh.MaToTien
)
SELECT 
    c.MaDanhMuc,
    c.CapDo,
    c.TenHienThiCay AS CauTrucCayDanhMuc,
    tk.TongSoTaiSanTrongNhanh,
    tk.TongSoPhienTrongNhanh,
    c.DuongDanPhanCap
FROM CayDanhMuc c
LEFT JOIN ThongKeCongDon tk ON c.MaDanhMuc = tk.MaDanhMuc
ORDER BY c.DuongDanPhanCap;

-- Truy vấn: Tìm toàn bộ Tài sản và Phiên đấu giá thuộc một nhánh 
-- danh mục bất kỳ (Ví dụ: Nhánh 1 - 'Thiết bị công nghệ & Điện tử')
-- ---------------------------------------------------------------------
WITH RECURSIVE NhanhDanhMucCon AS (
    -- Chọn danh mục gốc cần tra cứu (có thể đổi MaDanhMuc = 1, 2, hoặc 3...)
    SELECT MaDanhMuc, TenDanhMuc, MaDanhMucCha, 1 AS CapDo
    FROM DANHMUC
    WHERE MaDanhMuc = 1 

    UNION ALL

    -- Đệ quy lấy toàn bộ danh mục con, cháu bên dưới
    SELECT dm.MaDanhMuc, dm.TenDanhMuc, dm.MaDanhMucCha, ndm.CapDo + 1
    FROM DANHMUC dm
    INNER JOIN NhanhDanhMucCon ndm ON dm.MaDanhMucCha = ndm.MaDanhMuc
)
SELECT 
    ndm.MaDanhMuc,
    ndm.TenDanhMuc,
    ts.MaTaiSan,
    ts.TenTaiSan,
    ts.LoaiTaiSan,
    nd.HoTen AS NguoiBan,
    pdg.MaPhien,
    pdg.GiaKhoiDiem,
    COALESCE(pdg.GiaHienTai, pdg.GiaKhoiDiem) AS GiaHienTaiHoacKhoiDiem,
    pdg.TrangThaiPhien
FROM NhanhDanhMucCon ndm
INNER JOIN TAISAN ts ON ts.MaDanhMuc = ndm.MaDanhMuc
INNER JOIN NGUOIDUNG nd ON nd.MaNguoiDung = ts.MaNguoiBan
LEFT JOIN PHIENDAUGIA pdg ON pdg.MaTaiSan = ts.MaTaiSan
ORDER BY ndm.MaDanhMuc, ts.MaTaiSan;


-- HÀM BÁO CÁO CÓ BỘ LỌC ĐỘNG 
-- Mục đích: Cho phép lọc danh sách phiên đấu giá theo nhiều tiêu chí tùy chọn:
--   + p_MaDanhMucGoc : Lọc theo nhánh danh mục (tự động lấy cả danh mục con cháu)
--   + p_TrangThai    : Lọc theo trạng thái phiên (VD: 'DANG_MO', 'DA_DONG'...)
--   + p_LoaiTaiSan   : Lọc theo phân lớp ('TACPHAMNGHETHUAT', 'DOSUUTAM', 'THIETBIDIENTU')
--   + p_GiaTu / p_GiaDen: Khoảng giá hiện tại (hoặc giá khởi điểm nếu chưa ai trả giá)
--   + p_TuKhoa       : Tìm kiếm gần đúng (ILIKE) theo tên tài sản
-- Sử dụng kỹ thuật Dynamic SQL (EXECUTE ... USING) chống SQL Injection.

CREATE OR REPLACE FUNCTION fn_BaoCaoPhienDauGiaDong(
    p_MaDanhMucGoc BIGINT DEFAULT NULL,
    p_TrangThai VARCHAR(50) DEFAULT NULL,
    p_LoaiTaiSan VARCHAR(50) DEFAULT NULL,
    p_GiaTu NUMERIC(16,2) DEFAULT NULL,
    p_GiaDen NUMERIC(16,2) DEFAULT NULL,
    p_TuKhoa VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE (
    MaPhien BIGINT,
    TenTaiSan VARCHAR(255),
    LoaiTaiSan VARCHAR(50),
    TenDanhMuc VARCHAR(255),
    NguoiBan VARCHAR(255),
    GiaKhoiDiem NUMERIC(16,2),
    GiaHienTai NUMERIC(16,2),
    SoLuotTraGia BIGINT,
    NguoiDanDau VARCHAR(255),
    ThoiDiemMo TIMESTAMPTZ,
    ThoiDiemDong TIMESTAMPTZ,
    TrangThaiPhien VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    -- Khởi tạo khung truy vấn kết hợp CTE đệ quy để hỗ trợ lọc theo nhánh danh mục
    v_sql := '
        WITH RECURSIVE CayDanhMucLoc AS (
            SELECT dm.MaDanhMuc, dm.TenDanhMuc, dm.MaDanhMucCha
            FROM DANHMUC dm
            WHERE ($1 IS NULL AND dm.MaDanhMucCha IS NULL) 
               OR ($1 IS NOT NULL AND dm.MaDanhMuc = $1)
            
            UNION ALL
            
            SELECT con.MaDanhMuc, con.TenDanhMuc, con.MaDanhMucCha
            FROM DANHMUC con
            INNER JOIN CayDanhMucLoc cha ON con.MaDanhMucCha = cha.MaDanhMuc
        )
        SELECT 
            pdg.MaPhien,
            ts.TenTaiSan,
            ts.LoaiTaiSan,
            cdm.TenDanhMuc,
            nb.HoTen AS NguoiBan,
            pdg.GiaKhoiDiem,
            pdg.GiaHienTai,
            COUNT(ltg.MaLuotTraGia) AS SoLuotTraGia,
            ndd.HoTen AS NguoiDanDau,
            pdg.ThoiDiemMo,
            pdg.ThoiDiemDong,
            pdg.TrangThaiPhien
        FROM PHIENDAUGIA pdg
        INNER JOIN TAISAN ts ON pdg.MaTaiSan = ts.MaTaiSan
        INNER JOIN CayDanhMucLoc cdm ON ts.MaDanhMuc = cdm.MaDanhMuc
        INNER JOIN NGUOIDUNG nb ON ts.MaNguoiBan = nb.MaNguoiDung
        LEFT JOIN LUOTTRAGIA ltg ON pdg.MaPhien = ltg.MaPhien
        LEFT JOIN LUOTTRAGIA ltg_dd ON pdg.MaLuotDanDau = ltg_dd.MaLuotTraGia AND pdg.MaPhien = ltg_dd.MaPhien
        LEFT JOIN NGUOIDUNG ndd ON ltg_dd.MaNguoiTraGia = ndd.MaNguoiDung
        WHERE 1 = 1
    ';

    -- Gắn động từng điều kiện lọc nếu tham số được truyền vào (khác NULL)
    IF p_TrangThai IS NOT NULL THEN
        v_sql := v_sql || ' AND pdg.TrangThaiPhien = $2';
    END IF;

    IF p_LoaiTaiSan IS NOT NULL THEN
        v_sql := v_sql || ' AND ts.LoaiTaiSan = $3';
    END IF;

    IF p_GiaTu IS NOT NULL THEN
        v_sql := v_sql || ' AND COALESCE(pdg.GiaHienTai, pdg.GiaKhoiDiem) >= $4';
    END IF;

    IF p_GiaDen IS NOT NULL THEN
        v_sql := v_sql || ' AND COALESCE(pdg.GiaHienTai, pdg.GiaKhoiDiem) <= $5';
    END IF;

    IF p_TuKhoa IS NOT NULL THEN
        v_sql := v_sql || ' AND ts.TenTaiSan ILIKE ''%'' || $6 || ''%''';
    END IF;

    -- Gom nhóm và sắp xếp kết quả
    v_sql := v_sql || '
        GROUP BY 
            pdg.MaPhien, ts.TenTaiSan, ts.LoaiTaiSan, cdm.TenDanhMuc, 
            nb.HoTen, pdg.GiaKhoiDiem, pdg.GiaHienTai, ndd.HoTen, 
            pdg.ThoiDiemMo, pdg.ThoiDiemDong, pdg.TrangThaiPhien
        ORDER BY pdg.ThoiDiemDong ASC, pdg.MaPhien ASC
    ';

    -- Thực thi câu lệnh Dynamic SQL với bộ tham số truyền vào qua mệnh đề USING
    RETURN QUERY EXECUTE v_sql 
    USING p_MaDanhMucGoc, p_TrangThai, p_LoaiTaiSan, p_GiaTu, p_GiaDen, p_TuKhoa;
END;
$$;

SELECT * FROM fn_BaoCaoPhienDauGiaDong();
SELECT * FROM fn_BaoCaoPhienDauGiaDong(p_MaDanhMucGoc => 1);
SELECT * FROM fn_BaoCaoPhienDauGiaDong(
    p_LoaiTaiSan => 'DOSUUTAM',
    p_GiaTu      => 1000000,
    p_GiaDen     => 50000000
);


-- ===================== PHẦN THÀNH VIÊN 2 =====================
-- Thứ tự chạy: DDL_HeThongDauGia.sql, seed_data.sql, queries.sql.
BEGIN;

-- Các phiên đang mở và sẽ kết thúc trong vòng một giờ.
SELECT p.MaPhien, ts.TenTaiSan, p.GiaHienTai, p.ThoiDiemDong,
       p.ThoiDiemDong - CURRENT_TIMESTAMP AS ThoiGianConLai
FROM PHIENDAUGIA p
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
WHERE p.TrangThaiPhien = 'DANG_DIEN_RA'
  AND p.ThoiDiemMo <= CURRENT_TIMESTAMP
  AND p.ThoiDiemDong > CURRENT_TIMESTAMP
  AND p.ThoiDiemDong <= CURRENT_TIMESTAMP + INTERVAL '1 hour'
ORDER BY p.ThoiDiemDong, p.MaPhien;

-- Người dẫn đầu; phiên chưa có lượt trả vẫn xuất hiện.
SELECT p.MaPhien, ts.TenTaiSan, nd.HoTen AS NguoiDanDau,
       l.SoTien AS GiaDanDau, l.ThoiDiemChapNhan
FROM PHIENDAUGIA p
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = p.MaLuotDanDau AND l.MaPhien = p.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY p.MaPhien;

-- Lịch sử giá và mức tăng so với lượt liền trước của cùng phiên.
SELECT l.MaPhien, l.MaLuotTraGia, nd.HoTen AS NguoiTraGia,
       l.ThoiDiemChapNhan, l.SoTien,
       l.SoTien - LAG(l.SoTien) OVER (
           PARTITION BY l.MaPhien ORDER BY l.ThoiDiemChapNhan, l.MaLuotTraGia
       ) AS MucTang
FROM LUOTTRAGIA l
JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY l.MaPhien, l.ThoiDiemChapNhan, l.MaLuotTraGia;

-- Tổng hợp đăng ký và lượt trả riêng để không đếm trùng khi ghép bảng.
WITH SoDangKy AS (
    SELECT MaPhien, COUNT(*) AS SoNguoiDangKy,
           COUNT(*) FILTER (WHERE TrangThaiDangKy = 'DA_DUYET') AS SoNguoiDaDuyet
    FROM DANGKY
    GROUP BY MaPhien
), SoTraGia AS (
    SELECT MaPhien, COUNT(DISTINCT MaNguoiTraGia) AS SoNguoiDaTraGia,
           COUNT(*) AS SoLuotTraGia
    FROM LUOTTRAGIA
    GROUP BY MaPhien
)
SELECT p.MaPhien,
       COALESCE(d.SoNguoiDangKy, 0) AS SoNguoiDangKy,
       COALESCE(d.SoNguoiDaDuyet, 0) AS SoNguoiDaDuyet,
       COALESCE(l.SoNguoiDaTraGia, 0) AS SoNguoiDaTraGia,
       COALESCE(l.SoLuotTraGia, 0) AS SoLuotTraGia
FROM PHIENDAUGIA p
LEFT JOIN SoDangKy d ON d.MaPhien = p.MaPhien
LEFT JOIN SoTraGia l ON l.MaPhien = p.MaPhien
ORDER BY p.MaPhien;

-- Giá thắng lấy từ lượt thắng. Tỷ lệ tính trên các phiên đã chốt.
SELECT k.MaPhien, k.ThoiDiemChot, nd.HoTen AS NguoiThang, l.SoTien AS GiaThang
FROM KETQUADAUGIA k
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY k.MaPhien;

SELECT COUNT(*) AS SoPhienDaChot, COUNT(MaLuotThang) AS SoPhienThanhCong,
       ROUND(100.0 * COUNT(MaLuotThang) / NULLIF(COUNT(*), 0), 2) AS TyLeThanhCongPhanTram
FROM KETQUADAUGIA;

-- Xếp hạng người trả giá trong từng phiên bằng hàm cửa sổ (mỗi người lấy mức giá cao nhất).
-- Hạng 1 là người dẫn đầu; cùng giá thì lượt được chấp nhận trước đứng trên (quy tắc 4).
-- Cột KhopMaLuotDanDau đối chiếu kết quả tính lại với MaLuotDanDau lưu trong PHIENDAUGIA.
WITH GiaCaoNhatMoiNguoi AS (
    SELECT DISTINCT ON (l.MaPhien, l.MaNguoiTraGia)
           l.MaPhien, l.MaNguoiTraGia, l.MaLuotTraGia, l.SoTien, l.ThoiDiemChapNhan
    FROM LUOTTRAGIA l
    ORDER BY l.MaPhien, l.MaNguoiTraGia, l.SoTien DESC, l.ThoiDiemChapNhan
), XepHang AS (
    SELECT g.*,
           ROW_NUMBER() OVER w AS Hang,
           LEAD(g.SoTien) OVER w AS GiaHangNhi,
           COUNT(*) OVER (PARTITION BY g.MaPhien) AS SoNguoiTraGia
    FROM GiaCaoNhatMoiNguoi g
    WINDOW w AS (PARTITION BY g.MaPhien ORDER BY g.SoTien DESC, g.ThoiDiemChapNhan, g.MaLuotTraGia)
)
SELECT x.MaPhien, ts.TenTaiSan, p.TrangThaiPhien,
       nd.HoTen AS NguoiDanDau, x.SoTien AS GiaDanDau,
       x.GiaHangNhi, x.SoTien - x.GiaHangNhi AS CachBietHangNhi,
       x.SoNguoiTraGia,
       ROUND(100.0 * (x.SoTien - p.GiaKhoiDiem) / p.GiaKhoiDiem, 2) AS PhanTramTangSoVoiKhoiDiem,
       (x.MaLuotTraGia = p.MaLuotDanDau) AS KhopMaLuotDanDau
FROM XepHang x
JOIN PHIENDAUGIA p ON p.MaPhien = x.MaPhien
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
JOIN NGUOIDUNG nd ON nd.MaNguoiDung = x.MaNguoiTraGia
WHERE x.Hang = 1
ORDER BY x.MaPhien;

-- Tỷ lệ phiên thành công theo từng nhánh danh mục gốc.
-- CTE đệ quy gắn mỗi danh mục lá về danh mục gốc; ROLLUP thêm dòng tổng toàn hệ thống.
WITH RECURSIVE GocDanhMuc AS (
    SELECT MaDanhMuc, MaDanhMuc AS MaGoc, TenDanhMuc AS TenGoc
    FROM DANHMUC
    WHERE MaDanhMucCha IS NULL

    UNION

    SELECT con.MaDanhMuc, cha.MaGoc, cha.TenGoc
    FROM DANHMUC con
    JOIN GocDanhMuc cha ON con.MaDanhMucCha = cha.MaDanhMuc
)
SELECT CASE WHEN GROUPING(g.MaGoc) = 1 THEN 'TOÀN HỆ THỐNG' ELSE g.TenGoc END AS NhanhDanhMuc,
       COUNT(*) AS SoPhienDaChot,
       COUNT(k.MaLuotThang) AS SoPhienThanhCong,
       COUNT(*) - COUNT(k.MaLuotThang) AS SoPhienThatBai,
       ROUND(100.0 * COUNT(k.MaLuotThang) / NULLIF(COUNT(*), 0), 2) AS TyLeThanhCongPhanTram,
       COALESCE(SUM(l.SoTien), 0) AS TongGiaTriGiaoDich
FROM KETQUADAUGIA k
JOIN PHIENDAUGIA p ON p.MaPhien = k.MaPhien
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
JOIN GocDanhMuc g ON g.MaDanhMuc = ts.MaDanhMuc
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
GROUP BY ROLLUP ((g.MaGoc, g.TenGoc))
ORDER BY GROUPING(g.MaGoc), g.MaGoc;

-- Bảng xếp hạng người mua trên các phiên đã chốt: số phiên tham gia, số phiên thắng, tổng chi.
WITH ThamGia AS (
    SELECT l.MaNguoiTraGia AS MaNguoiDung, COUNT(DISTINCT l.MaPhien) AS SoPhienThamGia
    FROM LUOTTRAGIA l
    JOIN KETQUADAUGIA k ON k.MaPhien = l.MaPhien
    GROUP BY l.MaNguoiTraGia
), Thang AS (
    SELECT l.MaNguoiTraGia AS MaNguoiDung, COUNT(*) AS SoPhienThang, SUM(l.SoTien) AS TongGiaThang
    FROM KETQUADAUGIA k
    JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
    GROUP BY l.MaNguoiTraGia
)
SELECT DENSE_RANK() OVER (ORDER BY COALESCE(th.TongGiaThang, 0) DESC) AS Hang,
       nd.HoTen,
       tg.SoPhienThamGia,
       COALESCE(th.SoPhienThang, 0) AS SoPhienThang,
       ROUND(100.0 * COALESCE(th.SoPhienThang, 0) / tg.SoPhienThamGia, 2) AS TyLeThangPhanTram,
       COALESCE(th.TongGiaThang, 0) AS TongGiaThang
FROM ThamGia tg
JOIN NGUOIDUNG nd ON nd.MaNguoiDung = tg.MaNguoiDung
LEFT JOIN Thang th ON th.MaNguoiDung = tg.MaNguoiDung
ORDER BY Hang, nd.HoTen;

-- Kiểm tra dữ liệu theo quy tắc nghiệp vụ. Kết quả rỗng nghĩa là không có vi phạm.
WITH LuotCoGiaTruoc AS (
    SELECT l.*,
           LAG(l.SoTien) OVER (PARTITION BY l.MaPhien
                               ORDER BY l.ThoiDiemChapNhan, l.MaLuotTraGia) AS GiaTruoc
    FROM LUOTTRAGIA l
)
SELECT l.MaPhien, l.MaLuotTraGia, v.ViPham
FROM LuotCoGiaTruoc l
JOIN PHIENDAUGIA p ON p.MaPhien = l.MaPhien
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
JOIN DANGKY dk ON dk.MaPhien = l.MaPhien AND dk.MaNguoiDung = l.MaNguoiTraGia
CROSS JOIN LATERAL (VALUES
    (l.SoTien < COALESCE(l.GiaTruoc + p.BuocGia, p.GiaKhoiDiem), 'Giá thấp hơn mức tối thiểu'),
    (MOD(l.SoTien - p.GiaKhoiDiem, p.BuocGia) <> 0,              'Giá lệch lưới bước giá'),
    (l.ThoiDiemChapNhan NOT BETWEEN p.ThoiDiemMo AND p.ThoiDiemDong, 'Trả giá ngoài giờ phiên'),
    (l.MaNguoiTraGia = ts.MaNguoiBan,                              'Người bán tự trả giá'),
    (dk.TrangThaiDangKy <> 'DA_DUYET',                             'Đăng ký chưa được duyệt')
) AS v(CoViPham, ViPham)
WHERE v.CoViPham
UNION ALL
SELECT p.MaPhien, p.MaLuotDanDau, 'GiaHienTai khác giá cao nhất của phiên'
FROM PHIENDAUGIA p
WHERE p.GiaHienTai IS DISTINCT FROM
      (SELECT MAX(l.SoTien) FROM LUOTTRAGIA l WHERE l.MaPhien = p.MaPhien)
ORDER BY 1, 2;

-- Hai hàm cùng khóa dòng phiên. Nếu lỗi, các ghi chép của lời gọi cùng rollback.
CREATE OR REPLACE FUNCTION fn_TraGia(
    p_MaPhien BIGINT, p_MaNguoiDung BIGINT, p_SoTien NUMERIC, p_MaYeuCau UUID
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_phien PHIENDAUGIA%ROWTYPE;
    v_luot LUOTTRAGIA%ROWTYPE;
    v_nguoi_ban BIGINT;
    v_trang_thai_dang_ky VARCHAR(50);
    v_gia_toi_thieu NUMERIC;
    v_thoi_diem TIMESTAMPTZ;
    v_ma_luot BIGINT;
BEGIN
    IF p_MaYeuCau IS NULL OR p_SoTien IS NULL OR p_SoTien <= 0
       OR p_SoTien > 99999999999999.99 OR p_SoTien <> TRUNC(p_SoTien, 2) THEN
        RAISE EXCEPTION 'Mã yêu cầu hoặc số tiền không hợp lệ' USING ERRCODE = '22023';
    END IF;

    -- Hai lần gửi cùng UUID phải kiểm tra tuần tự, kể cả khi gửi vào hai phiên.
    PERFORM pg_advisory_xact_lock(hashtextextended(p_MaYeuCau::TEXT, 19));
    SELECT * INTO v_luot FROM LUOTTRAGIA WHERE MaYeuCau = p_MaYeuCau;
    IF FOUND THEN
        IF v_luot.MaPhien IS DISTINCT FROM p_MaPhien
           OR v_luot.MaNguoiTraGia IS DISTINCT FROM p_MaNguoiDung
           OR v_luot.SoTien IS DISTINCT FROM p_SoTien THEN
            RAISE EXCEPTION 'Mã yêu cầu đã dùng cho lượt trả giá khác';
        END IF;
        RETURN v_luot.MaLuotTraGia;
    END IF;

    SELECT * INTO v_phien FROM PHIENDAUGIA WHERE MaPhien = p_MaPhien FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy phiên đấu giá';
    END IF;
    IF v_phien.TrangThaiPhien <> 'DANG_DIEN_RA' THEN
        RAISE EXCEPTION 'Phiên không nhận trả giá';
    END IF;

    SELECT MaNguoiBan INTO v_nguoi_ban FROM TAISAN
    WHERE MaTaiSan = v_phien.MaTaiSan FOR SHARE;
    IF p_MaNguoiDung = v_nguoi_ban THEN
        RAISE EXCEPTION 'Người bán không được trả giá tài sản của mình';
    END IF;

    SELECT TrangThaiDangKy INTO v_trang_thai_dang_ky FROM DANGKY
    WHERE MaPhien = p_MaPhien AND MaNguoiDung = p_MaNguoiDung FOR SHARE;
    IF v_trang_thai_dang_ky IS DISTINCT FROM 'DA_DUYET' THEN
        RAISE EXCEPTION 'Người trả giá chưa có đăng ký được duyệt cho phiên này';
    END IF;

    v_gia_toi_thieu := COALESCE(v_phien.GiaHienTai + v_phien.BuocGia, v_phien.GiaKhoiDiem);
    IF p_SoTien < v_gia_toi_thieu
       OR MOD(p_SoTien - v_phien.GiaKhoiDiem, v_phien.BuocGia) <> 0 THEN
        RAISE EXCEPTION 'Giá trả phải từ % và đúng lưới bước giá %',
            v_gia_toi_thieu, v_phien.BuocGia;
    END IF;

    -- Đọc đồng hồ sau khi đã chờ các khóa để không dùng giờ bắt đầu transaction.
    v_thoi_diem := clock_timestamp();
    IF v_thoi_diem < v_phien.ThoiDiemMo OR v_thoi_diem >= v_phien.ThoiDiemDong THEN
        RAISE EXCEPTION 'Thời điểm trả giá nằm ngoài giờ nhận lượt';
    END IF;

    INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
    VALUES (p_MaPhien, p_MaNguoiDung, p_SoTien, p_MaYeuCau, v_thoi_diem)
    RETURNING MaLuotTraGia INTO v_ma_luot;

    UPDATE PHIENDAUGIA
    SET GiaHienTai = p_SoTien, MaLuotDanDau = v_ma_luot, PhienBan = PhienBan + 1
    WHERE MaPhien = p_MaPhien;

    INSERT INTO NHATKYTHAYDOI (MaPhien, MaTacNhan, HanhDong, ChiTiet, ThoiDiemGhi)
    VALUES (p_MaPhien, p_MaNguoiDung, 'CHAP_NHAN_TRA_GIA',
            jsonb_build_object('MaLuotTraGia', v_ma_luot, 'SoTien', p_SoTien, 'MaYeuCau', p_MaYeuCau),
            v_thoi_diem);

    RETURN v_ma_luot;
END;
$$;

-- Trả về mã lượt thắng, hoặc NULL nếu phiên kết thúc không có người thắng.
CREATE OR REPLACE FUNCTION fn_DongPhienDauGia(p_MaPhien BIGINT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_phien PHIENDAUGIA%ROWTYPE;
    v_ma_luot_thang BIGINT;
    v_gia_thang NUMERIC(16,2);
    v_thoi_diem TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_phien FROM PHIENDAUGIA WHERE MaPhien = p_MaPhien FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy phiên đấu giá';
    END IF;

    SELECT MaLuotThang INTO v_ma_luot_thang FROM KETQUADAUGIA WHERE MaPhien = p_MaPhien;
    IF FOUND THEN
        RETURN v_ma_luot_thang;
    END IF;

    v_thoi_diem := clock_timestamp();
    IF v_thoi_diem < v_phien.ThoiDiemDong THEN
        RAISE EXCEPTION 'Phiên chưa đến giờ đóng';
    END IF;
    IF v_phien.TrangThaiPhien NOT IN ('DANG_DIEN_RA', 'CHUA_MO') THEN
        RAISE EXCEPTION 'Trạng thái phiên không cho phép chốt kết quả';
    END IF;

    SELECT MaLuotTraGia, SoTien INTO v_ma_luot_thang, v_gia_thang
    FROM LUOTTRAGIA
    WHERE MaPhien = p_MaPhien
    ORDER BY SoTien DESC, MaLuotTraGia
    LIMIT 1;

    INSERT INTO KETQUADAUGIA (MaPhien, MaLuotThang, ThoiDiemChot)
    VALUES (p_MaPhien, v_ma_luot_thang, v_thoi_diem);

    UPDATE PHIENDAUGIA
    SET TrangThaiPhien = CASE WHEN v_ma_luot_thang IS NULL THEN 'THAT_BAI' ELSE 'DA_DONG' END,
        GiaHienTai = v_gia_thang, MaLuotDanDau = v_ma_luot_thang, PhienBan = PhienBan + 1
    WHERE MaPhien = p_MaPhien;

    INSERT INTO NHATKYTHAYDOI (MaPhien, HanhDong, ChiTiet, ThoiDiemGhi)
    VALUES (p_MaPhien, 'DONG_PHIEN',
            jsonb_build_object('MaLuotThang', v_ma_luot_thang, 'GiaThang', v_gia_thang),
            v_thoi_diem);

    RETURN v_ma_luot_thang;
END;
$$;

COMMIT;


-- TESTER --
-- Ví dụ trả giá cho phiên 1 ngay sau khi nạp dữ liệu mẫu:
SELECT fn_TraGia(1, 8, 5750000, '19000000-0000-4000-8000-000000000101');
SELECT fn_DongPhienDauGia(2);


SELECT *
FROM PHIENDAUGIA
WHERE TrangThaiPhien LIKE 'DANG_DIEN_RA';
SELECT *
FROM NHATKYTHAYDOI;

--RESET TRUY VẤN Các phiên đang mở và sẽ kết thúc trong vòng một giờ.
UPDATE PHIENDAUGIA 
SET ThoiDiemDong = CURRENT_TIMESTAMP + INTERVAL '30 minutes' 
WHERE MaPhien = 1;


-- =====================================================================
-- BƯỚC 5 (TIẾP THEO): PHƯƠNG ÁN 2 - GIAO DỊCH VỚI MỨC CÔ LẬP SERIALIZABLE CÓ RETRY
-- =====================================================================
-- So sánh với Phương án 1:
--   + Phương án 1 (fn_TraGia): Dùng Khóa bi quan (Pessimistic Locking) bằng
--     SELECT ... FOR UPDATE. Khóa dòng ngay từ đầu, các giao dịch khác phải
--     chờ (blocking) cho đến khi giao dịch trước commit/rollback.
--   + Phương án 2 (fn_TraGia_Serializable): Dùng Kiểm soát tương tranh lạc quan
--     (Optimistic Concurrency Control - SSI) ở mức SERIALIZABLE. Không khóa dòng
--     khi đọc dữ liệu. Nếu phát hiện xung đột dữ liệu tuần tự hóa (mã lỗi 40001),
--     hệ thống tự động kích hoạt cơ chế Retry Loop với độ trễ ngẫu nhiên (Backoff).
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_TraGia_Serializable(
    p_MaPhien BIGINT,
    p_MaNguoiDung BIGINT,
    p_SoTien NUMERIC,
    p_MaYeuCau UUID,
    p_MaxRetries INT DEFAULT 5
) RETURNS TABLE (
    MaLuotTraGia BIGINT,
    SoLanThuLai INT,
    TrangThai VARCHAR(50),
    ThongBao TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_phien PHIENDAUGIA%ROWTYPE;
    v_luot LUOTTRAGIA%ROWTYPE;
    v_nguoi_ban BIGINT;
    v_trang_thai_dang_ky VARCHAR(50);
    v_gia_toi_thieu NUMERIC;
    v_thoi_diem TIMESTAMPTZ;
    v_ma_luot BIGINT;
    v_attempt INT := 0;
    v_delay NUMERIC;
BEGIN
    -- 1. Kiểm tra tính hợp lệ cơ bản của dữ liệu đầu vào
    IF p_MaYeuCau IS NULL OR p_SoTien IS NULL OR p_SoTien <= 0
       OR p_SoTien > 99999999999999.99 OR p_SoTien <> TRUNC(p_SoTien, 2) THEN
        RAISE EXCEPTION 'Mã yêu cầu hoặc số tiền không hợp lệ' USING ERRCODE = '22023';
    END IF;

    -- 2. Vòng lặp thử lại (Retry Loop) xử lý xung đột SERIALIZABLE (Mã 40001)
    LOOP
        v_attempt := v_attempt + 1;
        BEGIN
            -- Kiểm tra Idempotency: mã yêu cầu đã được xử lý thành công trước đó chưa
            SELECT * INTO v_luot FROM LUOTTRAGIA WHERE MaYeuCau = p_MaYeuCau;
            IF FOUND THEN
                IF v_luot.MaPhien IS DISTINCT FROM p_MaPhien
                   OR v_luot.MaNguoiTraGia IS DISTINCT FROM p_MaNguoiDung
                   OR v_luot.SoTien IS DISTINCT FROM p_SoTien THEN
                    RAISE EXCEPTION 'Mã yêu cầu đã dùng cho lượt trả giá khác';
                END IF;
                RETURN QUERY SELECT v_luot.MaLuotTraGia, v_attempt - 1, 'DA_TON_TAI'::VARCHAR(50), 'Mã yêu cầu trùng lặp hợp lệ (Idempotent)'::TEXT;
                RETURN;
            END IF;

            -- ĐỌC DỮ LIỆU LẠC QUAN: KHÔNG DÙNG "FOR UPDATE"
            SELECT * INTO v_phien FROM PHIENDAUGIA WHERE MaPhien = p_MaPhien;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Không tìm thấy phiên đấu giá';
            END IF;
            IF v_phien.TrangThaiPhien <> 'DANG_DIEN_RA' THEN
                RAISE EXCEPTION 'Phiên không nhận trả giá (Trạng thái: %)', v_phien.TrangThaiPhien;
            END IF;

            -- Kiểm tra người bán không được tự trả giá tài sản của mình
            SELECT MaNguoiBan INTO v_nguoi_ban FROM TAISAN WHERE MaTaiSan = v_phien.MaTaiSan;
            IF p_MaNguoiDung = v_nguoi_ban THEN
                RAISE EXCEPTION 'Người bán không được trả giá tài sản của mình';
            END IF;

            -- Kiểm tra người trả giá đã được duyệt đăng ký chưa
            SELECT TrangThaiDangKy INTO v_trang_thai_dang_ky FROM DANGKY
            WHERE MaPhien = p_MaPhien AND MaNguoiDung = p_MaNguoiDung;
            IF v_trang_thai_dang_ky IS DISTINCT FROM 'DA_DUYET' THEN
                RAISE EXCEPTION 'Người trả giá chưa có đăng ký được duyệt cho phiên này';
            END IF;

            -- Kiểm tra mức giá tối thiểu và lưới bước giá
            v_gia_toi_thieu := COALESCE(v_phien.GiaHienTai + v_phien.BuocGia, v_phien.GiaKhoiDiem);
            IF p_SoTien < v_gia_toi_thieu
               OR MOD(p_SoTien - v_phien.GiaKhoiDiem, v_phien.BuocGia) <> 0 THEN
                RAISE EXCEPTION 'Giá trả phải từ % và đúng lưới bước giá %', v_gia_toi_thieu, v_phien.BuocGia;
            END IF;

            -- Kiểm tra thời điểm trả giá có nằm trong khung giờ của phiên không
            v_thoi_diem := clock_timestamp();
            IF v_thoi_diem < v_phien.ThoiDiemMo OR v_thoi_diem >= v_phien.ThoiDiemDong THEN
                RAISE EXCEPTION 'Thời điểm trả giá nằm ngoài giờ nhận lượt';
            END IF;

            -- Ghi nhận lượt trả giá mới
            INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
            VALUES (p_MaPhien, p_MaNguoiDung, p_SoTien, p_MaYeuCau, v_thoi_diem)
            RETURNING MaLuotTraGia INTO v_ma_luot;

            -- Cập nhật trạng thái phiên (Tăng PhienBan để kiểm soát lạc quan)
            UPDATE PHIENDAUGIA
            SET GiaHienTai = p_SoTien, 
                MaLuotDanDau = v_ma_luot, 
                PhienBan = PhienBan + 1
            WHERE MaPhien = p_MaPhien;

            -- Ghi nhật ký hệ thống
            INSERT INTO NHATKYTHAYDOI (MaPhien, MaTacNhan, HanhDong, ChiTiet, ThoiDiemGhi)
            VALUES (p_MaPhien, p_MaNguoiDung, 'CHAP_NHAN_TRA_GIA',
                    jsonb_build_object('MaLuotTraGia', v_ma_luot, 'SoTien', p_SoTien, 'MaYeuCau', p_MaYeuCau, 'ThuLai', v_attempt - 1),
                    v_thoi_diem);

            -- Trả về kết quả thành công
            RETURN QUERY SELECT v_ma_luot, v_attempt - 1, 'THANH_CONG'::VARCHAR(50), 'Chấp nhận trả giá thành công'::TEXT;
            RETURN;

        EXCEPTION
            -- Bắt lỗi xung đột tuần tự hóa (40001) hoặc Deadlock (40P01)
            WHEN serialization_failure OR deadlock_detected THEN
                IF v_attempt >= p_MaxRetries THEN
                    RETURN QUERY SELECT NULL::BIGINT, v_attempt, 'THAT_BAI'::VARCHAR(50), 'Vượt quá số lần thử lại tối đa do xung đột tuần tự hóa'::TEXT;
                    RETURN;
                END IF;
                -- Random Backoff: Trì hoãn ngẫu nhiên 10ms - 50ms để giảm tỷ lệ va chạm ở lần thử kế tiếp
                v_delay := (10 + (random() * 40)) / 1000.0;
                PERFORM pg_sleep(v_delay);
        END;
    END LOOP;
END;
$$;


-- Hàm đóng phiên phối hợp đồng thời theo mức SERIALIZABLE có Retry
CREATE OR REPLACE FUNCTION fn_DongPhienDauGia_Serializable(
    p_MaPhien BIGINT,
    p_MaxRetries INT DEFAULT 5
) RETURNS TABLE (
    MaLuotThang BIGINT,
    SoLanThuLai INT,
    TrangThai VARCHAR(50),
    ThongBao TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_phien PHIENDAUGIA%ROWTYPE;
    v_ma_luot_thang BIGINT;
    v_gia_thang NUMERIC(16,2);
    v_thoi_diem TIMESTAMPTZ;
    v_attempt INT := 0;
    v_delay NUMERIC;
BEGIN
    LOOP
        v_attempt := v_attempt + 1;
        BEGIN
            -- Kiểm tra xem phiên đã chốt kết quả trước đó chưa
            SELECT MaLuotThang INTO v_ma_luot_thang FROM KETQUADAUGIA WHERE MaPhien = p_MaPhien;
            IF FOUND THEN
                RETURN QUERY SELECT v_ma_luot_thang, v_attempt - 1, 'DA_DONG'::VARCHAR(50), 'Phiên đã được chốt kết quả trước đó'::TEXT;
                RETURN;
            END IF;

            -- Đọc thông tin phiên không dùng FOR UPDATE
            SELECT * INTO v_phien FROM PHIENDAUGIA WHERE MaPhien = p_MaPhien;
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Không tìm thấy phiên đấu giá';
            END IF;

            v_thoi_diem := clock_timestamp();
            IF v_thoi_diem < v_phien.ThoiDiemDong THEN
                RAISE EXCEPTION 'Phiên chưa đến giờ đóng (Hiện tại: %, Giờ đóng: %)', v_thoi_diem, v_phien.ThoiDiemDong;
            END IF;
            IF v_phien.TrangThaiPhien NOT IN ('DANG_DIEN_RA', 'CHUA_MO') THEN
                RAISE EXCEPTION 'Trạng thái phiên không cho phép chốt kết quả';
            END IF;

            -- Tìm lượt trả giá cao nhất để trao giải thắng
            SELECT MaLuotTraGia, SoTien INTO v_ma_luot_thang, v_gia_thang
            FROM LUOTTRAGIA
            WHERE MaPhien = p_MaPhien
            ORDER BY SoTien DESC, MaLuotTraGia ASC
            LIMIT 1;

            -- Ghi nhận kết quả
            INSERT INTO KETQUADAUGIA (MaPhien, MaLuotThang, ThoiDiemChot)
            VALUES (p_MaPhien, v_ma_luot_thang, v_thoi_diem);

            -- Cập nhật trạng thái phiên
            UPDATE PHIENDAUGIA
            SET TrangThaiPhien = CASE WHEN v_ma_luot_thang IS NULL THEN 'THAT_BAI' ELSE 'DA_DONG' END,
                GiaHienTai = v_gia_thang, 
                MaLuotDanDau = v_ma_luot_thang, 
                PhienBan = PhienBan + 1
            WHERE MaPhien = p_MaPhien;

            -- Ghi nhật ký đóng phiên
            INSERT INTO NHATKYTHAYDOI (MaPhien, HanhDong, ChiTiet, ThoiDiemGhi)
            VALUES (p_MaPhien, 'DONG_PHIEN',
                    jsonb_build_object('MaLuotThang', v_ma_luot_thang, 'GiaThang', v_gia_thang, 'ThuLai', v_attempt - 1),
                    v_thoi_diem);

            RETURN QUERY SELECT v_ma_luot_thang, v_attempt - 1, 'THANH_CONG'::VARCHAR(50), 
                                CASE WHEN v_ma_luot_thang IS NULL THEN 'Phiên kết thúc thất bại (không có lượt trả giá)' 
                                     ELSE 'Chốt người thắng cuộc thành công' END::TEXT;
            RETURN;

        EXCEPTION
            WHEN serialization_failure OR deadlock_detected THEN
                IF v_attempt >= p_MaxRetries THEN
                    RETURN QUERY SELECT NULL::BIGINT, v_attempt, 'THAT_BAI'::VARCHAR(50), 'Đóng phiên thất bại do xung đột tuần tự hóa kéo dài'::TEXT;
                    RETURN;
                END IF;
                v_delay := (10 + (random() * 40)) / 1000.0;
                PERFORM pg_sleep(v_delay);
        END;
    END LOOP;
END;
$$;


-- =====================================================================
-- BƯỚC 7: CÁC KỊCH BẢN KIỂM THỬ TÍNH ĐÚNG ĐẮN VÀ TOÀN VẸN (DO THÀNH VIÊN 1 PHỤ TRÁCH)
-- =====================================================================

-- KỊCH BẢN 2 (Minh chứng 3): Kiểm tra tính Idempotency - Gửi lại cùng UUID không tạo lượt trùng
-- Lần 1: Gửi yêu cầu trả giá mới
SELECT * FROM fn_TraGia_Serializable(1, 7, 6000000, 'a0000000-0000-4000-8000-000000000001'::UUID);

-- Lần 2: Giả lập mạng bị lag, Client gửi lại đúng UUID trên với cùng số tiền
-- KẾT QUẢ MONG ĐỢI: Trả về trạng thái 'DA_TON_TAI', cùng mã lượt cũ, KHÔNG tạo bản ghi mới trong LUOTTRAGIA.
SELECT * FROM fn_TraGia_Serializable(1, 7, 6000000, 'a0000000-0000-4000-8000-000000000001'::UUID);


-- KỊCH BẢN 4 (Minh chứng 4): Kiểm tra tính Nguyên tử (Atomicity) - Lỗi giữa chừng tự động ROLLBACK
-- Thử nghiệm trả giá với số tiền vi phạm bước giá (không chia hết cho bước giá)
-- KẾT QUẢ MONG ĐỢI: Giao dịch ném lỗi và tự động Rollback hoàn toàn, không tạo bản ghi rác trong LUOTTRAGIA,
-- không làm thay đổi GiaHienTai hay PhienBan của PHIENDAUGIA.
DO $$
BEGIN
    PERFORM fn_TraGia_Serializable(1, 7, 6123456, 'b0000000-0000-4000-8000-000000000002'::UUID);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Đã bắt ngoại lệ vi phạm bước giá thành công. Dữ liệu được bảo toàn nguyên vẹn: %', SQLERRM;
END $$;

