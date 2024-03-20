module Battle
  module Effects
    class FieldTerrain < EffectBase
      # Get the db_symbol of the field terrain
      # @return [Symbol]
      attr_reader :db_symbol
      # Get the counter of the field terrain
      # @return [Integer]
      attr_accessor :internal_counter
      @registered_field_terrains = {}
      # Create a new field terrain effect
      # @param logic [Battle::Logic]
      # @param db_symbol [Symbol] db_symbol of the field terrain
      def initialize(logic, db_symbol)
        super(logic)
        @db_symbol = db_symbol
        @internal_counter = db_symbol == :none ? Float::INFINITY : 5
      end
      # Tell if the field terrain is none
      # @return [Boolean]
      def none?
        @db_symbol == :none
      end
      # Tell if the field terrain is electric
      # @return [Boolean]
      def electric?
        @db_symbol == :electric_terrain
      end
      # Tell if the field terrain is grassy
      # @return [Boolean]
      def grassy?
        @db_symbol == :grassy_terrain
      end
      # Tell if the field terrain is psychic
      # @return [Boolean]
      def psychic?
        @db_symbol == :psychic_terrain
      end
      # Tell if the field terrain is psychic
      # @return [Boolean]
      def misty?
        @db_symbol == :misty_terrain
      end
      class << self
        # Register a new field terrain
        # @param db_symbol [Symbol] db_symbol of the field terrain
        # @param klass [Class<Field terrain>] class of the field terrain effect
        def register(db_symbol, klass)
          @registered_field_terrains[db_symbol] = klass
        end
        # Create a new Field terrain effect
        # @param logic [Battle::Logic]
        # @param db_symbol [Symbol] db_symbol of the field terrain
        # @return [Field terrain]
        def new(logic, db_symbol)
          klass = @registered_field_terrains[db_symbol] || FieldTerrain
          object = klass.allocate
          object.send(:initialize, logic, db_symbol)
          return object
        end
      end
      class Electric < FieldTerrain
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          @internal_counter -= 1
          logic.fterrain_change_handler.fterrain_change(:none) if @internal_counter <= 0
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return unless target.affected_by_terrain? && status == :sleep
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 1207, target))
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 unless move.type_electric? && user.affected_by_terrain?
          return 1.5
        end
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false unless target.affected_by_terrain? && move.status?
          return false unless move.status_effects.any? { |status| status.status == :sleep } || move.db_symbol == :yawn
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 1207, target))
          return true
        end
      end
      register(:electric_terrain, Electric)
      class Grassy < FieldTerrain
        # List of moves reduced by grassy terrain
        GRASSY_REDUCED_MOVES = %i[earthquake magnitude bulldoze]
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          @internal_counter -= 1
          if @internal_counter <= 0
            logic.fterrain_change_handler.fterrain_change(:none)
          else
            battlers.each do |battler|
              next unless battler.affected_by_terrain?
              next if battler.dead?
              logic.damage_handler.heal(battler, battler.max_hp / 16)
            end
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1.5 if move.type_grass? && user.affected_by_terrain?
          return 0.5 if GRASSY_REDUCED_MOVES.include?(db_symbol) && user.affected_by_terrain?
          return 1
        end
      end
      register(:grassy_terrain, Grassy)
      class Misty < FieldTerrain
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          @internal_counter -= 1
          logic.fterrain_change_handler.fterrain_change(:none) if @internal_counter <= 0
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return unless target.affected_by_terrain? && status != :flinch && status != :cure
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 845, target))
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 unless move.type_dragon? && target.affected_by_terrain?
          return 0.5
        end
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false unless target.affected_by_terrain? && move.status?
          return false unless move.status_effects.any? || move.db_symbol == :yawn
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 845, target))
          return true
        end
      end
      register(:misty_terrain, Misty)
      class Psychic < FieldTerrain
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          @internal_counter -= 1
          logic.fterrain_change_handler.fterrain_change(:none) if @internal_counter <= 0
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 unless move.type_psychic? && user.affected_by_terrain?
          return 1.5
        end
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false unless target.affected_by_terrain? && move.relative_priority >= 1 && move.blocable?
          move.scene.display_message_and_wait(parse_text_with_pokemon(59, 1872, target))
          return true
        end
      end
      register(:psychic_terrain, Psychic)
    end
  end
end
