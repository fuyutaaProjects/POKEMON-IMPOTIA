module Battle
  class Move
    module Mechanics
      # Preset used for counter attacks
      # Should be included only in a Battle::Move class or a class with the same interface
      # The includer must overwrite the following methods:
      # - counter_fails?(attacker, user, targets)
      module Counter
        # Function that tests if the user is able to use the move
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
        # @return [Boolean] if the procedure can continue
        def move_usable_by_user(user, targets)
          return false unless super
          return show_usage_failure(user) && false if counter_fails?(last_attacker(user), user, targets)
          return true
        end
        alias counter_move_usable_by_user move_usable_by_user
        # Method calculating the damages done by counter
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @return [Integer]
        def damages(user, target)
          @effectiveness = 1
          @critical = false
          return 1 unless (attacker = last_attacker(user))
          log_data("damages = #{(attacker.move_history.last.move.damage_dealt * damage_multiplier).floor.clamp(1, Float::INFINITY)} \# after counter")
          return (attacker.move_history.last.move.damage_dealt * damage_multiplier).floor.clamp(1, Float::INFINITY)
        end
        alias counter_damages damages
        private
        # Test if the attack fails
        # @param attacker [PFM::PokemonBattler] the last attacker
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @return [Boolean] does the attack fails ?
        def counter_fails?(attacker, user, targets)
          log_error("#{self.class} should overwrite #{__method__}")
          return false
        end
        # Damage multiplier if the effect proc
        # @return [Integer, Float]
        def damage_multiplier
          2
        end
        # Method responsive testing accuracy and immunity.
        # It'll report the which pokemon evaded the move and which pokemon are immune to the move.
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @return [Array<PFM::PokemonBattler>]
        def accuracy_immunity_test(user, targets)
          super(user, [last_attacker(user)].compact)
        end
        alias counter_accuracy_immunity_test accuracy_immunity_test
        # Get the last pokemon that used a skill over the user
        # @param user [PFM::PokemonBattler]
        # @return [PFM::PokemonBattler, nil]
        def last_attacker(user)
          foes = logic.foes_of(user).sort { |a, b| b.attack_order <=> a.attack_order }
          attacker = foes.find { |foe| foe.move_history&.last&.targets&.include?(user) && foe.move_history.last.turn == $game_temp.battle_turn }
          return attacker
        end
        alias counter_last_attacker last_attacker
      end
      # Preset used for item based attacks
      # Should be included only in a Battle::Move class or a class with the same interface
      # The includer must overwrite the following methods:
      # - private consume_item?
      # - private valid_item_hold?
      module ItemBased
        # Function that tests if the user is able to use the move
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
        # @return [Boolean] if the procedure can continue
        def move_usable_by_user(user, targets)
          return false unless super
          return show_usage_failure(user) && false unless valid_held_item?(user.item_db_symbol)
          return true
        end
        alias item_based_move_usable_by_user move_usable_by_user
        private
        # Method calculating the damages done by the actual move
        # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @note The formula is the following:
        #       (((((((Level * 2 / 5) + 2) * BasePower * [Sp]Atk / 50) / [Sp]Def) * Mod1) + 2) *
        #         CH * Mod2 * R / 100) * STAB * Type1 * Type2 * Mod3)
        # @return [Integer]
        def damages(user, target)
          power = super
          consume_item(user)
          return power
        end
        alias item_based_damages damages
        # Remove the item from the battler
        # @param battler [PFM::PokemonBattler]
        def consume_item(battler)
          return unless consume_item?
          return if battler.has_ability?(:parental_bond) && battler.ability_effect.number_of_attacks - battler.ability_effect.attack_number == 1
          @logic.item_change_handler.change_item(:none, true, battler, battler, self)
        end
        # Tell if the move consume the item
        # @return [Boolean]
        def consume_item?
          log_error("#{__method__} should be overwritten by #{self.class}")
          false
        end
        # Test if the held item is valid
        # @param name [Symbol]
        # @return [Boolean]
        def valid_held_item?(name)
          log_error("#{__method__} should be overwritten by #{self.class}")
          return false
        end
      end
      # Preset used for attacks with power based on held item.
      # Should be included only in a Battle::Move class or a class with the same interface
      # The includer must overwrite the following methods:
      # - private consume_item?
      # - private valid_item_hold?
      # - private get_power_by_item
      module PowerBasedOnItem
        include ItemBased
        # Get the real base power of the move (taking in account all parameter)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @return [Integer]
        def real_base_power(user, target)
          return super unless valid_held_item?(user.item_db_symbol)
          log_data("power = #{get_power_by_item(user.item_db_symbol)} \# move based on held item")
          return get_power_by_item(user.item_db_symbol)
        end
        alias power_based_on_item_real_base_power real_base_power
        private
        # Get the real power of the move depending on the item
        # @param name [Symbol]
        # @return [Integer]
        def get_power_by_item(name)
          log_error("#{__method__} should be overwritten by #{self.class}")
          return 0
        end
      end
      # Preset used for attacks with power based on held item.
      # Should be included only in a Battle::Move class or a class with the same interface
      # The includer must overwrite the following methods:
      # - private consume_item?
      # - private valid_item_hold?
      # - private get_types_by_item
      module TypesBasedOnItem
        include ItemBased
        # Get the types of the move with 1st type being affected by effects
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @return [Array<Integer>] list of types of the move
        def definitive_types(user, target)
          return super unless valid_held_item?(user.item_db_symbol)
          log_data("types = #{get_types_by_item(user.item_db_symbol)} \# move based on held item")
          return get_types_by_item(user.item_db_symbol)
        end
        alias types_based_on_item_definitive_types definitive_types
        private
        # Get the real types of the move depending on the item
        # @param name [Symbol]
        # @return [Array<Integer>]
        def get_types_by_item(name)
          log_error("#{__method__} should be overwritten by #{self.class}")
          return []
        end
      end
      # Move based on the location type
      #
      # **REQUIREMENTS**
      # - define element_table
      module LocationBased
        # Function that tests if the targets blocks the move
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] expected target
        # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
        # @return [Boolean] if the target evade the move (and is not selected)
        def move_blocked_by_target?(user, target)
          return super || element_by_location.nil?
        end
        alias lb_move_blocked_by_target? move_blocked_by_target?
        private
        # Return the current location type
        # @return [Symbol]
        def location_type
          return logic.field_terrain_effect.db_symbol unless logic.field_terrain_effect.none?
          return $game_map.location_type($game_player.x, $game_player.y)
        end
        # Find the element using the given location using randomness.
        # @return [object, nil]
        def element_by_location
          element_table[location_type]&.sample(random: logic.generic_rng)
        end
        # Element by location type.
        # @return [Hash<Symbol, Array<Symbol>]
        def element_table
          log_error("#{__method__} should be overwritten by #{self.class}.")
          {}
        end
      end
      # Move that takes two turns
      #
      # **REQUIREMENTS**
      # None
      module TwoTurn
        private
        # Internal procedure of the move
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def proceed_internal(user, targets)
          @turn = nil unless user.effects.has?(&:force_next_move?)
          user.add_move_to_history(self, targets)
          return unless move_usable_by_user(user, targets) || (on_move_failure(user, targets, :usable_by_user) && false)
          usage_message(user)
          return scene.display_message_and_wait(parse_text(18, 106)) if targets.all?(&:dead?) && (on_move_failure(user, targets, :no_target) || true)
          if pp == 0 && !(user.effects.has?(&:force_next_move?) && !@forced_next_move_decrease_pp)
            return (scene.display_message_and_wait(parse_text(18, 85)) || true) && on_move_failure(user, targets, :pp) && nil
          end
          @turn = (@turn || 0) + 1
          if @turn == 1
            decrease_pp(user, targets)
            play_animation_turn1(user, targets)
            proceed_message_turn1(user, targets)
            deal_effects_turn1(user, targets)
            @scene.visual.set_info_state(:move_animation)
            @scene.visual.wait_for_animation
            return prepare_turn2(user, targets) unless shortcut?(user, targets)
            @turn += 1
          end
          if @turn >= 2
            @turn = nil
            execution_turn(user, targets)
          end
        end
        # TwoTurn Move execution procedure
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def execution_turn(user, targets)
          kill_turn1_effects(user)
          return unless !(actual_targets = proceed_move_accuracy(user, targets)).empty? || (on_move_failure(user, targets, :accuracy) && false)
          user, actual_targets = proceed_battlers_remap(user, actual_targets)
          actual_targets = accuracy_immunity_test(user, actual_targets)
          return if actual_targets.none? && (on_move_failure(user, targets, :immunity) || true)
          post_accuracy_check_effects(user, actual_targets)
          post_accuracy_check_move(user, actual_targets)
          play_animation(user, targets)
          deal_damage(user, actual_targets) && effect_working?(user, actual_targets) && deal_status(user, actual_targets) && deal_stats(user, actual_targets) && deal_effect(user, actual_targets)
          user.add_successful_move_to_history(self, actual_targets)
          @scene.visual.set_info_state(:move_animation)
          @scene.visual.wait_for_animation
        end
        # Check if the two turn move is executed in one turn
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @return [Boolean]
        def shortcut?(user, targets)
          @logic.each_effects(user) do |effect|
            return true if effect.on_two_turn_shortcut(user, targets, self)
          end
          return false
        end
        alias two_turns_shortcut? shortcut?
        # Add the effects to the pokemons (first turn)
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def deal_effects_turn1(user, targets)
          stat_changes_turn1(user, targets)&.each do |(stat, value)|
            @logic.stat_change_handler.stat_change_with_process(stat, value, user)
          end
        end
        alias two_turn_deal_effects_turn1 deal_effects_turn1
        # Give the force next move and other effects
        # @param user [PFM::PokemonBattler] user of the move
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def prepare_turn2(user, targets)
          user.effects.add(Effects::ForceNextMoveBase.new(@logic, user, self, targets, turn_count))
          user.effects.add(Effects::OutOfReachBase.new(@logic, user, self, can_hit_moves)) if can_hit_moves
        end
        alias two_turn_prepare_turn2 prepare_turn2
        # Remove effects from the first turn
        # @param user [PFM::PokemonBattler]
        def kill_turn1_effects(user)
          user.effects.get(&:force_next_move?).kill if user.effects.has?(&:force_next_move?)
          user.effects.get(&:out_of_reach?).kill if user.effects.has?(&:out_of_reach?)
        end
        alias two_turn_kill_turn1_effects kill_turn1_effects
        # Display the message and the animation of the turn
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def proceed_message_turn1(user, targets)
          nil
        end
        # Display the message and the animation of the turn
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        def play_animation_turn1(user, targets)
          nil
        end
        # Return the stat changes for the user
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>] expected targets
        # @return [Array<Array<[Symbol, Integer]>>] exemple : [[:dfe, -1], [:atk, 1]]
        def stat_changes_turn1(user, targets)
          nil
        end
        # Return the list of the moves that can reach the pokemon event in out_of_reach, nil if all attack reach the user
        # @return [Array<Symbol>]
        def can_hit_moves
          nil
        end
        # Return the number of turns the effect works
        # @return Integer
        def turn_count
          return 2
        end
      end
    end
    # Class describing a basic move (damage + potential status + potential stat)
    class Basic < Move
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        return true if status?
        raise 'Badly configured move, it should have positive power' if power < 0
        successful_damages = actual_targets.map do |target|
          hp = damages(user, target)
          damage_handler = @logic.damage_handler
          damage_handler.damage_change_with_process(hp, target, user, self) do
            scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target)) if critical_hit?
            efficent_message(effectiveness, target) if hp > 0
          end
          recoil(hp, user) if recoil? && damage_handler.instance_variable_get(:@reason).nil?
          next(false) if damage_handler.instance_variable_get(:@reason)
          next(true)
        end
        new_targets = actual_targets.map.with_index { |target, index| successful_damages[index] && target }.select { |target| target }
        actual_targets.clear.concat(new_targets)
        return successful_damages.include?(true)
      end
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        if !status? && user.can_be_lowered_or_canceled?(target = actual_targets.find { |t| t.has_ability?(:shield_dust) })
          @scene.visual.show_ability(target) if data.effect_chance > 0 && target.alive?
          return false
        end
        n = 1
        scene.logic.each_effects(user).each do |e|
          n *= e.effect_chance_modifier(self)
        end
        return bchance?((effect_chance * n) / 100.0) && super
      end
    end
    # Class describing a basic move (damage + status + stat = garanteed)
    class BasicWithSuccessfulEffect < Basic
      # Test if the effect is working
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Boolean]
      def effect_working?(user, actual_targets)
        exec_hooks(Move, :effect_working, binding)
        return true
      end
    end
    Move.register(:s_basic, Basic)
    # Class describing a self stat move (damage + potential status + potential stat to user)
    class SelfStat < Basic
      # Function that deals the stat to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_stats(user, actual_targets)
        super(user, [user])
      end
    end
    # Class describing a self status move (damage + potential status + potential stat to user)
    class SelfStatus < Basic
      # Function that deals the status condition to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_status(user, actual_targets)
        super(user, [user])
      end
    end
    Move.register(:s_self_stat, SelfStat)
    Move.register(:s_self_status, SelfStatus)
    # Class describing a self stat move (damage + potential status + potential stat to user)
    class StatusStat < Move
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        log_error 'Stat and Status move should not get power' if power > 0
        log_error 'Stat and Status move ignore effect chance!' if effect_chance.to_i.between?(1, 99)
        return true
      end
    end
    Move.register(:s_stat, StatusStat)
    Move.register(:s_status, StatusStat)
    # Class describing a move hiting multiple time
    class MultiHit < Basic
      # Number of hit randomly picked from that array
      MULTI_HIT_CHANCES = [2, 2, 2, 3, 3, 5, 4, 3]
      # Moves that always deal 3 hits
      TRIPLE_HIT_MOVES = %i[surging_strikes]
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        @user = user
        @actual_targets = actual_targets
        @nb_hit = 0
        @hit_amount = hit_amount(user, actual_targets)
        @hit_amount.times.count do |i|
          next(false) unless actual_targets.all?(&:alive?)
          next(false) if user.dead?
          @nb_hit += 1
          play_animation(user, actual_targets) if i > 0
          actual_targets.each do |target|
            hp = damages(user, target)
            @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
              if critical_hit?
                scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
              else
                if hp > 0 && i == @hit_amount - 1
                  efficent_message(effectiveness, target)
                end
              end
            end
            recoil(hp, user) if recoil?
          end
          next(true)
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
        return true unless @actual_targets.all?(&:alive?)
        return @hit_amount == @nb_hit
      end
      # Tells if the move hits multiple times
      # @return [Boolean]
      def multi_hit?
        return true
      end
      private
      # Get the number of hit the move can perform
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Integer]
      def hit_amount(user, actual_targets)
        return 3 if TRIPLE_HIT_MOVES.include?(db_symbol)
        return 5 if user.has_ability?(:skill_link)
        return MULTI_HIT_CHANCES.sample(random: @logic.generic_rng)
      end
    end
    # Class describing a move hitting twice
    class TwoHit < MultiHit
      private
      # Get the number of hit the move can perform
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Integer]
      def hit_amount(user, actual_targets)
        return 2
      end
    end
    # This method applies for triple kick and triple axel : power ramps up but the move stops if the subsequent attack misses.
    class TripleKick < MultiHit
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        final_power = power + @nb_hit * power
        return final_power
      end
      private
      # Function that deals the damage to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_damage(user, actual_targets)
        @user = user
        @actual_targets = actual_targets
        @nb_hit = 0
        @hit_amount = hit_amount(user, actual_targets)
        @hit_amount.times.count do |i|
          next(false) unless actual_targets.all?(&:alive?)
          next(false) if user.dead?
          next(false) if i > 0 && !user.has_ability?(:skill_link) && (actual_targets = recalc_targets(user, actual_targets)).empty?
          play_animation(user, actual_targets) if i > 0
          actual_targets.each do |target|
            hp = damages(user, target)
            @logic.damage_handler.damage_change_with_process(hp, target, user, self) do
              if critical_hit?
                scene.display_message_and_wait(actual_targets.size == 1 ? parse_text(18, 84) : parse_text_with_pokemon(19, 384, target))
              else
                if hp > 0 && i == @hit_amount - 1
                  efficent_message(effectiveness, target)
                end
              end
            end
            recoil(hp, user) if recoil?
          end
          @nb_hit += 1
          next(true)
        end
        @scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => @nb_hit.to_s))
        return false if user.dead?
        return true
      end
      # Recalculate the target each time it's needed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] the current targets we need the accuracy recalculation on
      def recalc_targets(user, targets)
        return [] unless proceed_move_accuracy(user, targets) || (on_move_failure(user, targets, :accuracy) && false)
        user, targets = proceed_battlers_remap(user, targets)
        actual_targets = accuracy_immunity_test(user, targets)
        return [] if actual_targets.none? && (on_move_failure(user, targets, :immunity) || true)
        return actual_targets
      end
      def hit_amount(user, actual_targets)
        return 3
      end
    end
    # Class describing Water Shuriken : Changes power and number of hit depending on greninja's base or Ash form.
    class WaterShuriken < MultiHit
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        modified_power = 20 if user.db_symbol == :greninja && user.form == 1
        return modified_power || power
      end
      # Get the number of hit the move can perform
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      # @return [Integer]
      def hit_amount(user, actual_targets)
        return 3 if user.db_symbol == :greninja && user.form == 1
        return super
      end
    end
    Move.register(:s_multi_hit, MultiHit)
    Move.register(:s_2hits, TwoHit)
    Move.register(:s_triple_kick, TripleKick)
    Move.register(:s_water_shuriken, WaterShuriken)
    # Class describing a heal move
    class HealMove < Move
      # Function that return the immunity
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] expected target
      def target_immune?(user, target)
        return true if super
        return %i[heal_pulse floral_healing].include?(db_symbol) && target.effects.has?(:substitute)
      end
      # Function that deals the heal to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, targets)
        targets.each do |target|
          hp = target.max_hp / 2
          hp = hp * 3 / 2 if pulse? && user.has_ability?(:mega_launcher)
          logic.damage_handler.heal(target, hp)
        end
      end
      # Tell that the move is a heal move
      def heal?
        return true
      end
    end
    Move.register(:s_heal, HealMove)
    class TwoTurnBase < Basic
      include Mechanics::TwoTurn
      private
      # List of move that can hit a Pokemon when he's out of reach
      #   CAN_HIT_BY_TYPE[oor_type] = [move db_symbol list]
      CAN_HIT_BY_TYPE = [%i[spikes toxic_spikes stealth_rock], %i[earthquake fissure magnitude spikes toxic_spikes stealth_rock], %i[gust whirlwind thunder swift sky_uppercut twister smack_down hurricane thousand_arrows spikes toxic_spikes stealth_rock], %i[surf whirlpool spikes toxic_spikes stealth_rock], nil]
      # Out of reach moves to type
      #   OutOfReach[sb_symbol] => oor_type
      TYPES = {dig: 1, fly: 2, dive: 3, bounce: 2, phantom_force: 0, shadow_force: 0}
      # Return the list of the moves that can reach the pokemon event in out_of_reach, nil if all attack reach the user
      # @return [Array<Symbol>]
      def can_hit_moves
        CAN_HIT_BY_TYPE[TYPES[db_symbol] || 4]
      end
      # List all the text_id used to announce the waiting turn in TwoTurnBase moves
      ANNOUNCES = {dig: 538, fly: 529, dive: 535, bounce: 544, phantom_force: 541, shadow_force: 541, skull_bash: 556, razor_wind: 547, freeze_shock: 866, ice_burn: 869, sky_attack: 550}
      # Move db_symbol to a list of stat and power
      # @return [Hash<Symbol, Array<Array[Symbol, Power]>]
      MOVE_TO_STAT = {skull_bash: [[:dfe, 1]]}
      # Move db_symbol to a list of stat and power change on the user
      # @return [Hash<Symbol, Array<Array[Symbol, Power]>]
      def stat_changes_turn1(user, targets)
        MOVE_TO_STAT[db_symbol]
      end
      # Display the message and the animation of the turn
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      def proceed_message_turn1(user, targets)
        txt_id = ANNOUNCES[db_symbol]
        @scene.display_message_and_wait(parse_text_with_pokemon(19, txt_id, user)) if txt_id
      end
    end
    Move.register(:s_2turns, TwoTurnBase)
    # Abstract class that manage logic of stage swapping moves
    class StatAndStageEdit < Move
      private
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return show_usage_failure(user) && false if targets.all? { |target| target.effects.has?(&:out_of_reach?) }
        return true
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        actual_targets.each do |target|
          next if target.effects.has?(&:out_of_reach?)
          edit_stages(user, target)
        end
        return true
      end
      # Apply the stats or/and stage edition
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      def edit_stages(user, target)
        log_error('Poorly implemented move: edit_stages(user, target) should have been overwritten in child class.')
      end
    end
    # Abstract class that manage logic of stage swapping moves and bypass accuracy calculation
    class StatAndStageEditBypassAccuracy < StatAndStageEdit
      # Tell if the move accuracy is bypassed
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean]
      def bypass_accuracy?(user, targets)
        return true
      end
    end
    # Class describing a Pledge move (moves combining for different effects)
    class Pledge < Basic
      # List the db_symbol for every Pledge moves
      # @return [Array<Symbol>]
      PLEDGE_MOVES = %i[water_pledge fire_pledge grass_pledge]
      # Return the combination for each effect triggered by Pledge combination
      # @return [Hash { Symbol => Array<Symbol, Array<>> }
      COMBINATION_LIST = {rainbow: %i[water_pledge fire_pledge], sea_of_fire: %i[fire_pledge grass_pledge], swamp: %i[grass_pledge water_pledge]}
      # Function that tests if the user is able to use the move
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
      # @return [Boolean] if the procedure can continue
      def move_usable_by_user(user, targets)
        return false unless super
        return check_order_of_attack(user, targets) if scene.logic.battle_info.vs_type > 1 && scene.logic.alive_battlers(user.bank).size >= 2
        return true
      end
      # Get the real base power of the move (taking in account all parameter)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @return [Integer]
      def real_base_power(user, target)
        return @combined_pledge ? 160 : super
      end
      # Function which permit things to happen before the move's animation
      def post_accuracy_check_move(user, actual_targets)
        scene.display_message_and_wait(parse_text(18, 193)) if @combined_pledge
      end
      # Function that deals the effect to the pokemon
      # @param user [PFM::PokemonBattler] user of the move
      # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
      def deal_effect(user, actual_targets)
        return false unless @combined_pledge
        comb_arr = [db_symbol, @combined_pledge]
        effect_symbol = nil
        COMBINATION_LIST.each { |key, value| effect_symbol = key if comb_arr & value == comb_arr }
        return unless effect_symbol
        send(effect_symbol, user, actual_targets)
        @combined_pledge = nil
        return true
      end
      # Register a Pledge move as one in the System
      # @param db_symbol [Symbol] db_symbol of the move
      def register_pledge_move(db_symbol)
        PLEDGE_MOVES << db_symbol unless PLEDGE_MOVES.include?(db_symbol)
      end
      # Register a pledge combination
      # @param effect_symbol [Symbol]
      # @param first_pledge_symbol [Symbol]
      # @param second_pledge_symbol
      def register_pledge_combination(effect_symbol, first_pledge_symbol, second_pledge_symbol)
        COMBINATION_LIST[effect_symbol] = [first_pledge_symbol, second_pledge_symbol]
      end
      private
      # Check the order to know if the user uses its Pledge Move or wait for the other to attack
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @return [Boolean]
      def check_order_of_attack(user, targets)
        allied_actions = scene.logic.turn_actions.select { |action| action.is_a?(Actions::Attack) && Actions::Attack.from(action).launcher.bank == user.bank }
        return true if allied_actions.size <= 1 || !allied_actions.all? { |action| PLEDGE_MOVES.include?(action.move.db_symbol) }
        other_move = (allied_actions.find { |action| action.launcher != user })
        other = other_move.launcher
        if user.attack_order < other.attack_order
          scene.display_message_and_wait(pledge_wait_text(user, other))
          user.add_successful_move_to_history(self, targets)
          return false
        else
          @combined_pledge = other_move.move.db_symbol
          return true
        end
      end
      # Get the right text depending on the user's side (and if it's a Trainer battle or not)
      # @param user [PFM::PokemonBattler]
      # @param other [PFM::PokemonBattler]
      # @return [String]
      def pledge_wait_text(user, other)
        text_id = (user.bank == 0 ? 1152 : (scene.logic.battle_info.trainer_battle? ? 1156 : 1158))
        parse_text(19, text_id, '[VAR PKNICK(0000)]' => user.given_name, '[VAR PKNICK(0001)]' => other.given_name)
      end
      # Create the Rainbow Effect
      # @param user [PFM::PokemonBattler]
      # @param _actual_targets [Array<PFM::PokemonBattler>]
      def rainbow(user, _actual_targets)
        return if logic.bank_effects[user.bank].has?(:rainbow)
        scene.logic.add_bank_effect(Battle::Effects::Rainbow.new(logic, user.bank))
      end
      # Create the SeaOfFire Effect
      # @param _user [PFM::PokemonBattler]
      # @param actual_targets [Array<PFM::PokemonBattler>]
      def sea_of_fire(_user, actual_targets)
        return if logic.bank_effects[actual_targets&.first&.bank].has?(:sea_of_fire)
        scene.logic.add_bank_effect(Battle::Effects::SeaOfFire.new(logic, actual_targets&.first&.bank))
      end
      # Create the Swamp Effect
      # @param _user [PFM::PokemonBattler]
      # @param actual_targets [Array<PFM::PokemonBattler>]
      def swamp(_user, actual_targets)
        return if logic.bank_effects[actual_targets&.first&.bank].has?(:swamp)
        scene.logic.add_bank_effect(Battle::Effects::Swamp.new(logic, actual_targets&.first&.bank))
      end
    end
    Move.register(:s_pledge, Pledge)
  end
end
