#!/usr/bin/env bash
#
# make-android-icons.sh - turn an image into a complete Android launcher icon set
# following Google's adaptive icon / launcher icon specifications.
#
# Generates (under <outdir>/res, ready to copy into app/src/main/res):
#   * Adaptive icon layers: foreground + monochrome (themed icons, Android 13+)
#     at 108dp (108/162/216/324/432 px), background as a color resource
#   * Adaptive icon XML (mipmap-anydpi-v26) for ic_launcher and ic_launcher_round
#   * Legacy launcher icons at 48dp (48/72/96/144/192 px): rounded square + round
#   * Play Store icon: 512x512, 32-bit PNG, full-bleed square (Google applies the mask)
#   * flutter_launcher_icons inputs (<outdir>/flutter): icon.png, icon_foreground.png,
#     icon_monochrome.png, icon_splash.png (1152 px, Android 12+ splash) and a
#     ready-made flutter_launcher_icons.yaml
#
# Google's adaptive icon geometry (all in dp):
#   canvas 108x108 | visible mask area 72x72 | safe zone = 66 dp diameter circle
#   Anything outside the 66 dp safe zone may be clipped by the device's mask.
#
# Requires ImageMagick (v7 `magick` or v6 `convert`).

set -euo pipefail

NAME="ic_launcher"
OUT="/tmp/android-icons"
BG="#FFFFFF"
SAFE_DP=66
CIRCLE=0
TRIM=1
ASSET_DIR="assets/icon"

usage() {
  cat <<EOF
Usage: ${0##*/} [options] <input-image>

Options:
  -o DIR    Output directory                     (default: ./android-icons)
  -n NAME   Icon base name                       (default: ic_launcher)
  -b COLOR  Background color as hex #RRGGBB      (default: #FFFFFF)
  -s DP     Max logo size in dp, 1-66            (default: 66)
  -c        Fit the logo's diagonal inside the safe-zone circle, so even the
            corners of a rectangular logo survive any mask shape (smaller logo)
  -a DIR    Folder in your Flutter project where you'll put the generated images;
            only used for the paths in flutter_launcher_icons.yaml
            (default: assets/icon)
  -T        Don't auto-trim transparent borders
  -h        Show this help

Tips:
  * Use a square source of at least 512x512 px, ideally a PNG with transparency.
  * A logo with transparent background works best: the background color comes
    from -b. A fully opaque square image is used as-is on top of that color.
EOF
}

die() { echo "error: $*" >&2; exit 1; }

while getopts ":o:n:b:s:a:cTh" opt; do
  case $opt in
    o) OUT=$OPTARG ;;
    n) NAME=$OPTARG ;;
    b) BG=$OPTARG ;;
    s) SAFE_DP=$OPTARG ;;
    a) ASSET_DIR=${OPTARG%/} ;;
    c) CIRCLE=1 ;;
    T) TRIM=0 ;;
    h) usage; exit 0 ;;
    :) die "option -$OPTARG requires an argument" ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

SRC=${1:-}
[[ -n $SRC && -f $SRC ]] || { usage; exit 1; }
[[ $BG =~ ^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$ ]] || die "background must be a hex color like #1A73E8"
[[ $SAFE_DP =~ ^[0-9]+$ ]] && (( SAFE_DP >= 1 && SAFE_DP <= 66 )) || die "-s must be an integer from 1 to 66"
[[ $NAME =~ ^[a-z0-9_]+$ ]] || die "name must be lowercase letters, digits, underscores (Android resource rules)"

# --- ImageMagick detection (v7 vs v6) ---------------------------------------
if command -v magick >/dev/null 2>&1; then
  IM=(magick); IDENT=(magick identify)
elif command -v convert >/dev/null 2>&1; then
  IM=(convert); IDENT=(identify)
else
  die "ImageMagick not found (install it, e.g. 'sudo apt install imagemagick')"
fi

# --- Geometry ----------------------------------------------------------------
PX=16                              # master resolution: 16 px per dp
CANVAS=$((108 * PX))               # 1728 px adaptive canvas
SAFE_PX=$((SAFE_DP * PX))          # max logo extent
LEGACY_WINDOW=$((88 * PX))         # area of the canvas used for legacy/Play icons
                                   # (logo ends up ~75% of the tile, leaving margin)

DENS=(mdpi hdpi xhdpi xxhdpi xxxhdpi)
MULT=(10 15 20 30 40)              # density multipliers x10 (1.0, 1.5, 2.0, 3.0, 4.0)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- 1. Normalize source -----------------------------------------------------
FRAME="${SRC}[0]"   # first frame only (gif/ico/pdf)
trim_args=()
opaque=$("${IDENT[@]}" -format '%[opaque]' "$FRAME")
if (( TRIM )) && [[ ${opaque,,} == "false" ]]; then
  trim_args=(-trim)  # only trim images that actually have transparency
fi
"${IM[@]}" "$FRAME" -background none -alpha on ${trim_args[@]+"${trim_args[@]}"} +repage "$TMP/src.png"

read -r w h < <("${IDENT[@]}" -format '%w %h\n' "$TMP/src.png")
(( w > 0 && h > 0 )) || die "could not read image dimensions"

# Scale so the logo fits the safe zone (bounding box, or diagonal with -c)
read -r W H < <(awk -v w="$w" -v h="$h" -v box="$SAFE_PX" -v circ="$CIRCLE" 'BEGIN {
  if (circ) s = box / sqrt(w*w + h*h); else s = box / (w > h ? w : h)
  W = int(w*s + 0.5); H = int(h*s + 0.5)
  if (W < 1) W = 1; if (H < 1) H = 1
  printf "%d %d\n", W, H
}')

# Warn if the source is too small for a sharp Android 12+ splash icon
# (icon_splash.png is 1152 px, i.e. 2/3 of the 1728 px master)
if (( W * 2 > w * 3 || H * 2 > h * 3 )); then
  echo "warning: source (${w}x${h}) is smaller than the logo area of icon_splash.png ($((W * 2 / 3))x$((H * 2 / 3)) px); it will be upscaled and look soft" >&2
fi

# --- 2. Master layers --------------------------------------------------------
# Foreground: logo centered on a transparent 108dp canvas
"${IM[@]}" "$TMP/src.png" -resize "${W}x${H}!" -background none -gravity center \
  -extent "${CANVAS}x${CANVAS}" "PNG32:$TMP/fg.png"

# Background: solid color
"${IM[@]}" -size "${CANVAS}x${CANVAS}" "xc:${BG}" "$TMP/bg.png"

# Monochrome layer for themed icons: logo silhouette (alpha preserved)
"${IM[@]}" "$TMP/fg.png" -fill black -colorize 100 "PNG32:$TMP/mono.png"

# Composite (fg over bg) and crop the window used for legacy/Play icons
"${IM[@]}" "$TMP/bg.png" "$TMP/fg.png" -compose over -composite \
  -gravity center -crop "${LEGACY_WINDOW}x${LEGACY_WINDOW}+0+0" +repage "$TMP/legacy_master.png"

# --- 3. Legacy icon helper ---------------------------------------------------
make_legacy() {  # size  shape(square|round)  outfile
  local s=$1 shape=$2 out=$3 r
  if [[ $shape == round ]]; then r=$((s / 2)); else r=$((s * 15 / 100)); fi
  "${IM[@]}" "$TMP/legacy_master.png" -resize "${s}x${s}" \
    \( -size "${s}x${s}" xc:none -fill white \
       -draw "roundrectangle 0,0 $((s-1)),$((s-1)) ${r},${r}" \) \
    -compose DstIn -composite "PNG32:$out"
}

# --- 4. Per-density output ---------------------------------------------------
for i in "${!DENS[@]}"; do
  d=${DENS[i]}; m=${MULT[i]}
  dir="$OUT/res/mipmap-$d"
  mkdir -p "$dir"
  adaptive=$((108 * m / 10))
  legacy=$((48 * m / 10))

  "${IM[@]}" "$TMP/fg.png"   -resize "${adaptive}x${adaptive}" "PNG32:$dir/${NAME}_foreground.png"
  "${IM[@]}" "$TMP/mono.png" -resize "${adaptive}x${adaptive}" "PNG32:$dir/${NAME}_monochrome.png"
  make_legacy "$legacy" square "$dir/${NAME}.png"
  make_legacy "$legacy" round  "$dir/${NAME}_round.png"
done

# --- 5. XML resources --------------------------------------------------------
mkdir -p "$OUT/res/mipmap-anydpi-v26" "$OUT/res/values"

cat > "$OUT/res/values/${NAME}_background.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="${NAME}_background">${BG}</color>
</resources>
EOF

for f in "${NAME}" "${NAME}_round"; do
  cat > "$OUT/res/mipmap-anydpi-v26/${f}.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/${NAME}_background"/>
    <foreground android:drawable="@mipmap/${NAME}_foreground"/>
    <monochrome android:drawable="@mipmap/${NAME}_monochrome"/>
</adaptive-icon>
EOF
done

# --- 6. Play Store icon (512x512, 32-bit PNG, <= 1024 KB, square, no shadow) --
PLAY="$OUT/play_store_512.png"
"${IM[@]}" "$TMP/legacy_master.png" -resize 512x512 -strip "PNG32:$PLAY"
size=$(wc -c < "$PLAY")
if (( size > 1024 * 1024 )); then
  echo "warning: Play Store icon is $((size / 1024)) KB, over the 1024 KB limit" >&2
fi

# --- 7. flutter_launcher_icons inputs ------------------------------------------
# icon.png            full-bleed square, bg + logo      -> image_path
# icon_foreground.png logo on transparent 108dp canvas  -> adaptive_icon_foreground
# icon_monochrome.png black silhouette of the logo      -> adaptive_icon_monochrome
# icon_splash.png     1152 px foreground for the Android 12+ splash (flutter_native_splash)
# The foreground/monochrome images already contain the 66dp safe-zone padding, so the
# config sets adaptive_icon_foreground_inset to 0 (the package default of 16% would
# shrink the logo a second time).
FL="$OUT/flutter"
mkdir -p "$FL"
"${IM[@]}" "$TMP/legacy_master.png" -resize 1024x1024 "PNG32:$FL/icon.png"
"${IM[@]}" "$TMP/fg.png"            -resize 1024x1024 "PNG32:$FL/icon_foreground.png"
"${IM[@]}" "$TMP/mono.png"          -resize 1024x1024 "PNG32:$FL/icon_monochrome.png"
# Android 12+ splash: 288dp at xxxhdpi = 1152 px. Same 108:72:66 geometry as the adaptive
# foreground, so the logo sits inside the 768 px (2/3) circle the splash screen shows.
"${IM[@]}" "$TMP/fg.png"            -resize 1152x1152 "PNG32:$FL/icon_splash.png"

cat > "$FL/flutter_launcher_icons.yaml" <<EOF
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "${ASSET_DIR}/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "${BG}"
  adaptive_icon_foreground: "${ASSET_DIR}/icon_foreground.png"
  adaptive_icon_foreground_inset: 0
  adaptive_icon_monochrome: "${ASSET_DIR}/icon_monochrome.png"
EOF

# --- Done --------------------------------------------------------------------
cat <<EOF

Done. Output in: $OUT

For flutter_launcher_icons (in $FL):
  icon.png, icon_foreground.png, icon_monochrome.png, icon_splash.png,
  flutter_launcher_icons.yaml

Next steps, from your Flutter project root:
  1. mkdir -p ${ASSET_DIR} && cp $FL/*.png ${ASSET_DIR}/
  2. flutter pub add dev:flutter_launcher_icons
  3. Paste the config below into pubspec.yaml (or save it as
     flutter_launcher_icons.yaml in the project root):

$(sed 's/^/       /' "$FL/flutter_launcher_icons.yaml")

  4. dart run flutter_launcher_icons

Android 12+ splash (sharp; icon_splash.png is copied to the assets folder in step 1):
  flutter pub add dev:flutter_native_splash
  add to pubspec.yaml, then run: dart run flutter_native_splash:create

       flutter_native_splash:
         color: "${BG}"
         android_12:
           color: "${BG}"
           image: ${ASSET_DIR}/icon_splash.png

Also generated:
  play_store_512.png   Google Play listing icon (upload in Play Console)
  res/                 native Android resources; not needed with flutter_launcher_icons,
                       only if you want to copy them into android/app/src/main/res/ yourself
EOF
