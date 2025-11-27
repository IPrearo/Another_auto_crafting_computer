; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
; 	FUNCTIONS FOR CRAFTING QUEUES AND AUTOCRAFTING
;   BASICALLY, THIS IS THE BASIS FOR AN UI
; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

include "Crafter_functions.xc"

; Maximum number of crafters and containers
const $max_prefix_count = 100

; Containers prefix for autocrafting resources
const $container_prefix = "Craft_container{}"
array $container_numbers : number

; Output conveyor name and frequency of outputing items
const $output_conveyor = "Output_conveyor"
const $output_frequency = 1
; Containers prefix for output containers
const $output_prefix = "Output_container{}"
array $output_numbers : number

; Crafter prefix for autocrafting
const $crafter_prefix = "Crafter{}"
array $crafter_numbers : number
; Stores which crafter numbers are not in use
array $available_crafters : number

; Craft stack. Items are crafted from last to first
array $craft_S : text
; Craft Queue. Items are put into the stack from first to last
array $craft_Q : text

; Whether the system was recently crafting something
var $was_crafting = 0

; These values are stored each time the queue or stack get bigger than it
; They can be used for progress bar visualization
storage var $max_craft_Q_size : number
storage var $max_craft_S_size : number

; Whether to autocraft a set of items until a specific amount (0 or non-zero)
storage var $autocraft : number
; Which items to keep in stock and how many of them in a .item{amount} pattern
storage var $autocraft_items : text

; Whether there was an error with the crafters
var $is_error = 0
	
	
; =-=-=-=-=-=-= G E N E R A L =-=-=-=-=-=-=

function @Initialize_crafting()
	; Checks which container and crafter numbers exist
	; 	and stores it in the respective arrays
	
	repeat $max_prefix_count ($i)
		var $dev_name = text($container_prefix, $i+1)
		if device_type($dev_name) == "Container" or device_type($dev_name) == "SmallContainer"
			$container_numbers.append($i+1)
			
		$dev_name = text($output_prefix, $i+1)
		if device_type($dev_name) == "Container" or device_type($dev_name) == "SmallContainer"
			$output_numbers.append($i+1)
			
		$dev_name = text($crafter_prefix, $i+1)
		if device_type($dev_name) == "Crafter"
			$crafter_numbers.append($i+1)
			
	; Starts all the crafters as available
	foreach $crafter_numbers ($i, $n)
		$available_crafters.append($n)
		
	$max_craft_Q_size = 0
	$max_craft_S_size = 0
		
		
function @error($message:text)
	; Prints an error message and sets the error variable to 1
	if $message
		print($message)
	$is_error = 1
		
function @clear_error()
	; Clears the error variable to 0
	$is_error = 0
		

; =-=-=-=-=-=-=-=-= L O G I S T I C S =-=-=-=-=-=-=-=-=


function @Container_name($n:number) : text
	; Formats the container number into a container name
	return text($container_prefix, $n)
	
function @Output_name($n:number) : text
	; Formats the container number into a container name
	return text($output_prefix, $n)

function @Stop_output()
	; Stops the output conveyor by putting a filter for "x"
	; To be sure, it also turns the conveyor off and items/second to 1 (minimum)
	output_text($output_conveyor, 2, "x")
	output_number($output_conveyor, 0, 0)
	output_number($output_conveyor, 1, 1)


function @Get_resource_items() : text
	; Sums up all items from the identified containers and returns a K{V} string
	;	This K{V} string will be a collection of all resources available
	var $contents = ""
	if $container_numbers.size
		foreach $container_numbers ($i, $n)
			var $container_contents = input_text(@Container_name($n), 0)
			; Sums the container contents to the overall resources ($contents)
			foreach $container_contents ($j, $t)
				$contents.$j += $t
		
	return $contents


function @Get_available_items() : text
	; Sums up all items from the identified containers and returns a K{V} string
	;	This K{V} string will be a collection of all resources available
	var $contents = ""
	; Crafting resource containers
	if $container_numbers.size
		foreach $container_numbers ($i, $n)
			var $container_contents = input_text(@Container_name($n), 0)
			; Sums the container contents to the overall resources ($contents)
			foreach $container_contents ($j, $t)
				$contents.$j += $t
			
	; Output containers
	if $output_numbers.size
		foreach $output_numbers ($i, $n)
			var $output_contents = input_text(@Output_name($n), 0)
			; Sums the container contents to the overall resources ($contents)
			foreach $output_contents ($j, $t)
				$contents.$j += $t
		
	return $contents


function @Get_item_quantity($item:text) : number
	; Gets the number of a specific item in storage
	; IF YOU WOULD LIKE TO SEARCH MULTIPLE ITEMS,
	;  PROBABLY SHOULD USE @Get_available_items DIRECTLY
	if $item == ""
		return 0
	var $available_items = @Get_available_items()
	if $available_items.$item
		return $available_items.$item
	return 0


function @Output_item_list() : text
	; Searches through the resource items to check if
	;		any of those should be in the output containers.
	; Output items are defined as anything outside the "PARTS"
	;   	category, but HDDs are manually included too.
	var $resource_items = @Get_resource_items()
	var $item_list = ""
	array $temp_list : text
	array $crafter_categories : text
	$crafter_categories.from(@Crafter_categories(), ",")
	; Checks each available resource if it should be outputed
	foreach $crafter_categories ($i, $cat)
		if $cat == "PARTS"
			$temp_list.clear()
			$temp_list.append("HDD")
		else
			$temp_list.from(@Crafter_category_items($cat), ",")
			
		foreach $temp_list ($j, $item)
			if $resource_items.$item > 0
				$item_list.$item = $resource_items.$item
				
	return $item_list


; =-=-=-=-=-=-=-=-= C R A F T I N G =-=-=-=-=-=-=-=-=


function @Crafter_name($n:number) : text
	; Formats the crafter number into a crafter name
	return text($crafter_prefix, $n)
	
	
function @Cancel_all_craft()
	; Clears both the queue and stack
	$craft_Q.clear()
	$craft_S.clear()
		
		
function @All_crafters_available() : number
	; Checks if the available and all crafters lists are the same size
	return $crafter_numbers.size == $available_crafters.size
	
function @Any_crafters_available() : number
	; Simple check to see if any crafters are available
	return $available_crafters.size > 0
		
		
function @Update_crafter_availability()
	; Updates which crafters are available
	; !! SHOULD RUN *BEFORE* CRAFTING ORDERS IN THE SAME TICK !!
	if @All_crafters_available()
		return
		
	foreach $crafter_numbers ($i, $n)
		var $is_available = 0
		var $c_name = @Crafter_name($n)
		
		; Checks if the crafter is already counted as available,
		; 	so these are not appended to $available_crafters again
		foreach $available_crafters ($j, $n2)
			if $n == $n2
				$is_available = 1
				break
		if $is_available
			continue
		
		; If it is not already counted as available, check if it is crafting or not
		; 	and proceed accordingly
		var $p = @Crafter_progress($c_name)
		if $p == -1
			@error("Error in crafter " & $c_name);
		if $p <= 0 or $p >= 1
			@Cancel_craft($c_name)
			$available_crafters.append($n)
		
	
function @Craft_with_select($item:text) : number
	; Selects an available crafter to craft the item
	; returns 1 if successul and 0 if not
	if @Any_crafters_available()
		@Start_craft(@Crafter_name($available_crafters.last), $item)
		$available_crafters.pop()
		return 1
	return 0
	
	
function @Missing_items($item:text, $quantity:number) : text
	; Gets which and how many items the system does not have in containers
	;	in order to craft a specific $quantity of $item
	var $container_items = @Get_resource_items()
	var $missing_items = ""
	var $recipe = get_recipe("crafter", $item)
	; Checks if the recipe can be done in a crafter
	if $recipe
		foreach $recipe ($k, $v)
			; Skips fluid checks, since we assume to have them
			if $k == "H2" or $k == "O2" or $k == "H2O"
				continue
			; Checks if there are enough items in store
			if $container_items.$k < $v * $quantity
				; Checks if the missing item can be crafted
				if get_recipe("crafter", $k)
					; Appends to the missing items list
					$missing_items.$k = $v * $quantity - $container_items.$k
				else
					@error("Missing item that is not craftable: " & $k)
	else
		@error("Recipe needed can't be done in a crafter: " & $item)
	return $missing_items
		
		
function @S_append($recipe:text)
	; Appends a recipe to the top of the stack
	; Recipe is a K{V} string
	$craft_S.append($recipe)
	
	
function @S_pop()
	; Pops the recipe at the top of the stack
	$craft_S.pop()

		
function @S_top_craft()
	; Crafts the last recipe of the stack
	; Also checks if the last recipe is done
	var $recipe = $craft_S.last
	var $stack_last = size($craft_S)-1
	var $zero_qtty = 0
	var $item_qtty = 0
	foreach $recipe ($item, $quantity)
		; Counts how many items there are in the recipe
		; 	and how many of those are already crafted ($quantity=0)
		$item_qtty++
		if $quantity <= 0
			$zero_qtty++
			continue
			
		; Checks for missing items to craft the item
		var $mi = @Missing_items($item, $quantity)
		; If needed, append missing items to the stack
		if $mi
			@S_append($mi)
			continue
			
		; Else, try to craft 1 of the current item
		; Craft_with_select returns 1 only if it found an available crafter for this
		if @Craft_with_select($item)
			; Updates the amount of items to craft
			$craft_S.$stack_last.$item -= 1
	
	; If all items are crafted, simply pop this recipe
	if $item_qtty == $zero_qtty and @All_crafters_available()
		@S_pop()
		
			
			
function @print_Q()
	; Prints the queue in a decent format
	if $craft_Q.size == 0
		return
	print("Queue:")
	foreach $craft_Q ($i, $item)
		print(text("   {}: {}", $i, $item))
		
function @print_S_root()
	; Prints the stack in a decent format
	if $craft_S.size == 0
		return
	print("Stack root:")
	var $S_root = $craft_S.0
	foreach $S_root ($i, $item)
		print(text("   {}: {}", $i, $item))
			
function @Q_append($item:text)
	; Append an item to last place on crafting queue
	$craft_Q.append($item)
			
function @Q_append_amount($item:text, $amount:number)
	; Append an item to last place on crafting queue
	$craft_Q.append("." & $item & "{" & text($amount) & "}")
	
function @Q_append_single($item:text)
	; Append an item to last place on crafting queue
	$craft_Q.append("." & $item & "{1}")
	
function @Q_progress() : number
	; Progress function based on maximum queue size
	if $max_craft_Q_size
		if $craft_Q.size > $max_craft_Q_size
			$max_craft_Q_size = $craft_Q.size
		return 1-$craft_Q.size/$max_craft_Q_size
	$max_craft_Q_size = $craft_Q.size	
	
	; Fake progress function to show
	if $craft_Q.size
		return 1-pow(2.71828, -$craft_Q.size/3)
	return 1
	
function @S_progress() : number
	; Progress function based on maximum queue size
	if $max_craft_S_size
		if $craft_S.size > $max_craft_S_size
			$max_craft_S_size = $craft_S.size
		return 1-$craft_S.size/$max_craft_S_size
	$max_craft_S_size = $craft_S.size	
	
	; "Fake" progress function to show
	if $craft_S.size
		return 1-pow(2.71828, -$craft_S.size/3)
	return 1
	
function @Current_items() : text
	; Returns the current items being crafted (Stack's last items)
	if $craft_S.size
		return $craft_S.last
	else
		return ""
		
function @Queued_items() : text
	; Gets the queued and stacked items as a .key{value} text
	var $items = ""
	if $craft_S.size
		var $S_item = $craft_S.0
		foreach $S_item ($k, $v)
			$items.$k += $v
	if $craft_Q.size
		foreach $craft_Q ($i, $order)
			foreach $order ($k, $v)
				$items.$k += $v
	return $items
	
function @Crafting_empty() : number
	; Returns 1 if the autocrafting queue AND stack are empty
	if $craft_Q.size or $craft_S.size
		return 0
	return 1
			
			
function @Q_to_S()
	;@print_Q()
	;@print_S_root()
	; Moves the first item of the queue into the stack for crafting
	var $item = $craft_Q.0
	$craft_Q.erase(0)
	@S_append($item)
	; print($item)
	
		
; =-=-=-=-=-=-=-=-= A U T O   C R A F T I N G =-=-=-=-=-=-=-=-=

function @Set_AC_value($item:text, $qtty:number)
	; Overwrites the amount to craft of an item
	if $item
		$autocraft_items.$item = max($qtty, 0)
		
function @Add_AC_value($item:text, $qtty:number)
	; Adds to the amount to craft of an item
	if $item
		$autocraft_items.$item = max($autocraft_items.$item+$qtty, 0)
		
function @Sub_AC_value($item:text, $qtty:number)
	; Substracts from the amount to craft of an item
	if $item
		$autocraft_items.$item = max($autocraft_items.$item-$qtty, 0)
	
function @Get_AC_qtty($item:text) : number
	; Gets the amount to keep in stock for a specific item
	if $item == ""
		return 0
	if $item and $autocraft_items.$item
		return $autocraft_items.$item
	return 0

function @Queued_and_available_items() : text
	; Collection of all available items if the queue and stack gets crafted
	var $Q_items = @Queued_items()
	var $container_items = @Get_available_items()
	foreach $Q_items ($k, $v)
		$container_items.$k += $v
	return $container_items

function @Missing_autocrafting_items()
	; Checks which items are set to be autocrafted but have an inferior amount
	
	; Only does this while the crafting queue and stack are empty,
	;	otherwise it could lead to extra items being crafted due to
	;	the check coinciding with crafters working
	if $craft_Q.size != 0 or $craft_S.size != 0
		return

	var $all_items = @Queued_and_available_items()
	if !size($autocraft_items)
		return
	foreach $autocraft_items ($k, $v)
		if $v > $all_items.$k
			; print(text("{}: {}", $k, $v-$all_items.$k))
			@Q_append_amount($k, $v-$all_items.$k)

		
		
timer frequency $output_frequency
	; Checks if it wasn't crafting recently to output items
	; This is necessary to stop needed COMPONENTS (category of items)
	; 	 being treated as output
	if !$was_crafting
		var $output_list = @Output_item_list()
		if $output_list == ""
			@Stop_output()
		else
			foreach $output_list ($k, $v)
				output_number($output_conveyor, 1, $v*$output_frequency)
				output_text($output_conveyor, 2, $k)
				break
	else
		@Stop_output()
		
		
	$was_crafting = !@Crafting_empty() or !@All_crafters_available()
	
		
tick
	; If there is an error, stops everything
	if $is_error
		return
		
	; Updates available crafters for this tick
	@Update_crafter_availability()
	
	; Outputs item if the queue and stack are empty
	if @Crafting_empty()
		output_number($output_conveyor, 0, 1)
		return
	else
		@Stop_output()
	
	; Check if there are crafters available
	if !$available_crafters.size
		return
	
	; Checks if the stack has items to craft
	if $craft_S.size < 1
		if $craft_Q.size < 1
			return
		@Q_to_S()
		
	; Craft the top stack item
	@S_top_craft()