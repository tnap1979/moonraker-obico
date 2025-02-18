#!/bin/sh

set -e

export OBICO_DIR=$(readlink -f $(dirname "$0"))/..

. "${OBICO_DIR}/scripts/funcs.sh"

SUFFIX=""
MOONRAKER_HOST="127.0.0.1"
MOONRAKER_PORT="7125"
OVERWRITE_CONFIG="n"
SKIP_LINKING="n"

usage() {
  if [ -n "$1" ]; then
    echo "${red}${1}${default}"
    echo ""
  fi
  cat <<EOF
Usage: $0 <[options]>   # Interactive installation to get moonraker-obico set up. Recommended if you have only 1 printer

Options:
          -s   Install moonraker-obico on a Sonic Pad
          -k   Install moonraker-obico on a K1/K1 Max
          -u   Show uninstallation instructions
EOF
}

ensure_deps() {
  report_status "Installing required system packages..."
  PKGLIST="python3 python3-pip"
  opkg install ${PKGLIST}
  pip3 install -q --no-cache-dir virtualenv
  ensure_venv
  debug Running... "${OBICO_ENV}"/bin/pip3 install -q --require-virtualenv --no-cache-dir -r "${OBICO_DIR}"/requirements.txt
  "${OBICO_ENV}"/bin/pip3 install -q --require-virtualenv --no-cache-dir -r "${OBICO_DIR}"/requirements.txt
  echo ""
}

recreate_service() {
  if [ $CREALITY_VARIANT = "sonic_pad" ]; then
    cp "${OBICO_DIR}"/scripts/openwrt_init.d/moonraker_obico_service /etc/init.d/
    rm -f /etc/rc.d/S67moonraker_obico_service
    rm -f /etc/rc.d/K1moonraker_obico_service
    ln -s ../init.d/moonraker_obico_service /etc/rc.d/S67moonraker_obico_service
    ln -s ../init.d/moonraker_obico_service /etc/rc.d/K1moonraker_obico_service
  elif [ $CREALITY_VARIANT = "k1" ]; then
    cp "${OBICO_DIR}"/scripts/openwrt_init.d/S99moonraker_obico /etc/init.d/
  fi
}

uninstall() {
  cat <<EOF
To uninstall Moonraker-Obico, please run:

rm -rf $OBICO_DIR
rm -rf $OBICO_DIR/../moonraker-obico-env
EOF

  if is_k1; then

    cat <<EOF
rm -f /etc/init.d/S99moonraker_obico
EOF

  else

    cat <<EOF
rm -f /etc/init.d/moonraker_obico_service
rm -f /etc/rc.d/S67moonraker_obico_service
rm -f /etc/rc.d/K1moonraker_obico_service
EOF

  fi
  exit 0
}

trap 'unknown_error' INT

prompt_for_variant_if_needed() {

  if [ -n "${CREALITY_VARIANT}" ]; then
    return
  fi

  echo "What Creality system are you installing Obico on right now?"
  echo "1) Sonic Pad"
  echo "2) K1/K1 Max"
  echo "3) Other"
  echo ""

  read user_input
  if [ "$user_input" = "1" ]; then
      CREALITY_VARIANT="sonic_pad"
  elif [ "$user_input" = "2" ]; then
      CREALITY_VARIANT="k1"
  else
      echo "Obico doesn't currently support this model."
      exit 0
  fi
}

# Parse command line arguments
while getopts "sku" arg; do
    case $arg in
        s) CREALITY_VARIANT="sonic_pad" ;;
        k) CREALITY_VARIANT="k1" ;;
        u) prompt_for_variant_if_needed && uninstall ;;
        *) usage && exit 1;;
    esac
done

prompt_for_variant_if_needed

if is_k1; then
  MOONRAKER_CONF_DIR="/usr/data/printer_data/config"
  MOONRAKER_LOG_DIR="/usr/data/printer_data/logs"
else
  MOONRAKER_CONF_DIR="/mnt/UDISK/printer_config"
  MOONRAKER_LOG_DIR="/mnt/UDISK/printer_logs"
fi

MOONRAKER_CONFIG_FILE="${MOONRAKER_CONF_DIR}/moonraker.conf"
OBICO_CFG_FILE="${MOONRAKER_CONF_DIR}/moonraker-obico.cfg"
OBICO_UPDATE_FILE="${MOONRAKER_CONF_DIR}/moonraker-obico-update.cfg"
OBICO_LOG_FILE="${MOONRAKER_LOG_DIR}/moonraker-obico.log"

welcome
ensure_deps

if ! cfg_existed ; then
  create_config
fi

recreate_service
recreate_update_file

trap - INT

if [ $SKIP_LINKING != "y" ]; then
  debug Running... "sh ${OBICO_DIR}/scripts/link.sh" -c "${OBICO_CFG_FILE}" -n \"${SUFFIX:1}\" -S
  sh "${OBICO_DIR}/scripts/link.sh" -c "${OBICO_CFG_FILE}" -n "${SUFFIX:1}" -S
fi
