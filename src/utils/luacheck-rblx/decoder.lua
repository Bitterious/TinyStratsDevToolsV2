local unicode = require(script.Parent.unicode)
local utils = require(script.Parent.utils)

local decoder = {}

local sbyte = string.byte
local sfind = string.find
local sgsub = string.gsub
local ssub = string.sub

local LatinChars = utils.class()
function LatinChars:__init(bytes)
	self._bytes = bytes
end
function LatinChars:get_codepoint(index)
	return sbyte(self._bytes, index)
end
function LatinChars:get_substring(from, to)
	return ssub(self._bytes, from, to)
end
local function hexadecimal_escaper(byte)
	return ("\\x%02X"):format(sbyte(byte))
end
function LatinChars:get_printable_substring(from, to)
	return (sgsub(ssub(self._bytes, from, to), "[^\32-\126]", hexadecimal_escaper))
end
function LatinChars:get_length()
	return #self._bytes
end
function LatinChars:find(pattern, from)
	return sfind(self._bytes, pattern, from)
end

local function get_codepoints_and_byte_offsets(bytes)
	local codepoints = {}
	local byte_offsets = {}
	local byte_index = 1
	local codepoint_index = 1
	while true do
		byte_offsets[codepoint_index] = byte_index
		local codepoint = sbyte(bytes, byte_index)
		if not codepoint then
			return codepoints, byte_offsets
		end
		byte_index = byte_index + 1
		if codepoint >= 0x80 then
			if codepoint < 0xC0 then
				return
			end
			local cont = (sbyte(bytes, byte_index) or 0) - 0x80
			if cont < 0 or cont >= 0x40 then
				return
			end
			byte_index = byte_index + 1
			if codepoint < 0xE0 then
				codepoint = cont + (codepoint - 0xC0) * 0x40
			elseif codepoint < 0xF0 then
				codepoint = cont + (codepoint - 0xE0) * 0x40
				cont = (sbyte(bytes, byte_index) or 0) - 0x80
				if cont < 0 or cont >= 0x40 then
					return
				end
				byte_index = byte_index + 1
				codepoint = cont + codepoint * 0x40
			elseif codepoint < 0xF8 then
				codepoint = cont + (codepoint - 0xF0) * 0x40
				cont = (sbyte(bytes, byte_index) or 0) - 0x80
				if cont < 0 or cont >= 0x40 then
					return
				end
				byte_index = byte_index + 1
				codepoint = cont + codepoint * 0x40
				cont = (sbyte(bytes, byte_index) or 0) - 0x80
				if cont < 0 or cont >= 0x40 then
					return
				end
				byte_index = byte_index + 1
				codepoint = cont + codepoint * 0x40
				if codepoint > 0x10FFFF then
					return
				end
			else
				return
			end
		end
		codepoints[codepoint_index] = codepoint
		codepoint_index = codepoint_index + 1
	end
end

local UnicodeChars = utils.class()

function UnicodeChars:__init(bytes, codepoints, byte_offsets)
	self._bytes = bytes
	self._codepoints = codepoints
	self._byte_offsets = byte_offsets
end
function UnicodeChars:get_codepoint(index)
	return self._codepoints[index]
end
function UnicodeChars:get_substring(from, to)
	local byte_offsets = self._byte_offsets
	return ssub(self._bytes, byte_offsets[from], byte_offsets[to + 1] - 1)
end
function UnicodeChars:get_printable_substring(from, to)
	local parts = {}
	for index = from, to do
		local codepoint = self._codepoints[index]
		if unicode.is_printable(codepoint) then
			table.insert(parts, self:get_substring(index, index))
		else
			table.insert(parts, (codepoint > 255 and "\\u{%X}" or "\\x%02X"):format(codepoint))
		end
	end
	return table.concat(parts)
end
function UnicodeChars:get_length()
	return #self._codepoints
end
function UnicodeChars:find(pattern, from)
	return sfind(self._bytes, pattern, self._byte_offsets[from])
end

function decoder.decode(bytes)
	if sfind(bytes, "[\128-\255]") then
		local codepoints, byte_offsets = get_codepoints_and_byte_offsets(bytes)
		if codepoints then
			return UnicodeChars(bytes, codepoints, byte_offsets)
		end
	end
	return LatinChars(bytes)
end

return decoder
