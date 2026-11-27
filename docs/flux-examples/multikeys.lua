-- Flux Engine: ejemplo de multi-keys
-- keyCount es la cantidad de teclas con la que se juega la canción (4 a 17).

function onCreatePost()
	debugPrint('Se juega con ' .. keyCount .. ' teclas')
end

function onCountdownStarted()
	-- hay un receptor por tecla: defaultPlayerStrumX0 ... defaultPlayerStrumX(keyCount - 1)
	for i = 0, keyCount - 1 do
		setPropertyFromGroup('playerStrums', i, 'alpha', 0.8)
	end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
	-- direction va de 0 a keyCount - 1 (el carril de la nota)
	if direction == keyCount - 1 then
		-- la última tecla de la derecha
	end
end
