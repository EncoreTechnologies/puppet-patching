#!/bin/bash
# Required environment variables 
# export PACKAGES     - list of packages to update
# export RESULT_FILE  - name of the file to write JSON results to
# export LOG_FILE     - name of the file to write OS specific patching logs to

## Apt package manager
apt-get -y update &>> "$LOG_FILE"
STATUS=$?
if [[ $STATUS -ne 0 ]]; then
  echo "apt-get -y update FAILED, you probably forgot to run this as sudo or there is a network error."
  exit $STATUS
fi

APT_OPTS="-o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef --no-install-recommends"
if [[ -z $PACKAGES ]]; then
  # upgrade everything
  APT_COMMAND="dist-upgrade"
else
  # upgrade only specific packages
  APT_COMMAND="install"
  APT_OPTS="$APT_OPTS --only-upgrade"
fi

apt-get "$APT_OPTS" -y "$APT_COMMAND" &>> "$LOG_FILE"
STATUS=$?

# Sections in the apt/history.log file are segmented by a Start-Date and End-Date
# delimiters.
# Look for the last "Start-Date" line and print out everything in the file after that
# to get our previous transaction.
LAST_LOG=$(tac /var/log/apt/history.log | sed '/Start-Date/q' | tac)
echo "$LAST_LOG" >> "$LOG_FILE"

# the log has two sections:
# Install: <lots of packages>
# Upgrade: <logs of packages>
# This pulls the Install: and Upgrade: lines and removes that beginning heading
# leaving us with a single, very long, line of packages
LAST_INSTALL=$(echo -n "$LAST_LOG" | grep '^Install: ' | sed 's/Install: //g')
LAST_UPGRADE=$(echo -n "$LAST_LOG" | grep '^Upgrade: ' | sed 's/Upgrade: //g')

# Packages are in a long with with the format:
# Install:
# <name>:<arch> (<version>, automatic), <name> etc...
# Upgrade:
# <name>:<arch> (<old-version>, <new-version>), <name> etc...
#
# We want to split up this long line into individual lines, one for each package
# we do this by splitting on the ), that separates each package
LAST_INSTALL_PACKAGES=$(echo -n "$LAST_INSTALL" | sed 's/), /)\n/g')
LAST_UPGRADE_PACKAGES=$(echo -n "$LAST_UPGRADE" | sed 's/), /)\n/g')

# print out all Installed packages as JSON
tee -a "${RESULT_FILE}" <<EOF
{
  "installed": [
EOF
comma=''
while read -r line; do
  if [ -z "$line" ]; then
    continue
  fi
  
  # Install:
  # <name>:<arch> (<version>, automatic), <name> etc...
  pkg=$(echo "$line" | awk '{print $1}')
  # package is: <name>:<arch>
  name=$(echo "$pkg" | awk -F':' '{print $1}')

  # This gets the version number and removes the '(' and ',' characters
  # from the string
  version=$(echo "$line" | awk '{print $2}' | sed 's/(\|,//g')
  
  if [ -n $comma ]; then
    echo "$comma" | tee -a "${RESULT_FILE}"
  fi
  echo "    {" | tee -a "${RESULT_FILE}"
  echo "      \"name\": \"${name}\"," | tee -a "${RESULT_FILE}"
  echo "      \"version\": \"${version}\"" | tee -a "${RESULT_FILE}"
  echo -n "    }" | tee -a "${RESULT_FILE}"
  comma=','
done <<< "$LAST_INSTALL_PACKAGES"
tee -a "${RESULT_FILE}" <<EOF

  ],
EOF

# print out all Upgraded packages as JSON
tee -a "${RESULT_FILE}" <<EOF
  "upgraded": [
EOF
comma=''
while read -r line; do
  if [ -z "$line" ]; then
    continue
  fi
  
  # Upgrade:
  # <name>:<arch> (<old-version>, <new-version>), <name> etc...
  pkg=$(echo "$line" | awk '{print $1}')
  # package is: <name>:<arch>
  name=$(echo "$pkg" | awk -F':' '{print $1}')

  # This gets the old version number and removes the '(' and ',' characters
  # from the string
  version_old=$(echo "$line" | awk '{print $2}' | sed 's/(\|,//g')
  # Get the new version and remove the ')' from the string
  version=$(echo "$line" | awk '{print $3}' | sed 's/)//g')

  if [ -n $comma ]; then
    echo "$comma" | tee -a "${RESULT_FILE}"
  fi
  echo "    {" | tee -a "${RESULT_FILE}"
  echo "      \"name\": \"${name}\"," | tee -a "${RESULT_FILE}"
  echo "      \"version\": \"${version}\"," | tee -a "${RESULT_FILE}"
  echo "      \"version_old\": \"${version_old}\"" | tee -a "${RESULT_FILE}"
  echo -n "    }" | tee -a "${RESULT_FILE}"
  comma=','
done <<< "$LAST_UPGRADE_PACKAGES"
tee -a "${RESULT_FILE}" <<EOF

  ]
}
EOF

exit $STATUS
