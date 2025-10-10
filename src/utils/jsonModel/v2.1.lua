-- jsonModel by @bittwrious for KryWorks Game Modding API
-- jsonModel 2 by @bittwrious for TSAPI
-- The MIT License (MIT)

-- Copyright (c) 2025, bittwrious (bitter@kry.works)

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local httpservice = game:GetService("HttpService")

local function json_encode_secure(input)
    local success, result = pcall(function()
        return httpservice:JSONEncode(input)
    end)
    if not success then
        return nil, result
    end
    return result, nil
end

local function json_decode_secure(input)
    local success, result = pcall(function()
        return httpservice:JSONDecode(input)
    end)
    if not success then
        return nil, result
    end
    return result, nil
end

local jsm = {}

--[[
    Central Key Registry
    Maps descriptive property names to short keys.
]]
local keyRegistry = {
    Root = "r",
    ValueRegistry = "vr",

    -- Value Types in Registry
    Vectors = "v",
    Colors = "cl",
    Numbers = "nm",
    Strings = "st",
    CFrames = "cf",

    -- General Instance Properties
    UUID = "u",
    ClassName = "c",
    Name = "n",
    Tags = "t",
    Children = "ch",

    -- Part Properties
    CFrame = "p",
    Size = "s",
    Color = "co",
    Shape = "sh",
    Transparency = "tr", -- Also used by Decal/Texture
    Material = "mt",
    Anchored = "a",
    CollisionGroup = "cg",
    CanCollide = "cc",
    CanQuery = "cq",
    CanTouch = "ct",
    Faces = "f",

    -- Model Properties
    PrimaryPart = "pp",

    -- Joint Properties (Motor6D/Weld)
    C0 = "c0",
    C1 = "c1",
    Part0 = "p0",
    Part1 = "p1",

    -- Decal/Texture Properties
    TextureId = "tx",
    TintColor = "tn",   -- for the Color3 property
    Shiny = "sy",       -- Decal specific
    Specular = "sp",    -- Decal specific
    ZIndex = "zi",
    Face = "fa",
    StudsPerTileU = "psu",
    StudsPerTileV = "psv",
    OffsetStudsU = "osu",
    OffsetStudsV = "osv",

    -- Face Name Keys
    Top = "tp",
    Bottom = "b",
    Left = "l",
    Right = "ri",
    Front = "fr",
    Back = "ba",

    -- Emitter Properties
    LightEmission = "le",
    LightInfluence = "li",
    Orientation = "or",
    Squash = "sq",
    Texture = "txa",
    ZOffset = "zo",
    EmissionDirection = "ed",
    Enabled = "en",
    Lifetime = "lt",
    Rate = "rt",
    Rotation = "ro",
    RotSpeed = "rs",
    Speed = "spd",
    SpreadAngle = "san",
    ShapeInOut = "shio",
    ShapeStyle = "shs",
    FlipbookLayout = "fbl",
    FlipbookFramerate = "fbr",
    FlipbookMode = "fbm",
    FlipbookStartRandom = "fbsr",
    Acceleration = "acc",
    Drag = "drg",
    LockedToPart = "ltp",
    TimeScale = "ts",
    VelocityInheritance = "vi",
    WindAffectsDrag = "wad",

    -- Fire properties
    SecondaryColor = "scc",
    Heat = "ht",

    -- Smoke properties
    Opacity = "opc",
    RiseVelocity = "rvl",

    -- Sparkle properties
    SparkleColor = "spkcl",

    -- Sky properties
    SkyboxBk = "skb",
    SkyboxDn = "skd",
    SkyboxFt = "skf",
    SkyboxLf = "skl",
    SkyboxRt = "skr",
    SkyboxUp = "sku",
    SkyboxOrientation = "sko",
    CelestialBodiesShown = "cbs",
    StarCount = "stc",
    MoonTextureId = "mti",
    SunTextureId = "sti",
    MoonAngularSize = "mas",
    SunAngularSize = "sas",
}

-- Create a reverse mapping for deserialization
local reverseKeyRegistry = {}
for key, value in pairs(keyRegistry) do
    if reverseKeyRegistry[value] then
        warn(`property key redefined. {reverseKeyRegistry[value]} and {key} collision`)
    end
    reverseKeyRegistry[value] = key
end

-- Data Conversion Utilities
local function cframe_to_array(orig:CFrame)
    local rx, ry, rz = orig:ToEulerAngles(Enum.RotationOrder.XYZ)
    return {orig.X, orig.Y, orig.Z, rx, ry, rz}
end
local function array_to_cframe(arr): CFrame
    local angle = CFrame.fromEulerAnglesXYZ(arr[4], arr[5], arr[6])
    return CFrame.new(arr[1], arr[2], arr[3]) * angle
end

local function color3_to_array(color:Color3)
    return {math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)}
end
local function array_to_color3(arr): Color3
    return Color3.fromRGB(arr[1], arr[2], arr[3])
end

local function vector3_to_array(vec3:Vector3)
    return {vec3.X, vec3.Y, vec3.Z}
end
local function array_to_vector3(arr): Vector3
    return Vector3.new(arr[1], arr[2], arr[3])
end

local function vector2_to_array(vec2:Vector2)
    return {vec2.X, vec2.Y}
end
local function array_to_vector2(arr): Vector2
    return Vector2.new(arr[1], arr[2])
end

local function numbersequence_to_array(ns: NumberSequence)
    local d = {}
    for _, v in ns.Keypoints do
        table.insert(d, {v.Time, v.Envelope, v.Value})
    end
    return d
end
local function array_to_numbersequence(arr): NumberSequence
    local kp = {}
    for _, v in ipairs(arr) do
        table.insert(kp, NumberSequenceKeypoint.new(v[1], v[3], v[2]))
    end
    return NumberSequence.new(kp)
end

local function numberrange_to_array(nr: NumberRange)
    return {nr.Min, nr.Max}
end
local function array_to_numberrange(arr): NumberRange
    return NumberRange.new(arr[1], arr[2])
end


-- Enum Mappings for space saving
local enum_maps = {
    class = {
        ["Part"] = 1,
        ["Folder"] = 2,
        ["Model"] = 3,
        ["Motor6D"] = 4,
        ["Weld"] = 5,
        ["Decal"] = 6,
        ["Texture"] = 7,
        ["ParticleEmitter"] = 8,
        ["Fire"] = 9,
        ["Smoke"] = 10,
        ["Sparkles"] = 11,
    },
    material = {},
    part_shape = {},
    surface_type = {},
    normal_id = { ["Top"] = 1, ["Bottom"] = 2, ["Left"] = 3, ["Right"] = 4, ["Front"] = 5, ["Back"] = 6 }
}

local function enum_to_id(enum: Enum, map)
    for i, x in enum:GetEnumItems() do
        map[x.Name] = i
    end
end
enum_to_id(Enum.Material, enum_maps.material)
enum_to_id(Enum.PartType, enum_maps.part_shape)
enum_to_id(Enum.SurfaceType, enum_maps.surface_type)

-- Reverse Enum Mappings
local reverse_enum_maps = { class = {}, material = {}, part_shape = {}, surface_type = {}, normal_id = {} }
for name, map in pairs(enum_maps) do
    for key, value in pairs(map) do
        reverse_enum_maps[name][value] = key
    end
end

local function create_value_registry()
    return {
        [keyRegistry.Vectors] = {},
        [keyRegistry.Colors] = {},
        [keyRegistry.Numbers] = {},
        [keyRegistry.Strings] = {},
        [keyRegistry.CFrames] = {},
        _vectorMap = {},
        _colorMap = {},
        _numberMap = {},
        _stringMap = {},
        _cframeMap = {},
    }
end

local function register_value(registry, valueTypeKey, value, conversionFunc)
    local map, list
    if valueTypeKey == keyRegistry.Vectors then
        map = registry._vectorMap
        list = registry[keyRegistry.Vectors]
    elseif valueTypeKey == keyRegistry.Colors then
        map = registry._colorMap
        list = registry[keyRegistry.Colors]
    elseif valueTypeKey == keyRegistry.Numbers then
        map = registry._numberMap
        list = registry[keyRegistry.Numbers]
    elseif valueTypeKey == keyRegistry.Strings then
        map = registry._stringMap
        list = registry[keyRegistry.Strings]
    elseif valueTypeKey == keyRegistry.CFrames then
        map = registry._cframeMap
        list = registry[keyRegistry.CFrames]
    else
        return nil
    end

    local key = tostring(value)
    if map[key] then
        return map[key]
    end

    local index = #list + 1
    map[key] = index
    if conversionFunc then
        list[index] = conversionFunc(value)
    else
        list[index] = value
    end
    return index
end

local instance_parsers = {}

function instance_parsers.parse_children(inst: Instance, children_table, reftable, valRegistry)
    for _, child in inst:GetChildren() do
        local class_name = child.ClassName
        local parser = instance_parsers[class_name:lower() .. "_to_table"]
        if parser then
            table.insert(children_table, parser(reftable, valRegistry, child))
        else
            warn(`Skipped instance {child:GetFullName()} because its not a supported class ({class_name}).`)
        end
    end
end

function instance_parsers.sky_to_table(reftable, valRegistry, sky: Sky)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[sky]),
        [keyRegistry.ClassName] = enum_maps.class[sky.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, sky.Name),
        [keyRegistry.Tags] = sky:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.SkyboxBk] = if sky.SkyboxBk ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxBk) else nil,
        [keyRegistry.SkyboxDn] = if sky.SkyboxDn ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxDn) else nil,
        [keyRegistry.SkyboxFt] = if sky.SkyboxFt ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxFt) else nil,
        [keyRegistry.SkyboxLf] = if sky.SkyboxLf ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxLf) else nil,
        [keyRegistry.SkyboxRt] = if sky.SkyboxRt ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxRt) else nil,
        [keyRegistry.SkyboxUp] = if sky.SkyboxUp ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SkyboxUp) else nil,
        [keyRegistry.SkyboxOrientation] = if sky.SkyboxOrientation ~= Vector3.zero then register_value(valRegistry, keyRegistry.Vectors, sky.SkyboxOrientation, cframe_to_array) else nil,
        [keyRegistry.CelestialBodiesShown] = if not sky.CelestialBodiesShown then false else nil,
        [keyRegistry.StarCount] = if sky.StarCount ~= 1000 then register_value(valRegistry, keyRegistry.Numbers, sky.StarCount) else nil,
        [keyRegistry.MoonTextureId] = if sky.MoonTextureId ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.MoonTextureId) else nil,
        [keyRegistry.SunTextureId] = if sky.SunTextureId ~= "" then register_value(valRegistry, keyRegistry.Strings, sky.SunTextureId) else nil,
        [keyRegistry.MoonAngularSize] = if sky.MoonAngularSize ~= 2 then register_value(valRegistry, keyRegistry.Numbers, sky.MoonAngularSize) else nil,
        [keyRegistry.SunAngularSize] = if sky.SunAngularSize ~= 2 then register_value(valRegistry, keyRegistry.Numbers, sky.SunAngularSize) else nil,
    }
    local children_table = {}
    instance_parsers.parse_children(sky, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.motor6d_to_table(reftable, valRegistry, motor: Motor6D|Weld)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[motor]),
        [keyRegistry.ClassName] = enum_maps.class[motor.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, motor.Name),
        [keyRegistry.Tags] = motor:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.C0] = register_value(valRegistry, keyRegistry.CFrames, motor.C0, cframe_to_array),
        [keyRegistry.C1] = register_value(valRegistry, keyRegistry.CFrames, motor.C1, cframe_to_array),
        [keyRegistry.Part0] = register_value(valRegistry, keyRegistry.Strings, reftable[motor.Part0]),
        [keyRegistry.Part1] = register_value(valRegistry, keyRegistry.Strings, reftable[motor.Part1]),
    }
    local children_table = {}
    instance_parsers.parse_children(motor, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.weld_to_table(reftable, valRegistry, weld: Weld)
    return instance_parsers.motor6d_to_table(reftable, valRegistry, weld)
end

function instance_parsers.particleemitter_to_table(reftable, valRegistry, emitter: ParticleEmitter)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[emitter]),
        [keyRegistry.ClassName] = enum_maps.class[emitter.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, emitter.Name),
        [keyRegistry.Tags] = emitter:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.LightEmission] = emitter.LightEmission,
        [keyRegistry.LightInfluence] = emitter.LightInfluence,
        [keyRegistry.Orientation] = emitter.Orientation.Name,
        [keyRegistry.Size] = numbersequence_to_array(emitter.Size),
        [keyRegistry.Squash] = numbersequence_to_array(emitter.Squash),
        [keyRegistry.Texture] = emitter.Texture,
        [keyRegistry.ZOffset] = emitter.ZOffset,
        [keyRegistry.EmissionDirection] = emitter.EmissionDirection.Name,
        [keyRegistry.Enabled] = emitter.Enabled,
        [keyRegistry.Lifetime] = numberrange_to_array(emitter.Lifetime),
        [keyRegistry.Rate] = emitter.Rate,
        [keyRegistry.Rotation] = numberrange_to_array(emitter.Rotation),
        [keyRegistry.RotSpeed] = numberrange_to_array(emitter.RotSpeed),
        [keyRegistry.Speed] = numberrange_to_array(emitter.Speed),
        [keyRegistry.SpreadAngle] = vector2_to_array(emitter.SpreadAngle),
        [keyRegistry.Shape] = emitter.Shape.Name,
        [keyRegistry.ShapeInOut] = emitter.ShapeInOut.Name,
        [keyRegistry.ShapeStyle] = emitter.ShapeStyle.Name,
        [keyRegistry.FlipbookLayout] = emitter.FlipbookLayout.Name,
        [keyRegistry.FlipbookFramerate] = numberrange_to_array(emitter.FlipbookFramerate),
        [keyRegistry.FlipbookMode] = emitter.FlipbookMode.Name,
        [keyRegistry.FlipbookStartRandom] = emitter.FlipbookStartRandom,
        [keyRegistry.Acceleration] = vector3_to_array(emitter.Acceleration),
        [keyRegistry.Drag] = emitter.Drag,
        [keyRegistry.LockedToPart] = emitter.LockedToPart,
        [keyRegistry.TimeScale] = emitter.TimeScale,
        [keyRegistry.VelocityInheritance] = emitter.VelocityInheritance,
        [keyRegistry.WindAffectsDrag] = emitter.WindAffectsDrag,
    }
    local children_table = {}
    instance_parsers.parse_children(emitter, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.fire_to_table(reftable, valRegistry, fire: Fire)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[fire]),
        [keyRegistry.ClassName] = enum_maps.class[fire.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, fire.Name),
        [keyRegistry.Tags] = fire:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.Color] = color3_to_array(fire.Color),
        [keyRegistry.SecondaryColor] = color3_to_array(fire.SecondaryColor),
        [keyRegistry.Heat] = fire.Heat,
        [keyRegistry.TimeScale] = fire.TimeScale,
        [keyRegistry.Enabled] = fire.Enabled,
    }
    local children_table = {}
    instance_parsers.parse_children(fire, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.smoke_to_table(reftable, valRegistry, smoke: Smoke)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[smoke]),
        [keyRegistry.ClassName] = enum_maps.class[smoke.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, smoke.Name),
        [keyRegistry.Tags] = smoke:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.Color] = color3_to_array(smoke.Color),
        [keyRegistry.Opacity] = smoke.Opacity,
        [keyRegistry.RiseVelocity] = smoke.RiseVelocity,
        [keyRegistry.TimeScale] = smoke.TimeScale,
        [keyRegistry.Enabled] = smoke.Enabled,
    }
    local children_table = {}
    instance_parsers.parse_children(smoke, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.sparkles_to_table(reftable, valRegistry, sparkles: Sparkles)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[sparkles]),
        [keyRegistry.ClassName] = enum_maps.class[sparkles.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, sparkles.Name),
        [keyRegistry.Tags] = sparkles:GetTags(), -- Tags are arrays of strings, harder to deduplicate efficiently
        [keyRegistry.SparkleColor] = color3_to_array(sparkles.SparkleColor),
        [keyRegistry.TimeScale] = sparkles.TimeScale,
        [keyRegistry.Enabled] = sparkles.Enabled,
    }
    local children_table = {}
    instance_parsers.parse_children(sparkles, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.folder_to_table(reftable, valRegistry, folder: Folder|Model)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[folder]),
        [keyRegistry.ClassName] = enum_maps.class[folder.ClassName],
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, folder.Name),
        [keyRegistry.Tags] = folder:GetTags(),
    }
    if folder:IsA("Model") and folder.PrimaryPart then
        data[keyRegistry.PrimaryPart] = register_value(valRegistry, keyRegistry.Strings, reftable[folder.PrimaryPart])
    end
    local children_table = {}
    instance_parsers.parse_children(folder, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.model_to_table(reftable, valRegistry, model: Model)
    return instance_parsers.folder_to_table(reftable, valRegistry, model)
end

function instance_parsers.part_to_table(reftable, valRegistry, part: Part)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[part]),
        [keyRegistry.ClassName] = enum_maps.class.Part,
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, part.Name),
        [keyRegistry.Tags] = (function() local tags = part:GetTags(); if #tags > 0 then return tags else return nil end end)(),
        [keyRegistry.CFrame] = register_value(valRegistry, keyRegistry.CFrames, part.CFrame, cframe_to_array),
        [keyRegistry.Size] = register_value(valRegistry, keyRegistry.Vectors, part.Size, vector3_to_array),
        [keyRegistry.Color] = register_value(valRegistry, keyRegistry.Colors, part.Color, color3_to_array),
        [keyRegistry.Shape] = enum_maps.part_shape[part.Shape.Name] or 1,
        [keyRegistry.Transparency] = if part.Transparency ~= 0 then register_value(valRegistry, keyRegistry.Numbers, part.Transparency) else nil,
        [keyRegistry.Material] = if part.Material.Name ~= "Plastic" then enum_maps.material[part.Material.Name] else nil,
        [keyRegistry.Anchored] = if part.Anchored then true else nil,
        [keyRegistry.CollisionGroup] = if part.CollisionGroup ~= "Default" then register_value(valRegistry, keyRegistry.Strings, part.CollisionGroup) else nil,
        [keyRegistry.CanCollide] = if not part.CanCollide then false else nil,
        [keyRegistry.CanQuery] = if not part.CanQuery then false else nil,
        [keyRegistry.CanTouch] = if not part.CanTouch then false else nil,
        [keyRegistry.Faces] = (function()
            local faces = {}
            if part.TopSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Top] = enum_maps.surface_type[part.TopSurface.Name] end
            if part.BottomSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Bottom] = enum_maps.surface_type[part.BottomSurface.Name] end
            if part.LeftSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Left] = enum_maps.surface_type[part.LeftSurface.Name] end
            if part.RightSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Right] = enum_maps.surface_type[part.RightSurface.Name] end
            if part.FrontSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Front] = enum_maps.surface_type[part.FrontSurface.Name] end
            if part.BackSurface ~= Enum.SurfaceType.Smooth then faces[keyRegistry.Back] = enum_maps.surface_type[part.BackSurface.Name] end
            if next(faces) then return faces end
            return nil
        end)()
    }
    local children_table = {}
    instance_parsers.parse_children(part, children_table, reftable, valRegistry)
    if #children_table > 0 then
        data[keyRegistry.Children] = children_table
    end
    return data
end

function instance_parsers.decal_to_table(reftable, valRegistry, decal: Decal)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[decal]),
        [keyRegistry.ClassName] = enum_maps.class.Decal,
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, decal.Name),
        [keyRegistry.Tags] = (function() local tags = decal:GetTags(); if #tags > 0 then return tags else return nil end end)(),
        [keyRegistry.TextureId] = if decal.Texture ~= "" then register_value(valRegistry, keyRegistry.Strings, decal.Texture) else nil,
        [keyRegistry.Face] = if decal.Face.Name ~= "Front" then enum_maps.normal_id[decal.Face.Name] else nil,
        [keyRegistry.ZIndex] = if decal.ZIndex ~= 1 then register_value(valRegistry, keyRegistry.Numbers, decal.ZIndex) else nil,
        [keyRegistry.TintColor] = if decal.Color3 ~= Color3.new(1, 1, 1) then register_value(valRegistry, keyRegistry.Colors, decal.Color3, color3_to_array) else nil,
        [keyRegistry.Transparency] = if decal.Transparency ~= 0 then register_value(valRegistry, keyRegistry.Numbers, decal.Transparency) else nil,
    }
    return data
end

function instance_parsers.texture_to_table(reftable, valRegistry, texture: Texture)
    local data = {
        [keyRegistry.UUID] = register_value(valRegistry, keyRegistry.Strings, reftable[texture]),
        [keyRegistry.ClassName] = enum_maps.class.Texture,
        [keyRegistry.Name] = register_value(valRegistry, keyRegistry.Strings, texture.Name),
        [keyRegistry.Tags] = (function() local tags = texture:GetTags(); if #tags > 0 then return tags else return nil end end)(),
        [keyRegistry.TextureId] = if texture.Texture ~= "" then register_value(valRegistry, keyRegistry.Strings, texture.Texture) else nil,
        [keyRegistry.Face] = if texture.Face.Name ~= "Front" then enum_maps.normal_id[texture.Face.Name] else nil,
        [keyRegistry.ZIndex] = if texture.ZIndex ~= 1 then register_value(valRegistry, keyRegistry.Numbers, texture.ZIndex) else nil,
        [keyRegistry.StudsPerTileU] = if texture.StudsPerTileU ~= 10 then register_value(valRegistry, keyRegistry.Numbers, texture.StudsPerTileU) else nil,
        [keyRegistry.StudsPerTileV] = if texture.StudsPerTileV ~= 10 then register_value(valRegistry, keyRegistry.Numbers, texture.StudsPerTileV) else nil,
        [keyRegistry.OffsetStudsU] = if texture.OffsetStudsU ~= 0 then register_value(valRegistry, keyRegistry.Numbers, texture.OffsetStudsU) else nil,
        [keyRegistry.OffsetStudsV] = if texture.OffsetStudsV ~= 0 then register_value(valRegistry, keyRegistry.Numbers, texture.OffsetStudsV) else nil,
        [keyRegistry.TintColor] = if texture.Color3 ~= Color3.new(1, 1, 1) then register_value(valRegistry, keyRegistry.Colors, texture.Color3, color3_to_array) else nil,
        [keyRegistry.Transparency] = if texture.Transparency ~= 0 then register_value(valRegistry, keyRegistry.Numbers, texture.Transparency) else nil,
    }
    return data
end


function jsm.to_json(model:Instance)
    local reftable = {}
    for _, desc in model:GetDescendants() do
        reftable[desc] = httpservice:GenerateGUID(false)
    end
    reftable[model] = httpservice:GenerateGUID(false)

    local valRegistry = create_value_registry()
    
    local parser = instance_parsers[model.ClassName:lower() .. "_to_table"]
    if not parser then
        warn("Root instance type is not supported: " .. model.ClassName)
        return nil, "Unsupported root instance type"
    end

    local rootData = parser(reftable, valRegistry, model)
    
    -- Clean up temporary maps before encoding
    valRegistry._vectorMap = nil
    valRegistry._colorMap = nil
    valRegistry._numberMap = nil
    valRegistry._stringMap = nil
    valRegistry._cframeMap = nil

    local final_data = {
        [keyRegistry.ValueRegistry] = valRegistry,
        [keyRegistry.Root] = rootData
    }

    return json_encode_secure(final_data)
end

function jsm.from_json(jsonstring)
    local full_data, err = json_decode_secure(jsonstring)
    if not full_data then return nil, err end

    local valRegistry = full_data[keyRegistry.ValueRegistry]
    local data = full_data[keyRegistry.Root]
    local rootclass = reverse_enum_maps.class[data[keyRegistry.ClassName]]
    if not rootclass then return nil, "invalid root class" end
    local function V(valueTypeKey, index)
        if not index then return nil end
        return valRegistry[valueTypeKey][index]
    end

    local reftable = {}
    local deferred = {}

    local function build(node, par, defer)
        local class_name = reverse_enum_maps.class[node[keyRegistry.ClassName]]
        local inst
        
        -- Helper to get value from registry

        local uuid = V(keyRegistry.Strings, node[keyRegistry.UUID])
        local name = V(keyRegistry.Strings, node[keyRegistry.Name])

        if class_name == "Part" then
            inst = Instance.new("Part")
            inst.Name = name
            inst.CFrame = array_to_cframe(V(keyRegistry.CFrames, node[keyRegistry.CFrame]))
            inst.Size = array_to_vector3(V(keyRegistry.Vectors, node[keyRegistry.Size]))
            inst.Color = array_to_color3(V(keyRegistry.Colors, node[keyRegistry.Color]))
            inst.Transparency = V(keyRegistry.Numbers, node[keyRegistry.Transparency]) or 0
            inst.Anchored = node[keyRegistry.Anchored] or false
            inst.CollisionGroup = V(keyRegistry.Strings, node[keyRegistry.CollisionGroup]) or "Default"
            inst.CanCollide = node[keyRegistry.CanCollide] ~= false
            inst.CanQuery = node[keyRegistry.CanQuery] ~= false
            inst.CanTouch = node[keyRegistry.CanTouch] ~= false
            inst.Shape = Enum.PartType[reverse_enum_maps.part_shape[node[keyRegistry.Shape]] or "Block"]
            local material_id = node[keyRegistry.Material] or 1
            inst.Material = Enum.Material[reverse_enum_maps.material[material_id]]
            inst.TopSurface = Enum.SurfaceType.Smooth
            inst.BottomSurface = Enum.SurfaceType.Smooth
            if node[keyRegistry.Faces] then
                for facename_key, facetype_val in pairs(node[keyRegistry.Faces]) do
                    local surface_property_name = reverseKeyRegistry[facename_key] .. "Surface"
                    local surface_type_name = reverse_enum_maps.surface_type[facetype_val]
                    if surface_type_name then
                        inst[surface_property_name] = Enum.SurfaceType[surface_type_name]
                    end
                end
            end
        elseif class_name == "Folder" or class_name == "Model" then
            inst = Instance.new(class_name)
            inst.Name = name
        elseif class_name == "Motor6D" or class_name == "Weld" then
            table.insert(defer, { data = node, parent = par })
            return
        elseif class_name == "Decal" or class_name == "Texture" then
            inst = Instance.new(class_name)
            inst.Name = name

            -- Common Texture/Decal properties
            inst.Texture = V(keyRegistry.Strings, node[keyRegistry.TextureId]) or ""
            local faceName = reverse_enum_maps.normal_id[node[keyRegistry.Face]] or "Front"
            inst.Face = Enum.NormalId[faceName]
            inst.ZIndex = V(keyRegistry.Numbers, node[keyRegistry.ZIndex]) or 1
            
            -- Appearance properties (Color3 tint and Transparency)
            local tintColorArr = V(keyRegistry.Colors, node[keyRegistry.TintColor])
            inst.Color3 = if tintColorArr then array_to_color3(tintColorArr) else Color3.new(1, 1, 1)
            inst.Transparency = V(keyRegistry.Numbers, node[keyRegistry.Transparency]) or 0

            if class_name == "Texture" then
                -- Texture-specific properties
                inst.StudsPerTileU = V(keyRegistry.Numbers, node[keyRegistry.StudsPerTileU]) or 10
                inst.StudsPerTileV = V(keyRegistry.Numbers, node[keyRegistry.StudsPerTileV]) or 10
                inst.OffsetStudsU = V(keyRegistry.Numbers, node[keyRegistry.OffsetStudsU]) or 0
                inst.OffsetStudsV = V(keyRegistry.Numbers, node[keyRegistry.OffsetStudsV]) or 0
            end
        elseif class_name == "ParticleEmitter" then
            inst = Instance.new(class_name)
            inst.Name = name
            inst.LightEmission = node[keyRegistry.LightEmission] or 1
            inst.LightInfluence = node[keyRegistry.LightInfluence] or 1
            inst.Orientation = Enum.ParticleOrientation[node[keyRegistry.Orientation]]
            inst.Size = array_to_numbersequence(node[keyRegistry.Size])
            inst.Squash = array_to_numbersequence(node[keyRegistry.Squash])
            inst.Texture = node[keyRegistry.Texture] or ""
            inst.ZOffset = node[keyRegistry.ZOffset] or 0
            inst.EmissionDirection = Enum.NormalId[node[keyRegistry.EmissionDirection]]
            inst.Enabled = node[keyRegistry.Enabled] ~= false
            inst.Lifetime = array_to_numberrange(node[keyRegistry.Lifetime])
            inst.Rate = node[keyRegistry.Rate] or 1
            inst.Rotation = array_to_numberrange(node[keyRegistry.Rotation])
            inst.RotSpeed = array_to_numberrange(node[keyRegistry.RotSpeed])
            inst.Speed = array_to_numberrange(node[keyRegistry.Speed])
            inst.SpreadAngle = array_to_vector2(node[keyRegistry.SpreadAngle])
            inst.Shape = Enum.ParticleEmitterShape[node[keyRegistry.Shape]]
            inst.ShapeInOut = Enum.ParticleEmitterShapeInOut[node[keyRegistry.ShapeInOut]]
            inst.ShapeStyle = Enum.ParticleEmitterShapeStyle[node[keyRegistry.ShapeStyle]]
            inst.FlipbookLayout = Enum.ParticleFlipbookLayout[node[keyRegistry.FlipbookLayout]]
            inst.FlipbookFramerate = array_to_numberrange(node[keyRegistry.FlipbookFramerate])
            inst.FlipbookMode = Enum.ParticleFlipbookMode[node[keyRegistry.FlipbookMode]]
            inst.FlipbookStartRandom = node[keyRegistry.FlipbookStartRandom] or 0
            inst.Acceleration = array_to_vector3(node[keyRegistry.Acceleration])
            inst.Drag = node[keyRegistry.Drag] or 0
            inst.LockedToPart = node[keyRegistry.LockedToPart] or false
            inst.TimeScale = node[keyRegistry.TimeScale] or 1
            inst.VelocityInheritance = node[keyRegistry.VelocityInheritance] or false
            inst.WindAffectsDrag = node[keyRegistry.WindAffectsDrag] or false
        elseif class_name == "Fire" then
            inst = Instance.new(class_name)
            inst.Name = name
            inst.Color = array_to_color3(node[keyRegistry.Color])
            inst.SecondaryColor = array_to_color3(node[keyRegistry.SecondaryColor])
            inst.Heat = node[keyRegistry.Heat] or 9
            inst.TimeScale = node[keyRegistry.TimeScale] or 1
            inst.Enabled = node[keyRegistry.Enabled]
        elseif class_name == "Smoke" then
            inst = Instance.new(class_name)
            inst.Name = name
            inst.Color = array_to_color3(node[keyRegistry.Color])
            inst.Opacity = node[keyRegistry.Opacity] or 1
            inst.RiseVelocity = node[keyRegistry.RiseVelocity] or 0
            inst.TimeScale = node[keyRegistry.TimeScale] or 1
            inst.Enabled = node[keyRegistry.Enabled]
        elseif class_name == "Sparkles" then
            inst = Instance.new(class_name)
            inst.Name = name
            inst.SparkleColor = array_to_color3(node[keyRegistry.SparkleColor])
            inst.TimeScale = node[keyRegistry.TimeScale] or 1
            inst.Enabled = node[keyRegistry.Enabled]
        elseif class_name == "Sky" then
            inst = Instance.new(class_name)
            inst.Name = name
            inst.SkyboxBk = V(keyRegistry.Strings, node[keyRegistry.SkyboxBk]) or ""
            inst.SkyboxDn = V(keyRegistry.Strings, node[keyRegistry.SkyboxDn]) or ""
            inst.SkyboxFt = V(keyRegistry.Strings, node[keyRegistry.SkyboxFt]) or ""
            inst.SkyboxLf = V(keyRegistry.Strings, node[keyRegistry.SkyboxLf]) or ""
            inst.SkyboxRt = V(keyRegistry.Strings, node[keyRegistry.SkyboxRt]) or ""
            inst.SkyboxUp = V(keyRegistry.Strings, node[keyRegistry.SkyboxUp]) or ""
            inst.SkyboxOrientation = if node[keyRegistry.SkyboxOrientation] then array_to_vector3(node[keyRegistry.SkyboxOrientation]) else Vector3.new(0, 0, 0)
            inst.CelestialBodiesShown = if node[keyRegistry.CelestialBodiesShown] == false then false else true
            inst.StarCount = node[keyRegistry.StarCount] or 1000
            inst.MoonTextureId = V(keyRegistry.Strings, node[keyRegistry.MoonTextureId]) or ""
            inst.SunTextureId = V(keyRegistry.Strings, node[keyRegistry.SunTextureId]) or ""
            inst.MoonAngularSize = node[keyRegistry.MoonAngularSize] or 2
            inst.SunAngularSize = node[keyRegistry.SunAngularSize] or 2
        else
            warn(`Skipped building instance for unknown class: {class_name}`)
            return
        end
        
        if node[keyRegistry.Tags] then
            for _, tag in ipairs(node[keyRegistry.Tags]) do
                inst:AddTag(tag)
            end
        end
        reftable[uuid] = inst
        inst.Parent = par
        
        if node[keyRegistry.Children] then
            for _, child in ipairs(node[keyRegistry.Children]) do
                build(child, inst, defer)
            end
        end
        
        if inst:IsA("Model") and node[keyRegistry.PrimaryPart] then
                table.insert(defer, { data = node, parent = par, isModelSetup = true })
        end
    end

    build(data, nil, deferred)

    -- Process deferred items
    local remaining_deferred = deferred
    for i = 1, 100 do
        if not remaining_deferred or #remaining_deferred == 0 then break end
        local next_deferred = {}
        for _, item in ipairs(remaining_deferred) do
            local d = item.data
            local inst = reftable[V(keyRegistry.Strings, d[keyRegistry.UUID])]
            
            if item.isModelSetup then
                    local pp_uuid = V(keyRegistry.Strings, d[keyRegistry.PrimaryPart])
                    if reftable[pp_uuid] then
                        inst.PrimaryPart = reftable[pp_uuid]
                    else
                        table.insert(next_deferred, item)
                    end
            else
                local class_name = reverse_enum_maps.class[d[keyRegistry.ClassName]]
                local p0_uuid = V(keyRegistry.Strings, d[keyRegistry.Part0])
                local p1_uuid = V(keyRegistry.Strings, d[keyRegistry.Part1])

                if reftable[p0_uuid] and reftable[p1_uuid] then
                    local joint = Instance.new(class_name)
                    joint.Name = V(keyRegistry.Strings, d[keyRegistry.Name])
                    joint.C0 = array_to_cframe(V(keyRegistry.CFrames, d[keyRegistry.C0]))
                    joint.C1 = array_to_cframe(V(keyRegistry.CFrames, d[keyRegistry.C1]))
                    joint.Part0 = reftable[p0_uuid]
                    joint.Part1 = reftable[p1_uuid]
                    if d[keyRegistry.Tags] then
                        for _, tag in ipairs(d[keyRegistry.Tags]) do joint:AddTag(tag) end
                    end
                    reftable[V(keyRegistry.Strings, d[keyRegistry.UUID])] = joint
                    joint.Parent = item.parent
                    
                    if d[keyRegistry.Children] then
                        for _, child_node in ipairs(d[keyRegistry.Children]) do
                            build(child_node, joint, next_deferred)
                        end
                    end
                else
                    table.insert(next_deferred, item)
                end
            end
        end
        remaining_deferred = next_deferred
    end
    
    if #remaining_deferred > 0 then
        warn("Could not resolve all deferred instances.")
    end

    return reftable[V(keyRegistry.Strings, data[keyRegistry.UUID])], nil
end

return jsm