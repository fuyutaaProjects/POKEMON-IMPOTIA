module Battle
  # Module containing the action classes for the battle
  module Actions
    # Base class for all actions
    class Base
      # Creates a new action
      # @param scene [Battle::Scene]
      def initialize(scene)
        @scene = scene
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1
      end
      # Tell if the action is valid
      # @return [Boolean]
      def valid?
        return self.class != Base
      end
      # Execute the action
      def execute
        return nil
      end
    end
    # Class describing the Attack Action
    class Attack < Base
      # Get the move of this action
      # @return [Battle::Move]
      attr_reader :move
      # Get the user of this move
      # @return [PFM::PokemonBattler]
      attr_reader :launcher
      # Tell if pursuit on this action is enabled
      # @return [Boolean]
      attr_accessor :pursuit_enabled
      # Tell if this action can ignore speed of the other pokemon
      # @return [Boolean]
      attr_accessor :ignore_speed
      # List all the sub launcher that will use the same move due to their ability (Dancer)
      # @return [Array]
      attr_reader :sub_launchers
      # Create a new attack action
      # @param scene [Battle::Scene]
      # @param move [Battle::Move]
      # @param launcher [PFM::PokemonBattler]
      # @param target_bank [Integer] bank the move aims
      # @param target_position [Integer] position the move aims
      def initialize(scene, move, launcher, target_bank, target_position)
        super(scene)
        @move = move
        @launcher = launcher
        @target_bank = target_bank
        @target_position = target_position
        @pursuit_enabled = false
        @ignore_speed = false
        @sub_launchers = []
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem)
        unless @pursuit_enabled && other.is_a?(Attack) && other.pursuit_enabled
          return -1 if @pursuit_enabled
          return 1 if other.is_a?(Attack) && other.pursuit_enabled
        end
        return (other.roaming_comparison_result(self) == 1 ? -1 : 1) if other.is_a?(Flee) && $wild_battle.is_roaming?(other.target.original)
        return -1 if other.is_a?(Flee) && move.relative_priority > 0
        return 1 unless other.is_a?(Attack)
        attack = Attack.from(other)
        return -1 if @ignore_speed && attack.move.priority(attack.launcher) == @move.priority(@launcher)
        priority_return = attack.move.priority(attack.launcher) <=> @move.priority(@launcher)
        return priority_return if priority_return != 0
        return 1 if @launcher.has_ability?(:stall) && (attack.launcher.battle_ability_db_symbol != :stall && %i[full_incense lagging_tail].none?(attack.launcher.battle_item_db_symbol))
        return -1 if attack.launcher.has_ability?(:stall) && (@launcher.battle_ability_db_symbol != :stall && %i[full_incense lagging_tail].none?(@launcher.battle_item_db_symbol))
        return 1 if %i[full_incense lagging_tail].any? { |db_symbol| @launcher.hold_item?(db_symbol) } && %i[full_incense lagging_tail].none?(attack.launcher.battle_item_db_symbol)
        return -1 if %i[full_incense lagging_tail].any? { |db_symbol| attack.launcher.hold_item?(db_symbol) } && %i[full_incense lagging_tail].none?(@launcher.battle_item_db_symbol)
        priority_return = mycelium_might_priority(attack)
        return priority_return if priority_return != 0
        trick_room_factor = @scene.logic.terrain_effects.has?(:trick_room) ? -1 : 1
        return (attack.launcher.spd <=> @launcher.spd) * trick_room_factor
      end
      # Get the priority of the move
      # @return [Integer]
      def priority
        return @pursuit_enabled ? 999 : @move.priority
      end
      # Get the target of the move
      # @return [PFM::PokemonBattler, nil]
      def target
        targets = @move.battler_targets(@launcher, @scene.logic).select(&:alive?)
        best_target = targets.select { |battler| battler.position == @target_position && battler.bank == @target_bank }.first
        return best_target if best_target
        best_target = targets.select { |battler| battler.bank == @target_bank }.first
        return best_target || targets.first
      end
      # Execute the action
      def execute
        @scene.battle_info.flee_attempt_count = 0 if @launcher.from_party?
        @move.proceed(@launcher, @target_bank, @target_position)
        @sub_launchers.each do |launcher|
          @scene.visual.show_ability(launcher)
          @move.dup.proceed(launcher, @target_bank, @target_position)
        end
      end
      # Define which Pokémon should go first if either of them or both have the ability Mycelium Might.
      # @param attack [Battle::Actions::Attack]
      # @return [Integer]
      def mycelium_might_priority(attack)
        return 0 if @launcher.battle_ability_db_symbol != :mycelium_might && attack.launcher.battle_ability_db_symbol != :mycelium_might
        return 1 if @launcher.has_ability?(:mycelium_might) && attack.launcher.battle_ability_db_symbol != :mycelium_might && @move.status?
        return -1 if attack.launcher.has_ability?(:mycelium_might) && launcher.battle_ability_db_symbol != :mycelium_might && attack.move.status?
        return 0
      end
      # Action describing the action forced by Encore
      class Encore < Attack
        # Execute the action
        def execute
          @move.forced_next_move_decrease_pp = true
          super
          @move.forced_next_move_decrease_pp = false
          if @move.pp <= 0 && (effect = @launcher.effects.get(:encore))
            effect.kill
          end
        end
      end
    end
    # Class describing the Pre Attacks Action
    class PreAttack < Base
      # Create a new attack action
      # @param scene [Battle::Scene]
      def initialize(scene, attack_actions)
        super(scene)
        @attack_actions = attack_actions
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(Attack)
        return -1
      end
      # Execute the action
      def execute
        @attack_actions.each { |action| action.move.proceed_pre_attack(action.launcher) }
      end
    end
    # Class describing the Mega Evolution action
    class Mega < Base
      # Get the user of this action
      # @return [PFM::PokemonBattler]
      attr_reader :user
      # Create a new mega evolution action
      # @param scene [Battle::Scene]
      # @param user [PFM::PokemonBattler]
      def initialize(scene, user)
        super(scene)
        @user = user
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem)
        return 1 if other.is_a?(Attack) && Attack.from(other).pursuit_enabled
        return 1 if other.is_a?(Item)
        return 1 if other.is_a?(Switch)
        return Mega.from(other).user.spd <=> @user.spd if other.is_a?(Mega)
        return -1
      end
      # Execute the action
      def execute
        @scene.logic.mega_evolve.mark_as_mega_evolved(@user)
        @scene.display_message_and_wait(message)
        @user.mega_evolve
        @scene.visual.show_switch_form_animation(@user)
        @user.ability_effect.on_switch_event(@scene.logic.switch_handler, @user, @user)
      end
      private
      # Get the mega evolve message
      # @return [String]
      def message
        return parse_text_with_pokemon(19, 1165, @user, PFM::Text::PKNICK[0] => @user.given_name, PFM::Text::ITEM2[2] => @user.item_name, PFM::Text::TRNAME[1] => @user.trainer_name, PFM::Text::ITEM2[3] => @scene.logic.mega_evolve.mega_tool_name(@user))
      end
    end
    # Class describing the usage of an Item
    class Item < Base
      # Get the Pokemon responsive of the item usage
      # @return [PFM::PokemonBattler]
      attr_reader :user
      # Get the item wrapper executing the action
      # @return [PFM::ItemDescriptor::Wrapper]
      attr_reader :item_wrapper
      # Create a new item action
      # @param scene [Battle::Scene]
      # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
      # @param bag [PFM::Bag]
      # @param user [PFM::PokemonBattler] pokemon responsive of the usage of the item (to help sorting alg.)
      def initialize(scene, item_wrapper, bag, user)
        super(scene)
        @item_wrapper = item_wrapper
        @bag = bag
        @user = user
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem)
        return 1 if other.is_a?(Attack) && Attack.from(other).pursuit_enabled
        return Item.from(other).user.spd <=> @user.spd if other.is_a?(Item)
        return -1
      end
      # Execute the action
      def execute
        names = @scene.battle_info.names
        trname = names.dig(@user.bank, @user.party_id) || names.dig(@user.bank, 0) || names.dig(0, 0)
        message = parse_text(18, 34, PFM::Text::ITEM2[1] => @item_wrapper.item.name, PFM::Text::TRNAME[0] => trname)
        @scene.display_message_and_wait(message)
        @bag.remove_item(@item_wrapper.item.id, 1) if @item_wrapper.item.is_limited
        @bag.last_battle_item_db_symbol = @item_wrapper.item.db_symbol
        @item_wrapper.execute_battle_action
      end
    end
    # Class describing the usage of switching out a Pokemon
    class Switch < Base
      # Get the Pokemon who's being switched
      # @return [PFM::PokemonBattler]
      attr_reader :who
      # Get the Pokemon with the Pokemon is being switched
      # @return [PFM::PokemonBattler]
      attr_reader :with
      # Create a new switch action
      # @param scene [Battle::Scene]
      # @param who [PFM::PokemonBattler] who's being switched out
      # @param with [PFM::PokemonBattler] with who the Pokemon is being switched
      def initialize(scene, who, with)
        super(scene)
        @who = who
        @with = with
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return 1 if other.is_a?(HighPriorityItem)
        return 1 if other.is_a?(Attack) && Attack.from(other).pursuit_enabled
        return 1 if other.is_a?(Item)
        return Switch.from(other).who.spd <=> @who.spd if other.is_a?(Switch)
        return -1
      end
      # Execute the action
      def execute
        return if !@who.position || !@who.position.between?(0, $game_temp.vs_type - 1)
        visual = @scene.visual
        sprite = visual.battler_sprite(@who.bank, @who.position)
        if @who.alive?
          sprite.go_out
          visual.hide_info_bar(@who)
          switch_out_message unless forced_switch?(who)
          wait_for(sprite, visual)
        end
        @scene.logic.switch_battlers(@who, @with)
        @scene.logic.switch_handler.execute_pre_switch_events(@who, @with)
        sprite.pokemon = @with
        sprite.visible = false
        sprite.go_in
        visual.show_info_bar(@with)
        switch_in_message unless forced_switch?(who)
        wait_for(sprite, visual)
        @scene.logic.switch_handler.execute_switch_events(@who, @with)
        @scene.logic.request_switch(@with, nil) if @with.dead?
        @who.reset_states
      end
      private
      # Wait for the sprite animation to be done
      # @param sprite [#done?]
      # @param visual [Battle::Visual]
      def wait_for(sprite, visual)
        until sprite.done?
          visual.update
          Graphics.update
        end
      end
      # Show the switch out message
      def switch_out_message
        return if @who.dead?
        msg_id = @who.from_party? ? (26 + @who.hp % 5) : 32
        hash = {PFM::Text::TRNAME[0] => @scene.battle_info.trainer_name(@who), PFM::Text::PKNICK[0] => @who.given_name, PFM::Text::PKNICK[1] => @who.given_name}
        message = parse_text(18, msg_id, hash)
        @scene.display_message_and_wait(message)
      end
      # Show the switch in message
      def switch_in_message
        msg_id = @with.from_party? ? (22 + @with.hp % 2) : 18
        hash = {PFM::Text::TRNAME[0] => @scene.battle_info.trainer_name(@with), PFM::Text::PKNICK[0] => @with.given_name, PFM::Text::PKNICK[1] => @with.given_name}
        message = parse_text(18, msg_id, hash)
        @scene.display_message_and_wait(message)
      end
      # Tell if the Pokemon was forced to switch
      # @param who [PFM::PokemonBattler] the switched out Pokemon
      # @return [Boolean]
      def forced_switch?(who)
        @scene.logic.all_alive_battlers.each do |pokemon|
          pmh = pokemon.successful_move_history
          next if pmh.empty?
          return true if pmh.last.move.force_switch? && pmh.last.targets.include?(who) && pmh.last.current_turn?
        end
        return false
      end
    end
    # Class describing the Flee action
    class Flee < Base
      # Get the pokemon trying to flee
      # @return [PFM::PokemonBattler]
      attr_reader :target
      # Create a new flee action
      # @param scene [Battle::Scene]
      # @param target [PFM::PokemonBattler]
      def initialize(scene, target)
        super(scene)
        @target = target
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return roaming_comparison_result(attack) if $wild_battle.is_roaming?(target.original) && other.is_a?(Attack) && (attack = Attack.from(other))
        return 1 if other.is_a?(Attack) && Attack.from(other).move.relative_priority > 0
        return -1
      end
      # Constant telling the priority applied to a Fleeing action for a Roaming Pokemon
      # @return [Integer]
      PRIORITY_ROAMING_FLEE = -7
      # Give the comparison result for a Roaming Pokemon
      # @param attack [Attack] other action
      # @return [Integer]
      # @note Based on Gen 5 mechanism as Gen 6 mechanism isn't a real Roaming feature
      # In Gen 5, a Roaming Pokemon trying to escape has a Priority of -7
      def roaming_comparison_result(attack)
        return 1 if attack.move.relative_priority > PRIORITY_ROAMING_FLEE
        return -1 if attack.move.relative_priority < PRIORITY_ROAMING_FLEE
        return 1 if target.spd < attack.launcher.spd
        return [-1, 1].sample if target.spd == attack.launcher.spd
        return -1 if target.spd > attack.launcher.spd
      end
      # Execute the action
      # @param from_scene [Boolean] if the action was triggered during the player choice
      def execute(from_scene = false)
        if from_scene
          execute_from_scene
        else
          if @scene.logic.switch_handler.can_switch?(@target)
            @scene.display_message_and_wait(parse_text_with_pokemon(19, 767, @target))
            @scene.logic.battle_result = @target.bank == 0 ? 1 : 3
            @scene.next_update = :battle_end
          end
        end
      end
      private
      # Execute the action if the pokemon is from party
      def execute_from_scene
        result = @scene.logic.flee_handler.attempt(@target.position)
        if result == :success
          @scene.logic.battle_result = 1
          @scene.next_update = :battle_end
        end
      end
    end
    # Class describing the activation message of item granting priority
    class HighPriorityItem < Base
      # Create a new high priority item action
      # @param scene [Battle::Scene]
      # @param holder [PFM::PokemonBattler]
      def initialize(scene, holder)
        super(scene)
        @holder = holder
      end
      # Compare this action with another
      # @param other [Base] other action
      # @return [Integer]
      def <=>(other)
        return -1 if other.is_a?(Flee)
        return 1
      end
      # Execute the action
      def execute
        return unless @scene.logic.instance_variable_get(:@result_item)
        item_name = @holder.item_name
        @holder.item_effect.send(:consume_berry, @holder) if @holder.item_effect.is_a?(Effects::Item::Berry)
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 1031, @holder, PFM::Text::ITEM2[1] => item_name))
        @scene.logic.instance_variable_set(:@result_item, nil)
      end
    end
  end
end
