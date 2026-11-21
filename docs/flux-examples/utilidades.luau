-- Módulo para require('utilidades'): devuelve una tabla con funciones.

local M = {}

-- 83500 (milisegundos) -> "1:23"
function M.tiempo(ms: number): string
	local segundos = math.floor(ms / 1000)
	return string.format('%d:%02d', segundos // 60, segundos % 60)
end

return M
