#!/usr/bin/env kr
// build.ks — compile yubikrypt, in KryptScript (no bash build step).
//
//   kr build.ks        compile yubikrypt.ks -> ./yubikrypt
//
// Self-contained (no k: imports). Everything via the native exec builtin.
// Prefers the dev krypton repo's compiler over a PATH install: a stale
// /usr/local/krypton can ship an older backend that miscompiles (silent
// SIGSEGV at runtime). Override the compiler with:  KCC=/path/to/kcc.sh kr build.ks

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
func exists(p) {
    if _chomp(exec("test -e " + _q(p) + " && echo 1 || echo 0")) == "1" { emit 1 }
    emit 0
}

func findKcc() {
    let override = sh("printf '%s' \"$KCC\"")
    if override != "" { emit override }
    let dev = sh("printf '%s' \"$HOME\"") + "/Documents/GitHub/krypton/kcc.sh"
    if exists(dev) == 1 { emit dev }
    let onpath = sh("command -v kcc.sh 2>/dev/null")
    if onpath != "" { emit onpath }
    emit ""
}

just run {
    let kcc = findKcc()
    if kcc == "" {
        kp("error: can't find kcc.sh (install Krypton or set KCC=/path/to/kcc.sh)")
        exit("1")
    }
    kp("compiling yubikrypt.ks with " + kcc)
    exec("bash " + _q(kcc) + " yubikrypt.ks -o yubikrypt")
    if exists("yubikrypt") == 1 {
        kp("built ./yubikrypt   - run it with: ./yubikrypt")
    } else {
        kp("build failed")
        exit("1")
    }
}
