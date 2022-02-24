allowHotReload(true)
-- all lua commands for cserver you can find in igor725/cs-lua/src
function preReload()
	command.remove('tp')
	command.remove('tppos')
	command.remove('afk')
	command.remove('announce')
	command.remove('clients')
end

function tpPlayers(caller, args)
	if not args then
		return '&cUsage: /tp <to> or /tp <whom> <to>'
	end
	local targ, subj = caller, nil
	local u1, u2 = args:match('^(.-)%s(.-)$')
	if u1 then
		targ, subj = client.getbyname(u1, u2)
	else
		subj = client.getbyname(args)
	end
	if not (targ and subj) then
		return '&cPlayer not found'
	end
	local succText = u1 and ("&e%s &awas teleported to &e%s"):format(targ:getname(), subj:getname()) or ("&aTeleported to &e%s"):format(subj:getname())
	local targWrld, subjWrld = targ:getworld(), subj:getworld()
	local subjPos = subj:getpositiona()
	if targWrld ~= subjWrld then
		if not u1 then targ:chat("&eTeleporting to player's world") end
		targ:gotoworld(subjWrld)
	end
	targ:teleport(subjPos, targ:getrotationa())
	return(succText)
end

function tpPosition(caller, args)
	if not args then
		return "&cUsage: /tppos <x> <y> <z> or /tppos <whom> <x> <y> <z>"
	end
	local player = caller
	local playerName, x, y, z = args:match(coordsPattern)
	if not x then
		return "&cUsage: /tppos <x> <y> <z> or /tppos <whom> <x> <y> <z>"
	end
	if #playerName > 0 then
		player = client.getbyname(playerName)
		if not player then
			return "&cPlayer not found"
		end
	end
	local succText = #playerName == 0 and ("&aTeleported to %.3f %.3f %.3f"):format(x,y,z) or ("&e%s &awas teleported to %.3f %.3f %.3f"):format(player:getname(), x,y,z)
	player:teleport(vector.float(x, y+1, z), player:getrotationa())
	return (succText)
end

function switchAFK(player, mode)
	if mode == nil then
		mode = true
	end
	if (pAfkList[player]) and (not mode) then
		pAfkList[player] = nil
		client.getbroadcast():chat(("&d%s no longer afk"):format(player:getname()))
	elseif (not pAfkList[player]) and (mode) then
		pAfkList[player] = true
		client.getbroadcast():chat(("&d%s went afk"):format(player:getname()))
	end
	if not mode then
		pLastActivity[player] = timer
	end
end

function onTick(tick)
	timer = timer + tick
	if math.floor(timer/1000) % 30 == 0 then
		for player, lastActivity in pairs(pLastActivity) do
			if timer - lastActivity >= AFK_TIME*1000 then
				switchAFK(player, true)
			end
		end
	end
end

function onRotate(player)
	switchAFK(player, false)
end

function onPlayerClick(player, args)
	switchAFK(player, false)
end

function onMove(player)
	local playerPos = player:getpositiona()
	local x,y,z = playerPos:get()
	if not pLastMovement[player] then
		pLastMovement[player] = {}
	end
	local playerMovement = pLastMovement[player]
	table.insert(playerMovement, {['x'] = x, ['y'] = y, ['z'] = z, ['time'] = timer})
	if #playerMovement > 2 then
		table.remove(playerMovement, 1)
	end
	if #playerMovement == 2 then
		local function calculate_speed(axis)
			local distance = playerMovement[#playerMovement][axis] - playerMovement[#playerMovement-1][axis]
			if (distance < 0) and (axis == 'y') then
				return 0
			end
			local time = playerMovement[#playerMovement]['time'] - playerMovement[#playerMovement-1]['time']
			local speed = (distance/time)*1000
			return math.abs(speed)
		end
		if calculate_speed('x') > 3 or calculate_speed('y') > 2 or calculate_speed("z") > 3 then
			switchAFK(player, false)
		end
	end
end

function onDisconnect(player)
	pAfkList[player] = nil
	pLastActivity[player] = nil
	pLastMovement[player] = nil
	local playerName, playerApp = player:getname(), player:getappname()
	for clientIndex, clientPlayer in ipairs(clients[playerApp]) do
		if clientPlayer == playerName then
			table.remove(clients[playerApp], clientIndex)
			if #clients[playerApp] == 0 then
				clients[playerApp] = nil
			end
		end
	end
end

function makeAnnounce(_, args)
	client.getbroadcast():chat(MESSAGE_TYPE_ANNOUNCE, args)
end

function onMessage(cl, _, text)
	local _, playerName, msg = text:match("^(/msg)%s+(.+)%s+(.-)$")
	local playerReceiver = playerName and client.getbyname(playerName) or nil
	if playerReceiver then
		if pAfkList[playerReceiver] then
			cl:chat("&eNote that this player is afk")
		end
	end
	if text ~= '/afk' then
		switchAFK(cl, false)
	end
end

function clients(caller)
	caller:chat("Players using: ")
	for k,v in pairs(clients) do
		caller:chat(("    &e%s: &f%s"):format(k, table.concat(v, ", ")))
	end
end

function addClient(player)
	local playerName, playerApp = player:getname(), player:getappname()
	if clients[playerApp] then
		table.insert(clients[playerApp], playerName)
	else
		clients[playerApp] = {playerName}
	end
end

function onSpawn(player)
	if player:isfirstspawn() then
		addClient(player)
	end
end

function onStart()
	command.add('tp', 'Teleport to player', CMDF_OP, tpPlayers)
	command.add('tppos', 'Teleport to specific coords', CMDF_OP, tpPosition)
	command.add('afk', 'Went to afk', CMDF_CLIENT, switchAFK)
	command.add('announce', 'Make an announcement', CMDF_OP, makeAnnounce)
	command.add('clients', 'List of the clients player are using, and who uses which client', CMDF_CLIENT, clients)
	coordsPattern = '^(.-)%s?([-+]?%d*%.?%d*)%s+([-+]?%d*%.?%d*)%s+([-+]?%d*%.?%d*)$'
	clients = {}
	pAfkList = {}
	pLastActivity = {}
	pLastMovement = {}
	AFK_TIME = 90
	timer = 0
	client.iterall(addClient)
end
