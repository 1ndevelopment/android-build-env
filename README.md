<div align="center">
  <img src="https://files.1ndev.com/images/software/android-build-env/A.B.E.cellphone_cropped_transparent.png" alt="Android Build Environment" width="360" style="border-radius: 12px;" />

  <h1>Android Build Environment</h1>

  <p><strong>Pre-built Docker images for Android CI — zero toolchain setup, every time.</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Java-25-orange?style=flat-square&logo=oracle" />
    <img src="https://img.shields.io/badge/Gradle-9.3.0-02303A?style=flat-square&logo=gradle" />
    <img src="https://img.shields.io/badge/Android_SDK-35-3DDC84?style=flat-square&logo=android" />
    <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=flat-square&logo=ubuntu" />
  </p>
</div>

---

Build once. Pull anywhere. Your CI pipeline goes straight to `./gradlew` — no SDK downloads, no Java installs, no waiting.

## What's inside

| Tool | Version |
|------|---------|
| Base OS | Ubuntu 24.04 |
| Java | Oracle JDK 25 |
| Gradle | 9.3.0 |
| Android compileSdk | 35 |
| Android Build Tools | 35.0.0 |
| Android Platform Tools | latest |
| Android Extras | m2repo, Google Play Services |

## File structure

```
.
├── Dockerfile               ← Image definition
├── build-and-push.sh        ← Build & push to any container registry
├── warmup/                  ← Minimal Android project (pre-warms Gradle cache)
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

## 1 · Build & push the image

```bash
chmod +x build-and-push.sh
```

Pick your registry:

```bash
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

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--repo` | Override the image name | `android-build-env` |
| `--tag` | Override the image tag | `java25-sdk35` |
| `--no-cache` | Build without Docker layer cache | — |
| `--no-push` | Build only, skip push | — |

> **First build takes ~15–20 min** — installs Java 25, Gradle, the Android SDK, and pre-warms the Gradle dependency cache. Subsequent builds are fast thanks to Docker layer caching.

---

## 2 · Registry setup

<details>
<summary><strong>Docker Hub</strong></summary>

```bash
docker login
```

Create a repository named `android-build-env` at [hub.docker.com](https://hub.docker.com).

</details>

<details>
<summary><strong>GitHub Container Registry (ghcr.io)</strong></summary>

```bash
echo YOUR_GITHUB_PAT | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

No repository pre-creation needed — it's created automatically on first push.

</details>

<details>
<summary><strong>Google Container Registry (gcr.io)</strong></summary>

```bash
gcloud auth configure-docker gcr.io
```

</details>

<details>
<summary><strong>Amazon ECR</strong></summary>

```bash
aws ecr create-repository --repository-name android-build-env --region us-east-1
```

The script handles login automatically via the AWS CLI.

</details>

<details>
<summary><strong>Azure Container Registry</strong></summary>

```bash
az acr login --name myregistry
```

</details>

---

## 3 · Use in CI

### GitHub Actions

1. Go to **Settings → Secrets and variables → Actions** in your repo
2. Add two secrets:
   - `DOCKERHUB_USERNAME` — your Docker Hub username
   - `DOCKERHUB_TOKEN` — a Docker Hub access token *(Account Settings → Security)*
3. Copy `android-build.yml` to `.github/workflows/` and update `YOUR_DOCKERHUB_USER`:

```yaml
container:
  image: YOUR_DOCKERHUB_USER/android-build-env:java25-sdk35
  credentials:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

### GitLab CI

Copy `gitlab-ci.yml` to your repo root as `.gitlab-ci.yml` and replace `YOUR_DOCKERHUB_USER`.

For **private** registries, add this variable under **Settings → CI/CD → Variables**:

| Variable | Value |
|----------|-------|
| `DOCKER_AUTH_CONFIG` | `{"auths":{"https://index.docker.io/v1/":{"auth":"<base64(user:token)>"}}}` |

Generate the base64 value:

```bash
echo -n "YOUR_DOCKERHUB_USER:YOUR_ACCESS_TOKEN" | base64
```

### Local / any runner

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  YOUR_DOCKERHUB_USER/android-build-env:java25-sdk35 \
  ./gradlew assembleDebug
```

---

## 4 · Build outputs

| Gradle task | Output |
|-------------|--------|
| `./gradlew assembleDebug` | `app/build/outputs/apk/debug/*.apk` |
| `./gradlew assembleRelease` | `app/build/outputs/apk/release/*.apk` |
| `./gradlew bundleRelease` | `app/build/outputs/bundle/release/*.aab` |

---

## 5 · Customization

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

Replace the Java install block in the Dockerfile with the [Temurin 21 binary](https://adoptium.net) and update `JAVA_HOME` accordingly.

### Pre-warm your exact Kotlin / AGP versions

Update `warmup/build.gradle` to match the AGP and Kotlin versions your project uses — they'll be baked into the image layer and cached on every pull.
