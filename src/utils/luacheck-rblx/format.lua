local stages = require(script.Parent.stages)

local format = {}

local function get_message_format(warning)
	local message_format = assert(stages.warnings[warning.code], "Unkown warning code " .. warning.code).message_format
	if type(message_format) == "function" then
		return message_format(warning)
	else
		return message_format
	end
end

local function plural(number)
	return (number == 1) and "" or "s"
end

local function substitute(string_format, values)
	return (
		string_format:gsub("{([_a-zA-Z0-9]+)(!?)}", function(field_name, highlight)
            local field = assert(values[field_name], "No field " .. field_name)
			local value = tostring(field)
			if highlight == "!" then
                return "'" .. value .. "'"
			else
				return value
			end
		end)
	)
end

local function format_message(event)
	return substitute(get_message_format(event), event)
end

function format.get_message(event)
	return format_message(event)
end

local function capitalize(str)
	return str:gsub("^.", string.upper)
end

local function fatal_type(file_report)
	return capitalize(file_report.fatal) .. " error"
end

local function count_warnings_errors(events)
	local warnings, errors = 0, 0
	for _, event in ipairs(events) do
		if event.code:sub(1, 1) == "0" then
			errors = errors + 1
		else
			warnings = warnings + 1
		end
	end
	return warnings, errors
end

local function format_file_report_header(report, file_name, opts)
	local label = "Checking " .. file_name
	local status
	if report.fatal then
		status = fatal_type(report)
	elseif #report == 0 then
		status = "OK"
	else
		local warnings, errors = count_warnings_errors(report)
		if warnings > 0 then
			status = tostring(warnings) .. " warning" .. plural(warnings)
		end
		if errors > 0 then
			status = status and (status .. " / ") or ""
			status ..= tostring(errors) .. " error" .. plural(errors)
		end
	end
	return label .. (" "):rep(math.max(50 - #label, 1)) .. status
end

local function format_location(file, location, opts)
	local res = ("%s:%d:%d"):format(file, location.line, location.column)
	if opts.ranges then
		res = ("%s-%d"):format(res, location.end_column)
	end
	return res
end

local function event_code(event)
	return (event.code:sub(1, 1) == "0" and "E" or "W") .. event.code
end

local function format_event(file_name, event, opts)
	local message = format_message(event)
	if opts.codes then
		message = ("(%s) %s"):format(event_code(event), message)
	end
	return format_location(file_name, event, opts) .. ": " .. message
end

local function format_file_report(report, file_name, opts)
	local buf = { format_file_report_header(report, file_name, opts) }
	if #report > 0 then
		table.insert(buf, "")
		for _, event in ipairs(report) do
			table.insert(buf, "    " .. format_event(file_name, event, opts))
		end
		table.insert(buf, "")
	elseif report.fatal then
		table.insert(buf, "")
		table.insert(buf, "    " .. file_name .. ": " .. report.msg)
		table.insert(buf, "")
	end
	return table.concat(buf, "\n")
end

format.builtin_formatters = {}

function format.builtin_formatters.default(report, file_names, opts)
	local buf = {}
	if opts.quiet <= 2 then
		for i, file_report in ipairs(report) do
			if opts.quiet == 0 or file_report.fatal or #file_report > 0 then
				table.insert(
					buf,
					(opts.quiet == 2 and format_file_report_header or format_file_report)(
						file_report,
						file_names[i],
						opts
					)
				)
			end
		end
		if #buf > 0 and buf[#buf]:sub(-1) ~= "\n" then
			table.insert(buf, "")
		end
	end
	local total = ("Total: %s warning%s / %s error%s in %d file%s"):format(
		report.warnings,
		plural(report.warnings),
		report.errors,
		plural(report.errors),
		#report - report.fatals,
		plural(#report - report.fatals)
	)
	if report.fatals > 0 then
		total = total .. (", couldn't check %s file%s"):format(report.fatals, plural(report.fatals))
	end
	table.insert(buf, total)
	return table.concat(buf, "\n")
end

function format.builtin_formatters.TAP(report, file_names, opts)
	opts.color = false
	local buf = {}
	for i, file_report in ipairs(report) do
		if file_report.fatal then
			table.insert(buf, ("not ok %d %s: %s"):format(#buf + 1, file_names[i], fatal_type(file_report)))
		elseif #file_report == 0 then
			table.insert(buf, ("ok %d %s"):format(#buf + 1, file_names[i]))
		else
			for _, warning in ipairs(file_report) do
				table.insert(buf, ("not ok %d %s"):format(#buf + 1, format_event(file_names[i], warning, opts)))
			end
		end
	end
	table.insert(buf, 1, "1.." .. tostring(#buf))
	return table.concat(buf, "\n")
end

function format.builtin_formatters.plain(report, file_names, opts)
	opts.color = false
	local buf = {}

	for i, file_report in ipairs(report) do
		if file_report.fatal then
			table.insert(buf, ("%s: %s (%s)"):format(file_names[i], fatal_type(file_report), file_report.msg))
		else
			for _, event in ipairs(file_report) do
				table.insert(buf, format_event(file_names[i], event, opts))
			end
		end
	end

	return table.concat(buf, "\n")
end

function format.format(report, file_names, options)
	return format.builtin_formatters[options.formatter or "default"](report, file_names, {
		quiet = options.quiet or 0,
		color = false,
		codes = options.codes,
		ranges = options.ranges,
	})
end

return format
