# Part 2 Standard - Hands-On Dockerfile và Docker Compose

> Mục tiêu: tự viết Dockerfile cho một backend Node.js/TypeScript, build image, run container, dùng Docker Compose để chạy app + PostgreSQL + Redis, và hiểu cách chuyển từ local sang production.

## 1. Chuẩn bị môi trường

Kiểm tra Docker:

```bash
docker --version
docker compose version
```

Nếu Docker chạy được, kiểm tra engine:

```bash
docker info
```

Nếu lệnh lỗi, thường do:

- Docker Desktop chưa start.
- User chưa có quyền gọi Docker daemon.
- WSL/Docker Desktop integration chưa bật trên Windows.
- Docker Engine chưa được cài trên Linux server.

## 2. App mẫu

Ta dùng backend Node.js + Express + TypeScript.

Cấu trúc:

```text
my-app/
├── Dockerfile
├── Dockerfile.multistage
├── compose.yaml
├── package.json
├── package-lock.json
├── tsconfig.json
└── src/
    └── index.ts
```

`src/index.ts`:

```ts
import express, { Request, Response } from 'express';

const app = express();
const PORT = Number(process.env.PORT ?? 3000);

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    env: process.env.NODE_ENV ?? null,
  });
});

app.get('/', (_req: Request, res: Response) => {
  res.json({ message: 'Hello from Docker' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

`package.json`:

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts"
  },
  "dependencies": {
    "express": "5.2.1"
  },
  "devDependencies": {
    "@types/express": "^5.0.0",
    "@types/node": "^24.0.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.8.0"
  }
}
```

`tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## 3. Dockerfile đầu tiên

`Dockerfile`:

```dockerfile
FROM node:24

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Giải thích từng dòng

`FROM node:24`

Chọn image nền có Node.js. Image này đã có Linux userspace và Node runtime. Bản `node:24` thường lớn hơn `node:24-alpine`, nhưng dễ học hơn vì có nhiều tool sẵn.

`WORKDIR /app`

Tạo và chuyển vào thư mục `/app`. Các lệnh sau chạy trong thư mục này.

`COPY package*.json ./`

Copy `package.json` và `package-lock.json` trước. Đây là pattern quan trọng để Docker cache bước install dependency.

`RUN npm install`

Cài dependency. Với production hoặc CI nên ưu tiên `npm ci` nếu có `package-lock.json` vì deterministic hơn.

`COPY tsconfig.json ./` và `COPY src ./src`

Copy source code vào image.

`RUN npm run build`

Compile TypeScript sang JavaScript ở `dist`.

`EXPOSE 3000`

Ghi metadata rằng app nghe port 3000 trong container. Nó không tự publish port ra host.

`CMD ["node", "dist/index.js"]`

Lệnh mặc định khi container start. Dạng JSON exec form tốt hơn shell form vì signal được truyền đúng hơn.

## 4. Thêm `.dockerignore`

Tạo `.dockerignore` để build context nhỏ và tránh copy rác:

```gitignore
node_modules
dist
.git
.env
.env.*
npm-debug.log
Dockerfile*
compose*.yaml
README.md
```

Lưu ý: nếu Dockerfile cần copy file nào thì đừng ignore file đó. Ví dụ nếu Dockerfile copy `compose.yaml` thì không ignore, nhưng bình thường image app không cần compose file.

## 5. Build image

```bash
docker build -t my-app:dev .
```

Ý nghĩa:

- `docker build`: build image.
- `-t my-app:dev`: đặt tên và tag.
- `.`: build context là thư mục hiện tại.

Xem image:

```bash
docker images my-app
```

Nếu build lại, bạn sẽ thấy vài bước `CACHED`. Đó là Docker layer cache.

## 6. Run container

```bash
docker run --rm -p 3000:3000 my-app:dev
```

Test:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/
```

Chạy background:

```bash
docker run -d --name my-app -p 3000:3000 my-app:dev
docker logs -f my-app
docker rm -f my-app
```

Truyền biến môi trường:

```bash
docker run --rm \
  -p 3000:3000 \
  -e NODE_ENV=development \
  -e PORT=3000 \
  my-app:dev
```

Trên PowerShell:

```powershell
docker run --rm `
  -p 3000:3000 `
  -e NODE_ENV=development `
  -e PORT=3000 `
  my-app:dev
```

## 7. Docker Compose cho app + database + Redis

`compose.yaml`:

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: development
      PORT: 3000
      DATABASE_URL: postgres://user:password@db:5432/mydb
      REDIS_URL: redis://redis:6379
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
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:8-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s

volumes:
  pg_data:
  redis_data:
```

Chạy:

```bash
docker compose up --build
```

Chạy background:

```bash
docker compose up -d --build
```

Xem trạng thái:

```bash
docker compose ps
```

Xem log:

```bash
docker compose logs -f app
docker compose logs -f db
```

Dừng:

```bash
docker compose down
```

Dừng và xóa volume:

```bash
docker compose down -v
```

Chỉ dùng `down -v` khi bạn chấp nhận mất dữ liệu database local.

## 8. Hiểu networking trong Compose

Compose tự tạo một network mặc định. Mỗi service có DNS name bằng tên service.

Trong app container:

```text
db -> IP container PostgreSQL
redis -> IP container Redis
```

Vì vậy:

```text
DATABASE_URL=postgres://user:password@db:5432/mydb
REDIS_URL=redis://redis:6379
```

Không dùng:

```text
DATABASE_URL=postgres://user:password@localhost:5432/mydb
```

Vì `localhost` trong app container là app container, không phải database.

## 9. Hiểu `depends_on` và healthcheck

`depends_on` dạng đơn giản chỉ đảm bảo container dependency được start trước, không đảm bảo service đã sẵn sàng nhận request.

Dạng tốt hơn:

```yaml
depends_on:
  db:
    condition: service_healthy
```

Điều kiện này yêu cầu `db` có healthcheck và phải healthy trước khi `app` start.

Healthcheck PostgreSQL:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 10s
```

Các tham số:

| Tham số | Ý nghĩa |
|---|---|
| `test` | Lệnh kiểm tra |
| `interval` | Bao lâu kiểm tra một lần |
| `timeout` | Một lần check được chạy tối đa bao lâu |
| `retries` | Thất bại liên tiếp bao nhiêu lần thì unhealthy |
| `start_period` | Thời gian khởi động chưa tính lỗi |

## 10. Debug khi container lỗi

### Container không start

```bash
docker compose ps
docker compose logs app
```

### Xem config Compose sau khi interpolate env

```bash
docker compose config
```

### Vào shell container

```bash
docker compose exec app sh
```

Nếu container đã exit:

```bash
docker compose run --rm app sh
```

### Xem environment trong container

```bash
docker compose exec app env
```

### Kiểm tra network DNS

```bash
docker compose exec app sh
getent hosts db
getent hosts redis
```

Một số image Alpine có thể không có đủ tool debug. Khi cần debug sâu, bạn có thể tạm dùng image debug hoặc cài tool trong môi trường dev, nhưng không nên nhét tool debug không cần thiết vào image production.

## 11. Lệnh Docker cần thuộc

```bash
# Container
docker ps
docker ps -a
docker logs -f <container>
docker exec -it <container> sh
docker inspect <container>
docker rm -f <container>

# Image
docker images
docker image inspect <image>
docker image rm <image>
docker image prune

# Volume
docker volume ls
docker volume inspect <volume>
docker volume prune

# Network
docker network ls
docker network inspect <network>

# Compose
docker compose up -d --build
docker compose ps
docker compose logs -f
docker compose exec app sh
docker compose down
docker compose down -v
```

## 12. Sai lầm cần tránh

### Copy toàn bộ source trước khi install dependency

Không tối ưu:

```dockerfile
COPY . .
RUN npm install
```

Mỗi lần sửa code, layer install dependency bị invalidated.

Tốt hơn:

```dockerfile
COPY package*.json ./
RUN npm ci
COPY src ./src
```

### Không có `.dockerignore`

Nếu không ignore `node_modules`, `.git`, `dist`, build context sẽ nặng, build chậm và có thể copy nhầm secret.

### Dùng `npm install` trong CI production build

Với lockfile, ưu tiên:

```dockerfile
RUN npm ci
```

`npm ci` cài đúng theo lockfile và fail nếu lockfile lệch.

### Publish port database ra host khi không cần

Local có thể cần:

```yaml
ports:
  - "5432:5432"
```

Production thường không nên expose database ra public interface. App nên gọi database qua private network.

### Đặt password thẳng trong `compose.yaml`

Local lab có thể tạm dùng. Production không nên commit secret vào repo.

### Nghĩ volume là backup

Volume giúp dữ liệu không mất khi container recreate. Backup là quy trình riêng: dump, snapshot, retention, restore test.

## 13. Production thật triển khai như thế nào?

### Local/dev

Dev thường dùng:

- `build: .`
- Bind mount source code nếu cần hot reload.
- Database/Redis chạy container local.
- Port publish ra localhost để test.
- `.env` local không commit.

### Production nhỏ bằng Compose trên VPS

Production Compose nên khác dev:

- Dùng `image:` đã build từ CI, không build trực tiếp trên server.
- Không mount source code.
- Không expose database ra ngoài.
- App chỉ `expose`, reverse proxy publish `80/443`.
- Có `restart: unless-stopped`.
- Có healthcheck.
- Secret nằm ngoài repo.
- Log ra stdout/stderr.

Ví dụ:

```yaml
services:
  app:
    image: ghcr.io/example/my-app:2026-05-21-a1b2c3d
    restart: unless-stopped
    env_file:
      - .env.production
    expose:
      - "3000"
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:18
    restart: unless-stopped
    env_file:
      - .env.production
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
```

Trong Compose, nếu bạn cần giữ ký tự `$` để container shell xử lý, dùng `$$` để tránh Compose interpolate trước.

### Production lớn

Với nhiều instance, rolling update, autoscaling, secret manager và traffic routing phức tạp, dùng orchestrator:

- Kubernetes: Deployment, Service, Ingress, ConfigMap, Secret, HPA.
- AWS ECS: Task Definition, Service, ALB, CloudWatch Logs, Secrets Manager.
- Nomad: job spec, service discovery, Vault integration.
- Docker Swarm: service, stack, secrets.

Điểm chung: bạn vẫn build Docker image trước, push registry, rồi deploy image đó.

## 14. Bài tập tự làm

1. Build image `my-app:dev`.
2. Run container bằng `docker run`, test `/health`.
3. Chạy stack bằng `docker compose up -d --build`.
4. Vào shell app container và chạy `env`.
5. Xem log app và database.
6. Dừng stack không xóa volume.
7. Dừng stack và xóa volume, quan sát database mất dữ liệu local.
8. Sửa một dòng trong `src/index.ts`, build lại và quan sát layer nào cached.

## 15. Checklist hoàn thành

Bạn nên làm được:

- Viết Dockerfile Node.js cơ bản.
- Build và tag image.
- Run container với port và env.
- Dùng Compose chạy nhiều service.
- Giải thích vì sao app gọi `db`, không gọi `localhost`.
- Biết khi nào dùng volume.
- Biết đọc logs và exec vào container.
- Biết điểm khác nhau giữa local Compose và production Compose.

## 16. Nguồn tham khảo chính thức

- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- Docker build best practices: https://docs.docker.com/build/building/best-practices/
- Docker Compose services reference: https://docs.docker.com/reference/compose-file/services/
- Docker Compose startup order: https://docs.docker.com/compose/how-tos/startup-order/
