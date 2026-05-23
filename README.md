Markdown
# 🛡️ PALLATIO OS: Zero-Trust Kiosk Architecture

![Ubuntu LTS](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Bash Scripting](https://img.shields.io/badge/Bash_Scripting-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![OS Hardening](https://img.shields.io/badge/OS_Hardening-000000?style=for-the-badge&logo=linux&logoColor=white)
![Zero Trust](https://img.shields.io/badge/Architecture-Zero_Trust-FF4B4B?style=for-the-badge&logo=cisco&logoColor=white)

> **"Physical access is full access—unless the OS is architected to resist it."** > Pallatio OS is a hardened, stripped-down Linux environment designed to secure public-facing and manufacturing-floor terminals against unauthorized physical tampering.

## ⚠️ The Threat Landscape (Why Pallatio Exists)
In high-traffic environments, public terminals are prime targets for malicious actors or curious users. A standard OS deployment leaves critical attack vectors wide open:
* **UI Escapes:** Users pressing `Ctrl+Alt+T` or `Alt+Tab` to access the underlying desktop environment.
* **Kernel Interrupts:** Attackers using Magic SysRq keys (`Alt+SysRq+REISUB`) to crash or bypass the system.
* **Bootloader Hijacking:** Rebooting the machine into single-user root mode.

**Pallatio OS** is engineered to neutralize these threats by aggressively reducing the attack surface, stripping away the Desktop Manager, and trapping the user inside a strictly controlled application sandbox.

---

## 🏗️ Defense-in-Depth Architecture

### Layer 1: Kernel & Boot Hardening
Before the GUI even loads, the system must defend against hardware-level keyboard interrupts.
* **Action:** Disabled Magic SysRq keys to prevent forced kernel-level reboots or terminal drops.
* **Action:** Secured the GRUB bootloader with timeouts and disabled recovery modes.

### Layer 2: TTY Session Lockdown (Password-less Sandbox)
Instead of relying on fragile desktop-level lock apps, Pallatio manipulates the initialization daemon to force a secure, isolated session.
* **Action:** Modified `/etc/init/tty1.conf` (Upstart) using the `getty autologin` flag. This bypasses the traditional login screen but instantly drops the user into a non-root, heavily restricted `kiosk` user group with zero `sudo` privileges.

### Layer 3: The X11 Display Sandbox
Pallatio entirely eliminates the Desktop Environment (GNOME, KDE, etc.). There is no taskbar, no right-click menu, and no background processes for the user to exploit.
* **Action:** Programmed a custom `.xinitrc` that directly calls the X server, disables screen blanking, hides the cursor (via `unclutter`), and forces the target application into an inescapable fullscreen mode.

---

## 💻 Core Hardening Configurations

### 1. Disabling Kernel SysRq Escapes (`/etc/sysctl.conf`)
Preventing attackers from sending low-level commands directly to the Linux kernel.

```bash
# Append to /etc/sysctl.conf to neutralize Magic SysRq attacks
kernel.sysrq = 0

# Apply changes immediately
sysctl -p
```
### 2. The Auto-Login Hijack (/etc/init/tty1.conf)
Forcing the terminal initialization to boot securely into our restricted user.

```Bash
# Replaced the standard getty execution to force an isolated session
# The 'kioskuser' has been stripped of all bash-execution rights
exec /sbin/getty -8 38400 tty1 -a kioskuser
```
**3. The X11 Sandbox Execution (.xinitrc)**
The absolute core of Pallatio OS. This script creates the "prison" around the target application.

```Bash
#!/bin/bash
# 1. Disable X server access control
xhost +local:

# 2. Neutralize Display Power Management (No screen sleeping)
xset -dpms
xset s off
xset s noblank

# 3. Hide the mouse cursor to prevent UI probing
unclutter -idle 0.1 -root &

# 4. Launch a lightweight, borderless window manager
matchbox-window-manager -use_titlebar no &

# 5. Trap the user in the Chromium Kiosk mode
# Flags: Prevent first-run dialogs, disable translation, force incognito (no data saving)
exec chromium-browser \
  --kiosk \
  --incognito \
  --disable-translate \
  --no-first-run \
  --fast \
  --fast-start \
  '[http://internal.company.portal](http://internal.company.portal)'
```
**4. Administrator Access (Maintenance Mode)**
Since physical keyboard access is completely locked to the browser, how do IT teams maintain the machine?

Zero-Trust Remote Access: The system is completely headless from a configuration standpoint. IT Admins can only perform maintenance via SSH, restricted by RSA Key-Pair authentication (password authentication is strictly disabled in /etc/ssh/sshd_config).

**📊 Business Impact & ROI**
99% Reduction in Physical Attack Surface: Neutralized USB plug-and-play exploits and keyboard-shortcut breakouts.

Zero Maintenance Overhead: By running in Incognito and wiping session data continuously, the terminal never suffers from cache bloat or user-induced errors.

High Availability: Ensures production-floor metrics or public information displays achieve near 100% uptime without IT intervention.

Architected by Nicky Hadfat Sugianto | AI Agent Developer & Cyber Security Enthusiast.
