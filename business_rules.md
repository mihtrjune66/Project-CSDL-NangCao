### ĐẶC TẢ QUY TẮC NGHIỆP VỤ HỆ THỐNG ĐẤU GIÁ ###

**1. Quy tắc Giá khởi điểm & Bước giá**
* Mỗi phiên đấu giá khởi tạo bắt buộc phải có Giá khởi điểm (`GiaKhoiDiem > 0`) và Bước giá (`BuocGia > 0`).
* Điều kiện trả giá: Lượt trả giá (`GiaTra`) chỉ hợp lệ khi `GiaTra >= GiaHienTai + BuocGia` và phải nằm đúng trên lưới bước giá: `MOD(GiaTra - GiaKhoiDiem, BuocGia) = 0`.
* Nếu phiên chưa có ai trả giá (`GiaHienTai IS NULL`), lượt trả đầu tiên tối thiểu phải bằng `GiaKhoiDiem` và vẫn phải tuân thủ lưới bước giá.

**2. Thời điểm Mở/Đóng & Tiêu chí chấp nhận trả giá gần giờ đóng (Anti-Sniping)**
* Khoảng thời gian hợp lệ: Hệ thống chỉ chấp nhận lượt trả giá khi thời điểm kiểm tra thực tế `ThoiDiemMo <= clock_timestamp() < ThoiDiemDong` và trạng thái phiên là `DANG_DIEN_RA`.
* Tiêu chí chấp nhận lượt trả giá gần giờ đóng: Thời điểm chấp nhận lượt trả giá (`v_thoi_diem := clock_timestamp()`) được lấy **sau khi giao dịch đã hoàn tất bước kiểm tra khóa/trạng thái**, bảo đảm không dùng thời gian bắt đầu transaction (`CURRENT_TIMESTAMP`) để lách qua mốc `ThoiDiemDong`. Đối với các phiên cấu hình chống vây giá (như Phiên 15 trong dữ liệu mẫu), lượt trả giá hợp lệ trong 30 giây cuối trước giờ đóng sẽ kích hoạt sự kiện `GIA_HAN_PHIEN` lùi mốc `ThoiDiemDong` thêm 2 phút.
* Đóng phiên đồng thời: Khi tiến trình `fn_DongPhienDauGia` kích hoạt tại mốc `clock_timestamp() >= ThoiDiemDong` (áp dụng cho phiên `DANG_DIEN_RA` hoặc phiên `CHUA_MO` đã quá hạn đóng), nó khóa dòng phiên (`FOR UPDATE`). Mọi lượt trả giá gửi đến sau mốc này hoặc phát sinh khi phiên đã đóng đều bị từ chối chính xác.

**3. Điều kiện Tham gia & Phòng ngừa thổi giá**
* Một người dùng có thể là Người bán ở phiên này và Người tham gia ở phiên khác. Chỉ những người dùng có bản ghi trong bảng `DANGKY` với trạng thái `TrangThaiDangKy = 'DA_DUYET'` mới được phép trả giá.
* Điều kiện chống gian lận: Người tạo tài sản (Người bán `TAISAN.MaNguoiBan`) tuyệt đối không được phép trả giá cho chính tài sản của mình.

**4. Cách xử lý hai yêu cầu cùng mức giá (Tie-breaking)**
* Trong một phiên, mỗi mức giá chỉ có tối đa một lượt trả giá được chấp nhận (`UNIQUE (MaPhien, SoTien)`). Khi hai yêu cầu trả cùng một mức giá xuất hiện đồng thời, hệ thống phân định dựa trên thứ tự giao dịch trong CSDL: khóa dòng phiên (Phương án 1) hoặc phát hiện xung đột tuần tự hóa của mức `SERIALIZABLE` (Phương án 2).
* Yêu cầu nào chiếm được khóa dòng (Phương án 1) hoặc commit trước (Phương án 2) sẽ được ghi nhận. Yêu cầu đến sau bị từ chối (ở Phương án 2: nhận lỗi `40001`, client thử lại cả giao dịch trên snapshot mới rồi bị từ chối) do `GiaHienTai` lúc này đã bị đẩy lên, vi phạm điều kiện bước giá tối thiểu.

**5. Cách xử lý khi KHÔNG có lượt trả giá hợp lệ (Bổ sung đầy đủ theo đề bài)**
* Khi mốc `ThoiDiemDong` đã qua mà phiên đấu giá không ghi nhận bất kỳ lượt trả giá nào hợp lệ (bảng `LUOTTRAGIA` trống cho phiên đó):
  * Tiến trình đóng phiên sẽ chuyển trạng thái phiên thành `THAT_BAI`.
  * Ghi nhận bản ghi chốt phiên vào bảng `KETQUADAUGIA` với `MaLuotThang = NULL` (biểu thị phiên đã chốt kết thúc nhưng không có người thắng cuộc, phục vụ thống kê tỷ lệ phiên thành công/thất bại).
  * Giải phóng tài sản để Người bán có thể thiết lập phiên đấu giá mới nếu muốn (như Tài sản 9 ở Phiên 9 thất bại được mở lại ở Phiên 10, hoặc Tài sản 13 ở Phiên 3 thất bại được mở lại ở Phiên 20).

**6. Quy tắc Phân định Thắng cuộc**
* Nếu có ít nhất 1 lượt trả giá hợp lệ, khi phiên kết thúc (`TrangThaiPhien = 'DA_DONG'`), hệ thống chốt duy nhất 1 kết quả thắng trong `KETQUADAUGIA` (`PRIMARY KEY (MaPhien)`) trỏ tới lượt trả giá cao nhất (`MaLuotThang`).
* Giá thắng truy xuất qua `MaLuotThang -> LUOTTRAGIA.SoTien` luôn bằng 100% với `GiaHienTai` trong `PHIENDAUGIA` và khớp với giá trị cao nhất `MAX(SoTien)` trong lịch sử `LUOTTRAGIA`.