#!/bin/bash

## Check for available updates (must have then in our cache already)
PKGS=$(apt upgrade --simulate 2>/dev/null | awk '$1 == "Inst" {print $0}' | sort)
cat <<EOF
{
  "updates": [
EOF

comma=''
while read -r line; do
  if [ -z "$line" ]; then
    continue
  fi
  name=$(echo "$line" | awk '{print $2}')
  # pull out the stuff in between the ()
  other_data=$(echo "$line" | awk -F '[()]' '{print $2}')
  version=$(echo "$other_data" | awk '{print $1}')
  repo=$(echo "$other_data" | awk '{print $2}' | sed 's/,//g')
  if [ -n $comma ]; then
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
