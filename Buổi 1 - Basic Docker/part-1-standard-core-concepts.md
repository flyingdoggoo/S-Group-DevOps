# Part 1 Standard - Core Concepts

> Mục tiêu: sau phần này bạn hiểu container là gì, Docker giải quyết vấn đề gì, image/container/registry khác nhau thế nào, và tư duy production cơ bản khi đóng gói ứng dụng.

## 1. Bức tranh lớn: ứng dụng thật sự chạy ở đâu?

Khi bạn viết một backend app, code không tự chạy một mình. Nó cần một **runtime environment**:

- Hệ điều hành và kernel.
- Runtime như Node.js, Java, Python, Go binary runtime.
- Thư viện hệ thống như `openssl`, `libc`, `ca-certificates`.
- Dependency của app như `express`, `pg`, `redis`.
- Biến môi trường như `PORT`, `DATABASE_URL`, `JWT_SECRET`.
- File cấu hình, certificate, thư mục upload, log.
- Network để gọi database, cache, service khác.

Câu "works on my machine" xảy ra vì môi trường local và server khác nhau. Ví dụ local của bạn dùng Node 24, server đang có Node 20; local có `.env`, server thiếu biến môi trường; local chạy Windows, production chạy Linux; local database mở port, production database nằm trong private network.

Docker giúp chuẩn hóa phần lớn môi trường đó bằng cách đóng gói app và dependency vào một **image**. Khi chạy image, Docker tạo ra một **container**.

## 2. Mental model cho người mới

Hãy nhớ chuỗi này:

```text
Dockerfile -> docker build -> Image -> docker run -> Container
```

Trong đó:

| Khái niệm | Hiểu đơn giản | Ví dụ |
|---|---|---|
| `Dockerfile` | Công thức build image | "Dùng Node, copy code, npm install, chạy app" |
| `Image` | Bản đóng gói read-only | `my-app:1.0.0` |
| `Container` | Một process đang chạy từ image | Container `api-1` đang nghe port 3000 |
| `Registry` | Kho chứa image | Docker Hub, GHCR, ECR, GCR |
| `Volume` | Nơi lưu dữ liệu bền vững | Data PostgreSQL |
| `Network` | Mạng riêng để container gọi nhau | `app` gọi `db:5432` |

Một image giống như file cài đặt đã đóng gói. Container giống như một lần chạy cụ thể của file đó. Bạn có thể chạy nhiều container từ cùng một image.

## 3. Container không phải Virtual Machine

### Virtual Machine

VM mô phỏng cả một máy tính:

- Có kernel riêng.
- Có hệ điều hành đầy đủ.
- Cách ly mạnh.
- Nặng hơn, boot chậm hơn, tốn RAM/disk hơn.

### Container

Container không mô phỏng cả máy tính:

- Dùng chung kernel với host.
- Đóng gói app và userspace dependency.
- Nhẹ hơn, start nhanh hơn.
- Cách ly bằng cơ chế của Linux như namespaces và cgroups.

```text
Virtual Machine:
App -> Guest OS -> Hypervisor -> Host OS/Hardware

Container:
App -> Container userspace -> Docker Engine -> Host kernel/Hardware
```

Điểm quan trọng: container chia sẻ kernel với host. Vì vậy container Linux cần Linux kernel. Docker Desktop trên Windows/macOS thường chạy một Linux VM nhỏ phía sau để cung cấp Linux kernel.

## 4. Docker dùng những cơ chế nào?

Bạn không cần thuộc sâu từ ngày đầu, nhưng nên biết ý nghĩa:

| Cơ chế | Vai trò |
|---|---|
| Namespaces | Cô lập process, network, mount, hostname, user... |
| Cgroups | Giới hạn CPU, RAM, IO cho container |
| Union filesystem | Xếp nhiều layer thành một filesystem cho image |
| Image layers | Mỗi lệnh build tạo layer có thể cache |
| Registry protocol | Push/pull image giữa máy dev, CI và server |

Vì vậy container không phải "máy ảo nhỏ". Nó là một process trên host, nhưng được cô lập để có filesystem, network và tài nguyên riêng.

## 5. Image, layer, tag, digest

### Image

Image là gói read-only. Nó chứa:

- Base filesystem từ image nền, ví dụ `node:24-alpine`.
- File app.
- Dependency.
- Metadata như `CMD`, `ENV`, `EXPOSE`, `WORKDIR`.

### Layer

Mỗi instruction trong Dockerfile thường tạo layer:

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY dist ./dist
CMD ["node", "dist/index.js"]
```

Nếu `package-lock.json` không đổi, Docker có thể tái sử dụng layer `npm ci`. Đây là lý do người ta copy file dependency trước, copy source code sau.

### Tag

Tag là tên dễ đọc:

```bash
my-app:latest
my-app:1.0.0
my-app:2026-05-21-abc123
```

`latest` không có nghĩa là mới nhất theo thời gian. Nó chỉ là một tag tên `latest`. Trong production, không nên triển khai bằng `latest` vì khó biết chính xác version nào đang chạy.

### Digest

Digest là định danh bất biến của image:

```text
my-app@sha256:...
```

Trong production nghiêm túc, tag dùng cho con người đọc, digest dùng để đảm bảo đúng artifact được deploy.

## 6. Container lifecycle

Một container có vòng đời:

```text
created -> running -> exited -> removed
```

Các lệnh hay dùng:

```bash
# Chạy container foreground
docker run -p 3000:3000 my-app:1.0.0

# Chạy background
docker run -d --name my-api -p 3000:3000 my-app:1.0.0

# Xem container đang chạy
docker ps

# Xem cả container đã dừng
docker ps -a

# Xem log
docker logs -f my-api

# Vào shell trong container
docker exec -it my-api sh

# Dừng và xóa
docker rm -f my-api
```

Container nên được xem là **ephemeral**: có thể xóa và tạo lại bất cứ lúc nào. Dữ liệu quan trọng không được chỉ nằm trong filesystem tạm của container.

## 7. Port mapping và network

App trong container có thể nghe port `3000`, nhưng máy host chưa truy cập được nếu bạn không publish port.

```bash
docker run -p 8080:3000 my-app:1.0.0
```

Ý nghĩa:

```text
host port 8080 -> container port 3000
```

Truy cập từ máy bạn:

```bash
curl http://localhost:8080
```

Trong Docker Compose, service gọi nhau bằng tên service:

```text
app -> db:5432
app -> redis:6379
```

Không dùng `localhost` để app container gọi database container. `localhost` bên trong container là chính container đó, không phải máy host và không phải container khác.

## 8. Volume và dữ liệu bền vững

Filesystem của container sẽ mất khi container bị xóa. Nếu chạy database trong container, phải dùng volume:

```bash
docker volume create pg_data
docker run -v pg_data:/var/lib/postgresql/data postgres:18
```

Trong Compose:

```yaml
services:
  db:
    image: postgres:18
    volumes:
      - pg_data:/var/lib/postgresql/data

volumes:
  pg_data:
```

Volume không phải backup. Volume chỉ giúp dữ liệu sống qua vòng đời container. Production vẫn cần backup riêng, restore test, retention policy và quyền truy cập rõ ràng.

## 9. Biến môi trường và config

Container thường nhận config qua environment variables:

```bash
docker run \
  -e NODE_ENV=production \
  -e PORT=3000 \
  -e DATABASE_URL=postgres://user:pass@db:5432/mydb \
  my-app:1.0.0
```

Config nên thay đổi theo môi trường; image thì không. Nghĩa là cùng một image có thể chạy ở staging và production, khác nhau ở env vars, secrets, network và tài nguyên.

Không nên bake secret vào image:

```dockerfile
# Sai
ENV JWT_SECRET=super-secret
```

Vì secret sẽ nằm trong image history hoặc metadata, rất khó kiểm soát.

## 10. Dockerfile cơ bản

Ví dụ backend Node.js:

```dockerfile
FROM node:24-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY dist ./dist

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/index.js"]
```

Giải thích:

| Dòng | Ý nghĩa |
|---|---|
| `FROM` | Chọn image nền |
| `WORKDIR` | Thư mục làm việc trong container |
| `COPY` | Copy file từ build context vào image |
| `RUN` | Chạy lệnh lúc build image |
| `ENV` | Đặt biến môi trường mặc định |
| `EXPOSE` | Tài liệu hóa port app nghe trong container |
| `CMD` | Lệnh mặc định khi container start |

`EXPOSE` không tự mở port ra máy host. Bạn vẫn cần `-p` hoặc config reverse proxy/orchestrator.

## 11. Docker Compose dùng để làm gì?

Khi app cần database, Redis, worker, reverse proxy, chạy từng container bằng `docker run` rất khó quản lý. Compose gom thành một file:

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://user:password@db:5432/mydb
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
```

Chạy:

```bash
docker compose up --build
docker compose down
```

Compose rất tốt cho local dev, demo, lab, CI nhỏ, hoặc production đơn giản trên một VPS. Với production lớn, bạn thường dùng orchestrator như Kubernetes, ECS, Nomad, Docker Swarm hoặc platform managed.

## 12. Sai lầm cần tránh

### Nhầm image và container

Sai: "Tôi đã xóa container nên mất image."

Đúng: container là instance chạy từ image. Xóa container không xóa image.

### Dùng `localhost` sai chỗ

Sai trong container:

```text
DATABASE_URL=postgres://user:pass@localhost:5432/mydb
```

Nếu database là service Compose tên `db`, dùng:

```text
DATABASE_URL=postgres://user:pass@db:5432/mydb
```

### Lưu dữ liệu quan trọng trong container

Sai:

```text
/app/uploads nằm trong container, không mount volume hoặc object storage
```

Khi container bị recreate, dữ liệu có thể mất.

### Dùng `latest` cho production

Sai:

```yaml
image: my-company/my-app:latest
```

Nên dùng tag version rõ:

```yaml
image: my-company/my-app:2026-05-21-commit-a1b2c3d
```

### Đưa secret vào Dockerfile

Sai:

```dockerfile
ENV DATABASE_PASSWORD=real-password
```

Secret phải đến từ secret manager, Docker secrets, CI/CD secrets, Kubernetes Secret, cloud secret manager, hoặc file runtime được bảo vệ.

### Chạy nhiều process không liên quan trong một container

Thường không nên nhét app, database, nginx vào cùng một container. Mỗi container nên có một trách nhiệm chính. Dùng Compose/orchestrator để ghép nhiều service.

## 13. Production thật triển khai như thế nào?

Một flow production phổ biến:

```text
Developer push code
-> CI chạy test
-> CI build Docker image
-> CI scan image
-> CI push image lên registry
-> CD deploy image tag/digest đến server/orchestrator
-> Orchestrator rolling update
-> Health check pass
-> Traffic chuyển sang version mới
```

Các nguyên tắc production:

| Nguyên tắc | Lý do |
|---|---|
| Build once, deploy many | Cùng một image đi qua dev/staging/prod để tránh lệch artifact |
| Immutable image | Không SSH vào container để sửa tay |
| Log ra stdout/stderr | Platform thu log tập trung |
| Config qua env/secrets | Không rebuild image chỉ để đổi config |
| Không dùng `latest` | Rollback và audit dễ hơn |
| Health check rõ ràng | Orchestrator biết container có thật sự sẵn sàng không |
| Resource limits | Tránh một service ăn hết CPU/RAM |
| Non-root user | Giảm tác hại nếu app bị khai thác |
| Image nhỏ | Ít attack surface, pull nhanh hơn |
| Backup dữ liệu | Volume không thay thế backup |

### Ví dụ production nhỏ trên VPS

Với dự án nhỏ, bạn có thể:

1. CI build và push image lên registry.
2. VPS pull image mới.
3. `docker compose up -d` với file production.
4. Nginx/Caddy/Traefik nhận HTTPS ở port 443 và proxy vào app.
5. Database có volume riêng hoặc dùng managed database.
6. Secret nằm trong file được phân quyền chặt hoặc secret manager.

Ví dụ `compose.prod.yaml` tối giản:

```yaml
services:
  app:
    image: ghcr.io/example/my-app:2026-05-21-a1b2c3d
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 3000
    env_file:
      - .env.production
    expose:
      - "3000"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  reverse-proxy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      app:
        condition: service_healthy

volumes:
  caddy_data:
  caddy_config:
```

Với hệ thống lớn, Compose thường không đủ. Bạn cần orchestrator để có rolling update, autoscaling, service discovery, secret management, scheduling, node failure handling và policy kiểm soát.

## 14. Checklist tự kiểm tra

Bạn nên trả lời được:

- Image khác container thế nào?
- Vì sao container không phải VM?
- Vì sao không dùng `localhost` để gọi database service khác trong Compose?
- Vì sao database cần volume?
- `EXPOSE` có mở port ra host không?
- Vì sao không dùng `latest` trong production?
- Vì sao secret không được viết vào Dockerfile?
- Production flow từ code đến deploy image gồm những bước nào?

## 15. Nguồn tham khảo chính thức

- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker build best practices: https://docs.docker.com/build/building/best-practices/
- Docker Compose services reference: https://docs.docker.com/reference/compose-file/services/

