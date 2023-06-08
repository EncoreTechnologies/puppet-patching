#!/bin/bash

# Sometimes yum check-update will output extra info like this:
# ---
# Security: kernel-3.14.6-200.fc20.x86_64 is an installed security update
# Security: kernel-3.14.2-200.fc20.x86_64 is the currently running version
# ---
# We need to filter those out as they screw up the package listing
#
# Also the PhotonOS version of tdnf generates lines by printing spaces, the
# repository, a carriage return, (less) spaces, the version, a carriage return,
# the package name and a line feed.  The human output is unchanged but this
# confuse the rest of the tooling, so "fix" the output to have the expected
# format.
PKGS=$(yum -q check-update 2>/dev/null | egrep -v "is broken|^Security:|^Loaded plugins" | awk '{ split($0, r, "\x0d"); res = r[1]; for (f in r) { keep = substr(res, 1 + length(r[f])); res = r[f] keep }; print res }' | grep -e '^[[:alnum:]]' | sort)
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

