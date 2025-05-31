#!/bin/bash

# Build a dynamic rust library for a chosen platform and automatically place it in the output bin
# directory so it can be used in Godot.
# Example usage: ./build_platform.sh windows debug
# Example output: addons/dijkstra-map/dijkstra_map_library/bin/dijkstra_map_gd.windows.debug.dll

if [ $# -ne 2 ]; then
    echo "Usage: $0 <platform> <profile>"
    echo "  platform: windows | linux | mac | mac_arm"
    echo "  profile:  debug | release"
    exit 1
fi

CHOSEN_PLATFORM=$1
CHOSEN_PROFILE=$2

# Verify platform choice
case $CHOSEN_PLATFORM in
    windows)
        PLATFORM="x86_64-pc-windows-msvc"
        PLATFORM_EXTENSION="dll"
        ;;
    linux)
        PLATFORM="x86_64-unknown-linux-gnu"
        PLATFORM_EXTENSION="so"
        ;;
    mac)
        PLATFORM="x86_64-apple-darwin"
        PLATFORM_EXTENSION="dylib"
        ;;
    mac_arm)
        PLATFORM="aarch64-apple-darwin"
        PLATFORM_EXTENSION="dylib"
        ;;
    *)
        echo "Invalid platform: $CHOSEN_PLATFORM"
        echo "Supported platforms: windows, linux, mac, mac_arm"
        exit 1
        ;;
esac

# Verify profile choice
case $CHOSEN_PROFILE in
  release)
    CARGO_FLAGS="--release"
    ;;
  debug)
    CARGO_FLAGS=""
    ;;
  *)
    echo "Invalid profile: $CHOSEN_PROFILE"
    echo "Supported profiles: debug, release"
    exit 1
    ;;
esac

# Build for the specified platform & profile
CRATE_NAME="dijkstra_map_gd"
BIN_DIR="addons/dijkstra-map/dijkstra_map_library/bin"
TARGET_DIR="target/$PLATFORM/$CHOSEN_PROFILE"
OUTPUT_FILE="${CRATE_NAME}.${CHOSEN_PLATFORM}.${CHOSEN_PROFILE}.${PLATFORM_EXTENSION}"
DEST_PATH="${BIN_DIR}/${OUTPUT_FILE}"

# Ensure target platform is available
rustup target add $PLATFORM

# Start build
echo "📦 Building $CRATE_NAME for $PLATFORM ($CHOSEN_PLATFORM) [$CHOSEN_PROFILE]..."
cargo build $CARGO_FLAGS --target $PLATFORM

# Copy built artifact over to the destination path
mkdir -p "$BIN_DIR"
cp "$TARGET_DIR/${CRATE_NAME}.${PLATFORM_EXTENSION}" "$DEST_PATH"

echo "Output written to $DEST_PATH"
