#!/bin/sh
set -eu

sdk=${VFLY_SDKROOT:-"$HOME/Library/Developer/SDKs/MacOSX10.13.sdk"}
headers="$sdk/System/Library/Frameworks/Kernel.framework/Headers"
if [ ! -f "$headers/IOKit/hid/IOHIDDevice.h" ] || [ ! -f "$sdk/usr/lib/libkmod.a" ]; then
    echo "error: Set VFLY_SDKROOT to a macOS 10.13 SDK containing the kernel HID headers and libkmod.a." >&2
    exit 1
fi

source_dir="$SRCROOT/VirtualFly"
work="$DERIVED_FILE_DIR/VirtualFly"
bundle="$work/vfly.kext"
resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$bundle/Contents/MacOS" "$resources"

cat > "$work/vfly_info.c" <<'MODULE'
#include <mach/mach_types.h>

extern kern_return_t _start(kmod_info_t *ki, void *data);
extern kern_return_t _stop(kmod_info_t *ki, void *data);

__attribute__((visibility("default"))) KMOD_EXPLICIT_DECL(com.mkrasnorutsky.driver.vfly, "1.0.0d1", _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = 0;
__private_extern__ kmod_stop_func_t *_antimain = 0;
__private_extern__ int _kext_apple_cc = __APPLE_CC__;
MODULE

for unit in virtual_fly virtual_fly_device virtual_fly_user_client; do
    /usr/bin/xcrun clang -target x86_64-apple-macos10.13 -isysroot "$sdk" \
        -I"$headers" -nostdinc -mkernel -fapple-kext -DKERNEL -DKERNEL_PRIVATE \
        -DDRIVER_PRIVATE -DAPPLE -DNeXT -Os -c "$source_dir/$unit.cpp" -o "$work/$unit.o"
done
/usr/bin/xcrun clang -target x86_64-apple-macos10.13 -isysroot "$sdk" \
    -I"$headers" -nostdinc -mkernel -DKERNEL -c "$work/vfly_info.c" -o "$work/vfly_info.o"
/usr/bin/xcrun clang -target x86_64-apple-macos10.13 -isysroot "$sdk" \
    -mkernel -nostdlib -Wl,-kext -Wl,-undefined,dynamic_lookup -Wl,-ld_classic \
    "$work/virtual_fly.o" "$work/virtual_fly_device.o" "$work/virtual_fly_user_client.o" \
    "$work/vfly_info.o" "$sdk/usr/lib/libkmodc++.a" "$sdk/usr/lib/libkmod.a" \
    -o "$bundle/Contents/MacOS/vfly"

/usr/bin/sed -e 's/${EXECUTABLE_NAME}/vfly/g' -e 's/${PRODUCT_NAME\(:rfc1034Identifier\)\{0,1\}}/vfly/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.mkrasnorutsky.driver.vfly/g' \
    "$source_dir/Info.plist" > "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 10.13' "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :DTSDKName string macosx10.13' "$bundle/Contents/Info.plist"

/bin/rm -rf "$resources/vfly.kext"
/usr/bin/ditto "$bundle" "$resources/vfly.kext"
