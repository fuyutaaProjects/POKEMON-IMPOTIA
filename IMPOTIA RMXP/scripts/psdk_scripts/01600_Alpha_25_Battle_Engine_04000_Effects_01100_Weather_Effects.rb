module Battle
  module Effects
    class Weather < EffectBase
      # Get the db_symbol of the weather
      # @return [Symbol]
      attr_reader :db_symbol
      @registered_weathers = {}
      # Create a new weather effect
      # @param logic [Battle::Logic]
      # @param db_symbol [Symbol] db_symbol of the weather
      def initialize(logic, db_symbol)
        super(logic)
        @db_symbol = db_symbol
      end
      class << self
        # Register a new weather
        # @param db_symbol [Symbol] db_symbol of the weather
        # @param klass [Class<Weather>] class of the weather effect
        def register(db_symbol, klass)
          @registered_weathers[db_symbol] = klass
        end
        # Create a new Weather effect
        # @param logic [Battle::Logic]
        # @param db_symbol [Symbol] db_symbol of the weather
        # @return [Weather]
        def new(logic, db_symbol)
          klass = @registered_weathers[db_symbol] || Weather
          object = klass.allocate
          object.send(:initialize, logic, db_symbol)
          return object
        end
      end
      class Fog < Weather
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if $env.decrease_weather_duration
            scene.display_message_and_wait(parse_text(18, 96))
            logic.weather_change_handler.weather_change(:none, 0)
          end
        end
      end
      register(:fog, Fog)
      class Hail < Weather
        # List of abilities that blocks hail damages
        HAIL_BLOCKING_ABILITIES = %i[magic_guard ice_body snow_cloak overcoat]
        # List of objects that block hail damages
        HAIL_BLOCKING_ITEMS = %i[safety_goggles]
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if $env.decrease_weather_duration
            scene.display_message_and_wait(parse_text(18, 95))
            logic.weather_change_handler.weather_change(:none, 0)
          else
            scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 495)
            scene.display_message_and_wait(parse_text(18, 99))
            battlers.each do |battler|
              next if battler.dead?
              next if hail_immunity?(battler)
              logic.damage_handler.damage_change((battler.max_hp / 16).clamp(1, Float::INFINITY), battler)
            end
          end
        end
        private
        # Check if we have an immunity to hail
        # @param battler [PFM::PokemonBattler]
        # @return [Boolean]
        def hail_immunity?(battler)
          return true if HAIL_BLOCKING_ABILITIES.include?(battler.battle_ability_db_symbol)
          return true if HAIL_BLOCKING_ITEMS.include?(battler.battle_item_db_symbol)
          return true if battler.type_ice?
          return true if battler.effects.has?(:out_of_reach_base)
          return false
        end
      end
      register(:hail, Hail)
      class Hardrain < Weather
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 493)
        end
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false unless move.type_fire?
          move.scene.display_message_and_wait(parse_text_with_pokemon(18, 275, target))
          return true
        end
        # Function called when a weather_prevention is checked
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_weather_prevention(handler, weather_type, last_weather)
          return if %i[hardsun hardrain strong_winds].include?(weather_type)
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text(18, 277))
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return move.type_water? ? 1.5 : 1
        end
      end
      register(:hardrain, Hardrain)
      class Hardsun < Weather
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 492)
        end
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false unless move.type_water?
          move.scene.display_message_and_wait(parse_text(18, 276))
          return true
        end
        # Function called when a weather_prevention is checked
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_weather_prevention(handler, weather_type, last_weather)
          return if %i[hardsun hardrain strong_winds].include?(weather_type)
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text(18, 278))
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return move.type_fire? ? 1.5 : 1
        end
      end
      register(:hardsun, Hardsun)
      class Rain < Weather
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if $env.decrease_weather_duration
            scene.display_message_and_wait(parse_text(18, 93))
            logic.weather_change_handler.weather_change(:none, 0)
          else
            scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 493)
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 0.5 if move.type_fire?
          return 1.5 if move.type_water?
          return 1
        end
      end
      register(:rain, Rain)
      class Sandstorm < Weather
        # List of abilities that blocks sandstorm damages
        SANDSTORM_BLOCKING_ABILITIES = %i[magic_guard sand_veil sand_rush sand_force overcoat]
        # List of objects that block sandstorm damages
        HAIL_BLOCKING_ITEMS = %i[safety_goggles]
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if $env.decrease_weather_duration
            scene.display_message_and_wait(parse_text(18, 94))
            logic.weather_change_handler.weather_change(:none, 0)
          else
            scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 494)
            scene.display_message_and_wait(parse_text(18, 98))
            battlers.each do |battler|
              next if battler.dead?
              next if sandstorm_immunity?(battler)
              logic.damage_handler.damage_change((battler.max_hp / 16).clamp(1, Float::INFINITY), battler)
            end
          end
        end
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if move.physical?
          return 1 unless target.type_rock?
          return 1.5
        end
        private
        # Check if we have an immunity to sandstorm
        # @param battler [PFM::PokemonBattler]
        # @return [Boolean]
        def sandstorm_immunity?(battler)
          return true if SANDSTORM_BLOCKING_ABILITIES.include?(battler.battle_ability_db_symbol)
          return true if HAIL_BLOCKING_ITEMS.include?(battler.battle_item_db_symbol)
          return true if battler.type_rock? || battler.type_ground? || battler.type_steel?
          return true if battler.effects.has?(:out_of_reach_base)
          return false
        end
      end
      register(:sandstorm, Sandstorm)
      class StrongWinds < Weather
        # Create a new effect
        # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
        def initialize(logic, db_symbol)
          @super_effective_types = each_data_type.select { |type| type.hit(:flying) > 1 }.map(&:id)
          super(logic, db_symbol)
        end
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if battlers.none? { |battler| battler.has_ability?(:delta_stream) }
            logic.weather_change_handler.weather_change(:none, 0)
            return scene.display_message_and_wait(parse_text(18, 274))
          end
          scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 566)
        end
        # Function called when a weather_prevention is checked
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog, :hardsun, :hardrain
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_weather_prevention(handler, weather_type, last_weather)
          return if %i[hardsun hardrain strong_winds].include?(weather_type)
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text(18, 280))
          end
        end
        # Function called before the accuracy check of a move is done
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param targets [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_accuracy_check(logic, scene, targets, launcher, skill)
          return if skill.status?
          return if targets.none?(&:type_flying?)
          if targets.none? { |target| @super_effective_types.any? { |super_effective_type| skill.definitive_types(launcher, target).include?(super_effective_type) } }
            return false
          end
          skill.scene.display_message_and_wait(parse_text(18, 279))
        end
        # Function that computes an overwrite of the type multiplier
        # @param target [PFM::PokemonBattler]
        # @param target_type [Integer] one of the type of the target
        # @param type [Integer] one of the type of the move
        # @param move [Battle::Move]
        # @return [Float, nil] overwriten type multiplier
        def on_single_type_multiplier_overwrite(target, target_type, type, move)
          return unless target_type == data_type(:flying).id
          return 1 if @super_effective_types.any? { |super_effective_type| super_effective_type == type }
        end
      end
      register(:strong_winds, StrongWinds)
      class Sunny < Weather
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          if $env.decrease_weather_duration
            scene.display_message_and_wait(parse_text(18, 92))
            logic.weather_change_handler.weather_change(:none, 0)
          else
            scene.visual.show_rmxp_animation(battlers.first || logic.battler(0, 0), 492)
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1.5 if move.type_fire?
          return 0.5 if move.type_water?
          return 1
        end
      end
      register(:sunny, Sunny)
    end
  end
end
