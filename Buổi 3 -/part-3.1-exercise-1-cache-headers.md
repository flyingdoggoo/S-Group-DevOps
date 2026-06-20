# Phần 3.1 — Bài tập 1: Cache Headers cho Static Assets

Một trình duyệt không bao giờ nên tải lại một file `app.js` nếu nó không thay đổi, nhưng nó bắt buộc phải luôn lấy được file `index.html` mới nhất.

### Yêu cầu:
1. Upload lại `index.html` với thời gian cache ngắn: `aws s3 cp ./frontend/index.html "s3://$BUCKET/" --cache-control "no-cache"`.
2. Upload các asset đã được băm tên (hashed assets như CSS/JS) với thời gian cache dài: `--cache-control "public, max-age=31536000, immutable"`.
3. Xác minh rằng các header này được trả về: `curl -I http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com/index.html` và kiểm tra header `Cache-Control`.
4. Giải thích trong một câu tại sao `index.html` phải là `no-cache` trong khi các bundle đã được băm tên (hashed bundles) có thể cache mãi mãi.

---

## Hướng dẫn giải quyết & Giải thích

### 1. Upload `index.html` với cache ngắn
Chạy lệnh sau trong terminal của bạn:
```bash
aws s3 cp ./frontend/index.html "s3://$BUCKET/" --cache-control "no-cache"
```
**Tại sao làm vậy?** Tùy chọn `--cache-control "no-cache"` thiết lập metadata cho file `index.html` trên S3, chỉ báo cho trình duyệt luôn phải kiểm tra lại (revalidate) với server trước khi sử dụng bản cache.

### 2. Upload các asset với cache dài
Giả sử bạn có file `app.12345.js` (hoặc các file CSS/JS tương tự), bạn upload chúng bằng lệnh:
```bash
aws s3 cp ./frontend/app.12345.js "s3://$BUCKET/" --cache-control "public, max-age=31536000, immutable"
```
**Tại sao làm vậy?** Các file này có tên độc nhất (chứa hash). Khi nội dung file thay đổi, tên file sẽ thay đổi (vd: thành `app.67890.js`). Do đó, file `app.12345.js` hiện tại sẽ không bao giờ thay đổi, cho phép trình duyệt cache nó trong thời gian tối đa (1 năm = 31536000 giây) mà không lo bị lỗi thời.

### 3. Xác minh header
Chạy lệnh curl để kiểm tra header:
```bash
curl -I http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com/index.html
```
Bạn sẽ thấy dòng `Cache-Control: no-cache` trong output trả về.

### 4. Giải thích (Trả lời yêu cầu 4)
**Giải thích:** File `index.html` là điểm bắt đầu của ứng dụng và chứa các đường dẫn trỏ tới các file JS/CSS (vd: `<script src="app.12345.js">`), do đó nó luôn cần bản cập nhật mới nhất để biết được tên file JS/CSS mới (`no-cache`); ngược lại, các bundle JS/CSS có tên chứa chuỗi băm (hash) tự động thay đổi mỗi khi nội dung thay đổi, nên phiên bản cũ của chúng có thể được lưu trữ vô thời hạn (`max-age=31536000`).
