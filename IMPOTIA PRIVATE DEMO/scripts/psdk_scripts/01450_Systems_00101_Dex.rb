module PFM
  # The Pokedex informations
  #
  # The main Pokedex object is stored in $pokedex or PFM.game_state.pokedex
  #
  # All Creature are usually marked as seen or captured in the correct scripts using $pokedex.mark_seen(id)
  # or $pokedex.mark_captured(id).
  #
  # When the Pokedex is disabled, no Creature can be marked as seen (unless they're added to the party).
  # All caught Creature are marked as captured so if for scenaristic reason you need the trainer to catch Creature
  # before having the Pokedex. Don't forget to call $pokedex.unmark_captured(id) (as well $pokedex.unmark_seen(id))
  # @author Nuri Yuri
  class Pokedex
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Get the current dex variant
    # @return [Symbol]
    attr_reader :variant
    # Get the list of seen variants
    # @return [Array<Symbol>]
    attr_reader :seen_variants
    # Create a new Pokedex object
    # @param game_state [PFM::GameState] game state storing this instance
    def initialize(game_state = PFM.game_state)
      @seen = 0
      @captured = 0
      @has_seen_and_forms = Hash.new(0)
      @has_captured = []
      @nb_fought = Hash.new(0)
      @nb_captured = Hash.new(0)
      @game_state = game_state
      @variant = :regional
      @seen_variants = [@variant]
    end
    # Convert the dex to .26 format
    def convert_to_dot26
      @variant ||= :regional
      @seen_variants ||= [@variant]
      if @has_seen_and_forms.is_a?(Hash)
        @has_seen_and_forms.delete_if { |_, v| v.nil? } if @has_seen_and_forms.value?(nil)
        @nb_fought.delete_if { |_, v| v.nil? } if @nb_fought.value?(nil)
        @nb_captured.delete_if { |_, v| v.nil? } if @nb_captured.value?(nil)
        return
      end
      all_db_symbols = [@has_seen_and_forms.size, @has_captured.size, @nb_fought.size, @nb_captured.size].max.times.map { |i| data_creature(i).db_symbol }
      has_seen_and_forms = @has_seen_and_forms.map.with_index { |v, i| !v || v == 0 ? nil : [all_db_symbols[i], v] }.compact.to_h
      has_captured = @has_captured.map.with_index { |v, i| v ? all_db_symbols[i] : nil }.compact
      nb_fought = @nb_fought.map.with_index { |v, i| !v || v == 0 ? nil : [all_db_symbols[i], v] }.compact.to_h
      nb_captured = @nb_captured.map.with_index { |v, i| !v || v == 0 ? nil : [all_db_symbols[i], v] }.compact.to_h
      @has_seen_and_forms = Hash.new(0)
      @has_seen_and_forms.merge!(has_seen_and_forms)
      @has_captured = has_captured
      @nb_fought = Hash.new(0)
      @nb_fought.merge!(nb_fought)
      @nb_captured = Hash.new(0)
      @nb_captured.merge!(nb_captured)
    end
    # Enable the Pokedex
    def enable
      @game_state.game_switches[Yuki::Sw::Pokedex] = true
    end
    # Test if the Pokedex is enabled
    # @return [Boolean]
    def enabled?
      @game_state.game_switches[Yuki::Sw::Pokedex]
    end
    # Disable the Pokedex
    def disable
      @game_state.game_switches[Yuki::Sw::Pokedex] = false
    end
    # Set the national flag of the Pokedex
    # @param mode [Boolean] the flag
    def national=(mode)
      @game_state.game_switches[Yuki::Sw::Pokedex_Nat] = (mode == true)
      if mode
        self.variant = :national
      else
        @seen_variants.delete(:national)
        self.variant = @seen_variants.first || :regional
      end
    end
    alias set_national national=
    # Set the variant the Dex is currently showing
    # @param variant [Symbol]
    def variant=(variant)
      return unless each_data_dex.any? { |dex| dex.db_symbol == variant }
      @variant = variant
      @seen_variants << variant unless @seen_variants.include?(variant)
    end
    # Is the Pokedex showing national Creature
    # @return [Boolean]
    def national?
      return @game_state.game_switches[Yuki::Sw::Pokedex_Nat]
    end
    # Return the number of Creature seen
    # @return [Integer]
    def creature_seen
      return @seen
    end
    alias pokemon_seen creature_seen
    # Return the number of caught Creature
    # @return [Integer]
    def creature_caught
      return @captured
    end
    alias pokemon_captured creature_caught
    # Return the number of Creature captured by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @return [Integer]
    def creature_caught_count(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return @nb_captured[db_symbol]
    end
    # Change the number of Creature captured by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @param number [Integer] the new number
    def set_creature_caught_count(db_symbol, number)
      return unless enabled?
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @nb_captured[db_symbol] = number.to_i
    end
    # Increase the number of Creature captured by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    def increase_creature_caught_count(db_symbol)
      return unless enabled?
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @nb_captured[db_symbol] += 1
    end
    alias pokemon_captured_inc increase_creature_caught_count
    # Return the number of Creature fought by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @return [Integer]
    def creature_fought(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return @nb_fought[db_symbol]
    end
    # Change the number of Creature fought by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @param number [Integer] the number of Creature fought in the specified specie
    def set_creature_fought(db_symbol, number)
      return unless enabled?
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @nb_fought[db_symbol] = number.to_i
    end
    # Increase the number of Creature fought by specie
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    def increase_creature_fought(db_symbol)
      return unless enabled?
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @nb_fought[db_symbol] += 1
    end
    alias pokemon_fought_inc increase_creature_fought
    # Mark a creature as seen
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @param form [Integer] the specific form of the Creature
    # @param forced [Boolean] if the Creature is marked seen even if the Pokedex is disabled
    #                         (Giving Creature before givin the Pokedex).
    def mark_seen(db_symbol, form = 0, forced: false)
      return unless enabled? || forced
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      return unless creature_unlocked?(db_symbol) || forced
      @seen += 1 if @has_seen_and_forms[db_symbol] == 0
      @has_seen_and_forms[db_symbol] |= (1 << form)
      @game_state.game_variables[Yuki::Var::Pokedex_Seen] = @seen
    end
    # Unmark a creature as seen
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @param form [Integer, false] if false, all form will be unseen, otherwise the specific form will be unseen
    def unmark_seen(db_symbol, form: false)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      if form
        @has_seen_and_forms[db_symbol] &= ~(1 << form)
      else
        @has_seen_and_forms.delete(db_symbol)
      end
      @seen -= 1 if !form || @has_seen_and_forms[db_symbol] == 0
      @game_state.game_variables[Yuki::Var::Pokedex_Seen] = @seen
    end
    # Mark a Creature as captured
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    def mark_captured(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      return unless creature_unlocked?(db_symbol)
      unless @has_captured.include?(db_symbol)
        @has_captured << db_symbol
        @captured += 1
      end
      @game_state.game_variables[Yuki::Var::Pokedex_Catch] = @captured
    end
    # Unmark a Creature as captured
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    def unmark_captured(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      if @has_captured.include?(db_symbol)
        @has_captured.delete(db_symbol)
        @captured -= 1
      end
      @game_state.game_variables[Yuki::Var::Pokedex_Catch] = @captured
    end
    # Has the player seen a Creature
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @return [Boolean]
    def creature_seen?(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return false if db_symbol == :__undef__
      return @has_seen_and_forms[db_symbol] != 0
    end
    alias pokemon_seen? creature_seen?
    alias has_seen? creature_seen?
    # Has the player caught this Creature
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @return [Boolean]
    def creature_caught?(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return false if db_symbol == :__undef__
      return @has_captured.include?(db_symbol)
    end
    alias pokemon_caught? creature_caught?
    alias has_captured? creature_caught?
    # Get the seen forms informations of a Creature
    # @param db_symbol [Symbol] db_symbol of the Creature in the database
    # @return [Integer] An interger where int[form] == 1 mean the form has been seen
    def form_seen(db_symbol)
      db_symbol = data_creature(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return 0 if db_symbol == :__undef__
      return @has_seen_and_forms[db_symbol]
    end
    alias get_forms form_seen
    # Tell if the creature is unlocked in the current dex state
    # @param db_symbol [Symbol]
    # @return [Boolean]
    def creature_unlocked?(db_symbol)
      return true if national?
      return data_dex(@variant).creatures.any? { |creature| creature.db_symbol == db_symbol }
    end
    # Calibrate the Pokedex information (seen/captured)
    def calibrate
      @has_seen_and_forms.delete_if { |_, v| v == 0 }
      @seen = @has_seen_and_forms.size
      @captured = @has_captured.size
      @game_state.game_variables[Yuki::Var::Pokedex_Catch] = @captured
      @game_state.game_variables[Yuki::Var::Pokedex_Seen] = @seen
    end
    # Detect the best worldmap to display for the creature
    # @param db_symbol [Symbol] db_symbol of the creature we want the worldmap to display
    # @return [Integer]
    def best_worldmap_for_creature(db_symbol)
      default = @game_state.env.get_worldmap
      return default if each_data_world_map.size == 0
      zone_db_symbols = spawn_zones(db_symbol)
      return default if zone_db_symbols.empty?
      world_maps = zone_db_symbols.map { |zone_db_symbol| data_zone(zone_db_symbol).worldmaps }.flatten.compact
      return default if world_maps.empty?
      best_id = world_maps.group_by { |id| id }.map { |k, v| [k, v.size] }.max_by(&:last).first
      return best_id || default
    end
    alias best_worldmap_pokemon best_worldmap_for_creature
    # Return the list of the zone id where the creature spawns
    # @param db_symbol [Symbol] db_symbol of the creature we want to know where it spawns
    # @return [Array<Symbol>]
    def spawn_zones(db_symbol)
      zones = each_data_zone.select do |zone|
        groups = zone.wild_groups.map { |group_db_symbol| data_group(group_db_symbol) }
        next(groups.any? { |group| group.encounters.any? { |encounter| encounter.specie == db_symbol } })
      end
      return zones.map(&:db_symbol)
    end
  end
  class GameState
    # The Pokedex of the player
    # @return [PFM::Pokedex]
    attr_accessor :pokedex
    on_player_initialize(:pokedex) {@pokedex = PFM.dex_class.new(self) }
    on_expand_global_variables(:pokedex) do
      $pokedex = @pokedex
      @pokedex.game_state = self
      @pokedex.convert_to_dot26 if trainer.current_version < 6656
    end
  end
end
PFM.dex_class = PFM::Pokedex
module UI
  # Dex sprite that show the Pokemon sprite with its name
  class DexWinSprite < SpriteStack
    # Create a new dex win sprite
    def initialize(viewport)
      super(viewport, 3, 11, default_cache: :pokedex)
      create_sprites
    end
    # Update the graphics
    def update_graphics
      @sprite.update
    end
    private
    def create_sprites
      add_background('WinSprite')
      @sprite = add_sprite(60, 124, NO_INITIAL_IMAGE, type: PokemonFaceSprite)
      pokemon_name = add_text(3, 6, 116, 19, :name_upper, 1, type: SymText, color: 10)
      pokemon_name.bold = true
    end
  end
  # Dex sprite that show the Pokemon location
  class DexSeenGot < SpriteStack
    # Create a new dex win sprite
    def initialize(viewport)
      super(viewport, 0, 152, default_cache: :pokedex)
      create_sprites
      self.data = $pokedex
    end
    private
    def create_sprites
      add_background('WinNum')
      seen_text = add_text(2, 0, 79, 26, ext_text(9000, 20), color: 10)
      seen_text.bold = true
      add_text(seen_text.real_width + 4, 0, 79, 26, :creature_seen, 0, type: SymText, color: 10)
      got_text = add_text(2, 28, 79, 26, ext_text(9000, 21), color: 10)
      got_text.bold = true
      add_text(got_text.real_width + 4, 28, 79, 26, :creature_caught, 0, type: SymText, color: 10)
    end
  end
  # Dex sprite that show the Pokemon infos
  class DexWinInfo < SpriteStack
    # Change the data
    # Array of visible sprites if the Pokemon was captured
    VISIBLE_SPRITES = 1..7
    # Create a new dex win sprite
    def initialize(viewport)
      super(viewport, 131, 37, default_cache: :pokedex)
      create_sprites
    end
    # Define the Pokemon shown by the UI
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      super(pokemon)
      update_capture_visibility(pokemon)
    end
    private
    # Show / hide the sprites according to the captured state of the Pokemon
    def update_capture_visibility(creature)
      is_captured = creature && $pokedex.creature_caught?(creature.id)
      VISIBLE_SPRITES.each do |i|
        @stack[i].visible = is_captured
      end
    end
    def create_sprites
      add_background('WinInfos')
      add_sprite(8, 4, 'Catch')
      add_text(29, 4, 116, 16, :pokedex_name, type: SymText, color: 10)
      add_text(9, 27, 116, 16, :pokedex_species, type: SymText)
      add_text(9, 67, 116, 16, :pokedex_weight, type: SymText)
      add_text(9, 87, 116, 16, :pokedex_height, type: SymText)
      add_sprite(25, 47, NO_INITIAL_IMAGE, true, type: Type1Sprite)
      add_sprite(112, 47, NO_INITIAL_IMAGE, true, type: Type2Sprite)
    end
  end
  # Dex sprite that show the Pokemon infos
  class DexButton < SpriteStack
    # Create a new dex button
    # @param viewport [Viewport]
    # @param index [Integer] index of the sprite in the viewport
    def initialize(viewport, index)
      super(viewport, 147, 62, default_cache: :pokedex)
      create_sprites
      fix_position(index)
    end
    # Change the data
    # @param pokemon [PFM::Pokemon] the Pokemon shown by the button
    def data=(pokemon)
      super(pokemon)
      update_catch_icon_visibility
    end
    # Tell the button if it's selected or not : change the obfuscator visibility & x position
    # @param value [Boolean] the selected state
    def selected=(value)
      @obfuscator.visible = !value
      set_position(value ? 147 : 163, y)
    end
    private
    def create_sprites
      add_background('But_List')
      @catch_icon = add_sprite(119, 9, 'Catch')
      add_sprite(17, 15, NO_INITIAL_IMAGE, type: PokemonIconSprite)
      add_text(35, 1, 116, 16, :id_text3, type: SymText, color: 10)
      add_text(35, 16, 116, 16, :name, type: SymText, color: 10)
      @obfuscator = add_foreground('But_ListShadow')
    end
    # Adjust the position according to the index
    # @param index [Integer] index of the sprite in the viewport
    def fix_position(index)
      set_position(index == 0 ? 147 : 163, y - 40 + index * 40)
    end
    # Change the catch visibility to the captured state of the Pokemon
    def update_catch_icon_visibility
      @catch_icon.visible = $pokedex.creature_caught?(data&.id || 0)
    end
  end
  # Dex sprite that show the Pokemon location
  class DexWinMap < SpriteStack
    # Filename of the World Map Icon
    MAP_ICON = data_item(:town_map).icon
    # Create a new dex win sprite
    def initialize(viewport, display_controls = true)
      super(viewport, 0, 0, default_cache: :pokedex)
      create_sprites(display_controls)
    end
    # Change the data and the state
    # @param pokemon [PFM::Pokemon, :map] if set to map, we'll be showing the map icon
    def data=(pokemon)
      if pokemon == :map
        @pkm_icon.visible = false
        @item_icon.visible = true
        @item_icon.set_bitmap(MAP_ICON, :icon)
      else
        if pokemon.is_a? PFM::Pokemon
          @pkm_icon.visible = true
          @item_icon.visible = false
          super(pokemon)
        end
      end
    end
    # Set the location name
    # @param place [String] the name to display
    # @param color [Integer] the color code
    def set_location(place, color = 10)
      @location.multiline_text = place
      @location.load_color color
    end
    # Set the region name
    # @param place [String] the name to display
    # @param color [Integer] the color code
    def set_region(place, color = 10)
      @region.multiline_text = place.upcase
      @location.load_color color
    end
    private
    def create_sprites(display_controls)
      @pkm_icon = add_sprite(28, 123, NO_INITIAL_IMAGE, type: PokemonIconSprite)
      @item_icon = add_sprite(13, 106, NO_INITIAL_IMAGE)
      @location = add_text(10, 18, 132, 16, ext_text(9000, 19), 1, color: 10)
      @region = add_text(150, 0, 150, 24, 'REGION', 2, color: 10)
      @region.bold = true
      create_controls if display_controls
    end
    def create_controls
      add_sprite(40, 221, NO_INITIAL_IMAGE, :Y, type: KeyShortcut)
      add_text(60, 221, 140, 16, ext_text(9000, 32), color: 10)
      add_sprite(190, 221, NO_INITIAL_IMAGE, :X, type: KeyShortcut)
      add_text(210, 221, 140, 16, ext_text(9000, 33), color: 10)
    end
  end
end
module GamePlay
  # Class that shows the Pokedex
  class Dex < BaseCleanUpdate::FrameBalanced
    # Text format for the name
    NAME_FORMAT = '%03d - %s'
    # Array of actions to do according to the pressed button
    ACTIONS = %i[action_A action_X action_Y action_B]
    include UI
    # Create a new Pokedex interface
    # @param page_id [PFM::Pokemon, Integer, false] id of the page to show
    def initialize(page_id = false)
      super()
      @pokemonlist = PFM::Pokemon.new(data_dex($pokedex.variant).creatures.first&.db_symbol || 1, 1)
      @arrow_direction = 1
      @state = page_id ? 1 : 0
      @page_id = page_id.is_a?(PFM::Pokemon) ? page_id.id : page_id
      @pkmn = page_id.is_a?(PFM::Pokemon) ? page_id.dup : nil
      generate_selected_pokemon_array(page_id)
      generate_pokemon_object
      Mouse.wheel = 0
    end
    # Update the UI inputs
    def update_inputs
      return action_A if Input.trigger?(:A)
      return action_X if Input.trigger?(:X)
      return action_Y if Input.trigger?(:Y)
      return action_B if Input.trigger?(:B)
      return false if @page_id
      if @state == 0
        max_index = @selected_pokemons.size - 1
        if index_changed(:@index, :UP, :DOWN, max_index)
          update_index
        else
          if index_changed!(:@index, :LEFT, :RIGHT, max_index)
            9.times {index_changed!(:@index, :LEFT, :RIGHT, max_index) }
            update_index
          else
            if Mouse.wheel != 0
              @index = (@index - Mouse.wheel) % (max_index + 1)
              Mouse.wheel = 0
              update_index
            end
          end
        end
      else
        if @state == 1
          max_index = @selected_pokemons.size - 1
          update_index_descr if index_changed(:@index, :UP, :DOWN, max_index)
        else
          if @state == 2
            @pokemon_worldmap.update
          end
        end
      end
    end
    # Update the mouse interaction with the ctrl buttons
    # @param _moved [Boolean] if the mouse moved during the frame
    def update_mouse(_moved = false)
      update_mouse_ctrl_buttons(@ctrl, ACTIONS)
    end
    private
    # Update the index when changed
    def update_index
      @pokemon.id = @selected_pokemons[@index]
      @pokeface.data = @pokemon
      update_list(true)
    end
    def update_index_descr
      @pokemon.id = @selected_pokemons[@index]
      @pokeface.data = @pokemon
      change_state(1)
    end
    # Action triggered when A is pressed
    def action_A
      return $game_system.se_play($data_system.buzzer_se) if @page_id
      $game_system.se_play($data_system.decision_se)
      change_state(@state + 1) if @state < 2
    end
    # Action triggered when B is pressed
    def action_B
      $game_system.se_play($data_system.decision_se)
      return @running = false if @state == 0 || @page_id
      change_state(@state - 1) if @state > 0
    end
    # Action triggered when X is pressed
    def action_X
      return $game_system.se_play($data_system.buzzer_se) if @page_id
      @pokemon_worldmap.on_toggle_zoom if @state == 2
      return if @state > 1
      return $game_system.se_play($data_system.buzzer_se)
    end
    # Action triggered when Y is pressed
    def action_Y
      @pokemon_worldmap.on_next_worldmap if @state == 2
      return if @state > 1
      return $game_system.se_play($data_system.buzzer_se) if @state == 0
      $game_system.cry_play(@pokemon.id) if @state == 1
    end
    # Change the state of the Interface
    # @param state [Integer] the id of the state
    def change_state(state)
      @state = state
      @base_ui.mode = state
      @frame.set_bitmap(state == 1 ? 'frameinfos' : 'frame', :pokedex)
      @pokeface.data = @pokemon if (@pokeface.visible = state != 2)
      if @arrow
        @arrow.visible = @seen_got.visible = state == 0
        @pokemon_worldmap.set_pokemon(@pokemon) if (@pokemon_worldmap.visible = state == 2)
        update_list(state == 0)
      end
      @pokemon_info.visible = @pokemon_descr.visible = state == 1
      if @pokemon_descr.visible
        if $pokedex.creature_caught?(@pokemon.id)
          @pokemon_descr.multiline_text = data_creature(@pokemon.db_symbol).descr
        else
          @pokemon_descr.multiline_text = ''
        end
        @pokemon_info.data = @pokemon
      end
    end
    # Update the button list
    # @param visible [Boolean]
    def update_list(visible)
      @scrollbar.visible = @scrollbut.visible = visible
      @scrollbut.y = 41 + 150 * @index / (@selected_pokemons.size - 1) if @selected_pokemons.size > 1
      base_index = calc_base_index
      @list.each_with_index do |el, i|
        next unless (el.visible = visible)
        pos = base_index + i
        id = @selected_pokemons[pos]
        next((el.visible = false)) unless id && pos >= 0
        @arrow.y = el.y + 11 if (el.selected = (pos == @index))
        @pokemonlist.id = id
        el.data = @pokemonlist
      end
    end
    # Calculate the base index of the list
    # @return [Integer]
    def calc_base_index
      return -1 if @selected_pokemons.size < 5
      if @index >= 2
        return @index - 2
      else
        if @index < 2
          return -1
        end
      end
    end
    # Generate the selected_pokemon array
    # @param page_id [Integer, false] see initialize
    def generate_selected_pokemon_array(page_id)
      dex = $pokedex
      dex_data = data_dex(dex.variant)
      creatures = dex_data.creatures
      @selected_pokemons = creatures.select { |creature| dex.creature_seen?(creature.db_symbol) }
      @selected_pokemons.map! { |creature| data_creature(creature.db_symbol).id }
      @selected_pokemons << 0 if @selected_pokemons.empty?
      if page_id
        @index = @selected_pokemons.index(page_id)
        unless @index
          @selected_pokemons << page_id
          @index = @selected_pokemons.size - 1
        end
      else
        @index = 0
      end
    end
    # Generate the Pokemon Object
    def generate_pokemon_object
      @pokemon = @pkmn ||= PFM::Pokemon.generate_from_hash(id: @selected_pokemons[@index].to_i, level: 1, no_shiny: true)
      [@pokemonlist, @pokemon].each do |creature|
        creature.instance_eval do
          # Return the formated name for Pokedex
          # @return [String]
          def pokedex_name
            format(GamePlay::Dex::NAME_FORMAT, dex_id, name)
          end
          # Get the dex id
          # @return [Integer]
          def dex_id
            dex_data = data_dex($pokedex.variant)
            id = dex_data.creatures.find_index { |creature| creature.db_symbol == db_symbol }
            return id ? id + dex_data.start_id : 0
          end
          # Return the formated Specie for Pokedex
          # @return [String]
          def pokedex_species
            data_creature(db_symbol).species
          end
          # Return the formated weight for Pokedex
          # @return [String]
          def pokedex_weight
            text = ext_text(9000, 70)
            using_retard_unit = !text.downcase.end_with?('kg')
            format(text, using_retard_unit ? (weight * 2.20462).ceil(2) : weight)
          end
          # Return the formated height for Pokedex
          # @return [String]
          def pokedex_height
            text = ext_text(9000, 71)
            using_retard_unit = !text.downcase.end_with?('m')
            if using_retard_unit
              inches = (height * 39.3701).to_i
              feet = inches / 12
              inches -= feet * 12
              format(text, feet, inches)
            else
              return format(text, height)
            end
          end
        end
      end
    end
    public
    # Create all the graphics
    def create_graphics
      create_viewport
      create_base_ui
      unless @page_id
        create_list
        create_arrow
        create_scroll_bar
        create_progression
        create_worldmap
      end
      create_face
      create_frame
      create_info
      change_state(@state)
    end
    # Update all the graphics
    def update_graphics
      @base_ui.update_background_animation
      update_arrow
      @pokeface.update_graphics
    end
    private
    # Update the arrow animation
    def update_arrow
      return unless @arrow&.visible
      return if Graphics.frame_count % 15 != 0
      @arrow.x += @arrow_direction
      @arrow_direction = 1 if @arrow.x <= 127
      @arrow_direction = -1 if @arrow.x >= 129
    end
    # Create the viewport and a Stack making the graphic creation easier
    def create_viewport
      @viewport = Viewport.create(:main, 50_000)
      @stack = SpriteStack.new(@viewport, default_cache: :pokedex)
    end
    # Create the base ui
    def create_base_ui
      btn_texts = button_texts
      @base_ui = UI::GenericBaseMultiMode.new(@viewport, btn_texts, [UI::GenericBase::DEFAULT_KEYS] * btn_texts.size)
      @ctrl = @base_ui.ctrl
    end
    # Create the Pokemon list
    def create_list
      @list = Array.new(6) { |i| DexButton.new(@viewport, i) }
    end
    # Create arrow (telling which Pokemon we're choosing)
    def create_arrow
      @arrow = @stack.add_sprite(127, 0, 'arrow')
    end
    # Create the scrollbar
    def create_scroll_bar
      @scrollbar = @stack.add_sprite(309, 36, 'scroll')
      @scrollbut = @stack.add_sprite(308, 41, 'but_scroll')
    end
    # Create the frame sprite
    def create_frame
      @frame = Sprite.new(@viewport)
    end
    # Create the face sprite ui
    def create_face
      @pokeface = DexWinSprite.new(@viewport)
    end
    # Create the progression ui
    def create_progression
      @seen_got = DexSeenGot.new(@viewport)
    end
    # Create the info ui
    def create_info
      @pokemon_info = DexWinInfo.new(@viewport)
      @pokemon_descr = @stack.add_text(11, 153, 298, 16, nil.to_s, color: 10)
    end
    # Create the worldmap ui
    def create_worldmap
      @pokemon_worldmap = GamePlay.town_map_class.new(:pokedex, $env.get_worldmap)
      @pokemon_worldmap.create_graphics
    end
    # Get the button text for the generic UI
    # @return [Array<Array<String>>]
    def button_texts
      return [[nil, nil, nil, ext_text(9000, 9)]] * 3 if @page_id
      return [[ext_text(9000, 6), ext_text(9000, 7), ext_text(9000, 8), ext_text(9000, 9)], [ext_text(9000, 10), ext_text(9000, 11), ext_text(9000, 12), ext_text(9000, 13)], [ext_text(9000, 6), ext_text(9000, 7), ext_text(9000, 8), ext_text(9000, 9)]]
    end
  end
end
GamePlay.dex_class = GamePlay::Dex
