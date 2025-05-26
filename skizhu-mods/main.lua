-- name: Enhanced Moveset v1.0
--[[
description:
A new enhanced moveset.\n
Feature:\n
- Jump immediately after landing from a ground pound to perform a boosted jump.\n
- Dive after a ground pound jump boost to trigger a dive boost.\n
- Dive while long jumping to trigger a dive boost.\n
- Chain long jumps to receive increasing boosts with each jump.\n
- Press the Y button in mid-air to start twirling.\n
- Perform a ground pound while twirling to execute a fast spinning ground pound.\n
]]
-- category: Moveset

gEnhancedStates = {}
for i = 0, (MAX_PLAYERS - 1) do
	gEnhancedStates[i] = {
		jumpBoostActive = false,
		diveBoostActive = false,
		longJumpChainActive = false,
		twirlActive = false,
		twirlGroundPoundActive = false,
		actionState = 0,
		timer = 0,
		chainCount = 0,
		spinStartYaw = 0,
		spinAccumYaw = 0,
	}
end

--- @param m MarioState
function enhanced_moveset_update(m)
	-- Setup
	local i = m.playerIndex
	local e = gEnhancedStates[i]

	-- Buttons
	local A_BUTTON_PRESSED = m.controller.buttonPressed & A_BUTTON ~= 0
	local B_BUTTON_PRESSED = m.controller.buttonPressed & B_BUTTON ~= 0
	local Y_BUTTON_PRESSED = m.controller.buttonPressed & Y_BUTTON ~= 0
	local Z_TRIG_PRESSED = m.controller.buttonPressed & Z_TRIG ~= 0

	-- Boost multipliers
	local JUMP_BOOST = 1.05
	local DIVE_HORIZONTAL_BOOST = 1.4
	local DIVE_VERTICAL_BOOST = 1.1
	local LONG_JUMP_BOOST = 1.1
	local YAW_BOOST = 4

	-- Other constants
	local YAW_STEP = 0x1000
	local LONG_JUMP_BOOST_TIMER = 10

	-- Trigger enhanced movesets
	if m.action == ACT_GROUND_POUND_LAND and A_BUTTON_PRESSED then
		reset_enhanced_states(m, e)
		e.jumpBoostActive = true
		e.actionState = 0
	end

	if m.action == ACT_LONG_JUMP and B_BUTTON_PRESSED then
		reset_enhanced_states(m, e)
		e.diveBoostActive = true
		e.actionState = 0
	end

	if (not e.twirlActive and not e.twirlGroundPoundActive) and ((m.action & ACT_FLAG_AIR) ~= 0 and Y_BUTTON_PRESSED) or m.action == ACT_TWIRLING then
		reset_enhanced_states(m, e)
		e.twirlActive = true
		e.actionState = 0
	end

	if e.jumpBoostActive and B_BUTTON_PRESSED then
		reset_enhanced_states(m, e)
		e.diveBoostActive = true
		e.actionState = 0
	end

	if e.jumpBoostActive and Y_BUTTON_PRESSED then
		reset_enhanced_states(m, e)
		e.twirlActive = true
		e.actionState = 0
	end

	if e.twirlActive and Z_TRIG_PRESSED then
		reset_enhanced_states(m, e)
		e.twirlGroundPoundActive = true
		e.actionState = 0
	end

	if m.action == ACT_LONG_JUMP_LAND then
		reset_enhanced_states(m, e)
		e.longJumpChainActive = true
		e.timer = LONG_JUMP_BOOST_TIMER
	end

	-- Handle enhanced movesets
	if e.jumpBoostActive then
		if e.actionState == 0 then
			e.spinStartYaw = m.faceAngle.y
			e.spinAccumYaw = 0
			if m.action ~= ACT_TRIPLE_JUMP then
				set_mario_action(m, ACT_TRIPLE_JUMP, 0)
			end
			m.vel.y = m.vel.y * JUMP_BOOST
			e.actionState = e.actionState + 1
		end
		if e.actionState == 1 then
			set_mario_animation(m, MARIO_ANIM_SINGLE_JUMP)
			set_anim_to_frame(m, 5)
			if m.vel.y > 0 then
				m.particleFlags = m.particleFlags | PARTICLE_SPARKLES | PARTICLE_DUST
				if e.spinAccumYaw < 0x10000 then
					e.spinAccumYaw = e.spinAccumYaw + YAW_STEP
					m.marioObj.header.gfx.angle.y = (e.spinStartYaw + e.spinAccumYaw) % 0x10000
				else
					m.marioObj.header.gfx.angle.y = e.spinStartYaw
				end
			end
		end
		if m.action ~= ACT_TRIPLE_JUMP then
			e.jumpBoostActive = false
		end
	end

	if e.diveBoostActive then
		if e.actionState == 0 then
			if m.action ~= ACT_DIVE then
				set_mario_action(m, ACT_DIVE, 0)
			end
			m.particleFlags = m.particleFlags | PARTICLE_MIST_CIRCLE
			m.forwardVel = m.forwardVel * DIVE_HORIZONTAL_BOOST
			m.vel.y = m.vel.y * DIVE_VERTICAL_BOOST
			e.actionState = e.actionState + 1
		end
		if e.actionState == 1 then
			m.particleFlags = m.particleFlags | PARTICLE_SPARKLES | PARTICLE_DUST
		end
		if m.action ~= ACT_DIVE then
			e.diveBoostActive = false
		end
	end

	if e.longJumpChainActive then
		if m.action == ACT_LONG_JUMP and e.timer > 0 then
			m.particleFlags = m.particleFlags | PARTICLE_MIST_CIRCLE
			e.chainCount = e.chainCount + 1

			if e.chainCount > 0 then
				m.forwardVel = m.forwardVel * (LONG_JUMP_BOOST + (e.chainCount / 10))
			end
			e.timer = 0
			e.actionState = 0
		end
		if m.action == ACT_LONG_JUMP and e.chainCount > 0 then
			m.particleFlags = m.particleFlags | PARTICLE_SPARKLES | PARTICLE_DUST
		end
		if e.timer == 0 and m.action ~= ACT_LONG_JUMP_LAND and m.action ~= ACT_LONG_JUMP then
			e.longJumpChainActive = false
			e.chainCount = 0
		end
	end

	if e.twirlActive then
		if e.actionState == 0 then
			if m.action ~= ACT_TWIRLING then
				set_mario_action(m, ACT_TWIRLING, 0)
			end
			e.actionState = e.actionState + 1
		end
		if e.actionState == 1 then
			set_mario_animation(m, MARIO_ANIM_TWIRL)
			m.particleFlags = m.particleFlags | PARTICLE_SPARKLES | PARTICLE_DUST
		end
		if m.action == ACT_TWIRL_LAND then
			set_mario_action(m, ACT_WALKING, 0)
			m.faceAngle.y = m.intendedYaw
		end
		if m.action ~= ACT_TWIRLING then
			e.twirlActive = false
		end
	end

	if e.twirlGroundPoundActive then
		if e.actionState == 0 then
			if m.action ~= ACT_GROUND_POUND then
				set_mario_action(m, ACT_GROUND_POUND, 0)
			end
			e.spinStartYaw = m.faceAngle.y
			e.spinAccumYaw = 0
			m.actionTimer = 15
			e.actionState = e.actionState + 1
		end
		if e.actionState == 1 then
			set_mario_animation(m, MARIO_ANIM_TWIRL)
			m.particleFlags = m.particleFlags | PARTICLE_SPARKLES | PARTICLE_DUST
			e.spinAccumYaw = e.spinAccumYaw + (YAW_STEP * YAW_BOOST)
			m.marioObj.header.gfx.angle.y = (e.spinStartYaw + e.spinAccumYaw) % 0x10000
		end
		if m.action ~= ACT_GROUND_POUND then
			e.twirlGroundPoundActive = false
		end
	end

	if e.timer > 0 then
		e.timer = e.timer - 1
	end
end

function reset_enhanced_states(m, e)
	e.jumpBoostActive = false
	e.diveBoostActive = false
	e.longJumpChainActive = false
	e.twirlActive = false
	e.twirlGroundPoundActive = false
end

hook_event(HOOK_MARIO_UPDATE, enhanced_moveset_update)
