# yubiKrypt

A YubiKey detector + OATH/TOTP authenticator written in **KryptScript** — the
scripting layer of [Krypton](https://krypton-lang.org). Single self-contained
`.ks` file, no C, no clang: everything runs through Krypton's native `exec`
builtin.

Plug a key in, leave it, and watch a live dashboard of your TOTP codes.

## What it does

- **Detects** a plugged-in YubiKey via `ioreg` — works with zero extra install.
- Shows the **model** and **enabled interfaces** (OTP / FIDO / CCID).
- With [`ykman`](https://developers.yubico.com/yubikey-manager/) installed:
  **serial, firmware, and live OATH TOTP codes** with a 30-second countdown.

No secrets are stored or transmitted — it only reads what the key (and `ykman`)
report.

## Build

Needs Krypton installed (provides `kcc.sh`). From this folder:

```sh
./build.sh
# or directly:
kcc.sh yubikrypt.ks -o yubikrypt
```

## Run

```sh
./yubikrypt          # live dashboard (refreshes every second; Ctrl-C to quit)
./yubikrypt once     # print status once and exit
```

## OATH codes (optional)

Detection works out of the box. To see TOTP codes you need Yubico's CLI:

```sh
brew install ykman
```

Then add accounts with `ykman oath accounts add ...` (or via Yubico Authenticator)
and yubiKrypt will display them live.

## How it works

| feature | mechanism | needs |
|---------|-----------|-------|
| detect key, model, interfaces | `ioreg -p IOUSB` | nothing |
| serial / firmware | `ykman info` | ykman |
| TOTP codes + countdown | `ykman oath accounts code` + `date +%s` | ykman |

All via `exec` — the program is pure KryptScript. macOS today; Linux is a small
change (`lsusb`/`ykman` instead of `ioreg`).

## Status

Prototype. Built and verified live against a real `YubiKey OTP+FIDO+CCID`.
