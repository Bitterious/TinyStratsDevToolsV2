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

return vFS