; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; 	BASIC FUNCTIONS FOR INPUT CONTROL
;   NOT MUCH TO SEE HERE
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

const $keyboard = "Craft_keyboard"
const $numpad = "Craft_numpad"


function @Numpad_val() : number
	; Returns the numpad value
	return input_number($numpad, 0)
	
	
function @Keyboard_val() : text
	; Returns the keyboard sent text
	return input_text($keyboard, 0)