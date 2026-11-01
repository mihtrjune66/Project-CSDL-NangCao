-- 1. BẢNG NGƯỜI DÙNG
CREATE TABLE NGUOIDUNG (
	MaNguoiDung BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, 
	HoTen VARCHAR(255) NOT NULL,
	ThuDienTu VARCHAR(255) NOT NULL,
	ThoiDiemTao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL, 
	CONSTRAINT uk_nguoidung_email UNIQUE (ThuDienTu)
);

-- 2. BẢNG DANH MỤC
CREATE TABLE DANHMUC (
	MaDanhMuc BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	TenDanhMuc VARCHAR(255) NOT NULL,
    MaDanhMucCha BIGINT,
	CONSTRAINT uk_danhmuc_ten UNIQUE (TenDanhMuc),
	CONSTRAINT fk_danhmuc_cha FOREIGN KEY (MaDanhMucCha) REFERENCES DANHMUC(MaDanhMuc) ON DELETE SET NULL
);

-- 3. BẢNG TÀI SẢN
CREATE TABLE TAISAN (
    MaTaiSan BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    MaNguoiBan BIGINT NOT NULL,
    MaDanhMuc BIGINT NOT NULL,
    LoaiTaiSan VARCHAR(50) NOT NULL,
    TenTaiSan VARCHAR(255) NOT NULL,
    MoTa TEXT,
    ThoiDiemTao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
	CONSTRAINT fk_taisan_nguoiban FOREIGN KEY (MaNguoiBan) REFERENCES NGUOIDUNG(MaNguoiDung),
	CONSTRAINT fk_taisan_danhmuc FOREIGN KEY (MaDanhMuc) REFERENCES DANHMUC(MaDanhMuc)
);

-- 4. BẢNG TÁC PHẨM NGHỆ THUẬT 
CREATE TABLE TACPHAMNGHETHUAT (
    MaTaiSan BIGINT PRIMARY KEY,
    TacGia VARCHAR(255),
    ChatLieu VARCHAR(100),
    NamSangTac INTEGER,
    CONSTRAINT fk_tpnt_taisan FOREIGN KEY (MaTaiSan) REFERENCES TAISAN(MaTaiSan) ON DELETE CASCADE
);

-- 5. BẢNG ĐỒ SƯU TẦM
CREATE TABLE DOSUUTAM (
    MaTaiSan BIGINT PRIMARY KEY,
    NguonGoc VARCHAR(255),
    DoHiem VARCHAR(100),
    NamSanXuat INTEGER,
    CONSTRAINT fk_dst_taisan FOREIGN KEY (MaTaiSan) REFERENCES TAISAN(MaTaiSan) ON DELETE CASCADE
);

-- 6. BẢNG THIẾT BỊ ĐIỆN TỬ 
CREATE TABLE THIETBIDIENTU (
    MaTaiSan BIGINT PRIMARY KEY,
    ThuongHieu VARCHAR(100) NOT NULL,
    MauThietBi VARCHAR(50),
    SoSeRi VARCHAR(100),
    TinhTrang VARCHAR(100) NOT NULL,
    CONSTRAINT uk_thietbidientu_soseri UNIQUE (SoSeRi),
    CONSTRAINT fk_tbdt_taisan FOREIGN KEY (MaTaiSan) REFERENCES TAISAN(MaTaiSan) ON DELETE CASCADE
);

-- 7. BẢNG PHIÊN ĐẤU GIÁ
CREATE TABLE PHIENDAUGIA (
    MaPhien BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    MaTaiSan BIGINT NOT NULL,
    GiaKhoiDiem NUMERIC(16,2) NOT NULL,
    BuocGia NUMERIC(16,2) NOT NULL,
    ThoiDiemMo TIMESTAMPTZ NOT NULL,
    ThoiDiemDong TIMESTAMPTZ NOT NULL,
    TrangThaiPhien VARCHAR(50) NOT NULL,
    GiaHienTai NUMERIC(16,2),
    MaLuotDanDau BIGINT,
    PhienBan INTEGER DEFAULT 0 NOT NULL,
    CONSTRAINT fk_phiendaugia_taisan FOREIGN KEY (MaTaiSan) REFERENCES TAISAN(MaTaiSan),
    CONSTRAINT ck_phiendaugia_trangthai CHECK (TrangThaiPhien ~ '[^[:space:]]'),
    CONSTRAINT ck_phiendaugia_giakhoidiem CHECK (GiaKhoiDiem > 0 AND GiaKhoiDiem <> 'NaN'::NUMERIC),
    CONSTRAINT ck_phiendaugia_buocgia CHECK (BuocGia > 0 AND BuocGia <> 'NaN'::NUMERIC),
    CONSTRAINT ck_phiendaugia_thoigian CHECK (ThoiDiemDong > ThoiDiemMo),
    CONSTRAINT ck_phiendaugia_phienban CHECK (PhienBan >= 0),
    CONSTRAINT ck_phiendaugia_giahientai CHECK (GiaHienTai >= GiaKhoiDiem AND GiaHienTai <> 'NaN'::NUMERIC),
    CONSTRAINT ck_phiendaugia_dandau CHECK ((GiaHienTai IS NULL) = (MaLuotDanDau IS NULL))
);

-- 8. BẢNG ĐĂNG KÝ
CREATE TABLE DANGKY (
    MaPhien BIGINT NOT NULL,
    MaNguoiDung BIGINT NOT NULL,
    TrangThaiDangKy VARCHAR(50) NOT NULL,
    ThoiDiemDangKy TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_dangky PRIMARY KEY (MaPhien, MaNguoiDung),
    CONSTRAINT fk_dangky_phien FOREIGN KEY (MaPhien) REFERENCES PHIENDAUGIA(MaPhien),
    CONSTRAINT fk_dangky_nguoidung FOREIGN KEY (MaNguoiDung) REFERENCES NGUOIDUNG(MaNguoiDung),
    CONSTRAINT ck_dangky_trangthai CHECK (TrangThaiDangKy ~ '[^[:space:]]')
);

-- 9. BẢNG LƯỢT TRẢ GIÁ
CREATE TABLE LUOTTRAGIA (
    MaLuotTraGia BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    MaPhien BIGINT NOT NULL,
    MaNguoiTraGia BIGINT NOT NULL,
    SoTien NUMERIC(16,2) NOT NULL,
    MaYeuCau UUID NOT NULL,
    ThoiDiemChapNhan TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uk_luottragia_mayeucau UNIQUE (MaYeuCau),
    CONSTRAINT uk_luottragia_phien_sotien UNIQUE (MaPhien, SoTien),
    CONSTRAINT uk_luottragia_luot_phien UNIQUE (MaLuotTraGia, MaPhien),
    CONSTRAINT fk_luottragia_dangky FOREIGN KEY (MaPhien, MaNguoiTraGia) REFERENCES DANGKY(MaPhien, MaNguoiDung),
    CONSTRAINT ck_luottragia_sotien CHECK (SoTien > 0 AND SoTien <> 'NaN'::NUMERIC)
);

-- 10. BẢNG KẾT QUẢ ĐẤU GIÁ
CREATE TABLE KETQUADAUGIA (
    MaPhien BIGINT PRIMARY KEY,
    MaLuotThang BIGINT,
    ThoiDiemChot TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ketquadaugia_phien FOREIGN KEY (MaPhien) REFERENCES PHIENDAUGIA(MaPhien),
    CONSTRAINT fk_ketquadaugia_luotthang FOREIGN KEY (MaLuotThang, MaPhien) REFERENCES LUOTTRAGIA(MaLuotTraGia, MaPhien)
);

-- 11. BẢNG NHẬT KÝ THAY ĐỔI
CREATE TABLE NHATKYTHAYDOI (
    MaNhatKy BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    MaPhien BIGINT NOT NULL,
    MaTacNhan BIGINT,
    HanhDong VARCHAR(50) NOT NULL,
    ChiTiet JSONB NOT NULL,
    ThoiDiemGhi TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    MaGiaoDich BIGINT DEFAULT txid_current() NOT NULL,
    CONSTRAINT fk_nhatkythaydoi_phien FOREIGN KEY (MaPhien) REFERENCES PHIENDAUGIA(MaPhien),
    CONSTRAINT fk_nhatkythaydoi_tacnhan FOREIGN KEY (MaTacNhan) REFERENCES NGUOIDUNG(MaNguoiDung),
    CONSTRAINT ck_nhatkythaydoi_hanhdong CHECK (HanhDong ~ '[^[:space:]]')
);

-- Thêm khóa ngoại dẫn đầu sau khi đã tạo bảng LUOTTRAGIA để tránh vòng phụ thuộc khi tạo bảng.
ALTER TABLE PHIENDAUGIA
    ADD CONSTRAINT fk_phiendaugia_luotdandau
    FOREIGN KEY (MaLuotDanDau, MaPhien) REFERENCES LUOTTRAGIA(MaLuotTraGia, MaPhien)
    DEFERRABLE INITIALLY DEFERRED;



