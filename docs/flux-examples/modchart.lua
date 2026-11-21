-- modchart.lua: ejemplo de modchart con FunkinModchart.
-- Va en mods/TuMod/data/<canción>/ (solo corre en esa canción).
-- Los beats empiezan en 0. jugador: 0 = oponente, 1 = jugador, nada = los dos.

function onCreatePost()
	-- las flechas ya existen en onCreatePost (si la canción empieza con un diálogo, usa onCountdownStarted)
	startModchart()

	addModifier('drunk')     -- las flechas se mueven de lado a lado
	addModifier('tipsy')     -- las flechas suben y bajan
	addModifier('reverse')   -- 1 = las flechas van al revés (como el downscroll)
	addModifier('transform') -- mover las flechas: valores 'x', 'y' y 'z'

	-- beat 8: el jugador se pone borracho en 4 beats
	easeModifier('drunk', 8, 4, 1, 'quadOut', 1)

	-- beat 16: tipsy para los dos, en 2 beats
	easeModifier('tipsy', 16, 2, 0.6, 'sineInOut')

	-- beat 24: todo vuelve a la normalidad
	easeModifier('drunk', 24, 2, 0, 'quadIn')
	easeModifier('tipsy', 24, 2, 0, 'quadIn')

	-- beat 32: el oponente con las flechas al revés, de golpe
	setModifier('reverse', 32, 1, 0)

	-- beat 40: las flechas del jugador 100 píxeles a la izquierda
	easeModifier('x', 40, 1, -100, 'backOut', 1)

	-- beat 48: llama a la función flash
	modchartCallback(48, 'flash')

	-- beat 56: todo como al principio
	setModifier('reverse', 56, 0, 0)
	easeModifier('x', 56, 1, 0, 'backOut', 1)
end

function flash(beat)
	cameraFlash('hud', 'FFFFFF', 0.5)
end
