#############################################################
#
#  build.bash
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
#  KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
#  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
#  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
#  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#  IN THE SOFTWARE.
#
#  (c) VojtaStavik.com, 2018
#
#############################################################

#!/bin/bash

# Exit this script immediatelly if any of the commands fails
set -e

PROJECT_NAME=ExampleApp

# The product of this script. This is the actual app bundle!
BUNDLE_DIR=${PROJECT_NAME}.app

# A place for any temporary files needed for building
TEMP_DIR=_BuildTemp

# Check for --device flag
if [ "$1" = "--device" ]; then
  BUILDING_FOR_DEVICE=true
fi

# Print the current target architecture
if [ "${BUILDING_FOR_DEVICE}" = true ]; then
  echo 👍 Bulding ${PROJECT_NAME} for device
else
  echo 👍 Bulding ${PROJECT_NAME} for simulator
fi


echo

#############################################################
echo → Step 1: Prepare Working Folders
#############################################################

# Delete existing folders from previous builds
rm -rf ${BUNDLE_DIR}
rm -rf ${TEMP_DIR}

mkdir ${BUNDLE_DIR}
echo ✅ Create ${BUNDLE_DIR} folder

mkdir ${TEMP_DIR}
echo ✅ Create ${TEMP_DIR} folder



echo

#############################################################
echo → Step 2: Compile Swift Files
#############################################################

# The root directory of the project sources
SOURCE_DIR=ExampleApp

# All Swift files in the source directory
SWIFT_SOURCE_FILES=${SOURCE_DIR}/*.swift

# Target architecture we want to build for
TARGET=""

# Path to the SDK we want to use for compiling
SDK_PATH=""

if [ "${BUILDING_FOR_DEVICE}" = true ]; then
  # Building for device
  TARGET=arm64-apple-ios12.0
  SDK_PATH=$(xcrun --show-sdk-path --sdk iphoneos)

  # The folder inside the app bundle where we
  # will copy all required dylibs
  FRAMEWORKS_DIR=Frameworks

  # Set additional flags for the compiler
  OTHER_FLAGS="-Xlinker -rpath -Xlinker @executable_path/${FRAMEWORKS_DIR}"

else
  # Building for simulator
  TARGET=x86_64-apple-ios12.0-simulator
  SDK_PATH=$(xcrun --show-sdk-path --sdk iphonesimulator)
fi

swiftc ${SWIFT_SOURCE_FILES} \
  -sdk ${SDK_PATH} \
  -target ${TARGET} \
  -emit-executable \
  ${OTHER_FLAGS} \
  -o ${BUNDLE_DIR}/${PROJECT_NAME}

echo ✅ Compile Swift source files ${SWIFT_SOURCE_FILES}



echo

#############################################################
echo → Step 3: Compile Storyboards
#############################################################

# All storyboards in the Base.lproj directory
STORYBOARDS=${SOURCE_DIR}/Base.lproj/*.storyboard

# The output folder for compiled storyboards
STORYBOARD_OUT_DIR=${BUNDLE_DIR}/Base.lproj

mkdir -p ${STORYBOARD_OUT_DIR}
echo ✅ Create ${STORYBOARD_OUT_DIR} folder

for storyboard_path in ${STORYBOARDS}; do
  ibtool $storyboard_path \
    --compilation-directory ${STORYBOARD_OUT_DIR}

  echo ✅ Compile $storyboard_path
done



echo

#############################################################
echo → Step 4: Process and Copy Info.plist
#############################################################

# The location of the original Info.plist file
ORIGINAL_INFO_PLIST=${SOURCE_DIR}/Info.plist

# The location of the temporary Info.plist copy for editing
TEMP_INFO_PLIST=${TEMP_DIR}/Info.plist

# The location of the processed Info.plist in the app bundle
PROCESSED_INFO_PLIST=${BUNDLE_DIR}/Info.plist

# The bundle identifier of the resulting app
APP_BUNDLE_IDENTIFIER=com.vojtastavik.${PROJECT_NAME}

cp ${ORIGINAL_INFO_PLIST} ${TEMP_INFO_PLIST}
echo ✅ Copy ${ORIGINAL_INFO_PLIST} to ${TEMP_INFO_PLIST}


# A command line tool for dealing with plists
PLIST_BUDDY=/usr/libexec/PlistBuddy

# Set the correct name of the executable file we created at step 2
${PLIST_BUDDY} -c "Set :CFBundleExecutable ${PROJECT_NAME}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleExecutable to ${PROJECT_NAME}

# Set a valid bundle indentifier
${PLIST_BUDDY} -c "Set :CFBundleIdentifier ${APP_BUNDLE_IDENTIFIER}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleIdentifier to ${APP_BUNDLE_IDENTIFIER}

# Set the proper bundle name
${PLIST_BUDDY} -c "Set :CFBundleName ${PROJECT_NAME}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleName to ${PROJECT_NAME}

# Copy processed Info.plist to the app bundle
cp ${TEMP_INFO_PLIST} ${PROCESSED_INFO_PLIST}
echo ✅ Copy ${TEMP_INFO_PLIST} to ${PROCESSED_INFO_PLIST}


echo

#############################################################
if [ "${BUILDING_FOR_DEVICE}" != true ]; then
  # If we build for simulator, we can exit the scrip here
  echo 🎉 Building ${PROJECT_NAME} for simulator successfully finished! 🎉
  exit 0
fi
#############################################################




#############################################################
echo → Step 5: Copy Swift Runtime Libraries
#############################################################

# The folder where the Swift runtime libs live on the computer
SWIFT_LIBS_SRC_DIR=/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos

# The folder where we want to copy them in the app bundle
SWIFT_LIBS_DEST_DIR=${BUNDLE_DIR}/${FRAMEWORKS_DIR}

# The list of all libs we want to copy
RUNTIME_LIBS=( libswiftCore.dylib libswiftCoreFoundation.dylib libswiftCoreGraphics.dylib libswiftCoreImage.dylib libswiftDarwin.dylib libswiftDispatch.dylib libswiftFoundation.dylib libswiftMetal.dylib libswiftObjectiveC.dylib libswiftQuartzCore.dylib libswiftSwiftOnoneSupport.dylib libswiftUIKit.dylib libswiftos.dylib )

mkdir -p ${BUNDLE_DIR}/${FRAMEWORKS_DIR}
echo ✅ Create ${SWIFT_LIBS_DEST_DIR} folder

for library_name in "${RUNTIME_LIBS[@]}"; do
  # Copy the library
  cp ${SWIFT_LIBS_SRC_DIR}/$library_name ${SWIFT_LIBS_DEST_DIR}/
  echo ✅ Copy $library_name to ${SWIFT_LIBS_DEST_DIR}
done



echo

#############################################################
echo → Step 6: Code Signing
#############################################################

# The name of the provisioning file to use
# ⚠️ YOU NEED TO CHANGE THIS TO YOUR PROFILE ️️⚠️
PROVISIONING_PROFILE_NAME=23a6e9d9-ad3c-4574-832c-be6eb9d51b8c.mobileprovision

# The location of the provisioning file inside the app bundle
EMBEDDED_PROVISIONING_PROFILE=${BUNDLE_DIR}/embedded.mobileprovision

cp ~/Library/MobileDevice/Provisioning\ Profiles/${PROVISIONING_PROFILE_NAME} ${EMBEDDED_PROVISIONING_PROFILE}
echo ✅ Copy provisioning profile ${PROVISIONING_PROFILE_NAME} to ${EMBEDDED_PROVISIONING_PROFILE}


# The team identifier of your signing identity
# ⚠️ YOU NEED TO CHANGE THIS TO YOUR ID ️️⚠️
TEAM_IDENTIFIER=X53G3KMVA6

# The location if the .xcent file
XCENT_FILE=${TEMP_DIR}/${PROJECT_NAME}.xcent

${PLIST_BUDDY} -c "Add :application-identifier string ${TEAM_IDENTIFIER}.${APP_BUNDLE_IDENTIFIER}" ${XCENT_FILE}
${PLIST_BUDDY} -c "Add :com.apple.developer.team-identifier string ${TEAM_IDENTIFIER}" ${XCENT_FILE}

echo ✅ Create ${XCENT_FILE}


# The id of the identity used for signing
IDENTITY=E8C36646D64DA3566CB93E918D2F0B7558E78BAA

# Sign all libraries in the bundle
for lib in ${SWIFT_LIBS_DEST_DIR}/*; do
  # Sign
  codesign \
    --force \
    --timestamp=none \
    --sign ${IDENTITY} \
    ${lib}
  echo ✅ Codesign ${lib}
done

# Sign the bundle itself
codesign \
  --force \
  --timestamp=none \
  --entitlements ${XCENT_FILE} \
  --sign ${IDENTITY} \
  ${BUNDLE_DIR}


echo ✅ Codesign ${BUNDLE_DIR}

echo


#############################################################
echo 🎉 Building ${PROJECT_NAME} for device successfully finished! 🎉
exit 0
#############################################################
