# Changes relative to upstream

Upstream: <https://github.com/pentesteracademy/voipshark> (last commit
2020-02-18). This fork keeps the original behaviour and only fixes what modern
Wireshark (4.4+, Lua 5.4) requires.

## 1. `bit32` removed in Lua 5.3+

**File:** `plugins/srtp_decrypt.lua`

The script used the Lua 5.2 global `bit32`:

```lua
local AND=bit32.band
...
```

Wireshark 4.4 removed Lua 5.2 support and now bundles Lua 5.4, where `bit32`
does not exist. Loading the plugin failed with:

```
Lua: Error during loading:
.../srtp_decrypt.lua:25: attempt to index global 'bit32' (a nil value)
```

It now uses `lockbox.util.bit`, which already probes for `bit`, `bit32` and
`bit.numberlua` in that order. Wireshark 4.4+ bundles the `bit` library, Lua
5.2 provides `bit32`.

One subtlety: `bit` returns *signed* 32-bit integers, whereas `bit32` returned
*unsigned* ones. The original code feeds the results to `string.format("%x", …)`
and would print 16 hex digits for negative values on Lua 5.4. The five
operations are therefore wrapped so results stay in `[0, 2^32)`, reproducing the
old `bit32` behaviour exactly.

## 2. `file_exists()` was never defined

**File:** `plugins/exportWav.lua`

The top-level path detection calls `file_exists(path)`, but no such global
exists in Wireshark's Lua API and the plugin never defines it. On Windows the
call is usually bypassed; on Linux/macOS it raised an error while loading the
script.

A local `file_exists()` based on `io.open` is now defined before first use.

## 3. `data-text-lines` no longer exists

**File:** `plugins/info_gather_unique_message.lua`

The plugin called `Field.new("data-text-lines")`, which is not present in
current Wireshark (the Data dissector exposes `data.text`). `Field.new()` on an
unknown field aborts the script.

The field is now resolved defensively: it first tries the legacy name and falls
back to `data.text`, and the tap callback skips packets when neither is
available.

## 4. Layout / install

* `lockbox/` moved to `plugins/lockbox/` so the `plugins` directory is a single
  drop-in unit. Wireshark automatically adds personal plugin directories to
  `package.path`, so `require("lockbox.util.array")` resolves without manual
  copying to `/usr/local/lib/lua/5.2/`.
* `plugins/init.lua` added: re-creates `bit32` on top of `bit` for any other
  legacy script, and appends the plugin directory to `package.path`.
* `install.ps1`, `install.sh`, `uninstall.ps1`, `uninstall.sh` added.
* README rewritten; Chinese translation added.

## Compatibility audit performed

* All 44 Lua files parse as Lua 5.3/5.4.
* All 44 Lua files were loaded in a real Lua 5.4.6 interpreter with a stub
  implementing the Wireshark API used by the plugins (`Field`, `Listener`,
  `TextWindow`, `Proto`, `Pref`, `DissectorTable`, `bit`, …): every lockbox
  module resolves through `require()` and every plugin reaches its
  registration code without error.
* Every `Field.new()` name used by the plugins was checked against the
  Wireshark 4.6 field reference. All exist except `data-text-lines` (fixed).
* `Listener`, `TextWindow`, `ProgDlg`, `new_dialog`, `register_menu`,
  `MENU_TOOLS_UNSORTED`, `Pref.bool`, `ByteArray.tvb`, `DissectorTable`,
  `gui_enabled`, `persconffile_path` are all still part of the 4.6 Lua API.
* `ssl.port` is still registered as an alias of `tls.port` in the TLS
  dissector, so the SIP-over-TLS registration keeps working.
* `DissectorTable:add()` still accepts numeric strings/ranges, so the SDP
  media-port registration is unchanged.

## Runtime verification checklist

These plugins need a real Wireshark GUI; they cannot be exercised by `tshark`.
After installing, verify with the bundled captures:

1. `SIP-RTP-Normal_Call_two_parties.pcap`
   * Tools → VOIP → SIP Information Gathering → Extensions
   * Tools → VOIP → Export Wav
2. `SIP-SRTP-Normal_Call_two_parties.pcap`
   * enable Preferences → Protocols → VoIPShark → *Decrypt SRTP Automatically*
   * reload, confirm decrypted RTP and playable audio
3. `SIP-over-TLS-RSA-SRTP_Normal_Call_two_parties.pcap`
   * requires the TLS key from `Sample PCAPs/default.key`
4. `DTMF.pcap` → Tools → VOIP → SIP Information Gathering → DTMF Sequences

If a script still fails on a future Wireshark release, the error dialog or
Tools → Lua Console shows the file and line number; most breakage will be a
renamed field (`Field.new`) or a removed helper.
