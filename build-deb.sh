#!/bin/bash
#
# build-deb.sh
#
# Build dedistracter Debian package using Docker BuildKit
# This allows building on macOS, Linux, and Windows
#
# Usage:
#   ./build-deb.sh           # Build and extract .deb to current directory
#   ./build-deb.sh --help    # Show this help message
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${SCRIPT_DIR}/build-output"
DOCKER_IMAGE="dedistracter-builder"

show_help() {
    cat << 'EOF'
Usage: ./build-deb.sh [OPTIONS]

Build dedistracter Debian package using Docker BuildKit.

OPTIONS:
  --help      Show this help message
  --clean     Remove build image
  --arm64     Build for ARM64 (Pi 4/5)
  --armhf     Build for ARMhf (Pi 0/1/2/3)

EXAMPLES:
  ./build-deb.sh              # Build for current architecture
  ./build-deb.sh --arm64      # Build for ARM64 Raspberry Pi
  ./build-deb.sh --clean      # Clean up Docker resources

The built .deb file will be in: ./build-output/

EOF
}

clean_build() {
    echo "Cleaning up Docker resources..."
    docker rmi "$DOCKER_IMAGE" 2>/dev/null || true
    rm -rf "$OUTPUT_DIR"
    echo "Cleaned!"
}

# Parse arguments
ARCH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --clean)
            clean_build
            exit 0
            ;;
        --arm64)
            ARCH="arm64"
            shift
            ;;
        --armhf)
            ARCH="armhf"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build arguments
BUILD_ARGS="--output type=local,dest=$OUTPUT_DIR"
if [ -n "$ARCH" ]; then
    BUILD_ARGS="$BUILD_ARGS --platform linux/$ARCH"
fi

# Enable BuildKit and build
echo "Building package using Docker BuildKit..."
DOCKER_BUILDKIT=1 docker build \
    -t "$DOCKER_IMAGE" \
    --target output \
    $BUILD_ARGS \
    "$SCRIPT_DIR"

# List output files
echo ""
echo "Build complete! Output files:"
ls -lh "$OUTPUT_DIR"/ 2>/dev/null | tail -n +2

echo ""
echo "To install on your Raspberry Pi:"
echo "  scp $OUTPUT_DIR/*.deb root@pi.hole:/tmp/"
echo "  ssh root@pi.hole dpkg -i '/tmp/*.deb'"
