# VoIPShark (Wireshark 4.x compatible fork)

VoIPShark is a set of Wireshark Lua plugins for analysing VoIP traffic: it can
decrypt SDES-SRTP automatically, export call audio, harvest SIP intelligence
and detect common SIP attacks.

This repository is a maintained fork of
[pentesteracademy/voipshark](https://github.com/pentesteracademy/voipshark).
The upstream project has not been touched since February 2020 and no longer
loads in current Wireshark releases, because Wireshark 4.4 moved to Lua 5.4
and removed the old `bit32` library. All fixes are listed in
[CHANGES.md](CHANGES.md).

> **Targets:** Wireshark 4.4 – 4.6 (Lua 5.4), Windows / macOS / Linux.
> Also expected to work on Wireshark 4.2 (Lua 5.2), but 4.2 is end-of-life.
> All 44 Lua files are verified to load under a real Lua 5.4 interpreter with
> Wireshark API stubs; see [CHANGES.md](CHANGES.md) for the audit.

---

## Features

Everything is available below **Tools → VOIP** (Wireshark GUI only; the
plugins exit immediately under `tshark`).

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
* **GUI only.** All plugins start with `if not gui_enabled() then return end`,
  so `tshark` does not load them.
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
