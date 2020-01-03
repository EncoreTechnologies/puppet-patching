#!/bin/bash

#############################################################################
# Find available updates on SLES variants                                   #
#                                                                           #
# zypper optionally gives the output as structured XML. We are using this   #
# to focus on the interesting bits and returning the JSON that is expected. #
#############################################################################

# read_dom
# read the XML input and seperate the tag from the attributes
# credit: https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
read_dom () {
  local IFS=\>
  read -d \< ENTITY CONTENT
  local ret=$?
  TAG_NAME=${ENTITY%% *}
  ATTRIBUTES=${ENTITY#* }
  return $ret
}

# parse_attr
# Some the the attributes have illegal variables in them from the DOM (valid in DOM
# invalid in BASH). This replaces '-' with "_" in the attribute name and strips
# all characters from the end if they are outside the last quote.
parse_attr () {
  local ATTR_ARRAY=( $ATTRIBUTES )
  ATTRIBUTES=""

  for ATTR in "${ATTR_ARRAY[@]}"
  do
    LINE=$(echo $ATTR | awk -F = -v OFS== '{gsub(/-/, "_", $1); print}')
    LINE=${LINE%\"*}
    LINE="${LINE}\""
    ATTRIBUTES="${ATTRIBUTES} ${LINE}"
  done
}

# parse_dom
# There are two interesting segments update and source. An example entry is:
# <update name="cpp7" edition="7.5.0+r278197-4.12.1" arch="x86_64" kind="package" edition-old="7.4.1+r275405-4.9.2" >
#  <summary>The GCC Preprocessor</summary>
#  <description>This Package contains just the preprocessor that is used by the X11 packages.</description>
#  <license></license>
#  <source url="https://updates.suse.com/SUSE/Updates/SLE-Module-Basesystem/15/x86_64/update" alias="Basesystem_Module_15_x86_64:SLE-Module-Basesystem15-Updates"/>
# </update>
#
# We are parsing the update line into a variable, then when the source line comes along we are dumping it, and the source alias into the JSON output.
parse_dom () {
  if [[ $TAG_NAME = "update" ]] ; then
    parse_attr

    local $ATTRIBUTES
    PKG_NAME=${name}
    PKG_VER=${edition}
  fi

  if [[ $TAG_NAME = "source" ]] ; then
    if [ -n $comma ]; then
      echo -n "$comma"
    fi

    parse_attr
    local $ATTRIBUTES
    echo " {"
    echo "      \"name\": ${PKG_NAME},"
    echo "      \"repo\": ${alias},"
    echo "      \"version\": ${PKG_VER}"

    echo -n "    }"
    comma=','
  fi
}

#############
# Main code #
#############
PKGS=$(zypper -x lu 2>/dev/null)
echo "{"
echo -n '  "updates": ['

comma=''
while read_dom; do
  parse_dom
done <<< "$PKGS"

echo ''
cat <<EOF
  ]
}
EOF

