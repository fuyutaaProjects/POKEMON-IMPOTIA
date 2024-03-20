module Battle
  module AI
    # Class responsive of handling the heuristics of moves
    class MoveHeuristicBase
      @move_heuristics = {}
      # Create a new MoveHeusristicBase
      # @param ignore_effectiveness [Boolean] if this heuristic ignore effectiveness (wants to compute it themself)
      # @param ignore_power [Boolean] if this heuristic ignore power (wants to compute it themself)
      # @param overwrite_move_kind_flag [Boolean] if the effect overwrite (to true) the can see move kind flag
      def initialize(ignore_effectiveness = false, ignore_power = false, overwrite_move_kind_flag = false)
        @ignore_effectiveness = ignore_effectiveness
        @ignore_power = ignore_power
        @overwrite_move_kind_flag = overwrite_move_kind_flag
      end
      # Is this heuristic ignoring effectiveness
      # @return [Boolean]
      def ignore_effectiveness?
        return @ignore_effectiveness
      end
      # Is this heuristic ignoring power
      # @return [Boolean]
      def ignore_power?
        return @ignore_power
      end
      # Is this heuristic ignoring power
      # @return [Boolean]
      def overwrite_move_kind_flag?
        return @overwrite_move_kind_flag
      end
      # Compute the heuristic
      # @param move [Battle::Move]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param ai [Battle::AI::Base]
      # @return [Float]
      def compute(move, user, target, ai)
        return 1.0 if move.status?
        return Math.sqrt(move.special? ? user.ats_basis / target.dfs_basis.to_f : user.atk_basis / target.dfe_basis.to_f)
      end
      class << self
        # Register a new move heuristic
        # @param db_symbol [Symbol] db_symbol of the move
        # @param klass [Class<MoveHeuristicBase>, nil] klass holding the logic for this heuristic
        # @param min_level [Integer] minimum level when the heuristic acts
        # @note If there's several min_level, the highest condition matching with current AI level is choosen.
        def register(db_symbol, klass, min_level = 0)
          @move_heuristics[db_symbol] ||= []
          @move_heuristics[db_symbol].delete_if { |entry| entry[:min_level] == min_level }
          @move_heuristics[db_symbol] << {min_level: min_level, klass: klass} if klass
          @move_heuristics[db_symbol].sort_by! { |entry| -entry[:min_level] }
        end
        # Get a MoveHeuristic by db_symbol and level
        # @param db_symbol [Symbol] db_symbol of the move
        # @param level [Integer] level of the current AI
        # @return [MoveHeuristicBase]
        def new(db_symbol, level)
          klass = @move_heuristics[db_symbol]&.find { |entry| entry[:min_level] <= level }
          klass = klass ? klass[:klass] : self
          heuristic = klass.allocate
          heuristic.send(:initialize)
          return heuristic
        end
      end
      class Rest < MoveHeuristicBase
        # Create a new Rest Heuristic
        def initialize
          super(true, true, true)
        end
        # Compute the heuristic
        # @param move [Battle::Move]
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param ai [Battle::AI::Base]
        # @return [Float]
        def compute(move, user, target, ai)
          boost = user.status_effect.instance_of?(Effects::Status) ? 0 : 1
          return (1 - user.hp_rate) * 2 + boost
        end
      end
      register(:s_rest, Rest, 1)
      class HealingMoves < MoveHeuristicBase
        # Create a new Rest Heuristic
        def initialize
          super(true, true, true)
        end
        # Compute the heuristic
        # @param move [Battle::Move]
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param ai [Battle::AI::Base]
        # @return [Float]
        def compute(move, user, target, ai)
          return 0 if target.effects.has?(:heal_block)
          return 0 if target.bank != user.bank
          return 0 if move.db_symbol == :heal_pulse && target.effects.has?(:substitute)
          return 0 if healing_sacrifice_clause(move, user, target, ai)
          return (1 - target.hp_rate) * 2
        end
        # Test if sacrifice move should not be used
        # @param move [Battle::Move]
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param ai [Battle::AI::Base]
        # @return [Float]
        def healing_sacrifice_clause(move, user, target, ai)
          return move.is_a?(Move::HealingSacrifice) && ai.scene.logic.can_battler_be_replaced?(target) && ai.scene.logic.allies_of(target).none? { |pokemon| pokemon.hp_rate <= 0.75 && pokemon.party_id == target.party_id }
        end
      end
      register(:s_heal, HealingMoves, 1)
      register(:s_heal_weather, HealingMoves, 1)
      register(:s_roost, HealingMoves, 1)
      register(:s_healing_wish, HealingMoves, 1)
      register(:s_lunar_dance, HealingMoves, 1)
      class CuringMove < MoveHeuristicBase
        # Create a new Rest Heuristic
        def initialize
          super(true, true, true)
        end
        # Compute the heuristic
        # @param move [Battle::Move]
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param ai [Battle::AI::Base]
        # @return [Float]
        def compute(move, user, target, ai)
          return 0 if target.effects.has?(:heal_block)
          return 0 if target.has_ability?(:soundproof)
          return 0 if target.dead? || target.status == 0
          return 0.75 + ai.scene.logic.move_damage_rng.rand(0..0.25)
        end
      end
      register(:s_heal_bell, CuringMove, 1)
      class ReflectMoves < MoveHeuristicBase
        # Create a new Rest Heuristic
        def initialize
          super(true, true, true)
        end
        # Compute the heuristic
        # @param move [Battle::Move]
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param ai [Battle::AI::Base]
        # @return [Float]
        def compute(move, user, target, ai)
          return 0 if ai.scene.logic.bank_effects[user.bank].has?(move.db_symbol) || (move.db_symbol == :aurora_veil && !$env.hail?)
          return 0.80 if move.db_symbol == :light_screen && ai.scene.logic.foes_of(user).none? { |foe| foe.moveset.none?(&:special?) }
          return 0.80 if move.db_symbol == :reflect && ai.scene.logic.foes_of(user).none? { |foe| foe.moveset.none?(&:physical?) }
          return 0.90 + ai.scene.logic.move_damage_rng.rand(0..0.10)
        end
      end
      register(:s_reflect, ReflectMoves, 1)
    end
  end
end
