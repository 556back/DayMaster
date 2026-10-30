#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug

if [[ -n "${IOS_TEST_DESTINATION:-}" ]]; then
  destination="$IOS_TEST_DESTINATION"
else
  simulator_id="$(xcrun simctl list devices available | awk '
    /^-- iOS / { split($3, version, "."); supported = version[1] >= 17 }
    supported && /^[[:space:]]*iPhone / {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^\([0-9A-Fa-f-]+\)$/ && length($i) == 38) {
          id = $i
          gsub(/[()]/, "", id)
          if (first == "") first = id
          if ($0 ~ /\(Booted\)/) booted = id
        }
      }
    }
    END { print booted != "" ? booted : first }
  ')"
  if [[ -z "$simulator_id" ]]; then
    printf '%s\n' \
      'No available iPhone simulator running iOS 17 or later was found.' \
      'Install an iOS Simulator runtime in Xcode Settings > Platforms, create an iPhone simulator, and rerun.' \
      'Or set IOS_TEST_DESTINATION to an existing supported iOS Simulator destination.' >&2
    exit 1
  fi
  destination="platform=iOS Simulator,id=$simulator_id"
fi

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -destination "$destination" \
  -derivedDataPath build/ios-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
