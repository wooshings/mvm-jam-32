require("engine.vector")

player = {
	movement = {
		speed = 200,
		accel = 1500,
		fall = 1000,
		grav= 900,
		jump_height = 50,
		jump_boost_height = 100,
		jump_boost_time = 0.3,
		coyote_time = 0.2,
		--air_jumps = 1, -- TODO separate jump_boost info for each?
		-- TODO wall jumps / climb ?
	},
	state = {
		jump_start = 0,
		jump_jump_held = 1000,
		coyote_timer = 0,
		--air_jumps_used = 0,
	},
	velocity = vec(0, 0),
	touching = {
		ground = false,
		ceiling = false,
		wall = false,
	},
	aabb = {
		x = 10,
		y = 100,
		w = 10,
		h = 10,
	},
}

function player.boost_ratio(t)
	return t ^ 0.75
end

-- see jump_physics.txt
-- or don't, differential equations are hell
function player.max_jump_height(velocity)
	return -player.movement.fall/player.movement.grav*(player.movement.fall*math.log(1+velocity/player.movement.fall)-velocity)
end

function player.jump_velocity(height)
	-- Newton's Method
	local guess = 100
	for i = 0, 10 do
		local slope = player.max_jump_height(guess + 0.5) - player.max_jump_height(guess - 0.5)
		local err = player.max_jump_height(guess) - height
		guess = guess - err / slope
	end
	return guess
end

function physics_step(input, gamma, v0, x0, dt)
	local c = input / gamma - v0
	local c2 = -c / gamma
	local v1 = input / gamma - c * math.exp(-gamma * dt)
	local dx = input * dt / gamma + c * math.exp(-gamma * dt) / gamma + c2
	return v1, x0 + dx
end

function player:update(dt)
	self.state.coyote_timer = self.state.coyote_timer + dt
	if self.touching.ground then
		self.state.jump_help = self.movement.jump_boost_time + 1
		self.state.coyote_timer = 0
	end
	if self.touching.ceiling then
		self.state.jump_help = self.movement.jump_boost_time + 1
	end

	local input_dir = vector.utils.input_vector()
	local input_accel = { x = input_dir.x * self.movement.accel, y = self.movement.grav }
	if input.held(input.BTN1) then
		if self.state.coyote_timer < self.movement.coyote_time then
			self.velocity.y = -player.jump_velocity(self.movement.jump_height)
			self.state.jump_held = 0
			self.state.coyote_timer = self.movement.coyote_time + 1
			self.state.jump_start = self.aabb.y
		elseif self.state.jump_held < self.movement.jump_boost_time then
			local target_total = self.movement.jump_height + self.movement.jump_boost_height * player.boost_ratio(self.state.jump_held / self.movement.jump_boost_time)
			local height_remaining = target_total + self.aabb.y - self.state.jump_start
			self.velocity.y = -player.jump_velocity(height_remaining)
			self.state.jump_held = self.state.jump_held + dt
		end
	else
		self.state.jump_held = self.movement.jump_boost_time + 1
	end
	local target = {}
	self.velocity.x, target.x = physics_step(input_accel.x, self.movement.accel / self.movement.speed, self.velocity.x, self.aabb.x, dt)
	self.velocity.y, target.y = physics_step(input_accel.y, self.movement.grav / self.movement.fall, self.velocity.y, self.aabb.y, dt)
	player:move_to(target)
end

function player:move_to(target)
	self.aabb, self.touching = collision.move_to(world[current_scene], self.aabb, target)
	if self.touching.ceiling or self.touching.ground then
		self.velocity.y = 0
	end
	if self.touching.wall then
		self.velocity.x = 0
	end
end

function player:draw()
	gfx.rect_fill(
		player.aabb.x - player.aabb.w / 2,
		player.aabb.y - player.aabb.h,
		player.aabb.w,
		player.aabb.h,
		gfx.COLOR_WHITE
	)
end

