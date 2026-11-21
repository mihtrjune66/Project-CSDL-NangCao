-- DỮ LIỆU MẪU HỆ THỐNG ĐẤU GIÁ TRỰC TUYẾN (Chạy sau DDL_HeThongDauGia.sql)
-- Quy mô: 15 Người dùng | 21 Danh mục (3 cấp) | 18 Tài sản | 20 Phiên đấu giá | 50 Đăng ký | 45 Lượt trả giá
-- Trạng thái 20 phiên: 6 DANG_DIEN_RA, 3 CHUA_MO, 7 DA_DONG (có người thắng), 4 THAT_BAI (không ai trả giá)

BEGIN;

-- 1. BẢNG NGƯỜI DÙNG (15 người dùng)
INSERT INTO NGUOIDUNG (MaNguoiDung, HoTen, ThuDienTu, ThoiDiemTao)
OVERRIDING SYSTEM VALUE VALUES
(1,  'Nguyễn Văn An',       'an.nguyen@gmail.com',      CURRENT_TIMESTAMP - INTERVAL '60 days'),
(2,  'Trần Thị Bích',       'bich.tran@gmail.com',      CURRENT_TIMESTAMP - INTERVAL '55 days'),
(3,  'Lê Hoàng Cường',      'cuong.le@gmail.com',       CURRENT_TIMESTAMP - INTERVAL '50 days'),
(4,  'Phạm Minh Đức',       'duc.pham@gmail.com',       CURRENT_TIMESTAMP - INTERVAL '45 days'),
(5,  'Hoàng Thu Giang',     'giang.hoang@gmail.com',    CURRENT_TIMESTAMP - INTERVAL '40 days'),
(6,  'Vũ Đình Hải',         'hai.vu@gmail.com',         CURRENT_TIMESTAMP - INTERVAL '35 days'),
(7,  'Đỗ Mỹ Linh',          'linh.do@gmail.com',        CURRENT_TIMESTAMP - INTERVAL '30 days'),
(8,  'Bùi Quốc Nam',        'nam.bui@gmail.com',        CURRENT_TIMESTAMP - INTERVAL '25 days'),
(9,  'Đặng Tuấn Kiệt',      'kiet.dang@outlook.com',    CURRENT_TIMESTAMP - INTERVAL '22 days'),
(10, 'Ngô Phương Thảo',     'thao.ngo@yahoo.com',       CURRENT_TIMESTAMP - INTERVAL '20 days'),
(11, 'Dương Gia Bảo',       'bao.duong@gmail.com',      CURRENT_TIMESTAMP - INTERVAL '18 days'),
(12, 'Lý Thanh Tâm',        'tam.ly@gmail.com',         CURRENT_TIMESTAMP - INTERVAL '15 days'),
(13, 'Trương Quốc Khánh',   'khanh.truong@gmail.com',   CURRENT_TIMESTAMP - INTERVAL '12 days'),
(14, 'Mai Ngọc Ánh',        'anh.mai@gmail.com',        CURRENT_TIMESTAMP - INTERVAL '8 days'),
(15, 'Phan Trọng Hiếu',     'hieu.phan@gmail.com',      CURRENT_TIMESTAMP - INTERVAL '5 days');

-- 2. BẢNG DANH MỤC (21 danh mục chia 3 tầng sâu)
INSERT INTO DANHMUC (MaDanhMuc, TenDanhMuc, MaDanhMucCha)
OVERRIDING SYSTEM VALUE VALUES
-- Tầng 1: 3 Danh mục gốc (MaDanhMucCha IS NULL)
(1, 'Thiết bị công nghệ & Điện tử', NULL),
(2, 'Tác phẩm nghệ thuật & Điêu khắc', NULL),
(3, 'Cổ vật & Đồ sưu tầm quý hiếm', NULL),

-- Tầng 2: 6 Danh mục nhánh giữa
(4, 'Máy ảnh & Thiết bị quang học',  1),
(5, 'Âm thanh Hi-End & Máy tính',    1),
(6, 'Hội họa truyền thống Việt Nam', 2),
(7, 'Mỹ thuật đương đại & Điêu khắc',2),
(8, 'Tiền cổ, Tem & Đồng hồ cơ',     3),
(9, 'Gốm sứ cổ đại & Đồ đồng',       3),

-- Tầng 3: 12 Danh mục lá (Chi tiết)
(10, 'Máy ảnh Mirrorless & Rangefinder', 4),
(11, 'Ống kính (Lens) & Máy quay Cinema',4),
(12, 'Thiết bị bay & Drone chuyên nghiệp',4),
(13, 'Mâm đĩa than & Amply đèn Hi-Fi',   5),
(14, 'Laptop Workstation & Máy trạm',    5),
(15, 'Tranh sơn mài & Khảm xà cừ',       6),
(16, 'Tranh lụa & Tranh giấy Dó',        6),
(17, 'Tranh sơn dầu & Acrylic',          7),
(18, 'Tượng điêu khắc đồng & Gỗ quý',    7),
(19, 'Tiền xu bạc & Tem thư quý hiếm',   8),
(20, 'Đồng hồ cơ Vintage Thụy Sĩ',       8),
(21, 'Bình gốm & Lư đồng phong kiến',    9);

-- 3. BẢNG TÀI SẢN (18 Tài sản: 6 Nghệ thuật, 6 Đồ sưu tầm, 6 Thiết bị điện tử)
INSERT INTO TAISAN (MaTaiSan, MaNguoiBan, MaDanhMuc, LoaiTaiSan, TenTaiSan, MoTa, ThoiDiemTao)
OVERRIDING SYSTEM VALUE VALUES
-- A. NHÓM TÁC PHẨM NGHỆ THUẬT (ID: 1 -> 6)
(1, 1, 15, 'TACPHAMNGHETHUAT', 'Bức họa Ánh Trăng Đêm', 
    'Tranh sơn mài khảm ốc đỏ tinh xảo từ làng nghề truyền thống Hạ Thái', CURRENT_TIMESTAMP - INTERVAL '20 days'),
(2, 2, 17, 'TACPHAMNGHETHUAT', 'Bình Minh Trên Đỉnh Phù Vân', 
    'Tranh sơn dầu vẽ phong cảnh thiên nhiên Tây Bắc khổ lớn 120x80cm', CURRENT_TIMESTAMP - INTERVAL '19 days'),
(3, 1, 15, 'TACPHAMNGHETHUAT', 'Hội Làng Mùa Xuân', 
    'Tác phẩm tranh sơn mài thếp vàng đạt giải mỹ thuật năm 2018', CURRENT_TIMESTAMP - INTERVAL '18 days'),
(4, 9, 16, 'TACPHAMNGHETHUAT', 'Thiếu Nữ Bên Hoa Sen', 
    'Tranh vẽ trên lụa tơ tằm Hà Đông bằng màu khoáng tự nhiên', CURRENT_TIMESTAMP - INTERVAL '17 days'),
(5, 2, 17, 'TACPHAMNGHETHUAT', 'Phố Cổ Hà Nội Mùa Thu', 
    'Tranh sơn dầu vẽ bằng bay (Palette Knife) tạo khối nổi 3D sống động', CURRENT_TIMESTAMP - INTERVAL '16 days'),
(6, 9, 18, 'TACPHAMNGHETHUAT', 'Tượng đồng Cá Chép Hóa Rồng', 
    'Tác phẩm điêu khắc đồng đỏ nguyên khối đúc thủ công nặng 18kg', CURRENT_TIMESTAMP - INTERVAL '15 days'),

-- B. NHÓM ĐỒ SƯU TẦM (ID: 7 -> 12)
(7,  3, 19, 'DOSUUTAM', 'Đồng xu bạc Đông Dương 1 Piastre 1908', 
    'Đồng xu cổ nguyên bản thời Pháp thuộc, độ hoàn thiện sắc nét hiếm có', CURRENT_TIMESTAMP - INTERVAL '14 days'),
(8,  4, 21, 'DOSUUTAM', 'Bình gốm hoa nâu thời Lý thế kỷ XI', 
    'Hiện vật gốm men tro họa tiết hoa sen khắc chìm còn nguyên vẹn', CURRENT_TIMESTAMP - INTERVAL '13 days'),
(9,  3, 19, 'DOSUUTAM', 'Bộ tem thư kỷ niệm Quốc tế Lao động 1957', 
    'Bộ tem cổ còn nguyên lề 4 con, chưa đóng dấu bưu điện', CURRENT_TIMESTAMP - INTERVAL '12 days'),
(10, 10, 20, 'DOSUUTAM', 'Đồng hồ bỏ túi Omega Grand Prix Paris 1900', 
    'Đồng hồ quả quýt vỏ bạc đúc 0.800, máy cơ cót tay chạy chuẩn xác', CURRENT_TIMESTAMP - INTERVAL '11 days'),
(11, 4, 21, 'DOSUUTAM', 'Lư hương đồng tam sự thời Nguyễn', 
    'Bộ lư đồng mắt tre lên màu patin xanh cổ kính tự nhiên qua hơn 100 năm', CURRENT_TIMESTAMP - INTERVAL '10 days'),
(12, 10, 20, 'DOSUUTAM', 'Đồng hồ đeo tay Rolex Oyster Perpetual 1968', 
    'Phiên bản mặt số Pie-Pan cổ điển, dây da cá sấu nguyên bản kèm hộp xưa', CURRENT_TIMESTAMP - INTERVAL '9 days'),

-- C. NHÓM THIẾT BỊ ĐIỆN TỬ (ID: 13 -> 18)
(13, 5, 10, 'THIETBIDIENTU', 'Máy ảnh Leica M11 Body (Bản giới hạn Đen Nhám)', 
    'Máy ảnh Rangefinder Full-frame 60MP sản xuất tại Đức, chụp dưới 500 shot', CURRENT_TIMESTAMP - INTERVAL '8 days'),
(14, 6, 11, 'THIETBIDIENTU', 'Ống kính Sony FE 70-200mm f/2.8 GM OSS II', 
    'Ống kính Tele G-Master thế hệ 2, kính trong vắt không bụi mốc, kèm hood zin', CURRENT_TIMESTAMP - INTERVAL '7 days'),
(15, 5, 13, 'THIETBIDIENTU', 'Mâm đĩa than McIntosh MT5 Precision Turntable', 
    'Bàn xoay đĩa than Hi-End kim đọc Blue Point No.2, mâm phát sáng xanh đặc trưng', CURRENT_TIMESTAMP - INTERVAL '6 days'),
(16, 6, 14, 'THIETBIDIENTU', 'Laptop Apple MacBook Pro 16-inch M3 Max 64GB/2TB', 
    'Trạm làm việc di động cấu hình kịch trần cho đồ họa 3D, pin sạc 12 lần', CURRENT_TIMESTAMP - INTERVAL '5 days'),
(17, 11, 12, 'THIETBIDIENTU', 'Flycam DJI Inspire 3 Cinema Drone Combo', 
    'Drone quay phim điện ảnh chuẩn 8K ProRes RAW kèm camera Zenmuse X9', CURRENT_TIMESTAMP - INTERVAL '4 days'),
(18, 11, 13, 'THIETBIDIENTU', 'Amply đèn Accuphase E-800 Class A Integrated', 
    'Amply Hi-End tham chiếu xuất xứ Nhật Bản, công suất thuần Class A 50W/kênh', CURRENT_TIMESTAMP - INTERVAL '3 days');

-- 4. BẢNG CON: TÁC PHẨM NGHỆ THUẬT (6 bản ghi: ID 1 -> 6)
INSERT INTO TACPHAMNGHETHUAT (MaTaiSan, TacGia, ChatLieu, NamSangTac) VALUES
(1, 'Họa sĩ Nguyễn Gia Trí',    'Sơn mài trên gỗ mít dát vàng',   2012),
(2, 'Họa sĩ Trần Văn Cẩn',      'Sơn dầu trên toan Canvas',       2019),
(3, 'Họa sĩ Nguyễn Phan Chánh', 'Sơn mài vỏ trứng và thếp bạc',   2018),
(4, 'Họa sĩ Mai Trung Thứ',     'Màu nước trên lụa tơ tằm',       2015),
(5, 'Họa sĩ Bùi Xuân Phái',     'Sơn dầu vẽ bay trên bố',         2021),
(6, 'Nghệ nhân Vũ Duy Thuấn',   'Đồng đỏ đúc thủ công nguyên khối',2020);

-- 5. BẢNG CON: ĐỒ SƯU TẦM (6 bản ghi: ID 7 -> 12)
INSERT INTO DOSUUTAM (MaTaiSan, NguonGoc, DoHiem, NamSanXuat) VALUES
(7,  'Sưu tập tư nhân tại Hà Nội',     'Cực hiếm (Độ nét XF45)',    1908),
(8,  'Khai quật di chỉ Nam Sách',       'Độc bản bảo tàng cấp 2',    1085),
(9,  'Nhượng quyền từ gia đình bưu tá', 'Hiếm gặp (Mint Condition)',  1957),
(10, 'Đấu giá viên tại Geneva Thụy Sĩ', 'Giới hạn 500 chiếc toàn cầu',1900),
(11, 'Phủ thờ cổ tại Cố đô Huế',        'Cổ vật nguyên trạng cấp 1',  1895),
(12, 'Bộ sưu tập đồng hồ Sài Gòn xưa',  'Rất hiếm (Zin nguyên bản)',  1968);

-- 6. BẢNG CON: THIẾT BỊ ĐIỆN TỬ (6 bản ghi: ID 13 -> 18)
INSERT INTO THIETBIDIENTU (MaTaiSan, ThuongHieu, MauThietBi, SoSeRi, TinhTrang) VALUES
(13, 'Leica',     'Đen nhám (Matte Black)',       'LC-M11-GER-88901', 'Như mới 99.9% Fullbox'),
(14, 'Sony',      'Trắng Xám G-Master',           'SN-GM2-70200-452', 'Đã qua sử dụng 98%'),
(15, 'McIntosh',  'Đen phối Kính xanh',           'MC-MT5-USA-10294', 'Nguyên bản 100%'),
(16, 'Apple',     'Đen Không Gian (Space Black)', 'C02-M3MAX-99812',  'Mới 99% còn AppleCare+'),
(17, 'DJI',       'Đen Carbon Fiber',             'DJI-INS3-CN-77412','Mới 99% bay 3 giờ'),
(18, 'Accuphase', 'Vàng Champagne (Gold)',        'ACC-E800-JP-33901','Nguyên thùng xốp 99.5%');

-- 7. BẢNG PHIÊN ĐẤU GIÁ (20 phiên: 6 đang diễn ra, 3 chưa mở, 7 đã đóng, 4 thất bại)
INSERT INTO PHIENDAUGIA (
    MaPhien, MaTaiSan, GiaKhoiDiem, BuocGia, ThoiDiemMo, ThoiDiemDong, TrangThaiPhien
) OVERRIDING SYSTEM VALUE VALUES
(1, 1,  5000000, 250000, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '30 minutes', 'DANG_DIEN_RA'),
(2, 7,  2000000, 100000, CURRENT_TIMESTAMP - INTERVAL '3 days', CURRENT_TIMESTAMP - INTERVAL '2 days', 'DA_DONG'),
(3, 13, 8000000, 500000, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '1 day', 'THAT_BAI'),
(4, 14, 3000000, 200000, CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '2 hours', 'DANG_DIEN_RA'),
(5, 2,  4000000, 200000, CURRENT_TIMESTAMP + INTERVAL '1 day', CURRENT_TIMESTAMP + INTERVAL '2 days', 'CHUA_MO'),
(6, 8,  1000000, 100000, CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '1 day', 'DA_DONG'),
(7,  3,  80000000,  5000000, CURRENT_TIMESTAMP - INTERVAL '16 days', CURRENT_TIMESTAMP - INTERVAL '12 days', 'DA_DONG'),
(8,  4,  40000000,  2000000, CURRENT_TIMESTAMP - INTERVAL '15 days', CURRENT_TIMESTAMP - INTERVAL '11 days', 'THAT_BAI'),
(9,  9,   8000000,   500000, CURRENT_TIMESTAMP - INTERVAL '11 days', CURRENT_TIMESTAMP - INTERVAL '8 days',  'THAT_BAI'),
-- Phiên 10: Tài sản 9 được đăng đấu giá lại sau khi Phiên 9 thất bại (Quy tắc 5)
(10, 9,   6000000,   500000, CURRENT_TIMESTAMP - INTERVAL '6 days',  CURRENT_TIMESTAMP - INTERVAL '2 days',  'DA_DONG'),
(11, 10, 120000000, 5000000, CURRENT_TIMESTAMP - INTERVAL '10 days', CURRENT_TIMESTAMP - INTERVAL '5 days',  'DA_DONG'),
(12, 12, 250000000, 10000000,CURRENT_TIMESTAMP - INTERVAL '3 days',  CURRENT_TIMESTAMP + INTERVAL '2 days',  'DANG_DIEN_RA'),
(13, 15, 220000000, 10000000,CURRENT_TIMESTAMP - INTERVAL '5 days',  CURRENT_TIMESTAMP - INTERVAL '1 day',   'THAT_BAI'),
(14, 16, 90000000,  2000000, CURRENT_TIMESTAMP - INTERVAL '4 days',  CURRENT_TIMESTAMP + INTERVAL '1 day',   'DANG_DIEN_RA'),
-- Phiên 15: Lượt trả cuối rơi vào 20 giây trước giờ đóng nên được gia hạn thêm 2 phút (Quy tắc 2)
(15, 17, 200000000, 5000000, CURRENT_TIMESTAMP - INTERVAL '3 days',
     CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '2 days 18 hours 2 minutes', 'DA_DONG'),
(16, 5,  35000000,  1500000, CURRENT_TIMESTAMP - INTERVAL '2 days',  CURRENT_TIMESTAMP + INTERVAL '3 days',  'DANG_DIEN_RA'),
(17, 11, 45000000,  2000000, CURRENT_TIMESTAMP - INTERVAL '1 day',   CURRENT_TIMESTAMP + INTERVAL '4 days',  'DANG_DIEN_RA'),
(18, 6,  60000000,  3000000, CURRENT_TIMESTAMP + INTERVAL '2 days',  CURRENT_TIMESTAMP + INTERVAL '7 days',  'CHUA_MO'),
(19, 18, 150000000, 5000000, CURRENT_TIMESTAMP + INTERVAL '1 day',   CURRENT_TIMESTAMP + INTERVAL '6 days',  'CHUA_MO'),
-- Phiên 20: Tài sản 13 được đăng đấu giá lại sau khi Phiên 3 thất bại (Quy tắc 5)
(20, 13, 7000000,   500000,  CURRENT_TIMESTAMP - INTERVAL '22 hours', CURRENT_TIMESTAMP - INTERVAL '2 hours', 'DA_DONG');

-- 8. BẢNG ĐĂNG KÝ (50 bản ghi đăng ký tham gia phiên)
INSERT INTO DANGKY (MaPhien, MaNguoiDung, TrangThaiDangKy, ThoiDiemDangKy)
SELECT dk.MaPhien, dk.MaNguoiDung, dk.TrangThai, p.ThoiDiemMo + dk.LechSoVoiMo
FROM (VALUES
    (1, 7, 'DA_DUYET', INTERVAL '5 minutes'), (1, 8, 'DA_DUYET', INTERVAL '5 minutes'),
    (1, 12, 'CHO_DUYET', INTERVAL '5 minutes'),
    (2, 7, 'DA_DUYET', INTERVAL '5 minutes'), (2, 12, 'DA_DUYET', INTERVAL '5 minutes'),
    (3, 8, 'DA_DUYET', INTERVAL '5 minutes'),
    (4, 7, 'DA_DUYET', INTERVAL '5 minutes'), (4, 8, 'DA_DUYET', INTERVAL '5 minutes'),
    (4, 12, 'CHO_DUYET', INTERVAL '5 minutes'),
    (6, 7, 'DA_DUYET', INTERVAL '5 minutes'), (6, 13, 'DA_DUYET', INTERVAL '5 minutes'),
    (7, 5, 'DA_DUYET', INTERVAL '-6 hours'), (7, 6, 'DA_DUYET', INTERVAL '-6 hours'),
    (7, 10, 'DA_DUYET', INTERVAL '-6 hours'),
    (8, 2, 'DA_DUYET', INTERVAL '-6 hours'), (8, 7, 'TU_CHOI', INTERVAL '-6 hours'),
    (9, 12, 'DA_DUYET', INTERVAL '-6 hours'),
    (10, 12, 'DA_DUYET', INTERVAL '-6 hours'), (10, 14, 'DA_DUYET', INTERVAL '-6 hours'),
    (11, 1, 'DA_DUYET', INTERVAL '-6 hours'), (11, 4, 'DA_DUYET', INTERVAL '-6 hours'),
    (11, 7, 'DA_DUYET', INTERVAL '-6 hours'), (11, 13, 'DA_DUYET', INTERVAL '-6 hours'),
    (12, 3, 'DA_DUYET', INTERVAL '-6 hours'), (12, 6, 'DA_DUYET', INTERVAL '-6 hours'),
    (12, 9, 'DA_DUYET', INTERVAL '-6 hours'), (12, 15, 'DA_DUYET', INTERVAL '-6 hours'),
    (13, 9, 'DA_DUYET', INTERVAL '-6 hours'),
    (14, 8, 'DA_DUYET', INTERVAL '-6 hours'), (14, 11, 'DA_DUYET', INTERVAL '-6 hours'),
    (14, 13, 'DA_DUYET', INTERVAL '-6 hours'), (14, 14, 'DA_DUYET', INTERVAL '-6 hours'),
    (14, 15, 'CHO_DUYET', INTERVAL '-6 hours'),
    (15, 4, 'DA_DUYET', INTERVAL '-6 hours'), (15, 6, 'DA_DUYET', INTERVAL '-6 hours'),
    (15, 13, 'DA_DUYET', INTERVAL '-6 hours'), (15, 15, 'DA_DUYET', INTERVAL '-6 hours'),
    (16, 1, 'DA_DUYET', INTERVAL '-6 hours'), (16, 7, 'DA_DUYET', INTERVAL '-6 hours'),
    (16, 14, 'DA_DUYET', INTERVAL '-6 hours'),
    (17, 5, 'DA_DUYET', INTERVAL '-6 hours'), (17, 11, 'DA_DUYET', INTERVAL '-6 hours'),
    (18, 2, 'DA_DUYET', INTERVAL '-2 days -6 hours'), (18, 12, 'CHO_DUYET', INTERVAL '-2 days -6 hours'),
    (19, 5, 'CHO_DUYET', INTERVAL '-1 day -6 hours'), (19, 7, 'DA_DUYET', INTERVAL '-1 day -6 hours'),
    (19, 10, 'TU_CHOI', INTERVAL '-1 day -6 hours'),
    (20, 3, 'DA_DUYET', INTERVAL '-6 hours'), (20, 8, 'DA_DUYET', INTERVAL '-6 hours'),
    (20, 14, 'DA_DUYET', INTERVAL '-6 hours')
) AS dk(MaPhien, MaNguoiDung, TrangThai, LechSoVoiMo)
JOIN PHIENDAUGIA p ON p.MaPhien = dk.MaPhien;

-- 9. BẢNG LƯỢT TRẢ GIÁ (45 lượt trả giá hợp lệ, tuân thủ lưới bước giá và có mã UUID riêng)
INSERT INTO LUOTTRAGIA (MaPhien, MaNguoiTraGia, SoTien, MaYeuCau, ThoiDiemChapNhan)
SELECT lg.MaPhien, lg.MaNguoiDung, lg.SoTien, lg.MaYeuCau::UUID,
       p.ThoiDiemMo + lg.SauKhiMo
FROM (VALUES
    (1, 7, 5000000, '19000000-0000-4000-8000-000000000001', INTERVAL '10 minutes'),
    (1, 8, 5250000, '19000000-0000-4000-8000-000000000002', INTERVAL '20 minutes'),
    (1, 7, 5500000, '19000000-0000-4000-8000-000000000003', INTERVAL '30 minutes'),
    (2, 7, 2000000, '19000000-0000-4000-8000-000000000004', INTERVAL '10 minutes'),
    (2, 12,2100000, '19000000-0000-4000-8000-000000000005', INTERVAL '20 minutes'),
    (6, 7, 1000000, '19000000-0000-4000-8000-000000000006', INTERVAL '10 minutes'),
    (6, 13,1200000, '19000000-0000-4000-8000-000000000007', INTERVAL '20 minutes'),
    (7, 5,  80000000, '19000000-0000-4000-8000-000000000008', INTERVAL '1 hour'),
    (7, 10, 85000000, '19000000-0000-4000-8000-000000000009', INTERVAL '6 hours'),
    (7, 5,  90000000, '19000000-0000-4000-8000-000000000010', INTERVAL '1 day'),
    (7, 6, 100000000, '19000000-0000-4000-8000-000000000011', INTERVAL '2 days'),
    (7, 10,105000000, '19000000-0000-4000-8000-000000000012', INTERVAL '3 days 12 hours'),
    (10, 12, 6000000, '19000000-0000-4000-8000-000000000013', INTERVAL '4 hours'),
    (10, 14, 6500000, '19000000-0000-4000-8000-000000000014', INTERVAL '1 day'),
    (10, 12, 7500000, '19000000-0000-4000-8000-000000000015', INTERVAL '2 days'),
    (11, 4, 120000000, '19000000-0000-4000-8000-000000000016', INTERVAL '3 hours'),
    (11, 13,125000000, '19000000-0000-4000-8000-000000000017', INTERVAL '9 hours'),
    (11, 4, 130000000, '19000000-0000-4000-8000-000000000018', INTERVAL '1 day'),
    (11, 1, 140000000, '19000000-0000-4000-8000-000000000019', INTERVAL '2 days'),
    (11, 13,150000000, '19000000-0000-4000-8000-000000000020', INTERVAL '3 days'),
    (11, 4, 155000000, '19000000-0000-4000-8000-000000000021', INTERVAL '4 days 20 hours'),
    (12, 9, 250000000, '19000000-0000-4000-8000-000000000022', INTERVAL '2 hours'),
    (12, 3, 260000000, '19000000-0000-4000-8000-000000000023', INTERVAL '8 hours'),
    (12, 9, 270000000, '19000000-0000-4000-8000-000000000024', INTERVAL '1 day'),
    (12, 15,290000000, '19000000-0000-4000-8000-000000000025', INTERVAL '2 days'),
    (12, 3, 300000000, '19000000-0000-4000-8000-000000000026', INTERVAL '2 days 18 hours'),
    (14, 11, 90000000, '19000000-0000-4000-8000-000000000027', INTERVAL '1 hour'),
    (14, 14, 92000000, '19000000-0000-4000-8000-000000000028', INTERVAL '4 hours'),
    (14, 8,  96000000, '19000000-0000-4000-8000-000000000029', INTERVAL '1 day'),
    (14, 11,100000000, '19000000-0000-4000-8000-000000000030', INTERVAL '2 days'),
    (14, 14,102000000, '19000000-0000-4000-8000-000000000031', INTERVAL '3 days'),
    (14, 13,106000000, '19000000-0000-4000-8000-000000000032', INTERVAL '3 days 12 hours'),
    (15, 13,200000000, '19000000-0000-4000-8000-000000000033', INTERVAL '1 hour'),
    (15, 6, 205000000, '19000000-0000-4000-8000-000000000034', INTERVAL '5 hours'),
    (15, 13,215000000, '19000000-0000-4000-8000-000000000035', INTERVAL '1 day'),
    (15, 4, 220000000, '19000000-0000-4000-8000-000000000036', INTERVAL '2 days'),
    (15, 15,230000000, '19000000-0000-4000-8000-000000000037', INTERVAL '2 days 17 hours 59 minutes 40 seconds'),
    (16, 1, 35000000, '19000000-0000-4000-8000-000000000038', INTERVAL '3 hours'),
    (16, 14,36500000, '19000000-0000-4000-8000-000000000039', INTERVAL '10 hours'),
    (16, 1, 38000000, '19000000-0000-4000-8000-000000000040', INTERVAL '1 day'),
    (16, 7, 41000000, '19000000-0000-4000-8000-000000000041', INTERVAL '1 day 12 hours'),
    (20, 8,  7000000, '19000000-0000-4000-8000-000000000042', INTERVAL '1 hour'),
    (20, 14, 7500000, '19000000-0000-4000-8000-000000000043', INTERVAL '5 hours'),
    (20, 8,  8500000, '19000000-0000-4000-8000-000000000044', INTERVAL '12 hours'),
    (20, 3,  9000000, '19000000-0000-4000-8000-000000000045', INTERVAL '18 hours')
) AS lg(MaPhien, MaNguoiDung, SoTien, MaYeuCau, SauKhiMo)
JOIN PHIENDAUGIA p ON p.MaPhien = lg.MaPhien;

WITH LuotCaoNhat AS (
    SELECT DISTINCT ON (MaPhien) MaPhien, MaLuotTraGia, SoTien,
           COUNT(*) OVER (PARTITION BY MaPhien) AS SoLuot
    FROM LUOTTRAGIA
    ORDER BY MaPhien, SoTien DESC, MaLuotTraGia
)
UPDATE PHIENDAUGIA p
SET GiaHienTai = l.SoTien, MaLuotDanDau = l.MaLuotTraGia, PhienBan = l.SoLuot
FROM LuotCaoNhat l
WHERE p.MaPhien = l.MaPhien;

-- 10. BẢNG KẾT QUẢ ĐẤU GIÁ (11 phiên đã chốt: 7 thành công, 4 thất bại có MaLuotThang NULL)
INSERT INTO KETQUADAUGIA (MaPhien, MaLuotThang, ThoiDiemChot)
SELECT MaPhien, MaLuotDanDau, ThoiDiemDong
FROM PHIENDAUGIA
WHERE TrangThaiPhien IN ('DA_DONG', 'THAT_BAI');

UPDATE PHIENDAUGIA
SET PhienBan = PhienBan + 1
WHERE TrangThaiPhien IN ('DA_DONG', 'THAT_BAI');

-- 11. BẢNG NHẬT KÝ THAY ĐỔI (Nhật ký trả giá, đóng phiên và gia hạn chống vây giá)
INSERT INTO NHATKYTHAYDOI (MaPhien, MaTacNhan, HanhDong, ChiTiet, ThoiDiemGhi)
SELECT MaPhien, MaNguoiTraGia, 'CHAP_NHAN_TRA_GIA',
       jsonb_build_object('MaLuotTraGia', MaLuotTraGia, 'SoTien', SoTien, 'MaYeuCau', MaYeuCau),
       ThoiDiemChapNhan
FROM LUOTTRAGIA
UNION ALL
SELECT MaPhien, NULL::BIGINT, 'DONG_PHIEN',
       jsonb_build_object('MaLuotThang', MaLuotThang), ThoiDiemChot
FROM KETQUADAUGIA
UNION ALL
-- Chống vây giá: lượt cuối của phiên 15 làm giờ đóng lùi thêm 2 phút.
SELECT l.MaPhien, NULL::BIGINT, 'GIA_HAN_PHIEN',
       jsonb_build_object('MaLuotKichHoat', l.MaLuotTraGia,
                          'GioDongCu', p.ThoiDiemDong - INTERVAL '2 minutes',
                          'GioDongMoi', p.ThoiDiemDong),
       l.ThoiDiemChapNhan
FROM LUOTTRAGIA l
JOIN PHIENDAUGIA p ON p.MaPhien = l.MaPhien AND p.MaLuotDanDau = l.MaLuotTraGia
WHERE l.MaPhien = 15;

-- Đồng bộ lại Sequence cho các cột IDENTITY
SELECT setval(pg_get_serial_sequence('NGUOIDUNG', 'manguoidung'), (SELECT MAX(MaNguoiDung) FROM NGUOIDUNG));
SELECT setval(pg_get_serial_sequence('DANHMUC',   'madanhmuc'),   (SELECT MAX(MaDanhMuc) FROM DANHMUC));
SELECT setval(pg_get_serial_sequence('TAISAN',    'mataisan'),    (SELECT MAX(MaTaiSan) FROM TAISAN));
SELECT setval(pg_get_serial_sequence('PHIENDAUGIA', 'maphien'), (SELECT MAX(MaPhien) FROM PHIENDAUGIA));

COMMIT;
