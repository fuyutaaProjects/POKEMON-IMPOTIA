module PFM
  # The text parser of PSDK (retrieve text from Studio::Text)
  # @author Nuri Yuri
  module Text
    @variables = {}
    @plural = Array.new(7, false)
    # Pokemon Nickname var catcher
    PKNICK = Array.new(7) { |i| "[VAR PKNICK(000#{i})]" }
    # Pokemon name var catcher
    PKNAME = Array.new(7) { |i| "[VAR PKNAME(000#{i})]" }
    # Trainer name var catcher
    TRNAME = Array.new(7) { |i| "[VAR TRNAME(000#{i})]" }
    # Item var catcher
    ITEM2 = ['[VAR ITEM2(0000)]', '[VAR ITEM2(0001)]', '[VAR ITEM2(0002)]', '[VAR ITEM2(0003)]']
    # Definite article catcher
    ITEMPLUR1 = ['[VAR ITEMPLUR1]']
    # Move var catcher
    MOVE = ['[VAR MOVE(0000)]', '[VAR MOVE(0001)]', '[VAR MOVE(0002)]']
    # Number var catcher
    NUMB = [nil.to_s, '[VAR NUM1(0000)]', '[VAR NUM1(0001)]']
    # Number 3 var catcher
    NUM3 = ['[VAR NUM3(0000)]', '[VAR NUM3(0001)]', '[VAR NUM3(0002)]']
    # Number 2 var catcher
    NUM2 = ['[VAR NUM2(0000)]', '[VAR NUM2(0001)]', '[VAR NUM2(0002)]', '[VAR NUM2(0003)]']
    # Number 7 var catcher regexp
    NUM7R = /\[VAR NUM7[^\]]*\]/
    # Number x var catcher regexp
    NUMXR = /\[VAR NUM.[^\]]*\]/
    # Berry var catcher
    BERRY = [nil.to_s, nil.to_s, nil.to_s, nil.to_s, nil.to_s, nil.to_s, nil.to_s, '[VAR BERRY(0007)]']
    # Color var catcher
    COLOR = ['[VAR COLOR(0000)]', '[VAR COLOR(0001)]', '[VAR COLOR(0002)]', '[VAR COLOR(0003)]']
    # Location var catcher
    LOCATION = ['[VAR LOCATION(0000)]', '[VAR LOCATION(0001)]', '[VAR LOCATION(0002)]', '[VAR LOCATION(0003)]', '[VAR LOCATION(0004)]']
    # Ability var catcher
    ABILITY = ['[VAR ABILITY(0002)]', '[VAR ABILITY(0001)]', '[VAR ABILITY(0002)]']
    # Kaphotics decoded var clean regexp
    KAPHOTICS_Clean = /\[VAR [^\]]+\]/
    # /\[VAR .[A-Z\,\(\)a-z0-9]+\]/
    # Nummeric branch regexp catcher
    NUMBRNCH_Reg = /\[VAR NUMBRNCH\(....,....\)\][^\[]+/
    # Gender branch regexp catcher
    GENDBR_Reg = /\[VAR GENDBR\(....,....\)\][^\[]+/
    # Bell detector
    BELL_Reg = /\[VAR BE05\(([0-9]+)\)\]/
    # TODO!
    # Empty string (remove stuff)
    S_Empty = nil.to_s
    # Non breaking space '!' detector
    NBSP_B = / !/
    # Non breaking space '!' remplacement
    NBSP_R = ' !'
    # Automatic replacement of ... with the correct char
    Dot = ['...', '…']
    # Automatic replacement of the $ with a non breaking space $
    Money = [' $', ' $']
    module_function
    # Define generic constants adder to an object (Get var catcher easier)
    # @param obj [Class] the object that will receive constants
    def define_const(obj)
      obj.const_set(:PKNICK, PKNICK)
      obj.const_set(:PKNAME, PKNAME)
      obj.const_set(:TRNAME, TRNAME)
      obj.const_set(:ITEM2, ITEM2)
      obj.const_set(:ITEMPLUR1, ITEMPLUR1)
      obj.const_set(:MOVE, MOVE)
      obj.const_set(:NUMB, NUMB)
      obj.const_set(:NUM3, NUM3)
      obj.const_set(:NUM2, NUM2)
      obj.const_set(:COLOR, COLOR)
      obj.const_set(:LOCATION, LOCATION)
      obj.const_set(:ABILITY, ABILITY)
      obj.const_set(:NUM7R, NUM7R)
      obj.const_set(:NUMXR, NUMXR)
    end
    # Parse a text from the text database with specific informations
    # @param file_id [Integer] ID of the text file
    # @param text_id [Integer] ID of the text in the file
    # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
    # @return [String] the text parsed and ready to be displayed
    def parse(file_id, text_id, additionnal_var = nil)
      parse_with_pokemon(file_id, text_id, nil, additionnal_var)
    end
    # Parse a text from the text database with specific informations and a pokemon
    # @param file_id [Integer] ID of the text file
    # @param text_id [Integer] ID of the text in the file
    # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
    # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
    # @return [String] the text parsed and ready to be displayed
    def parse_with_pokemon(file_id, text_id, pokemon, additionnal_var = nil)
      text_id += ($game_temp.trainer_battle ? 2 : 1) if enemy_pokemon?(pokemon)
      text = Studio::Text.get(file_id, text_id).clone
      additionnal_var&.each { |expr, value| text.gsub!(expr, value || '<nil>') }
      @variables.each { |expr, value| text.gsub!(expr, value) }
      text.gsub!(PKNICK[0], pokemon.given_name) if pokemon
      parse_rest_of_thing(text)
      return text
    end
    # Detect if a Pokemon is an enemy Pokemon
    # @param pokemon [PFM::PokemonBattler]
    # @return [Boolean]
    def enemy_pokemon?(pokemon)
      return false unless $scene.is_a?(Battle::Scene)
      return false unless pokemon
      return pokemon.bank != 0 if pokemon.is_a?(PFM::PokemonBattler)
      return pokemon.position.nil? || pokemon.position < 0
    end
    # Parse a text from the text database with 2 pokemon & specific information
    # @param file_id [Integer] ID of the text file
    # @param text_id [Integer] ID of the text in the file
    # @param pokemon1 [PFM::Pokemon] pokemon we're talking about
    # @param pokemon2 [PFM::Pokemon] pokemon who originated the "problem" (eg. bind)
    # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
    # @return [String] the text parsed and ready to be displayed
    def parse_with_2pokemon(file_id, text_id, pokemon1, pokemon2, additionnal_var)
      if enemy_pokemon?(pokemon1)
        text_id += $game_temp.trainer_battle ? 5 : 3
        text_id += 1 if enemy_pokemon?(pokemon2)
      else
        if enemy_pokemon?(pokemon2)
          text_id += ($game_temp.trainer_battle ? 2 : 1)
        end
      end
      text = Studio::Text.get(file_id, text_id).clone
      additionnal_var&.each { |expr, value| text.gsub!(expr, value || '<nil>') }
      @variables.each { |expr, value| text.gsub!(expr, value) }
      text.gsub!(PKNICK[0], pokemon1.given_name)
      text.gsub!(PKNICK[1], pokemon2.given_name)
      parse_rest_of_thing(text)
      return text
    end
    # Parse a text from the text database with specific informations and two Pokemon
    # @param file_id [Integer] ID of the text file
    # @param text_id [Integer] ID of the text in the file
    # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
    # @param pokemon2 [PFM::Pokemon] second pokemon that will introduce an offset on text_id (its name is also used)
    # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
    # @return [String] the text parsed and ready to be displayed
    def parse_with_pokemons(file_id, text_id, pokemon, pokemon2, additionnal_var = nil)
      if enemy_pokemon?(pokemon)
        text_id += ($game_temp.trainer_battle ? 5 : 3)
        text_id += 1 if enemy_pokemon?(pokemon2)
      else
        if enemy_pokemon?(pokemon2)
          text_id += ($game_temp.trainer_battle ? 2 : 1)
        end
      end
      text = ::Studio::Text.get(file_id, text_id).clone
      additionnal_var&.each { |expr, value| text.gsub!(expr, value || '<nil>') }
      @variables.each { |expr, value| text.gsub!(expr, value) }
      text.gsub!(PKNICK[0], pokemon.given_name) if pokemon
      text.gsub!(PKNICK[1], pokemon2.given_name) if pokemon2
      parse_rest_of_thing(text)
      return text
    end
    # Parse the NUMBRNCH (pural)
    # @param text [String] text that will be parsed
    # @note Sorry for the code, when I did that I wasn't in the "clear" period ^^'
    def parse_numbrnch(text)
      text.gsub!(NUMBRNCH_Reg) do |s|
        index, quant = s.split(',').collect { |element| element.to_i(16) }
        ret = s.split(']')[1]
        if @plural[index]
          beg = quant & 0xFF
          len = quant >> 8
          end_position = beg + len
        else
          beg = 0
          len = quant & 0xFF
          end_position = len + (quant >> 8)
        end
        len2 = ret.size - end_position
        next((ret[beg, len] + ret[end_position, len2].to_s))
      end
    end
    # Parse the GENDBR (gender of the player, I didn't see other case)
    # @param text [String] text that will be parsed
    # @note Sorry for the code, when I did that I wasn't in the "clear" period ^^'
    def parse_gendbr(text)
      text.gsub!(GENDBR_Reg) do |s|
        quant = s.split(',')[1].to_i(16)
        ret = s.split(']')[1]
        if $trainer.playing_girl
          beg = quant & 0xFF
          len = quant >> 8
          end_position = beg + len
        else
          beg = 0
          len = quant & 0xFF
          end_position = len + (quant >> 8)
        end
        len2 = ret.size - end_position
        next((ret[beg, len] + ret[end_position, len2].to_s))
      end
    end
    # Perform the rest of the automatic parse (factorization)
    # @param text [String] text that will be parsed
    def parse_rest_of_thing(text)
      parse_numbrnch(text)
      parse_gendbr(text)
      text.gsub!(KAPHOTICS_Clean, S_Empty)
      text.gsub!(NBSP_B, NBSP_R)
    end
    # Define an automatic var catcher with its value
    # @param expr [String, Regexp] the var catcher that is replaced by the value
    # @param value [String] the value that replace the expr
    def set_variable(expr, value)
      @variables[expr] = value.to_s.force_encoding(Encoding::UTF_8)
    end
    # Remove an automatic var catcher with its value
    # @param expr [String, Regexp] the var catcher that is replaced by a value
    def unset_variable(expr)
      @variables.delete(expr)
    end
    # Remove every automatic var catcher defined
    def reset_variables
      @variables.clear
    end
    # Set the numbranches to plural state
    # @param value_or_index [Integer, Boolean] the value for all branch or the index you want to set in pural
    # @param value [Boolean] the value when you choosed an index
    def set_plural(value_or_index = true, value = true)
      if value_or_index.is_a?(Integer)
        @plural[value_or_index] = value
      else
        @plural.collect! {value_or_index }
      end
    end
    # The \\ temporary replacement
    S_000 = "\x00"
    # Parse a string for a message
    # @param text [String] the message
    # @return [String] the parsed message
    def parse_string_for_messages(text)
      return text.dup if text.empty?
      text = detect_dialog(text).dup
      text.gsub!(/\\\\/, S_000)
      text.gsub!(/\\v\[([0-9]+)\]/i) {$game_variables[$1.to_i] }
      text.gsub!(/\\n\[([0-9]+)\]/i) {$game_actors[$1.to_i]&.name }
      text.gsub!(/\\p\[([0-9]+)\]/i) {$actors[$1.to_i - 1]&.name }
      text.gsub!(/\\k\[([^\]]+)\]/i) {get_key_name($1) }
      text.gsub!('\\E') {$game_switches[Yuki::Sw::Gender] ? 'e' : nil }
      text.gsub!(/\\f\[([^\]]+)\]/i) {$1.split('§')[$game_switches[Yuki::Sw::Gender] ? 0 : 1] }
      text.gsub!(/\\t\[([0-9]+), *([0-9]+)\]/i) {::PFM::Text.parse($1.to_i, $2.to_i) }
      text.gsub!(*Dot)
      text.gsub!(*Money)
      @variables.each { |expr, value| text.gsub!(expr, value) }
      text.gsub!(KAPHOTICS_Clean, S_Empty)
      return text
    end
    # Detect a dialog text from message and return it instead of text
    # @param text [String]
    def detect_dialog(text)
      if (match = text.match(/^([0-9]+),( |)([0-9]+)/))
        text = Studio::Text.get_dialog_message(match[1].to_i, match[3].to_i)
      end
      return text
    end
    # The InGame key name to their key value association
    GameKeys = {0 => 'KeyError', 'a' => :A, 'b' => :B, 'x' => :X, 'y' => :Y, 'l' => :L, 'r' => :R, 'l2' => :L2, 'r2' => :R2, 'select' => :SELECT, 'start' => :START, 'l3' => :L3, 'r3' => :R3, 'down' => :DOWN, 'left' => :LEFT, 'right' => :RIGHT, 'up' => :UP, 'home' => :HOME}
    # Return the real keyboard key name
    # @param name [String] the InGame key name
    # @return [String] the keyboard key name
    def get_key_name(name)
      key_id = GameKeys[name.downcase]
      return GameKeys[0] unless key_id
      key_value = Input::Keys[key_id][0]
      return "J#{-(key_value + 1) / 32 + 1}K#{(-key_value - 1) % 32}" if key_value < 0
      keybd = Input::Keyboard
      keybd.constants.each do |key_name|
        return key_name.to_s if keybd.const_get(key_name) == key_value
      end
      return GameKeys[0]
    end
    # Set the Pokemon Name variable
    # @param value [String, PFM::Pokemon]
    # @param index [Integer] index of the pkname variable
    def set_pkname(value, index = 0)
      value = value.name if value.is_a?(PFM::Pokemon)
      set_variable(PKNAME[index].to_s, value.to_s)
    end
    # Set the Pokemon Nickname variable
    # @param value [String, PFM::Pokemon]
    # @param index [Integer] index of the pknick variable
    def set_pknick(value, index = 0)
      value = value.given_name if value.is_a?(PFM::Pokemon)
      set_variable(PKNICK[index].to_s, value.to_s)
    end
    # Set the item name variable
    # @param value [String, Symbol, Integer]
    # @param index [Integer] index of the item variable
    def set_item_name(value, index = 0)
      value = data_item(value).name if value.is_a?(Integer) || value.is_a?(Symbol)
      set_variable(ITEM2[index].to_s, value.to_s)
    end
    # Set the move name variable
    # @param value [String, Symbol, Integer]
    # @param index [Integer] index of the move variable
    def set_move_name(value, index = 0)
      value = data_move(value).name if value.is_a?(Integer) || value.is_a?(Symbol)
      set_variable(MOVE[index].to_s, value.to_s)
    end
    # Set the ability name variable
    # @param value [String, Symbol, Integer, PFM::Pokemon]
    # @param index [Integer] index of the move variable
    def set_ability_name(value, index = 0)
      value = data_ability(value).name if value.is_a?(Symbol) || value.is_a?(Integer)
      value = value.ability_name if value.is_a?(PFM::Pokemon)
      set_variable(ABILITY[index].to_s, value.to_s)
    end
    # Set the number1 variable
    # @param value [Integer, String]
    # @param index [Integer] index of the number1 variable
    def set_num1(value, index = 1)
      set_variable(NUMB[index].to_s, value.to_s)
    end
    # Set the number2 variable
    # @param value [Integer, String]
    # @param index [Integer] index of the number1 variable
    def set_num2(value, index = 0)
      set_variable(NUM2[index].to_s, value.to_s)
    end
    # Set the number2 variable
    # @param value [Integer, String]
    # @param index [Integer] index of the number1 variable
    def set_num3(value, index = 0)
      set_variable(NUM3[index].to_s, value.to_s)
    end
  end
  # Class that help to make choice inside Interfaces
  class Choice_Helper
    # Create a new Choice_Helper
    # @param klass [Class] class used to display the choice
    # @param can_cancel [Boolean] if the user can cancel the choice
    # @param cancel_index [Integer, nil] Index returned if the user cancel
    def initialize(klass, can_cancel = true, cancel_index = nil)
      @choices = []
      @class = klass
      @can_cancel = can_cancel
      @cancel_index = cancel_index
    end
    # Return the number of choices (for calculation)
    # @return [Integer]
    def size
      return @choices.size
    end
    # Cancel the choice from outside
    def cancel
      @canceled = true
    end
    # Register a choice
    # @param text [String]
    # @param disable_detect [#call, nil] handle to call to detect if the choice is disabled or not
    # @param on_validate [#call, nil] handle to call when the choice validated on this choice
    # @param color [Integer, nil] non default color to use on this choice
    # @param args [Array] arguments to send to the disable_detect and on_validate handler
    # @return [self]
    def register_choice(text, *args, disable_detect: nil, on_validate: nil, color: nil)
      @choices << {text: text, args: args, disable_detect: disable_detect, on_validate: on_validate, color: color}
      return self
    end
    # Display the choice
    # @param viewport [Viewport] viewport in wich the choice is shown
    # @param x [Integer] x coordinate of the choice window
    # @param y [Integer] y coordinate of the choice window
    # @param width [Integer] width of the choice window
    # @param on_update [#call, nil] handle to call during choice update
    # @param align_right [Boolean] tell if the x/y coordinate are the top right coordinate of the choice
    # @param args [Array] argument to send to the on_update handle
    # @return [Integer] the choice made by the user
    def display_choice(viewport, x, y, width, *args, on_update: nil, align_right: false)
      @canceled = false
      window = build_choice_window(viewport, x, y, width, align_right)
      loop do
        Graphics.update
        window.update
        on_update&.call(*args)
        break if check_cancel(window)
        break if check_validate(window)
      end
      $game_system.se_play($data_system.decision_se)
      index = window.index
      window.dispose
      call_validate_handle(index)
      return index
    end
    private
    # Build the choice window
    # @param viewport [Viewport] viewport in wich the choice is shown
    # @param x [Integer] x coordinate of the choice window
    # @param y [Integer] y coordinate of the choice window
    # @param width [Integer] width of the choice window
    # @param align_right [Boolean] tell if the x/y coordinate are the top right coordinate of the choice
    # @return [Yuki::ChoiceWindow]
    def build_choice_window(viewport, x, y, width, align_right)
      choice_list = @choices.collect { |c| c[:text] }
      window = @class.new(width, choice_list, viewport)
      window.set_position(x - (align_right ? window.width : 0), y)
      window.z = viewport ? viewport.z : 1000
      @choices.each_with_index do |c, i|
        if c[:disable_detect]&.call(*c[:args])
          window.colors[i] = window.get_disable_color
        else
          if c[:color]
            window.colors[i] = c[:color]
          end
        end
      end
      window.refresh
      Graphics.sort_z
      return window
    end
    # Check if the choice is validated (enabled and choosen by the player)
    # @param window [Choice_Window] the choice window
    def check_validate(window)
      return false unless window.validated?
      choice = @choices[window.index]
      return true unless choice[:disable_detect]
      if choice[:disable_detect].call(*choice[:args])
        $game_system.se_play($data_system.buzzer_se)
        return false
      end
      return true
    end
    # Check if the choice is canceled by the user
    # @param window [Choice_Window] the choice window
    def check_cancel(window)
      return false unless @can_cancel
      return false unless Input.trigger?(:B) || @canceled
      if @cancel_index && @cancel_index >= 0
        window.index = @cancel_index
      else
        if @cancel_index
          window.index = @choices.size + @cancel_index
        else
          window.index = @choices.size - 1
        end
      end
      return true
    end
    # Attempt to call the on_validate handle when the user has choosen an option
    # @param index [Integer] choice made by the user
    def call_validate_handle(index)
      choice = @choices[index]
      return unless choice
      return unless choice[:on_validate]
      choice[:on_validate].call(*choice[:args])
    end
  end
  # List of Processes that are called when a skill is used in map
  # Associate a skill id to a proc that take 3 parameter : pkmn(PFM::Pokemon), skill(PFM::Skill), test(Boolean)
  SKILL_PROCESS = {milk_drink: milk_drink = proc do |pkmn, _skill, test = false|
    next(:block) if pkmn.hp <= 0 && test
    next(:choice) if test
    if $actors[$scene.return_data] != pkmn && !pkmn.dead? && pkmn.hp != pkmn.max_hp
      heal_hp = pkmn.max_hp * 20 / 100
      $actors[$scene.return_data].hp -= heal_hp
      pkmn.hp += heal_hp
    else
      $scene.display_message(parse_text(22, 108))
    end
  end, soft_boiled: milk_drink, sweet_scent: proc do |_pkmn, _skill, test = false|
    next(false) if test
    if $env.normal?
      if $wild_battle.available?
        $game_system.map_interpreter.launch_common_event(Game_CommonEvent::WILD_BATTLE)
      else
        $scene.display_message(parse_text(39, 7))
      end
    else
      $scene.display_message(parse_text(39, 8))
    end
  end, fly: proc do |pkmn, _skill, test = false|
    next(false) if test
    if $game_switches[Yuki::Sw::Env_CanFly]
      GamePlay.open_town_map_to_fly($env.get_worldmap, pkmn)
      next(true)
    else
      next(:block)
    end
  end, surf: proc do |_pkmn, _skill, test = false|
    d = $game_player.direction
    x = $game_player.x
    y = $game_player.y
    z = $game_player.z
    new_x, new_y = $game_player.front_tile
    sys_tag = $game_map.system_tag(new_x, new_y)
    next(:block) unless $game_map.passable?(x, y, d, nil) && $game_map.passable?(new_x, new_y, 10 - d, $game_player) && z <= 1 && !$game_player.surfing? && Game_Character::SurfTag.include?(sys_tag)
    next(false) if test
    $game_temp.common_event_id = Game_CommonEvent::SURF_ENTER
    next(true)
  end}
  # The InGame Pokemon management
  # @author Nuri Yuri
  class Pokemon
    # List of chance to get a specific ability on Pokemon generation
    ABILITY_CHANCES = [49, 98, 100]
    # Unknown flag (should always be up in Pokemon)
    FLAG_UNKOWN_USE = 0x0080_0000
    # Flag telling the Pokemon comes from this game (this fangame)
    FLAG_FROM_THIS_GAME = 0x0040_0000
    # Flag telling the Pokemon has been caught by the player
    FLAG_CAUGHT_BY_PLAYER = 0x0020_0000
    # Flag telling the Pokemon comes from present time (used to distinguish pokemon imported from previous games)
    FLAG_PRESENT_TIME = 0x0010_0000
    # Flag that tells the Pokemon object to generate Shiny with IV starting at 15
    Shiny_IV = false
    # Create a new Pokemon with specific parameters
    # @param id [Integer, Symbol] ID of the Pokemon in the database
    # @param level [Integer] level of the Pokemon
    # @param force_shiny [Boolean] if the Pokemon have 100% chance to be shiny
    # @param no_shiny [Boolean] if the Pokemon have 0% chance to be shiny (override force_shiny)
    # @param form [Integer] Form index of the Pokemon (-1 = automatic generation)
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    # @option opts [String] :given_name Nickname of the Pokemon
    # @option opts [Integer, Symbol] :captured_with ID of the ball used to catch the Pokemon
    # @option opts [Integer] :captured_in ID of the zone where the Pokemon was caught
    # @option opts [Integer, Time] :captured_at Time when the Pokemon was caught
    # @option opts [Integer] :captured_level Level of the Pokemon when it was caught
    # @option opts [Integer] :egg_in ID of the zone where the egg was layed/found
    # @option opts [Integer, Time] :egg_at Time when the egg was layed/found
    # @option opts [Integer, String] :gender Forced gender of the Pokemon
    # @option opts [Integer] :nature Nature of the Pokemon
    # @option opts [Array<Integer>] :stats IV array ([hp, atk, dfe, spd, ats, dfs])
    # @option opts [Array<Integer>] :bonus EV array ([hp, atk, dfe, spd, ats, dfs])
    # @option opts [Integer, Symbol] :item ID of the item the Pokemon is holding
    # @option opts [Integer, Symbol] :ability ID of the ability the Pokemon has
    # @option opts [Integer] :rareness Rareness of the Pokemon (0 = not catchable, 255 = always catchable)
    # @option opts [Integer] :loyalty Happiness of the Pokemon
    # @option opts [Array<Integer, Symbol>] :moves Current Moves of the Pokemon (0 = default)
    # @option opts [Array(Integer, Integer)] :memo_text Text used for the memo ([file_id, text_id])
    # @option opts [String] :trainer_name Name of the trainer that caught / got the Pokemon
    # @option opts [Integer] :trainer_id ID of the trainer that caught / got the Pokemon
    def initialize(id, level, force_shiny = false, no_shiny = false, form = -1, opts = {})
      primary_data_initialize(id, level, force_shiny, no_shiny)
      catch_data_initialize(opts)
      form_data_initialize(form)
      stat_data_initialize(opts)
      moves_initialize(opts)
      item_holding_initialize(opts)
      ability_initialize(opts)
    end
    # Initialize the egg process of the Pokemon
    def egg_init
      @egg_in = $env.master_zone
      @egg_at = Time.new.to_i
      @step_remaining = data.hatch_steps
      @item_holding = 0
      $quests.get_egg
    end
    # Ends the egg process of the Pokemon
    def egg_finish
      @captured_in = $env.master_zone
      self.flags = (FLAG_UNKOWN_USE | FLAG_FROM_THIS_GAME | FLAG_PRESENT_TIME | FLAG_CAUGHT_BY_PLAYER)
      @captured_at = Time.new.to_i
      @trainer_id = $trainer.id
      @trainer_name = $trainer.name
    end
    private
    # Method assigning the ID, level, shiny property
    # @param id [Integer, Symbol] ID of the Pokemon in the database
    # @param level [Integer] level of the Pokemon
    # @param force_shiny [Boolean] if the Pokemon have 100% chance to be shiny
    # @param no_shiny [Boolean] if the Pokemon have 0% chance to be shiny (override force_shiny)
    def primary_data_initialize(id, level, force_shiny, no_shiny)
      real_id = id.is_a?(Symbol) ? data_creature(id).id : id.to_i
      log_error("Bad Pokémon ID (#{id}) - Ignore if you opened the Pokedex") if real_id == 0
      @id = real_id
      @db_symbol = data_creature(real_id).db_symbol
      code_initialize
      self.shiny = force_shiny if force_shiny
      self.shiny = !no_shiny if no_shiny
      @level = level.clamp(1, Float::INFINITY)
      @step_remaining = 0
      @ribbons = []
      @skill_learnt = []
      @skills_set = []
      @sub_id = nil
      @sub_code = nil
      @sub_form = nil
      @status = 0
      @status_count = 0
      @battle_stage = Array.new(7, 0)
      @position = 0
      @battle_turns = 0
      @mega_evolved = false
    end
    # Code generation in order to get a shiny
    def code_initialize
      shiny_attempts.clamp(1, Float::INFINITY).times do
        @code = rand(0xFFFF_FFFF)
        break if shiny
      end
    end
    # Number of attempt to generate a shiny
    # @return [Integer]
    def shiny_attempts
      n = 1
      n += 2 if $bag.contain_item?(:shiny_charm)
      n += 2 * $wild_battle.compute_fishing_chain
      return n
    end
    # Method that initialize the data related to caching
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def catch_data_initialize(opts)
      @captured_with = data_item(opts[:captured_with] || :poke_ball).id
      @captured_at = (opts[:captured_at] || Time.now).to_i
      @captured_level = opts[:captured_level] || @level
      @egg_in = opts[:egg_in]
      @egg_at = opts[:egg_at]
      @trainer_id = opts[:trainer_id] || $trainer.id
      @trainer_name = opts[:trainer_name] || $trainer.name
      @captured_in = opts[:captured_in] || $env.master_zone
      @given_name = opts[:given_name]
      @memo_text = opts[:memo_text]
      self.gender = opts[:gender] || (rand(100) < primary_data.female_rate ? 2 : 1)
      self.flags = (FLAG_UNKOWN_USE | FLAG_FROM_THIS_GAME | FLAG_PRESENT_TIME)
      self.flags |= FLAG_CAUGHT_BY_PLAYER if @trainer_id == $trainer.id && @trainer_name == $trainer.name
    end
    # Method that initialize data related to form
    # @param form [Integer] Form index of the Pokemon (-1 = automatic generation)
    def form_data_initialize(form)
      form = form_generation(form)
      form = 0 if data_creature(db_symbol).forms.none? { |creature_form| creature_form.form == form }
      @form = form
      exp_initialize
    end
    # Method that initialize the experience info of the Pokemon
    def exp_initialize
      self.exp = exp_list[@level].to_i
    end
    # Method that initialize the stat data
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def stat_data_initialize(opts)
      self.loyalty = opts[:loyalty] || data.base_loyalty
      self.rareness = opts[:rareness]
      ev_data_initialize(opts)
      iv_data_initialize(opts)
      nature_opts = opts[:nature].is_a?(Symbol) ? Configs.natures.db_symbol_to_id[opts[:nature]] : opts[:nature]
      @nature = (nature_opts || (@code >> 16)) % Configs.natures.data.size
      self.hp = max_hp
    end
    # Method that initialize the EV data
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def ev_data_initialize(opts)
      stats = Configs.stats
      @ev_hp = opts.dig(:bonus, stats.hp_index) || 0
      @ev_atk = opts.dig(:bonus, stats.atk_index) || 0
      @ev_dfe = opts.dig(:bonus, stats.dfe_index) || 0
      @ev_spd = opts.dig(:bonus, stats.spd_index) || 0
      @ev_ats = opts.dig(:bonus, stats.ats_index) || 0
      @ev_dfs = opts.dig(:bonus, stats.dfs_index) || 0
    end
    # Method that initialize the IV data
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def iv_data_initialize(opts)
      iv_base = (Shiny_IV && shiny? ? 16 : 0)
      iv_rand = (Shiny_IV && shiny? ? 16 : 32)
      stats = Configs.stats
      @iv_hp = (opts.dig(:stats, stats.hp_index) || (Random::IV_HP.rand(iv_rand) + iv_base)).clamp(0, 31)
      @iv_atk = (opts.dig(:stats, stats.atk_index) || (Random::IV_ATK.rand(iv_rand) + iv_base)).clamp(0, 31)
      @iv_dfe = (opts.dig(:stats, stats.dfe_index) || (Random::IV_DFE.rand(iv_rand) + iv_base)).clamp(0, 31)
      @iv_spd = (opts.dig(:stats, stats.spd_index) || (Random::IV_SPD.rand(iv_rand) + iv_base)).clamp(0, 31)
      @iv_ats = (opts.dig(:stats, stats.ats_index) || (Random::IV_ATS.rand(iv_rand) + iv_base)).clamp(0, 31)
      @iv_dfs = (opts.dig(:stats, stats.dfs_index) || (Random::IV_DFS.rand(iv_rand) + iv_base)).clamp(0, 31)
    end
    # Method that initialize the move set
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def moves_initialize(opts)
      move_set = data.move_set.select(&:level_learnable?).sort_by(&:level).reverse
      move_set.each do |move|
        next unless move.level.between?(0, level)
        learn_skill(move.move)
      end
      skills_set.reverse!
      load_skill_from_array(opts[:moves]) if opts[:moves]
    end
    # Method that initialize the held item
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def item_holding_initialize(opts)
      return @item_holding = data_item(opts[:item]).id if opts[:item]
      items = data.item_held
      rng = rand(100)
      item_holding = items.find do |item|
        next(true) if rng < item.chance
        rng -= item.chance
        next(false)
      end
      @item_holding = item_holding ? data_item(item_holding.db_symbol).id : 0
    end
    # Method that initialize the ability
    # @param opts [Hash] Hash describing optional value you want to assign to the Pokemon
    def ability_initialize(opts)
      ability = data.abilities
      if opts[:ability]
        @ability = opts[:ability]
      else
        ability_chance = rand(100)
        @ability = ability[@ability_index = ABILITY_CHANCES.find_index { |value| value > ability_chance }]
      end
      @ability = data_ability(@ability).id unless @ability.is_a?(Integer)
      @ability_used = false
    end
    public
    # ID of the Pokemon in the database
    # @return [Integer]
    attr_reader :id
    # Current Level of the Pokemon
    # @return [Integer]
    attr_reader :level
    # The total amount of exp the Pokemon got
    # @return [Integer]
    attr_accessor :exp
    # The current HP the Pokemon has
    # @return [Integer]
    attr_reader :hp
    # Code of the pokemon
    # @return [Integer]
    attr_accessor :code
    # Number of step before the egg hatch (thus the Pokemon is an egg)
    # @return [Integer]
    attr_accessor :step_remaining
    # ID of the item used to catch the Pokemon
    # @return [Integer]
    attr_accessor :captured_with
    # Zone (id) where the Pokemon was captured mixed with the Gemme 4.0 Flag
    # @return [Integer]
    attr_accessor :captured_in
    # Time when the Pokemon was captured (in seconds from jan 1970)
    # @return [Integer]
    attr_accessor :captured_at
    # Level of the Pokemon when the Pokemon was caught
    # @return [Integer]
    attr_accessor :captured_level
    # Zone (id) where the Egg has been obtained
    # @return [Integer]
    attr_accessor :egg_in
    # Time when the Egg has been obtained
    # @return [Integer]
    attr_accessor :egg_at
    # ID of the original trainer
    # @return [Integer]
    attr_writer :trainer_id
    # Name of the original trainer
    # @return [String]
    attr_accessor :trainer_name
    # The name given to the Pokemon
    # @return [String]
    attr_accessor :given_name
    # Gender of the Pokemon : 0 = no gender, 1 = male, 2 = female
    # @return [Integer]
    attr_reader :gender
    # Happiness/loyalty of the Pokemon (0 no bonds, 255 full bonds)
    # @return [Integer]
    attr_reader :loyalty
    # Form Index of the Pokemon, ex: Unkown A = 0, Unkown Z = 25
    # @return [Integer]
    attr_reader :form
    # HP Effort Value
    # @return [Integer]
    attr_accessor :ev_hp
    # ATK Effort Value
    # @return [Integer]
    attr_accessor :ev_atk
    # DFE Effort Value
    # @return [Integer]
    attr_accessor :ev_dfe
    # SPD Effort Value
    # @return [Integer]
    attr_accessor :ev_spd
    # ATS Effort Value
    # @return [Integer]
    attr_accessor :ev_ats
    # DFS Effort Value
    # @return [Integer]
    attr_accessor :ev_dfs
    # HP Individual Value
    # @return [Integer]
    attr_accessor :iv_hp
    # ATK Individual Value
    # @return [Integer]
    attr_accessor :iv_atk
    # DFE Individual Value
    # @return [Integer]
    attr_accessor :iv_dfe
    # SPD Individual Value
    # @return [Integer]
    attr_accessor :iv_spd
    # ATS Individual Value
    # @return [Integer]
    attr_accessor :iv_ats
    # DFS Individual Value
    # @return [Integer]
    attr_accessor :iv_dfs
    # ID of the Pokemon's nature (in the database)
    # @return [Integer]
    attr_writer :nature
    # The rate of HP the Pokemon has
    # @return [Float]
    attr_accessor :hp_rate
    # The rate of exp point the Pokemon has in its level
    # @return [Float]
    attr_accessor :exp_rate
    # ID of the item the Pokemon is holding
    # @return [Integer]
    attr_accessor :item_holding
    # First type ID of the Pokemon
    # @return [Integer]
    attr_writer :type1
    # Second type ID of the Pokemon
    # @return [Integer]
    attr_writer :type2
    # Third type ID of the Pokemon (moves/Mega)
    # @return [Integer]
    attr_writer :type3
    # Character filename of the Pokemon (FollowMe optimizations)
    # @return [String]
    attr_accessor :character
    # Memo text [file_id, text_id]
    # @return [Array<Integer>]
    attr_accessor :memo_text
    # List of Ribbon ID the Pokemon got
    # @return [Array<Integer>]
    attr_accessor :ribbons
    # List of Skill id the Pokemon learnt during its life
    # @return [Array<Integer>]
    attr_reader :skill_learnt
    # The current moveset of the Pokemon
    # @return [Array<PFM::Skill>] 4 or less moves
    attr_accessor :skills_set
    # Check whether the ability has been already used in battle
    # @return [Boolean]
    attr_accessor :ability_used
    # ID of the Pokemon ability in the database
    # @return [Integer]
    attr_writer :ability
    # Index of the ability in the Pokemon data
    # @return [Integer, nil]
    attr_accessor :ability_index
    # ID of the status of the Pokemon
    # @return [Integer]
    attr_accessor :status
    # Internal status counter that helps some status to terminate or worsen
    # @return [Integer]
    attr_accessor :status_count
    # The battle Stage of the Pokemon [atk, dfe, spd, ats, dfs, eva, acc]
    # @return [Array(Integer, Integer, Integer, Integer, Integer, Integer, Integer)]
    attr_accessor :battle_stage
    # The Pokemon critical modifier (always 0 but usable for scenaristic reasons...)
    # @return [Integer]
    attr_writer :critical_modifier
    def critical_modifier
      @critical_modifier || 0
    end
    # The position in the Battle, > 0 = actor, < 0 = enemy (index = -position-1), nil = not fighting
    # @return [Integer, nil]
    attr_accessor :position
    # If the pokemon is confused
    # @return [Boolean]
    attr_accessor :confuse
    # Number of turn the Pokemon has fought
    # @return [Integer]
    attr_accessor :battle_turns
    # Attack order value tells when the Pokemon attacks (used to test if attack before another pokemon)
    # @return [Integer]
    attr_accessor :attack_order
    # ID of the skill the Pokemon would like to use
    # @return [Integer]
    attr_accessor :prepared_skill
    # Real id of the Pokemon when used transform
    # @return [Integer, nil]
    attr_accessor :sub_id
    # Real code of the Pokemon when used transform (needed to test if roaming pokemon is ditto)
    # @return [Integer, nil]
    attr_accessor :sub_code
    # Real form index of the Pokemon when used transform (needed to test if roaming pokemon is ditto)
    # @return [Integer, nil]
    attr_accessor :sub_form
    # ID of the item the Pokemon is holding in battle
    # @return [Integer, nil]
    attr_accessor :battle_item
    # Various data information of the item during battle
    # @return [Array, nil]
    attr_accessor :battle_item_data
    # Get the primary data of the Pokemon
    # @return [Studio::CreatureForm]
    def primary_data
      data_creature(db_symbol).forms[0]
    end
    # Get the current data of the Pokemon
    # @return [Studio::CreatureForm]
    def data
      data_creature(db_symbol).forms.find { |creature_form| creature_form.form == form } || primary_data
    end
    alias get_data data
    # Give the maximum level of the Pokemon
    # @return [Integer]
    def max_level
      infinity = Float::INFINITY
      return [@max_level || infinity, PFM.game_state.level_max_limit || infinity, Configs.settings.max_level].min.clamp(1, Float::INFINITY)
    end
    # Set the maximum level of the Pokemon
    # @param level [Integer, nil]
    def max_level=(level)
      @max_level = level.is_a?(Integer) ? level : nil
    end
    # Get the shiny attribute
    # @return [Boolean]
    def shiny?
      return (@code & 0xFFFF) < shiny_rate || @shiny
    end
    alias shiny shiny?
    # Set the shiny attribut
    # @param shiny [Boolean]
    def shiny=(shiny)
      @code = (@code & 0xFFFF0000) | (shiny ? 0 : 0xFFFF)
    end
    # Give the shiny rate for the Pokemon, The number should be between 0 & 0xFFFF.
    # 0 means absolutely no chance to be shiny, 0xFFFF means always shiny
    # @return [Integer]
    def shiny_rate
      16
    end
    # Return the db_symbol of the Pokemon in the database
    # @return [Symbol]
    def db_symbol
      return @db_symbol ||= data_creature(id).db_symbol
    end
    # Tell if the Pokemon is an egg or not
    # @return [Boolean]
    def egg?
      return @step_remaining > 0
    end
    alias egg egg?
    # Set the captured_in flags (to know from which game the pokemon came from)
    # @param flag [Integer] the new flag
    def flags=(flag)
      @captured_in = zone_id | (flag & 0xFFFF_0000)
    end
    # Get Pokemon flags
    # @return [Integer]
    def flags
      return @captured_in & 0xFFFF_0000
    end
    # Tell if the pokemon is from a past version
    # @return [Boolean]
    def from_past?
      return !flags.anybits?(FLAG_PRESENT_TIME)
    end
    # Tell if the Pokemon is caught by the trainer
    # @return [Boolean]
    def caught_by_player?
      return flags.anybits?(FLAG_CAUGHT_BY_PLAYER)
    end
    # Get the zone id where the Pokemon has been found
    # @param special_zone [Integer, nil] if you want to use this function for stuff like egg_zone_id
    def zone_id(special_zone = nil)
      (special_zone || @captured_in) & 0x0000FFFF
    end
    # Set the gender of the Pokemon
    # @param gender [Integer]
    def gender=(gender)
      if primary_data.female_rate == -1
        @gender = 0
      else
        if primary_data.female_rate == 0
          @gender = 1
        else
          if primary_data.female_rate == 100
            @gender = 2
          else
            gender = ['i', 'm', 'f'].index(gender.downcase).to_i if gender.is_a?(String)
            @gender = gender.clamp(0, 2)
          end
        end
      end
    end
    alias set_gender gender=
    # Tell if the Pokemon is genderless
    # @return [Boolean]
    def genderless?
      gender == 0
    end
    # Tell if the Pokemon is a male
    # @return [Boolean]
    def male?
      gender == 1
    end
    # Tell if the Pokemon is a female
    # @return [Boolean]
    def female?
      gender == 2
    end
    # Change the Pokemon Loyalty
    # @param loyalty [Integer] new loyalty value
    def loyalty=(loyalty)
      @loyalty = loyalty.clamp(0, 255)
    end
    # Return the nature data of the Pokemon
    # @return [Array<Integer>] [text_id, atk%, dfe%, spd%, ats%, dfs%]
    def nature
      return Configs.natures[nature_id]
    end
    # Return the nature id of the Pokemon
    # @return [Integer]
    def nature_id
      return @nature
    end
    # Return the Pokemon rareness
    # @return [Integer]
    def rareness
      return @rareness || data.catch_rate
    end
    # Change the Pokemon rareness
    # @param v [Integer, nil] the new rareness of the Pokemon
    def rareness=(v)
      @rareness = v&.clamp(0, 255)
    end
    # Return the height of the Pokemon
    # @return [Numeric]
    def height
      return data.height
    end
    # Return the weight of the Pokemon
    # @return [Numeric]
    def weight
      return data.weight
    end
    # Return the ball sprite name of the Pokemon
    # @return [String] Sprite to load in Graphics/ball/
    def ball_sprite
      item = data_item(@captured_with)
      return 'ball_1' unless item.is_a?(Studio::BallItem)
      return Studio::BallItem.from(item).img
    end
    # Return the ball color of the Pokemon (flash)
    # @return [Color]
    def ball_color
      item = data_item(@captured_with)
      return Color.new(0, 0, 0) unless item.is_a?(Studio::BallItem)
      return Studio::BallItem.from(item).color
    end
    # Return the normalized trainer id of the Pokemon
    # @return [Integer]
    def trainer_id
      return @trainer_id % 100_000
    end
    # Return if the Pokemon is from the player (he caught it)
    # @return [Boolean]
    def from_player?
      return flags.anybits?(FLAG_CAUGHT_BY_PLAYER)
    end
    # Return the db_symbol of the Pokemon's item held
    # @return [Symbol]
    def item_db_symbol
      return data_item($game_temp.in_battle ? (@battle_item || @item_holding) : @item_holding).db_symbol
    end
    # Alias for item_holding
    # @return [Integer]
    def item_hold
      return @item_holding
    end
    # Return the current ability of the Pokemon
    # @return [Integer]
    def ability
      return @ability
    end
    # Return the db_symbol of the Pokemon's Ability
    # @return [Symbol]
    def ability_db_symbol
      data_ability(ability).db_symbol
    end
    # Add a ribbon to the Pokemon
    # @param id [Integer] ID of the ribbon (in the ribbon text file)
    def add_ribbon(id)
      return unless id.between?(0, 50)
      @ribbons << id unless @ribbons.include?(id)
    end
    # Has the pokemon got a ribbon ?
    # @return [Boolean]
    def ribbon_got?(id)
      return @ribbons.include?(id)
    end
    public
    # All possible attempt of finding an egg (for legacy)
    # @todo Change this later
    EGG_FILENAMES = ['egg_%<id>03d_%<form>02d', 'egg_%<id>03d', 'egg_%<name>s_%<form>02d', 'egg_%<name>s', 'egg']
    # Size of a battler
    BATTLER_SIZE = 96
    # Size of an icon
    ICON_SIZE = 32
    # Size of a footprint
    FOOT_SIZE = 16
    # Return the ball image of the Pokemon
    # @return [Texture]
    def ball_image
      return RPG::Cache.ball(ball_sprite)
    end
    class << self
      # Icon filename of a Pokemon
      # @param id [Integer] ID of the Pokemon
      # @param form [Integer] form index of the Pokemon
      # @param female [Boolean] if the Pokemon is a female
      # @param shiny [Boolean] shiny state of the Pokemon
      # @param egg [Boolean] egg state of the Pokemon
      # @return [String]
      def icon_filename(id, form, female, shiny, egg)
        format_arg = {id: id, form: form, name: data_creature(id).db_symbol}
        return correct_filename_from(EGG_FILENAMES, format_arg, RPG::Cache.method(:b_icon_exist?)) || EGG_FILENAMES.last if egg
        resources = data_creature_form(id, form).resources
        return missing_resources_error(id) unless resources
        return resources.icon_shiny_f if resources.has_female && shiny && female && !resources.icon_shiny_f.empty?
        return resources.icon_f if resources.has_female && female && !resources.icon_f.empty?
        return resources.icon_shiny if shiny && !resources.icon_shiny.empty?
        return resources.icon.empty? ? '000' : resources.icon
      end
      # Return the front battler name
      # @param id [Integer] ID of the Pokemon
      # @param form [Integer] form index of the Pokemon
      # @param female [Boolean] if the Pokemon is a female
      # @param shiny [Boolean] shiny state of the Pokemon
      # @param egg [Boolean] egg state of the Pokemon
      # @return [String]
      def front_filename(id, form, female, shiny, egg)
        format_arg = {id: id, form: form, name: data_creature(id).db_symbol}
        return correct_filename_from(EGG_FILENAMES, format_arg, RPG::Cache.method(:poke_front_exist?)) || EGG_FILENAMES.last if egg
        resources = data_creature_form(id, form).resources
        return missing_resources_error(id) unless resources
        return resources.front_shiny_f if resources.has_female && shiny && female && !resources.front_shiny_f.empty?
        return resources.front_f if resources.has_female && female && !resources.front_f.empty?
        return resources.front_shiny if shiny && !resources.front_shiny.empty?
        return resources.front.empty? || shiny ? '000' : resources.front
      end
      # Return the front gif name
      # @param id [Integer] ID of the Pokemon
      # @param form [Integer] form index of the Pokemon
      # @param female [Boolean] if the Pokemon is a female
      # @param shiny [Boolean] shiny state of the Pokemon
      # @param egg [Boolean] egg state of the Pokemon
      # @return [String, nil]
      def front_gif_filename(id, form, female, shiny, egg)
        hue = shiny ? 1 : 0
        cache_exist = proc { |filename| RPG::Cache.poke_front_exist?(filename, hue) }
        filename = front_filename(id, form, female, shiny, egg) + '.gif'
        return filename = filename_exist(filename, cache_exist)
      end
      # Return the back battler name
      # @param id [Integer] ID of the Pokemon
      # @param form [Integer] form index of the Pokemon
      # @param female [Boolean] if the Pokemon is a female
      # @param shiny [Boolean] shiny state of the Pokemon
      # @param egg [Boolean] egg state of the Pokemon
      # @return [String]
      def back_filename(id, form, female, shiny, egg)
        format_arg = {id: id, form: form, name: data_creature(id).db_symbol}
        return correct_filename_from(EGG_FILENAMES, format_arg, RPG::Cache.method(:poke_back_exist?)) || EGG_FILENAMES.last if egg
        resources = data_creature_form(id, form).resources
        return missing_resources_error(id) unless resources
        return resources.back_shiny_f if resources.has_female && shiny && female && !resources.back_shiny_f.empty?
        return resources.back_f if resources.has_female && female && !resources.back_f.empty?
        return resources.back_shiny if shiny && !resources.back_shiny.empty?
        return resources.back.empty? || shiny ? '000' : resources.back
      end
      # Return the back gif name
      # @param id [Integer] ID of the Pokemon
      # @param form [Integer] form index of the Pokemon
      # @param female [Boolean] if the Pokemon is a female
      # @param shiny [Boolean] shiny state of the Pokemon
      # @param egg [Boolean] egg state of the Pokemon
      # @return [String, nil]
      def back_gif_filename(id, form, female, shiny, egg)
        hue = shiny ? 1 : 0
        cache_exist = proc { |filename| RPG::Cache.poke_back_exist?(filename, hue) }
        filename = back_filename(id, form, female, shiny, egg) + '.gif'
        return filename = filename_exist(filename, cache_exist)
      end
      # Display an error in case of missing resources and fallback to the default one
      # @param id [Integer, Symbol] ID of the Pokemon
      # @return [String]
      def missing_resources_error(id)
        log_error("Missing resources error: Your Pokémon #{data_creature(id).name} has no resources in its data.")
        return '000'
      end
      private
      # Find the correct filename in a collection (for legacy egg sprites checks)
      # @param formats [Array<String>]
      # @param format_arg [Hash]
      # @param cache_exist [Method, Proc]
      # @return [String, nil] formated filename if it exists
      def correct_filename_from(formats, format_arg, cache_exist)
        formats.each do |filename_format|
          filename = format(filename_format, format_arg)
          return filename if cache_exist.call(filename)
        end
        return nil
      end
      # Check if the filename exists in the cache
      # @param filename [String]
      # @param cache_exist [Method, Proc]
      # @return [String, nil] filename if it exists
      def filename_exist(filename, cache_exist)
        return filename if cache_exist.call(filename)
        return nil
      end
    end
    # Return the icon of the Pokemon
    # @return [Texture]
    def icon
      return RPG::Cache.b_icon(PFM::Pokemon.icon_filename(id, form, female?, shiny?, egg?))
    end
    # Return the front battler of the Pokemon
    # @return [Texture]
    def battler_face
      return RPG::Cache.poke_front(PFM::Pokemon.front_filename(id, form, female?, shiny?, egg?), shiny? ? 1 : 0)
    end
    alias battler_front battler_face
    # Return the back battle of the Pokemon
    # @return [Texture]
    def battler_back
      return RPG::Cache.poke_back(PFM::Pokemon.back_filename(id, form, female?, shiny?, egg?), shiny? ? 1 : 0)
    end
    # Return the front offset y of the Pokemon
    # @return [Integer]
    def front_offset_y
      return data.front_offset_y
    end
    # Return the character name of the Pokemon
    # @return [String]
    def character_name
      unless @character
        resources = data_creature_form(id, form).resources
        filename = resources.character_shiny_f if shiny && female?
        filename ||= resources.character_f if female?
        filename ||= resources.character_shiny if shiny?
        @character = filename || resources.character || '000'
      end
      return @character
    end
    # Return the cry file name of the Pokemon
    # @return [String]
    def cry
      return nil.to_s if @step_remaining > 0
      cry = data&.resources&.cry
      return "Audio/SE/Cries/#{data.resources.cry}" if cry && !cry&.empty? && File.exist?("Audio/SE/Cries/#{cry}")
      return format('Audio/SE/Cries/%03dCry', @id)
    end
    # Return the GifReader face of the Pokemon
    # @return [::Yuki::GifReader, nil]
    def gif_face
      return nil unless @step_remaining
      filename = Pokemon.front_gif_filename(@id, @form, female?, shiny?, false)
      return filename && Yuki::GifReader.new(RPG::Cache.poke_front(filename, shiny? ? 1 : 0), true)
    end
    # Return the GifReader back of the Pokemon
    # @return [::Yuki::GifReader, nil]
    def gif_back
      return nil unless @step_remaining
      filename = Pokemon.back_gif_filename(@id, @form, female?, shiny?, false)
      return filename && Yuki::GifReader.new(RPG::Cache.poke_back(filename, shiny? ? 1 : 0), true)
    end
    public
    # Return the list of EV the pokemon gives when beaten
    # @return [Array<Integer>] ev list (used in bonus functions) : [hp, atk, dfe, spd, ats, dfs]
    def battle_list
      data = get_data
      return [data.ev_hp, data.ev_atk, data.ev_dfe, data.ev_spd, data.ev_ats, data.ev_dfs]
    end
    # Add ev bonus to a Pokemon (with item interaction : x2)
    # @param list [Array<Integer>] an ev list  : [hp, atk, dfe, spd, ats, dfs]
    # @return [Boolean, nil] if the ev had totally been added or not (nil = couldn't be added at all)
    def add_bonus(list)
      return nil if egg?
      stats = Configs.stats
      n = item_db_symbol == :macho_brace ? 2 : 1
      r = add_ev_hp(list[stats.hp_index] * n, total_ev)
      r &= add_ev_atk(list[stats.atk_index] * n, total_ev)
      r &= add_ev_dfe(list[stats.dfe_index] * n, total_ev)
      r &= add_ev_spd(list[stats.spd_index] * n, total_ev)
      r &= add_ev_ats(list[stats.ats_index] * n, total_ev)
      r &= add_ev_dfs(list[stats.dfs_index] * n, total_ev)
      return r
    end
    # Add ev bonus to a Pokemon (without item interaction)
    # @param list [Array<Integer>] an ev list  : [hp, atk, dfe, spd, ats, dfs]
    # @return [Boolean, nil] if the ev had totally been added or not (nil = couldn't be added at all)
    def edit_bonus(list)
      return nil if egg?
      stats = Configs.stats
      r = add_ev_hp(list[stats.hp_index], total_ev)
      r &= add_ev_atk(list[stats.atk_index], total_ev)
      r &= add_ev_dfe(list[stats.dfe_index], total_ev)
      r &= add_ev_spd(list[stats.spd_index], total_ev)
      r &= add_ev_ats(list[stats.ats_index], total_ev)
      r &= add_ev_dfs(list[stats.dfs_index], total_ev)
      return r
    end
    # Return the total amount of EV
    # @return [Integer]
    def total_ev
      return @ev_hp + @ev_atk + @ev_dfe + @ev_spd + @ev_ats + @ev_dfs
    end
    # Automatic ev adder using an index
    # @param index [Integer] ev index (see GameData::EV), should add 10. If index > 10 take index % 10 and add only 1 EV.
    # @param apply [Boolean] if the ev change is applied
    # @param count [Integer] number of EV to add
    # @return [Integer, false] if not false, the value of the current EV depending on the index
    def ev_check(index, apply = false, count = 1)
      evs = total_ev
      return false if evs >= Configs.stats.max_total_ev
      if index >= 10
        index = index % 10
        return (ev_var(index, evs, apply ? count : 0) < Configs.stats.max_stat_ev)
      else
        return (ev_var(index, evs, apply ? 10 : 0) < 100)
      end
    end
    # Get and add EV
    # @param index [Integer] ev index (see GameData::EV)
    # @param evs [Integer] the total ev
    # @param value [Integer] the quantity of EV to add (if 0 no add)
    # @return [Integer]
    def ev_var(index, evs, value = 0)
      stats = Configs.stats
      case index
      when stats.hp_index
        add_ev_hp(value, evs) if value > 0
        return @ev_hp
      when stats.atk_index
        add_ev_atk(value, evs) if value > 0
        return @ev_atk
      when stats.dfe_index
        add_ev_dfe(value, evs) if value > 0
        return @ev_dfe
      when stats.spd_index
        add_ev_spd(value, evs) if value > 0
        return @ev_spd
      when stats.ats_index
        add_ev_ats(value, evs) if value > 0
        return @ev_ats
      when stats.dfs_index
        add_ev_dfs(value, evs) if value > 0
        return @ev_dfs
      else
        return 0
      end
    end
    # Safely add HP EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_hp(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_hp > Configs.stats.max_stat_ev - 1
      @ev_hp += n
      @ev_hp = @ev_hp.clamp(0, Configs.stats.max_stat_ev)
      @hp = (@hp_rate * max_hp).round
      @hp_rate = @hp.to_f / max_hp
      return true
    end
    # Safely add ATK EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_atk(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_atk > Configs.stats.max_stat_ev - 1
      @ev_atk += n
      @ev_atk = @ev_atk.clamp(0, Configs.stats.max_stat_ev)
      return true
    end
    # Safely add DFE EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_dfe(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_dfe > Configs.stats.max_stat_ev - 1
      @ev_dfe += n
      @ev_dfe = @ev_dfe.clamp(0, Configs.stats.max_stat_ev)
      return true
    end
    # Safely add SPD EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_spd(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_spd > Configs.stats.max_stat_ev - 1
      @ev_spd += n
      @ev_spd = @ev_spd.clamp(0, Configs.stats.max_stat_ev)
      return true
    end
    # Safely add ATS EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_ats(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_ats > Configs.stats.max_stat_ev - 1
      @ev_ats += n
      @ev_ats = @ev_ats.clamp(0, Configs.stats.max_stat_ev)
      return true
    end
    # Safely add DFS EV
    # @param n [Integer] amount of EV to add
    # @param evs [Integer] total ev
    # @return [Boolean] if the ev has successfully been added
    def add_ev_dfs(n, evs)
      return true if n == 0
      n -= 1 while (evs + n) > Configs.stats.max_total_ev
      return false if @ev_dfs > Configs.stats.max_stat_ev - 1
      @ev_dfs += n
      @ev_dfs = @ev_dfs.clamp(0, Configs.stats.max_stat_ev)
      return true
    end
    public
    include Hooks
    # List of key in evolution Hash that corresponds to the expected ID when evolution is valid
    # @return [Array<Symbol>]
    SPECIAL_EVOLUTION_ID = %i[trade id]
    @evolution_criteria = {}
    @evolution_reason_required_criteria = {}
    class << self
      # List of evolution criteria
      # @return [Hash{ Symbol => Proc }]
      attr_reader :evolution_criteria
      # List of evolution criteria required for specific reason
      # @return [Hash{ Symbol => Array<Symbol> }]
      attr_reader :evolution_reason_required_criteria
      # Add a new evolution criteria
      # @param key [Symbol] hash key expected in special evolution
      # @param reasons [Array<Symbol>] evolution reasons that require this criteria in order to allow evolution
      # @param block [Proc] executed proc for special evolution test, will receive : value, extend_data, reason
      def add_evolution_criteria(key, reasons = nil, &block)
        @evolution_criteria[key] = block
        reasons&.each do |reason|
          (@evolution_reason_required_criteria[reason] ||= []) << key
        end
      end
    end
    # Return the base experience of the Pokemon
    # @return [Integer]
    def base_exp
      return data.base_experience
    end
    # Return the exp curve type ID
    # @return [Integer]
    def exp_type
      return data.experience_type
    end
    # Return the exp curve
    # @return [ExpList]
    def exp_list
      return ExpList.new(exp_type)
    end
    # Return the required total exp (so including old levels) to increase the Pokemon's level
    # @return [Integer]
    def exp_lvl
      data = exp_list
      v = data[@level + 1]
      return data[@level] if !v || PFM.game_state&.level_max_limit.to_i <= @level
      return v
    end
    # Return the text of the amount of exp the pokemon needs to go to the next level
    # @return [String]
    def exp_remaining_text
      expa = exp_lvl - exp
      expa = 0 if expa < 0
      return expa.to_s
    end
    # Return the text of the current pokemon experience
    # @return [String]
    def exp_text
      @exp.to_s
    end
    # Change the Pokemon total exp
    # @param v [Integer] the new exp value
    def exp=(v)
      @exp = v.to_i
      exp_lvl = self.exp_lvl
      if exp_lvl >= @exp
        exp_last = exp_list[@level]
        delta = exp_lvl - exp_last
        current = exp - exp_last
        @exp_rate = (delta == 0 ? 1 : current / delta.to_f)
      else
        @exp_rate = (@level < PFM.game_state.level_max_limit ? 1 : 0)
      end
    end
    # Increase the level of the Pokemon
    # @return [Boolean] if the level has successfully been increased
    def level_up
      return false if @level >= PFM.game_state.level_max_limit
      exp_last = exp_list[@level]
      delta = exp_lvl - exp_last
      self.exp += (delta - (exp - exp_last))
      update_loyalty if $game_temp.in_battle
      return true
    end
    # Update the Pokemon loyalty
    def update_loyalty
      value = 3
      value = 4 if loyalty < 200
      value = 5 if loyalty < 100
      value *= 2 if data_item(captured_with).db_symbol == :luxury_ball
      value *= 1.5 if item_db_symbol == :soothe_bell
      self.loyalty += value.floor
    end
    # Generate the level up stat list for the level up window
    # @return [Array<Array<Integer>>] list0, list1 : old, new basis value
    def level_up_stat_refresh
      st = $game_temp.in_battle
      $game_temp.in_battle = false
      list0 = [max_hp, atk_basis, dfe_basis, ats_basis, dfs_basis, spd_basis]
      @level += 1 if @level < PFM.game_state.level_max_limit
      self.exp = exp_list[@level] if @exp < exp_list[@level].to_i
      self.exp = exp
      hp_diff = list0[0] - @hp
      list1 = [max_hp, atk_basis, dfe_basis, ats_basis, dfs_basis, spd_basis]
      self.hp = (max_hp - hp_diff) if @hp > 0
      $game_temp.in_battle = st
      return [list0, list1]
    end
    # Show the level up window
    # @param list0 [Array<Integer>] old basis stat list
    # @param list1 [Array<Integer>] new basis stat list
    # @param z_level [Integer] z superiority of the Window
    def level_up_window_call(list0, list1, z_level)
      vp = $scene&.viewport
      window = UI::LevelUpWindow.new(vp, self, list0, list1)
      window.z = z_level
      Graphics.sort_z
      until Input.trigger?(:A)
        window.update
        Graphics.update
      end
      $game_system.se_play($data_system.decision_se)
      window.dispose
    end
    # Change the level of the Pokemon
    # @param lvl [Integer] the new level of the Pokemon
    def level=(lvl)
      return if lvl == @level
      lvl = lvl.clamp(1, PFM.game_state.level_max_limit)
      @exp = exp_list[lvl]
      @exp_rate = 0
      @level = lvl
    end
    # Check if the Pokemon can evolve and return the evolve id if possible
    # @param reason [Symbol] evolve check reason (:level_up, :trade, :stone)
    # @param extend_data [Hash, nil] extend_data generated by an item
    # @return [Array<Integer, nil>, false] if the Pokemon can evolve, the evolve id, otherwise false
    def evolve_check(reason = :level_up, extend_data = nil)
      return false if item_db_symbol == :everstone
      data = Configs.settings.always_use_form0_for_evolution ? primary_data : self.data
      if data.evolutions.empty?
        data = primary_data if Configs.settings.use_form0_when_no_evolution_data
        return false if data.evolutions.empty?
      end
      required_criterion = Pokemon.evolution_reason_required_criteria[reason] || []
      criteria = Pokemon.evolution_criteria
      expected_evolution = data.evolutions.find do |evolution|
        next(false) unless required_criterion.all? { |key| evolution.condition_data(key) }
        next(evolution.conditions.all? do |condition|
          next(false) unless (block = criteria[condition[:type]])
          next(instance_exec(condition[:value], extend_data, reason, &block))
        end)
      end
      return false unless expected_evolution
      return data_creature(expected_evolution.db_symbol).id, expected_evolution.form
    end
    add_evolution_criteria(:tradeWith, [:tradeWith]) { |value, extend_data, reason| extend_data&.db_symbol == value && reason == :tradeWith }
    add_evolution_criteria(:minLevel) { |value| @level >= value.to_i }
    add_evolution_criteria(:maxLevel) { |value| @level <= value.to_i }
    add_evolution_criteria(:itemHold) { |value| value == item_db_symbol }
    add_evolution_criteria(:minLoyalty) { |value| @loyalty >= value.to_i }
    add_evolution_criteria(:maxLoyalty) { |value| @loyalty <= value.to_i }
    add_evolution_criteria(:skill1) { |value| skill_learnt?(value) }
    add_evolution_criteria(:skill2) { |value| skill_learnt?(value) }
    add_evolution_criteria(:skill3) { |value| skill_learnt?(value) }
    add_evolution_criteria(:skill4) { |value| skill_learnt?(value) }
    add_evolution_criteria(:weather) { |value| $env.current_weather_db_symbol == value }
    add_evolution_criteria(:env) { |value| $game_player.system_tag == value }
    add_evolution_criteria(:gender) { |value| @gender == value }
    add_evolution_criteria(:stone, [:stone]) { |value, extend_data, reason| reason == :stone && value == extend_data }
    add_evolution_criteria(:dayNight) { |value| value == $game_variables[Yuki::Var::TJN_Tone] }
    add_evolution_criteria(:func) { |value| send(value) }
    add_evolution_criteria(:maps) { |value| value.include?($game_map.map_id) }
    add_evolution_criteria(:trade, [:trade]) { |_value, _extend_data, reason| reason == :trade }
    add_evolution_criteria(:id) {true }
    add_evolution_criteria(:form) {true }
    add_evolution_criteria(:switch) { |value| $game_switches[value] }
    add_evolution_criteria(:nature) { |value| nature_id == value }
    add_evolution_criteria(:gemme) {false }
    # Method that actually make a Pokemon evolve
    # @param id [Integer] ID of the Pokemon that evolve
    # @param form [Integer, nil] form of the Pokemon that evolve
    def evolve(id, form)
      old_evolution_db_symbol = db_symbol
      old_evolution_form = self.form
      hp_diff = self.max_hp - self.hp
      self.id = id
      if form
        self.form = form
      else
        form_calibrate(:evolve)
      end
      return unless $actors.include?(self)
      previous_pokemon_evolution_method = data_creature_form(old_evolution_db_symbol, old_evolution_form).evolutions
      evolution_items = previous_pokemon_evolution_method.map { |evolution| evolution.condition_data(:itemHold) }.compact
      self.item_holding = 0 if evolution_items.include?(item_db_symbol)
      check_skill_and_learn
      check_skill_and_learn(false, 0)
      $pokedex.mark_seen(self.id, self.form, forced: true)
      $pokedex.mark_captured(self.id)
      $pokedex.increase_creature_caught_count(self.id)
      self.hp = (self.max_hp - hp_diff) if self.hp > 0
      exec_hooks(PFM::Pokemon, :evolution, binding)
    end
    Hooks.register(PFM::Pokemon, :evolution, 'Shedinja Evolution') do
      next unless id == 291 && $actors.size < 6 && $bag.contain_item?(4)
      munja = dup
      munja.id = 292
      munja.hp = munja.max_hp
      munja.item_holding = 0
      $actors << munja
      $bag.remove_item(4, 1)
      $pokedex.mark_seen(292, forced: true)
      $pokedex.mark_captured(292)
    end
    # Change the id of the Pokemon
    # @param new_id [Integer] the new id of the Pokemon
    def id=(new_id)
      @character = nil
      if new_id && (req = data_creature(new_id)).id != 0 && (forms = req.forms)
        @id = new_id
        @db_symbol = forms.first.db_symbol
        @form = 0 if forms.none? { |creature_form| creature_form.form == @form }
        @form = form_generation(-1) if @form == 0
        @form = 0 if forms.none? { |creature_form| creature_form.form == @form }
        update_ability
      end
    end
    # Update the Pokemon Ability
    def update_ability
      return unless @ability_index
      @ability = get_data.abilities[@ability_index.to_i]
    end
    # Check evolve condition to evolve in Hitmonlee (kicklee)
    # @return [Boolean] if the condition is valid
    def elv_kicklee
      atk > dfe
    end
    # Check evolve condition to evolve in Hitmonchan (tygnon)
    # @return [Boolean] if the condition is valid
    def elv_tygnon
      atk < dfe
    end
    # Check evolve condition to evolve in Hitmontop (Kapoera)
    # @return [Boolean] if the condition is valid
    def elv_kapoera
      atk == dfe
    end
    # Check evolve condition to evolve in Silcoon (Armulys)
    # @return [Boolean] if the condition is valid
    def elv_armulys
      ((@code & 0xFFFF) % 10) <= 4
    end
    # Check evolve condition to evolve in Cascoon (Blindalys)
    # @return [Boolean] if the condition is valid
    def elv_blindalys
      !elv_armulys
    end
    # Check evolve condition to evolve in Mantine
    # @return [Boolean] if the condition is valid
    def elv_demanta
      PFM.game_state.has_pokemon?(223)
    end
    # Check evolve condition to evolve in Pangoro (Pandarbare)
    # @return [Boolean] if the condition is valid
    def elv_pandarbare
      return $actors.any? { |pokemon| pokemon&.type_dark? }
    end
    # Check evolve condition to evolve in Malamar (Sepiatroce)
    # @note uses :DOWN to validate the evolve condition
    # @return [Boolean] if the condition is valid
    def elv_sepiatroce
      return Input.press?(:DOWN)
    end
    # Check evolve condition to evolve in Sylveon (Nymphali)
    # @return [Boolean] if the condition is valid
    def elv_nymphali
      return @skills_set.any? { |skill| skill&.type?(data_type(:fairy).id) }
    end
    # Check evolve condition to evolve in Toxtricity-amped (Salarsen-aigüe)
    # [0, 2, 3, 4, 6, 8, 9, 11, 13, 14, 19, 22, 24]
    # return [Boolean] if the condition is valid
    def elv_toxtricity_amped
      natures_toxtricity = %i[hardy brave adamant naughty docile impish lax hasty jolly naive rash sassy quirky]
      return natures_toxtricity.include?(Configs.natures.db_symbol_to_id.key(nature_id))
    end
    # Check evolve condition when not in Toxtricity-amped (Salarsen-aigüe)
    def elv_toxtricity_low_key
      return !elv_toxtricity_amped
    end
    public
    # Helper class helping to get exp values based on each kind of equation
    class ExpList
      include Enumerable
      # List of method name per kind of exp
      KIND_TO_METHOD = %i[exp_fast exp_normal exp_slow exp_parabolic exp_eratic exp_fluctuating]
      # Create a new ExpList
      # @param kind [Integer] kind of exp
      def initialize(kind)
        @method = KIND_TO_METHOD[kind] || :exp_normal
      end
      # Get the total amount of exp to level up to the level parameter
      # @param level [Integer]
      # @return [Integer]
      def [](level)
        send(@method, level)
      end
      # Iterate over all the experience curve
      # @yieldparam total_exp [Integer] the total exp at the current level
      def each
        return to_enum(__method__) unless block_given?
        1.upto(size) { |i| yield(self[i]) }
      end
      # Get the size of the exp list table for this curve
      def size
        Configs.settings.max_level
      end
      private
      def exp_fast(level)
        return Integer(4 * (level ** 3) / 5)
      end
      def exp_normal(level)
        return Integer(level ** 3)
      end
      def exp_slow(level)
        return Integer(5 * (level ** 3) / 4)
      end
      def exp_parabolic(level)
        return 1 if level <= 1
        return Integer((6 * (level ** 3) / 5 - 15 * (level ** 2) + 100 * level - 140))
      end
      def exp_eratic(level)
        return Integer(level ** 3 * (100 - level) / 50) if level <= 50
        return Integer(level ** 3 * (150 - level) / 100) if level <= 68
        return Integer(level ** 3 * ((1911 - 10 * level) / 3) / 500) if level <= 98
        return Integer(level ** 3 * (160 - level) / 100) if level <= 100
        return Integer(600_000 + 103_364 * (level - 100) + Math.cos(level) * 30_000)
      end
      def exp_fluctuating(level)
        return Integer(level ** 3 * (24 + (level + 1) / 3) / 50) if level <= 15
        return Integer(level ** 3 * (14 + level) / 50) if level <= 35
        return Integer(level ** 3 * (32 + (level / 2)) / 50)
      end
    end
    public
    # List of form calibration hook for Creatures that needs form calibration (when switching items, being place in computer or when team changes)
    FORM_CALIBRATE = {}
    # List of form generation hook for Creatures that needs an initial form when the PFM::Pokemon object is generated.
    FORM_GENERATION = {}
    # List of items (in the form index order) that change the form of Arceus
    ArceusItem = %i[__undef__ flame_plate splash_plate zap_plate meadow_plate icicle_plate fist_plate toxic_plate earth_plate sky_plate mind_plate insect_plate stone_plate spooky_plate draco_plate iron_plate dread_plate pixie_plate]
    # List of items (in the form index order) that change the form of Genesect
    GenesectModules = %i[__undef__ burn_drive chill_drive douse_drive shock_drive]
    # List of item (in the form index oreder) that change the form of Silvally
    SilvallyROM = %i[__undef__ fighting_memory flying_memory poison_memory ground_memory rock_memory bug_memory ghost_memory steel_memory __undef__ fire_memory water_memory grass_memory electric_memory psychic_memory ice_memory dragon_memory dark_memory fairy_memory]
    # Change the form of the Pokemon
    # @note If the form doesn't exist, the form is not changed
    # @param value [Integer] the new form index
    def form=(value)
      value = value.to_i
      if data_creature(db_symbol).forms.any? { |creature_form| creature_form.form == value }
        @form = value
        form_calibrate
        update_ability
      end
    end
    # Check if the Pokemon can mega evolve
    # @return [Integer, false] form index if the Pokemon can mega evolve, false otherwise
    def can_mega_evolve?
      return false if mega_evolved?
      return 30 if db_symbol == :rayquaza && skills_set.any? { |skill| skill.db_symbol == :dragon_ascent }
      item = item_db_symbol
      mega_evolution = data.evolutions.find { |evolution| evolution.condition_data(:gemme) == item }
      return mega_evolution ? mega_evolution.form : false
    end
    # Mega evolve the Pokemon (if possible)
    def mega_evolve
      mega_evolution = can_mega_evolve?
      return unless mega_evolution
      @mega_evolved = @form
      @form = mega_evolution
      @ability = data_ability(data.abilities.sample).id
      self.ability = nil if self.is_a?(PFM::PokemonBattler)
    end
    # Reset the Pokemon to its normal form after mega evolution
    def unmega_evolve
      if @mega_evolved
        @form = @mega_evolved
        restore_ability
        @mega_evolved = false
      end
    end
    # Is the Pokemon mega evolved ?
    def mega_evolved?
      return @mega_evolved != false
    end
    # Absofusion of the Pokemon (if possible)
    # @param pokemon PFM::Pokemon The Pokemon used in the fusion
    def absofusion(pokemon)
      return if @fusion
      return unless form_calibrate(pokemon.db_symbol)
      @fusion = pokemon
      $actors.delete(pokemon)
    end
    # Separate (if possible) the Pokemon and restore the Pokemon used in the fusion
    def separate
      return unless @fusion || $actors.size != 6
      form_calibrate(:none)
      $actors << @fusion
      @fusion = nil
    end
    # If the Pokemon is a absofusion
    def absofusionned?
      return !@fusion.nil?
    end
    # Automatically generate the form index of the Pokemon
    # @note It calls the block stored in the hash FORM_GENERATION where the key is the Pokemon db_symbol
    # @param form [Integer] if form != 0 does not generate the form (protection)
    # @return [Integer] the form index
    def form_generation(form, old_value = nil)
      form = old_value if old_value
      return form if form != -1
      @character = nil
      block = FORM_GENERATION[db_symbol]
      return instance_exec(&block).to_i if block
      return 0
    end
    # Automatically calibrate the form of the Pokemon
    # @note It calls the block stored in the hash FORM_CALIBRATE where the key is the Pokemon db_symbol &
    #   the block parameter is the reason. The block should change @form
    # @param reason [Symbol] what called form_calibrate (:menu, :evolve, :load, ...)
    # @return [Boolean] if the Pokemon's form has changed
    def form_calibrate(reason = :menu)
      @character = nil
      last_form = @form
      block = FORM_CALIBRATE[db_symbol]
      instance_exec(reason, &block) if block
      @form = 0 if data_creature(db_symbol).forms.none? { |creature_form| creature_form.form == @form }
      update_ability
      return last_form != @form
    end
    # Calculate the form of deerling & sawsbuck
    # @return [Integer] the right form
    def current_deerling_form
      time = Time.new
      case time.month
      when 1, 2
        return @form = 3
      when 3
        return @form = (time.day < 21 ? 3 : 0)
      when 6
        return @form = (time.day < 21 ? 0 : 1)
      when 7, 8
        return @form = 1
      when 9
        return @form = (time.day < 21 ? 1 : 2)
      when 10, 11
        return @form = 2
      when 12
        return @form = (time.day < 21 ? 2 : 3)
      end
      return @form = 0
    end
    # Determine the form of Shaymin
    # @param reason [Symbol]
    def shaymin_form(reason)
      return 0 if frozen?
      return 1 if @form == 1 && ($env.morning? || $env.day?)
      return 1 if reason == :gracidea && ($env.morning? || $env.day?)
      return 0
    end
    # Determine the form of the Kyurem
    # @param [Symbol] reason The db_symbol of the Pokemon used for the fusion
    def kyurem_form(reason)
      return @form unless %i[reshiram zekrom none].include?(reason)
      return 1 if reason == :zekrom
      return 2 if reason == :reshiram
      return 0
    end
    # Determine the form of the Necrozma
    # @param [Symbol] reason The db_symbol of the Pokemon used for the fusion
    def necrozma_form(reason)
      return @form unless %i[solgaleo lunala none].include?(reason)
      return 1 if reason == :solgaleo
      return 2 if reason == :lunala
      return 0
    end
    # Determine the form of the Zygarde
    # @param reason [Symbol]
    # @return [Integer] form of zygarde
    def zygarde_form(reason)
      current_hp = @hp
      @base_form = @form unless @form == 3
      new_form = 3 if !dead? && hp_rate <= 0.5 && reason == :battle
      @form = new_form || @base_form || 1
      self.hp = current_hp
      return @form
    end
    # Determine the form of Cramorant
    # @param reason [Symbol]
    def cramorant_form(reason)
      return 0 if reason == :base
      return 1 if reason == :arrokuda
      return 2 if reason == :pikachu
      return 0
    end
    # Determine the form of the Calyrex
    # @param [Symbol] reason The db_symbol of the Pokemon used for the fusion
    def calyrex_form(reason)
      return @form unless %i[glastrier spectrier none].include?(reason)
      return 1 if reason == :glastrier
      return 2 if reason == :spectrier
      return 0
    end
    FORM_GENERATION[:unown] = proc {@form = @code % 28 }
    FORM_GENERATION[:castform] = proc do
      env = $env
      if env.sunny? || $env.hardsun?
        next(@form = 2)
      else
        if env.rain? || $env.hardrain?
          next(@form = 3)
        else
          if env.hail?
            next(@form = 6)
          end
        end
      end
      next(@form = 0)
    end
    FORM_GENERATION[:burmy] = FORM_GENERATION[:wormadam] = proc do
      env = $env
      if env.building?
        next(@form = 2)
      else
        if env.grass? || env.tall_grass? || env.very_tall_grass?
          next(@form = 0)
        end
      end
      next(@form = 1)
    end
    FORM_GENERATION[:cherrim] = proc {@form = $env.sunny? || $env.hardsun? ? 1 : 0 }
    FORM_GENERATION[:deerling] = FORM_GENERATION[:sawsbuck] = proc {@form = current_deerling_form }
    FORM_GENERATION[:meowstic] = proc {@form = @gender == 2 ? 1 : 0 }
    FORM_CALIBRATE[:giratina] = proc {@form = item_db_symbol == :griseous_orb ? 1 : 0 }
    FORM_CALIBRATE[:arceus] = proc {@form = ArceusItem.index(item_db_symbol).to_i }
    FORM_CALIBRATE[:shaymin] = proc { |reason| @form = shaymin_form(reason) }
    FORM_CALIBRATE[:genesect] = proc {@form = GenesectModules.index(item_db_symbol).to_i }
    FORM_CALIBRATE[:silvally] = proc {@form = SilvallyROM.index(item_db_symbol).to_i }
    FORM_CALIBRATE[:deerling] = FORM_CALIBRATE[:sawsbuck] = proc {@form = current_deerling_form }
    FORM_CALIBRATE[:darmanitan] = proc { |reason| @form = hp_rate <= 0.5 && reason == :battle ? @form | 1 : @form & ~1 }
    FORM_CALIBRATE[:tornadus] = proc { |reason| @form = reason == :therian ? 1 : 0 }
    FORM_CALIBRATE[:thundurus] = proc { |reason| @form = reason == :therian ? 1 : 0 }
    FORM_CALIBRATE[:landorus] = proc { |reason| @form = reason == :therian ? 1 : 0 }
    FORM_CALIBRATE[:kyurem] = proc { |reason| @form = kyurem_form(reason) }
    FORM_CALIBRATE[:keldeo] = proc {@form = find_skill(:secret_sword) ? 1 : 0 }
    FORM_CALIBRATE[:meloetta] = proc { |reason| @form = reason == :dance ? 1 : 0 }
    FORM_CALIBRATE[:aegislash] = proc { |reason| @form = reason == :blade ? 0 : 1 }
    FORM_CALIBRATE[:necrozma] = proc { |reason| @form = necrozma_form(reason) }
    FORM_CALIBRATE[:mimikyu] = proc { |reason| @form = reason == :battle ? 1 : 0 }
    FORM_CALIBRATE[:eiscue] = proc { |reason| @form = reason == :battle ? 1 : 0 }
    FORM_CALIBRATE[:zacian] = proc {@form = item_db_symbol == :rusted_sword ? 1 : 0 }
    FORM_CALIBRATE[:zamazenta] = proc {@form = item_db_symbol == :rusted_shield ? 1 : 0 }
    FORM_CALIBRATE[:calyrex] = proc { |reason| @form = calyrex_form(reason) }
    FORM_CALIBRATE[:groudon] = proc {@form = item_db_symbol == :red_orb ? 1 : 0 }
    FORM_CALIBRATE[:kyogre] = proc {@form = item_db_symbol == :blue_orb ? 1 : 0 }
    FORM_CALIBRATE[:wishiwashi] = proc { |reason| @form = hp_rate >= 0.25 && level >= 20 && reason == :battle ? 1 : 0 }
    FORM_CALIBRATE[:minior] = proc { |reason| @form = hp_rate <= 0.5 && reason == :battle ? @form | 1 : 0 }
    FORM_CALIBRATE[:zygarde] = proc { |reason| @form = zygarde_form(reason) }
    FORM_CALIBRATE[:morpeko] = proc { |reason| @form = reason == :battle ? 1 : 0 }
    FORM_CALIBRATE[:greninja] = proc { |reason| @form = reason == :battle ? 1 : 0 }
    FORM_CALIBRATE[:cramorant] = proc { |reason| @form = cramorant_form(reason) }
    public
    # Learn a new skill
    # @param db_symbol [Symbol] db_symbol of the move in the database
    # @return [Boolean, nil] true = learnt, false = already learnt, nil = couldn't learn
    def learn_skill(db_symbol)
      move = data_move(db_symbol)
      return false if skill_learnt?(move.db_symbol, only_in_move_set: true)
      if @skills_set.size < 4
        @skills_set << PFM::Skill.new(move.db_symbol)
        @skill_learnt << move.db_symbol unless @skill_learnt.include?(move.id) || @skill_learnt.include?(move.db_symbol)
        form_calibrate if data.db_symbol == :keldeo
        return true
      end
      return nil
    end
    # Forget a skill by its id
    # @param db_symbol [Symbol] db_symbol of the move in the database
    # @param delete_from_learnt [Boolean] if the skill should be deleted from the skill_learnt attribute of the Pokemon
    def forget_skill(db_symbol, delete_from_learnt: false)
      move = data_move(db_symbol)
      @skills_set.delete_if { |skill| skill.db_symbol == move.db_symbol }
      @skill_learnt.delete_if { |skill_id| data_move(skill_id).db_symbol == move.db_symbol } if delete_from_learnt
      form_calibrate if data.db_symbol == :keldeo
    end
    # Swap the position of two skills in the skills_set
    # @param index1 [Integer] Index of the first skill to swap
    # @param index2 [Integer] Index of the second skill to swap
    def swap_skills_index(index1, index2)
      @skills_set[index1], @skills_set[index2] = @skills_set[index2], @skills_set[index1]
      @skills_set.compact!
    end
    # Replace the skill at a specific index
    # @param index [Integer] index of the skill to replace by a new skill
    # @param db_symbol [Symbol] db_symbol of the move in the database
    def replace_skill_index(index, db_symbol)
      return if index >= 4
      move = data_move(db_symbol)
      @skills_set[index] = PFM::Skill.new(move.db_symbol)
      @skills_set.compact!
      @skill_learnt << move.db_symbol unless @skill_learnt.include?(move.id) || @skill_learnt.include?(move.db_symbol)
      form_calibrate if data.db_symbol == :keldeo
    end
    # Has the pokemon already learnt a skill ?
    # @param db_symbol [Symbol] db_symbol of the move
    # @param only_in_move_set [Boolean] if the function only check in the current move set
    # @return [Boolean]
    def skill_learnt?(db_symbol, only_in_move_set: true)
      return false if egg?
      move = data_move(db_symbol)
      return true if @skills_set.any? { |skill| skill && skill.db_symbol == move.db_symbol }
      return false if only_in_move_set
      return @skill_learnt.include?(move.id) || @skill_learnt.include?(move.db_symbol)
    end
    alias has_skill? skill_learnt?
    # Find a skill in the moveset of the Pokemon
    # @param db_symbol [Symbol] db_symbol of the skill in the database
    # @return [PFM::Skill, false]
    def find_skill(db_symbol)
      return false if egg?
      move = data_move(db_symbol)
      @skills_set.each do |skill|
        return skill if skill && skill.db_symbol == move.db_symbol
      end
      return false
    end
    # Check if the Pokemon can learn a new skill and make it learn the skill
    # @param silent [Boolean] if the skill is automatically learnt or not (false = show skill learn interface & messages)
    # @param level [Integer] The level to check in order to learn the moves (<= 0 = evolution)
    def check_skill_and_learn(silent = false, level = @level)
      learn_move = proc do |db_symbol|
        next if skill_learnt?(db_symbol)
        next(GamePlay.open_move_teaching(self, db_symbol)) unless silent
        @skills_set << PFM::Skill.new(db_symbol)
        @skills_set.shift if @skills_set.size > 4
        @skill_learnt << db_symbol unless @skill_learnt.include?(id) || @skill_learnt.include?(db_symbol)
      end
      if level <= 0
        data.move_set.select(&:evolution_learnable?).each do |move|
          learn_move.call(move.move)
        end
      else
        data.move_set.select { |move| move.level_learnable? && move.level == level }.each do |move|
          learn_move.call(move.move)
        end
      end
    end
    # Can learn skill at this level
    # @param level [Integer]
    def can_learn_skill_at_this_level?(level = @level)
      data.move_set.select { |move| move.level_learnable? && move.level == level }.any?
    end
    # Check if the Pokemon can learn a skill
    # @param db_symbol [Integer, Symbol] id or db_symbol of the move
    # @return [Boolean, nil] nil = learnt, false = cannot learn, true = can learn
    def can_learn?(db_symbol)
      return false if egg?
      db_symbol = data_move(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return nil if skill_learnt?(db_symbol)
      return data.move_set.any? { |move| move.move == db_symbol && !move.breed_learnable? }
    end
    # Get the list of all the skill the Pokemon can learn again
    # @param mode [Integer] Define the moves that can be learnt again :
    #   1 = breed_moves + learnt + potentially_learnt
    #   2 = all moves
    #   other = learnt + potentially_learnt
    # @return [Array<Symbol>]
    def remindable_skills(mode = 0)
      move_set = data.move_set
      level = mode == 2 ? Float::INFINITY : @level
      moves = move_set.select { |move| move.level_learnable? && level >= move.level }.map(&:move)
      moves.concat(@skill_learnt.map { |move| move.is_a?(Integer) ? data_move(move).db_symbol : move })
      moves.concat(move_set.select { |move| move.breed_learnable? || move.evolution_learnable? }.map(&:move)) if mode == 1 || mode == 2
      return (moves - skills_set.map(&:db_symbol)).uniq
    end
    # Load the skill from an Array
    # @param skills [Array] the skills array (containing IDs or Symbols)
    def load_skill_from_array(skills)
      skills.each_with_index do |skill, j|
        next(skills_set[j] = nil) if skill == :__remove__
        next if skill == 0 || skill == :__undef__ || skill.is_a?(String)
        replace_skill_index(j, skill)
      end
      skills_set.compact!
    end
    alias moveset skills_set
    public
    # Return the base HP
    # @return [Integer]
    def base_hp
      return data.base_hp
    end
    # Return the base ATK
    # @return [Integer]
    def base_atk
      return data.base_atk
    end
    # Return the base DFE
    # @return [Integer]
    def base_dfe
      return data.base_dfe
    end
    # Return the base SPD
    # @return [Integer]
    def base_spd
      return data.base_spd
    end
    # Return the base ATS
    # @return [Integer]
    def base_ats
      return data.base_ats
    end
    # Return the base DFS
    # @return [Integer]
    def base_dfs
      return data.base_dfs
    end
    # Return the max HP of the Pokemon
    # @return [Integer]
    def max_hp
      return 1 if db_symbol == :shedinja
      return ((@iv_hp + 2 * base_hp + @ev_hp / 4) * @level) / 100 + 10 + @level
    end
    # Return the current atk
    # @return [Integer]
    def atk
      return (atk_basis * atk_modifier).floor
    end
    # Return the current dfe
    # @return [Integer]
    def dfe
      return (dfe_basis * dfe_modifier).floor
    end
    # Return the current spd
    # @return [Integer]
    def spd
      return (spd_basis * spd_modifier).floor
    end
    # Return the current ats
    # @return [Integer]
    def ats
      return (ats_basis * ats_modifier).floor
    end
    # Return the current dfs
    # @return [Integer]
    def dfs
      return (dfs_basis * dfs_modifier).floor
    end
    # Return the atk stage
    # @return [Integer]
    def atk_stage
      return @battle_stage[0]
    end
    # Return the dfe stage
    # @return [Integer]
    def dfe_stage
      return @battle_stage[1]
    end
    # Return the spd stage
    # @return [Integer]
    def spd_stage
      return @battle_stage[2]
    end
    # Return the ats stage
    # @return [Integer]
    def ats_stage
      return @battle_stage[3]
    end
    # Return the dfs stage
    # @return [Integer]
    def dfs_stage
      return @battle_stage[4]
    end
    # Return the evasion stage
    # @return [Integer]
    def eva_stage
      return @battle_stage[5]
    end
    # Return the accuracy stage
    # @return [Integer]
    def acc_stage
      return @battle_stage[6]
    end
    # Change a stat stage
    # @param stat_id [Integer] id of the stat : 0 = atk, 1 = dfe, 2 = spd, 3 = ats, 4 = dfs, 5 = eva, 6 = acc
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_stat(stat_id, amount)
      last_value = @battle_stage[stat_id]
      @battle_stage[stat_id] += amount
      if @battle_stage[stat_id] > 6
        @battle_stage[stat_id] = 6
      else
        if @battle_stage[stat_id] < -6
          @battle_stage[stat_id] = -6
        end
      end
      return @battle_stage[stat_id] - last_value
    end
    # Change the atk stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_atk(amount)
      return change_stat(0, amount)
    end
    # Change the dfe stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_dfe(amount)
      return change_stat(1, amount)
    end
    # Change the spd stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_spd(amount)
      return change_stat(2, amount)
    end
    # Change the ats stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_ats(amount)
      return change_stat(3, amount)
    end
    # Change the dfs stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_dfs(amount)
      return change_stat(4, amount)
    end
    # Change the eva stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_eva(amount)
      return change_stat(5, amount)
    end
    # Change the acc stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_acc(amount)
      return change_stat(6, amount)
    end
    # Return the stage modifier (multiplier)
    # @param stage [Integer] the value of the stage
    # @return [Float] the multiplier
    def modifier_stage(stage)
      if stage >= 0
        return (2 + stage) / 2.0
      else
        return 2.0 / (2 - stage)
      end
    end
    # Return the atk modifier
    # @return [Float] the multiplier
    def atk_modifier
      return modifier_stage(atk_stage)
    end
    # Return the dfe modifier
    # @return [Float] the multiplier
    def dfe_modifier
      return modifier_stage(dfe_stage)
    end
    # Return the spd modifier
    # @return [Float] the multiplier
    def spd_modifier
      return modifier_stage(spd_stage)
    end
    # Return the ats modifier
    # @return [Float] the multiplier
    def ats_modifier
      return modifier_stage(ats_stage)
    end
    # Return the dfs modifier
    # @return [Float] the multiplier
    def dfs_modifier
      return modifier_stage(dfs_stage)
    end
    # Change the IV and update the statistics
    # @param list [Array<Integer>] list of new IV [hp, atk, dfe, spd, ats, dfs]
    def dv_modifier(list)
      @iv_hp = get_dv_value(list[0], @iv_hp)
      @iv_atk = get_dv_value(list[1], @iv_atk)
      @iv_dfe = get_dv_value(list[2], @iv_dfe)
      @iv_spd = get_dv_value(list[3], @iv_spd)
      @iv_ats = get_dv_value(list[4], @iv_ats)
      @iv_dfs = get_dv_value(list[5], @iv_dfs)
      @hp = max_hp
    end
    # Get the adjusted IV
    # @param value [Integer] the new value
    # @param old [Integer] the old value
    # @return [Integer] something between old and 31 (value in most case)
    def get_dv_value(value, old)
      if value < 0
        return old
      else
        if value > 31
          return 31
        end
      end
      return value
    end
    # Return the atk stat without battle modifier
    # @return [Integer]
    def atk_basis
      return calc_regular_stat(base_atk, @iv_atk, @ev_atk, 1)
    end
    # Return the dfe stat without battle modifier
    # @return [Integer]
    def dfe_basis
      return calc_regular_stat(base_dfe, @iv_dfe, @ev_dfe, 2)
    end
    # Return the spd stat without battle modifier
    # @return [Integer]
    def spd_basis
      return calc_regular_stat(base_spd, @iv_spd, @ev_spd, 3)
    end
    # Return the ats stat without battle modifier
    # @return [Integer]
    def ats_basis
      return calc_regular_stat(base_ats, @iv_ats, @ev_ats, 4)
    end
    # Return the dfs stat without battle modifier
    # @return [Integer]
    def dfs_basis
      return calc_regular_stat(base_dfs, @iv_dfs, @ev_dfs, 5)
    end
    # Change the HP value of the Pokemon
    # @note If v <= 0, the pokemon status become 0
    # @param v [Integer] the new HP value
    def hp=(v)
      if v <= 0
        @hp = 0
        @hp_rate = 0
        @status = 0
      else
        if v >= max_hp
          @hp = max_hp
          @hp_rate = 1
        else
          @hp = v
          @hp_rate = (v / max_hp.to_f)
        end
      end
    end
    # Return the EV HP text
    # @return [String]
    def ev_hp_text
      format(ev_text, ev_hp)
    end
    # Return the EV ATK text
    # @return [String]
    def ev_atk_text
      format(ev_text, ev_atk)
    end
    # Return the EV DFE text
    # @return [String]
    def ev_dfe_text
      format(ev_text, ev_dfe)
    end
    # Return the EV SPD text
    # @return [String]
    def ev_spd_text
      format(ev_text, ev_spd)
    end
    # Return the EV ATS text
    # @return [String]
    def ev_ats_text
      format(ev_text, ev_ats)
    end
    # Return the EV DFS text
    # @return [String]
    def ev_dfs_text
      format(ev_text, ev_dfs)
    end
    # Return the IV HP text
    # @return [String]
    def iv_hp_text
      format(iv_text, iv_hp)
    end
    # Return the IV ATK text
    # @return [String]
    def iv_atk_text
      format(iv_text, iv_atk)
    end
    # Return the IV DFE text
    # @return [String]
    def iv_dfe_text
      format(iv_text, iv_dfe)
    end
    # Return the IV SPD text
    # @return [String]
    def iv_spd_text
      format(iv_text, iv_spd)
    end
    # Return the IV ATS text
    # @return [String]
    def iv_ats_text
      format(iv_text, iv_ats)
    end
    # Return the IV DFS text
    # @return [String]
    def iv_dfs_text
      format(iv_text, iv_dfs)
    end
    private
    # Return the text "EV: %d"
    # @return [String]
    def ev_text
      'EV: %d'
    end
    # Return the text "IV: %d"
    # @return [String]
    def iv_text
      'IV: %d'
    end
    # Calculate the stat according to the stat formula
    # @param base [Integer] base of the stat
    # @param iv [Integer] IV of the stat
    # @param ev [Integer] EV of the stat
    # @param nature_index [Integer] Index of the nature modifier in the nature array
    def calc_regular_stat(base, iv, ev, nature_index)
      return (((2 * base + ev / 4 + iv) * @level / 100) + 5) * nature[nature_index] / 100
    end
    public
    # Is the Pokemon not able to fight
    # @return [Boolean]
    def dead?
      return hp <= 0 || egg?
    end
    # Is the Pokemon able to fight
    # @return [Boolean]
    def alive?
      return hp > 0 && !egg?
    end
    # Is the pokemon affected by a status
    # @return [Boolean]
    def status?
      return @status != 0
    end
    # Cure the Pokemon from its statues modifications
    def cure
      @status = 0
      @status_count = 0
    end
    # Is the Pokemon poisoned?
    # @return [Boolean]
    def poisoned?
      return @status == Configs.states.ids[:poison]
    end
    # Empoison the Pokemon
    # @param forcing [Boolean] force the new status
    # @return [Boolean] if the pokemon has been empoisoned
    def status_poison(forcing = false)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:poison]
        return true
      end
      return false
    end
    # Can the Pokemon be poisoned ?
    # @return [Boolean]
    def can_be_poisoned?
      return false if type_poison? || type_steel?
      return false if @status != 0
      return true
    end
    # Is the Pokemon paralyzed?
    # @return [Boolean]
    def paralyzed?
      return @status == Configs.states.ids[:paralysis]
    end
    # Paralyze the Pokemon
    # @param forcing [Boolean] force the new status
    # @return [Boolean] if the pokemon has been paralyzed
    def status_paralyze(forcing = false)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:paralysis]
        return true
      end
      return false
    end
    # Can the Pokemon be paralyzed?
    # @return [Boolean]
    def can_be_paralyzed?
      return false if @status != 0
      return false if type_electric?
      return true
    end
    # Is the Pokemon burnt?
    # @return [Boolean]
    def burn?
      return @status == Configs.states.ids[:burn]
    end
    alias burnt? burn?
    # Burn the Pokemon
    # @param forcing [Boolean] force the new status
    # @return [Boolean] if the pokemon has been burnt
    def status_burn(forcing = false)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:burn]
        return true
      end
      return false
    end
    # Can the Pokemon be burnt?
    # @return [Boolean]
    def can_be_burn?
      return @status == 0 && !type_fire?
    end
    # Is the Pokemon asleep?
    # @return [Boolean]
    def asleep?
      return @status == Configs.states.ids[:sleep]
    end
    # Put the Pokemon to sleep
    # @param forcing [Boolean] force the new status
    # @param nb_turn [Integer, nil] number of turn the Pokemon will sleep
    # @return [Boolean] if the pokemon has been put to sleep
    def status_sleep(forcing = false, nb_turn = nil)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:sleep]
        if nb_turn
          @status_count = nb_turn
        else
          @status_count = $scene.is_a?(Battle::Scene) ? $scene.logic.generic_rng.rand(2..5) : rand(2..5)
        end
        @status_count = (@status_count / 2).floor if $scene.is_a?(Battle::Scene) ? has_ability?(:early_bird) : ability_db_symbol == :early_bird
        return true
      end
      return false
    end
    # Can the Pokemon be asleep?
    # @return [Boolean]
    def can_be_asleep?
      return false if @status != 0
      return true
    end
    # Check if the Pokemon is still asleep
    # @return [Boolean] true = the Pokemon is still asleep
    def sleep_check
      @status_count -= 1
      return true if @status_count > 0
      @status = 0
      return false
    end
    # Is the Pokemon frozen?
    # @return [Boolean]
    def frozen?
      return @status == Configs.states.ids[:freeze]
    end
    # Freeze the Pokemon
    # @param forcing [Boolean] force the new status
    # @return [Boolean] if the pokemon has been frozen
    def status_frozen(forcing = false)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:freeze]
        return true
      end
      return false
    end
    # Can the Pokemon be frozen?
    # @return [Boolean]
    def can_be_frozen?(skill_type = 0)
      return false if @status != 0 || (skill_type == 6 && type_ice?)
      return true
    end
    # Is the Pokemon in toxic state ?
    # @return [Boolean]
    def toxic?
      return @status == Configs.states.ids[:toxic]
    end
    # Intoxicate the Pokemon
    # @param forcing [Boolean] force the new status
    # @return [Boolean] if the pokemon has been intoxicated
    def status_toxic(forcing = true)
      if (@status == 0 || forcing) && !dead?
        @status = Configs.states.ids[:toxic]
        @status_count = 0
        return true
      end
      return false
    end
    public
    # Return the current first type of the Pokemon
    # @return [Integer]
    def type1
      return data_type(data.type1).id
    end
    # Return the current second type of the Pokemon
    # @return [Integer]
    def type2
      return data_type(data.type2).id
    end
    # Return the current third type of the Pokemon
    # @return [Integer]
    def type3
      return 0
    end
    # Is the Pokemon type normal ?
    # @return [Boolean]
    def type_normal?
      return type?(data_type(:normal).id)
    end
    # Is the Pokemon type fire ?
    # @return [Boolean]
    def type_fire?
      return type?(data_type(:fire).id)
    end
    alias type_feu? type_fire?
    # Is the Pokemon type water ?
    # @return [Boolean]
    def type_water?
      return type?(data_type(:water).id)
    end
    alias type_eau? type_water?
    # Is the Pokemon type electric ?
    # @return [Boolean]
    def type_electric?
      return type?(data_type(:electric).id)
    end
    alias type_electrique? type_electric?
    # Is the Pokemon type grass ?
    # @return [Boolean]
    def type_grass?
      return type?(data_type(:grass).id)
    end
    alias type_plante? type_grass?
    # Is the Pokemon type ice ?
    # @return [Boolean]
    def type_ice?
      return type?(data_type(:ice).id)
    end
    alias type_glace? type_ice?
    # Is the Pokemon type fighting ?
    # @return [Boolean]
    def type_fighting?
      return type?(data_type(:fighting).id)
    end
    alias type_combat? type_fighting?
    # Is the Pokemon type poison ?
    # @return [Boolean]
    def type_poison?
      return type?(data_type(:poison).id)
    end
    # Is the Pokemon type ground ?
    # @return [Boolean]
    def type_ground?
      return type?(data_type(:ground).id)
    end
    alias type_sol? type_ground?
    # Is the Pokemon type fly ?
    # @return [Boolean]
    def type_flying?
      return type?(data_type(:flying).id)
    end
    alias type_vol? type_flying?
    alias type_fly? type_flying?
    # Is the Pokemon type psy ?
    # @return [Boolean]
    def type_psychic?
      return type?(data_type(:psychic).id)
    end
    alias type_psy? type_psychic?
    # Is the Pokemon type insect/bug ?
    # @return [Boolean]
    def type_bug?
      return type?(data_type(:bug).id)
    end
    alias type_insect? type_bug?
    # Is the Pokemon type rock ?
    # @return [Boolean]
    def type_rock?
      return type?(data_type(:rock).id)
    end
    alias type_roche? type_rock?
    # Is the Pokemon type ghost ?
    # @return [Boolean]
    def type_ghost?
      return type?(data_type(:ghost).id)
    end
    alias type_spectre? type_ghost?
    # Is the Pokemon type dragon ?
    # @return [Boolean]
    def type_dragon?
      return type?(data_type(:dragon).id)
    end
    # Is the Pokemon type steel ?
    # @return [Boolean]
    def type_steel?
      return type?(data_type(:steel).id)
    end
    alias type_acier? type_steel?
    # Is the Pokemon type dark ?
    # @return [Boolean]
    def type_dark?
      return type?(data_type(:dark).id)
    end
    alias type_tenebre? type_dark?
    # Is the Pokemon type fairy ?
    # @return [Boolean]
    def type_fairy?
      return type?(data_type(:fairy).id)
    end
    alias type_fee? type_fairy?
    # Check the Pokemon type by the type ID
    # @param type [Integer] ID of the type in the database
    # @return [Boolean]
    def type?(type)
      return (type1 == type || type2 == type || (type3 == type && type != 0))
    end
    # Is the Pokemon typeless ?
    # @return [Boolean]
    def typeless?
      return type1 == 0 && type2 == 0 && type3 == 0
    end
    # Is the user single typed ?
    # @return [Boolean]
    def single_type?
      return type1 != 0 && type2 == 0 && type3 == 0
    end
    # Has the user a third type ?
    # @return [Boolean]
    def third_type?
      type3 != 0
    end
    public
    # PSP 0.7 ID Hash key
    G_ID = 'ID'
    # PSP 0.7 level Hash key
    G_NV = 'NV'
    # PSP 0.7 item hash key
    G_OBJ = 'OBJ'
    # PSP 0.7 stat hash key
    G_STAT = 'STAT'
    # PSP 0.7 move hash key
    G_MOVE = 'MOVE'
    # PSP 0.7 gender hash key
    G_GR = 'GR'
    # PSP 0.7 form hash key
    G_FORM = 'FORM'
    # PSP 0.7 shiny hash key
    G_SHINY = 'SHINY'
    class << self
      # Generate a Pokemon from a hash
      # @param hash [Hash] Hash describing optional value you want to assign to the Pokemon
      # @option hash [Integer, Symbol] :id ID of the Pokemon
      # @option hash [Integer] :level level of the Pokemon
      # @option hash [Boolean] :shiny if the pokemon will be shiny
      # @option hash [Boolean] :no_shiny if the pokemon will never be shiny
      # @option hash [Integer] :form form index of the Pokemon
      # @option hash [String] :given_name Nickname of the Pokemon
      # @option hash [Integer, Symbol] :captured_with ID of the ball used to catch the Pokemon
      # @option hash [Integer] :captured_in ID of the zone where the Pokemon was caught
      # @option hash [Integer, Time] :captured_at Time when the Pokemon was caught
      # @option hash [Integer] :captured_level Level of the Pokemon when it was caught
      # @option hash [Integer] :egg_in ID of the zone where the egg was layed/found
      # @option hash [Integer, Time] :egg_at Time when the egg was layed/found
      # @option hash [Integer, String] :gender Forced gender of the Pokemon
      # @option hash [Integer] :nature Nature of the Pokemon
      # @option hash [Array<Integer>] :stats IV array ([hp, atk, dfe, spd, ats, dfs])
      # @option hash [Array<Integer>] :bonus EV array ([hp, atk, dfe, spd, ats, dfs])
      # @option hash [Integer, Symbol] :item ID of the item the Pokemon is holding
      # @option hash [Integer, Symbol] :ability ID of the ability the Pokemon has
      # @option hash [Integer] :rareness Rareness of the Pokemon (0 = not catchable, 255 = always catchable)
      # @option hash [Integer] :loyalty Happiness of the Pokemon
      # @option hash [Array<Integer, Symbol>] :moves Current Moves of the Pokemon (0 = default)
      # @option hash [Array(Integer, Integer)] :memo_text Text used for the memo ([file_id, text_id])
      # @option hash [String] :trainer_name Name of the trainer that caught / got the Pokemon
      # @option hash [Integer] :trainer_id ID of the trainer that caught / got the Pokemon
      # @return [PFM::Pokemon]
      def generate_from_hash(hash)
        pkmn_id = hash[:id]
        return psp_generate_from_hash(hash) unless pkmn_id
        level = hash[:level].to_i
        shiny = hash[:shiny]
        ns = hash[:no_shiny]
        form = hash[:form] || -1
        hash[:captured_with] ||= hash[:ball]
        return PFM::Pokemon.new(pkmn_id, level, shiny, ns, form, hash)
      end
      private
      def psp_generate_from_hash(hash)
        form = hash[G_FORM]
        pokemon = PFM::Pokemon.new(hash[G_ID], hash[G_NV], hash[G_SHINY], false, form || -1)
        sexe = hash[G_GR]
        pokemon.set_gender(sexe) if sexe
        moves = hash[G_MOVE]
        pokemon.load_skill_from_array(moves) if moves
        stat = hash[G_STAT]
        pokemon.dv_modifier(stat) if stat && stat.size == 6
        obj = hash[G_OBJ]
        pokemon.item_holding = obj
        return pokemon
      end
    end
    public
    # Return the Pokemon name in the Pokedex
    # @return [String]
    def name
      return Studio::Text.get(0, @step_remaining == 0 ? @id : 0)
    end
    # Return the Pokemon name upcase in the Pokedex
    # @return [String]
    def name_upper
      return Studio::Text.get(0, @step_remaining == 0 ? @id : 0).upcase
    end
    # Return the given name of the Pokemon (Pokedex name if no given name)
    # @return [String]
    def given_name
      return @given_name || name
    end
    alias nickname given_name
    # Give a new name to the Pokemon
    # @param nickname [String] the new name of the Pokemon
    def given_name=(nickname)
      @given_name = nickname
      @given_name = nil if nickname == name
    end
    alias nickname= given_name=
    # Convert the Pokemon to a string (battle debug)
    # @return [String]
    def to_s
      return "<P:#{self.given_name}_#{@code.to_s(36)}_#{@position}>"
    end
    # Return the text of the nature
    # @return [String]
    def nature_text
      return text_get(8, nature.first)
    end
    # Return the name of the zone where the Pokemon has been caught
    # @return [String]
    def captured_zone_name
      zone_name = _utf8(data_zone(zone_id).name)
      return PFM::Text.parse_string_for_messages(zone_name)
    end
    # Return the name of the zone where the egg has been obtained
    # @return [String]
    def egg_zone_name
      zone_name = _utf8(data_zone(zone_id(@egg_in)).name)
      return PFM::Text.parse_string_for_messages(zone_name)
    end
    # Return the name of the item the Pokemon is holding
    # @return [String]
    def item_name
      return data_item(item_db_symbol).name
    end
    # Return the name of the current ability of the Pokemon
    # @return [String]
    def ability_name
      return data_ability(ability_db_symbol).name
    end
    # Reture the description of the current ability of the Pokemon
    # @return [String]
    def ability_descr
      return data_ability(ability_db_symbol).descr
    end
    # Return the normalized text trainer id of the Pokemon
    # @return [String]
    def trainer_id_text
      return sprintf('%05d', self.trainer_id)
    end
    # Returns the level text
    # @return [String]
    def level_text
      @level.to_s
    end
    # Return the level text (to_pokemon_number)
    # @return [String]
    def level_pokemon_number
      @level.to_s.to_pokemon_number
    end
    # Return the level text with "Level: " inside
    # @return [String]
    def level_text2
      "#{text_get(27, 29)}#@level"
    end
    # Returns the HP text
    # @return [String]
    def hp_text
      "#@hp / #{self.max_hp}"
    end
    # Returns the HP text (to_pokemon_number)
    # @return [String]
    def hp_pokemon_number
      "#@hp / #{self.max_hp}".to_pokemon_number
    end
    # Return the text of the Pokemon ID
    # @return [String]
    def id_text
      format('%03d', dex_id)
    end
    # Return the text of the Pokemon ID with N°
    # @return [String]
    def id_text2
      format('N°%03d', dex_id)
    end
    # Return the text of the Pokemon ID to pokemon number
    # @return [String]
    def id_text3
      format('%03d', dex_id).to_pokemon_number
    end
    private
    # Get the dex id of the Pokemon
    # @return [Integer]
    def dex_id
      dex_data = data_dex($pokedex.national? ? :national : $pokedex.variant)
      index = dex_data.creatures.find_index { |creature| creature.db_symbol == db_symbol }
      return index ? index + dex_data.start_id : 0
    end
    public
    # Tell if the Creature likes flavor
    # @param flavor [Symbol]
    def flavor_liked?(flavor)
      return false if no_preferences?
      return Configs.flavors.nature_liking_flavor[flavor].include?(nature_id)
    end
    # Tell if the Creature dislikes flavor
    # @param flavor [Symbol]
    def flavor_disliked?(flavor)
      return false if no_preferences?
      return Configs.flavors.nature_disliking_flavor[flavor].include?(nature_id)
    end
    # Check if the Creature has a nature with no preferences
    def no_preferences?
      return Configs.flavors.nature_with_no_preferences.include?(nature_id)
    end
  end
  # The InGame skill/move information of a Pokemon
  # @author Nuri Yuri
  class Skill
    # The maximum number of PP the skill has
    # @return [Integer]
    attr_accessor :ppmax
    # The current number of PP the skill has
    # @return [Integer]
    attr_reader :pp
    # ID of the skill in the Database
    # @return [Integer]
    attr_reader :id
    # Create a new Skill information
    # @param db_symbol [Symbol] db_symbol of the skill/move in the database
    def initialize(db_symbol)
      data = data_move(db_symbol)
      @id = data.id
      @db_symbol = data.db_symbol
      if @id == 0
        @ppmax = 0
        @pp = 0
        return
      end
      @ppmax = data.pp
      @pp = @ppmax
    end
    # Return the actual data of the move
    # @return [Studio::Move]
    def data
      return data_move(@db_symbol || @id || :__undef__)
    end
    # Return the db_symbol of the skill
    # @return [Symbol]
    def db_symbol
      return @db_symbol ||= data.db_symbol
    end
    # Return the name of the skill
    # @return [String]
    def name
      return data.name
    end
    # Return the symbol of the method to call in BattleEngine
    # @return [Symbol]
    def symbol
      return data.be_method
    end
    # Return the text of the power of the skill
    # @return [String]
    def power_text
      power = base_power
      return text_get(11, 12) if power == 0
      return power.to_s
    end
    # Return the text of the PP of the skill
    # @return [String]
    def pp_text
      "#{@pp} / #{@ppmax}"
    end
    # Return the base power (Data power) of the skill
    # @return [Integer]
    def base_power
      return data.power
    end
    alias power base_power
    # Return the actual type ID of the skill
    # @return [Integer]
    def type
      return data_type(data.type).id
    end
    # Return the actual accuracy of the skill
    # @return [Integer]
    def accuracy
      return data.accuracy
    end
    # Return the accuracy text of the skill
    # @return [String]
    def accuracy_text
      acc = data.accuracy
      return text_get(11, 12) if acc == 0
      return acc.to_s
    end
    # Return the skill description
    # @return [String]
    def description
      return text_get(7, @id || 0)
    end
    # Return the ID of the common event to call on Map use
    # @return [Integer]
    def map_use
      return data.map_use
    end
    # Is the skill a specific type ?
    # @param type_id [Integer] ID of the type
    def type?(type_id)
      return type == type_id
    end
    # Change the PP
    # @param v [Integer] the new pp value
    def pp=(v)
      @pp = v.clamp(0, @ppmax)
    end
    # Get the ATK class for the UI
    # @return [Integer]
    def atk_class
      return 2 if data.category == :special
      return 3 if data.category == :status
      return 1
    end
  end
end
