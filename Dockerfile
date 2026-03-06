# ============================================================
#  Android CI Build Image
#  Java 25 + Gradle 9.3.0 + Android SDK 35
# ============================================================
FROM debian:bookworm-slim

LABEL maintainer="1ndevelopment" \
      description="Android CI build image: Java 25, Gradle 9.3.0, Android SDK 35" \
      android.compileSdk="35" \
      android.buildTools="35.0.0" \
      gradle.version="9.3.0" \
      java.version="25"

# ── Prevent interactive prompts during apt installs ──────────
ENV DEBIAN_FRONTEND=noninteractive

# ── Core versions ────────────────────────────────────────────
ENV JAVA_VERSION=25 \
    GRADLE_VERSION=9.3.0 \
    ANDROID_COMPILE_SDK=35 \
    ANDROID_BUILD_TOOLS=35.0.0 \
    ANDROID_SDK_TOOLS_VERSION=11076708

# ── Path layout ──────────────────────────────────────────────
ENV ANDROID_HOME=/opt/android-sdk \
    GRADLE_HOME=/opt/gradle/gradle-9.3.0 \
    JAVA_HOME=/opt/java

ENV PATH="${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS}:${PATH}"

# ── Android SDK license acceptance ───────────────────────────
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}

# ============================================================
#  1. System dependencies
# ============================================================
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        unzip \
        zip \
        tar \
        git \
        make \
        lib32stdc++6 \
        lib32z1 \
        libc6-i386 \
        libgcc-s1 \
        libncurses6 \
        zlib1g \
        ca-certificates \
        locales \
        openssh-client \
        rsync \
        sudo \
        nano \
        gh \
        jq \
        zstd \
        nodejs \
        npm \
        python3 \
        python3-pip \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ============================================================
#  2. Java 25  (Oracle JDK 25)
# ============================================================
RUN mkdir -p /opt/java && \
    curl -fsSL -o jdk-25_linux-x64_bin.tar.gz \
        https://download.oracle.com/java/25/archive/jdk-25_linux-x64_bin.tar.gz && \
    tar -xzf jdk-25_linux-x64_bin.tar.gz -C /opt/java --strip-components=1 && \
    rm jdk-25_linux-x64_bin.tar.gz && \
    # World-readable so any user can execute
    chmod -R 755 /opt/java

# Verify Java
RUN java -version

# ============================================================
#  3. Gradle 9.3.0
# ============================================================
RUN mkdir -p /opt/gradle && \
    wget -q "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
         -O /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt/gradle && \
    rm /tmp/gradle.zip && \
    # World-readable so any user can execute
    chmod -R 755 /opt/gradle

# Verify Gradle
RUN gradle --version

# ============================================================
#  4. Android Command-line Tools (sdkmanager)
# ============================================================
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" && \
    wget -q \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip" \
        -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extract && \
    mv /tmp/cmdline-tools-extract/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" && \
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extract

# ============================================================
#  5. Accept Android SDK licenses & install SDK components
# ============================================================
RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true

RUN sdkmanager --update && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_COMPILE_SDK}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "extras;android;m2repository" \
        "extras;google;m2repository" \
        "extras;google;google_play_services"

# Optional extras — uncomment to include NDK or emulator support:
# RUN sdkmanager "ndk;25.2.9519653"
# RUN sdkmanager "emulator" "system-images;android-34;google_apis;x86_64"

# ============================================================
#  6. Pre-warm the Gradle cache (wrapper + common plugins)
#     Build a minimal Android project so that Gradle downloads
#     its dependency metadata at image-build time, not CI time.
# ============================================================
WORKDIR /tmp/warmup

COPY warmup/ /tmp/warmup/

RUN gradle dependencies --no-daemon --quiet || true && \
    gradle assembleDebug --no-daemon --quiet || true

# Clean up warmup project after caching
RUN rm -rf /tmp/warmup

# ============================================================
#  7. Final setup
# ============================================================
# Create a dedicated group for SDK access
RUN groupadd --gid 1001 android && \
    # builder user — default non-root CI user
    groupadd --gid 1002 builder && \
    useradd --uid 1002 --gid builder --shell /bin/bash --create-home builder && \
    # Add builder to the android group
    usermod -aG android builder && \
    # Allow builder passwordless sudo
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership & permissions so any member of the android group
# can read/write/execute the entire SDK, Java, and Gradle installs
RUN chown -R root:android "${ANDROID_HOME}" && \
    chmod -R 775 "${ANDROID_HOME}" && \
    chown -R root:android /opt/java && \
    chmod -R 755 /opt/java && \
    chown -R root:android /opt/gradle && \
    chmod -R 755 /opt/gradle && \
    # Sticky group bit so new files inside inherit the android group
    find "${ANDROID_HOME}" -type d -exec chmod g+s {} \; && \
    find /opt/gradle -type d -exec chmod g+s {} \;

# Expose the android group and key env vars to all future users
# by writing to /etc/environment (sourced login-wide)
RUN echo "ANDROID_HOME=${ANDROID_HOME}" >> /etc/environment && \
    echo "ANDROID_SDK_ROOT=${ANDROID_HOME}" >> /etc/environment && \
    echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment && \
    echo "GRADLE_HOME=${GRADLE_HOME}" >> /etc/environment && \
    # Also add to /etc/profile.d so PATH is set for any login shell
    echo "export PATH=${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS}:\$PATH" \
        > /etc/profile.d/android-tools.sh && \
    chmod +x /etc/profile.d/android-tools.sh

WORKDIR /workspace

# Switch to non-root builder user by default.
# Any other user added to the 'android' group gets the same access.
# Override with --user root if your CI runner requires it.
USER builder

# Verify the full toolchain is functional as non-root
RUN java -version && \
    gradle --version && \
    sdkmanager --list_installed

CMD ["/bin/bash"]
