# Discord AppLock (iOS Native Tweak)

Tweak bảo vệ Discord trên iOS bằng Touch ID / Face ID và mật mã thiết bị, đồng thời che mờ hoặc hiện logo Discord trong App Switcher (đa nhiệm).

## Tính năng
- **Bảo mật sinh trắc học chuẩn Apple:** Sử dụng `LocalAuthentication.framework` (`LAPolicyDeviceOwnerAuthentication`) hỗ trợ Touch ID, Face ID và tự động chuyển sang Mật mã iPhone khi không quét được.
- **Che nội dung trong App Switcher:** Hook trực tiếp vào vòng đời ứng dụng ở tầng Native (`applicationWillResignActive:`), đảm bảo che ngay lập tức không bị delay trước khi iOS chụp ảnh thu nhỏ của ứng dụng.
- **Tùy chọn phong cách:** Hỗ trợ lớp phủ làm mờ (Blur) hoặc lớp phủ nền tối kèm Logo Discord chính giữa.
- **Thời gian chờ (Timeout):** Cho phép đặt thời gian khoá lại (ngay lập tức, 30 giây, 1 phút, 5 phút...).

## Cách build thành file `.deb` trên Windows (Không cần máy Mac)
Dự án đã tích hợp sẵn GitHub Actions workflow tại `.github/workflows/build.yml`:
1. Tạo một repository mới trên GitHub (public hoặc private).
2. Tải toàn bộ thư mục `discord-applock-tweak` lên repository đó.
3. Vào tab **Actions** trên GitHub repository $\rightarrow$ chọn workflow **Build Discord AppLock Deb** $\rightarrow$ nhấn **Run workflow**.
4. Chờ khoảng 1-2 phút, sau khi build xong bạn vào mục **Artifacts** để tải file `DiscordAppLock-deb.zip` (bên trong có file `.deb` sẵn sàng cài đặt).

## Cách cài đặt trên iPhone
- **Nếu dùng Jailbreak (Dopamine, palera1n...):** Mở file `.deb` bằng **Sileo** hoặc **Zebra** và bấm cài đặt, sau đó mở lại Discord.
- **Nếu dùng TrollStore / Sideloadly / AltStore:** 
  - Bạn có thể chèn trực tiếp file `.dylib` (biên dịch từ tweak) vào file `.ipa` của Discord qua Sideloadly (mục *Advanced $\rightarrow$ Inject dylibs/frameworks*) hoặc TrollStore.
