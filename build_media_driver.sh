#!/bin/bash

# Check if the build directory exists
if [ ! -d "build" ]; then
	    echo "Creating build directory..."
	        mkdir build
fi

# Navigate into the build directory
cd build || exit

# Run cmake and make
echo "Running cmake..."
cmake ..

echo "Building with make..."
make -j"$(nproc)"
