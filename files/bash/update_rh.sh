#!/bin/bash
# Required environment variables 
# export PACKAGES     - list of packages to update
# export RESULT_FILE  - name of the file to write JSON results to
# export LOG_FILE     - name of the file to write OS specific patching logs to

function rpm_name_split() {
  rpm_name="$1"
  # if this host is a Red Hat host with Yum, it will have Python because
  # Yum/dnf is written in python.
  PYTHON_SCRIPT=$(cat <<EOF
import sys
# copied: from rpmUtils.miscutils import splitFilename
# this is broken when parsing Epochs that are in the version string, so
# we had to implement our own... sorry

def splitFilename(filename):
    """
    Pass in a standard style rpm fullname 
    
    Return a name, version, release, epoch, arch, e.g.::
        foo-1.0-1.i386.rpm returns foo, 1.0, 1, i386
        1:bar-9-123a.ia64.rpm returns bar, 9, 123a, 1, ia64
    """

    if filename[-4:] == '.rpm':
        filename = filename[:-4]
       
    archIndex = filename.rfind('.')
    arch = filename[archIndex+1:]

    relIndex = filename[:archIndex].rfind('-')
    rel = filename[relIndex+1:archIndex]

    verIndex = filename[:relIndex].rfind('-')
    ver = filename[verIndex+1:relIndex]

    epochIndex = ver.find(':')
    if epochIndex == -1:
        epoch = ''
    else:
        epoch = ver[:epochIndex]
        ver = ver[epochIndex+1:]
    
    name = filename[:verIndex]
    if verIndex == -1:
       name = ''
    return name, ver, rel, epoch, arch


filename = sys.stdin.read()
(n, v, r, e, a) = splitFilename(filename)

print('name={}'.format(n))
print('version={}'.format(v))
print('release={}'.format(r))
print('epoch={}'.format(e))
print('arch={}'.format(a))
EOF
               )
  rpm_name_split=$(echo "${rpm_name}" | python -c "${PYTHON_SCRIPT}")
  echo "${rpm_name_split}"
}

################################################################################

STATUS=0

## Yum package manager
#
# Because we're using '| tee' inside a $(), we can't just check $? after the command
# as it will return the exit code of the LAST thing in the pipe,
# instead we really want to return code of the `yum` command (first thing in the pipe).
# For this to work, we need to exit the command in the $() with a value
# from the $PIPESTATUS array to get access to the `yum` command's return value.
# Now, the exit status for the $() will be whatever the exit status is for `yum` instead
# of the exit status of `tee`.
YUM_UPDATE=$(yum -y update $PACKAGES | tee -a "$LOG_FILE"; exit ${PIPESTATUS[0]})
STATUS=$?

# check if packages were updated or not
if echo "$YUM_UPDATE" | grep -q "No packages marked for"; then
  tee -a "${RESULT_FILE}" <<EOF
{
  "installed": [],
  "upgraded": []
}
EOF
else
  ## Collect yum history if update was performed.
  YUM_HISTORY_LAST_ID=$(yum history list | grep -Em 1 '^ *[0-9]' | awk '{ print $1 }')
  YUM_HISTORY_FULL=$(yum history info "$YUM_HISTORY_LAST_ID" | tee -a "$LOG_FILE")
  
  # Yum history contains a section called "Packages Altered:" that has details
  # of all of the things that changed during the yum transaction. This is what
  # we want to parse below and the awk statement finds the "Packages Altered:" heading
  # and then prints out the rest of the output from that point on, discarding the earlier
  # output.
  YUM_HISTORY=$(echo "$YUM_HISTORY_FULL" | tac | sed '/Packages Altered:/q' | tac)
  
  # Installed   <package>  <repo>
  # example:
  #     Installed     rpm-4.11.3-35.el7.x86_64       @base
  # example RHEL 8:
  #     Install     rpm-4.11.3-35.el7.x86_64       @base
  LAST_INSTALL=$(echo "$YUM_HISTORY" | grep "Install\|Installed\|Dep-Install")
  tee -a "${RESULT_FILE}" <<EOF
{
  "installed": [
EOF
  comma=''
  while read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    pkg_name=$(echo "$line" | awk '{print $2}')
    repo=$(echo "$line" | awk '{print $3}')
    
    pkg_name_split=$(rpm_name_split "$pkg_name")
    name=$(echo "$pkg_name_split" | grep '^name=' | awk -F'=' '{print $2}')
    version=$(echo "$pkg_name_split" | grep '^version=' | awk -F'=' '{print $2}')
    release=$(echo "$pkg_name_split" | grep '^release=' | awk -F'=' '{print $2}')
    epoch=$(echo "$pkg_name_split" | grep '^epoch=' | awk -F'=' '{print $2}')
    arch=$(echo "$pkg_name_split" | grep '^arch=' | awk -F'=' '{print $2}')
    
    if [ -n $comma ]; then
      echo "$comma" | tee -a "${RESULT_FILE}"
    fi
    echo "    {" | tee -a "${RESULT_FILE}"
    echo "      \"full\": \"${pkg_name}\"," | tee -a "${RESULT_FILE}"
    echo "      \"name\": \"${name}\"," | tee -a "${RESULT_FILE}"
    echo "      \"version\": \"${version}\"," | tee -a "${RESULT_FILE}"
    echo "      \"release\": \"${release}\"," | tee -a "${RESULT_FILE}"
    echo "      \"epoch\": \"${epoch}\"," | tee -a "${RESULT_FILE}"
    echo "      \"arch\": \"${arch}\"," | tee -a "${RESULT_FILE}"
    echo "      \"repo\": \"${repo}\"" | tee -a "${RESULT_FILE}"
    echo -n "    }" | tee -a "${RESULT_FILE}"
    comma=','
  done <<< "$LAST_INSTALL"
  tee -a "${RESULT_FILE}" <<EOF

  ],
EOF
  
  # Updated <package-old-version> <repo>
  # Update     <new-version> <repo>
  # Example:
  #     Updated puppet-bolt-1.25.0-1.el7.x86_64 @puppet6
  #     Update              1.26.0-1.el7.x86_64 @puppet6
  # Example RHEL 8:
  #     Upgrade   st2-3.6.0-3.x86_64 @StackStorm_stable
  #     Upgraded  st2-3.5.0-1.x86_64 @@System
  LAST_UPGRADE=$(echo "$YUM_HISTORY" | grep "Upgraded \| Upgrade \| Updated \| Update ")
  tee -a "${RESULT_FILE}" <<EOF
  "upgraded": [
EOF
  comma=''
  while read -r line_updated_old && read -r line_update_new; do
    if [ -z "$line_updated_old" ]; then
      continue
    fi
    ### Old (Updated: )
    pkg_name_old=$(echo "$line_updated_old" | awk '{print $2}')
    repo_old=$(echo "$line_updated_old" | awk '{print $3}')
  
    pkg_name_old_split=$(rpm_name_split "$pkg_name_old")
    name_old=$(echo "$pkg_name_old_split" | grep '^name=' | awk -F'=' '{print $2}')
    version_old=$(echo "$pkg_name_old_split" | grep '^version=' | awk -F'=' '{print $2}')
    release_old=$(echo "$pkg_name_old_split" | grep '^release=' | awk -F'=' '{print $2}')
    epoch_old=$(echo "$pkg_name_old_split" | grep '^epoch=' | awk -F'=' '{print $2}')
    arch_old=$(echo "$pkg_name_old_split" | grep '^arch=' | awk -F'=' '{print $2}')
  
    ### New (Update: )
    pkg_name_new=$(echo "$line_update_new" | awk '{print $2}')
    repo_new=$(echo "$line_update_new" | awk '{print $3}')
    
    pkg_name_new_split=$(rpm_name_split "$pkg_name_new")
    name_new=$(echo "$pkg_name_new_split" | grep '^name=' | awk -F'=' '{print $2}')
    version_new=$(echo "$pkg_name_new_split" | grep '^version=' | awk -F'=' '{print $2}')
    release_new=$(echo "$pkg_name_new_split" | grep '^release=' | awk -F'=' '{print $2}')
    epoch_new=$(echo "$pkg_name_new_split" | grep '^epoch=' | awk -F'=' '{print $2}')
    arch_new=$(echo "$pkg_name_new_split" | grep '^arch=' | awk -F'=' '{print $2}')
  
    # The "Update: " lines usually (for some reason) don't contain the package name
    # so we use name from the "Updated: " lines instead.
    name="${name_new}"
    if [ -z "${name}" ]; then
      name="${name_old}"
    fi
  
    if [ -n $comma ]; then
      echo "$comma" | tee -a "${RESULT_FILE}"
    fi
    echo "    {" | tee -a "${RESULT_FILE}"
    echo "      \"full\": \"${pkg_name_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"full_old\": \"${pkg_name_old}\"," | tee -a "${RESULT_FILE}"
    echo "      \"name\": \"${name}\"," | tee -a "${RESULT_FILE}"
    echo "      \"version\": \"${version_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"version_old\": \"${version_old}\"," | tee -a "${RESULT_FILE}"
    echo "      \"release\": \"${release_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"release_old\": \"${release_old}\"," | tee -a "${RESULT_FILE}"
    echo "      \"epoch\": \"${epoch_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"epoch_old\": \"${epoch_old}\"," | tee -a "${RESULT_FILE}"
    echo "      \"arch\": \"${arch_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"arch_old\": \"${arch_old}\"," | tee -a "${RESULT_FILE}"
    echo "      \"repo\": \"${repo_new}\"," | tee -a "${RESULT_FILE}"
    echo "      \"repo_old\": \"${repo_old}\"" | tee -a "${RESULT_FILE}"
    echo -n "    }" | tee -a "${RESULT_FILE}"
    comma=','
  done <<< "$LAST_UPGRADE"
  tee -a "${RESULT_FILE}" <<EOF

  ]
}
EOF
fi
                         
exit $STATUS
