#!/bin/bash
# Builds a Release KAPL.app and packs it into build/KAPL-<version>.dmg: the
# app, a link to /Applications and the app's icon on the disk and the file.
#
#   scripts/make-dmg.sh                         ad-hoc signed, for this Mac
#   scripts/make-dmg.sh --team TEAMID           signed with Developer ID
#   scripts/make-dmg.sh --team TEAMID --notary-profile PROFILE
#                                               ...and notarized by Apple
#
# PROFILE is stored once with:
#   xcrun notarytool store-credentials PROFILE --apple-id you@example.com --team-id TEAMID
#
# --no-layout skips arranging the Finder window, which scripts Finder and
# may ask once for permission to control it.
set -euo pipefail

team=""
notary_profile=""
layout=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --team) team="$2"; shift 2 ;;
        --notary-profile) notary_profile="$2"; shift 2 ;;
        --no-layout) layout=0; shift ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done
if [[ -n "$notary_profile" && -z "$team" ]]; then
    echo "error: notarization needs --team (a Developer ID signature)" >&2
    exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$root/build/release"
volume_name="KAPL"

# MARK: Build

signing=()
identity=""
if [[ -n "$team" ]]; then
    identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "($team)" | head -1 | awk -F'"' '{print $2}')
    if [[ -z "$identity" ]]; then
        echo "error: no \"Developer ID Application\" certificate for team $team in the keychain" >&2
        exit 1
    fi
    signing=(CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$team" CODE_SIGN_IDENTITY="$identity" OTHER_CODE_SIGN_FLAGS=--timestamp)
    echo "==> Signing with $identity"
else
    echo "==> Ad-hoc signing: runs on this Mac; other Macs will block it (see README)"
fi

echo "==> Building Release"
rm -rf "$work"
# Any Mac: a universal binary for Apple silicon and Intel.
xcodebuild -project "$root/KAPL.xcodeproj" -scheme KAPL -configuration Release \
    -destination "generic/platform=macOS" -derivedDataPath "$work/DerivedData" \
    ${signing[@]+"${signing[@]}"} build -quiet

app="$work/DerivedData/Build/Products/Release/KAPL.app"
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
icon="$app/Contents/Resources/AppIcon.icns"
dmg="$root/build/KAPL-$version.dmg"

# MARK: Disk image

echo "==> Packing $(basename "$dmg")"
stage="$work/stage"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

rw="$work/rw.dmg"
hdiutil create -quiet -volname "$volume_name" -srcfolder "$stage" -fs HFS+ -format UDRW -ov "$rw"
mount=$(hdiutil attach -readwrite -noverify -noautoopen "$rw" | awk -F'\t' '/\/Volumes\// {print $NF}')

if [[ $layout == 1 ]]; then
    if ! osascript <<EOF
tell application "Finder"
    tell disk "$(basename "$mount")"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 740, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "KAPL.app" of container window to {140, 170}
        set position of item "Applications" of container window to {400, 170}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
    then
        echo "warning: could not arrange the Finder window; the DMG works, just unarranged" >&2
    fi
fi

# A hidden .VolumeIcon.icns becomes the disk's icon. Set after the layout,
# which drops it, and on the mounted disk: `hdiutil create -srcfolder` leaves
# hidden files out.
cp "$icon" "$mount/.VolumeIcon.icns"
SetFile -c icnC "$mount/.VolumeIcon.icns"
SetFile -a C "$mount"

rm -rf "$mount/.fseventsd"
sync
for attempt in 1 2 3 4 5; do
    hdiutil detach -quiet "$mount" && break
    sleep 2
done

rm -f "$dmg"
hdiutil convert -quiet "$rw" -format UDZO -imagekey zlib-level=9 -o "$dmg"
rm -f "$rw"

# MARK: Sign and notarize

if [[ -n "$identity" ]]; then
    codesign --sign "$identity" --timestamp "$dmg"
fi
if [[ -n "$notary_profile" ]]; then
    echo "==> Notarizing (usually a few minutes)"
    xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg"
fi

# The file icon lives in extended attributes: set it last, after signing.
osascript -l JavaScript -e "
    ObjC.import('AppKit');
    \$.NSWorkspace.sharedWorkspace.setIconForFileOptions(\$.NSImage.alloc.initWithContentsOfFile('$icon'), '$dmg', 0);
" >/dev/null

echo "==> Done: $dmg"
