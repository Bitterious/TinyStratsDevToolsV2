local fs = require(script.Parent.fs)
local serializer = require(script.Parent.serializer)
local sha1 = require(script.Parent.vendor.sha1)
local utils = require(script.Parent.utils)
local base64 = require(script.Parent.Parent.base64)
local vFS = require(script.Parent.Parent.vFS)

local cache = {}

function cache.get_default_dir()
	return "tinystrats/cache"
end

local format_version = "1"

local Cache = utils.class()

function Cache:__init(cache_id, plugin_instance)
	if not plugin_instance then
		return nil, "Plugin instance is required"
	end
	self._plugin = plugin_instance
	self._id = cache_id
	local cachefs
	local existing = self._plugin:GetSetting("tinystrats/.cache/" .. cache_id)
	if existing then
		existing = base64.decode(existing)
		cachefs = vFS.from_binary_string(existing)
	else
		cachefs = vFS.new()
	end
	self._fs = cachefs
	self._current_dir = cachefs.current_dir or ""
	self._dir = cache.get_default_dir()
	if not vFS.file_exists(self._fs, self._dir) then
		vFS.create_object(self._fs, self._dir)
	end
	return true
end

function Cache:_save()
	local binary = vFS.to_binary_string(self._fs)
	local encoded = base64.encode(binary)
	self._plugin:SetSetting("tinystrats/.cache/" .. self._id, encoded)
end

function Cache:put(filename, check_result)
	local normalized_filename = fs.normalize(fs.join(self._current_dir, filename))
	local cache_filename = fs.join(self._dir, sha1.sha1(normalized_filename))
	local serialized_result = serializer.dump_check_result(check_result)
	local data = format_version .. "\n" .. normalized_filename .. "\n" .. serialized_result
	if vFS.file_exists(self._fs, cache_filename) then
		local _, err = vFS.write_file(self._fs, cache_filename, data)
		if err then 
			return false, err 
		end
	else
		local _, err = vFS.create_object(self._fs, cache_filename, data)
		if err then 
			return false, err 
		end
	end
	self:_save()
	return true
end

function Cache:get(filename)
	local normalized_filename = fs.normalize(fs.join(self._current_dir, filename))
	local cache_filename = fs.join(self._dir, sha1.sha1(normalized_filename))
	if not vFS.file_exists(self._fs, cache_filename) then
		return
	end
	local file_mtime = fs.get_mtime(filename)
	local cache_dates = vFS.get_dates(self._fs, cache_filename)
	if not file_mtime or not cache_dates or file_mtime >= cache_dates.modified_at then
		return
	end
	local fh = vFS.get_file_handler(self._fs, cache_filename)
	if not fh then
		return
	end
	local version_line = fh:read("*l")
	if version_line ~= format_version then
		fh:close()
		return
	end
	local filename_line = fh:read("*l")
	if filename_line ~= normalized_filename then
		fh:close()
		return
	end
	local serialized_result = fh:read("*a")
	fh:close()
	if not serialized_result then
		return nil, true
	end
	local result = serializer.load_check_result(serialized_result)
	if not result then
		return nil, true
	end
	return result
end

function Cache:clear(filename)
	if filename then
		local normalized_filename = fs.normalize(fs.join(self._current_dir, filename))
		local cache_filename = fs.join(self._dir, sha1.sha1(normalized_filename))
		if vFS.file_exists(self._fs, cache_filename) then
			vFS.remove_object(self._fs, cache_filename)
			self:_save()
		end
	end
end

function cache.new(cache_id, plugin_instance)
	if not plugin_instance then
		return nil, "Plugin instance is required"
	end
	return Cache(cache_id, plugin_instance)
end

return cache