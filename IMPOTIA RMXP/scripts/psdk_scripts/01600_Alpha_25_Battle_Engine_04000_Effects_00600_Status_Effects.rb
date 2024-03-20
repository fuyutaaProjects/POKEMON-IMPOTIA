module Battle
  module Effects
    class Status < EffectBase
      # Get the target of the effect
      # @return [PFM::PokemonBattler]
      attr_reader :target
      @registered_statuses = {}
      # Create a new status effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param status [Symbol] Symbol of the status
      def initialize(logic, target, status)
        super(logic)
        @target = target
        @status = status
      end
      # Get the ID of the status
      # @return [Integer]
      def status_id
        Configs.states.ids[@status] || -1
      end
      # Tell if the status effect is poisoning
      # @return [Boolean]
      def poison?
        @status == :poison
      end
      # Tell if the status effect is paralysis
      # @return [Boolean]
      def paralysis?
        @status == :paralysis
      end
      # Tell if the status effect is burn
      # @return [Boolean]
      def burn?
        @status == :burn
      end
      # Tell if the status effect is asleep
      # @return [Boolean]
      def asleep?
        @status == :sleep
      end
      # Tell if the status effect is frozen
      # @return [Boolean]
      def frozen?
        @status == :freeze
      end
      # Tell if the status effect is toxic
      # @return [Boolean]
      def toxic?
        @status == :toxic
      end
      # Tell if the effect is a global poisoning effect (poison or toxic)
      # @return [Boolean]
      def global_poisoning?
        poison? || toxic?
      end
      class << self
        # Register a new status
        # @param status [Symbol] Symbol of the status
        # @param klass [Class<Status>] class of the status effect
        def register(status, klass)
          @registered_statuses[status] = klass
        end
        # Create a new Status effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param status [Symbol] Symbol of the status
        # @return [Status]
        def new(logic, target, status)
          klass = @registered_statuses[status] || Status
          object = klass.allocate
          object.send(:initialize, logic, target, status)
          return object
        end
      end
      class Poison < Status
        # Prevent poison from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :poison && status != :toxic
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 249, target))
          end
        end
        # Apply poison effect on end of turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(target)
          return if target.dead?
          return if target.has_ability?(:magic_guard)
          if target.has_ability?(:poison_heal)
            scene.visual.show_ability(target, true)
            logic.damage_handler.heal(target, poison_effect)
            scene.visual.hide_ability(target)
            return
          end
          scene.display_message_and_wait(parse_text_with_pokemon(19, 243, target))
          scene.visual.show_rmxp_animation(target, 469 + status_id)
          logic.damage_handler.damage_change(poison_effect, target)
          nil
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :poison
        end
        private
        # Return the Poison effect on HP of the Pokemon
        # @return [Integer] number of HP loosen
        def poison_effect
          return (target.max_hp / 8).clamp(1, Float::INFINITY)
        end
      end
      register(:poison, Poison)
      class Paralysis < Status
        # Prevent paralysis from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :paralysis
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 282, target))
          end
        end
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != target
          if user.paralyzed? && paralysis_check
            move.scene.visual.show_rmxp_animation(user, 469 + status_id)
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 276, user))
            return :prevent
          end
        end
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return 1 if @target.has_ability?(:quick_feet)
          return 0.25
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :paralysis
        end
        private
        # Check if the pokemon cannot move due to paralysis
        # @return [Boolean]
        def paralysis_check
          bchance?(0.25, @logic)
        end
      end
      register(:paralysis, Paralysis)
      class Burn < Status
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 if user != self.target
          return 1 unless move.physical?
          return 1 if user.has_ability?(:guts)
          return 0.5
        end
        # Prevent burn from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :burn
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 267, target))
          end
        end
        # Apply burn effect on end of turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(target)
          return if target.dead?
          return if target.has_ability?(:magic_guard)
          hp = burn_effect
          hp /= 2 if target.has_ability?(:heatproof)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 261, target))
          scene.visual.show_rmxp_animation(target, 469 + status_id)
          logic.damage_handler.damage_change(hp.clamp(1, Float::INFINITY), target)
          nil
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :burn
        end
        private
        # Return the Burn effect on HP of the Pokemon
        # @return [Integer] number of HP loosen
        def burn_effect
          return (target.max_hp / 8).clamp(1, Float::INFINITY)
        end
      end
      register(:burn, Burn)
      class Asleep < Status
        # List of moves that works when the user is asleep
        SLEEPING_MOVES = %i[snore sleep_talk]
        # Prevent sleep from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :sleep
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 315, target))
          end
        end
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != target
          if user.sleep_check
            move.scene.visual.show_rmxp_animation(user, 469 + status_id)
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 309, user))
            return if SLEEPING_MOVES.include?(move.db_symbol)
            return :prevent
          else
            move.scene.visual.refresh_info_bar(user)
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 312, user))
          end
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :sleep
        end
      end
      register(:sleep, Asleep)
      class Frozen < Status
        # Prevent freeze from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :freeze
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 297, target))
          end
        end
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != target
          if froze_check
            if move.unfreeze?
              move.scene.display_message_and_wait(parse_text_with_pokemon(19, 303, user))
            else
              move.scene.visual.show_rmxp_animation(user, 469 + status_id)
              move.scene.display_message_and_wait(parse_text_with_pokemon(19, 288, user))
              return :prevent
            end
          else
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 294, user))
          end
          user.cure
          move.scene.visual.refresh_info_bar(user)
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :freeze
        end
        private
        # Check if the Pokemon is still frozen
        # @return [Boolean]
        def froze_check
          !bchance?(0.2, @logic)
        end
      end
      register(:freeze, Frozen)
      class Toxic < Status
        # Create a new toxic effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param status_id [Integer] ID of the status
        def initialize(logic, target, status_id)
          super
          @toxic_counter = 1
        end
        # Reset the toxic counter
        def reset
          @toxic_counter = 1
        end
        # Prevent toxic from being applied twice
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != self.target
          return if status != :poison && status != :toxic
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 249, target))
          end
        end
        # Apply toxic effect on end of turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(target)
          return if target.dead?
          return if target.has_ability?(:magic_guard)
          if target.has_ability?(:poison_heal)
            @toxic_counter += 1
            scene.visual.show_ability(target, true)
            logic.damage_handler.heal(target, poison_effect)
            scene.visual.hide_ability(target)
            return
          end
          scene.display_message_and_wait(parse_text_with_pokemon(19, 243, target))
          scene.visual.show_rmxp_animation(target, 469 + status_id)
          logic.damage_handler.damage_change(toxic_effect, target)
          @toxic_counter += 1
          nil
        end
        # Function giving the name of the effect
        # @return [Symbol]
        def name
          :toxic
        end
        private
        # Return the Poison effect on HP of the Pokemon (used solely by the Poison Heal ability)
        # @return [Integer] number of HP loosen
        def poison_effect
          return (target.max_hp / 8).clamp(1, Float::INFINITY)
        end
        # Return the Poison effect on HP of the Pokemon
        # @return [Integer] number of HP loosen
        def toxic_effect
          return (target.max_hp * @toxic_counter / 16).clamp(1, Float::INFINITY)
        end
      end
      register(:toxic, Toxic)
    end
  end
end
Hooks.register(PFM::PokemonBattler, :on_reset_states, 'PSDK reset toxic') do
  status_effect.reset if status_effect.is_a?(Battle::Effects::Status::Toxic)
end
