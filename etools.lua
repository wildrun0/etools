allowHotReload(true)
-- all lua commands for cserver you can find in igor725/cs-lua/src

function delcommands()
	command.remove('tp')
	command.remove('tppos')
	command.remove('afk')
	command.remove('announce')
	command.remove('clients')
end

function preReload()
	delcommands()
end
function onStop()
	delcommands()
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
		pLastActivity[player].time = (os.time() - AFK_TIME*1000) -- чтобы его из афк не выкинуло
	end
	if (pAfkList[player]) and (not mode) then
		pAfkList[player] = nil
		client.getbroadcast():chat(("&d%s no longer afk"):format(player:getname()))
		pLastActivity[player].time = os.time()
	elseif (not pAfkList[player]) and (mode) then
		pAfkList[player] = true
		client.getbroadcast():chat(("&d%s went afk"):format(player:getname()))
	end
end

function onTick(tick)
	if os.time() % 1 == 0 then
		for player, lastActivity in pairs(pLastActivity) do
			if os.time() - lastActivity.time >= AFK_TIME*1000 then
				switchAFK(player, true)
			else
				switchAFK(player, false)
			end
		end
	end
end

function onRotate(player)
	pLastActivity[player].time = os.time()
end

function onMove(player)
	local playerMovements = pLastActivity[player]
	playerMovements.pastvec:set(playerMovements.currentvec:get())
	player:getposition(playerMovements.currentvec)
	local function calculate_coords(axis)
		local coord_diff = playerMovements.currentvec[axis] - playerMovements.pastvec[axis]
		if (coord_diff < 0) and (axis == "y") then
			return 0
		end
		return math.abs(coord_diff)
	end
	if (pAfkList[player]) and (not pLastActivity[player].washit) then
		if (calculate_coords('x') > PLAYER_AFK_THRESHOLD) or (calculate_coords("y") > PLAYER_AFK_THRESHOLD) or (calculate_coords("z") > PLAYER_AFK_THRESHOLD) then
			switchAFK(player, false)
		end
	end
end

function onPlayerClick(player, args)
	local enemyTarget = args.target
	if pAfkList[enemyTarget] then
		pLastActivity[enemyTarget].washit = true
	end
end

function onDisconnect(player)
	pAfkList[player] = nil
	pLastActivity[player] = nil
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
		pLastActivity[cl].time = os.time()
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

function onHandshake(cl)
	if cl:isop() then
		cl:setdispname("&c" .. cl:getname())
	end
	pLastActivity[cl] = {washit = false, pastvec = vector.float(), currentvec = cl:getpositiona(), time = os.time()}
	addClient(cl)
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
	AFK_TIME = 90
	PLAYER_AFK_THRESHOLD = 0.03125
	client.iterall(function(player)
		pLastActivity[player] = {washit = false, pastvec = vector.float(), currentvec = player:getpositiona(), time = os.time()}
		addClient(player)
	end)
end
