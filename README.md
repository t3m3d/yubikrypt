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

## Install

### 1. Prerequisites

- **macOS** (Apple Silicon / arm64). Linux is a small change away — see *How it
  works*.
- **Krypton** — the compiler/runtime that provides `kcc.sh` and `kr`. Get it
  from [krypton-lang.org](https://krypton-lang.org) (or build from the
  [krypton repo](https://github.com/t3m3d/krypton): `./install.sh`). Make sure
  `kcc.sh` / `kr` are on your `PATH`:

  ```sh
  kcc.sh --version    # should print a version
  ```

- **ykman** *(optional — needed only for OATH/TOTP codes)*:

  ```sh
  brew install ykman
  ```

### 2. Get yubiKrypt

```sh
git clone https://github.com/t3m3d/yubikrypt.git
cd yubikrypt
```

### 3. Build

The build script is itself KryptScript (no bash build step):

```sh
kr build.ks
# or compile directly:
kcc.sh yubikrypt.ks -o yubikrypt
```

This produces the `./yubikrypt` binary (gitignored — you build it locally).

> **Note:** if you have both a packaged Krypton (`/usr/local/krypton`) and a
> dev checkout, build with the dev repo's compiler — a stale install can
> miscompile (silent crash at runtime). `build.ks` prefers the dev repo
> automatically; override with `KCC=/path/to/kcc.sh kr build.ks`.

### 4. (Optional) put it on your PATH

```sh
sudo ln -sf "$PWD/yubikrypt" /usr/local/bin/yubikrypt
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
