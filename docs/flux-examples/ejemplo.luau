-- Luau (el Lua de Roblox) en Flux Engine.
-- Ponelo en mods/TuMod/scripts/ (o en data/<canción>/) junto con utilidades.luau.
-- Los objetos del juego se usan directo: game.boyfriend.alpha = 0.5, FlxSprite.new(0, 0)...

local util = require('utilidades') -- carga utilidades.luau (está al lado de este archivo)

local texto
local cuadro
local golpes = 0
local mejorRacha = 0

function onCreatePost()
	texto = makeText(20, 120, 0, 'Golpes: 0', 24)
	texto.cameras = {game.camHUD} -- una tabla de Luau se convierte sola en lista de Haxe
	game:add(texto)

	cuadro = FlxSprite.new(20, 170)
	cuadro:makeGraphic(40, 40, 0xFF33CCFF)
	cuadro.cameras = {game.camHUD}
	game:add(cuadro)

	-- task.wait pausa solo esta función: el juego sigue y después continúa acá
	game.boyfriend.alpha = 0
	task.wait(0.5)
	tween(game.boyfriend, {alpha = 1}, 0.4, 'quadOut')
end

function onCountdownStarted()
	-- las listas de Haxe se recorren con for (empiezan en 1, como en Lua)
	for i, strum in game.opponentStrums.members do
		strum.alpha = 0.5
	end
end

function goodNoteHit(note)
	if note.isSustainNote then return end
	golpes += 1
	mejorRacha = math.max(mejorRacha, game.combo)
	texto.text = `Golpes: {golpes}  Mejor racha: {mejorRacha}  {util.tiempo(Conductor.songPosition)}`
	if golpes % 50 == 0 then
		cameraFlash('hud', 0xFFFFFFFF, 0.3)
	end
end

function onBeatHit()
	cuadro.angle += 45
	if curBeat % 4 == 0 then
		cuadro.scale:set(1.3, 1.3)
		tween(cuadro.scale, {x = 1, y = 1}, 0.2, 'quadOut')
	end
end

function onEndSong()
	print(`Terminó con {golpes} golpes`)
end
