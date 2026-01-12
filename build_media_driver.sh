#!/bin/bash

# Define log file
LOG_FILE="build_log.txt"

# Check if the build directory exists
if [ ! -d "build" ]; then
	echo "Creating build directory..."
	mkdir build
else
	echo "Deleting existing and recreate build directory"
	rm -rf build
	mkdir build
fi

# Navigate into the build directory
cd build || exit

# Run cmake and make
echo "Running cmake..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_DRIVER_SYSCONF=OFF -DENABLE_KERNELS=ON -DENABLE_NONFREE_KERNELS=ON -DBUILD_CMRTLIB=OFF -DMEDIA_BUILD_FATAL_WARNINGS=OFF | tee -a "$LOG_FILE"

echo "Building with make..."
make -j"$(nproc)" 2>&1 | tee -a "$LOG_FILE"


# Check if make was successful
if [ $? -eq 0 ]; then
	echo ""
	read -p "✅ Build completed successfully. Do you want to run 'make install'? (y/n): " choice
	if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
		echo "Running make install..."
		sudo make install 2>&1 | tee -a "$LOG_FILE"
	else
		echo "Skipping make install."
	fi
else
	echo "❌ Build failed. Check '$LOG_FILE' for details."
fi
