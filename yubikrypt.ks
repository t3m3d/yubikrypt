#!/usr/bin/env kr
// yubikrypt - a YubiKey detector + OATH/TOTP authenticator, in KryptScript.
//
// Self-contained (no k: imports), so it compiles anywhere Krypton is installed.
// Everything runs through the native `exec` builtin - no C, no clang.
//
//   kr yubikrypt.ks            live dashboard (refreshes; Ctrl-C to quit)
//   kr yubikrypt.ks once       print status once and exit
//   kr yubikrypt.ks watch      same as default (explicit)
//
// What it shows:
//   - whether a YubiKey is plugged in (via ioreg - zero extra install)
//   - the model / enabled interfaces (OTP / FIDO / CCID)
//   - if `ykman` is installed: serial + firmware + live OATH TOTP codes with a
//     30s countdown. Install codes support with:  brew install ykman
//
// No secrets are stored or transmitted; it only reads what the key/ykman report.

// -- tiny prelude (inlined so there are no stdlib path deps) ---------------
func _chomp(s) {
    let lo = 0
    let hi = len(s)
    while lo < hi {
        let c = toInt(charCode(s[lo]))
        if c == 32 || c == 9 || c == 10 || c == 13 { lo += 1 } else { break }
    }
    while hi > lo {
        let c = toInt(charCode(s[hi - 1]))
        if c == 32 || c == 9 || c == 10 || c == 13 { hi -= 1 } else { break }
    }
    emit substring(s, lo, hi)
}
func _q(s) { emit "\"" + s + "\"" }
func sh(cmd) { emit _chomp(exec(cmd)) }
func shRaw(cmd) { emit exec(cmd) }
func have(name) {
    if _chomp(exec("command -v " + _q(name) + " 2>/dev/null")) == "" { emit 0 }
    emit 1
}
func isLinux() {
    if sh("uname -s") == "Linux" { emit 1 }
    emit 0
}

// -- ANSI ------------------------------------------------------------------
func _e() { emit fromCharCode(27) + "[" }
func col(code, s) { emit _e() + code + "m" + s + _e() + "0m" }
func green(s)  { emit col("32", s) }
func red(s)    { emit col("31", s) }
func yellow(s) { emit col("33", s) }
func cyan(s)   { emit col("36", s) }
func gray(s)   { emit col("90", s) }
func bold(s)   { emit col("1", s) }
func clearScreen() { kp(_e() + "2J" + _e() + "H") }

// -- YubiKey detection (ioreg - works with no extra tools) ------------------
// count of YubiKey USB devices currently attached.
func ykCount() {
    if isLinux() == 1 {
        // Yubico USB vendor id = 1050; lsusb: "... ID 1050:xxxx Yubico.com YubiKey ..."
        let c = sh("lsusb 2>/dev/null | grep -ic 'yubico'")
        if c == "" { emit 0 }
        emit toInt(c)
    }
    let c = sh("ioreg -p IOUSB 2>/dev/null | grep -i 'yubikey' | grep -c 'IOUSBHostDevice'")
    if c == "" { emit 0 }
    emit toInt(c)
}
// product/model string, e.g. "YubiKey OTP+FIDO+CCID".
func ykModel() {
    if isLinux() == 1 {
        emit sh("lsusb 2>/dev/null | grep -i yubico | head -1 | grep -oi 'yubikey.*'")
    }
    emit sh("ioreg -p IOUSB 2>/dev/null | grep -i 'yubikey' | grep 'IOUSBHostDevice' | head -1 | sed 's/.*+-o //; s/@.*//'")
}
// pretty interface list derived from the model name.
func ykInterfaces(model) {
    let out = ""
    if contains(model, "OTP")  { out = out + "OTP " }
    if contains(model, "FIDO") { out = out + "FIDO " }
    if contains(model, "CCID") { out = out + "CCID(PIV/OATH) " }
    if out == "" { emit "(unknown)" }
    emit _chomp(out)
}

// -- ykman-backed details (optional) ----------------------------------------
func ykmanInfo() { emit shRaw("ykman info 2>/dev/null") }
// raw "ykman oath accounts code" output (label + 6-8 digit code per line).
func oathCodes() { emit shRaw("ykman oath accounts code 2>/dev/null") }

// -- time / TOTP window -----------------------------------------------------
func nowSec() { emit toInt(sh("date +%s")) }
func totpRemaining() {
    let n = nowSec()
    let w = n / 30
    emit 30 - (n - w * 30)
}

// -- rendering ---------------------------------------------------------------
func banner() {
    kp(bold(cyan("  yubiKrypt")) + gray("  - KryptScript YubiKey authenticator (C-free)"))
    kp(gray("  ---------------------------------------------------------"))
}

func renderStatus() {
    let n = ykCount()
    if n == 0 {
        kp("  " + red("* no YubiKey detected") + gray("  (plug one in)"))
        emit ""
    }
    let model = ykModel()
    kp("  " + green("* YubiKey present") + "   " + bold(model))
    kp("  " + gray("  interfaces: ") + ykInterfaces(model))
    if n > 1 { kp("  " + yellow("  (" + toStr(n) + " keys attached; showing the first)")) }
    emit ""
}

// serial + firmware as a two-line block (or "" if ykman absent). Cached by
// the caller — these don't change while the key is plugged in.
func ykInfoBlock() {
    if have("ykman") == 0 { emit "" }
    let sn = sh("ykman info 2>/dev/null | grep -i 'serial' | head -1")
    let fw = sh("ykman info 2>/dev/null | grep -i 'firmware' | head -1")
    let out = ""
    if sn != "" { out = out + "  " + gray("  " + sn) + fromCharCode(10) }
    if fw != "" { out = out + "  " + gray("  " + fw) }
    emit out
}

// render pre-fetched OATH codes (passed in so we fetch at most once per window).
func renderCodes(ymPresent, infoBlock, codes, rem) {
    if ymPresent == 0 {
        kp("")
        if isLinux() == 1 {
            kp("  " + yellow("OATH codes need ykman.") + gray("  install:  ")
               + bold("sudo pacman -S yubikey-manager") + gray("  (or pipx install yubikey-manager)"))
        } else {
            kp("  " + yellow("OATH codes need ykman.") + gray("  install:  ") + bold("brew install ykman"))
        }
        emit ""
    }
    if infoBlock != "" { kp(infoBlock) }
    kp("")
    if _chomp(codes) == "" {
        kp("  " + gray("  no OATH accounts (or key is locked / needs a password)"))
        emit ""
    }
    kp("  " + bold("OATH codes") + gray("   refresh in ") + bold(toStr(rem) + "s"))
    kp(gray("  ---------------------------------------------------------"))
    let total = lineCount(codes)
    let i = 0
    while i < total {
        let line = _chomp(getLine(codes, i))
        if len(line) > 0 { kp("  " + cyan(line)) }
        i += 1
    }
    emit ""
}

func draw(present, ymPresent, infoBlock, codes, rem) {
    clearScreen()
    banner()
    renderStatus()
    if present > 0 { renderCodes(ymPresent, infoBlock, codes, rem) }
    kp("")
    kp(gray("  Ctrl-C to quit"))
    emit ""
}

just run {
    let mode = "watch"
    if argCount() >= 1 { mode = arg(0) }

    // cached per TOTP window so we don't spawn ykman every second.
    let lastWin = 0 - 1
    let codes = ""
    let infoBlock = ""

    if mode == "once" {
        let present = ykCount()
        let ym = have("ykman")
        if present > 0 {
            if ym == 1 { codes = oathCodes()  infoBlock = ykInfoBlock() }
        }
        draw(present, ym, infoBlock, codes, totpRemaining())
        exit("0")
    }

    // live dashboard: redraw every second; OATH codes re-fetched only when the
    // 30-second TOTP window rolls over (ykman is slow — don't hammer the key).
    while "1" == "1" {
        let present = ykCount()
        let ym = have("ykman")
        let n = nowSec()
        let win = n / 30
        let rem = 30 - (n - win * 30)
        if present > 0 {
            if ym == 1 {
                if win != lastWin {
                    codes = oathCodes()
                    infoBlock = ykInfoBlock()
                    lastWin = win
                }
            }
        }
        draw(present, ym, infoBlock, codes, rem)
        exec("sleep 1")
    }
}
