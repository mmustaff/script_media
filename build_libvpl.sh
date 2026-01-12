#!/bin/bash

# Remove existing _build directory if it exists
if [ -d "_build" ]; then
	echo "Removing existing _build directory..."
	rm -rf _build
fi

mkdir _build && cd _build

# Run cmake configuration
echo "Running cmake configuration..."
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_EXAMPLES=ON ..
if [ $? -ne 0 ]; then
	echo "CMake configuration failed. Aborting."
	exit 1
fi
# Build the project
echo "Building project..."
make -j"$(nproc)"
if [ $? -ne 0 ]; then
	echo "Build failed. Aborting."
	exit 1
fi

# Prompt user to install
read -p "Build completed successfully. Do you want to install to $VPL_INSTALL_DIR? (y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
	echo "Installing..."
	sudo make install
else
	echo "Installation skipped."
fi

