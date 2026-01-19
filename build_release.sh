#!/bin/bash

# Default source path
DEFAULT_SRC="$CHROMIUMBUILD/chromium/src"

# Check if an argument is provided, otherwise use the default
if [[ -n "$1" ]]; then
    SRC="$1"
else
    SRC="${DEFAULT_SRC}"
fi

echo "Using Chromium source directory: ${SRC}"

# Check if the source directory exists
if [[ ! -d "${SRC}" ]]; then
    echo "ERROR: Source directory '${SRC}' does not exist."
    echo "Please provide a valid source folder as an argument or modify the DEFAULT_SRC variable in the script."
    exit 1
fi

echo "Changing directory to Chromium source: ${SRC}"
cd "${SRC}" || { echo "Failed to change directory to ${SRC}. Exiting."; exit 1; }

ARCHITECTURE=arm64   # arm64 / x64 / emulator 

echo "Setting up build configuration for architecture: ${ARCHITECTURE}"
if [[ "$ARCHITECTURE" == "arm64" ]]; then
   echo "Building for arm64"
   BUILD_FOLDER="Release_arm64"
elif [[ "$ARCHITECTURE" == "x64" ]]; then
   echo "Building for x64"
   BUILD_FOLDER="Release_X64"
else
   echo "Unknown architecture; EXITING"
   exit 1
fi

gn gen out/Release_arm64

TARGET_DIR="${SRC}/out/${BUILD_FOLDER}"
TARGET_ARGS="${TARGET_DIR}/args.gn"
SOURCE_GN="${CHROMIUMBUILD}/chromium_aaos_gmev/${BUILD_FOLDER}.gn"

if [[ -f "${SOURCE_GN}" && -d "${TARGET_DIR}" ]]; then
    cp -f "${SOURCE_GN}" "${TARGET_ARGS}"
    echo "Copied ${SOURCE_GN} to ${TARGET_ARGS}"
elif [[ -f "${TARGET_ARGS}" ]]; then
    echo "Using existing ${TARGET_ARGS}"
else
    echo "ERROR: ${TARGET_ARGS} not found. Run: gn args out/${BUILD_FOLDER}"
    exit 1
fi

VERSION_FILE="${SRC}/chrome/VERSION"

# Check if the version file exists in the correct location
if [[ -f ${VERSION_FILE} ]]; then
    echo "Updating version file: ${VERSION_FILE}"

    # PATCH (increment patch, not MAJOR)
    PATCH_LINE=$(grep -n '^PATCH=' "${VERSION_FILE}" | cut -d: -f1 || true)
    if [[ -n "${PATCH_LINE}" ]]; then
        PATCH=$(sed -n "${PATCH_LINE}p" < "${VERSION_FILE}")
        patch_version=${PATCH#*=}
        patch_version=$((patch_version + 1))
        sed -i "s/^PATCH=.*$/PATCH=${patch_version}/" "${VERSION_FILE}"
        echo "Updated PATCH version to ${patch_version}"
    else
        echo "PATCH line not found in ${VERSION_FILE}; skipping PATCH update."
    fi
  
    echo "Current version details:"
    cat ${VERSION_FILE}
else
    echo "WARNING: Version file not found in ${VERSION_FILE}. Skipping version update."
fi

# Build
echo "Starting build process. This is a very long process..."
autoninja -C out/${BUILD_FOLDER} chrome_public_bundle
if [[ $? -ne 0 ]]; then
    echo "Build failed. Exiting."
    exit 1
fi
echo "Build completed successfully."

# Sign
AAB_FILE="${SRC}/out/${BUILD_FOLDER}/apks/ChromePublic.aab"

if [[ -f ${AAB_FILE} ]]; then
    echo "Signing AAB file: ${AAB_FILE}"
    apksigner sign --ks $HOME/Documents/KeyStore/store.jks --min-sdk-version 24 ${AAB_FILE}
    if [[ $? -eq 0 ]]; then
        echo "Signing completed successfully."
    else
        echo "Signing failed! You can retry signing without rebuilding by running:"
        echo "  apksigner sign --ks \$HOME/Documents/KeyStore/store.jks --min-sdk-version 24 ${AAB_FILE}"
        exit 1
    fi
else
    echo "ERROR: AAB file not found at ${AAB_FILE}. Exiting."
    exit 1
fi

echo "Script execution completed successfully!"
