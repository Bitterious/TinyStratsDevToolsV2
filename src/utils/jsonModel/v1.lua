-- jsonModel by @bittwrious for KryWorks Game Modding API
-- jsonModel 1 by @bittwrious for TSAPI
--The MIT License (MIT)

--Copyright (c) 2025, bittwrious (bitter@kry.works)

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in
--all copies or substantial portions of the Software.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--THE SOFTWARE.

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

local function cframe_to_table(orig:CFrame)
	local rx, ry, rz = orig:ToEulerAngles(Enum.RotationOrder.XYZ)
	return {
		PX = orig.X,
		PY = orig.Y,
		PZ = orig.Z,
		RX = rx,
		RY = ry,
		RZ = rz
	}
end
local function table_to_cframe(tab): CFrame
	local angle = CFrame.fromEulerAnglesXYZ(tab.RX, tab.RY, tab.RZ)
	return CFrame.new(tab.PX, tab.PY, tab.PZ) * angle
end

local function color3_to_table(color:Color3)
	return {
		R = color.R*255,
		G = color.G*255,
		B = color.B*255
	}
end
local function table_to_color3(tab): Color3
	return Color3.fromRGB(tab.R, tab.G, tab.B)
end

local function vector3_to_table(vec3:Vector3)
	return {
		X = vec3.X,
		Y = vec3.Y,
		Z = vec3.Z
	}
end
local function table_to_vector3(tab): Vector3
	return Vector3.new(tab.X, tab.Y, tab.Z)
end

local instance_parsers = {}

function instance_parsers.parse_children(inst: Instance, children_table, reftable)
	for _, child in inst:GetChildren() do
		if child.ClassName == "Part" then
			table.insert(children_table, instance_parsers.part_to_table(reftable, child))
		elseif child.ClassName == "Folder" or child.ClassName == "Model" then
			table.insert(children_table, instance_parsers.folder_to_table(reftable, child))
		elseif child.ClassName == "Motor6D" or child:IsA("Weld") or child:IsA("ManualWeld") then
			table.insert(children_table, instance_parsers.motor6d_to_table(reftable, child))
		elseif child.ClassName == "Texture" then
			table.insert(children_table, instance_parsers.texture_to_table(reftable, child))
		elseif child.ClassName == "Decal" then
			table.insert(children_table, instance_parsers.decal_to_table(reftable, child))
		else
			warn(`Skipped instance {child:GetFullName()} because its not a supported class ({child.ClassName}).`)
		end
	end
end

function instance_parsers.motor6d_to_table(reftable, motor: Motor6D|Weld)
	local data = {
		uuid = reftable[motor],
		class = if motor:IsA("Motor6D") then "motor" else "weld",
		name = motor.Name,
		tags = motor:GetTags(),
		c0 = cframe_to_table(motor.C0),
		c1 = cframe_to_table(motor.C1),
		p0 = reftable[motor.Part0],
		p1 = reftable[motor.Part1],
		children = {},
	}
	instance_parsers.parse_children(motor, data.children, reftable)
	return data
end
function instance_parsers.folder_to_table(reftable, folder: Folder|Model)
	local data = {
		uuid = reftable[folder],
		class = if folder.ClassName == "Folder" then "folder" else "model",
		primarypart = if folder:IsA("Model") and folder.PrimaryPart then reftable[folder.PrimaryPart] else nil,
		name = folder.Name,
		tags = folder:GetTags(),
		children = {},
	}
	instance_parsers.parse_children(folder, data.children, reftable)
	return data
end
function instance_parsers.part_to_table(reftable, part: Part)
	local data = {
		uuid = reftable[part],
		class = "part",
		name = part.Name,
		tags = part:GetTags(),
		pos = cframe_to_table(part.CFrame),
		size = vector3_to_table(part.Size),
		color = color3_to_table(part.Color),
		shape = part.Shape.Name,
		transparency = part.Transparency,
		material = part.Material.Name,
		anchored = part.Anchored,
		faces = {
			TopSurface = part.TopSurface.Name,
			BottomSurface = part.BottomSurface.Name,
			LeftSurface = part.LeftSurface.Name,
			RightSurface = part.RightSurface.Name,
			FrontSurface = part.FrontSurface.Name,
			BackSurface = part.BackSurface.Name,
		},
		children = {},
	}
	instance_parsers.parse_children(part, data.children, reftable)
	return data
end
function instance_parsers.decal_to_table(reftable, decal: Decal)
	local data = {
		uuid = reftable[decal],
		class = "decal",
		name = decal.Name,
		tags = decal:GetTags(),
		color = color3_to_table(decal.Color3),
		texture = decal.Texture,
		zindex = decal.ZIndex,
		transparency = decal.Transparency,
		face = decal.Face.Name,
		children = {},
	}
	instance_parsers.parse_children(decal, data.children, reftable)
	return data
end
function instance_parsers.texture_to_table(reftable, texture: Texture)
	local data = {
		uuid = reftable[texture],
		class = "texture",
		name = texture.Name,
		tags = texture:GetTags(),
		color = color3_to_table(texture.Color3),
		texture = texture.Texture,
		perhstud = texture.StudsPerTileU,
		pervstud = texture.StudsPerTileV,
		offseth = texture.OffsetStudsU,
		offsetv = texture.OffsetStudsV,
		face = texture.Face.Name,
		transparency = texture.Transparency,
		children = {},
	}
	instance_parsers.parse_children(texture, data.children, reftable)
	return data
end

function jsm.to_json(model:Instance)
	local reftable = {}
	for _, desc in model:GetDescendants() do
		reftable[desc] = httpservice:GenerateGUID(false)
	end
	local data = {
		class = "model_root_"..model.ClassName,
		name = model.Name,
		primary = if model:IsA("Model") and model.PrimaryPart then reftable[model.PrimaryPart] else nil,
		children = {}
	}
	instance_parsers.parse_children(model, data.children, reftable)
	return json_encode_secure(data)
end

function jsm.from_json(jsonstring)
	local data, err = json_decode_secure(jsonstring)
	if not data then return nil, err end
	if not data.class:find("model_root") then return nil, "invalid root" end
	local rootclass = data.class:sub(string.len("model_root_") + 1)
	local reftable = {}
	local deferred: {any}? = {}
	local function build(node, par, defer)
		if node.class == "part" then
			local inst = Instance.new("Part")
			inst.Name = node.name
			inst.CFrame = table_to_cframe(node.pos)
			inst.Size = table_to_vector3(node.size)
			inst.Color = table_to_color3(node.color)
			inst.Transparency = node.transparency
			inst.Anchored = node.anchored
			inst.Material = Enum.Material[node.material] or Enum.Material.Plastic
			inst.Shape = Enum.PartType[node.shape] or Enum.PartType.Block
			inst.TopSurface = Enum.SurfaceType.Smooth
			if node.faces then
				for facename, facetype in pairs(node.faces) do
					if Enum.SurfaceType[facetype] then
						inst[facename] = Enum.SurfaceType[facetype]
					else
						warn(`Invalid surface type {facetype} for face {facename} on part {node.name}.`)
					end
				end
			end
			for _, tag in ipairs(node.tags or {}) do
				inst:AddTag(tag)
			end
			reftable[node.uuid] = inst
			inst.Parent = par
			for _, child in ipairs(node.children or {}) do
				build(child, inst, defer)
			end
		elseif node.class == "decal" then
			local inst = Instance.new("Decal")
			inst.Name = node.name
			inst.Texture = node.texture
			inst.Color3 = table_to_color3(node.color)
			inst.ZIndex = node.zindex or 0
			inst.Face = Enum.NormalId[node.face] or Enum.NormalId.Top
			inst.Transparency = node.transparency or 0
			for _, tag in ipairs(node.tags or {}) do
				inst:AddTag(tag)
			end
			reftable[node.uuid] = inst
			inst.Parent = par
			for _, child in ipairs(node.children or {}) do
				build(child, inst, defer)
			end
		elseif node.class == "folder" then
			local inst = Instance.new("Folder")
			inst.Name = node.name
			for _, tag in ipairs(node.tags or {}) do
				inst:AddTag(tag)
			end
			reftable[node.uuid] = inst
			inst.Parent = par
			for _, child in ipairs(node.children or {}) do
				build(child, inst, defer)
			end
		elseif node.class == "texture" then
			local inst = Instance.new("Texture")
			inst.Name = node.name
			inst.Texture = node.texture
			inst.OffsetStudsU = node.offseth
			inst.OffsetStudsV = node.offsetv
			inst.StudsPerTileU = node.perhstud
			inst.StudsPerTileV = node.pervstud
			inst.Color3 = table_to_color3(node.color)
			inst.Transparency = node.transparency
			inst.Face = Enum.NormalId[node.face] or Enum.NormalId.Top
			for _, tag in ipairs(node.tags or {}) do
				inst:AddTag(tag)
			end
			reftable[node.uuid] = inst
			inst.Parent = par
			for _, child in ipairs(node.children or {}) do
				build(child, inst, defer)
			end
		elseif node.class == "motor" or node.class == "weld" or node.class == "model" then
			table.insert(defer, { data = node, parent = par })
		end
	end
	local root = Instance.new(rootclass)
	root.Name = data.name
	for _, child in ipairs(data.children or {}) do
		build(child, root, deferred)
	end
	while deferred do
		local newdeferred = {}
		for _, item in ipairs(deferred) do
			local d = item.data
			if d.class == "model" then
				local model = Instance.new("Model")
				model.Name = d.name
				model.PrimaryPart = reftable[d.primarypart]
				for _, tag in ipairs(d.tags or {}) do
					model:AddTag(tag)
				end
				model.Parent = item.parent
				for _, child in ipairs(d.children) do
					table.insert(newdeferred, { data = child, parent = model })
				end
			elseif d.class == "motor" or d.class == "weld" then
				local joint = if d.class == "motor" then Instance.new("Motor6D") else Instance.new("Weld")
				joint.Name = d.name
				joint.C0 = table_to_cframe(d.c0)
				joint.C1 = table_to_cframe(d.c1)
				joint.Part0 = reftable[d.p0]
				joint.Part1 = reftable[d.p1]
				for _, tag in ipairs(d.tags or {}) do
					joint:AddTag(tag)
				end
				reftable[d.uuid] = joint
				joint.Parent = item.parent
			else
				build(d, item.parent, newdeferred)
			end
		end
		if #newdeferred > 0 then deferred = newdeferred
		else deferred = nil end
	end
	if data.primary then
		root.PrimaryPart = reftable[data.primary]
	end
	return root, nil
end

return jsm
