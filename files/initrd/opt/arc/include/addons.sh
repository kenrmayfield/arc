###############################################################################
# Return list of available addons
# 1 - Platform
function availableAddons() {
  if [ -z "${1}" ]; then
    echo ""
    return 1
  fi
  MACHINE="$(virt-what 2>/dev/null | head -1)"
  [ -z "${MACHINE}" ] && MACHINE="physical"
  for D in $(find "${ADDONS_PATH}" -maxdepth 1 -type d 2>/dev/null | sort); do
    [ ! -f "${D}/manifest.yml" ] && continue
    local ADDON=$(basename "${D}")
    local SYSTEM=$(readConfigKey "system" "${D}/manifest.yml")
    [ "${SYSTEM}" = true ] && continue
    local AVAILABLE="$(readConfigKey "${1}" "${D}/manifest.yml")"
    [ "${AVAILABLE}" = false ] && continue
    if [ "${MACHINE}" = "physical" ]; then
      if [ "${ADDON}" = "ledcontrol" ]; then
        if is_in_array "${1}" "${KVER5L[@]}"; then
          UGREEN_CHECK=$(dmidecode --string system-product-name 2>/dev/null)
          case "${UGREEN_CHECK}" in
            DXP6800*|DX4600*|DX4700*|DXP2800*|DXP4800*|DXP8800*)
              ;;
            *)
              continue
              ;;
          esac
        else
          continue
        fi
      elif [ "${ADDON}" = "fancontrol" ] && ! is_in_array "${1}" "${KVER5L[@]}"; then
        continue
      fi
    elif [ "${MACHINE}" != "physical" ] && { [ "${ADDON}" = "cpufreqscaling" ] || [ "${ADDON}" = "fancontrol" ] || [ "${ADDON}" = "ledcontrol" ]; }; then
      continue
    fi
    local DESC="$(readConfigKey "description" "${D}/manifest.yml")"
    local BETA="$(readConfigKey "beta" "${D}/manifest.yml")"
    local TARGET="$(readConfigKey "target" "${D}/manifest.yml")"
    [ "${BETA}" = true ] && BETA="(Beta) " || BETA=""
    if [ "${TARGET}" = "app" ]; then
      [ "${AVAILABLE}" = true ] && echo -e "${ADDON}\t\Z4${BETA}${DESC}\Zn"
    elif [ "${TARGET}" = "system" ]; then
      [ "${AVAILABLE}" = true ] && echo -e "${ADDON}\t\Z1${BETA}${DESC}\Zn"
    else
      [ "${AVAILABLE}" = true ] && echo -e "${ADDON}\t${BETA}${DESC}"
    fi
  done
}

###############################################################################
# Check if addon exist
# 1 - Addon id
# 2 - Platform
# Return ERROR if not exists
function checkAddonExist() {
  if [ -z "${1}" ] || [ -z "${2}" ]; then
    return 1 # ERROR
  fi
  # First check generic files
  if [ -f "${ADDONS_PATH}/${1}/all.tgz" ]; then
    return 0 # OK
  fi
  return 1 # ERROR
}

###############################################################################
# Install Addon into ramdisk image
# 1 - Addon id
# 2 - Platform
# 3 - Kernel Version
# Return ERROR if not installed
function installAddon() {
  if [ -z "${1}" ]; then
    echo "ERROR: installAddon: Addon not defined"
    return 1
  fi
  local ADDON="${1}"
  mkdir -p "${TMP_PATH}/${ADDON}"
  local HAS_FILES=0
  # First check generic files
  if [ -f "${ADDONS_PATH}/${ADDON}/all.tgz" ]; then
    tar -zxf "${ADDONS_PATH}/${ADDON}/all.tgz" -C "${TMP_PATH}/${ADDON}" 2>"${LOG_FILE}"
    if [ $? -ne 0 ]; then
      return 1
    fi
    HAS_FILES=1
  fi
  # Now check specific platform files
  if [ -f "${ADDONS_PATH}/${ADDON}/${2}-${3}.tgz" ]; then
    tar -zxf "${ADDONS_PATH}/${ADDON}/${2}-${3}.tgz" -C "${TMP_PATH}/${ADDON}" 2>"${LOG_FILE}"
    if [ $? -ne 0 ]; then
      return 1
    fi
    HAS_FILES=1
  fi
  # If has files to copy, copy it, else return error
  if [ ${HAS_FILES} -ne 1 ]; then
    deleteConfigKey "addon.${ADDON}" "${USER_CONFIG_FILE}"
    return 0
  fi
  cp -f "${TMP_PATH}/${ADDON}/install.sh" "${RAMDISK_PATH}/addons/${ADDON}.sh" 2>"${LOG_FILE}"
  chmod +x "${RAMDISK_PATH}/addons/${ADDON}.sh"
  [ -d "${TMP_PATH}/${ADDON}/root" ] && cp -rnf "${TMP_PATH}/${ADDON}/root/"* "${RAMDISK_PATH}/" 2>"${LOG_FILE}"
  rm -rf "${TMP_PATH}/${ADDON}"
  return 0
}

###############################################################################
# Untar an addon to correct path
# 1 - Addon file path
# Return name of addon on sucess or empty on error
function untarAddon() {
  if [ -z "${1}" ]; then
    echo ""
    return 1
  fi
  rm -rf "${TMP_PATH}/addon"
  mkdir -p "${TMP_PATH}/addon"
  tar -xaf "${1}" -C "${TMP_PATH}/addon" || return
  local ADDON=$(readConfigKey "name" "${TMP_PATH}/addon/manifest.yml")
  [ -z "${ADDON}" ] && return
  rm -rf "${ADDONS_PATH}/${ADDON}"
  mv -f "${TMP_PATH}/addon" "${ADDONS_PATH}/${ADDON}"
  echo "${ADDON}"
}

###############################################################################
# Detect if has new local plugins to install/reinstall
function updateAddon() {
  for F in $(ls ${ADDONS_PATH}/*.addon 2>/dev/null); do
    local ADDON=$(basename "${F}" | sed 's|.addon||')
    rm -rf "${ADDONS_PATH}/${ADDON}"
    mkdir -p "${ADDONS_PATH}/${ADDON}"
    echo "Installing ${F} to ${ADDONS_PATH}/${ADDON}"
    tar -xaf "${F}" -C "${ADDONS_PATH}/${ADDON}"
    rm -f "${F}"
  done
}

###############################################################################
# Read Addon Key
# 1 - Addon
# 2 - key
function readAddonKey() {
  if [ -z "${1}" ] || [ -z "${2}" ]; then
    echo ""
    return 1
  fi
  if [ ! -f "${ADDONS_PATH}/${1}/manifest.yml" ]; then
    echo ""
    return 1
  fi
  readConfigKey "${2}" "${ADDONS_PATH}/${1}/manifest.yml"
}