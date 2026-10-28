// Warcraft III real-battle screenshots: computer players play a normal melee game, the camera follows
// the fights, and for every screenshot the map writes every visible unit of our 48 types.
// In World Editor: a copy of a Blizzard melee map. Scenario -> Player Properties: players 2..N
// Controller = Computer (Race = Random). Select the "Melee Initialization" trigger,
// Edit -> Convert to Custom Text, delete all of its text and paste this whole file instead.
//
// Player 1 (you) gets no units and is never defeated, so you just watch. Every ~4 seconds the camera
// jumps to a fight (or a unit, or a base), all units freeze for a moment, and the map writes
// "UNIT|name|x|y|zoom|z" for every visible labeled unit (x, y = position relative to the camera target,
// z = how much higher its ground is than the ground under the camera target) to
// Documents\Warcraft III\CustomMapData\wc3dataset\shot_<number>.txt
// capture.py waits for that file and takes the screenshot.

function Dataset_Battle takes nothing returns nothing
    local integer array id
    local string array name
    local integer n = 0
    local group all = CreateGroup()
    local unit array fight
    local integer nf
    local unit array any
    local integer na
    local unit array base
    local integer nbase
    local unit u
    local unit focus
    local integer shot = 0
    local integer i
    local integer c
    local integer t
    local real cx
    local real cy
    local real zoom
    local real z0
    local location loc = Location(0, 0)
    local hashtable typeindex = InitHashtable()
    local rect area

    // ---- the 48 units (some classes have two forms), same names as dataset_trigger.j ----
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

    // unit type -> number in the list above (+1, so 0 means "not one of ours"); one lookup instead of 51
    // comparisons per unit, otherwise a late game with hundreds of units stops the script
    set c = 0
    loop
        exitwhen c >= n
        call SaveInteger(typeindex, 0, id[c], c + 1)
        set c = c + 1
    endloop

    // ---- a normal melee game, but player 1 only watches ----
    call FogEnable(false)
    call FogMaskEnable(false)
    call MeleeStartingVisibility()
    call MeleeStartingHeroLimit()
    call MeleeGrantHeroItems()
    call MeleeStartingResources()
    call MeleeClearExcessUnits()
    call MeleeStartingUnits()
    call MeleeStartingAI()
    // no MeleeInitVictoryDefeat(): nobody is ever defeated, so the game keeps going

    // write who is in the game to wc3dataset\players.txt (to check that every computer player got a base)
    call PreloadGenClear()
    call PreloadGenStart()
    set i = 0
    loop
        exitwhen i >= 12
        set t = 0
        call GroupEnumUnitsOfPlayer(all, Player(i), null)
        loop
            set u = FirstOfGroup(all)
            exitwhen u == null
            call GroupRemoveUnit(all, u)
            set t = t + 1
        endloop
        set c = 0
        if GetPlayerSlotState(Player(i)) == PLAYER_SLOT_STATE_PLAYING then
            set c = 1
        endif
        if GetPlayerController(Player(i)) == MAP_CONTROL_COMPUTER then
            call Preload("PLAYER|" + I2S(i + 1) + "|computer|playing=" + I2S(c) + "|units=" + I2S(t))
        elseif GetPlayerController(Player(i)) == MAP_CONTROL_USER then
            call Preload("PLAYER|" + I2S(i + 1) + "|user|playing=" + I2S(c) + "|units=" + I2S(t))
        endif
        set i = i + 1
    endloop
    call PreloadGenEnd("wc3dataset\\players.txt")
    call GroupEnumUnitsOfPlayer(all, Player(0), null)
    loop
        set u = FirstOfGroup(all)
        exitwhen u == null
        call GroupRemoveUnit(all, u)
        call RemoveUnit(u)
    endloop
    call TriggerSleepAction(30.0)
    call SetCameraField(CAMERA_FIELD_ROTATION, 90, 0)
    call SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, 304, 0)
    call SetCameraField(CAMERA_FIELD_ROLL, 0, 0)

    loop
        // find units that are fighting, any of our units, and buildings
        set nf = 0
        set na = 0
        set nbase = 0
        call GroupEnumUnitsInRect(all, bj_mapInitialPlayableArea, null)
        loop
            set u = FirstOfGroup(all)
            exitwhen u == null
            call GroupRemoveUnit(all, u)
            if GetWidgetLife(u) > 0.405 and not IsUnitHidden(u) then
                if IsUnitType(u, UNIT_TYPE_STRUCTURE) then
                    set base[nbase] = u
                    set nbase = nbase + 1
                else
                    set c = LoadInteger(typeindex, 0, GetUnitTypeId(u)) - 1
                    if c >= 0 then
                        set any[na] = u
                        set na = na + 1
                        if GetUnitCurrentOrder(u) == OrderId("attack") then
                            set fight[nf] = u
                            set nf = nf + 1
                        endif
                    endif
                endif
            endif
        endloop

        call TriggerSleepAction(0.0)    // a short wait also resets the script's work limit

        // camera: a fight most of the time, otherwise any unit or a base
        set c = GetRandomInt(1, 10)
        if nf > 0 and c <= 7 then
            set focus = fight[GetRandomInt(0, nf - 1)]
        elseif na > 0 and c <= 9 then
            set focus = any[GetRandomInt(0, na - 1)]
        elseif nbase > 0 then
            set focus = base[GetRandomInt(0, nbase - 1)]
        else
            set focus = null
        endif

        if focus != null then
            set cx = GetUnitX(focus) + GetRandomReal(-400, 400)
            set cy = GetUnitY(focus) + GetRandomReal(-250, 250)
            set zoom = GetRandomReal(1450, 1850)
            call PauseAllUnitsBJ(true)
            call TriggerSleepAction(0.0)
            call SetCameraPosition(cx, cy)
            call SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, zoom, 0)
            call TriggerSleepAction(0.6)

            // every visible unit of our 48 types near the camera
            call MoveLocation(loc, cx, cy)
            set z0 = GetLocationZ(loc)
            call PreloadGenClear()
            call PreloadGenStart()
            set area = Rect(cx - 1400, cy - 800, cx + 1400, cy + 1000)
            call GroupEnumUnitsInRect(all, area, null)
            call RemoveRect(area)
            loop
                set u = FirstOfGroup(all)
                exitwhen u == null
                call GroupRemoveUnit(all, u)
                if GetWidgetLife(u) > 0.405 and not IsUnitHidden(u) and IsUnitVisible(u, Player(0)) and not IsUnitInvisible(u, Player(0)) then
                    set c = LoadInteger(typeindex, 0, GetUnitTypeId(u)) - 1
                    if c >= 0 then
                        call MoveLocation(loc, GetUnitX(u), GetUnitY(u))
                        call Preload("UNIT|" + name[c] + "|" + R2S(GetUnitX(u) - cx) + "|" + R2S(GetUnitY(u) - cy) + "|" + R2S(zoom) + "|" + R2S(GetLocationZ(loc) - z0))
                    endif
                endif
            endloop
            call PreloadGenEnd("wc3dataset\\shot_" + I2S(shot) + ".txt")
            set shot = shot + 1
            call TriggerSleepAction(1.2)
            call PauseAllUnitsBJ(false)
        endif
        // let the game play on for a while
        call TriggerSleepAction(3.0)
    endloop
endfunction

function Trig_Melee_Initialization_Actions takes nothing returns nothing
    // only from the timer below, not a second time from "Run on Map Initialization"
    if GetTriggerEventId() == EVENT_GAME_TIMER_EXPIRED then
        call Dataset_Battle()
    endif
endfunction

function InitTrig_Melee_Initialization takes nothing returns nothing
    set gg_trg_Melee_Initialization = CreateTrigger()
    call TriggerRegisterTimerEventSingle(gg_trg_Melee_Initialization, 0.01)
    call TriggerAddAction(gg_trg_Melee_Initialization, function Trig_Melee_Initialization_Actions)
endfunction
