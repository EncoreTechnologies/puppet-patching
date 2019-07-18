#!/bin/bash

## TODO: make our log file format cleaner
## TODO: potentially write JSON to log file?

PACKAGES="$PT_names"
LOG_FILE="$PT_log_file"
if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="/var/log/patching.log"
fi
if [[ ! -e "$LOG_FILE" ]]; then
  touch "$LOG_FILE"
fi

DEBTEST=$(lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}')
RHTEST=$(cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g")

function rpm_name_split() {
  rpm_name="$1"
  # if this host is a Red Hat host with Yum, it will have Python because
  # Yum/dnf is written in python.
  rpm_name_split=$(echo "${rpm_name}" | python -c "import sys; from rpmUtils.miscutils import splitFilename; (n, v, r, e, a) = splitFilename(sys.stdin.read()); print('name={}'.format(n)); print('version={}'.format(v)); print('release={}'.format(r)); print('epoch={}'.format(e)); print('arch={}'.format(a))")
  echo "${rpm_name_split}"
}

STATUS=0
################################################################################
if [[ -n "$RHTEST" ]]; then
  ## Yum package manager.
  yum -y update $PACKAGES &>> "$LOG_FILE"
  STATUS=$?

  ## Collect yum history if update was performed.
  YUM_HISTORY_LAST_ID=$(yum history list | grep -Em 1 '^ *[0-9]' | awk '{ print $1 }')
  YUM_HISTORY=$(yum history info "$YUM_HISTORY_LAST_ID" &>> "$LOG_FILE")

  # Installed   <package>  <repo>
  # example:
  #     Installed     rpm-4.11.3-35.el7.x86_64       @base
  LAST_INSTALL=$(echo "$YUM_HISTORY" | grep "Installed")
  cat <<EOF
{
  "installed": [
EOF
  comma=''
  while read -r line; do
    pkg_name=$(echo "$line" | awk '{print $2}')
    repo=$(echo "$line" | awk '{print $3}')
    
    pkg_name_split=$(rpm_name_split $pkg_name)
    name=$(echo "$pkg_name_split" | grep '^name=' | awk -F'=' '{print $2}')
    version=$(echo "$pkg_name_split" | grep '^version=' | awk -F'=' '{print $2}')
    
    if [ -n $comma ]; then
      echo "$comma"
    fi
    echo "    {"
    echo "      \"name\": \"${name}\","
    echo "      \"version\": \"${version}\","
    echo "      \"repo\": \"${repo}\""
    echo -n "    }"
    comma=','
  done <<< "$LAST_INSTALL"
  cat <<EOF

  ],
EOF
  
  # Updated <package-old-version> <repo>
  # Update     <new-version> <repo>
  # Example:
  #     Updated puppet-bolt-1.25.0-1.el7.x86_64 @puppet6
  #     Update              1.26.0-1.el7.x86_64 @puppet6
  LAST_UPGRADE=$(echo "$YUM_HISTORY" | grep -A1 "Updated")
  cat <<EOF
  "upgraded": [
EOF
  comma=''
  while read -r line_updated && read -r line_update; do
    pkg_name=$(echo "$line_updated" | awk '{print $2}')
    repo=$(echo "$line_updated" | awk '{print $3}')

    pkg_name_split=$(rpm_name_split $pkg_name)
    name=$(echo "$pkg_name_split" | grep '^name=' | awk -F'=' '{print $2}')
    version_old=$(echo "$pkg_name_split" | grep '^version=' | awk -F'=' '{print $2}')

    pkg_ver_new=$(echo "$line_update" | awk '{print $2}')
    pkg_ver_split=$(rpm_name_split $pkg_ver_new)
    version=$(echo "$pkg_ver_split" | grep '^version=' | awk -F'=' '{print $2}')

    if [ -n $comma ]; then
      echo "$comma"
    fi
    echo "    {"
    echo "      \"name\": \"${name}\","
    echo "      \"version\": \"${version}\","
    echo "      \"version_old\": \"${version_old}\","
    echo "      \"repo\": \"${repo}\""
    echo -n "    }"
    comma=','
  done <<< "$LAST_UPGRADE"
  cat <<EOF

  ]
}
EOF

################################################################################  
elif [[ -n "$DEBTEST" ]]; then
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
  LAST_LOG=$(tac /var/log/apt/history.log | awk '!flag; /Start-Date/{flag = 1};' | tac)
  echo "$LAST_LOG" >> "$LOG_FILE"
  
  # the log has two sections:
  # Install: <lots of packages>
  # Upgrade: <logs of packages>
  # This pulls the Install: and Upgrade: lines and removes that beginning heading
  # leaving us with a single, very long, line of packages
  LAST_INSTALL=$(echo "$LAST_LOG" | grep '^Install: ' | sed 's/Install: //g')
  LAST_UPGRADE=$(echo "$LAST_LOG" | grep '^Upgrade: ' | sed 's/Upgrade: //g')

  # Packages are in a long with with the format:
  # Install:
  # <name>:<arch> (<version>, automatic), <name> etc...
  # Upgrade:
  # <name>:<arch> (<old-version>, <new-version>), <name> etc...
  #
  # We want to split up this long line into individual lines, one for each package
  # we do this by splitting on the ), that separates each package
  LAST_INSTALL_PACKAGES=$(echo "$LAST_INSTALL" | sed 's/), /)\n/g')
  LAST_UPGRADE_PACKAGES=$(echo "$LAST_UPGRADE" | sed 's/), /)\n/g')

  # print out all Installed packages as JSON
  cat <<EOF
{
  "installed": [
EOF
  comma=''
  while read -r line; do
    # Install:
    # <name>:<arch> (<version>, automatic), <name> etc...
    pkg=$(echo "$line" | awk '{print $1}')
    # package is: <name>:<arch>
    name=$(echo "$pkg" | awk -F':' '{print $1}')

    # This gets the version number and removes the '(' and ',' characters
    # from the string
    version=$(echo "$line" | awk '{print $2}' | sed 's/(\|,//g')
    
    if [ -n $comma ]; then
      echo "$comma"
    fi
    echo "    {"
    echo "      \"name\": \"${name}\","
    echo "      \"version\": \"${version}\""
    echo -n "    }"
    comma=','
  done <<< "$LAST_INSTALL_PACKAGES"
  cat <<EOF

  ],
EOF

  # print out all Upgraded packages as JSON
  cat <<EOF
  "upgraded": [
EOF
  comma=''
  while read -r line; do
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
      echo "$comma"
    fi
    echo "    {"
    echo "      \"name\": \"${name}\","
    echo "      \"version\": \"${version}\","
    echo "      \"version_old\": \"${version_old}\""
    echo -n "    }"
    comma=','
  done <<< "$LAST_UPGRADE_PACKAGES"
  cat <<EOF

  ]
}
EOF

################################################################################
else
  echo "Unknown Operating System: DEBTEST=${DEBTEST} RHTEST=${RHTEST}"
  exit 2
fi

exit $STATUS
