# Phần 3.3 — Bài tập 3: Khóa chặt Bucket Policy (Lock Down the Bucket Policy)

Quyền `s3:GetObject` được mở toang khá phù hợp cho một buổi demo nhưng lại rất cẩu thả trong thực tế.

### Yêu cầu:
1. Xác nhận các quyền hiện tại đang được cho phép: `aws s3api get-bucket-policy --bucket "$BUCKET"`.
2. Hạn chế policy để nó chỉ cấp quyền `s3:GetObject` (đã có sẵn) và không cấp gì khác — xác nhận rằng không có hành động `s3:ListBucket` hay quyền ghi (write) nào được công khai.
3. Cố gắng ghi một file vào bucket dưới dạng người dùng ẩn danh (ví dụ: dùng `curl -X PUT`) và xác nhận thao tác đó bị từ chối (denied).
4. Lập tài liệu giải thích tại sao quyền "public read" (đọc công khai) không bao giờ đồng nghĩa với việc cho phép "public list" (danh sách công khai) hoặc "public write" (ghi công khai).

---

## Hướng dẫn giải quyết & Giải thích

### Bước 1: Kiểm tra quyền hiện tại
Chạy lệnh kiểm tra policy:
```bash
aws s3api get-bucket-policy --bucket "$BUCKET"
```
Kết quả trả về sẽ hiển thị file JSON chứa cấu hình policy hiện tại. Đảm bảo ở phần `Action` chỉ có `"s3:GetObject"`.

### Bước 2: Đảm bảo policy giới hạn nghiêm ngặt
Nếu policy bạn đang dùng giống ở Phần 2.1, nó vốn đã an toàn vì chỉ cấp `s3:GetObject`. Để kiểm tra chắc chắn không có `ListBucket`, hãy thử mở trình duyệt hoặc gọi cURL vào thẳng thư mục gốc của bucket (ví dụ `http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com/`).
Nếu S3 trả về mã `403 Forbidden` thay vì liệt kê các file, nghĩa là quyền `ListBucket` đã được khóa an toàn.

### Bước 3: Thử nghiệm quyền Write (Ghi)
Dùng lệnh cURL để cố gắng upload hoặc sửa đổi một file:
```bash
curl -X PUT -d "hacked" http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com/hacked.html
```
Kết quả trả về sẽ là một thông báo lỗi HTTP 403 Forbidden (hoặc `AccessDenied`). Điều này chứng tỏ người dùng bên ngoài không thể thay đổi dữ liệu của bạn.

### Bước 4: Giải thích (Trả lời yêu cầu 4)
**Giải thích:**
- **Không Public List:** Nếu bạn cho phép liệt kê file (list bucket), bất kỳ ai cũng có thể xem toàn bộ cấu trúc thư mục của bạn. Kẻ xấu có thể tải xuống các file nhạy cảm vô tình bị lọt vào đó (ví dụ như mã nguồn nháp, file .env), hoặc clone toàn bộ website của bạn một cách dễ dàng.
- **Không Public Write:** Cấp quyền ghi công khai là lỗi bảo mật nghiêm trọng nhất. Kẻ xấu có thể thay thế file `index.html` của bạn thành mã độc (phishing), phát tán virus trên đường dẫn website của bạn, hoặc upload hàng tấn dữ liệu rác để làm "cháy túi" chi phí S3 của bạn. Quyền đọc (read) chỉ dùng để cung cấp tài nguyên tĩnh, không bao giờ được phép thay đổi (write).
