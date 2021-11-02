#!/bin/bash

cfgdir=/etc/zfs-auto
[[ ! -d "$cfgdir" ]] && "[ERROR] /etc/zfs-auto must exist" && exit 1

## TODO logging?

########################################################################
# Functions                                                            #
########################################################################

sshx() {
  [[ -z "$1" ]] && eval "${@:2}" || ssh -t -q -o "BatchMode=yes" "$1" "${@:2}"
  return $?
}


########################################################################
# Parse arguments                                                      #
########################################################################

label=''
debug=false
while getopts "dl:" option; do
  case $option in
    d) debug=true;;
    l) label=$OPTARG;; ## e.g. "hourly|daily|weekly|monthly"
  esac
done

# legacy: enable debug if set as individual parameter
for param in "$@"; do
  [[ "$param" == "debug" ]] && debug=true
done

# script may be linked below /etc/cron.${label}
[[ -z "$label" ]] \
  && label=$(basename $(dirname $0) | cut -d '.' -f2)

## verify label as hourly, daily, weekly or monthly
validLabel=false
for l in hourly daily weekly monthly; do
  [[ "$l" == "$label" ]] && validLabel=true && break
done
$validLabel || exit 1


########################################################################
# Main                                                                 #
########################################################################

for path in ${cfgdir}/*; do
  host=''
  dataset=''
  snap_hourly=false
  snap_daily=false
  snap_weekly=false
  snap_monthly=false
  snap_recursive=false
  snap_destroy_only=false
  source $path
  [[ $dataset =~ ":" ]] \
    && host=$(echo $dataset | cut -d ':' -f 1) \
    && dataset=$(echo $dataset | cut -d ':' -f 2)
  [[ -z "$dataset" ]] && continue
  snap_enable=snap_${label}
  snap_enable=${!snap_enable}
  [[ "$snap_enable" != true && ! "$snap_enable" -gt 0 ]] && continue
  [[ "$debug" == true ]] && opts="--dry-run"
  opts="${opts} --prefix=auto --label=${label}"
  [[ "$snap_enable" -gt 0 ]] && opts="${opts} --keep=${snap_enable}"
  [[ "$snap_recursive" == true ]] && opts="${opts} --recursive"
  [[ "$snap_destroy_only" == true ]] && opts="${opts} --destroy-only"
  echo "run: ${opts} ${host}:${dataset}"
  pathSet="PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/bin:/sbin:/bin'"
  checkCmd="command -v zfs-auto-snapshot &> /dev/null"
  execCmd="zfs-auto-snapshot ${opts} ${dataset}"
  sshx "$host" "${pathSet} && ${checkCmd} && ${execCmd}"
done

exit 0
