# VoIPShark (Wireshark 4.x compatible fork)

**English** · [简体中文](README.zh-CN.md)

[![Lua syntax check](https://github.com/Andersonong-github/voipshark/actions/workflows/lua-check.yml/badge.svg)](https://github.com/Andersonong-github/voipshark/actions/workflows/lua-check.yml)

VoIPShark is a set of Wireshark Lua plugins for analysing VoIP traffic: it can
decrypt SDES-SRTP automatically, export call audio, harvest SIP intelligence
and detect common SIP attacks.

This repository is a maintained fork of
[pentesteracademy/voipshark](https://github.com/pentesteracademy/voipshark).
The upstream project has not been touched since February 2020 and no longer
loads in current Wireshark releases, because Wireshark 4.4 moved to Lua 5.4
and removed the old `bit32` library. All fixes are listed in
[CHANGES.md](CHANGES.md).

> **Verified on:** Wireshark 4.6.7 (portable build, Windows) — the whole plugin
> set installs, loads without errors, and decrypts the bundled SRTP captures.
> Also expected to work on Wireshark 4.4 (Lua 5.4) and 4.2 (Lua 5.2, end of
> life). See [CHANGES.md](CHANGES.md) for the full audit.

---

## Features

The menu entries are available below **Tools → VOIP** (Wireshark GUI). The
menu-driven plugins exit immediately under `tshark`; `srtp_decrypt.lua` also
works headless (see below).

| Plugin | Menu | What it does |
| --- | --- | --- |
| `srtp_decrypt.lua` | automatic | Hooks SIP on UDP/5060 and TLS/5061, reads the SDES key from `a=crypto:... inline:<base64>` in SDP, derives the SRTP session key/salt (RFC 3711 AES-CM KDF) and decrypts RTP payloads in place. Supports `AES_CM_128_HMAC_SHA1_80` and `AES_CM_256_HMAC_SHA1_80`. Encrypted calls then show up as plain RTP with the original packet structure and timestamps. Enable it in **Edit → Preferences → Protocols → VoIPShark → Decrypt SRTP Automatically**. |
| `exportWav.lua` | VOIP → Export Wav | Groups RTP by `src-dst-ssrc` and writes one `.wav` per stream. Suitable for G.711 (PCMU/PCMA) audio. |
| `info_gather_sip.lua` | VOIP → SIP Information Gathering → Extensions / Servers and Proxy / SIP Auth Export | Lists extensions, SIP servers/proxies, and exports digest-auth material (username, realm, nonce, URI, response, …) that can be fed to tools such as `sipcrack`. |
| `info_gather_rtp.lua` | VOIP → SIP Information Gathering → RTP Packet Transfers | Summarises RTP streams and packet transfers per call. |
| `info_gather_dtmf.lua` | VOIP → SIP Information Gathering → DTMF Sequences | Reconstructs dialled DTMF digits from `telephone-event` RTP. |
| `info_gather_unique_message.lua` | VOIP → SIP Information Gathering → Unique Messages | De-duplicates SIP `MESSAGE` (SMS) bodies and shows sender/receiver/text. |
| `attack_detection.lua` | VOIP → VOIP Attack Detection → … | Brute force, message flooding, INVITE flooding, SIP MITM attempts and unauthenticated users. Thresholds are hard-coded in the script (`brute_force_request_threshold = 5`, `invite_flood_threshold = 3`, …). |

Results are shown in text windows with **Search** and **Reset** buttons.

---

## Build ("compiling")

VoIPShark is **pure Lua**: there is no compilation step, no C extension and no
separate Lua installation required. The files under `plugins/` are already the
finished artifact, and Wireshark executes them with its own bundled Lua 5.4
interpreter.

"Building" therefore only means:

1. **Syntax-check** the scripts (optional, needs a standalone Lua 5.4):

   ```bash
   # Debian/Ubuntu: sudo apt install lua5.4
   find plugins -name '*.lua' -print0 | xargs -0 -n1 luac -p
   ```

   No Lua installed? Use the bundled Node.js checker (the same one GitHub
   Actions runs):

   ```bash
   npm install --no-save luaparse
   node tools/check-lua.js
   ```

   Or simply let Wireshark parse them — this must print no `Lua Error`:

   ```bash
   tshark -G plugins
   ```

2. **Package** a zip you can attach to a GitHub release (optional):

   ```powershell
   Compress-Archive -Path plugins\* -DestinationPath voipshark-plugins.zip -Force
   ```

   ```bash
   (cd plugins && zip -r ../voipshark-plugins.zip .)
   ```

3. **Install** it — see below. Installing is just copying the files; Wireshark
   picks them up on the next start.

---

## Installation

### Windows (PowerShell)

```powershell
# from the repository root
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script copies everything under `plugins\` (including the `lockbox`
library and `init.lua`) into `%APPDATA%\Wireshark\plugins`, making a backup of
any file it overwrites. Restart Wireshark afterwards.

Manual install: copy the **contents** of the `plugins` folder into

```
%APPDATA%\Wireshark\plugins
```

#### Wireshark Portable

A portable build keeps everything under its own folder, so point the installer
at its personal plugin directory:

```powershell
# WiresharkPortable64 in Documents, for example
.\install.ps1 -Destination "$HOME\Documents\WiresharkPortable64\Data\settings\Wireshark\plugins"
```

The path is always `<portable folder>\Data\settings\Wireshark\plugins`; you can
confirm it in the portable Wireshark under **Help → About Wireshark → Folders →
Personal Lua Plugins**.

### Linux / macOS

```bash
./install.sh
```

The default destination is `~/.local/lib/wireshark/plugins`. Override it with
`WIRESHARK_PLUGIN_DIR=/path/to/plugins ./install.sh` if your Wireshark uses a
different personal plugin directory.

Manual install: copy the **contents** of `plugins/` (not the folder itself)
into your personal Lua plugin directory.

### Finding the right directory

In Wireshark: **Help → About Wireshark → Folders → Personal Lua Plugins**.
On the command line: `tshark -G folders | grep -i "Personal Lua"`.

The final layout must look like this:

```
<personal-lua-plugins>/
├── init.lua
├── srtp_decrypt.lua
├── attack_detection.lua
├── exportWav.lua
├── info_gather_sip.lua
├── info_gather_rtp.lua
├── info_gather_dtmf.lua
├── info_gather_unique_message.lua
├── util.lua
└── lockbox/
    ├── init.lua
    ├── cipher/
    ├── digest/
    └── ...
```

`init.lua` is loaded before the other scripts and only provides compatibility
shims (it re-creates `bit32` on top of Wireshark's bundled `bit` library and
adds the plugin directory to `package.path`).

### Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

```bash
./uninstall.sh
```

Both only remove the files that belong to this project and leave everything
else in the plugin directory untouched.

---

## Verifying the install

1. Start Wireshark and check that **Tools → VOIP** exists.
2. Open `Sample PCAPs/SIP-SRTP-Normal_Call_two_parties.pcap`.
3. Enable **Edit → Preferences → Protocols → VoIPShark → Decrypt SRTP
   Automatically**, then reload the capture (Ctrl+Shift+R).
4. The SRTP packets should now be dissected as RTP with readable payload.
5. Try **VOIP → Export Wav** to dump the audio, or **VOIP → SIP Information
   Gathering → SIP Auth Export** on `SIP-RTP-Normal_Call_two_parties.pcap`.

Headless check with `tshark` (works without the GUI):

```bash
tshark -r "Sample PCAPs/SIP-SRTP-Normal_Call_two_parties.pcap" \
       -o voipshark.srtp:TRUE -Y rtp -T fields -e rtp.ssrc | head
```

The SRTP packets should be listed as `rtp` with their SSRC. Add `-2` to
reproduce the GUI's two-pass dissection.

If something fails, open **Tools → Lua Console** (or watch the dialog shown at
startup) to see the exact Lua error.

---

## Compatibility notes / limitations

* **SDES only.** SRTP decryption relies on the master key being present in SDP
  (`a=crypto:… inline:…`). DTLS-SRTP (key exchanged in the DTLS handshake) is
  not supported. ZRTP is not supported. Of the SDES suites, AES_CM_128 and
  AES_CM_256 are implemented; AES_CM_192 and the null cipher are not.
* **SIP over TLS is registered on port 5061 only.** Other ports can be added
  at the bottom of `plugins/srtp_decrypt.lua`.
* **WAV export assumes raw PCM payload**, i.e. G.711. G.722, Opus, AMR and
  other codecs will produce noise. For those, export the RTP payload and
  decode it with a proper codec.
* **SIP packets that carry `a=crypto` are handled by the plugin itself.** While
  *Decrypt SRTP Automatically* is enabled those INVITE/200 messages are shown
  as `VoIPShark` and their SIP/SDP details are not dissected, and RTCP streams
  appear as `data`. Disable the preference to get the normal SIP/SDP view back.
* **GUI only for the menu-driven plugins.** `srtp_decrypt.lua` itself also runs
  under `tshark` (use `-o voipshark.srtp:TRUE`); the others exit immediately
  when `gui_enabled()` is false.
* **Hard-coded heuristic thresholds** in `attack_detection.lua`; edit the
  `settings` table if your environment needs different values.
* Wireshark 4.2 is still supported by the code path (Lua 5.2 + `bit32`), but it
  no longer receives security updates — prefer 4.4/4.6.

## Changes from upstream

See [CHANGES.md](CHANGES.md). Summary:

* `bit32` replaced by the bundled `bit` library (with unsigned 32-bit
  normalisation) — fixes `attempt to index global 'bit32' (a nil value)`.
* `file_exists()` implemented (upstream called an undefined global).
* `data-text-lines` replaced by `data.text` with a fallback (the field no
  longer exists in current Wireshark).
* AES_CM_256 suites are now decrypted too (the cipher is chosen from the key
  length instead of being hard-coded to AES-128).
* Payloads whose length is not a multiple of 16 bytes are no longer truncated.
* The SIP-over-TLS registration uses `tls.port` (falling back to `ssl.port`),
  which removes a deprecation warning on Wireshark 4.6.
* `lockbox` moved into `plugins/` so the plugin directory is a single
  drop-in; `init.lua` added for module paths and the `bit32` shim.
* Install/uninstall scripts and updated documentation.

## Credits

Original tool by Nishant Sharma, Ashish Bhangale and Jeswin Mathai
(Pentester Academy), under the guidance of Vivek Ramachandran.
Presented at DEF CON China 1.0 and Black Hat Asia 2019 Arsenal.

The AES/SHA implementation is [lockbox](https://github.com/gilbertchen/lockbox)
by Gilbert Chen.

## License

GNU General Public License v2.0 — see [LICENSE](LICENSE).

## Disclaimer

Use only on networks and captures you own or are explicitly authorised to
test. Decrypting third-party voice traffic may be illegal in your
jurisdiction.
