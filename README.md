# Android Builder Environment Container

Pre-built Docker image with **Java 25 + Gradle 9.3.0 + Android SDK 34**.  
Push it to Docker Hub once — pull it anywhere, get straight to building.

---

## Contents

| Tool | Version |
|------|---------|
| Base OS | Ubuntu 24.04 |
| Java | OpenJDK 25 (EA) |
| Gradle | 9.3.0 |
| Android compileSdk | 34 |
| Android Build Tools | 34.0.0 |
| Android Platform Tools | latest |
| Android Extras | m2repo, Google Play Services |

---

## File structure

```
.
├── Dockerfile               ← The image definition
├── build-and-push.sh        ← Helper to build & push to Docker Hub
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

## 1. One-time Docker Hub setup

```bash
# Log in to Docker Hub (credentials are cached locally)
docker login
```

If you don't have a Docker Hub account, create one at https://hub.docker.com.  
Create a repository named `android-ci` (public or private).

---

## 2. Build & push the image

```bash
chmod +x build-and-push.sh

# Build and push — automatically tags as both <tag> and :latest
./build-and-push.sh YOUR_DOCKERHUB_USER

# Or specify a custom tag
./build-and-push.sh YOUR_DOCKERHUB_USER sdk34-java25
```

> **First build takes ~15–20 min** — installs Java 25, Gradle, the Android SDK,
> and pre-warms the Gradle dependency cache. Docker layer caching makes rebuilds fast.

Your image will be available at:
```
docker pull YOUR_DOCKERHUB_USER/android-ci:latest
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
  image: YOUR_DOCKERHUB_USER/android-ci:latest
  credentials:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

### GitLab CI

Copy `gitlab-ci.yml` to your repo root as `.gitlab-ci.yml` and replace `YOUR_DOCKERHUB_USER`.

For **private** Docker Hub repos, add this CI/CD variable in GitLab
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
  YOUR_DOCKERHUB_USER/android-ci:latest \
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
Replace the Java install block's JDK_URL with the Temurin 21 URL from adoptium.net.

### Kotlin / AGP version
Update warmup/build.gradle to pre-warm the exact versions your project uses.

---

## Notes on Java 25

Java 25 is an **Early Access** release. Once GA ships, update the `JDK_URL` in
the Dockerfile to the stable Temurin/Adoptium download — no other changes needed.
