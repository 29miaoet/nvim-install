#!/usr/bin/env bash
# ============================================================================
#  install.sh — full Neovim installer for Ubuntu Linux
#  Config source: https://github.com/29miaoet/nvim-install (master branch)
#
#  Pipeable:
#    curl -fsSL \
#      https://raw.githubusercontent.com/29miaoet/nvim-install/refs/heads/master/install.sh \
#      | bash
#
#  What it does, in order:
#    1. Validates sudo ONCE, up front (later sudo calls reuse the cached ticket)
#    2. Checks prerequisites (apt-installs git ONLY if missing — lazy.nvim
#       needs it; nothing else is ever installed)
#    3. Downloads the latest STABLE Neovim tarball from GitHub into /usr/local
#    4. Replaces ~/.config/nvim with init.lua + plugin specs from this repo
#    5. Runs headless "Lazy! sync" so plugins are pre-installed
#    6. Appends "alias vim='nvim'" to ~/.bashrc (no duplicates on re-run)
#
#  Every step logs to the terminal; any unexpected failure aborts with the
#  failing line, command, and exit code.
# ============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Settings — edit these to change behaviour
# ---------------------------------------------------------------------------

# true  -> existing ~/.config/nvim is moved to ~/.config/nvim.backup.<timestamp>
# false -> existing ~/.config/nvim is deleted outright        (current default)
BACKUP_EXISTING_CONFIG=false

# Plugin spec files pulled from <repo>/lua/plugins/<name>.lua
# NOTE: "treesitter" is intentionally omitted — compiling its parsers needs a
# C compiler, and this script deliberately installs no toolchains.
# To re-enable later: add "treesitter" to this list (and install gcc yourself).
PLUGINS=(
  colorizer
  colorscheme
  markdown-preview
  multicursor
)

REPO_RAW_BASE="https://raw.githubusercontent.com/29miaoet/nvim-install/refs/heads/master"
NVIM_RELEASE_BASE="https://github.com/neovim/neovim/releases/download/stable"
CONFIG_DIR="${HOME}/.config/nvim"

# ---------------------------------------------------------------------------
# Logging helpers — everything this script does is echoed to the terminal
# ---------------------------------------------------------------------------
log()  { printf '\033[1;32m[ OK   ]\033[0m %s\n' "$*"; }
info() { printf '\033[1;36m[ INFO ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ WARN ]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ FAIL ]\033[0m %s\n' "$*" >&2; }

on_error() {
  local code="$1" line="$2" cmd="$3"
  err "Line ${line}: '${cmd}' failed (exit code ${code})."
  err "Aborting."
  exit "${code}"
}
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

fetch() {
  # fetch <url> <destination> <label> — verbose download with a clear failure
  local url="$1" dest="$2" label="$3"
  info "Downloading ${label}"
  info "    ${url}"
  if ! curl -fsSL --retry 3 --retry-delay 2 "${url}" -o "${dest}"; then
    err "Failed to download ${label}"
    err "    URL: ${url}"
    err "Check your connection, and that the file exists on 'master' of"
    err "https://github.com/29miaoet/nvim-install"
    exit 1
  fi
  log "Saved ${label} -> ${dest} ($(du -h "${dest}" | cut -f1))"
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
[[ -n "${HOME}" ]] || { err "HOME is not set — aborting."; exit 1; }

info "nvim-install started: $(date '+%Y-%m-%d %H:%M:%S')"
info "User:   $(id -un) (uid ${EUID})"
info "Host:   $(uname -sr) ($(uname -m))"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  info "Distro: ${PRETTY_NAME:-unknown}"
fi

WORKDIR="$(mktemp -d)"
trap 'info "Cleaning up temp dir ${WORKDIR}"; rm -rf "${WORKDIR}"' EXIT
info "Temp working dir: ${WORKDIR}"

# --- sudo: validate credentials exactly once, up front ----------------------
if [[ ${EUID} -eq 0 ]]; then
  SUDO=""
  log "Running as root — sudo not required."
else
  command -v sudo >/dev/null 2>&1 || {
    err "sudo is not available and this script is not running as root."
    exit 1
  }
  info "Validating sudo credentials (single prompt; later sudo calls reuse the ticket)..."
  sudo -v
  log "sudo credentials validated."
fi

as_root() {
  if [[ -n "${SUDO}" ]]; then sudo "$@"; else "$@"; fi
}

# --- Prerequisites ------------------------------------------------------------
for cmd in curl tar; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    log "Prerequisite found: ${cmd} ($(command -v "${cmd}"))"
  else
    err "Required command '${cmd}' is not on PATH."
    err "Install it first with: sudo apt-get install ${cmd}"
    exit 1
  fi
done

if command -v git >/dev/null 2>&1; then
  log "Prerequisite found: git ($(git --version))"
else
  warn "git is missing — lazy.nvim cannot clone plugins without it."
  info "Installing git via apt (the ONLY package this script will ever install)..."
  as_root apt-get update
  as_root apt-get install -y git
  log "git installed: $(git --version)"
fi

# --- Neovim: latest stable tarball from GitHub --------------------------------
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)        ASSET="nvim-linux-x86_64.tar.gz" ;;
  aarch64|arm64) ASSET="nvim-linux-aarch64.tar.gz" ;;
  *)
    err "Unsupported architecture '${ARCH}' — this script handles x86_64/aarch64 only."
    exit 1
    ;;
esac

TARBALL="${WORKDIR}/${ASSET}"
info "Downloading latest stable Neovim release (${ASSET})..."
info "    ${NVIM_RELEASE_BASE}/${ASSET}"
if ! curl -fL --retry 3 --retry-delay 2 --progress-bar \
      "${NVIM_RELEASE_BASE}/${ASSET}" -o "${TARBALL}"; then
  # Releases before v0.10.4 named the x86_64 archive "nvim-linux64.tar.gz".
  if [[ "${ARCH}" == "x86_64" ]]; then
    warn "Primary asset failed — retrying legacy archive name nvim-linux64.tar.gz..."
    ASSET="nvim-linux64.tar.gz"
    TARBALL="${WORKDIR}/${ASSET}"
    curl -fL --retry 3 --retry-delay 2 --progress-bar \
      "${NVIM_RELEASE_BASE}/${ASSET}" -o "${TARBALL}" \
      || { err "Could not download the Neovim stable tarball."; exit 1; }
  else
    err "Could not download a Neovim stable tarball for ${ARCH}."
    exit 1
  fi
fi
log "Neovim tarball saved: ${TARBALL} ($(du -h "${TARBALL}" | cut -f1))"

# Determine the archive's top-level directory (e.g. "nvim-linux-x86_64")
TOPDIR="$(tar -tzf "${TARBALL}" | sed -n '1s#/.*##p')"
if [[ -z "${TOPDIR}" || "${TOPDIR}" == "." ]]; then
  err "Could not determine the archive's root directory — aborting."
  exit 1
fi
info "Archive root: ${TOPDIR}/"

info "Removing any previous install at /usr/local/${TOPDIR} ..."
as_root rm -rf "/usr/local/${TOPDIR}"

info "Extracting to /usr/local ..."
as_root tar -xzf "${TARBALL}" -C /usr/local
log "Neovim extracted to /usr/local/${TOPDIR}"

info "Creating symlink /usr/local/bin/nvim -> /usr/local/${TOPDIR}/bin/nvim"
as_root ln -sfn "/usr/local/${TOPDIR}/bin/nvim" "/usr/local/bin/nvim"

NVIM_BIN="/usr/local/bin/nvim"
NVIM_VERSION="$("${NVIM_BIN}" --version | head -n 1)"
log "Neovim installed: ${NVIM_VERSION}"

if command -v nvim >/dev/null 2>&1 && [[ "$(command -v nvim)" != "${NVIM_BIN}" ]]; then
  warn "A different nvim is also on PATH: $(command -v nvim)"
  warn "/usr/local/bin normally shadows it, but this shell's PATH may differ."
fi

# --- Configuration from this repository ----------------------------------------
if [[ -d "${CONFIG_DIR}" ]]; then
  if [[ "${BACKUP_EXISTING_CONFIG}" == "true" ]]; then
    BACKUP_DIR="${CONFIG_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    info "Existing Neovim config found — backing it up to ${BACKUP_DIR}"
    mv "${CONFIG_DIR}" "${BACKUP_DIR}"
    log "Backup complete."
  else
    warn "Existing Neovim config found at ${CONFIG_DIR}."
    warn "BACKUP_EXISTING_CONFIG=${BACKUP_EXISTING_CONFIG} — replacing it WITHOUT backup."
    rm -rf "${CONFIG_DIR}"
    log "Old config removed."
  fi
else
  info "No existing config at ${CONFIG_DIR} — fresh install."
fi

info "Creating ${CONFIG_DIR}/lua/plugins ..."
mkdir -p "${CONFIG_DIR}/lua/plugins"
log "Directory structure created."

fetch "${REPO_RAW_BASE}/init.lua" "${CONFIG_DIR}/init.lua" "init.lua"

for plugin in "${PLUGINS[@]}"; do
  fetch "${REPO_RAW_BASE}/lua/plugins/${plugin}.lua" \
        "${CONFIG_DIR}/lua/plugins/${plugin}.lua" \
        "plugin spec: ${plugin}.lua"
done

info "Installed config files:"
find "${CONFIG_DIR}" | sort | sed 's#^#    #'

# --- Plugin bootstrap -----------------------------------------------------------
info "Launching headless Neovim to bootstrap lazy.nvim and sync plugins..."
info "(First run also clones lazy.nvim itself — this can take a minute.)"
if "${NVIM_BIN}" --headless "+Lazy! sync" +qa </dev/null; then
  log "Plugin sync completed."
else
  warn "Headless plugin sync reported an error — continuing anyway."
  warn "Plugins will be retried automatically on the first normal launch."
fi

# --- bashrc alias ----------------------------------------------------------------
BASHRC="${HOME}/.bashrc"

if [[ ! -f "${BASHRC}" ]]; then
  warn "${BASHRC} does not exist — creating it."
  touch "${BASHRC}"
fi

if grep -qsF "alias vim='nvim'" "${BASHRC}" \
   || grep -qsF 'alias vim="nvim"' "${BASHRC}" \
   || grep -qsF "alias vim=nvim" "${BASHRC}"; then
  log "Alias 'vim' -> 'nvim' already present in ~/.bashrc — nothing to do."
else
  if grep -qsE "^[[:space:]]*alias[[:space:]]+vim=" "${BASHRC}"; then
    warn "A different vim alias exists in ~/.bashrc — it will be overridden"
    warn "by the appended one (bash uses the last definition in the file):"
    grep -nE "^[[:space:]]*alias[[:space:]]+vim=" "${BASHRC}" | sed 's#^#    #'
  else
    info "Adding alias to ~/.bashrc..."
  fi
  {
    printf '\n# Added by 29miaoet/nvim-install\n'
    printf "alias vim='nvim'\n"
  } >> "${BASHRC}"
  log "Alias 'vim' -> 'nvim' appended to ~/.bashrc."
fi

# --- Done --------------------------------------------------------------------------
echo
log "=================== install complete ==================="
log "Neovim:    ${NVIM_VERSION}"
log "Binary:    ${NVIM_BIN} (symlink -> /usr/local/${TOPDIR}/bin/nvim)"
log "Config:    ${CONFIG_DIR} (init.lua + ${#PLUGINS[@]} plugin specs)"
log "Plugins:   ${PLUGINS[*]}"
log "Alias:     vim -> nvim (in ~/.bashrc)"
log "Finished:  $(date '+%Y-%m-%d %H:%M:%S')"
echo
info "The 'vim' alias is active in NEW terminals."
info "To use it immediately:  source ~/.bashrc"
info "Run <leader>r inside nvim to execute the open file (best effort —"
info "needs python3 / node / tsx / g++ / xdg-open on PATH per filetype)."
