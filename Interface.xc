; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; 	AUTOCRAFTING INTERFACE
;   THIS INCLUDES QUEUEING ITEMS,
;		SETTING STOCK QUANTITIES,
;		KEYBOARD-BASED SEARCH
;		NUMPAD INPUT OF VALUES
;		AND A LITTLE MORE
;
;	BY STEAM USER WarFant
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

include "Crafting.xc"
include "Screen_functions.xc"
include "Input_devices.xc"

; Whether it is in the welcome screen
var $welcome_screen = 1

; Background Color
var $bgC = color(18, 15, 20)
; Foreground Color
var $fgC = color(200, 100, 0)
; Dark Foreground Color
var $dfC = color(3, 0, 6)
; Item Text Color
var $itC = color(230, 230, 255)
; Item Background Color
var $ibC = color(40, 40, 40)

; Margin value for vertical spacing in item buttons
const $ITEM_MARGIN = 15
; Half of the scroll's triangle side
const $SCROLL_T = 5

; (Main) button width, height and text size
var $b_width = 0
var $b_height = 0
var $b_txt_size = 1

; Crafter categories to draw
array $craft_categories : text
; Number of categories
var $N_categories = 0
; Currently selected category
var $selected_category : text
; Currently selected item
var $selected_item : text
; Currently selected quantity
var $selected_qtty = 1
; How far down the item list is
var $item_list_down = 0

; Whether on autocraft settings
var $on_settings = 0
; Whether the search is active
var $searching = 0
var $search_term = ""
; Whether the numpad is active
var $numpad_on = 0


function @Change_category($cat:text)
	; Selects a new category
	$selected_category = $cat
	$item_list_down = 0
	if $searching
		$searching!!
	@Dirty_screen()
	
function @Change_item($item:text)
	; Selects a new item
	$selected_item = $item
	
function @Toggle_search()
	; Toggles whether to search the keyboard text on the item list
	$searching!!
	@Dirty_screen()
	
function @Craft_selected()
	; Crafts a specified amount of the currently selected item
	if $selected_item and $selected_qtty
		@Q_append_amount($selected_item, $selected_qtty)
	
function @Scroll_item($direction:number)
	; Changes the scroll variable for the item list
	var $norm = if($direction>0, 1, -1)
	if max($item_list_down+$norm, 0) != $item_list_down
		$item_list_down = max($item_list_down+$norm, 0)
		@Dirty_screen()
		
		
function @Col_button($xs:number, $ys:number, $width:number, $height:number, $label:text, $cb:number, $cf:number) : number
	; Draws one button (Col stands for colored)
	var $txt_x = $xs + @Centralized_x($width, $label)
	var $txt_y = $ys + @Centralized_y($b_height)
	var $clicked = 0
	
	if $screen.button_rect($xs, $ys, $xs+$width, $ys+$height, $cb, $cf)
		$clicked = 1
	$screen.write($txt_x, $txt_y, $cb, $label)
	return $clicked
	
	
function @Gen_button($xs:number, $ys:number, $width:number, $height:number, $label:text, $sel:number) : number
	; Draws one button with generic colors
	if $sel
		return @Col_button($xs, $ys, $width, $height, $label, $dfC, $fgC)
	else
		return @Col_button($xs, $ys, $width, $height, $label, $fgC, $dfC)

function @Draw_welcome_logo($centerX:number, $centerY:number)
	; Draws a little logo to make the welcome screen less boring
	var $rad = min($s_width, $s_height) * 0.1
	$screen.draw_circle($centerX,$centerY+$rad/2,$rad, $fgC)
	$screen.draw_circle($centerX-$rad/2,$centerY,$rad, $dfC)
	$screen.draw_circle($centerX+$rad/2,$centerY,$rad, $fgC)
	

function @Initialize_interface()
	; Initializes some interface variables
	;	and draws the welcome screen
	$s_width = $screen.width
	$s_height = $screen.height
	$screen.blank($bgC)
	
	; Writes the welcome text
	var $welcome = "Hello!"
	$screen.text_size(10)
	$screen.text_align(center)
	$screen.write(0, 0, $fgC, $welcome)
	$screen.text_align(left)
	
	@Draw_welcome_logo(0.5*$s_width-(1.5+0.5*size($welcome))*$screen.char_w, 0.5*$s_height)
	
	; Initializes some global variables
	$craft_categories.from(@Crafter_categories(), ",")
	$selected_category = $craft_categories.0
	
	$N_categories = $craft_categories.size
	$b_width = round($s_width/$N_categories)
	$b_height = round($s_height/10)
	
	; Checks the biggest font that still fits in the button width
	var $max_cat_size = 0
	foreach $craft_categories ($i, $cat)
		if size($cat) > $max_cat_size
			$max_cat_size = size($cat)
	repeat 10 ($i)
		$screen.text_size(10-$i)
		if $screen.char_w*$max_cat_size < $b_width-2 and $screen.char_h < $b_height-2
			$b_txt_size = 10-$i
			break


function @Main_button($xs:number, $ys:number, $txt:text, $selected:number) : number
	; Draws one of the main screen buttons (categories and screen "tabs")
	var $txt_x = $xs + @Centralized_x($b_width, $txt)
	var $txt_y = $ys + @Centralized_y($b_height)
	var $line_y = $txt_y+$screen.char_h/2+5
	
	var $mainC = $dfC
	var $secC = $fgC
	if $selected
		$mainC = $fgC
		$secC = $dfC
	
	var $clicked = 0
	if $screen.button_rect($xs, $ys, $xs+$b_width, $ys+$b_height, $bgC, $mainC)
		$clicked = 1
		
	$screen.write($txt_x, $txt_y, $secC, $txt)
	$screen.draw_line($txt_x-2, $line_y, $txt_x+2+$screen.char_w*size($txt), $line_y, $secC)
	return $clicked


function @Item_button($ys:number, $w:number, $txt:text) : number
	; Draws one item button
	var $txt_x = $b_width + @Centralized_x($w, $txt)
	var $txt_y = $ys + @Centralized_y($screen.char_h+$ITEM_MARGIN)
	
	var $clicked = 0
	if $screen.button_rect($b_width, $ys, $b_width+$w, $ys+$screen.char_h+$ITEM_MARGIN, $bgC, $ibC)
		$clicked = 1
		
	$screen.write($txt_x, $txt_y, $itC, $txt)
	return $clicked
	
	
function @V_progress_bar($x:number, $ys:number, $w:number, $h:number, $p:number, $pC:number, $bC:number, $td:number)
	; Draws a vertical progress bar:
	; x is the center x position, ys is the starting (up) y position
	; w is the width, h is the height, p is the progress
	; pC is the progress color, bC is the border color
	; td is whether to draw the progress top-down (or down-top)
	; THIS DOES NOT AUTOMATICALLY ERASE THE PREVIOUS PROGRESS BAR
	var $xs = $x-$w/2
	var $xe = $x+$w/2
	$screen.draw_rect($xs, $ys, $xe, $ys+$h, $bC)
	if $td
		$screen.draw_rect($xs, $ys, $xe, $ys+$h*$p, $bC, $pC)
	else
		$screen.draw_rect($xs, $ys+$h*(1-$p), $xe, $ys+$h, $bC, $pC)
	
	
function @Craft_amount_button($xs:number, $ys:number, $width:number, $amount:number)
	; Draws one button from the right side panel
	$screen.text_size(2)
	var $txt = text("x{}", $amount)
	if @Gen_button($xs, $ys, $width, $b_height, $txt, $amount==$selected_qtty)
		$selected_qtty = $amount
		@Dirty_screen()
	
	
function @Draw_right_sidescreen()
	; Draws the right sidescreen
	var $xs = $s_width-2*$b_width+$ITEM_MARGIN
	var $xe = $xs + 2*$b_width - 2*$ITEM_MARGIN
	$screen.draw_rect($xs-$ITEM_MARGIN+1, 2*$b_height, $s_width-1, 8*$b_height+5, $bgC, $dfC)
	
	$screen.text_size(2)
	var $txt_x = $xs + @Centralized_x(2*$b_width-2*$ITEM_MARGIN, $selected_item)
	var $line_y = 2.5*$b_height+$screen.char_h/2+8
	
	$screen.write($txt_x, 2.5*$b_height, $fgC, $selected_item)
	$screen.draw_line($txt_x-2, $line_y, $txt_x+2+$screen.char_w*size($selected_item), $line_y, $fgC)
	
	$screen.text_size(1)
	var $recipe = get_recipe("crafter", $selected_item)
	if $recipe
		@Collumn_write($xs, $line_y+$screen.char_h, $xe, 4*$b_height-$screen.char_h, $fgC, $recipe, 1)
		
	var $small_width = ($xe-$xs) / 3
	@Craft_amount_button($xs, 4*$b_height, $small_width, 1)
	@Craft_amount_button($xs+$small_width, 4*$b_height, $small_width, 5)
	@Craft_amount_button($xs+2*$small_width, 4*$b_height, $small_width, 10)
	
	var $big_width = ($xe-$xs) / 2
	@Craft_amount_button($xs, 5*$b_height, $big_width, 100)
	@Craft_amount_button($xs+$big_width, 5*$b_height, $big_width, 1000)
	
	; Writes the number of stored items and aimed amount
	$screen.text_size(2)
	var $qtty = @Get_AC_qtty($selected_item)
	var $txt_y = 6*$b_height + @Centralized_y(0.5*$b_height)
	var $available_qtty = text(@Get_item_quantity($selected_item))
	$txt_x = $xs + @Centralized_x($xe-$xs, "["&$available_qtty&"|"&text($qtty)&"]")
	$screen.write($txt_x+1, $txt_y+2, $fgC, "["&$available_qtty&"|"&text($qtty)&"]")
		
	if $on_settings
		if @Col_button($xs+$small_width, 6.5*$b_height, $small_width, $b_height, "Set", $bgC, color(80,80,255))
			@Set_AC_value($selected_item, $selected_qtty)
			@Dirty_screen()
		$screen.text_size(3)
		if @Col_button($xs, 6.5*$b_height, $small_width, $b_height, "-", $bgC, red)
			@Sub_AC_value($selected_item, $selected_qtty)
			@Dirty_screen()
		if @Col_button($xs+2*$small_width, 6.5*$b_height, $small_width, $b_height, "+", $bgC, green)
			@Add_AC_value($selected_item, $selected_qtty)
			@Dirty_screen()
		
		$screen.text_size(1)
		$txt_y = 6.5*$b_height + 4*$screen.char_h + 5
		
		; Writes the new values if the buttons are to be pushed
		var $new_qtty = max(0, $qtty-$selected_qtty)
		$txt_x = $xs + @Centralized_x($small_width, text(max(0, $qtty-$selected_qtty)))
		$screen.write($txt_x, $txt_y, $bgC, text($new_qtty))
		$new_qtty = $selected_qtty
		$txt_x = $xs+$small_width + @Centralized_x($small_width, text($new_qtty))
		$screen.write($txt_x, $txt_y, $bgC, text($new_qtty))
		$new_qtty = $selected_qtty + $qtty
		$txt_x = $xs+2*$small_width + @Centralized_x($small_width, text($new_qtty))
		$screen.write($txt_x, $txt_y, $bgC, text($new_qtty))
		
	else
		if @Col_button($xs, 6.5*$b_height, $big_width, $b_height, "Craft", $bgC, green)
			@Craft_selected()
			
		if @Col_button($xs+$big_width, 6.5*$b_height, $big_width, $b_height, "Cancel", $bgC, red)
			print("Crafting canceled")
			@Cancel_all_craft()	
			
		; Writes the selected quantity to craft
		$screen.text_size(1)
		$txt_y = 6.5*$b_height + 4*$screen.char_h + 5
		$txt_x = $xs + @Centralized_x($big_width, text($selected_qtty))
		$screen.write($txt_x, $txt_y, $bgC, text($selected_qtty))
	
function @Draw_main_buttons()
	; Draws all the category buttons
	$screen.text_size($b_txt_size)
	foreach $craft_categories ($i, $cat)
		if @Main_button($i*$b_width, 0, $cat, $cat == $selected_category and !$searching)
			@Change_category($cat)
	

function @Draw_item_scroll($up:number, $down:number)
	; Draws the scroll bar for the items
	var $w = $b_width/4
	var $xe = $s_width-2*$b_width
	var $xs = $xe-$w
	var $ys = $b_height+10
	var $total_h = $s_height - 20 - 2 * $b_height
	var $ye = $ys + $total_h/2
	var $ym = ($ye+$ys)/2
	var $xm = ($xe+$xs)/2
	if $up
		if $screen.button_rect($xs, $ys, $xe, $ye, $bgC, $ibC)
			@Scroll_item(-1)
		$screen.draw_triangle($xm-$SCROLL_T, $ym+$SCROLL_T, $xm, $ym-$SCROLL_T, $xm+$SCROLL_T, $ym+$SCROLL_T, $itC, $itC)
	if $down
		$ym += $total_h/2
		if $screen.button_rect($xs, $ye, $xe, $ye+$total_h/2, $bgC, $ibC)
			@Scroll_item(1)
		$screen.draw_triangle($xm-$SCROLL_T, $ym-$SCROLL_T, $xm, $ym+$SCROLL_T, $xm+$SCROLL_T, $ym-$SCROLL_T, $itC, $itC)
		
	
function @Draw_items()
	; Draws all the item buttons
	array $items : text
	$items.clear()
	; Apply search term
	if $searching and $search_term != ""
		array $temp : text
		foreach $craft_categories ($j, $cat)
			$temp.from(get_recipes("crafter", $cat), ",")
			foreach $temp ($i, $item)
				if contains(lower($item), lower($search_term))
					$items.append($item)
	else
		$items.from(get_recipes("crafter", $selected_category), ",")
		
	
	$screen.text_size(2)
	var $button_h = ($screen.char_h+$ITEM_MARGIN)
	var $ys = $b_height+10
	var $ye = $s_height-$b_height-10
	var $max_items = ($ye-$ys) / $button_h
	; Checks if it needs a scroll bar
	var $has_scroll = size($items) > $max_items
	var $w = if($has_scroll, $s_width-3*$b_width-$b_width/4, $s_width-3*$b_width)
	
	if $has_scroll
		var $scrolled = -round( $item_list_down * $max_items/2 )
		if size($items)+$scrolled < $max_items
			$scrolled = -size($items)+$max_items
		@Draw_item_scroll($item_list_down, size($items)+$scrolled > $max_items)
		foreach $items ($i, $item)
			if $ye < $ys+($i+$scrolled+1)*$button_h
				break
			if $ys+($i+$scrolled)*$button_h < $ys
				continue
			if @Item_button($ys+($i+$scrolled)*$button_h, $w, $item)
				@Change_item($item)
	else
		foreach $items ($i, $item)
			if @Item_button($ys+$i*$button_h, $w, $item)
				@Change_item($item)
	
			
	$screen.draw_rect(0, $b_height, $s_width, $b_height+10, $bgC, $bgC)
	$screen.draw_rect(0, $s_height-$b_height-5, $s_width, $s_height-($b_height+10), $bgC, $bgC)
	
	
function @Draw_bottom_buttons()
	; Draws the main screen bottom buttons ("tabs")
	$screen.text_size($b_txt_size)
	var $ys = $s_height-$b_height - 5
	var $xs = 50
	if @Main_button($xs, $ys, "AUTOCRAFT", $autocraft)
		$autocraft!!
		@Dirty_screen()
	if @Main_button($xs+$b_width, $ys, "SETTINGS", $on_settings)
		$on_settings!!
		@Dirty_screen()
	if @Main_button($xs+2*$b_width, $ys, "SEARCH", $searching)
		@Toggle_search()
	if @Main_button($xs+3*$b_width, $ys, "NUMPAD", $numpad_on)
		$numpad_on!!
		$selected_qtty = 1
		@Dirty_screen()
	
	
function @Draw_left_sidescreen()
	; Draws the left sidescreen (progress bars for queue and stack)
	
	; Erases previous screen
	$screen.draw_rect(0, $b_height, $b_width, $s_height-$b_height-5, $bgC, $bgC)
	$screen.text_size(2)
	var $mid_x = $b_width/2
	var $ys = 2*$b_height
	var $yb = $ys+1.5*$screen.char_h
	var $bw = 2*$screen.char_w
	
	; Writes "Q" and draws the queue progress bar
	var $Q_x = $mid_x-3*$screen.char_w
	$screen.write($Q_x, $ys, $fgC, "Q")
	@V_progress_bar($Q_x+$screen.char_w/2, $yb, $bw, 0.3*$s_height, 1-@Q_progress(), $fgC, $fgC, 0)
	
	; Writes "S" and draws the stack progress bar
	var $S_x = $mid_x+2*$screen.char_w
	$screen.write($mid_x+2*$screen.char_w, 2*$b_height, $fgC, "S")
	@V_progress_bar($S_x+$screen.char_w/2, $yb, $bw, 0.3*$s_height, 1-@S_progress(), $fgC, $fgC, 0)
	
	; Draws a separator
	var $hbar_y = $yb+0.3*$s_height+$screen.char_h
	$screen.draw_line(10, $hbar_y, $b_width-10, $hbar_y, $fgC)
	
	; Writes the current items being crafted (last in stack)
	$screen.text_size(1)
	var $current_stack = @Current_items()
	var $txt_y = $hbar_y + $screen.char_h
	foreach $current_stack ($k, $v)
		if $txt_y + 2*$screen.char_h > $s_height-$b_height
			break
		var $kx = @Centralized_x($b_width, $k)
		var $vx = @Centralized_x($b_width, $v)
		$screen.write($kx, $txt_y, $fgC, $k)
		$txt_y += $screen.char_h
		$screen.write($vx, $txt_y, $fgC, $v)
		$txt_y += 2*$screen.char_h
	
	
	
function @Draw_screen()
	; Draws the entire screen
	$screen_dirty = 0
	
	$screen.blank($bgC)
	@Draw_bottom_buttons()
	@Draw_main_buttons()
	@Draw_items()
	@Draw_right_sidescreen()
	@Draw_left_sidescreen()
		
		
		
click.$screen()
	; When the screen is clicked, draws the buttons to check for clicks
	$welcome_screen = 0
	@Draw_screen()
	
timer frequency 20
	; Checks if the screen needs to be redrawn because of screen dirt
	if $numpad_on and @Numpad_val() != $selected_qtty
		$selected_qtty = @Numpad_val()
		@Dirty_screen()
	if $searching and @Keyboard_val() != $search_term
		$search_term = @Keyboard_val()
		@Dirty_screen()
		
	if $screen_dirty
		@Draw_screen()
		
timer interval 0.5
	; Queues autocrafting items
	if $autocraft and @Crafting_empty()
		@Missing_autocrafting_items()

	; Draws the left sidescreen during crafting
	if $welcome_screen
		return
		
	if @Crafting_empty() and !$was_crafting
		return
		
	@Draw_left_sidescreen()
	@Draw_right_sidescreen()