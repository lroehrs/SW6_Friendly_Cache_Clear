#!/bin/bash
#lroehrs

cd "$(dirname "$0")" || { echo "ERROR: cd $(dirname "$0") failed." >&2; exit 1; }

exec {lock_fd}> ".$(basename $0).lck" || exit 1
flock -n "$lock_fd" || { echo "ERROR: flock() failed." >&2; exit 1; }

prod_dir="$(find . -maxdepth 1  -type d -name "prod_*")"
dev_dir="$(find . -maxdepth 1 -type d -name "dev_*")"

if [[ "$( echo ${prod_dir} | wc -l)" -eq "0" ]] && [[ "$(${dev_dir} | wc -l)" -eq "0" ]]; then
  echo "Couldn't find cache directory.. Exit!"; exit 1
fi

fcc_empty=".fcc_empty"
if [[ ! -d "$fcc_empty" ]]; then
  mkdir $fcc_empty
fi

fcc_del=".fcc_delete"
if [[ ! -d "$fcc_del" ]]; then
  mkdir $fcc_del
fi

num="0"
if [[ "$( echo ${prod_dir}] | wc -l)" -ge "1" ]]; then
  echo "Start moving caches -> prod"
  for prod in ${prod_dir}; do
    mv ${prod} ${fcc_del}/${num}
    ((num++))
  done
fi

if [[ "$( echo ${dev_dir} | wc -l)" -ge "1" ]]; then
  echo "Start moving caches -> dev"
  for dev in ${dev_dir}; do
    mv ${dev} ${fcc_del}/${num}
    ((num++))
  done
fi

echo "Compile Theme.."
php ../../bin/console theme:compile > /dev/null
echo "Warm-Up Cache.."
php ../../bin/console cache:warmup > /dev/null
echo "Warm-Up HTTP Cache.."
php ../../bin/console http:cache:warm:up > /dev/null

if [[ -x "$(command -v rsync)" ]]; then
  echo "Deleting cache now friendly.."
  rsync -a --delete ${fcc_empty}/ ${fcc_del}/
else
  echo -e "Can't use rsync, please install it. \Use unfriendly rm instead.."
  rm -Rf ${fcc_del}
fi
