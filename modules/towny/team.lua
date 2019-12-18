local Public = {}

local item_drop_radius = 2

function Public.add_player_to_town(player, town_center)
	player.force = town_center.market.force
	game.permissions.get_group("Default").add_player(player)
	player.tag = ""
	player.color = town_center.color
	player.chat_color = town_center.color
end

function Public.give_homeless_items(player)
	player.insert({name = "stone-furnace", count = 1})
	player.insert({name = "raw-fish", count = 3})
end

function Public.set_player_to_homeless(player)
	player.force = game.forces.player
	game.permissions.get_group("Homeless").add_player(player)
	player.tag = "[Homeless]"
	player.color = {150, 150, 150}
	player.chat_color = {150, 150, 150}
end

local function ally_homeless(player, target)
	local requesting_force = player.force
	local target_force = target.force

	if requesting_force.index ~= 1 and target_force.index ~= 1 then return end
	if requesting_force.index == 1 and target_force.index == 1 then return true end
	
	if requesting_force.index == 1 then
		global.towny.requests[player.index] = target_force.name
		game.print(">> " .. player.name .. " wants to settle in " .. target_force.name .. " Town!", {255, 255, 0})
		return true
	end
	
	if target_force.index == 1 then		
		if target.type ~= "character" then return true end
		local target_player = target.player
		if not target_player then return true end
		global.towny.requests[player.index] = target_player.name				
		
		if global.towny.requests[target_player.index] then 
			if global.towny.requests[target_player.index] == player.force.name then
				game.print(">> " .. player.name .. " has accepted " .. target_player.name .. " into their Town!", {255, 255, 0})
				Public.add_player_to_town(target_player, global.towny.town_centers[player.name])
				return true
			end
		end	
			
		game.print(">> " .. player.name .. " is inviting " .. target_player.name .. " into their Town!", {255, 255, 0})	
		return true
	end
end

local function ally_neighbour_towns(player, target)
	local requesting_force = player.force
	local target_force = target.force
	
	if target_force.get_friend(requesting_force) and requesting_force.get_friend(target_force) then return end
	
	requesting_force.set_friend(target_force, true)
	game.print(">> Town " .. requesting_force.name .. " has set " .. target_force.name .. " as their friend!", {255, 255, 0})
	
	if target_force.get_friend(requesting_force) then
		game.print(">> The towns " .. requesting_force.name .. " and " .. target_force.name .. " have formed an alliance!", {255, 255, 0})
	end
end

function Public.ally_town(player, item)
	local position = item.position
	local surface = player.surface
	local area = {{position.x - item_drop_radius, position.y - item_drop_radius}, {position.x + item_drop_radius, position.y + item_drop_radius}}
	
	local target = false
	
	for _, e in pairs(surface.find_entities_filtered({type = {"character", "market"}, area = area})) do
		if e.force.name ~= requesting_force.name then
			target = e
			break
		end
	end
	
	if not target then return end

	if ally_homeless(player, target) then return end	
	ally_neighbour_towns(player, target)
end

function Public.declare_war(player, item)
	local position = item.position
	local surface = player.surface
	local area = {{position.x - item_drop_radius, position.y - item_drop_radius}, {position.x + item_drop_radius, position.y + item_drop_radius}}

	local requesting_force = player.force
	local target = surface.find_entities_filtered({type = {"character", "market"}, area = area})[1]

	if not target then return end
	local target_force = target.force
	
	if target_force.index == 1 then return end
	
	if requesting_force.name == target_force.name then
		if player.name ~= target.force.name then
			Public.set_player_to_homeless(player)
			game.print(">> " .. player.name .. " has abandoned " .. target_force.name .. "'s Town!", {255, 255, 0})
			global.towny.requests[player.index] = nil
		end	
		if player.name == target.force.name then
			if target.type ~= "character" then return end
			local target_player = target.player
			if not target_player then return end
			if target_player.index == player.index then return end
			Public.set_player_to_homeless(target_player)
			game.print(">> " .. player.name .. " has banished " .. target_player.name .. " from their Town!", {255, 255, 0})
		end
		return
	end
	
	if requesting_force.index == 1 then return end
	
	requesting_force.set_friend(target_force, false)
	target_force.set_friend(requesting_force, false)
	game.print(">> Town " .. requesting_force.name .. " has set " .. target_force.name .. " as their foe!", {255, 255, 0})
end

function Public.add_new_force(force_name)
	game.create_force(force_name)
	
	game.forces.player.set_cease_fire(force_name, true)
	game.forces[force_name].set_cease_fire('player', true)
	
	game.forces[force_name].research_queue_enabled = true
end

function Public.kill_force(force_name)
	local force = game.forces[force_name]
	local market = global.towny.town_centers[force_name].market	
	local surface = market.surface
	
	surface.create_entity({name = "big-artillery-explosion", position = market.position})
	
	for _, player in pairs(force.players) do
		if player.character then
			player.character.die()
		else
			global.towny.requests[player.index] = "kill-character"
		end
		player.force = game.forces.player
	end

	for _, e in pairs(surface.find_entities_filtered({force = force_name})) do
		if e.health then
			if e.valid then
				if e.health > 0 then e.active = false end
			end
		end
	end

	game.merge_forces(force_name, "neutral")
	
	global.towny.town_centers[force_name] = nil
	global.towny.size_of_town_centers = global.towny.size_of_town_centers - 1
	
	game.print(">> " .. force_name .. "'s town has fallen!", {255, 255, 0})	
end

return Public