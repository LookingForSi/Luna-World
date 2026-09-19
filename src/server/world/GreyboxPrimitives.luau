--!strict

export type Attributes = { [string]: any }

local MARKER_SIZE = Vector3.new(2, 2, 2)
local MARKER_COLOR = Color3.fromRGB(255, 196, 64)
local LABEL_SIZE = UDim2.fromOffset(220, 32)
local LABEL_OFFSET = Vector3.new(0, 3, 0)
local DEFAULT_LABEL_MAX_DISTANCE = 65
local MARKER_LABEL_MAX_DISTANCE = 45

local GreyboxPrimitives = {}

local function applyAttributes(instance: Instance, attributes: Attributes)
	for name, value in pairs(attributes) do
		instance:SetAttribute(name, value)
	end
end

function GreyboxPrimitives.createBlock(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	attributes: Attributes
): BasePart
	local block = Instance.new("Part")
	block.Name = name
	block.Size = size
	block.CFrame = cframe
	block.Material = material
	block.Anchored = true
	block.CanCollide = true
	applyAttributes(block, attributes)
	block.Parent = parent

	return block
end

function GreyboxPrimitives.createLabel(adornee: BasePart, text: string, maxDistance: number?): BillboardGui
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Adornee = adornee
	label.AlwaysOnTop = false
	label.MaxDistance = maxDistance or DEFAULT_LABEL_MAX_DISTANCE
	label.Size = LABEL_SIZE
	label.StudsOffset = LABEL_OFFSET

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = text
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextScaled = false
	textLabel.TextSize = 15
	textLabel.TextWrapped = true
	textLabel.TextStrokeTransparency = 0.55
	textLabel.Parent = label

	label.Parent = adornee

	return label
end

function GreyboxPrimitives.createMarker(
	parent: Instance,
	name: string,
	position: Vector3,
	attributes: Attributes
): BasePart
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Size = MARKER_SIZE
	marker.Position = position
	marker.Shape = Enum.PartType.Ball
	marker.Material = Enum.Material.Neon
	marker.Color = MARKER_COLOR
	marker.Anchored = true
	marker.CanCollide = false
	marker:SetAttribute("StableId", name)
	applyAttributes(marker, attributes)
	GreyboxPrimitives.createLabel(marker, name, MARKER_LABEL_MAX_DISTANCE)
	marker.Parent = parent

	return marker
end

function GreyboxPrimitives.createSegment(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	width: number,
	thickness: number
): BasePart
	local offset = toPosition - fromPosition
	local midpoint = fromPosition + offset / 2
	local segment = GreyboxPrimitives.createBlock(
		parent,
		name,
		Vector3.new(width, thickness, offset.Magnitude),
		CFrame.lookAt(midpoint, toPosition),
		Enum.Material.SmoothPlastic,
		{}
	)

	return segment
end

function GreyboxPrimitives.createSegmentWithOverlap(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	width: number,
	thickness: number,
	overlap: number
): BasePart
	assert(overlap >= 0, "segment overlap must be non-negative")
	local offset = toPosition - fromPosition
	assert(offset.Magnitude > 0, "segment endpoints must not be identical")

	local extension = offset.Unit * overlap / 2
	return GreyboxPrimitives.createSegment(
		parent,
		name,
		fromPosition - extension,
		toPosition + extension,
		width,
		thickness
	)
end

return table.freeze(GreyboxPrimitives)
