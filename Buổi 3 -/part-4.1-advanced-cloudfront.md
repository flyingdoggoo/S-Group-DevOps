# Phần 4.1 — Nâng cao 1: Sử dụng CloudFront trước S3 (CDN + HTTPS)

Một S3 website endpoint thông thường chỉ hỗ trợ HTTP, chỉ được phục vụ từ một Region duy nhất và làm lộ tên bucket. **CloudFront** là mạng phân phối nội dung (CDN) của AWS: nó lưu bộ đệm (cache) các file tĩnh của bạn tại các "điểm biên" (edge locations) trên toàn thế giới và cung cấp HTTPS miễn phí.

```text
Trình duyệt ──► CloudFront edge (thành phố gần nhất) ──► S3 bucket (origin)
              │ cache index.html, app.js
              └ phục vụ qua HTTPS, tên miền tùy chỉnh
```

**Lý do tại sao nên dùng:**
- **HTTPS** miễn phí qua AWS Certificate Manager.
- **Độ trễ (Latency):** các file được phục vụ từ điểm biên gần với người dùng nhất, thay vì chỉ ở một Region duy nhất.
- **Bảo mật:** bạn có thể khóa bucket ở trạng thái *hoàn toàn riêng tư (private)* và chỉ cho phép duy nhất CloudFront đọc nó (sử dụng Origin Access Control - OAC). Lúc này, URL của S3 sẽ không còn bị lộ ra công chúng nữa.

**Các bước phác thảo:**
1. Tạo một distribution trên CloudFront với origin là S3 bucket (sử dụng *REST* endpoint của bucket, **không phải** website endpoint khi dùng OAC).
2. Bật **Origin Access Control (OAC)** và để giao diện Console tự động cập nhật bucket policy sao cho chỉ CloudFront mới có thể đọc.
3. Cài đặt **Default root object** thành `index.html`.
4. Sau khi deploy, bạn sẽ nhận được một URL dạng `*.cloudfront.net` chạy qua HTTPS. Hãy trỏ bản ghi CNAME của domain tùy chỉnh (custom domain) của bạn vào URL đó.

> **Lưu ý quan trọng về xóa cache (Cache invalidation):** CloudFront cache cực kỳ mạnh mẽ. Sau khi upload lại `index.html`, bạn phải xóa cache thủ công: `aws cloudfront create-invalidation --distribution-id <ID> --paths "/index.html"`.
