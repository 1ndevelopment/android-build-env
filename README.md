# Android Build Environment (A.B.E)

<img src="https://files.1ndev.com/images/software/android-build-env/A.B.E.png" alt="ABE" width="120" align="left" style="border-radius: 8px; margin-left: 16px;" />

Generate pre-built Docker images with **Java 25 + Gradle 9.3.0 + Android SDK 35**.  
Build and push it to any container registry — pull it anywhere and get straight to building.  
No toolchain setup on every CI run.

---

## Contents

| Tool | Version |
|------|---------|
| Base OS | Ubuntu 24.04 |
| Java | Oracle JDK 25 |
| Gradle | 9.3.0 |
| Android compileSdk | 35 |
| Android Build Tools | 35.0.0 |
| Android Platform Tools | latest |
| Android Extras | m2repo, Google Play Services |

---

## File structure

```
.
├── Dockerfile               ← The image definition
├── build-and-push.sh        ← Build & push to any container registry
├── warmup/                  ← Minimal Android project (Gradle cache pre-warm)
│   ├── build.gradle
│   ├── settings.gradle
│   ├── gradle.properties
│   └── app/
│       ├── build.gradle
│       └── src/main/...
├── android-build.yml        ← Example GitHub Actions workflow
└── gitlab-ci.yml            ← Example GitLab CI pipeline
```

---

## 1. Build & push the image

```bash
chmod +x build-and-push.sh

# Docker Hub
./build-and-push.sh --registry dockerhub --user 1ndevelopment

# GitHub Container Registry
./build-and-push.sh --registry ghcr --user 1ndevelopment

# Google Container Registry
./build-and-push.sh --registry gcr --user my-gcp-project

# Amazon ECR
./build-and-push.sh --registry ecr --host 123456789.dkr.ecr.us-east-1.amazonaws.com

# Azure Container Registry
./build-and-push.sh --registry acr --host myregistry.azurecr.io

# Self-hosted / custom
./build-and-push.sh --registry custom --host registry.mycompany.com --user myteam
```

### Additional flags

| Flag | Description | Default |
|------|-------------|---------|
| `--repo` | Override the image name | `android-build-env` |
| `--tag` | Override the image tag | `java25-sdk35` |
| `--no-cache` | Build without Docker layer cache | — |
| `--no-push` | Build only, skip push | — |

> **First build takes ~15–20 min** — installs Java 25, Gradle, the Android SDK,
> and pre-warms the Gradle dependency cache. Docker layer caching makes rebuilds fast.

---

## 2. Registry setup

### Docker Hub
```bash
docker login
```
Create a repository named `android-build-env` at https://hub.docker.com.

### GitHub Container Registry (ghcr.io)
```bash
echo YOUR_GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```
No repository pre-creation needed — it's created on first push.

### Google Container Registry (gcr.io)
```bash
gcloud auth configure-docker gcr.io
```

### Amazon ECR
```bash
aws ecr create-repository --repository-name android-build-env --region us-east-1
```
The script handles login automatically via the AWS CLI.

### Azure Container Registry
```bash
az acr login --name myregistry
```

---

## 3. Use in CI

### GitHub Actions

1. Go to your repo → **Settings → Secrets and variables → Actions**
2. Add two secrets:
   - `DOCKERHUB_USERNAME` — your Docker Hub username
   - `DOCKERHUB_TOKEN` — a Docker Hub access token (hub.docker.com → Account Settings → Security)
3. Copy `android-build.yml` to `.github/workflows/` and replace `YOUR_DOCKERHUB_USER`:

```yaml
container:
  image: YOUR_DOCKERHUB_USER/android-build-env:java25-sdk35
  credentials:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

### GitLab CI

Copy `gitlab-ci.yml` to your repo root as `.gitlab-ci.yml` and replace `YOUR_DOCKERHUB_USER`.

For **private** registries, add this CI/CD variable in GitLab
(**Settings → CI/CD → Variables**):

| Variable | Value |
|----------|-------|
| `DOCKER_AUTH_CONFIG` | `{"auths":{"https://index.docker.io/v1/":{"auth":"<base64(user:token)>"}}}` |

Generate the base64 value:
```bash
echo -n "YOUR_DOCKERHUB_USER:YOUR_ACCESS_TOKEN" | base64
```

### Any runner / local build

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  YOUR_DOCKERHUB_USER/android-build-env:java25-sdk35 \
  ./gradlew assembleDebug
```

---

## 4. Build outputs

| Gradle task | Output path |
|-------------|-------------|
| `./gradlew assembleDebug` | `app/build/outputs/apk/debug/*.apk` |
| `./gradlew assembleRelease` | `app/build/outputs/apk/release/*.apk` |
| `./gradlew bundleRelease` | `app/build/outputs/bundle/release/*.aab` |

---

## 5. Customization tips

### Add NDK
Uncomment in the Dockerfile:
```dockerfile
RUN sdkmanager "ndk;25.2.9519653"
```

### Target a different API level
```dockerfile
ENV ANDROID_COMPILE_SDK=35 \
    ANDROID_BUILD_TOOLS=35.0.0
```

### Switch to Java 21 LTS
Replace the Java install block in the Dockerfile with the Temurin 21 binary from https://adoptium.net and update `JAVA_HOME` accordingly.

### Kotlin / AGP version
Update `warmup/build.gradle` to pre-warm the exact AGP and Kotlin versions your project uses, so those are cached in the image layer too.
