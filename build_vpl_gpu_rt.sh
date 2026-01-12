#!/bin/bash

# Check and remove existing build directory
if [ -d "build" ]; then
	echo "Removing existing build directory..."
	rm -rf build
fi

# Create and enter build directory
mkdir build && cd build

# Run cmake and check for errors
echo "Running cmake..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_TESTS=ON -DBUILD_TOOLS=ON
if [ $? -ne 0 ]; then
	echo "CMake configuration failed. Aborting."
	exit 1
fi

# Run make and check for errors
echo "Running make..."
make -j"$(nproc)"
if [ $? -ne 0 ]; then
	echo "Make failed. Aborting."
	exit 1
fi

# Prompt user to install
read -p "Build completed successfully. Do you want to install? (y/n): " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
	echo "Installing..."
	sudo make install
else
	echo "Installation skipped."
fi
