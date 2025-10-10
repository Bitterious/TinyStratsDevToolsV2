-- jsonAnim by @bittwrious for Tiny Strats Modding API
-- jsonAnim 1 by @bittwrious for TinyWorker
--The MIT License (MIT)

--Copyright (c) 2025, bittwrious (bittwriously@outlook.com)

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

local jsa = {}

local easing_direction = {
	[Enum.PoseEasingDirection.In] = 1,
	[Enum.PoseEasingDirection.Out] = 2,
	[Enum.PoseEasingDirection.InOut] = 3,
}
local easing_style = {
	[Enum.PoseEasingStyle.Constant] = 1,
	[Enum.PoseEasingStyle.Linear] = 2,
	[Enum.PoseEasingStyle.CubicV2] = 3,
	[Enum.PoseEasingStyle.Cubic] = 3,
	[Enum.PoseEasingStyle.Bounce] = 4,
	[Enum.PoseEasingStyle.Elastic] = 5,
}
local priority = {
	[Enum.AnimationPriority.Action4] = 1,
	[Enum.AnimationPriority.Action3] = 2,
	[Enum.AnimationPriority.Action2] = 3,
	[Enum.AnimationPriority.Action] = 4,
	[Enum.AnimationPriority.Core] = 5,
	[Enum.AnimationPriority.Idle] = 6,
	[Enum.AnimationPriority.Movement] = 7,
}

local r_easing_direction, r_easing_style, r_priority = {}, {}, {}
for i, v in easing_direction do r_easing_direction[v] = i end
for i, v in easing_style do r_easing_style[v] = i end
for i, v in priority do r_priority[v] = i end

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

function jsa.sequence_to_json(kfsq: KeyframeSequence)
	local keyframes = {}
	for _, k in kfsq:GetChildren() do
		table.insert(keyframes, k::Keyframe)
	end
	table.sort(keyframes, function(a, b) return a.Time < b.Time end)
	local function recursive_pose_parse(base: Pose)
		local style, direction = easing_style[base.EasingStyle], easing_direction[base.EasingDirection]
		local isnull = base:FindFirstChild("Null") ~= nil
		local data = {
			p = { base.Name, cframe_to_table(base.CFrame), base.Weight, style, direction, isnull },
			c = {}
		}
		for _, x in base:GetChildren() do
			if x:IsA("Pose") then
				table.insert(data.c, recursive_pose_parse(x))
			end
		end
		return data
	end
	local kfdata = {}
	for i, v in keyframes do
		kfdata[i] = {
			t = v.Time,
			p = {},
		}
		for _, x in v:GetChildren() do
			if x:IsA("Pose") then
				table.insert(kfdata[i].p, recursive_pose_parse(x))
			end
		end
	end
	local data = {
		kf = kfdata,
		pr = priority[kfsq.Priority],
		loop = kfsq.Loop
	}
	local encoded, err = json_encode_secure(data)
	if err ~= nil then error(err) end
	return encoded
end

function jsa.json_to_sequence(json: string)
	local data = json_decode_secure(json)
	if data == nil then error("invalid json") end
	local function recursive_pose_build(base: Instance, posedata)
		local name, cframe, weight, style, direction, isnull = unpack(posedata.p)
		local new = Instance.new("Pose")
		new.Name = name
		new.CFrame = table_to_cframe(cframe)
		new.Weight = weight
		new.EasingStyle = r_easing_style[style]
		new.EasingDirection = r_easing_direction[direction]
		if isnull then Instance.new("IntValue", new).Name = "Null" end
		new.Parent = base
		for _, x in posedata.c do
			recursive_pose_build(new, x)
		end
		return new
	end
	local kfsq = Instance.new("KeyframeSequence")
	kfsq.Priority = r_priority[data.pr]
	kfsq.Loop = data.loop
	for i, v in data.kf do
		local k = Instance.new("Keyframe")
		k.Time = v.t
		for _, x in v.p do
			recursive_pose_build(k, x)
		end
		k.Parent = kfsq
	end
	return kfsq
end

return jsa
