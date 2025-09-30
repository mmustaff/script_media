#!/bin/bash

REPO_FILE="repos.txt"

#Define base repo names and paths
declare -A REPOS=(
	["gmmlib"]="os.linux.ubuntu.iot.debianpkgs.gmmlib"
	["libva"]="os.linux.ubuntu.iot.debianpkgs.libva"
	["libva-utils"]="os.linux.ubuntu.iot.debianpkgs.libva-utils"
	["media-driver"]="os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
	["vpl-gpu-rt"]="os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
	["libvpl"]="os.linux.ubuntu.iot.debianpkgs.onevpl"
	["libvpl-tool"]="os.linux.ubuntu.iot.debianpkgs.libvpl-tools"
)

# Flags 
FORKED=false
ORG="intel-innersource"

# If repos.txt doesn't exist, prompt user
if [ ! -f "$REPO_FILE" ]; then
	echo "Repository list file not found."

	# Ask if using Intel Innersource
	read -p "Use Intel Innersource repositories? (y/n): " use_innersource
	if [[ "$use_innersource" =~ ^[Nn]$ ]]; then
		# Ask if using personal fork
		read -p "Use personal forked repositories? (y/n): " use_fork
		if [[ "$use_fork" =~ ^[Yy]$ ]]; then
			read -p "Enter your GitHub user ID: " USER_ID
			ORG="$USER_ID"
			FORKED=true
		else
			echo "No valid repository source selected. Exiting."
			exit 1
		fi
	fi

	# Create repos.txt
	echo "Creating template '$REPO_FILE'..."
	> "$REPO_FILE"
	for repo in "${!REPOS[@]}"; do
		echo "$repo=https://github.com/$ORG/${REPOS[$repo]}.git" >> "$REPO_FILE"
	done
	echo "Template created. Please review '$REPO_FILE' before running the script again."
	exit 0
fi


# Prompt for branch to checkout
read -p "Enter the branch name to checkout (e.g., noble): " BRANCH

# Read and clone each repo
while IFS='=' read -r name url; do
	if [ -n "$name" ] && [ -n "$url" ]; then
		
		# Extract actual directory name from URL
		repo_dir=$(basename "$url" .git)
		
		# Only clone if the directory doesn't exist
		if [ ! -d "$repo_dir" ]; then
			echo "Cloning $name from $url..."
			git clone "$url"
		else
			echo "Directory $repo_dir already exists. Skipping clone for $name."
		fi
		
		cd "$repo_dir" || { echo "Failed to enter directory $repo_dir"; continue; }
		
		if $FORKED; then
			# Add upstream and fetch
			UPSTREAM_URL="https://github.com/intel-innersource/${REPOS[$name]}.git"
			echo "Adding upstream remote: $UPSTREAM_URL"
			git remote add upstream "$UPSTREAM_URL"
			git fetch upstream
			
			# Checkout upstream branch
			echo "Checking out upstream/$BRANCH..."
			git checkout -b "$BRANCH" "upstream/$BRANCH"
		else
			# Checkout branch directly
			echo "Checking out $BRANCH..."
			git checkout "$BRANCH"
		fi

		#Update git submodule
		git submodule update --init
		cd source
		git pull

		cd ../..
	fi
done < "$REPO_FILE"

echo "All repositories processed."
