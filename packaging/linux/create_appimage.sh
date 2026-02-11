#!/bin/bash
set -e

# Define paths
BUILD_DIR="build/linux/x64/release/bundle"
APP_DIR="AppDir"

echo "Checking build directory..."
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory $BUILD_DIR does not exist."
    echo "Please run 'flutter build linux --release' first."
    exit 1
fi

echo "Cleaning up previous AppDir..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"

echo "Copying build artifacts..."
# Find all executables in build directory
EXECUTABLES=$(find "$BUILD_DIR" -maxdepth 1 -type f -executable)

if [ -z "$EXECUTABLES" ]; then
    echo "Error: No executable found in $BUILD_DIR"
    exit 1
fi

# We'll use the first found executable as the main entry point
MAIN_EXECUTABLE=""

echo "$EXECUTABLES" | while read -r EXECUTABLE; do
    EXEC_NAME=$(basename "$EXECUTABLE")
    echo "Found executable: $EXEC_NAME"
    cp "$EXECUTABLE" "$APP_DIR/usr/bin/$EXEC_NAME"
done

# Set the main executable to the first one found for the desktop file
MAIN_EXECUTABLE=$(echo "$EXECUTABLES" | head -n 1 | xargs basename)
echo "Main executable is: $MAIN_EXECUTABLE"

# Copy shared libraries to usr/lib
# This ensures libraries like libdesktop_multi_window_plugin.so are available
echo "Copying libraries..."
cp -r "$BUILD_DIR/lib/"* "$APP_DIR/usr/lib/"

# Copy assets (data folder)
# Flutter expects 'data' relative to executable.
# If executable is in usr/bin, data should be in usr/bin/data
echo "Copying data..."
mkdir -p "$APP_DIR/usr/bin/data"
cp -r "$BUILD_DIR/data/"* "$APP_DIR/usr/bin/data/"

# Copy Desktop file
echo "Copying desktop file..."
cp "linux/com.arran4.flutter_jules.desktop" "$APP_DIR/usr/share/applications/jules_client.desktop"

# Copy Icon
echo "Copying icon..."
cp "assets/icon/app_icon.png" "$APP_DIR/usr/share/icons/hicolor/256x256/apps/jules_client.png"

echo "Updating desktop file..."
# Update Exec and Icon fields
sed -i "s/^Exec=.*/Exec=$MAIN_EXECUTABLE/" "$APP_DIR/usr/share/applications/jules_client.desktop"
sed -i 's/^Icon=.*/Icon=jules_client/' "$APP_DIR/usr/share/applications/jules_client.desktop"

echo "Downloading linuxdeploy..."
if [ ! -f "linuxdeploy-x86_64.AppImage" ]; then
    wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
    chmod +x linuxdeploy-x86_64.AppImage
fi

echo "Generating AppImage..."
# Use --appimage-extract-and-run in case fuse is missing/configured restrictively
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run \
    --appdir "$APP_DIR" \
    --output appimage \
    --icon-file "assets/icon/app_icon.png" \
    --desktop-file "$APP_DIR/usr/share/applications/jules_client.desktop" \
    --executable "$APP_DIR/usr/bin/$MAIN_EXECUTABLE"

echo "AppImage creation complete."
