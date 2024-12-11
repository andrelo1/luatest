local INPUT_COMMAND_UNKNOWN <const> = 0
local INPUT_COMMAND_MOVE <const> = 1

local BLOCK_STATE_FALLING <const> = 1
local BLOCK_STATE_DESTROYED <const> = 2

local BlockField = {}

function BlockField:init(width, height)
	self.blocks = {}
	self.width = width
	self.height = height
end

function BlockField:get(x, y)
	if x < 0 or x >= self.width or y < 0 or y >= self.height then
		return nil
	end

	return self.blocks[y * self.width + x]
end

function BlockField:set(x, y, block)
	if x < 0 or x >= self.width or y < 0 or y >= self.height then
		return
	end

	self.blocks[y * self.width + x] = block
end

function BlockField:swap(x1, y1, x2, y2)
	local block = self:get(x2, y2)
	self:set(x2, y2, self:get(x1, y1))
	self:set(x1, y1, block)
end

local ActivationRuleMatch3 = {}

function ActivationRuleMatch3:canActivate(x, y)
	local block1 = BlockField:get(x, y)

	if not block1 then
		return false
	end

	local count = 1

	for x_ = x - 1, x - 2, -1 do
		local block2 = BlockField:get(x_, y)
		if not block2 or block2.type ~= block1.type or block2:isFalling() then
			break
		end
		count = count + 1
	end

	for x_ = x + 1, x + 2 do
		local block2 = BlockField:get(x_, y)
		if not block2 or block2.type ~= block1.type or block2:isFalling() then
			break
		end
		count = count + 1
	end

	if count >= 3 then
		return true
	end

	count = 1

	for y_ = y - 1, y - 2, -1 do
		local block2 = BlockField:get(x, y_)
		if not block2 or block2.type ~= block1.type or block2:isFalling() then
			break
		end
		count = count + 1
	end

	for y_ = y + 1, y + 2 do
		local block2 = BlockField:get(x, y_)
		if not block2 or block2.type ~= block1.type or block2:isFalling() then
			break
		end
		count = count + 1
	end

	return count >= 3
end

local Block = {}
Block.__index = Block

function Block:new(type)
	local block = {}
	block.type = type
	block.state = 0
	block.activationRule = ActivationRuleMatch3
	setmetatable(block, Block)
	return block
end

function Block:isFalling()
	return self.state & BLOCK_STATE_FALLING == BLOCK_STATE_FALLING
end

function Block:setFalling(val)
	if val then
		self.state = self.state | BLOCK_STATE_FALLING
	else
		self.state = self.state & (~BLOCK_STATE_FALLING)
	end
end

function Block:isDestroyed()
	return self.state & BLOCK_STATE_DESTROYED == BLOCK_STATE_DESTROYED
end

function Block:setDestroyed(val)
	if val then
		self.state = self.state | BLOCK_STATE_DESTROYED
	else
		self.state = self.state & (~BLOCK_STATE_DESTROYED)
	end
end

function Block:activate()
	self:setDestroyed(true)
end

local Model = {}

function Model:clearStats()
	self.stats.blocksMoved = 0
	self.stats.blocksRemoved = 0
end

function Model:init()
	BlockField:init(10, 10)

	for x = 0, BlockField.width - 1 do
		for y = 0, BlockField.height - 1 do
			BlockField:set(x, y, Block:new(math.random(0, 5)))
		end
	end

	self.stats = {}
	self:clearStats()
end

function Model:movementUpdate()
	for y = BlockField.height - 2, 0, -1 do
		for x = 0, BlockField.width - 1 do
			local block = BlockField:get(x, y)
			if block and block:isFalling() then
				BlockField:swap(x, y, x, y + 1)
				self.stats.blocksMoved = self.stats.blocksMoved + 1
			end
		end
	end
end

function Model:movementStateUpdate()
	for x = 0, BlockField.width - 1 do
		local block = BlockField:get(x, BlockField.height - 1)
		if block then
			block:setFalling(false)
		end
	end

	for y = BlockField.height - 2, 0, -1 do
		for x = 0, BlockField.width - 1 do
			local block1 = BlockField:get(x, y)
			local block2 = BlockField:get(x, y + 1)
			if block1 then
				block1:setFalling(not block2 or block2:isFalling())
			end
		end
	end
end

function Model:addNewBlocks()
	for x = 0, BlockField.width - 1 do
		if not BlockField:get(x, 0) then
			BlockField:set(x, 0, Block:new(math.random(0, 5)))
		end
	end
end

function Model:activateBlocks()
	for x = 0, BlockField.width - 1 do
		for y = 0, BlockField.height - 1 do
			local block = BlockField:get(x, y)
			if block and not block:isFalling() then
				if block.activationRule:canActivate(x, y) then
					block:activate()
				end
			end
		end
	end
end

function Model:removeDestroyedBlocks()
	for x = 0, BlockField.width - 1 do
		for y = 0, BlockField.height - 1 do
			local block = BlockField:get(x, y)
			if block and block:isDestroyed() then
				BlockField:set(x, y, nil)
				self.stats.blocksRemoved = self.stats.blocksRemoved + 1
			end
		end
	end
end

function Model:tick()
	self:movementUpdate()
	self:activateBlocks()
	self:removeDestroyedBlocks()
	self:addNewBlocks()
	self:movementStateUpdate()
end

function Model:activatableBlocksCount()
	local count = 0

	for x = 0, BlockField.width - 1 do
		for y = 0, BlockField.height - 1 do
			local block = BlockField:get(x, y)
			if block and block.activationRule:canActivate(x, y) then
				count = count + 1
			end
		end
	end

	return count
end

function Model:getPotentialMoves()
	local moves = {}

	for x = 0, BlockField.width - 2 do
		for y = 0, BlockField.height - 1 do
			BlockField:swap(x, y, x + 1, y)
			if self:activatableBlocksCount() > 0 then
				table.insert(moves, {from = {x = x, y = y}, to = {x = x + 1, y = y}})
				table.insert(moves, {from = {x = x + 1, y = y}, to = {x = x, y = y}})
			end
			BlockField:swap(x, y, x + 1, y)
		end
	end

	for x = 0, BlockField.width - 1 do
		for y = 0, BlockField.height - 2 do
			BlockField:swap(x, y, x, y + 1)
			if self:activatableBlocksCount() > 0 then
				table.insert(moves, {from = {x = x, y = y}, to = {x = x, y = y + 1}})
				table.insert(moves, {from = {x = x, y = y + 1}, to = {x = x, y = y}})
			end
			BlockField:swap(x, y, x, y + 1)
		end
	end

	return moves
end

function Model:move(from, to)
	BlockField:swap(from.x, from.y, to.x, to.y)
end

function Model:mix(count)
	for i = 0, count - 1 do
		local from = {x = math.random(0, BlockField.width - 1), y = math.random(0, BlockField.height - 1)}
		local to = {x = math.random(0, BlockField.width - 1), y = math.random(0, BlockField.height - 1)}
		self:move(from, to)
	end
end

function Model:dump()
	local s

	s = "    "
	for x = 0, BlockField.width - 1 do
		s = s..x.." "
	end

	print(s)

	s = "----"
	for x = 0, BlockField.width - 1 do
		s = s.."--"
	end

	print(s)

	local typeStr = "ABCDEF"

	for y = 0, BlockField.height - 1 do
		s = y.." | "
		for x = 0, BlockField.width - 1 do
			local block = BlockField:get(x, y)
			if block then
				s = s..string.sub(typeStr, block.type + 1, block.type + 1).." "
			else
				s = s.."  "
			end
		end
		print(s)
	end
end

local Game = {}

function Game:init()
	Model:init()
end

function Game:render()
	Model:dump()
	print()
end

function Game:readUserInput()
	local s = string.lower(io.read())

	if not s or s == "" then
		return {type = INPUT_COMMAND_UNKNOWN}
	end

	if string.len(s) == 4 and string.find(s, "m%d%d[l, r, u, d]") then
		local from = {}
		from.x = tonumber(string.sub(s, 2, 2))
		from.y = tonumber(string.sub(s, 3, 3))
		local to = {x = from.x, y = from.y}
		local dir = string.sub(s, 4, 4)

		if dir == "l" then
			to.x = to.x - 1
		elseif dir == "r" then
			to.x = to.x + 1
		elseif dir == "u" then
			to.y = to.y - 1
		else
			to.y = to.y + 1
		end

		return {type = INPUT_COMMAND_MOVE, from = from, to = to}
	end

	return {type = INPUT_COMMAND_UNKNOWN}
end

function Game:mainLoop()
	while true do
		while true do
			Model:clearStats()
			Model:tick()
			self:render()

			if Model.stats.blocksMoved == 0 and Model.stats.blocksRemoved == 0 then
				break;
			end
		end

		local potentialMoves = Model:getPotentialMoves()

		if #potentialMoves == 0 then
			Model:mix(100)
			self:render()
		else
			local cmd = self:readUserInput()

			while cmd.type == INPUT_COMMAND_UNKNOWN do
				cmd = self:readUserInput()
			end

			for i, move in ipairs(potentialMoves) do
				if cmd.from.x == move.from.x and cmd.from.y == move.from.y and cmd.to.x == move.to.x and cmd.to.y == move.to.y then
					Model:move(cmd.from, cmd.to)
					break
				end
			end
		end
	end
end

Game:init()
Game:render()
Game:mainLoop()