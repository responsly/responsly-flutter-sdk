#!/usr/bin/env bash
#
# Copies the native Responsly SDK sources into this plugin.
#
# The plugin is self-contained: it compiles the iOS and Android SDK sources that are stored in
# this repository. This script refreshes those copies from the native repositories and records
# what was copied in native-sdk.lock. Run it for every release, then commit the result.
#
#   tool/sync_native.sh [--ios <dir>] [--android <dir>] [--allow-dirty]
#
# By default the native repositories are expected next to this one:
#   ../responsly-ios-sdk       (or $RESPONSLY_IOS_SDK_DIR)
#   ../responsly-android-sdk   (or $RESPONSLY_ANDROID_SDK_DIR)
#
# Everything this script writes is listed at the end of its output. Do not edit those files by
# hand: change the native repository and run the script again.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_SDK="${RESPONSLY_IOS_SDK_DIR:-$ROOT/../responsly-ios-sdk}"
ANDROID_SDK="${RESPONSLY_ANDROID_SDK_DIR:-$ROOT/../responsly-android-sdk}"
ALLOW_DIRTY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ios) IOS_SDK="$2"; shift 2 ;;
    --android) ANDROID_SDK="$2"; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

fail() {
  echo "sync_native: $*" >&2
  exit 1
}

command -v git >/dev/null || fail "git is required"
command -v rsync >/dev/null || fail "rsync is required"

# What is copied, relative to each native repository.
IOS_SOURCES="Sources/ResponslySDK"
ANDROID_SOURCES="sdk/src/main/kotlin/com/responsly/sdk"
ANDROID_MANIFEST="sdk/src/main/AndroidManifest.xml"
ANDROID_CONSUMER_RULES="sdk/consumer-rules.pro"
ANDROID_VERSION_CATALOG="gradle/libs.versions.toml"
ANDROID_BUILD_FILE="sdk/build.gradle.kts"

# Where it goes, relative to this repository.
IOS_TARGET="ios/responsly_sdk/Sources/responsly_sdk/ResponslySDK"
ANDROID_TARGET="android/src/main/kotlin/com/responsly/sdk"
ANDROID_MANIFEST_TARGET="android/src/main/AndroidManifest.xml"
ANDROID_CONSUMER_RULES_TARGET="android/consumer-rules.pro"
LOCK_FILE="native-sdk.lock"

[ -d "$IOS_SDK/$IOS_SOURCES" ] || fail "iOS SDK sources not found in $IOS_SDK/$IOS_SOURCES"
[ -d "$ANDROID_SDK/$ANDROID_SOURCES" ] || fail "Android SDK sources not found in $ANDROID_SDK/$ANDROID_SOURCES"
IOS_SDK="$(cd "$IOS_SDK" && pwd)"
ANDROID_SDK="$(cd "$ANDROID_SDK" && pwd)"

# Prints the commit of a repository; refuses uncommitted changes in the paths that are copied,
# because the recorded commit would not describe them.
commit_of() {
  local repo="$1"
  shift
  git -C "$repo" rev-parse --verify --quiet HEAD >/dev/null || fail "$repo is not a git repository with a commit"
  if [ -n "$(git -C "$repo" status --porcelain -- "$@")" ]; then
    if [ "$ALLOW_DIRTY" -eq 1 ]; then
      echo "$(git -C "$repo" rev-parse HEAD)-dirty"
      return
    fi
    fail "$repo has uncommitted changes in: $*. Commit them, or pass --allow-dirty."
  fi
  git -C "$repo" rev-parse HEAD
}

IOS_COMMIT="$(commit_of "$IOS_SDK" "$IOS_SOURCES")"
ANDROID_COMMIT="$(commit_of "$ANDROID_SDK" "$ANDROID_SOURCES" "$ANDROID_MANIFEST" "$ANDROID_CONSUMER_RULES" "$ANDROID_VERSION_CATALOG" "$ANDROID_BUILD_FILE")"

# --- Versions -------------------------------------------------------------------------------

first_match() {
  # first_match <file> <sed expression that prints the value>
  sed -n "$2" "$1" | head -n 1
}

IOS_VERSION="$(first_match "$IOS_SDK/$IOS_SOURCES/Responsly.swift" 's/.*static let sdkVersion: String = "\([^"]*\)".*/\1/p')"
ANDROID_VERSION="$(first_match "$ANDROID_SDK/$ANDROID_SOURCES/Responsly.kt" 's/.*const val SDK_VERSION: String = "\([^"]*\)".*/\1/p')"
PLUGIN_VERSION="$(first_match "$ROOT/pubspec.yaml" 's/^version: *\([^ +]*\).*/\1/p')"

[ -n "$IOS_VERSION" ] || fail "could not read Responsly.sdkVersion from the iOS SDK"
[ -n "$ANDROID_VERSION" ] || fail "could not read Responsly.SDK_VERSION from the Android SDK"
[ -n "$PLUGIN_VERSION" ] || fail "could not read the version from pubspec.yaml"

# All Responsly SDK packages share one version number.
if [ "$IOS_VERSION" != "$PLUGIN_VERSION" ] || [ "$ANDROID_VERSION" != "$PLUGIN_VERSION" ]; then
  fail "version mismatch: pubspec.yaml $PLUGIN_VERSION, iOS SDK $IOS_VERSION, Android SDK $ANDROID_VERSION. Set the version in pubspec.yaml first."
fi

# The Android SDK's dependencies. android/build.gradle reads the versions from the lock file,
# so the plugin always asks for exactly what the native SDK asks for.
catalog_version() {
  first_match "$ANDROID_SDK/$ANDROID_VERSION_CATALOG" "s/^$1 *= *\"\\([^\"]*\\)\".*/\\1/p"
}
ANDROIDX_WEBKIT="$(catalog_version androidx-webkit)"
ANDROIDX_ANNOTATION="$(catalog_version androidx-annotation)"
[ -n "$ANDROIDX_WEBKIT" ] || fail "could not read the androidx.webkit version from $ANDROID_VERSION_CATALOG"
[ -n "$ANDROIDX_ANNOTATION" ] || fail "could not read the androidx.annotation version from $ANDROID_VERSION_CATALOG"

# android/build.gradle declares these two dependencies by hand. Stop when the SDK gains another.
UNKNOWN_DEPENDENCIES="$(grep -E '^[[:space:]]*(api|implementation|compileOnly|runtimeOnly)\(' "$ANDROID_SDK/$ANDROID_BUILD_FILE" \
  | grep -v -E 'libs\.androidx\.(webkit|annotation)\)' || true)"
[ -z "$UNKNOWN_DEPENDENCIES" ] || fail "the Android SDK has dependencies this plugin does not declare:
$UNKNOWN_DEPENDENCIES
Add them to android/build.gradle and to this script."

# The plugin's own manifest is the SDK's manifest: fail when the SDK starts to ship resources,
# which would need copying too.
[ ! -d "$ANDROID_SDK/sdk/src/main/res" ] || fail "the Android SDK now has resources (sdk/src/main/res); teach this script to copy them"

# --- Copy -----------------------------------------------------------------------------------

cd "$ROOT"

mkdir -p "$IOS_TARGET" "$ANDROID_TARGET"
rsync -a --delete --exclude '.DS_Store' "$IOS_SDK/$IOS_SOURCES/" "$IOS_TARGET/"
rsync -a --delete --exclude '.DS_Store' "$ANDROID_SDK/$ANDROID_SOURCES/" "$ANDROID_TARGET/"

[ -f "$IOS_TARGET/Resources/PrivacyInfo.xcprivacy" ] || fail "the iOS SDK no longer has Resources/PrivacyInfo.xcprivacy; update ios/responsly_sdk/Package.swift and ios/responsly_sdk.podspec"

# The manifest carries what an app would get from the SDK's own artifact: the INTERNET permission,
# the startup provider and the file chooser activity. The plugin adds nothing of its own.
{
  IFS= read -r first_line
  case "$first_line" in
    '<?xml'*)
      printf '%s\n' "$first_line"
      printf '%s\n' "<!-- Copied from the Responsly Android SDK by tool/sync_native.sh. Do not edit. -->"
      ;;
    *)
      printf '%s\n' "<!-- Copied from the Responsly Android SDK by tool/sync_native.sh. Do not edit. -->"
      printf '%s\n' "$first_line"
      ;;
  esac
  cat
} < "$ANDROID_SDK/$ANDROID_MANIFEST" > "$ANDROID_MANIFEST_TARGET"

{
  printf '%s\n' "# Copied from the Responsly Android SDK by tool/sync_native.sh. Do not edit."
  cat "$ANDROID_SDK/$ANDROID_CONSUMER_RULES"
} > "$ANDROID_CONSUMER_RULES_TARGET"

cat > "$LOCK_FILE" <<EOF
# Written by tool/sync_native.sh. Do not edit.
# The native Responsly SDK sources compiled into this plugin.
ios.repository=responsly-ios-sdk
ios.version=$IOS_VERSION
ios.commit=$IOS_COMMIT
android.repository=responsly-android-sdk
android.version=$ANDROID_VERSION
android.commit=$ANDROID_COMMIT
# Dependency versions pinned by the Android SDK; read by android/build.gradle.
android.androidx.webkit=$ANDROIDX_WEBKIT
android.androidx.annotation=$ANDROIDX_ANNOTATION
EOF

echo "iOS SDK      $IOS_VERSION  $IOS_COMMIT"
echo "Android SDK  $ANDROID_VERSION  $ANDROID_COMMIT"
echo "Wrote:"
echo "  $IOS_TARGET/"
echo "  $ANDROID_TARGET/"
echo "  $ANDROID_MANIFEST_TARGET"
echo "  $ANDROID_CONSUMER_RULES_TARGET"
echo "  $LOCK_FILE"
