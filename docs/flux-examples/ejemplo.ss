// ejemplo.ss: SScript 24. Va en mods/TuMod/scripts/ o en mods/TuMod/data/<canción>/
// Tiene el mismo preset que los .hxs: game, FlxG, makeText, tween, timer, playSound, setVar...

var combo = 0;
var texto = null;

function onCreatePost() {
	texto = makeText(20, 120, 400, 'Combo: 0', 28);
	texto.cameras = [camHUD]; // los campos de PlayState se usan directo
	add(texto);
}

function goodNoteHit(note) {
	if (note.isSustainNote)
		return;
	combo++;
	texto.text = 'Combo: ${combo}';
	if (combo % 50 == 0) {
		texto.color = 0xFFFFD700;
		tween(texto.scale, {x: 1.3, y: 1.3}, 0.15, 'quadOut', function() {
			// una función sin argumentos también sirve de callback
			texto.scale.set(1, 1);
			texto.color = 0xFFFFFFFF;
		});
	}
}

function noteMiss(note) {
	combo = 0;
	texto.text = 'Combo: 0';
}
