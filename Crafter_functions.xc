; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; 	BASIC FUNCTIONS FOR CRAFTER CONTROL
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=



function @Start_craft($crafter:text, $item:text)
	; Starts a crafter to craft the $item
	; Continuous crafting is turned on and off because Archean
	output_text($crafter, 1, $item)
	output_number($crafter, 0, 1)
	output_number($crafter, 0, 0)
	
	
function @Cancel_craft($crafter:text)
	; Cancels the craft by putting the crafting item as ""
	output_text($crafter, 1, "x")
	output_number($crafter, 0, 0)
	
	
function @Crafter_progress($crafter:text) : number
	; Checks the progress of a crafter
	return input_number($crafter, 0)
	
	
function @is_crafting($crafter:text) : number
	; checks whether the crafter is occupied
	var $p = @Crafter_progress($crafter)
	return ($p>0 and $p<1)
	
	
function @Crafter_categories() : text
	; Gets all crafter categories of items
	return get_recipes_categories("crafter")
	
function @Crafter_category_items($cat:text) : text
	; Gets all crafter items for a category
	return get_recipes("crafter", $cat)