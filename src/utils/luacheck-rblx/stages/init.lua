local utils = require(script.Parent.utils)

local stages = {}

stages.names = {
   "parse",
   "unwrap_parens",
   "linearize",
   "parse_inline_options",
   "name_functions",
   "resolve_locals",
   "detect_bad_whitespace",
   "detect_cyclomatic_complexity",
   "detect_empty_blocks",
   "detect_empty_statements",
   "detect_globals",
   "detect_reversed_fornum_loops",
   "detect_unbalanced_assignments",
   "detect_uninit_accesses",
   "detect_unreachable_code",
   "detect_unused_fields",
   "detect_unused_locals"
}

stages.modules = {}
stages.warnings = {}

for _, name in ipairs(stages.names) do
   table.insert(stages.modules, require(script:FindFirstChild(name)))
end

local base_fields = {"code", "line", "column", "end_column"}

local function register_warnings(warnings)
   for code, warning in pairs(warnings) do
      assert(not stages.warnings[code])
      assert(warning.message_format)
      assert(warning.fields)
      local full_fields = utils.concat_arrays({base_fields, warning.fields})
      stages.warnings[code] = {
         message_format = warning.message_format,
         fields = full_fields,
         fields_set = utils.array_to_set(full_fields)
      }
   end
end

register_warnings({
   ["011"] = {message_format = "{msg}", fields = {"msg", "prev_line", "prev_column", "prev_end_column"}},
   ["631"] = {message_format = "line is too long ({end_column} > {max_length})", fields = {}}
})

for _, stage_module in ipairs(stages.modules) do
   if stage_module.warnings then
      register_warnings(stage_module.warnings)
   end
end

function stages.run(chstate)
   for _, stage_module in ipairs(stages.modules) do
      stage_module.run(chstate)
   end
end

return stages