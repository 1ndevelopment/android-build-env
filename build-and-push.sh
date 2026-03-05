#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  build-and-push.sh
#  Builds the Android CI image and pushes it to Docker Hub.
#
#  Prerequisites:
#    docker login   (run once — credentials are cached)
#
#  Usage:
#    ./build-and-push.sh <dockerhub-username> [tag]
#
#  Examples:
#    ./build-and-push.sh myuser
#    ./build-and-push.sh myuser sdk34-java25
#    ./build-and-push.sh myuser latest
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

DOCKERHUB_USER="${1:-}"
TAG="${2:-sdk34-java25-gradle9.3.0}"
REPO="android-build-env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Validate input ───────────────────────────────────────────────
if [[ -z "${DOCKERHUB_USER}" ]]; then
  echo "❌  Usage: ./build-and-push.sh <dockerhub-username> [tag]"
  echo "    Example: ./build-and-push.sh myuser latest"
  exit 1
fi

FULL_IMAGE="${DOCKERHUB_USER}/${REPO}:${TAG}"
LATEST_IMAGE="${DOCKERHUB_USER}/${REPO}:latest"

echo "──────────────────────────────────────────────"
echo "  Docker Hub user : ${DOCKERHUB_USER}"
echo "  Repository      : ${REPO}"
echo "  Tag             : ${TAG}"
echo "  Full image      : ${FULL_IMAGE}"
echo "──────────────────────────────────────────────"

# ── Ensure Docker is logged in to Docker Hub ─────────────────────
if ! docker info 2>/dev/null | grep -q "Username"; then
  echo "▶  Not logged in to Docker Hub. Running docker login..."
  docker login
fi

# ── Build ────────────────────────────────────────────────────────
echo ""
echo "▶  Building image..."
docker build \
  --no-cache \
  --progress=plain \
  --tag "${FULL_IMAGE}" \
  --tag "${LATEST_IMAGE}" \
  "${SCRIPT_DIR}"

echo "✅  Build complete: ${FULL_IMAGE}"

# ── Push both tags ───────────────────────────────────────────────
echo ""
echo "▶  Pushing ${FULL_IMAGE}..."
docker push "${FULL_IMAGE}"

echo "▶  Pushing ${LATEST_IMAGE}..."
docker push "${LATEST_IMAGE}"

echo ""
echo "✅  Done! Your image is live at:"
echo "    docker pull ${FULL_IMAGE}"
echo "    docker pull ${LATEST_IMAGE}"
