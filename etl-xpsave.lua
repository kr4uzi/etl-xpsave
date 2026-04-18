--[[
    author: https://github.com/sheldarr
    license: MIT
    name: etl-xpsave
    repository: https://github.com/kr4uzi/etl-xpsave
    version: 2.0
]]--

local luasql = require('luasql.sqlite3')

local MOD_NAME = "etl-xpsave"

local CONNECTIONS_STATUS = {
    disconnected = 0,
    connecting = 1,
    connected = 2
}

local SKILLS = {
    BATTLESENSE = 0,
    ENGINEERING = 1,
    MEDIC = 2,
    FIELDOPS = 3,
    LIGHTWEAPONS = 4,
    HEAVYWEAPONS = 5,
    COVERTOPS = 6
}

serverOptions = {
    maxPlayers = tonumber(et.trap_Cvar_Get("sv_maxclients")),
    basePath = string.gsub(et.trap_Cvar_Get("fs_basepath") .. "/" .. et.trap_Cvar_Get("fs_game") .. "/","\\","/"),
    homePath = string.gsub(et.trap_Cvar_Get("fs_homepath") .. "/" .. et.trap_Cvar_Get("fs_game") .. "/","\\","/"),
    xpSaveDelay = 60000,
    xpSaveFileName = "xpsave.sqlite3"
}

function round(number)
    return math.floor(number + 0.5)
end

function getPlayer(clientNumber)
    return {
        connectionStatus = et.gentity_get(clientNumber, "pers.connected"),
        guid = et.Info_ValueForKey(et.trap_GetUserinfo(clientNumber), "cl_guid"),
        name = et.Info_ValueForKey(et.trap_GetUserinfo(clientNumber), "name"),
        number = clientNumber,
        skills = {
            battlesense = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.BATTLESENSE)),
            engineering = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.ENGINEERING)),
            medic = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.MEDIC)),
            fieldops = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.FIELDOPS)),
            lightweapons = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.LIGHTWEAPONS)),
            heavyweapons = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.HEAVYWEAPONS)),
            covertops = round(et.gentity_get(clientNumber, "sess.skillpoints", SKILLS.COVERTOPS))
        }
    }
end

function initialize()
    local dbpath = serverOptions.basePath .. serverOptions.xpSaveFileName
    env = assert(luasql.sqlite3())
    con = assert(env:connect(dbpath))
    assert(con:execute[[
        CREATE TABLE IF NOT EXISTS `player` (
            `id` INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            `guid` TEXT NOT NULL UNIQUE,
            `ip` TEXT NOT NULL,
            `lastseen` INTEGER NOT NULL,
            `battlesense` INTEGER DEFAULT 0,
            `engineering` INTEGER DEFAULT 0,
            `medic` INTEGER DEFAULT 0,
            `fieldops` INTEGER DEFAULT 0,
            `lightweapons` INTEGER DEFAULT 0,
            `heavyweapons` INTEGER DEFAULT 0,
            `covertops` INTEGER DEFAULT 0
        );
    ]])
end

function setXpForPlayer(player)
    local cur = assert(con:execute("SELECT guid, battlesense, engineering, medic, fieldops, lightweapons, heavyweapons, covertops FROM player WHERE guid = '"..con:escape(player.guid).."'"))
    local playerXp = cur:fetch({}, "a")
    cur:close()

    if playerXp then
        et.G_Printf("BATTLESENSE %d ENGINEERING %d MEDIC %d FIELDOPS %d LIGHTWEAPONS %d HEAVYWEAPONS %d COVERTOPS %d\n",
            playerXp.battlesense, playerXp.engineering, playerXp.medic, playerXp.fieldops, playerXp.lightweapons,
            playerXp.heavyweapons, playerXp.covertops)
        sendMessageToPlayer(player, "^2OK\n")

        et.G_XP_Set (player.number, playerXp.battlesense, SKILLS.BATTLESENSE, 0)
        et.G_XP_Set (player.number, playerXp.engineering, SKILLS.ENGINEERING, 0)
        et.G_XP_Set (player.number, playerXp.medic, SKILLS.MEDIC, 0)
        et.G_XP_Set (player.number, playerXp.fieldops, SKILLS.FIELDOPS, 0)
        et.G_XP_Set (player.number, playerXp.lightweapons, SKILLS.LIGHTWEAPONS, 0)
        et.G_XP_Set (player.number, playerXp.heavyweapons, SKILLS.HEAVYWEAPONS, 0)
        et.G_XP_Set (player.number, playerXp.covertops, SKILLS.COVERTOPS, 0)
        return;
    end
end

function saveXpForPlayer(player)
    et.G_Printf("Saving XP for %s %s\n", player.name, player.guid)
    et.G_Printf("BATTLESENSE %d ENGINEERING %d MEDIC %d FIELDOPS %d LIGHTWEAPONS %d HEAVYWEAPONS %d COVERTOPS %d\n",
        player.skills.battlesense, player.skills.engineering, player.skills.medic, player.skills.fieldops, player.skills.lightweapons,
        player.skills.heavyweapons, player.skills.covertops)
    sendMessageToPlayer(player, "SAVING XP...\n")
    sendMessageToPlayer(player, "^2OK\n")

    local ip = et.Info_ValueForKey(et.trap_GetUserinfo(player.number), "ip")
    local query = string.format([[
        INSERT OR REPLACE INTO player (guid, ip, lastseen, battlesense, engineering, medic, fieldops, lightweapons, heavyweapons, covertops)
        VALUES (
            '%s',
            '%s',
            %d,
            %d, %d, %d, %d, %d, %d, %d
        )
    ]], con:escape(player.guid), con:escape(ip), os.time(),
        player.skills.battlesense, player.skills.engineering, player.skills.medic,
        player.skills.fieldops, player.skills.lightweapons, player.skills.heavyweapons,
        player.skills.covertops)

    assert(con:execute(query))
end

function saveXpForAllPlayers()
    for clientNumber = 0, serverOptions.maxPlayers - 1 do
        local player = getPlayer(clientNumber);

        if player.connectionStatus == CONNECTIONS_STATUS.connected then
            saveXpForPlayer(player)
        end
    end
end

function et.G_Printf(...)
    et.G_Print(string.format(...))
end

function sendMessageToPlayer(player, message, ...)
    et.trap_SendServerCommand(player.number, "cpm\"" .. string.format(message, ...) .. "\n\"")
end

function et_InitGame(levelTime, randomSeed, restart)
    et.G_Printf("et_InitGame [%d] [%d] [%d]\n", levelTime, randomSeed, restart)
    et.RegisterModname(MOD_NAME)
    initialize()
end

function et_ShutdownGame(restart)
    et.G_Printf("et_ShutdownGame [%s]\n", restart)

    saveXpForAllPlayers()
end

function et_RunFrame(levelTime)
    if levelTime % serverOptions.xpSaveDelay == 0 then
        saveXpForAllPlayers()
    end
end

function et_ClientDisconnect(clientNumber)
    et.G_Printf( "et_ClientDisconnect: [%d]\n", clientNumber)
    local player = getPlayer(clientNumber)

    et.G_Printf( "et_ClientDisconnect: [%d] %s\n", clientNumber, player.name)

    saveXpForPlayer(player)
end

function et_ClientBegin(clientNumber)
    local player = getPlayer(clientNumber)

    et.G_Printf( "et_ClientBegin: [%d] %s\n", clientNumber, player.name)
    sendMessageToPlayer(player, "Welcome %s (Stats Loaded) \n", player.name)

    setXpForPlayer(player)
end
