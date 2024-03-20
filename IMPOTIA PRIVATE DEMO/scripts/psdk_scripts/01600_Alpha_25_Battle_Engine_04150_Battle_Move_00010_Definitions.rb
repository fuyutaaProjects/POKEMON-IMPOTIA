module Battle
  class Move
    # Moves that change the ability of a Pokémon
    # Template = Role Play
    class AbilityChanging < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if targets.empty?
        unless @logic.ability_change_handler.can_change_ability?(user, ability_symbol(user, targets.first), user, self)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless @logic.ability_change_handler.can_change_ability?(user, ability_symbol(user, target), user, self)
          @scene.visual.show_ability(user)
          @scene.visual.wait_for_animation
          @logic.ability_change_handler.change_ability(user, ability_symbol(user, target), user, self)
          @scene.visual.show_ability(user)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 619, user, PFM::Text::ABILITY[2] => target.ability_name, PFM::Text::PKNICK[1] => target.given_name))
        end
      end
      # Function that returns the ability which will assigned to the target
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      def ability_symbol(user, target)
        return target.ability_db_symbol
      end
    end
    # Role Play move
    class Entrainment < AbilityChanging
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        can_change_ability = targets.any? do |target|
          @logic.ability_change_handler.can_change_ability?(target, ability_symbol(user, target), user, self) && target.ability_db_symbol != ability_symbol(user, target)
        end
        unless can_change_ability
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless @logic.ability_change_handler.can_change_ability?(target, ability_symbol(user, target), user, self)
          @scene.visual.show_ability(target)
          @scene.visual.wait_for_animation
          @logic.ability_change_handler.change_ability(target, ability_symbol(user, target), user, self)
          @scene.visual.show_ability(target)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 405, target, PFM::Text::ABILITY[1] => target.ability_name))
        end
      end
    end
    # Simple Beam move
    class SimpleBeam < Entrainment
      # Function that returns the ability which will assigned to the target
      def ability_symbol(user, target)
        return :simple
      end
    end
    # Worry Seed move
    class WorrySeed < Entrainment
      # Function that returns the ability which will assigned to the target
      def ability_symbol(user, target)
        return :insomnia
      end
    end
    # Skill Swap move
    # Move that exchanges ability between user and target
    class AbilitySwap < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if targets.empty?
        unless @logic.ability_change_handler.can_change_ability?(user, targets.first.ability_db_symbol, user, self) && @logic.ability_change_handler.can_change_ability?(targets.first, user.ability_db_symbol, user, self)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless @logic.ability_change_handler.can_change_ability?(user, target.ability_db_symbol, user, self) && @logic.ability_change_handler.can_change_ability?(target, user.ability_db_symbol, user, self)
          @scene.visual.show_ability(user)
          @scene.visual.show_ability(target)
          @scene.visual.wait_for_animation
          user_ability = user.ability_db_symbol
          @logic.ability_change_handler.change_ability(user, target.ability_db_symbol, user, self)
          @logic.ability_change_handler.change_ability(target, user_ability, user, self)
          @scene.visual.show_ability(user)
          @scene.visual.show_ability(target)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 508, user))
        end
      end
    end
    Move.register(:s_entrainment, Entrainment)
    Move.register(:s_simple_beam, SimpleBeam)
    Move.register(:s_skill_swap, AbilitySwap)
    Move.register(:s_role_play, AbilityChanging)
    Move.register(:s_worry_seed, WorrySeed)
    # Class describing a move that drains HP
    class Absorb < Move
      # don't forget to add a "x.0" if the factor is a float, or it will be converted to 1 (= 100% damage-to-heal conversion)
      DRAIN_FACTORS = {draining_kiss: 4 / 3.0, oblivion_wing: 4 / 3.0}
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false if target.has_ability?(:comatose) && be_method == :s_dream_eater
        return true if !target.asleep? && be_method == :s_dream_eater
        return super
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return true if status?
        raise 'Badly configured move, it should have positive power' if power < 0
        actual_targets.each do |target|
          hp = damages(user, target)
          @logic.damage_handler.drain_with_process(hp, target, user, self, hp_overwrite: hp, drain_factor: drain_factor) do
            if critical_hit?
              scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
            else
              if hp > 0
                efficent_message(effectiveness, target)
              end
            end
          end
          recoil(hp, user) if recoil?
        end
        return true
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        if user.effects.has?(:heal_block)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 893, user, '[VAR PKNICK(0000)]' => user.given_name, '[VAR MOVE(0001)]' => name))
          return false
        end
        return true if super
      end
      # Tell that the move is a drain move
      # @return [Boolean]
      def drain?
        return true
      end
      # Returns the drain factor
      # @return [Integer]
      def drain_factor
        DRAIN_FACTORS[db_symbol] || super
      end
    end
    Move.register(:s_absorb, Absorb)
    Move.register(:s_dream_eater, Absorb)
    # Class managing Acrobatics move
    class Acrobatics < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return power * 2 if user.item_effect.is_a?(Battle::Effects::Item::Gems) && user.item_consumed
        return power * 2 unless user.item_db_symbol != :__undef__
        return super
      end
    end
    Move.register(:s_acrobatics, Acrobatics)
    # Class that manage the Acupressure move
    # @see https://bulbapedia.bulbagarden.net/wiki/Acupressure_(move)
    # @see https://pokemondb.net/move/acupressure
    # @see https://www.pokepedia.fr/Acupression
    class Acupressure < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        map_stages_id(user, targets)
        return show_usage_failure(user) && false if @stages_ids.empty?
        return true
      end
      # All the stages that the move can modify
      # @return [Array[Symbol]]
      def stages
        Logic::StatChangeHandler::ALL_STATS
      end
      # Map the stages ids of each target
      def map_stages_id(user, targets)
        select_stage = -> (target) { (Logic::StatChangeHandler::ALL_STATS.select { |s| @logic.stat_change_handler.stat_increasable?(s, target, user, self) }).sample(random: @logic.generic_rng) }
        @stages_ids = targets.map { |target| [target, select_stage.call(target)] }.to_h.compact
      end
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        if @stages_ids.nil?
          map_stages_id(user, actual_targets)
          return show_usage_failure(user) if @stages_ids.nil? || @stages_ids&.empty?
        end
        actual_targets.each do |target|
          next unless @stages_ids[target]
          @logic.stat_change_handler.stat_change(@stages_ids[target], 2, target, user, self)
        end
      end
    end
    Move.register(:s_acupressure, Acupressure)
    # Move that give a third type to an enemy
    class AddThirdType < Move
      TYPES = {trick_or_treat: :ghost, forest_s_curse: :grass}
      TYPES.default = :normal
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.send(:"type_#{TYPES[db_symbol]}?")
        return true if target.has_ability?(:multitype) || target.has_ability?(:rks_system)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.type3 = new_type
          scene.display_message_and_wait(message(target))
        end
      end
      # Get the type given by the move
      # @return [Integer] the ID of the Type given by the move
      def new_type
        return data_type(TYPES[db_symbol] || 0).id
      end
      # Get the message text
      # @return [String]
      def message(target)
        return parse_text_with_pokemon(19, 902, target, '[VAR TYPE(0001)]' => data_type(new_type).name)
      end
    end
    Move.register(:s_add_type, AddThirdType)
    # Me First move
    class AfterYou < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || logic.battler_attacks_after?(user, targets.first)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        attacks = logic.actions.select { |action| action.is_a?(Actions::Attack) }
        target_action = attacks.find { |action| action.launcher == target }
        return unless target_action
        logic.actions.delete(target_action)
        logic.actions << target_action
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1140, target))
      end
    end
    Move.register(:s_after_you, AfterYou)
    # Class managing the Aqua Ring move
    class AquaRing < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.all? { |target| target.effects.has?(:aqua_ring) }
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:aqua_ring)
          target.effects.add(Effects::AquaRing.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 601, target))
        end
      end
    end
    Move.register(:s_aqua_ring, AquaRing)
    # Assist move
    class Assist < Move
      CANNOT_BE_SELECTED_MOVES = %i[assist baneful_bunker beak_blast belch bestow bounce celebrate chatter circle_throw copycat counter covet destiny_bound detect dig dive dragon_tail endure feint fly focus_punch follow_me helping_hand hold_hands king_s_shield mat_block me_first metronome mimic mirror_coat mirror_move nature_power phantom_force protect rage_powder roar shadow_force shell_trap sketch sky_drop sleep_talk snatch spiky_shield spotlight struggle switcheroo thief transform trick whirlwind]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if usable_moves(user).empty?
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        skill = usable_moves(user).sample(random: @logic.generic_rng)
        move = Battle::Move[skill.be_method].new(skill.id, 1, 1, @scene)
        def move.move_usable_by_user(user, targets)
          return true
        end
        use_another_move(move, user)
      end
      # Function that list all the moves the user can pick
      # @param user [PFM::PokemonBattler]
      # @return [Array<Battle::Move>]
      def usable_moves(user)
        team = @logic.trainer_battlers.reject { |pkm| pkm == user }
        skills = team.flat_map(&:moveset).uniq(&:db_symbol)
        skills.reject! { |move| CANNOT_BE_SELECTED_MOVES.include?(move.db_symbol) }
        return skills
      end
    end
    Move.register(:s_assist, Assist)
    # Class that manage Assurance move
    # @see https://bulbapedia.bulbagarden.net/wiki/Assurance_(move)
    # @see https://pokemondb.net/move/Assurance
    # @see https://www.pokepedia.fr/Assurance
    class Assurance < Basic
      # Base power calculation
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def calc_base_power(user, target)
        result = super
        damage_took = target.damage_history.any?(&:current_turn?)
        log_data("power = #{result * (damage_took ? 2 : 1)} \# after Move::Assurance calc")
        return result * (damage_took ? 2 : 1)
      end
    end
    Move.register(:s_assurance, Assurance)
    # Move that inflict attract effect to the ennemy
    class Attract < Move
      private
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[oblivious aroma_veil]
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:attract) || (user.gender * target.gender) != 2
        ally = @logic.allies_of(target).find { |a| BLOCKING_ABILITY.include?(a.battle_ability_db_symbol) }
        if target.hold_item?(:mental_herb)
          @logic.item_change_handler.change_item(:none, true, target)
          return true
        else
          if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
            @scene.visual.show_ability(target)
            return true
          else
            if user.can_be_lowered_or_canceled? && ally
              @scene.visual.show_ability(ally)
              return true
            end
          end
        end
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::Attract.new(@logic, target, user))
          user.effects.add(Effects::Attract.new(@logic, user, target)) if target.hold_item?(:destiny_knot)
        end
      end
    end
    Move.register(:s_attract, Attract)
    class AuraWheel < SelfStat
      # Hash containing each valid user and the move's type depending on the form
      # @return [Hash{Symbol => Hash}]
      VALID_USER = Hash.new
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless VALID_USER[user.db_symbol]
        return true
      end
      # Get the types of the move with 1st type being affected by effects
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Array<Integer>] list of types of the move
      def definitive_types(user, target)
        return [data_type(VALID_USER[user.db_symbol][user.form]).id]
      end
      class << self
        # Register a valid user for this move
        # @param creature_db_symbol [Symbol] db_symbol of the new valid user
        # @param forms_and_types [Array<Array>] the array containing the informations
        # @param default [Symbol] db_symbol of the type by default for this user
        # @example : register_valid_user(:pikachu, [0, :electrik], [1, :psychic], [2, :fire], default: :electrik)
        # This will let Pikachu use the move, its form 0 will make the move Electrik type, form 1 Psychic type, its form 2 Fire type
        # and any other form will have Electrik type by default
        def register_valid_user(creature_db_symbol, *forms_and_types, default: nil)
          VALID_USER[creature_db_symbol] = forms_and_types.to_h
          VALID_USER[creature_db_symbol].default = default || forms_and_types.to_h.first[1]
        end
      end
      register_valid_user(:morpeko, [0, :electric], [1, :dark], default: :electrik)
    end
    Move.register(:s_aura_wheel, AuraWheel)
    # Move that inflict Autotomize to the enemy bank
    class Autotomize < Move
      private
      MODIFIERS = %i[atk_stage dfe_stage ats_stage dfs_stage spd_stage eva_stage acc_stage]
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        target_stats_before = actual_targets.map { |target| [target, MODIFIERS.map { |stat| target.send(stat) }] }.to_h
        result = super
        actual_targets.select! { |target| target_stats_before[target] != MODIFIERS.map { |stat| target.send(stat) } }
        return result && !actual_targets.empty?
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          if (effect = target.effects.get(:autotomize))
            effect.launch_effect(self)
          else
            target.effects.add(Effects::Autotomize.new(@logic, target, self))
          end
        end
      end
    end
    Move.register(:s_autotomize, Autotomize)
    # Class that manage Avalanche move
    # @see https://bulbapedia.bulbagarden.net/wiki/Avalanche_(move)
    # @see https://pokemondb.net/move/avalanche
    # @see https://www.pokepedia.fr/Avalanche
    class Avalanche < Basic
      # Base power calculation
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def calc_base_power(user, target)
        result = super
        damage_took = user.damage_history.any? { |dh| dh.current_turn? && dh.launcher == target }
        log_data("power = #{result * (damage_took ? 2 : 1)} \# after Move::Avalanche calc")
        return result * (damage_took ? 2 : 1)
      end
    end
    Move.register(:s_avalanche, Avalanche)
    # Baton Pass causes the user to switch out for another Pokémon, passing any stat changes to the Pokémon that switches in.
    # @see https://pokemondb.net/move/baton-pass
    # @see https://bulbapedia.bulbagarden.net/wiki/Baton_Pass_(move)
    # @see https://www.pokepedia.fr/Relais
    class BatonPass < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        switchable_allies = logic.alive_battlers_without_check(user.bank).count { |pokemon| pokemon != user && pokemon.party_id == user.party_id }
        return show_usage_failure(user) && false unless switchable_allies > 0
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Battle::Effects::BatonPass.new(logic, target))
          logic.request_switch(target, nil)
        end
      end
    end
    Move.register(:s_baton_pass, BatonPass)
    # Implement the Beak Blast move
    class BeakBlast < Basic
      # Is the move doing something before any other attack ?
      # @return [Boolean]
      def pre_attack?
        true
      end
      # Proceed the procedure before any other attack.
      # @param user [PFM::PokemonBattler]
      def proceed_pre_attack(user)
        return unless can_pre_use_move?(user)
        @scene.display_message_and_wait(parse_text_with_pokemon(59, 1880, user))
        user.effects.add(Effects::BeakBlast.new(@logic, user))
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless @enabled
        return true
      end
      private
      # Check if the user is able to display the message related to the move
      # @param user [PFM::PokemonBattler]
      def can_pre_use_move?(user)
        @enabled = false
        return false if (user.frozen? || user.asleep?)
        @enabled = true
        return true
      end
    end
    Move.register(:s_beak_blast, BeakBlast)
    # Class that manage the move Beat Up
    # Beat Up inflicts damage on the target from the user, and each conscious Pokémon in the user's party that does not have a non-volatile status.
    # @see https://bulbapedia.bulbagarden.net/wiki/Beat_Up_(move)
    # @see https://pokemondb.net/move/beat-up
    # @see https://www.pokepedia.fr/Baston
    class BeatUp < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if (@bu_battlers = battlers_that_hit(user)).empty?
        return true
      end
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        unless @bu_current_battler
          bu_power = 0
          @logic.all_battlers do |battler|
            bu_power += (battler.atk_basis / 10 + 5).ceil if battler.bank == user.bank
          end
          return bu_power
        end
        bu_power = (@bu_current_battler.atk_basis / 10 + 5).ceil
        log_data('power = %i # BeatUp from %s on %s (through %s)' % [bu_power, @bu_current_battler.name, target.name, user.name])
        return bu_power
      end
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        nb_hit = @bu_battlers.size.times.count do |i|
          next(false) unless actual_targets.any?(&:alive?)
          play_animation(user, actual_targets) if i > 0
          @bu_current_battler = @bu_battlers[i]
          actual_targets.each do |target|
            next if target.dead?
            deal_damage_to_target(user, actual_targets, target)
          end
        end
        final_message(nb_hit)
      end
      # Function that deal the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @param target [PFM::PokemonBattler] the current target
      def deal_damage_to_target(user, actual_targets, target)
        hp = damages(user, target)
        @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
          if critical_hit?
            critical_hit_message(target, actual_targets, target)
          else
            if hp > 0 && target == actual_targets.last
              efficent_message(effectiveness, target)
            end
          end
        end
        recoil(hp, user) if recoil?
      end
      # Function that retrieve the battlers that hit the targets
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Array[PFM::Battler]]
      def battlers_that_hit(user)
        logic.alive_battlers_without_check(user.bank)
      end
      # Display the right message in case of critical hit
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @param target [PFM::PokemonBattler] the current target
      # @return [String]
      def critical_hit_message(user, actual_targets, target)
        scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
      end
      # Display the message after all the hit have been performed
      # @param nb_hit [Integer] amount of hit performed
      def final_message(nb_hit)
        @scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => nb_hit.to_s))
      end
    end
    Move.register(:s_beat_up, BeatUp)
    # Class managing the Pluck move
    class Belch < Basic
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return true if user.item_consumed && Effects::Item.new(logic, user, user.consumed_item).is_a?(Effects::Item::Berry)
        show_usage_failure(user)
        return false
      end
    end
    Move.register(:s_belch, Belch)
    class BellyDrum < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        can_change_atk = logic.stat_change_handler.stat_increasable?(:atk, user)
        if user.hp_rate < 0.51 || !can_change_atk
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        hp = (user.max_hp / 2).floor
        scene.visual.show_hp_animations([user], [-hp])
        scene.display_message_and_wait(parse_text_with_pokemon(19, 613, user))
        logic.stat_change_handler.stat_change_with_process(:atk, 12, user)
      end
    end
    Move.register(:s_bellydrum, BellyDrum)
    class Bestow < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless logic.item_change_handler.can_give_item?(user, targets.first)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        item = user.battle_item_db_symbol
        item_name = user.item_name
        logic.item_change_handler.change_item(item, true, target, user, self)
        logic.item_change_handler.change_item(:none, true, user, user, self)
        logic.terrain_effects.add(Battle::Effects::Bestow.new(logic, user, target, item))
        logic.scene.display_message_and_wait(give_text(target, user, item_name))
      end
      # Get the text displayed when the user gives its item to the target
      # @param target [Array<PFM::PokemonBattler>]
      # @param user [PFM::PokemonBattler] user of the move
      # @param item [String] the name of the item
      # @return [String] the text to display
      def give_text(target, user, item)
        return parse_text_with_2pokemon(19, 1117, target, user, PFM::Text::ITEM2[2] => item)
      end
    end
    Move.register(:s_bestow, Bestow)
    # Bide Move
    class Bide < BasicWithSuccessfulEffect
      # Get the types of the move with 1st type being affected by effects
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Array<Integer>] list of types of the move
      def definitive_types(user, target)
        [0]
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return super if user.effects.get(:bide)&.unleach?
        return true
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if user.effects.get(:bide)&.unleach? && user.effects.get(:bide).damages == 0
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return if user.effects.has?(:bide)
        user.effects.add(Effects::Bide.new(logic, user, self, actual_targets, 3))
      end
      # Method calculating the damages done by counter
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        effect = user.effects.get(:bide)
        return ((effect&.damages || 1) * 2).clamp(1, Float::INFINITY)
      end
      # Method responsive testing accuracy and immunity.
      # It'll report the which pokemon evaded the move and which pokemon are immune to the move.
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Array<PFM::PokemonBattler>]
      def accuracy_immunity_test(user, targets)
        attackers = (logic.foes_of(user) + logic.allies_of(user)).sort { |a, b| b.attack_order <=> a.attack_order }
        attacker = attackers.find { |foe| foe.move_history.last&.targets&.include?(user) && foe.move_history.last.turn == $game_temp.battle_turn }
        return [attacker || logic.foes_of(user).sample(random: logic.generic_rng)]
      end
      # Play the move animation (only without all the decoration)
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def play_animation_internal(user, targets)
        super if user.effects.has?(:bide) && user.effects.get(:bide).unleach?
      end
      # Show the move usage message
      # @param user [PFM::PokemonBattler] user of the move
      def usage_message(user)
        if !user.effects.has?(:bide)
          super
        else
          if user.effects.get(:bide).unleach?
            return scene.display_message_and_wait(parse_text_with_pokemon(19, 748, user))
          end
        end
        scene.display_message_and_wait(parse_text_with_pokemon(19, 745, user))
      end
    end
    Move.register(:s_bide, Bide)
    # Move that binds the target to the field
    class Bind < Basic
      private
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        actual_targets.any? { |target| !target.effects.has?(:bind) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        turn_count = user.hold_item?(:grip_claw) ? 7 : logic.generic_rng.rand(4..5)
        actual_targets.each do |target|
          next if target.effects.has?(:bind)
          target.effects.add(Effects::Bind.new(logic, target, user, turn_count, self))
        end
      end
    end
    Move.register(:s_bind, Bind)
    # Move that deals damage from the user defense and not its attack statistics
    class BodyPress < Basic
      # Get the basis atk for the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_sp_atk_basis(user, target, ph_move)
        return user.dfe_basis
      end
      # Statistic modifier calculation: ATK/ATS
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_atk_stat_modifier(user, target, ph_move)
        return 1 if critical_hit?
        return user.dfe_modifier
      end
    end
    Move.register(:s_body_press, BodyPress)
    # Class managing Brick Break move
    class BrickBreak < BasicWithSuccessfulEffect
      private
      WALLS = %i[light_screen reflect aurora_veil]
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        @logic.bank_effects[bank].each do |effect|
          next unless WALLS.include?(effect.name)
          case effect.name
          when :reflect
            @scene.display_message_and_wait(parse_text(18, bank == 0 ? 132 : 133))
          when :light_screen
            @scene.display_message_and_wait(parse_text(18, bank == 0 ? 136 : 137))
          else
            @scene.display_message_and_wait(parse_text(18, bank == 0 ? 140 : 141))
          end
          log_info("PSDK Brick Break: #{effect.name} effect removed.")
          effect.kill
        end
      end
    end
    Move.register(:s_brick_break, BrickBreak)
    # Power doubles if opponent's HP is 50% or less.
    class Brine < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return target.hp <= (target.max_hp / 2) ? power * 2 : power
      end
    end
    Move.register(:s_brine, Brine)
    # Implement the Burn Up move
    class BurnUp < Basic
      # Text of the loss of our type after launching the attack
      TEXTS_IDS = {burn_up: [:parse_text_with_pokemon, 59, 1856]}
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless user.type?(type)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.add(Effects::BurnUp.new(@logic, user, turn_count, type))
        scene.display_message_and_wait(send(*TEXTS_IDS[db_symbol], user)) if TEXTS_IDS[db_symbol]
      end
      # Return the number of turns the effect works
      # @return Integer
      def turn_count
        return Float::INFINITY
      end
    end
    Move.register(:s_burn_up, BurnUp)
    # Camouflage causes the user to change its type based on the current terrain.
    # @see https://pokemondb.net/move/camouflage
    # @see https://bulbapedia.bulbagarden.net/wiki/Camouflage_(move)
    # @see https://www.pokepedia.fr/Camouflage
    class Camouflage < Move
      include Mechanics::LocationBased
      private
      # Play the move animation
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def play_animation(user, targets)
        super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        type = data_type(element_by_location).id
        actual_targets.each do |target|
          target.change_types(type)
          scene.display_message_and_wait(deal_message(user, target, type))
        end
      end
      def deal_message(user, target, type)
        parse_text_with_pokemon(19, 899, target, {'[VAR TYPE(0001)]' => data_type(type).name})
      end
      # Element by location type.
      # @return [Hash<Symbol, Array<Symbol>]
      def element_table
        TYPE_BY_LOCATION
      end
      class << self
        def reset
          const_set(:TYPE_BY_LOCATION, {})
        end
        def register(loc, type)
          TYPE_BY_LOCATION[loc] ||= []
          TYPE_BY_LOCATION[loc] << type
          TYPE_BY_LOCATION[loc].uniq!
        end
      end
      reset
      register(:__undef__, :normal)
      register(:regular_ground, :normal)
      register(:building, :normal)
      register(:grass, :grass)
      register(:desert, :ground)
      register(:cave, :rock)
      register(:water, :water)
      register(:shallow_water, :ground)
      register(:snow, :ice)
      register(:icy_cave, :ice)
      register(:volcanic, :fire)
      register(:burial, :ghost)
      register(:soaring, :flying)
      register(:misty_terrain, :fairy)
      register(:grassy_terrain, :grass)
      register(:electric_terrain, :electric)
      register(:psychic_terrain, :psychic)
      register(:space, :dragon)
      register(:ultra_space, :dragon)
    end
    register(:s_camouflage, Camouflage)
    # Move that binds the target to the field
    class CantSwitch < Basic
      private
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.all? { |target| !target.effects.has?(:cantswitch) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:cantswitch)
          target.effects.add(Effects::CantSwitch.new(logic, target, user, self))
          scene.display_message_and_wait(message(target))
        end
      end
      # Get the message text
      # @return [String]
      def message(target)
        return parse_text_with_pokemon(19, 875, target)
      end
    end
    Move.register(:s_cantflee, CantSwitch)
    # Class managing captivate move
    class Captivate < Move
      private
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[oblivious]
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if user.gender == target.gender || target.gender == 0
        if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
          @scene.visual.show_ability(target)
          return true
        end
        return super
      end
    end
    Move.register(:s_captivate, Captivate)
    # Move that give a third type to an enemy
    class ChangeType < Move
      TYPES = {soak: :water, magic_powder: :psychic}
      ABILITY_EXCEPTION = %i[multitype rks_system]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |t| t.effects.has?(:change_type) || condition(t) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:change_type) || condition(target)
          target.effects.add(Battle::Effects::ChangeType.new(logic, target, new_type))
          scene.display_message_and_wait(message(target))
        end
      end
      # Method that tells if the Move's effect can proceed
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def condition(target)
        return type_check(target) && target.type2 == 0 && target.type3 == 0 || ABILITY_EXCEPTION.include?(target.ability_db_symbol) || target.effects.has?(:substitute)
      end
      # Method that tells if the target already has the type
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def type_check(target)
        return target.type_water?
      end
      # Get the type given by the move
      # @return [Integer] the ID of the Type given by the move
      def new_type
        return data_type(TYPES[db_symbol] || 0).id
      end
      # Get the message text
      # @return [String]
      def message(target)
        return parse_text_with_pokemon(19, 899, target, '[VAR TYPE(0001)]' => data_type(new_type).name)
      end
    end
    Move.register(:s_change_type, ChangeType)
    # Charge raises the user's Special Defense by one stage, and if this Pokémon's next move is a damage-dealing Electric-type attack, it will deal double damage.
    # @see https://pokemondb.net/move/charge
    # @see https://bulbapedia.bulbagarden.net/wiki/Charge_(move)
    # @see https://www.pokepedia.fr/Chargeur
    class Charge < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(effect_name)
          target.effects.add(create_effect(user, target))
          scene.display_message_and_wait(effect_message(user, target))
        end
      end
      # Symbol name of the effect
      # @return [Symbol]
      def effect_name
        :charge
      end
      # Create the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @return [Effects::EffectBase]
      def create_effect(user, target)
        Effects::Charge.new(@logic, target, 2)
      end
      # Message displayed when the effect is created
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @return [String]
      def effect_message(user, target)
        parse_text_with_pokemon(19, 664, target)
      end
    end
    Move.register(:s_charge, Charge)
    class ClangorousSoul < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        can_change_atk = logic.stat_change_handler.stat_increasable?(:atk, user)
        can_change_ats = logic.stat_change_handler.stat_increasable?(:ats, user)
        can_change_dfe = logic.stat_change_handler.stat_increasable?(:dfe, user)
        can_change_dfs = logic.stat_change_handler.stat_increasable?(:dfs, user)
        can_change_spd = logic.stat_change_handler.stat_increasable?(:spd, user)
        stat_changeable = can_change_atk || can_change_ats || can_change_dfe || can_change_dfs || can_change_spd
        if user.hp_rate <= 0.33 || !stat_changeable
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        hp = (user.max_hp / 3).floor
        scene.visual.show_hp_animations([user], [-hp])
      end
    end
    Move.register(:s_clangorous_soul, ClangorousSoul)
    # Move that sets the type of the Pokemon as type of the first move
    class Conversion < BasicWithSuccessfulEffect
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        target.type1 = user.moveset.first&.type || 0
        target.type2 = 0
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 899, target, '[VAR TYPE(0001)]' => data_type(target.type1).name))
      end
    end
    # Move that sets the type of the Pokemon as type of the last move used by target
    class Conversion2 < BasicWithSuccessfulEffect
      # Return the exceptions to the Conversion 2 effect
      MOVE_EXCEPTIONS = %i[revelation_dance struggle]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.none? { |target| target.move_history.any? && !MOVE_EXCEPTIONS.include?(target.move_history.last.db_symbol) && target.move_history.last.move.type != 0 }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        last_move_user = actual_targets.max_by { |target| target.move_history.any? ? target.move_history.max_by(&:turn) : 0 }
        type = last_move_user.move_history&.last&.move&.type || 0
        user.type1 = random_resistances(type)
        user.type2 = 0
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 899, user, '[VAR TYPE(0001)]' => data_type(user.type1).name))
      end
      # Check the resistances to one type and return one random
      # @param move_type [Integer] type of the move used by the target
      # @return Integer
      def random_resistances(move_type)
        resistances = each_data_type.select { |type| data_type(move_type).hit(type.db_symbol) < 1 }
        return resistances.sample.id
      end
    end
    Move.register(:s_conversion, Conversion)
    Move.register(:s_conversion2, Conversion2)
    # Move that inflict leech seed to the ennemy
    class CoreEnforcer < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| !target.effects.has?(:ability_suppressed) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:ability_suppressed)
          launchers = logic.turn_actions.map { |action| action.instance_variable_get(:@launcher) }
          launchers.first == user ? target.effects.add(Effects::AbilitySuppressed.new(@logic, target)) : next
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 565, target))
        end
      end
    end
    Move.register(:s_core_enforcer, CoreEnforcer)
    # When hit by a Physical Attack, user strikes back with 2x power.
    # @see https://pokemondb.net/move/counter
    # @see https://bulbapedia.bulbagarden.net/wiki/Counter_(move)
    # @see https://www.pokepedia.fr/Riposte_(capacit%C3%A9)
    class Counter < Basic
      include Mechanics::Counter
      private
      # Test if the attack fails
      # @param attacker [PFM::PokemonBattler] the last attacker
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean] does the attack fails ?
      def counter_fails?(attacker, user, targets)
        return !attacker || logic.allies_of(user).include?(attacker) || attacker.type_ghost? || !attacker.successful_move_history.last.move.physical? || attacker.successful_move_history.last.turn != $game_temp.battle_turn
      end
    end
    Move.register(:s_counter, Counter)
    # When hit by a Special Attack, user strikes back with 2x power.
    # @see https://pokemondb.net/move/mirror-coat
    # @see https://bulbapedia.bulbagarden.net/wiki/Mirror_Coat_(move)
    # @see https://www.pokepedia.fr/Voile_Miroir
    class MirrorCoat < Basic
      include Mechanics::Counter
      private
      # Test if the attack fails
      # @param attacker [PFM::PokemonBattler] the last attacker in this round
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean] does the attack fails ?
      def counter_fails?(attacker, user, targets)
        return !attacker || logic.allies_of(user).include?(attacker) || attacker.type_dark? || !attacker.successful_move_history.last.move.special? || attacker.successful_move_history.last.turn != $game_temp.battle_turn
      end
    end
    Move.register(:s_mirror_coat, MirrorCoat)
    # Deals damage equal to 1.5x opponent's attack.
    # @see https://pokemondb.net/move/metal-burst
    # @see https://bulbapedia.bulbagarden.net/wiki/Metal_Burst_(move)
    # @see https://www.pokepedia.fr/Fulmifer
    class MetalBurst < Basic
      include Mechanics::Counter
      private
      # Test if the attack fails
      # @param attacker [PFM::PokemonBattler] the last attacker
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean] does the attack fails ?
      def counter_fails?(attacker, user, targets)
        return !attacker || logic.allies_of(user).include?(attacker) || attacker.successful_move_history.last.move.status? || attacker.successful_move_history.last.turn != $game_temp.battle_turn
      end
      # Damage multiplier if the effect proc
      # @return [Integer, Float]
      def damage_multiplier
        1.5
      end
    end
    Move.register(:s_metal_burst, MetalBurst)
    # Class managing Crafty Shield
    # Crafty Shield protects all Pokemon on the user bank from status moves
    class CraftyShield < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        actual_targets.each { |target| target.effects.add(Effects::CraftyShield.new(@logic, target)) }
        @scene.display_message_and_wait(parse_text(18, bank != 0 ? 212 : 211))
      end
    end
    Move.register(:s_crafty_shield, CraftyShield)
    # Class managing Curse
    class Curse < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        if user.type_ghost? && super
          return true
        else
          if user.type_ghost? && target.effects.has?(:curse)
            scene.display_message_and_wait(parse_text(18, 74))
            return true
          end
        end
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if user.type_ghost?
          hp = user.max_hp / 2
          scene.visual.show_hp_animations([user], [-hp])
          actual_targets.each do |target|
            target.effects.add(Effects::Curse.new(@logic, target))
            scene.display_message_and_wait(parse_text_with_pokemon(19, 1070, target, '[VAR PKNICK(0000)]' => user.given_name, '[VAR PKNICK(0001)]' => target.given_name))
          end
        else
          @logic.stat_change_handler.stat_change_with_process(:spd, -1, user, user, self)
          @logic.stat_change_handler.stat_change_with_process(:atk, 1, user, user, self)
          @logic.stat_change_handler.stat_change_with_process(:dfe, 1, user, user, self)
        end
      end
    end
    Move.register(:s_curse, Curse)
    class CustomStatsBased < Basic
      # Physical moves that use the special attack
      ATS_PHYSICAL_MOVES = %i[psyshock secret_sword]
      # Special moves that use the attack
      ATK_SPECIAL_MOVES = []
      # Is the skill physical ?
      # @return [Boolean]
      def physical?
        return ATS_PHYSICAL_MOVES.include?(db_symbol)
      end
      # Is the skill special ?
      # @return [Boolean]
      def special?
        return ATK_SPECIAL_MOVES.include?(db_symbol)
      end
      # Get the basis atk for the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_sp_atk_basis(user, target, ph_move)
        return ph_move ? user.ats_basis : user.atk_basis
      end
      # Statistic modifier calculation: ATK/ATS
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_atk_stat_modifier(user, target, ph_move)
        modifier = ph_move ? user.ats_modifier : user.atk_modifier
        modifier = modifier > 1 ? modifier : 1 if critical_hit?
        return modifier
      end
    end
    Move.register(:s_custom_stats_based, CustomStatsBased)
    Move.register(:s_psyshock, CustomStatsBased)
    # Class managing Defog move
    class Defog < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if $env.current_weather_db_symbol == weather_to_cancel
          handler.logic.weather_change_handler.weather_change(:none, 0)
          handler.scene.display_message_and_wait(weather_cancel_text)
        end
        user.effects.each { |e| e.kill if e.rapid_spin_affected? }
        logic.bank_effects.each_with_index do |bank_effect, bank_index|
          bank_effect.each do |e|
            e.kill if e.rapid_spin_affected?
            e.kill if bank_index != user.bank && effects_to_kill.include?(e.name)
          end
        end
      end
      # List of the effects to kill on the enemy board
      # @return [Array<Symbol>]
      def effects_to_kill
        return %i[light_screen reflect safeguard mist aurora_veil]
      end
      # The type of weather the Move can cancel
      # @return [Symbol]
      def weather_to_cancel
        return :fog
      end
      # The message displayed when the right weather is canceled
      # @return [String]
      def weather_cancel_text
        return parse_text(18, 98)
      end
    end
    Move.register(:s_defog, Defog)
    # Class that manage DestinyBond move. Works together with Effects::DestinyBond.
    # @see https://pokemondb.net/move/destiny-bond
    # @see https://bulbapedia.bulbagarden.net/wiki/Destiny_Bond_(move)
    # @see https://www.pokepedia.fr/Lien_du_Destin
    class DestinyBond < Move
      private
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if target.effects.has?(:destiny_bond)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 626, user))
        user.effects.add(Effects::DestinyBond.new(logic, user))
      end
    end
    Move.register(:s_destiny_bond, DestinyBond)
    # Disable move
    class Disable < Move
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[aroma_veil]
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        ally = @logic.allies_of(target).find { |a| BLOCKING_ABILITY.include?(a.battle_ability_db_symbol) }
        if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
          @scene.visual.show_ability(target)
          return true
        else
          if user.can_be_lowered_or_canceled? && ally
            @scene.visual.show_ability(ally)
            return true
          end
        end
        return super
      end
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        return failure_message unless target.move_history.last
        return failure_message if target.effects.has?(:disable)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          move = target.move_history.last.original_move
          message = parse_text_with_pokemon(19, 592, target, PFM::Text::MOVE[1] => move.name)
          target.effects.add(Effects::Disable.new(@logic, target, move))
          @scene.display_message_and_wait(message)
        end
      end
      private
      # Display failure message
      # @return [Boolean] true for blocking
      def failure_message
        @logic.scene.display_message_and_wait(parse_text(18, 74))
        return true
      end
    end
    Move.register(:s_disable, Disable)
    class DoubleIronBash < TwoHit
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return target.effects.has?(:minimize) ? power * 2 : power
      end
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return target.effects.has?(:minimize) ? true : super
      end
    end
    Move.register(:s_double_iron_bash, DoubleIronBash)
    class DragonDarts < Basic
      private
      # Create a new move
      # @param db_symbol [Symbol] db_symbol of the move in the database
      # @param pp [Integer] number of pp the move currently has
      # @param ppmax [Integer] maximum number of pp the move currently has
      # @param scene [Battle::Scene] current battle scene
      def initialize(db_symbol, pp, ppmax, scene)
        super
        @allies_targets = nil
        @all_targets = nil
      end
      # Internal procedure of the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_internal(user, targets)
        return unless actual_targets = determine_targets(user, targets)
        post_accuracy_check_effects(user, actual_targets)
        post_accuracy_check_move(user, actual_targets)
        play_animation(user, targets)
        deal_damage(user, actual_targets) && effect_working?(user, actual_targets) && deal_status(user, actual_targets) && deal_stats(user, actual_targets) && deal_effect(user, actual_targets)
        user.add_move_to_history(self, actual_targets)
        @scene.visual.set_info_state(:move_animation)
        @scene.visual.wait_for_animation
      end
      # Determine which targets the user will focus
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Array<PFM::PokemonBattler>, nil]
      def determine_targets(user, targets)
        @allies_targets = nil
        original_targets = targets.first
        actual_targets = proceed_internal_precheck(user, targets)
        if $game_temp.vs_type == 1
          return actual_targets.empty? ? nil : actual_targets
        end
        return actual_targets if actual_targets && original_targets.bank == user.bank
        if actual_targets.nil? && original_targets.bank != user.bank
          return if original_targets.effects.has?(:center_of_attention)
          actual_targets = @logic.allies_of(original_targets, true)
          actual_targets = actual_targets.sample if actual_targets.length > 1
          actual_targets = proceed_internal_precheck(user, actual_targets)
          return actual_targets.nil? ? nil : actual_targets
        end
        unless original_targets.effects.has?(:center_of_attention)
          @allies_targets = @logic.allies_of(original_targets, true)
          @allies_targets = @allies_targets.sample if @allies_targets.length > 1
        end
        return actual_targets
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        @user = user
        @actual_targets = actual_targets
        @nb_hit = 0
        @hit_amount = 2
        @all_targets = nil
        @all_targets = actual_targets unless actual_targets.nil?
        @all_targets += @allies_targets unless @allies_targets.nil?
        @hit_amount.times do |i|
          target = @all_targets[i % @all_targets.size]
          next(false) unless target.alive?
          next(false) if user.dead?
          if [target] == @allies_targets
            result = proceed_internal_precheck(user, [target])
            return if result.nil?
          end
          @nb_hit += 1
          play_animation(user, [target]) if @nb_hit > 1
          hp = damages(user, target)
          @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
            if critical_hit?
              scene.display_message_and_wait(@all_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
            else
              if hp > 0 && @nb_hit == @hit_amount
                efficent_message(effectiveness, target)
              end
            end
          end
          recoil(hp, user) if recoil?
        end
        @scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => @nb_hit.to_s))
        return false if user.dead?
        return true
      end
      # Check if this the last hit of the move
      # Don't call this method before deal_damage method call
      # @return [Boolean]
      def last_hit?
        return true if @user.dead?
        return true unless @all_targets.all?(&:alive?)
        return @hit_amount == @nb_hit
      end
      # Tells if the move hits multiple times
      # @return [Boolean]
      def multi_hit?
        return true
      end
    end
    Move.register(:s_dragon_darts, DragonDarts)
    # Echoed Voice deals damage starting at base power 40, and increases by 40 each turn if used by any
    # Pokémon on the field, up to a maximum base power of 200.
    # @see https://pokemondb.net/move/echoed-voice
    # @see https://bulbapedia.bulbagarden.net/wiki/Echoed_Voice_(move)
    # @see https://www.pokepedia.fr/%C3%89cho_(capacit%C3%A9)
    class EchoedVoice < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        mod = logic.terrain_effects.get(:echoed_voice)&.successive_turns || 1
        real_power = (super + (echo_boost * mod)).clamp(0, max_power)
        log_data("power = #{real_power} \# echoed voice successive turns #{mod}")
        return real_power
      end
      private
      # Internal procedure of the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_internal(user, targets)
        logic.terrain_effects.add(Effects::EchoedVoice.new(logic)) unless logic.terrain_effects.has?(:echoed_voice)
        logic.terrain_effects.get(:echoed_voice).increase
        super
      end
      # Boost added to the power for each turn where the move has been used
      # @return [Integer]
      def echo_boost
        40
      end
      # Maximum value of the power
      # @return [Integer]
      def max_power
        200
      end
    end
    register(:s_echo, EchoedVoice)
    class EerieSpell < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.all? { |target| target.move_history.any? && target.skills_set[find_last_skill_position(target)]&.pp != 0 }
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          last_skill = find_last_skill_position(target)
          next if target.move_history.empty? || target.skills_set[last_skill].pp == 0
          num = 3.clamp(1, target.skills_set[last_skill].pp)
          target.skills_set[last_skill].pp -= num
          scene.display_message_and_wait(parse_text_with_pokemon(19, 641, target, PFM::Text::MOVE[1] => target.skills_set[last_skill].name, '[VAR NUM1(0002)]' => num.to_s))
        end
      end
      # Find the last skill used position in the moveset of the Pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Integer]
      def find_last_skill_position(pokemon)
        pokemon.skills_set.each_with_index do |skill, i|
          return i if skill && skill.id == pokemon.move_history.last.move.id
        end
        return 0
      end
    end
    Move.register(:s_eerie_spell, EerieSpell)
    # Move that inflict electrify to the ennemy
    class Electrify < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:change_type)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::Electrify.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1195, target))
        end
      end
    end
    Move.register(:s_electrify, Electrify)
    class ElectroBall < Basic
      # List of all base power depending on the speed ration between target & user
      BASE_POWERS = [[0.25, 150], [0.33, 120], [0.5, 80], [1, 60], [Float::INFINITY, 40]]
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        ratio = target.spd / user.spd
        return BASE_POWERS.find { |(first)| first > ratio }&.last || 40
      end
    end
    Move.register(:s_electro_ball, ElectroBall)
    # Embargo prevents the target using any items for five turns. This includes both held items and items used by the trainer such as medicines.
    # @see https://pokemondb.net/move/embargo
    # @see https://bulbapedia.bulbagarden.net/wiki/Embargo_(move)
    # @see https://www.pokepedia.fr/Embargo
    class Embargo < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        return true if target.effects.has?(effect_symbol)
        return false
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(effect_symbol)
          target.effects.add(create_effect(user, target))
          scene.display_message_and_wait(proc_message(user, target))
        end
      end
      # Symbol name of the effect
      # @return [Symbol]
      def effect_symbol
        :embargo
      end
      # Duration of the effect including the current turn
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @return [Effects::EffectBase]
      def create_effect(user, target)
        Effects::Embargo.new(logic, target, 5)
      end
      def proc_message(user, target)
        return parse_text_with_pokemon(19, 727, target)
      end
    end
    Move.register(:s_embargo, Embargo)
    # Move that forces the target to use the move previously used during 3 turns
    class Encore < Move
      # List of move the target cannot use with encore
      NO_ENCORE_MOVES = %i[encore mimic mirror_move sketch struggle transform]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.empty?
        @verified = result = verify_targets(targets)
        show_usage_failure(user) unless result
        return result
      end
      private
      # Test if the move that should be forced is disallowed to be forced or not
      # @param db_symbol [Symbol]
      # @return [Boolean]
      def move_disallowed?(db_symbol)
        return NO_ENCORE_MOVES.include?(db_symbol)
      end
      # Verify all the targets and tell if the move can continue
      # @param targets [Array<PFM::PokemonBattler>]
      # @return [Boolean]
      def verify_targets(targets)
        targets.any? do |target|
          next(false) unless target
          next(false) if cant_encore_target?(target)
          next(true)
        end
      end
      # Tell if the target can be Encore'd
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def cant_encore_target?(target)
        last_move = target.move_history.last
        has_forced_effect = target.effects.has? { |e| e.force_next_move? && !e.dead? }
        return true if !last_move || has_forced_effect || move_disallowed?(last_move.db_symbol) || last_move.original_move.pp <= 0
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if !@verified && verify_targets(actual_targets)
          show_usage_failure(user)
          @verified = nil
          return false
        end
        actual_targets.each do |target|
          next unless target && !cant_encore_target?(target)
          move_history = target.move_history.last
          target.effects.add(effect = create_effect(move_history.original_move, target, move_history.targets))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 559, target))
          if (index = logic.actions.find_index { |action| action.is_a?(Actions::Attack) && action.launcher == target })
            logic.actions[index] = effect.make_action
          end
        end
      end
      # Create the effect
      # @param move [Battle::Move] move that was used by target
      # @param target [PFM::PokemonBattler] target that used the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Effects::Encore]
      def create_effect(move, target, actual_targets)
        Effects::Encore.new(logic, target, move, actual_targets)
      end
    end
    Move.register(:s_encore, Encore)
    class Endeavor < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.all? { |target| user.hp >= target.hp }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.hp > user.hp
          hp = target.hp - user.hp
          @scene.visual.show_hp_animations([target], [-hp])
        end
      end
    end
    Move.register(:s_endeavor, Endeavor)
    class Eruption < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return (power * user.hp_rate).clamp(1, Float::INFINITY)
      end
    end
    Move.register(:s_eruption, Eruption)
    # Class managing Facade move
    class Facade < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return 140 if user.burn? || user.paralyzed? || user.poisoned? || user.toxic?
        return power
      end
    end
    Move.register(:s_facade, Facade)
    # class managing Fake Out move
    class FakeOut < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        if user.turn_count > 1
          show_usage_failure(user)
          return false
        end
        return true
      end
    end
    Move.register(:s_fake_out, FakeOut)
    class FalseSwipe < Basic
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        hp_total = super
        hp_total = target.hp - 1 if hp_total >= target.hp && !target.effects.has?(:substitute)
        return hp_total
      end
    end
    Move.register(:s_false_swipe, FalseSwipe)
    # Class managing moves that deal a status or flinch
    class Fangs < Basic
      # Function that deals the status condition to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_status(user, actual_targets)
        return true if status_effects.empty?
        status = bchance?(0.5) ? status_effects[0].status : :flinch
        actual_targets.each do |target|
          @logic.status_change_handler.status_change_with_process(status, target, user, self)
        end
      end
    end
    Move.register(:s_a_fang, Fangs)
    # Feint has an increased power if the target used Protect or Detect during this turn. It lift the effects of protection moves.
    # @see https://pokemondb.net/move/feint
    # @see https://bulbapedia.bulbagarden.net/wiki/Feint_(move)
    # @see https://www.pokepedia.fr/Ruse
    class Feint < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return increased_power if target.successful_move_history.any? && increased_power_move?(target.successful_move_history.last)
        return super
      end
      # Detect if the move is protected by another move on target
      # @param target [PFM::PokemonBattler]
      # @param symbol [Symbol]
      def blocked_by?(target, symbol)
        return false unless super
        return !target.effects.has?(:protect)
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.each do |effect|
            next unless lifted_effect?(effect)
            effect.kill
            scene.display_message_and_wait(deal_message(user, target, effect))
          end
        end
      end
      INCREASED_POWER_MOVES = %i[protect]
      # Does the move increase the attack power ?
      # @param successful_move_history [PFM::PokemonBattler::SuccessfulMoveHistory]
      # @return [Boolean]
      def increased_power_move?(successful_move_history)
        successful_move_history.current_turn? && INCREASED_POWER_MOVES.include?(successful_move_history.move.db_symbol)
      end
      # Increased power value
      # @return [Integer]
      def increased_power
        50
      end
      LIFTED_EFFECTS = %i[protect]
      # Is the effect lifted by the move
      # @param effect [Battle::Effects::EffectBase]
      # @return [Boolean]
      def lifted_effect?(effect)
        LIFTED_EFFECTS.include?(effect.name)
      end
      # Message display when the move lift an effect
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param effect [Battle::Effects::EffectBase]
      # @return [String]
      def deal_message(user, target, effect)
        parse_text_with_pokemon(19, 526, target)
      end
    end
    Move.register(:s_feint, Feint)
    class FellStinger < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return !actual_targets.empty? && actual_targets.first.dead?
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        logic.stat_change_handler.stat_change_with_process(:atk, 3, user)
        if user.ability_effect.is_a?(Effects::Ability::Moxie) && logic.stat_change_handler.stat_increasable?(:atk, user)
          scene.visual.show_ability(user)
          logic.stat_change_handler.stat_change_with_process(:atk, 1, user)
        end
      end
    end
    Move.register(:s_fell_stinger, FellStinger)
    class FinalGambit < Move
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        hp_dealt = user.hp
        scene.visual.show_hp_animations([user], [-hp_dealt])
        actual_targets.each do |target|
          scene.logic.damage_handler.damage_change_with_process(hp_dealt, target, user, self)
        end
      end
    end
    Move.register(:s_final_gambit, FinalGambit)
    class FishiousRend < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        n = 1
        n *= damage_multiplier if logic.battler_attacks_before?(user, target) || target.switching?
        return super * n
      end
      private
      # Damage multiplier if the effect procs
      # @return [Integer, Float]
      def damage_multiplier
        return 2
      end
    end
    register(:s_fishious_rend, FishiousRend)
    # Class managing fixed damages moves
    class FixedDamages < Basic
      FIXED_DMG_PARAM = {sonic_boom: 20, dragon_rage: 40}
      # Method calculating the damages done by the actual move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        @critical = false
        @effectiveness = 1
        dmg = FIXED_DMG_PARAM[db_symbol]
        log_data("Fixed Damages Move: #{dmg} HP")
        return dmg || 1
      end
    end
    Move.register(:s_fixed_damage, FixedDamages)
    class Flail < Basic
      Flail_Pow = [20, 40, 80, 100, 150, 200]
      Flail_HP = [0.7, 0.35, 0.2, 0.10, 0.04, 0]
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        index = Flail_HP.find_index { |i| i >= user.hp_rate }
        return Flail_Pow[index.to_i]
      end
    end
    Move.register(:s_flail, Flail)
    # Flame Burst deals damage and will also cause splash damage to any Pokémon adjacent to the target.
    # @see https://pokemondb.net/move/flame-burst
    # @see https://bulbapedia.bulbagarden.net/wiki/Flame_Burst_(move)
    # @see https://www.pokepedia.fr/Rebondifeu
    class FlameBurst < Basic
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        super
        splash_targets = []
        splash_damages = []
        actual_targets.each do |target|
          targets = logic.adjacent_allies_of(target)
          targets.each do |sub_target|
            damage = calc_splash_damage(user, target)
            logic.damage_handler.damage_change(damage, sub_target)
            splash_targets << sub_target
            splash_damages << -damage
          end
        end
        scene.visual.show_hp_animations(splash_targets, splash_damages)
      end
      # Calculate the damage dealt by the splash
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the splash
      # @return [Integer]
      def calc_splash_damage(user, target)
        return (target.max_hp / 16)
      end
    end
    register(:s_flame_burst, FlameBurst)
    # Power depends on held item.
    # @see https://pokemondb.net/move/fling
    # @see https://bulbapedia.bulbagarden.net/wiki/Fling_(move)
    # @see https://www.pokepedia.fr/D%C3%A9gommage
    class Fling < Basic
      include Mechanics::PowerBasedOnItem
      private
      # Tell if the item is consumed during the attack
      # @return [Boolean]
      def consume_item?
        true
      end
      # Test if the held item is valid
      # @param name [Symbol]
      # @return [Boolean]
      def valid_held_item?(name)
        (data_item(name).fling_power || 0) > 0
      end
      # Get the real power of the move depending on the item
      # @param name [Symbol]
      # @return [Integer]
      def get_power_by_item(name)
        data_item(name).fling_power || 0
      end
    end
    Move.register(:s_fling, Fling)
    # Flower Heal move
    class FloralHealing < HealMove
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          hp = @logic.field_terrain_effect.grassy? ? target.max_hp * 2 / 3 : target.max_hp / 2
          logic.damage_handler.heal(target, hp)
        end
      end
    end
    Move.register(:s_floral_healing, FloralHealing)
    # Class that manage the Flower Shield move
    # @see https://bulbapedia.bulbagarden.net/wiki/Flower_Shield_(move)
    # @see https://pokemondb.net/move/flower-shield
    # @see https://www.pokepedia.fr/Garde_Florale
    class FlowerShield < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user?(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless targets.any? { |target| target.type_grass? && !target.effects.has?(&:out_of_reach?) }
        return true
      end
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return super || !target.type_grass? || target.effects.has?(&:out_of_reach?)
      end
      private
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        actual_targets.each do |target|
          @logic.stat_change_handler.stat_change_with_process(:dfe, 1, target, user, self)
        end
      end
    end
    Move.register(:s_flower_shield, FlowerShield)
    # Move that has a flying type as second type
    class FlyingPress < Basic
      # Get the types of the move with 1st type being affected by effects
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Array<Integer>] list of types of the move
      def definitive_types(user, target)
        super << data_type(second_type).id
      end
      # Method calculating the damages done by the actual move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        return target.effects.has?(:minimize) ? super * 2 : super
      end
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true if target.effects.has?(:minimize)
        super
      end
      private
      # Get the second type of the move
      # @return [Symbol]
      def second_type
        return :flying
      end
    end
    Move.register(:s_flying_press, FlyingPress)
    # class managing Focus Energy
    class FocusEnergy < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::FocusEnergy.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1047, target))
        end
      end
    end
    Move.register(:s_focus_energy, FocusEnergy)
    # The user of Focus Punch will tighten its focus before any other moves are made. 
    # If any regular move (with a higher priority than -3) 
    # directly hits the focused Pokémon, it loses its focus and flinches, not carrying out the attack. 
    # If no direct hits are made, Focus Punch attacks as normal.
    # @see https://pokemondb.net/move/focus-punch
    # @see https://bulbapedia.bulbagarden.net/wiki/Focus_Punch_(move)
    # @see https://www.pokepedia.fr/Mitra-Poing
    class FocusPunch < Basic
      # Is the move doing something before any other attack ?
      # @return [Boolean]
      def pre_attack?
        true
      end
      # Proceed the procedure before any other attack.
      # @param user [PFM::PokemonBattler]
      def proceed_pre_attack(user)
        return unless can_pre_use_move?(user)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 616, user))
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if disturbed?(user)
        return show_usage_failure(user) && false unless @enabled
        return true
      end
      private
      # Check if the user is able to display the message related to the move
      # @param user [PFM::PokemonBattler]
      def can_pre_use_move?(user)
        @enabled = false
        return false if (user.frozen? || user.asleep?)
        @enabled = true
        return true
      end
      # Is the pokemon unable to proceed the attack ?
      # @param user [PFM::PokemonBattler]
      # @return [Boolean]
      def disturbed?(user)
        user.damage_history.any?(&:current_turn?)
      end
    end
    Move.register(:s_focus_punch, FocusPunch)
    # Move that inflict Spikes to the enemy bank
    class FollowMe < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if logic.battle_info.vs_type == 1 || logic.battler_attacks_last?(user) || any_battler_with_follow_me_effect?(user)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.add(Effects::CenterOfAttention.new(logic, user, 1, self))
        scene.display_message_and_wait(parse_text_with_pokemon(19, 670, user))
      end
      # Test if any alive battler used followMe this turn
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Boolean]
      def any_battler_with_follow_me_effect?(user)
        last_move_history = logic.adjacent_allies_of(user).map { |battler| battler.successful_move_history.last }.compact
        return last_move_history.any? { |move_history| move_history.current_turn? && move_history.move.be_method == :s_follow_me }
      end
    end
    Move.register(:s_follow_me, FollowMe)
    # Class managing moves that force the target switch
    # Roar, Whirlwind, Dragon Tail, Circle Throw
    class ForceSwitch < BasicWithSuccessfulEffect
      # Tell if the move is a move that forces target switch
      # @return [Boolean]
      def force_switch?
        return true
      end
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:crafty_shield) && be_method == :s_roar
        return super
      end
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true unless target.effects.has?(&:out_of_reach?) && be_method == :s_roar
        super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next(false) unless @logic.switch_handler.can_switch?(target, self) && user.alive?
          next(false) if target.effects.has?(:substitute) && be_method == :s_dragon_tail
          next(false) if @logic.switch_request.any? { |request| request[:who] == target }
          if !@logic.battle_info.trainer_battle? && @logic.alive_battlers_without_check(target.bank).size == 1 && target.bank == 1 && user.level >= target.level && !$game_switches[Yuki::Sw::BT_NoEscape]
            @battler_s = @scene.visual.battler_sprite(target.bank, target.position)
            @battler_s.flee_animation
            @logic.scene.visual.wait_for_animation
            @logic.battle_result = 1
          end
          rand_pkmn = (@logic.alive_battlers_without_check(target.bank).select { |p| p if p.party_id == target.party_id && p.position == -1 }).compact
          @logic.actions.reject! { |a| a.is_a?(Actions::Attack) && a.launcher == target }
          @logic.switch_request << {who: target, with: rand_pkmn.sample} unless rand_pkmn.empty?
        end
      end
    end
    Move.register(:s_dragon_tail, ForceSwitch)
    Move.register(:s_roar, ForceSwitch)
    # Move that makes possible to hit Ghost type Pokemon with Normal or Fighting type moves
    class Foresight < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::Foresight.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 369, target))
        end
      end
    end
    Move.register(:s_foresight, Foresight)
    # Class managing Foul Play move
    class FoulPlay < Basic
      # Get the basis atk for the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_sp_atk_basis(user, target, ph_move)
        return ph_move ? target.atk_basis : target.ats_basis
      end
      # Statistic modifier calculation: ATK/ATS
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_atk_stat_modifier(user, target, ph_move)
        return 1 if critical_hit?
        return ph_move ? target.atk_modifier : target.ats_modifier
      end
    end
    Move.register(:s_foul_play, FoulPlay)
    class FreezyFrost < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return @logic.all_alive_battlers.each { |battler| battler.battle_stage.any? { |stage| stage != 0 } }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @logic.all_alive_battlers.each do |battler|
          next if battler.battle_stage.all?(&:zero?)
          battler.battle_stage.map! {0 }
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 195, battler))
        end
      end
    end
    Move.register(:s_freezy_frost, FreezyFrost)
    class Frustration < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        power = (255 - user.loyalty) / 2.5
        power.floor.clamp(1, 102)
        log_data("Frustration power: #{power}")
        return power
      end
    end
    Move.register(:s_frustration, Frustration)
    # Move that inflict a critical hit
    class FullCrit < Basic
      # Return the critical rate index of the skill
      # @return [Integer]
      def critical_rate
        return 100
      end
    end
    Move.register(:s_full_crit, FullCrit)
    # Fury Cutter starts with a base power of 10. Every time it is used successively, its power will double, up to a maximum of 160.
    # @see https://bulbapedia.bulbagarden.net/wiki/Fury_Cutter_(move)
    # @see https://pokemondb.net/move/fury-cutter
    # @see https://www.pokepedia.fr/Taillade
    class FuryCutter < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        successive_uses = (user.effects.get(effect_name)&.successive_uses || 0) + 1
        fury_cutter_power = (super * 2 ** (successive_uses - 1)).clamp(0, max_power)
        log_data('power = %i # %s effect %i successive uses' % [fury_cutter_power, effect_name, successive_uses])
        return fury_cutter_power
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.add(create_effect(user, actual_targets)) unless user.effects.has?(effect_name)
        user.effects.get(effect_name).increase
      end
      # Max base power of the move.
      # @return [Integer]
      def max_power
        160
      end
      # Class of the effect
      # @return [Symbol]
      def effect_name
        :fury_cutter
      end
      # Create the move effect object
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Battle::Effects::EffectBase]
      def create_effect(user, actual_targets)
        Battle::Effects::FuryCutter.new(logic, user, self)
      end
    end
    Move.register(:s_fury_cutter, FuryCutter)
    class FusionFlare < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        n = 1
        n *= 2 if boosted_move?(user, target)
        return super * n
      end
      # Tell if the move will be boosted
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def boosted_move?(user, target)
        other_move_actions = logic.turn_actions.select do |a|
          a.is_a?(Actions::Attack) && Actions::Attack.from(a).launcher != user && Actions::Attack.from(a).move.db_symbol == fusion_move
        end
        return false if other_move_actions.empty?
        return other_move_actions.any? do |move_action|
          other = Actions::Attack.from(move_action).launcher
          next(false) unless user.attack_order > other.attack_order && other.last_successful_move_is?(fusion_move)
          next(user.attack_order == other.attack_order.next)
        end
      end
      # Get the other move triggering the damage boost
      # @return [db_symbol]
      def fusion_move
        return :fusion_bolt
      end
    end
    class FusionBolt < FusionFlare
      def fusion_move
        return :fusion_flare
      end
    end
    Move.register(:s_fusion_flare, FusionFlare)
    Move.register(:s_fusion_bolt, FusionBolt)
    # Future Sight deals damage, but does not hit until two turns after the move is used. 
    # If the opponent switched Pokémon in the meantime, the new Pokémon gets hit, 
    # with their type and stats taken into account.
    # @see https://pokemondb.net/move/future-sight
    # @see https://bulbapedia.bulbagarden.net/wiki/Future_Sight_(move)
    # @see https://www.pokepedia.fr/Prescience
    class FutureSight < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |t| @logic.position_effects[t.bank][t.position].has?(:future_sight) }
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        log_data("FutureSight targets : #{actual_targets}")
        actual_targets.each do |target|
          next if @logic.position_effects[target.bank][target.position].has?(:future_sight)
          @logic.add_position_effect(create_effect(user, target))
          @scene.display_message_and_wait(deal_message(user, target))
        end
      end
      # Hash containing the countdown for each "Future Sight"-like move
      # @return [Hash]
      COUNTDOWN = {future_sight: 3, doom_desire: 3}
      # Return the right countdown depending on the move, or a static one
      # @return [Integer]
      def countdown
        return COUNTDOWN[db_symbol] || 3
      end
      # Create the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @return [Effects::PositionTiedEffectBase]
      def create_effect(user, target)
        Effects::FutureSight.new(@logic, target.bank, target.position, user, countdown, self)
      end
      # Message displayed when the effect is dealt
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      def deal_message(user, target)
        parse_text_with_pokemon(19, 1080, user)
      end
    end
    Move.register(:s_future_sight, FutureSight)
    # Move that inflict leech seed to the ennemy
    class GastroAcid < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:ability_suppressed) || !@logic.ability_change_handler.can_change_ability?(target, :none)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::AbilitySuppressed.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 565, target))
        end
      end
    end
    Move.register(:s_gastro_acid, GastroAcid)
    # Gear Up move
    class GearUp < Move
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| %i[minus plus].include?(target.ability_db_symbol) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless %i[minus plus].include?(target.ability_db_symbol)
          scene.logic.stat_change_handler.stat_change_with_process(:atk, 1, target, user, self)
          scene.logic.stat_change_handler.stat_change_with_process(:ats, 1, target, user, self)
        end
      end
    end
    Move.register(:s_gear_up, GearUp)
    # Class managing the Geomancy move
    # @see https://pokemondb.net/move/geomancy
    class Geomancy < TwoTurnBase
      private
      # Display the message and the animation of the turn
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_message_turn1(user, targets)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 1213, user))
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          @logic.stat_change_handler.stat_change_with_process(:ats, 2, target, user, self)
          @logic.stat_change_handler.stat_change_with_process(:dfs, 2, target, user, self)
          @logic.stat_change_handler.stat_change_with_process(:spd, 2, target, user, self)
        end
      end
    end
    Move.register(:s_geomancy, Geomancy)
    class GlitzyGlow < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return !@logic.bank_effects[user.bank].has?(effect)
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        turn_count = user.hold_item?(:light_clay) ? 8 : 5
        @logic.bank_effects[user.bank].add(class_effect.new(@logic, user.bank, 0))
        @scene.display_message_and_wait(parse_text(18, message + user.bank.clamp(0, 1)))
      end
      # Get the effect to check
      def effect
        :light_screen
      end
      # Get the new effect to deal
      def class_effect
        Effects::LightScreen
      end
      # Get the message to display
      def message
        134
      end
    end
    class BaddyBad < GlitzyGlow
      # Get the effect to check
      def effect
        :reflect
      end
      # Get the new effect to deal
      def class_effect
        Effects::Reflect
      end
      # Get the message to display
      def message
        130
      end
    end
    Move.register(:s_glitzy_glow, GlitzyGlow)
    Move.register(:s_baddy_bad, BaddyBad)
    class GravApple < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return power = power * 1.5 if @logic.terrain_effects.has?(:gravity)
        return power
      end
    end
    Move.register(:s_grav_apple, GravApple)
    # Move increase the gravity
    class Gravity < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        if super
          effect_klass = Effects::Gravity
          if logic.terrain_effects.each.any? { |effect| effect.class == effect_klass }
            show_usage_failure(user)
            return false
          end
          return true
        end
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.terrain_effects.add(Effects::Gravity.new(@scene.logic))
        scene.display_message_and_wait(parse_text(18, 123))
      end
    end
    Move.register(:s_gravity, Gravity)
    # Class describing a self stat move (damage + potential status + potential stat to user)
    class Growth < SelfStat
      def deal_stats(user, actual_targets)
        battle_stage_mod.each do |stage|
          if $env.sunny? || $env.hardsun?
            @logic.stat_change_handler.stat_change_with_process(stage.stat, 2, user, user, self)
          else
            @logic.stat_change_handler.stat_change_with_process(stage.stat, 1, user, user, self)
          end
        end
      end
    end
    Move.register(:s_growth, Growth)
    # Class managing Grudge move
    class Grudge < Move
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.all? { |target| !target.effects.has?(:grudge) }
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:grudge)
          target.effects.add(Effects::Grudge.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 632, target))
        end
      end
    end
    Move.register(:s_grudge, Grudge)
    class GyroBall < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        power = 25 * (target.spd / user.spd)
        power.clamp(1, 150)
        log_data("Gyro Ball power: #{power}")
        return power
      end
    end
    Move.register(:s_gyro_ball, GyroBall)
    # Class managing moves that deal damages equivalent level
    class HPEqLevel < Basic
      private
      # Method calculating the damages done by the actual move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        @critical = false
        @effectiveness = 1
        log_data("Damages equivalent to the user Level Move: #{user.level} HP")
        return user.level || 1
      end
    end
    Move.register(:s_hp_eq_level, HPEqLevel)
    # class managing HappyHour move
    class HappyHour < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if logic.terrain_effects.has?(:happy_hour)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param _user [PFM::PokemonBattler] user of the move
      # @param _actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(_user, _actual_targets)
        logic.terrain_effects.add(Effects::HappyHour.new(logic))
        scene.display_message_and_wait(parse_text(18, 255))
      end
    end
    Move.register(:s_happy_hour, HappyHour)
    # Move that resets stats of all pokemon on the field
    class Haze < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return true if db_symbol != :haze
        if targets.none? { |target| target.battle_stage.any? { |stage| stage != 0 } }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.battle_stage.none? { |stage| stage != 0 }
          target.battle_stage.map! {0 }
          scene.display_message_and_wait(parse_text_with_pokemon(19, 195, target))
        end
      end
    end
    Move.register(:s_haze, Haze)
    # Class describing a heal move
    class HealBell < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        if target.has_ability?(:soundproof)
          scene.visual.show_ability(target)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 210, target))
          return true
        end
        return false
      end
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets = scene.logic.all_battlers.select { |p| p.bank == user.bank && p.party_id == user.party_id && p.alive? } unless db_symbol == :refresh
        target_cure = false
        targets.each do |target|
          next if target.status == 0
          scene.logic.status_change_handler.status_change(:cure, target)
          target_cure = true
        end
        scene.display_message_and_wait(parse_text(18, 70)) unless target_cure
      end
    end
    Move.register(:s_heal_bell, HealBell)
    # Move that rectricts the targets from healing in certain ways for five turns
    class HealBlock < Move
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[aroma_veil]
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        ally = @logic.allies_of(target).find { |a| BLOCKING_ABILITY.include?(a.battle_ability_db_symbol) }
        if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
          @scene.visual.show_ability(target)
          return true
        else
          if user.can_be_lowered_or_canceled? && ally
            @scene.visual.show_ability(ally)
            return true
          end
        end
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::HealBlock.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 884, target))
        end
      end
    end
    Move.register(:s_heal_block, HealBlock)
    # Class describing a heal move
    class HealWeather < HealMove
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          if $env.normal? || $env.strong_winds?
            hp = target.max_hp / 2
          else
            if $env.sunny? || $env.hardsun?
              hp = target.max_hp * 2 / 3
            else
              hp = target.max_hp / 4
            end
          end
          hp = hp * 3 / 2 if pulse? && user.has_ability?(:mega_launcher)
          logic.damage_handler.heal(target, hp)
        end
      end
    end
    Move.register(:s_heal_weather, HealWeather)
    class HealingSacrifice < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        unless @logic.can_battler_be_replaced?(user)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          add_effect(target)
          @scene.visual.show_hp_animations([target], [-target.hp])
          @logic.switch_request << {who: target}
        end
      end
      # Add the effect to the Pokemon
      # @param target [PFM::PokemonBattler]
      def add_effect(target)
        log_error('Move Implementation Error: add_effect should be overwritten in child class.')
      end
    end
    class HealingWish < HealingSacrifice
      # Add the effect to the Pokemon
      # @param target [PFM::PokemonBattler]
      def add_effect(target)
        target.effects.add(Effects::HealingWish.new(@logic, target))
      end
    end
    class LunarDance < HealingSacrifice
      # Add the effect to the Pokemon
      # @param target [PFM::PokemonBattler]
      def add_effect(target)
        target.effects.add(Effects::LunarDance.new(@logic, target))
      end
    end
    Move.register(:s_healing_wish, HealingWish)
    Move.register(:s_lunar_dance, LunarDance)
    class HeavySlam < Basic
      MINIMUM_WEIGHT_PERCENT = [0.5, 0.3334, 0.25, 0.20]
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        target_weight = (target.weight != target.data.weight) ? (user.can_be_lowered_or_canceled? ? target.weight : target.data.weight) : target.weight
        weight_percent = target_weight.to_f / user.weight
        weight_index = MINIMUM_WEIGHT_PERCENT.find_index { |weight| weight_percent > weight } || MINIMUM_WEIGHT_PERCENT.size
        minimize_factor = target.effects.has?(:minimize) ? 2 : 1
        return (40 + 20 * weight_index) * minimize_factor
      end
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true if target.effects.has?(:minimize)
        super
      end
    end
    Move.register(:s_heavy_slam, HeavySlam)
    # In Double Battles, boosts the power of the partner's move.
    # @see https://pokemondb.net/move/helping-hand
    # @see https://bulbapedia.bulbagarden.net/wiki/Helping_Hand_(move)
    # @see https://www.pokepedia.fr/Coup_d%27Main
    class HelpingHand < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.reject { |t| t == user }.empty? || logic.battle_info.vs_type == 1 || targets.all? { |t| t.effects.has?(:helping_hand) }
          return show_usage_failure(user) && false
        end
        return true
      end
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:helping_hand_mark)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:helping_hand)
          user.effects.add(create_effect(user, target))
          scene.display_message_and_wait(deal_message(user, target))
        end
      end
      # Create the effect given to the target
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] targets that will be affected by the move
      # @return [Effects::EffectBase]
      def create_effect(user, target)
        Effects::HelpingHand.new(logic, user, target, 1)
      end
      # Message displayed when the effect is dealt to the target
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [String]
      def deal_message(user, target)
        parse_text_with_pokemon(19, 1050, user, PFM::Text::PKNICK[1] => target.given_name)
      end
    end
    Move.register(:s_helping_hand, HelpingHand)
    # Move that inflict Hex to the enemy
    class Hex < BasicWithSuccessfulEffect
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        hp_dealt = super
        hp_dealt *= 2 if states.include?(Configs.states.symbol(target.status))
        hp_dealt *= 2 if target.has_ability?(:comatose)
        return hp_dealt
      end
      private
      # Return the States that triggers the x2 damages
      STATES = %i[burn paralysis sleep freeze poison toxic]
      # Return the STATES constant
      # @return [Array<Symbol>]
      def states
        STATES
      end
    end
    Move.register(:s_hex, Hex)
    # Hidden Power deals damage, however its type varies for every Pokémon, depending on that Pokémon's Individual Values (IVs).
    # @see https://pokemondb.net/move/hidden-power
    # @see https://bulbapedia.bulbagarden.net/wiki/Hidden_Power_(move)
    # @see https://www.pokepedia.fr/Puissance_Cach%C3%A9e
    # @see https://bulbapedia.bulbagarden.net/wiki/Hidden_Power_(move)/Calculation
    class HiddenPower < Basic
      # Get the types of the move with 1st type being affected by effects
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Array<Integer>] list of types of the move
      def definitive_types(user, target)
        index = 0
        iv_list.each_with_index { |iv, i| index += (user.send(iv) & 1) * 2 ** i }
        index = (index * (types_table.length - 1) / 63).floor
        type_id = types_table[index]
        log_data("Hidden power : internal index=#{index} > #{type_id}")
        return [data_type(type_id).id]
      end
      private
      # Hidden power move types
      # @return [Array<Symbol>] array of types
      TYPES_TABLE = %i[fighting flying poison ground rock bug ghost steel fire water grass electric psychic ice dragon dark]
      # Hidden power move types
      # @return [Array<Symbol>] array of types
      def types_table
        return TYPES_TABLE
      end
      # IVs weighted from the litest to the heaviest in type / damage calculation
      # @return [Array<Symbol>]
      IV_LIST = %i[iv_hp iv_atk iv_dfe iv_spd iv_ats iv_dfs]
      # IVs weighted from the litest to the heaviest in type / damage calculation
      # @return [Array<Symbol>]
      def iv_list
        return IV_LIST
      end
    end
    Move.register(:s_hidden_power, HiddenPower)
    # Move that has a big recoil when fails
    class HighJumpKick < Basic
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity, :pp
      def on_move_failure(user, targets, reason)
        return if [:usable_by_user, :pp].include?(reason)
        return crash_procedure(user)
      end
      # Define the crash procedure when the move isn't able to connect to the target
      # @param user [PFM::PokemonBattler] user of the move
      def crash_procedure(user)
        hp = user.max_hp / 2
        scene.visual.show_hp_animations([user], [-hp])
        scene.display_message_and_wait(parse_text_with_pokemon(19, 908, user))
      end
    end
    Move.register(:s_jump_kick, HighJumpKick)
    # Class managing moves that deal double power & cure status
    class HitThenCureStatus < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return power * 2 if status_check(target)
        return super
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless status_check(target)
          @logic.status_change_handler.status_change(:cure, target, user)
        end
      end
      # Check the status
      # @return [Boolean] tell if the Pokemon has this status
      def status_check(target)
        log_error('Move Implementation Error: status_check should be overwritten in child class.')
      end
    end
    # Class managing Smelling Salts move
    class SmellingSalts < HitThenCureStatus
      # Check the status
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean] tell if the Pokemon has this status
      def status_check(target)
        return target.paralyzed?
      end
    end
    # Class managing Wake-Up Slap move
    class WakeUpSlap < HitThenCureStatus
      # Check the status
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean] tell if the Pokemon has this status
      def status_check(target)
        return target.asleep? || target.has_ability?(:comatose)
      end
    end
    Move.register(:s_smelling_salt, SmellingSalts)
    Move.register(:s_wakeup_slap, WakeUpSlap)
    # Opponent is unable to use moves that the user also knows.
    # @see https://pokemondb.net/move/imprison
    # @see https://bulbapedia.bulbagarden.net/wiki/Imprison_(move)
    # @see https://www.pokepedia.fr/Possessif
    class Imprison < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |target| user.effects.get(:imprison)&.targetted?(target) }
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if user.effects.has?(:imprison)
          user.effects.add(Effects::Imprison.new(logic, target))
          scene.display_message_and_wait(deal_message(user, target))
        end
      end
      # Message displayed when the effect is dealt
      # @param user [PFM::PokemonBattler]
      # @param actual_targets [Array<PFM::PokemonBattler>]
      # @return [String]
      def deal_message(user, actual_targets)
        parse_text_with_pokemon(19, 586, user)
      end
    end
    Move.register(:s_imprison, Imprison)
    # Class managing the Incinerate move
    class Incinerate < BasicWithSuccessfulEffect
      DESTROYABLE_ITEMS = %i[fire_gem water_gem electric_gem grass_gem ice_gem fighting_gem poison_gem ground_gem flying_gem psychic_gem bug_gem rock_gem ghost_gem dragon_gem dark_gem steel_gem normal_gem fairy_gem]
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        dmg = super
        if dmg > 0 && @logic.item_change_handler.can_lose_item?(target, user)
          if DESTROYABLE_ITEMS.include?(target.battle_item_db_symbol)
            @logic.item_change_handler.change_item(:none, true, target, user, self)
          else
            if target.hold_berry?(target.battle_item_db_symbol) && !target.effects.has?(:item_burnt)
              @scene.display_message_and_wait(parse_text_with_pokemon(19, 1114, target, PFM::Text::ITEM2[1] => target.item_name))
              target.effects.add(Effects::ItemBurnt.new(@logic, target))
            end
          end
        end
        return dmg
      end
    end
    Move.register(:s_incinerate, Incinerate)
    # class managing Ingrain move
    class Ingrain < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |target| target.effects.has?(:ingrain) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:ingrain)
          target.effects.add(Effects::Ingrain.new(logic, target, user, self))
          scene.display_message_and_wait(message(user))
        end
      end
      # Get the message text
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def message(pokemon)
        return parse_text_with_pokemon(19, 736, pokemon)
      end
    end
    Move.register(:s_ingrain, Ingrain)
    # Move increase changing all moves to electric for 1 turn
    class IonDeluge < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if logic.terrain_effects.has?(:ion_deluge)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.terrain_effects.add(Effects::IonDeluge.new(@scene.logic))
        scene.display_message_and_wait(parse_text(18, 257))
      end
    end
    Move.register(:s_ion_deluge, IonDeluge)
    # Jaw Lock move
    class JawLock < Basic
      private
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return true unless user.effects.has?(:cantswitch) || actual_targets.any? { |target| target.effects.has?(:cantswitch) }
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        unless user.effects.has?(:cantswitch)
          user.effects.add(Effects::CantSwitch.new(logic, user, user, self))
          scene.display_message_and_wait(parse_text_with_pokemon(19, 875, user))
        end
        actual_targets.each do |target|
          next if target.effects.has?(:cantswitch)
          target.effects.add(Effects::CantSwitch.new(logic, target, user, self))
          scene.display_message_and_wait(parse_text_with_pokemon(19, 875, target))
        end
      end
    end
    Move.register(:s_jaw_lock, JawLock)
    # Type depends on the Arceus Plate being held.
    # @see https://pokemondb.net/move/judgment
    # @see https://bulbapedia.bulbagarden.net/wiki/Judgment_(move)
    # @see https://www.pokepedia.fr/Jugement
    class Judgment < Basic
      include Mechanics::TypesBasedOnItem
      private
      # Tell if the item is consumed during the attack
      # @return [Boolean]
      def consume_item?
        false
      end
      # Test if the held item is valid
      # @param name [Symbol]
      # @return [Boolean]
      def valid_held_item?(name)
        return true
      end
      # Get the real types of the move depending on the item, type of the corresponding item if a plate, normal otherwise
      # @param name [Symbol]
      # @return [Array<Integer>]
      def get_types_by_item(name)
        if JUDGMENT_TABLE.keys.include?(name)
          [data_type(JUDGMENT_TABLE[name]).id]
        else
          [data_type(:normal).id]
        end
      end
      # Table of move type depending on item
      # @return [Hash<Symbol, Symbol>]
      JUDGMENT_TABLE = {flame_plate: :fire, splash_plate: :water, zap_plate: :electric, meadow_plate: :grass, icicle_plate: :ice, fist_plate: :fighting, toxic_plate: :poison, earth_plate: :ground, sky_plate: :flying, mind_plate: :psychic, insect_plate: :bug, stone_plate: :rock, spooky_plate: :ghost, draco_plate: :dragon, iron_plate: :steel, dread_plate: :dark, pixie_plate: :fairy}
    end
    Move.register(:s_judgment, Judgment)
    # Move that inflict Knock Off to the ennemy
    class KnockOff < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return effect_working?(user, [target]) ? super * 1.5 : super
      end
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| @logic.item_change_handler.can_lose_item?(target, user) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless @logic.item_change_handler.can_lose_item?(target, user)
          next if user.dead? && target.hold_item?(:rocky_helmet) || %i[rough_skin iron_barbs].include?(target.battle_ability_db_symbol)
          additionnal_variables = {PFM::Text::ITEM2[2] => target.item_name, PFM::Text::PKNICK[1] => target.given_name}
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1056, user, additionnal_variables))
          if target.from_party? && !target.effects.has?(:item_stolen)
            @logic.item_change_handler.change_item(:none, false, target, user, self)
            target.effects.add(Effects::ItemStolen.new(@logic, target))
          else
            @logic.item_change_handler.change_item(:none, true, target, user, self)
          end
        end
      end
    end
    Move.register(:s_knock_off, KnockOff)
    # class managing Focus Energy
    class LaserFocus < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::LaserFocus.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1047, target))
        end
      end
    end
    Move.register(:s_laser_focus, LaserFocus)
    class LastResort < Basic
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return failure(user) unless user.moveset.map(&:db_symbol).include?(:last_resort)
        return failure(user) if user.moveset.size == 1
        return failure(user) unless all_other_move_used?(user)
        return true
      end
      # Display the usage failure message and return false
      # @param user [PFM::PokemonBattler]
      # @return [false]
      def failure(user)
        show_usage_failure(user)
        return false
      end
      private
      # Test if the user has used all the other moves
      # @param user [PFM::PokemonBattler]
      def all_other_move_used?(user)
        return user.moveset.each { |move| move.pp == 0 && move.db_symbol != :last_resort }
      end
    end
    Move.register(:s_last_resort, LastResort)
    # Move that inflict leech seed to the ennemy
    class LeechSeed < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:leech_seed_mark) || target.type_grass? || target.effects.has?(:substitute)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          @logic.add_position_effect(Effects::LeechSeed.new(@logic, user, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 607, target))
        end
      end
    end
    Move.register(:s_leech_seed, LeechSeed)
    # Class describing a move that heals the user and its allies
    class LifeDew < HealMove
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          hp = target.max_hp / 4
          logic.damage_handler.heal(target, hp)
        end
      end
    end
    Move.register(:s_life_dew, LifeDew)
    # Class describing a heal move
    class JungleHealing < HealMove
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          hp = target.max_hp / 4
          logic.damage_handler.heal(target, hp)
          next if target.status == 0 || target.dead?
          scene.logic.status_change_handler.status_change(:cure, target)
        end
      end
    end
    Move.register(:s_jungle_healing, JungleHealing)
    # Move that adds a field on the bank protecting from physicial or special moves
    class Reflect < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if logic.bank_effects[user.bank].has?(db_symbol) || (db_symbol == :aurora_veil && !$env.hail?)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        turn_count = user.hold_item?(:light_clay) ? 8 : 5
        if db_symbol == :light_screen
          logic.bank_effects[user.bank].add(Effects::LightScreen.new(logic, user.bank, 0, turn_count))
          scene.display_message_and_wait(parse_text(18, 134 + user.bank.clamp(0, 1)))
        else
          if db_symbol == :aurora_veil
            logic.bank_effects[user.bank].add(Effects::AuroraVeil.new(logic, user.bank, 0, turn_count))
            scene.display_message_and_wait(parse_text(18, 288 + user.bank.clamp(0, 1)))
          else
            logic.bank_effects[user.bank].add(Effects::Reflect.new(logic, user.bank, 0, turn_count))
            scene.display_message_and_wait(parse_text(18, 130 + user.bank.clamp(0, 1)))
          end
        end
      end
    end
    Move.register(:s_reflect, Reflect)
    # class managing Lock-On and Mind Reader moves
    class LockOn < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if user.effects.get(:lock_on)&.target == target
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if user.effects.get(:lock_on)&.target == target
          user.effects.add(Effects::LockOn.new(@logic, user, target))
          text = parse_text_with_pokemon(19, target.bank == 0 ? 656 : 651, user, PFM::Text::PKNICK[0] => user.given_name, PFM::Text::PKNICK[1] => target.given_name)
          @scene.display_message_and_wait(text)
        end
      end
    end
    Move.register(:s_lock_on, LockOn)
    Move.register(:s_mind_reader, LockOn)
    class LowKick < Basic
      MAXIMUM_WEIGHT = [10, 25, 50, 100, 200]
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        target_weight = (target.weight != target.data.weight) ? (user.can_be_lowered_or_canceled? ? target.weight : target.data.weight) : target.weight
        weight_index = MAXIMUM_WEIGHT.find_index { |weight| target_weight < weight } || MAXIMUM_WEIGHT.size
        return 20 + 20 * weight_index
      end
    end
    Move.register(:s_low_kick, LowKick)
    # class managing HappyHour move
    class LuckyChant < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param _targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, _targets)
        return false unless super
        return false if logic.bank_effects[user.bank].has?(:lucky_chant)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param _actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, _actual_targets)
        @logic.add_bank_effect(Effects::LuckyChant.new(@logic, user.bank))
        @scene.display_message_and_wait(parse_text(18, message_id + user.bank))
      end
      # ID of the message that is responsible for telling the beginning of the effect
      # @return [Integer]
      def message_id
        return 150
      end
    end
    Move.register(:s_lucky_chant, LuckyChant)
    # Move that inflict Magic Coat to the user
    class MagicCoat < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if @logic.battler_attacks_last?(user)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::MagicCoat.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 761, target))
        end
      end
    end
    Move.register(:s_magic_coat, MagicCoat)
    # Move that give a third type to an enemy
    class MagicPowder < ChangeType
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        if target.hold_item?(:safety_goggles)
          @logic.scene.visual.show_item(target)
          return true
        end
        return super ? true : false
      end
      # Method that tells if the target already has the type
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def type_check(target)
        return target.type_psychic?
      end
    end
    Move.register(:s_magic_powder, MagicPowder)
    # Magic Room suppresses the effects of held items for all Pokémon for five turns.
    # @see https://pokemondb.net/move/magic-room
    # @see https://bulbapedia.bulbagarden.net/wiki/Magic_Room_(move)
    # @see https://www.pokepedia.fr/Zone_Magique
    class MagicRoom < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if logic.terrain_effects.has?(:magic_room)
          logic.terrain_effects.get(:magic_room).kill
        else
          logic.terrain_effects.add(Effects::MagicRoom.new(logic, duration))
        end
      end
      # Duration of the effect
      # @return [Integer]
      def duration
        5
      end
    end
    register(:s_magic_room, MagicRoom)
    # User becomes immune to Ground-type moves for 5 turns.
    # @see https://pokemondb.net/move/magnet-rise
    # @see https://bulbapedia.bulbagarden.net/wiki/Magnet_Rise_(move)
    # @see https://www.pokepedia.fr/Vol_Magn%C3%A9tik
    class MagnetRise < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |target| target.effects.has?(effect_name) }
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(effect_name)
          target.effects.add(create_effect(user, target))
          @logic.scene.display_message_and_wait(on_create_message(user, target))
        end
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :magnet_rise
      end
      # Create the effect
      # @return [Battle::Effects::EffectBase]
      def create_effect(user, target)
        return Effects::MagnetRise.new(logic, target, 5)
      end
      # Message displayed when the effect is added to the target
      # @return [String]
      def on_create_message(user, target)
        parse_text_with_pokemon(19, 658, target)
      end
    end
    Move.register(:s_magnet_rise, MagnetRise)
    # Magnetic Flux move
    class MagneticFlux < Move
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        actual_targets.any? { |target| target.ability_db_symbol == :plus || target.ability_db_symbol == :minus }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.ability_db_symbol == :plus || target.ability_db_symbol == :minus
          scene.logic.stat_change_handler.stat_change_with_process(:dfe, 1, target, user, self)
          scene.logic.stat_change_handler.stat_change_with_process(:dfs, 1, target, user, self)
        end
      end
    end
    Move.register(:s_magnetic_flux, MagneticFlux)
    # Class managing Magnitude move
    # @see https://bulbapedia.bulbagarden.net/wiki/Magnitude_(move)
    # @see https://pokemondb.net/move/magnitude
    # @see https://www.pokepedia.fr/Ampleur
    class Magnitude < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return magnitude_table[3][1] unless @magnitude_found
        log_data("magnitude power #{@magnitude_found[1]} \# #{@magnitude_found}")
        power = @magnitude_found[1]
        @magnitude_found = nil
        return power
      end
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        return super(user, target) unless (e = target.effects.get(&:out_of_reach?)) && !e&.on_move_prevention_target(user, target, self)
        d = super(user, target)
        log_data("damage = #{d * 2} \# #{d} * 2 (magnitude overhall damages double when target is using dig)")
        return (d * 2).floor
      end
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        find_magnitude
        return true
      end
      def find_magnitude
        dice = logic.generic_rng.rand(100).floor
        @magnitude_found = magnitude_table.find { |row| row[0] > dice } || magnitude_table[0]
      end
      # Show the move usage message
      # @param user [PFM::PokemonBattler] user of the move
      def usage_message(user)
        super
        find_magnitude if @magnitude_found.nil?
        @scene.display_message_and_wait(parse_text(18, @magnitude_found[2]))
      end
      # Damage table
      # Array<[probability_of_100, power, text]>
      # Sum of probabilities must be 100
      MAGNITUDE_TABLE = [[5, 10, 108], [15, 30, 109], [35, 50, 110], [65, 70, 111], [85, 90, 112], [95, 110, 113], [100, 150, 114]]
      # Damage table
      # Array<[probability_of_100, power, text]>
      # Sum of probabilities must be 100
      def magnitude_table
        MAGNITUDE_TABLE
      end
    end
    Move.register(:s_magnitude, Magnitude)
    # class managing Make It Rain move
    class MakeItRain < SelfStat
      private
      # Function that deals the effect (generates money the player gains at the end of battle)
      # @param user [PFM::PokemonBattler] user of the move
      # @param _actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return unless user.from_party?
        money = user.level * 5
        total_money = money * actual_targets.size
        scene.battle_info.additional_money += total_money
        scene.display_message_and_wait(parse_text(18, 128))
      end
    end
    Move.register(:s_make_it_rain, MakeItRain)
    # Me First move
    class MeFirst < Move
      CANNOT_BE_SELECTED_MOVES = %i[me_first sucker_punch fake_out]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || logic.battler_attacks_after?(user, targets.first) || CANNOT_BE_SELECTED_MOVES.include?(target_move(targets.first))
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that retrieve the target move from the action stack
      # @return [Symbol]
      def target_move(target)
        attacks = logic.actions.select { |action| action.is_a?(Actions::Attack) }
        attacks.find { |action| action.launcher == target }&.move&.db_symbol || CANNOT_BE_SELECTED_MOVES.first
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        skill = data_move(target_move(actual_targets.first))
        move = Battle::Move[skill.be_method].new(skill.db_symbol, 1, 1, @scene)
        def move.calc_mod2(user, target)
          super * 1.5
        end
        def move.chance_of_hit(user, target)
          return 100
        end
        use_another_move(move, user)
      end
    end
    Move.register(:s_me_first, MeFirst)
    # class managing Memento move
    class Memento < Move
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        hp = user.max_hp
        scene.visual.show_hp_animations([user], [-hp])
      end
    end
    Move.register(:s_memento, Memento)
    # Metronome move
    class Metronome < Move
      CANNOT_BE_SELECTED_MOVES = %i[after_you assist baneful_bunker beak_blast belch bestow celebrate chatter copycat counter covet crafty_shield destiny_bound detect diamond_storm endure feint fleur_cannon focus_punch follow_me freeze_shock helping_hand hold_hands hyperspace_fury hyperspace_hole ice_burn instruct king_s_shield light_of_ruin mat_block me_first metronome mimic mind_blown mirror_coat mirror_move nature_power photon_geyser plasma_fists protect quash quick_guard rage_powder relic_song secret_sword shell_trap sketch sleep_talk snarl snatch snore spectral_thief spiky_shield spotlight steam_eruption struggle switcheroo techno_blast thousand_arrows thousand_waves thief transform trick v_create wide_guard]
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        skill = each_data_move.reject { |i| CANNOT_BE_SELECTED_MOVES.include?(i.db_symbol) }.sample(random: @logic.generic_rng)
        move = Battle::Move[skill.be_method].new(skill.id, 1, 1, @scene)
        def move.usage_message(user)
          @scene.visual.hide_team_info
          scene.display_message_and_wait(parse_text(18, 126, '[VAR MOVE(0000)]' => name))
          PFM::Text.reset_variables
        end
        use_another_move(move, user)
      end
    end
    Move.register(:s_metronome, Metronome)
    # Move that copies the last move of the choosen target
    class Mimic < Move
      NO_MIMIC_MOVES = %i[chatter metronome sketch struggle mimic]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || targets.first.move_history.empty? || NO_MIMIC_MOVES.include?(targets.first.move_history.last.move.db_symbol)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        mimic_move_index = user.moveset.index(self)
        return unless mimic_move_index
        user.mimic_move = [self, mimic_move_index]
        move = actual_targets.first.move_history.last.move
        user.moveset[mimic_move_index] = Move[move.be_method].new(move.id, 5, 5, scene)
        scene.display_message_and_wait(parse_text_with_pokemon(19, 688, user, PFM::Text::MOVE[1] => move.name))
      end
    end
    Move.register(:s_mimic, Mimic)
    class MindBlown < Basic
      # Get the reason why the move is disabled
      # @param user [PFM::PokemonBattler] user of the move
      # @return [#call] Block that should be called when the move is disabled
      def disable_reason(user)
        damp_battlers = logic.all_alive_battlers.select { |battler| battler.has_ability?(:damp) }
        return super if damp_battlers.empty?
        return proc {@logic.scene.visual.show_ability(damp_battlers.first) && @logic.scene.display_message_and_wait(parse_text_with_pokemon(60, 508, user)) }
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        damp_battlers = logic.all_alive_battlers.select { |battler| battler.has_ability?(:damp) }
        unless damp_battlers.empty?
          @logic.scene.visual.show_ability(damp_battlers.first)
          return show_usage_failure(user) && false
        end
        return true
      end
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity, :pp
      def on_move_failure(user, targets, reason)
        return unless %i[accuracy immunity].include?(reason)
        return crash_procedure(user)
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        super ? true : crash_procedure(user) && false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        crash_procedure(user)
      end
      private
      # Define the crash procedure when the move isn't able to connect to the target
      # @param user [PFM::PokemonBattler] user of the move
      def crash_procedure(user)
        return if user.has_ability?(:wonder_guard)
        hp = user.max_hp / 2
        scene.visual.show_hp_animations([user], [-hp])
      end
    end
    Move.register(:s_mind_blown, MindBlown)
    # Class that manage Minimize move
    class Minimize < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each { |target| target.effects.add(Effects::Minimize.new(@logic, target)) }
      end
    end
    Move.register(:s_minimize, Minimize)
    # Move that makes possible to hit Dark type Pokemon with Psychic type moves
    class MiracleEye < Move
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::MiracleEye.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 369, target))
        end
      end
    end
    Move.register(:s_miracle_eye, MiracleEye)
    # Move that mimics the last move of the choosen target
    class MirrorMove < Move
      COPY_CAT_MOVE_EXCLUDED = %i[baneful_bunker beak_blast behemoth_blade bestow celebrate chatter circle_throw copycat counter covet destiny_bond detect dragon_tail endure feint focus_punch follow_me helping_hand hold_hands king_s_shield mat_block assist me_first metronome mimic mirror_coat mirror_move protect rage_powder roar shell_trap sketch sleep_talk snatch struggle spiky_shield spotlight switcheroo thief transform trick whirlwind]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        last_used_move = last_move(user, targets)
        log_error("1111111111 #{last_used_move}")
        if !last_used_move || move_excluded?(last_used_move)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        move = last_move(user, actual_targets).dup
        def move.move_usable_by_user(user, targets)
          return true
        end
        use_another_move(move, user)
      end
      private
      # Tell if the move is usable or not
      # @param move [Battle::Move]
      # @return [Boolean]
      def move_excluded?(move)
        return !move.mirror_move_affected? if db_symbol == :mirror_move
        return COPY_CAT_MOVE_EXCLUDED.include?(move.db_symbol)
      end
      # Function that gets the last used move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Battle::Move, nil] the last move
      def last_move(user, targets)
        if db_symbol == :mirror_move
          return nil unless (target = targets.first)
          return nil unless (move_history = target.move_history.last)
          return nil if move_history.turn < ($game_temp.battle_turn - 1)
          return move_history.move
        end
        return copy_cat_last_move(user)
      end
      # Function that gets the last used move for copy cat
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Battle::Move, nil] the last move
      def copy_cat_last_move(user)
        battlers = logic.all_alive_battlers.select { |battler| battler != user }
        last_move_history = battlers.map { |battler| battler.move_history.last }.compact
        max_turn = last_move_history.map(&:turn).max
        last_turn_history = last_move_history.select { |history| history.turn == max_turn }
        last_history = last_turn_history.max_by(&:attack_order)
        return last_history&.move
      end
    end
    Move.register(:s_mirror_move, MirrorMove)
    # Mist move
    class Mist < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if logic.bank_effects[user.bank].has?(:mist)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.map(&:bank).uniq.each do |bank|
          logic.bank_effects[bank].add(Effects::Mist.new(logic, bank))
          scene.display_message_and_wait(parse_text(18, bank == 0 ? 142 : 143))
        end
      end
    end
    Move.register(:s_mist, Mist)
    # Move that lower the power of electric/fire moves
    class MudSport < Move
      # List of effect depending on db_symbol of the move
      # @return [Hash{ Symbol => Class<Battle::Effects::EffectBase> }]
      EFFECT_KLASS = {}
      # List of message used to declare the effect
      # @return [Hash{ Symbol => Integer }]
      EFFECT_MESSAGE = {}
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        if super
          effect_klass = EFFECT_KLASS[db_symbol]
          if logic.terrain_effects.each.any? { |effect| effect.class == effect_klass }
            show_usage_failure(user)
            return false
          end
          return true
        end
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.terrain_effects.add(EFFECT_KLASS[db_symbol].new(@scene.logic))
        scene.display_message_and_wait(parse_text(18, EFFECT_MESSAGE[db_symbol]))
      end
      class << self
        # Register an effect to a "MudSport" like move
        # @param db_symbol [Symbol] Symbol of the move
        # @param klass [Class<Battle::Effects::EffectBase>]
        # @param message_id [Integer] ID of the message to show in file 18 when effect is applied
        def register_effect(db_symbol, klass, message_id)
          EFFECT_KLASS[db_symbol] = klass
          EFFECT_MESSAGE[db_symbol] = message_id
        end
      end
      register_effect(:mud_sport, Effects::MudSport, 120)
      register_effect(:water_sport, Effects::WaterSport, 118)
    end
    Move.register(:s_thing_sport, MudSport)
    # Type depends on the Sylvally ROM being held.
    # @see https://pokemondb.net/move/judgment
    # @see https://bulbapedia.bulbagarden.net/wiki/Judgment_(move)
    # @see https://www.pokepedia.fr/Jugement
    class MultiAttack < Basic
      include Mechanics::TypesBasedOnItem
      private
      # Tell if the item is consumed during the attack
      # @return [Boolean]
      def consume_item?
        false
      end
      # Test if the held item is valid
      # @param name [Symbol]
      # @return [Boolean]
      def valid_held_item?(name)
        return true
      end
      # Get the real types of the move depending on the item, type of the corresponding item if a memory, normal otherwise
      # @param name [Symbol]
      # @return [Array<Integer>]
      def get_types_by_item(name)
        if MEMORY_TABLE.keys.include?(name)
          [data_type(MEMORY_TABLE[name]).id]
        else
          [data_type(:normal).id]
        end
      end
      # Table of move type depending on item
      # @return [Hash<Symbol, Symbol>]
      MEMORY_TABLE = {fire_memory: :fire, water_memory: :water, electric_memory: :electric, grass_memory: :grass, ice_memory: :ice, fighting_memory: :fighting, poison_memory: :poison, ground_memory: :ground, flying_memory: :flying, psychic_memory: :psychic, bug_memory: :bug, rock_memory: :rock, ghost_memory: :ghost, dragon_memory: :dragon, steel_memory: :steel, dark_memory: :dark, fairy_memory: :fairy}
    end
    Move.register(:s_multi_attack, MultiAttack)
    # Natural Gift deals damage with no additional effects. However, its type and base power vary depending on the user's held Berry. 
    # @see https://pokemondb.net/move/natural-gift
    # @see https://bulbapedia.bulbagarden.net/wiki/Natural_Gift_(move)
    # @see https://www.pokepedia.fr/Don_Naturel
    class NaturalGift < Basic
      include Mechanics::PowerBasedOnItem
      include Mechanics::TypesBasedOnItem
      private
      # Tell if the item is consumed during the attack
      # @return [Boolean]
      def consume_item?
        true
      end
      # Test if the held item is valid
      # @param name [Symbol]
      # @return [Boolean]
      def valid_held_item?(name)
        NATURAL_GIFT_TABLE.keys.include?(name)
      end
      # Get the real power of the move depending on the item
      # @param name [Symbol]
      # @return [Integer]
      def get_power_by_item(name)
        NATURAL_GIFT_TABLE[name][0]
      end
      # Get the real types of the move depending on the item
      # @param name [Symbol]
      # @return [Array<Integer>]
      def get_types_by_item(name)
        [data_type(NATURAL_GIFT_TABLE[name][1]).id]
      end
      class << self
        def reset
          const_set(:NATURAL_GIFT_TABLE, {})
        end
        def register(berry, power, type)
          NATURAL_GIFT_TABLE[berry] ||= []
          NATURAL_GIFT_TABLE[berry] = [power, type]
        end
      end
      reset
      register(:chilan_berry, 80, :normal)
      register(:cheri_berry, 80, :fire)
      register(:occa_berry, 80, :fire)
      register(:bluk_berry, 90, :fire)
      register(:watmel_berry, 100, :fire)
      register(:chesto_berry, 80, :water)
      register(:passho_berry, 80, :water)
      register(:nanab_berry, 90, :water)
      register(:durin_berry, 100, :water)
      register(:pecha_berry, 80, :electric)
      register(:wacan_berry, 80, :electric)
      register(:wepear_berry, 90, :electric)
      register(:belue_berry, 100, :electric)
      register(:rawst_berry, 80, :grass)
      register(:rindo_berry, 80, :grass)
      register(:pinap_berry, 90, :grass)
      register(:liechi_berry, 100, :grass)
      register(:aspear_berry, 80, :ice)
      register(:yache_berry, 80, :ice)
      register(:pomeg_berry, 90, :ice)
      register(:ganlon_berry, 100, :ice)
      register(:leppa_berry, 80, :fighting)
      register(:chople_berry, 80, :fighting)
      register(:kelpsy_berry, 90, :fighting)
      register(:salac_berry, 100, :fighting)
      register(:oran_berry, 80, :poison)
      register(:kebia_berry, 80, :poison)
      register(:qualot_berry, 90, :poison)
      register(:petaya_berry, 100, :poison)
      register(:persim_berry, 80, :ground)
      register(:shuca_berry, 80, :ground)
      register(:hondew_berry, 90, :ground)
      register(:apicot_berry, 100, :ground)
      register(:lum_berry, 80, :flying)
      register(:coba_berry, 80, :flying)
      register(:grepa_berry, 90, :flying)
      register(:lansat_berry, 100, :flying)
      register(:sitrus_berry, 80, :psychic)
      register(:payapa_berry, 80, :psychic)
      register(:tamato_berry, 90, :psychic)
      register(:starf_berry, 100, :psychic)
      register(:figy_berry, 80, :bug)
      register(:tanga_berry, 80, :bug)
      register(:cornn_berry, 90, :bug)
      register(:enigma_berry, 100, :bug)
      register(:wiki_berry, 80, :rock)
      register(:charti_berry, 80, :rock)
      register(:magost_berry, 90, :rock)
      register(:micle_berry, 100, :rock)
      register(:mago_berry, 80, :ghost)
      register(:kasib_berry, 80, :ghost)
      register(:rabuta_berry, 90, :ghost)
      register(:custap_berry, 100, :ghost)
      register(:aguav_berry, 80, :dragon)
      register(:haban_berry, 80, :dragon)
      register(:nomel_berry, 90, :dragon)
      register(:jaboca_berry, 100, :dragon)
      register(:iapapa_berry, 80, :dark)
      register(:colbur_berry, 80, :dark)
      register(:spelon_berry, 90, :dark)
      register(:rowap_berry, 100, :dark)
      register(:razz_berry, 80, :steel)
      register(:babiri_berry, 80, :steel)
      register(:pamtre_berry, 90, :steel)
      register(:roseli_berry, 80, :fairy)
      register(:kee_berry, 100, :fairy)
      register(:maranga_berry, 100, :dark)
    end
    Move.register(:s_natural_gift, NaturalGift)
    # When Nature Power is used it turns into a different move depending on the current battle terrain.
    # @see https://pokemondb.net/move/nature-power
    # @see https://bulbapedia.bulbagarden.net/wiki/Nature_Power_(move)
    # @see https://www.pokepedia.fr/Force_Nature
    class NaturePower < Move
      include Mechanics::LocationBased
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        skill = data_move(element_by_location)
        log_data("nature power \# becomes #{skill.db_symbol}")
        move = Battle::Move[skill.be_method].new(skill.db_symbol, 1, 1, @scene)
        def move.usage_message(user)
          @scene.visual.hide_team_info
          scene.display_message_and_wait(parse_text(18, 127, '[VAR MOVE(0000)]' => name))
          PFM::Text.reset_variables
        end
        def move.move_usable_by_user(user, targets)
          return true
        end
        use_another_move(move, user)
      end
      # Element by location type.
      # @return [Hash<Symbol, Array<Symbol>]
      def element_table
        MOVES_TABLE
      end
      class << self
        def reset
          const_set(:MOVES_TABLE, {})
        end
        def register(loc, move)
          MOVES_TABLE[loc] ||= []
          MOVES_TABLE[loc] << move
          MOVES_TABLE[loc].uniq!
        end
      end
      reset
      register(:__undef__, :tri_attack)
      register(:regular_ground, :tri_attack)
      register(:building, :tri_attack)
      register(:grass, :energy_ball)
      register(:desert, :earth_power)
      register(:cave, :power_gem)
      register(:water, :hydro_pump)
      register(:shallow_water, :mud_bomb)
      register(:snow, :frost_breath)
      register(:icy_cave, :ice_beam)
      register(:volcanic, :lava_plume)
      register(:burial, :shadow_ball)
      register(:soaring, :air_slash)
      register(:misty_terrain, :moonblast)
      register(:grassy_terrain, :energy_ball)
      register(:electric_terrain, :thunderbolt)
      register(:psychic_terrain, :psychic)
      register(:space, :draco_meteor)
      register(:ultra_space, :psyshock)
    end
    Move.register(:s_nature_power, NaturePower)
    # Move that makes possible to hit Ghost type Pokemon with Normal or Fighting type moves
    class Nightmare < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return true if targets.all? { |target| target.has_ability?(:comatose) }
        return false unless super
        if targets.all? { |target| target.effects.has?(:nightmare) }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:nightmare)
          target.effects.add(Effects::Nightmare.new(@logic, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 321, target))
        end
      end
    end
    Move.register(:s_nightmare, Nightmare)
    class NoRetreat < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if user.effects.has?(:no_retreat)
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.add(Effects::NoRetreat.new(logic, user, user, self)) if can_be_affected?(user)
      end
      # Check if the user can be affected by the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Boolean]
      def can_be_affected?(user)
        return false if user.type_ghost?
        return false if user.effects.has?(:cantswitch)
        return true
      end
    end
    Move.register(:s_no_retreat, NoRetreat)
    # Class managing OHKO moves
    class OHKO < Basic
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        super
        scene.display_message_and_wait(parse_text(18, 100)) if actual_targets.any?(&:dead?)
        return true
      end
      # Tell if the move is an OHKO move
      # @return [Boolean]
      def ohko?
        return true
      end
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.type_ice? && db_symbol == :sheer_cold
        return super
      end
      # Return the chance of hit of the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Float]
      def chance_of_hit(user, target)
        log_data("\# OHKO move: chance_of_hit(#{user}, #{target}) for #{db_symbol}")
        return 100 if bypass_chance_of_hit?(user, target)
        return (user.level < target.level ? 0 : (user.level - target.level) + 30)
      end
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        @critical = false
        @effectiveness = 1
        log_data('OHKO Move: 100% HP')
        return target.max_hp
      end
    end
    Move.register(:s_ohko, OHKO)
    class Octolock < Basic
      private
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return failure_message if target.effects.has?(:bind)
        return super
      end
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        actual_targets.any? { |target| !target.effects.has?(:bind) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:bind)
          target.effects.add(Effects::Octolock.new(logic, target, user, Float::INFINITY, self))
        end
      end
      # Display failure message
      # @return [Boolean] true for blocking
      def failure_message
        @logic.scene.display_message_and_wait(parse_text(18, 74))
        return true
      end
    end
    Move.register(:s_octolock, Octolock)
    # Move that share HP between targets
    class PainSplit < Move
      # Check if the move bypass chance of hit and cannot fail
      # @param _user [PFM::PokemonBattler] user of the move
      # @param _target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(_user, _target)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        hp_total = 0
        actual_targets = [user].concat(actual_targets)
        actual_targets.each { |target| hp_total += target.effects.has?(:substitute) ? target.effects.get(:substitute).hp : target.hp }
        hp_total = (hp_total / actual_targets.size).to_i
        scene.display_message_and_wait(message)
        actual_targets.each do |target|
          if target.effects.has?(:substitute) && !authentic?
            substitute = target.effects.get(:substitute)
            substitute.hp = hp_total.clamp(1, substitute.max_hp)
          else
            scene.visual.show_hp_animations([target], [hp_total - target.hp])
          end
        end
      end
      # Get the message
      def message
        return parse_text(18, 117)
      end
    end
    Move.register(:s_pain_split, PainSplit)
    # Parting Shot lowers the opponent's Attack and Special Attack by one stage each, then the user switches out of battle.
    # @see https://pokemondb.net/move/parting-shot
    # @see https://bulbapedia.bulbagarden.net/wiki/Parting_Shot_(move)
    # @see https://www.pokepedia.fr/Dernier_Mot
    class PartingShot < Move
      # Tell if the move is a move that switch the user if that hit
      def self_user_switch?
        return true
      end
      private
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        @switchable = switchable?(actual_targets)
        super
      end
      # Function that if the Pokemon can be switched or not
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def switchable?(actual_targets)
        return false unless actual_targets.any? do |target|
          next(!target.has_ability?(:contrary) && battle_stage_mod.any? { |stage| logic.stat_change_handler.stat_decreasable?(stage.stat, target) } || target.has_ability?(:contrary) && battle_stage_mod.any? { |stage| logic.stat_change_handler.stat_increasable?(stage.stat, target) })
        end
        return false if actual_targets.all? { |target| target.has_ability?(:clear_body) }
        return false if actual_targets.all? { |target| logic.bank_effects[target.bank].has?(:mist) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return false unless @logic.switch_handler.can_switch?(user, self)
        return false unless @switchable
        @logic.switch_request << {who: user}
      end
    end
    Move.register(:s_parting_shot, PartingShot)
    # Power doubles if the user was attacked first.
    # @see https://pokemondb.net/move/payback
    # @see https://bulbapedia.bulbagarden.net/wiki/Payback_(move)
    # @see https://www.pokepedia.fr/Repr%C3%A9sailles
    class PayBack < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        last_damage = user.damage_history.last
        mult = (last_damage&.current_turn? && last_damage&.launcher ? damage_multiplier : 1)
        log_data("real_base_power = #{super * mult} \# Payback multiplier: #{mult}")
        return super * mult
      end
      private
      # Damage multiplier if the effect proc
      # @return [Integer, Float]
      def damage_multiplier
        2
      end
    end
    Move.register(:s_payback, PayBack)
    # class managing PayDay move
    class PayDay < BasicWithSuccessfulEffect
      private
      # Function that deals the effect (generates money the player gains at the end of battle)
      # @param user [PFM::PokemonBattler] user of the move
      # @param _actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, _actual_targets)
        return unless user.from_party?
        m = user.level * 5
        scene.battle_info.additional_money += m
        scene.display_message_and_wait(parse_text(18, 128))
      end
    end
    Move.register(:s_payday, PayDay)
    # Any Pokemon in play when this attack is used faints in 3 turns.
    # @see https://pokemondb.net/move/perish-song
    # @see https://bulbapedia.bulbagarden.net/wiki/Perish_Song_(move)
    # @see https://www.pokepedia.fr/Requiem
    class PerishSong < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.any? { |target| target.effects.has?(:perish_song) } || user.effects.has?(:perish_song)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each { |target| target.effects.add(create_effect(user, target)) }
        @scene.display_message_and_wait(message_after_animation(user, actual_targets))
      end
      # Return the effect of the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target that will be affected by the effect
      # @return [Effects::EffectBase]
      def create_effect(user, target)
        Effects::PerishSong.new(logic, target, 4)
      end
      # Return the parsed message to display once the animation is played
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [String]
      def message_after_animation(user, actual_targets)
        parse_text(18, 125)
      end
    end
    Move.register(:s_perish_song, PerishSong)
    class PlasmaFists < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return !@logic.terrain_effects.has?(:ion_deluge)
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @logic.terrain_effects.add(Effects::IonDeluge.new(@scene.logic))
        @scene.display_message_and_wait(parse_text(18, 257))
      end
    end
    Move.register(:s_plasma_fists, PlasmaFists)
    # Class managing the Pluck move
    class Pluck < Basic
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return if user.dead?
        actual_targets.each do |target|
          next unless @logic.item_change_handler.can_lose_item?(target, user) && target.hold_berry?(target.battle_item_db_symbol)
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 776, user, PFM::Text::ITEM2[1] => target.item_name))
          if target.item_effect.is_a?(Effects::Item::Berry)
            user_effect = Effects::Item.new(logic, user, target.item_effect.db_symbol)
            user_effect.execute_berry_effect(force_heal: true)
            if user.has_ability?(:cheek_pouch) && !user.effects.has?(:heal_block)
              @scene.visual.show_ability(user)
              @logic.damage_handler.heal(user, user.max_hp / 3)
            end
          end
          @logic.item_change_handler.change_item(:none, true, target, user, self)
        end
      end
    end
    Move.register(:s_pluck, Pluck)
    class PollenPuff < Basic
      # Method calculating the damages done by the actual move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        hp_dealt = super
        hp_dealt = 0 if logic.allies_of(user).include?(target)
        return hp_dealt
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless logic.allies_of(user).include?(target)
          next if user.effects.has?(:heal_block)
          next if target.effects.has?(:heal_block)
          hp = target.max_hp / 2
          logic.damage_handler.heal(target, hp)
        end
      end
    end
    Move.register(:s_pollen_puff, PollenPuff)
    # Implements the Poltergeist move
    class Poltergeist < Basic
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || targets.all?(:dead?) || targets.first.battle_ability_db_symbol == :__undef__
          show_usage_failure(user)
          return false
        end
        return true
      end
    end
    Move.register(:s_poltergeist, Poltergeist)
    # Powder move
    class Powder < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || logic.battler_attacks_after?(user, targets.first) || targets.first.effects.has?(:powder)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        target.effects.add(Effects::Powder.new(@logic, target))
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1210, target))
      end
    end
    Move.register(:s_powder, Powder)
    # User's own Attack and Defense switch.
    # @see https://pokemondb.net/move/power-trick
    # @see https://bulbapedia.bulbagarden.net/wiki/Power_Trick_(move)
    # @see https://www.pokepedia.fr/Astuce_Force
    class PowerTrick < StatAndStageEdit
      private
      # Apply the exchange
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        old_atk, old_dfe = target.atk_basis, target.dfe_basis
        target.atk_basis, target.dfe_basis = target.dfe_basis, target.atk_basis
        scene.display_message_and_wait(parse_text_with_pokemon(19, 773, target))
        log_data("power trick \# #{target.name} exchange atk and dfe (atk:#{old_atk} > #{target.atk_basis}) (dfe:#{old_dfe} > #{target.dfe_basis})")
      end
    end
    Move.register(:s_power_trick, PowerTrick)
    class Present < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return @real_base_power if @real_base_power
        rng = logic.generic_rng.rand(1..100)
        log_data("Rng gave you: #{rng}")
        if rng <= 40
          return 40
        else
          if rng <= 70
            return 80
          else
            if rng <= 80
              return 120
            else
              return 0
            end
          end
        end
      end
      def power
        return @real_base_power || 0
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        @real_base_power = real_base_power(user, target)
        if @real_base_power > 0
          super
          return false
        end
        return true
      ensure
        @real_base_power = nil
      end
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          hp = (target.max_hp / 4).floor
          if target.effects.has?(:heal_block)
            log_data('Heal blocked')
            scene.display_message_and_wait(parse_text_with_pokemon(19, 890, target))
          else
            if target.hp == target.max_hp
              log_data('Target has MAX HP')
              scene.display_message_and_wait(parse_text_with_pokemon(19, 896, target))
            else
              log_data('Healing time')
              logic.damage_handler.heal(target, hp, test_heal_block: false)
            end
          end
        end
      end
    end
    Move.register(:s_present, Present)
    # Protect move
    class Protect < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if user.turn_count > 1 && db_symbol == :mat_block
          show_usage_failure(user)
          return false
        end
        if user.effects.has?(:substitute) || logic.battler_attacks_last?(user)
          show_usage_failure(user)
          return false
        end
        turn = $game_temp.battle_turn
        consecutive_uses = user.successful_move_history.reverse.take_while do |history|
          if history.move.be_method == :s_protect
            turn -= 1
            next(turn == history.turn)
          end
        end
        unless bchance?(2 ** -consecutive_uses.size)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(Effects::Protect.new(logic, target, self))
          scene.display_message_and_wait(deal_message(target))
        end
      end
      def deal_message(user)
        msg_id = 517
        msg_id = 511 if db_symbol == :endure
        msg_id = 800 if db_symbol == :quick_guard
        msg_id = 797 if db_symbol == :wide_guard
        return parse_text_with_pokemon(19, msg_id, user)
      end
    end
    Move.register(:s_protect, Protect)
    # Class managing the Psych Up move
    class PsychUp < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if targets.all? { |target| target.battle_stage.all?(&:zero?) }
        return true
      end
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:crafty_shield)
        return super
      end
      private
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true unless target.effects.has?(&:out_of_reach?)
        super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.battle_stage.all?(&:zero?)
          target.battle_stage.each_with_index do |value, index|
            next if value == 0
            user.set_stat_stage(index, value)
          end
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1053, user, PFM::Text::PKNICK[1] => target.given_name))
        end
      end
    end
    Move.register(:s_psych_up, PsychUp)
    class PsychoShift < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.all? { |target| target.effects.has?(:substitute) } || right_status_symbol(user).nil?
          return show_usage_failure(user) && false
        end
        return true
      end
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true unless logic.status_change_handler.status_appliable?(right_status_symbol(user), target, user, self)
        return true if target.has_ability?(:comatose)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:substitute)
          logic.status_change_handler.status_change(right_status_symbol(user), target, user, self)
          logic.status_change_handler.status_change(:cure, user, user, self)
        end
      end
      # Get the right symbol for a status of a Pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Symbol]
      def right_status_symbol(pokemon)
        return Configs.states.symbol(pokemon.status)
      end
    end
    Move.register(:s_psycho_shift, PsychoShift)
    # Class managing Psywave
    class Psywave < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        n = (user.level * (logic.move_damage_rng.rand(1..100) + 50) / 100).floor
        n.clamp(1, Float::INFINITY)
        return n || power
      end
    end
    Move.register(:s_psywave, Psywave)
    # Purify move
    class Purify < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return unless super
        unless targets.any?(&:status?)
          return show_usage_failure(user) && false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.status?
          @logic.status_change_handler.status_change_with_process(:cure, target, user, self)
        end
        hp = user.max_hp / 2
        logic.damage_handler.heal(user, hp)
      end
    end
    Move.register(:s_purify, Purify)
    # Pursuit move, double the power if hitting switching out Pokemon
    class Pursuit < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return super * 2 if target.switching? && target.last_sent_turn != $game_temp.battle_turn
        return super
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @logic.actions.reject! { |a| a.is_a?(Actions::Switch) && actual_targets.include?(a.who) && a.who.dead? }
        return true
      end
    end
    Move.register(:s_pursuit, Pursuit)
    # Quash move
    class Quash < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.empty? || logic.battler_attacks_after?(user, targets.first)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        attacks = logic.actions.select { |action| action.is_a?(Actions::Attack) }
        target_action = attacks.find { |action| action.launcher == target }
        return unless target_action
        logic.actions.delete(target_action)
        logic.actions.insert(0, target_action)
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1137, target))
      end
    end
    Move.register(:s_quash, Quash)
    # Class managing moves that deal a status or flinch
    class Rage < BasicWithSuccessfulEffect
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return if user.effects.has?(:rage) && !user.effects.get(:rage).dead?
        user.effects.add(Effects::Rage.new(logic, user))
      end
    end
    Move.register(:s_rage, Rage)
    # Class that manage Rage Fist move
    class RageFist < Basic
      # Base power calculation
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        power = super
        damage_taken = user.damage_history.count(&:move)
        new_power = (power + damage_taken * 50).clamp(1, 350)
        log_data("power = #{new_power} \# after Move::RageFist calc")
        return new_power
      end
    end
    Move.register(:s_rage_fist, RageFist)
    # Class managing Rapid Spin move
    class RapidSpin < BasicWithSuccessfulEffect
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.each { |e| e.kill if e.rapid_spin_affected? }
        logic.bank_effects[user.bank].each { |e| e.kill if e.rapid_spin_affected? }
      end
    end
    Move.register(:s_rapid_spin, RapidSpin)
    # Move that has a little recoil when it hits the opponent
    class RecoilMove < Basic
      # List of factor depending on the move
      RECOIL_FACTORS = {brave_bird: 3, double_edge: 3, chloroblast: 2, flare_blitz: 3, head_charge: 4, head_smash: 2, light_of_ruin: 2, shadow_end: 2, shadow_rush: 16, struggle: 4, submission: 4, take_down: 4, volt_tackle: 3, wave_crash: 3, wild_charge: 4, wood_hammer: 3}
      # Tell that the move is a recoil move
      # @return [Boolean]
      def recoil?
        true
      end
      # Returns the recoil factor
      # @return [Integer]
      def recoil_factor
        RECOIL_FACTORS[db_symbol] || super
      end
      # Test if the recoil applies to user max hp
      def recoil_applies_on_user_max_hp?
        %i[struggle shadow_rush].include?(db_symbol)
      end
      # Test if teh recoil applis to user current hp
      def recoil_applies_on_user_hp?
        %i[shadow_end].include?(db_symbol)
      end
      # Function applying recoil damage to the user
      # @param hp [Integer]
      # @param user [PFM::PokemonBattler]
      def recoil(hp, user)
        hp = user.max_hp if recoil_applies_on_user_max_hp?
        hp = user.hp if recoil_applies_on_user_hp?
        super(hp, user)
      end
    end
    # Struggle Move
    class Struggle < RecoilMove
      # Get the types of the move with 1st type being affected by effects
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Array<Integer>] list of types of the move
      def definitive_types(user, target)
        [0]
      end
    end
    Move.register(:s_recoil, RecoilMove)
    Move.register(:s_struggle, Struggle)
    class Recycle < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.none?(&:item_consumed)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.item_consumed && target.consumed_item != :__undef__
          @scene.logic.item_change_handler.change_item(target.consumed_item, true, target, user, self)
        end
      end
    end
    Move.register(:s_recycle, Recycle)
    class ReflectType < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets.first
        return if target.typeless?
        return if always_failing_target.include?(target.db_symbol)
        user.type1 = (target.type1 == 0 && target.type2 == 0) ? 1 : target.type1
        user.type2 = target.type2
        user.type3 = target.type3
        logic.scene.display_message_and_wait(message(user, target))
      end
      # Get the db_symbol of the Pokemon on which the move always fails
      # @return [Array<Symbol>]
      def always_failing_target
        return %i[arceus silvally]
      end
      # Get the right message to display
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [String]
      def message(user, target)
        return parse_text_with_2pokemon(19, 1095, user, target)
      end
    end
    Move.register(:s_reflect_type, ReflectType)
    # Relic Song is a damage-dealing Normal-type move introduced in Generation V. It is the signature move of Meloetta.
    # @see https://pokemondb.net/move/relic-song
    # @see https://bulbapedia.bulbagarden.net/wiki/Relic_Song_(move)
    # @see https://www.pokepedia.fr/Chant_Antique
    class RelicSong < Basic
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        super
        return unless user.db_symbol == :meloetta
        return if user.has_ability?(:sheer_force) && user.ability_effect&.activated?
        return if user.has_ability?(:parental_bond) && (user.ability_effect.number_of_attacks - user.ability_effect.attack_number != 1)
        return unless user.form_calibrate(:dance)
        scene.visual.battler_sprite(user.bank, user.position).pokemon = user
        scene.display_message_and_wait(parse_text(22, 157, ::PFM::Text::PKNAME[0] => user.given_name))
      end
    end
    Move.register(:s_relic_song, RelicSong)
    class Reload < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if user.effects.has?(:force_next_move_base)
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        user.effects.add(Effects::ForceNextMoveBase.new(@logic, user, self, actual_targets, turn_count))
      end
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity, :pp
      def on_move_failure(user, targets, reason)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 851, user)) if reason == :usable_by_user && user.effects.has?(:force_next_move_base)
      end
      # Return the number of turns the effect works
      # @return Integer
      def turn_count
        return 2
      end
    end
    Move.register(:s_reload, Reload)
    # Class managing Rest
    # @see https://bulbapedia.bulbagarden.net/wiki/Rest_(move)
    class Rest < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        if target.has_ability?(:insomnia) || target.has_ability?(:vital_spirit) || target.has_ability?(:sweet_veil) || target.has_ability?(:comatose)
          scene.visual.show_ability(target)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 451, target))
          return true
        else
          if target.hp == target.max_hp
            scene.display_message_and_wait(parse_text_with_pokemon(19, 451, target))
            return true
          else
            if target.effects.has?(:heal_block)
              txt = parse_text_with_pokemon(19, 893, user, '[VAR PKNICK(0000)]' => user.given_name, '[VAR MOVE(0001)]' => name)
              scene.display_message_and_wait(txt)
              return true
            else
              if @logic.field_terrain_effect.misty? && target.affected_by_terrain?
                scene.display_message_and_wait(parse_text_with_pokemon(19, 845, target))
                return true
              else
                if @logic.field_terrain_effect.electric? && target.affected_by_terrain?
                  scene.display_message_and_wait(parse_text_with_pokemon(19, 1207, target))
                  return true
                else
                  if uproar?
                    scene.display_message_and_wait(parse_text_with_pokemon(19, 709, target))
                    return true
                  end
                end
              end
            end
          end
        end
        return false
      end
      # If a pokemon is using Uproar
      # @return [Boolean]
      def uproar?
        fu = @logic.all_alive_battlers.find { |pkm| pkm.effects.has?(:uproar) }
        return !fu.nil?
      end
      # Function that deals the status condition to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_status(user, actual_targets)
        actual_targets.each do |target|
          scene.visual.show_info_bar(target)
          target.status_sleep(true, 3)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 306, target))
          hp = target.max_hp
          logic.damage_handler.heal(target, hp, test_heal_block: false) do
            scene.display_message_and_wait(parse_text_with_pokemon(19, 638, target))
          end
          target.item_effect.execute_berry_effect if target.item_effect.instance_of?(Effects::Item::StatusBerry::Chesto)
        end
      end
    end
    Move.register(:s_rest, Rest)
    # Inflicts double damage if a teammate fainted on the last turn.
    class Retaliate < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        check = @logic.all_battlers.any? { |battler| battler.from_party? && battler.damage_history.any? { |history| history.ko && history.last_turn? } }
        return check ? power * 2 : power
      end
    end
    Move.register(:s_retaliate, Retaliate)
    class Return < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        power = (user.loyalty / 2.5).clamp(1, 255)
        log_data("Power of Return: #{power}")
        return power
      end
    end
    Move.register(:s_return, Return)
    class RevelationDance < Basic
      def definitive_types(user, target)
        return [user.type1] if user.type1 && user.type1 != 0
        first_type, *rest = super
        return [first_type, *rest]
      end
    end
    Move.register(:s_revelation_dance, RevelationDance)
    # Move that deals Revenge to the target
    class Revenge < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        check = user.damage_history.any? { |history| history.turn == $game_temp.battle_turn && history.launcher == target }
        return check ? power * 2 : power
      end
    end
    Move.register(:s_revenge, Revenge)
    # Move that is used during 5 turn and get more powerfull until it gets interrupted
    class Rollout < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        rollout_effect = user.effects.get(effect_name)
        mod = rollout_effect.successive_uses if rollout_effect
        mod = (mod || 0) + 1 if user.successful_move_history.any? { |move| move.db_symbol == :defense_curl }
        return super * 2 ** (mod || 0)
      end
      private
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity
      def on_move_failure(user, targets, reason)
        user.effects.get(effect_name)&.kill
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        rollout_effect = user.effects.get(effect_name)
        return rollout_effect.increase if rollout_effect
        effect = create_effect(user, actual_targets)
        user.effects.replace(effect, &:force_next_move?)
        effect.increase
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :rollout
      end
      # Create the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Effects::EffectBase]
      def create_effect(user, actual_targets)
        Effects::Rollout.new(logic, user, self, actual_targets, 5)
      end
    end
    # Ice Ball deals damage for 5 turns, doubling in power each turn. The move stops if it misses on any turn.
    # @see https://pokemondb.net/move/ice-ball
    # @see https://bulbapedia.bulbagarden.net/wiki/Ice_Ball_(move)
    # @see https://www.pokepedia.fr/Ball%27Glace
    class IceBall < Rollout
      # Return the chance of hit of the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Float]
      def chance_of_hit(user, target)
        effect = user.effects.get(effect_name)
        return super unless effect
        result = (super * 0.9 ** effect.successive_uses).round
        log_data("chance of hit = #{result} \# ice ball successive use : #{effect.successive_uses}")
        return result
      end
    end
    Move.register(:s_rollout, Rollout)
    Move.register(:s_ice_ball, IceBall)
    class Roost < HealMove
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          hp = target.max_hp / 2
          target.effects.add(Effects::Roost.new(@logic, target, turn_count)) if logic.damage_handler.heal(target, hp)
        end
      end
      # Return the number of turns the effect works
      # @return Integer
      def turn_count
        return 1
      end
    end
    Move.register(:s_roost, Roost)
    # Rototiller move
    class Rototiller < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if logic.all_alive_battlers.none?(&:type_grass?)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the stats to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        super(user, logic.all_alive_battlers.select { |target| target.type_grass? && target.grounded? })
      end
    end
    Move.register(:s_rototiller, Rototiller)
    # Round deals damage. If multiple Pokémon on the same team use it in the same turn, the power doubles to 120 and the 
    # slower Pokémon move immediately after the fastest Pokémon uses it, regardless of their Speed.
    # @see https://pokemondb.net/move/round
    # @see https://bulbapedia.bulbagarden.net/wiki/Round_(move)
    # @see https://www.pokepedia.fr/Chant_Canon
    class Round < BasicWithSuccessfulEffect
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        mod = (any_allies_used_round?(user) ? 2 : 1)
        log_data("power * #{mod} \# round #{mod == 1 ? 'not' : ''} used by an ally this turn.")
        return super * mod
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.force_sort_actions do |a, b|
          next(a <=> b) unless a.is_a?(Actions::Attack) && b.is_a?(Actions::Attack)
          a_is_ally_and_round = logic.allies_of(user).include?(a.launcher) && a.move.db_symbol == :round
          b_is_ally_and_round = logic.allies_of(user).include?(b.launcher) && b.move.db_symbol == :round
          next(b.launcher.speed <=> a.launcher.speed) if a_is_ally_and_round && b_is_ally_and_round
          next(1) if a_is_ally_and_round
          next(-1) if b_is_ally_and_round
          next(a <=> b)
        end
      end
      # Test if any ally had used round in the current turn
      # @param user [PFM::PokemonBattler]
      # @return [Boolean]
      def any_allies_used_round?(user)
        logic.allies_of(user).any? do |ally|
          return true if ally.move_history.any? { |mh| mh.current_turn? && mh.move.db_symbol == :round }
        end
        return false
      end
    end
    register(:s_round, Round)
    # Inflict Sacred Sword to an enemy (ignore evasion and defense stats change)
    class SacredSword < Basic
      # Return the evasion modifier of the target
      # @param _target [PFM::PokemonBattler]
      # @return [Float]
      def evasion_mod(_target)
        return 1
      end
      # Statistic modifier calculation: DFE/DFS
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param ph_move [Boolean] true: physical, false: special
      # @return [Integer]
      def calc_def_stat_modifier(user, target, ph_move)
        return 1
      end
    end
    Move.register(:s_sacred_sword, SacredSword)
    # The user's party is protected from status conditions.
    # @see https://pokemondb.net/move/safeguard
    # @see https://bulbapedia.bulbagarden.net/wiki/Safeguard
    # @see https://www.pokepedia.fr/Rune_Protect
    class Safeguard < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if logic.bank_effects[user.bank].has?(effect_name)
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if logic.bank_effects[target.bank].has?(effect_name)
          logic.bank_effects[target.bank].add(create_effect(user, target))
          scene.display_message_and_wait(parse_text(18, 138 + target.bank.clamp(0, 1)))
        end
      end
      # Duration of the effect including the current turn
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def create_effect(user, target)
        Effects::Safeguard.new(logic, target.bank, 0, 5)
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :safeguard
      end
    end
    Move.register(:s_safe_guard, Safeguard)
    class SappySeed < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| can_affect_target?(target) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless can_affect_target?(target)
          @logic.add_position_effect(Effects::LeechSeed.new(@logic, user, target))
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 607, target))
        end
      end
      private
      # Check if the effect can affect the target
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def can_affect_target?(target)
        return false if target.dead? || target.type_grass?
        return false if target.effects.has? { |effect| %i[leech_seed_mark substitute].include?(effect.name) }
        return true
      end
    end
    Move.register(:s_sappy_seed, SappySeed)
    # Inflicts Scale Shot to an enemy (multi hit + drops the defense and rises the speed of the user by 1 stage each)
    class ScaleShot < MultiHit
      private
      # Function that defines the number of hits
      def hit_amount(user, actual_targets)
        return 5 if user.has_ability?(:skill_link)
        return MULTI_HIT_CHANCES.sample(random: @logic.generic_rng)
      end
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        super(user, [user])
      end
    end
    Move.register(:s_scale_shot, ScaleShot)
    # Secret Power deals damage and has a 30% chance of inducing a secondary effect on the opponent, depending on the environment.
    # @see https://pokemondb.net/move/secret-power
    # @see https://bulbapedia.bulbagarden.net/wiki/Secret_Power_(move)
    # @see https://www.pokepedia.fr/Force_Cach%C3%A9e
    class SecretPower < BasicWithSuccessfulEffect
      include Mechanics::LocationBased
      private
      # Play the move animation
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def play_animation(user, targets)
        @secret_power = element_by_location
        mock = Move.new(@secret_power.mock, 1, 1, @scene)
        mock.send(:play_animation, user, targets)
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return if logic.generic_rng.rand(100) > proc_chance
        actual_targets.each do |target|
          send(@secret_power.type, user, target, *@secret_power.params)
        end
      end
      # Change the target status
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param status [Symbol]
      def sp_status(user, target, status)
        logic.status_change_handler.status_change_with_process(status, target, user, self)
      end
      # Change a stat
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param stat [Symbol]
      # @param power [Integer]
      def sp_stat(user, target, stat, power)
        logic.stat_change_handler.stat_change_with_process(stat, power, target, user, self)
      end
      # Secret Power Card to pick
      class SPC
        attr_reader :mock, :type, :params
        # Create a new Secret Power possibility
        # @param mock [Symbol, Integer] ID or db_symbol of the animation move
        # @param type [Symbol] name of the function to call
        # @param params [Array<Object>] params to pass to the function
        def initialize(mock, type, *params)
          @mock = mock
          @type = type
          @params = params
        end
        def to_s
          "<SPC @mock=:#{@mock} @type=:#{@type} @params=#{@params}>"
        end
      end
      # Element by location type.
      # @return [Hash<Symbol, Array<Symbol>]
      def element_table
        SECRET_POWER_TABLE
      end
      # Chances of status/stat to proc out of 100
      # @return [Integer]
      def proc_chance
        30
      end
      class << self
        def reset
          const_set(:SECRET_POWER_TABLE, {})
        end
        # @param loc [Symbol] Name of the location type
        # @param mock [Symbol, Integer] ID or db_symbol of the move used for the animation
        # @param type [Symbol] name of the function to call
        # @param params [Array<Object>] params to pass to the function
        def register(loc, mock, type, *params)
          SECRET_POWER_TABLE[loc] ||= []
          SECRET_POWER_TABLE[loc] << SPC.new(mock, type, *params)
        end
      end
      reset
      register(:__undef__, :body_slam, :sp_status, :paralysis)
      register(:regular_ground, :body_slam, :sp_status, :paralysis)
      register(:building, :body_slam, :sp_status, :paralysis)
      register(:grass, :vine_whip, :sp_status, :sleep)
      register(:desert, :mud_slap, :sp_stat, :acc, -1)
      register(:cave, :rock_throw, :sp_status, :flinch)
      register(:water, :water_pulse, :sp_stat, :atk, -1)
      register(:shallow_water, :mud_shot, :sp_stat, :spd, -1)
      register(:snow, :avalanche, :sp_status, :freeze)
      register(:icy_cave, :ice_shard, :sp_status, :freeze)
      register(:volcanic, :incinerate, :sp_status, :burn)
      register(:burial, :shadow_sneak, :sp_status, :flinch)
      register(:soaring, :gust, :sp_stat, :spd, -1)
      register(:misty_terrain, :fairy_wind, :sp_stat, :ats, -1)
      register(:grassy_terrain, :vine_whip, :sp_status, :sleep)
      register(:electric_terrain, :thunder_shock, :sp_status, :paralysis)
      register(:psychic_terrain, :confusion, :sp_stat, :spd, -1)
    end
    Move.register(:s_secret_power, SecretPower)
    # Move that execute Self-Destruct / Explosion
    class SelfDestruct < BasicWithSuccessfulEffect
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if scene.logic.all_alive_battlers.any? { |battler| battler.has_ability?(:damp) }
          show_usage_failure(user)
          decrease_pp(user, targets)
          return false
        end
        return true
      end
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity, :pp
      def on_move_failure(user, targets, reason)
        return false if reason != :immunity
        play_animation(user, targets)
        deal_effect(user, [])
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.damage_handler.damage_change(user.hp, user)
      end
    end
    register(:s_explosion, SelfDestruct)
    class ShellSideArm < Basic
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @note The formula is the following:
      #       (((((((Level * 2 / 5) + 2) * BasePower * [Sp]Atk / 50) / [Sp]Def) * Mod1) + 2) *
      #         CH * Mod2 * R / 100) * STAB * Type1 * Type2 * Mod3)
      # @return [Integer]
      def damages(user, target)
        @physical = true
        @special = false
        physical_hp = super
        @physical = false
        @special = true
        special_hp = super
        if physical_hp > special_hp
          @physical = true
          @special = false
          return physical_hp
        else
          return special_hp
        end
      end
      # Is the skill physical ?
      # @return [Boolean]
      def physical?
        return @physical
      end
      # Is the skill special ?
      # @return [Boolean]
      def special?
        return @special
      end
      # Is the skill direct ?
      # @return [Boolean]
      def direct?
        return @physical
      end
    end
    Move.register(:s_shell_side_arm, ShellSideArm)
    # Class describing a heal move
    class ShoreUp < HealMove
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move           
      def deal_effect(user, targets)
        targets.each do |target|
          if $env.sandstorm?
            hp = target.max_hp * 2 / 3
          else
            hp = target.max_hp / 2
          end
          logic.damage_handler.heal(target, hp)
        end
      end
    end
    Move.register(:s_shore_up, ShoreUp)
    # Sketch move
    class Sketch < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.first.move_history.empty? || !user.moveset.include?(self) || user.transform
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        move_index = user.moveset.index(self)
        target_move = actual_targets.first.move_history.last.move
        new_skill = PFM::Skill.new(target_move.id)
        new_move = Battle::Move[new_skill.symbol].new(new_skill.id, new_skill.pp, new_skill.ppmax, scene)
        user.moveset[move_index] = new_move
        user.original.skills_set[move_index] = new_skill unless scene.battle_info.max_level
        scene.display_message_and_wait(parse_text_with_pokemon(19, 691, user, PFM::Text::MOVE[1] => new_move.name))
      end
    end
    Move.register(:s_sketch, Sketch)
    # Sky Drop takes the target into the air on the first turn, then drops them on the second turn, wherein they receive damage.
    # @see https://pokemondb.net/move/sky-drop
    # @see https://bulbapedia.bulbagarden.net/wiki/Sky_Drop_(move)
    # @see https://www.pokepedia.fr/Chute_Libre
    class SkyDrop < TwoTurnBase
      private
      # Return the list of the moves that can reach the pokemon event in out_of_reach, nil if all attack reach the user
      # @return [Array<Symbol>]
      CAN_HIT_MOVES = %i[gust hurricane sky_uppercut smack_down thunder twister]
      # Return the list of the moves that can reach the pokemon event in out_of_reach, nil if all attack reach the user
      # @return [Array<Symbol>]
      def can_hit_moves
        CAN_HIT_MOVES
      end
      # @param super_result [Boolean] the result of original method
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_userturn1(super_result, user, targets)
        return show_usage_failuer(user) && false if @logic.terrain_effects.has?(:gravity)
        return two_turn_move_usable_by_userturn1(super_result, user, targets)
      end
      # Display the message and the animation of the turn
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_message_turn1(user, targets)
        targets.each do |target|
          @scene.display_message_and_wait(parse_text_with_2pokemon(19, 1124, user, target))
        end
      end
      # Add the effects to the pokemons (first turn)
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def deal_effects_turn1(user, targets)
        two_turn_deal_effects_turn1(user, targets)
        targets.each do |target|
          target.effects.add(Effects::PreventTargetsMove.new(@logic, target, targets, 1))
        end
      end
    end
    Move.register(:s_sky_drop, SkyDrop)
    # Sleep Talk move
    class SleepTalk < Move
      CANNOT_BE_SELECTED_MOVES = %i[assist belch bide bounce copycat dig dive freeze_shock fly focus_punch geomancy ice_burn me_first metronome sleep_talk mirror_move mimic phantom_force razor_wind shadow_force sketch skull_bash sky_attack sky_drop solar_beam uproar]
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return true if user.has_ability?(:comatose) && !usable_moves(user).empty?
        return false unless super
        return show_usage_failure(user) && false if !user.asleep? || usable_moves(user).empty?
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        move = usable_moves(user).sample(random: @logic.generic_rng).dup
        move = Battle::Move[move.be_method].new(move.id, move.ppmax, move.ppmax, @scene)
        def move.move_usable_by_user(user, targets)
          return true
        end
        use_another_move(move, user)
      end
      # Function that list all the moves the user can pick
      # @param user [PFM::PokemonBattler]
      # @return [Array<Battle::Move>]
      def usable_moves(user)
        user.skills_set.reject { |skill| CANNOT_BE_SELECTED_MOVES.include?(skill.db_symbol) }
      end
    end
    Move.register(:s_sleep_talk, SleepTalk)
    # Move that deals damage and knocks the target to the ground
    class SmackDown < Basic
      private
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return false if actual_targets.all?(&:grounded?)
        return false if actual_targets.all? { |target| target.effects.has?(:substitute) } && !authentic?
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.grounded? || (target.effects.has?(:substitute) && !authentic?)
          target.effects.add(Effects::SmackDown.new(@scene.logic, target))
          scene.display_message_and_wait(parse_text_with_pokemon(19, 1134, target))
        end
      end
    end
    Move.register(:s_smack_down, SmackDown)
    # Snatch moves first and steals the effects of the next status move used by the opponent(s) in that turn.
    # @see https://pokemondb.net/move/snatch
    # @see https://bulbapedia.bulbagarden.net/wiki/Snatch_(move)
    # @see https://www.pokepedia.fr/Saisie
    class Snatch < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |pkm| pkm.effects.has?(effect_name) }
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(effect_name)
          target.effects.add(create_effect(user, target))
          scene.display_message_and_wait(deal_message(user, target))
        end
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :snatch
      end
      # Create the effect
      # @return [Battle::Effects::EffectBase]
      def create_effect(user, target)
        return Effects::Snatch.new(logic, target)
      end
      # Message displayed when the move succeed
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler]
      # @return [String]
      def deal_message(user, target)
        parse_text_with_pokemon(19, 751, target)
      end
    end
    Move.register(:s_snatch, Snatch)
    class Snore < Basic
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return true if user.has_ability?(:comatose)
        unless user.asleep?
          show_usage_failure(user)
          return false
        end
        return true
      end
    end
    Move.register(:s_snore, Snore)
    # The user of Solar Beam will absorb light on the first turn. On the second turn, Solar Beam deals damage.
    # @see https://pokemondb.net/move/solar-beam
    # @see https://bulbapedia.bulbagarden.net/wiki/Solar_Beam_(move)
    # @see https://www.pokepedia.fr/Lance-Soleil
    class SolarBeam < TwoTurnBase
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        power2 = power
        power2 *= 0.5 if $env.sandstorm? || $env.hail? || $env.rain?
        return power2
      end
      private
      # Check if the two turn move is executed in one turn
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean]
      def shortcut?(user, targets)
        return true if $env.sunny? || $env.hardsun?
        super
      end
      # Display the message and the animation of the turn
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_message_turn1(user, targets)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 553, user))
      end
    end
    Move.register(:s_solar_beam, SolarBeam)
    # Class that defines the move Sparkling Aria
    class SparklingAria < Basic
      # Function that indicates the status to check
      def status_condition
        return :burn
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.status == Configs.states.ids[status_condition]
          @logic.status_change_handler.status_change_with_process(:cure, target, user, self)
        end
      end
    end
    Move.register(:s_sparkling_aria, SparklingAria)
    class SparklySwirl < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        targets = @logic.all_battlers.select { |p| p.bank == user.bank && p.party_id == user.party_id && p.alive? }
        return targets.any?(&:status?)
      end
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        effect_targets = @logic.all_battlers.select { |p| p.bank == user.bank && (p.party_id == user.party_id || @logic.adjacent_allies_of(user).include?(p)) && p.alive? }
        effect_targets.each do |target|
          next unless target.status?
          @scene.logic.status_change_handler.status_change(:cure, target)
        end
      end
    end
    Move.register(:s_sparkly_swirl, SparklySwirl)
    class SpectralThief < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| target.battle_stage.any?(&:positive?) }
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.battle_stage.any?(&:positive?)
          target.battle_stage.each_with_index do |stat_value, index|
            next unless stat_value.positive?
            user.set_stat_stage(index, stat_value)
            target.set_stat_stage(index, 0)
          end
          @scene.display_message_and_wait(parse_text_with_pokemon(59, 1934, user))
        end
      end
    end
    Move.register(:s_spectral_thief, SpectralThief)
    # Move that inflict Spikes to the enemy bank
    class Spikes < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        target_bank = user.bank == 1 ? 0 : 1
        return true unless (effect = @logic.bank_effects[target_bank]&.get(:spikes))
        if effect.max_power?
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        if (effect = @logic.bank_effects[bank]&.get(:spikes))
          effect.empower
        else
          @logic.add_bank_effect(Effects::Spikes.new(@logic, bank))
        end
        @scene.display_message_and_wait(parse_text(18, bank == 0 ? 154 : 155))
      end
    end
    Move.register(:s_spike, Spikes)
    # Spit Up deals varying damage depending on how many times the user used Stockpile.
    # @see https://pokemondb.net/move/spit-up
    # @see https://bulbapedia.bulbagarden.net/wiki/Spit_Up_(move)
    # @see https://www.pokepedia.fr/Rel%C3%A2che
    class SpitUp < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless user.effects.get(effect_name)&.usable?
        return true
      end
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        effect = user.effects.get(effect_name)
        power = 100 * (effect&.stockpile || 1)
        log_data("\# power = #{power} <stockpile:#{effect&.stockpile || 1}>")
        return power
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return show_usage_failure(user) && false unless user.effects.get(effect_name)&.usable?
        user.effects.get(effect_name).use
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :stockpile
      end
    end
    Move.register(:s_split_up, SpitUp)
    # Spite decreases the move's PP by exactly 4.
    # @see https://bulbapedia.bulbagarden.net/wiki/Spite_(move)
    # @see https://www.pokepedia.fr/Dépit
    class Spite < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.all? { |target| target.skills_set[find_last_skill_position(target)]&.pp == 0 || target.move_history.empty? }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          last_skill = find_last_skill_position(target)
          next unless target.skills_set[last_skill].pp > 0
          num = 4.clamp(1, target.skills_set[last_skill].pp)
          target.skills_set[last_skill].pp -= num
          scene.display_message_and_wait(parse_text_with_pokemon(19, 641, target, PFM::Text::MOVE[1] => target.skills_set[last_skill].name, '[VAR NUM1(0002)]' => num.to_s))
        end
      end
      # Find the last skill used position in the moveset of the Pokemon
      # @param pokemon [PFM::PokemonBattler]
      # @return [Integer]
      def find_last_skill_position(pokemon)
        return 0 if pokemon.move_history.empty?
        pokemon.skills_set.each_with_index do |skill, i|
          return i if skill && skill.id == pokemon.move_history.last.move.id
        end
        return 0
      end
    end
    Move.register(:s_spite, Spite)
    # Class that manage the splash move
    # @see https://bulbapedia.bulbagarden.net/wiki/Splash_(move)
    # @see https://pokemondb.net/move/splash
    # @see https://www.pokepedia.fr/Trempette
    class Splash < Move
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @scene.display_message_and_wait(parse_text(18, 106))
      end
    end
    # Class that manage moves like Celebrate & Hold Hands
    class DoNothing < Move
      alias deal_effect void_true
    end
    Move.register(:s_splash, Splash)
    Move.register(:s_do_nothing, DoNothing)
    # Class that manage the Power Split move
    # @see https://bulbapedia.bulbagarden.net/wiki/Power_Split_(move)
    # @see https://pokemondb.net/move/power-split
    # @see https://www.pokepedia.fr/Partage_Force
    class PowerSplit < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        user.atk_basis = target.atk_basis = ((user.atk_basis + target.atk_basis) / 2).floor
        user.ats_basis = target.ats_basis = ((user.ats_basis + target.ats_basis) / 2).floor
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1102, user))
      end
    end
    Move.register(:s_power_split, PowerSplit)
    # Class that manage the Guard Split move
    # @see https://bulbapedia.bulbagarden.net/wiki/Guard_Split_(move)
    # @see https://pokemondb.net/move/guard-split
    # @see https://www.pokepedia.fr/Partage_Garde
    class GuardSplit < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        user.dfe_basis = target.dfe_basis = ((user.dfe_basis + target.dfe_basis) / 2).floor
        user.dfs_basis = target.dfs_basis = ((user.dfs_basis + target.dfs_basis) / 2).floor
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1105, user))
      end
    end
    Move.register(:s_guard_split, GuardSplit)
    # Class that manage Heart Swap move
    # @see https://bulbapedia.bulbagarden.net/wiki/Heart_Swap_(move)
    # @see https://pokemondb.net/move/heart-swap
    # @see https://www.pokepedia.fr/Permuc%C5%93ur
    class HeartSwap < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        target.acc_stage, user.acc_stage = user.acc_stage, target.acc_stage
        target.atk_stage, user.atk_stage = user.atk_stage, target.atk_stage
        target.ats_stage, user.ats_stage = user.ats_stage, target.ats_stage
        target.dfe_stage, user.dfe_stage = user.dfe_stage, target.dfe_stage
        target.dfs_stage, user.dfs_stage = user.dfs_stage, target.dfs_stage
        target.eva_stage, user.eva_stage = user.eva_stage, target.eva_stage
        target.spd_stage, user.spd_stage = user.spd_stage, target.spd_stage
        scene.display_message_and_wait(parse_text_with_pokemon(19, 673, user))
      end
    end
    Move.register(:s_heart_swap, HeartSwap)
    # Class that manage Power Swap move
    # @see https://bulbapedia.bulbagarden.net/wiki/Power_Swap_(move)
    # @see https://pokemondb.net/move/power-swap
    # @see https://www.pokepedia.fr/Permuforce
    class PowerSwap < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        target.atk_stage, user.atk_stage = user.atk_stage, target.atk_stage
        target.ats_stage, user.ats_stage = user.ats_stage, target.ats_stage
        scene.display_message_and_wait(parse_text_with_pokemon(19, 676, user))
      end
    end
    Move.register(:s_power_swap, PowerSwap)
    # Class that manage Guard Swap move
    # @see https://bulbapedia.bulbagarden.net/wiki/Guard_Swap_(move)
    # @see https://pokemondb.net/move/guard-swap
    # @see https://www.pokepedia.fr/Permugarde
    class GuardSwap < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        target.dfe_stage, user.dfe_stage = user.dfe_stage, target.dfe_stage
        target.dfs_stage, user.dfs_stage = user.dfs_stage, target.dfs_stage
        scene.display_message_and_wait(parse_text_with_pokemon(19, 679, user))
      end
    end
    Move.register(:s_guard_swap, GuardSwap)
    class SpeedSwap < StatAndStageEditBypassAccuracy
      private
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        user_old_spd, target_old_spd = user.spd_basis, target.spd_basis
        user.spd_basis, target.spd_basis = target.spd_basis, user.spd_basis
        log_data("speed swap of \##{target.name} exchanged the speeds stats (user speed:#{user_old_spd} > #{user.spd_basis}) (target speed:#{target_old_spd} > #{target.spd_basis})")
      end
    end
    Move.register(:s_speed_swap, SpeedSwap)
    # Move that inflict Stealth Rock to the enemy bank
    class StealthRock < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        target_bank = user.bank == 1 ? 0 : 1
        if @logic.bank_effects[target_bank]&.get(:stealth_rock)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Calculate the multiplier needed to get the damage factor of the Stealth Rock
      # @param target [PFM::PokemonBattler]
      # @return [Integer, Float]
      def calc_factor(target)
        type = [self.type]
        @effectiveness = -1
        n = calc_type_n_multiplier(target, :type1, type) * calc_type_n_multiplier(target, :type2, type) * calc_type_n_multiplier(target, :type3, type)
        return n
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        @logic.add_bank_effect(Effects::StealthRock.new(@logic, bank, self))
        @scene.display_message_and_wait(parse_text(18, bank == 0 ? 162 : 163))
      end
    end
    Move.register(:s_stealth_rock, StealthRock)
    # Implement the Stell Roller move
    class SteelRoller < Basic
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if @logic.field_terrain_effect.none?
        return true
      end
      # Function that deals the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.fterrain_change_handler.fterrain_change_with_process(:none)
      end
    end
    Move.register(:s_steel_roller, SteelRoller)
    # Move that inflict Sticky Web to the enemy bank
    class StickyWeb < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        target_bank = user.bank == 1 ? 0 : 1
        if @logic.bank_effects[target_bank]&.get(:sticky_web)
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        @logic.add_bank_effect(Effects::StickyWeb.new(@logic, bank, user))
        @scene.display_message_and_wait(parse_text(18, bank == 0 ? 214 : 215))
      end
    end
    Move.register(:s_sticky_web, StickyWeb)
    # Stockpile raises the user's Defense and Special Defense by one stage each and charges up power for use with companion moves Spit Up or Swallow.
    # @see https://pokemondb.net/move/stockpile
    # @see https://bulbapedia.bulbagarden.net/wiki/Stockpile_(move)
    # @see https://www.pokepedia.fr/Stockage
    class Stockpile < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless targets.any? { |target| !target.effects.has?(effect_name) || target.effects.get(effect_name).increasable? }
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target.effects.add(create_effect(user, target)) unless target.effects.has?(effect_name)
          target.effects.get(effect_name).increase
        end
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :stockpile
      end
      # Create the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target that will be affected by the move
      def create_effect(user, target)
        return Effects::Stockpile.new(logic, target)
      end
    end
    Move.register(:s_stockpile, Stockpile)
    class Stomp < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return super * 2 if target.effects.has?(:minimize)
        return super
      end
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true if target.effects.has?(:minimize)
        super
      end
    end
    Move.register(:s_stomp, Stomp)
    # Move that deals more damage if user has any stat boost
    class StoredPower < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        base_power = db_symbol == :stored_power ? 20 : 60
        stat_count = stat_increase_count(user)
        stat_count = stat_count.clamp(0, 7) if db_symbol == :punishment
        return 20 * stat_count + base_power
      end
      private
      # Get the number of increased stats
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Integer]
      def stat_increase_count(user)
        return user.atk_stage.clamp(0, Float::INFINITY) + user.dfe_stage.clamp(0, Float::INFINITY) + user.spd_stage.clamp(0, Float::INFINITY) + user.ats_stage.clamp(0, Float::INFINITY) + user.dfs_stage.clamp(0, Float::INFINITY) + user.acc_stage.clamp(0, Float::INFINITY) + user.eva_stage.clamp(0, Float::INFINITY)
      end
    end
    Move.register(:s_stored_power, StoredPower)
    # Class describing a move that drains HP
    class StrengthSap < Move
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          atkdrained = user.hold_item?(:big_root) ? target.atk * 130 / 100 : target.atk
          if target.has_ability?(:liquid_ooze)
            @scene.visual.show_ability(target)
            logic.damage_handler.damage_change(atkdrained, user)
            @scene.display_message_and_wait(parse_text_with_pokemon(19, 457, user))
          else
            logic.damage_handler.heal(user, atkdrained)
          end
        end
        return true
      end
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return show_usage_failure(user) && false if targets.all? do |target|
          (target.atk_stage == -6 && !target.effects.has?(:contrary)) || (target.atk_stage == 6 && target.effects.has?(:contrary))
        end
        return show_usage_failure(user) && false unless super
        return true
      end
      # Tell that the move is a drain move
      # @return [Boolean]
      def drain?
        return true
      end
    end
    Move.register(:s_strength_sap, StrengthSap)
    # Stuff Cheeks move
    class StuffCheeks < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false unless user.hold_berry?(user.battle_item_db_symbol)
        return true
      end
      # Get the reason why the move is disabled
      # @param user [PFM::PokemonBattler] user of the move
      # @return [#call] Block that should be called when the move is disabled
      def disable_reason(user)
        return proc {@logic.scene.display_message_and_wait(parse_text_with_pokemon(60, 508, user)) } unless user.hold_berry?(user.battle_item_db_symbol)
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.hold_berry?(target.battle_item_db_symbol)
          if target.item_effect.is_a?(Effects::Item::Berry)
            target.item_effect.execute_berry_effect(force_heal: true)
            if target.has_ability?(:cheek_pouch) && !target.effects.has?(:heal_block)
              @scene.visual.show_ability(target)
              @logic.damage_handler.heal(target, target.max_hp / 3)
            end
            scene.logic.stat_change_handler.stat_change_with_process(:dfe, 2, target, user, self)
          end
          @logic.item_change_handler.change_item(:none, true, target, user, self)
        end
      end
    end
    Move.register(:s_stuff_cheeks, StuffCheeks)
    # Move that put the mon into a substitue
    class Substitute < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if user.hp_rate <= 0.25
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if user.effects.has?(:substitute)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 788, user))
        else
          if user.hp_rate > 0.25
            hp = (user.max_hp / 4).floor
            scene.visual.show_hp_animations([user], [-hp])
            user.effects.add(Effects::Substitute.new(logic, user))
            scene.visual.show_switch_form_animation(user)
            scene.display_message_and_wait(parse_text_with_pokemon(19, 785, user))
          end
        end
      end
    end
    Move.register(:s_substitute, Substitute)
    class SuckerPunch < Basic
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.all? { |target| !logic.battler_attacks_after?(user, target) && target_move_is_status_move?(target) }
          return show_usage_failure(user) && false
        end
        return true
      end
      # Function that tells if the target is using a Move & if it's a status move
      # @return [Boolean]
      def target_move_is_status_move?(target)
        attacks = logic.actions.select { |action| action.is_a?(Actions::Attack) }
        return true unless (move = attacks.find { |action| action.launcher == target }&.move)
        return false if move&.db_symbol == :me_first
        return move&.status?
      end
    end
    Move.register(:s_sucker_punch, SuckerPunch)
    # Class managing Super Fang move
    class SuperFang < Basic
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        @critical = false
        @effectiveness = 1
        log_data("Forced HP Move: #{(target.hp / 2).clamp(1, Float::INFINITY)} HP")
        return (target.hp / 2).clamp(1, Float::INFINITY)
      end
    end
    Move.register(:s_super_fang, SuperFang)
    # Swallow recovers a varying amount of HP depending on how many times the user has used Stockpile.
    # @see https://pokemondb.net/move/swallow
    # @see https://bulbapedia.bulbagarden.net/wiki/Swallow_(move)
    # @see https://www.pokepedia.fr/Avale
    class Swallow < HealMove
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        unless targets.any? { |target| target.effects.has?(effect_name) || target.effects.get(effect_name)&.usable? }
          return show_usage_failure(user) && false
        end
        return true
      end
      private
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          effect = target.effects.get(effect_name)
          next unless effect&.usable?
          hp = target.max_hp * (ratio[effect.stockpile] || 0)
          log_error("Poorly configured moves, healed hp should be above zero. <stockpile:#{effect.stockpile}, ratios:#{ratio}") if hp <= 0
          log_data("\# heal (swallow) #{hp}hp (stockpile:#{effect.stockpile}, ratio:#{ratio[effect.stockpile]}")
          if logic.damage_handler.heal(target, hp)
            effect.use
          end
        end
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :stockpile
      end
      # Healing value depending on stockpile
      # @return [Array]
      RATIO = [nil, 0.25, 0.5, 1]
      # Healing value depending on stockpile
      # @return [Array]
      def ratio
        RATIO
      end
    end
    Move.register(:s_swallow, Swallow)
    class Switcheroo < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        unless @logic.item_change_handler.can_lose_item?(user) || targets.any? { |target| @logic.item_change_handler.can_lose_item?(target, user) }
          show_usage_failure(user)
          return false
        end
        return true
      end
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          target_item = target.battle_item_db_symbol
          user_item = user.battle_item_db_symbol
          @logic.item_change_handler.change_item(user_item, false, target, user, self)
          @logic.item_change_handler.change_item(target_item, false, user, user, self)
          @scene.display_message_and_wait(first_message(user))
          @scene.display_message_and_wait(second_message(user)) if target_item != :__undef__
        end
      end
      # First message displayed
      def first_message(pokemon)
        parse_text_with_pokemon(19, 682, pokemon)
      end
      # Second message displayed
      def second_message(pokemon)
        parse_text_with_pokemon(19, 685, pokemon, ::PFM::Text::ITEM2[1] => pokemon.item_name)
      end
    end
    Move.register(:s_trick, Switcheroo)
    # class managing moves that damages all adjacent enemies that share one type with the user
    class Synchronoise < Basic
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if user.typeless? || targets.none? { |target| share_types?(user, target) }
          show_usage_failure(user)
          return false
        end
        return true if super
      end
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        actual_targets.each do |target|
          next unless share_types?(user, target)
          hp = damages(user, target)
          @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
            if critical_hit?
              scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
            else
              if hp > 0
                efficent_message(effectiveness, target)
              end
            end
          end
          recoil(hp, user) if recoil?
        end
        return true
      end
      # Tell if the user share on type with the target
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def share_types?(user, target)
        return target.type?(user.type1) || target.type?(user.type2) || (target.type?(user.type3) && user.type3 != 0)
      end
    end
    Move.register(:s_synchronoise, Synchronoise)
    # class managing Tailwind move
    class Tailwind < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param _targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, _targets)
        return false unless super
        return show_usage_failure(user) && false if logic.bank_effects[user.bank].has?(:tailwind)
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param _actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, _actual_targets)
        @logic.add_bank_effect(Effects::Tailwind.new(@logic, user.bank))
        @scene.display_message_and_wait(parse_text(18, 146 + user.bank))
      end
    end
    Move.register(:s_tailwind, Tailwind)
    class TarShot < Basic
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:tar_shot)
          target.effects.add(Effects::TarShot.new(@logic, target, db_symbol))
        end
      end
    end
    Move.register(:s_tar_shot, TarShot)
    # Taunt move
    class Taunt < Move
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[oblivious aroma_veil]
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:taunt)
        ally = @logic.allies_of(target).find { |a| BLOCKING_ABILITY.include?(a.battle_ability_db_symbol) }
        if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
          @scene.visual.show_ability(target)
          return true
        else
          if user.can_be_lowered_or_canceled? && ally
            @scene.visual.show_ability(ally)
            return true
          end
        end
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          message = parse_text_with_pokemon(19, 568, target)
          target.effects.add(Effects::Taunt.new(@logic, target))
          @scene.display_message_and_wait(message)
        end
      end
    end
    Move.register(:s_taunt, Taunt)
    # Teatime move
    class Teatime < Move
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return @scene.display_message_and_wait(parse_text(18, 106)) && false if actual_targets.none? { |target| target.hold_berry?(target.battle_item_db_symbol) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        @scene.display_message_and_wait(parse_text(60, 404))
        actual_targets.each do |target|
          next unless target.hold_berry?(target.battle_item_db_symbol)
          if target.item_effect.is_a?(Effects::Item::Berry)
            target_effect = Effects::Item.new(logic, target, target.item_effect.db_symbol)
            target_effect.execute_berry_effect(force_heal: true)
            if target.has_ability?(:cheek_pouch) && !target.effects.has?(:heal_block)
              @scene.visual.show_ability(target)
              @logic.damage_handler.heal(target, target.max_hp / 3)
            end
          end
        end
      end
    end
    Move.register(:s_teatime, Teatime)
    class TechnoBlast < Basic
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        unless user.db_symbol == :genesect
          show_usage_failure(user)
          return false
        end
        return true if super
      end
    end
    Move.register(:s_techno_blast, TechnoBlast)
    # Telekinesis raises the target into the air for three turns, guaranteeing that all attacks against 
    # the target (except OHKO moves) will hit, regardless of Accuracy or Evasion.
    # @see https://pokemondb.net/move/telekinesis
    # @see https://bulbapedia.bulbagarden.net/wiki/Telekinesis_(move)
    # @see https://www.pokepedia.fr/L%C3%A9vikin%C3%A9sie
    # @see [Effects::Telekinesis]
    class Telekinesis < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        return true if target.effects.has?(effect_name)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(effect_name)
          target.effects.add(create_effect(user, target))
        end
      end
      private
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :telekinesis
      end
      # Create the effect applied to the target
      # @return [Effects::EffectBase]
      def create_effect(user, target)
        Effects::Telekinesis.new(logic, target, 4)
      end
    end
    Move.register(:s_telekinesis, Telekinesis)
    # Class managing Teleport move
    class Teleport < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def effect_working?(user, targets)
        return false if $game_switches[Yuki::Sw::BT_NoEscape]
        reason = @logic.battle_info.trainer_battle? ? :switch : :flee
        targets.any? do |target|
          return true if target.hold_item?(:smoke_ball)
          return false unless @logic.switch_handler.can_switch?(target, self, reason: reason)
        end
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          if @logic.battle_info.trainer_battle?
            @logic.switch_request << {who: target}
          else
            @battler_s = @scene.visual.battler_sprite(target.bank, target.position)
            @battler_s.flee_animation
            @logic.scene.visual.wait_for_animation
            scene.display_message_and_wait(parse_text_with_pokemon(19, 767, target))
            @logic.battle_result = 1
          end
        end
      end
    end
    Move.register(:s_teleport, Teleport)
    # Move that execute Misty Explosion
    class MistyExplosion < SelfDestruct
      def real_base_power(user, target)
        return power * 1.5 if @logic.field_terrain_effect.misty?
        return super
      end
    end
    register(:s_misty_explosion, MistyExplosion)
    # Move that execute Expanding Force
    class ExpandingForce < BasicWithSuccessfulEffect
      def real_base_power(user, target)
        return power * 1.5 if @logic.field_terrain_effect.psychic? && user.grounded?
        return super
      end
      def deal_effect(user, actual_targets)
        return unless user.grounded? && @logic.field_terrain_effect.psychic?
        targets = @logic.adjacent_allies_of(actual_targets.first)
        deal_damage(user, targets)
      end
    end
    register(:s_expanding_force, ExpandingForce)
    # Move that execute Rising Voltage
    class RisingVoltage < Basic
      def real_base_power(user, target)
        return power * 2 if @logic.field_terrain_effect.electric? && target.grounded?
        return super
      end
    end
    register(:s_rising_voltage, RisingVoltage)
    # Move that execute Grassy Glide
    class GrassyGlide < BasicWithSuccessfulEffect
      # Return the priority of the skill
      # @param user [PFM::PokemonBattler] user for the priority check
      # @return [Integer]
      def priority(user = nil)
        priority = super
        priority += 1 if priority < 14 && @logic.field_terrain_effect.grassy? && user && user.grounded?
        return priority
      end
    end
    register(:s_grassy_glide, GrassyGlide)
    class TerrainMove < Move
      TERRAIN_MOVES = {electric_terrain: :electric_terrain, grassy_terrain: :grassy_terrain, misty_terrain: :misty_terrain, psychic_terrain: :psychic_terrain}
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        logic.fterrain_change_handler.fterrain_change_with_process(TERRAIN_MOVES[db_symbol])
      end
    end
    Move.register(:s_terrain, TerrainMove)
    class TerrainPulse < Basic
      # Return the current type of the move
      # @return [Integer]
      def type
        return data_type(:electric).id if @logic.field_terrain_effect.electric?
        return data_type(:grass).id if @logic.field_terrain_effect.grassy?
        return data_type(:psychic).id if @logic.field_terrain_effect.psychic?
        return data_type(:fairy).id if @logic.field_terrain_effect.misty?
        return data_type(data.type).id
      end
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        base_power = user.grounded? && !@logic.field_terrain_effect.none? ? 100 : 50
        return base_power
      end
    end
    Move.register(:s_terrain_pulse, TerrainPulse)
    # Class managing the Thief move
    class Thief < BasicWithSuccessfulEffect
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless @logic.item_change_handler.can_lose_item?(target, user) && %i[none __undef__].include?(user.item_db_symbol)
          next if user.dead? && target.hold_item?(:rocky_helmet) || %i[rough_skin iron_barbs].include?(target.battle_ability_db_symbol)
          additionnal_variables = {PFM::Text::ITEM2[2] => target.item_name, PFM::Text::PKNICK[1] => target.given_name}
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1063, user, additionnal_variables))
          target_item = target.item_db_symbol
          if $game_temp.trainer_battle
            @logic.item_change_handler.change_item(target_item, false, user, user, self)
            if target.from_party? && !target.effects.has?(:item_stolen)
              @logic.item_change_handler.change_item(:none, false, target, user, self)
              target.effects.add(Effects::ItemStolen.new(@logic, target))
            else
              @logic.item_change_handler.change_item(:none, true, target, user, self)
            end
          else
            overwrite = user.from_party? && !target.from_party?
            @logic.item_change_handler.change_item(target_item, overwrite, user, user, self)
            @logic.item_change_handler.change_item(:none, false, target, user, self)
          end
        end
      end
    end
    Move.register(:s_thief, Thief)
    # Thrash Move
    class Thrash < BasicWithSuccessfulEffect
      private
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity
      def on_move_failure(user, targets, reason)
        effect = user.effects.get(:force_next_move_base)
        return if effect.nil?
        return effect.kill unless effect.triggered?
        logic.status_change_handler.status_change_with_process(:confusion, user, nil, self) unless user.confused?
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        effect = user.effects.get(:force_next_move_base)
        if effect
          logic.status_change_handler.status_change_with_process(:confusion, user, nil, self) if effect.triggered? && !user.confused?
        else
          user.effects.add(Effects::ForceNextMoveBase.new(logic, user, self, actual_targets, turn_count))
        end
      end
      # Return the number of turns the effect works
      # @return Integer
      def turn_count
        return @logic.generic_rng.rand(2..3)
      end
    end
    Move.register(:s_thrash, Thrash)
    Move.register(:s_outrage, Thrash)
    class ThroatChop < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        return actual_targets.any? { |target| !target.effects.has?(:throat_chop) }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:throat_chop)
          target.effects.add(Effects::ThroatChop.new(logic, target, user, turn_count, self))
        end
      end
      private
      # Return the number of turns the effect works
      # @return Integer
      def turn_count
        return 3
      end
    end
    Move.register(:s_throat_chop, ThroatChop)
    # Accuracy depends of weather.
    # @see https://pokemondb.net/move/thunder
    # @see https://bulbapedia.bulbagarden.net/wiki/Thunder_(move)
    # @see https://www.pokepedia.fr/Fatal-Foudre
    class Thunder < Basic
      # Return the current accuracy of the move
      # @return [Integer]
      def accuracy
        al = @scene.logic.all_alive_battlers.any? { |battler| battler.has_ability?(:cloud_nine) || battler.has_ability?(:air_lock) }
        return super if al
        return 50 if $env.sunny? || $env.hardsun?
        return 0 if $env.rain? || $env.hardrain?
        return super
      end
    end
    Move.register(:s_thunder, Thunder)
    Move.register(:s_hurricane, Thunder)
    # Class managing the Topsy-Turvy move
    class TopsyTurvy < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return false if targets.all? { |target| target.battle_stage.all?(&:zero?) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.battle_stage.all?(&:zero?)
          target.battle_stage.each_with_index do |value, index|
            next if value == 0
            target.set_stat_stage(index, -value)
          end
          @scene.display_message_and_wait(parse_text_with_pokemon(19, 1177, target))
        end
      end
    end
    Move.register(:s_topsy_turvy, TopsyTurvy)
    # Torment Move
    class Torment < Move
      # Ability preventing the move from working
      BLOCKING_ABILITY = %i[aroma_veil]
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return true if target.effects.has?(:torment)
        ally = @logic.allies_of(target).find { |a| BLOCKING_ABILITY.include?(a.battle_ability_db_symbol) }
        if user.can_be_lowered_or_canceled?(BLOCKING_ABILITY.include?(target.battle_ability_db_symbol))
          @scene.visual.show_ability(target)
          return true
        else
          if user.can_be_lowered_or_canceled? && ally
            @scene.visual.show_ability(ally)
            return true
          end
        end
        return super
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          message = parse_text_with_pokemon(19, 577, target)
          target.effects.add(Effects::Torment.new(@logic, target))
          @scene.display_message_and_wait(message)
        end
      end
    end
    Move.register(:s_torment, Torment)
    class ToxicThread < Move
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        cannot_stat = battle_stage_mod.all? { |stage| stage.count == 0 || !@logic.stat_change_handler.stat_decreasable?(stage.stat, target, user, self) }
        cannot_status = status_effects.all? { |status| status.luck_rate == 0 || !@logic.status_change_handler.status_appliable?(status.status, target, user, self) }
        return failure_message if cannot_stat && cannot_status
        return super
      end
      private
      # Display failure message
      # @return [Boolean] true for blocking
      def failure_message
        logic.scene.display_message_and_wait(parse_text(18, 74))
        return true
      end
    end
    Move.register(:s_toxic_thread, ToxicThread)
    # Move that inflict Toxic Spikes to the enemy bank
    class ToxicSpikes < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return true
      end
      private
      # Test if the target is immune
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @return [Boolean]
      def target_immune?(user, target)
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        bank = actual_targets.map(&:bank).first
        if (effect = @logic.bank_effects[bank]&.get(:toxic_spikes))
          effect.empower
        else
          @logic.add_bank_effect(Effects::ToxicSpikes.new(@logic, bank))
        end
        @scene.display_message_and_wait(parse_text(18, bank == 0 ? 158 : 159))
      end
    end
    Move.register(:s_toxic_spike, ToxicSpikes)
    # Class managing moves that deal a status or flinch
    class Transform < BasicWithSuccessfulEffect
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        unless logic.transform_handler.can_transform?(user)
          show_usage_failure(user)
          return false
        end
        return true
      end
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        return !logic.transform_handler.can_copy?(target)
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        target = actual_targets
        user.transform = target.sample(random: logic.generic_rng)
        scene.visual.show_switch_form_animation(user)
        scene.visual.wait_for_animation
        scene.display_message_and_wait(parse_text_with_2pokemon(*message_id, user, user.transform))
        user.effects.add(Effects::Transform.new(logic, user))
        user.type1 = data_type(:normal).id if user.transform.type1 == 0
      end
      # Return the text's CSV ids
      # @return [Array<Integer>]
      def message_id
        return 19, 644
      end
    end
    Move.register(:s_transform, Transform)
    # Class managing moves that deal a status between three ones
    class TriAttack < Basic
      # Function that deals the status condition to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_status(user, actual_targets)
        return true if status_effects.empty?
        status = %i[paralysis burn freeze].sample(random: @logic.generic_rng)
        actual_targets.each do |target|
          @logic.status_change_handler.status_change_with_process(status, target, user, self)
        end
      end
    end
    Move.register(:s_tri_attack, TriAttack)
    # Move changing speed order of Pokemon
    class TrickRoom < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        effect_klass = Effects::TrickRoom
        if logic.terrain_effects.each.any? { |effect| effect.class == effect_klass }
          logic.terrain_effects.each { |effect| effect&.kill if effect.class == effect_klass }
          return false
        end
        logic.terrain_effects.add(Effects::TrickRoom.new(@scene.logic))
        scene.display_message_and_wait(parse_text_with_pokemon(19, 860, user))
      end
    end
    Move.register(:s_trick_room, TrickRoom)
    # Trump Card inflicts more damage when fewer PP are left, as per the table.
    # @see https://pokemondb.net/move/trump-card
    # @see https://bulbapedia.bulbagarden.net/wiki/Trump_Card_(move)
    # @see https://www.pokepedia.fr/Atout
    class TrumpCard < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        res = power_table[pp] || default_power
        log_data("power = #{res} \# trump card (pp:#{pp})")
        return res
      end
      private
      # Check if the move bypass chance of hit and cannot fail
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Boolean]
      def bypass_chance_of_hit?(user, target)
        return true unless target.effects.has?(&:out_of_reach?)
        super
      end
      # Power table
      # Array<Integer>
      POWER_TABLE = [200, 80, 60, 50]
      # Power table
      # @return [Array<Integer>]
      def power_table
        POWER_TABLE
      end
      # Power of the move if the power table is nil at pp index
      # @return [Integer]
      def default_power
        40
      end
    end
    register(:s_trump_card, TrumpCard)
    # Class managing moves that allow a Pokemon to hit and switch
    class UTurn < Move
      # Tell if the move is a move that switch the user if that hit
      def self_user_switch?
        return true
      end
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return true if status?
        raise 'Badly configured move, it should have positive power' if power < 0
        actual_targets.each do |target|
          @hp = damages(user, target)
          @logic.damage_handler.damage_change_with_process(@hp, target, user, self) do
            if critical_hit?
              scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
            else
              if @hp > 0
                efficent_message(effectiveness, target)
              end
            end
          end
          recoil(@hp, user) if recoil?
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return false unless @logic.switch_handler.can_switch?(user, self)
        return false if user.item_effect.is_a?(Effects::Item::RedCard)
        return false if actual_targets.any? { |target| target.item_effect.is_a?(Effects::Item::EjectButton) }
        return false if actual_targets.any? { |target| target.has_ability?(:emergency_exit) && (target.hp + @hp) > target.max_hp / 2 && target.alive? }
        @logic.switch_request << {who: user}
      end
    end
    Move.register(:s_u_turn, UTurn)
    # Uproar inflicts damage for 3 turns. During this time, no Pokémon on the field will be able to sleep, and any sleeping Pokémon will be woken up.
    # @see https://pokemondb.net/move/uproar
    # @see https://bulbapedia.bulbagarden.net/wiki/Uproar_(move)
    # @see https://www.pokepedia.fr/Brouhaha
    class UpRoar < BasicWithSuccessfulEffect
      # List the targets of this move
      # @param pokemon [PFM::PokemonBattler] the Pokemon using the move
      # @param logic [Battle::Logic] the battle logic allowing to find the targets
      # @return [Array<PFM::PokemonBattler>] the possible targets
      # @note use one_target? to select the target inside the possible result
      def battler_targets(pokemon, logic)
        @uproaring = pokemon.effects.has?(effect_name)
        return super
      end
      # Return the target symbol the skill can aim
      # @return [Symbol]
      def target
        return @uproaring ? :adjacent_foe : super
      end
      private
      # Event called if the move failed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity
      def on_move_failure(user, targets, reason)
        user.effects.get(effect_name)&.kill
        scene.display_message_and_wait(calm_down_message(user))
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return if user.effects.has?(effect_name)
        user.effects.add(create_effect(user, actual_targets))
        logic.terrain_effects.add(Effects::UpRoar::SleepPrevention.new(logic, user))
      end
      # Method responsive testing accuracy and immunity.
      # It'll report the which pokemon evaded the move and which pokemon are immune to the move.
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Array<PFM::PokemonBattler>]
      def accuracy_immunity_test(user, targets)
        [super.sample(random: logic.generic_rng)]
      end
      # Name of the effect
      # @return [Symbol]
      def effect_name
        :uproar
      end
      # Create the effect
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets
      # @return [Effects::EffectBase]
      def create_effect(user, actual_targets)
        Effects::UpRoar.new(logic, user, self, actual_targets, 3)
      end
      # Message displayed when the move fails and the pokemon calm down
      # @param user [PFM::PokemonBattler] user of the move
      # @return [String]
      def calm_down_message(user)
        parse_text_with_pokemon(19, 718, user)
      end
    end
    Move.register(:s_uproar, UpRoar)
    class VenomDrench < Move
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        if targets.none? { |target| target.poisoned? || target.toxic? }
          return show_usage_failure(user) && false
        end
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next unless target.poisoned? || target.toxic?
          logic.stat_change_handler.stat_change_with_process(:atk, -1, target, user)
          logic.stat_change_handler.stat_change_with_process(:ats, -1, target, user)
          logic.stat_change_handler.stat_change_with_process(:spd, -1, target, user)
        end
      end
    end
    Move.register(:s_venom_drench, VenomDrench)
    # Class managing Venoshock move
    class Venoshock < Basic
      # Method calculating the damages done by the actual move
      # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def damages(user, target)
        dmg = super
        dmg *= 2 if target.poisoned? || target.toxic?
        log_data("PSDK Venoshock Damages: #{dmg}")
        return dmg
      end
    end
    Move.register(:s_venoshock, Venoshock)
    class WeatherBall < Basic
      # Return the current type of the move
      # @return [Integer]
      def type
        al = @scene.logic.all_alive_battlers.any? { |battler| battler.has_ability?(:cloud_nine) || battler.has_ability?(:air_lock) }
        return data_type(data.type).id if al
        return data_type(:fire).id if $env.sunny? || $env.hardsun?
        return data_type(:water).id if $env.rain? || $env.hardrain?
        return data_type(:ice).id if $env.hail?
        return data_type(:rock).id if $env.sandstorm?
        return data_type(data.type).id
      end
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        base_power = $env.normal? ? 50 : 100
        return base_power
      end
    end
    Move.register(:s_weather_ball, WeatherBall)
    class WeatherMove < Move
      WEATHER_MOVES = {rain_dance: :rain, sunny_day: :sunny, sandstorm: :sandstorm, hail: :hail}
      WEATHER_ITEMS = {rain_dance: :damp_rock, sunny_day: :heat_rock, sandstorm: :smooth_rock, hail: :icy_rock}
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        nb_turn = user.hold_item?(WEATHER_ITEMS[db_symbol]) ? 8 : 5
        logic.weather_change_handler.weather_change_with_process(WEATHER_MOVES[db_symbol], nb_turn)
      end
    end
    Move.register(:s_weather, WeatherMove)
    # Move that setup a Wish that heals the Pokemon at the target's position
    class Wish < Move
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        !actual_targets.all? { |target| logic.bank_effects[target.bank].has?(:wish) && logic.bank_effects[target.bank].get(:wish).position == target.position }
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if logic.bank_effects[target.bank].has?(:wish) && logic.bank_effects[target.bank].get(:wish).position == target.position
          logic.bank_effects[target.bank].add(Battle::Effects::Wish.new(logic, target.bank, target.position, target.max_hp / 2))
        end
      end
    end
    Move.register(:s_wish, Wish)
    # Wonder Room switches the Defense and Special Defense of all Pokémon in battle, for 5 turns.
    # @see https://pokemondb.net/move/wonder-room
    # @see https://bulbapedia.bulbagarden.net/wiki/Wonder_Room_(move)
    # @see https://www.pokepedia.fr/Zone_%C3%89trange/G%C3%A9n%C3%A9ration_6
    class WonderRoom < Move
      private
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        if logic.terrain_effects.has?(:wonder_room)
          logic.terrain_effects.get(:wonder_room)&.kill
        else
          logic.terrain_effects.add(Effects::WonderRoom.new(logic, actual_targets, duration))
        end
      end
      # Duration of the effect
      # @return [Integer]
      def duration
        5
      end
    end
    register(:s_wonder_room, WonderRoom)
    class WringOut < Basic
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return (max_power * target.hp_rate).clamp(1, Float::INFINITY)
      end
      # Get the max power the moves can have
      # @return [Integer]
      def max_power
        return 120
      end
    end
    Move.register(:s_wring_out, WringOut)
    # Class that manage the Yawn skill, works together with the Effects::Drowsiness class
    # @see https://bulbapedia.bulbagarden.net/wiki/Yawn_(move)
    class Yawn < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        target_with_ability = @logic.foes_of(user).find { |target| %i[sweet_veil flower_veil].include?(target.battle_ability_db_symbol) }
        if target_with_ability
          @logic.scene.visual.show_ability(target_with_ability)
          show_usage_failure(user)
          return false
        end
        if targets.any? { |target| @logic.bank_effects[target.bank].has?(:safeguard) || %i[electric_terrain misty_terrain].include?(logic.field_terrain) && target.grounded? }
          return show_usage_failure(user) && false
        end
        return true
      end
      # Function that tests if the targets blocks the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
      # @return [Boolean] if the target evade the move (and is not selected)
      def move_blocked_by_target?(user, target)
        return true if super
        return failure_message(target) if target.status?
        return failure_message(target) if %i[drowsiness substitute].any? { |db_symbol| target.effects.has?(db_symbol) } || target.status?
        return failure_message(target) if %i[insomnia vital_spirit comatose].include?(target.battle_ability_db_symbol)
        return failure_message(target) if ($env.sunny? || $env.hardsun?) && target.has_ability?(:leaf_guard)
        return failure_message(target) if target.db_symbol == :minior && target.form == 0
        return false
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(:drowsiness)
          target.effects.add(Effects::Drowsiness.new(@logic, target, turn_count, user))
        end
      end
      # Return the turn countdown before the effect proc (including the current one)
      # @return [Integer]
      def turn_count
        2
      end
      # Display failure message
      # @param target [PFM::PokemonBattler] expected target
      # @return [Boolean] true if blocked
      def failure_message(target)
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(59, 2048, target))
        return true
      end
    end
    Move.register(:s_yawn, Yawn)
  end
end
