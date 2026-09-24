#!/bin/bash
# Fills the app icon set from one 1024×1024 PNG (default: Design/AppIcon.png).
# The DMG takes its disk and file icons from the built app, so this is the
# only place the icon comes from.
#
#   scripts/set-app-icon.sh [path/to/icon-1024.png]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
source_png="${1:-$root/Design/AppIcon.png}"
iconset="$root/KAPL/Assets.xcassets/AppIcon.appiconset"

size=$(sips -g pixelWidth -g pixelHeight "$source_png" | awk '/pixel/ {print $2}' | sort -u)
if [[ "$size" != "1024" ]]; then
    echo "error: $source_png must be 1024×1024" >&2
    exit 1
fi

mkdir -p "$iconset"
images=""
for points in 16 32 128 256 512; do
    for scale in 1 2; do
        pixels=$((points * scale))
        file="icon_${points}x${points}@${scale}x.png"
        sips -z "$pixels" "$pixels" "$source_png" --out "$iconset/$file" >/dev/null
        images+="    { \"filename\" : \"$file\", \"idiom\" : \"mac\", \"scale\" : \"${scale}x\", \"size\" : \"${points}x${points}\" },"$'\n'
    done
done

cat > "$iconset/Contents.json" <<EOF
{
  "images" : [
${images%,$'\n'}
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

cat > "$root/KAPL/Assets.xcassets/Contents.json" <<EOF
{
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

echo "App icon updated from $source_png"
