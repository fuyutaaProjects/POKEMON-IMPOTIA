module PFM
  # The wild battle management
  #
  # The main object is stored in $wild_battle and PFM.game_state.wild_battle
  class Wild_Battle
    # List of ability that force strong Pokemon to battle (Intimidation / Regard vif)
    WEAK_POKEMON_ABILITY = %i[intimidate keen_eye]
    # List of special wild battle that are actually fishing
    FISHING_BATTLES = %i[normal super mega]
    # List of ability giving the max level of the pokemon we can encounter
    MAX_POKEMON_LEVEL_ABILITY = %i[hustle pressure vital_spirit]
    # Mapping allowing to get the correct tool based on the input
    TOOL_MAPPING = {normal: :old_rod, super: :good_rod, mega: :super_rod, rock: :rock_smash, headbutt: :headbutt}
    # List of Roaming Pokemon
    # @return [Array<PFM::Wild_RoamingInfo>]
    attr_reader :roaming_pokemons
    # List of Remaining creature groups
    # @return [Array<Studio::Group>]
    attr_reader :groups
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Get the history of the encounters wild Pokémon
    # @return [Array<Hash>]
    attr_reader :encounters_history
    # Create a new Wild_Battle manager
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state)
      @roaming_pokemons = []
      @forced_wild_battle = false
      @groups = []
      @game_state = game_state
      @encounters_history = []
    end
    # Reset the wild battle
    def reset
      @groups&.clear
      @roaming_pokemons.each(&:update)
      @roaming_pokemons.delete_if(&:pokemon_dead?)
      PFM::Wild_RoamingInfo.lock
      @fished = false
      @fish_battle = nil
    end
    # Load the groups of Wild Pokemon (map change/ time change)
    def load_groups
      groups = $env.get_current_zone_data.wild_groups.map { |group_name| data_group(group_name) }
      @groups = groups.select { |group| group.custom_conditions.reduce(true) { |prev, curr| curr.reduce_evaluate(prev) } }
    end
    # Is a wild battle available ?
    # @return [Boolean]
    def available?
      return false if $scene.is_a?(Battle::Scene)
      return false if game_state.pokemon_alive == 0
      return true if @fish_battle
      return true if roaming_battle_available?
      @forced_wild_battle = false
      return remaining_battle_available?
    end
    # Test if there's any fish battle available and start it if asked.
    # @param rod [Symbol] the kind of rod used to fish : :norma, :super, :mega
    # @param start [Boolean] if the battle should be started
    # @return [Boolean, nil] if there's a battle available
    def any_fish?(rod = :normal, start = false)
      return false unless game_state.env.can_fish?
      system_tag = game_state.game_player.front_system_tag_db_symbol
      terrain_tag = game_state.game_player.front_terrain_tag
      tool = TOOL_MAPPING[rod] || :__undef__
      current_group = @groups.find { |group| group.tool == tool && group.system_tag == system_tag && group.terrain_tag == terrain_tag }
      return false unless current_group
      if start
        @fish_battle = current_group
        if FISHING_BATTLES.include?(rod)
          @fished = true
        else
          @fished = false
        end
        return nil
      else
        return true
      end
    end
    # Test if there's any hidden battle available and start it if asked.
    # @param rod [Symbol] the kind of rod used to fish : :rock, :headbutt
    # @param start [Boolean] if the battle should be started
    # @return [Boolean, nil] if there's a battle available
    def any_hidden_pokemon?(rod = :rock, start = false)
      system_tag = game_state.game_player.front_system_tag_db_symbol
      terrain_tag = game_state.game_player.front_terrain_tag
      tool = TOOL_MAPPING[rod] || :__undef__
      current_group = @groups.find { |group| group.tool == tool && group.system_tag == system_tag && group.terrain_tag == terrain_tag }
      return false unless current_group
      if start
        @fish_battle = current_group
        @fished = false
        return nil
      else
        return true
      end
    end
    # Start a wild battle
    # @overload start_battle(id, level, *args)
    #   @param id [PFM::Pokemon] First Pokemon in the wild battle.
    #   @param level [Object] ignored
    #   @param args [Array<PFM::Pokemon>] other pokemon in the wild battle.
    #   @param battle_id [Integer] ID of the events to load for battle scenario
    # @overload start_battle(id, level, *args)
    #   @param id [Integer] id of the Pokemon in the database
    #   @param level [Integer] level of the first Pokemon
    #   @param args [Array<Integer, Integer>] array of id, level of the other Pokemon in the wild battle.
    #   @param battle_id [Integer] ID of the events to load for battle scenario
    def start_battle(id, level = 70, *others, battle_id: 1)
      $game_temp.battle_can_lose = false
      init_battle(id, level, *others)
      Graphics.freeze
      $scene = Battle::Scene.new(setup(battle_id))
      Yuki::FollowMe.set_battle_entry
    end
    # Init a wild battle
    # @note Does not start the battle
    # @overload init_battle(id, level, *args)
    #   @param id [PFM::Pokemon] First Pokemon in the wild battle.
    #   @param level [Object] ignored
    #   @param args [Array<PFM::Pokemon>] other pokemon in the wild battle.
    # @overload init_battle(id, level, *args)
    #   @param id [Integer] id of the Pokemon in the database
    #   @param level [Integer] level of the first Pokemon
    #   @param args [Array<Integer, Integer>] array of id, level of the other Pokemon in the wild battle.
    def init_battle(id, level = 70, *others)
      if id.class == PFM::Pokemon
        @forced_wild_battle = [id, *others]
      else
        id = data_creature(id).id if id.is_a?(Symbol)
        @forced_wild_battle = [PFM::Pokemon.new(id, level)]
        0.step(others.size - 1, 2) do |i|
          others[i] = data_creature(others[i]).id if others[i].is_a?(Symbol)
          @forced_wild_battle << PFM::Pokemon.new(others[i], others[i + 1])
        end
      end
    end
    # Set the Battle::Info with the right information
    # @param battle_id [Integer] ID of the events to load for battle scenario
    # @return [Battle::Logic::BattleInfo, nil]
    def setup(battle_id = 1)
      if @forced_wild_battle
        reset_encounters_history
        return configure_battle(@forced_wild_battle, battle_id)
      end
      return nil if PFM.game_state.repel_count > 0
      return nil unless (group = current_selected_group)
      reset_encounters_history if can_encounters_history_reset?(group)
      maxed = MAX_POKEMON_LEVEL_ABILITY.include?(creature_ability) && rand(100) < 50
      is_double_battle = group.is_double_battle || $game_variables[Yuki::Var::Allied_Trainer_ID] > 0
      all_creatures = (group.encounters * (is_double_battle ? 2 : 1)).map do |encounter|
        encounter.to_creature(maxed ? encounter.level_setup.range.end : nil)
      end
      creature_to_select = configure_creature(all_creatures)
      selected_creature = select_creature(group, creature_to_select)
      selected_creature.each do |creature|
        add_encounter_history(creature, group)
        reset_encounters_history if creature.shiny?
      end
      return configure_battle(selected_creature, battle_id)
    ensure
      @forced_wild_battle = false
      @fish_battle = nil
    end
    # Define a group of remaining wild battle
    # @param zone_type [Integer] type of the zone, see $env.get_zone_type to know the id
    # @param tag [Integer] terrain_tag on which the player should be to start a battle with wild Pokemon of this group
    # @param delta_level [Integer] the disparity of the Pokemon levels
    # @param vs_type [Integer] the vs_type the Wild Battle are
    # @param data [Array<Integer, Integer, Integer>, Array<Integer, Hash, Integer>] Array of id, level/informations, chance to see (Pokemon informations)
    def set(zone_type, tag, delta_level, vs_type, *data)
      raise 'This method is no longer supported'
    end
    # Test if a Pokemon is a roaming Pokemon (Usefull in battle)
    # @param pokemon [PFM::Pokemon]
    # @return [Boolean]
    def roaming?(pokemon)
      return roaming_pokemons.any? { |info| info.pokemon == pokemon }
    end
    alias is_roaming? roaming?
    # Add a roaming Pokemon
    # @param chance [Integer] the chance divider to see the Pokemon
    # @param proc_id [Integer] ID of the Wild_RoamingInfo::RoamingProcs
    # @param pokemon_hash [Hash, PFM::Pokemon] hash to generate the mon (cf. PFM::Pokemon#generate_from_hash), or the Pokemon
    # @return [PFM::Pokemon] the generated roaming Pokemon
    def add_roaming_pokemon(chance, proc_id, pokemon_hash)
      pokemon = pokemon_hash.is_a?(PFM::Pokemon) ? pokemon_hash : ::PFM::Pokemon.generate_from_hash(pokemon_hash)
      PFM::Wild_RoamingInfo.unlock
      @roaming_pokemons << Wild_RoamingInfo.new(pokemon, chance, proc_id)
      PFM::Wild_RoamingInfo.lock
      return pokemon
    end
    # Remove a roaming Pokemon from the roaming Pokemon array
    # @param pokemon [PFM::Pokemon] the Pokemon that should be removed
    def remove_roaming_pokemon(pokemon)
      roaming_pokemons.delete_if { |i| i.pokemon == pokemon }
    end
    # Ability that increase the rate of any fishing rod # Glue / Ventouse
    FishIncRate = %i[sticky_hold suction_cups]
    # Check if a Pokemon can be fished there with a specific fishing rod type
    # @param type [Symbol] :mega, :super, :normal
    # @return [Boolean]
    def check_fishing_chances(type)
      creek_amount = game_state.game_player.fishing_creek_amount
      is_inc_rate = FishIncRate.include?(creature_ability)
      return true if creek_amount >= 3
      case type
      when :mega
        rate = 60
      when :super
        rate = 45
      else
        rate = 30
      end
      rate *= 1.5 if is_inc_rate
      rate *= 1 + 0.1 * creek_amount
      result = rand(100) < rate
      reset_encounters_history unless result
      return result
    end
    # yield a block on every available roaming Pokemon
    def each_roaming_pokemon
      @roaming_pokemons.each do |roaming_info|
        yield(roaming_info.pokemon)
      end
    end
    # Tell the roaming pokemon that the playe has look at their position
    def on_map_viewed
      @roaming_pokemons.each do |info|
        info.spotted = true
      end
    end
    # Reset the history of the encounters wild Pokémon
    def reset_encounters_history
      @encounters_history = []
    end
    # Compute the fishing chain
    # @return [Integer] The total fishing chain (max 20)
    def compute_fishing_chain
      return 0 unless @encounters_history
      return @encounters_history.take_while { |encounter| %i[old_rod good_rod super_rod].include?(encounter[:tool]) }.count.clamp(0, 20)
    end
    # Method that prevent non wanted data save of the Wild_Battle object
    def begin_save
      $TMP_ENCOUNTERS_HISTORY = @encounters_history
      @encounters_history = []
    end
    # Method that end the save state of the Wild_Battle object
    def end_save
      @encounters_history = $TMP_ENCOUNTERS_HISTORY
      $TMP_ENCOUNTERS_HISTORY = nil
    end
    private
    # Test if a roaming battle is available
    # @return [Boolean]
    def roaming_battle_available?
      return false unless (info = roaming_pokemons.find(&:appearing?))
      PFM::Wild_RoamingInfo.unlock
      info.spotted = true
      init_battle(info.pokemon)
      return true
    end
    # Test if a remaining battle is available
    # @return [Boolean]
    def remaining_battle_available?
      system_tag = game_state.game_player.system_tag_db_symbol
      terrain_tag = game_state.game_player.terrain_tag
      current_group = @groups.find { |group| group.tool.nil? && group.system_tag == system_tag && group.terrain_tag == terrain_tag }
      return false unless current_group
      actor_level = $actors[0].level
      if PFM.game_state.repel_count > 0 && current_group.encounters.all? { |encounter| encounter.level_setup.repel_rejected(actor_level) }
        return false
      end
      if WEAK_POKEMON_ABILITY.include?(creature_ability)
        return current_group.encounters.any? { |encounter| encounter.level_setup.strong_selected(actor_level) } || rand(100) < 50
      end
      return true
    end
    # Function that returns the Creature ability of the Creature triggering all the stuff related to ability
    # @return [Symbol] db_symbol of the ability
    def creature_ability
      return :__undef__ unless game_state.actors[0]
      return game_state.actors[0].ability_db_symbol
    end
    # Get the current selected group
    # @return [Studio::Group, nil]
    def current_selected_group
      return @fish_battle if @fish_battle
      system_tag = game_state.game_player.system_tag_db_symbol
      terrain_tag = game_state.game_player.terrain_tag
      return @groups.find { |group| group.tool.nil? && group.system_tag == system_tag && group.terrain_tag == terrain_tag }
    end
    # Add an encounter in the history
    # @param creature [PFM::Pokemon]
    # @param group [Studio::Group]
    def add_encounter_history(creature, group)
      @encounters_history ||= []
      hash = {}
      hash[:db_symbol] = creature.db_symbol
      hash[:form] = creature.form
      hash[:system_tag] = group.system_tag
      hash[:terrain_tag] = group.terrain_tag
      hash[:tool] = group.tool
      @encounters_history << hash
    end
    # Check and reset if necessary the history of the encounters
    # @param group [Studio::Group]
    def can_encounters_history_reset?(group)
      last = @encounters_history&.last
      return false unless last
      is_fishing_group = %i[old_rod good_rod super_rod].include?(group.tool)
      is_fishing_last = %i[old_rod good_rod super_rod].include?(last[:tool])
      return is_fishing_group != is_fishing_last
    end
    public
    # Hash describing which method to seek to change the Pokemon chances depending on the player's leading Pokemon's talent
    CHANGE_POKEMON_CHANCE = {keen_eye: :rate_intimidate_keen_eye, intimidate: :rate_intimidate_keen_eye, cute_charm: :rate_cute_charm, magnet_pull: :rate_magnet_pull, compound_eyes: :rate_compound_eyes, super_luck: :rate_compound_eyes, static: :rate_static, lightning_rod: :rate_static, flash_fire: :rate_flash_fire, synchronize: :rate_synchronize, storm_drain: :rate_storm_drain, harvest: :rate_harvest}
    private
    # Configure the creature array for later selection
    # @param creatures [Array<PFM::Pokemon>]
    # @return [Array<Array(PFM::Pokemon, Float)>] all creatures with their rate to get selected
    def configure_creature(creatures)
      main_creature = $actors[0]
      ability = creature_ability
      repel_active = PFM.game_state.repel_count > 0
      return creatures.map do |creature|
        rate = 1
        rate = send(CHANGE_POKEMON_CHANCE[ability], creature, main_creature) if respond_to?(CHANGE_POKEMON_CHANCE[ability] || :__undef__, true)
        if creature.level < main_creature.level
          rate *= 0.33 if main_creature.item_db_symbol == :cleanse_tag
          rate = 0 if repel_active
        end
        next([creature, rate])
      end
    end
    # Get rate for Intimidate/Keen Eye cases
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_intimidate_keen_eye(creature, main_creature)
      return (creature.level + 5) < main_creature.level ? 0.5 : 1
    end
    # Get rate for Cute Charm case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_cute_charm(creature, main_creature)
      return (creature.gender * main_creature.gender) == 2 ? 1.5 : 1
    end
    # Get rate for Magnet Pull case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_magnet_pull(creature, main_creature)
      return creature.type_steel? ? 1.5 : 1
    end
    # Get rate for Compound Eyes case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_compound_eyes(creature, main_creature)
      return creature.item_db_symbol != :__undef__ ? 1.5 : 1
    end
    # Get rate for Statik case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_static(creature, main_creature)
      return creature.type_electric? ? 1.5 : 1
    end
    # Get rate for Storm Drain case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_storm_drain(creature, main_creature)
      return creature.type_water? ? 1.5 : 1
    end
    # Get rate for Flash Fire case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_flash_fire(creature, main_creature)
      return creature.type_fire? ? 1.5 : 1
    end
    # Get rate for Harvest case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_harvest(creature, main_creature)
      return creature.type_grass? ? 1.5 : 1
    end
    # Get rate for Synchronize case
    # @param creature [PFM::Pokemon] creature to select
    # @param main_creature [PFM::Pokemon] pokemon that caused the rate verification
    # @return [Float] new rate or 1
    def rate_synchronize(creature, main_creature)
      return creature.nature_id == main_creature.nature_id ? 1.5 : 1
    end
    # Select the creatures that will be in the battle
    # @param group [Studio::Group] the descriptor of the Wild group
    # @param creature_to_select [Array<Array(PFM::Pokemon, Float)>] list of Pokemon to select with their rates
    # @return [Array<PFM::Pokemon>]
    def select_creature(group, creature_to_select)
      encounters = group.encounters
      real_rareness = creature_to_select.map.with_index { |arr, i| [arr.first, arr.last * encounters[i % encounters.size].encounter_rate] }
      reduced_rareness = real_rareness.reduce([]) { |acc, curr| acc << (curr.last + (acc.last || 0)) }
      max_rand = reduced_rareness.last
      is_double_battle = group.is_double_battle || $game_variables[Yuki::Var::Allied_Trainer_ID] > 0
      return (is_double_battle ? 2 : 1).times.reduce([]) do |acc, _|
        nb = Random::WILD_BATTLE.rand(max_rand.to_i)
        index = reduced_rareness.find_index { |i| i > nb } || real_rareness.size - 1
        creature = real_rareness[index].first
        redo if acc.include?(creature)
        acc << creature
      end
    end
    # Configure the wild battle
    # @param enemy_arr [Array<PFM::Pokemon>]
    # @param battle_id [Integer] ID of the events to load for battle scenario
    # @return [Battle::Logic::BattleInfo]
    def configure_battle(enemy_arr, battle_id)
      return if (!enemy_arr.is_a? Array) || !enemy_arr || enemy_arr&.empty?
      allied_trainer_id = $game_variables[Yuki::Var::Allied_Trainer_ID]
      ally = data_trainer(allied_trainer_id) if allied_trainer_id.positive?
      has_roaming = enemy_arr.any? { |pokemon| roaming?(pokemon) }
      info = Battle::Logic::BattleInfo.new
      info.add_party(0, *info.player_basic_info)
      info.add_party(0, ally.party.map(&:to_creature), ally.name, ally.class_name, nil, nil, nil, ally.ai) if allied_trainer_id.positive?
      info.add_party(1, enemy_arr, nil, nil, nil, nil, nil, has_roaming ? -1 : 0)
      info.battle_id = battle_id
      info.fishing = !@fish_battle.nil?
      info.vs_type = 2 if enemy_arr.size >= 2
      return info
    end
  end
  # Retro compatibility with saves
  Wild_Info = Object
  class GameState
    # The information about the Wild Battle
    # @return [PFM::Wild_Battle]
    attr_accessor :wild_battle
    on_player_initialize(:wild_battle) {@wild_battle = PFM::Wild_Battle.new(self) }
    on_expand_global_variables(:wild_battle) do
      $wild_battle = @wild_battle
      @wild_battle.game_state = self
    end
  end
  # Wild Roaming Pokemon informations
  # @author Nuri Yuri
  class Wild_RoamingInfo
    # The tag in which the Roaming Pokemon will appear
    # @return [Integer]
    attr_accessor :tag
    # The system_tag zone ID in which the Roaming Pokemon will appear
    # @return [Integer]
    attr_accessor :zone_type
    # The ID of the map in which the Roaming Pokemon will appear
    # @return [Integer]
    attr_accessor :map_id
    # The roaming Pokemon
    # @return [PFM::Pokemon]
    attr_reader :pokemon
    # The spotted state of the pokemon. True if the player look at the map position or after fighting the roaming pokemon
    # @return [Boolean]
    attr_accessor :spotted
    @@locked = true
    # Allow roaming informations to be updated
    def self.unlock
      @@locked = false
    end
    # Disallow roaming informations to be updated
    def self.lock
      @@locked = true
    end
    # Create a new Wild_RoamingInfo
    # @param pokemon [PFM::Pokemon] the roaming Pokemon
    # @param chance [Integer] the chance divider to see the Pokemon
    # @param zone_proc_id [Integer] ID of the Wild_RoamingInfo::RoamingProcs
    def initialize(pokemon, chance, zone_proc_id)
      @pokemon = pokemon
      @proc_id = zone_proc_id
      @map_id = -1
      @chance = chance
      @tag = 0
      @zone_type = -1
      @spotted = true
      update
    end
    # Call the Roaming Proc to update the Roaming Pokemon zone information
    def update
      RoamingProcs[@proc_id]&.call(self) unless @@locked
    end
    # Test if the Pokemon is dead (delete from the stack)
    # @return [Boolean]
    def pokemon_dead?
      @pokemon.dead?
    end
    # Test if the Roaming Pokemon is appearing (to start the battle)
    # @return [Boolean]
    def appearing?
      return false if @pokemon.hp <= 0
      if @map_id == $game_map.map_id && @zone_type == $env.get_zone_type(true) && @tag == $game_player.terrain_tag
        return rand(@chance) == 0
      end
      return false
    end
    # Test if the Roaming Pokemon could appear here
    # @return [Boolean]
    def could_appear?
      return (@map_id == $game_map.map_id && @zone_type == $env.get_zone_type(true) && @tag == $game_player.terrain_tag)
    end
  end
end
# The procs of Roaming Pokemon.
# 
# The proc takes the Wild_RoamingInfo in parameter and change the informations.
::PFM::Wild_RoamingInfo::RoamingProcs = [proc do |infos|
  infos.map_id = 1
  infos.zone_type = 1
  infos.tag = 1
end, proc do |infos|
  maps = [25, 46, 35, 27]
  if (infos.map_id == $game_map.map_id && infos.spotted) || infos.map_id == -1
    infos.map_id = (maps - [infos.map_id]).sample
    infos.spotted = false
  end
  infos.zone_type = 1
  infos.tag = 0
end]
