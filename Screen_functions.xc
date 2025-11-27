; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; 	BASIC FUNCTIONS FOR SCREEN CONTROL
;   THIS INCLUDES TEXT ALIGNMENT AND SUCH
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

; Screen definition
var $screen = screen("Craft_dashboard", 0)
var $s_width : number
var $s_height : number

; Whether to redraw the screen
var $screen_dirty = 0



function @Dirty_screen()
	; Sinalizes that the screen should be redrawn
	$screen_dirty = 1
	

function @Centralized_x($width:number, $text:text) : number
	; Returns the centralized x position for a text
	return $width/2 - $screen.char_w*size($text)/2
	
	
function @Centralized_y($height:number) : number
	; Returns the centralized y position for a height
	return $height/2 - $screen.char_h/2
	
	
function @Ljustified_write($xs:number, $ys:number, $width:number, $color:number, $text:text)
	; Writes a left-justified text based on spaces
	array $words : text
	$words.from($text, " ")
	var $crrnt_x = 0
	var $crrnt_y = 0
	; Writes each word individually, checking if it should break the line
	; TODO: probably could optimize by calculating entire lines and THEN drawing them
	foreach $words ($i, $word)
		if $crrnt_x + size($word)*$screen.char_w > $width
			$crrnt_x = 0
			$crrnt_y += $screen.char_h
		$screen.write($xs+$crrnt_x, $ys+$crrnt_y, $color, $word)
		$crrnt_x += (size($word)+1)*$screen.char_w
	
			
function @Vertical_write($xs:number, $ys:number, $color:number, $text:text)
	; Writes vertically on the screen, meaning something like
	; t
	; h
	; i
	; s
	var $crrnt_y = 0
	var $size = size($text)
	repeat $size ($i)
		$screen.write($xs, $ys+$crrnt_y, $color, $text.$i)
		$crrnt_y += $screen.char_h
		
		
function @Collumn_write($xs:number, $ys:number, $xe:number, $ye:number, $color:number, $text:text, $kv:number)
	; Writes a list of .key{value} items in columns
	; EXAMPLE
	; itemA:200			foo:35
	; itemB:10			bar:6000
	
	; Calculates the words and maximum word width
	; By word this means the pattern item:value
	var $ch = $screen.char_h
	var $cw = $screen.char_w
	array $words : text
	if $kv
		foreach $text ($k, $v)
			$words.append($k & ":" & $v)
	else
		$words.from($text, " ")
	if $words.size == 0
		return
		
	; Number of collumns needed and words per collumn
	var $N_col = ceil( $words.size * $ch / ($ye-$ys) )
	var $N_per_col = floor( $words.size / $N_col )
	
	var $crrnt_c = 0
	var $col_w = ($xe-$xs)/$N_col
	var $crrnt_y = $ys
	; Writes each word where it should be
	foreach $words ($i, $word)
		$screen.write($xs+$crrnt_c*$col_w, $crrnt_y, $color, $word)
		$crrnt_y += $ch
		if $crrnt_y+$ch > $ye
			$crrnt_c++
			$crrnt_y = $ys
	$words.clear()