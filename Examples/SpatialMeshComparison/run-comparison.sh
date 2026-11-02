#!/bin/bash
# Run from any directory. Keep OUTPUT_DIR outside the repository for private inputs.
set -euo pipefail
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 SIMULATOR_UDID OUTPUT_DIR [LOCAL_IMAGE]" >&2
    exit 2
fi
simulator="$1"
output_dir="$2"
input_image="${3:-}"
example_dir="$(cd "$(dirname "$0")" && pwd)"
derived_dir="$(mktemp -d "${TMPDIR:-/tmp}/palette-spatial.XXXXXX")"
bundle_id="com.paletteKit.research.SpatialMeshComparison"
mkdir -p "$output_dir"
xcodegen generate --spec "$example_dir/project.yml"
xcodebuild build -project "$example_dir/SpatialMeshComparison.xcodeproj" \
    -scheme SpatialMeshComparison -configuration Debug -destination "id=$simulator" \
    -derivedDataPath "$derived_dir" > "$output_dir/build.log" 2>&1
xcrun simctl terminate "$simulator" "$bundle_id" 2>/dev/null || true
xcrun simctl install "$simulator" "$derived_dir/Build/Products/Debug-iphonesimulator/SpatialMeshComparison.app"
container_dir="$(xcrun simctl get_app_container "$simulator" "$bundle_id" data)"
# Remove only this harness's generated outputs and previous optional input.
python3 - "$container_dir" "$input_image" <<'PY'
from pathlib import Path
import shutil, sys
folder = Path(sys.argv[1]) / 'Documents'
shutil.rmtree(folder / 'SpatialComparison', ignore_errors=True)
(folder / 'input.jpg').unlink(missing_ok=True)
if sys.argv[2]:
    shutil.copyfile(sys.argv[2], folder / 'input.jpg')
PY
xcrun simctl launch "$simulator" "$bundle_id"
for attempt in {1..60}; do
    if [ -f "$container_dir/Documents/SpatialComparison/metrics.json" ]; then
        cp -R "$container_dir/Documents/SpatialComparison/." "$output_dir/"
        xcrun simctl io "$simulator" screenshot "$output_dir/simulator-screen.png"
        echo "Saved comparisons to $output_dir"
        exit 0
    fi
    sleep 1
done
echo "Export did not finish; inspect the app's error message. Build: $derived_dir" >&2
exit 1
