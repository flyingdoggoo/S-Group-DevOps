# Part 4 Advanced 1 - Multi-Stage Builds

> Mục tiêu: hiểu vì sao Dockerfile một stage chưa đủ tốt cho production, biết viết multi-stage build cho Node.js/TypeScript, tách build-time dependency khỏi runtime image, và biết triển khai image production qua CI/CD.

## 1. Vấn đề của Dockerfile một stage

Dockerfile ở Part 2:

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

Dockerfile này chạy được, nhưng production chưa tốt:

- Image chứa cả TypeScript compiler.
- Image chứa `devDependencies`.
- Có thể chứa source TypeScript dù runtime chỉ cần `dist`.
- Base image `node:24` lớn hơn cần thiết.
- Attack surface lớn hơn.
- Pull/push image chậm hơn.
- Vulnerability scan dễ báo nhiều lỗi từ package không cần ở runtime.

Production runtime chỉ cần:

- Node runtime.
- `node_modules` production.
- File compiled JavaScript trong `dist`.
- File config/runtime cần thiết.

Không cần:

- `typescript`.
- `ts-node`.
- `@types/*`.
- Source `src`.
- Tool build.

## 2. Multi-stage build là gì?

Multi-stage build cho phép một Dockerfile có nhiều `FROM`.

Ví dụ:

```dockerfile
FROM node:24 AS builder
# build app

FROM node:24-alpine AS production
# chỉ copy output cần chạy từ builder
```

Mỗi `FROM` tạo một stage. Stage sau có thể copy file từ stage trước:

```dockerfile
COPY --from=builder /app/dist ./dist
```

Ý tưởng:

```text
builder stage:
  có đầy đủ dependency để compile
  tạo dist/

production stage:
  nhỏ hơn
  chỉ chứa thứ cần để chạy
```

## 3. Dockerfile multi-stage cho Node.js/TypeScript

`Dockerfile.multistage`:

```dockerfile
# Stage 1: install all dependencies and build TypeScript
FROM node:24 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

# Stage 2: install only production dependencies
FROM node:24-alpine AS production

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Build:

```bash
docker build -f Dockerfile.multistage -t my-app:prod .
```

Run:

```bash
docker run --rm -p 3000:3000 my-app:prod
```

Test:

```bash
curl http://localhost:3000/health
```

## 4. Giải thích chi tiết

### `FROM node:24 AS builder`

Stage này dùng để build. Nó có thể lớn hơn vì không đi vào production final image.

Tên `builder` quan trọng vì:

```dockerfile
COPY --from=builder /app/dist ./dist
```

Nếu không đặt tên, bạn phải dùng `--from=0`, dễ vỡ khi reorder stage.

### `RUN npm ci`

Builder cần cả dependencies và devDependencies vì TypeScript compiler nằm trong devDependencies.

`npm ci` yêu cầu `package-lock.json` và cài đúng theo lockfile. CI/CD production build nên dùng `npm ci`, không dùng `npm install` tùy tiện.

### `RUN npm run build`

Tạo `dist`. Đây là output duy nhất app Node runtime cần từ builder.

### `FROM node:24-alpine AS production`

Final stage là image thật được xuất ra sau build. Image này nên nhỏ và chỉ chứa runtime.

Alpine nhỏ, nhưng cần chú ý một số native dependency có thể khác vì Alpine dùng musl libc thay vì glibc. Nếu app dùng package native phức tạp, có thể cân nhắc `node:24-slim` thay vì Alpine.

### `RUN npm ci --omit=dev`

Chỉ cài production dependencies. Không cài `typescript`, `ts-node`, `@types/*`.

### `COPY --from=builder /app/dist ./dist`

Copy compiled output từ stage builder. Không copy `src`.

### `CMD ["node", "dist/index.js"]`

Runtime chạy JavaScript compiled.

## 5. Vì sao không copy `node_modules` từ builder?

Bạn có thể nghĩ:

```dockerfile
COPY --from=builder /app/node_modules ./node_modules
```

Nhưng builder có cả devDependencies. Như vậy production image vẫn mang theo dependency không cần thiết.

Một cách khác là prune:

```dockerfile
RUN npm prune --omit=dev
```

Tuy nhiên pattern dễ hiểu và sạch cho người mới là cài production dependency trong final stage:

```dockerfile
COPY package*.json ./
RUN npm ci --omit=dev
```

Với package native, việc cài dependency trong final stage cũng giúp dependency được build phù hợp với base image final. Nếu builder là Debian mà final là Alpine, copy `node_modules` native từ Debian sang Alpine có thể lỗi.

## 6. Thêm non-root user cho production

Nhiều Node official image đã có user `node`. Bạn có thể chạy app bằng user này:

```dockerfile
FROM node:24-alpine AS production

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder --chown=node:node /app/dist ./dist

USER node

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Lợi ích: nếu app bị khai thác, attacker không mặc định có quyền root trong container.

Lưu ý: nếu app cần ghi file trong `/app`, bạn phải đảm bảo quyền ghi cho user `node`. Production tốt hơn là không ghi vào app directory; upload nên đi object storage hoặc volume riêng.

## 7. `.dockerignore` cho multi-stage

`.dockerignore`:

```gitignore
node_modules
dist
.git
.env
.env.*
npm-debug.log
coverage
Dockerfile*
compose*.yaml
*.md
```

Nếu bạn muốn build docs hoặc copy file markdown vào image thì đừng ignore `*.md`. Với backend runtime, thường không cần.

`.dockerignore` giúp:

- Build context nhỏ.
- Build nhanh hơn.
- Tránh copy nhầm secret.
- Giảm khả năng cache bị invalidated bởi file không liên quan.

## 8. Build target

Bạn có thể build đến stage cụ thể:

```bash
docker build -f Dockerfile.multistage --target builder -t my-app:builder .
docker build -f Dockerfile.multistage --target production -t my-app:prod .
```

Ứng dụng:

- Debug stage builder.
- Chạy test trong stage test.
- Dùng Compose chọn target dev/prod.

Ví dụ thêm stage test:

```dockerfile
FROM builder AS test
RUN npm test

FROM node:24-alpine AS production
# ...
```

CI có thể build target `test` trước, sau đó build target `production`.

## 9. Compose dùng multi-stage

Local development có thể build stage khác production:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.multistage
      target: production
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      PORT: 3000
```

Với production thật, thường không build trên server:

```yaml
services:
  app:
    image: ghcr.io/example/my-app:2026-05-21-a1b2c3d
    restart: unless-stopped
    env_file:
      - .env.production
    expose:
      - "3000"
```

CI build image rồi push registry. Server chỉ pull image đã kiểm thử.

## 10. So sánh image size

Build image một stage:

```bash
docker build -f Dockerfile -t my-app:single .
```

Build image multi-stage:

```bash
docker build -f Dockerfile.multistage -t my-app:multi .
```

So sánh:

```bash
docker images | grep my-app
```

Trên PowerShell:

```powershell
docker images | Select-String my-app
```

Xem layer:

```bash
docker history my-app:single
docker history my-app:multi
```

Kỳ vọng: image multi-stage nhỏ hơn, ít layer runtime không cần thiết hơn, không chứa source TypeScript và devDependencies.

## 11. Cache trong multi-stage

Pattern tốt:

```dockerfile
COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
```

Vì dependency ít đổi hơn source code. Khi sửa `src/index.ts`, Docker có thể reuse layer `npm ci`.

Pattern kém:

```dockerfile
COPY . .
RUN npm ci
RUN npm run build
```

Mỗi lần sửa một file bất kỳ, layer install dependency bị build lại.

Với BuildKit, có thể tăng tốc npm bằng cache mount:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:24 AS builder
WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
```

Cache mount không đưa cache npm vào final image. Nó chỉ giúp build nhanh hơn.

## 12. Healthcheck trong production image

Multi-stage không bắt buộc healthcheck, nhưng production thường cần. Nếu final image có `wget`, bạn có thể:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
```

Nếu final image không có `wget`, đừng cài quá nhiều tool chỉ vì healthcheck. Có thể dùng Node:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
```

Với Node phiên bản mới có `fetch` global. Nếu runtime không hỗ trợ, dùng script nhỏ trong app hoặc để orchestrator kiểm tra HTTP endpoint.

## 13. Secret trong build

Không truyền secret bằng `ARG` rồi dùng trong Dockerfile nếu secret có thể lưu vào layer/history.

Không nên:

```dockerfile
ARG NPM_TOKEN
RUN npm config set //registry.npmjs.org/:_authToken=$NPM_TOKEN
```

Nên dùng BuildKit secret mount khi cần private package:

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

Build:

```bash
docker build --secret id=npmrc,src=.npmrc -t my-app:prod .
```

Ý tưởng: secret chỉ xuất hiện trong lúc build step chạy, không được bake vào image final.

## 14. Sai lầm cần tránh

### Final image vẫn chứa devDependencies

Sai:

```dockerfile
COPY --from=builder /app/node_modules ./node_modules
```

nếu builder đã `npm ci` đầy đủ.

Đúng hơn:

```dockerfile
RUN npm ci --omit=dev
```

### Builder và runtime dùng base quá khác nhau

Nếu dependency native được build ở Debian rồi chạy ở Alpine, có thể lỗi. Khi app có native modules, cân nhắc:

- Builder và runtime cùng family, ví dụ đều Alpine.
- Hoặc dùng `node:24-slim` cho runtime.
- Hoặc cài dependency production trực tiếp ở final stage.

### Không copy lockfile

Sai:

```dockerfile
COPY package.json ./
RUN npm install
```

Đúng:

```dockerfile
COPY package*.json ./
RUN npm ci
```

### Dùng `latest` cho base image production

Không nên:

```dockerfile
FROM node:latest
```

Nên pin version major/minor phù hợp:

```dockerfile
FROM node:24-alpine
```

Mức chặt hơn là pin digest, đặc biệt với môi trường yêu cầu reproducibility cao.

### Build trên server production

Không nên SSH vào server rồi:

```bash
git pull
docker build -t my-app .
docker compose up -d
```

Cách này làm server production thành build machine, khó audit, dễ lệch dependency, rollback kém. Nên build trong CI, push registry, server pull image.

### Copy cả repo vào final image

Sai:

```dockerfile
COPY . .
```

trong final stage nếu runtime chỉ cần `dist` và `node_modules` production.

## 15. Production thật triển khai multi-stage như nào?

Flow khuyến nghị:

```text
push code
-> CI install/test/lint
-> docker build multi-stage target production
-> scan image
-> tag image bằng version/commit SHA
-> push registry
-> deploy staging
-> smoke test
-> promote/deploy production
-> monitor health/error/latency
```

Tag gợi ý:

```text
ghcr.io/company/my-app:1.4.2
ghcr.io/company/my-app:2026-05-21-a1b2c3d
ghcr.io/company/my-app:main-a1b2c3d
```

Tránh deploy bằng:

```text
ghcr.io/company/my-app:latest
```

### CI ví dụ với GitHub Actions

```yaml
name: build

on:
  push:
    branches: [main]

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          file: Dockerfile.multistage
          target: production
          push: true
          tags: ghcr.io/example/my-app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Server hoặc orchestrator deploy tag `${{ github.sha }}`. Rollback là chọn lại tag cũ.

### Trên Kubernetes

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
          envFrom:
            - secretRef:
                name: my-app-secrets
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 30
```

### Trên VPS với Compose

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
      test: ["CMD", "node", "-e", "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

Deploy:

```bash
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f app
```

## 16. Bài tập thực hành

1. Build image một stage `my-app:single`.
2. Build image multi-stage `my-app:multi`.
3. So sánh size bằng `docker images`.
4. So sánh layer bằng `docker history`.
5. Vào shell final image và kiểm tra không có `src`:

```bash
docker run --rm -it --entrypoint sh my-app:multi
ls -la
ls -la src
```

6. Kiểm tra `typescript` không nằm trong production dependency:

```bash
docker run --rm -it --entrypoint sh my-app:multi
npm ls typescript
```

7. Sửa source code, build lại, quan sát bước `npm ci` có cached không.
8. Thêm `USER node`, build và run lại.
9. Đổi final image từ Alpine sang Slim nếu dependency native lỗi.

## 17. Checklist hoàn thành

Bạn nên trả lời được:

- Multi-stage build giải quyết vấn đề gì?
- Stage `builder` và `production` khác nhau thế nào?
- Vì sao final image không nên chứa devDependencies?
- Vì sao không nên copy `node_modules` từ builder sang final một cách mù quáng?
- `--target` dùng để làm gì?
- Vì sao CI nên build image, server chỉ pull image?
- Khi nào Alpine có thể gây lỗi?
- Secret trong build nên xử lý thế nào?

## 18. Nguồn tham khảo chính thức

- Docker multi-stage builds: https://docs.docker.com/build/building/multi-stage/
- Docker build best practices: https://docs.docker.com/build/building/best-practices/
- Optimize cache usage in builds: https://docs.docker.com/build/cache/optimize/
- Dockerfile HEALTHCHECK reference: https://docs.docker.com/reference/dockerfile/#healthcheck

