-- Corre mientras el menú principal está abierto: mods/TuMod/states/MainMenuState.luau
-- "game" es el menú.

local texto

function onCreatePost()
	texto = makeText(10, FlxG.height - 60, 0, 'Flux Engine + Luau', 18)
	game:add(texto)

	-- un bucle que parpadea para siempre sin trabar el menú
	task.spawn(function()
		while true do
			tween(texto, {alpha = 0.3}, 0.6)
			task.wait(0.6)
			tween(texto, {alpha = 1}, 0.6)
			task.wait(0.6)
		end
	end)
end

function onUpdate(elapsed)
	if keyboardJustPressed('L') then
		texto.text = `Luau {math.random(1, 100)}`
	end
end
