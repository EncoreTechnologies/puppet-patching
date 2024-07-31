#!/bin/bash

export RESULT_FILE="$PT_result_file"
if [[ -z "$RESULT_FILE" ]]; then
  export RESULT_FILE="/var/log/patching.json"
fi
if [[ ! -e "$RESULT_FILE" ]]; then
  echo '{"installed": [], "upgraded": []}'
  exit 0
fi

# The result_file is a file where each record is a JSON dictionary.
# Look for the last "{" line and print out everything in the file after that
# to get our previous transaction.
LAST_LOG=$(tac "$RESULT_FILE" | sed '/^{$/q' | tac)
echo "$LAST_LOG"
exit 0
