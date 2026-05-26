collision = {}

-- returns the first interruption from (start) -> (target) along each axis as a ratio from 0-1
function collision.path_interruptions(room, start, target)
	-- TODO: support sloped floors and walls? (optional)
	local floor_collision = nil
	local wall_collision = nil
	for _, floor in pairs(room.floors) do
		if (start.y < floor.left.y) ~= (target.y < floor.left.y) then
			local portion = (floor.left.y - start.y) / (target.y - start.y)
			local intersection_x = (target.x - start.x) * portion + start.x
			if intersection_x >= floor.left.x and intersection_x <= floor.right.x then
				if (not floor_collision) or portion < floor_collision then
					floor_collision = portion
				end
			end
		end
	end
	for _, wall in pairs(room.walls) do
		if (start.x < wall.bottom.x) ~= (target.x < wall.bottom.x) then
			local portion = (wall.bottom.x - start.x) / (target.x - start.x)
			local intersection_y = (target.y - start.y) * portion + start.y
			if intersection_y >= wall.top.y and intersection_y <= wall.bottom.y then
				if (not wall_collision) or portion < wall_collision then
					wall_collision = portion
				end
			end
		end
	end
	return { floor = floor_collision, wall = wall_collision }
end

function collision.move_to(room, start, target)
	local displacement = { x = target.x - start.x, y = target.y - start.y }
	-- run path_interruptions on each corner of the hitbox
	local collision_points = {
		{ x = start.x - start.w / 2, y = start.y },
		{ x = start.x + start.w / 2, y = start.y },
		{ x = start.x - start.w / 2, y = start.y - start.h },
		{ x = start.x + start.w / 2, y = start.y - start.h },
	}
	local floor_collision = nil
	local wall_collision = nil
	for _, start_point in pairs(collision_points) do
		local target_point = { x = start_point.x + displacement.x, y = start_point.y + displacement.y }
		local collisions = collision.path_interruptions(room, start_point, target_point)
		if (not floor_collision) or (collisions.floor and collisions.floor < floor_collision) then
			floor_collision = collisions.floor
		end
		if (not wall_collision) or (collisions.wall and collisions.wall < wall_collision) then
			wall_collision = collisions.wall
		end
	end
	-- because floors and ceilings are checked separately, there is potential for clipiping (e.g. if the
	-- player has sufficient vertical velocity that they would clear a wall, but is blocked by a ceiling)
	-- to fix this, run collision a second time with the displacement capped if a collision is detected
	-- add an epsilon so that collision detection remains true on the second run
	if floor_collision then
		displacement.y = displacement.y * (floor_collision + 0.001)
	end
	if wall_collision then
		displacement.x = displacement.x * (wall_collision + 0.001)
	end
	floor_collision = nil
	wall_collision = nil
	for _, start_point in pairs(collision_points) do
		local target_point = { x = start_point.x + displacement.x, y = start_point.y + displacement.y }
		local collisions = collision.path_interruptions(room, start_point, target_point)
		if (not floor_collision) or (collisions.floor and collisions.floor < floor_collision) then
			floor_collision = collisions.floor
		end
		if (not wall_collision) or (collisions.wall and collisions.wall < wall_collision) then
			wall_collision = collisions.wall
		end
	end

	local touching = { ground = false, ceiling = false, wall = false }
	local end_point = { x = start.x, y = start.y }
	-- use a small boundary around walls
	if floor_collision then
		if displacement.y > 0 then
			end_point.y = end_point.y - 0.1
			touching.ground = true
		end
		if displacement.y < 0 then
			end_point.y = end_point.y + 0.1
			touching.ceiling = true
		end
		displacement.y = displacement.y * floor_collision
	else
	end
	if wall_collision then
		if displacement.x > 0 then
			end_point.x = end_point.x - 0.1
			touching.wall = true
		end
		if displacement.x < 0 then
			end_point.x = end_point.x + 0.1
			touching.wall = true
		end
		displacement.x = displacement.x * wall_collision
	end
	end_point.x = end_point.x + displacement.x
	end_point.y = end_point.y + displacement.y
	end_point.h = start.h
	end_point.w = start.w
	return end_point, touching
end
