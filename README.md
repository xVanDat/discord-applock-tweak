# Discord AppLock (iOS Native Tweak)

Tweak bảo vệ Discord trên iOS bằng Touch ID / Face ID và mật mã thiết bị, đồng thời che mờ hoặc hiện logo Discord trong App Switcher (đa nhiệm).

## Tính năng
- **Bảo mật sinh trắc học chuẩn Apple:** Sử dụng `LocalAuthentication.framework` (`LAPolicyDeviceOwnerAuthentication`) hỗ trợ Touch ID, Face ID và tự động chuyển sang Mật mã iPhone khi không quét được.
- **Trực tiếp từ ứng dụng:** Logo Discord lấy trực tiếp 100% từ icon chính chủ trong gói ứng dụng Discord (`CFBundleIcons`).
- **Che nội dung trong App Switcher:** Hook trực tiếp vào vòng đời ứng dụng ở tầng Native (`applicationWillResignActive:`), đảm bảo che ngay lập tức không bị delay trước khi iOS chụp ảnh thu nhỏ của ứng dụng.
- **Menu Cài đặt bằng cử chỉ 3 ngón tay:** Không cần cài bất kỳ plugin nào! Chỉ cần **nhấn giữ 3 ngón tay trên màn hình** khoảng 0.7 giây bên trong Discord để mở menu cài đặt Native:
  - Bật / tắt khoá Touch ID / Face ID.
  - Chọn kiểu che trong App Switcher: Logo Discord hoặc Làm mờ (Blur).
  - Chọn thời gian khoá lại: Ngay lập tức, 30 giây, 1 phút, 5 phút...
  - Tự do gõ thay đổi lời nhắn hiển thị dưới popup Touch ID / Face ID (Subtitle).
- **Bảo vệ chống thay đổi trái phép:** Cử chỉ 3 ngón tay yêu cầu xác thực vân tay / mật mã của chủ máy trước khi mở menu cài đặt!
