#!/bin/bash
# Required environment variables 
# export RESULT_FILE  - name of the file to write JSON results to

# Sometimes yum check-update will output extra info like this:
# ---
# Security: kernel-3.14.6-200.fc20.x86_64 is an installed security update
# Security: kernel-3.14.2-200.fc20.x86_64 is the currently running version
# ---
# We need to filter those out as they screw up the package listing
PKGS=$(yum -q check-update 2>/dev/null | egrep -v "is broken|^Security:|^Loaded plugins" | awk '/^[[:alnum:]]/ {print $0}' | sort)

if [ -z "$PKGS" ]; then
  LAST_LOG=$(tac "$RESULT_FILE" | sed '/{/q' | tac)
  LINE_COUNT=$(echo "$LAST_LOG" | wc -l)
  if [ "$LINE_COUNT" -gt 1 ]; then
    echo '{ "failed": [], "installed": [], "upgraded": [] }' >> $RESULT_FILE
  fi
fi

cat <<EOF
{
  "updates": [
EOF

comma=''
while read -r line; do
  if [ -z "$line" ]; then
    continue
  fi
  name=$(echo "$line" | awk '{print $1}')
  version=$(echo "$line" | awk '{print $2}')
  repo=$(echo "$line" | awk '{print $3}')
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

