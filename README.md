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
