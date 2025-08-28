#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.gmmlib"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.libva"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.libva-utils"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.media-driver"
REPO_NAME="os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.onevpl"
#REPO_NAME="os.linux.ubuntu.iot.debianpkgs.libvpl-tools"

#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.gmmlib"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.libva"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.libva-utils"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.media-driver"
REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.onevpl"
#REPO_PATH="https://github.com/mmustaff/os.linux.ubuntu.iot.debianpkgs.libvpl-tools"

#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.gmmlib"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.libva"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.libva-utils"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.media-driver-non-free"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.media-driver"
REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.onevpl-intel-gpu"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.onevpl"
#REPO_UPSTREAM_PATH="https://github.com/intel-innersource/os.linux.ubuntu.iot.debianpkgs.libvpl-tools"

rm -rf $REPO_NAME
git clone $REPO_PATH
cd $REPO_NAME
git remote add upstream $REPO_UPSTREAM_PATH
git fetch upstream
git checkout upstream/noble
