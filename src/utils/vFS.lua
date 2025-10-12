local vFS = {}
local httpsv = game:GetService("HttpService")

local function new_node(id: number, name: string, data: string?)
	return {
		id = id,
		name = name,
		data = data,
		isfile = data ~= nil,
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
	}
	return fs
end

function vFS.to_string(fs)
	return httpsv:JSONEncode(fs.nodes)
end
function vFS.from_string(str: string)
	local fs = vFS.new()
	fs.nodes = httpsv:JSONDecode(str)
	return fs
end

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
	if not node then return end
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
	if not node then return end
	return node.data
end
function vFS.write_file(fs, path: string, data: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return end
	node.data = data
end

function vFS.file_exists(fs, path: string)
	return vFS.find_node(fs, parse_path(path, fs.current_dir)) ~= nil
end

function vFS.create_file(fs, rpath: string, data: string?)
	local path, name, parentpath = parse_path(rpath, fs.current_dir)
	if vFS.find_node(fs, path) then return end
	local parent = vFS.find_node(fs, parentpath)
	local new_id = #fs.nodes + 1
	local node = new_node(new_id, name, data or "")
	if parent then
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
	fs.nodes[new_id] = node
	return node
end
function vFS.remove_file(fs, path: string)
	--TODO: implement
end

function vFS.get_id(fs, path: string)
	local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
	if not node then return end
	return node.id
end

function vFS.get_file_handler(fs, path: string)
    local node = vFS.find_node(fs, parse_path(path, fs.current_dir))
    if not node or node.type ~= "file" then
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