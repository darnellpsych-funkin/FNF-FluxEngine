-- Flux Engine - Lua usando RuleScript, NXScript y hscript-plus
-- Ponlo en: mods/TuMod/scripts/ejemplo-lua-flux.lua

function onCreatePost()
	-- RuleScript: el código queda guardado y después puedes llamar sus funciones
	runRuleScript([[
		function saludar(nombre) return 'Hola ' + nombre + ' desde RuleScript';
	]])
	debugPrint(runFluxFunction('rulescript', 'saludar', {'Juaquin'}))

	-- NXScript: crear una función y llamarla en la misma línea
	local doble = runNXScript('func doble(x) { return x * 2 }', 'doble', {21})
	debugPrint('NXScript dice: ' .. doble)

	-- hscript-plus
	runHScriptPlus('function triple(x) { return x * 3; }')
	debugPrint('hscript-plus dice: ' .. runFluxFunction('hscriptplus', 'triple', {5}))

	-- Cargar un script de archivo (busca .rhx, .nx, .nxs o .hsp)
	-- addFluxScript('scripts/bfInmortalSicks')
end

function onBeatHit()
	-- Avisar a todos los scripts de Flux (.rhx, .nx, .hsp)
	if curBeat % 16 == 0 then
		callOnFluxScripts('onAvisoDeLua', {curBeat})
	end
end
