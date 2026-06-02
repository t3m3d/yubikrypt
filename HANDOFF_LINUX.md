# Handoff — build yubiKrypt on Linux (Agent L)

Goal: yubiKrypt runs on Linux (Arch) with the **same interface** as macOS — same
banner, colors, layout, watch loop, 30s-window caching. Only the OS-specific
probe commands change. Keep it **one** `yubikrypt.ks` that branches on `uname`,
so the macOS frontend is reused verbatim.

---

## 0. Hard dependency — read this first

yubiKrypt is **100% `exec`-driven** (ioreg/lsusb, ykman, date all run through the
native `exec` builtin). On Linux, `exec`/`shellRun` are **still unimplemented
no-ops** in `compiler/linux_x86/elf.k` (see `handoff_linux_exec.md` in the
krypton repo — your current task).

**So: implement Linux `exec` first.** Until it works, yubiKrypt compiles but
detects nothing. Verify exec with:

```bash
kcc.sh -r <(echo 'just run { kp(exec("echo alive")) }')   # must print: alive
```

When that prints `alive`, proceed.

---

## 1. What changes vs macOS (only 3 functions + the install hint)

Everything else — `_chomp`, `_q`, `sh`, `have`, the ANSI/color funcs, `banner`,
`renderStatus`, `renderCodes`, `draw`, the watch loop with per-window caching,
`nowSec`/`totpRemaining`, `ykmanInfo`/`oathCodes` — is **identical** and stays
untouched. `ykman`, `date +%s` behave the same on Linux.

Add one helper and branch the two detection funcs:

```krypton
// add near the prelude
func isLinux() {
    if sh("uname -s") == "Linux" { emit 1 }
    emit 0
}

// replace ykCount() with this branched version
func ykCount() {
    if isLinux() == 1 {
        // Yubico USB vendor id = 1050; lsusb line: "... ID 1050:xxxx Yubico.com YubiKey ..."
        let c = sh("lsusb 2>/dev/null | grep -ic 'yubico'")
        if c == "" { emit 0 }
        emit toInt(c)
    }
    let c = sh("ioreg -p IOUSB 2>/dev/null | grep -i 'yubikey' | grep -c 'IOUSBHostDevice'")
    if c == "" { emit 0 }
    emit toInt(c)
}

// replace ykModel() with this branched version
func ykModel() {
    if isLinux() == 1 {
        // pull "YubiKey OTP+FIDO+CCID" out of the lsusb line
        emit sh("lsusb 2>/dev/null | grep -i yubico | head -1 | grep -oi 'yubikey.*'")
    }
    emit sh("ioreg -p IOUSB 2>/dev/null | grep -i 'yubikey' | grep 'IOUSBHostDevice' | head -1 | sed 's/.*+-o //; s/@.*//'")
}
```

`ykInterfaces(model)` already derives OTP/FIDO/CCID from the model string — no
change; lsusb and ioreg both yield e.g. `YubiKey OTP+FIDO+CCID`.

Branch the install hint in `renderCodes` (the `ymPresent == 0` arm):

```krypton
    if ymPresent == 0 {
        kp("")
        if isLinux() == 1 {
            kp("  " + yellow("OATH codes need ykman.") + gray("  install:  ")
               + bold("sudo pacman -S yubikey-manager") + gray("  (or: pipx install yubikey-manager)"))
        } else {
            kp("  " + yellow("OATH codes need ykman.") + gray("  install:  ") + bold("brew install ykman"))
        }
        emit ""
    }
```

That's the whole port. Do **not** touch the rendering/layout — the macOS
frontend is the reference and must look the same.

---

## 2. Detection without lsusb (optional, more native)

`lsusb` needs the `usbutils` package (`sudo pacman -S usbutils`). If you want a
zero-package fallback, Linux exposes USB devices under `/sys` — and the elf.k
backend already has **`readProc`** (reads `/sys` & `/proc` virtual files where
`readFile` returns empty). But globbing `/sys/bus/usb/devices/*/idVendor`
needs a directory listing, which needs `exec` anyway. Simplest path: require
`usbutils` for `lsusb`, note it in the README. (A pure-`readProc` detector that
slurps `/sys/kernel/debug/usb/devices` and greps for `Vendor=1050` in-Krypton is
possible but debugfs isn't always mounted — skip unless you want the challenge.)

---

## 3. ykman on Arch

```bash
sudo pacman -S yubikey-manager      # community repo
# or, if you prefer pip isolation:
pipx install yubikey-manager
```

Then `ykman info` and `ykman oath accounts code` work exactly as on macOS —
`ykmanInfo`/`oathCodes`/`ykInfoBlock` need no changes.

---

## 4. Build & test (Arch)

```bash
git clone https://github.com/t3m3d/yubikrypt.git
cd yubikrypt
kr build.ks                 # build.ks already prefers the dev krypton compiler
./yubikrypt once            # snapshot
./yubikrypt                 # live dashboard
```

Checklist:
- [ ] Linux `exec` works (`exec("echo alive")` → `alive`)
- [ ] `./yubikrypt once` with a key in → "YubiKey present" + model + interfaces
- [ ] with `ykman` installed → serial, firmware, live OATH codes + countdown
- [ ] watch mode redraws every 1s, re-fetches codes only when the 30s window rolls
- [ ] output is ASCII only (Krypton mojibakes >127 / UTF-8 literals — keep it ASCII)
- [ ] interface matches macOS screenshot (same banner/colors/layout)

---

## 5. Commit

Single cross-platform `yubikrypt.ks` (uname branch). Update README's "How it
works" table to add the Linux row (`lsusb` / `/sys`) and the pacman/pipx install
line. Commit to the yubikrypt repo, push to `origin main`.

```
git add yubikrypt.ks README.md
git commit -m "feat: Linux support (lsusb detection, pacman/pipx ykman)"
git push origin main
```

Keep it one file — the macOS frontend is beautiful; Linux just feeds it.
