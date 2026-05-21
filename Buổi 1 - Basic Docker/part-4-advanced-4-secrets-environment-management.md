# Part 4 Advanced 4 - Secrets và Environment Management

> Mục tiêu: hiểu config khác secret thế nào, dùng `.env` đúng cách trong Docker Compose, tránh commit secret, biết dùng Compose secrets/Docker secrets, và hiểu production thật quản lý secret bằng CI/CD hoặc secret manager.

## 1. Config và secret khác nhau thế nào?

Không phải biến môi trường nào cũng là secret.

| Loại | Ví dụ | Có nhạy cảm không? |
|---|---|---|
| Config thường | `NODE_ENV=production`, `PORT=3000`, `LOG_LEVEL=info` | Không hoặc thấp |
| Endpoint nội bộ | `REDIS_HOST=redis`, `DB_HOST=db` | Thấp/trung bình |
| Secret | `POSTGRES_PASSWORD`, `JWT_SECRET`, `STRIPE_SECRET_KEY` | Cao |
| Credential file | TLS private key, service account JSON | Cao |

Nguyên tắc:

```text
Image giống nhau giữa các môi trường.
Config và secret được inject lúc runtime.
```

Không rebuild image chỉ để đổi password hay endpoint production.

## 2. Vì sao hardcode secret nguy hiểm?

Không nên đặt secret trong:

- Dockerfile.
- `compose.yaml` commit vào Git.
- Source code.
- Image layer.
- Build arg.
- Log.
- Screenshot terminal.
- README thật.

Ví dụ sai:

```dockerfile
ENV JWT_SECRET=real-production-secret
```

Sai:

```yaml
services:
  app:
    environment:
      DATABASE_URL: postgres://user:real-password@db:5432/mydb
```

Vấn đề:

- Secret nằm trong Git history.
- Secret có thể nằm trong image metadata/history.
- Secret có thể bị in ra logs/debug.
- Người có quyền đọc repo có quyền đọc secret.
- Rất khó rotate triệt để.

## 3. `.env` trong Docker Compose dùng để làm gì?

Compose có hai khái niệm dễ nhầm:

1. `.env` để **interpolate biến trong Compose file**.
2. `env_file` để **đưa biến vào container environment**.

### `.env` interpolation

`.env`:

```env
APP_PORT=3000
POSTGRES_PASSWORD=dev-password
```

`compose.yaml`:

```yaml
services:
  app:
    ports:
      - "${APP_PORT}:3000"

  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

Compose đọc `.env` để thay `${APP_PORT}` và `${POSTGRES_PASSWORD}` trước khi tạo config.

Kiểm tra kết quả:

```bash
docker compose config
```

### `env_file`

`.env.app`:

```env
NODE_ENV=development
PORT=3000
DATABASE_URL=postgres://user:password@db:5432/mydb
REDIS_URL=redis://redis:6379
```

`compose.yaml`:

```yaml
services:
  app:
    env_file:
      - .env.app
```

Các biến trong `.env.app` được đưa vào environment của container `app`.

## 4. Pattern local dev an toàn

Trong repo:

```text
.env.example      commit
.env              không commit
compose.yaml      commit
.gitignore        commit
```

`.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

`.env.example`:

```env
APP_PORT=3000
POSTGRES_USER=user
POSTGRES_PASSWORD=change-me
POSTGRES_DB=mydb
DATABASE_URL=postgres://user:change-me@db:5432/mydb
REDIS_URL=redis://redis:6379
JWT_SECRET=change-me
```

`.env` local thật:

```env
APP_PORT=3000
POSTGRES_USER=user
POSTGRES_PASSWORD=local-dev-password
POSTGRES_DB=mydb
DATABASE_URL=postgres://user:local-dev-password@db:5432/mydb
REDIS_URL=redis://redis:6379
JWT_SECRET=local-jwt-secret
```

Không commit `.env`.

## 5. Refactor Compose từ hardcoded secret sang `.env`

Trước:

```yaml
services:
  app:
    environment:
      NODE_ENV: development
      DATABASE_URL: postgres://user:password@db:5432/mydb
      REDIS_URL: redis://redis:6379

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
```

Sau:

```yaml
services:
  app:
    environment:
      NODE_ENV: ${NODE_ENV:-development}
      PORT: ${PORT:-3000}
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
    ports:
      - "${APP_PORT:-3000}:3000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
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

Lưu ý `"$${POSTGRES_USER}"`: dùng `$$` để Compose không interpolate biến đó ở host, mà để shell trong container xử lý.

## 6. Biến bắt buộc và giá trị mặc định

Compose interpolation hỗ trợ default:

```yaml
NODE_ENV: ${NODE_ENV:-development}
```

Nếu thiếu `NODE_ENV`, dùng `development`.

Biến bắt buộc:

```yaml
DATABASE_URL: ${DATABASE_URL:?DATABASE_URL is required}
```

Nếu thiếu, `docker compose config` hoặc `up` sẽ báo lỗi.

Pattern production nên dùng biến bắt buộc cho secret quan trọng:

```yaml
JWT_SECRET: ${JWT_SECRET:?JWT_SECRET is required}
```

## 7. Environment precedence cần hiểu

Khi cùng một biến được set ở nhiều nơi, giá trị nào thắng phụ thuộc nguồn:

- CLI `docker compose run -e FOO=...`
- `environment` trong Compose.
- `env_file`.
- image `ENV` trong Dockerfile.

Người mới thường bị lỗi vì set `.env` rồi nghĩ container sẽ tự có biến đó. `.env` mặc định chủ yếu phục vụ interpolation cho Compose file; muốn đưa vào container thì dùng `environment` hoặc `env_file`.

Debug:

```bash
docker compose config
docker compose exec app env
```

Nếu `docker compose config` có biến đúng nhưng `docker compose exec app env` không có, bạn mới chỉ dùng biến cho interpolation chứ chưa inject vào container.

## 8. Secret dưới dạng file tốt hơn env var khi nào?

Environment variables tiện, nhưng có rủi ro:

- Dễ bị in ra khi debug `env`.
- Có thể xuất hiện trong process inspection tùy môi trường.
- Nhiều thư viện log config lúc startup.
- Khó kiểm soát quyền truy cập trong container.

Secret file thường tốt hơn cho secret nhạy cảm:

```text
/run/secrets/db_password
/run/secrets/jwt_secret
```

App đọc file:

```ts
import { readFileSync } from 'fs';

function readSecret(name: string): string {
  return readFileSync(`/run/secrets/${name}`, 'utf8').trim();
}

const jwtSecret = process.env.JWT_SECRET ?? readSecret('jwt_secret');
```

Nhiều Docker Official Images hỗ trợ biến `_FILE`, ví dụ PostgreSQL:

```yaml
environment:
  POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

## 9. Docker Compose secrets

Compose secrets mount secret thành file trong container, thường ở `/run/secrets/<secret_name>`.

Ví dụ local:

`secrets/db_password.txt`:

```text
local-dev-password
```

`compose.yaml`:

```yaml
services:
  db:
    image: postgres:18
    environment:
      POSTGRES_USER: user
      POSTGRES_DB: mydb
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

`.gitignore`:

```gitignore
secrets/*
!secrets/.gitkeep
```

Điểm quan trọng:

- Service chỉ thấy secret nếu được cấp trong `services.<name>.secrets`.
- Secret được mount như file.
- Compose local secrets giúp tránh env var, nhưng file secret vẫn nằm trên máy bạn. Cần bảo vệ quyền file và không commit.

## 10. Docker Secrets trong Swarm

Docker Secrets gốc được thiết kế cho Swarm mode.

Tạo secret:

```bash
printf "supersecretpassword" | docker secret create db_password -
```

Compose stack:

```yaml
services:
  db:
    image: postgres:18
    secrets:
      - db_password
    environment:
      POSTGRES_USER: user
      POSTGRES_DB: mydb
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    external: true
```

Deploy:

```bash
docker stack deploy -c compose.yaml my-stack
```

Swarm secrets phù hợp nếu bạn dùng Swarm. Nếu bạn dùng Kubernetes/ECS/cloud platform, thường dùng secret mechanism của platform đó.

## 11. Build secrets khác runtime secrets

Build secret dùng trong lúc build image, ví dụ private npm registry token. Runtime secret dùng khi container chạy, ví dụ database password.

Không nên dùng `ARG` cho secret:

```dockerfile
ARG NPM_TOKEN
RUN npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN
```

Secret có thể lọt vào layer/history.

Dùng BuildKit secret:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:24 AS builder
WORKDIR /app

COPY package*.json ./
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

Build:

```bash
docker build --secret id=npmrc,src=.npmrc -t my-app:prod .
```

Không copy `.npmrc` vào image.

## 12. Production thật quản lý secret như nào?

### VPS nhỏ dùng Compose

Tối thiểu:

- `.env.production` nằm trên server, không nằm trong repo.
- File chỉ readable bởi user deploy.
- Backup server không public secret.
- Không in `env` ra logs.
- Có quy trình rotate secret.

Ví dụ:

```yaml
services:
  app:
    image: ghcr.io/example/my-app:a1b2c3d
    restart: unless-stopped
    env_file:
      - .env.production
    expose:
      - "3000"
```

Phân quyền Linux:

```bash
chmod 600 .env.production
```

### VPS tốt hơn dùng secret files

```yaml
services:
  app:
    image: ghcr.io/example/my-app:a1b2c3d
    secrets:
      - jwt_secret
      - db_password
    environment:
      JWT_SECRET_FILE: /run/secrets/jwt_secret
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  jwt_secret:
    file: /opt/my-app/secrets/jwt_secret
  db_password:
    file: /opt/my-app/secrets/db_password
```

### Kubernetes

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
type: Opaque
stringData:
  DATABASE_URL: postgres://user:password@postgres:5432/mydb
  JWT_SECRET: replace-me
---
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
          envFrom:
            - secretRef:
                name: my-app-secrets
```

Trong production nghiêm túc, Kubernetes Secret thường được kết hợp với:

- External Secrets Operator.
- Sealed Secrets.
- SOPS.
- Cloud KMS.
- Vault.

### AWS ECS

Thông thường:

- Secrets nằm trong AWS Secrets Manager hoặc SSM Parameter Store.
- ECS task definition reference secret ARN.
- IAM role giới hạn task chỉ đọc secret cần thiết.

Ý tưởng chung: app không biết secret đến từ đâu, chỉ đọc env/file runtime.

## 13. Secret rotation

Rotation là đổi secret có kiểm soát.

Ví dụ rotate database password:

1. Tạo password mới trong database.
2. Cập nhật secret manager.
3. Deploy app đọc secret mới.
4. Đảm bảo app mới connect thành công.
5. Thu hồi password cũ.
6. Kiểm tra không còn instance dùng password cũ.

Với JWT secret, rotation phức tạp hơn vì token cũ còn hiệu lực. Pattern thường dùng:

- Có key id (`kid`).
- App verify bằng nhiều public/secret keys trong giai đoạn chuyển tiếp.
- Sign token mới bằng key mới.
- Hết thời gian token cũ, bỏ key cũ.

Không nên rotate bằng cách sửa trực tiếp trong container đang chạy.

## 14. Logging và secret redaction

Sai:

```ts
console.log(process.env);
console.log({ databaseUrl: process.env.DATABASE_URL });
```

Tốt hơn:

```ts
function redact(value: string | undefined): string {
  if (!value) return '<empty>';
  return value.length <= 4 ? '****' : `${value.slice(0, 2)}****${value.slice(-2)}`;
}

console.log({
  nodeEnv: process.env.NODE_ENV,
  hasDatabaseUrl: Boolean(process.env.DATABASE_URL),
  jwtSecret: redact(process.env.JWT_SECRET),
});
```

Trong production, logger nên có redaction rule cho key như:

```text
password
secret
token
authorization
cookie
api_key
```

## 15. Validate config lúc app start

App nên fail fast nếu thiếu config bắt buộc.

Ví dụ:

```ts
function requireEnv(name: string): string {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

const config = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: requireEnv('DATABASE_URL'),
  redisUrl: requireEnv('REDIS_URL'),
  jwtSecret: requireEnv('JWT_SECRET'),
};
```

Lợi ích:

- Lỗi config lộ ngay khi deploy.
- Không để app chạy nửa vời rồi fail ở request đầu tiên.
- Healthcheck/readiness phản ánh đúng trạng thái.

Không in giá trị secret trong error message.

## 16. Sai lầm cần tránh

### Commit `.env`

Kể cả repo private, vẫn không nên commit secret. Repo private có nhiều integration, CI logs, fork, backup.

### Nghĩ xóa file khỏi Git là xong

Nếu secret đã commit, nó vẫn nằm trong Git history. Cần rotate secret. Sau đó mới rewrite history nếu cần.

### Đặt secret trong Dockerfile `ENV`

Secret đi vào image metadata/layer và có thể bị inspect.

### Dùng build arg cho secret

`ARG` không phải secret manager.

### In toàn bộ environment khi debug

`env`, `printenv`, `console.log(process.env)` có thể lộ secret trong logs.

### Dùng cùng secret cho dev/staging/prod

Mỗi môi trường cần secret riêng. Dev bị lộ không được kéo theo prod.

### Không có `.env.example`

Người mới vào project không biết cần biến nào. `.env.example` nên có placeholder, không có secret thật.

### Quên escape `$` trong Compose healthcheck

Nếu muốn biến được shell trong container đọc, dùng `$$`:

```yaml
test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
```

## 17. Production checklist

| Hạng mục | Khuyến nghị |
|---|---|
| Secret source | Secret manager/platform secret, không phải Git |
| Local docs | `.env.example` có placeholder |
| Git ignore | `.env`, `.env.*`, secret files |
| Runtime injection | env/file qua platform |
| Build secret | BuildKit secret mount |
| Rotation | Có quy trình đổi secret |
| Logs | Redact secret |
| Access control | Least privilege |
| Audit | Biết ai đọc/sửa secret |
| Backup | Backup không làm lộ secret |

## 18. Bài tập thực hành

1. Tạo `.env.example` cho `my-app`.
2. Tạo `.env` local thật và thêm vào `.gitignore`.
3. Refactor `compose.yaml` dùng `${POSTGRES_PASSWORD}` thay vì hardcode.
4. Chạy `docker compose config` để kiểm tra interpolation.
5. Chạy `docker compose exec app env` để xem biến nào vào container.
6. Chuyển `POSTGRES_PASSWORD` sang Compose secret file.
7. Dùng `POSTGRES_PASSWORD_FILE` cho PostgreSQL.
8. Cố tình thiếu `DATABASE_URL` với `${DATABASE_URL:?required}`, quan sát Compose báo lỗi.
9. Viết `requireEnv()` trong app để fail fast khi thiếu secret.

## 19. Checklist hoàn thành

Bạn nên trả lời được:

- Config khác secret thế nào?
- `.env` interpolation khác `env_file` thế nào?
- Vì sao không commit `.env`?
- Vì sao secret file thường tốt hơn env var?
- Compose secrets mount ở đâu trong container?
- Docker Swarm secrets khác Compose local secrets thế nào?
- Build secret khác runtime secret thế nào?
- Production rotate secret theo quy trình nào?

## 20. Nguồn tham khảo chính thức

- Environment variables in Compose: https://docs.docker.com/compose/how-tos/environment-variables/
- Set environment variables in Compose: https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/
- Manage secrets securely in Docker Compose: https://docs.docker.com/compose/how-tos/use-secrets/
- Compose file secrets reference: https://docs.docker.com/reference/compose-file/secrets/
- Docker build secrets: https://docs.docker.com/build/building/secrets/

