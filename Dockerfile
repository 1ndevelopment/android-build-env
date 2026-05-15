# ============================================================
#  Android CI Build Image
#  Java 25 + Gradle 9.3.0 + Android SDK 35
# ============================================================
FROM alpine:3.20

## Proxy config
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG http_proxy
ARG https_proxy

ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    http_proxy=${http_proxy} \
    https_proxy=${https_proxy}

ARG INSTALL_NDK=false
ARG BUILDER_UID=1002
ARG BUILDER_GID=1002

LABEL maintainer="1ndevelopment" \
      install.ndk="${INSTALL_NDK}" \
      description="Android CI build image: Java 25, Gradle 9.3.0, Android SDK 35" \
      android.compileSdk="35" \
      android.buildTools="35.0.0" \
      gradle.version="9.3.0" \
      java.version="25"

# ── Core versions ────────────────────────────────────────────
ENV JAVA_VERSION=25 \
    GRADLE_VERSION=9.3.0 \
    ANDROID_COMPILE_SDK=35 \
    ANDROID_BUILD_TOOLS=35.0.0 \
    ANDROID_SDK_TOOLS_VERSION=11076708 \
    ANDROID_NDK_VERSION=27.0.12077973

# ── Path layout ──────────────────────────────────────────────
ENV ANDROID_HOME=/opt/android-sdk \
    GRADLE_HOME=/opt/gradle/gradle-9.3.0 \
    JAVA_HOME=/opt/java

ENV PATH="${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS}:${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}:${PATH}"

# ── Android SDK license acceptance ───────────────────────────
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}

# ============================================================
#  1. System dependencies
# ============================================================
RUN apk add --no-cache \
        bash \
        binutils \
        curl \
        wget \
        sshpass \
        unzip \
        zip \
        tar \
        git \
        make \
        libgcc \
        libstdc++ \
        ncurses \
        zlib \
        ca-certificates \
        musl-locales \
        openssh-client-default \
        rsync \
        sudo \
        nano \
        github-cli \
        jq \
        zstd \
        gcompat \
        python3 \
        py3-pip

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ============================================================
#  2. Java 25  (Azul Zulu JDK 25 — musl build for Alpine)
# ============================================================
RUN mkdir -p /opt/java && \
    curl -fsSL -o jdk-25_musl_x64.tar.gz \
        https://cdn.azul.com/zulu/bin/zulu25.34.17-ca-jdk25.0.3-linux_musl_x64.tar.gz && \
    tar -xzf jdk-25_musl_x64.tar.gz -C /opt/java --strip-components=1 && \
    rm jdk-25_musl_x64.tar.gz && \
    # World-readable so any user can execute
    chmod -R 755 /opt/java

# Verify Java
RUN java -version && \
    rm -rf /opt/java/lib/src.zip /opt/java/man

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
RUN gradle --version && \
    rm -rf ${GRADLE_HOME}/docs ${GRADLE_HOME}/src ${GRADLE_HOME}/javadoc

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
RUN yes | sdkmanager --licenses > /dev/null 2>&1 || true && \
    sdkmanager --update && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_COMPILE_SDK}" \
        "build-tools;${ANDROID_BUILD_TOOLS}" \
        "extras;android;m2repository" \
        "extras;google;m2repository" \
        "extras;google;google_play_services" \
        "cmake;3.22.1" && \
    rm -rf ~/.android/cache && \
    if [ "$INSTALL_NDK" = "true" ]; then \
        sdkmanager "ndk;${ANDROID_NDK_VERSION}" && \
        rm -rf ~/.android/cache; \
    fi
# RUN sdkmanager "emulator" "system-images;android-34;google_apis;x86_64"

# ============================================================
#  6. Strip native binaries & clean package caches
# ============================================================
RUN if [ "$INSTALL_NDK" = "true" ]; then \
        find ${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}/toolchains \
            -name '*.so*' -type f -exec strip --strip-unneeded {} \; \
            2>/dev/null || true && \
        find ${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}/toolchains \
            -type f -executable -exec strip --strip-unneeded {} \; \
            2>/dev/null || true; \
    fi && \
    pip cache purge 2>/dev/null || true

# ============================================================
#  7. Final setup
# ============================================================
# Create a dedicated group for SDK access
# BUILDER_UID / BUILDER_GID should match the host user's uid:gid so that
# mounted volumes are writable. Defaults to 1002:1002.
# Pass --build-arg BUILDER_UID=$(id -u) --build-arg BUILDER_GID=$(id -g) to match.
RUN addgroup -g 1001 android && \
    addgroup -g ${BUILDER_GID} builder && \
    adduser -u ${BUILDER_UID} -G builder -s /bin/bash -D builder && \
    adduser builder android && \
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
    echo "ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}" >> /etc/environment && \
    echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment && \
    echo "GRADLE_HOME=${GRADLE_HOME}" >> /etc/environment && \
    # Also add to /etc/profile.d so PATH is set for any login shell
    echo "export PATH=${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS}:${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}:\$PATH" \
        > /etc/profile.d/android-tools.sh && \
    chmod +x /etc/profile.d/android-tools.sh

WORKDIR /workspace

RUN chown -R builder:builder /workspace

# Switch to non-root builder user by default.
# Any other user added to the 'android' group gets the same access.
# Override with --user root if your CI runner requires it.
USER builder

# Verify the full toolchain is functional as non-root
RUN java -version && \
    gradle --version && \
    sdkmanager --list_installed && \
    if [ "$INSTALL_NDK" = "true" ]; then \
        ls -la ${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}; \
    fi

CMD ["/bin/bash"]
