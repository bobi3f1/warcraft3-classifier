// Warcraft III dataset generator.
// In World Editor: select the "Melee Initialization" trigger, Edit -> Convert to Custom Text,
// delete all of its text and paste this whole file instead.
//
// Every 1.5 seconds the map places 1-6 random units on a random spot, moves the camera there
// and writes the names of the units to
// Documents\Warcraft III\CustomMapData\wc3dataset\shot_<number>.txt
// capture.py waits for that file and takes the screenshot.

function Dataset_Run takes nothing returns nothing
    local integer array id
    local string array name
    local integer n = 0
    local integer array building
    local integer nb = 0
    local string array anim
    local group scene = CreateGroup()
    local unit u
    local integer shot = 0
    local integer k
    local integer i
    local integer c
    local integer tries
    local real cx
    local real cy
    local real minx = GetRectMinX(bj_mapInitialPlayableArea) + 1500
    local real maxx = GetRectMaxX(bj_mapInitialPlayableArea) - 1500
    local real miny = GetRectMinY(bj_mapInitialPlayableArea) + 1500
    local real maxy = GetRectMaxY(bj_mapInitialPlayableArea) - 1500

    // ---- the 48 units (some classes have two forms) ----
    set id[n] = 'hpea'
    set name[n] = "Human Peasant"
    set n = n + 1
    set id[n] = 'hfoo'
    set name[n] = "Human Footman"
    set n = n + 1
    set id[n] = 'hrif'
    set name[n] = "Human Rifleman"
    set n = n + 1
    set id[n] = 'hkni'
    set name[n] = "Human Knight"
    set n = n + 1
    set id[n] = 'hmpr'
    set name[n] = "Human Priest"
    set n = n + 1
    set id[n] = 'hsor'
    set name[n] = "Human Sorceress"
    set n = n + 1
    set id[n] = 'hspt'
    set name[n] = "Human Spell Breaker"
    set n = n + 1
    set id[n] = 'hgyr'
    set name[n] = "Human Flying Machine"
    set n = n + 1
    set id[n] = 'hmtm'
    set name[n] = "Human Mortar Team"
    set n = n + 1
    set id[n] = 'hmtt'
    set name[n] = "Human Siege Engine"
    set n = n + 1
    set id[n] = 'hgry'
    set name[n] = "Human Gryphon Rider"
    set n = n + 1
    set id[n] = 'hdhw'
    set name[n] = "Human Dragonhawk Rider"
    set n = n + 1

    set id[n] = 'opeo'
    set name[n] = "Orc Peon"
    set n = n + 1
    set id[n] = 'ogru'
    set name[n] = "Orc Grunt"
    set n = n + 1
    set id[n] = 'ohun'
    set name[n] = "Troll Headhunter"
    set n = n + 1
    set id[n] = 'otbk'
    set name[n] = "Troll Headhunter"
    set n = n + 1
    set id[n] = 'ocat'
    set name[n] = "Orc Demolisher"
    set n = n + 1
    set id[n] = 'orai'
    set name[n] = "Orc Raider"
    set n = n + 1
    set id[n] = 'okod'
    set name[n] = "Orc Kodo Beast"
    set n = n + 1
    set id[n] = 'owyv'
    set name[n] = "Orc Wind Rider"
    set n = n + 1
    set id[n] = 'otbr'
    set name[n] = "Troll Batrider"
    set n = n + 1
    set id[n] = 'oshm'
    set name[n] = "Orc Shaman"
    set n = n + 1
    set id[n] = 'odoc'
    set name[n] = "Troll Witch Doctor"
    set n = n + 1
    set id[n] = 'ospw'
    set name[n] = "Tauren Spirit Walker"
    set n = n + 1
    set id[n] = 'otau'
    set name[n] = "Orc Tauren"
    set n = n + 1

    set id[n] = 'ewsp'
    set name[n] = "Night Elf Wisp"
    set n = n + 1
    set id[n] = 'earc'
    set name[n] = "Night Elf Archer"
    set n = n + 1
    set id[n] = 'esen'
    set name[n] = "Night Elf Huntress"
    set n = n + 1
    set id[n] = 'ebal'
    set name[n] = "Night Elf Glaive Thrower"
    set n = n + 1
    set id[n] = 'edry'
    set name[n] = "Night Elf Dryad"
    set n = n + 1
    set id[n] = 'edoc'
    set name[n] = "Night Elf Druid of the Claw"
    set n = n + 1
    set id[n] = 'edcm'
    set name[n] = "Night Elf Druid of the Claw"
    set n = n + 1
    set id[n] = 'edot'
    set name[n] = "Night Elf Druid of the Talon"
    set n = n + 1
    set id[n] = 'edtm'
    set name[n] = "Night Elf Druid of the Talon"
    set n = n + 1
    set id[n] = 'emtg'
    set name[n] = "Night Elf Mountain Giant"
    set n = n + 1
    set id[n] = 'ehip'
    set name[n] = "Night Elf Hippogryph"
    set n = n + 1
    set id[n] = 'ehpr'
    set name[n] = "Night Elf Hippogryph Rider"
    set n = n + 1
    set id[n] = 'efdr'
    set name[n] = "Night Elf Faerie Dragon"
    set n = n + 1
    set id[n] = 'echm'
    set name[n] = "Night Elf Chimaera"
    set n = n + 1

    set id[n] = 'uaco'
    set name[n] = "Undead Acolyte"
    set n = n + 1
    set id[n] = 'ugho'
    set name[n] = "Undead Ghoul"
    set n = n + 1
    set id[n] = 'ucry'
    set name[n] = "Undead Crypt Fiend"
    set n = n + 1
    set id[n] = 'ugar'
    set name[n] = "Undead Gargoyle"
    set n = n + 1
    set id[n] = 'umtw'
    set name[n] = "Undead Meat Wagon"
    set n = n + 1
    set id[n] = 'uabo'
    set name[n] = "Undead Abomination"
    set n = n + 1
    set id[n] = 'unec'
    set name[n] = "Undead Necromancer"
    set n = n + 1
    set id[n] = 'uban'
    set name[n] = "Undead Banshee"
    set n = n + 1
    set id[n] = 'uobs'
    set name[n] = "Undead Obsidian Statue"
    set n = n + 1
    set id[n] = 'ubsp'
    set name[n] = "Undead Destroyer"
    set n = n + 1
    set id[n] = 'ufro'
    set name[n] = "Undead Frost Wyrm"
    set n = n + 1
    set id[n] = 'ushd'
    set name[n] = "Undead Shade"
    set n = n + 1

    // ---- buildings: shown sometimes, never labeled (the model must ignore them) ----
    set building[0] = 'hbar'
    set building[1] = 'htow'
    set building[2] = 'hhou'
    set building[3] = 'obar'
    set building[4] = 'ogre'
    set building[5] = 'otrb'
    set building[6] = 'eaom'
    set building[7] = 'etol'
    set building[8] = 'emow'
    set building[9] = 'usep'
    set building[10] = 'unpl'
    set building[11] = 'uzig'
    set nb = 12

    set anim[0] = "stand"
    set anim[1] = "walk"
    set anim[2] = "attack"

    // ---- clean start: no fog, no creeps, fixed time of day ----
    call FogEnable(false)
    call FogMaskEnable(false)
    call SuspendTimeOfDay(true)
    call GroupEnumUnitsOfPlayer(scene, Player(PLAYER_NEUTRAL_AGGRESSIVE), null)
    loop
        set u = FirstOfGroup(scene)
        exitwhen u == null
        call GroupRemoveUnit(scene, u)
        call RemoveUnit(u)
    endloop

    loop
        // remove the previous scene
        loop
            set u = FirstOfGroup(scene)
            exitwhen u == null
            call GroupRemoveUnit(scene, u)
            call RemoveUnit(u)
        endloop

        // random walkable spot
        set tries = 0
        loop
            set cx = GetRandomReal(minx, maxx)
            set cy = GetRandomReal(miny, maxy)
            set tries = tries + 1
            exitwhen tries > 50 or not IsTerrainPathable(cx, cy, PATHING_TYPE_WALKABILITY)
        endloop

        // day most of the time, sometimes night
        if GetRandomInt(1, 5) == 1 then
            call SetFloatGameState(GAME_STATE_TIME_OF_DAY, GetRandomReal(19.0, 23.5))
        else
            call SetFloatGameState(GAME_STATE_TIME_OF_DAY, GetRandomReal(7.0, 17.0))
        endif

        call PreloadGenClear()
        call PreloadGenStart()

        // 1-6 units side by side, random team color, facing and animation
        set k = GetRandomInt(1, 6)
        set i = 0
        loop
            exitwhen i >= k
            set c = GetRandomInt(0, n - 1)
            if id[c] == 'ushd' then
                set u = CreateUnit(Player(0), id[c], cx - 550 + 1100.0 * (i + 0.5) / k + GetRandomReal(-60, 60), cy + GetRandomReal(-150, 300), GetRandomReal(0, 360))
            else
                set u = CreateUnit(Player(GetRandomInt(0, 11)), id[c], cx - 550 + 1100.0 * (i + 0.5) / k + GetRandomReal(-60, 60), cy + GetRandomReal(-150, 300), GetRandomReal(0, 360))
            endif
            call UnitAddAbility(u, 'Aloc')
            call SetUnitAnimation(u, anim[GetRandomInt(0, 2)])
            call GroupAddUnit(scene, u)
            call Preload(name[c])
            set i = i + 1
        endloop

        // sometimes a building in the background
        if GetRandomInt(1, 2) == 1 then
            set u = CreateUnit(Player(GetRandomInt(0, 11)), building[GetRandomInt(0, nb - 1)], cx + GetRandomReal(-700, 700), cy + 650, 270)
            call UnitAddAbility(u, 'Aloc')
            call GroupAddUnit(scene, u)
        endif

        call SetCameraPosition(cx, cy)
        call SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, GetRandomReal(1350, 1900), 0)
        call PreloadGenEnd("wc3dataset\\shot_" + I2S(shot) + ".txt")
        set shot = shot + 1
        call TriggerSleepAction(1.5)
    endloop
endfunction

function Trig_Melee_Initialization_Actions takes nothing returns nothing
    call Dataset_Run()
endfunction

function InitTrig_Melee_Initialization takes nothing returns nothing
    set gg_trg_Melee_Initialization = CreateTrigger()
    call TriggerRegisterTimerEventSingle(gg_trg_Melee_Initialization, 1.00)
    call TriggerAddAction(gg_trg_Melee_Initialization, function Trig_Melee_Initialization_Actions)
endfunction
