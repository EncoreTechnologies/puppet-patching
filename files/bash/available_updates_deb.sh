#!/bin/bash

## Check for available updates (must have them in our cache already)
PKGS=$(apt list --upgradable 2>/dev/null | awk 'NR>1 {print $0}' | sort)
cat <<EOF
{
  "updates": [
EOF

comma=''
while read -r line; do
  if [ -z "$line" ]; then
    continue
  fi
  name=$(echo "$line" | awk -F/ '{print $1}')
  version=$(echo "$line" | awk '{print $2}')
  repo=$(echo "$line" | awk '{print $3}')
  if [ -n "$comma" ]; then
    echo "$comma"
  fi
  echo "    {"
  echo "      \"name\": \"${name}\","
  echo "      \"version\": \"${version}\","
  echo "      \"repo\": \"${repo}\""
  echo -n "    }"
  comma=','
done <<< "$PKGS"

echo ''
cat <<EOF
  ]
}
EOF
