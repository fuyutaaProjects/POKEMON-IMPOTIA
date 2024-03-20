module PFM
  # The game informations and Party management
  #
  # The global object is stored in PFM.game_state
  # @author Nuri Yuri
  class GameState
    # Constant containing all the proc to call when creating a new GameState object (for battle)
    ON_INITIALIZE = {}
    # Constant containing all the proc to call when creating a new GameState object (for the player)
    ON_PLAYER_INITIALIZE = {}
    # Constant containing all the proc to call when expanding the global variables
    ON_EXPAND_GLOBAL_VARIABLES = {}
    class << self
      # Add a new proc on initialize (for battle)
      # @param name [Symbol] name of the block to add
      # @param block [Proc] proc to execute with the GameState context
      def on_initialize(name, &block)
        ON_INITIALIZE[name] = block
      end
      # Add a new proc on player initialize (for the player)
      # @param name [Symbol] name of the block to add
      # @param block [Proc] proc to execute with the GameState context
      def on_player_initialize(name, &block)
        ON_PLAYER_INITIALIZE[name] = block
      end
      # Add a new proc on global variable expand
      # @param name [Symbol] name of the block to add
      # @param block [Proc] proc to execute with the GameState context
      def on_expand_global_variables(name, &block)
        ON_EXPAND_GLOBAL_VARIABLES[name] = block
      end
    end
    # The Pokemon of the Player
    # @return [Array<PFM::Pokemon>]
    attr_accessor :actors
    on_initialize(:actors) do
      @actors = []
    end
    on_expand_global_variables(:actors) do
      $actors = @actors
    end
    # The number of steps the repel will work
    # @return [Integer]
    attr_reader :repel_count
    on_initialize(:repel_count) {@repel_count = 0 }
    # The number of steps the player did
    # @return [Integer]
    attr_accessor :steps
    on_initialize(:steps) {@steps = 0 }
    # The $game_variables
    # @return [Game_Variables]
    attr_accessor :game_variables
    on_player_initialize(:game_variables) do
      @game_variables = Game_Variables.new
      $game_variables ||= @game_variables
    end
    on_expand_global_variables(:game_variables) do
      $game_variables = @game_variables
    end
    # The $game_switches
    # @return [Game_Switches]
    attr_accessor :game_switches
    on_player_initialize(:game_switches) do
      @game_switches = Game_Switches.new
      $game_switches ||= @game_switches
    end
    on_expand_global_variables(:game_switches) do
      $game_switches = @game_switches
    end
    # The $game_self_switches
    # @return [Game_SelfSwitches]
    attr_accessor :game_self_switches
    on_player_initialize(:game_self_switches) {@game_self_switches = Game_SelfSwitches.new }
    on_expand_global_variables(:game_self_switches) do
      $game_self_switches = @game_self_switches
    end
    # The $game_self_variables
    # @return [Game_SelfVariables]
    attr_accessor :game_self_variables
    on_player_initialize(:game_self_variables) {@game_self_variables = Game_SelfVariables.new }
    on_expand_global_variables(:game_self_variables) do
      $game_self_variables = @game_self_variables
    end
    # The $game_system
    # @return [Game_System]
    attr_accessor :game_system
    on_player_initialize(:game_system) {@game_system = Game_System.new }
    on_expand_global_variables(:game_system) do
      $game_system = @game_system
    end
    # The $game_screen
    # @return [Game_Screen]
    attr_accessor :game_screen
    on_player_initialize(:game_screen) {@game_screen = Game_Screen.new }
    on_expand_global_variables(:game_screen) do
      $game_screen = @game_screen
    end
    # The $game_actors
    # @return [Game_Actors]
    attr_accessor :game_actors
    on_player_initialize(:game_actors) {@game_actors = Game_Actors.new }
    on_expand_global_variables(:game_actors) do
      $game_actors = @game_actors
    end
    # The $game_party
    # @return [Game_Party]
    attr_accessor :game_party
    on_player_initialize(:game_party) {@game_party = Game_Party.new }
    on_expand_global_variables(:game_party) do
      $game_party = @game_party
    end
    on_player_initialize(:game_troop) {@game_troop = Game_Troop.new }
    on_expand_global_variables(:game_troop) {$game_troop = @game_troop }
    # The $game_map
    # @return [Game_Map]
    attr_accessor :game_map
    on_player_initialize(:game_map) {@game_map = Game_Map.new }
    on_expand_global_variables(:game_map) do
      $game_map = @game_map
    end
    # The $game_player
    # @return [Game_Player]
    attr_accessor :game_player
    on_player_initialize(:game_player) {@game_player = Game_Player.new }
    on_expand_global_variables(:game_player) do
      $game_player = @game_player
    end
    # The $game_temp
    # @return [Game_Temp]
    attr_accessor :game_temp
    on_player_initialize(:game_temp) {@game_temp = Game_Temp.new }
    on_expand_global_variables(:game_temp) do
      $game_temp = @game_temp
    end
    # The nuzlocke logic
    # @return [Nuzlocke]
    attr_accessor :nuzlocke
    on_player_initialize(:nuzlocke) {@nuzlocke = PFM.nuzlocke_class.new(self) }
    on_expand_global_variables(:nuzlocke) do
      @nuzlocke ||= PFM.nuzlocke_class.new(self)
      @nuzlocke.graveyard ||= []
      @nuzlocke.game_state = self
    end
    # The pathfinding requests
    # @return [Array<Object>]
    attr_accessor :pathfinding_requests
    on_player_initialize(:pathfinding_requests) {@pathfinding_requests = Pathfinding::DEFAULT_SAVE }
    on_expand_global_variables(:pathfinding_requests) {@pathfinding_requests ||= Pathfinding::DEFAULT_SAVE }
    # Name of the time set to use (nil = default)
    # @return [Symbol, nil]
    attr_accessor :tint_time_set
    # User data
    # @return [Hash]
    attr_reader :user_data
    on_player_initialize(:user_data) {@user_data = {} }
    on_expand_global_variables(:user_data) do
      @user_data ||= {}
      $user_data = @user_data
    end
    # Maximum level an allied Pokemon can reach
    # @return [Integer]
    attr_accessor :level_max_limit
    on_player_initialize(:level_max_limit) {@level_max_limit = Configs.settings.max_level }
    on_expand_global_variables(:level_max_limit) {@level_max_limit ||= Configs.settings.max_level }
    # The in game berry data
    # @return [Hash]
    attr_accessor :berries
    on_player_initialize(:berries) {@berries = {} }
    # Create a new Pokemon Party
    # @param battle [Boolean] if its a party of a NPC battler
    # @param starting_language [String] the lang id of the game described by this object
    def initialize(battle = false, starting_language = 'en')
      @starting_language = starting_language
      ON_INITIALIZE.each_value do |block|
        instance_exec(&block) if block
      end
      return if battle
      game_state_initialize
      rmxp_boot unless $tester
    end
    private
    # Initialize the game state variable
    def game_state_initialize
      ON_PLAYER_INITIALIZE.each_value do |block|
        instance_exec(&block) if block
      end
      expand_global_var
      load_parameters
    end
    # Perform the RMXP bootup
    def rmxp_boot
      expand_global_var
      @game_party.setup_starting_members
      log_info("$data_system.start_map_id = #{$data_system.start_map_id}")
      log_info("$data_system.start_x = #{$data_system.start_x}")
      log_info("$data_system.start_x = #{$data_system.start_y}")
      @game_map.setup($data_system.start_map_id)
      @game_player.moveto($data_system.start_x + Yuki::MapLinker.get_OffsetX, $data_system.start_y + Yuki::MapLinker.get_OffsetY)
      @game_player.refresh
      @game_map.autoplay
    end
    public
    # Expand the global variable with the instance variables of the object
    def expand_global_var
      PFM.game_state = self
      $pokemon_party = self
      ON_EXPAND_GLOBAL_VARIABLES.each_value do |block|
        instance_exec(&block) if block
      end
    end
    # Update the processing of the repel
    def repel_update
      return if cant_process_event_tasks?
      if @repel_count > 0
        @repel_count -= 1
        $scene.delay_display_call(:display_repel_check) if @repel_count == 0
      end
    end
    # Update section to detect if a wild battle must start
    # @note this methods calls common event 1 if a battle must start
    def battle_starting_update
      return if cant_process_event_tasks?
      encounter_count = $game_player.encounter_count
      if !$game_system.encounter_disabled && ((@steps % encounter_count) == 0) && @wild_battle.available?
        $game_system.map_interpreter.launch_common_event(1) unless $game_system.map_interpreter.running?
      end
    end
    # Update the processing of the poison event
    def poison_update
      return unless (@steps - (@steps / 8) * 8) == 0
      return if cant_process_event_tasks?
      psn_event = false
      @actors.each do |pokemon|
        next unless pokemon.poisoned? || pokemon.toxic?
        next if pokemon.ability_db_symbol == :immunity
        $scene.delay_display_call(:display_poison_animation) unless psn_event
        psn_event = true
        pokemon.hp -= (pokemon.toxic? ? 2 : 1)
        if pokemon.hp <= 0 && $game_switches[::Yuki::Sw::OW_Poison]
          $scene.delay_display_call(:display_poison_faint, pokemon)
        end
        next unless pokemon.hp <= 1 && !$game_switches[::Yuki::Sw::OW_Poison]
        pokemon.hp = 1
        pokemon.cure
        $scene.delay_display_call(:display_poison_end, pokemon)
      end
      nuzlocke.clear_dead_pokemon if nuzlocke.enabled?
    end
    # Abilities that increase the hatch speed
    FASTER_HATCH_ABILITIES = %i[magma_armor flame_body steam_engine]
    # Update the remaining steps of all the Egg to hatch
    def hatch_check_update
      return if cant_process_event_tasks?
      amca = FASTER_HATCH_ABILITIES.include?(@actors[0]&.ability_db_symbol || :__undef__)
      @actors.each do |pokemon|
        next unless pokemon.step_remaining > 0
        pokemon.step_remaining -= 1
        pokemon.step_remaining -= 1 if amca && (pokemon.step_remaining > 0)
        if pokemon.step_remaining == 0
          pokemon.egg_finish
          $scene.delay_display_call(:display_egg_hatch, pokemon)
        end
      end
    end
    # Update the loyalty process of the pokemon
    def loyalty_update
      return unless (@steps - (@steps / 128) * 128) == 0 && rand(2) == 0
      return if cant_process_event_tasks?
      @actors.each do |pokemon|
        value = pokemon.loyalty < 200 ? 2 : 1
        value *= 2 if data_item(pokemon.captured_with).db_symbol == :luxury_ball
        value *= 1.5 if pokemon.item_db_symbol == :soothe_bell
        pokemon.loyalty += value.floor
      end
    end
    # Tell if EventTasks can't process
    # @return [Boolean]
    def cant_process_event_tasks?
      return ($game_player.move_route_forcing || $game_system.map_interpreter.running? || $game_temp.message_window_showing || $game_player.sliding)
    end
    # Increase the @step and manage events that trigger each steps
    # @return [Array] informations about events that has been triggered.
    def increase_steps
      @steps += 1
      $game_party.steps = @steps
    end
    # Change the repel_count
    # @param v [Integer]
    def repel_count=(v)
      @repel_count = v.to_i.abs
    end
    alias set_repel_count repel_count=
    alias get_repel_count repel_count
    # Return the money the player has
    # @return [Integer]
    def money
      return $game_party.gold
    end
    # Change the money the player has
    # @param v [Integer]
    def money=(v)
      $game_party.gold = v.to_i
    end
    # Add money
    # @param n [Integer] amount of money to add
    def add_money(n)
      return lose_money(-n) if n < 0
      $game_party.gold += n
    end
    # Lose money
    # @param n [Integer] amount of money to lose
    def lose_money(n)
      return add_money(-n) if n < 0
      $game_party.gold -= n
      $game_party.gold = 0 if $game_party.gold < 0
    end
    # Load some parameters (audio volume & text)
    def load_parameters
      Audio.music_volume = @options.music_volume
      Audio.sfx_volume = @options.sfx_volume
      Studio::Text.load
    end
    public
    # Return the size of the party
    # @return [Integer]
    def size
      return @actors.size
    end
    # Is the party empty ?
    # @return [Boolean]
    def empty?
      return @actors.empty?
    end
    # Is the party full ?
    # @return [Boolean]
    def full?
      return @actors.size == 6
    end
    # Is the party not able to start a battle ?
    # @return [Boolean]
    def dead?
      return empty? || @actors.all?(&:dead?)
    end
    # Is the party able to start a battle ?
    # @return [Boolean]
    def alive?
      return !dead?
    end
    # Number of pokemon alive in the party
    # @param max [Integer] the number of Pokemon to check from the begining of the party
    def pokemon_alive(max = @actors.size)
      alive = 0
      max.times do |i|
        alive += 1 if @actors[i] && !@actors[i].dead?
      end
      return alive
    end
    # Index of the first pokemon alive in the party
    def first_pokemon_alive_index
      return @actors.index { |pokemon| !pokemon.dead? }
    end
    # Test if a specific Pokémon is able to fight or not
    # @param id [Integer] ID of the Pokemon
    # @return [Boolean]
    # @example Checking if Pikachu is alive in the party
    #   PFM.game_state.specific_alive?(25)
    # @example Checking if alolan Meowth is alive in the party
    #   PFM.game_state.specific_alive?(52) { |pokemon| pokemon.form == 1 }
    def specific_alive?(id)
      if block_given?
        return @actors.any? { |pokemon| !pokemon.dead? && (pokemon.id == id || !id) && yield(pokemon) }
      else
        return @actors.any? { |pokemon| !pokemon.dead? && pokemon.id == id }
      end
    end
    # Add a Pokemon to the pary (also update the Pokedex Informations)
    # @param pkmn [PFM::Pokemon]
    # @return [Boolean, Integer] Box index if stored in a box, false if failed, true if stored in the Party
    def add_pokemon(pkmn)
      unless pkmn.egg?
        @pokedex.mark_seen(pkmn.id, pkmn.form, forced: true)
        @pokedex.mark_captured(pkmn.id)
        @pokedex.increase_creature_fought(pkmn.id)
        @pokedex.increase_creature_caught_count(pkmn.id)
      end
      if full?
        return @storage.current_box if @storage.store(pkmn)
        return false
      else
        @actors << pkmn
        return true
      end
    end
    # Remove a pokemon from the party
    # @param var [Integer, Symbol] the var value (index or id)
    # @param by_id [Boolean] if the pokemon are removed by their id
    # @param all [Boolean] if every pokemon that has the id are removed
    def remove_pokemon(var, by_id = false, all = false)
      var = data_creature(var).id if var.is_a?(Symbol)
      if by_id
        @actors.each_with_index do |pokemon, index|
          if pokemon.id == var
            @actors[index] = nil
            break unless all
          end
        end
      else
        @actors[var] = nil
      end
      @actors.compact!
    end
    # Switch pokemon in the party
    # @param first [Integer] index of the first pokemon to switch
    # @param second [Integer] index of the second pokemon to switch
    def switch_pokemon(first, second)
      @actors[first], @actors[second] = @actors[second], @actors[first]
      @actors.compact!
    end
    # Check if the player has a specific Pokemon in its party
    # @param id [Integer, Symbol] id of the Pokemon in the database
    # @param level [Integer, nil] the level required
    # @param form [Integer, nil] the form of the Pokemon
    # @param shiny [Boolean, nil] if the Pokemon should be shiny or not
    # @param index [Boolean] if you want an index when found
    # @return [Boolean, Integer] if the Pokemon has been found
    def contain_matching_pokemon?(id, level = nil, form = nil, shiny = nil, index: false)
      id = data_creature(id).id if id.is_a?(Symbol)
      @actors.each_with_index do |pokemon, i|
        next unless pokemon.id == id
        bool = true
        bool &&= pokemon.level == level if level
        bool &&= pokemon.form == form if form
        bool &&= pokemon.shiny == shiny unless shiny.nil?
        next unless bool
        return i if index
        return true
      end
      return false
    end
    alias has_pokemon? contain_matching_pokemon?
    # Check if the player has enough Pokemon to choose in its party
    # Doesn't count banned Pokemon
    # @param arr [Array] ids of the banned Pokemon
    def contain_enough_selectable_pokemon?(arr = [])
      if arr.any?
        count = @actors.count { |pokemon| !arr.include?(pokemon.id) }
      else
        count = $actors.size
      end
      return false unless $game_variables[Yuki::Var::Max_Pokemon_Select].between(1, size)
      return $game_variables[Yuki::Var::Max_Pokemon_Select] <= count
    end
    alias has_enough_selectable_pokemon? contain_enough_selectable_pokemon?
    # Find a specific Pokemon index in the party
    # @param id [Integer, Symbol] id of the Pokemon in the database
    # @param level [Integer, nil] the level required
    # @param form [Integer, nil] the form of the Pokemon
    # @param shiny [Boolean, nil] if the Pokemon should be shiny or not
    # @return [Integer, false] index of the Pokemon in the party
    def pokemon_index(id, level = nil, form = nil, shiny = nil)
      has_pokemon?(id, level, form, shiny, index: true)
    end
    # Heal the pokemon in the Party
    def heal_party
      @actors.each do |pokemon|
        next unless pokemon
        pokemon.cure
        pokemon.hp = pokemon.max_hp
        pokemon.skills_set.each do |skill|
          skill&.pp = skill.ppmax
        end
      end
    end
    # Return the maximum level of the Pokemon in the Party
    # @return [Integer]
    def max_level
      @actors.max_by(&:level)&.level || 0
    end
    # Check if the party has a Pokemon with a specific skill
    # @param id [Integer, Symbol] ID of the skill in the database
    # @param index [Boolean] if the method return the index of the Pokemon that has the skill
    # @return [Boolean, Integer]
    def contain_pokemon_with_the_skill?(id, index = false)
      id = data_move(id).id if id.is_a?(Symbol)
      @actors.each_with_index do |pokemon, i|
        next unless pokemon
        pokemon.skills_set.each do |skill|
          if skill&.id == id
            return index ? i : true
          end
        end
      end
      return false
    end
    alias has_skill? contain_pokemon_with_the_skill?
    # Get the index of the Pokemon that has the specified skill
    # @param id [Integer, Symbol] ID of the skill in the database
    # @return [Integer, false]
    def pokemon_skill_index(id)
      has_skill?(id, true)
    end
    # Check if the party has a Pokemon with a specific ability
    # @param id [Integer, Symbol] ID of the ability in the database
    # @param index [Boolean] if the method return the index of the Pokemon that has the ability
    # @return [Boolean, Integer]
    def contain_pokemon_with_the_ability?(id, index = false)
      id = data_ability(id).id if id.is_a?(Symbol)
      @actors.each_with_index do |pokemon, i|
        if pokemon&.ability == id
          return index ? i : true
        end
      end
      return false
    end
    alias has_ability? contain_pokemon_with_the_ability?
    # Get the index of the Pokemon that has the specified ability
    # @param id [Integer, Symbol] ID of the ability in the database
    # @return [Integer, false]
    def pokemon_ability_index(id)
      has_ability?(id, true)
    end
    # Checks if one Pokemon of the party can learn the requested skill.
    # @overload can_learn?(id)
    #   @param id [Integer, Symbol] the id of the skill in the database
    #   @return [Boolean]
    # @overload can_learn?(id, index)
    #   Returns the position of the first pokemon that meets conditions
    #   @param id [Integer, Symbol] the id of the skill in the database
    #   @param index [true] indicating to return the index
    #   @return [Integer, false]
    def can_learn?(id, index = false)
      id = data_move(id).db_symbol if id.is_a?(Integer)
      if index
        return @actors.find_index { |pokemon| pokemon&.can_learn?(id) } || false
      else
        return @actors.any? { |pokemon| pokemon&.can_learn?(id) }
      end
    end
    # Return the index of the Pokemon who can learn the specified skill
    # @param id [Integer, Symbol] the id of the skill in the database
    # @return [Integer, false]
    def can_learn_index(id)
      can_learn?(id, true)
    end
    # Checks if one Pokemon of the party can learn or has learnt the requested skill.
    # @overload can_learn_or_learnt?(id)
    #   @param id [Integer, Symbol] the id of the skill in the database
    #   @return [Boolean]
    # @overload can_learn_or_learnt?(id, index)
    #   Returns the position of the first pokemon that meets conditions
    #   @param id [Integer, Symbol] the id of the skill in the database
    #   @param index [true] indicating to return the index
    #   @return [Integer, false]
    def can_learn_or_learnt?(id, index = false)
      id = data_move(id).id if id.is_a?(Symbol)
      @actors.each_with_index do |pokemon, i|
        next unless pokemon
        if pokemon.can_learn?(id) != false
          return index ? i : true
        end
      end
      return false
    end
    # Return the index of the Pokemon who can learn or has learn the specified skill
    # @param id [Integer, Symbol] the id of the skill in the database
    # @return [Integer, false]
    def can_learn_or_learnt_index(id)
      can_learn_or_learnt?(id, true)
    end
    # Return the Pokemon that match the specific criteria
    # @param criteria [Hash] list of property linked to a value to check in order to find the Pokemon
    # @return [PFM::Pokemon, nil]
    def find_pokemon(criteria)
      @actors.find do |pokemon|
        criteria.each do |property, value|
          break((false)) unless pokemon.send(property) == value
        end
      end
    end
  end
  # Alias for old saves
  Pokemon_Party = GameState
end
# Global accessor for the game state
# @return [PFM::GameState, nil]
def game_state
  PFM.game_state
end
