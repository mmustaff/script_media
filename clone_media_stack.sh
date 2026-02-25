#!/bin/bash

REPO_FILE="repos.txt"
CONFIG_FILE="config.env"

# Define base repo names and paths
declare -A REPOS=(
    ["gmmlib"]="os.linux.ubuntu.iot.debianpkgs.gmmlib"
    ["libva"]="os.linux.ubuntu.iot.debianpkgs.libva"
    ["libva-utils"]="os.linux.ubuntu.iot.debianpkgs.libva-utils"
    ["media-driver-non-free"]="os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
    ["media-driver"]="os.linux.ubuntu.iot.debianpkgs.media-driver"
    ["vpl-gpu-rt"]="os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
    ["vpl"]="os.linux.ubuntu.iot.debianpkgs.onevpl"
    ["vpl-tool"]="os.linux.ubuntu.iot.debianpkgs.libvpl-tools"
    ["ffmpeg"]="os.linux.ubuntu.iot.debianpkgs.ffmpeg"
    ["gst"]="os.linux.ubuntu.iot.debianpkgs.gstreamer"
    ["gst-base"]="os.linux.ubuntu.iot.debianpkgs.gst-plugins-base"
    ["gst-good"]="os.linux.ubuntu.iot.debianpkgs.gst-plugins-good"
    ["gst-bad"]="os.linux.ubuntu.iot.debianpkgs.gst-plugins-bad"
    ["gst-ugly"]="os.linux.ubuntu.iot.debianpkgs.gst-plugins-ugly"
    #["gst-rtsp-server"]="os.linux.ubuntu.iot.debianpkgs.gst-rtsp-server"
)

# Load config if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    FORKED=false
    ORG="intel-innersource"
fi

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

    # Save config
    echo "FORKED=$FORKED" > "$CONFIG_FILE"
    echo "ORG=$ORG" >> "$CONFIG_FILE"

    echo "Template created. Please review '$REPO_FILE' before running the script again."
    exit 0
fi

# Prompt for branch to checkout
read -p "Enter the branch name to checkout (e.g., noble): " BRANCH

# Read and clone each repo
while IFS='=' read -r name url; do
    if [ -n "$name" ] && [ -n "$url" ]; then

        # Only clone if the directory doesn't exist
        if [ ! -d "$name" ]; then
            echo "Cloning $name from $url..."
            git clone "$url" "$name"
        else
            echo "Directory $name already exists. Skipping clone for $name."
        fi

        cd "$name" || { echo "Failed to enter directory $name"; continue; }

        if [ "$FORKED" = true ]; then
            # Add upstream and fetch
            UPSTREAM_URL="https://github.com/intel-innersource/${REPOS[$name]}.git"
            if git remote get-url upstream >/dev/null 2>&1; then
                echo "Upstream remote already exists."
            else
                echo "Adding upstream remote: $UPSTREAM_URL"
                git remote add upstream "$UPSTREAM_URL"
            fi
            git fetch upstream
            git fetch origin

            # Checkout the branch from origin, then bring in latest upstream changes and push back to origin.
            if ! git show-ref --verify --quiet "refs/remotes/upstream/$BRANCH"; then
                echo "Branch upstream/$BRANCH not found. Skipping branch sync."
            else
                if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
                    echo "Checking out $BRANCH from origin/$BRANCH..."
                    git checkout -B "$BRANCH" "origin/$BRANCH"
                else
                    echo "origin/$BRANCH not found; creating $BRANCH from upstream/$BRANCH and pushing to origin..."
                    git checkout -B "$BRANCH" "upstream/$BRANCH"
                    git push -u origin "$BRANCH"
                fi

                echo "Updating $BRANCH from upstream/$BRANCH (fast-forward only)..."
                if git merge --ff-only "upstream/$BRANCH"; then
                    echo "Pushing updated $BRANCH back to origin..."
                    git push origin "$BRANCH"
                else
                    echo "WARNING: Cannot fast-forward $BRANCH from upstream/$BRANCH (diverged). Resolve manually."
                fi
            fi
        else
            # Checkout branch directly
            echo "Checking out $BRANCH..."
            git checkout "$BRANCH"
        fi

        # Update git submodule
        git submodule update --init

        # Pull latest changes if 'source' directory exists
        if [ -d "source" ]; then
            cd source
            git pull
            cd ..
        fi

        cd ..
    fi
done < "$REPO_FILE"

echo "✅All repositories processed."
