// Warcraft III dataset generator.
// In World Editor: select the "Melee Initialization" trigger, Edit -> Convert to Custom Text,
// delete all of its text and paste this whole file instead.
//
// Every few seconds the map builds a new scene on a random spot and moves the camera there:
// 1-8 random units in a row, in a crowded group, as an army of one type, or as two armies
// fighting (they can't die), sometimes with unlabeled heroes, a building and spell effects.
// Then it freezes the units and writes every labeled unit to
// Documents\Warcraft III\CustomMapData\wc3dataset\shot_<number>.txt
// as "UNIT|name|x|y|zoom|z" (x, y = position relative to the camera target, z = how much higher the
// unit's ground is than the ground under the camera target), so capture.py can
// compute where each unit is on the screen (boxes for the detector).
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
    local real x
    local real y
    local real zoom
    local real a
    local real r
    local integer j
    local integer mode
    local integer side = 0
    local integer pa
    local integer pb
    local integer army
    local integer owner
    local integer array hero
    local integer nh = 0
    local string array fxpath
    local integer nfx = 0
    local effect array fx
    local integer nfxon = 0
    local unit array su
    local string array sn
    local integer ns = 0
    local location loc = Location(0, 0)
    local real z0
    local rect area
    local destructable tree
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

    // ---- heroes: shown sometimes, never labeled (they look like big versions of normal units) ----
    set hero[0] = 'Hamg'
    set hero[1] = 'Hmkg'
    set hero[2] = 'Hpal'
    set hero[3] = 'Hblm'
    set hero[4] = 'Obla'
    set hero[5] = 'Ofar'
    set hero[6] = 'Otch'
    set hero[7] = 'Oshd'
    set hero[8] = 'Edem'
    set hero[9] = 'Ekee'
    set hero[10] = 'Emoo'
    set hero[11] = 'Ewar'
    set hero[12] = 'Udea'
    set hero[13] = 'Ulic'
    set hero[14] = 'Udre'
    set hero[15] = 'Ucrl'
    set nh = 16

    // ---- spell effects drawn over the scene (a wrong path just shows nothing) ----
    set fxpath[0] = "Abilities\\Spells\\Human\\ThunderClap\\ThunderClapCaster.mdl"
    set fxpath[1] = "Abilities\\Spells\\Orc\\WarStomp\\WarStompCaster.mdl"
    set fxpath[2] = "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl"
    set fxpath[3] = "Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl"
    set fxpath[4] = "Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl"
    set fxpath[5] = "Objects\\Spawnmodels\\Human\\HumanLargeDeathExplode\\HumanLargeDeathExplode.mdl"
    set nfx = 6

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

    // load every model once now, so the game doesn't freeze when a unit appears for the first time
    // (they are removed together with the first scene)
    set i = 0
    loop
        exitwhen i >= n
        call GroupAddUnit(scene, CreateUnit(Player(0), id[i], minx, miny, 0))
        set i = i + 1
    endloop
    set i = 0
    loop
        exitwhen i >= nb
        call GroupAddUnit(scene, CreateUnit(Player(0), building[i], minx, miny, 0))
        set i = i + 1
    endloop
    set i = 0
    loop
        exitwhen i >= nh
        call GroupAddUnit(scene, CreateUnit(Player(0), hero[i], minx, miny, 0))
        set i = i + 1
    endloop
    call TriggerSleepAction(2.0)

    // fixed camera angle (the game's default), the box formula in the notebooks depends on it
    call SetCameraField(CAMERA_FIELD_ROTATION, 90, 0)
    call SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, 304, 0)
    call SetCameraField(CAMERA_FIELD_ROLL, 0, 0)

    loop
        // remove the previous scene: units, heroes, buildings and spell effects
        loop
            set u = FirstOfGroup(scene)
            exitwhen u == null
            call GroupRemoveUnit(scene, u)
            call RemoveUnit(u)
        endloop
        set i = 0
        loop
            exitwhen i >= nfxon
            call DestroyEffect(fx[i])
            set i = i + 1
        endloop
        set nfxon = 0
        set ns = 0
        call ClearSelection()

        // random walkable spot with no trees (or other destructables) where the units will stand,
        // or in front of them - trees closer to the camera would hide the units
        set tries = 0
        loop
            set cx = GetRandomReal(minx, maxx)
            set cy = GetRandomReal(miny, maxy)
            set tries = tries + 1
            set area = Rect(cx - 750, cy - 650, cx + 750, cy + 400)
            set tree = RandomDestructableInRectSimpleBJ(area)
            call RemoveRect(area)
            exitwhen tries > 100 or (tree == null and not IsTerrainPathable(cx, cy, PATHING_TYPE_WALKABILITY))
        endloop

        // day most of the time, sometimes night
        if GetRandomInt(1, 5) == 1 then
            call SetFloatGameState(GAME_STATE_TIME_OF_DAY, GetRandomReal(19.0, 23.5))
        else
            call SetFloatGameState(GAME_STATE_TIME_OF_DAY, GetRandomReal(7.0, 17.0))
        endif
        set zoom = GetRandomReal(1350, 1900)

        // how the units stand: 0 = in a row (30%), 1 = crowded group (30%),
        // 2 = two armies fighting (20%), 3 = an army of one type plus one other unit (20%)
        set mode = GetRandomInt(0, 9)
        if mode <= 2 then
            set mode = 0
        elseif mode <= 5 then
            set mode = 1
        elseif mode <= 7 then
            set mode = 2
        else
            set mode = 3
        endif
        set k = GetRandomInt(1, 8)
        set army = GetRandomInt(0, n - 1)
        set pa = GetRandomInt(0, 11)
        set pb = ModuloInteger(pa + GetRandomInt(1, 11), 12)
        if mode == 2 then
            call SetPlayerAllianceStateBJ(Player(pa), Player(pb), bj_ALLIANCE_UNALLIED)
            call SetPlayerAllianceStateBJ(Player(pb), Player(pa), bj_ALLIANCE_UNALLIED)
            if k < 2 then
                set k = 2
            endif
        endif

        set i = 0
        loop
            exitwhen i >= k
            set c = GetRandomInt(0, n - 1)
            if mode == 3 and i < k - 1 then
                set c = army
            endif
            if mode == 0 then
                set x = cx - 550 + 1100.0 * (i + 0.5) / k + GetRandomReal(-60, 60)
                set y = cy + GetRandomReal(-300, 150)
            elseif mode == 2 then
                set side = ModuloInteger(i, 2)
                set x = cx - 350 + 700 * side + GetRandomReal(-150, 150)
                set y = cy - 75 + GetRandomReal(-200, 200)
            else
                set a = GetRandomReal(0, 2 * bj_PI)
                set r = GetRandomReal(0, 100 + 40 * k)
                set x = cx + r * Cos(a)
                set y = cy - 75 + r * Sin(a) * 0.7
            endif
            // the Shade is invisible to everyone but its owner, so it always belongs to us
            if id[c] == 'ushd' then
                set owner = 0
            elseif mode == 2 and side == 0 then
                set owner = pa
            elseif mode == 2 then
                set owner = pb
            else
                set owner = GetRandomInt(0, 11)
            endif
            set u = CreateUnit(Player(owner), id[c], x, y, GetRandomReal(0, 360))
            if mode == 2 then
                // they really fight (attack animations, spells, blood), but nobody dies before the screenshot
                call BlzSetUnitMaxHP(u, 100000)
                call SetUnitState(u, UNIT_STATE_LIFE, 100000)
                call IssuePointOrder(u, "attack", cx, cy - 75)
            else
                call UnitAddAbility(u, 'Aloc')
                call SetUnitAnimation(u, anim[GetRandomInt(0, 2)])
            endif
            call GroupAddUnit(scene, u)
            set su[ns] = u
            set sn[ns] = name[c]
            set ns = ns + 1
            set i = i + 1
        endloop

        // sometimes 1-2 heroes (not labeled: the model must learn they are not one of the 48 units)
        if GetRandomInt(1, 3) == 1 then
            set j = GetRandomInt(1, 2)
            loop
                exitwhen j <= 0
                set u = CreateUnit(Player(GetRandomInt(0, 11)), hero[GetRandomInt(0, nh - 1)], cx + GetRandomReal(-500, 500), cy - 75 + GetRandomReal(-250, 250), GetRandomReal(0, 360))
                call UnitAddAbility(u, 'Aloc')
                call SetUnitAnimation(u, anim[GetRandomInt(0, 2)])
                call GroupAddUnit(scene, u)
                set j = j - 1
            endloop
        endif

        // sometimes a building in the background
        if GetRandomInt(1, 2) == 1 then
            set u = CreateUnit(Player(GetRandomInt(0, 11)), building[GetRandomInt(0, nb - 1)], cx + GetRandomReal(-700, 700), cy + 650, 270)
            call UnitAddAbility(u, 'Aloc')
            call GroupAddUnit(scene, u)
        endif

        call SetCameraPosition(cx, cy)
        call SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, zoom, 0)
        if mode == 2 then
            call TriggerSleepAction(1.2)
        endif

        // sometimes our fighting units are selected (green circles; Aloc units can't be selected)
        if GetRandomInt(1, 3) == 1 then
            set i = 0
            loop
                exitwhen i >= ns
                if GetOwningPlayer(su[i]) == Player(0) then
                    call SelectUnit(su[i], true)
                endif
                set i = i + 1
            endloop
        endif

        // sometimes spell effects on top of the scene
        if GetRandomInt(1, 3) == 1 then
            set j = GetRandomInt(1, 3)
            loop
                exitwhen j <= 0
                set fx[nfxon] = AddSpecialEffect(fxpath[GetRandomInt(0, nfx - 1)], cx + GetRandomReal(-450, 450), cy - 75 + GetRandomReal(-250, 250))
                set nfxon = nfxon + 1
                set j = j - 1
            endloop
        endif

        // freeze the units and write where each labeled unit really is now
        // (the game pushes units apart when they are created on top of each other, and fighters move)
        call MoveLocation(loc, cx, cy)
        set z0 = GetLocationZ(loc)
        call PreloadGenClear()
        call PreloadGenStart()
        set i = 0
        loop
            exitwhen i >= ns
            call PauseUnit(su[i], true)
            call MoveLocation(loc, GetUnitX(su[i]), GetUnitY(su[i]))
            call Preload("UNIT|" + sn[i] + "|" + R2S(GetUnitX(su[i]) - cx) + "|" + R2S(GetUnitY(su[i]) - cy) + "|" + R2S(zoom) + "|" + R2S(GetLocationZ(loc) - z0))
            set i = i + 1
        endloop
        call PreloadGenEnd("wc3dataset\\shot_" + I2S(shot) + ".txt")
        set shot = shot + 1
        call TriggerSleepAction(1.5)
    endloop
endfunction

function Trig_Melee_Initialization_Actions takes nothing returns nothing
    // only from the 1-second timer below, not a second time from "Run on Map Initialization"
    if GetTriggerEventId() == EVENT_GAME_TIMER_EXPIRED then
        call Dataset_Run()
    endif
endfunction

function InitTrig_Melee_Initialization takes nothing returns nothing
    set gg_trg_Melee_Initialization = CreateTrigger()
    call TriggerRegisterTimerEventSingle(gg_trg_Melee_Initialization, 1.00)
    call TriggerAddAction(gg_trg_Melee_Initialization, function Trig_Melee_Initialization_Actions)
endfunction
