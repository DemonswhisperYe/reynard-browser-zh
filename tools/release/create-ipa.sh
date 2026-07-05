#!/bin/sh

set -eu

CLANG_PATH="$(xcrun --sdk iphoneos --find clang)"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
ARCHIVE_DIR="$ROOT_DIR/dist/Reynard.xcarchive"
APP_DIR="$ARCHIVE_DIR/Products/Applications"
WORK_DIR="$ROOT_DIR/dist/Reynard"

cd "$ROOT_DIR"

if [ ! -d "$APP_DIR" ]; then
	echo "Missing archive output at $APP_DIR"
	echo "Run tools/release/build-app.sh first."
	exit 1
fi

is_macho_file() {
	file "$1" | grep -Eq 'Mach-O|Mach.O'
}

sign_app_payload() {
	payload_app="$1"

	find "$payload_app" -type f | while IFS= read -r file; do
		if is_macho_file "$file"; then
			case "$file" in
				*/ptrace_jit)
					ldid -S"$ROOT_DIR/browser/Reynard/JIT/Unsandboxed/ptrace_jit.entitlements" "$file"
					;;
				*/Reynard.app/Reynard)
					ldid -S"$ROOT_DIR/browser/Reynard/Entitlements/Reynard.private.entitlements" "$file"
					;;
				*/Reynard\ Helper.appex/Reynard\ Helper)
					ldid -S"$ROOT_DIR/browser/Helper/Entitlements/Reynard-Helper.private.entitlements" "$file"
					;;
				*)
					ldid -S "$file"
					;;
			esac
		fi
	done
}

APP_PATH="$(find "$APP_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [ -z "$APP_PATH" ]; then
	echo "No .app found in $APP_DIR"
	exit 1
fi

# I absolutely hate Apple for this
# Why is my bundle identifier just become unavailable for no reason?
plutil -replace CFBundleIdentifier -string "com.minh-ton.Reynard" "$APP_PATH/Info.plist"
plutil -replace CFBundleIdentifier -string "com.minh-ton.Reynard.Helper" "$APP_PATH/PlugIns/Reynard Helper.appex/Info.plist"
plutil -replace CFBundleIdentifier -string "com.minh-ton.Reynard.OpenIn" "$APP_PATH/PlugIns/OpenIn.appex/Info.plist"

rm -rf "$WORK_DIR" "$ROOT_DIR/dist/Reynard.ipa" "$ROOT_DIR/dist/Reynard-TrollStore.tipa" "$ROOT_DIR/dist/Reynard-Jailbroken.ipa"
mkdir -p "$WORK_DIR/Payload"
cp -R "$APP_PATH" "$WORK_DIR/Payload/"

cd "$WORK_DIR"
zip -r ../Reynard.ipa Payload -x "._*" -x ".DS_Store" -x "__MACOSX" # normal ipa

PTRACE_JIT_SRC="$ROOT_DIR/browser/Reynard/JIT/Unsandboxed/ptrace_jit.c"
PTRACE_JIT_OUT="Payload/Reynard.app/ptrace_jit"

"$CLANG_PATH" \
	-arch arm64 \
	-isysroot "$SDK_PATH" \
	-miphoneos-version-min=13.0 \
	-Os \
	"$PTRACE_JIT_SRC" \
	-o "$PTRACE_JIT_OUT"

sign_app_payload "$WORK_DIR/Payload"
zip -r ../Reynard-TrollStore.tipa Payload -x "._*" -x ".DS_Store" -x "__MACOSX" # trollstore ipa
cp ../Reynard-TrollStore.tipa ../Reynard-Jailbroken.ipa # for jailbroken users
