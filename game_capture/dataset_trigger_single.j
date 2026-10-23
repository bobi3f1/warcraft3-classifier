// One unit CLASS per scene, with one to three copies. Use capture_single.py.
// Replace the entire Melee Initialization custom-text trigger with this file.
// 48 classes x 32 rounds = 1536 scenes, about 52 minutes at 2 seconds each.

function Dataset_Run takes nothing returns nothing
    local integer array id
    local string array name
    local integer array first
    local integer array forms
    local group scene = CreateGroup()
    local unit u
    local integer i = 0
    local integer c
    local integer variant
    local integer shot = 0
    local integer round
    local integer copies
    local integer position
    local integer tries
    local integer failedSearches = 0
    local boolean safe
    local rect area
    local destructable tree
    local real cx
    local real cy
    local real x
    local real y
    local real offsetx
    local real offsety
    local real facing
    local real zoom
    local real minx = GetRectMinX(bj_mapInitialPlayableArea) + 1600
    local real maxx = GetRectMaxX(bj_mapInitialPlayableArea) - 1600
    local real miny = GetRectMinY(bj_mapInitialPlayableArea) + 1600
    local real maxy = GetRectMaxY(bj_mapInitialPlayableArea) - 1600

    set id[0] = 'hpea'
    set name[0] = "Human Peasant"
    set id[1] = 'hfoo'
    set name[1] = "Human Footman"
    set id[2] = 'hrif'
    set name[2] = "Human Rifleman"
    set id[3] = 'hkni'
    set name[3] = "Human Knight"
    set id[4] = 'hmpr'
    set name[4] = "Human Priest"
    set id[5] = 'hsor'
    set name[5] = "Human Sorceress"
    set id[6] = 'hspt'
    set name[6] = "Human Spell Breaker"
    set id[7] = 'hgyr'
    set name[7] = "Human Flying Machine"
    set id[8] = 'hmtm'
    set name[8] = "Human Mortar Team"
    set id[9] = 'hmtt'
    set name[9] = "Human Siege Engine"
    set id[10] = 'hgry'
    set name[10] = "Human Gryphon Rider"
    set id[11] = 'hdhw'
    set name[11] = "Human Dragonhawk Rider"
    set id[12] = 'opeo'
    set name[12] = "Orc Peon"
    set id[13] = 'ogru'
    set name[13] = "Orc Grunt"
    set id[14] = 'ohun'
    set name[14] = "Troll Headhunter"
    set id[15] = 'otbk'
    set name[15] = "Troll Headhunter"
    set id[16] = 'ocat'
    set name[16] = "Orc Demolisher"
    set id[17] = 'orai'
    set name[17] = "Orc Raider"
    set id[18] = 'okod'
    set name[18] = "Orc Kodo Beast"
    set id[19] = 'owyv'
    set name[19] = "Orc Wind Rider"
    set id[20] = 'otbr'
    set name[20] = "Troll Batrider"
    set id[21] = 'oshm'
    set name[21] = "Orc Shaman"
    set id[22] = 'odoc'
    set name[22] = "Troll Witch Doctor"
    set id[23] = 'ospw'
    set name[23] = "Tauren Spirit Walker"
    set id[24] = 'otau'
    set name[24] = "Orc Tauren"
    set id[25] = 'ewsp'
    set name[25] = "Night Elf Wisp"
    set id[26] = 'earc'
    set name[26] = "Night Elf Archer"
    set id[27] = 'esen'
    set name[27] = "Night Elf Huntress"
    set id[28] = 'ebal'
    set name[28] = "Night Elf Glaive Thrower"
    set id[29] = 'edry'
    set name[29] = "Night Elf Dryad"
    set id[30] = 'edoc'
    set name[30] = "Night Elf Druid of the Claw"
    set id[31] = 'edcm'
    set name[31] = "Night Elf Druid of the Claw"
    set id[32] = 'edot'
    set name[32] = "Night Elf Druid of the Talon"
    set id[33] = 'edtm'
    set name[33] = "Night Elf Druid of the Talon"
    set id[34] = 'emtg'
    set name[34] = "Night Elf Mountain Giant"
    set id[35] = 'ehip'
    set name[35] = "Night Elf Hippogryph"
    set id[36] = 'ehpr'
    set name[36] = "Night Elf Hippogryph Rider"
    set id[37] = 'efdr'
    set name[37] = "Night Elf Faerie Dragon"
    set id[38] = 'echm'
    set name[38] = "Night Elf Chimaera"
    set id[39] = 'uaco'
    set name[39] = "Undead Acolyte"
    set id[40] = 'ugho'
    set name[40] = "Undead Ghoul"
    set id[41] = 'ucry'
    set name[41] = "Undead Crypt Fiend"
    set id[42] = 'ugar'
    set name[42] = "Undead Gargoyle"
    set id[43] = 'umtw'
    set name[43] = "Undead Meat Wagon"
    set id[44] = 'uabo'
    set name[44] = "Undead Abomination"
    set id[45] = 'unec'
    set name[45] = "Undead Necromancer"
    set id[46] = 'uban'
    set name[46] = "Undead Banshee"
    set id[47] = 'uobs'
    set name[47] = "Undead Obsidian Statue"
    set id[48] = 'ubsp'
    set name[48] = "Undead Destroyer"
    set id[49] = 'ufro'
    set name[49] = "Undead Frost Wyrm"
    set id[50] = 'ushd'
    set name[50] = "Undead Shade"
    set first[0] = 0
    set forms[0] = 1
    set first[1] = 1
    set forms[1] = 1
    set first[2] = 2
    set forms[2] = 1
    set first[3] = 3
    set forms[3] = 1
    set first[4] = 4
    set forms[4] = 1
    set first[5] = 5
    set forms[5] = 1
    set first[6] = 6
    set forms[6] = 1
    set first[7] = 7
    set forms[7] = 1
    set first[8] = 8
    set forms[8] = 1
    set first[9] = 9
    set forms[9] = 1
    set first[10] = 10
    set forms[10] = 1
    set first[11] = 11
    set forms[11] = 1
    set first[12] = 12
    set forms[12] = 1
    set first[13] = 13
    set forms[13] = 1
    set first[14] = 14
    set forms[14] = 2
    set first[15] = 16
    set forms[15] = 1
    set first[16] = 17
    set forms[16] = 1
    set first[17] = 18
    set forms[17] = 1
    set first[18] = 19
    set forms[18] = 1
    set first[19] = 20
    set forms[19] = 1
    set first[20] = 21
    set forms[20] = 1
    set first[21] = 22
    set forms[21] = 1
    set first[22] = 23
    set forms[22] = 1
    set first[23] = 24
    set forms[23] = 1
    set first[24] = 25
    set forms[24] = 1
    set first[25] = 26
    set forms[25] = 1
    set first[26] = 27
    set forms[26] = 1
    set first[27] = 28
    set forms[27] = 1
    set first[28] = 29
    set forms[28] = 1
    set first[29] = 30
    set forms[29] = 2
    set first[30] = 32
    set forms[30] = 2
    set first[31] = 34
    set forms[31] = 1
    set first[32] = 35
    set forms[32] = 1
    set first[33] = 36
    set forms[33] = 1
    set first[34] = 37
    set forms[34] = 1
    set first[35] = 38
    set forms[35] = 1
    set first[36] = 39
    set forms[36] = 1
    set first[37] = 40
    set forms[37] = 1
    set first[38] = 41
    set forms[38] = 1
    set first[39] = 42
    set forms[39] = 1
    set first[40] = 43
    set forms[40] = 1
    set first[41] = 44
    set forms[41] = 1
    set first[42] = 45
    set forms[42] = 1
    set first[43] = 46
    set forms[43] = 1
    set first[44] = 47
    set forms[44] = 1
    set first[45] = 48
    set forms[45] = 1
    set first[46] = 49
    set forms[46] = 1
    set first[47] = 50
    set forms[47] = 1

    // Remove preplaced units and buildings; no unlabeled units remain in the scene.
    set i = 0
    loop
        exitwhen i >= bj_MAX_PLAYER_SLOTS
        call GroupEnumUnitsOfPlayer(scene, Player(i), null)
        loop
            set u = FirstOfGroup(scene)
            exitwhen u == null
            call GroupRemoveUnit(scene, u)
            call RemoveUnit(u)
        endloop
        set i = i + 1
    endloop
    call FogEnable(false)
    call FogMaskEnable(false)
    call SuspendTimeOfDay(true)
    call SetFloatGameState(GAME_STATE_TIME_OF_DAY, 12.0)
    call ClearSelection()
    call SetCameraField(CAMERA_FIELD_ROTATION, 90, 0)
    call SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, 304, 0)
    call SetCameraField(CAMERA_FIELD_ROLL, 0, 0)

    // Warm up all 51 models before the first capture marker.
    set i = 0
    loop
        exitwhen i >= 51
        set u = CreateUnit(Player(0), id[i], minx, miny, 0)
        call UnitAddAbility(u, 'Aloc')
        call GroupAddUnit(scene, u)
        set i = i + 1
    endloop
    call TriggerSleepAction(3.0)

    loop
        exitwhen shot >= 1536
        set c = ModuloInteger(shot, 48)
        set round = shot / 48
        // Each model form sees all eight facing angles before changing form.
        set variant = first[c] + ModuloInteger(round / 8, forms[c])
        set facing = 45.0 * ModuloInteger(round, 8) + GetRandomReal(-8, 8)
        set position = ModuloInteger(round, 9)
        set offsetx = (ModuloInteger(position, 3) - 1) * 220.0
        set offsety = (position / 3 - 1) * 140.0 - 70.0
        set copies = 1
        if round >= 16 then
            set copies = 2 + ModuloInteger(round / 8, 2)
        endif
        set zoom = GetRandomReal(1500, 1800)

        // Never accept the old unsafe fallback after 100 failed location attempts.
        set safe = false
        set tries = 0
        loop
            exitwhen safe or tries >= 300
            set cx = GetRandomReal(minx, maxx)
            set cy = GetRandomReal(miny, maxy)
            set area = Rect(cx - 900, cy - 900, cx + 900, cy + 650)
            set tree = RandomDestructableInRectSimpleBJ(area)
            call RemoveRect(area)
            set safe = tree == null
            set i = 0
            loop
                exitwhen i >= copies
                set x = cx + offsetx + (i - (copies - 1) / 2.0) * 340
                set y = cy + offsety
                if IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) then
                    set safe = false
                endif
                set i = i + 1
            endloop
            set tries = tries + 1
        endloop
        if safe then
            set failedSearches = 0
            // Keep the previous scene until a valid replacement is available.
            loop
                set u = FirstOfGroup(scene)
                exitwhen u == null
                call GroupRemoveUnit(scene, u)
                call RemoveUnit(u)
            endloop
            call ClearTextMessages()
            set i = 0
            loop
                exitwhen i >= copies
                set x = cx + offsetx + (i - (copies - 1) / 2.0) * 340
                set y = cy + offsety
                // Same owner keeps Shade visible; color varies independently of the class.
                set u = CreateUnit(Player(0), id[variant], x, y, facing + GetRandomReal(-5, 5))
                call UnitAddAbility(u, 'Aloc')
                call SetUnitColor(u, ConvertPlayerColor(GetRandomInt(0, 11)))
                call SetUnitAnimation(u, "stand")
                call GroupAddUnit(scene, u)
                set i = i + 1
            endloop
            call SetCameraPosition(cx, cy)
            call SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, zoom, 0)
            call ClearSelection()
            // Allow rendering to settle BEFORE announcing that the scene is ready.
            call TriggerSleepAction(1.00)
            call PreloadGenClear()
            call PreloadGenStart()
            call Preload(name[variant])
            call Preload("META|" + I2S(c) + "|" + I2S(round) + "|" + I2S(copies) + "|" + R2S(facing) + "|" + I2S(position) + "|" + R2S(zoom) + "|" + I2S(variant))
            call PreloadGenEnd("wc3single\\shot_" + I2S(shot) + ".txt")
            set shot = shot + 1
            call TriggerSleepAction(1.40)
        else
            set failedSearches = failedSearches + 1
            if failedSearches >= 5 then
                call DisplayTimedTextToPlayer(Player(0), 0, 0, 30, "Capture stopped: no clear area. Use a larger, open map.")
                return
            endif
            // Do not put warnings over screenshots from the next successful scene.
            call TriggerSleepAction(2.0)
        endif
    endloop
    call DisplayTimedTextToPlayer(Player(0), 0, 0, 30, "Single-class capture complete: 1536 scenes.")
endfunction

function Trig_Melee_Initialization_Actions takes nothing returns nothing
    if GetTriggerEventId() == EVENT_GAME_TIMER_EXPIRED then
        call Dataset_Run()
    endif
endfunction

function InitTrig_Melee_Initialization takes nothing returns nothing
    set gg_trg_Melee_Initialization = CreateTrigger()
    call TriggerRegisterTimerEventSingle(gg_trg_Melee_Initialization, 1.00)
    call TriggerAddAction(gg_trg_Melee_Initialization, function Trig_Melee_Initialization_Actions)
endfunction
