# Phần 4.3 — Nâng cao 3: Định tuyến trên cùng một domain (Không bị lỗi CORS)

Khi frontend chạy trên `example.com` và backend chạy trên một máy chủ khác (domain khác), trình duyệt sẽ áp đặt chính sách **CORS (Cross-Origin Resource Sharing)** — bạn sẽ phải cấu hình các header CORS trên backend hoặc phải định tuyến cả hai về cùng một domain.

**Định tuyến theo đường dẫn (Path-based routing) sử dụng chung một ALB / CloudFront:**

```text
example.com/*       ──► S3 (frontend tĩnh)
example.com/api/*   ──► ECS backend
```

- **CloudFront** hỗ trợ thiết lập nhiều **origins** cùng với các **behaviors (hành vi)**: tất cả đường dẫn `/api/*` → chuyển tới ECS/ALB origin, tất cả các đường dẫn còn lại → chuyển tới S3 origin.
- Trình duyệt chỉ nhìn thấy một domain duy nhất → **không còn lỗi CORS, không có preflight requests, không phải lúng túng thiết lập biến `API_URL`** (bạn chỉ cần gọi `fetch('/api/health')` là ứng dụng sẽ chạy).

**Thử thách:** Cấu hình lại hệ thống từ Phần 2 sao cho frontend gọi trực tiếp URL tương đối `/api/health`, và thiết lập CloudFront định tuyến mọi request `/api/*` tới ALB của bạn. Cuối cùng, xóa hoàn toàn file "chữa cháy" `config.js` chứa IP.
