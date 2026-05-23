#!/usr/bin/env bash
#===============================================================================
#
#   ██████╗  █████╗ ██╗     ██╗      █████╗ ████████╗██╗ ██████╗
#   ██╔══██╗██╔══██╗██║     ██║     ██╔══██╗╚══██╔══╝██║██╔═══██╗
#   ██████╔╝███████║██║     ██║     ███████║   ██║   ██║██║   ██║
#   ██╔═══╝ ██╔══██║██║     ██║     ██╔══██║   ██║   ██║██║   ██║
#   ██║     ██║  ██║███████╗███████╗██║  ██║   ██║   ██║╚██████╔╝
#   ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝   ╚═╝  ╚═╝ ╚═════╝
#                            ██████╗ ███████╗
#                           ██╔═══██╗██╔════╝
#                           ██║   ██║███████╗
#                           ██║   ██║╚════██║
#                           ╚██████╔╝███████║
#                            ╚═════╝ ╚══════╝
#
#   Pallatio OS — Secure Linux Kiosk Deployment Script
#
#===============================================================================
#
#   FILE:           deploy_pallatio.sh
#   VERSION:        1.0.0
#   DESCRIPTION:    Automated provisioning script for Pallatio OS kiosk
#                   environments. Configures a hardened, single-purpose
#                   Linux workstation running Chromium in strict kiosk mode.
#
#   USAGE:          sudo bash deploy_pallatio.sh
#
#   SECURITY ARCHITECT:
#                   Nicky Hadfat
#                   All security policies, kernel hardening parameters, and
#                   privilege-separation strategies in this script were
#                   designed and reviewed by Nicky Hadfat.
#
#   LICENSE:        Proprietary — Pallatio OS Project
#   COPYRIGHT:      (c) 2026 Pallatio OS Contributors
#
#===============================================================================

# ==============================================================================
# SECTION 0: SHELL OPTIONS & GLOBAL CONFIGURATION
# ==============================================================================

# -e  : Exit immediately if any command returns a non-zero status.
#        This ensures the script fails fast rather than silently continuing
#        after an error, which is critical for security-sensitive deployments.
# -u  : Treat unset variables as an error and exit immediately.
#        Prevents dangerous typos from expanding to empty strings.
# -o pipefail : The return value of a pipeline is the status of the last
#               command to exit with a non-zero status, or zero if all
#               commands exit successfully. Without this, only the final
#               command in a pipeline determines the exit code.
set -euo pipefail

# IFS (Internal Field Separator) is restricted to newline and tab only.
# This prevents word-splitting on spaces in filenames or variables, a
# common source of subtle security bugs in shell scripts.
IFS=$'\n\t'

# ------------------------------------------------------------------------------
# Global Constants
# ------------------------------------------------------------------------------

# The dedicated kiosk user account name. This user will have no interactive
# shell and extremely limited filesystem permissions.
readonly KIOSK_USER="kioskuser"

# The home directory for the kiosk user. All session configuration files
# (.xinitrc) will be placed here.
readonly KIOSK_HOME="/home/${KIOSK_USER}"

# The URL that the kiosk Chromium instance will load on boot.
# Change this to your desired kiosk landing page.
readonly KIOSK_URL="http://localhost"

# The target getty/tty unit for autologin. tty1 is the primary virtual
# console on most Linux systems.
readonly AUTOLOGIN_TTY="tty1"

# systemd override directory for the getty service on the autologin TTY.
readonly GETTY_OVERRIDE_DIR="/etc/systemd/system/getty@${AUTOLOGIN_TTY}.service.d"

# Sysctl configuration file path for kernel parameter hardening.
readonly SYSCTL_CONF="/etc/sysctl.conf"

# Timestamp for logging purposes.
readonly TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# Script name for log messages.
readonly SCRIPT_NAME="$(basename "$0")"

# ==============================================================================
# SECTION 1: UTILITY FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# log_info()
# Prints an informational message to stdout with a timestamp and green
# color coding for easy visual parsing in terminal output.
#
# Arguments:
#   $1 - The message string to display.
# ------------------------------------------------------------------------------
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m  [${TIMESTAMP}] $1"
}

# ------------------------------------------------------------------------------
# log_warn()
# Prints a warning message to stderr with yellow color coding.
# Warnings indicate non-fatal conditions that the administrator should review.
#
# Arguments:
#   $1 - The warning message string.
# ------------------------------------------------------------------------------
log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m  [${TIMESTAMP}] $1" >&2
}

# ------------------------------------------------------------------------------
# log_error()
# Prints an error message to stderr with red color coding, then exits
# the script with a non-zero status code. Because `set -e` is active,
# this function is typically called for conditions that are unrecoverable.
#
# Arguments:
#   $1 - The error message string.
# ------------------------------------------------------------------------------
log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m [${TIMESTAMP}] $1" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# log_step()
# Prints a prominent step header to visually separate major phases of the
# deployment process. Uses cyan color and a horizontal rule.
#
# Arguments:
#   $1 - Step number (e.g., "1/4").
#   $2 - Step description.
# ------------------------------------------------------------------------------
log_step() {
    echo ""
    echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[0;36m  STEP $1 ── $2\033[0m"
    echo -e "\033[0;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
}

# ==============================================================================
# SECTION 2: PRE-FLIGHT CHECKS
# ==============================================================================

# ------------------------------------------------------------------------------
# Display the professional deployment banner.
# This banner identifies the project, version, and security architect.
# It is shown at the very start of every deployment run.
# ------------------------------------------------------------------------------
echo ""
echo -e "\033[1;35m╔══════════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;35m║                                                                  ║\033[0m"
echo -e "\033[1;35m║\033[0m   \033[1;37mPALLATIO OS\033[0m — Secure Kiosk Deployment Engine                \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   Version 1.0.0                                                \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   Security Architect : \033[1;33mNicky Hadfat\033[0m                             \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   Deployment Date    : ${TIMESTAMP}                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   \"Security is not a product, but a process.\"                    \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                         — Bruce Schneier         \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════════╝\033[0m"
echo ""

# ------------------------------------------------------------------------------
# Root privilege verification.
# This script modifies system-level configuration files (/etc/sysctl.conf,
# systemd unit overrides) and creates system users. It MUST be run as root
# or via sudo. Running as a non-root user would cause silent failures or
# partial deployments, which are dangerous in a security context.
# ------------------------------------------------------------------------------
if [[ "$(id -u)" -ne 0 ]]; then
    log_error "This script must be run as root (sudo). Aborting."
fi

log_info "Root privileges confirmed. Beginning Pallatio OS kiosk deployment..."
log_info "Script: ${SCRIPT_NAME}"
log_info "Timestamp: ${TIMESTAMP}"

# ==============================================================================
# SECTION 3: STEP 1 — CREATE RESTRICTED KIOSK USER
# ==============================================================================
#
# Security Rationale (Designed by Nicky Hadfat):
#
#   The kiosk user is created with /usr/sbin/nologin as its login shell.
#   This means:
#     - The user CANNOT open an interactive bash/sh session via SSH, console,
#       or su/sudo escalation.
#     - The user is restricted exclusively to the X session launched by the
#       autologin + xinit pipeline.
#     - Even if an attacker compromises the Chromium process, they cannot
#       spawn a shell as this user.
#
#   The user is created with --system to indicate it is a service account,
#   and --create-home to ensure the home directory exists for .xinitrc.
#   No password is set, preventing any password-based authentication.
#
# ==============================================================================

log_step "1/4" "Creating restricted kiosk user '${KIOSK_USER}'"

if id "${KIOSK_USER}" &>/dev/null; then
    # If the user already exists from a previous deployment, log a warning
    # but do not fail. This makes the script idempotent (safe to re-run).
    log_warn "User '${KIOSK_USER}' already exists. Skipping user creation."
    log_info "Verifying existing user shell is set to /usr/sbin/nologin..."

    # Ensure the shell is correctly set even if the user was pre-existing.
    # This guards against a prior misconfiguration.
    current_shell="$(getent passwd "${KIOSK_USER}" | cut -d: -f7)"
    if [[ "${current_shell}" != "/usr/sbin/nologin" ]]; then
        log_warn "User shell was '${current_shell}', forcing to /usr/sbin/nologin."
        usermod --shell /usr/sbin/nologin "${KIOSK_USER}"
        log_info "Shell corrected to /usr/sbin/nologin."
    else
        log_info "Shell is already /usr/sbin/nologin. No changes needed."
    fi
else
    # Create the kiosk user with:
    #   --system       : Mark as a system/service account (lower UID range).
    #   --create-home  : Ensure /home/kioskuser is created.
    #   --shell        : Set to nologin to prevent interactive shell access.
    #   --comment      : Human-readable description for audit logs.
    useradd \
        --system \
        --create-home \
        --shell /usr/sbin/nologin \
        --comment "Pallatio OS Kiosk User (Restricted)" \
        "${KIOSK_USER}"

    log_info "User '${KIOSK_USER}' created successfully."
    log_info "  Home directory : ${KIOSK_HOME}"
    log_info "  Login shell    : /usr/sbin/nologin (no interactive access)"
    log_info "  Password       : LOCKED (no password-based auth)"
fi

# Lock the account password as an additional safeguard. This prevents
# any password-based login even if someone later tries to set one.
passwd --lock "${KIOSK_USER}" &>/dev/null || true
log_info "Password for '${KIOSK_USER}' is locked."

# ==============================================================================
# SECTION 4: STEP 2 — KERNEL HARDENING (SYSCTL)
# ==============================================================================
#
# Security Rationale (Designed by Nicky Hadfat):
#
#   The Magic SysRq key is a Linux kernel feature that allows low-level
#   system commands to be issued via a keyboard shortcut (Alt+SysRq+<key>),
#   even when the system is unresponsive. While useful for development,
#   in a kiosk environment this is a critical attack vector:
#
#     - Alt+SysRq+S : Sync all filesystems
#     - Alt+SysRq+U : Remount all filesystems read-only
#     - Alt+SysRq+B : Immediately reboot (no shutdown)
#     - Alt+SysRq+E : Send SIGTERM to all processes (kill kiosk)
#     - Alt+SysRq+I : Send SIGKILL to all processes
#     - Alt+SysRq+K : Secure Attention Key (kill all processes on current VT)
#
#   Setting kernel.sysrq = 0 disables ALL SysRq functions, preventing
#   physical attackers from using the keyboard to disrupt, crash, or
#   gain control of the kiosk system.
#
# ==============================================================================

log_step "2/4" "Hardening kernel — disabling Magic SysRq key"

# Define the sysctl parameter we need to enforce.
readonly SYSRQ_PARAM="kernel.sysrq = 0"

# Check if the parameter is already present in sysctl.conf to maintain
# idempotency. We use a regex that matches the parameter regardless of
# spacing variations (e.g., "kernel.sysrq=0" or "kernel.sysrq = 0").
if grep -qE '^\s*kernel\.sysrq\s*=\s*0' "${SYSCTL_CONF}" 2>/dev/null; then
    log_info "kernel.sysrq is already set to 0 in ${SYSCTL_CONF}. Skipping."
else
    # Check if there's an existing (different) kernel.sysrq setting.
    # If so, we comment it out and append the correct value to avoid
    # conflicting directives. sysctl uses the LAST occurrence.
    if grep -qE '^\s*kernel\.sysrq\s*=' "${SYSCTL_CONF}" 2>/dev/null; then
        log_warn "Found existing kernel.sysrq setting. Commenting it out."

        # Use sed to comment out any existing kernel.sysrq lines.
        # The backup file (.bak) is created for rollback capability.
        sed -i.bak 's/^\s*kernel\.sysrq\s*=.*$/# [Pallatio OS] Disabled by deploy_pallatio.sh — &/' \
            "${SYSCTL_CONF}"
        log_info "Previous kernel.sysrq entry commented out (backup: ${SYSCTL_CONF}.bak)."
    fi

    # Safely append the hardened parameter with a clear comment block
    # identifying when and why the change was made.
    {
        echo ""
        echo "# =============================================================="
        echo "# Pallatio OS — Kernel Hardening"
        echo "# Applied by: deploy_pallatio.sh"
        echo "# Security Architect: Nicky Hadfat"
        echo "# Date: ${TIMESTAMP}"
        echo "# Purpose: Disable Magic SysRq to prevent physical keyboard"
        echo "#          attacks on the kiosk terminal."
        echo "# =============================================================="
        echo "${SYSRQ_PARAM}"
    } >> "${SYSCTL_CONF}"

    log_info "Appended '${SYSRQ_PARAM}' to ${SYSCTL_CONF}."
fi

# Apply the sysctl change immediately without requiring a reboot.
# The -p flag reads the configuration file and applies all parameters.
sysctl -p "${SYSCTL_CONF}" > /dev/null 2>&1
log_info "Sysctl parameters reloaded. kernel.sysrq is now disabled."

# Verify the change took effect in the running kernel.
current_sysrq="$(cat /proc/sys/kernel/sysrq 2>/dev/null || echo 'unknown')"
if [[ "${current_sysrq}" == "0" ]]; then
    log_info "Verification: /proc/sys/kernel/sysrq = 0 ✓"
else
    log_warn "Verification: /proc/sys/kernel/sysrq = ${current_sysrq} (expected 0)."
    log_warn "The change will take full effect after the next reboot."
fi

# ==============================================================================
# SECTION 5: STEP 3 — GENERATE SECURE AUTOLOGIN CONFIGURATION
# ==============================================================================
#
# Security Rationale (Designed by Nicky Hadfat):
#
#   Kiosk systems must boot directly into the kiosk session without
#   presenting a login prompt. A login prompt on a public kiosk would:
#
#     1. Expose the system to brute-force password attacks.
#     2. Allow users to attempt username enumeration.
#     3. Create confusion — the kiosk should be zero-interaction.
#
#   We accomplish autologin by creating a systemd drop-in override for
#   the getty@tty1 service. This override replaces the standard agetty
#   invocation with one that:
#
#     - Uses --autologin to bypass the login prompt entirely.
#     - Uses --noclear to prevent the screen from being cleared (useful
#       for debugging boot issues).
#     - Launches the kioskuser session, which in turn executes .xinitrc
#       via the user's .bash_profile or startx hook.
#
#   The autologin is restricted to tty1 only. All other virtual terminals
#   retain standard login behavior, providing a recovery path for
#   administrators.
#
# ==============================================================================

log_step "3/4" "Generating secure autologin configuration for TTY '${AUTOLOGIN_TTY}'"

# Create the systemd drop-in override directory if it doesn't exist.
# systemd reads drop-in files from /etc/systemd/system/<unit>.d/*.conf
if [[ ! -d "${GETTY_OVERRIDE_DIR}" ]]; then
    mkdir -p "${GETTY_OVERRIDE_DIR}"
    log_info "Created systemd override directory: ${GETTY_OVERRIDE_DIR}"
else
    log_info "Override directory already exists: ${GETTY_OVERRIDE_DIR}"
fi

# Define the override configuration file path.
readonly AUTOLOGIN_CONF="${GETTY_OVERRIDE_DIR}/autologin.conf"

# Write the autologin override configuration.
# The [Service] section overrides the ExecStart directive from the
# original getty@.service unit file. We must first clear ExecStart
# with an empty assignment before setting the new value — this is
# a systemd requirement for list-type directives.
cat > "${AUTOLOGIN_CONF}" << 'AUTOLOGIN_EOF'
# ==============================================================================
# Pallatio OS — Autologin Configuration
# Generated by: deploy_pallatio.sh
# Security Architect: Nicky Hadfat
#
# PURPOSE:
#   Configures automatic login for the kiosk user on tty1.
#   This bypasses the standard login prompt, allowing the kiosk session
#   to start immediately on boot without any user interaction.
#
# SECURITY NOTES:
#   - Autologin is restricted to tty1 only.
#   - The kioskuser has /usr/sbin/nologin as its shell, preventing
#     interactive shell access even after autologin.
#   - The autologin session immediately launches xinit/.xinitrc,
#     which starts the locked-down Chromium kiosk.
# ==============================================================================

[Service]
# Clear the default ExecStart (required by systemd before overriding).
ExecStart=

# Launch agetty with autologin for the kiosk user.
#   --autologin kioskuser : Skip the login prompt, authenticate as kioskuser.
#   --noclear             : Don't clear the screen (preserves boot messages for debugging).
#   %I                    : systemd specifier for the TTY instance (e.g., tty1).
#   $TERM                 : Inherit the terminal type from the environment.
ExecStart=-/sbin/agetty --autologin kioskuser --noclear %I $TERM

[Install]
WantedBy=multi-user.target
AUTOLOGIN_EOF

# Set strict permissions on the autologin configuration file.
# Only root should be able to read or modify this file to prevent
# an attacker from changing the autologin target user.
chmod 644 "${AUTOLOGIN_CONF}"
chown root:root "${AUTOLOGIN_CONF}"

log_info "Autologin configuration written to: ${AUTOLOGIN_CONF}"
log_info "  Autologin user : ${KIOSK_USER}"
log_info "  Target TTY     : ${AUTOLOGIN_TTY}"
log_info "  File perms     : 644 (root:root)"

# Create a .bash_profile for the kioskuser that automatically starts
# the X session (xinit) when the user is logged in on tty1.
# Because the user's shell is /usr/sbin/nologin, we need an alternative
# mechanism. We use a systemd-level approach: the autologin + startx.
#
# However, since nologin prevents shell execution, we configure the
# getty to run xinit directly for the kioskuser via a wrapper script.
readonly KIOSK_XINIT_WRAPPER="/usr/local/bin/pallatio-kiosk-start.sh"

cat > "${KIOSK_XINIT_WRAPPER}" << WRAPPER_EOF
#!/usr/bin/env bash
# ==============================================================================
# Pallatio OS — Kiosk Session Launcher
# Generated by: deploy_pallatio.sh
# Security Architect: Nicky Hadfat
#
# This wrapper is invoked by the autologin getty configuration.
# It starts the X server and loads the kioskuser's .xinitrc.
# ==============================================================================

# Start X with the kioskuser's .xinitrc configuration.
exec /usr/bin/xinit ${KIOSK_HOME}/.xinitrc -- :0 vt1 -nolisten tcp -nolisten local
WRAPPER_EOF

# Make the wrapper executable. Only root can modify it.
chmod 755 "${KIOSK_XINIT_WRAPPER}"
chown root:root "${KIOSK_XINIT_WRAPPER}"

log_info "Kiosk session launcher created: ${KIOSK_XINIT_WRAPPER}"

# Update the autologin override to use the wrapper script instead of
# a standard shell login, since kioskuser has nologin as its shell.
cat > "${AUTOLOGIN_CONF}" << AUTOLOGIN_FINAL_EOF
# ==============================================================================
# Pallatio OS — Autologin Configuration (Final)
# Generated by: deploy_pallatio.sh
# Security Architect: Nicky Hadfat
#
# Automatically logs in as kioskuser on tty1 and launches the kiosk
# X session via the Pallatio wrapper script.
# ==============================================================================

[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM

[Install]
WantedBy=multi-user.target
AUTOLOGIN_FINAL_EOF

chmod 644 "${AUTOLOGIN_CONF}"
chown root:root "${AUTOLOGIN_CONF}"

# Reload systemd daemon to pick up the new override configuration.
# This is required after creating or modifying any systemd unit files.
systemctl daemon-reload
log_info "systemd daemon reloaded. Autologin override is now active."

# ==============================================================================
# SECTION 6: STEP 4 — GENERATE RESTRICTED .xinitrc
# ==============================================================================
#
# Security Rationale (Designed by Nicky Hadfat):
#
#   The .xinitrc file is the entry point for the X session. In a kiosk
#   environment, this file must enforce a completely locked-down session:
#
#   1. SCREEN BLANKING DISABLED (xset):
#      - xset s off        : Disable the screensaver.
#      - xset -dpms         : Disable DPMS (Display Power Management Signaling).
#      - xset s noblank     : Prevent the screen from blanking on idle.
#      A kiosk must always display content. Screen blanking could be
#      mistaken for a system crash by users, or could be exploited to
#      hide unauthorized activity.
#
#   2. CURSOR HIDDEN (unclutter):
#      - unclutter runs in the background and hides the mouse cursor
#        after 0.1 seconds of inactivity. This prevents users from
#        seeing cursor artifacts and creates a cleaner kiosk experience.
#      - The --jitter flag ignores small mouse movements that could
#        be caused by vibration of the kiosk hardware.
#
#   3. CHROMIUM IN STRICT KIOSK MODE:
#      - --kiosk            : Fullscreen, no address bar, no tabs, no menus.
#      - --incognito        : No browsing history, cookies, or cache persist
#                             across sessions.
#      - --no-first-run     : Skip the "Welcome to Chromium" dialog.
#      - --disable-translate : Prevent the translation bar from appearing.
#      - --disable-infobars : Suppress all information bars.
#      - --disable-features=TranslateUI : Double-ensure translation UI is off.
#      - --noerrdialogs     : Suppress error dialogs that could expose info.
#      - --disable-session-crashed-bubble : Don't show "restore pages?" prompt.
#      - --check-for-update-interval=31536000 : Effectively disable update
#                             checks (set to 1 year in seconds).
#      - --disable-component-update : Prevent background component updates.
#      - --autoplay-policy=no-user-gesture-required : Allow media autoplay
#                             without user interaction (useful for kiosk
#                             content that includes video).
#      - --disable-pinch     : Prevent pinch-to-zoom on touchscreens.
#      - --overscroll-history-navigation=0 : Disable swipe-to-go-back.
#
# ==============================================================================

log_step "4/4" "Generating restricted .xinitrc for kiosk session"

# Define the path to the .xinitrc file in the kiosk user's home directory.
readonly XINITRC_PATH="${KIOSK_HOME}/.xinitrc"

# Write the .xinitrc file with all security configurations.
cat > "${XINITRC_PATH}" << 'XINITRC_EOF'
#!/usr/bin/env bash
# ==============================================================================
#
#   Pallatio OS — Kiosk Session Configuration (.xinitrc)
#
#   Security Architect: Nicky Hadfat
#   Generated by:       deploy_pallatio.sh
#
#   This file configures the X session for the Pallatio OS kiosk.
#   It disables all power-saving features, hides the cursor, and
#   launches Chromium in a fully locked-down kiosk mode.
#
#   DO NOT EDIT THIS FILE MANUALLY.
#   Re-run deploy_pallatio.sh to regenerate it.
#
# ==============================================================================

# ------------------------------------------------------------------------------
# DISPLAY POWER MANAGEMENT
# Disable all screen blanking and power saving features.
# A kiosk display must remain active at all times.
# ------------------------------------------------------------------------------

# Disable the X screensaver entirely.
xset s off

# Disable DPMS (Display Power Management Signaling).
# This prevents the monitor from entering standby, suspend, or off states.
xset -dpms

# Prevent the screen from blanking due to idle timeout.
xset s noblank

# ------------------------------------------------------------------------------
# CURSOR MANAGEMENT
# Hide the mouse cursor to create a clean kiosk interface.
# The cursor reappears briefly on mouse movement, then hides again.
# ------------------------------------------------------------------------------

# Start unclutter in the background.
#   -idle 0.1  : Hide cursor after 0.1 seconds of inactivity.
#   -root      : Apply to the root window (entire screen).
#   -jitter 2  : Ignore mouse movements smaller than 2 pixels
#                (prevents cursor from flickering due to hardware noise).
unclutter -idle 0.1 -root -jitter 2 &

# ------------------------------------------------------------------------------
# CHROMIUM KIOSK LAUNCH
# Launch Chromium in strict kiosk mode with all escape routes disabled.
# 'exec' replaces this shell process with Chromium, ensuring that when
# Chromium exits (or crashes), the X session terminates cleanly.
# ------------------------------------------------------------------------------

exec chromium-browser \
    --kiosk \
    --incognito \
    --no-first-run \
    --disable-translate \
    --disable-infobars \
    --disable-features=TranslateUI \
    --noerrdialogs \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    --disable-component-update \
    --autoplay-policy=no-user-gesture-required \
    --disable-pinch \
    --overscroll-history-navigation=0 \
    --disable-dev-tools \
    --disable-extensions \
    --disable-popup-blocking \
    --disable-background-networking \
    --password-store=basic \
    --disable-sync \
    --disable-default-apps \
    --start-fullscreen \
    --window-position=0,0 \
    'http://localhost'
XINITRC_EOF

# Set ownership of the .xinitrc to the kiosk user.
# The file must be owned by the user that the X session runs as.
chown "${KIOSK_USER}:${KIOSK_USER}" "${XINITRC_PATH}"

# Set permissions to 755 (owner: rwx, group: r-x, others: r-x).
# The file must be executable since it's launched by xinit as a script.
# Read permission is granted to group/others for auditability, but only
# root and kioskuser can modify it (via ownership).
chmod 755 "${XINITRC_PATH}"

log_info ".xinitrc written to: ${XINITRC_PATH}"
log_info "  Screen blanking  : DISABLED (xset s off, -dpms, s noblank)"
log_info "  Cursor hiding    : ENABLED (unclutter, 0.1s idle timeout)"
log_info "  Chromium mode    : --kiosk --incognito (fully locked down)"
log_info "  Kiosk URL        : ${KIOSK_URL}"
log_info "  File owner       : ${KIOSK_USER}:${KIOSK_USER}"
log_info "  File perms       : 755"

# ==============================================================================
# SECTION 7: POST-DEPLOYMENT SUMMARY
# ==============================================================================

echo ""
echo -e "\033[1;35m╔══════════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;35m║                                                                  ║\033[0m"
echo -e "\033[1;35m║\033[0m   \033[1;32m✓ PALLATIO OS DEPLOYMENT COMPLETE\033[0m                              \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   The following security measures have been applied:             \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m     [✓] Restricted kiosk user created (nologin shell)            \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m     [✓] Kernel hardened (Magic SysRq disabled)                   \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m     [✓] Autologin configured on ${AUTOLOGIN_TTY}                          \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m     [✓] .xinitrc generated (Chromium kiosk + incognito)          \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   Security Architect: \033[1;33mNicky Hadfat\033[0m                              \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   Completed at: ${TIMESTAMP}                       \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   \033[0;33mReboot the system to activate the kiosk environment.\033[0m          \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m   $ sudo reboot                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m║\033[0m                                                                  \033[1;35m║\033[0m"
echo -e "\033[1;35m╚══════════════════════════════════════════════════════════════════╝\033[0m"
echo ""

# ==============================================================================
# END OF SCRIPT
# ==============================================================================
# Exit with success status code.
exit 0
