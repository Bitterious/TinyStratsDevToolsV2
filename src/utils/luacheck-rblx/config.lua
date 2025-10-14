local cache = require(script.Parent.cache)
local options = require(script.Parent.options)
local builtin_standards = require(script.Parent.builtin_standards)
local fs = require(script.Parent.fs)
local globbing = require(script.Parent.globbing)
local standards = require(script.Parent.standards)
local utils = require(script.Parent.utils)
local vFS = require(script.Parent.Parent.vFS)

local config = {}
config.default_path = ".luacheckrc"

function config.get_default_global_path()
	return "tinystrats/global/.luacheckrc"
end

local function locate_config(filesystem, path, global_path)
	if path == false then
		return
	end
	local is_default_path = not path
	path = path or config.default_path
	local current_dir = filesystem.current_dir or ""
	local search_dir = current_dir
	while true do
		local config_path = fs.join(search_dir, path)
		if vFS.file_exists(filesystem, config_path) then
			return config_path, search_dir
		end
		if search_dir == "" or search_dir == "/" then
			break
		end
		search_dir = fs.split_base(search_dir)
	end
	if not is_default_path then
		return nil, ("Couldn't find configuration file %s"):format(path)
	end
	if global_path == false then
		return
	end
	global_path = global_path or config.get_default_global_path()
	if global_path and vFS.file_exists(filesystem, global_path) then
		return global_path, fs.split_base(global_path)
	end
	return
end

local function try_load_from_vfs(filesystem, path)
	if not vFS.file_exists(filesystem, path) then
		return nil
	end
	local fh = vFS.get_file_handler(filesystem, path)
	if not fh then
		return nil
	end
	local src = fh:read("*a")
	fh:close()
	if not src then
		return nil
	end
	local func, err = utils.load(src, nil, "@" .. path)
	return err or func
end

local special_mts = {
	stds = { __index = builtin_standards },
	files = {
		__index = function(files, key)
			files[key] = {}
			return files[key]
		end,
	},
}

local function make_config_env_mt()
	local env_mt = {}
	local special_values = {}
	for key, mt in pairs(special_mts) do
		special_values[key] = setmetatable({}, mt)
	end
	function env_mt.__index(_, key)
		if special_mts[key] then
			return special_values[key]
		else
			return _G[key]
		end
	end
	function env_mt.__newindex(env, key, value)
		if special_mts[key] then
			if type(value) == "table" then
				setmetatable(value, special_mts[key])
			end

			special_values[key] = value
		else
			rawset(env, key, value)
		end
	end
	return env_mt, special_values
end

local function make_config_env()
	local mt, special_values = make_config_env_mt()
	return setmetatable({}, mt), special_values
end

local function remove_env_mt(env, special_values)
	setmetatable(env, nil)
	utils.update(env, special_values)
end

local function set_default_std(files, pattern, std)
	local pattern_opts = { std = std }
	if files[pattern] then
		pattern_opts = utils.update(pattern_opts, files[pattern])
	end
	files[pattern] = pattern_opts
end

local function add_default_path_options(opts)
	local files = {}
	if opts.files then
		files = utils.update(files, opts.files)
	end
	opts.files = files
	set_default_std(files, "**/*.luacheckrc", "+luacheckrc")
end

local fallback_config = { options = {}, anchor_dir = "" }
add_default_path_options(fallback_config.options)

function config.load_config(filesystem, path, global_path)
	if not filesystem then
		return fallback_config
	end
	local config_path, anchor_dir = locate_config(filesystem, path, global_path)
	if not config_path then
		if anchor_dir then
			return nil, anchor_dir
		else
			return fallback_config
		end
	end
	local env, special_values = make_config_env()
	local func_or_err = try_load_from_vfs(filesystem, config_path)
	if type(func_or_err) == "string" then
		return nil, ("Couldn't load configuration from %s: syntax error (%s)"):format(config_path, func_or_err)
	end
	if not func_or_err then
		return nil, ("Couldn't load configuration from %s: file not found"):format(config_path)
	end
	setfenv(func_or_err, env)
	local success, ret = pcall(func_or_err)
	if not success then
		return nil, ("Couldn't load configuration from %s: runtime error (%s)"):format(config_path, ret)
	end
	if type(ret) == "table" then
		utils.update(env, ret)
	end
	remove_env_mt(env, special_values)
	add_default_path_options(env)
	return { options = env, config_path = config_path, anchor_dir = anchor_dir }
end

function config.table_to_config(opts)
	return { options = opts }
end

local function add_stds_from_config(conf, stds)
	if conf.options.stds ~= nil then
		if type(conf.options.stds) ~= "table" then
			return nil, ("invalid option 'stds': table expected, got %s"):format(type(conf.options.stds))
		end
		local std_names = {}
		for std_name in pairs(conf.options.stds) do
			if type(std_name) == "string" then
				table.insert(std_names, std_name)
			end
		end
		table.sort(std_names)
		for _, std_name in ipairs(std_names) do
			local std = conf.options.stds[std_name]
			if type(std) ~= "table" then
				return nil, ("invalid custom std '%s': table expected, got %s"):format(std_name, type(std))
			end
			local ok, err = standards.validate_std_table(std)
			if not ok then
				return nil, ("invalid custom std '%s': %s"):format(std_name, err)
			end
			stds[std_name] = std
		end
	end
	return true
end

local function error_prefix(conf)
	if conf.config_path then
		return ("in config loaded from %s: "):format(conf.config_path)
	else
		return ""
	end
end

local function quiet_validator(x)
	if type(x) == "number" then
		if math.floor(x) == x and x >= 0 and x <= 3 then
			return true
		else
			return false, ("integer in range 0..3 expected, got %.20g"):format(x)
		end
	else
		return false, ("integer in range 0..3 expected, got %s"):format(type(x))
	end
end

local function jobs_validator(x)
	if type(x) == "number" then
		if math.floor(x) == x and x >= 1 then
			return true
		else
			return false, ("positive integer expected, got %.20g"):format(x)
		end
	else
		return false, ("positive integer expected, got %s"):format(type(x))
	end
end

config.format_options = {
	quiet = quiet_validator,
	color = utils.has_type("boolean"),
	codes = utils.has_type("boolean"),
	ranges = utils.has_type("boolean"),
	formatter = utils.has_either_type("string", "function"),
}

local top_options = {
	cache = utils.has_either_type("string", "boolean"),
	jobs = jobs_validator,
	files = utils.has_type("table"),
	stds = utils.has_type("table"),
	exclude_files = utils.array_of("string"),
	include_files = utils.array_of("string"),
}

utils.update(top_options, config.format_options)
utils.update(top_options, options.all_options)

local function validate_config(conf, stds)
	local ok, err = options.validate(top_options, conf.options, stds)
	if not ok then
		return nil, err
	end
	if conf.options.files then
		for path, opts in pairs(conf.options.files) do
			if type(path) == "string" then
				ok, err = options.validate(options.all_options, opts, stds)

				if not ok then
					return nil, ("invalid options for path '%s': %s"):format(path, err)
				end
			end
		end
	end
	return true
end

local ConfigStack = utils.class()

function ConfigStack:__init(configs, stds)
	self._configs = configs
	self._stds = stds
end
function ConfigStack:get_stds()
	return self._stds
end

function config.stack_configs(configs)
	local stds = utils.update({}, builtin_standards)
	for _, conf in ipairs(configs) do
		local ok, err = add_stds_from_config(conf, stds)
		if not ok then
			return nil, error_prefix(conf) .. err
		end
	end
	for _, conf in ipairs(configs) do
		local ok, err = validate_config(conf, stds)
		if not ok then
			return nil, error_prefix(conf) .. err
		end
	end
	return ConfigStack(configs, stds)
end

function ConfigStack:get_top_options(filesystem)
	local res = {
		quiet = 0,
		color = true,
		codes = false,
		ranges = false,
		formatter = "default",
		cache = false,
		jobs = false,
		include_files = {},
		exclude_files = {},
	}
	local current_dir = filesystem and filesystem.current_dir or ""
	local last_anchor_dir
	for _, conf in ipairs(self._configs) do
		for _, option in ipairs({ "quiet", "color", "codes", "ranges", "jobs" }) do
			if conf.options[option] ~= nil then
				res[option] = conf.options[option]
			end
		end
		last_anchor_dir = conf.anchor_dir or last_anchor_dir
		if conf.options.formatter ~= nil then
			res.formatter = conf.options.formatter
			res.formatter_anchor_dir = last_anchor_dir
		end
		local anchor_dir = conf.anchor_dir or current_dir
		for _, option in ipairs({ "include_files", "exclude_files" }) do
			if conf.options[option] ~= nil then
				for _, glob in ipairs(conf.options[option]) do
					table.insert(res[option], fs.normalize(fs.join(anchor_dir, glob)))
				end
			end
		end
		if conf.options.cache ~= nil then
			if conf.options.cache == true then
				if not res.cache then
					res.cache = fs.normalize(fs.join(last_anchor_dir or current_dir, cache.get_default_dir()))
				end
			elseif conf.options.cache == false then
				res.cache = false
			else
				res.cache = fs.normalize(fs.join(anchor_dir, conf.options.cache))
			end
		end
	end
	return res
end

local function add_applying_overrides(option_stack, conf, filename, filesystem)
	if not filename or not conf.options.files then
		return
	end
	local current_dir = filesystem and filesystem.current_dir or ""
	local abs_filename = fs.normalize(fs.join(current_dir, filename))
	local anchor_dir
	if conf.anchor_dir == "" then
		anchor_dir = fs.split_base(current_dir)
	else
		anchor_dir = conf.anchor_dir or current_dir
	end
	local matching_pairs = {}
	for glob, opts in pairs(conf.options.files) do
		if type(glob) == "string" then
			local abs_glob = fs.normalize(fs.join(anchor_dir, glob))

			if globbing.match(abs_glob, abs_filename) then
				table.insert(matching_pairs, {
					abs_glob = abs_glob,
					opts = opts,
				})
			end
		end
	end
	table.sort(matching_pairs, function(pair1, pair2)
		return globbing.compare(pair1.abs_glob, pair2.abs_glob)
	end)
	for _, pair in ipairs(matching_pairs) do
		table.insert(option_stack, pair.opts)
	end
end

function ConfigStack:get_options(filename, filesystem)
	local res = {}
	for _, conf in ipairs(self._configs) do
		table.insert(res, conf.options)
		add_applying_overrides(res, conf, filename, filesystem)
	end
	return res
end

return config
