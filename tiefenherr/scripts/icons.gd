class_name Icons
extends RefCounted
## Erzeugt die Symbole der Befehlsleiste zur Laufzeit aus eingebetteten SVG-Zeichnungen.

const HEAD := '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48" stroke-linecap="round" stroke-linejoin="round">'
const SVG := {
	"select": '<path d="M12 6 L12 36 L20 29 L26 42 L31 40 L25 27 L36 27 Z" fill="#f4e6c0" stroke="#3a2a12" stroke-width="2.5"/>',
	"dig": '<path d="M14 40 L34 14" stroke="#9a6a35" stroke-width="5"/><path d="M18 10 Q34 6 42 22" fill="none" stroke="#c9d0da" stroke-width="6"/><path d="M18 10 Q34 6 42 22" fill="none" stroke="#f5f7fa" stroke-width="2"/>',
	"room1": '<ellipse cx="24" cy="36" rx="15" ry="6" fill="#c8901c" stroke="#5a3a08" stroke-width="2"/><ellipse cx="24" cy="29" rx="15" ry="6" fill="#e8b030" stroke="#5a3a08" stroke-width="2"/><ellipse cx="24" cy="22" rx="15" ry="6" fill="#ffd24a" stroke="#5a3a08" stroke-width="2"/><ellipse cx="24" cy="15" rx="15" ry="6" fill="#ffe680" stroke="#5a3a08" stroke-width="2"/>',
	"room2": '<path d="M5 26 Q24 46 43 26 L40 36 Q24 46 8 36 Z" fill="#8a6230" stroke="#3a2710" stroke-width="2"/><ellipse cx="24" cy="26" rx="19" ry="8" fill="#c79a4c" stroke="#3a2710" stroke-width="2"/><ellipse cx="24" cy="26" rx="12" ry="4.5" fill="#4a3018"/><path d="M30 10 q5 -1 6 3 M34 5 q5 -1 6 3" fill="none" stroke="#bfd0ff" stroke-width="2.5"/>',
	"room3": '<path d="M19 26 L18 40 Q24 43 30 40 L29 26 Z" fill="#efe8d0" stroke="#4a4030" stroke-width="2"/><path d="M5 26 Q7 8 24 8 Q41 8 43 26 Q24 31 5 26 Z" fill="#2fd0a8" stroke="#0c4a3c" stroke-width="2"/><circle cx="16" cy="18" r="3" fill="#d8fff2"/><circle cx="29" cy="15" r="3.5" fill="#d8fff2"/><circle cx="34" cy="22" r="2" fill="#d8fff2"/>',
	"room4": '<path d="M9 9 L33 35" stroke="#dfe5ee" stroke-width="5"/><path d="M39 9 L15 35" stroke="#dfe5ee" stroke-width="5"/><path d="M27 37 L37 29 M21 37 L11 29" stroke="#a0702c" stroke-width="4"/><path d="M34 37 L40 43 M14 37 L8 43" stroke="#6a4418" stroke-width="5"/>',
	"sell": '<circle cx="20" cy="26" r="14" fill="#e8b030" stroke="#5a3a08" stroke-width="2.5"/><path d="M20 18 L20 34 M15 22 Q20 17 25 22 Q20 26 15 30 Q20 35 25 30" fill="none" stroke="#5a3a08" stroke-width="2.5"/><path d="M30 12 L42 12 M37 6 L43 12 L37 18" fill="none" stroke="#ff5a48" stroke-width="4"/>',
	"trap_spike": '<rect x="4" y="36" width="40" height="7" rx="2" fill="#3a3a42" stroke="#15151a" stroke-width="2"/><path d="M7 36 L13 10 L19 36 Z M18 36 L24 6 L30 36 Z M29 36 L35 10 L41 36 Z" fill="#d5dae2" stroke="#3a3f48" stroke-width="2"/>',
	"trap_wallspike": '<rect x="4" y="4" width="13" height="40" fill="#7a3a30" stroke="#2a1410" stroke-width="2"/><path d="M4 17 H17 M4 30 H17 M10 4 V17 M10 30 V44" stroke="#2a1410" stroke-width="2"/><path d="M17 7 L43 12 L17 17 Z M17 19 L43 24 L17 29 Z M17 31 L43 36 L17 41 Z" fill="#d5dae2" stroke="#3a3f48" stroke-width="2"/>',
	"trap_fire": '<path d="M24 4 Q38 18 36 30 Q35 43 24 44 Q13 43 12 30 Q11 22 18 15 Q19 22 23 22 Q21 12 24 4 Z" fill="#ff7a1a" stroke="#6a1c04" stroke-width="2"/><path d="M24 22 Q31 30 29 36 Q27 41 24 41 Q20 41 19 36 Q18 30 24 22 Z" fill="#ffe066"/>',
	"trap_poison": '<path d="M12 24 Q4 24 5 17 Q6 11 13 12 Q16 4 25 6 Q33 4 36 12 Q44 12 43 19 Q43 24 36 24 Z" fill="#5fd03a" stroke="#1c4a0c" stroke-width="2"/><path d="M14 30 q-3 6 0 7 q3 -1 0 -7 Z M24 32 q-3 7 0 9 q3 -2 0 -9 Z M34 30 q-3 6 0 7 q3 -1 0 -7 Z" fill="#a8ff5a" stroke="#1c4a0c" stroke-width="1.5"/>',
	"spell_imp": '<path d="M12 20 L2 8 L16 14 Z M36 20 L46 8 L32 14 Z" fill="#7d8a3a" stroke="#2a3010" stroke-width="2"/><circle cx="24" cy="24" r="14" fill="#93a244" stroke="#2a3010" stroke-width="2"/><circle cx="18" cy="22" r="3.5" fill="#ffe24a"/><circle cx="30" cy="22" r="3.5" fill="#ffe24a"/><path d="M17 31 Q24 36 31 31" fill="none" stroke="#2a3010" stroke-width="2.5"/><path d="M38 34 L46 42 M42 32 L48 38" stroke="#dfe5ee" stroke-width="3"/>',
	"spell_bolt": '<path d="M28 3 L10 27 L22 27 L17 45 L38 19 L26 19 Z" fill="#9fd0ff" stroke="#143a6a" stroke-width="2.5"/><path d="M26 9 L16 24 L25 24" fill="none" stroke="#ffffff" stroke-width="2"/>',
	"spell_heal": '<path d="M24 42 Q4 28 6 16 Q8 6 17 8 Q22 9 24 14 Q26 9 31 8 Q40 6 42 16 Q44 28 24 42 Z" fill="#3fd070" stroke="#0c4a24" stroke-width="2.5"/><path d="M24 15 V31 M16 23 H32" stroke="#ffffff" stroke-width="5"/>',
}

static var _cache := {}


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if not SVG.has(key):
		return null
	var img := Image.new()
	if img.load_svg_from_string(HEAD + SVG[key] + "</svg>", 1.0) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
