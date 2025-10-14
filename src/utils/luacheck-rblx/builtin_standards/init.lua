local standards = script.Parent.standards

local builtin_standards = {}

local function def_to_std(def)
	return { read_globals = def.fields }
end

local empty = {}

local string_defs = {}

string_defs.min = standards.def_fields(
	"byte",
	"char",
	"dump",
	"find",
	"format",
	"gmatch",
	"gsub",
	"len",
	"lower",
	"match",
	"rep",
	"reverse",
	"sub",
	"upper",
    "pack",
    "packsize",
    "unpack"
)

string_defs.luau = string_defs.min

local bit32_def = standards.def_fields(
	"arshift",
	"band",
	"bnot",
	"bor",
	"btest",
	"bxor",
	"extract",
	"lrotate",
	"lshift",
	"replace",
	"rrotate",
	"rshift"
)

local function make_min_def(method_defs)
	local string_def = string_defs[method_defs]
	return {
		fields = {
            bit32 = bit32_def,
			_G = { other_fields = true, read_only = false },
			_VERSION = string_def,
			arg = { other_fields = true },
			assert = empty,
			collectgarbage = empty,
			coroutine = standards.def_fields("create", "resume", "running", "status", "wrap", "yield"),
			debug = standards.def_fields(
				"debug",
				"gethook",
				"getinfo",
				"getlocal",
				"getmetatable",
				"getregistry",
				"getupvalue",
				"sethook",
				"setlocal",
				"setmetatable",
				"setupvalue",
				"traceback"
			),
			dofile = empty,
			error = empty,
			getmetatable = empty,
			ipairs = empty,
			load = empty,
			loadfile = empty,
			math = standards.def_fields(
				"abs",
				"acos",
				"asin",
				"atan",
				"ceil",
				"cos",
				"deg",
				"exp",
				"floor",
				"fmod",
				"huge",
				"log",
				"max",
				"min",
				"modf",
				"pi",
				"rad",
				"random",
				"randomseed",
				"sin",
				"sqrt",
				"tan",
                "atan2",
                "cosh",
                "frexp",
                "ldexp",
                "log10",
                "pow",
                "sinh",
                "tanh"
			),
			next = empty,
			os = standards.def_fields(
				"clock",
				"date",
				"difftime",
				"remove",
				"rename",
				"time"
			),
			pairs = empty,
			pcall = empty,
			print = empty,
			rawequal = empty,
			rawget = empty,
			rawset = empty,
            rawlen = empty,
			require = empty,
			select = empty,
			setmetatable = empty,
			string = string_def,
			table = standards.def_fields(
                "concat",
                "insert",
                "remove",
                "sort",
                "maxn",
                "pack",
                "unpack",
                "move"
            ),
			tonumber = empty,
			tostring = empty,
			type = empty,
			xpcall = empty,
            utf8 = {
                fields = {
                    char = empty,
                    charpattern = string_defs.luau,
                    codepoint = empty,
                    codes = empty,
                    len = empty,
                    offset = empty
                }
            }
		},
	}
end

local lua_defs = {}

lua_defs.min = make_min_def("min")
lua_defs.luau = make_min_def("luau")

for name, def in pairs(lua_defs) do
	builtin_standards[name] = def_to_std(def)
end

local function get_running_lua_std_name()
	return "luau"
end

builtin_standards._G = builtin_standards[get_running_lua_std_name()]

builtin_standards.luacheckrc = {
	globals = {
		"global",
		"unused",
		"redefined",
		"unused_args",
		"unused_secondaries",
		"self",
		"compat",
		"allow_defined",
		"allow_defined_top",
		"module",
		"globals",
		"read_globals",
		"new_globals",
		"new_read_globals",
		"not_globals",
		"ignore",
		"enable",
		"only",
		"std",
		"max_line_length",
		"max_code_line_length",
		"max_string_line_length",
		"max_comment_line_length",
		"max_cyclomatic_complexity",
		"quiet",
		"color",
		"codes",
		"ranges",
		"formatter",
		"cache",
		"jobs",
		"files",
		"stds",
		"exclude_files",
		"include_files",
	},
}

builtin_standards.none = {}

return builtin_standards
