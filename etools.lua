allowHotReload(true)
-- all lua commands for cserver you can find in igor725/cs-lua/src
function delcommands()
	command.remove('clear')
	command.remove('tp')
	command.remove('tppos')
	command.remove('afk')
	command.remove('announce')
	command.remove('clients')
end

preReload = delcommands

function onStop()
	delcommands()
	client.iterall(function(players)
		if players:isop() then
			players:setdispname("&c"..players:getname())
		else
			players:setdispname(players:getname())
		end
		players:update()
	end)
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
	if pAfkList[subj].isAfk then
		pLastActivity[subj].washit = true
	end
	if pAfkList[targ].isAfk then
		pLastActivity[targ].washit = true
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
	local timestamp = os.time()
	if mode == nil then
		if timestamp - pAfkList[player].callTime <= AFK_TIMEOUT then
			return ("&cYou should wait before using &e/afk&c again")
		end
		if pLastActivity[player].isMoving then
			return ("&cYou can't use this command while moving!")
		end
		mode = true
		pLastActivity[player].time = (timestamp - AFK_TIME) -- чтобы его из афк не выкинуло
		pAfkList[player].callTime = timestamp
	end
	if (pAfkList[player].isAfk) and (not mode) then
		pAfkList[player].isAfk = false
		client.getbroadcast():chat(("%s&d is no longer afk"):format(pAfkList[player].name))
		pLastActivity[player].time = timestamp
		player:setdispname(pAfkList[player].name)
		pAfkList[player].name = nil
		if AFK_SAFE_MODE then
			player:setpvp(pAfkList[player].pvpmode)
		end
		client.iterall(function(otherPlayer)
			otherPlayer:update()
		end)
	elseif (not pAfkList[player].isAfk) and (mode) then
		pAfkList[player].isAfk = true
		pAfkList[player].name = player:getdispname()
		if not pAfkList[player].name:match("&%a+.+") then -- гандон без префикса фуу лох
			pAfkList[player].name = "&f"..pAfkList[player].name
		end
		client.getbroadcast():chat(("%s&d went afk"):format(pAfkList[player].name))
		player:setdispname("&d[AFK] " .. pAfkList[player].name)
		pLastActivity[player].washit = true
		if AFK_SAFE_MODE then
			pAfkList[player].pvpmode = player:isinpvp()
			player:setpvp(false)
		end
		client.iterall(function(otherPlayer)
			otherPlayer:update()
		end)
	end
end

function onTick(tick)
	timer = timer + tick
	for player, lastActivity in pairs(pLastActivity) do
		local timestamp = os.time()
		if timestamp % 1 == 0 then
			if timestamp - lastActivity.time >= AFK_TIME then
				switchAFK(player, true)
			else
				switchAFK(player, false)
			end
		end
		if lastActivity.isMoving then
			if timer - lastActivity.lastTickMovement > 500 then
				lastActivity.isMoving = false
				if lastActivity.washit then
					lastActivity.washit = false
				end
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
	playerMovements.isMoving = true
	playerMovements.lastTickMovement = timer
	if (not pAfkList[player].isAfk) then
		playerMovements.time = os.time()
	end
	local function calculate_coords(axis)
		local coord_diff = playerMovements.currentvec[axis] - playerMovements.pastvec[axis]
		if (coord_diff < 0) and (axis == "y") then
			return 0
		end
		return math.abs(coord_diff)
	end
	if (not playerMovements.washit) and (pAfkList[player].isAfk) then
		if (calculate_coords('x') > PLAYER_AFK_THRESHOLD) or (calculate_coords("y") > PLAYER_AFK_THRESHOLD) or (calculate_coords("z") > PLAYER_AFK_THRESHOLD) then
			switchAFK(player, false)
		end
	end
end

function onPlayerClick(player, args)
	local enemyTarget = args.target
	if (enemyTarget) and (pAfkList[enemyTarget].isAfk) then
		pLastActivity[enemyTarget].washit = true
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
	if pAfkList[cl].isAfk then
		cl:setdispname(pAfkList[cl].name)
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

function onDisconnect(player)
	pAfkList[player] = nil
	pLastActivity[player] = nil
	if not player:isinstate(PLAYER_STATE_INGAME) then return end
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


function onConnect(player)
	pAfkList[player] = {isAfk = false, callTime = 0}
	pLastActivity[player] = {lastTickMovement = timer, washit = false, pastvec = vector.float(), currentvec = vector.float(), time = os.time()}
end

function onHandshake(cl)
	if cl:isop() then
		cl:setdispname("&c" .. cl:getname())
	end
	addClient(cl)
end

function clearChat(caller)
	for i=1, 12 do
		caller:chat(" ")
	end
end

function onStart()
	command.add('clear', 'Clear chat', CMDF_CLIENT, clearChat)
	command.add('tp', 'Teleport to player', CMDF_OP, tpPlayers)
	command.add('tppos', 'Teleport to specific coords', CMDF_OP, tpPosition)
	command.add('afk', 'Went to afk', CMDF_CLIENT, switchAFK)
	command.add('announce', 'Make an announcement', CMDF_OP, makeAnnounce)
	command.add('clients', 'List of the clients player are using, and who uses which client', CMDF_CLIENT, clients)
	coordsPattern = '^(.-)%s?([-+]?%d*%.?%d*)%s+([-+]?%d*%.?%d*)%s+([-+]?%d*%.?%d*)$'
	clients = {}
	pAfkList = pAfkList or {}
	pLastActivity = pLastActivity or {}
	plSettings = config.new{
		name = "etools.cfg",
		items = {
			{
				name = "afk-time",
				comment = "Amount of seconds after which the player will be set AFK (in seconds)",
				type = CONFIG_TYPE_INT16,
				default = 90
			},
			{
				name = "afk-timeout",
				comment = "Timeout after a command call (in seconds)",
				type = CONFIG_TYPE_INT16,
				default = 15
			},
			{
				name = "afk-safe-mode",
				comment = "Disable pvp for player who's AFK (requires cs-survival plugin)",
				type = CONFIG_TYPE_BOOL,
				default = true
			}
		}
	}
	plSettings:save(not plSettings:load())
	AFK_TIME = plSettings:get("afk-time")
	AFK_TIMEOUT = plSettings:get("afk-timeout")
	AFK_SAFE_MODE = plSettings:get("afk-safe-mode")
	PLAYER_AFK_THRESHOLD = 0.0625
	timer = timer or 0
	client.iterall(function(player)
		pLastActivity[player] = pLastActivity[player] or {lastTickMovement = timer, washit = false, pastvec = vector.float(), currentvec = vector.float(), time = os.time()}
		pAfkList[player] = pAfkList[player] or {isAfk = false, callTime = 0}
		addClient(player)
	end)
end

function postStart()
	isSurvivalEnabled = survival.init()
	if (AFK_SAFE_MODE) and (not isSurvivalEnabled) then
		print("ETools: afk-safe-mode requires a cs-survival plugin (not detected)")
		AFK_SAFE_MODE = false
	end
end