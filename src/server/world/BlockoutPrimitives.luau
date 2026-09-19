--!strict

local TerrainGrounding = require(script.Parent.TerrainGrounding)

export type PartOptions = {
	canCollide: boolean?,
	transparency: number?,
	shape: Enum.PartType?,
	attributes: { [string]: any }?,
}

local BlockoutPrimitives = {}

local function applyOptions(part: Part, options: PartOptions?)
	if options == nil then
		return
	end

	if options.canCollide ~= nil then
		part.CanCollide = options.canCollide
	end
	if options.transparency ~= nil then
		part.Transparency = options.transparency
	end
	if options.shape ~= nil then
		part.Shape = options.shape
	end
	if options.attributes ~= nil then
		for name, value in pairs(options.attributes) do
			part:SetAttribute(name, value)
		end
	end
end

function BlockoutPrimitives.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	options: PartOptions?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	applyOptions(part, options)
	part.Parent = parent
	return part
end

function BlockoutPrimitives.groundedPart(
	parent: Instance,
	name: string,
	authoredPosition: Vector3,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	options: PartOptions?
): (Part, boolean)
	local groundPosition, hit = TerrainGrounding.surfaceAt(authoredPosition)
	local center = groundPosition + Vector3.new(0, size.Y / 2, 0)
	return BlockoutPrimitives.part(parent, name, size, CFrame.new(center), material, color, options), hit
end

function BlockoutPrimitives.segment(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	width: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	options: PartOptions?
): Part
	local offset = toPosition - fromPosition
	local midpoint = fromPosition + offset / 2
	return BlockoutPrimitives.part(
		parent,
		name,
		Vector3.new(width, thickness, offset.Magnitude),
		CFrame.lookAt(midpoint, toPosition),
		material,
		color,
		options
	)
end

function BlockoutPrimitives.groundedSegment(
	parent: Instance,
	name: string,
	authoredFrom: Vector3,
	authoredTo: Vector3,
	width: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	options: PartOptions?
): (Part, number)
	local fromGround, hitFrom = TerrainGrounding.surfaceAt(authoredFrom)
	local toGround, hitTo = TerrainGrounding.surfaceAt(authoredTo)
	local vertical = Vector3.new(0, thickness / 2 + 0.05, 0)
	local part = BlockoutPrimitives.segment(
		parent,
		name,
		fromGround + vertical,
		toGround + vertical,
		width,
		thickness,
		material,
		color,
		options
	)

	local hits = 0
	if hitFrom then hits += 1 end
	if hitTo then hits += 1 end
	return part, hits
end

function BlockoutPrimitives.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function BlockoutPrimitives.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

return table.freeze(BlockoutPrimitives)
