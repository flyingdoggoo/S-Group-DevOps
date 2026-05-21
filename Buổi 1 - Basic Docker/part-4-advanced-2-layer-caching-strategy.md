# Part 4 Advanced 2 - Docker Layer Caching Strategy

> Mục tiêu: hiểu Docker build cache hoạt động như thế nào, biết sắp xếp Dockerfile để build nhanh hơn, tránh invalid cache không cần thiết, dùng `.dockerignore`, BuildKit cache mount và external cache trong CI/CD.

## 1. Vì sao layer caching quan trọng?

Khi làm một app nhỏ, build Docker chậm vài chục giây có thể chưa thấy vấn đề. Nhưng trong production thật, build image xảy ra liên tục:

- Mỗi lần push code.
- Mỗi lần mở pull request.
- Mỗi lần chạy CI test.
- Mỗi lần rebuild để vá base image.
- Mỗi lần build multi-platform.

Nếu Dockerfile không tối ưu cache, CI/CD sẽ chậm, tốn tiền runner, developer chờ lâu và feedback loop kém.

Ví dụ Node.js app:

```text
Source code đổi mỗi ngày.
package-lock.json đổi ít hơn nhiều.
Base image đổi ít hơn nữa.
```

Vậy Dockerfile nên đặt các bước ít thay đổi lên trước, các bước hay thay đổi xuống sau. Đây là nguyên tắc lớn nhất của Docker layer caching.

## 2. Docker image layer là gì?

Một image được tạo từ nhiều layer xếp chồng lên nhau. Mỗi instruction như `RUN`, `COPY`, `ADD` thường tạo một layer hoặc ảnh hưởng đến cache key.

Ví dụ:

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY src ./src
RUN npm run build
CMD ["node", "dist/index.js"]
```

Docker build theo thứ tự từ trên xuống:

```text
FROM
-> WORKDIR
-> COPY package*.json
-> RUN npm ci
-> COPY src
-> RUN npm run build
-> CMD
```

Nếu một bước bị cache miss, tất cả bước phía sau thường phải chạy lại.

## 3. Cache hit và cache miss

### Cache hit

Docker thấy instruction hiện tại và dữ liệu liên quan giống lần build trước. Nó tái sử dụng kết quả cũ.

Log thường có:

```text
CACHED
```

### Cache miss

Docker thấy instruction hoặc dữ liệu liên quan đã đổi. Nó chạy lại bước đó và các bước sau.

Ví dụ:

```dockerfile
COPY src ./src
RUN npm run build
```

Nếu bạn sửa `src/index.ts`, bước `COPY src ./src` cache miss, nên `RUN npm run build` cũng chạy lại.

## 4. Quy tắc cache cần nhớ

Docker build cache có vài quy tắc quan trọng:

| Quy tắc | Ý nghĩa thực tế |
|---|---|
| Build chạy từ trên xuống | Bước trước ảnh hưởng bước sau |
| Instruction phải match | Đổi text lệnh `RUN` là cache miss |
| `COPY`/`ADD` phụ thuộc file được copy | Đổi file liên quan là cache miss |
| Một bước cache miss kéo theo bước sau | Đặt bước hay đổi xuống dưới |
| `RUN` không tự biết package ngoài đã mới hơn | `RUN apk add curl` có thể vẫn cached dù repo ngoài đổi |
| `.dockerignore` ảnh hưởng build context | Context nhỏ hơn giúp build nhanh và cache sạch hơn |

Điểm dễ nhầm: chỉ đổi modification time của file thường không đủ làm invalid cache; Docker dùng checksum từ metadata/file liên quan, không đơn giản chỉ nhìn timestamp.

## 5. Dockerfile kém tối ưu

Ví dụ này chạy được nhưng cache tệ:

```dockerfile
FROM node:24-alpine
WORKDIR /app

COPY . .
RUN npm ci
RUN npm run build

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Vấn đề:

- `COPY . .` copy toàn bộ repo trước khi install dependency.
- Sửa một dòng trong `src/index.ts` cũng làm cache miss bước `COPY . .`.
- Vì `RUN npm ci` nằm sau đó, dependency phải cài lại dù `package-lock.json` không đổi.
- Nếu không có `.dockerignore`, `node_modules`, `.git`, logs, coverage có thể đi vào build context.

## 6. Dockerfile tối ưu cơ bản cho Node.js

Pattern tốt hơn:

```dockerfile
FROM node:24-alpine
WORKDIR /app

# Dependency layer: chỉ đổi khi package.json/package-lock.json đổi
COPY package*.json ./
RUN npm ci

# Source layer: đổi thường xuyên hơn
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Khi bạn sửa source code:

```text
COPY package*.json -> CACHED
RUN npm ci        -> CACHED
COPY src         -> chạy lại
RUN npm build    -> chạy lại
```

Đây là khác biệt lớn trong CI/CD.

## 7. Pattern tốt hơn cho production với multi-stage

Kết hợp với Advanced 1:

```dockerfile
# syntax=docker/dockerfile:1

FROM node:24 AS builder
WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:24-alpine AS production
ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

COPY --from=builder /app/dist ./dist

USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

Giải thích:

- `package*.json` được copy trước để dependency layer ổn định.
- `--mount=type=cache,target=/root/.npm` giữ npm cache giữa các lần build.
- Build stage có devDependencies để compile TypeScript.
- Production stage chỉ cài production dependencies.
- Source code không nằm trong final image.

## 8. `.dockerignore` là một phần của cache strategy

Build context là toàn bộ dữ liệu Docker client gửi cho builder. Nếu context lớn, build chậm hơn và dễ cache miss hơn.

`.dockerignore` gợi ý cho Node.js:

```gitignore
node_modules
dist
.git
.github
.env
.env.*
npm-debug.log
coverage
*.log
Dockerfile*
compose*.yaml
README.md
```

Lưu ý:

- Đừng ignore file Dockerfile cần `COPY`.
- Đừng ignore `package-lock.json`.
- Đừng ignore `src` nếu Dockerfile copy `src`.
- Với monorepo, nên build bằng context hẹp nhất có thể.

Ví dụ context hẹp:

```bash
docker build -f my-app/Dockerfile -t my-app:cache-test my-app
```

Thay vì build từ root repo rất lớn nếu app chỉ nằm trong `my-app`.

## 9. Đo cache bằng lệnh build

Trong thư mục app:

```bash
docker build --progress=plain -t my-app:cache-test .
```

Build lần đầu thường lâu hơn.

Sửa một comment trong `src/index.ts`, rồi build lại:

```bash
docker build --progress=plain -t my-app:cache-test .
```

Quan sát output:

```text
#7 CACHED
#8 [builder 5/6] COPY src ./src
#9 [builder 6/6] RUN npm run build
```

Trên Linux/macOS có thể dùng:

```bash
time docker build -t my-app:cache-test .
```

Trên PowerShell:

```powershell
Measure-Command { docker build -t my-app:cache-test . }
```

## 10. Cache mount là gì?

Docker layer cache và package manager cache là hai chuyện khác nhau.

### Layer cache

Nếu `RUN npm ci` cache hit, lệnh không chạy lại.

### Cache mount

Nếu `RUN npm ci` phải chạy lại, npm vẫn có thể tái sử dụng cache download từ lần build trước.

Ví dụ:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:24-alpine
WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
```

Khi `package-lock.json` đổi, `npm ci` vẫn chạy lại, nhưng package không đổi có thể được lấy từ cache mount thay vì tải lại từ registry.

## 11. Cache mount cho các ecosystem khác

Node.js:

```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
```

Python pip:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
```

Go:

```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server
```

APT:

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl
```

Với APT, `sharing=locked` giúp tránh nhiều build ghi vào cùng cache cùng lúc.

## 12. External cache trong CI/CD

Trên máy local, Docker giữ cache trong builder local. Trên CI runner ephemeral, runner có thể bị xóa sau mỗi job, cache mất. Cần external cache.

Ví dụ GitHub Actions:

```yaml
name: docker-build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/build-push-action@v6
        with:
          context: ./my-app
          file: ./my-app/Dockerfile.multistage
          target: production
          push: false
          tags: my-app:ci
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Khi cần push image:

```yaml
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: ./my-app
          file: ./my-app/Dockerfile.multistage
          target: production
          push: true
          tags: ghcr.io/example/my-app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Có thể dùng registry cache nếu muốn cache đi cùng registry:

```yaml
cache-from: type=registry,ref=ghcr.io/example/my-app:buildcache
cache-to: type=registry,ref=ghcr.io/example/my-app:buildcache,mode=max
```

## 13. Cache busting: khi nào cần phá cache?

Đừng dùng `--no-cache` như thói quen. Nó làm build chậm và che giấu Dockerfile kém.

Dùng `--no-cache` khi:

- Bạn nghi cache làm kết quả build sai.
- Bạn cần rebuild toàn bộ để kiểm tra reproducibility.
- Bạn muốn lấy package mới từ OS repository mà Dockerfile chưa pin rõ.

```bash
docker build --no-cache -t my-app:fresh .
```

Phá cache một stage cụ thể:

```bash
docker build --no-cache-filter builder -t my-app:fresh .
```

Cache bust bằng build arg:

```dockerfile
ARG CACHE_BUST=1
RUN echo "$CACHE_BUST" > /tmp/cache-bust
```

Build:

```bash
docker build --build-arg CACHE_BUST=$(date +%s) .
```

Không nên dùng cách này tràn lan. Nếu cần phá cache thường xuyên, Dockerfile có thể đang thiếu version pin hoặc layer order chưa đúng.

## 14. `RUN apt-get update` và cache

Sai:

```dockerfile
RUN apt-get update
RUN apt-get install -y curl
```

Vì `apt-get update` có thể bị cached, còn package index cũ.

Tốt hơn:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
```

Lý do:

- Update index và install nằm cùng layer.
- Không giữ apt list trong final image.
- `--no-install-recommends` giảm package thừa.

Nếu cần reproducibility cao, pin version package và base image digest.

## 15. Monorepo và cache

Monorepo dễ làm cache miss vì context lớn:

```text
repo/
├── apps/
│   ├── api/
│   └── web/
├── packages/
│   └── shared/
└── docs/
```

Nếu build API mà context là toàn repo:

```bash
docker build -f apps/api/Dockerfile .
```

Sửa docs cũng có thể ảnh hưởng context hoặc cache nếu Dockerfile `COPY . .`.

Tốt hơn:

- Dùng `.dockerignore` kỹ.
- Copy chính xác file cần thiết.
- Dùng context hẹp nếu được.
- Với workspace package manager, copy lockfile/workspace manifests trước, source sau.

Ví dụ:

```dockerfile
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY packages/shared/package.json packages/shared/package.json
RUN npm ci

COPY apps/api apps/api
COPY packages/shared packages/shared
RUN npm run build -w apps/api
```

## 16. Sai lầm cần tránh

### `COPY . .` quá sớm

Đây là lỗi phổ biến nhất. Nó làm mọi thay đổi nhỏ phá cache dependency.

### Không có `.dockerignore`

`node_modules`, `.git`, `dist`, coverage, log và secret có thể đi vào context.

### Dùng `npm install` thay vì `npm ci` trong CI

`npm install` có thể cập nhật lockfile hoặc resolve khác kỳ vọng. Với CI, dùng `npm ci`.

### Dùng `--no-cache` để "cho chắc"

Nó làm mất lợi ích của Docker cache. Nên hiểu vì sao cache sai thay vì tắt toàn bộ.

### Tải dependency bằng script không deterministic

Ví dụ:

```dockerfile
RUN curl https://example.com/install.sh | sh
```

Nếu script remote đổi, Docker cache có thể vẫn giữ kết quả cũ hoặc build mới ra kết quả khác mà khó audit. Production nên pin version/checksum.

### Build context chứa secret

Ngay cả khi Dockerfile không copy `.env`, gửi secret vào build context vẫn là rủi ro. Dùng `.dockerignore`.

### Cache mount chứa artifact không nên tin tuyệt đối

Cache mount giúp nhanh hơn, không phải nguồn chân lý. Build vẫn phải dựa vào lockfile/version pin.

## 17. Production thật triển khai cache strategy như nào?

Một pipeline production tốt:

```text
Developer push code
-> CI checkout
-> setup Buildx
-> restore external build cache
-> docker build target production
-> run tests hoặc smoke test image
-> scan vulnerability/SBOM
-> push image tag commit SHA
-> export/update build cache
-> deploy image tag cụ thể
```

Nguyên tắc:

| Nguyên tắc | Lý do |
|---|---|
| Build trong CI, không build trên server | Reproducible và audit được |
| Dùng lockfile | Dependency ổn định |
| Dùng `.dockerignore` | Context nhỏ và tránh secret |
| Layer dependency trước source | Rebuild nhanh |
| External cache cho CI | Runner mới vẫn build nhanh |
| Tag image bằng commit SHA | Rollback rõ ràng |
| Không phụ thuộc cache để đúng | Cache chỉ là tăng tốc, không phải correctness |

## 18. Bài tập thực hành

Trong thư mục `my-app`:

1. Build lần đầu:

```bash
docker build --progress=plain -t my-app:cache-test .
```

2. Build lại không đổi gì, quan sát `CACHED`.
3. Sửa `src/index.ts`, build lại.
4. Sửa `package.json` hoặc `package-lock.json`, build lại.
5. So sánh thời gian bằng `Measure-Command` trên PowerShell.
6. Thêm `.dockerignore` nếu chưa có, build lại.
7. Thử Dockerfile kém tối ưu có `COPY . .` trước `npm ci`, so sánh behavior.
8. Thêm BuildKit cache mount cho npm, build lại sau khi đổi dependency.

## 19. Checklist hoàn thành

Bạn nên trả lời được:

- Vì sao thứ tự instruction trong Dockerfile ảnh hưởng build time?
- Khi nào `COPY package*.json` bị cache miss?
- Vì sao `COPY . .` trước `npm ci` là kém?
- `.dockerignore` giúp gì ngoài chuyện giảm dung lượng?
- Cache mount khác layer cache thế nào?
- Vì sao CI cần external cache?
- Khi nào nên dùng `--no-cache`?
- Production pipeline dùng cache nhưng vẫn phải đảm bảo reproducibility như thế nào?

## 20. Nguồn tham khảo chính thức

- Docker build cache invalidation: https://docs.docker.com/build/cache/invalidation/
- Optimize cache usage in builds: https://docs.docker.com/build/cache/optimize/
- Docker build best practices: https://docs.docker.com/build/building/best-practices/
- Docker Build GitHub Actions cache: https://docs.docker.com/build/ci/github-actions/cache/

