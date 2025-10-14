local cache = require(script.Parent.cache)
local config = require(script.Parent.config)
local format = require(script.Parent.format)
local fs = require(script.Parent.fs)
local globbing = require(script.Parent.globbing)
local luacheck = require(script.Parent)
local options = require(script.Parent.options)
local utils = require(script.Parent.utils)
local vFS = require(script.Parent.Parent.vFS)

local runner = {}

local Runner = utils.class()

function Runner:__init(config_stack, filesystem, plugin_instance)
	self._config_stack = config_stack
	self._filesystem = filesystem
	self._plugin = plugin_instance
end

local config_options = {
	config = utils.has_type_or_false("string"),
	default_config = utils.has_type_or_false("string")
}

function runner.new(opts)
	if not opts.filesystem then
		return nil, "filesystem (vFS instance) is required"
	end
	if not opts.plugin then
		return nil, "plugin instance is required"
	end
	local ok, err = options.validate(config_options, opts)
	if not ok then
		error(("bad argument #1 to 'runner.new' (%s)"):format(err))
	end
	local base_config, config_err = config.load_config(
		opts.filesystem,
		opts.config,
		opts.default_config
	)
	if not base_config then
		return nil, config_err
	end
	local override_config = config.table_to_config(opts)
	local config_stack
	config_stack, err = config.stack_configs({base_config, override_config})
	if not config_stack then
		return nil, err
	end
	return Runner(config_stack, opts.filesystem, opts.plugin)
end

local function validate_inputs(inputs)
	if type(inputs) ~= "table" then
		return nil, ("inputs table expected, got %s"):format(type(inputs))
	end
	for index, input in ipairs(inputs) do
		local context = ("invalid input table at index [%d]"):format(index)
		if type(input) ~= "table" then
			return nil, ("%s: table expected, got %s"):format(context, type(input))
		end
		local specifies_source
		for _, field in ipairs({"path", "string", "filename"}) do
			if input[field] ~= nil then
				if type(input[field]) ~= "string" then
					return nil, ("%s: invalid field '%s': string expected, got %s"):format(
						context, field, type(input[field]))
				end
				if field ~= "filename" then
					specifies_source = true
				end
			end
		end
		if not specifies_source then
			return nil, ("%s: one of fields 'path' or 'string' must be present"):format(context)
		end
	end

	return true
end

local function matches_any(globs, filename)
	for _, glob in ipairs(globs) do
		if globbing.match(glob, filename) then
			return true
		end
	end
	return false
end

function Runner:_is_filename_included(abs_filename)
	return not matches_any(self._top_opts.exclude_files, abs_filename) and (
		#self._top_opts.include_files == 0 or matches_any(self._top_opts.include_files, abs_filename))
end

function Runner:_prepare_inputs(inputs)
	local current_dir = self._filesystem.current_dir or ""
	local dir_pattern = #self._top_opts.include_files > 0 and "" or "%.lua$"
	local res = {}
	local function add(input)
		if input.path then
			input.path = input.path:gsub("^%.[/\\]([^/])", "%1")
			input.abs_path = fs.normalize(fs.join(current_dir, input.path))
		end
		local abs_filename
		if input.filename then
			abs_filename = fs.normalize(fs.join(current_dir, input.filename))
		else
			input.filename = input.path
			abs_filename = input.abs_path
		end
		if not input.filename or self:_is_filename_included(abs_filename) then
			table.insert(res, input)
		end
	end
	for _, input in ipairs(inputs) do
		if input.path then
			if vFS.file_exists(self._filesystem, input.path) and not vFS.is_file(self._filesystem, input.path) then
				local filenames = vFS.ls(self._filesystem, input.path, true)
				for _, filename in ipairs(filenames) do
					local full_path = fs.join(input.path, filename)
					if dir_pattern == "" or filename:match(dir_pattern) then
						if vFS.file_exists(self._filesystem, full_path) then
							add({path = full_path, filename = input.filename})
						end
					end
				end
			elseif vFS.file_exists(self._filesystem, input.path) then
				add({path = input.path, filename = input.filename})
			else
				add({
					path = input.path,
					fatal = "I/O",
					msg = "file not found in filesystem",
					filename = input.filename
				})
			end
		elseif input.string then
			add({string = input.string, filename = input.filename})
		else
			error("input doesn't specify source to check")
		end
	end
	return res
end

function Runner:_add_cached_reports(inputs)
	for _, input in ipairs(inputs) do
		if not input.fatal and input.path then
			local file_dates = vFS.get_dates(self._filesystem, input.path)
			local file_mtime = file_dates and file_dates.modified_at
			local report, err = self._cache:get(input.path, file_mtime)
			if err then
				input.fatal = "I/O"
				input.msg = ("Couldn't load cache for %s: malformed data"):format(input.path)
			else
				input.cached_report = report
			end
		end
	end
end

function Runner:_add_new_reports(inputs)
	local sources = {}
	local original_indexes = {}
	for index, input in ipairs(inputs) do
		if not input.fatal and not input.cached_report then
			if input.string then
				table.insert(sources, input.string)
				table.insert(original_indexes, index)
			else
				local fh = vFS.get_file_handler(self._filesystem, input.path)
				if fh then
					local source = fh:read("*a")
					fh:close()
					if source then
						table.insert(sources, source)
						table.insert(original_indexes, index)
					else
						input.fatal = "I/O"
						input.msg = "couldn't read file"
					end
				else
					input.fatal = "I/O"
					input.msg = "couldn't open file"
				end
			end
		end
	end
	local reports = {}
	for _, source in ipairs(sources) do
		table.insert(reports, luacheck.get_report(source))
	end
	for index, report in ipairs(reports) do
		inputs[original_indexes[index]].new_report = report
	end
end

function Runner:_save_new_reports_to_cache(inputs)
	for _, input in ipairs(inputs) do
		if input.new_report and input.path then
			local ok, err = self._cache:put(input.path, input.new_report)

			if not ok then
				return nil, ("Couldn't save cache for %s: %s"):format(
					input.path, err or "I/O error"
				)
			end
		end
	end

	return true
end

function Runner:_get_reports(inputs)
	if self._top_opts.cache then
		local cache_id = self._top_opts.cache:gsub("[^%w_-]", "_")
		local err
		self._cache, err = cache.new(cache_id, self._plugin)
		if not self._cache then
			return nil, err
		end
		self:_add_cached_reports(inputs)
	end
	self:_add_new_reports(inputs)
	if self._top_opts.cache then
		local ok, err = self:_save_new_reports_to_cache(inputs)

		if not ok then
			return nil, err
		end
	end
	local res = {}
	for _, input in ipairs(inputs) do
		local report = input.cached_report or input.new_report

		if not report then
			report = {fatal = input.fatal, msg = input.msg}
		end

		report.filename = input.filename
		table.insert(res, report)
	end
	return res
end

function Runner:_get_final_report(reports)
	local processing_options = {}
	for index, report in ipairs(reports) do
		if not report.fatal then
			processing_options[index] = self._config_stack:get_options(
				report.filename,
				self._filesystem
			)
		end
	end
	local final_report = luacheck.process_reports(
		reports,
		processing_options,
		self._config_stack:get_stds()
	)
	for index, report in ipairs(reports) do
		final_report[index].filename = report.filename
	end
	return final_report
end

function Runner:check(inputs)
	local ok, err = validate_inputs(inputs)
	if not ok then
		error(("bad argument #1 to 'Runner:check' (%s)"):format(err))
	end
	self._top_opts = self._config_stack:get_top_options(self._filesystem)
	local prepared_inputs = self:_prepare_inputs(inputs)
	local reports, reports_err = self:_get_reports(prepared_inputs)
	if not reports then
		return nil, reports_err
	end
	return self:_get_final_report(reports)
end

function Runner:format(report, format_opts)
	if type(report) ~= "table" then
		error(("bad argument #1 to 'Runner:format' (report table expected, got %s)"):format(type(report)))
	end
	format_opts = format_opts or {}
	local is_valid, err = options.validate(config.format_options, format_opts)
	if not is_valid then
		error(("bad argument #2 to 'Runner:format' (%s)"):format(err))
	end
	local top_opts = self._config_stack:get_top_options(self._filesystem)
	local combined_opts = {}
	for _, option in ipairs({"formatter", "quiet", "color", "codes", "ranges"}) do
		combined_opts[option] = top_opts[option]
		if format_opts[option] ~= nil then
			combined_opts[option] = format_opts[option]
		end
	end
	local filenames = {}
	for _, file_report in ipairs(report) do
		table.insert(filenames, file_report.filename or "<unnamed source>")
	end
	local output
	if format.builtin_formatters[combined_opts.formatter] then
		output = format.format(report, filenames, combined_opts)
	else
		local formatter_func = combined_opts.formatter
		if type(combined_opts.formatter) == "string" then
			local require_ok = false
			local err_msg
			require_ok, formatter_func = pcall(require, combined_opts.formatter)
			if not require_ok then
				err_msg = formatter_func
				formatter_func = nil
			end
			if not require_ok then
				return nil, ("Couldn't load custom formatter '%s': %s"):format(
					combined_opts.formatter, err_msg
				)
			end
		end
		local ok
		ok, output = pcall(formatter_func, report, filenames, combined_opts)
		if not ok then
			return nil, ("Couldn't run custom formatter '%s': %s"):format(
				tostring(combined_opts.formatter), output
			)
		end
	end
	if #output > 0 and output:sub(-1) ~= "\n" then
		output = output .. "\n"
	end
	return output
end

return runner