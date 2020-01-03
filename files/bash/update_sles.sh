#!/bin/bash
# Required environment variables 
# export PACKAGES     - list of packages to update
# export RESULT_FILE  - name of the file to write JSON results to
# export LOG_FILE     - name of the file to write OS specific patching logs to

## Zypper package manager
ZYPPER_UPDATE=$(zypper --non-interactive update $PACKAGES &>> "$LOG_FILE")
STATUS=$?
case $STATUS in
[1-4] | 6)
  echo "zypper --non-interactive update FAILED with an error. Please investigate."
  exit $STATUS
  ;;
5)
  echo "zypper --non-interactive update FAILED with insufficient privelidges. You probably forgot to run this as sudo."
  exit $STATUS
  ;;
7)
  echo "zypper --non-interactive update FAILED due to conflicting zypper run. Please try again once zypper is not running."
  exit $STATUS
  ;;
8)
  echo "zypper --non-interactive update FAILED due to dependency errors. Please investigate."
  exit $STATUS
  ;;
*)
  # all other exit codes are a form of success.
  ;;
esac

# The zypp/history file logs commands as well as results.
# Look for the last "|'zypper' 'up'|" line and print out everything in the file after that
# to get our previous transaction.
LAST_LOG=$(tac /var/log/zypp/history | sed "/|'zypper' 'up'|/q" | tac)
echo "$LAST_LOG" >> "$LOG_FILE"

# The log file contains install as well as other information items.
# We are only interested in the lines containing "|install|"
LAST_INSTALL=$(echo -n "$LAST_LOG" | grep '|install|')

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

  # The line should have the format:
  # <date>|install|<name>|<version>|<arch>|<user>|<repo>|<checksum>|
  name=$(echo "$line" | awk -F '|' '{print $3}')
  version=$(echo "$line" | awk -F '|' '{print $4}')
  arch=$(echo "$line" | awk -F '|' '{print $5}')
  repo=$(echo "$line" | awk -F '|' '{print $7}')

  if [ -n $comma ]; then
    echo "$comma" | tee -a "${RESULT_FILE}"
  fi
  echo "    {" | tee -a "${RESULT_FILE}"
  echo "      \"name\": \"${name}\"," | tee -a "${RESULT_FILE}"
  echo "      \"version\": \"${version}\"" | tee -a "${RESULT_FILE}"
  echo "      \"arch\": \"${arch}\"," | tee -a "${RESULT_FILE}"
  echo "      \"repo\": \"${repo}\"" | tee -a "${RESULT_FILE}"
  echo -n "    }" | tee -a "${RESULT_FILE}"
  comma=','
done <<< "$LAST_INSTALL"
tee -a "${RESULT_FILE}" <<EOF

  ],
EOF

# SLES does not record upgrades in the history file

exit $STATUS
