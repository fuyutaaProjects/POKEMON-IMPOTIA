module Battle
  module Effects
    module Mechanics
      # Effect mechanics that make the pokemon flies
      # When including this mechanics :
      # - overwrite on_proc_message
      # - overwrite on_delete_message
      # - call Effects::Mechanics::ForceFlying.register_force_flying_hook in the class
      module ForceFlying
        # Create a new Pokemon tied effect
        # @param duration [Integer] duration of the effect (including the current turn)
        def force_flying_initialize(duration)
          self.counter = duration
        end
        # Function called when the effect has been deleted from the effects handler
        def on_delete
          msg = on_delete_message
          @logic.scene.display_message_and_wait(msg) if msg
        end
        alias force_flying_on_delete on_delete
        private
        # Transfer the effect to the given pokemon via baton switch
        # @param with [PFM::Battler] the pokemon switched in
        # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
        def baton_switch_transfer(with)
          self.class.new(@logic, with)
        end
        alias force_flying_baton_switch_transfer baton_switch_transfer
        # Message displayed when the effect procs
        # @return [String, nil]
        def on_proc_message
          nil
        end
        # Message displayed when the effect wear off
        # @return [String, nil]
        def on_delete_message
          nil
        end
        class << self
          # Make to pokemon flying in grounded? test
          # @param reason [String] reason of the hook
          # @param name [Symbol] name of the effect
          def register_force_flying_hook(reason, name)
            PFM::PokemonBattler.register_force_flying_hook(reason) do |pokemon, scene|
              next(false) unless pokemon.effects.has?(name)
              msg = pokemon.effects.get(name).send(:on_proc_message)
              scene.display_message_and_wait(msg) if msg
              next(true)
            end
          end
        end
      end
      # Give functions to manage a move that force the next one. Must be used in a EffectBase child class.
      module ForceNextMove
        # Get the move the Pokemon has to use
        # @return [Battle::Move]
        attr_reader :move
        # Get the targets of the move
        # @return [Array<PFM::PokemonBattler>]
        attr_reader :targets
        # Tell if the effect forces the next move
        # @return [Boolean]
        def force_next_move?
          return true
        end
        # Tell if the effect forces the next turn action into a Attack action
        # @return [Boolean]
        def force_next_turn_action?
          return true
        end
        # Function that updates the counter of the effect
        def update_counter
          return if paused?(@pokemon)
          @counter -= 1
          @counter = 0 if interrupted?(@pokemon)
        end
        # List of move that must be paused when user is asleep/frozen/flinched
        MOVES_PAUSED = %i[freeze_shock geomancy ice_burn razor_wind skull_bash sky_attack solar_beam]
        # Function that tells us if we should pause the move or not
        # @param user [PFM::PokemonBattler] user of the move
        def paused?(user)
          return true if MOVES_PAUSED.include?(move.db_symbol) && (user.frozen? || user.asleep? || user.effects.has?(:flinch))
          return false
        end
        # Function that tells us if we should interrupt the move or not
        # @param user [PFM::PokemonBattler] user of the move
        def interrupted?(user)
          return true if !MOVES_PAUSED.include?(move.db_symbol) && (user.frozen? || user.asleep? || user.effects.has?(:flinch))
          return false
        end
        # Make the Attack action that is forced by this effect
        # @return [Actions::Attack]
        def make_action
          raise "Failed to make effect for #{self.class}" unless @pokemon && @logic
          target = targets.first
          return action_class.new(@logic.scene, move, @pokemon, target.bank, target.position)
        end
        # Get the class of the action
        # @return [Class<Actions::Attack>]
        def action_class
          Actions::Attack
        end
        private
        # Create a new Forced next move effect
        # @param move [Battle::Move]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param counter [Integer] number of turn the move is forced to be used
        def init_force_next_move(move, targets, counter)
          @move = move
          @targets = targets
          self.counter = counter
        end
      end
      # Effect linked to another, if the other die, this one dies too.
      #
      # **Requirement**
      # - Call initialize_mark
      module Mark
        # Get the origin mark
        # @return [EffectBase]
        attr_reader :mark_origin
        # Initialize the mechanic
        # @param origin [EffectBase]
        def initialize_mark(origin)
          @mark_origin = origin
        end
        # Tell if the effect is dead
        # @return [Boolean]
        def dead?
          super || @mark_origin.dead?
        end
        alias mark_dead? dead?
      end
      # Neutralize Type Effect
      #
      # **Includer requirements**
      # - call neutralize_type_initialize
      # - def neutralyzed_type
      module NeutralizeType
        # Create a new effect
        # @param target [PFM::PokemonBattler]
        # @param turn_count [Integer]
        def neutralize_type_initialize(target, turn_count)
          @target = target
          target.ignore_types(*neutralyzed_types)
          self.counter = turn_count
        end
        # Show the message when the effect gets deleted
        def on_delete
          @target.restore_types
        end
        alias neutralize_type_on_delete on_delete
        private
        # Get the neutralized types
        # @return [Array<Integer>]
        def neutralyzed_types
          log_error("#{__method__} should be overwritten by #{self.class}")
          return [0]
        end
      end
      # Make the pokemon out of reach
      #
      # **Requirement**
      # - Call initialize_out_of_reach
      module OutOfReach
        # Get the move the Pokemon has to use
        # @return [Battle::Move]
        attr_reader :move
        # Init the mechanic
        # @param pokemon [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @param exceptions [Array<Symbol>] move that hit the target while out of reach
        # @param counter [Integer] number of turn the user is out_of_reach
        def initialize_out_of_reach(pokemon, move, exceptions, counter = 2)
          @oor_pokemon = pokemon
          @oor_exceptions = exceptions
          @move = move
          self.counter = counter
        end
        # Tell if the effect make the pokemon out reach
        # @return [Boolean]
        def out_of_reach?
          return true
        end
        alias oor_out_of_reach? out_of_reach?
        # Function that updates the counter of the effect
        def update_counter
          @counter -= 1
          @counter = 0 if interrupted?(@pokemon)
        end
        # List of move that must be paused when user is asleep/frozen/flinched
        MOVES_PAUSED = %i[freeze_shock geomancy ice_burn razor_wind skull_bash sky_attack solar_beam]
        # Function that tells us if we should interrupt the move or not
        # @param user [PFM::PokemonBattler] user of the move
        def interrupted?(user)
          return true if !MOVES_PAUSED.include?(move.db_symbol) && (user.frozen? || user.asleep? || user.effects.has?(:flinch))
          return false
        end
        # Check if the attack can hit the pokemon. Should be called after testing out_of_reach?
        # @param name [Symbol]
        # @return [Boolean]
        def can_hit_while_out_of_reach?(name)
          return @oor_exceptions.include?(name)
        end
        alias oor_can_hit_while_out_of_reach? can_hit_while_out_of_reach?
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if target != @oor_pokemon
          result = !can_hit_while_out_of_reach?(move.db_symbol)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 213, target)) if result
          return result
        end
        alias oor_on_move_prevention_target on_move_prevention_target
      end
      module SuccessiveSuccessfulUses
        # Return the number of successive successful use of the move.
        # @return [Integer]
        def successive_uses
          return @successive_uses if @pokemon.successful_move_history.last&.last_turn? && @pokemon.last_successful_move_is?(@move_db_symbol)
          if @pokemon.successful_move_history.last&.last_turn? && accepted_moves.any? { |move_sym| @pokemon.last_successful_move_is?(move_sym) }
            return @successive_uses
          end
          return @successive_uses = 0
        end
        # Increase the successive uses by one
        def increase
          @successive_uses += 1
        end
        private
        # Init the successive uses module
        # @param pokemon [PFM::PokemonBattler]
        # @param move [Battle::Move]
        def init_successive_successful_uses(pokemon, move)
          @pokemon = pokemon
          @successive_uses = 0
          @move_db_symbol = move.db_symbol
        end
        # List of the moves that don't break the continuity and don't increment
        ACCEPTED_MOVES = %i[mirror_move]
        # List of the moves that don't break the continuity and don't increment
        # @return [Array[Symbol]]
        def accepted_moves
          ACCEPTED_MOVES
        end
      end
      # Store targets informations
      #
      # **Requirement**
      # - Call initialize_with_targets
      module WithTargets
        # Init the mechanic
        # @param targets [Array<PFM::PokemonBattler>, PFM::PokemonBattler] battler targetted by the effect
        def initialize_with_targets(targets)
          @wt_targets = [targets].flatten
        end
        # Tell if the given battler is targetted by the effect
        # @param battler [PFM::PokemonBattler]
        # @return [Boolean]
        def targetted?(battler)
          return @wt_targets.include?(battler)
        end
        alias with_targets_targetted? targetted?
      end
      # Store targets informations
      #
      # **Requirement**
      # - Call initialize_with_marked_targets
      #
      # **Initialization exemple**
      # ```ruby
      # # Inside EffectBase child class
      # initialize_with_marked_targets(targets) { |target| YourMarkEffect.new(logic, self, user, target) }
      # ```
      module WithMarkedTargets
        include Mechanics::WithTargets
        # Initialize the mechanic
        # @param user [PFM::PokemonBattler, nil]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param block [Proc] block taking one argument (PFM::PokemonBattler) and return an EffectBase
        def initialize_with_marked_targets(user, targets, &block)
          initialize_with_targets(targets)
          @wmt_user = user
          targets.each { |target| target.effects.add(block.call(target)) }
        end
        # The launcher of this effect
        # @return [PFM::PokemonBattler, nil]
        def launcher
          @wmt_user
        end
        # Tell if the effect is dead
        # @return [Boolean]
        def dead?
          super || !@wt_targets.all?(&:position) || @wt_targets.all?(&:dead?)
        end
        alias wmt_dead? dead?
      end
    end
  end
end
