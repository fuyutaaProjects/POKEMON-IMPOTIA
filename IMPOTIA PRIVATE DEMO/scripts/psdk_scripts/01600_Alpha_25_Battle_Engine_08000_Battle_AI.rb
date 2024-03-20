module Battle
  # Module responsive of mocking the battle scene so nothing happen on the reality
  #
  # How to use:
  #   scene = @scene.clone
  #   scene.extend(SceneMock)
  #
  # Note: super inside this script might call the original function
  module SceneMock
    class << self
      # Method called when a scene gets mocked (through extend)
      # @param mod [Battle::Scene]
      def extended(mod)
        mod.instance_variable_set(:@battle_info, Marshal.load(Marshal.dump(mod.battle_info)))
        mod.instance_variable_set(:@viewport, nil)
        mod.instance_variable_set(:@visual, mod.visual.clone)
        mod.visual.instance_variable_set(:@scene, mod)
        mod.visual.extend(VisualMock)
        mod.instance_variable_set(:@logic, mod.logic.clone)
        mod.logic.instance_variable_set(:@scene, mod)
        mod.logic.extend(LogicMock)
      end
    end
    # Get the mock actions
    # @return [Array<Hash>]
    attr_reader :mock_actions
    # Function that pushes an action to the action array (thing that happens during execution)
    # @param data [Hash]
    def mock_push_action(data)
      @mock_actions ||= []
      @mock_actions << data
    end
    # Function that clears the mock actions
    def mock_clear_actions
      @mock_actions = []
    end
    def message_window
      log_error("message_window called by #{caller[0]}")
      return nil
    end
    def display_message_and_wait(*)
      return 0
    end
    def display_message(*)
      return 0
    end
    def update
      return nil
    end
  end
  # Module responsive of mocking the battle visual so nothing happen on the reality
  #
  # Note: super inside this script might call the original function
  module VisualMock
    class << self
      # Method called when a visual gets mocked (through extend)
      # @param mod [Battle::Visual]
      def extended(mod)
        mod.instance_variable_set(:@screenshot, nil)
        mod.instance_variable_set(:@viewport, nil)
        mod.instance_variable_set(:@viewport_sub, nil)
        mod.instance_variable_set(:@battlers, {})
        mod.instance_variable_set(:@info_bars, {})
        mod.instance_variable_set(:@team_info, {})
        mod.instance_variable_set(:@ability_bars, {})
        mod.instance_variable_set(:@item_bars, {})
        mod.instance_variable_set(:@item_bars, {})
        mod.instance_variable_set(:@animations, [])
        mod.instance_variable_set(:@animatable, [])
        mod.instance_variable_set(:@parallel_animations, {})
        mod.instance_variable_set(:@to_dispose, [])
        mod.instance_variable_set(:@locking, false)
      end
    end
    # Lock the battle scene
    def lock
      if block_given?
        @locking = true
        yield
        return @locking = false
      end
    end
    # Show the ability animation
    # @param target [PFM::PokemonBattler]
    def show_ability(target)
      return
    end
    # Show the exp distribution
    # @param exp_data [Hash{ PFM::PokemonBattler => Integer }] info about experience each pokemon should receive
    def show_exp_distribution(exp_data)
      return
    end
    # Method that show the pokemon choice
    # @param forced [Boolean]
    # @return [PFM::PokemonBattler, nil]
    def show_pokemon_choice(forced = false)
      log_error("show_pokemon_choice was called inside mock by #{caller[0]}")
      return
    end
    # Show a dedicated animation
    # @param target [PFM::PokemonBattler]
    # @param id [Integer]
    def show_rmxp_animation(target, id)
      return
    end
    # Show the item user animation
    # @param target [PFM::PokemonBattler]
    def show_item(target)
      return
    end
    # Refresh a specific bar (when Pokemon loses HP or change state)
    # @param pokemon [PFM::PokemonBattler] the pokemon that was shown by the bar
    def refresh_info_bar(pokemon)
      return
    end
    # Show HP animations
    # @param targets [Array<PFM::PokemonBattler>]
    # @param hps [Array<Integer>]
    # @param effectiveness [Array<Integer, nil>]
    # @param messages [Proc] messages shown right before the post processing
    def show_hp_animations(targets, hps, effectiveness = [], &messages)
      return
    end
    # Show the pokemon switch form animation
    # @param target [PFM::PokemonBattler]
    def show_switch_form_animation(target)
      return
    end
    # Set the state info
    # @param state [Symbol] kind of state (:choice, :move, :move_animation)
    # @param pokemon [Array<PFM::PokemonBattler>] optional list of Pokemon to show (move)
    def set_info_state(state, pokemon = nil)
      return
    end
    # Wait for all animation to end (non parallel one)
    def wait_for_animation
      return
    end
    # Hide team info
    def hide_team_info
      return
    end
    # Make a move animation
    # @param user [PFM::PokemonBattler]
    # @param targets [Array<PFM::PokemonBattler>]
    # @param move [Battle::Move]
    def show_move_animation(user, targets, move)
      return
    end
  end
  # Module responsive of mocking the battle logic so nothing happen on the reality
  #
  # Note: super inside this script might call the original function
  module LogicMock
    class << self
      # Method called when a visual gets mocked (through extend)
      # @param mod [Battle::Logic]
      def extended(mod)
        mod.instance_variable_set(:@battle_info, mod.scene.battle_info)
        mod.instance_variable_set(:@messages, [])
        mod.instance_variable_set(:@actions, [])
        mod.instance_eval do
          @battlers.each do |battler_arr|
            battler_arr.map! do |battler|
              battler = battler.clone
              battler.instance_variable_set(:@scene, mod.scene)
              next(battler)
            end
          end
        end
        battlers = mod.instance_variable_get(:@battlers).flatten
        battlers.each do |battler|
          battler.instance_variable_set(:@effects, mock_effect_handler(battler.effects, battlers))
        end
        mod.instance_variable_set(:@terrain_effects, mock_effect_handler(mod.terrain_effects, battlers))
        mod.bank_effects.map { |effects| mock_effect_handler(effects, battlers) }
        mod.position_effects.each { |bank| bank&.map! { |effects| mock_effect_handler(effects, battlers) } }
        mod.instance_variable_set(:@evolve_request, [])
        mod.instance_variable_set(:@switch_request, [])
        mod.instance_variable_set(:@battle_result, -1)
        mod.instance_variable_set(:@env, Marshal.load(Marshal.dump($env)))
      end
      # Mock the effect handler
      # @param handler [Effects::EffectsHandler]
      # @param battlers [Array<PFM::PokemonBattler>]
      def mock_effect_handler(handler, battlers)
        handler = handler.clone
        effects = handler.instance_variable_get(:@effects).clone
        effects.map! do |effect|
          effect = effect.clone
          effect.instance_variables.each do |iv|
            obj = effect.instance_variable_get(iv)
            next unless obj.is_a?(PFM::PokemonBattler)
            obj = battlers.find { |battler| battler.original == obj.original }
            effect.instance_variable_set(iv, obj) if obj
          end
          next(effect)
        end
        handler.instance_variable_set(:@effects, effects)
        return handler
      end
    end
    # Get a new weather change handler
    # @return [Battle::Logic::WeatherChangeHandler]
    def weather_change_handler
      return Logic::WeatherChangeHandler.new(self, @scene, @env)
    end
    # Get a new field terrain change handler
    # @return [Battle::Logic::WeatherChangeHandler]
    def fterrain_change_handler
      return Logic::FTerrainChangeHandler.new(self, @scene, @env)
    end
    # Get the env object
    # @return [PFM::Environnement]
    attr_reader :env
  end
  # Module holding the whole AI code
  module AI
    # Base class of AI, it holds the most important data
    class Base
      include Hooks
      # Get the scene that initialized the AI
      # @return [Battle::Scene]
      attr_reader :scene
      # Get the bank the AI controls
      # @return [Integer]
      attr_reader :bank
      # Get the party the AI controls
      # @return [Integer]
      attr_reader :party_id
      @ai_class_by_level = {}
      # Create a new AI instance
      # @param scene [Battle::Scene] scene that hold the logic object
      # @param bank [Integer] bank where the AI acts
      # @param party_id [Integer] ID of the party the AI look for Pokemon info
      # @param level [Integer] level of tha AI
      def initialize(scene, bank, party_id, level)
        @scene = scene
        @bank = bank
        @party_id = party_id
        @level = level
        @move_heuristic_cache = Hash.new { |hash, key| hash[key] = MoveHeuristicBase.new(key.be_method, @level) }
        init_capability
      end
      # Get the action the AI wants to do
      # @return [Array<Actions::Base>]
      def trigger
        return controlled_pokemon.flat_map do |pokemon|
          effect = pokemon.effects.get(&:force_next_turn_action?)
          next(effect.make_action) if effect
          battle_action_for(pokemon)
        end.compact
      end
      class << self
        # Register a new AI
        # @param level [Integer] level of the AI
        # @param klass [Class<Base>]
        def register(level, klass)
          @ai_class_by_level[level] = klass
        end
        # Get a registered AI
        # @param level [Integer] level of the AI
        # @return [Class<Battle::AI::Base>]
        def registered(level)
          @ai_class_by_level[level] || Base
        end
      end
      # Get all Pokemon in the party of the AI
      # @return [Array<PFM::PokemonBattler>]
      def party
        @scene.logic.all_battlers.select { |battler| battler.bank == @bank && battler.party_id == @party_id }
      end
      # Get all the controlled Pokemon
      # @return [Array<PFM::PokemonBattler>]
      def controlled_pokemon
        0.upto(@scene.battle_info.vs_type - 1).map { |i| @scene.logic.battler(@bank, i) }.compact.select { |battler| battler.party_id == @party_id }
      end
      private
      # Try to find the battle action for a dedicated pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Actions::Base, Array<Actions::Base>]
      # @note Actions are internally structured this way in the action array: [heuristic, action]
      def battle_action_for(pokemon)
        actions = usable_moves(pokemon).map { |move| move_action_for(move, pokemon) }
        move_heuristics = actions.compact.map(&:first)
        mega = mega_evolve_action_for(pokemon) if @can_mega_evolve
        force_switch = move_heuristics.all? { |heuristic| heuristic == 0 }
        actions.concat(clean_switch_trigger_actions(switch_actions_for(pokemon, move_heuristics), force_switch)) if @can_switch
        actions.concat(item_actions_for(pokemon, move_heuristics)) if @can_use_item
        actions.concat([flee_action_for(pokemon)].compact) if @can_flee
        exec_hooks(Base, :battle_action_for, binding)
        final_action = actions.compact.shuffle(random: @scene.logic.generic_rng).max_by(&:first)&.last
        mega = nil if final_action.is_a?(Actions::Switch)
        return mega ? [mega, final_action] : final_action
      end
      # Function that returns a mocked version of the scene
      # @return [Battle::Scene<Battle::SceneMock>]
      def mocked_scene
        @scene.clone.extend(SceneMock)
      end
      # Function responsive of initializing all the IA capatibility flags
      def init_capability
        @can_see_effectiveness = false
        @can_see_power = false
        @can_see_move_kind = false
        @can_switch = false
        @can_use_item = false
        @can_heal = false
        @can_choose_target = false
        @can_flee = false
        @can_read_opponent_movepool = false
        @can_mega_evolve = false
        @heal_threshold = 0.1
      end
      # Get all the move the pokemon can use
      # @param pokemon [PFM::PokemonBattler]
      # @return [Array<Battle::Move>]
      def usable_moves(pokemon)
        moves = pokemon.moveset.reject { |move| move_unusable?(pokemon, move) }
        return moves if moves.any?
        return [Battle::Move[:s_struggle].new(data_move(:struggle).id, 1, 1, @scene)]
      end
      # Function that check if the move is not usable
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Boolean] if the move should be rejeced from the moveset
      def move_unusable?(pokemon, move)
        return true if move.pp == 0
        return true if move.disable_reason(pokemon)
        return true if move.instance_of?(Battle::Move)
        return true if pokemon.effects.has?(&:force_next_move?) && pokemon.effects.get(&:force_next_move?).move != move
        return move.status? && pokemon.effects.has?(:oblivious)
      end
      public
      private
      # Get the move heuristic for a move
      # @param move [Battle::Move]
      # @return [AI::MoveHeuristicBase]
      def move_heuristic_object(move)
        @move_heuristic_cache[move]
      end
      # List all the possible action for a move
      # @param move [Battle::Move]
      # @param pokemon [PFM::PokemonBattler]
      # @return [Array<[Float, Battle::Actions::Base]>]
      def move_action_for(move, pokemon)
        action_class = (effect = pokemon.effects.get(&:force_next_move?)) ? effect.action_class : Actions::Attack
        targets = filter_targets(move.battler_targets(pokemon, @scene.logic), pokemon, move)
        actions = targets.map do |battler|
          [move_heuristic(move, pokemon, battler), action_class.new(@scene, move, pokemon, battler.bank, battler.position)]
        end
        actions = group_move_action(actions) unless move.one_target?
        return actions.shuffle(random: @scene.logic.generic_rng).max_by(&:first)
      end
      # Process the move heuristic
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Float]
      def move_heuristic(move, user, target)
        heuristic = 1.0
        move_heuristic = move_heuristic_object(move)
        effectiveness = @can_see_effectiveness && !move_heuristic.ignore_effectiveness? ? move_effectiveness(move, user, target) : 1.0
        heuristic *= move_power(move, user, target, effectiveness) if @can_see_power && !move_heuristic.ignore_power?
        heuristic *= move_heuristic.compute(move, user, target, self) if @can_see_move_kind || move_heuristic.overwrite_move_kind_flag?
        heuristic *= move_status_modifier(move, user, target)
        return heuristic
      end
      # Process the move effectiveness
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Float]
      def move_effectiveness(move, user, target)
        effectiveness = Math.sqrt(move.calc_stab(user, move.definitive_types(user, target)) * move.type_modifier(user, target))
        return effectiveness == 0 ? 0 : 1.0 if move.status?
        return effectiveness
      end
      # Process the move power
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param effectiveness [Float]
      # @return [Float]
      def move_power(move, user, target, effectiveness)
        return 0 if effectiveness == 0
        if move.status?
          return effectiveness if move.respond_to?(:special_ai_modifier) && @can_see_move_kind
          return Math.exp((user.last_sent_turn - $game_temp.battle_turn + 1) / 10.0) * effectiveness * 0.85
        end
        return 0.75 + move.real_base_power(user, target) * effectiveness / 4000
      end
      # Process the move status modifier
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Float]
      def move_status_modifier(move, user, target)
        result = 1.0
        return result if move.status_effects.empty?
        result = 0 if move.status? && move.status_effects.any? { |status| Configs.states.ids[status.status] == target.status }
        move_status = move.status_effects.first.status
        result = 0 if !@scene.logic.status_change_handler.status_appliable?(move_status, target, user, move) && @can_switch
        return result
      end
      # Group the move actions when they're hitting several targets
      # @param actions [Array]
      # @return [Array]
      def group_move_action(actions)
        return actions if actions.empty?
        action = actions.first.last
        heuristic = actions.reduce(0) { |sum, curr| sum + curr.first } / actions.size
        return [[heuristic, action]]
      end
      # Filter the target a move can aim
      # @param targets [Array<PFM::PokemonBattler>]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Array<PFM::PokemonBattler>]
      def filter_targets(targets, pokemon, move)
        alive_targets = targets.select(&:alive?)
        return [alive_targets.sample || targets.sample(random: @scene.logic.generic_rng)].compact if move.target == :random_foe
        return targets if move.no_choice_skill? || !move.one_target?
        no_bank_target = alive_targets.reject { |battler| battler.bank == @bank }
        if @can_choose_target
          return no_bank_target.empty? ? targets : no_bank_target
        else
          return [(no_bank_target.empty? ? targets : no_bank_target).sample(random: @scene.logic.generic_rng)].compact
        end
      end
      public
      private
      # Find the mega evolve actions for the said Pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Actions::Mega]
      def mega_evolve_action_for(pokemon)
        return nil unless @scene.logic.mega_evolve.can_pokemon_mega_evolve?(pokemon)
        return Actions::Mega.new(@scene, pokemon)
      end
      public
      # Function returning pokemon to switch with on request
      # @param who [PFM::PokemonBattler]
      # @return [PFM::PokemonBattler, nil]
      def request_switch(who)
        actions = clean_switch_actions(switch_actions_generate_for(who))
        return nil if actions.empty?
        best = actions.compact.shuffle(random: @scene.logic.generic_rng).max_by(&:first)
        Debug::AiWindow.append(self, actions.compact) if defined?(Debug::AiWindow)
        return best.last.with
      end
      private
      # Generate the switch action for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @param move_heuristics [Array<Float>]
      # @return [Array<[Float, Actions::Switch]>]
      def switch_actions_for(pokemon, move_heuristics)
        return [] unless @scene.logic.switch_handler.can_switch?(pokemon)
        danger_factor = switch_danger_processing(pokemon)
        return [] if (move_heuristics.max || 0) > danger_factor
        return switch_actions_generate_for(pokemon)
      end
      # Function that clean the switch action:
      #  - Exclude duplicate switch in action
      #  - Ensure a Pokemon that is already on the field cannot get in the field
      # @param actions [Array<[Float, Actions::Switch]>]
      # @return [Array<[Float, Actions::Switch]>]
      def clean_switch_actions(actions)
        pokemon_in_field = @scene.logic.all_alive_battlers
        actions = actions.reject { |action| pokemon_in_field.include?(Actions::Switch.from(action[1]).with) }
        return actions.uniq { |action| action[1].with }
      end
      # Function that clean the switch action for AI trigger
      #  - Exclude duplicate switch in action
      #  - Ensure a Pokemon that is already on the field cannot get in the field
      #  - Remove actions if the Pokemon was recently sent out and the random number was not less than 1
      # @param actions [Array<[Float, Actions::Switch]>]
      # @param force_switch [Boolean] if we ignore the fact switch can be performed or not and let the pokemon switch anyway
      # @return [Array<[Float, Actions::Switch]>]
      def clean_switch_trigger_actions(actions, force_switch = false)
        return clean_switch_actions(actions).select { |action| force_switch || can_switch_be_performed?(action[1]) }
      end
      # Function that tell if a Pokemon can be switched out based on the current turn & some random factor
      # @param action [Actions::Switch]
      # @return [Boolean]
      def can_switch_be_performed?(action)
        delta = ($game_temp.battle_turn - action.who.last_sent_turn).clamp(1, 5)
        return true if delta == 5
        rand_factor = (10 / (delta ** 1.2)).floor
        return @scene.logic.generic_rng.rand(rand_factor) < 1
      end
      # Generate the actual switch actions for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Array<[Float, Actions::Switch]>]
      def switch_actions_generate_for(pokemon)
        switchable = (party - [pokemon] - @scene.logic.allies_of(pokemon)).select(&:alive?)
        return switchable.map do |battler|
          damaging_move = usable_moves(battler).reject(&:status?)
          next([damaging_move.map { |move| move_action_for(move, battler) }.compact.map(&:first).max || 0, Actions::Switch.new(@scene, pokemon, battler)])
        end
      end
      # Get the danger factor of the Pokemon (depending on opponent)
      # @param pokemon [PFM::PokemonBattler]
      # @return [Float]
      def switch_danger_processing(pokemon)
        foe_moves = switch_opponent_moves(pokemon)
        foe_move_heuristics = foe_moves.map { |info| move_heuristic(info[:move], info[:foe], pokemon) }
        return foe_move_heuristics.max || @scene.logic.generic_rng.rand
      end
      # Get the opponent moves in order to choose if we switch or not
      # @param pokemon [PFM::PokemonBattler]
      # @return [Array<{ foe: PFM::PokemonBattler, move: Battle::Move }>]
      def switch_opponent_moves(pokemon)
        return [] unless @can_read_opponent_movepool
        return @scene.logic.foes_of(pokemon).flat_map do |foe|
          foe.move_history.map(&:move).uniq(&:db_symbol).map do |move|
            {foe: foe, move: move}
          end
        end
      end
      public
      # List of boosting items
      BOOSTING_ITEMS = %i[x_attack x_sp_atk x_speed x_defense x_sp_def]
      # List of healing items
      HEALING_ITEMS = %i[full_restore hyper_potion energy_root moomoo_milk lemonade super_potion energy_powder soda_pop fresh_water potion berry_juice sweet_heart sitrus_berry oran_berry]
      # List of item that heal from poison
      POISON_HEAL_ITEMS = %i[antidote full_heal heal_powder lava_cookie old_gateau pecha_berry lum_berry casteliacone lumiose_galette shalour_sable]
      # List of item that heals from burn state
      BURN_HEAL_ITEMS = %i[burn_heal full_heal heal_powder lava_cookie old_gateau rawst_berry lum_berry casteliacone lumiose_galette shalour_sable]
      # List of item that heals from paralysis
      PARALYZE_HEAL_ITEMS = %i[paralyze_heal full_heal heal_powder lava_cookie old_gateau cheri_berry lum_berry casteliacone lumiose_galette shalour_sable]
      # List of item that heals from frozen state
      FREEZE_HEAL_ITEMS = %i[ice_heal full_heal heal_powder lava_cookie old_gateau aspear_berry lum_berry casteliacone lumiose_galette shalour_sable]
      # List of item that wake the Pokemon up
      WAKE_UP_ITEMS = %i[awakening full_heal heal_powder lava_cookie old_gateau blue_flute chesto_berry lum_berry casteliacone lumiose_galette shalour_sable]
      private
      # Generate the item action for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @param move_heuristics [Array<Float>]
      # @return [Array<[Float, Actions::Item]>]
      def item_actions_for(pokemon, move_heuristics)
        actions = boost_item_actions_for(pokemon, move_heuristics)
        actions.concat(heal_item_actions_for(pokemon, move_heuristics)) if @can_heal && pokemon.hp_rate <= @heal_threshold && !pokemon.dead?
        actions.concat(status_heal_item_actions_for(pokemon, move_heuristics)) if @can_heal && pokemon.status != 0
        return actions
      end
      # Generate the boost item action for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @param move_heuristics [Array<Float>]
      # @return [Array<[Float, Actions::Item]>]
      def boost_item_actions_for(pokemon, move_heuristics)
        interest_factor = boost_item_interest_factor_for(pokemon)
        BOOSTING_ITEMS.select { |item| pokemon.bag.contain_item?(item) }.map do |item|
          wrapper = PFM::ItemDescriptor.actions(item)
          if wrapper.on_creature_choice(pokemon, @scene)
            wrapper.bind(@scene, pokemon)
            next([interest_factor, Actions::Item.new(@scene, wrapper, pokemon.bag, pokemon)])
          else
            next(nil)
          end
        end.compact
      end
      # Get the boost item interest factor
      # @param pokemon [PFM::PokemonBattler]
      # @return [Float]
      def boost_item_interest_factor_for(pokemon)
        Math.exp((pokemon.last_sent_turn - $game_temp.battle_turn + 1) / 10.0) * 0.85
      end
      # Generate the heal item action for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @param move_heuristics [Array<Float>]
      # @return [Array<[Float, Actions::Item]>]
      def heal_item_actions_for(pokemon, move_heuristics)
        HEALING_ITEMS.select { |item| pokemon.bag.contain_item?(item) }.map do |item|
          wrapper = PFM::ItemDescriptor.actions(item)
          wrapper.bind(@scene, pokemon)
          factor = (wrapper.item.is_a?(Studio::ConstantHealItem) ? wrapper.item.hp_count.to_f / pokemon.max_hp : wrapper.item.hp_rate) * 2.0
          next([factor, Actions::Item.new(@scene, wrapper, pokemon.bag, pokemon)])
        end.compact
      end
      # Generate the heal item action for the pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @param move_heuristics [Array<Float>]
      # @return [Array<[Float, Actions::Item]>]
      def status_heal_item_actions_for(pokemon, move_heuristics)
        if pokemon.burn?
          items = BURN_HEAL_ITEMS
          rate = 1 - pokemon.hp_rate / 4
        else
          if pokemon.poisoned? || pokemon.toxic?
            items = POISON_HEAL_ITEMS
            rate = 1 - pokemon.hp_rate / 4
          else
            if pokemon.paralyzed?
              items = PARALYZE_HEAL_ITEMS
              rate = 0.78
            else
              if pokemon.frozen?
                items = FREEZE_HEAL_ITEMS
                rate = 0.85
              else
                if pokemon.asleep?
                  items = WAKE_UP_ITEMS
                  rate = 0.76
                end
              end
            end
          end
        end
        return items.select { |item| pokemon.bag.contain_item?(item) }.map do |item|
          wrapper = PFM::ItemDescriptor.actions(item)
          wrapper.bind(@scene, pokemon)
          next([rate, Actions::Item.new(@scene, wrapper, pokemon.bag, pokemon)])
        end.compact
      end
      public
      private
      # Find the mega evolve actions for the said Pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Array<[Float, Actions::Flee]>, nil]
      def flee_action_for(pokemon)
        return nil unless @scene.logic.switch_handler.can_switch?(pokemon)
        return [Float::INFINITY, Actions::Flee.new(@scene, pokemon)]
      end
    end
    # AI corresponding to the wild Pokemon
    class Wild < Base
      Base.register(0, self)
    end
    # AI corresponding to the youngster & similar trainers (base money < 20)
    class TrainerLv1 < Base
      private
      def init_capability
        super
        @can_see_power = true
      end
      Base.register(1, self)
    end
    # AI corresponding to the bird keeper (base money < 36)
    class TrainerLv2 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
      end
      Base.register(2, self)
    end
    # AI coreresponding to sailor (base money < 48)
    class TrainerLv3 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
        @can_see_move_kind = true
      end
      Base.register(3, self)
    end
    # AI corresponding to gambler (base money < 80)
    class TrainerLv4 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
        @can_see_move_kind = true
        @can_mega_evolve = true
        @can_switch = true
        @can_use_item = true
      end
      Base.register(4, self)
    end
    # AI corresponding to Boss (base money < 100)
    class TrainerLv5 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
        @can_see_move_kind = true
        @can_mega_evolve = true
        @can_switch = true
        @can_use_item = true
        @can_choose_target = true
      end
      Base.register(5, self)
    end
    # AI corresponding to rival, gym leader, elite four (base money < 200)
    class TrainerLv6 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
        @can_see_move_kind = true
        @can_mega_evolve = true
        @can_switch = true
        @can_use_item = true
        @can_choose_target = true
        @can_heal = true
      end
      Base.register(6, self)
    end
    # AI corresponding to champion (base money >= 200)
    class TrainerLv7 < Base
      private
      def init_capability
        super
        @can_see_effectiveness = true
        @can_see_power = true
        @can_see_move_kind = true
        @can_mega_evolve = true
        @can_switch = true
        @can_use_item = true
        @can_choose_target = true
        @can_heal = true
        @can_read_opponent_movepool = true
      end
      Base.register(7, self)
    end
    # AI corresponding to roaming Pokemon
    class RoamingWild < TrainerLv3
      private
      def init_capability
        super
        @can_flee = true
      end
      Base.register(-1, self)
    end
  end
end
