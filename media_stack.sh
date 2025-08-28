#!/bin/bash

# [EDIT HERE] Log printing behaviour
# set -x # Print executed commands - for debug purposes
# exec 2>/dev/null # Suppress error messages - only for cleaner logs
# exec > >(tee -a media_stack_installer.log) 2>&1 # Redirect all stdout and stderr to a log file


# FUNCTIONS

print_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -h, --help                Show this help message and exit
  -o, --opensource          Use opensource repositories
  -u, --ubuntu              Use Ubuntu BKC, requires 1Source setup
  -y, --yocto               Use Yocto recipes, requires 1Source setup
  -f, --ffmpeg              Install FFmpeg application
  -g, --gstreamer           Install GStreamer application
  -d, --debug               Add flags to install debug builds
  -b, --branch BRANCH       Specify branch to checkout (default: noble, only for --ubuntu)
  -c, --use-commit-list     Use specific commit list (from COMMIT_LIST array)
  -l, --log FILE            Log output to FILE, suppresses colored text output

Examples:
  $0 --ubuntu --branch noble --use-commit-list --debug
  $0 -o -f -g -d

Tips:
    Find editable variables in the script with [EDIT HERE] tags.

EOF
}

parse_args() {
    # Default values
    USE_OPENSOURCE=0
    USE_UBUNTU=0
    USE_YOCTO=0
    USE_FFMPEG=0
    USE_GSTREAMER=0
    BRANCH="noble"
    USE_COMMITS=0
    USE_DEBUG_BUILD=0
    CREATE_LOGS=0
    LOG_FILE="media_stack.log"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h | --help)
            print_help
            exit 0
            ;;
        -o | --opensource)
            USE_OPENSOURCE=1
            ;;
        -u | --ubuntu)
            USE_UBUNTU=1
            ;;
        -y | --yocto)
            USE_YOCTO=1
            ;;
        -f | --ffmpeg)
            USE_FFMPEG=1
            ;;
        -g | --gstreamer)
            USE_GSTREAMER=1
            ;;
        -b | --branch)
            shift
            BRANCH="$1"
            ;;
        --branch=*)
            BRANCH="${1#*=}"
            ;;
        -c | --use-commit-list)
            USE_COMMITS=1
            ;;
        -d | --debug)
            USE_DEBUG_BUILD=1
            ;;
        -l | --log)
            CREATE_LOGS=1
            shift
            LOG_FILE="$1"
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        esac
        shift
    done

    if [[ $USE_OPENSOURCE -eq 0 && $USE_UBUNTU -eq 0 && $USE_YOCTO -eq 0 ]]; then
        echo "Error: You must specify one: --opensource, --ubuntu, or --yocto."
        print_help
        exit 1
    fi
}

setup_vars() {
    # open source repositories
    if [ $USE_OPENSOURCE == 1 ]; then
        REPO_LIST+=(
            "libva"
            "libva-utils"
            "gmmlib"
            "media-driver"
            "vpl-gpu-rt"
            "libvpl"
            "libvpl-tools"
        )
        if [[ $USE_FFMPEG -eq 1 ]]; then REPO_LIST+=("FFmpeg"); fi
        if [[ $USE_GSTREAMER -eq 1 ]]; then REPO_LIST+=("gstreamer"); fi
    fi

    # ubuntu bkc repositories
    if [ $USE_UBUNTU -eq 1 ]; then
        REPO_LIST+=(
            "os.linux.ubuntu.iot.debianpkgs.libva"
            "os.linux.ubuntu.iot.debianpkgs.libva-utils"
            "os.linux.ubuntu.iot.debianpkgs.gmmlib"
            "os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
            "os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
            "os.linux.ubuntu.iot.debianpkgs.onevpl"
            "os.linux.ubuntu.iot.debianpkgs.libvpl-tools"
        )
        if [[ $USE_FFMPEG -eq 1 ]]; then
            REPO_LIST+=(
                "os.linux.ubuntu.iot.debianpkgs.ffmpeg"
            )
        fi
        if [[ $USE_GSTREAMER -eq 1 ]]; then
            REPO_LIST+=(
                "os.linux.ubuntu.iot.debianpkgs.gstreamer"
                "os.linux.ubuntu.iot.debianpkgs.gst-plugins-base"
                "os.linux.ubuntu.iot.debianpkgs.gst-plugins-good"
                "os.linux.ubuntu.iot.debianpkgs.gst-plugins-bad"
                "os.linux.ubuntu.iot.debianpkgs.gst-plugins-ugly"
            )
        fi
    fi

    # yocto bkc repositories
    if [ $USE_YOCTO -eq 1 ]; then
        # clone yocto repos

        cd $WORK_DIR
        git clone https://github.com/YoeDistro/meta-intel.git
        git clone https://github.com/intel-innersource/os.linux.yocto.build.meta-intel-iot-main.git

        # copy media stack patches to the patches directory

        mkdir patches

        cd $WORK_DIR/meta-intel/
        cp recipes-graphics/libva/files/* $WORK_DIR/patches
        cp recipes-graphics/gmmlib/files/* $WORK_DIR/patches
        cp recipes-multimedia/libva/files/* $WORK_DIR/patches
        cp recipes-multimedia/vpl/files/* $WORK_DIR/patches

        cd $WORK_DIR/os.linux.yocto.build.meta-intel-iot-main/
        cp recipes-graphics/libva/files/* $WORK_DIR/patches
        cp recipes-graphics/gmmlib/files/* $WORK_DIR/patches
        cp recipes-multimedia/libva/files/* $WORK_DIR/patches
        cp recipes-multimedia/vpl/files/* $WORK_DIR/patches

        cd $WORK_DIR

        REPO_LIST+=(
            "libva"
            "libva-utils"
            "gmmlib"
            "media-driver"
            "vpl-gpu-rt"
            "libvpl"
            "libvpl-tools"
        )
        # TODO: add ffmpeg and gstreamer repos

        BB_PATH+=(
            "recipes-graphics/libva/libva-intel_*.bb"
            "recipes-graphics/libva/libva-intel-utils_*.bb"
            "recipes-graphics/gmmlib/gmmlib_*.bb"
            "recipes-multimedia/libva/intel-media-driver_*.bb"
            "recipes-multimedia/vpl/vpl-gpu-rt_*.bb"
            "recipes-multimedia/vpl/libvpl_*.bb"
            "recipes-multimedia/vpl/libvpl-tools_*.bb"
        )

    fi

    # add debug flags, if requested
    if [[ $USE_DEBUG_BUILD -eq 1 ]]; then
        setup_meson+=" -Dbuildtype=debug"
        setup_cmake+=" -DCMAKE_BUILD_TYPE=Debug"
        setup_autogen+=" --enable-debug"
        # setup_configure+=" --enable-debug"
    fi

    #[EDIT HERE] commit versions of media stacks 
    if [ $USE_COMMITS -eq 1 ]; then
        COMMIT_LIST+=( 
            "527814f" # libva
            "38522a5" # libva-utils
            "52930b6" # gmmlib
            "5305e5d" # media-driver
            "" # vpl-gpu-rt / onevpl-intel-gpu
            "" # libvpl
            "" # libvpl-tools
        )
        if [[ $USE_FFMPEG -eq 1 ]]; then
            COMMIT_LIST+=(
                "" # ffmpeg
            )
        fi
        if [[ $USE_GSTREAMER -eq 1 ]]; then
            COMMIT_LIST+=(
                "" # gstreamer1.0 / gstreamer monorepo
                "" # gst-plugins-base
                "" # gst-plugins-good
                "" # gst-plugins-bad
                "" # gst-plugins-ugly
            )
        fi
    fi
}

setup_env() {

    # SETUP SCRIPT

    SETUP_SCRIPT_CONTENT='
#!/bin/bash
# WORKING DIRECTORY
WORK_DIRNAME=$(pwd)
export WORK_DIR=$WORK_DIRNAME

# Common
export PATH=$WORK_DIR/usr/bin/:$PATH
export PKG_CONFIG_PATH=$WORK_DIR/usr/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=$WORK_DIR/usr/lib:$LD_LIBRARY_PATH

# Media driver
export LIBVA_DRIVERS_PATH=$WORK_DIR/usr/lib/dri
export LIBVA_DRIVER_NAME=iHD

# OneVPL
export LD_LIBRARY_PATH=$WORK_DIR/usr/lib/vpl-tools:$LD_LIBRARY_PATH
export ONEVPL_SEARCH_PATH=$WORK_DIR/usr/lib
export ONEVPL_PRIORITY_PATH=$ONEVPL_SEARCH_PATH

# GST
export LD_LIBRARY_PATH=$WORK_DIR/usr/lib/gstreamer-1.0:$LD_LIBRARY_PATH
export GST_GL_PLATFORM=egl
export GST_GL_API=gles2

if pgrep -x "weston" >/dev/null; then
    export XDG_RUNTIME_DIR="/tmp"
    export WAYLAND_DISPLAY="wayland-1"
else
    export XDG_RUNTIME_DIR="/run/user/1000"
    export WAYLAND_DISPLAY="wayland-0"
fi

# Proxy
export http_proxy=http://proxy-us.intel.com:912
export https_proxy=http://proxy-us.intel.com:912
'

    if [[ -z $(ls | grep "setup.sh") ]]; then
        echo "No setup.sh found, creating one..."
        echo "$SETUP_SCRIPT_CONTENT" >setup.sh
        chmod +x setup.sh
        sudo apt-get install libxcb-dri3-dev libxcb-present-dev meson -y
    fi
    echo "Sourcing setup.sh..."
    source setup.sh
    printenv | grep PATH
}

clone() {
    header "$1"
    cd $WORK_DIR
    if [[ $1 == *"debianpkgs"* ]]; then
        git clone --recurse-submodules https://github.com/intel-innersource/$1.git
    elif [[ $1 == "gstreamer" ]]; then
        git clone https://gitlab.freedesktop.org/gstreamer/$1.git
    elif [[ $1 == *"gst"* ]]; then
        git clone https://salsa.debian.org/gstreamer-team/$1.git
    elif [[ $1 == "FFmpeg" ]]; then
        git clone https://github.com/FFmpeg/$1.git
    else
        git clone https://github.com/intel/$1.git
    fi
}

checkout() {
    header "$1"
    cd $WORK_DIR/$1
    if [[ $USE_OPENSOURCE -eq 1 ]]; then
        if [[ $USE_COMMITS -eq 1 && -n ${COMMIT_LIST[$2]} && ${COMMIT_LIST[$2]} != "" ]]; then git checkout ${COMMIT_LIST[$2]}; fi
    fi
    if [[ $USE_UBUNTU -eq 1 ]]; then
        git checkout $BRANCH
        if [[ $USE_COMMITS -eq 1 && -n ${COMMIT_LIST[$2]} && ${COMMIT_LIST[$2]} != "" ]]; then git checkout ${COMMIT_LIST[$2]}; fi
    fi
    if [[ $USE_YOCTO -eq 1 ]]; then
        if [[ $USE_COMMITS -eq 1 && -n ${COMMIT_LIST[$2]} && ${COMMIT_LIST[$2]} != "" ]]; then git checkout ${COMMIT_LIST[$2]}; fi
        cat $WORK_DIR/meta-intel/${BB_PATH[$2]} | grep "SRCREV" | sed 's/^SRCREV = "\(.*\)"/\1/' | xargs git checkout
    fi
}

patch() {
    header "$1"
    cd $WORK_DIR/$1
    if [ $USE_UBUNTU -eq 1 ]; then
        cd debian/patches/ && cat series | grep "\.patch" | sed 's/^/git am /' >patchlist.sh &&
            chmod +x ./patchlist.sh && cp * ../../source &&
            cd ../../source && ./patchlist.sh
    fi
    if [[ $USE_YOCTO -eq 1 ]]; then
        cat $WORK_DIR/meta-intel/${BB_PATH[$2]} | grep "\.patch" > patchlist.txt
        cat $WORK_DIR/os.linux.yocto.build.meta-intel-iot-main/${BB_PATH[$2]}append | grep "\.patch" >> patchlist.txt
        cat patchlist.txt | sed -e 's/^SRC_URI:append = "//' -e 's/^[ \t]*//' -e 's/file:\/\///' -e 's/\\$//' -e 's|^|git am $WORK_DIR/patches/|' > patchlist.sh
        chmod +x patchlist.sh && ./patchlist.sh
    fi
}

build() {
    header "$1"
    cd $WORK_DIR/$1
    if [ $USE_UBUNTU -eq 1 ]; then cd source; fi

    case $1 in
    *"gst"*)
        eval "$setup_meson"
        meson compile -C build
        meson install -C build
        ;;
    *"libva"* | *"libva-utils"*)
        eval "$setup_autogen"
        make -j8 && make install
        ;;
    *"ffmpeg"* | *"FFmpeg"*)
        eval "$setup_configure"
        make -j8 && make install
        ;;
    *)
        mkdir build && cd build
        eval "$setup_cmake"
        make -j8 && make install
        ;;
    esac
}

header() {
    cols=$(tput cols)
    word="   $1   "
    padding=$(((cols - ${#word}) / 2))
    printf '%*s' "$padding" '' | tr ' ' '#' && printf '%s' "$word" && printf '%*s\n' $((cols - padding - ${#word})) '' | tr ' ' '#'
}

# MAIN ENTRY

parse_args "$@"

if [[ $CREATE_LOGS -eq 1 ]]; then exec > >(tee -a "$LOG_FILE") 2>&1 ; fi

header "SETUP ENV"
setup_env

# GLOBAL VARIABLES

declare -a REPO_LIST=()
declare -a BB_PATH=()
declare -a COMMIT_LIST=()

#[EDIT HERE] build setup commands
setup_meson="meson setup build --wipe -Dprefix=$WORK_DIR/usr -Dlibdir=$WORK_DIR/usr/lib -Dgst-plugins-bad:msdk=enabled -Dgst-plugins-bad:mfx_api=oneVPL"
setup_cmake="cmake -DCMAKE_INSTALL_PREFIX=$WORK_DIR/usr .."
setup_autogen="./autogen.sh --prefix=$WORK_DIR/usr"
setup_configure="./configure --prefix=$WORK_DIR/usr --libdir=$WORK_DIR/usr/lib --enable-vaapi --enable-libvpl --enable-shared --disable-stripping || ./configure --prefix=$WORK_DIR/usr --libdir=$WORK_DIR/usr/lib --enable-vaapi --enable-libvpl --enable-shared --disable-stripping --disable-x86asm"

setup_vars

header "CLONING"
for i in "${!REPO_LIST[@]}"; do clone "${REPO_LIST[i]}"; done

header "CHECKOUT"
for i in "${!REPO_LIST[@]}"; do checkout "${REPO_LIST[i]}" "$i"; done

header "PATCHING"
for i in "${!REPO_LIST[@]}"; do patch "${REPO_LIST[i]}" "$i"; done

header "BUILDING"
for i in "${!REPO_LIST[@]}"; do build "${REPO_LIST[i]}"; done