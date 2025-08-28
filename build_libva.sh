#!/bin/bash

echo "Select your Linux distribution family:"
echo "1) Debian (e.g., Ubuntu)"
echo "2) RPM (e.g., Fedora, CentOS)"
read -p "Enter choice [1 or 2]: " distro

echo "Select build method:"
echo "1) Autogen"
echo "2) Meson"
read -p "Enter choice [1 or 2]: " method

# Set prefix and libdir based on distro
if [ "$distro" == "1" ]; then
	prefix="/usr"
	libdir="/usr/lib/x86_64-linux-gnu"
elif [ "$distro" == "2" ]; then
	prefix="/usr"
	libdir="/usr/lib64"
else
	echo "Invalid distro selection. Exiting."
	exit 1
fi

# Run selected build method
if [ "$method" == "1" ]; then
	echo "Running Autogen build..."
	./autogen.sh --prefix="$prefix" --libdir="$libdir"
	if [ $? -ne 0 ]; then
		echo "Autogen configuration failed. Aborting."
		exit 1
	fi

	make -j"$(nproc)"
	if [ $? -ne 0 ]; then
		echo "Make failed. Aborting."
		exit 1
	fi
	read -p "Build completed successfully. Do you want to install? (y/n): " choice
	if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
		sudo make install
	else
		echo "Installation skipped."
	fi

elif [ "$method" == "2" ]; then
	echo "Running Meson build..."

	# Clean up old build directory
	if [ -d "build" ]; then
		echo "Removing existing build directory..."
		rm -rf build
	fi

	mkdir build && cd build
	meson .. -Dprefix="$prefix" -Dlibdir="$libdir"
	if [ $? -ne 0 ]; then
		echo "Meson configuration failed. Aborting."
		exit 1
	fi

	ninja
	if [ $? -ne 0 ]; then
		echo "Ninja build failed. Aborting."
		exit 1
	fi

	read -p "Build completed successfully. Do you want to install? (y/n): " choice
	if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
		sudo ninja install
	else
		echo "Installation skipped."
	fi
else
	echo "Invalid build method selection. Exiting."
	exit 1
fi

