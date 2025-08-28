#!/bin/bash

# Set install directory
export VPL_INSTALL_DIR="$(pwd)/../../_vplinstall"
echo "VPL_INSTALL_DIR set to $VPL_INSTALL_DIR"

# Create install directory if it doesn't exist
if [ ! -d "$VPL_INSTALL_DIR" ]; then
	echo "Creating VPL_INSTALL_DIR at $VPL_INSTALL_DIR..."
	mkdir -p "$VPL_INSTALL_DIR"
fi

# Run bootstrap script
echo "Running bootstrap..."
sudo script/bootstrap
if [ $? -ne 0 ]; then
	echo "Bootstrap failed. Aborting."
	exit 1
fi

# Remove existing _build directory if it exists
if [ -d "_build" ]; then
	echo "Removing existing _build directory..."
	rm -rf _build
fi

# Run cmake configuration
echo "Running cmake configuration..."
cmake -B _build -DCMAKE_PREFIX_PATH="$VPL_INSTALL_DIR"
if [ $? -ne 0 ]; then
	echo "CMake configuration failed. Aborting."
	exit 1
fi
# Build the project
echo "Building project..."
cmake --build _build
if [ $? -ne 0 ]; then
	echo "Build failed. Aborting."
	exit 1
fi

# Prompt user to install
read -p "Build completed successfully. Do you want to install to $VPL_INSTALL_DIR? (y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
	echo "Installing..."
	cmake --install _build --prefix "$VPL_INSTALL_DIR"
else
	echo "Installation skipped."
fi

