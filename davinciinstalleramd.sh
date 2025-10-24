#!/bin/bash

# Script to Install DaVinci Resolve 19 on Ubuntu 22.04/24.04 with ATI/AMD Graphics

set -e  # Exit on any error

# Variables
ACTIVE_USER=$(logname)
HOME_DIR=$(eval echo "~$ACTIVE_USER")
DOWNLOADS_DIR="$HOME_DIR/Downloads"
EXTRACTION_DIR="/opt/resolve"
ZIP_FILE_PATTERN="DaVinci_Resolve_*.zip"

# Step 1: Ensure FUSE and libfuse.so.2 are Installed
echo "Checking for FUSE and libfuse.so.2..."
if ! dpkg -l | grep -q fuse; then
    echo "Installing FUSE..."
    sudo apt update
    sudo apt install -y fuse libfuse2
fi

if [ ! -f /lib/x86_64-linux-gnu/libfuse.so.2 ]; then
    echo "libfuse.so.2 is not found. Installing libfuse2..."
    sudo apt install -y libfuse2
fi

# Step 2: Install Required Qt Libraries
echo "Installing required Qt libraries..."
sudo apt install -y qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5dbus5 \
libxrender1 libxrandr2 libxi6 libxkbcommon-x11-0 libxcb-xinerama0 \
libxcb-xfixes0 qtwayland5 libxcb-glx0 libxcb-util1 mesa-opencl-icd \
mesa-vulkan-drivers libvulkan1 vulkan-tools clinfo

# Step 3: Check if vulkan-tools and mesa-vulkan-drivers are available
echo "Verifying Vulkan tools installation..."
if ! dpkg -l | grep -q vulkan-tools; then
    sudo apt install -y vulkan-tools
fi

if ! dpkg -l | grep -q mesa-vulkan-drivers; then
    sudo apt install -y mesa-vulkan-drivers
fi

# Step 4: Optional ROCm Driver Installation
echo -e "\nROCm drivers are recommended for enhanced AMD GPU support.\nSupported GPUs include:\n- Radeon VII\n- Radeon RX 6800/6800 XT\n- Radeon RX 6900 XT\n- Radeon RX 7900 XT/XTX\n- Radeon Pro W6800\n- Radeon Pro VII"
echo -n "Do you want to install ROCm drivers? (yes/no): "
read install_rocm
if [ "$install_rocm" = "yes" ]; then
    echo "Installing ROCm..."
    sudo apt update
    sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
    sudo apt install -y python3-setuptools python3-wheel
    sudo usermod -a -G render,video "$ACTIVE_USER"

    wget https://repo.radeon.com/amdgpu-install/6.3.3/ubuntu/noble/amdgpu-install_6.3.60303-1_all.deb
    sudo apt install ./amdgpu-install_6.3.60303-1_all.deb
    sudo apt update
    sudo apt install -y amdgpu-dkms rocm
fi

# Step 5: Navigate to Downloads Directory
echo "Navigating to Downloads directory..."
if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Error: Downloads directory not found at $DOWNLOADS_DIR."
    exit 1
fi
cd "$DOWNLOADS_DIR"

# Step 6: Extract DaVinci Resolve ZIP File
echo "Extracting DaVinci Resolve installer..."
ZIP_FILE=$(find . -maxdepth 1 -type f -name "$ZIP_FILE_PATTERN" | head -n 1)
if [ -z "$ZIP_FILE" ]; then
    echo "Error: DaVinci Resolve ZIP file not found in $DOWNLOADS_DIR."
    exit 1
fi

unzip -o "$ZIP_FILE" -d DaVinci_Resolve/
chown -R "$ACTIVE_USER:$ACTIVE_USER" DaVinci_Resolve
chmod -R 774 DaVinci_Resolve

# Step 7: Run the Installer or Extract AppImage
echo "Running the DaVinci Resolve installer..."
cd DaVinci_Resolve
INSTALLER_FILE=$(find . -type f -name "DaVinci_Resolve_*.run" | head -n 1)
if [ -z "$INSTALLER_FILE" ]; then
    echo "Error: DaVinci Resolve installer (.run) file not found."
    exit 1
fi

chmod +x "$INSTALLER_FILE"

export QT_DEBUG_PLUGINS=1
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

if ! SKIP_PACKAGE_CHECK=1 ./$INSTALLER_FILE -a; then
    echo "FUSE is not functional. Extracting AppImage contents..."
    sudo mkdir -p "$EXTRACTION_DIR"
    ./$INSTALLER_FILE --appimage-extract
    sudo mv squashfs-root/* "$EXTRACTION_DIR/"
    sudo chown -R root:root "$EXTRACTION_DIR"
fi

# Step 8: Resolve Library Conflicts
echo "Resolving library conflicts..."
if [ -d "$EXTRACTION_DIR/libs" ]; then
    cd "$EXTRACTION_DIR/libs"
    sudo mkdir -p not_used
    sudo mv libgio* not_used || true
    sudo mv libgmodule* not_used || true
    sudo cp /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 "$EXTRACTION_DIR/libs/" || echo "Warning: libglib-2.0.so.0 not found."
else
    echo "Warning: $EXTRACTION_DIR/libs not found. Skipping conflict resolution."
fi

# Step 9: Cleanup
echo "Cleaning up..."
cd "$DOWNLOADS_DIR"
rm -rf DaVinci_Resolve

echo "DaVinci Resolve installation completed successfully! Please reboot if you installed ROCm."

