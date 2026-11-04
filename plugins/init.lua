--[[
  VoIPShark 4.x compatibility bootstrap

  Wireshark loads this file (from a Lua plugin directory) before any other
  Lua plugin in that directory, which makes it a good place for the small
  shims needed by the original 2019 plugins.

  Changes:
    * Adds this directory to package.path so "require('lockbox.*')" works
      regardless of where the lockbox folder is placed.
    * Re-creates the Lua 5.2 "bit32" library on top of Wireshark's bundled
      "bit" library (Lua 5.4 removed bit32). Results are normalised to
      unsigned 32-bit values, matching the old bit32 behaviour.
--]]

do
  -- Make sure modules shipped next to this file can always be required.
  local source = debug.getinfo(1, "S").source
  local dir = source:match("^@(.*[/\\])")
  if dir then
    local sep = package.config:sub(1, 1)
    package.path = package.path
      .. ";" .. dir .. "?.lua"
      .. ";" .. dir .. "?" .. sep .. "init.lua"
  end

  if not bit32 then
    local ok, bit = pcall(require, "bit")
    if ok and type(bit) == "table" then
      local function u32(n) return n % 4294967296 end
      bit32 = {
        band   = function(a, b) return u32(bit.band(a, b)) end,
        bor    = function(a, b) return u32(bit.bor(a, b)) end,
        bxor   = function(a, b) return u32(bit.bxor(a, b)) end,
        bnot   = function(a) return u32(bit.bnot(a)) end,
        lshift = function(a, b) return u32(bit.lshift(a, b)) end,
        rshift = function(a, b) return u32(bit.rshift(a, b)) end,
        arshift = function(a, b) return u32(bit.arshift(a, b)) end,
        lrotate = function(a, b) return u32((bit.lrotate or bit.rol)(a, b)) end,
        rrotate = function(a, b) return u32((bit.rrotate or bit.ror)(a, b)) end,
      }
    end
  end
end
