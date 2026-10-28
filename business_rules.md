### ĐẶC TẢ QUY TẮC NGHIỆP VỤ HỆ THỐNG ĐẤU GIÁ ###

**1. Quy tắc Giá khởi điểm & Bước giá**
* Mỗi phiên đấu giá khởi tạo bắt buộc phải có Giá khởi điểm (GiaKhoiDiem) và Bước giá (BuocGia).
* Điều kiện trả giá: Lượt trả giá (GiaTra) chỉ hợp lệ khi GiaTra >= GiaHienTai + BuocGia.
* Nếu phiên chưa có ai trả giá, lượt trả đầu tiên tối thiểu phải bằng GiaKhoiDiem.

**2. Thời điểm Mở/Đóng & Tiêu chí chấp nhận trả giá gần giờ đóng (Anti-Sniping)**
* Khoảng thời gian hợp lệ: Hệ thống chỉ chấp nhận lượt trả giá khi ThoiGianBatDau <= ThoiGianTra <= ThoiGianKetThuc và trạng thái phiên là DANG_DIEN_RA.
* Trả giá gần giờ đóng: Nếu một lượt trả giá hợp lệ được gửi vào những giây cuối (ví dụ: trong vòng 30 giây trước ThoiGianKetThuc), hệ thống có thể áp dụng quy tắc tự động gia hạn thêm thời gian đóng (ví dụ: cộng thêm 2 phút vào ThoiGianKetThuc) để tránh hiện tượng vây giá ác ý (sniping) và tạo cơ hội cạnh tranh công bằng.
* Đóng phiên đồng thời: Khi tiến trình DongPhienDauGia kích hoạt tại mốc ThoiGianKetThuc, nó sẽ khóa phiên (FOR UPDATE hoặc dùng SERIALIZABLE). Mọi lượt trả giá gửi đến sau mốc này hoặc phát sinh khi phiên đang bị khóa đóng đều bị từ chối chính xác.

**3. Điều kiện Tham gia & Phòng ngừa thổi giá**
* Một người dùng có thể là Người bán ở phiên này và Người tham gia ở phiên khác.
* Điều kiện chống gian lận: Người tạo phiên (Người bán) tuyệt đối không được phép trả giá cho chính tài sản của mình.

**4. Cách xử lý hai yêu cầu cùng mức giá (Tie-breaking)**
* Khi hai yêu cầu trả giá bằng tiền xuất hiện cùng thời điểm, hệ thống phân định dựa trên dấu thời gian nguyên tử (Timestamp/Sequence) trong Transaction của CSDL.
* Yêu cầu nào chiếm được khóa dòng (Lock) và commit trước sẽ được ghi nhận. Yêu cầu đến sau bị từ chối do GiaHienTai lúc này đã bị đẩy lên, vi phạm điều kiện bước giá.

**5. Cách xử lý khi KHÔNG có lượt trả giá hợp lệ (Bổ sung đầy đủ theo đề bài)**
* Khi mốc ThoiGianKetThuc đến mà phiên đấu giá không ghi nhận bất kỳ lượt trả giá nào hợp lệ (bảng LuotTraGia trống cho phiên đó):
  * Tiến trình đóng phiên sẽ chuyển trạng thái phiên thành THAT_BAI (hoặc KHONG_THANH_CONG).
  * Không khởi tạo bản ghi người thắng trong bảng KetQuaDauGia.
  * Trả lại tài sản cho Người bán để họ có thể thiết lập phiên đấu giá mới nếu muốn.

**6. Quy tắc Phân định Thắng cuộc**
* Nếu có ít nhất 1 lượt trả giá hợp lệ, khi phiên kết thúc, hệ thống chốt duy nhất 1 kết quả thắng cho người trả giá cao nhất.
* Giá thắng (GiaThang) ghi vào KetQuaDauGia phải bằng 100% với GiaHienTai trong PhienDauGia và khớp với giá trị cao nhất trong LuotTraGia.