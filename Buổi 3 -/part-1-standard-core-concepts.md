# Phần 1 — Tiêu chuẩn: Các khái niệm cốt lõi (Core Concepts)

## 1.1 Nội dung tĩnh (Static Content) vs Nội dung động (Dynamic Content)

Cho đến nay chúng ta mới chỉ triển khai một thứ: một backend chạy mã (code) trên mỗi request. Nhưng một ứng dụng thực tế có hai loại nội dung rất khác nhau, và việc xử lý chúng giống nhau sẽ gây lãng phí.

**Nội dung tĩnh (Static content)** — các file giống nhau đối với mọi người dùng và không thay đổi theo từng request:
- HTML, CSS, JavaScript bundles
- Hình ảnh, font chữ, icon
- Đầu ra đã được biên dịch (compiled) của một ứng dụng React / Vue / Angular

**Nội dung động (Dynamic content)** — được tạo ra cho từng request, thường là cho từng người dùng:
- Phản hồi API (`/api/orders` cho người dùng *đang đăng nhập* này)
- Bất cứ thứ gì đọc/ghi cơ sở dữ liệu (Database)
- Bất cứ thứ gì chạy logic nghiệp vụ (business logic) của bạn

| | Tĩnh (Static) | Động (Dynamic) |
|---|---|---|
| Giống nhau cho mọi người dùng? | Có | Không |
| Cần một server đang chạy? | Không — chỉ cần một file server | Có — cần chạy code |
| Cách scale (Mở rộng) | Copy file tới nhiều edge server (CDN) | Chạy thêm các container |
| Chi phí | Vài xu (lưu trữ + băng thông) | Vài đô la (thời gian tính toán) |
| Ví dụ | `index.html`, `app.js` | `GET /health`, `POST /login` |

**Nhận định cốt lõi:** bạn nên phục vụ các file tĩnh từ một bộ nhớ lưu trữ giá rẻ, có khả năng mở rộng vô hạn, và dành riêng phần tính toán (compute) đắt tiền cho các phần nội dung động. Việc đặt bản build React của bạn sau một Node server giống như thuê một đầu bếp chỉ để phát những chiếc bánh mì sandwich đã đóng gói sẵn.

---

## 1.2 Kiến trúc Hệ thống Cơ bản (Basic System Architecture)

Sự phân tách này mang lại cho chúng ta kiến trúc web hai tầng (two-tier) cổ điển:

```text
                    ┌─────────────────────────────┐
   Trình duyệt ────►│ Hosting Tĩnh (S3)           │  index.html, app.js, css
      │             │ → chỉ phục vụ các file      │
      │             └─────────────────────────────┘
      │
      │  fetch('/api/...')
      │             ┌─────────────────────────────┐
      └────────────►│ Máy tính toán (ECS container)│  chạy code backend của bạn
                    │ → chạy code, giao tiếp DB   │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                            ┌────────────┐
                            │ Cơ sở dữ liệu│
                            └────────────┘
```

- **Frontend → Hosting tĩnh:** trình duyệt tải HTML/JS/CSS một lần từ kho lưu trữ object (object storage).
- **Backend → Tính toán (Compute):** JS sau khi tải về sẽ gọi API của bạn để lấy dữ liệu động.

Hai thành phần này hoàn toàn **độc lập (decoupled)** — bạn có thể deploy lại frontend mà không cần đụng đến backend, mở rộng chúng một cách độc lập, và thậm chí đặt chúng trên các domain khác nhau (hoặc cùng domain với path routing, sẽ học ở phần Nâng cao).

---

## 1.3 Object Storage (S3)

**Amazon S3 (Simple Storage Service)** là object storage: bạn lưu trữ các **object** (file + siêu dữ liệu - metadata) bên trong các **bucket** (các container cấp cao nhất với tên duy nhất trên toàn cầu). Nó không phải là một hệ thống file (filesystem) và cũng không phải là một ổ đĩa cứng — không có các thư mục (những "thư mục" bạn thấy thực chất chỉ là các tiền tố key) và bạn không thể chạy code ở đó.

| Khái niệm | Ý nghĩa |
|---|---|
| **Bucket** | Một namespace (không gian tên) cho các object của bạn. Tên bucket là duy nhất trên toàn bộ hệ thống AWS. |
| **Object** | Một file cộng với siêu dữ liệu (metadata), được định danh bởi một **key** (VD: `assets/app.js`). |
| **Key** | Tên đầy đủ giống-như-đường-dẫn của một object trong bucket. |
| **Region** | Khu vực địa lý vật lý nơi bucket tồn tại (ảnh hưởng đến độ trễ + tuân thủ quy định). |

**Tại sao dùng S3 cho frontend?**
- **Độ bền dữ liệu:** 99.999999999% ("11 số 9") — AWS tự động sao chép các object của bạn trên nhiều phần cứng.
- **Khả năng mở rộng:** phục vụ 1 request hay 1 tỷ request mà không cần quản lý bất kỳ server nào.
- **Chi phí:** khoảng $0.023/GB/tháng cho lưu trữ. Một frontend bundle thường chỉ vài MB.
- **Hosting website tĩnh:** S3 có thể phục vụ trực tiếp một bucket qua giao thức HTTP như một website.

> **Mô hình tư duy:** S3 là một ổ cứng lớn vô hạn, bền bỉ vô hạn mà bạn giao tiếp qua giao thức HTTP thay vì qua cáp SATA.

---

## 1.4 Điều phối Container (Container Orchestration - ECS)

Trong Session 2, chúng ta đã chạy container thủ công: SSH vào một VM, chạy `docker compose up`. Cách này ổn cho một server. Nhưng điều gì sẽ xảy ra khi container bị crash lúc 3 giờ sáng? Khi bạn cần ba bản sao để chịu tải? Khi bạn muốn deploy mà không có downtime? Bạn sẽ phải SSH vào server để trông chừng nó mãi mãi.

**Điều phối Container (Container orchestration)** tự động hóa vòng đời của các container: lên lịch chạy chúng trên các máy tính, khởi động lại khi chúng chết, tăng giảm số lượng, và rollout các phiên bản mới.

**Amazon ECS (Elastic Container Service)** là trình điều phối của AWS. Các thuật ngữ:

| Thuật ngữ | Ý nghĩa | Sự tương đồng |
|---|---|---|
| **Task Definition** | Một bản thiết kế: dùng image nào, bao nhiêu CPU/RAM, port, biến môi trường | Giống như một lệnh `docker run` / `compose.yaml` cho một ứng dụng |
| **Task** | Một phiên bản đang chạy của một task definition (1+ containers) | Một container đang chạy |
| **Service** | Giữ cho N task luôn chạy, khởi động lại khi lỗi, thực hiện rolling deploy | Giống `restart: unless-stopped` + load balancer |
| **Cluster** | Một nhóm logic các task/service | "Môi trường" nơi chúng chạy |

**Các loại Launch type — ai quản lý server?**

```text
┌──────────────────────────────────────────────────────────┐
│ ECS on EC2    → bạn quản lý các VM bên dưới               │
│                 (kiểm soát nhiều hơn, bạn tự vá lỗi host) │
├──────────────────────────────────────────────────────────┤
│ ECS on Fargate→ AWS quản lý VM, bạn chỉ cần đưa ra task   │
│                 (container serverless — không cần quản lý host)│
└──────────────────────────────────────────────────────────┘
```

Chúng ta sẽ sử dụng **Fargate** cho lần deploy "rút gọn" này: bạn cung cấp cho ECS một image và kích thước CPU/RAM, nó sẽ chạy container mà bạn không cần phải đụng vào một server nào. Để chạy bất kỳ image nào, ECS trước tiên cần nó nằm trong một registry — đó chính là **Amazon ECR (Elastic Container Registry)**, tương tự như Docker Hub riêng tư của AWS.

```text
image ở máy local ──► docker push ──► ECR (registry) ──► ECS Fargate pull + chạy nó
```
