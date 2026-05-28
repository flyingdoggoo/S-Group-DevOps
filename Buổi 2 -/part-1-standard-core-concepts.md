# Part 1 - Standard: Core Concepts

## 1.1 Cloud là gì?

Trong Session 1, chúng ta chạy app trên laptop cá nhân. Cách này phù hợp để học và phát triển local, nhưng không phù hợp để phục vụ người dùng thật trên internet vì:

- Laptop có thể tắt máy vào ban đêm.
- IP thường thay đổi (dynamic IP).
- Không được thiết kế để chạy tải ổn định 24/7.

## Định nghĩa ngắn gọn

**Cloud computing** là mô hình thuê tài nguyên máy tính (server, storage, network) qua internet, dùng khi nào trả tiền khi đó (*on-demand* và *pay-as-you-go*).

## So sánh nhanh On-Premise và Cloud

| Tiêu chí | Traditional (On-Premise) | Cloud |
|---|---|---|
| Phần cứng | Tự mua, tự bảo trì | Nhà cung cấp sở hữu |
| Thời gian setup | Hàng tuần (mua -> rack -> cài) | Vài giây/phút (qua API/Console) |
| Mở rộng | Mua thêm máy | Bấm nút hoặc đổi cấu hình |
| Chi phí | CapEx (đầu tư lớn ban đầu) | OpEx (trả theo mức dùng) |
| Rủi ro hạ tầng | Tự chịu khi lỗi phần cứng | Provider chịu phần lớn phần hạ tầng |

Nhà cung cấp phổ biến: **AWS**, **Google Cloud (GCP)**, **Microsoft Azure**.  
Trong khoá học này dùng AWS vì thị phần lớn và Free Tier khá tốt cho người mới.

## Góc nhìn cho người mới

- Cloud không có nghĩa là “không có server”, mà là **server của người khác nhưng bạn thuê để dùng**.
- Thay vì tự mua máy vật lý, bạn tạo máy ảo nhanh chóng bằng vài thao tác.
- Khi học, mục tiêu chính là hiểu dòng chảy: **Internet -> Cloud VM -> App**.

## Kết luận ngắn

Cloud giúp bạn triển khai nhanh, linh hoạt, giảm rào cản vận hành ban đầu và phù hợp với workflow DevOps hiện đại.

---

## 1.2 IaaS là gì?

Các dịch vụ cloud thường chia làm 3 lớp dựa trên mức độ nhà cung cấp quản lý giúp bạn:

```text
┌────────────────────────────────────────────────┐
│ SaaS  (Software as a Service)                  │  Gmail, Notion, Figma
│       -> Bạn chỉ sử dụng ứng dụng              │
├────────────────────────────────────────────────┤
│ PaaS  (Platform as a Service)                  │  Vercel, Railway, Heroku
│       -> Bạn đẩy code, provider chạy           │
├────────────────────────────────────────────────┤
│ IaaS  (Infrastructure as a Service)            │  AWS EC2, GCP Compute
│       -> Bạn có VM thô, tự quản lý gần như hết │
└────────────────────────────────────────────────┘
```

## Định nghĩa IaaS

**IaaS** cung cấp máy ảo mức thấp nhất để bạn SSH vào như một Linux server bình thường:

- Tự cài package hệ điều hành.
- Tự cài runtime (Node.js, Java, Python...).
- Tự cấu hình mạng và firewall.

## Ưu và nhược điểm

- **Ưu điểm:** kiểm soát cao, chạy được nhiều kiểu workload, chi phí dễ dự đoán.
- **Nhược điểm:** tự chịu trách nhiệm patch bảo mật, monitoring, scaling, backup.

## Gợi ý tư duy

- Nếu bạn muốn học gốc rễ hệ thống: bắt đầu từ IaaS là rất tốt.
- Nếu bạn muốn đi nhanh để ship app: thường dùng PaaS.
- Trong thực tế, đội ngũ kỹ thuật hay kết hợp cả hai.

Trong lộ trình này:
- Session hiện tại tập trung IaaS (EC2 VM).
- PaaS sẽ học ở Session 4.

**Nhớ câu này:** `IaaS = một máy ảo trên cloud mà bạn tự vận hành`.

---

## 1.3 VM hoạt động như thế nào?

## VM là gì?

**Virtual Machine (VM)** là một máy tính ảo chạy trên máy chủ vật lý thật.  
Máy chủ vật lý dùng **hypervisor** để chia CPU, RAM, disk, network thành nhiều VM cách ly nhau.

```text
┌─────────────────────────────────────────────────┐
│              Physical Server                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  VM 1    │  │  VM 2    │  │  VM 3    │      │
│  │ Ubuntu   │  │ Amazon   │  │ Windows  │      │
│  │ 22.04    │  │ Linux    │  │ Server   │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│             Hypervisor (KVM, Xen)               │
│             Host OS                             │
│             CPU / RAM / Disk / NIC              │
└─────────────────────────────────────────────────┘
```

Trên AWS, VM được gọi là **EC2 instance** (*Elastic Compute Cloud*).

## Thành phần cơ bản của một EC2 instance

| Thuộc tính | Ví dụ | Ý nghĩa |
|---|---|---|
| **Instance type** | `t3.micro` | Cấu hình tài nguyên (vCPU, RAM) |
| **AMI** | Ubuntu 24.04 | Mẫu hệ điều hành để khởi tạo máy |
| **Storage (EBS)** | 8 GB SSD | Ổ đĩa ảo gắn vào máy |
| **Public IP** | `54.x.x.x` | Địa chỉ internet để truy cập từ ngoài |
| **Key pair** | `training-key.pem` | Khóa SSH để đăng nhập |
| **Security Group** | Rule cho 22/80/443 | Firewall mức instance |

## So sánh nhanh VM và Container

- **VM:** mô phỏng cả máy tính, có kernel riêng.
- **Container:** chia sẻ kernel host, nhẹ hơn, khởi động nhanh hơn.

Mô hình phổ biến production:
- Chạy nhiều container bên trong một VM.
- VM lo cách ly ở mức hạ tầng.
- Container lo cách ly giữa các app/service.

## Góc nhìn cho người mới

- Đừng nghĩ VM và container là “đối thủ”. Chúng thường **đi cùng nhau**.
- VM là “nền nhà”, container là “các phòng” trong nhà.

---

## 1.4 Networking cơ bản (IP, Port, Firewall)

Trước khi deploy, bạn cần một mô hình tư duy tối thiểu để hiểu traffic đi từ internet vào app như thế nào.

## IP address

**IP** là địa chỉ của máy trong mạng.

- **Public IP:** truy cập được từ internet (ví dụ `54.169.23.10`).
- **Private IP:** chỉ dùng trong mạng nội bộ cloud (ví dụ `172.31.0.5`).

## Port

Một máy có thể chạy nhiều dịch vụ.  
**Port** là “cổng” để phân biệt dịch vụ trên cùng một IP.

| Port | Dịch vụ thường gặp |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 3000 | App Node.js (Session 1) |
| 5432 | Postgres |
| 6379 | Redis |

Ví dụ địa chỉ đầy đủ: `54.169.23.10:3000` nghĩa là truy cập cổng 3000 trên máy đó.

## Security Group (Firewall của EC2)

Mặc định EC2 chặn toàn bộ kết nối vào. Bạn phải mở từng cổng cần thiết:

- Port `22` chỉ cho **IP của bạn** (để SSH).
- Port `80` và `443` cho `0.0.0.0/0` (để user internet truy cập web).

```text
Internet -> [Security Group: allow 80, 443] -> EC2 instance -> Docker -> app
                 ^
                 └-- allow 22 only from your laptop IP
```

## Quy tắc an toàn quan trọng

- Không mở SSH `22` cho `0.0.0.0/0`.
- Chỉ mở cổng nào thật sự cần dùng.
- Cổng test (ví dụ `3000`) nên mở tạm và khóa lại sau khi xong.

> Bot quét internet tìm cổng SSH mở công khai diễn ra liên tục mỗi ngày.

## Checklist nhanh cho người mới

- Tôi có biết service chạy ở port nào chưa?
- Port đó có thật sự cần public không?
- Rule Security Group có tối thiểu quyền chưa (*least privilege*)?

