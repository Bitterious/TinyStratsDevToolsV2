local options = {}

local builtin_standards = require(script.Parent.builtin_standards)
local standards = require(script.Parent.standards)
local utils = require(script.Parent.utils)

local boolean = utils.has_type("boolean")
local number_or_false = utils.has_type_or_false("number")
local array_of_strings = utils.array_of("string")

local function split_std(std, stds)
	local parts = utils.split(std, "+")
	if parts[1]:match("^%s*$") then
		parts.add = true
		table.remove(parts, 1)
	end
	for i, part in ipairs(parts) do
		parts[i] = utils.strip(part)

		if not stds[parts[i]] then
			return nil, ("unknown std '%s'"):format(parts[i])
		end
	end
	return parts
end

local function std_or_array_of_strings(x, stds)
	if type(x) == "string" then
		local ok, err = split_std(x, stds)
		return not not ok, err
	elseif type(x) == "table" then
		return standards.validate_std_table(x)
	else
		return false, "string or table expected, got " .. type(x)
	end
end

local function field_map(x)
	if type(x) == "table" then
		return standards.validate_globals_table(x)
	else
		return false, "table expected, got " .. type(x)
	end
end

options.nullary_inline_options = {
	global = boolean,
	unused = boolean,
	redefined = boolean,
	unused_args = boolean,
	unused_secondaries = boolean,
	self = boolean,
	compat = boolean,
	allow_defined = boolean,
	allow_defined_top = boolean,
	module = boolean,
}

options.variadic_inline_options = {
	globals = field_map,
	read_globals = field_map,
	new_globals = field_map,
	new_read_globals = field_map,
	not_globals = array_of_strings,
	ignore = array_of_strings,
	enable = array_of_strings,
	only = array_of_strings,
}

options.all_options = {
	std = std_or_array_of_strings,
	max_line_length = number_or_false,
	max_code_line_length = number_or_false,
	max_string_line_length = number_or_false,
	max_comment_line_length = number_or_false,
	max_cyclomatic_complexity = number_or_false,
}

utils.update(options.all_options, options.nullary_inline_options)
utils.update(options.all_options, options.variadic_inline_options)

function options.validate(option_set, opts, stds)
	if opts == nil then
		return true
	end
	if type(opts) ~= "table" then
		return false, "option table expected, got " .. type(opts)
	end
	stds = stds or builtin_standards
	for option, validator in utils.sorted_pairs(option_set) do
		if opts[option] ~= nil then
			local ok, err = validator(opts[option], stds)
			if not ok then
				return false, ("invalid value of option '%s': %s"):format(option, err)
			end
		end
	end
	return true
end

local function get_std_tables(opts_stack, stds)
	local base_std
	local add_stds = {}
	local no_compat = false
	for _, opts in utils.ripairs(opts_stack) do
		if opts.compat and not no_compat then
			base_std = stds.max
			break
		elseif opts.compat == false then
			no_compat = true
		end
		if opts.std then
			if type(opts.std) == "table" then
				base_std = opts.std
				break
			else
				local parts = split_std(opts.std, stds)
				for _, part in ipairs(parts) do
					table.insert(add_stds, stds[part])
				end
				if not parts.add then
					base_std = {}
					break
				end
			end
		end
	end
	table.insert(add_stds, 1, base_std or stds.max)
	return add_stds
end

local function index_of_last_option_usage(opts_stack, option_name)
	for index, opts in utils.ripairs(opts_stack) do
		if opts[option_name] then
			return index
		end
	end
	return 0
end

local function split_field(field_name)
	return utils.split(field_name, "%.")
end

local function field_comparator(field1, field2)
	local parts1 = field1[1]
	local parts2 = field2[1]
	for i = 1, math.max(#parts1, #parts2) do
		local part1 = parts1[i]
		local part2 = parts2[i]
		if not part1 then
			return true
		elseif not part2 then
			return false
		end
		if part1 ~= part2 then
			return part1 < part2
		end
	end
	return false
end

local function get_final_std(opts_stack, stds)
	local final_std = {}
	local std_tables = get_std_tables(opts_stack, stds)
	for _, std_table in ipairs(std_tables) do
		standards.add_std_table(final_std, std_table)
	end
	local last_new_globals = index_of_last_option_usage(opts_stack, "new_globals")
	local last_new_read_globals = index_of_last_option_usage(opts_stack, "new_read_globals")
	for index, opts in ipairs(opts_stack) do
		local globals = (index >= last_new_globals) and (opts.new_globals or opts.globals)
		local read_globals = (index >= last_new_read_globals) and (opts.new_read_globals or opts.read_globals)
		local new_fields = {}
		if globals then
			for _, global in ipairs(globals) do
				table.insert(new_fields, { split_field(global), false })
			end
		end
		if read_globals then
			for _, read_global in ipairs(read_globals) do
				table.insert(new_fields, { split_field(read_global), true })
			end
		end
		if globals and read_globals then
			table.sort(new_fields, field_comparator)
		end
		for _, field in ipairs(new_fields) do
			standards.overwrite_field(final_std, field[1], field[2])
		end
		standards.add_std_table(final_std, { globals = globals, read_globals = read_globals }, true, true)
		if opts.not_globals then
			for _, not_global in ipairs(opts.not_globals) do
				standards.remove_field(final_std, split_field(not_global))
			end
		end
	end
	standards.finalize(final_std)
	return final_std
end

local function get_scalar_opt(opts_stack, option, default)
	for _, opts in utils.ripairs(opts_stack) do
		if opts[option] ~= nil then
			return opts[option]
		end
	end
	return default
end

local line_length_suboptions = { "max_code_line_length", "max_string_line_length", "max_comment_line_length" }

local function get_max_line_opts(opts_stack)
	local res = { max_line_length = 120 }
	for _, opt_name in ipairs(line_length_suboptions) do
		res[opt_name] = res.max_line_length
	end
	for _, opts in ipairs(opts_stack) do
		if opts.max_line_length ~= nil then
			res.max_line_length = opts.max_line_length
			for _, opt_name in ipairs(line_length_suboptions) do
				res[opt_name] = opts.max_line_length
			end
		end
		for _, opt_name in ipairs(line_length_suboptions) do
			if opts[opt_name] ~= nil then
				res[opt_name] = opts[opt_name]
			end
		end
	end
	return res
end

local function anchor_pattern(pattern, only_start)
	if not pattern then
		return
	end
	if pattern:sub(1, 1) == "^" or pattern:sub(-1) == "$" then
		return pattern
	else
		return "^" .. pattern .. (only_start and "" or "$")
	end
end

local function normalize_pattern(pattern)
	local code_pattern, name_pattern
	local slash_pos = pattern:find("/")
	if slash_pos then
		code_pattern = pattern:sub(1, slash_pos - 1)
		name_pattern = pattern:sub(slash_pos + 1)
	elseif pattern:find("[_a-zA-Z]") then
		name_pattern = pattern
	else
		code_pattern = pattern
	end
	return { anchor_pattern(code_pattern, true), anchor_pattern(name_pattern) }
end

local macros = {
	{ "unused_args", "21[23]" },
	{ "global", "1" },
	{ "unused", "[23]" },
	{ "redefined", "4" },
}

local function get_rules(opts_stack)
	local rules = {}
	local used_macros = {}
	for _, opts in utils.ripairs(opts_stack) do
		for _, macro_info in ipairs(macros) do
			local option, pattern = macro_info[1], macro_info[2]
			if not used_macros[option] then
				if opts[option] ~= nil then
					table.insert(rules, { { pattern }, opts[option] and "enable" or "disable" })
					used_macros[option] = true
				end
			end
		end
		if opts.ignore then
			table.insert(rules, { opts.ignore, "disable" })
		end
		if opts.only then
			table.insert(rules, { opts.only, "only" })
		end
		if opts.enable then
			table.insert(rules, { opts.enable, "enable" })
		end
	end
	return rules
end

local function normalize_patterns(rules)
	local res = {}
	for i, rule in ipairs(rules) do
		res[i] = { {}, rule[2] }
		for j, pattern in ipairs(rule[1]) do
			res[i][1][j] = normalize_pattern(pattern)
		end
	end
	return res
end

local scalar_options = {
	unused_secondaries = true,
	self = true,
	module = false,
	allow_defined = false,
	allow_defined_top = false,
	max_cyclomatic_complexity = false,
}
function options.normalize(opts_stack, stds)
	local res = {}
	stds = stds or builtin_standards
	res.std = get_final_std(opts_stack, stds)
	for option, default in pairs(scalar_options) do
		res[option] = get_scalar_opt(opts_stack, option, default)
	end
	local max_line_opts = get_max_line_opts(opts_stack)
	utils.update(res, max_line_opts)
	res.rules = normalize_patterns(get_rules(opts_stack))
	return res
end

return options
