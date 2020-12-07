#!/bin/bash
#@lroehrs / Profihost AG 2020

NC='\033[0;m'
CR='\033[0;31m'
CG='\033[0;32m'
CPH='\033[1;32m'
CY='\033[0;33m'

cd "$(dirname "$0")" || { echo -e ${CR}"ERROR: cd $(dirname "$0") failed."${NC} >&2; exit 1; }

exec {lock_fd}> ".$(basename $0).lck" || exit 1
flock -n "$lock_fd" || { echo -e ${CR}"ERROR: flock() failed."${NC} >&2; exit 1; }

function show_help {
  echo -e ${CPH}"\n+-----------------+"${NC}
  echo -e ${CPH}"|Profihost AG 2020|"${NC}
  echo -e ${CPH}"+-----------------+\n"${NC}
  echo -e "Usage: $0 (for Shopware 6) [options [parameter]]\n"
  echo -e "Options:"
  echo -e "-bw|--rsync-bwlimit [KB/s], Set rsync Bandwith Limit in KBytes per second. See rsync Manuel. Default: 50000"
  echo -e "-h |--help, Print what you see"
  exit 0
}

function x_re {
  re=$?
  if [[ $re -eq "0" ]]; then
    echo -e ${CG}"successfully"${NC}
  else
    echo -e ${CR}"ERROR: The process wasn't successfully..\nError Code: $re"${NC} >&2 ; exit $re
  fi
}

while [[ -n $1 ]]; do
  case "$1" in
    -h|--help)
      show_help ;;
    -bw|--rsync-bwlimit)
      shift
      rsync_bw_value="$1"
      shift ;;
    *)
      echo -e ${CR}"ERROR: Incorrect arguments"${NC}
      show_help ;;
  esac
done


prod_dir="$(find . -maxdepth 1  -type d -name "prod_*")"
dev_dir="$(find . -maxdepth 1 -type d -name "dev_*")"

if [[ "$( echo ${prod_dir} | wc -c )" -le "1" ]] && [[ "$(${dev_dir} | wc -c)" -le "1" ]]; then
  echo -e ${CR}"ERROR: Couldn't find cache directory.. Exit!"${NC} >&2; exit 1;
fi

fcc_empty=".fcc_empty"
if [[ ! -d "$fcc_empty" ]]; then
  mkdir $fcc_empty
fi

fcc_del=".fcc_delete"
if [[ ! -d "$fcc_del" ]]; then
  mkdir $fcc_del
fi

num="1"
if [[ "$( echo ${prod_dir} | wc -c )" -ge "2" ]]; then
  echo "Start moving caches -> prod"
  for prod in ${prod_dir}; do
    mv ${prod} ${fcc_del}/${num}
    ((num++))
  done
  x_re
fi

if [[ "$( echo ${dev_dir} | wc -c )" -ge "2" ]]; then
  echo "Start moving caches -> dev"
  for dev in ${dev_dir}; do
    mv ${dev} ${fcc_del}/${num}
    ((num++))
  done
  x_re
fi

echo "Compile Theme.."
php ../../bin/console theme:compile > /dev/null ; x_re
echo "Warm-Up Cache.."
php ../../bin/console cache:warmup > /dev/null ; x_re
echo "Warm-Up HTTP Cache.."
php ../../bin/console http:cache:warm:up > /dev/null ; x_re

if [[ -z "${rsync_bw_value}" ]]; then
  rsync_bw="--bwlimit=50000"
else
  rsync_bw="--bwlimit=${rsync_bw_value}"
fi

if [[ -x "$(command -v rsync)" ]]; then
  echo "Deleting cache now friendly.."
  rsync -a --delete ${rsync_bw} ${fcc_empty}/ ${fcc_del}/ ; x_re
else
  echo -e ${CY}"Can't use rsync, please install it. \Use unfriendly rm instead.."${NC}
  rm -Rf ${fcc_del} ; x_re
fi
