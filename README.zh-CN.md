# VoIPShark（Wireshark 4.x 兼容版）

VoIPShark 是一组 Wireshark Lua 插件，用于分析 VoIP 流量：自动解密 SDES-SRTP、
导出通话音频、收集 SIP 情报、检测常见 SIP 攻击。

本仓库是 [pentesteracademy/voipshark](https://github.com/pentesteracademy/voipshark)
的维护分支。上游自 2020 年 2 月起停止更新，在 Wireshark 4.4+ 上已经无法加载
（Lua 5.4 移除了 `bit32`）。所有改动见 [CHANGES.md](CHANGES.md)。

> **兼容性：** Wireshark 4.4–4.6（Lua 5.4），Windows / macOS / Linux。
> 理论上也兼容 4.2（Lua 5.2），但 4.2 已停止维护。
> 全部 44 个 Lua 文件已在真实 Lua 5.4 解释器 + Wireshark API 桩环境下验证可加载，
> 详见 [CHANGES.md](CHANGES.md)。

---

## 功能

安装后全部位于 **Tools → VOIP** 菜单（仅 GUI；`tshark` 下插件会自动退出）。

| 插件 | 菜单 | 作用 |
| --- | --- | --- |
| `srtp_decrypt.lua` | 自动生效 | 挂钩 UDP/5060 与 TLS/5061，从 SDP 的 `a=crypto:... inline:<base64>` 读取 SDES 密钥，按 RFC 3711 的 AES-CM KDF 派生 SRTP 会话密钥并就地解密 RTP。启用方式：**Edit → Preferences → Protocols → VoIPShark → Decrypt SRTP Automatically**。 |
| `exportWav.lua` | VOIP → Export Wav | 按 `源IP-目的IP-SSRC` 聚合 RTP，每条流导出一个 `.wav`。适合 G.711（PCMU/PCMA）。 |
| `info_gather_sip.lua` | VOIP → SIP Information Gathering → Extensions / Servers and Proxy / SIP Auth Export | 枚举分机号、SIP 服务器/代理；导出 401/407 的认证字段（username、realm、nonce、URI、response 等），可交给 `sipcrack` 跑字典。 |
| `info_gather_rtp.lua` | … → RTP Packet Transfers | 按通话汇总 RTP 流和包传输。 |
| `info_gather_dtmf.lua` | … → DTMF Sequences | 从 `telephone-event` 还原按键序列。 |
| `info_gather_unique_message.lua` | … → Unique Messages | SIP `MESSAGE`（短信）正文去重，显示收发方与内容。 |
| `attack_detection.lua` | VOIP → VOIP Attack Detection → … | 暴力破解、消息洪泛、INVITE 洪泛、SIP MITM、未认证用户。阈值写死在脚本里（默认暴力破解 5 次、INVITE 洪泛 3 次）。 |

结果以文本窗口展示，带 **Search** / **Reset** 按钮。

---

## 安装

### Windows（PowerShell）

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会把 `plugins\` 下的全部内容（含 `lockbox` 库和 `init.lua`）复制到
`%APPDATA%\Wireshark\plugins`，覆盖前会做备份。完成后重启 Wireshark。

手动安装：把 `plugins` 文件夹里的**内容**复制到

```
%APPDATA%\Wireshark\plugins
```

### Linux / macOS

```bash
./install.sh
```

默认目标目录是 `~/.local/lib/wireshark/plugins`；如需修改：

```bash
WIRESHARK_PLUGIN_DIR=/your/plugin/dir ./install.sh
```

手动安装：把 `plugins/` 里的**内容**（不是文件夹本身）复制到个人 Lua 插件目录。

### 找到正确的目录

Wireshark 里：**Help → About Wireshark → Folders → Personal Lua Plugins**。
命令行：`tshark -G folders | grep -i "Personal Lua"`。

最终目录结构应为：

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

`init.lua` 会先于其他脚本加载，只做兼容处理：在 Wireshark 自带的 `bit` 库上
重建 `bit32`，并把插件目录加入 `package.path`。

### 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

```bash
./uninstall.sh
```

只删除本项目安装的文件，不影响插件目录里的其他内容。

---

## 验证安装

1. 启动 Wireshark，确认 **Tools → VOIP** 存在。
2. 打开 `Sample PCAPs/SIP-SRTP-Normal_Call_two_parties.pcap`。
3. 打开 **Edit → Preferences → Protocols → VoIPShark → Decrypt SRTP
   Automatically**，然后重新加载抓包（Ctrl+Shift+R）。
4. SRTP 包应显示为可读的 RTP 明文。
5. 试一下 **VOIP → Export Wav**，或对
   `SIP-RTP-Normal_Call_two_parties.pcap` 使用 **SIP Auth Export**。

如果失败，打开 **Tools → Lua Console**（或启动时弹出的错误窗口）查看具体
Lua 报错。

---

## 已知限制

* **仅支持 SDES**：密钥必须出现在 SDP 的 `a=crypto:… inline:…` 中。
  不支持 DTLS-SRTP 和 ZRTP。
* **SIP over TLS 只注册了 5061 端口**，其他端口可在
  `plugins/srtp_decrypt.lua` 末尾自行添加。
* **WAV 导出按原始 PCM 处理**，适用于 G.711；G.722、Opus、AMR 等会导出噪音。
* **仅 GUI**：所有插件都以 `if not gui_enabled() then return end` 开头。
* 攻击检测阈值写死在 `attack_detection.lua` 的 `settings` 表里。
* 4.2 仍可用（Lua 5.2 + `bit32`），但已无安全更新，建议用 4.4/4.6。

## 相对上游的改动

详见 [CHANGES.md](CHANGES.md)，摘要：

* 用 Wireshark 自带的 `bit` 库替代 `bit32`（并归一化为无符号 32 位）——
  修复 `attempt to index global 'bit32' (a nil value)`。
* 实现 `file_exists()`（上游调用了未定义的全局函数）。
* `data-text-lines` → `data.text`（旧字段已不存在），带向后兼容回退。
* `lockbox` 移入 `plugins/`，插件目录可直接整体复制；新增 `init.lua`。
* 新增安装/卸载脚本和文档。

## 版权与致谢

原始工具作者：Nishant Sharma、Ashish Bhangale、Jeswin Mathai
（Pentester Academy），指导：Vivek Ramachandran。
曾在 DEF CON China 1.0 与 Black Hat Asia 2019 Arsenal 展示。

AES/SHA 实现来自 [lockbox](https://github.com/gilbertchen/lockbox)（Gilbert Chen）。

## 许可证

GNU General Public License v2.0，见 [LICENSE](LICENSE)。

## 免责声明

仅可用于你拥有或获得明确授权的网络与抓包。解密第三方语音流量在部分司法辖区
可能违法。
