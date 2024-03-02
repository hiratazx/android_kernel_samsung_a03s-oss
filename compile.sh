#!/bin/bash

# Ask the user for Device Name, Codename, and Maintainer for the kernel
echo "Enter Device Name for the kernel:"
read device_name

echo "Enter Codename(s) for the kernel (up to 5, separate by comma if more than one):"
read codenames

# Convert comma-separated codenames to an array
IFS=',' read -ra codename_array <<< "$codenames"

# Ensure there are at most 5 codenames
codename_count=${#codename_array[@]}
if [ "$codename_count" -gt 5 ]; then
    echo "Error: You can only provide up to 5 codenames for the kernel."
    exit 1
fi

echo "Enter Maintainer for the kernel:"
read maintainer

# Get the system's architecture
arch=$(uname -m)

# Check if the architecture is not x86 or x86-64
if [ "$arch" != "x86_64" ] && [ "$arch" != "x86" ]; then
  echo "Unsupported architecture: $arch"
  exit 1
fi

#!/bin/bash

# Function to check if a command is available
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install packages on Debian-based distributions
install_debian_packages() {
  sudo apt update
  sudo apt install -y flex bc
}

# Function to install packages on Red Hat-based distributions
install_redhat_packages() {
  sudo dnf install -y flex bc   # For Fedora, CentOS, RHEL
  #sudo yum install -y flex bc  # For older versions of CentOS and RHEL
}

# Function to install packages on Arch Linux
install_arch_packages() {
  sudo pacman -Syu --noconfirm flex bc
}

# Check if the required packages are already installed
if ! command_exists flex || ! command_exists bc; then
  # Detect the Linux distribution
  if command_exists lsb_release; then
    distro=$(lsb_release -si)
  else
    distro=$(cat /etc/*-release | grep '^ID=' | awk -F'=' '{print tolower($2)}' | tr -d '"')
  fi

  # Install packages based on the detected distribution
  case $distro in
    debian|ubuntu|Ubuntu)
      install_debian_packages
      ;;
    fedora|centos|rhel)
      install_redhat_packages
      ;;
    arch)
      install_arch_packages
      ;;
    *)
      echo "Unsupported distribution: $distro"
      echo "Please install it manually!"
      echo "Packages: bc flex"
      exit 1
      ;;
  esac
fi

# Clone GCC & Proton Clang.
if [ -d "$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/" ]; then
  echo "GCC exist"
else
  echo "GCC not exist"
  echo "Downloading GCC Toolchain!"
  wget -q --show-progress https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/0a0604336d4d1067aa1aaef8d3779b31fcee841d.tar.gz
  mkdir -pv $(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/
  tar xfv 0a0604336d4d1067aa1aaef8d3779b31fcee841d.tar.gz -C $(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/
  rm -v 0a0604336d4d1067aa1aaef8d3779b31fcee841d.tar.gz
fi

if [ -d "$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/" ]; then
  echo "Clang exist"
else
  echo "Clang not exist"
  echo "Downloading Clang Toolchain!"
  wget -q --show-progress https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-11.0.0_r3/clang-r383902.tar.gz
  mkdir -pv $(pwd)/toolchain/clang/host/linux-x86/clang-r383902/
  tar xfv clang-r383902.tar.gz -C $(pwd)/toolchain/clang/host/linux-x86/clang-r383902/
  rm -v clang-r383902.tar.gz
fi

# Export ARCH/SUBARCH flags.
export ARCH="arm64"
export SUBARCH="arm64"

# User config
export KBUILD_BUILD_USER=ItzKaguya
export KBUILD_BUILD_HOST=ItzKaguya-PC

# Export Android Platform flags
export ANDROID_MAJOR_VERSION=t
export PLATFORM_VERSION=13

# Export toolchain/clang/llvm flags
export CROSS_COMPILE="$(pwd)/toolchain/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-androidkernel-"
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CC="$(pwd)/toolchain/clang/host/linux-x86/clang-r383902/bin/clang"
export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

echo "List of available defconfigs:"
ls arch/$ARCH/configs

echo "Enter the defconfig you want to use (default: yukiprjkt_defconfig):"
read chosen_defconfig

defconfig=${chosen_defconfig:-yukiprjkt_defconfig}

ram=$(free -h --si | awk '/^Mem:/ {print $2}')

current_user=$(whoami)

start_time=$(date +%s)

threads=$(nproc)
build_command="make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y -j$threads"

if [ "$maintainer" = "ItzKaguya" ]; then
    zip_name="ItzKaguya-Kernel-${codename_array[0]}.zip"
else
    zip_name="ItzKaguya-Kernel-${codename_array[0]}-$maintainer.zip"
fi

backup_path="$(pwd)/kernel-backup"

if [ -e "out/arch/arm64/boot/Image.gz" ]; then
    echo "Creating backup of entire out/arch/arm64/boot folder"
    mkdir -p "$backup_path"
    cp -r out/arch/arm64/boot "$backup_path/backup-$(date +'%Y%m%d%H%M%S')"

    echo "Removing existing out/arch/arm64/boot folder after backup"
    rm -rf out/arch/arm64/boot
fi

# Build
echo ""
echo "Starting Building"
echo "Build Started on $(date '+%A, %d %B %Y') - $(TZ=Asia/Makassar date '+%T %Z')"
echo "Defconfig : $defconfig"
echo "Maintainer : $maintainer"
echo "User : $(whoami)"
echo "Build Threads : $threads"
echo "RAM : $ram"
make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y $defconfig

build_start_time=$(date +%s)
$build_command
build_end_time=$(date +%s)
elapsed_time=$((build_end_time - build_start_time))
build_duration=$(printf '%02d:%02d:%02d' $((elapsed_time / 3600)) $((elapsed_time % 3600 / 60)) $((elapsed_time % 60)))

echo "Build Ended on $(date '+%A, %d %B %Y') - $(TZ=Asia/Makassar date '+%T %Z')"

if [ -e "out/arch/arm64/boot/Image.gz" ]; then
    echo "Build Success! Build time elapsed: $build_duration"
    echo "You can check the result in out/arch/arm64/boot/"

    anykernel_path="$(pwd)/out/AnyKernel3"

    echo "Cloning AnyKernel3 repository"
    rm -rf "$anykernel_path"
    git clone https://github.com/nnhra/ItzKaguya-AnyKernel3 "$anykernel_path"

    anykernel_script="$anykernel_path/anykernel.sh"

    sed -i "s/kernel\.string=.*/kernel.string=ItzKaguya Kernel for $device_name/" "$anykernel_script"

    for i in "${!codename_array[@]}"; do
        index=$((i + 1))
        sed -i "s/device\.name$index=.*/device.name$index=${codename_array[i]}/" "$anykernel_script"
    done

    for i in $(seq $((codename_count + 1)) 5); do
        sed -i "s/device\.name$i=.*/device.name$i=/" "$anykernel_script"
    done

    cd "$anykernel_path"

    zip -0 -r "$zip_name" *
    cd ../..

    release_path="$(pwd)/out/kernel-release/$(date +'%Y%m%d%H%M%S')"
    mkdir -p "$release_path"
    mv "$anykernel_path/$zip_name" "$release_path"

    echo "Restoring AnyKernel3 repository"
    cd "$anykernel_path"
    git restore anykernel.sh

    echo "AnyKernel3 script updated for $device_name (${codename_array[0]}) maintained by $maintainer."
    echo "Zip file created: $release_path/$zip_name"
    echo "Flashable zip file created! Check the results on out/kernel-release/"
else
    echo "Build Failed! Build time elapsed: $build_duration"
fi
