local fs = {}

local vFS = require(script.Parent.Parent.vFS)
local utils = require(script.Parent.utils)

local function ensure_dir_sep(path)
    if path:sub(-1) ~= utils.dir_sep then
        path = path .. utils.dir_sep
    end
    return path
end

function fs.split_base(path)
    if path:match("^/") then
        if path:match("^//") then
            return "//", path:sub(3)
        else
            return "/", path:sub(2)
        end
    else
        return "", path
    end
end

function fs.is_absolute(path)
    return fs.split_base(path) ~= ""
end

function fs.normalize(path)
    local base, rest = fs.split_base(path)
    rest = rest:gsub("[/\\]", utils.dir_sep)
    local parts = {}
    for part in rest:gmatch("[^"..utils.dir_sep.."]+") do
        if part ~= "." then
            if part == ".." and #parts > 0 and parts[#parts] ~= ".." then
                parts[#parts] = nil
            else
                parts[#parts + 1] = part
            end
        end
    end
    if base == "" and #parts == 0 then
        return "."
    else
        return base..table.concat(parts, utils.dir_sep)
    end
end

local function join_two_paths(base, path)
    if base == "" or fs.is_absolute(path) then
        return path
    else
        return ensure_dir_sep(base) .. path
    end
end
function fs.join(base, ...)
    local res = base
    for i = 1, select("#", ...) do
        res = join_two_paths(res, select(i, ...))
    end
    return res
end

function fs.is_subpath(path, subpath)
    local base1, rest1 = fs.split_base(path)
    local base2, rest2 = fs.split_base(subpath)
    if base1 ~= base2 then
        return false
    end
    if rest2:sub(1, #rest1) ~= rest1 then
        return false
    end
    return rest1 == rest2 or rest2:sub(#rest1 + 1, #rest1 + 1) == utils.dir_sep
end

function fs.is_dir(path)
    local node = vFS.find_node(utils.current_fs, vFS.get_absolute_path(utils.current_fs, path))
    if not node then return nil, "directory not found" end
    return node.data == nil
end
function fs.is_file(path)
    local node = vFS.find_node(utils.current_fs, vFS.get_absolute_path(utils.current_fs, path))
    if not node then return nil, "file not found" end
    return node.data ~= nil
end

function fs.find_file(path, file)
    if fs.is_absolute(file) then
        return fs.is_file(file) and path, ""
    end
    path = fs.normalize(path)
    local base, rest = fs.split_base(path)
    local rel_path = ""
    while true do
        if fs.is_file(fs.join(base..rest, file)) then
            return base..rest, rel_path
        elseif rest == "" then
            return
        end
        rest = rest:match("^(.*)"..utils.dir_sep..".*$") or ""
        rel_path = rel_path..".."..utils.dir_sep
    end
end

function fs.dir_iter(dir_path)
    local dir_items, err = vFS.ls(utils.current_fs, vFS.get_absolute_path(utils.current_fs, dir_path))
    if not err then
      return nil, "couldn't list directory: " .. utils.unprefix(err, "cannot open " .. dir_path .. ": ")
   end
    return ipairs(dir_items)
end

function fs.extract_files(dir_path, pattern)
    local res = {}
    local err_map = {}
    local function scan(dir)
        local iter, state, var = fs.dir_iter(dir)
        if not iter then
            err_map[dir] = state
            table.insert(res, dir)
            return
        end
        for path in iter, state, var do
            if path ~= "." and path ~= ".." then
                local full_path = fs.join(dir, path)
                if fs.is_dir(full_path) then
                    scan(full_path)
                elseif path:match(pattern) and fs.is_file(full_path) then
                    table.insert(res, full_path)
                end
            end
        end
    end
    scan(dir_path)
    table.sort(res)
    return res, err_map
end

local function make_absolute_dirs(dir_path)
    if fs.is_dir(dir_path) then
        return true
    end
    local upper_dir = fs.normalize(fs.join(dir_path, ".."))
    if upper_dir == dir_path then
        return nil, ("Filesystem root %s is not a directory"):format(upper_dir)
    end
    local upper_ok, upper_err = make_absolute_dirs(upper_dir)
    if not upper_ok then
        return nil, upper_err
    end
    local make_ok, make_error = vFS.create_object(utils.current_fs, dir_path, nil)
    if not make_ok then
        return nil, ("Couldn't make directory %s: %s"):format(dir_path, make_error)
    end
    return true
end

function fs.make_dirs(dir_path)
   return make_absolute_dirs(fs.normalize(fs.join(fs.get_current_dir(), dir_path)))
end

function fs.get_mtime(path)
    local dates, err = vFS.get_dates(utils.current_fs, path)
    if err then return nil, err end
    return dates.modified_at
end

function fs.get_current_dir()
   return ensure_dir_sep(assert(utils.current_fs.current_dir))
end

return fs