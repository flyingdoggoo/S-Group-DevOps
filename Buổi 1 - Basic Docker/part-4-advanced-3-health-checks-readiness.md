# Part 4 Advanced 3 - Health Checks và Container Orchestration Readiness

> Mục tiêu: hiểu health check không chỉ là "container đang chạy", biết phân biệt liveness/readiness/startup, viết health endpoint tốt, cấu hình Dockerfile/Compose healthcheck, và hiểu production orchestrator dùng health signal để deploy an toàn.

## 1. Vấn đề: process chạy chưa chắc app khỏe

Một container có thể ở trạng thái `running`, nhưng app bên trong vẫn không phục vụ request được.

Ví dụ:

- Node process vẫn sống nhưng event loop bị nghẽn.
- App đang boot và chưa mở port.
- App mở port nhưng chưa connect được database.
- Migration đang chạy.
- App bị deadlock.
- Thread pool hết tài nguyên.
- Dependency như Redis/PostgreSQL restart.
- App trả toàn lỗi 500 nhưng process chưa crash.

Vì vậy production cần health checks.

```text
running process != ready to serve traffic
```

## 2. Health check là gì?

Health check là một lệnh hoặc HTTP request chạy định kỳ để trả lời câu hỏi:

```text
Container/service này còn hoạt động đúng không?
```

Docker hỗ trợ `HEALTHCHECK` trong Dockerfile. Docker Compose hỗ trợ `healthcheck` trong service. Orchestrator như Kubernetes/ECS cũng có health check riêng.

Docker container có thể có health status:

```text
starting -> healthy -> unhealthy
```

Exit code của health command:

| Exit code | Ý nghĩa |
|---|---|
| `0` | Healthy |
| `1` | Unhealthy |
| `2` | Reserved, không nên dùng |

## 3. Liveness, readiness, startup

Đây là ba khái niệm production quan trọng.

### Liveness

Câu hỏi:

```text
Process còn sống và có nên restart không?
```

Nếu liveness fail, orchestrator thường restart container.

Liveness không nên phụ thuộc mạnh vào database/cache bên ngoài. Nếu database down tạm thời mà bạn restart toàn bộ app liên tục, sự cố có thể nặng hơn.

### Readiness

Câu hỏi:

```text
App đã sẵn sàng nhận traffic chưa?
```

Nếu readiness fail, orchestrator không route traffic đến instance đó, nhưng không nhất thiết restart container.

Readiness có thể kiểm tra:

- HTTP server đã sẵn sàng.
- Config cần thiết hợp lệ.
- Database connection pool đã init.
- Migration bắt buộc đã xong.
- App không ở trạng thái draining/shutdown.

### Startup

Câu hỏi:

```text
App có đang trong giai đoạn khởi động lâu hợp lệ không?
```

Startup probe giúp app có thời gian boot mà không bị liveness kill quá sớm.

Trong Dockerfile/Compose không có đủ ba loại như Kubernetes, nhưng bạn có thể mô phỏng phần nào bằng `start_period`, `start_interval`, `retries`.

## 4. Thiết kế endpoint `/health`, `/live`, `/ready`

Với app nhỏ, một endpoint `/health` là đủ để học:

```http
GET /health -> 200 {"status":"ok"}
```

Với production tốt hơn:

| Endpoint | Mục đích | Có nên check DB không? |
|---|---|---|
| `/live` | Process sống, event loop trả lời được | Thường không |
| `/ready` | App sẵn sàng nhận traffic | Có thể, tùy yêu cầu |
| `/health` | Endpoint tổng hợp hoặc alias | Tùy hệ thống |

Ví dụ:

```ts
app.get('/live', (_req, res) => {
  res.json({ status: 'alive' });
});

app.get('/ready', async (_req, res) => {
  const ready = isAppReady();

  if (!ready) {
    res.status(503).json({ status: 'not_ready' });
    return;
  }

  res.json({ status: 'ready' });
});
```

Nguyên tắc:

- Health endpoint phải nhanh.
- Không cần auth nếu chỉ dùng nội bộ, nhưng không nên expose quá nhiều thông tin.
- Không trả secret, connection string, stack trace.
- Trả `200` khi pass, `503` khi fail.
- Timeout ngắn.

## 5. Healthcheck trong Dockerfile

Ví dụ dùng Node built-in `fetch`, tránh phụ thuộc `curl`/`wget` trong image:

```dockerfile
FROM node:24-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY dist ./dist

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/index.js"]
```

Các option:

| Option | Ý nghĩa |
|---|---|
| `--interval` | Bao lâu chạy check một lần |
| `--timeout` | Một lần check được chạy tối đa bao lâu |
| `--start-period` | Thời gian grace period lúc container mới start |
| `--start-interval` | Tần suất check trong start period, cần Docker Engine mới |
| `--retries` | Số lần fail liên tiếp trước khi unhealthy |

Dockerfile chỉ có một `HEALTHCHECK` có hiệu lực. Nếu khai báo nhiều, cái cuối cùng thắng.

## 6. Healthcheck trong Compose

Compose có thể khai báo hoặc override healthcheck:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.multistage
      target: production
    ports:
      - "3000:3000"
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
        ]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

Nếu image có `wget`:

```yaml
healthcheck:
  test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s
```

Nếu image có `curl`:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:3000/health || exit 1"]
```

`CMD` không chạy qua shell. `CMD-SHELL` chạy qua shell, nên dùng được `||`, biến shell và pipe.

## 7. `depends_on` với `service_healthy`

Compose không đợi service "ready" theo nghĩa ứng dụng. Mặc định nó chỉ tạo/start theo thứ tự dependency. Để đợi dependency healthy:

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
      redis:
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
      start_period: 10s

  redis:
    image: redis:8-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
```

Điểm quan trọng: `depends_on` chỉ giúp lúc startup. App vẫn cần retry/backoff khi DB restart sau đó.

## 8. App healthcheck sau Nginx reverse proxy

Nếu có Nginx ở trước:

```text
host -> nginx -> app
```

Bạn nên có hai loại check:

- Nginx check app nội bộ bằng Docker network.
- App tự check chính nó.

Compose:

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      app:
        condition: service_healthy

  app:
    build:
      context: .
      dockerfile: Dockerfile.multistage
      target: production
    expose:
      - "3000"
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
        ]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

Kiểm tra từ host:

```bash
curl http://localhost/health
```

Kiểm tra health status container:

```bash
docker compose ps
docker inspect --format='{{json .State.Health}}' <container_name>
```

Nếu có `jq`:

```bash
docker inspect --format='{{json .State.Health}}' <container_name> | jq
```

## 9. Health endpoint mẫu cho Node/Express

Ví dụ đơn giản:

```ts
import express from 'express';

const app = express();
const PORT = Number(process.env.PORT ?? 3000);
let shuttingDown = false;

process.on('SIGTERM', () => {
  shuttingDown = true;
  setTimeout(() => process.exit(0), 10_000);
});

app.get('/live', (_req, res) => {
  res.json({ status: 'alive' });
});

app.get('/ready', (_req, res) => {
  if (shuttingDown) {
    res.status(503).json({ status: 'shutting_down' });
    return;
  }

  res.json({ status: 'ready' });
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', env: process.env.NODE_ENV ?? null });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
```

Vì sao `shuttingDown` hữu ích?

Khi orchestrator gửi `SIGTERM`, app có thể trả readiness fail để ngừng nhận traffic mới, xử lý nốt request đang chạy, rồi exit.

## 10. Graceful shutdown

Health check chỉ là một nửa. Production còn cần shutdown tử tế.

Luồng tốt:

```text
orchestrator muốn stop instance
-> gửi SIGTERM
-> app đánh dấu not ready
-> load balancer ngừng route request mới
-> app xử lý xong request đang chạy
-> đóng server/db connection
-> process exit 0
```

Node.js ví dụ:

```ts
const server = app.listen(PORT, '0.0.0.0');

process.on('SIGTERM', () => {
  shuttingDown = true;

  server.close(() => {
    process.exit(0);
  });

  setTimeout(() => {
    process.exit(1);
  }, 30_000);
});
```

Trong Dockerfile, dùng exec form để signal truyền đúng:

```dockerfile
CMD ["node", "dist/index.js"]
```

Tránh:

```dockerfile
CMD node dist/index.js
```

Shell form có thể làm signal handling khó đoán hơn.

## 11. Healthcheck không nên làm gì?

### Không chạy query nặng

Sai:

```text
/health chạy SELECT phức tạp trên bảng lớn
```

Health check chạy liên tục. Query nặng có thể tự gây tải.

### Không gọi quá nhiều dependency

Nếu `/health` gọi database, Redis, payment gateway, email provider, object storage, search engine, thì một dependency nhỏ lỗi có thể làm toàn bộ app bị restart hoặc rút khỏi load balancer.

Tách:

- `/live`: nhẹ, local.
- `/ready`: dependency bắt buộc để nhận traffic.
- `/diagnostics`: sâu hơn, có auth, không dùng làm liveness.

### Không trả thông tin nhạy cảm

Sai:

```json
{
  "databaseUrl": "postgres://user:password@db:5432/mydb",
  "jwtSecret": "..."
}
```

Đúng:

```json
{
  "status": "ready",
  "checks": {
    "database": "ok"
  }
}
```

### Không đặt timeout quá dài

Nếu timeout 30s và interval 30s, signal unhealthy có thể đến rất chậm. Production thường cần timeout ngắn và endpoint nhẹ.

## 12. Docker healthcheck và orchestrator healthcheck khác nhau

Dockerfile `HEALTHCHECK`:

- Chạy bên trong container.
- Docker Engine biết status healthy/unhealthy.
- Compose có thể dùng `depends_on.condition: service_healthy`.

Kubernetes probes:

- `livenessProbe`: restart container khi fail.
- `readinessProbe`: bỏ pod khỏi service endpoints khi fail.
- `startupProbe`: bảo vệ app boot lâu.

AWS ECS:

- Container health check trong task definition.
- Load balancer target group health check.
- Service deployment circuit breaker tùy config.

Không phải platform nào cũng dùng Dockerfile `HEALTHCHECK`. Nhiều orchestrator có cơ chế probe riêng và có thể bỏ qua healthcheck trong image. Vì vậy production config nên rõ ở platform đang dùng.

## 13. Kubernetes ví dụ

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: ghcr.io/example/my-app:a1b2c3d
          ports:
            - containerPort: 3000
          startupProbe:
            httpGet:
              path: /live
              port: 3000
            failureThreshold: 30
            periodSeconds: 2
          livenessProbe:
            httpGet:
              path: /live
              port: 3000
            periodSeconds: 30
            timeoutSeconds: 3
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 3000
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
```

Ý nghĩa:

- Startup probe cho app tối đa khoảng 60s để boot.
- Liveness dùng `/live`, nhẹ.
- Readiness dùng `/ready`, quyết định route traffic.

## 14. Compose production nhỏ trên VPS

```yaml
services:
  app:
    image: ghcr.io/example/my-app:a1b2c3d
    restart: unless-stopped
    env_file:
      - .env.production
    expose:
      - "3000"
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "fetch('http://localhost:3000/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
        ]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 20s

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      app:
        condition: service_healthy
```

Với Compose, `restart: unless-stopped` restart container khi process exit, nhưng không tự restart chỉ vì healthcheck unhealthy trong mọi trường hợp như orchestrator đầy đủ. Đừng hiểu nhầm Compose là Kubernetes.

## 15. Debug healthcheck fail

Xem trạng thái:

```bash
docker compose ps
```

Inspect:

```bash
docker inspect --format='{{json .State.Health}}' <container_name>
```

Xem logs app:

```bash
docker compose logs -f app
```

Chạy thử health command bên trong container:

```bash
docker compose exec app sh
node -e "fetch('http://localhost:3000/health').then(r=>console.log(r.status)).catch(err=>{console.error(err); process.exit(1)})"
```

Các nguyên nhân phổ biến:

- App không listen `0.0.0.0`.
- Sai port.
- Sai path `/health`.
- Image không có `curl`/`wget`.
- `start_period` quá ngắn.
- Health endpoint phụ thuộc database và database chậm.
- App boot lâu hơn `retries * interval`.
- Health command quote sai trên Compose/YAML.

## 16. Sai lầm cần tránh

### Dùng healthcheck thay cho logging/monitoring

Healthcheck chỉ trả lời khỏe/yếu. Nó không thay thế logs, metrics, tracing, alerting.

### Liveness check phụ thuộc database

Database fail tạm thời có thể làm app bị restart hàng loạt. Liveness nên kiểm tra process/app local.

### Readiness luôn trả 200

Nếu app chưa sẵn sàng nhưng `/ready` vẫn 200, orchestrator sẽ gửi traffic quá sớm.

### Health endpoint quá chậm

Endpoint chậm làm healthcheck timeout, tự tạo lỗi giả.

### Quên graceful shutdown

Nếu app nhận SIGTERM rồi chết ngay, request đang xử lý có thể fail. Readiness và graceful shutdown nên đi cùng nhau.

### Nghĩ `depends_on` giải quyết mọi dependency

`depends_on` không giúp khi dependency restart sau lúc app đã chạy. App cần retry/backoff.

## 17. Production thật triển khai như nào?

Một production rollout tốt:

```text
Deploy version mới
-> container start
-> startup grace period
-> readiness pass
-> load balancer route traffic
-> liveness giám sát process
-> nếu readiness fail, rút traffic
-> nếu liveness fail, restart
-> nếu deploy lỗi, rollback
```

Checklist production:

| Hạng mục | Khuyến nghị |
|---|---|
| `/live` | Nhẹ, không phụ thuộc external service |
| `/ready` | Kiểm tra sẵn sàng nhận traffic |
| Timeout | Ngắn, thường vài giây |
| Start grace | Đủ cho app boot/migration |
| Logs | Health fail phải có log chẩn đoán |
| Graceful shutdown | Bắt SIGTERM, ngừng nhận traffic mới |
| Metrics | Error rate, latency, saturation |
| Alert | Alert theo user impact, không chỉ unhealthy đơn lẻ |
| Rollback | Image tag rõ ràng |

## 18. Bài tập thực hành

1. Thêm `/live` và `/ready` vào app mẫu.
2. Cấu hình Compose healthcheck gọi `/ready`.
3. Chạy `docker compose up -d --build`.
4. Xem `docker compose ps` cho đến khi app healthy.
5. Cố tình sửa healthcheck sai port, quan sát unhealthy.
6. Cố tình để `start_period: 1s`, quan sát app boot chậm có thể fail.
7. Thêm Nginx `depends_on.app.condition: service_healthy`.
8. Viết graceful shutdown cho Node app.
9. Test `docker compose stop app` và xem log shutdown.

## 19. Checklist hoàn thành

Bạn nên trả lời được:

- Vì sao container `running` chưa chắc app ready?
- Liveness khác readiness thế nào?
- Khi nào nên check database trong health endpoint?
- `start_period`, `interval`, `timeout`, `retries` nghĩa là gì?
- Vì sao image có thể fail healthcheck nếu thiếu `curl`/`wget`?
- Compose `depends_on.condition: service_healthy` giúp gì và không giúp gì?
- Production orchestrator dùng readiness để rollout an toàn như thế nào?

## 20. Nguồn tham khảo chính thức

- Dockerfile HEALTHCHECK reference: https://docs.docker.com/reference/dockerfile/#healthcheck
- Docker Compose healthcheck reference: https://docs.docker.com/reference/compose-file/services/#healthcheck
- Docker Compose startup order: https://docs.docker.com/compose/how-tos/startup-order/
- Kubernetes probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

