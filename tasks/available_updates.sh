#!/bin/bash

DEBTEST=$(lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}')
RHTEST=$(cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g")

################################################################################
if [[ -n "$RHTEST" ]]; then
  # Sometimes yum check-update will output extra info like this:
  # ---
  # Security: kernel-3.14.6-200.fc20.x86_64 is an installed security update
  # Security: kernel-3.14.2-200.fc20.x86_64 is the currently running version
  # ---
  # We need to filter those out as they screw up the package listing
  PKGS=$(yum -q check-update 2>/dev/null | egrep -v "is broken|^Security:|^Loaded plugins" | awk '/^[[:alnum:]]/ {print $0}' | sort)
  cat <<EOF
{
  "updates": [
EOF
  comma=''
  while read -r line; do
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

################################################################################
elif [[ -n "$DEBTEST" ]]; then
  PKGS=$(apt upgrade --simulate 2>/dev/null | awk '$1 == "Inst" {print $0}' | sort)
  cat <<EOF
{
  "updates": [
EOF
  comma=''
  while read -r line; do
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

################################################################################  
else
  echo "Unknown Operating System: DEBTEST=${DEBTEST} RHTEST=${RHTEST}"
  exit 2
fi

# # PKGS contains one package per line, we need to convert this to JSON format
# PKGS_JSON_ARRAY=$(echo -n "[\"$PKGS\"]" | tr '\n' ' ' | sed -e 's/\s\+/", "/g')
# cat <<JSON
# {
#   "updates": ${PKGS_JSON_ARRAY}
# }
# JSON
