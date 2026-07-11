#!/bin/bash
set -e

# Input file
INPUT_IMAGE="$1"
OUTPUT_ICNS="$2"

if [ -z "$INPUT_IMAGE" ] || [ -z "$OUTPUT_ICNS" ]; then
    echo "Usage: $0 <input_image> <output_icns>"
    exit 1
fi

# Ensure parent directory of output exists
mkdir -p "$(dirname "$OUTPUT_ICNS")"

ICONSET_DIR="AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate the various sizes using sips
echo "Resizing images using sips..."
sips -s format png -z 16 16     "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -s format png -z 32 32     "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -s format png -z 32 32     "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -s format png -z 64 64     "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -s format png -z 128 128   "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -s format png -z 256 256   "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -s format png -z 256 256   "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -s format png -z 512 512   "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -s format png -z 512 512   "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -s format png -z 1024 1024 "$INPUT_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# Compile iconset to icns
echo "Compiling iconset into .icns using iconutil..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Clean up iconset
rm -rf "$ICONSET_DIR"

echo "Icon generated successfully at: $OUTPUT_ICNS"
