# Author: Jules Wang  https://github.com/JulesWang
# This work is licensed under the terms of the GNU GPL, version 2 or later.
# See the LICENSE file in the top-level directory.

line_cleared = []
stored = false

# Count full lines
cal_lines = (display) ->

	lines = 0

	for i in [0...display.length] by 1
		fullLine = true
		line_cleared[i] = false
		for j in [0...display[i].length] by 1
			if display[i][j] == null
				fullLine = false
				break
		if fullLine
			lines += 1
			line_cleared[i] = true
	lines

# Count holes
cal_holes = (display) ->
	holes = 0

	for j in [0...display[0].length-1] by 1
		i = display.length - 1
		while i > 0 && (display[i][j] == null || line_cleared[i])
			i--
		for k in [0...i] by 1
			if display[k][j] == null
				holes++
	holes

# Calculate the peak of tetris mountain
cal_peak = (display) ->
	for i in [display.length-1..0] by -1
		for j in [0...display[i].length] by 1
			if display[i][j] != null
				return i
	0

# 
cal_steep = (display) ->
	steep = 0
	height = []
	for j in [0...display[0].length] by 1
		i = display.length - 1
		while i >= 0 && display[i][j] == null
			i--
		height[j] = i
	
	for j in [0...display[0].length-1] by 1
		steep += Math.abs(height[j] - height[j+1])
		#steep += (height[j] - height[j+1])*(height[j] - height[j+1])

	# find | |, it is a trouble maker 
	#      | |
	#      |_|
	for j in [1...display[0].length-1] by 1
		if (height[j+1] - height[j]) >= 3 && (height[j-1] - height[j]) >= 3
			steep += 10

	if height[1] - height[0] >= 3
		steep += 10

	steep

cal_rightmost = (display) ->
	rm = 0
	for i in [0...display.length] by 1
		if display[i][display[0].length - 1] != null  && !line_cleared[i]
			rm += 1
	rm

cal_rightmost_holes = (display) ->
	holes = 0
	j = display[0].length-1
	i = display.length - 1
	while i > 0 && (display[i][j] == null || line_cleared[i])
		i--
	for k in [0...i] by 1
		if display[k][j] == null
			holes++

	holes
			
fit_one_block = (b) ->
	state = game.state
	display = game.state.display
	type = b.block

	best = {}
	best.score = -1

	# changes happen here
	per_line = 8
	per_height = -4
	per_hole = -20
	per_steep = -1
	per_rightmost = -1
	per_rightmost_holes = -1

	peak = 0
	steep_before = 0
	steep_after = 0

	for rot in [0...4] by 1
		for k in [0...10] by 1
			score = 1000 # base score
			a_block = cache.blocks.srs.blocks[type][rot]
			w = k
			h = b.h
			
			while state.tryActiveBlockPosition(w, h - 1, a_block)
				h -= 1

			continue if h >= 18
			
			peak = cal_peak(display)
			steep_before = cal_steep(display)
			for i in [0...a_block.length] by 1
				display[h - a_block[i][0]][w + a_block[i][1]] = cache.blocks.srs.color[type]

			steep_after = cal_steep(display)

			# 1
			score +=  peak * per_height

			# 2
			lines = cal_lines(display)
			score += lines * (per_line+peak/2.0)

			# 3
			holes = cal_holes(display)
			score += holes * per_hole

			# 4
			rm = cal_rightmost(display)
			score += (!!rm) * per_rightmost

			# 5
			rm_holes = cal_rightmost_holes(display)
			score += (rm_holes) * per_rightmost_holes
			
			# 6
			score += (steep_after - steep_before) * per_steep

			if(score > best.score)
				best.rot = rot
				best.x = k
				best.holes = holes
				best.score = score
				best.rm_holes = rm_holes
						
			# restore
			for i in [0...a_block.length] by 1
				display[h - a_block[i][0]][w + a_block[i][1]] = null

	return best


ai = () ->
	return if not game

	state = game.state
	hold = state.hold
	ab = state.activeBlock
	cur = ab.block #backup
	peak = cal_peak(game.state.display)

	# always try to store the 'i' stick
	if ab.block == 'i' &&  hold != ab.block && peak < 15
		ab.block = hold
		best_hold = fit_one_block(ab)
		ab.block = cur
		if best_hold.holes == 0 && best_hold.rm_holes == 0
			state.storeBlock()
			go_on()
			return

	# then try to store the 't'
	if ab.block == 't' &&  hold != ab.block && hold != 'i' && peak < 15
		ab.block = hold
		best_hold = fit_one_block(ab)
		ab.block = cur
		if best_hold.holes == 0 && best_hold.rm_holes == 0
			state.storeBlock()
			go_on()
			return

			
	best = fit_one_block(ab)

	if hold != ab.block && ((best.holes+best.rm_holes) > 0 || peak > 15)
		ab.block = hold
		best_hold = fit_one_block(ab)
		ab.block = cur
		if best_hold.holes < best.holes || ((best_hold.holes == best.holes) && (best_hold.rm_holes < best.rm_holes)) ||((best_hold.holes == best.holes) && (best_hold.rm_holes == best.rm_holes) && (best_hold.score > best.score))

			state.storeBlock()
			go_on()
			return


	move_count = best.x - 4 #(@drawer.options.cols - 1)/2


	for i in [0...best.rot] by 1
		state.rotateRight()


	if(move_count > 0)
		for i in [0...move_count] by 1
			state.moveRight()
	else
		for i in [move_count...0] by 1
			state.moveLeft()

	#console.log(best.rot)
	#console.log(best.x)
	#console.log(best.score)
	go_on()

	state.doDrop()

go_on = () ->
	return if !cpu_mode

	setTimeout(ai,intval)

	if intval > 10
		intval -= 50

	# For Debug
	#if cal_peak(game.state.display) > 10
		#setTimeout(ai,1000)

	#if game.state.counter > 5000
		#game.state.resetState()
