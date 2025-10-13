local unpack, pack = table.unpack, table.pack -- we dont need compat checks since its all gonna run on luau
local vFS = require(script.Parent.Parent.vFS)

local utils = {}

utils.dir_sep = "/"
utils.current_fs = nil

local bom = "\239\187\191"

function utils.read_file(file)
    assert(utils.current_fs, "no filesystem given for luacheck")
    local handle
    if type(file) == "string" then
        local get_err
        handle, get_err = vFS.get_file_handler(utils.current_fs, file)
        if not handle then
            get_err = utils.unprefix(get_err, file .. ": ")
            return nil, "couldn't read: " .. get_err
        end
    else handle = file end
    local res, read_err = handle:read("*a")
    handle:close()
    if not res then
      return nil, "couldn't read: " .. read_err
    end
   if res:sub(1, bom:len()) == bom then
      res = res:sub(bom:len() + 1)
   end
   return res, nil
end

function utils.load(src, env, chunkname)
    local func, err = loadstring(src, chunkname)
    if func then
        if env then
            setfenv(func, env)
        end
        return func, nil
    else
        return nil, err
    end
end

function utils.load_config(path, env)
    env = env or {}
    local src, read_err = utils.read_file(path)
    if not src then
        return nil, "I/O", read_err
    end
    local func, load_err = utils.load(src, env, "chunk")
    if not func then
        return nil, "syntax", "line " .. utils.unprefix(load_err, "[string \"chunk\"]:")
    end
    local ok, res = pcall(func)
    if not ok then
        return nil, "runtime", "line " .. utils.unprefix(res, "[string \"chunk\"]:")
    end
    return env, res
end

function utils.array_to_set(array)
    local result = {}
    for _, subarray in ipairs(array) do
        for _, item in ipairs(subarray) do
            table.insert(result, item)
        end
    end
    return result
end

function utils.update(t1, t2)
    for k, v in pairs(t2) do
        t1[k] = v
    end
    return t1
end

local class_mt = {}
function class_mt.__call(class, ...)
    local obj = setmetatable({}, class)
    if class.__init then
        local init_ret = pack(class.__init(obj, ...))
        if init_ret.n > 0 then
            return unpack(init_ret, 1, init_ret.n)
        end
    end
    return obj
end

function utils.class()
    local class = setmetatable({}, class_mt)
    class.__index = class
    return class
end
function utils.is_instance(object, class)
    return rawequal(getmetatable(object), class)
end

-- STACK CLASS
local Stack = utils.class()
utils.Stack = Stack

function Stack:__init()
    self.size = 0
end
function Stack:push(value)
    self.size += 1
    self[self.size] = value
    self.top = value
end
function Stack:pop()
    local value = self[self.size]
    self[self.size] = nil
    self.size -= 1
    self.top = self[self.size]
    return value
end

-- ERRORWRAPPER CLASS
local ErrorWrapper = utils.class()
utils.ErrorWrapper = ErrorWrapper

function ErrorWrapper:__init(err, traceback)
    self.err = err
    self.traceback = traceback
end
function ErrorWrapper:__tostring()
    return tostring(self.err) .. "\n" .. self.traceback
end

local function error_handler(err)
    if utils.is_instance(err, ErrorWrapper) then
        return err
    else
        return ErrorWrapper(err, debug.traceback())
    end
end

function utils.try(f, ...)
    local args = {...}
    local argc = #args
    local function task()
        f(unpack(args, 1, argc))
    end
    return xpcall(task, error_handler)
end

local function ripairs_iterator(array, i)
    if i == 1 then return nil
    else i -= 1; return i, array[i] end
end

function utils.ripairs(array)
    return ripairs_iterator, array, #array + 1
end

function utils.sorted_pairs(t)
    local keys = {}
    for key in pairs(t) do
        table.insert(keys, key)
    end
    table.sort(keys)
    local index = 1
    return function()
        local key = keys[index]
        if key == nil then return end
        index += 1
        return key, t[key]
    end
end

function utils.unprefix(str, prefix)
    if str:sub(1, prefix:len()) == prefix then
        return str:sub(prefix:len() + 1)
    else
        return str
    end
end

function utils.after(str, pattern)
    local _, last_matched_index = str:find(pattern)
    if last_matched_index then
        return str:sub(last_matched_index + 1)
    end
    return
end

function utils.strip(str)
    local _, last_start_place = str:find("^%s*")
    local first_end_space = str:find("%s*$")
    return str:sub(last_start_place + 1, first_end_space - 1)
end

function utils.split(str, sep)
    local parts = {}
    local pattern
    if sep then
        pattern = `{sep}([^{sep}]*)`
    else pattern = "%S+" end
    for part in str:gmatch(pattern) do
        table.insert(parts, part)
    end
    return parts
end

local InvalidPatternError = utils.class()
utils.InvalidPatternError = InvalidPatternError

function InvalidPatternError:__init(err, pattern)
    self.err = err
    self.pattern = pattern
end
function InvalidPatternError:__tostring()
    return self.err
end

function utils.pmatch(str, pattern)
    assert(type(str) == "string")
    assert(type(pattern) == "string")
    local ok, res = pcall(string.match, str, pattern)
    if not ok then
        error(utils.InvalidPatternError(res, pattern), 0)
    else
        return not not res -- actually easier than making a proper check
    end
end

function utils.map(func, array)
    local result = {}
    for i, v in ipairs(array) do
        result[i] = func(v)
    end
    return result
end

local has_type_error = "%s expected, got %s"
function utils.has_type(type_)
    return function(x)
        if type(x) == type_ then
            return true, nil
        else
            return false, has_type_error:format(type_, type(x))
        end
    end
end

local has_type_or_false_error_1 = "%s or false expected, got true"
local has_type_or_false_error_2 = "%s or false expected, got %s"
function utils.has_type_or_false(type_)
    return function(x)
        if type(x) == type_ then
            return true, nil
        elseif type(x) == "boolean" then
            if x then
                return false, has_type_or_false_error_1:format(type_)
            else
                return true, nil
            end
        else
            return false, has_type_or_false_error_2:format(type_, type(x))
        end
    end
end

local has_either_type_error = "%s or %s expected, got %s"
function utils.has_either_type(type1, type2)
    return function(x)
        if type(x) == type1 or type(x) == type2 then
            return true
        else
            return false, has_either_type_error:format(type1, type2, type(x))
        end
    end
end

local array_of_error_1 = "array of %ss expected, got %s"
local array_of_error_2 = "array of %ss expected, got %s at index [%d]"
function utils.array_of(type_)
    return function(x)
        if type(x) ~= "table" then
            return false, array_of_error_1:format(type_, type(x))
        end
        for index, item in ipairs(x) do
            if type(item) ~= type_ then
            return false, array_of_error_2:format(type_, type(item), index)
            end
        end
        return true
    end
end

return utils