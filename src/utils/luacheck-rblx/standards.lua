local standards = {}

local function validate_fields(fields, is_root, index)
	if fields == nil then
		return true
	end
	local field_type = is_root and "global" or "field"
	if type(fields) ~= "table" then
		return false, ("%ss table expected, got %s"):format(field_type, type(fields)), index
	end
	for key, value in pairs(fields) do
		if type(key) == "string" then
			local new_index = (index or "") .. "." .. key
			if type(value) ~= "table" then
				return false, ("%s description table expected, got %s"):format(field_type, type(value)), new_index
			end
			if value.read_only ~= nil and type(value.read_only) ~= "boolean" then
				local err = "invalid value of option 'read_only': boolean expected, got " .. type(value.read_only)
				return false, err, new_index
			end
			if value.other_fields ~= nil and type(value.other_fields) ~= "boolean" then
				local err = "invalid value of option 'other_fields': boolean expected, got " .. type(value.other_fields)
				return false, err, new_index
			end
			local ok, err, err_index = validate_fields(value.fields, false, new_index .. ".fields")
			if not ok then
				return false, err, err_index
			end
		elseif type(value) ~= "string" then
			local key_as_string = type(key) == "number" and ("%.20g"):format(key) or ("<%s>"):format(type(key))
			local new_index = ("%s[%s]"):format(index or "", key_as_string)
			return false, ("string expected as %s name, got %s"):format(field_type, type(value)), new_index
		end
	end
	return true
end

function standards.validate_globals_table(globals_table)
	local ok, err, err_index = validate_fields(globals_table, true)
	if ok then
		return true
	end
	local err_prefix = err_index and ("in field %s: "):format(err_index) or ""
	return false, err_prefix .. err
end

function standards.validate_std_table(std_table)
	local ok, err, err_index = validate_fields(std_table.globals, true, ".globals")
	if ok then
		ok, err, err_index = validate_fields(std_table.read_globals, true, ".read_globals")
	end
	if ok then
		return true
	end
	local err_prefix = ("in field %s: "):format(err_index)
	return false, err_prefix .. err
end

local infinitely_indexable_def = { other_fields = true }

local function add_fields(def, fields, overwrite, ignore_array_part, default_read_only)
	if not fields then
		return
	end
	for field_name, field_def in pairs(fields) do
		if type(field_name) == "string" or not ignore_array_part then
			if type(field_name) ~= "string" then
				field_name = field_def
				field_def = infinitely_indexable_def
			end
			if not def.fields then
				def.fields = {}
			end
			if not def.fields[field_name] then
				def.fields[field_name] = {}
			end
			local existing_field_def = def.fields[field_name]
			local new_read_only = field_def.read_only
			if new_read_only == nil then
				new_read_only = default_read_only
			end
			if new_read_only ~= nil then
				if overwrite or new_read_only == false then
					existing_field_def.read_only = new_read_only
				end
			end
			if field_def.other_fields ~= nil then
				if overwrite or field_def.other_fields == true then
					existing_field_def.other_fields = field_def.other_fields
				end
			end
			add_fields(existing_field_def, field_def.fields, overwrite, false, nil)
		end
	end
end

function standards.add_std_table(final_std, std_table, overwrite, ignore_top_array_part)
	add_fields(final_std, std_table.globals, overwrite, ignore_top_array_part, false)
	add_fields(final_std, std_table.read_globals, overwrite, ignore_top_array_part, true)
end

function standards.overwrite_field(final_std, field_names, read_only)
	local field_def = final_std
	for _, field_name in ipairs(field_names) do
		if not field_def.fields then
			field_def.fields = {}
		end
		if not field_def.fields[field_name] then
			field_def.fields[field_name] = { read_only = read_only }
		end
		field_def = field_def.fields[field_name]
	end
	for key in pairs(field_def) do
		field_def[key] = nil
	end
	field_def.read_only = read_only
	field_def.other_fields = true
end

function standards.remove_field(final_std, field_names)
	local field_def = final_std
	local parent_def
	for _, field_name in ipairs(field_names) do
		parent_def = field_def
		if not field_def.fields or not field_def.fields[field_name] then
			return
		end
		field_def = field_def.fields[field_name]
	end
	if parent_def then
		parent_def.fields[field_names[#field_names]] = nil
	end
end

local function infer_deep_read_only_statuses(def, read_only)
	local deep_read_only = not def.other_fields or read_only
	if def.fields then
		for _, field_def in pairs(def.fields) do
			local field_read_only = read_only
			if field_def.read_only ~= nil then
				field_read_only = field_def.read_only
			end
			infer_deep_read_only_statuses(field_def, field_read_only)
			deep_read_only = deep_read_only and field_read_only and field_def.deep_read_only
		end
	end
	if deep_read_only then
		def.deep_read_only = true
	end
end

function standards.finalize(final_std)
	infer_deep_read_only_statuses(final_std, true)
end

local empty = {}
function standards.def_fields(...)
	local fields = {}
	for _, field in ipairs({ ... }) do
		fields[field] = empty
	end
	return { fields = fields }
end
return standards
