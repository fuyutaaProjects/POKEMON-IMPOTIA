module Battle
  # Logic part of Pokemon Battle
  #
  # This class helps to access to the battle information & to process some part of the battle
  class Logic
    # @return [Array<Array>] list of messages to send to an interpreter (AI/Scene)
    attr_reader :messages
    # @return [Array<Actions::Base>] list of the current actions to proccess during the scene
    attr_reader :actions
    # @return [Array<Actions::Base>] list of all actions that occurs within the current turn
    attr_accessor :turn_actions
    # 0 : Victory, 1 : Flee, 2 : Defeat, -1 : undef
    # @return [Integer]
    attr_accessor :battle_result
    # @return [Array<Array<PFM::Bag>>] bags of each banks
    attr_reader :bags
    # @return [Battle::Logic::BattleInfo]
    attr_reader :battle_info
    # Get the evolve requests
    # @return [Array<PFM::PokemonBattler>]
    attr_reader :evolve_request
    # Get the Mega Evolve helper
    # @return [MegaEvolve]
    attr_reader :mega_evolve
    # Get the switch requests
    # @return [Array<Hash>]
    attr_reader :switch_request
    # Get the scene used to instanciate this Logic instance
    # @return [Battle::Scene]
    attr_reader :scene
    # Get the move damage rng
    # @return [Random]
    attr_reader :move_damage_rng
    # Get the move critical rng
    # @return [Random]
    attr_reader :move_critical_rng
    # Get the move accuracy rng
    # @return [Random]
    attr_reader :move_accuracy_rng
    # Get the generic rng
    # @return [Random]
    attr_reader :generic_rng
    # If the battle is in debug and forcing the end of it
    attr_accessor :debug_end_of_battle
    # All the Pokemon with Ball Fetch on the field sorted by decreasing speed when the player fails the capture
    # @return [Array<PFM::PokemonBattler>]
    attr_accessor :ball_fetch_on_field
    # Create a new Logic instance
    # @param scene [Scene] scene that hold the logic object
    def initialize(scene)
      @scene = scene
      @battle_info = scene.battle_info
      Message.setup(self)
      @messages = []
      @actions = []
      @turn_actions = []
      @bags = @battle_info.bags
      @battlers = []
      init_effects
      @mega_evolve = MegaEvolve.new(scene)
      @global_states = {}
      @bank_states = Hash.new({})
      @battle_result = -1
      @switch_request = []
      @evolve_request = []
      $game_temp.battle_turn = 0
      $bag.last_ball_used_db_symbol = :__undef__
      @ball_fetch_on_field = []
    end
    # Safe to_s & inspect
    def to_s
      format('#<%<class>s:%<id>08X>', class: self.class, id: __id__)
    end
    alias inspect to_s
    # Return the number of bank in the current battle
    # @return [Integer]
    def bank_count
      return @battlers.size
    end
    # Tell if the battle can continue
    # @return [Boolean]
    def can_battle_continue?
      return false if @battle_result >= 0
      if all_battlers.any?(&:from_party?) && all_battlers.select(&:from_party?).all?(&:dead?) && !$game_switches[Yuki::Sw::BT_AI_CAN_WIN]
        @battle_result = 2
        return false
      end
      banks_that_can_fight = @battlers.map.with_index { |battlers, bank| battlers.any?(&:alive?) ? bank : nil }.compact
      if banks_that_can_fight.size <= 1
        @battle_result = banks_that_can_fight.include?(0) ? 0 : 2
        return false
      end
      return true
    end
    # Load the RNG for the battle logic
    # @param seeds [Hash] seeds for the RNG
    def load_rng(seeds = Hash.new(Random.new_seed))
      @move_damage_rng = Random.new(seeds[:move_damage_rng])
      @move_critical_rng = Random.new(seeds[:move_critical_rng])
      @move_accuracy_rng = Random.new(seeds[:move_accuracy_rng])
      @generic_rng = Random.new(seeds[:generic_rng])
    end
    # Get the current RNG Seeds
    # @return [Hash{ Symbol => Integer }]
    def rng_seeds
      {move_damage_rng: @move_damage_rng.seed, move_critical_rng: @move_critical_rng.seed, move_accuracy_rng: @move_accuracy_rng.seed, generic_rng: @generic_rng.seed}
    end
    # Return the battler of a bank
    # @param bank [Integer] bank where the Pokemon is
    # @param position [Integer] position of the Pokemon in the bank
    # @return [PFM::PokemonBattler, nil]
    def battler(bank, position)
      return nil if position < 0
      return @battlers.dig(bank, position)
    end
    # Return the number of battler (alive) in one bank
    # @param bank [Integer]
    # @return [Integer]
    def battler_count(bank)
      count = 0
      $game_temp.vs_type.times { |i| count += 1 if battler(bank, i)&.dead? == false }
      return count
    end
    # Return the adjacent foes
    # @param pokemon [PFM::PokemonBattler]
    # @return [Array<PFM::PokemonBattler>]
    def adjacent_foes_of(pokemon)
      foes_of(pokemon, true)
    end
    # Return the foes
    # @param pokemon [PFM::PokemonBattler]
    # @param check_adjacent [Boolean]
    # @return [Array<PFM::PokemonBattler>]
    def foes_of(pokemon, check_adjacent = false)
      return [] if pokemon.position.nil? || pokemon.position >= @battle_info.vs_type
      position = pokemon.position
      return @battlers.flat_map.with_index do |battler_bank, bank|
        next(nil.to_a) if bank == pokemon.bank
        next(battler_bank.select.with_index do |foe, foe_position|
          foe.can_fight? && (!check_adjacent || (foe_position - position).abs <= 1)
        end)
      end
    end
    # Return the adjacent allies
    # @param pokemon [PFM::PokemonBattler]
    # @return [Array<PFM::PokemonBattler>]
    def adjacent_allies_of(pokemon)
      allies_of(pokemon, true)
    end
    # Return the allies (excluding the pokemon)
    # @param pokemon [PFM::PokemonBattler]
    # @param check_adjacent [Boolean]
    # @return [Array<PFM::PokemonBattler>]
    def allies_of(pokemon, check_adjacent = false)
      return [] if pokemon.position.nil? || pokemon.position >= @battle_info.vs_type
      position = pokemon.position
      return @battlers[pokemon.bank].select.with_index do |ally, ally_position|
        next(ally_position != position && ally.can_fight? && (!check_adjacent || (ally_position - position).abs <= 1))
      end
    end
    # Return all the alive battler of a bank
    # @param bank [Integer]
    # @return [Array<PFM::PokemonBattler>]
    def alive_battlers(bank)
      return @battlers[bank].select(&:can_fight?)
    end
    # Return all the alive battler of a bank but don't check can_fight?
    # @param bank [Integer]
    # @return [Array<PFM::PokemonBattler>]
    def alive_battlers_without_check(bank)
      return @battlers[bank].select(&:alive?)
    end
    # Return all alive battlers
    # @return [Array<PFM::PokemonBattler>]
    def all_alive_battlers
      return @battlers.each_index.flat_map { |bank| alive_battlers(bank) }
    end
    # Load the battlers from the battle infos
    def load_battlers
      @battle_info.parties.each_with_index do |parties, bank|
        next unless parties
        parties.each_with_index do |party, index|
          load_battlers_from_party(party, bank, index)
        end
        adjust_party(@battlers[bank]) if @battle_info.vs_type > 1
        @battle_info.vs_type.times do |i|
          @battlers.dig(bank, i)&.position = i
        end
      end
      all_battlers { |battler| transform_handler.initialize_transform_attempt(battler) }
    end
    # Add a switch request
    # @param who [PFM::PokemonBattler]
    # @param with [PFM::PokemonBattler, nil] if nil, ask the player
    def request_switch(who, with)
      @switch_request.delete_if { |request| request[:who] == who }
      @switch_request << {who: who, with: with}
    end
    # Update the turn count of all alive battler
    def update_battler_turn_count
      $game_temp.battle_turn += 1
      all_alive_battlers.each do |pokemon|
        pokemon.turn_count += 1
        pokemon.last_battle_turn = $game_temp.battle_turn
      end
    end
    # Test if the battler attacks before another
    # @param battler [PFM::PokemonBattler]
    # @param other [PFM::PokemonBattler]
    # @return [Boolean]
    def battler_attacks_before?(battler, other)
      return false unless battler.attack_order&.integer? && other.attack_order&.integer?
      return false if other.dead?
      return battler.attack_order < other.attack_order
    end
    # Test if the battler attacks after another
    # @param battler [PFM::PokemonBattler]
    # @param other [PFM::PokemonBattler]
    # @return [Boolean]
    def battler_attacks_after?(battler, other)
      return false unless battler.attack_order&.integer? && other.attack_order&.integer?
      return battler.attack_order > other.attack_order
    end
    # Test if the battler attacks first
    # @param battler [PFM::PokemonBattler]
    # @return [Boolean]
    def battler_attacks_first?(battler)
      return battler.attack_order == 0
    end
    # Test if the battler attacks last
    # @param battler [PFM::PokemonBattler]
    # @return [Boolean]
    def battler_attacks_last?(battler)
      last_order = all_alive_battlers.map(&:attack_order).reject { |i| i == Float::INFINITY }.compact.max
      return battler.attack_order == last_order
    end
    # Switch two pokemon (logically)
    # @param who [PFM::PokemonBattler] Pokemon being switched
    # @param with [PFM::PokemonBattler] Pokemon comming on the ground
    def switch_battlers(who, with)
      with_position = @battlers[who.bank].index(with)
      who_position = @battlers[who.bank].index(who)
      @battlers[who.bank][who_position] = with
      @battlers[with.bank][with_position] = who
      with.position, who.position = who.position, with.position
      with.place_in_party, who.place_in_party = who.place_in_party, with.place_in_party
      with.last_battle_turn = $game_temp.battle_turn
    end
    # Iterate through all battlers
    # @yieldparam battler [PFM::PokemonBattler]
    # @return [Enumerable<PFM::PokemonBattler>]
    def all_battlers
      if block_given?
        @battlers.flatten.each { |battler| yield(battler) }
      else
        return @battlers.flatten.each
      end
    end
    # Test if the battler can be replaced
    # @param who [PFM::PokemonBattler]
    # @return [Boolean]
    def can_battler_be_replaced?(who)
      return false if who.effects.has?(&:force_next_turn_action?) && who.alive?
      bank = who.bank
      party_id = who.party_id
      allies = allies_of(who)
      number = all_battlers.count { |pokemon| pokemon != who && pokemon.alive? && pokemon.bank == bank && pokemon.party_id == party_id && !allies.include?(pokemon) }
      return number > 0
    end
    # List all the trainer Pokemon
    # @return [Array<PFM::PokemonBattler>]
    def trainer_battlers
      return @battlers[0].compact.select(&:from_party?)
    end
    # Check active abilities on the field
    # @return [Array<PFM::PokemonBattler>]
    def any_field_ability_active?(db_symbol)
      return @battlers.any? { |battlers| battlers.any? { |battler| battler.has_ability?(db_symbol) } }
    end
    private
    # Load the battlers from a party
    # @param party [Array<PFM::Pokemon>]
    # @param bank [Integer]
    # @param index [Integer] index of the party in the parties array (party_id)
    def load_battlers_from_party(party, bank, index)
      party = sort_party(party)
      battlers = (@battlers[bank] ||= [])
      max_level = @battle_info.max_level
      party.each do |pokemon|
        battler = max_level ? PFM::PokemonBattler.new(pokemon, @scene, max_level) : PFM::PokemonBattler.new(pokemon, @scene)
        battler.bank = bank
        battler.place_in_party = scene.logic.battle_info.party(battler).index(battler.original)
        battler.party_id = index
        battler.bag = @bags[bank][index] || PFM::Bag.new
        battlers << battler
      end
    end
    # Sort a party (push the dead mon at the end)
    # @param party [Array<PFM::Pokemon>]
    # @return [Array<PFM::Pokemon>]
    def sort_party(party)
      party = party.compact
      dead_mons = party.select(&:dead?)
      party.delete_if { |pokemon| dead_mons.include?(pokemon) }
      party.concat(dead_mons)
    end
    # Make sure the Pokemon of each party are in first position
    # @param party [Array<PFM::PokemonBattler>]
    def adjust_party(party)
      parties = {}
      party.each do |pokemon|
        sub_party = (parties[pokemon.party_id] ||= [])
        sub_party << pokemon
      end
      party.clear
      i = 0
      did_something = true
      while did_something
        did_something = false
        parties.each_value do |sub_party|
          next unless (pokemon = sub_party[i])
          party << pokemon
          did_something = true
        end
        i += 1
      end
    end
    # List all dead enemy Pokemon during this turn
    # @return [Array<PFM::PokemonBattler>]
    def dead_enemy_battler_during_this_turn
      turn = $game_temp.battle_turn
      return 1.upto(bank_count - 1).flat_map do |bank|
        next(@battlers[bank].compact.select { |battler| battler.last_battle_turn == turn && battler.dead? })
      end
    end
    # List all dead friend Pokemon during this turn
    # @return [Array<PFM::PokemonBattler>]
    def dead_friend_battler_during_this_turn
      turn = $game_temp.battle_turn
      return @battlers[0].compact.select { |battler| battler.last_battle_turn == turn && battler.dead? && !battler.from_party? }
    end
    public
    # Constant giving an offset for the move priority : In RH moves start their priority from 0 (-7) and end at 14 (+7)
    MOVE_PRIORITY_OFFSET = -7
    # Priority of pursuit when a switch will occur
    PURSUIT_PRIORITY = 7
    # Priority of MEGA
    MEGA_PRIORITY = 8
    # Priority of other things
    OTHER_PRIORITY = 6
    # List of move first handler by item held
    ITEM_PRIORITY_BOOST_IN_PRIORITY = {quick_claw: :check_priority_trigger_quick_claw, custap_berry: :check_priority_trigger_custap_berry}
    # List of move first handler by ability
    ABILITY_PRIORITY_BOOST_IN_PRIORITY = {quick_draw: :check_priority_trigger_quick_draw}
    # Value that contains 0.25
    VAL_0_25 = 0.25
    # Add actions to process in the next step
    # @param actions [Array<Actions::Base>] the list of the actions
    def add_actions(actions)
      @actions.concat(actions.select(&:valid?))
    end
    # Execute the next action
    # @return [Boolean] if there was an action or not
    def perform_next_action
      return false if @actions.empty? || !can_battle_continue?
      action = @actions.pop
      log_debug("Current action : #{action}")
      @scene.message_window.blocking = false
      PFM::Text.reset_variables
      action.execute
      execute_post_action_events
      battle_phase_switch_exp_check
      return true
    end
    # Sort the actions
    # @note The last action in the stack is the first action to pop out from the stack
    def sort_actions
      refine_actions
      sorted_actions = sort_action_and_add_effects
      @actions.clear
      @actions.concat(sorted_actions.reverse)
      @turn_actions.clear
      @turn_actions.concat(sorted_actions.reverse)
      define_pokemon_action_properties
    end
    # Sort the actions
    # @param block [Block] block used to sort the actions take |Actions::Base, Actions::Base| as arguments
    def force_sort_actions(&block)
      @actions.sort!(&block)
    end
    private
    # Process specific behaviours
    def refine_actions
      handle_pre_attack_action
      handle_dancer
    end
    # Execute post action effects
    def execute_post_action_events
      log_debug('Execution of the on_post_action_event effects')
      each_effects(*all_alive_battlers) { |e| e.on_post_action_event(self, @scene, all_alive_battlers) }
    end
    # Define all pokemon action properties based on the actions
    def define_pokemon_action_properties
      all_alive_battlers.each { |battler| battler.attack_order = Float::INFINITY }
      index = @actions.count { |action| action.is_a?(Actions::Attack) } - 1
      @actions.each do |action|
        next unless action.is_a?(Actions::Attack)
        Actions::Attack.from(action).launcher.attack_order = index
        index -= 1
      end
    end
    # Group the action by priority
    # @return [Array<Actions::Base>]
    def sort_action_and_add_effects
      highest_priority = @actions.reject { |action| action.is_a?(Actions::Attack) }
      switching = process_and_list_switching_actions(highest_priority)
      move_action = @actions.select { |action| action.is_a?(Actions::Attack) }
      if switching.any?
        move_action.each do |action|
          next unless action.move.db_symbol == :pursuit
          target = action.target
          action.pursuit_enabled = switching.any? { |switch| switch.who == target }
        end
      end
      move_by_priority = move_action.group_by(&:priority)
      move_by_priority.each { |_, attacks| check_priority_item_trigger(attacks) }
      actions = highest_priority.concat(move_by_priority.values.flatten)
      return actions.sort
    end
    # List & add effect of switching actions
    # @param highest_priority [Array<Actions::Base>] list of actions that are not attack
    # @return [Array<Actions::Switch>] list of switch action
    def process_and_list_switching_actions(highest_priority)
      switching_actions = highest_priority.select { |action| action.is_a?(Actions::Switch) && action.who }
      switching_actions.each do |action|
        action.who.switching = true
        action.with.switching = true
      end
      return switching_actions
    end
    # Check for item held that gives more priority and put the pokemon on top
    # @param actions [Array<Actions::Attack>]
    def check_priority_item_trigger(actions)
      return if actions.size <= 1
      triggered_action = actions[1..-1].find do |action|
        message1 = ABILITY_PRIORITY_BOOST_IN_PRIORITY[action.launcher.ability_db_symbol]
        log_debug("#{action.launcher.ability_db_symbol} activate ?") if message1
        result1 = (message1 ? send(message1, action) : false)
        log_debug("#{message1} returned #{result1}") if message1
        if result1
          @scene.visual.show_ability(action.launcher)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1257, action.launcher))
          next((result1))
        end
        message2 = ITEM_PRIORITY_BOOST_IN_PRIORITY[action.launcher.battle_item_db_symbol]
        log_debug("#{action.launcher.battle_item_db_symbol} held by #{action.launcher}") if message2
        @result_item = (message2 ? send(message2, action.launcher) : false)
        log_debug("#{message2} returned #{@result_item}") if message2
        next((@result_item))
      end
      return unless triggered_action
      triggered_action.ignore_speed = true
      actions << Actions::HighPriorityItem.new(@scene, triggered_action.launcher)
    end
    # Function that handle the dancer ability
    def handle_dancer
      dancing_moves = @actions.select { |action| action.is_a?(Actions::Attack) && action.move.dance? }
      dancers = all_alive_battlers.select { |battler| battler.has_ability?(:dancer) }
      dancing_moves.each do |move|
        move.sub_launchers.concat(dancers.reject { |dancer| dancer == move.launcher })
      end
    end
    # Handle the attakcs with pre attack effects
    def handle_pre_attack_action
      attack_actions = @actions.select { |action| action.is_a?(Actions::Attack) && action.move.pre_attack? }.sort
      return if attack_actions.empty?
      add_actions([Actions::PreAttack.new(@scene, attack_actions)])
    end
    # Test the quick claw trigger
    # @param pokemon [PFM::PokemonBattler]
    # @return [Boolean] if the item triggered
    def check_priority_trigger_quick_claw(pokemon)
      return bchance?(0.2, self)
    end
    # Test the custap berry trigger
    # @param pokemon [PFM::PokemonBattler]
    # @return [Boolean] if the item triggered
    def check_priority_trigger_custap_berry(pokemon)
      return pokemon.has_ability?(:gluttony) ? pokemon.hp_rate < 0.5 : pokemon.hp_rate < 0.25
    end
    # Test the quick draw trigger
    # @param action [Battle::Actions::Base]
    # @return [Boolean] if the ability triggered
    def check_priority_trigger_quick_draw(action)
      return bchance?(0.3, self) if action.is_a?(Actions::Attack) && !action.move.status?
    end
    public
    # List of critical rates according to the current critical count
    CRITICAL_RATES = {0 => 0, 1 => 6_250, 2 => 12_500, 3 => 50_000}
    CRITICAL_RATES.default = 100_000
    # Calculate if the current action will be a critical hit
    # @param user [PFM::PokemonBattler]
    # @param target [PFM::PokemonBattler]
    # @param initial_critical_count [Integer] Initial critical count of the move
    # @return [Boolean]
    def calc_critical_hit(user, target, initial_critical_count)
      return false if bank_effects[target.bank].has?(:lucky_chant)
      return true if user.has_ability?(:merciless) && (target.poisoned? || target.toxic?)
      return true if user.effects.has?(:laser_focus)
      current_value = @move_critical_rng.rand(100_000)
      return current_value < CRITICAL_RATES[calc_critical_count(user, target, initial_critical_count)]
    end
    # List of ability preventing the critical hit from happening
    NO_CRITICAL_ABILITIES = %i[battle_armor shell_armor]
    # Calculate the critical count (to get the right critical propability)
    # @param user [PFM::PokemonBattler]
    # @param target [PFM::PokemonBattler]
    # @param initial_critical_count [Integer] Initial critical count of the move
    # @return [Integer]
    def calc_critical_count(user, target, initial_critical_count)
      return 0 if user.can_be_lowered_or_canceled?(NO_CRITICAL_ABILITIES.include?(target.battle_ability_db_symbol))
      critical_count = initial_critical_count
      critical_count += 2 if user.effects.has?(:focus_energy)
      critical_count += 1 if user.has_ability?(:super_luck)
      critical_count += 1 if calc_critical_count_item(user)
      critical_count += 1 if user.effects.has?(:lansat_berry)
      return critical_count
    end
    # List of items that unconditionally improve critical rate
    UNCONDITIONAL_CRITICAL_ITEMS = %i[razor_claw scope_lens]
    # Tell if the user has an item that increase the critical count
    # @param user [PFM::PokemonBattler]
    # @return [Boolean]
    def calc_critical_count_item(user)
      item = user.battle_item_db_symbol
      return true if UNCONDITIONAL_CRITICAL_ITEMS.include?(item)
      return true if item == :leek && user.db_symbol == :farfetch_d
      return true if item == :lucky_punch && user.db_symbol == :chansey
      return false
    end
    public
    # Function that distribute the exp to all Pokemon and switch dead pokemon
    def battle_phase_end
      log_debug('Entering battle_phase_end')
      end_turn_handler.process_events
      log_debug('end_turn_handler called')
      @switch_request.concat(dead_enemy_battler_during_this_turn.map { |battler| {who: battler} })
      log_data("Number of switch request (ennemy) : #{@switch_request.size}")
      @switch_request.concat(dead_friend_battler_during_this_turn.map { |battler| {who: battler} })
      log_data("Number of switch request (friend) : #{@switch_request.size}")
      turn = $game_temp.battle_turn
      @switch_request.concat(trainer_battlers.select { |battler| battler.last_battle_turn == turn && battler.dead? }.map { |battler| {who: battler} })
      log_data("Number of switch request (enemy + actors) : #{@switch_request.size}")
      @switch_request.uniq! { |h| h[:who] }
      @switch_request.select! { |h| h[:who].position&.between?(0, @battle_info.vs_type - 1) }
      battle_phase_switch_exp_check
      log_debug('battle_phase_switch_exp_check called')
      all_alive_battlers.each { |pokemon| pokemon.switching = false }
    end
    # Function that test the experience distribution
    def battle_phase_exp
      exp_distributions = exp_handler.distribute_exp_grouped(dead_enemy_battler_during_this_turn)
      @scene.visual.show_exp_distribution(exp_distributions) if exp_distributions.any?
    end
    # Function that process the switches and give exp
    def battle_phase_switch_exp_check
      return unless can_battle_continue?
      log_debug('battle_phase_switch_exp_check working')
      battle_phase_exp
      @switch_request.each { |h| battle_phase_switch_execute(**h) }
      @switch_request.clear
    end
    # Function that executes the switch request
    # @param who [PFM::PokemonBattler] Pokemon being switched out
    # @param with [PFM::PokemonBattler, nil] Pokemon replacing who
    def battle_phase_switch_execute(who:, with: nil)
      return Actions::Switch.new(@scene, who, with).execute if who && with
      log_data("Attempting to switch #{who}")
      return unless can_battler_be_replaced?(who)
      with = switch_choose_with(who)
      log_data("Pokemon switched with #{who} : #{with}")
      return unless with
      during_end_of_turn = @actions.empty?
      request_switch_to_trainer(with) if who.bank != 0 && who.dead? && during_end_of_turn && !@scene.force_ia_switch?
      Actions::Switch.new(@scene, who, with).execute
    end
    # Function that process the battle end when Pokemon was caught
    def battle_phase_end_caught
      pokemon = alive_battlers(1).find { |enemy| @battle_info.caught_pokemon == enemy }
      @scene.visual.show_exp_distribution(exp_handler.distribute_exp_for(pokemon))
    end
    private
    # Function that guess who we should switch the pokemon with
    # @param who [PFM::PokemonBattler]
    # @return [PFM::PokemonBattler, nil]
    def switch_choose_with(who)
      if who.from_party?
        return nil if trainer_battlers.all?(&:dead?)
        return @scene.visual.show_pokemon_choice(true)
      end
      right_ai = @scene.artificial_intelligences.find { |ai| ai.party_id == who.party_id && ai.bank == who.bank }
      return right_ai&.request_switch(who)
    end
    # Function that ask the player if he wants to switch
    # @param enemy [PFM::PokemonBattler]
    def request_switch_to_trainer(enemy)
      battlers = trainer_battlers
      who = battlers[0]
      if $options.battle_mode && @battle_info.vs_type == 1 && battlers.count(&:alive?) > 1 && can_battler_be_replaced?(who) && !who.dead?
        text = parse_text(18, 21, '[VAR 010E(0000)]' => @battle_info.trainer_class(enemy), '[VAR TRNAME(0001)]' => @battle_info.trainer_name(enemy), '[VAR 019E(0000)]' => "#{@battle_info.trainer_class(enemy)} #{@battle_info.trainer_name(enemy)}", '[VAR PKNICK(0002)]' => enemy.given_name)
        choice = @scene.display_message_and_wait(text, 1, text_get(11, 27), text_get(11, 28))
        if choice == 0 && (result = @scene.visual.show_pokemon_choice)
          Actions::Switch.new(@scene, who, result).execute if result != who
        end
      end
    end
    public
    # Get a new stat change handler
    # @return [Battle::Logic::StatChangeHandler]
    def stat_change_handler
      return StatChangeHandler.new(self, @scene)
    end
    # Get a new item change handler
    # @return [Battle::Logic::ItemChangeHandler]
    def item_change_handler
      return ItemChangeHandler.new(self, @scene)
    end
    # Get a new item change handler
    # @return [Battle::Logic::StatusChangeHandler]
    def status_change_handler
      return StatusChangeHandler.new(self, @scene)
    end
    # Get a new damage handler
    # @return [Battle::Logic::DamageHandler]
    def damage_handler
      return DamageHandler.new(self, @scene)
    end
    # Get a new switch handler
    # @return [Battle::Logic::SwitchHandler]
    def switch_handler
      return SwitchHandler.new(self, @scene)
    end
    # Get a new switch handler
    # @return [Battle::Logic::EndTurnHandler]
    def end_turn_handler
      return EndTurnHandler.new(self, @scene)
    end
    # Get a new weather change handler
    # @return [Battle::Logic::WeatherChangeHandler]
    def weather_change_handler
      return WeatherChangeHandler.new(self, @scene)
    end
    # Get a new field terrain change handler
    # @return [Battle::Logic::FTerrainChangeHandler]
    def fterrain_change_handler
      return FTerrainChangeHandler.new(self, @scene)
    end
    # Get the flee handler
    # @return [Battle::Logic::FleeHandler]
    def flee_handler
      return FleeHandler.new(self, @scene)
    end
    # Get the catch handler
    # @return [Battle::Logic::CatchHandler]
    def catch_handler
      return CatchHandler.new(self, @scene)
    end
    # Get the ability change handler
    # @return [Battle::Logic::AbilityChangeHandler]
    def ability_change_handler
      return AbilityChangeHandler.new(self, @scene)
    end
    # Get the battle end handler
    # @return [Battle::Logic::BattleEndHandler]
    def battle_end_handler
      return BattleEndHandler.new(self, @scene)
    end
    # Get the exp handler
    # @return [Battle::Logic::ExpHandler]
    def exp_handler
      return ExpHandler.new(self)
    end
    # Get the transform handler
    # @return [Battle::Logic::TransformHandler]
    def transform_handler
      return TransformHandler.new(self, @scene)
    end
    public
    # Get the terrain effects
    # @return [Effects::EffectsHandler]
    attr_reader :terrain_effects
    # Get the bank effects
    # @return [Array<Effects::EffectsHandler>]
    attr_reader :bank_effects
    # Get the position effects
    # @return [Array<Array<Battle::Effects::EffectsHandler>>]
    attr_reader :position_effects
    # Get or set the current field terrain type
    # @return [Symbol]
    attr_accessor :field_terrain
    # Execute a block on each effect depending on what to select as effect
    # @param pokemons [Array<PFM::PokemonBattler>] list of battlers we want to see their effect executed
    # @yieldparam [Effects::EffectBase]
    # @return [Array<Effects::EffectBase>, Symbol, Integer, nil] the first block return that was a symbol
    # @note This returns an enumerator if no block is given
    # @note If the block returns a Symbol, this methods returns this symbol immediately without processing the other effects
    def each_effects(*pokemons)
      return to_enum(__method__, *pokemons) unless block_given?
      yielder = proc do |e|
        r = yield(e)
        return r if r.is_a?(Symbol)
      end
      pokemons = pokemons.compact.uniq
      @terrain_effects.each(&yielder)
      yielder.call(weather_effect)
      yielder.call(field_terrain_effect)
      pokemons.each { |pokemon| pokemon.evaluate_effects(yielder) }
      allies = pokemons.flat_map { |pokemon| @scene.logic.allies_of(pokemon).select { |ally| ally.ability_effect.affect_allies } }.uniq
      allies.reject! { |pokemon| pokemons.include?(pokemon) }
      allies.each { |pokemon| yielder.call(pokemon.ability_effect) }
      pokemons.compact.map(&:bank).uniq.each { |bank| @bank_effects[bank]&.each(&yielder) }
      return nil
    end
    # Add an effect on a position
    # @param effect [Battle::Effects::PositionTiedEffectBase]
    def add_position_effect(effect)
      bank = effect.bank
      position = effect.position
      @position_effects[bank] ||= []
      @position_effects[bank][position] ||= Effects::EffectsHandler.new
      @position_effects[bank][position].add(effect)
    end
    # Add an effect on a bank
    # @param effect [Battle::Effects::PositionTiedEffectBase]
    def add_bank_effect(effect)
      bank = effect.bank
      @bank_effects[bank] ||= Effects::EffectsHandler.new
      @bank_effects[bank].add(effect)
    end
    # Delete all the dead effect by updating counters & removing them
    def delete_dead_effects
      @terrain_effects.update_counter
      @bank_effects.each(&:update_counter)
      @position_effects.each { |bank| bank.each { |position| position&.update_counter } }
      all_alive_battlers.map(&:effects).each(&:update_counter)
    end
    # Get the weather effect
    # @return [Effects::Weather]
    def weather_effect
      if !@weather_effect || @weather_effect.db_symbol != $env.current_weather_db_symbol
        @weather_effect = Battle::Effects::Weather.new(self, $env.current_weather_db_symbol)
      end
      return @weather_effect
    end
    # Get the field terrain effect
    # @return [Effects::FieldTerrain]
    def field_terrain_effect
      if !@field_terrain_effect || @field_terrain_effect.db_symbol != @field_terrain
        @field_terrain_effect = Battle::Effects::FieldTerrain.new(self, @field_terrain)
      end
      return @field_terrain_effect
    end
    private
    def init_effects
      @terrain_effects = Effects::EffectsHandler.new
      @bank_effects = Array.new(@bags.size) {Effects::EffectsHandler.new }
      @position_effects = Array.new(@bags.size) {Array.new(@battle_info.vs_type) {Effects::EffectsHandler.new } }
      @field_terrain = :none
    end
    public
    # Logic for mega evolution
    class MegaEvolve
      # List of tools that allow MEGA Evolution
      MEGA_EVOLVE_TOOLS = %i[mega_ring mega_bracelet mega_pendant mega_glasses mega_anchor mega_stickpin mega_tiara mega_anklet mega_cuff mega_charm mega_glove]
      # Create the MegaEvolve checker
      # @param scene [Battle::Scene]
      def initialize(scene)
        @scene = scene
        @used_mega_tool_bags = []
      end
      # Test if a Pokemon can Mega Evolve
      # @param pokemon [PFM::PokemonBattler] Pokemon that should mega evolve
      # @return [Boolean]
      def can_pokemon_mega_evolve?(pokemon)
        bag = pokemon.bag
        return false unless MEGA_EVOLVE_TOOLS.any? { |item_db_symbol| bag.contain_item?(item_db_symbol) }
        return false if pokemon.from_party? && any_mega_player_action?
        return !@used_mega_tool_bags.include?(bag) && pokemon.can_mega_evolve?
      end
      # Mark a Pokemon as mega evolved
      # @param pokemon [PFM::PokemonBattler]
      def mark_as_mega_evolved(pokemon)
        @used_mega_tool_bags << pokemon.bag
      end
      # Give the name of the mega tool used by the trainer
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def mega_tool_name(pokemon)
        bag = pokemon.bag
        symbol = MEGA_EVOLVE_TOOLS.find { |item_db_symbol| bag.contain_item?(item_db_symbol) }
        return data_item(symbol || 0).name
      end
      private
      # Function that checks if any action of the player is a mega evolve
      # @return [Boolean]
      def any_mega_player_action?
        @scene.player_actions.any? { |actions| actions.is_a?(Array) }
      end
    end
    public
    # Class describing the informations about the battle
    class BattleInfo
      # List of item decupling money
      MONEY_ITEMS = %i[amulet_coin luck_incense]
      # List of base money giving AI levels (if strictly below the value)
      AI_LEVELS_BASE_MONEY = [16, 20, 36, 48, 80, 100, 200, Float::INFINITY]
      # @return [Array<Array<String>>] List of the name of the battlers according to the bank & their position
      attr_accessor :names
      # @return [Array<Array<String>>] List of the classes of the battlers according to the bank & their position
      attr_accessor :classes
      # @return [Array<Array<String>>] List of the battler (image) name of the battlers according to the bank
      attr_accessor :battlers
      # @return [Array<Array<PFM::Bag>>] List of the bags of the battlers according to the bank
      attr_accessor :bags
      # @return [Array<Array<Array<PFM::Pokemon>>>] List of the "Party" of the battlers according to the bank & their position
      attr_accessor :parties
      # @return [Array<Array<Integer>>]
      attr_accessor :ai_levels
      # @return [Array<Array<Integer>>] List of the base money of the battlers according to the bank
      attr_accessor :base_moneys
      # @return [Integer, nil] Maximum level allowed for the battle
      attr_accessor :max_level
      # @return [Integer] Number of Pokemon fighting at the same time
      attr_accessor :vs_type
      # @return [Integer] Reason of the wild battle
      attr_accessor :wild_battle_reason
      # @return [Boolean] if the trainer battle is a "couple" battle
      attr_accessor :trainer_is_couple
      # @return [Integer] ID of the battle (for event loading)
      attr_accessor :battle_id
      # Get the number of time the player tried to flee
      # @return [Integer]
      attr_accessor :flee_attempt_count
      # Tell if the battle follows a fishing attempt
      # @return [Boolean]
      attr_accessor :fishing
      # Get the caught Pokemon
      # @return [PFM::PokemonBattler]
      attr_accessor :caught_pokemon
      # Get the victory BGM
      # @return [String]
      attr_accessor :victory_bgm
      # Get the battle bgm
      # @return [String]
      attr_accessor :battle_bgm
      # Get the additionnal money
      # @return [Integer]
      attr_accessor :additional_money
      # Get the victory text
      # @return [Array<String>]
      attr_accessor :victory_texts
      # Get the defeat text
      # @return [Array<String>]
      attr_accessor :defeat_texts
      # Create a new Battle Info
      # @param hash [Hash] basic info about the battle
      def initialize(hash = {})
        @names = hash[:names] || [[], []]
        @classes = hash[:classes] || [[], []]
        @battlers = hash[:battlers] || [[], []]
        @bags = hash[:bags] || [[], []]
        @parties = hash[:parties] || [[], []]
        @ai_levels = hash[:ai_levels] || [[], []]
        @base_moneys = hash[:base_moneys] || [[], []]
        @max_level = hash[:max_level] || nil
        @vs_type = hash[:vs_type] || 1
        @trainer_is_couple = hash[:couple] || false
        @battle_id = hash[:battle_id] || -1
        @flee_attempt_count = 0
        @fishing = hash[:fishing] || false
        @victory_bgm = hash[:victory_bgm] || guess_victory_bgm
        @battle_bgm = hash[:battle_bgm] || guess_battle_bgm
        @additional_money = 0
        @victory_texts = hash[:victory_texts] || []
        @defeat_texts = hash[:defeat_texts] || []
        @background_name = hash[:background_name] || $game_temp.battleback_name.to_s
      end
      # Tell if the battle allow exp
      # @return [Boolean]
      def disallow_exp?
        return @max_level || $game_switches[Yuki::Sw::BT_NoExp]
      end
      class << self
        # Configure a PSDK battle from old settings
        # @param id_trainer1 [Integer]
        # @param id_trainer2 [Integer]
        # @param id_friend [Integer]
        # @return [Battle::Logic::BattleInfo]
        def from_old_psdk_settings(id_trainer1, id_trainer2 = 0, id_friend = 0)
          battle_info = BattleInfo.new
          battle_info.add_party(0, *battle_info.player_basic_info)
          add_trainer(battle_info, 1, id_trainer1)
          add_trainer(battle_info, 1, id_trainer2) if id_trainer2 != 0
          add_trainer(battle_info, 0, id_friend) if id_friend != 0
          battle_info.vs_type = 2 if battle_info.trainer_is_couple || battle_info.parties.any? { |party| party.size == 2 }
          return battle_info
        end
        # Add a trainer to the battle_info object
        # @param battle_info [BattleInfo]
        # @param bank [Integer] bank of the trainer
        # @param id_trainer [Integer] ID of the trainer in the database
        def add_trainer(battle_info, bank, id_trainer)
          trainer = data_trainer(id_trainer)
          klass = trainer.class_name
          battler = trainer.battler
          name = trainer.name
          party = trainer.party.map(&:to_creature)
          bag = PFM::Bag.new
          trainer.bag_entries.each { |bag_entry| bag.add_item(bag_entry[:dbSymbol], bag_entry[:amount]) }
          battle_info.add_party(bank, party, name, klass, battler, bag, nil, trainer.ai)
          battle_info.base_moneys[bank] << trainer.base_money if bank == 1
          battle_info.trainer_is_couple = battle_info.parties[1].size == 1 if bank == 1 && trainer.vs_type == 2
          battle_info.battle_id = trainer.battle_id if trainer.battle_id != 0
        end
        # Guess the AI level based on the base money (or a variable)
        # @param base_money [Integer]
        # @return [Integer]
        def ai_level(base_money)
          return $game_variables[Yuki::Var::AI_LEVEL] if $game_variables[Yuki::Var::AI_LEVEL] > 0
          return AI_LEVELS_BASE_MONEY.find_index { |base_money_limit| base_money < base_money_limit } || 1
        end
      end
      # Tell if the battle is a trainer battle
      # @return [Boolean]
      def trainer_battle?
        !@names[1].empty?
      end
      # Return the basic info about the player
      # @return [Array]
      def player_basic_info
        battler_name = $game_actors[1].battler_name
        battler_name = $game_player.charset_base if !battler_name || battler_name.empty?
        battler_name = 'dp_back_03' if !battler_name || battler_name.empty?
        return $actors, $trainer.name, data_trainer(0).class_name, battler_name, $bag
      end
      # Add a party to a bank
      # @param bank [Integer] bank where the party should be defined
      # @param party [Array<PFM::Pokemon>] Pokemon of the battler
      # @param name [String, nil] name of the battler (don't set it if Wild Battle)
      # @param klass [String, nil] name of the battler (don't set it if Wild Battle)
      # @param battler [String, nil] name of the battler image (don't set it if Wild Battle)
      # @param bag [String, nil] bag used by the party
      # @param base_money [Integer]
      # @param ai_level [Integer]
      def add_party(bank, party, name = nil, klass = nil, battler = nil, bag = nil, base_money = nil, ai_level = nil, victory_text = nil, defeat_text = nil)
        @parties[bank] ||= []
        @parties[bank] << party
        @names[bank] ||= []
        @names[bank] << name if name
        @classes[bank] ||= []
        @classes[bank] << klass if klass
        @battlers[bank] ||= []
        @battlers[bank] << battler if battler
        @bags[bank] ||= []
        @bags[bank] << (bag || PFM::Bag.new)
        @base_moneys[bank] ||= []
        @base_moneys[bank] << base_money if base_money
        @ai_levels[bank] ||= []
        @ai_levels[bank] << ai_level
        if bank == 1
          @victory_texts << victory_text
          @defeat_texts << defeat_text
        end
      end
      # Get the trainer name of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [String]
      def trainer_name(battler)
        return @names[battler.bank][party_index(battler)]
      end
      # Get the trainer class of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [String]
      def trainer_class(battler)
        return @classes[battler.bank][party_index(battler)]
      end
      # Get the bag of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [PFM::Bag]
      def bag(battler)
        return @bags[battler.bank][party_index(battler)]
      end
      # Get the party of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [Array<PFM::Pokemon>]
      def party(battler)
        return @parties[battler.bank][party_index(battler)] if battler.bank
        @parties.find { |parties| parties.any? { |party| party.include?(battler.original) } }&.find { |party| party.include?(battler.original) }
      end
      # Get the base money of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [Integer]
      def base_money(battler)
        return @base_moneys.dig(battler.bank, party_index(battler)) || 1
      end
      # Get the total money
      # @param logic [Battle::Logic]
      def total_money(logic)
        pokemon = $game_temp.vs_type.times.map { |i| logic.battler(1, i) }.compact
        money = additional_money + pokemon.reduce(0) { |acc, curr| curr.level * base_money(curr) + acc }
        money *= 2 if logic.terrain_effects.has?(:happy_hour)
        money *= 2 if money_item_multiplier?(logic)
        return money
      end
      # Tell if the money item multiplier is active
      # @param logic [Battle::Logic]
      # @return [Boolean]
      def money_item_multiplier?(logic)
        battler_list = logic.all_battlers.select { |b| b&.bank == 0 && MONEY_ITEMS.include?(b&.item_db_symbol) }
        return false if battler_list.empty?
        return battler_list.any? { |battler| logic.all_battlers.any? { |p| p != battler && p.encountered?(battler) } }
      end
      private
      # Function that guess the battle bgm
      # @return [Array, String]
      def guess_battle_bgm
        audio_file = $game_system.battle_bgm || $game_system.playing_bgm
        return 'audio/bgm/rosa_wild_battle' if audio_file.name.empty?
        return ["audio/bgm/#{audio_file.name}", audio_file.volume, audio_file.pitch]
      end
      # Function that guess the victory bgm
      # @return [Array, String]
      def guess_victory_bgm
        audio_file = $game_system.battle_end_me
        filename = "audio/bgm/#{audio_file.name}"
        return 'audio/bgm/xy_trainer_battle_victory' unless File.exist?(filename)
        return [filename, audio_file.volume, audio_file.pitch]
      end
      # Find the party index of a battler
      # @param battler [PFM::PokemonBattler]
      # @return [Integer]
      def party_index(battler)
        return @parties[battler.bank].find_index { |party| party.include?(battler.original) } || 0
      end
      public
      # Name of the background according to their processed zone_type
      BACKGROUND_NAMES = ['back_building', 'back_grass', 'back_tall_grass', 'back_taller_grass', 'back_cave', 'back_mount', 'back_sand', 'back_pond', 'back_sea', 'back_under_water', 'back_ice', 'back_snow']
      # List of of suffix for the timed background. Order is morning, day, sunset, night.
      # @return [Array<Array<String>>]
      TIMED_BACKGROUND_SUFFIXES = [['morning', 'day'], ['day'], ['sunset', 'night'], ['night']]
      # Get the background name
      # @return [String]
      attr_accessor :background_name
      # Get the correct background name to display
      # @param prefix [String, nil] prefix to add to all suggested background
      # @param block [Proc] proc responsive of telling weither the filename param exists and can be used
      # @yieldparam background_name [String]
      # @yieldreturn [Boolean]
      # @return [String] found background name
      def find_background_name_to_display(prefix = nil, &block)
        suggestions = background_name_suggestions(prefix)
        log_debug("Background #{prefix} suggestions: #{suggestions.join(', ')}")
        return suggestions.find(&block) || suggestions.last
      end
      private
      # Get all the possible background name to display
      # @param prefix [String, nil] prefix to add to all suggested background
      # @return [Array<string>]
      def background_name_suggestions(prefix)
        return [*background_name_suggestions_for("#{prefix}#{@background_name}"), *background_name_suggestions_for("#{prefix}#{system_tag_background_name}")].uniq
      end
      # Get the suggestion for a background name
      # @param background_name [String]
      # @return [Array<string>]
      def background_name_suggestions_for(background_name)
        return nil unless background_name
        return nil if background_name.empty?
        timed = timed_background_names(background_name)
        return [*(timed && timed.flat_map { |name| trainer_background_name(name) }), *timed, *trainer_background_name(background_name), background_name]
      end
      # Function that returns the possible background names depending on the time
      # @param background_name [String]
      # @return [Array<String>, nil]
      def timed_background_names(background_name)
        return nil unless $game_switches[Yuki::Sw::TJN_Enabled] && $game_switches[Yuki::Sw::Env_CanFly]
        mapper = proc { |suffix| "#{background_name}_#{suffix}" }
        if $game_switches[Yuki::Sw::TJN_MorningTime]
          return TIMED_BACKGROUND_SUFFIXES[0].map(&mapper)
        else
          if $game_switches[Yuki::Sw::TJN_DayTime]
            return TIMED_BACKGROUND_SUFFIXES[1].map(&mapper)
          else
            if $game_switches[Yuki::Sw::TJN_SunsetTime]
              return TIMED_BACKGROUND_SUFFIXES[2].map(&mapper)
            else
              if $game_switches[Yuki::Sw::TJN_NightTime]
                return TIMED_BACKGROUND_SUFFIXES[3].map(&mapper)
              end
            end
          end
        end
        return nil
      end
      # Function that returns the background name based on the system tag
      # @return [String]
      def system_tag_background_name
        zone_type = $env.get_zone_type
        zone_type += 1 if zone_type > 0 || $env.grass?
        return BACKGROUND_NAMES[zone_type].to_s
      end
      # Function that returns the background name based on the trainer names
      # @param background_name [String]
      # @return [Array<String>]
      def trainer_background_name(background_name)
        return @battlers[1].uniq.map { |suffix| "#{background_name}_#{suffix}" }
      end
    end
    public
    public
    # Class responsive of describing the minimum functionality of change handlers
    class ChangeHandlerBase
      # Get the logic
      # @return [Battle::Logic]
      attr_reader :logic
      # Get the scene
      # @return [Battle::Scene]
      attr_reader :scene
      # Get the list of the pre-checked effects
      # @return [Array<Battle::Effects::EffectBase]
      attr_accessor :pre_checked_effects
      # Create a new ChangeHandler
      # @param logic [Battle::Logic]
      # @param scene [Battle::Scene]
      def initialize(logic, scene)
        @logic = logic
        @scene = scene
        @pre_checked_effects = []
        @reason = nil
      end
      # Process the reason a change could not be done
      def process_prevention_reason
        @reason&.call
      end
      # Reset the reason why change cannot be done
      def reset_prevention_reason
        @reason = nil
      end
      # Function that register a reason why the change is not possible
      # @param reason [Proc] reason that will be registered
      # @return [:prevent] :prevent to make easier the return of hooks
      def prevent_change(&reason)
        @reason = reason
        return :prevent
      end
    end
    public
    # Handler responsive of answering properly statistic changes requests
    class StatChangeHandler < ChangeHandlerBase
      include Hooks
      # Position of text for Attack depending on the power
      TEXT_POS = {atk: atk = [0, 27, 48, 69, 153, 174, 132, 111, 90], dfe: atk.map { |i| i + 3 }, ats: atk.map { |i| i + 6 }, dfs: atk.map { |i| i + 9 }, spd: atk.map { |i| i + 12 }, acc: atk.map { |i| i + 15 }, eva: atk.map { |i| i + 18 }}
      # ID of the animation depending on the stat
      ANIMATION = {atk: 478, dfe: 480, spd: 482, dfs: 486, ats: 484, eva: 488, acc: 490}
      # Index of the stages depending on the stat to change
      # @return [Hash{ Symbol => Integer }]
      STAT_INDEX = {atk: Configs.stats.atk_stage_index, dfe: Configs.stats.dfe_stage_index, ats: Configs.stats.ats_stage_index, dfs: Configs.stats.dfs_stage_index, spd: Configs.stats.spd_stage_index, acc: Configs.stats.acc_stage_index, eva: Configs.stats.eva_stage_index}
      # Array containing all the possible stats
      ALL_STATS = %i[atk dfe spd dfs ats eva acc]
      # Array containing all the attack kind stat
      ATTACK_STATS = %i[atk ats]
      # Array containing all the defense kind stat
      DEFENSE_STATS = %i[dfe dfs]
      # Array containing the physical stats
      PHYSICAL_STATS = %i[atk dfe]
      # Array containing the special stats
      SPECIAL_STATS = %i[ats dfs]
      # Function telling if a stat can be increased
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @note Thing that prevents the stat from increasoing should be defined using :stat_increase_prevention Hook.
      # @return [Boolean]
      def stat_increasable?(stat, target, launcher = nil, skill = nil)
        return false if target.hp <= 0
        reset_prevention_reason
        exec_hooks(StatChangeHandler, :stat_increase_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# stat = #{stat}; target = #{target}; launcher = #{launcher}; skill = #{skill}")
        log_data("\# FR: stat_increasable? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function telling if a stat can be decreased
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @note Thing that prevents the stat from decreasing should be defined using :stat_decrease_prevention Hook.
      # @return [Boolean]
      def stat_decreasable?(stat, target, launcher = nil, skill = nil)
        return false if target.hp <= 0
        reset_prevention_reason
        exec_hooks(StatChangeHandler, :stat_decrease_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# stat = #{stat}; target = #{target}; launcher = #{launcher}; skill = #{skill}")
        log_data("\# FR: stat_decreasable? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that actually change a stat
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param power [Integer] power of the stat change
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param no_message [Boolean] if the message about stat increase should be shown
      def stat_change(stat, power, target, launcher = nil, skill = nil, no_message: false)
        log_data("\# stat_change(#{stat}, #{power}, #{target}, #{launcher}, #{skill})")
        exec_hooks(StatChangeHandler, :stat_change, binding)
        amount = target.change_stat(STAT_INDEX[stat], power)
        show_stat_change_text_and_animation(stat, power, amount, target, no_message)
        exec_hooks(StatChangeHandler, :stat_change_post_event, binding)
      rescue Hooks::ForceReturn => e
        log_data("\# FR: stat_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that test if the change is possible and perform the change if so
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param power [Integer] power of the stat change
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param no_message [Boolean] if the message about stat increase should be shown
      def stat_change_with_process(stat, power, target, launcher = nil, skill = nil, no_message: false)
        if power < 0
          result = stat_decreasable?(stat, target, launcher, skill)
        else
          result = stat_increasable?(stat, target, launcher, skill)
        end
        return process_prevention_reason unless result
        stat_change(stat, power, target, launcher, skill, no_message: no_message)
      end
      # Get the text index in the TEXT_POS array depending on amount & power
      # @param amount [Integer]
      # @param power [Integer]
      # @return [Integer] text pos
      def stat_text_index(amount, power)
        if amount != 0
          return -3 if power < -2
          return (power > 2 ? 3 : power)
        end
        return (power > 0 ? 4 : 5)
      end
      private
      # Compute the right animation offset based on target and power
      # @param target [PFM::PokemonBattler]
      # @param power [Integer]
      # @return [Integer]
      def animation_offset(target, power)
        if power < 0
          return target.bank == 0 ? 1 : 0
        else
          return target.bank == 0 ? 0 : 1
        end
      end
      # Play the animation & display the text depending on the stat
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param power [Integer] expected power of the stat increase
      # @param amount [Integer] actual amount changed
      # @param target [PFM::PokemonBattler]
      # @param no_message [Boolean] if the message about stat increase should be shown
      def show_stat_change_text_and_animation(stat, power, amount, target, no_message)
        return if power.zero? && amount.zero?
        text_index = stat_text_index(amount, power)
        @scene.visual.show_rmxp_animation(target, ANIMATION[stat] + animation_offset(target, power)) if amount != 0
        @scene.display_message_and_wait(parse_text_with_pokemon(19, TEXT_POS[stat][text_index], target)) unless no_message
      end
      class << self
        # Function that registers a stat_increase_prevention hook
        # @param reason [String] reason of the stat_increase_prevention registration
        # @yieldparam handler [StatChangeHandler]
        # @yieldparam stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the stat increase cannot apply
        def register_stat_increase_prevention_hook(reason)
          Hooks.register(StatChangeHandler, :stat_increase_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:stat), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a stat_decrease_prevention hook
        # @param reason [String] reason of the stat_decrease_prevention registration
        # @yieldparam handler [StatChangeHandler]
        # @yieldparam stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the stat decrease cannot apply
        def register_stat_decrease_prevention_hook(reason)
          Hooks.register(StatChangeHandler, :stat_decrease_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:stat), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            force_return(false) if result == :prevent
          end
        end
        # Function that register a stat_change_post_event hook
        # @param reason [String] reason of the stat_change_post_event registration
        # @yieldparam handler [StatChangeHandler]
        # @yieldparam stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @yieldparam power [Integer] power of the stat change
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_stat_change_post_event_hook(reason)
          Hooks.register(StatChangeHandler, :stat_change_post_event, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:stat), hook_binding.local_variable_get(:power), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
        # Function that register a stat_change hook
        # @param reason [String] reason of the stat_change registration
        # @yieldparam handler [StatChangeHandler]
        # @yieldparam stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @yieldparam power [Integer] power of the stat change
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [Integer, nil] if integer, it will change the power
        def register_stat_change_hook(reason)
          Hooks.register(StatChangeHandler, :stat_change, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:stat), hook_binding.local_variable_get(:power), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            hook_binding.local_variable_set(:power, result) if result.is_a?(Integer)
          end
        end
      end
    end
    StatChangeHandler.register_stat_decrease_prevention_hook('PSDK stat decr: self stage') do |handler, stat, target, _, _|
      next if target.battle_stage[StatChangeHandler::STAT_INDEX[stat]] != PFM::PokemonBattler::MIN_STAGE
      next(handler.prevent_change do
        text_index = handler.stat_text_index(0, -1)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, StatChangeHandler::TEXT_POS[stat][text_index], target))
      end)
    end
    StatChangeHandler.register_stat_increase_prevention_hook('PSDK stat incr: self stage') do |handler, stat, target, _, _|
      next if target.battle_stage[StatChangeHandler::STAT_INDEX[stat]] != PFM::PokemonBattler::MAX_STAGE
      next(handler.prevent_change do
        text_index = handler.stat_text_index(0, 1)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, StatChangeHandler::TEXT_POS[stat][text_index], target))
      end)
    end
    StatChangeHandler.register_stat_decrease_prevention_hook('PSDK stat decr: Effects') do |handler, stat, target, launcher, skill|
      next(handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_stat_decrease_prevention(handler, stat, target, launcher, skill))
      end)
    end
    StatChangeHandler.register_stat_increase_prevention_hook('PSDK stat incr: Effects') do |handler, stat, target, launcher, skill|
      next(handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_stat_increase_prevention(handler, stat, target, launcher, skill))
      end)
    end
    StatChangeHandler.register_stat_change_hook('PSDK stat_change: Effects') do |handler, stat, power, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        result = effect.on_stat_change(handler, stat, power, target, launcher, skill)
        power = result if result.is_a?(Integer)
      end
      next(power)
    end
    StatChangeHandler.register_stat_change_post_event_hook('PSDK stat_change_post: Effects') do |handler, stat, power, target, launcher, skill|
      next(handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_stat_change_post(handler, stat, power, target, launcher, skill))
      end)
    end
    public
    # Handler responsive of answering properly item changes requests
    class ItemChangeHandler < ChangeHandlerBase
      include Hooks
      # List of item that cannot be knocked off
      PROTECTED_ITEMS = %i[exp_share lucky_egg amulet_coin oak_s_letter gram_1 gram_2 gram_3 prof_s_letter letter greet_mail favored_mail rsvp_mail thanks_mail inquiry_mail like_mail reply_mail bridge_mail_s bridge_mail_d bridge_mail_t bridge_mail_v bridge_mail_m]
      # TO DO : Add Z-Crystals to PROTECTED_ITEMS (7G)
      # List of items that cannot be knocked off if the holder is a specific Pokemon
      PROTECTED_POKEMON_ITEMS = {giratina: %i[griseous_orb], arceus: %i[flame_plate splash_plate zap_plate meadow_plate icicle_plate fist_plate toxic_plate earth_plate sky_plate mind_plate insect_plate stone_plate spooky_plate draco_plate dread_plate iron_plate pixie_plate], genesect: %i[shock_drive burn_drive chill_drive douse_drive], silvally: %i[bug_memory dark_memory dragon_memory electry_memory fairy_memory fighting_memory fire_memory flying_memory ghost_memory grass_memory ground_memory ice_memory poison_memory psychic_memory rock_memory steel_memory water_memory], kyogre: %i[blue_orb], groudon: %i[red_orb], zacian: %i[rusted_sword], zamazenta: %i[rusted_shield], venusaur: %i[venusaurite], charizard: %i[charizardite_x charizardite_y], blatoise: %i[blastoisinite], alakazam: %i[alakazite], gengar: %i[gengarite], kangaskhan: %i[kangaskhanite], pinsir: %i[pinsirite], gyarados: %i[gyaradosite], aerodactyl: %i[aerodactylite], mewtwo: %i[mewtwonite_x mewtwonite_y], ampharos: %i[ampharosite], scizor: %i[scizorite], heracross: %i[heracronite], houndoom: %i[houndoominite], tyranitar: %i[tyranitarite], blaziken: %i[blazikenite], gardevoir: %i[gardevoirite], mawile: %i[mawilite], aggron: %i[aggronite], medicham: %i[medichamite], manectric: %i[manectite], banette: %i[banettite], absol: %i[absolite], latias: %i[latiasite], latios: %i[latiosite], garchomp: %i[garchompite], lucario: %i[lucarionite], abomasnow: %i[abomasite], beedril: %i[beedrillite], pidgeot: %i[pidgeotite], slowbro: %i[slowbronite], steelix: %i[steelixite], sceptile: %i[sceptilite], swamper: %i[swampertite], sableye: %i[sablenite], sharpedo: %i[sharpedoite], camerupt: %i[cameruptite], altaria: %i[altarianite], glalie: %i[glalitite], salamence: %i[salamencite], metagross: %i[metagrossite], lopunny: %i[lopunnite]}
      # Function that change the item held by a Pokemon
      # @param db_symbol [Symbol, :none] Symbol ID of the item
      # @param overwrite [Boolean] if the actual item held should be overwritten
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [Boolean] if the operation was successful
      def change_item(db_symbol, overwrite, target, launcher = nil, skill = nil)
        log_data("\# change_item(#{db_symbol}, #{overwrite}, #{target}, #{launcher}, #{skill})")
        exec_hooks(ItemChangeHandler, :pre_item_change, binding)
        target.battle_item = db_symbol == :none ? 0 : data_item(db_symbol).id
        target.item_holding = target.battle_item if overwrite
        exec_hooks(ItemChangeHandler, :post_item_change, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# FR: change_item #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that checks if the Pokemon can lose its item
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @return [Boolean]
      def can_lose_item?(target, launcher = nil)
        return false unless target.hold_item?(target.item_db_symbol)
        return false if %i[none __undef__].include?(target.battle_item_db_symbol) || PROTECTED_ITEMS.include?(target.item_db_symbol)
        return false if target.dead?
        return false if launcher&.can_be_lowered_or_canceled?(target.has_ability?(:sticky_hold))
        return false if PROTECTED_POKEMON_ITEMS[target.db_symbol]&.include?(target.battle_item_db_symbol)
        return false if target.effects.has?(:substitute) && target != launcher
        return true
      end
      # Function that checks if the Pokemon can give its item to a target
      # @param giver [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @return [Boolean]
      def can_give_item?(giver, target, launcher = giver)
        return false unless can_lose_item?(giver, launcher)
        return false if target.hold_item?(target.battle_item_db_symbol)
        return false unless target.battle_item_db_symbol == :__undef__
        return false if PROTECTED_POKEMON_ITEMS.keys.include?(target.db_symbol)
        return true
      end
      class << self
        # Function that registers a pre_item_change hook
        # @param reason [String] reason of the pre_item_change registration
        # @yieldparam handler [ItemChangeHandler]
        # @yieldparam db_symbol [Symbol] Symbol ID of the item
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the item change cannot be applied
        def register_pre_item_change_hook(reason)
          Hooks.register(ItemChangeHandler, :pre_item_change, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:db_symbol), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a post_item_change hook
        # @param reason [String] reason of the post_item_change registration
        # @yieldparam handler [ItemChangeHandler]
        # @yieldparam db_symbol [Symbol] Symbol ID of the item
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_post_item_change_hook(reason)
          Hooks.register(ItemChangeHandler, :post_item_change, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:db_symbol), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
      end
    end
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Consumed item') do |_, db_symbol, target|
      next if target.item_consumed || target.effects.has?(:item_stolen)
      next unless db_symbol == :none
      target.item_consumed = true
      target.consumed_item = target.battle_item_db_symbol
    end
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Retrieve item') do |_, db_symbol, target|
      next if db_symbol == :none || data_item(db_symbol).db_symbol == :__undef__
      target.item_consumed = false
      target.consumed_item = nil
    end
    ItemChangeHandler.register_post_item_change_hook('PSDK item change post: Effects') do |handler, db_symbol, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_post_item_change(handler, db_symbol, target, launcher, skill))
      end
    end
    ItemChangeHandler.register_pre_item_change_hook('PSDK item change pre: Effects') do |handler, db_symbol, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_pre_item_change(handler, db_symbol, target, launcher, skill))
      end
    end
    public
    # Handler responsive of answering properly status changes requests
    class StatusChangeHandler < ChangeHandlerBase
      include Hooks
      # List of method to call in order to apply the status on the Pokemon
      STATUS_APPLY_METHODS = {poison: :status_poison, toxic: :status_toxic, confusion: :status_confuse, sleep: :status_sleep, freeze: :status_frozen, paralysis: :status_paralyze, burn: :status_burn, cure: :cure, flinch: :apply_flinch}
      # List of message ID when applying a status
      STATUS_APPLY_MESSAGE = {poison: 234, toxic: 237, confusion: 345, sleep: 306, freeze: 288, paralysis: 273, burn: 255}
      # List of animation ID when applying a status
      STATUS_APPLY_ANIMATION = {poison: 470, toxic: 477, confusion: 475, sleep: 473, freeze: 474, paralysis: 471, burn: 472, flinch: 476}
      # Function telling if a status can be applyied
      # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @note Thing that prevents the status from being applyied should be defined using :status_prevention Hook.
      # @return [Boolean]
      def status_appliable?(status, target, launcher = nil, skill = nil)
        return false if target.hp <= 0
        reset_prevention_reason
        exec_hooks(StatusChangeHandler, :status_prevention, binding) if status != :cure
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# status = #{status}; target = #{target}; launcher = #{launcher}; skill = #{skill}")
        log_data("\# FR: status_appliable? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that actually change the status
      # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure, :confuse_cure
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param message_overwrite [Integer] Index of the message to use if file 19 to apply the status (if there's specific reason)
      def status_change(status, target, launcher = nil, skill = nil, message_overwrite: nil)
        log_data("\# status_change(#{status}, #{target}, #{launcher}, #{skill})")
        case status
        when :cure
          message_overwrite ||= cure_message_id(target)
          target.send(STATUS_APPLY_METHODS[status])
        when :confuse_cure
          target.effects.get(:confusion)&.kill
          target.effects.delete_specific_dead_effect(:confusion)
          message_overwrite = 351
        else
          message_overwrite ||= STATUS_APPLY_MESSAGE[status]
          target.send(STATUS_APPLY_METHODS[status], true)
          @scene.visual.show_rmxp_animation(target, STATUS_APPLY_ANIMATION[status])
        end
        @scene.display_message_and_wait(parse_text_with_pokemon(19, message_overwrite, target)) if message_overwrite
        exec_hooks(StatusChangeHandler, :post_status_change, binding)
      rescue Hooks::ForceReturn => e
        log_data("\# FR: status_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      ensure
        @scene.visual.refresh_info_bar(target)
      end
      # Function that test if the change is possible and perform the change if so
      # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def status_change_with_process(status, target, launcher = nil, skill = nil, message_overwrite: nil)
        return process_prevention_reason unless status_appliable?(status, target, launcher, skill)
        status_change(status, target, launcher, skill, message_overwrite: message_overwrite)
      end
      private
      # Get the message ID for the curing message
      # @param target [PFM::PokemonBattler]
      # @return [Integer]
      def cure_message_id(target)
        if target.poisoned? || target.toxic?
          return 246
        else
          if target.burn?
            return 264
          else
            if target.frozen?
              return 294
            else
              if target.paralyzed?
                return 279
              else
                return 312
              end
            end
          end
        end
      end
      class << self
        # Function that registers a status_prevention hook
        # @param reason [String] reason of the status_prevention registration
        # @yieldparam handler [StatusChangeHandler]
        # @yieldparam status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the status cannot be applied
        def register_status_prevention_hook(reason)
          Hooks.register(StatusChangeHandler, :status_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:status), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a post_status_change hook
        # @param reason [String] reason of the post_status_change registration
        # @yieldparam handler [StatusChangeHandler]
        # @yieldparam status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_post_status_change_hook(reason)
          Hooks.register(StatusChangeHandler, :post_status_change, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:status), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
      end
    end
    StatusChangeHandler.register_post_status_change_hook('PSDK post status: Effects') do |handler, status, target, launcher, skill|
      handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_post_status_change(handler, status, target, launcher, skill))
      end
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: Effects') do |handler, status, target, launcher, skill|
      next(handler.logic.each_effects(target, launcher) do |effect|
        next(effect.on_status_prevention(handler, status, target, launcher, skill))
      end)
    end
    StatusChangeHandler.register_post_status_change_hook('Shaymin form') do |handler, _, target, _, _|
      next unless target.db_symbol == :shaymin && target.frozen?
      next unless target.form_calibrate(:none)
      handler.scene.visual.battler_sprite(target.bank, target.position).pokemon = target
      handler.scene.display_message_and_wait(parse_text(22, 157, ::PFM::Text::PKNAME[0] => target.given_name))
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: confused') do |handler, status, target|
      next if status != :confusion || !target.confused?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 354, target))
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: can_be_asleep') do |handler, status, target, _, skill|
      next if status != :sleep || target.can_be_asleep? || skill&.db_symbol == :rest
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 318, target))
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: can_be_frozen') do |handler, status, target, _, skill|
      next if status != :freeze || target.can_be_frozen?(skill&.type || 0)
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 300, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: can_be_poisoned') do |handler, status, target, launcher, skill|
      next unless %i[poison toxic].include?(status)
      next if launcher&.has_ability?(:corrosion)
      next if target.can_be_poisoned?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 252, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: can_be_paralyzed') do |handler, status, target, _, skill|
      next if status != :paralysis || target.can_be_paralyzed?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 285, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: can_be_burn') do |handler, status, target, _, skill|
      next if status != :burn || target.can_be_burn?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 270, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: Ground type immune to thunder-wave') do |handler, status, target, launcher, skill|
      next unless status == :paralysis
      next unless skill&.db_symbol == :thunder_wave && !launcher&.has_ability?(:normalize)
      next unless target.type_ground?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 285, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: Grass types immune to powder moves') do |handler, _, target, _, skill|
      next if !skill&.powder? || !target.type_grass?
      next(handler.prevent_change do
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 216, target)) if skill.nil? || skill.status?
      end)
    end
    StatusChangeHandler.register_status_prevention_hook('PSDK status prev: Pokemon that doesn\'t attack can\'t be flinched') do |handler, status, target, launcher, skill|
      next unless status == :flinch
      next unless handler.scene.logic.battler_attacks_after?(launcher, target)
      next(handler.prevent_change)
    end
    public
    # Handler responsive of defining how damage should be dealt (if possible)
    class DamageHandler < ChangeHandlerBase
      include Hooks
      # Function telling if a damage can be applied and how much
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @note Thing that prevents the damage from being applied should be defined using :damage_prevention Hook.
      # @return [Integer, false]
      def damage_appliable(hp, target, launcher = nil, skill = nil)
        log_data("\# damage_appliable(#{hp}, #{target}, #{launcher}, #{skill})")
        return false if target.hp <= 0
        reset_prevention_reason
        exec_hooks(DamageHandler, :damage_prevention, binding)
        return hp
      rescue Hooks::ForceReturn => e
        log_data("\# FR: damage_appliable #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that actually deal the damage
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param messages [Proc] messages shown right before the post processing
      def damage_change(hp, target, launcher = nil, skill = nil, &messages)
        skill&.damage_dealt += hp
        @scene.visual.show_hp_animations([target], [-hp], [skill&.effectiveness], &messages)
        target.last_hit_by_move = skill if skill
        exec_hooks(DamageHandler, :post_damage, binding) if target.hp > 0
        if target.hp <= 0
          exec_hooks(DamageHandler, :post_damage_death, binding)
          target.ko_count += 1
        end
        target.add_damage_to_history(hp, launcher, skill, target.hp <= 0)
        log_data("\# damage_change(#{hp}, #{target}, #{launcher}, #{skill}, #{target.hp <= 0})")
      rescue Hooks::ForceReturn => e
        log_data("\# FR: damage_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      ensure
        @scene.visual.refresh_info_bar(target)
      end
      # Function that test if the damage can be dealt and deal the damage if so
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param messages [Proc] messages shown right before the post processing
      def damage_change_with_process(hp, target, launcher = nil, skill = nil, &messages)
        return process_prevention_reason unless (hp = damage_appliable(hp, target, launcher, skill))
        process_prevention_reason
        damage_change(hp, target, launcher, skill, &messages)
      end
      # Function that proceed the heal of a Pokemon
      # @param target [PFM::PokemonBattler]
      # @param hp [Integer] number of HP to heal
      # @param test_heal_block [Boolean]
      # @param animation_id [Symbol, Integer] animation to use instead of the original one
      # @yieldparam hp [Integer] the actual hp healed
      # @return [Boolean] if the heal was successful or not
      # @note this method yields a block in order to show the message after the animation
      # @note this shows the default message if no block has been given
      def heal(target, hp, test_heal_block: true, animation_id: nil)
        if test_heal_block && target.effects.has?(:heal_block)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 890, target))
          return false
        end
        if target.hp >= target.max_hp
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 896, target))
          return false
        end
        actual_hp = hp.clamp(1, target.max_hp - target.hp)
        target.position == -1 ? target.hp += actual_hp : scene.visual.show_hp_animations([target], [actual_hp])
        if block_given?
          yield(actual_hp)
        else
          scene.display_message_and_wait(parse_text_with_pokemon(19, 387, target))
        end
        return true
      end
      # Function that drains a certain quantity of HP from the target and give it to the user
      # @param hp_factor [Integer] the division factor of HP to drain
      # @param target [PFM::PokemonBattler] target that get HP drained
      # @param launcher [PFM::PokemonBattler] launcher of a draining move/effect
      # @param skill [Battle::Move, nil] Potential move used
      # @param hp_overwrite [Integer, nil] for the number of hp drained by the move
      # @param drain_factor [Integer] the division factor of HP drained
      # @param messages [Proc] messages shown right before the post processing
      def drain(hp_factor, target, launcher, skill = nil, hp_overwrite: nil, drain_factor: 1, &messages)
        hp = hp_overwrite || (target.max_hp / hp_factor).clamp(1, Float::INFINITY)
        skill&.damage_dealt += hp
        @scene.visual.show_hp_animations([target], [-hp], [skill&.effectiveness], &messages)
        target.last_hit_by_move = skill if skill
        if target.has_ability?(:liquid_ooze)
          @scene.visual.show_ability(target)
          damage_change(hp, launcher, launcher, nil)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 457, launcher))
        else
          if launcher.effects.has?(:heal_block)
            @scene.display_message_and_wait(parse_text_with_pokemon(19, 890, launcher))
          else
            if launcher.alive? && launcher.hp < launcher.max_hp
              hp = hp * 130 / 100 if launcher.hold_item?(:big_root)
              hp = hp * 3 / 2 if skill&.pulse? && launcher.has_ability?(:mega_launcher)
              @scene.visual.show_hp_animations([launcher], [(hp / drain_factor).to_i.clamp(1, Float::INFINITY)])
              @scene.display_message_and_wait(parse_text_with_pokemon(19, 905, target))
            end
          end
        end
        exec_hooks(DamageHandler, :post_damage, binding) if target.hp > 0
        if target.hp <= 0
          exec_hooks(DamageHandler, :post_damage_death, binding)
          target.ko_count += 1
        end
        target.add_damage_to_history(hp, launcher, skill, target.hp <= 0)
        log_data("\# drain damage_change(#{hp}, #{target}, #{launcher}, #{skill}, #{target.hp <= 0})")
      rescue Hooks::ForceReturn => e
        log_data("\# FR: drain damage_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      ensure
        @scene.visual.refresh_info_bar(target)
      end
      # Function that test if the drain damages can be dealt and perform the drain if so
      # @param hp_factor [Integer] the division factor of HP to drain
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @param hp_overwrite [Integer, nil] for the number of hp drained by the move
      # @param drain_factor [Integer] the division factor of HP drained
      # @param messages [Proc] messages shown right before the post processing
      def drain_with_process(hp_factor, target, launcher, skill = nil, hp_overwrite: nil, drain_factor: 1, &messages)
        hp = hp_overwrite || (target.max_hp / hp_factor).clamp(0, Float::INFINITY)
        return process_prevention_reason unless (hp = damage_appliable(hp, target, launcher, skill))
        drain(hp_factor, target, launcher, skill, hp_overwrite: hp, drain_factor: drain_factor, &messages)
      end
      class << self
        # Function that registers a damage_prevention hook
        # @param reason [String] reason of the damage_prevention registration
        # @yieldparam handler [DamageHandler]
        # @yieldparam hp [Integer] number of hp (damage) dealt
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, Integer] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def register_damage_prevention_hook(reason)
          Hooks.register(DamageHandler, :damage_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:hp), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            hook_binding.local_variable_set(:hp, result) if result.is_a?(Integer)
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a post_damage hook (when target is still alive)
        # @param reason [String] reason of the post_damage registration
        # @yieldparam handler [DamageHandler]
        # @yieldparam hp [Integer] number of hp (damage) dealt
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_post_damage_hook(reason)
          Hooks.register(DamageHandler, :post_damage, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:hp), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
        # Function that registers a post_damage_death hook (when target is KO)
        # @param reason [String] reason of the post_damage_death registration
        # @yieldparam handler [DamageHandler]
        # @yieldparam hp [Integer] number of hp (damage) dealt
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        def register_post_damage_death_hook(reason)
          Hooks.register(DamageHandler, :post_damage_death, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:hp), hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
      end
    end
    DamageHandler.register_post_damage_hook('PSDK post damage: Mummy') do |handler, hp, target, launcher, skill|
      next unless target.ability_effect.is_a?(Effects::Ability::Mummy)
      target.ability_effect.on_post_damage(handler, hp, target, launcher, skill)
    end
    DamageHandler.register_post_damage_death_hook('PSDK post damage death: Mummy') do |handler, hp, target, launcher, skill|
      next unless target.ability_effect.is_a?(Effects::Ability::Mummy)
      target.ability_effect.on_post_damage_death(handler, hp, target, launcher, skill)
    end
    DamageHandler.register_damage_prevention_hook('PSDK damage prev: Effects') do |handler, hp, target, launcher, skill|
      next(handler.logic.each_effects(launcher, target) do |e|
        result = e.on_damage_prevention(handler, hp, target, launcher, skill)
        hp = result if result.is_a?(Integer)
        next(result)
      end || hp)
    end
    DamageHandler.register_post_damage_hook('PSDK post damage: Effects') do |handler, hp, target, launcher, skill|
      handler.logic.each_effects(launcher, target) do |e|
        e.on_post_damage(handler, hp, target, launcher, skill)
      end
    end
    DamageHandler.register_post_damage_death_hook('PSDK post damage death: Effects') do |handler, hp, target, launcher, skill|
      handler.logic.each_effects(launcher, target) do |e|
        e.on_post_damage_death(handler, hp, target, launcher, skill)
      end
    end
    DamageHandler.register_post_damage_death_hook('PSDK post damage death: Loyalty update') do |_, _, target, launcher, _|
      next(target.loyalty -= 1) unless launcher
      high_level_opponent = launcher.level - target.level >= 30
      low_loyalty = target.loyalty < 200
      if high_level_opponent
        target.loyalty -= low_loyalty ? 5 : 10
      else
        target.loyalty -= 1
      end
    end
    DamageHandler.register_post_damage_hook('PSDK Post damage: Illusion') do |handler, _, target, launcher, skill|
      next unless skill && launcher != target
      next unless target.original.ability_db_symbol == :illusion && target.illusion
      target.illusion = nil
      handler.scene.visual.show_ability(target)
      handler.scene.visual.show_switch_form_animation(target)
      handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 478, target))
    end
    DamageHandler.register_post_damage_death_hook('PSDK Post damage: Illusion') do |_, _, target, launcher, skill|
      next unless skill && launcher != target
      next unless target.original.ability_db_symbol == :illusion && target.illusion
      target.illusion = nil
    end
    public
    # Handler responsive of processing switch events that happens during switch
    class SwitchHandler < ChangeHandlerBase
      include Hooks
      # Test if the switch is possible
      # @param pokemon [PFM::PokemonBattler] pokemon to switch
      # @param skill [Battle::Move, nil] potential move
      # @param reason [Symbol] the reason why the SwitchHandler is called (:switch or :flee)
      # @return [Boolean] if it can switch or not
      def can_switch?(pokemon, skill = nil, reason: :switch)
        log_data("\# can_switch?(#{pokemon}, #{skill})")
        return false if pokemon.hp <= 0
        reset_prevention_reason
        exec_hooks(SwitchHandler, :switch_passthrough, binding)
        exec_hooks(SwitchHandler, :switch_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# FR: can_switch? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Execute the events before the pokemon switch out
      # @param who [PFM::PokemonBattler] Pokemon who is switched out
      # @param with [PFM::PokemonBattler, nil] Pokemon who is switched in
      # @note In the event we're starting the battle who & with should be identic, this help to process effect like Intimidate
      def execute_pre_switch_events(who, with)
        exec_hooks(SwitchHandler, :pre_switch_event, binding)
      end
      # Perform the switch between two Pokemon
      # @param who [PFM::PokemonBattler] Pokemon who is switched out
      # @param with [PFM::PokemonBattler, nil] Pokemon who is switched in
      # @note In the event we're starting the battle who & with should be identic, this help to process effect like Intimidate
      def execute_switch_events(who, with)
        if with != who
          with.turn_count = 0
        end
        exec_hooks(SwitchHandler, :switch_event, binding)
      end
      class << self
        # Register a switch passthrough. If the block returns :passthrough, it will say that Pokemon can switch in can_switch?
        # @param reason [String] reason of the switch_passthrough hook
        # @yieldparam handler [SwitchHandler]
        # @yieldparam pokemon [PFM::PokemonBattler]
        # @yieldparam skill [Battle::Move, nil] potential skill used to switch
        # @yieldparam reason [Symbol] the reason why the SwitchHandler is called
        # @yieldreturn [:passthrough, nil] if :passthrough, can_switch? will return true without checking switch_prevention
        def register_switch_passthrough_hook(reason)
          Hooks.register(SwitchHandler, :switch_passthrough, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:pokemon), hook_binding.local_variable_get(:skill), hook_binding.local_variable_get(:reason))
            force_return(true) if result == :passthrough
          end
        end
        # Register a switch prevention hook. If the block returns :prevent, it will say that Pokemon cannot switch in can_switch?
        # @param reason [String] reason of the switch_prevention hook
        # @yieldparam handler [SwitchHandler]
        # @yieldparam pokemon [PFM::PokemonBattler]
        # @yieldparam skill [Battle::Move, nil] potential skill used to switch
        # @yieldparam reason [Symbol] the reason why the SwitchHandler is called
        # @yieldreturn [:prevent, nil] if :prevent, can_switch? will return false
        def register_switch_prevention_hook(reason)
          Hooks.register(SwitchHandler, :switch_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:pokemon), hook_binding.local_variable_get(:skill), hook_binding.local_variable_get(:reason))
            force_return(false) if result == :prevent
          end
        end
        # Register a pre switch event
        # @param reason [String] reason of the pre_switch_event hook
        # @yieldparam handler [SwitchHandler]
        # @yieldparam who [PFM::PokemonBattler] Pokemon that is switched out
        # @yieldparam with [PFM::PokemonBattler] Pokemon that is switched in
        def register_pre_switch_event_hook(reason)
          Hooks.register(SwitchHandler, :pre_switch_event, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:who), hook_binding.local_variable_get(:with))
          end
        end
        # Register a switch event
        # @param reason [String] reason of the switch_event hook
        # @yieldparam handler [SwitchHandler]
        # @yieldparam who [PFM::PokemonBattler] Pokemon that is switched out
        # @yieldparam with [PFM::PokemonBattler] Pokemon that is switched in
        def register_switch_event_hook(reason)
          Hooks.register(SwitchHandler, :switch_event, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:who), hook_binding.local_variable_get(:with))
          end
        end
      end
    end
    SwitchHandler.register_switch_event_hook('Update last_sent_turn value') do |_, _, with|
      with.last_sent_turn = $game_temp.battle_turn
    end
    SwitchHandler.register_switch_passthrough_hook('PSDK switch pass: Effects') do |handler, pokemon, skill, reason|
      next(handler.logic.each_effects(pokemon) do |e|
        next(e.on_switch_passthrough(handler, pokemon, skill, reason))
      end)
    end
    SwitchHandler.register_switch_prevention_hook('PSDK switch prev: Effects') do |handler, pokemon, skill, reason|
      next(handler.logic.each_effects(*handler.logic.all_alive_battlers) do |e|
        next(e.on_switch_prevention(handler, pokemon, skill, reason))
      end)
    end
    SwitchHandler.register_switch_event_hook('PSDK switch: Neutralizing Gas Effect') do |handler, who, with|
      if who != with && who.has_ability?(:neutralizing_gas) && who.ability_effect.activated?
        who.ability_effect.on_switch_event(handler, who, with)
        handler.pre_checked_effects << who.ability_effect
      end
      battlers = handler.logic.all_alive_battlers.find_all { |battler| battler.has_ability?(:neutralizing_gas) }
      next if battlers.empty?
      battlers.each { |battler| handler.pre_checked_effects << battler.ability_effect }
      next if battlers.any? { |battler| battler.ability_effect.activated? }
      battler = battlers.sort_by(&:spd).reverse.first
      battler.ability_effect.on_switch_event(handler, battler, battler)
    end
    SwitchHandler.register_switch_event_hook('PSDK switch: Tablets of Ruin Effect') do |handler, who, with|
      if who != with && %i[tablets_of_ruin beads_of_ruin vessel_of_ruin sword_of_ruin].include?(who.battle_ability_db_symbol) && who.ability_effect.activated?
        who.ability_effect.on_switch_event(handler, who, with)
        handler.pre_checked_effects << who.ability_effect
      end
      owner_ability = with.battle_ability_db_symbol
      next unless %i[tablets_of_ruin beads_of_ruin vessel_of_ruin sword_of_ruin].include?(owner_ability)
      battlers = handler.logic.all_alive_battlers.select { |battler| battler.has_ability?(owner_ability) }
      next if battlers.empty?
      battlers.each { |battler| handler.pre_checked_effects << battler.ability_effect }
      next if battlers.any? { |battler| battler.ability_effect.activated? }
      battler = battlers.sort_by(&:spd).reverse.first
      battler.ability_effect.on_switch_event(handler, battler, battler)
    end
    SwitchHandler.register_switch_event_hook('PSDK switch: Effects') do |handler, who, with|
      next(handler.logic.each_effects(*[who, with].uniq) do |e|
        next if handler.pre_checked_effects.include?(e)
        next(e.on_switch_event(handler, who, with))
      end)
    end
    SwitchHandler.register_switch_prevention_hook('PSDK switch prevent: U-Turn moves') do |handler, pokemon, skill|
      party = handler.logic.all_battlers.select { |p| p.bank == pokemon.bank && p.party_id == pokemon.party_id }
      next(:prevent) if (party - [pokemon] - handler.logic.allies_of(pokemon)).count(&:alive?) == 0 && skill&.self_user_switch?
    end
    SwitchHandler.register_switch_passthrough_hook('PSDK switch pass: U-Turn moves') do |handler, pokemon, skill|
      party = handler.logic.all_battlers.select { |p| p.bank == pokemon.bank && p.party_id == pokemon.party_id }
      alive_pokemon = (party - [pokemon] - handler.logic.allies_of(pokemon)).count(&:alive?)
      next(:passthrough) if skill&.self_user_switch? && alive_pokemon > 0
    end
    SwitchHandler.register_switch_event_hook('Update encounter list') do |handler, _, with|
      handler.logic.all_battlers do |battler|
        next if battler.position == -1 || battler.dead? || battler == with
        battler.add_battler_to_encounter_list(with)
        with.add_battler_to_encounter_list(battler)
      end
    end
    SwitchHandler.register_pre_switch_event_hook('Update Pokemon appearance with Illusion Ability : entering battle') do |handler, who, with|
      next unless with.ability_db_symbol == :illusion
      handler.logic.transform_handler.initialize_transform_attempt(with)
    end
    SwitchHandler.register_switch_event_hook('Update Pokemon appearance with Illusion Ability : leaving battle') do |handler, who, with|
      next unless who.original.ability_db_symbol == :illusion && who.illusion
      next if who == with
      who.illusion = nil
    end
    SwitchHandler.register_switch_event_hook('Meloetta form') do |_, who, _|
      who.form_calibrate(:none) if who.db_symbol == :meloetta
    end
    public
    # Handler responsive of calling all the end turn events
    class EndTurnHandler
      include Hooks
      # Create a new end turn handler
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene]
      def initialize(logic, scene)
        @logic = logic
        @scene = scene
      end
      # Function that call all the events (end_turn_event)
      def process_events
        @alive_battlers = @logic.all_alive_battlers.dup
        exec_hooks(EndTurnHandler, :end_turn_event, binding)
        @logic.delete_dead_effects
      end
      class << self
        # Register a end turn event
        # @param reason [String] reason of the event
        # @yieldparam logic [Battle::Logic] logic of the battle
        # @yieldparam scene [Battle::Scene] battle scene
        # @yieldparam battlers [Array<PFM::PokemonBattler>] all alive battlers
        def register_end_turn_event(reason)
          Hooks.register(EndTurnHandler, :end_turn_event, reason) do
            @alive_battlers.reject!(&:dead?)
            yield(@logic, @scene, @alive_battlers)
          end
        end
      end
    end
    EndTurnHandler.register_end_turn_event('PSDK end turn: Effects') do |logic, scene, battlers|
      logic.each_effects(*battlers) do |e|
        e.on_end_turn_event(logic, scene, battlers)
      end
    end
    EndTurnHandler.register_end_turn_event('PSDK end turn: Unmega evolve KO\'d Mega Pokemon') do |logic, _, _|
      logic.all_battlers do |battler|
        next unless battler.dead? && battler.mega_evolved?
        battler.unmega_evolve
      end
    end
    public
    # Handler responsive of answering properly weather changes requests
    class WeatherChangeHandler < ChangeHandlerBase
      include Hooks
      # Mapping between weather symbol & message_id
      WEATHER_SYM_TO_MSG = {none: 97, rain: 88, sunny: 87, sandstorm: 89, hail: 90, fog: 91, hardsun: 271, hardrain: 269, strong_winds: 273}
      # Create a new Weather Change Handler
      # @param logic [Battle::Logic]
      # @param scene [Battle::Scene]
      # @param env [PFM::Environnement]
      def initialize(logic, scene, env = $env)
        super(logic, scene)
        @env = env
      end
      # Function telling if a weather can be applyied
      # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
      # @return [Boolean]
      def weather_appliable?(weather_type)
        log_data("\# weather_appliable?(#{weather_type})")
        reset_prevention_reason
        last_weather = @env.current_weather_db_symbol
        exec_hooks(WeatherChangeHandler, :weather_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# FR: weather_appliable? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that actually change the weather
      # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
      # @param nb_turn [Integer, nil] Number of turn, use nil for Infinity
      def weather_change(weather_type, nb_turn)
        log_data("\# weather_change(#{weather_type}, #{nb_turn})")
        last_weather = @env.current_weather_db_symbol
        @env.apply_weather(weather_type, nb_turn)
        show_weather_message(last_weather, weather_type)
        exec_hooks(WeatherChangeHandler, :on_post_weather_change, binding)
      rescue Hooks::ForceReturn => e
        log_data("\# FR: weather_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that test if the change is possible and perform the change if so
      # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
      # @param nb_turn [Integer, nil] Number of turn, use nil for Infinity
      def weather_change_with_process(weather_type, nb_turn)
        return process_prevention_reason unless weather_appliable?(weather_type)
        weather_change(weather_type, nb_turn)
      end
      private
      # Show the weather message
      # @param last_weather [Symbol]
      # @param current_weather [Symbol]
      def show_weather_message(last_weather, current_weather)
        return if last_weather == current_weather
        @scene.display_message_and_wait(parse_text(18, WEATHER_SYM_TO_MSG[current_weather]))
      end
      class << self
        # Function that registers a weather_prevention hook
        # @param reason [String] reason of the weather_prevention registration
        # @yieldparam handler [WeatherChangeHandler]
        # @yieldparam weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @yieldparam last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @yieldreturn [:prevent, nil] :prevent if the status cannot be applied
        def register_weather_prevention_hook(reason)
          Hooks.register(WeatherChangeHandler, :weather_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:weather_type), hook_binding.local_variable_get(:last_weather))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a on_post_weather_change hook
        # @param reason [String] reason of the on_post_weather_change registration
        # @yieldparam handler [WeatherChangeHandler]
        # @yieldparam weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @yieldparam last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        def register_post_weather_change_hook(reason)
          Hooks.register(WeatherChangeHandler, :on_post_weather_change, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:weather_type), hook_binding.local_variable_get(:last_weather))
          end
        end
      end
    end
    WeatherChangeHandler.register_weather_prevention_hook('PSDK prev weather: Effects') do |handler, weather_type, last_weather|
      next(handler.logic.each_effects(*handler.logic.all_alive_battlers) do |e|
        next(e.on_weather_prevention(handler, weather_type, last_weather))
      end)
    end
    WeatherChangeHandler.register_post_weather_change_hook('PSDK post weather: Effects') do |handler, weather_type, last_weather|
      next(handler.logic.each_effects(*handler.logic.all_alive_battlers) do |e|
        next(e.on_post_weather_change(handler, weather_type, last_weather))
      end)
    end
    WeatherChangeHandler.register_weather_prevention_hook('PSDK prev weather: Duplicate weather') do |_, weather, prev|
      next if weather != prev
      next(:prevent)
    end
    public
    # Handler responsive of processing flee attempt
    class FleeHandler < ChangeHandlerBase
      include Hooks
      # Try to flee
      # @param index [Integer] index of the Pokemon on the trainer bank
      # @note flee_block hooks are called to test if the flee is blocked for other reason than switch blocked
      # @return [Symbol] if success :success, if failure :failure, if blocked (trainer battle) :blocked
      def attempt(index)
        log_data("\# flee\#attempt(#{index})")
        exec_hooks(FleeHandler, :flee_block, binding)
        exec_hooks(FleeHandler, :flee_passthrough, binding)
        switch_handler = @logic.switch_handler
        unless switch_handler.can_switch?(@logic.battler(0, index), reason: :flee)
          switch_handler.process_prevention_reason
          return :failure
        end
        value = flee_value(index)
        @logic.battle_info.flee_attempt_count += 1
        result = @logic.generic_rng.rand(256) < value ? :success : :failure
        @scene.display_message_and_wait(parse_text(18, result == :success ? 75 : 76))
        return result
      rescue Hooks::ForceReturn => e
        log_data("\# FR: flee\#attempt #{e.data} from #{e.hook_name} (#{e.reason})")
        process_prevention_reason
        return e.data
      end
      private
      # Get the value used to test if the flee is successful
      # @param index [Integer] index of the Pokemon on the trainer bank
      # @note formula ajusted according to: https://docs.google.com/document/d/1Jv-hDNpeEU-cLTiy1c1b3YSRgSEDt2ffbgk5vkPhkKE
      # @return [Integer]
      def flee_value(index)
        trainer_poke = @logic.battler(0, index)
        enemy_poke = @logic.battler(1, index) || @logic.battler(1, 0)
        a = trainer_poke&.spd_basis || 1
        b = (enemy_poke&.spd_basis || 4).clamp(4, Float::INFINITY)
        c = @logic.battle_info.flee_attempt_count
        log_debug("flee_value: a = #{a}, b = #{b}, c = #{c}")
        return 256 if a > b
        return ((a * 32 / (b / 4)) + 30 * c)
      end
      class << self
        # Function that registers a flee_block hook
        # @param reason [String] reason of the flee_block registration
        # @yieldparam handler [FleeHandler]
        # @yieldreturn [:prevent, nil] :prevent if the stat increase cannot apply
        def register_flee_block_hook(reason)
          Hooks.register(FleeHandler, :flee_block, reason) do
            result = yield(self)
            force_return(:blocked) if result == :prevent
          end
        end
        # Function that registers a flee_passthrough hook
        # @param reason [String] reason of the flee_passthrough registration
        # @yieldparam handler [FleeHandler]
        # @yieldparam pokemon [PFM::PokemonBattler] pokemon attempting to flee
        # @yieldreturn [:prevent, nil] :prevent if the stat increase cannot apply
        def register_flee_passthrough_hook(reason)
          Hooks.register(FleeHandler, :flee_passthrough, reason) do |hook_binding|
            result = yield(self, logic.battler(0, hook_binding.local_variable_get(:index)))
            force_return(:success) if result == :success
          end
        end
      end
      FleeHandler.register_flee_passthrough_hook('PSDK smoke ball') do |handler, pokemon|
        next if pokemon.item_db_symbol != :smoke_ball
        message = parse_text_with_pokemon(19, 1010, pokemon, PFM::Text::ITEM2[1] => pokemon.item_name)
        handler.scene.display_message_and_wait(message)
        next(:success)
      end
      FleeHandler.register_flee_passthrough_hook('PSDK run away') do |handler, pokemon|
        next unless pokemon.has_ability?(:run_away)
        handler.scene.visual.show_ability(pokemon)
        message = parse_text_with_pokemon(19, 767, pokemon)
        handler.scene.display_message_and_wait(message)
        next(:success)
      end
      FleeHandler.register_flee_block_hook('No flee in trainer battle') do |handler|
        next unless handler.logic.battle_info.trainer_battle?
        next(handler.prevent_change do
          handler.scene.display_message_and_wait(parse_text(18, 79))
        end)
      end
      FleeHandler.register_flee_block_hook('No flee when BT_NoEscape is on') do |handler|
        next unless $game_switches[Yuki::Sw::BT_NoEscape]
        handler.prevent_change do
          handler.scene.display_message_and_wait(parse_text(18, 77))
        end
      end
    end
    public
    # Handler responsive of answering properly Pokemon catching requests
    class CatchHandler < ChangeHandlerBase
      include Hooks
      # Modifier applied to the formula depending of the Status
      # @return [Hash{ Symbol => Integer }]
      STATUS_MODIFIER = {poison: 1.5, paralysis: 1.5, burn: 1.5, sleep: 2.5, freeze: 2.5, toxic: 1.5}
      # List all the special ball rate calculation block
      BALL_RATE_CALCULATION = {}
      # ID of the catching text in the text database
      # @return [Array<Array<Integer>>]
      TEXT_CATCH = [[18, 63], [18, 64], [18, 65], [18, 66], [18, 67], [18, 68]]
      # DB_Symbol of each Ultra-Beast
      # @return [Array<Symbol>]
      ULTRA_BEAST = %i[nihilego buzzwole pheromosa xurkitree celesteela kartana guzzlord poipole naganadel stakataka blacephalon]
      # Function that try to catch the targeted Pokemon
      # @param target [PFM::PokemonBattler]
      # @param pkm_ally [PFM::PokemonBattler]
      # @param ball [Studio::BallItem] db_symbol of the used ball
      def try_to_catch_pokemon(target, pkm_ally, ball)
        log_data("\# FR: try_to_catch_pokemon(#{target}, #{pkm_ally}, #{ball})")
        @bounces = 0
        @scene.message_window.blocking = true
        @scene.message_window.wait_input = true
        exec_hooks(Battle::Logic::CatchHandler, :ball_blocked, binding)
        catching_procedure(target, pkm_ally, ball)
        show_message_and_animation(target, ball, @bounces, caught?)
        return caught?
      rescue Hooks::ForceReturn => e
        log_data("\# FR: try_to_catch_pokemon #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Tells if the Pokemon is caught
      # @return [Boolean]
      def caught?
        return @bounces == 4 || @critical_capture
      end
      class << self
        # Define a new ball rate calculation in BALL_RATE_CALCULATION
        # @param ball_name [Symbol] the DB_symbol of the ball
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam pkm_ally [PFM::PokemonBattler]
        # @yieldreturn [Integer] the new catch_rate
        def add_ball_rate_calculation(ball_name, &block)
          BALL_RATE_CALCULATION[ball_name] = block if block
        end
      end
      add_ball_rate_calculation(:dive_ball) do |target, _pkm_ally|
        next((target.rareness * 3.5)) if $scene.battle_info.fishing
        next((target.rareness * 3.5)) if $game_player.surfing?
        next(target.rareness)
      end
      add_ball_rate_calculation(:dusk_ball) do |target, _pkm_ally|
        next((target.rareness * 3.5)) if $env.cave?
        next((target.rareness * 3.5)) if $env.night?
        next(target.rareness)
      end
      add_ball_rate_calculation(:fast_ball) do |target, _pkm_ally|
        next(target.rareness * (target.base_spd >= 100 ? 4 : 1))
      end
      add_ball_rate_calculation(:heavy_ball) do |target, _pkm_ally|
        modifier = target.rareness
        weight = target.weight
        if weight.between?(0, 204.7)
          modifier -= 20
        else
          if weight.between?(204.8, 307.1)
            modifier += 20
          else
            if weight.between?(307.2, 409.5)
              modifier += 30
            else
              if weight >= 409.6
                modifier += 40
              end
            end
          end
        end
        next(modifier.clamp(1, 255))
      end
      add_ball_rate_calculation(:level_ball) do |target, pkm_ally|
        e_level = target.level
        p_level = pkm_ally.level
        if (e_level * 4) <= p_level
          next(target.rareness * 8)
        else
          if (e_level * 2) <= p_level
            next(target.rareness * 4)
          else
            if e_level < p_level
              next(target.rareness * 2)
            end
          end
        end
        next(target.rareness)
      end
      add_ball_rate_calculation(:love_ball) do |target, pkm_ally|
        if target.id == pkm_ally.id
          next(target.rareness * 8) if (target.gender != pkm_ally.gender) && [target.gender, pkm_ally.gender].none? { |pkm| pkm.gender == 0 }
        end
        next(target.rareness)
      end
      add_ball_rate_calculation(:lure_ball) do |target, _pkm_ally|
        next(target.rareness * ($scene.battle_info.fishing ? 3 : 1))
      end
      add_ball_rate_calculation(:moon_ball) do |target, _pkm_ally|
        ok = data_creature(target.db_symbol).forms.first.evolutions.any? { |evolution| evolution.condition_data(:stone) == :moon_stone }
        next(target.rareness * (ok ? 4 : 1))
      end
      add_ball_rate_calculation(:nest_ball) do |target, _pkm_ally|
        next(target.rareness) if target.level >= 30
        next(target.rareness * (((41 - target.level) * 4096 / 10.0).to_i / 4096.0).clamp(1, 4))
      end
      add_ball_rate_calculation(:net_ball) do |target, _pkm_ally|
        check = [target.type1, target.type2, target.type3].any? { |type| [3, 12].include? type }
        next(target.rareness * (check ? 3 : 1))
      end
      add_ball_rate_calculation(:quick_ball) do |target, _pkm_ally|
        next(target.rareness * ($game_temp.battle_turn == 0 ? 5 : 1))
      end
      add_ball_rate_calculation(:repeat_ball) do |target, _pkm_ally|
        next(target.rareness * ($pokedex.has_captured?(target.id) ? 3 : 1))
      end
      add_ball_rate_calculation(:timer_ball) do |target, _pkm_ally|
        next([(1 + ($game_temp.battle_turn) * 1229.0 / 4096), 4].min * target.rareness)
      end
      add_ball_rate_calculation(:dream_ball) do |target, _pkm_ally|
        next(target.rareness * (target.asleep? ? 4 : 1))
      end
      private
      # Function that calculate the modified rate for the capture
      # @param target [PFM::PokemonBattler]
      # @param pkm_ally [PFM::PokemonBattler]
      # @param ball [Studio::BallItem] db_symbol of the used ball
      def catching_procedure(target, pkm_ally, ball)
        a = final_rate(target, pkm_ally, ball)
        return if check_critical_capture(a)
        if a >= 255
          @bounces = 4
        else
          4.times do |i|
            log_debug("bounce no.#{i}")
            break unless check_bounce(a)
          end
        end
      end
      # Get the right catch rate of the target depending on the ball used
      # @param target [PFM::PokemonBattler]
      # @param pkm_ally [PFM::PokemonBattler]
      # @param ball [Studio::BallItem] db_symbol of the used ball
      def catch_rate(target, pkm_ally, ball)
        return (target.rareness * 0.1) if ULTRA_BEAST.include?(target.db_symbol) && ball != :beast_ball
        return (target.rareness * 5) if ULTRA_BEAST.include?(target.db_symbol) && ball == :beast_ball
        return BALL_RATE_CALCULATION[ball.db_symbol].call(target, pkm_ally) if BALL_RATE_CALCULATION.keys.include?(ball.db_symbol)
        return target.rareness
      end
      # Calculate the final_rate 'a'() (6G formula from here : https://bulbapedia.bulbagarden.net/wiki/Catch_rate#Capture_method_.28Generation_VI.29)
      # @param target [PFM::PokemonBattler]
      # @param pkm_ally [PFM::PokemonBattler]
      # @param ball [Studio::BallItem] db_symbol of the used ball
      def final_rate(target, pkm_ally, ball)
        rate = catch_rate(target, pkm_ally, ball)
        log_debug("Catch rate = #{rate}")
        bonus_ball = ball.catch_rate
        log_debug("Bonus ball = #{bonus_ball}")
        bonus_status = STATUS_MODIFIER[Configs.states.symbol(target.status)] || 1
        log_debug("Status modifier = #{bonus_status}")
        a = (((3 * target.max_hp) - (2 * target.hp)) * rate * bonus_ball / (3 * target.max_hp).to_f * bonus_status).floor
        log_debug("Final rate = #{a}")
        exec_hooks(Battle::Logic::CatchHandler, :special_rate_modifier, binding)
        return a
      end
      # Check if a Critical capture ensue
      # @return [Boolean]
      def check_critical_capture(a)
        count = $pokedex.creature_caught
        if count > 600
          a *= 2.5
        else
          if count >= 451
            a *= 2
          else
            if count >= 301
              a *= 1.5
            else
              if count >= 151
                a *= 1
              else
                if count >= 31
                  a *= 0.5
                else
                  a *= 0
                end
              end
            end
          end
        end
        c = a / 6
        log_debug("c = #{c}")
        if logic.generic_rng.rand(0..255) < c
          @critical_capture = true
          @bounces = 1
        end
      end
      def check_bounce(a)
        b = (65_536 / ((255 / a.to_f) ** 0.1875)).floor
        check = logic.generic_rng.rand(0..65_535)
        if check < b
          log_debug("Success as #{check} is inferior to #{b}")
          @bounces += 1
          log_debug("@bounces = #{@bounces}")
          return true
        end
        log_debug("Failure as #{check} is superior to #{b}")
        return false
      end
      def show_message_and_animation(target, ball, nb_bounce, caught)
        @scene.visual.show_catch_animation(target, ball, nb_bounce, caught)
        @scene.display_message_and_wait(parse_text(*TEXT_CATCH[(nb_bounce) % 4], PFM::Text::PKNAME[0] => target.name)) unless caught
        return caught
      end
      Hooks.register(Battle::Logic::CatchHandler, :ball_blocked, 'Check if the initial rareness of the Pokemon is 0') do |hook_binding|
        if hook_binding[:target].rareness == 0
          @scene.display_message_and_wait(parse_text(18, 69))
          force_return(false)
        end
      end
      Hooks.register(Battle::Logic::CatchHandler, :ball_blocked, 'Check if catching is forbidden in this battle') do |_hook_binding|
        if $game_switches[Yuki::Sw::BT_NoCatch]
          @scene.display_message_and_wait(parse_text(18, 69))
          force_return(false)
        end
      end
      Hooks.register(Battle::Logic::CatchHandler, :ball_blocked, 'Check if the battle is a Trainer battle') do |hook_binding|
        if logic.battle_info.trainer_battle? && hook_binding[:ball].db_symbol != :rocket_ball
          @scene.display_message_and_wait(parse_text(18, 69))
          force_return(false)
        end
      end
    end
    public
    # Handler responsive of answering properly ability changes requests
    class AbilityChangeHandler < ChangeHandlerBase
      include Hooks
      # List of abilities that can be overwritten
      CANT_OVERWRITE_ABILITIES = %i[battle_bond comatose disguise multitype power_construct rks_system schooling shields_down stance_change zen_mode gulp_missile]
      # List of abilities the receiver/power_of_alchemy ability can't copy
      RECEIVER_CANT_COPY_ABILITIES = %i[receiver power_of_alchemy trace forecast flower_gift multitype illusion wonder_guard zen_mode imposter stance_change power_construct schooling comatose shields_down disguise rks_system battle_bond gulp_missile]
      # These moves fail if the target has these abilities
      SKILL_BLOCKING_ABILITIES = {entrainment: %i[truant], role_play: %i[flower_gift forecast illusion imposter power_of_alchemy receiver trace wonder_guard], simple_beam: %i[simple truant], skill_swap: %i[illusion wonder_guard], worry_seed: %i[gulp_missile]}
      # Case of a ability that fail
      ABILITY_BLOCKING_ABILITIES = {mummy: %i[mummy], wandering_spirit: %i[wandering_spirit], trace: %i[flower_gift forecast illusion imposter multitype stance_change trace zen_mode receiver power_of_alchemy], receiver: RECEIVER_CANT_COPY_ABILITIES, power_of_alchemy: RECEIVER_CANT_COPY_ABILITIES}
      # Case of a move that fail if the launcher has this ability
      USER_BLOCKING_ABILITIES = {entrainment: %i[disguise forecast flower_gift illusion imposter power_construct power_of_alchemy receiver trace zen_mode], role_play: CANT_OVERWRITE_ABILITIES + %i[receiver power_of_alchemy]}
      # Function that change the ability of a Pokemon
      # @param target [PFM::PokemonBattler]
      # @param ability_symbol [Symbol, :none] Symbol ID of the Ability
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def change_ability(target, ability_symbol, launcher = nil, skill = nil)
        return unless can_change_ability?(target, ability_symbol, launcher, skill)
        target.ability = (ability_symbol == :none ? 0 : data_ability(ability_symbol).id) || 0
        exec_hooks(AbilityChangeHandler, :post_ability_change, binding)
      end
      # Function that tell if this is possible to change the ability of a Pokemon
      # @param target [PFM::PokemonBattler]
      # @param ability_symbol [Symbol, :none] Symbol ID of the Ability
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def can_change_ability?(target, ability_symbol, launcher = nil, skill = nil)
        log_data("\# can_change_ability?(#{target}, #{ability_symbol}, #{launcher}, #{skill})")
        exec_hooks(AbilityChangeHandler, :ability_change_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# FR: can_change_ability? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      class << self
        # Function that registers a ability_change_prevention hook
        # @param reason [String] reason of the ability_change_prevention registration
        # @yieldparam handler [AbilityChangeHandler]
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam ability_symbol [Symbol] Symbol of the Ability which will be set
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the ability cannot be changed
        def register_ability_prevention_hook(reason)
          Hooks.register(AbilityChangeHandler, :ability_change_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:ability_symbol), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a post_ability_change hook
        # @param reason [String] reason of the ability_change_prevention registration
        # @yieldparam handler [AbilityChangeHandler]
        # @yieldparam target [PFM::PokemonBattler]
        # @yieldparam ability_symbol [Symbol] Symbol of the Ability which will be set
        # @yieldparam launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @yieldparam skill [Battle::Move, nil] Potential move used
        # @yieldreturn [:prevent, nil] :prevent if the ability cannot be changed
        def register_post_ability_change_hook(reason)
          Hooks.register(AbilityChangeHandler, :post_ability_change, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:ability_symbol), hook_binding.local_variable_get(:launcher), hook_binding.local_variable_get(:skill))
          end
        end
      end
    end
    AbilityChangeHandler.register_ability_prevention_hook('PSDK Ability Prev: Cannot OW Target Ability') do |handler, target, _, _, _|
      next unless AbilityChangeHandler::CANT_OVERWRITE_ABILITIES.include?(target.ability_db_symbol)
      next(handler.prevent_change)
    end
    AbilityChangeHandler.register_ability_prevention_hook('PSDK Ability Prev: Cannot OW Target Ability With Skill') do |handler, target, _, launcher, skill|
      next unless skill && launcher != target && AbilityChangeHandler::SKILL_BLOCKING_ABILITIES[skill.db_symbol]&.include?(target.ability_db_symbol)
      next(handler.prevent_change)
    end
    AbilityChangeHandler.register_ability_prevention_hook('PSDK Ability Prev: Cannot OW Target Ability With Ability') do |handler, target, ability_symbol, _, skill|
      next unless AbilityChangeHandler::ABILITY_BLOCKING_ABILITIES[ability_symbol]&.include?(target.ability_db_symbol) && !skill
      next(handler.prevent_change)
    end
    AbilityChangeHandler.register_ability_prevention_hook('PSDK Ability Prev: Cannot OW User Ability With Skill') do |handler, target, _, launcher, skill|
      next unless skill && launcher == target && AbilityChangeHandler::SKILL_BLOCKING_ABILITIES[skill.db_symbol]&.include?(launcher.ability_db_symbol)
      next(handler.prevent_change)
    end
    AbilityChangeHandler.register_post_ability_change_hook('PSDK Post Ability Change: Illusion reset') do |handler, target, _, launcher, skill|
      next unless target.original.ability_db_symbol == :illusion && target.illusion
      target.illusion = nil
      handler.scene.visual.show_ability(target)
      handler.scene.visual.show_switch_form_animation(target)
      handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 478, target))
    end
    public
    # Handler responsive of handling the end of the battle
    class BattleEndHandler < ChangeHandlerBase
      include Hooks
      # Process the battle end
      def process
        @scene.message_window.blocking = true
        players_pokemon = @logic.all_battlers.select(&:from_party?)
        players_pokemon.concat($actors.map { |pkmn| PFM::PokemonBattler.new(pkmn, $scene) }) if players_pokemon.empty?
        $game_temp.battle_can_lose = false if PFM.game_state.nuzlocke.enabled? && !$game_switches[Yuki::Sw::BT_AUTHORIZE_DEFEAT_NUZLOCKE]
        exec_hooks(BattleEndHandler, :battle_end, binding)
        exec_hooks(BattleEndHandler, :battle_end_no_defeat, binding) if @logic.battle_result != 2
        @logic.all_battlers(&:copy_properties_back_to_original)
        exec_hooks(BattleEndHandler, :battle_end_nuzlocke, binding) if PFM.game_state.nuzlocke.enabled?
        unless $scene.is_a?(Yuki::SoftReset) || $scene.is_a?(Scene_Title)
          $game_system.bgm_play($game_system.playing_bgm)
          $game_system.bgs_play($game_system.playing_bgs)
        end
      end
      # Get the item to pick up
      # @param pokemon [PFM::Pokemon]
      # @return [Integer]
      def pickup_item(pokemon)
        off = (((pokemon.level - 1.0) / Configs.settings.max_level) * 10).round
        ind = pickup_index(@logic.generic_rng.rand(100))
        env = $env
        return GrassItem[off][ind] if env.tall_grass? || env.grass?
        return CaveItem[off][ind] if env.cave? || env.mount?
        return WaterItem[off][ind] if env.sea? || env.pond?
        return CommonItem[off][ind]
      end
      # Process the loose sequence when the battle doesn't allow defeat
      def player_loose_sequence
        lost_money = calculate_lost_money
        variables = {PFM::Text::TRNAME[0] => $trainer.name, PFM::Text::NUMXR => lost_money.to_s}
        PFM.game_state.lose_money(lost_money)
        @scene.message_window.stay_visible = true
        @scene.visual.lock do
          @scene.display_message(parse_text(18, 56, variables))
          @scene.display_message(parse_text(18, @scene.battle_info.trainer_battle? ? 58 : 57, variables))
          @scene.display_message(parse_text(18, 59, variables))
        end
      end
      private
      # Get the right pickup index
      # @param seed [Integer]
      # @return [Integer]
      def pickup_index(seed)
        return 0 if seed < 30
        return (1 + (seed - 30) / 10) if seed < 80
        return 6 if seed < 88
        return 7 if seed < 94
        return 8 if seed < 99
        return 9
      end
      # Get the money the player looses when he lose a battle
      # @return [Integer]
      def calculate_lost_money
        base_payout * @logic.battler(0, 0).level
      end
      # Get the base payout to calculate the lost money
      # @return [Integer]
      def base_payout
        return [8, 16, 24, 36, 48, 64, 80, 100, 120][$trainer.badge_counter] || 120
      end
      class << self
        # Function that registers a battle end procedure
        # @param reason [String] reason of the battle_end registration
        # @yieldparam handler [BattleEndHandler]
        # @yieldparam players_pokemon [Array<PFM::PokemonBattler>]
        def register(reason)
          Hooks.register(BattleEndHandler, :battle_end, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:players_pokemon))
          end
        end
        # Function that registers a battle end procedure when it's not a defeat
        # @param reason [String] reason of the battle_end_no_defeat registration
        # @yieldparam handler [BattleEndHandler]
        # @yieldparam players_pokemon [Array<PFM::PokemonBattler>]
        def register_no_defeat(reason)
          Hooks.register(BattleEndHandler, :battle_end_no_defeat, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:players_pokemon))
          end
        end
        # Function that registers a battle end procedure when nuzlocke mode is enabled
        # @param reason [String] reason of the battle_end_nuzlocke registration
        # @yieldparam handler [BattleEndHandler]
        # @yieldparam players_pokemon [Array<PFM::PokemonBattler>]
        def register_nuzlocke(reason)
          Hooks.register(BattleEndHandler, :battle_end_nuzlocke, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:players_pokemon))
          end
        end
      end
      public
      # List of Items (ID) got with Pickup on Grass
      # @author Nuri Yuri
      GrassItem = [[155, 151, 158, 150, 152, 149, 4, 79, 154, 92], [151, 158, 150, 152, 149, 4, 79, 154, 92, 85], [158, 26, 28, 27, 3, 76, 154, 92, 85, 25], [26, 28, 27, 3, 76, 154, 92, 85, 25, 38], [28, 27, 2, 76, 154, 92, 85, 25, 38, 278], [27, 2, 76, 154, 28, 85, 24, 38, 278, 537], [2, 76, 154, 28, 85, 24, 93, 278, 537, 40], [77, 154, 28, 85, 24, 93, 50, 80, 40, 537], [154, 28, 2, 24, 93, 50, 80, 40, 537, 234], [28, 2, 23, 93, 50, 80, 40, 51, 234, 537], [2, 23, 93, 50, 80, 40, 51, 234, 53, 537]]
      # List of Items (ID) got with Pickup in Cave
      # @author Nuri Yuri
      CaveItem = [[17, 18, 26, 78, 28, 27, 3, 79, 78, 92], [18, 4, 26, 28, 27, 3, 79, 78, 92, 82], [4, 26, 28, 27, 3, 76, 78, 92, 82, 25], [26, 28, 27, 3, 77, 78, 92, 82, 25, 38], [28, 27, 2, 77, 78, 92, 82, 25, 38, 278], [27, 2, 77, 78, 28, 82, 24, 38, 278, 537], [2, 77, 78, 28, 82, 24, 93, 278, 537, 40], [77, 78, 28, 82, 24, 93, 50, 80, 40, 537], [78, 28, 2, 24, 93, 50, 80, 40, 537, 234], [28, 2, 23, 93, 50, 80, 40, 51, 234, 537], [2, 23, 93, 50, 80, 40, 51, 234, 53, 537]]
      # List of Items (ID) got with Pickup on Water
      # @author Nuri Yuri
      WaterItem = [[17, 18, 26, 78, 28, 27, 3, 79, 78, 92], [18, 4, 26, 28, 27, 3, 79, 78, 92, 84], [4, 26, 28, 27, 3, 76, 78, 92, 84, 25], [26, 28, 27, 3, 77, 78, 92, 84, 25, 38], [28, 27, 2, 77, 78, 92, 84, 25, 38, 278], [27, 2, 77, 78, 28, 84, 24, 38, 278, 537], [2, 77, 78, 28, 84, 24, 93, 278, 537, 40], [77, 78, 28, 84, 24, 93, 50, 80, 40, 537], [78, 28, 2, 24, 93, 50, 80, 40, 537, 234], [28, 2, 23, 93, 50, 80, 40, 51, 234, 537], [2, 23, 93, 50, 80, 40, 51, 234, 53, 537]]
      # List of Items (ID) got with Pickup on common tiles
      # @author Nuri Yuri
      CommonItem = [[17, 18, 26, 78, 28, 27, 3, 79, 78, 92], [18, 4, 26, 28, 27, 3, 79, 78, 92, 83], [4, 26, 28, 27, 3, 76, 78, 92, 83, 25], [26, 28, 27, 3, 77, 78, 92, 83, 25, 38], [28, 27, 2, 77, 78, 92, 83, 25, 38, 278], [27, 2, 77, 78, 28, 83, 24, 38, 278, 537], [2, 77, 78, 28, 83, 24, 93, 278, 537, 40], [77, 78, 28, 83, 24, 93, 50, 80, 40, 537], [78, 28, 2, 24, 93, 50, 80, 40, 537, 234], [28, 2, 23, 93, 50, 80, 40, 51, 234, 537], [2, 23, 93, 50, 80, 40, 51, 234, 53, 537]]
    end
    BattleEndHandler.register('PSDK set switches') do |handler|
      $game_switches[Yuki::Sw::BT_Catch] = !handler.logic.battle_info.caught_pokemon.nil?
      $game_switches[Yuki::Sw::BT_Defeat] = handler.logic.battle_result == 2
      $game_switches[Yuki::Sw::BT_Victory] = handler.logic.battle_result == 0
      $game_switches[Yuki::Sw::BT_Player_Flee] = handler.logic.battle_result == 1
      $game_switches[Yuki::Sw::BT_Wild_Flee] = handler.logic.battle_result == 3
      $game_switches[Yuki::Sw::BT_NoEscape] = false
    end
    BattleEndHandler.register('PSDK reset weather to normal') do
      $env.apply_weather(:none, 0) unless $game_switches[Yuki::Sw::MixWeather]
    end
    BattleEndHandler.register('PSDK trainer messages') do |handler|
      next unless $game_temp.trainer_battle
      $game_temp.vs_type.times.map do |i|
        next(handler.scene.visual.battler_sprite(1, -i - 1))
      end.compact.each(&:go_in)
      ids = [$game_variables[Yuki::Var::Trainer_Battle_ID], $game_variables[Yuki::Var::Second_Trainer_ID]].select { |i| i > 0 }
      if handler.logic.battle_result == 0
        handler.logic.battle_phase_exp
        Audio.bgm_play(*handler.scene.battle_info.victory_bgm)
        handler.scene.battle_info.defeat_texts.each_with_index do |text, i|
          if text
            handler.scene.display_message_and_wait(text)
          else
            if ids[i]
              handler.scene.display_message_and_wait(text_get(48, ids[i]))
            end
          end
        end
        if (v = handler.scene.battle_info.total_money(handler.logic)) > 0
          PFM.game_state.add_money(v)
          handler.scene.display_message_and_wait(parse_text(18, 60, PFM::Text::TRNAME[0] => $trainer.name, PFM::Text::NUMXR => v.to_s))
        end
      else
        handler.scene.battle_info.victory_texts.each_with_index do |text, i|
          if text
            handler.scene.display_message_and_wait(text)
          else
            if ids[i]
              handler.scene.display_message_and_wait(text_get(47, ids[i]))
            end
          end
        end
      end
    end
    BattleEndHandler.register('PSDK wild victory') do |handler|
      next if $game_temp.trainer_battle || handler.logic.battle_result.between?(1, 2)
      Audio.bgm_play(*handler.scene.battle_info.victory_bgm)
      handler.logic.battle_phase_exp
      if (v = handler.scene.battle_info.additional_money) > 0
        PFM.game_state.add_money(v)
        handler.scene.display_message_and_wait(parse_text(18, 61, PFM::Text::TRNAME[0] => $trainer.name, PFM::Text::NUMXR => v.to_s))
      end
    end
    BattleEndHandler.register_no_defeat('PSDK natural cure') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        pokemon.cure if pokemon.original.ability_db_symbol == :natural_cure
      end
    end
    BattleEndHandler.register_no_defeat('PSDK honey gather') do |handler, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.ability_db_symbol == :honey_gather && pokemon.item_holding == 0 && handler.logic.generic_rng.rand(100) < (pokemon.level / 2)
        next if pokemon.original.egg?
        pokemon.item_holding = data_item(:honey).id
      end
    end
    BattleEndHandler.register_no_defeat('PSDK pickup') do |handler, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.ability_db_symbol == :pickup && pokemon.item_holding == 0 && handler.logic.generic_rng.rand(100) < 10
        next unless handler.logic.battle_result == 0
        next if pokemon.original.egg?
        pokemon.item_holding = handler.pickup_item(pokemon.original)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power band') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_band
        pokemon.add_ev_dfs(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power belt') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_belt
        pokemon.add_ev_dfe(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power anklet') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_anklet
        pokemon.add_ev_spd(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power lens') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_lens
        pokemon.add_ev_ats(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power weight') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_weight
        pokemon.add_ev_hp(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK power bracer') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.original.item_db_symbol == :power_bracer
        pokemon.add_ev_atk(4, pokemon.original.total_ev)
      end
    end
    BattleEndHandler.register('PSDK form calibration') do |_, players_pokemon|
      players_pokemon.each(&:unmega_evolve)
      players_pokemon.each(&:form_calibrate)
    end
    BattleEndHandler.register('PSDK burmy & wormadam calibration') do |_, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless pokemon.db_symbol == :burmy || pokemon.db_symbol == :wormadam
        pokemon.form = pokemon.form_generation(-1)
      end
    end
    BattleEndHandler.register_no_defeat('PSDK Evolve') do |handler, players_pokemon|
      players_pokemon.each do |pokemon|
        next unless handler.logic.evolve_request.include?(pokemon) && pokemon.alive?
        original = pokemon.original
        id, form = original.evolve_check(:level_up)
        handler.scene.instance_variable_set(:@cfi_type, :none)
        next unless id
        GamePlay.make_pokemon_evolve(original, id, form)
        $pokedex.mark_seen(original.id, original.form, forced: true)
        $pokedex.mark_captured(original.id)
        $quests.see_pokemon(original.db_symbol)
        $quests.catch_pokemon(original)
        pokemon.id = original.id
        pokemon.form = original.form
      end
    end
    BattleEndHandler.register('PSDK stop cycling') do |handler, players_pokemon|
      $game_player.leave_cycling_state if players_pokemon.all?(&:dead?) && !$game_temp.battle_can_lose && handler.logic.battle_result == 2
    end
    BattleEndHandler.register('Reset Z position of the player') do |handler, players_pokemon|
      $game_player.z = 0 if players_pokemon.all?(&:dead?) && !$game_temp.battle_can_lose && handler.logic.battle_result == 2
    end
    BattleEndHandler.register('PSDK send player back to Pokemon Center') do |handler, players_pokemon|
      next unless players_pokemon.all?(&:dead?) || handler.logic.debug_end_of_battle
      next if handler.logic.battle_result != 2
      unless $game_temp.battle_can_lose
        handler.player_loose_sequence
        $wild_battle.reset
        $wild_battle.reset_encounters_history
        $game_temp.transition_processing = true
        $game_temp.player_transferring = true
        $game_map.setup($game_temp.player_new_map_id = $game_variables[::Yuki::Var::E_Return_ID])
        $game_temp.player_new_x = $game_variables[::Yuki::Var::E_Return_X] + ::Yuki::MapLinker.get_OffsetX
        $game_temp.player_new_y = $game_variables[::Yuki::Var::E_Return_Y] + ::Yuki::MapLinker.get_OffsetY
        $game_temp.player_new_direction = 8
        $game_switches[Yuki::Sw::FM_NoReset] = true
        $game_temp.common_event_id = 3
      end
    end
    BattleEndHandler.register('PSDK Update Pokedex') do |handler|
      handler.logic.all_battlers do |battler|
        next if battler.from_party? || battler.last_sent_turn == -1
        $pokedex.mark_seen(battler.id, battler.form, forced: true)
        $pokedex.increase_creature_fought(battler.id) unless battler.alive?
      end
    end
    BattleEndHandler.register('PSDK Update Quest') do |handler|
      handler.logic.all_battlers do |battler|
        next if battler.from_party?
        $quests.see_pokemon(battler.db_symbol) unless battler.last_sent_turn == -1
        $quests.beat_pokemon(battler.db_symbol) unless battler.alive?
      end
    end
    BattleEndHandler.register('PSDK give back the items for Bestow Effects') do |handler|
      next if (effects = handler.logic.terrain_effects.get_all(:bestow)).empty?
      effects.each(&:give_back_item)
    end
    BattleEndHandler.register_nuzlocke('PSDK Nuzlocke') do |handler|
      PFM.game_state.nuzlocke.clear_dead_pokemon
      handler.logic.all_battlers do |battler|
        PFM.game_state.nuzlocke.lock_catch_in_current_zone(battler.id) unless battler.from_party?
      end
      caught_pokemon = handler.logic.battle_info.caught_pokemon
      PFM.game_state.nuzlocke.lock_catch_in_current_zone(caught_pokemon.id) if caught_pokemon
    end
    public
    public
    # Handler responsive of answering properly terrain changes requests
    class FTerrainChangeHandler < ChangeHandlerBase
      include Hooks
      # Weather thingies copiepasted, I don't think this is really useful right now
      FTERRAIN_SYM_TO_MSG = {none: {electric_terrain: 227, grassy_terrain: 223, misty_terrain: 225, psychic_terrain: 347}, electric_terrain: 226, grassy_terrain: 222, misty_terrain: 224, psychic_terrain: 346}
      # Function telling if a terrain can be applyied
      # @param fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
      # @return [Boolean]
      def fterrain_appliable?(fterrain_type)
        log_data("\# fterrain_appliable?(#{fterrain_type})")
        reset_prevention_reason
        last_fterrain = @logic.field_terrain || :none
        exec_hooks(FTerrainChangeHandler, :fterrain_prevention, binding)
        return true
      rescue Hooks::ForceReturn => e
        log_data("\# FR: fterrain_appliable? #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that actually change the terrain
      # @param fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
      def fterrain_change(fterrain_type)
        log_data("\# fterrain_change(#{fterrain_type})")
        last_fterrain = @logic.field_terrain || :none
        @logic.field_terrain = fterrain_type
        @logic.field_terrain_effect
        show_fterrain_message(last_fterrain, fterrain_type)
        exec_hooks(FTerrainChangeHandler, :post_fterrain_change, binding)
      rescue Hooks::ForceReturn => e
        log_data("\# FR: fterrain_change #{e.data} from #{e.hook_name} (#{e.reason})")
        return e.data
      end
      # Function that test if the change is possible and perform the change if so
      # @param fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
      def fterrain_change_with_process(fterrain_type)
        return process_prevention_reason unless fterrain_appliable?(fterrain_type)
        fterrain_change(fterrain_type)
      end
      private
      # Show the terrain  message
      # @param last_fterrain [Symbol]
      # @param current_fterrain [Symbol]
      def show_fterrain_message(last_fterrain, current_fterrain)
        return if last_fterrain == current_fterrain
        if current_fterrain == :none
          @scene.display_message_and_wait(parse_text(60, FTERRAIN_SYM_TO_MSG[current_fterrain][last_fterrain]))
        else
          @scene.display_message_and_wait(parse_text(60, FTERRAIN_SYM_TO_MSG[:none][last_fterrain])) if last_fterrain != :none
          @scene.display_message_and_wait(parse_text(60, FTERRAIN_SYM_TO_MSG[current_fterrain]))
        end
      end
      class << self
        # Function that registers a fterrain_prevetion hook
        # @param reason [String] reason of the fterrain_prevetion registration
        # @yieldparam handler [FTerrainChangeHandler]
        # @yieldparam fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        # @yieldparam last_fterrain [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        # @yieldreturn [:prevent, nil] :prevent if the status cannot be applied
        def register_fterrain_prevention_hook(reason)
          Hooks.register(FTerrainChangeHandler, :fterrain_prevention, reason) do |hook_binding|
            result = yield(self, hook_binding.local_variable_get(:fterrain_type), hook_binding.local_variable_get(:last_fterrain))
            force_return(false) if result == :prevent
          end
        end
        # Function that registers a post_fterrain_handler hook
        # @param reason [String] reason of the post_fterrain_handler registration
        # @yieldparam handler [FTerrainChangeHandler]
        # @yieldparam fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        # @yieldparam last_fterrain [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        def register_post_fterrain_change_hook(reason)
          Hooks.register(FTerrainChangeHandler, :post_fterrain_change, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:fterrain_type), hook_binding.local_variable_get(:last_fterrain))
          end
        end
      end
    end
    FTerrainChangeHandler.register_fterrain_prevention_hook('PSDK prev field terrain: Effects') do |handler, fterrain_type, last_fterrain|
      next(handler.logic.each_effects(*handler.logic.all_alive_battlers) do |e|
        next(e.on_fterrain_prevention(handler, fterrain_type, last_fterrain))
      end)
    end
    FTerrainChangeHandler.register_post_fterrain_change_hook('PSDK post field terrain: Effects') do |handler, fterrain_type, last_fterrain|
      next(handler.logic.each_effects(*handler.logic.all_alive_battlers) do |e|
        next(e.on_post_fterrain_change(handler, fterrain_type, last_fterrain))
      end)
    end
    FTerrainChangeHandler.register_fterrain_prevention_hook('PSDK prev field terrain: Duplicate field terrain') do |_, fterrain, prev|
      next if fterrain != prev
      next(:prevent)
    end
    public
    # Handler responsive of answering properly transform requests
    class TransformHandler < ChangeHandlerBase
      include Hooks
      # Function responsive of transforming a Pokemon when initialized
      # @param target [PFM::PokemonBattler]
      def initialize_transform_attempt(target)
        exec_hooks(TransformHandler, :on_initialize_transform, binding)
      end
      # Function that tells if the Pokemon can transform or not
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def can_transform?(target)
        return !target.transform
      end
      # Function that tells if the pokemon can copy another pokemon
      # @param copied [PFM::PokemonBattler]
      # @return [Boolean]
      def can_copy?(copied)
        return false if copied&.effects&.has?(:substitute)
        return false if copied.has_ability?(:illusion) && !can_transform?(copied)
        return true
      end
      class << self
        # Function that registers a on_initialize_transform hook
        # @param reason [String] reason of the on_initialize_transform registration
        # @yieldparam handler [TransformHandler]
        # @yieldparam target [PFM::PokemonBattler] pokemon to try to transform on initialize
        # @yieldreturn [nil]
        def register_on_initialize_transform(reason)
          Hooks.register(TransformHandler, :on_initialize_transform, reason) do |hook_binding|
            yield(self, hook_binding.local_variable_get(:target))
          end
        end
      end
    end
    TransformHandler.register_on_initialize_transform('PSDK: Illusion') do |handler, target|
      next if target.original.ability_db_symbol != :illusion
      party = handler.logic.battle_info.party(target)
      party = party.map { |original| next(handler.logic.all_battlers.find { |pkm| pkm.original == original }) }
      party = party.sort_by(&:place_in_party)
      party = party&.reject(&:dead?)
      next if party.empty? || party.index(target) == (party.size - 1)
      next if party.last.position >= 0
      target.illusion = party.last
    end
    TransformHandler.register_on_initialize_transform('PSDK transform : Effects') do |handler, target|
      next unless target.effects
      next(handler.logic.each_effects(target) do |e|
        next(e.on_transform_event(handler, target))
      end)
    end
    public
    # Class responsive of calculating experience & EV of Pokemon when a Pokemon faints
    class ExpHandler
      include Hooks
      # Get the logic object
      # @return [Battle::Logic]
      attr_reader :logic
      # Create the exp handler
      # @param logic [Battle::Logic]
      def initialize(logic)
        @logic = logic
      end
      # Distribute the experience for several pokemon and merge them
      # @param enemies [Array<PFM::PokemonBattler>]
      # @return [Hash{ PFM::PokemonBattler => Integer }]
      def distribute_exp_grouped(enemies)
        exp_distributions = {}
        enemies.each do |enemy|
          next if enemy.exp_distributed
          exp_distributions.merge!(distribute_exp_for(enemy)) do |_, old_val, new_val|
            old_val + new_val
          end
        end
        return exp_distributions
      end
      # Distribute the experience for a single pokemon
      # @param enemy [PFM::PokemonBattler]
      # @return [Hash{ PFM::PokemonBattler => Integer }]
      def distribute_exp_for(enemy)
        evable = evable_pokemon(enemy)
        expable = expable_pokemon(enemy)
        return {} if logic.battle_info.disallow_exp?
        distribute_ev_to(evable, enemy)
        exp_data = global_multi_exp_factor? ? distribute_global_exp_for(enemy, expable) : distribute_separate_exp_for(enemy, expable)
        enemy.exp_distributed = true
        return exp_data.to_h
      end
      private
      # Tell if the exp factor is global or on pokemon that fought
      # @return [Boolean]
      def global_multi_exp_factor?
        $bag.contain_item?(:exp_share)
      end
      # Get the list of Pokemon that should receive the exp
      # @param enemy [PFM::PokemonBattler]
      # @return [Array<PFM::PokemonBattler>]
      def expable_pokemon(enemy)
        if !$game_switches[Yuki::Sw::BT_HardExp] || global_multi_exp_factor?
          return logic.trainer_battlers.reject { |receiver| receiver.max_level == receiver.level || receiver.dead? }
        else
          return logic.trainer_battlers.reject do |receiver|
            receiver.delete_battler_to_encounter_list(enemy) if (has_encountered = receiver.encountered?(enemy))
            next(receiver.max_level == receiver.level || receiver.dead? || !(has_encountered || receiver.item_db_symbol == :exp_share))
          end
        end
      end
      # Exp distribution formula when multi-exp is in bag (thus act as global distribution)
      # @param expable [Array<PFM::PokemonBattler>]
      # @param enemy [PFM::PokemonBattler]
      # @return [Array<[PFM::PokemonBattler, Integer]>]
      def distribute_global_exp_for(enemy, expable)
        base_exp = exp_base(enemy)
        return expable.map do |receiver|
          exp = (base_exp * level_multiplier(enemy.level, receiver.level) * exp_multipliers(receiver)).floor
          exp /= (receiver.last_battle_turn != $game_temp.battle_turn ? 2 : 1) * ($game_switches[Yuki::Sw::BT_ScaledExp] ? 5 : 7)
          next([receiver, exp])
        end
      end
      # Exp distribution formulat when multi-exp is not in bag (thus calculated separately for all pokemon)
      # @param expable [Array<PFM::PokemonBattler>]
      # @param enemy [PFM::PokemonBattler]
      # @return [Array<[PFM::PokemonBattler, Integer]>]
      def distribute_separate_exp_for(enemy, expable)
        base_exp = exp_base(enemy)
        fought_count_during_this_turn = expable.count { |battler| battler.last_battle_turn == $game_temp.battle_turn && battler.alive? }.clamp(1, 6)
        multi_exp_count = expable.count { |battler| battler.item_db_symbol == :exp_share && battler.alive? }
        multi_exp_factor = exp_multi_exp_factor(multi_exp_count)
        fought_exp_factor = exp_fought_factor(multi_exp_count, fought_count_during_this_turn)
        return expable.map do |receiver|
          exp = (base_exp * level_multiplier(enemy.level, receiver.level) * exp_multipliers(receiver)).floor
          if receiver.last_battle_turn != $game_temp.battle_turn
            next([receiver, (exp / multi_exp_factor).to_i])
          else
            next([receiver, (exp / fought_exp_factor).to_i + (receiver.item_db_symbol == :exp_share ? exp / multi_exp_factor : 0).to_i])
          end
        end
      end
      # Base exp
      # @param enemy [PFM::PokemonBattler]
      # @return [Float]
      def exp_base(enemy)
        return enemy.base_exp * enemy.level * (logic.battle_info.trainer_battle? ? 1.5 : 1)
      end
      # Multiplier depending on levels of enemy and receiver
      # @param enemy_level [Integer]
      # @param receiver_level [Integer]
      # @return [Float]
      def level_multiplier(enemy_level, receiver_level)
        return $game_switches[Yuki::Sw::BT_ScaledExp] ? ((2.0 * enemy_level + 10) / (enemy_level + receiver_level + 10)) ** 2.5 : 1
      end
      # Exp multipliers
      # @param receiver [PFM::PokemonBattler]
      def exp_multipliers(receiver)
        aura_factor = aura_factor(receiver)
        lucky_factor = receiver.item_db_symbol == :lucky_egg ? 1.5 : 1
        trade_factor = receiver.from_player? ? 1 : 1.5
        loyalty_factor = happy?(receiver) ? 1.2 : 1
        evolution_factor = receiver.evolve_check(:level_up) ? 1.2 : 1
        return aura_factor * lucky_factor * trade_factor * loyalty_factor * evolution_factor
      end
      # Tell if the pokemon is happy
      # @param receiver [PFM::PokemonBattler]
      # @return [Boolean]
      def happy?(receiver)
        return receiver.loyalty > 200
      end
      # Get the aura factor
      # @param receiver [PFM::PokemonBattler]
      # @return [Integer]
      def aura_factor(receiver)
        return 1
      end
      # Get the multi_exp factor
      # @param multi_exp_count [Integer] number of Pokemon with multi_exp
      # @return [Integer]
      def exp_multi_exp_factor(multi_exp_count)
        return ($game_switches[Yuki::Sw::BT_ScaledExp] ? 10 : 14) * (multi_exp_count + 1)
      end
      # Get the fought factor
      # @param multi_exp_count [Integer] number of Pokemon with multi_exp
      # @param fought [Integer] number of Pokemon that fought
      def exp_fought_factor(multi_exp_count, fought)
        return ($game_switches[Yuki::Sw::BT_ScaledExp] ? 5 : 7) * (multi_exp_count > 0 ? 2.0 : 1.0) * fought
      end
      # Get the list of Pokemon that should receive the EV
      # @param enemy [PFM::PokemonBattler]
      # @return [Array<PFM::PokemonBattler>]
      def evable_pokemon(enemy)
        if !$game_switches[Yuki::Sw::BT_HardExp] || global_multi_exp_factor?
          return logic.trainer_battlers.reject(&:dead?)
        else
          return logic.trainer_battlers.reject do |receiver|
            has_encountered = receiver.encountered?(enemy)
            next(receiver.dead? || !(has_encountered || receiver.item_db_symbol == :exp_share))
          end
        end
      end
      # Distribute the ev to evables depending on the enemy that was taken down
      # @param evable [Array<PFM::PokemonBattler>]
      # @param enemy [PFM::PokemonBattler]
      def distribute_ev_to(evable, enemy)
        log_debug("\# distribute_ev_to([#{evable.join(', ')}], #{enemy}")
        evable.map(&:original).each do |receiver|
          receiver.add_bonus(enemy.battle_list)
          exec_hooks(ExpHandler, :power_ev_bonus, binding)
        end
      end
      class << self
        # Register a hook allowing a pokemon to receive a power_ev bonus
        # @param reason [String] reason of the power_ev_bonus call
        # @yieldparam receiver [PFM::Pokemon] pokemon receiving the bonus
        # @yieldparam enemy [PFM::PokemonBattler] pokemon causing the bonus to be distributed
        # @yieldparam handler [ExpHandler] exp handler managing everything
        def register_power_ev_bonus(reason)
          Hooks.register(ExpHandler, :power_ev_bonus, reason) do |hook_binding|
            yield(hook_binding.local_variable_get(:receiver), hook_binding.local_variable_get(:enemy), self)
          end
        end
      end
      register_power_ev_bonus('Power band') do |receiver|
        next unless receiver.item_db_symbol == :power_band
        receiver.add_ev_dfs(4, receiver.total_ev)
      end
      register_power_ev_bonus('Power belt') do |receiver|
        next unless receiver.item_db_symbol == :power_belt
        receiver.add_ev_dfe(4, receiver.total_ev)
      end
      register_power_ev_bonus('Power anklet') do |receiver|
        next unless receiver.item_db_symbol == :power_anklet
        receiver.add_ev_spd(4, receiver.total_ev)
      end
      register_power_ev_bonus('Power lens') do |receiver|
        next unless receiver.item_db_symbol == :power_lens
        receiver.add_ev_ats(4, receiver.total_ev)
      end
      register_power_ev_bonus('Power weight') do |receiver|
        next unless receiver.item_db_symbol == :power_weight
        receiver.add_ev_hp(4, receiver.total_ev)
      end
      register_power_ev_bonus('Power bracer') do |receiver|
        next unless receiver.item_db_symbol == :power_bracer
        receiver.add_ev_atk(4, receiver.total_ev)
      end
    end
  end
end
