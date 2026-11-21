-- 1. HÀM BÁO CÁO CÓ BỘ LỌC ĐỘNG (fn_BaoCaoPhienDauGiaDong)
-- Lọc danh sách phiên đấu giá theo nhánh danh mục, trạng thái ('DANG_DIEN_RA', 'DA_DONG'...), loại tài sản, khoảng giá và từ khóa
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


-- 2. HÀM TRẢ GIÁ - PHƯƠNG ÁN 1: KHÓA BI QUAN (Pessimistic Locking)
-- Sử dụng: SELECT ... FOR UPDATE trên dòng phiên đấu giá
-- Kiểm tra điều kiện hợp lệ, ghi nhận lịch sử và cập nhật giá hiện tại nguyên tử
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


-- 3. HÀM ĐÓNG PHIÊN ĐẤU GIÁ (fn_DongPhienDauGia)
-- Sử dụng: SELECT ... FOR UPDATE để khóa phiên
-- Chốt kết quả vào KETQUADAUGIA, cập nhật trạng thái DA_DONG hoặc THAT_BAI
-- Trả về mã lượt thắng (MaLuotThang), hoặc NULL nếu không có người trả giá
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


-- 4. HÀM TRẢ GIÁ - PHƯƠNG ÁN 2: MỨC CÔ LẬP SERIALIZABLE CÓ THỬ LẠI
-- Sử dụng: BEGIN ISOLATION LEVEL SERIALIZABLE; SELECT fn_TraGia_Serializable(...); COMMIT;
-- Không khóa dòng, PostgreSQL tự phát hiện xung đột và báo lỗi 40001.
-- Gặp lỗi 40001 thì ROLLBACK rồi chạy lại cả giao dịch với cùng MaYeuCau
-- (không thử lại bên trong hàm vì snapshot của giao dịch SERIALIZABLE không đổi).
CREATE OR REPLACE FUNCTION fn_TraGia_Serializable(
    p_MaPhien BIGINT,
    p_MaNguoiDung BIGINT,
    p_SoTien NUMERIC,
    p_MaYeuCau UUID
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
    -- Bắt buộc gọi trong giao dịch SERIALIZABLE
    IF current_setting('transaction_isolation') <> 'serializable' THEN
        RAISE EXCEPTION 'Phương án 2 phải chạy trong giao dịch SERIALIZABLE'
            USING ERRCODE = '25001',
                  HINT = 'BEGIN ISOLATION LEVEL SERIALIZABLE; SELECT fn_TraGia_Serializable(...); COMMIT;';
    END IF;

    IF p_MaYeuCau IS NULL OR p_SoTien IS NULL OR p_SoTien <= 0
       OR p_SoTien > 99999999999999.99 OR p_SoTien <> TRUNC(p_SoTien, 2) THEN
        RAISE EXCEPTION 'Mã yêu cầu hoặc số tiền không hợp lệ' USING ERRCODE = '22023';
    END IF;

    -- 1. Chống gửi lặp: cùng MaYeuCau đã được chấp nhận thì trả lại lượt cũ
    SELECT * INTO v_luot FROM LUOTTRAGIA WHERE MaYeuCau = p_MaYeuCau;
    IF FOUND THEN
        IF v_luot.MaPhien IS DISTINCT FROM p_MaPhien
           OR v_luot.MaNguoiTraGia IS DISTINCT FROM p_MaNguoiDung
           OR v_luot.SoTien IS DISTINCT FROM p_SoTien THEN
            RAISE EXCEPTION 'Mã yêu cầu đã dùng cho lượt trả giá khác';
        END IF;
        RETURN v_luot.MaLuotTraGia;
    END IF;

    -- 2. Đọc phiên (không FOR UPDATE)
    SELECT * INTO v_phien FROM PHIENDAUGIA WHERE MaPhien = p_MaPhien;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy phiên đấu giá';
    END IF;
    IF v_phien.TrangThaiPhien <> 'DANG_DIEN_RA' THEN
        RAISE EXCEPTION 'Phiên không nhận trả giá';
    END IF;

    -- 3. Kiểm tra người tham gia và mức giá giống Phương án 1
    SELECT MaNguoiBan INTO v_nguoi_ban FROM TAISAN WHERE MaTaiSan = v_phien.MaTaiSan;
    IF p_MaNguoiDung = v_nguoi_ban THEN
        RAISE EXCEPTION 'Người bán không được trả giá tài sản của mình';
    END IF;

    SELECT TrangThaiDangKy INTO v_trang_thai_dang_ky FROM DANGKY
    WHERE MaPhien = p_MaPhien AND MaNguoiDung = p_MaNguoiDung;
    IF v_trang_thai_dang_ky IS DISTINCT FROM 'DA_DUYET' THEN
        RAISE EXCEPTION 'Người trả giá chưa có đăng ký được duyệt cho phiên này';
    END IF;

    v_gia_toi_thieu := COALESCE(v_phien.GiaHienTai + v_phien.BuocGia, v_phien.GiaKhoiDiem);
    IF p_SoTien < v_gia_toi_thieu
       OR MOD(p_SoTien - v_phien.GiaKhoiDiem, v_phien.BuocGia) <> 0 THEN
        RAISE EXCEPTION 'Giá trả phải từ % và đúng lưới bước giá %',
            v_gia_toi_thieu, v_phien.BuocGia;
    END IF;

    v_thoi_diem := clock_timestamp();
    IF v_thoi_diem < v_phien.ThoiDiemMo OR v_thoi_diem >= v_phien.ThoiDiemDong THEN
        RAISE EXCEPTION 'Thời điểm trả giá nằm ngoài giờ nhận lượt';
    END IF;

    -- 4. Ghi lượt trả và cập nhật giá hiện tại
    -- Trùng MaYeuCau hoặc trùng mức giá với giao dịch khác vừa commit thì báo 40001 để thử lại
    BEGIN
        INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
        VALUES (p_MaPhien, p_MaNguoiDung, p_SoTien, p_MaYeuCau, v_thoi_diem)
        RETURNING MaLuotTraGia INTO v_ma_luot;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Xung đột với giao dịch đồng thời, cần thử lại giao dịch'
            USING ERRCODE = 'serialization_failure';
    END;

    -- Nếu giao dịch khác đã sửa dòng phiên thì lệnh UPDATE này báo 40001
    UPDATE PHIENDAUGIA
    SET GiaHienTai = p_SoTien, MaLuotDanDau = v_ma_luot, PhienBan = PhienBan + 1
    WHERE MaPhien = p_MaPhien;

    -- Kiểm tra lại giờ đóng vì có thể đã phải chờ giao dịch khác
    IF clock_timestamp() >= v_phien.ThoiDiemDong THEN
        RAISE EXCEPTION 'Thời điểm trả giá nằm ngoài giờ nhận lượt';
    END IF;

    INSERT INTO NHATKYTHAYDOI (MaPhien, MaTacNhan, HanhDong, ChiTiet, ThoiDiemGhi)
    VALUES (p_MaPhien, p_MaNguoiDung, 'CHAP_NHAN_TRA_GIA',
            jsonb_build_object('MaLuotTraGia', v_ma_luot, 'SoTien', p_SoTien, 'MaYeuCau', p_MaYeuCau),
            v_thoi_diem);

    RETURN v_ma_luot;
END;
$$;



-- Truy vấn 1: Xây dựng cây phân cấp danh mục và thống kê cộng dồn (Roll-up) tài sản & phiên đấu giá
WITH RECURSIVE CayDanhMuc AS (
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


-- Truy vấn 2: Tìm toàn bộ tài sản và phiên đấu giá thuộc một nhánh danh mục (Ví dụ: Nhánh 1 - 'Thiết bị công nghệ & Điện tử')
WITH RECURSIVE NhanhDanhMucCon AS (
    SELECT MaDanhMuc, TenDanhMuc, MaDanhMucCha, 1 AS CapDo
    FROM DANHMUC
    WHERE MaDanhMuc = 1 

    UNION ALL

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


-- Truy vấn 3: Tìm các phiên đấu giá đang diễn ra và sẽ kết thúc trong vòng 1 giờ
SELECT p.MaPhien, ts.TenTaiSan, p.GiaHienTai, p.ThoiDiemDong,
       p.ThoiDiemDong - CURRENT_TIMESTAMP AS ThoiGianConLai
FROM PHIENDAUGIA p
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
WHERE p.TrangThaiPhien = 'DANG_DIEN_RA'
  AND p.ThoiDiemMo <= CURRENT_TIMESTAMP
  AND p.ThoiDiemDong > CURRENT_TIMESTAMP
  AND p.ThoiDiemDong <= CURRENT_TIMESTAMP + INTERVAL '1 hour'
ORDER BY p.ThoiDiemDong, p.MaPhien;


-- Truy vấn 4: Xác định người đang dẫn đầu của các phiên đấu giá (bao gồm cả phiên chưa có lượt trả giá)
SELECT p.MaPhien, ts.TenTaiSan, nd.HoTen AS NguoiDanDau,
       l.SoTien AS GiaDanDau, l.ThoiDiemChapNhan
FROM PHIENDAUGIA p
JOIN TAISAN ts ON ts.MaTaiSan = p.MaTaiSan
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = p.MaLuotDanDau AND l.MaPhien = p.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY p.MaPhien;


-- Truy vấn 5: Lịch sử thay đổi giá và mức tăng so với lượt liền trước của cùng phiên
SELECT l.MaPhien, l.MaLuotTraGia, nd.HoTen AS NguoiTraGia,
       l.ThoiDiemChapNhan, l.SoTien,
       l.SoTien - LAG(l.SoTien) OVER (
           PARTITION BY l.MaPhien ORDER BY l.ThoiDiemChapNhan, l.MaLuotTraGia
       ) AS MucTang
FROM LUOTTRAGIA l
JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY l.MaPhien, l.ThoiDiemChapNhan, l.MaLuotTraGia;


-- Truy vấn 6: Thống kê số lượng người đăng ký và lượt trả giá theo từng phiên (tách CTE để chống đếm trùng)
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


-- Truy vấn 7: Truy xuất giá thắng cuộc và thống kê tỷ lệ phiên thành công trên các phiên đã chốt
SELECT k.MaPhien, k.ThoiDiemChot, nd.HoTen AS NguoiThang, l.SoTien AS GiaThang
FROM KETQUADAUGIA k
LEFT JOIN LUOTTRAGIA l ON l.MaLuotTraGia = k.MaLuotThang AND l.MaPhien = k.MaPhien
LEFT JOIN NGUOIDUNG nd ON nd.MaNguoiDung = l.MaNguoiTraGia
ORDER BY k.MaPhien;

SELECT COUNT(*) AS SoPhienDaChot, COUNT(MaLuotThang) AS SoPhienThanhCong,
       ROUND(100.0 * COUNT(MaLuotThang) / NULLIF(COUNT(*), 0), 2) AS TyLeThanhCongPhanTram
FROM KETQUADAUGIA;


-- Truy vấn 8: Xếp hạng người trả giá trong từng phiên bằng Window Functions và đối soát MaLuotDanDau
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


-- Truy vấn 9: Thống kê tỷ lệ phiên thành công và tổng giá trị giao dịch theo từng nhánh danh mục gốc (WITH RECURSIVE & ROLLUP)
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


-- Truy vấn 10: Bảng xếp hạng người mua trên các phiên đã chốt (số phiên tham gia, số phiên thắng, tổng giá thắng)
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


-- Truy vấn 11: Kiểm toán toàn vẹn dữ liệu theo quy tắc nghiệp vụ (Kết quả rỗng = 0 vi phạm)
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

