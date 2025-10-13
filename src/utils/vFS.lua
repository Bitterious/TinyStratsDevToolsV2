local vFS = {}

local MEGABYTE = 1024^2
local DEFAULT_MAX_FILE_SIZE = 2 * MEGABYTE
local DEFAULT_MAX_TOTAL_SIZE = 2 * MEGABYTE

local function new_node(id: number, name: string, data: string?)
	return {
		-- NODE DATA
		id = id,
		name = name,
		data = data,
		-- TREE DATA
		parent = nil,
		next = nil, prev = nil,
		first = nil,
	}
end

function vFS.new()
	local fs = {
		nodes = {},
		cache = { id_to_path = {}, path_to_id = {} },
		current_dir = "/",
		current_size = nil,
		max_file_size = DEFAULT_MAX_FILE_SIZE,
		max_total_size = DEFAULT_MAX_TOTAL_SIZE,
	}
	return fs
end

local function rebuild_cache_tree(fs, node, path)
	fs.cache.path_to_id[path] = node.id
	fs.cache.id_to_path[node.id] = path
	if node.first then
		local current = fs.nodes[node.first]
		while current do
			rebuild_cache_tree(fs, current, path .. "/" .. current.name)
			if not current.next then break end
			current = fs.nodes[current.next]
		end
	end
end

function vFS.to_binary_string(fs)
	local buffer = {}
	local function insert(...)
		local d = {...}
		if #d == 0 then return end
		local str
		if #d == 1 then str = d[1]
		else str = string.pack(...) end
		table.insert(buffer, str)
	end
	for _, node in fs.nodes do
		if not node then continue end
		local flags = if node.data ~= nil then 1 else 0
		table.insert(buffer, string.char(flags))

		insert("I4", node.id)
		insert("I2", #node.name)
		insert(node.name)
		insert("I4", node.parent or 0)
		insert("I4", node.prev or 0)
		insert("I4", node.next or 0)
		insert("I4", node.first or 0)

		if node.data ~= nil then
			insert("I4", #node.data)
			insert(node.data)
		end
	end
	local raw = table.concat(buffer)
	return raw
end

function vFS.from_binary_string(raw: string)
	local fs = vFS.new()
	local pos = 1
	local nodes = {}
	local function read(format, len)
		if format then
			local value = string.unpack(format, raw, pos)
			pos += string.packsize(format)
			return value
		else
			local value = raw:sub(pos, pos + len - 1)
			pos += len
			return value
		end
	end
	while pos <= #raw do
		local flags = raw:byte(pos)
		pos += 1
		local node = {
            id = read("I4"),
            name = read(nil, read("I2")),
            parent = read("I4"),
            prev = read("I4"),
            next = read("I4"),
            first = read("I4"),
            data = nil,
		}
        if node.parent == 0 then node.parent = nil end
        if node.prev == 0 then node.prev = nil end
        if node.next == 0 then node.next = nil end
        if node.first == 0 then node.first = nil end
        if flags == 1 then
            local data_len = read("I4")
            node.data = read(nil, data_len)
        end
        nodes[node.id] = node
	end
    fs.nodes = nodes
    for i, node in pairs(fs.nodes) do
        if not node.parent then
			rebuild_cache_tree(fs, node, "/" .. node.name)
        end
    end
	return fs
end
-- redirect old functions to new ones
function vFS.to_string(fs) return vFS.to_binary_string(fs) end
function vFS.from_string(raw) return vFS.from_binary_string(raw) end

local function parse_path(path: string, current_dir: string)
	local path_array = path:split("/")
	local absolute_path = "/"
	local parent_path = "/"
	local target_name = path_array[#path_array]
	local is_file = path_array[#path_array] ~= ""
	if not is_file then target_name = path_array[#path_array-1] end
	if path_array[1] ~= "" then -- absolute value aka starts with "/"
		local current_dir_array = current_dir:split("/")
		for _, v in current_dir_array do table.insert(path_array, 1, v) end
	end
	local index = 1
	while index <= #path_array do
		local accessor = path_array[index]
		if not accessor then break end
		if accessor == ".." then
			table.remove(path_array, index)
			table.remove(path_array, index-1)
			index -= 1
			continue
		elseif accessor == "." or accessor == "/" or accessor == "" then
			table.remove(path_array, index)
			continue
		end
		index += 1
	end
	for i, v in path_array do
		absolute_path ..= v
		if i ~= #path_array or not is_file then
			absolute_path ..= "/"
		else
			parent_path ..= v
		end
	end
	return absolute_path, target_name, parent_path
end

function vFS.get_path(fs, id: number)
	if fs.cache.id_to_path[id] then
		return fs.cache.id_to_path[id]
	end
	local node = fs.nodes[id]
	if not node then return nil, "invalid id" end
	local path
	if not node.parent then
		path = "/" .. node.name
	else
		path = vFS.get_path(fs, node.parent) .. "/" .. node.name
	end
	fs.cache.id_to_path[id] = path
	fs.cache.path_to_id[path] = id
	return path
end

function vFS.find_node(fs, absolute_path: string)
	if fs.cache.path_to_id[absolute_path] then
		return fs.nodes[fs.cache.path_to_id[absolute_path]]
	end
	local current = nil
	for _, v in absolute_path:split("/") do
		if v == "" then continue end
		if not current then
			for i, node in fs.nodes do
				if node.parent then continue end
				if node.name == v then
					current = node
					break
				end
			end
			if not current then return end
		else
			local search = fs.nodes[current.first]
			while search do
				if search.name == v then
					current = search
					break
				end
				if not search.next then continue end
				search = fs.nodes[search.next]
			end
			if not current then return end
		end
	end
	if current then
		fs.cache.path_to_id[absolute_path] = current.id
		fs.cache.id_to_path[current.id] = absolute_path
	end
	return current
end

function vFS.ls(fs, dir: string?)
	dir = dir or "/"
	local absolute_dir = parse_path(dir::string, fs.current_dir)
	if absolute_dir == "/" then
		local rootless = {}
		for i, node in fs.nodes do
			if not node.parent then
				table.insert(rootless, node)
			end
		end
		return rootless
	end
	local node = vFS.find_node(fs, absolute_dir)
	if not node then return false, "directory not found" end
	if node.data then return false, "path is a file" end
	local list = {}
	local search = fs.nodes[node.first]
	while search do
		table.insert(list, search)
		if not search.next then break end
		search = fs.nodes[search.next]
	end
	return list
end

function vFS.read_file(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return false, "file not found" end
	return node.data
end
function vFS.write_file(fs, path: string, data: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return false, "file not found" end
	node.data = data
	return true
end

function vFS.file_exists(fs, path: string)
	return vFS.find_node(fs, parse_path(path, fs.current_dir)) ~= nil
end

-- if the data param is nil it is a directory else it is a file
function vFS.create_object(fs, rpath: string, data: string?)
	local path, name, parentpath = parse_path(rpath, fs.current_dir)
	if vFS.find_node(fs, path) then return false, "file already exists" end
	local parent = vFS.find_node(fs, parentpath)
	local new_id = #fs.nodes + 1
	local node = new_node(new_id, name, data or "")
	if parent then
		if parent.data then return false, "parent is a file" end -- parent is a file
		node.parent = parent.id
		if not parent.first then
			parent.first = new_id
		else
			local last = fs.nodes[parent.first]
			while last.next do
				last = fs.nodes[last.next]
			end
			last.next = new_id
			node.prev = last.id
		end
	end
	fs.cache.id_to_path[new_id] = path
	fs.cache.path_to_id[path] = new_id
	fs.nodes[new_id] = node
	return node
end

function vFS.remove_object(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return false, "file not found" end
	if node.prev then
		fs.nodes[node.prev].next = node.next
	elseif node.parent then
		fs.nodes[node.parent].first = node.next
	end
	if node.next then
		fs.nodes[node.next].prev = node.prev
	end
	fs.nodes[node.id] = nil
	fs.cache.path_to_id[node.name] = nil
	fs.cache.id_to_path[node.id] = nil
	if node.first then -- this is a directory
		local current = fs.nodes[node.first]
		while current do
			vFS.remove_object(fs, vFS.get_path(fs, current.id))
			if not current.next then break end
			current = fs.nodes[current.next]
		end
	end
	return true
end

function vFS.move(fs, rpath: string, target: string)
	local path, _, _ = parse_path(rpath, fs.current_dir)
	local node = vFS.find_node(fs, path)
	if not node then return false, "file not found" end
	local tpath, tname, tparent_path = parse_path(target, fs.current_dir)
	local target_node = vFS.find_node(fs, tpath)
	if target_node then return false, "target already exists" end
	local target_parent = vFS.find_node(fs, tparent_path)
	if not target_parent then return false, "target path not found" end
	if target_parent.data then return false, "target is a file" end
	if node.parent then
		local parent = fs.nodes[node.parent]
		if parent.first == node.id then
			parent.first = node.next
		end
		if node.prev then
			fs.nodes[node.prev].next = node.next
		end
		if node.next then
			fs.nodes[node.next].prev = node.prev
		end
	end
	node.parent = target_parent.id
	node.name = tname
	if not target_parent.first then
		target_parent.first = node.id
	else
		local last = fs.nodes[target_parent.first]
		while last.next do
			last = fs.nodes[last.next]
		end
		last.next = node.id
		node.prev = last.id
	end
	fs.cache.path_to_id[tpath] = node.id
	fs.cache.id_to_path[node.id] = tpath
	return true
end

local function clone_directory(fs, node, target)
	local parent = vFS.create_object(fs, target, nil)
	local current = fs.nodes[node.first]
	while current do
		if current.data then
			vFS.create_object(fs, target .. "/" .. current.name, current.data)
		else
			clone_directory(fs, current, target .. "/" .. current.name)
		end
	end
	return parent
end

function vFS.copy(fs, source: string, target: string)
	local path, _, _ = parse_path(source, fs.current_dir)
	local node = vFS.find_node(fs, path)
	if not node then return false, "file not found" end
	local tpath, _, tparent_path = parse_path(target, fs.current_dir)
	local target_node = vFS.find_node(fs, tpath)
	if target_node then return false, "target already exists" end
	local target_parent = vFS.find_node(fs, tparent_path)
	if not target_parent then return false, "target path not found" end
	if target_parent.data then return false, "target is a file" end
	if node.data then
		return vFS.create_object(fs, target, node.data)
	else
		return clone_directory(fs, node, target)
	end
end

function vFS.get_file_size(fs, path: string)
	local data = vFS.read_file(fs, path)
	if not data then return -1 end
	return string.len(data)
end
function vFS.get_directory_size(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return -1 end
	if node.data then return -1 end
	local size = 0
	local current = fs.nodes[node.first]
	while current do
		if current.data then
			size = size + string.len(current.data)
		else
			size = size + vFS.get_directory_size(fs, vFS.get_path(fs, current.id))
		end
	end
	return size
end

function vFS.get_parent_path(fs, path: string)
	local _, _, parent_path = parse_path(path, fs.current_dir)
	return parent_path
end

function vFS.is_file(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return nil, "file not found" end
	return node.data ~= nil
end

function vFS.get_absolute_path(fs, path: string)
	local abspath, _, _ = parse_path(path, fs.current_dir)
	return abspath
end

function vFS.cd(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return nil, "target path doesn't exist" end
	if node.data then return nil, "target path is a file" end
	fs.current_dir = node.name
	return true
end

function vFS.get_id(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return false, "file not found" end
	return node.id
end

function vFS.get_file_handler(fs, path: string)
    local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
    if not node or node.data == nil then
        return nil, "cannot open " .. path .. ": No such file"
    end
    local handle = {
        node = node,
        current_position = 1,
        is_closed = false,
    }
    local handle_mt = { __index = {} }
    local function check_closed()
        if handle.is_closed then
            return nil, "attempt to use a closed file"
        end
        return true
    end
    function handle_mt.__index:read(mode: string | number)
        check_closed()
        if handle.current_position > #self.node.data then
            return nil
        end
        mode = mode or "*l"
        if type(mode) == "number" then
            local end_pos = self.current_position + mode - 1
            local data = string.sub(self.node.data, self.current_position, end_pos)
            self.current_position = end_pos + 1
            return data
        elseif type(mode) == "string" then
            local format = string.lower(string.sub(mode, 2))
            if format == "a" then
                local data = string.sub(self.node.data, self.current_position)
                self.current_position = #self.node.data + 1
                return data
            elseif format == "l" then
                local end_pos = string.find(self.node.data, "\n", self.current_position, true)
                if end_pos then
                    local line = string.sub(self.node.data, self.current_position, end_pos - 1)
                    self.current_position = end_pos + 1
                    return line
                else
                    local line = string.sub(self.node.data, self.current_position)
                    self.current_position = #self.node.data + 1
                    return line
                end
            elseif format == "L" then
                 local end_pos = string.find(self.node.data, "\n", self.current_position, true)
                 if end_pos then
                    local line = string.sub(self.node.data, self.current_position, end_pos)
                    self.current_position = end_pos + 1
                    return line
                 else
                    local line = string.sub(self.node.data, self.current_position)
                    self.current_position = #self.node.data + 1
                    return line
                 end
            elseif format == "n" then
                local _, end_pos, num_str = string.find(self.node.data, "^%s*(-?%d*%.?%d+)", self.current_position)
                if num_str then
                    self.current_position = end_pos + 1
                    return tonumber(num_str)
                end
                return nil
            end
        end
        error("bad argument #1 to 'read' (invalid option '" .. tostring(mode) .. "')")
    end
    function handle_mt.__index:write(...)
        check_closed()
        local args = {...}
        local data_to_write = table.concat(args)
        local prefix = string.sub(self.node.data, 1, self.current_position - 1)
        local suffix = string.sub(self.node.data, self.current_position + #data_to_write)
        self.node.data = prefix .. data_to_write .. suffix
        self.current_position = self.current_position + #data_to_write
        return self
    end
    function handle_mt.__index:seek(whence: string, offset: number)
        check_closed()
        whence = whence or "cur"
        offset = offset or 0
        local new_pos
        if whence == "set" then
            new_pos = 1 + offset
        elseif whence == "cur" then
            new_pos = self.current_position + offset
        elseif whence == "end" then
            new_pos = #self.node.data + 1 + offset
        else
            return nil, "invalid whence"
        end
        if new_pos < 1 then
            new_pos = 1
        elseif new_pos > #self.node.data + 1 then
            new_pos = #self.node.data + 1
        end
        self.current_position = new_pos
        return self.current_position - 1
    end
    function handle_mt.__index:lines()
        check_closed()
        return function()
            return self:read("*l")
        end
    end
    function handle_mt.__index:close()
        if self.is_closed then return nil, "file is already closed" end
        self.is_closed = true
        self.node = nil
        return true
    end
    return setmetatable(handle, handle_mt)
end

return vFS