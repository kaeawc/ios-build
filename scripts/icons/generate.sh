#!/usr/bin/env bash
#
# Generates placeholder app icons for every platform from one design: a flat colour with the app's
# initial. They exist so archives pass App Store validation; replace them with real artwork before
# shipping. scripts/rename.sh reruns this with the new app's initial.
#
# Usage: bash scripts/icons/generate.sh [initial] [colour]
#   initial  letter on the icon (default: first letter of APP_NAME in Shared.xcconfig)
#   colour   background colour as #RRGGBB (default: #3D6CF5)
#
# Needs rsvg-convert (macOS: brew install librsvg; Linux: apt-get install librsvg2-bin) and python3.
#
# Writes:
#   iOS       App/Assets.xcassets/AppIcon.appiconset (light, dark and tinted, 1024 pt)
#   tvOS      App/Assets.xcassets/AppIcon-tvOS.brandassets (layered icons and Top Shelf images)
#   visionOS  App/Assets.xcassets/AppIcon-visionOS.solidimagestack (three 1024 pt layers)
#   watchOS   Watch/Assets.xcassets/AppIcon.appiconset (1024 pt)

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

script_dir=scripts/icons
app_dir=ios/StarterApp
shared="$app_dir/Configurations/Shared.xcconfig"

setting() {
  sed -n "s/^$1 = //p" "$shared" | head -n 1
}

initial="${1:-$(setting APP_NAME | cut -c1)}"
colour="${2:-#3D6CF5}"
display_name="$(setting APP_DISPLAY_NAME)"

if [[ ! "$initial" =~ ^[A-Za-z0-9]$ ]]; then
  echo "initial must be a single letter or digit: '$initial'" >&2
  exit 1
fi
if [[ ! "$colour" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
  echo "colour must look like #RRGGBB: '$colour'" >&2
  exit 1
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert missing. macOS: brew install librsvg; Linux: apt-get install librsvg2-bin" >&2
  exit 1
fi

initial=$(printf '%s' "$initial" | tr '[:lower:]' '[:upper:]')
# Escape the display name for XML (rename.sh already rejects \, $ and ").
name_xml=$(printf '%s' "$display_name" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
font="font-family=\"SF Pro Rounded, Helvetica Neue, Helvetica, Arial, DejaVu Sans, sans-serif\" font-weight=\"bold\""

# Prints an SVG of the given layer at width x height.
#   full    background + disc + initial (iOS, watchOS)
#   dark    iOS dark appearance: dark background, coloured disc and initial
#   tinted  iOS tinted appearance: greyscale on black; the system applies the tint
#   back    background only (opaque bottom layer)
#   middle  translucent disc (transparent elsewhere)
#   front   initial (transparent elsewhere)
#   shelf   Top Shelf banner: background + display name
svg() {
  local layer="$1" width="$2" height="$3"
  local short=$((width < height ? width : height))
  local cx=$((width / 2)) cy=$((height / 2))
  local radius=$((short * 34 / 100)) size=$((short * 46 / 100))
  # Cap height is about 0.7 em, so shifting the baseline by 0.35 em centres the letter.
  local baseline=$((cy + size * 35 / 100))

  local background="<rect width=\"$width\" height=\"$height\" fill=\"$colour\"/>"
  background+="<rect width=\"$width\" height=\"$height\" fill=\"url(#shade)\"/>"
  local disc="<circle cx=\"$cx\" cy=\"$cy\" r=\"$radius\" fill=\"#FFFFFF\" fill-opacity=\"0.22\"/>"
  local letter="<text x=\"$cx\" y=\"$baseline\" font-size=\"$size\" $font text-anchor=\"middle\" fill=\"#FFFFFF\">$initial</text>"

  local body
  case "$layer" in
    full) body="$background$disc$letter" ;;
    dark)
      body="<rect width=\"$width\" height=\"$height\" fill=\"#1C1C1E\"/>"
      body+="<circle cx=\"$cx\" cy=\"$cy\" r=\"$radius\" fill=\"$colour\" fill-opacity=\"0.35\"/>"
      body+="${letter//fill=\"#FFFFFF\"/fill=\"$colour\"}"
      ;;
    tinted)
      body="<rect width=\"$width\" height=\"$height\" fill=\"#000000\"/>"
      body+="<circle cx=\"$cx\" cy=\"$cy\" r=\"$radius\" fill=\"#FFFFFF\" fill-opacity=\"0.25\"/>$letter"
      ;;
    back) body="$background" ;;
    middle) body="$disc" ;;
    front) body="$letter" ;;
    shelf)
      local text_size=$((height * 22 / 100))
      body="$background<text x=\"$cx\" y=\"$((cy + text_size * 35 / 100))\" font-size=\"$text_size\" $font"
      body+=" text-anchor=\"middle\" fill=\"#FFFFFF\">$name_xml</text>"
      ;;
    *)
      echo "unknown layer $layer" >&2
      exit 1
      ;;
  esac

  cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">
<defs><linearGradient id="shade" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.12"/><stop offset="1" stop-color="#000000" stop-opacity="0.12"/>
</linearGradient></defs>
$body
</svg>
EOF
}

opaque=()

# render <layer> <width> <height> <output.png>
render() {
  mkdir -p "$(dirname "$4")"
  svg "$1" "$2" "$3" | rsvg-convert --width "$2" --height "$3" --format png --output "$4"
  case "$1" in
    middle | front) ;;
    *) opaque+=("$4") ;;
  esac
}

# json <path> <content>: writes an asset catalog Contents.json.
json() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1"
}
info='"info" : { "author" : "xcode", "version" : 1 }'

# MARK: iOS (single size; Xcode generates the rest)

ios="$app_dir/App/Assets.xcassets/AppIcon.appiconset"
rm -rf "$ios"
render full 1024 1024 "$ios/AppIcon.png"
render dark 1024 1024 "$ios/AppIcon-Dark.png"
render tinted 1024 1024 "$ios/AppIcon-Tinted.png"
json "$ios/Contents.json" '{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "AppIcon-Dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "AppIcon-Tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024"
    }
  ],
  '"$info"'
}'

# MARK: watchOS

watch="$app_dir/Watch/Assets.xcassets/AppIcon.appiconset"
rm -rf "$watch"
render full 1024 1024 "$watch/AppIcon.png"
json "$watch/Contents.json" '{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "watchos", "size" : "1024x1024" }
  ],
  '"$info"'
}'

# MARK: tvOS (brand assets: layered App Icon at 400x240 pt, App Store icon, Top Shelf images)

tv="$app_dir/App/Assets.xcassets/AppIcon-tvOS.brandassets"
rm -rf "$tv"
json "$tv/Contents.json" '{
  "assets" : [
    { "filename" : "App Icon - App Store.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "1280x768" },
    { "filename" : "App Icon.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "400x240" },
    { "filename" : "Top Shelf Image Wide.imageset", "idiom" : "tv", "role" : "top-shelf-image-wide", "size" : "2320x720" },
    { "filename" : "Top Shelf Image.imageset", "idiom" : "tv", "role" : "top-shelf-image", "size" : "1920x720" }
  ],
  '"$info"'
}'

# tv_stack <name> <width> <height> <scales...>
tv_stack() {
  local stack="$tv/$1.imagestack" width="$2" height="$3"
  shift 3
  json "$stack/Contents.json" '{
  '"$info"',
  "layers" : [ { "filename" : "Front.imagestacklayer" }, { "filename" : "Middle.imagestacklayer" }, { "filename" : "Back.imagestacklayer" } ]
}'
  local layer
  for layer in Front Middle Back; do
    local dir="$stack/$layer.imagestacklayer"
    json "$dir/Contents.json" "{
  $info
}"
    local images="" scale
    for scale in "$@"; do
      local file="$layer@${scale}x.png"
      render "$(printf '%s' "$layer" | tr '[:upper:]' '[:lower:]')" $((width * scale)) $((height * scale)) \
        "$dir/Content.imageset/$file"
      images+="${images:+, }{ \"filename\" : \"$file\", \"idiom\" : \"tv\", \"scale\" : \"${scale}x\" }"
    done
    json "$dir/Content.imageset/Contents.json" "{
  \"images\" : [ $images ],
  $info
}"
  done
}
tv_stack "App Icon" 400 240 1 2
tv_stack "App Icon - App Store" 1280 768 1

# tv_shelf <name> <width> <height>
tv_shelf() {
  local set="$tv/$1.imageset"
  render shelf "$2" "$3" "$set/TopShelf@1x.png"
  render shelf $(($2 * 2)) $(($3 * 2)) "$set/TopShelf@2x.png"
  json "$set/Contents.json" "{
  \"images\" : [
    { \"filename\" : \"TopShelf@1x.png\", \"idiom\" : \"tv\", \"scale\" : \"1x\" },
    { \"filename\" : \"TopShelf@2x.png\", \"idiom\" : \"tv\", \"scale\" : \"2x\" }
  ],
  $info
}"
}
tv_shelf "Top Shelf Image" 1920 720
tv_shelf "Top Shelf Image Wide" 2320 720

# MARK: visionOS (solid image stack: three 1024 pt layers; the back layer must be opaque)

vision="$app_dir/App/Assets.xcassets/AppIcon-visionOS.solidimagestack"
rm -rf "$vision"
json "$vision/Contents.json" '{
  '"$info"',
  "layers" : [ { "filename" : "Front.solidimagestacklayer" }, { "filename" : "Middle.solidimagestacklayer" }, { "filename" : "Back.solidimagestacklayer" } ]
}'
for layer in Front Middle Back; do
  dir="$vision/$layer.solidimagestacklayer"
  json "$dir/Contents.json" "{
  $info
}"
  render "$(printf '%s' "$layer" | tr '[:upper:]' '[:lower:]')" 1024 1024 "$dir/Content.imageset/$layer.png"
  json "$dir/Content.imageset/Contents.json" "{
  \"images\" : [ { \"filename\" : \"$layer.png\", \"idiom\" : \"vision\", \"scale\" : \"2x\" } ],
  $info
}"
done

python3 "$script_dir/flatten_png.py" "${opaque[@]}"
echo "Generated placeholder icons with '$initial' on $colour."
