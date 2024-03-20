module Battle
  module Effects
    class Ability < EffectBase
      # Get the db_symbol of the ability
      # @return [Symbol]
      attr_reader :db_symbol
      # Get the target of the effect
      # @return [PFM::PokemonBattler]
      attr_reader :target
      # Detect if the ability affects allies
      # @return [Boolean]
      attr_reader :affect_allies
      @registered_abilities = {}
      # Create a new ability effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param db_symbol [Symbol] db_symbol of the ability
      def initialize(logic, target, db_symbol)
        super(logic)
        @target = target
        @db_symbol = db_symbol
        @affect_allies = false
      end
      class << self
        # Register a new ability
        # @param db_symbol [Symbol] db_symbol of the ability
        # @param klass [Class<Ability>] class of the ability effect
        def register(db_symbol, klass)
          @registered_abilities[db_symbol] = klass
        end
        # Create a new Ability effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        # @return [Ability]
        def new(logic, target, db_symbol)
          klass = @registered_abilities[db_symbol] || Ability
          object = klass.allocate
          object.send(:initialize, logic, target, db_symbol)
          return object
        end
      end
      class BoostingMoveType < Ability
        # Initial condition to give the power increase
        POWER_INCREASE_CONDITION = Hash.new(proc {true })
        # Type condition to give the power increase
        TYPE_CONDITION = Hash.new(:normal)
        # Power increase if all condition are met
        POWER_INCREASE = Hash.new(1.5)
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return 1 unless POWER_INCREASE_CONDITION[@db_symbol].call(user, target, move)
          return 1 if move.type != data_type(TYPE_CONDITION[@db_symbol]).id
          return POWER_INCREASE[@db_symbol]
        end
        class << self
          # Register a BoostingMoveType ability
          # @param db_symbol [Symbol] db_symbol of the ability
          # @param type [Symbol] move type getting power increase
          # @param multiplier [Float] multiplier if all condition are meet
          # @param block [Proc] additional condition
          # @yieldparam user [PFM::PokemonBattler]
          # @yieldparam target [PFM::PokemonBattler]
          # @yieldparam move [Battle::Move]
          # @yieldreturn [Boolean]
          def register(db_symbol, type, multiplier = nil, &block)
            POWER_INCREASE_CONDITION[db_symbol] = block if block
            TYPE_CONDITION[db_symbol] = type
            POWER_INCREASE[db_symbol] = multiplier if multiplier
            Ability.register(db_symbol, BoostingMoveType)
          end
        end
        register(:blaze, :fire) { |user| user.hp_rate <= 0.333 }
        register(:overgrow, :grass) { |user| user.hp_rate <= 0.333 }
        register(:torrent, :water) { |user| user.hp_rate <= 0.333 }
        register(:swarm, :bug) { |user| user.hp_rate <= 0.333 }
        register(:dragon_s_maw, :dragon)
        register(:steelworker, :steel)
        register(:transistor, :electric)
        register(:rocky_payload, :rock)
      end
      class ElectricSurge < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          fterrain_handler = handler.logic.fterrain_change_handler
          return unless fterrain_handler.fterrain_appliable?(terrain_type)
          handler.scene.visual.show_ability(with)
          fterrain_handler.fterrain_change(terrain_type)
        end
        private
        # Tell which fieldterrain will be set
        # @return [Symbol]
        def terrain_type
          return :electric_terrain
        end
      end
      register(:electric_surge, ElectricSurge)
      class GrassySurge < ElectricSurge
        private
        # Tell which fieldterrain will be set
        # @return [Symbol]
        def terrain_type
          return :grassy_terrain
        end
      end
      register(:grassy_surge, GrassySurge)
      class MistySurge < ElectricSurge
        private
        # Tell which fieldterrain will be set
        # @return [Symbol]
        def terrain_type
          return :misty_terrain
        end
      end
      register(:misty_surge, MistySurge)
      class PsychicSurge < ElectricSurge
        private
        # Tell which fieldterrain will be set
        # @return [Symbol]
        def terrain_type
          return :psychic_terrain
        end
      end
      register(:psychic_surge, PsychicSurge)
      class ShadowTag < Ability
        # Function called when testing if pokemon can switch (when he couldn't passthrough)
        # @param handler [Battle::Logic::SwitchHandler]
        # @param pokemon [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] potential skill used to switch
        # @param reason [Symbol] the reason why the SwitchHandler is called
        # @return [:prevent, nil] if :prevent, can_switch? will return false
        def on_switch_prevention(handler, pokemon, skill, reason)
          return if effect_prevented?(pokemon, skill)
          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            text = parse_text_with_pokemon(19, 881, @target, PFM::Text::PKNICK[0] => @target.given_name, PFM::Text::ABILITY[1] => @target.ability_name)
            handler.scene.display_message_and_wait(text)
          end
        end
        private
        # Additional check that prevent effect
        # @param pokemon [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] potential skill used to switch
        # @return [Boolean]
        def effect_prevented?(pokemon, skill)
          return pokemon.bank == @target.bank || pokemon.type_ghost? || pokemon.has_ability?(:shadow_tag)
        end
      end
      register(:shadow_tag, ShadowTag)
      class MagnetPull < ShadowTag
        private
        # Additional check that prevent effect
        # @param pokemon [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] potential skill used to switch
        # @return [Boolean]
        def effect_prevented?(pokemon, skill)
          return pokemon.bank == @target.bank || !pokemon.type_steel?
        end
      end
      register(:magnet_pull, MagnetPull)
      class SuctionCups < ShadowTag
        private
        # Additional check that prevent effect
        # @param pokemon [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] potential skill used to switch
        # @return [Boolean]
        # @note I think this ability is not designed to be implemented like this, it should kill the passthrough
        # @todo fix this ability
        def effect_prevented?(pokemon, skill)
          return true if pokemon.can_be_lowered_or_canceled?
          return pokemon.bank == @target.bank || !skill || skill.force_switch?
        end
      end
      register(:suction_cups, SuctionCups)
      class ArenaTrap < ShadowTag
        private
        # Additional check that prevent effect
        # @param pokemon [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] potential skill used to switch
        # @return [Boolean]
        def effect_prevented?(pokemon, skill)
          return pokemon.bank == @target.bank || !pokemon.grounded?
        end
      end
      register(:arena_trap, ArenaTrap)
      class SuperEffectivePowerReduction < Ability
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled? && move.super_effective?
          return 0.75
        end
      end
      register(:solid_rock, SuperEffectivePowerReduction)
      register(:filter, SuperEffectivePowerReduction)
      register(:prism_armor, SuperEffectivePowerReduction)
      class Drizzle < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          weather_handler = handler.logic.weather_change_handler
          return unless weather_handler.weather_appliable?(weather)
          handler.scene.visual.show_ability(with)
          nb_turn = with.hold_item?(item_db_symbol) ? 8 : 5
          weather_handler.weather_change(weather, nb_turn)
          handler.scene.visual.show_rmxp_animation(with, animation_id)
        end
        private
        # Tell the weather to set
        # @return [Symbol]
        def weather
          return :rain
        end
        # Tell which item increase the turn count
        # @return [Symbol]
        def item_db_symbol
          return :damp_rock
        end
        # Tell which animation to play
        # @return [Integer]
        def animation_id
          493
        end
      end
      register(:drizzle, Drizzle)
      class Drought < Drizzle
        private
        # Tell the weather to set
        # @return [Symbol]
        def weather
          return :sunny
        end
        # Tell which item increase the turn count
        # @return [Symbol]
        def item_db_symbol
          return :heat_rock
        end
        # Tell which animation to play
        # @return [Integer]
        def animation_id
          492
        end
      end
      register(:drought, Drought)
      class SandStream < Drizzle
        private
        # Tell the weather to set
        # @return [Symbol]
        def weather
          return :sandstorm
        end
        # Tell which item increase the turn count
        # @return [Symbol]
        def item_db_symbol
          return :smooth_rock
        end
        # Tell which animation to play
        # @return [Integer]
        def animation_id
          494
        end
      end
      register(:sand_stream, SandStream)
      class SnowWarning < Drizzle
        private
        # Tell the weather to set
        # @return [Symbol]
        def weather
          return :hail
        end
        # Tell which item increase the turn count
        # @return [Symbol]
        def item_db_symbol
          return :icy_rock
        end
        # Tell which animation to play
        # @return [Integer]
        def animation_id
          494
        end
      end
      register(:snow_warning, SnowWarning)
      class ChangingMoveType < BoostingMoveType
        # List of type overwrite
        TYPES_OVERWRITES = Hash.new(:normal)
        # Function called when we try to get the definitive type of a move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @param type [Integer] current type of the move (potentially after effects)
        # @return [Integer, nil] new type of the move
        def on_move_type_change(user, target, move, type)
          return nil if self.target != user || move.be_method == :s_weather_ball || type != data_type(:normal).id
          return data_type(TYPES_OVERWRITES[db_symbol]).id
        end
        class << self
          # Register a ChangingMoveType ability
          # @param db_symbol [Symbol] db_symbol of the ability
          # @param type_overwrite [Symbol] move type overwrite for weather_ball
          # @param multiplier [Float] multiplier if all condition are meet
          # @param block [Proc] additional condition
          # @yieldparam user [PFM::PokemonBattler]
          # @yieldparam target [PFM::PokemonBattler]
          # @yieldparam move [Battle::Move]
          # @yieldreturn [Boolean]
          def register(db_symbol, type_overwrite, multiplier = 1.3, &block)
            POWER_INCREASE_CONDITION[db_symbol] = block if block
            BoostingMoveType::TYPE_CONDITION[db_symbol] = :normal
            TYPES_OVERWRITES[db_symbol] = type_overwrite
            BoostingMoveType::POWER_INCREASE[db_symbol] = multiplier if multiplier
            Ability.register(db_symbol, ChangingMoveType)
          end
        end
        register(:pixilate, :fairy)
        register(:refrigerate, :ice)
        register(:aerilate, :flying)
        register(:galvanize, :electric)
      end
      class Aftermath < Ability
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          return if handler.logic.all_alive_battlers.any? { |battler| battler.has_ability?(:damp) }
          damages = (launcher.max_hp / 4).clamp(1, Float::INFINITY)
          handler.scene.visual.show_ability(target)
          handler.scene.visual.show_hp_animations([launcher], [-damages])
        end
      end
      register(:aftermath, Aftermath)
      class AirLock < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target || $env.current_weather_db_symbol == :none
          handler.scene.visual.show_ability(with)
          handler.logic.weather_change_handler.weather_change(:none, 0)
        end
        # Function called when a weather_prevention is checked
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_weather_prevention(handler, weather_type, last_weather)
          return if weather_type == :none
          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
          end
        end
      end
      register(:air_lock, AirLock)
      register(:cloud_nine, AirLock)
      class Analytic < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return move.logic.battler_attacks_last?(user) ? 1.3 : 1
        end
      end
      register(:analytic, Analytic)
      class AngerPoint < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.critical_hit?
          if handler.logic.stat_change_handler.stat_increasable?(:atk, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:atk, 12, target)
          end
        end
      end
      register(:anger_point, AngerPoint)
      class AngerShell < Ability
        # Stats affected by ability activation
        STATS = {atk: 1, ats: 1, spd: 1, dfe: -1, dfs: -1}
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target || target.hp_rate > 0.5
          return if launcher.has_ability?(:sheer_force) && launcher.ability_effect&.activated?
          return unless target.hp + hp > target.max_hp / 2
          handler.scene.visual.show_ability(target)
          handler.scene.visual.wait_for_animation
          STATS.each do |stat, value|
            next if value.positive? && !handler.logic.stat_change_handler.stat_increasable?(stat, target)
            next if value.negative? && !handler.logic.stat_change_handler.stat_decreasable?(stat, target)
            handler.logic.stat_change_handler.stat_change(stat, value, target)
          end
        end
      end
      register(:anger_shell, AngerShell)
      class Anticipation < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.logic.foes_of(with).each do |foe|
            next(false) if foe.dead?
            next(false) if foe.moveset.none? { |move| move.type_modifier(foe, with) >= 2 || move.be_method == :s_ohko }
            handler.scene.visual.show_ability(with)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 436, with))
          end
        end
      end
      register(:anticipation, Anticipation)
      class ArmorTail < Ability
        # Create a new Armor Tail effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user == @target || user.bank == @target.bank
          return unless move&.priority(user) > 7 && (move&.one_target? || move&.db_symbol == :perish_song)
          return unless user&.can_be_lowered_or_canceled?
          move.scene.visual.show_ability(@target)
          move.scene.visual.wait_for_animation
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 911, user, PFM::Text::MOVE[1] => move.name))
          return :prevent
        end
      end
      register(:armor_tail, ArmorTail)
      class Auras < Ability
        # List of messages shown when entering the field
        AURA_MESSAGES = {fairy_aura: 1205, dark_aura: 1201, aura_break: 1231}
        # Create a new PowerSpot effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != target
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, AURA_MESSAGES[db_symbol], with))
        end
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          fairy_aura_active = move.type_fairy? && move.logic.any_field_ability_active?(:fairy_aura)
          dark_aura_active = move.type_dark? && move.logic.any_field_ability_active?(:dark_aura)
          return 1 unless fairy_aura_active || dark_aura_active
          return move.logic.any_field_ability_active?(:aura_break) ? 0.75 : 1.33
        end
      end
      register(:fairy_aura, Auras)
      register(:dark_aura, Auras)
      register(:aura_break, Auras)
      class BadDreams < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          sleeping_foes = logic.foes_of(@target).select(&:asleep?) + logic.foes_of(@target).select { |p| p.has_ability?(:comatose) }
          return unless sleeping_foes.any?
          scene.visual.show_ability(@target) if sleeping_foes.any?
          sleeping_foes.each do |sleeping_foe|
            hp = sleeping_foe.max_hp / 8
            logic.damage_handler.damage_change(hp.clamp(1, Float::INFINITY), sleeping_foe)
          end
        end
      end
      register(:bad_dreams, BadDreams)
      class BallFetch < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless pick_up_possible?(logic)
          scene.visual.show_ability(@target)
          logic.item_change_handler.change_item($bag.last_ball_used_db_symbol, true, @target)
          @target.ability_used = true
        end
        private
        # Function that check if we can pick up Pokeball
        # @param logic [Battle::Logic] logic of the battle
        # @return [Boolean]
        def pick_up_possible?(logic)
          result = logic.ball_fetch_on_field
          return false if result.empty? || result.first != @target
          return false if @target.dead? || @target.ability_used || @target.battle_item_db_symbol != :__undef__
          return false if $bag.last_ball_used_db_symbol == :__undef__
          return true
        end
      end
      register(:ball_fetch, BallFetch)
      class Battery < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user == @target && user.bank != @target.bank
          return move.special? ? 1.3 : 1
        end
      end
      register(:battery, Battery)
      class BattleBond < Ability
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          @activate = true if @activate.nil?
          if launcher == @target
            return unless launcher && launcher.hp > 0
            return if @activate == false
            original_form = launcher.form
            launcher.form_calibrate(:battle)
            if launcher.form != original_form
              handler.scene.visual.show_ability(launcher)
              handler.scene.visual.show_switch_form_animation(launcher)
            end
          else
            if target == @target
              target.form = 0
              @activate = false
            end
          end
        end
      end
      register(:battle_bond, BattleBond)
      class BeastBoost < Ability
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher == target
          return unless launcher && launcher.hp > 0
          stat = boosted_stat(launcher.spd, launcher.dfs, launcher.ats, launcher.dfe, launcher.atk)
          return if stat.nil?
          if handler.logic.stat_change_handler.stat_increasable?(stat, launcher)
            handler.scene.visual.show_ability(launcher)
            handler.logic.stat_change_handler.stat_change_with_process(stat, 1, launcher)
          end
        end
        private
        # @param spd [Integer] Return the current spd
        # @param dfs [Integer] Return the current dfs
        # @param ats [Integer] Return the current ats
        # @param dfe [Integer] Return the current dfe
        # @param atk [Integer] Return the current atk
        def boosted_stat(spd, dfs, ats, dfe, atk)
          stats = [[:spd, spd], [:dfs, dfs], [:ats, ats], [:dfe, dfe], [:atk, atk]]
          return stats.max_by(&:last)&.first
        end
      end
      register(:beast_boost, BeastBoost)
      class Berserk < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target || target.hp_rate > 0.5
          return unless (target.hp + hp) > (target.max_hp / 2)
          return if launcher.has_ability?(:sheer_force) && launcher.ability_effect&.activated?
          if handler.logic.stat_change_handler.stat_increasable?(:ats, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:ats, 1, target)
          end
        end
      end
      register(:berserk, Berserk)
      class BigPecks < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return if target == launcher || stat != :dfe
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 201, target))
          end
        end
      end
      register(:big_pecks, BigPecks)
      class Bulletproof < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Boolean] if the target is immune to the move
        def on_move_ability_immunity(user, target, move)
          return false if target != @target
          return @logic.scene.visual.show_ability(target) && true if move.ballistics? && user.can_be_lowered_or_canceled?
          return false
        end
      end
      register(:bulletproof, Bulletproof)
      class ChillingNeigh < Ability
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher == target
          return unless launcher && launcher.hp > 0
          if handler.logic.stat_change_handler.stat_increasable?(boosted_stat, launcher)
            handler.scene.visual.show_ability(launcher)
            handler.logic.stat_change_handler.stat_change_with_process(boosted_stat, 1, launcher)
          end
        end
        private
        def boosted_stat
          return :atk
        end
      end
      register(:chilling_neigh, ChillingNeigh)
      class GrimNeigh < ChillingNeigh
        private
        def boosted_stat
          return :ats
        end
      end
      register(:grim_neigh, GrimNeigh)
      class Chlorophyll < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return ($env.sunny? || $env.hardsun?) ? 2 : 1
        end
      end
      register(:chlorophyll, Chlorophyll)
      class ClearBody < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return unless launcher && target != launcher && launcher.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 198, target))
          end
        end
      end
      register(:clear_body, ClearBody)
      class ColorChange < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill && launcher
          return if skill.status? || skill.is_a?(Battle::Move::Basic::MultiHit) && !skill.last_hit?
          definitive_types = skill.definitive_types(launcher, target)
          return if definitive_types.any? { |type| target.type?(type) || type == 0 }
          return if launcher.has_ability?(:sheer_force) && launcher.ability_effect&.activated?
          handler.scene.visual.show_ability(target)
          target.type1 = definitive_types.first
          target.type2 = 0
          target.type3 = 0
          text = parse_text_with_pokemon(19, 899, target, PFM::Text::PKNICK[0] => target.given_name, '[VAR TYPE(0001)]' => data_type(definitive_types.first).name)
          handler.scene.display_message_and_wait(text)
        end
      end
      register(:color_change, ColorChange)
      class Comatose < Ability
        STATUS = %i[toxic poison burn paralysis freeze sleep]
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return unless STATUS.include?(status)
          return handler.prevent_change do
            handler.scene.display_message_and_wait(parse_text(18, 74))
          end
        end
      end
      register(:comatose, Comatose)
      class CompoundEyes < Ability
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if user != @target
          return 1.3
        end
      end
      register(:compound_eyes, CompoundEyes)
      class Contrary < Ability
        # Function called when a stat_change is about to be applied
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param power [Integer] power of the stat change
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Integer, nil] if integer, it will change the power
        def on_stat_change(handler, stat, power, target, launcher, skill)
          return if target != @target
          if !launcher || launcher.can_be_lowered_or_canceled?
            handler.scene.visual.show_ability(target)
            return -power
          end
          return nil
        end
        # Name of the effect
        # @return [Symbol]
        def name
          return :contrary
        end
      end
      register(:contrary, Contrary)
      class Costar < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          allies = handler.logic.allies_of(with).reject { |ally| ally.battle_stage.all?(&:zero?) }
          return if allies.empty?
          ally = allies.sample
          ally.battle_stage.each_with_index do |stat_value, index|
            next if stat_value.zero?
            with.set_stat_stage(index, stat_value)
          end
          handler.scene.visual.show_ability(with)
          handler.scene.visual.wait_for_animation
          handler.scene.display_message_and_wait(parse_text_with_2pokemon(19, 1053, with, ally))
        end
      end
      register(:costar, Costar)
      class CottonDown < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill && launcher && launcher.hp > 0
          if handler.logic.stat_change_handler.stat_decreasable?(:spd, launcher)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:spd, -1, launcher, launcher.has_ability?(:mirror_armor) ? target : nil)
          end
        end
      end
      register(:cotton_down, CottonDown)
      class CuriousMedicine < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target || who == with
          targets = @logic.adjacent_allies_of(@target)
          targets.each do |target|
            next if target.battle_stage.none? { |stage| stage != 0 }
            handler.scene.visual.show_ability(@target)
            target.battle_stage.map! {0 }
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 195, target))
          end
        end
      end
      register(:curious_medicine, CuriousMedicine)
      class CursedBody < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && bchance?(0.3, @logic) && !launcher.has_ability?(:long_reach)
          return if (target.effects.has?(:substitute) && !skill.authentic?) || skill.db_symbol == :struggle || target.effects.has?(:disable)
          handler.scene.visual.show_ability(target)
          launcher.effects.add(Effects::Disable.new(@logic, launcher, skill))
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 592, launcher, PFM::Text::MOVE[1] => skill.name))
        end
      end
      register(:cursed_body, CursedBody)
      class CuteCharm < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && bchance?(0.3, @logic) && !launcher.has_ability?(:long_reach)
          return unless launcher.gender * target.gender == 2 && launcher.effects.has?(:attract)
          handler.scene.visual.show_ability(target)
          launcher.effects.add(Effects::Attract.new(handler.logic, launcher, target))
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 327, launcher))
        end
      end
      register(:cute_charm, CuteCharm)
      class DauntlessShield < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.scene.visual.show_ability(with)
          handler.logic.stat_change_handler.stat_change_with_process(:dfe, 1, with)
        end
      end
      register(:dauntless_shield, DauntlessShield)
      class Defeatist < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return 0.5 if user.hp < user.max_hp / 2
          return 1
        end
      end
      register(:defeatist, Defeatist)
      class Defiant < Ability
        # Function called when a stat_change has been applied
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param power [Integer] power of the stat change
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Integer, nil] if integer, it will change the power
        def on_stat_change_post(handler, stat, power, target, launcher, skill)
          return if target != @target || target == launcher
          return if @logic.allies_of(target).include?(launcher)
          return if power >= 0
          handler.scene.visual.show_ability(target)
          handler.logic.stat_change_handler.stat_change_with_process(stat_changed, 2, target)
        end
        # Stat changed by the ability
        # @return [symbol] of the stat
        def stat_changed
          return :atk
        end
      end
      class Competitive < Defiant
        # Stat changed by the ability
        # @return [symbol] of the stat
        def stat_changed
          return :ats
        end
      end
      register(:defiant, Defiant)
      register(:competitive, Competitive)
      class Disguise < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target || target.effects.has?(:heal_block) || skill&.status?
          return unless launcher&.can_be_lowered_or_canceled?
          original_form = target.form
          target.form_calibrate(:battle)
          if target.form != original_form
            return handler.prevent_change do
              handler.scene.visual.show_ability(target)
              handler.scene.visual.show_switch_form_animation(target)
              handler.scene.visual.show_hp_animations([target], [-target.max_hp / 8])
            end
          end
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          target.form = 0
        end
      end
      register(:disguise, Disguise)
      class Download < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          random_foe = handler.logic.foes_of(with).shuffle(random: handler.logic.generic_rng).find(&:alive?)
          return unless random_foe
          handler.scene.visual.show_ability(with)
          handler.logic.stat_change_handler.stat_change_with_process(random_foe.dfe < random_foe.dfs ? :atk : :ats, 1, with)
        end
      end
      register(:download, Download)
      class DrySkin < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return move.type == data_type(:fire).id ? 1.25 : 1
        end
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return unless skill&.type_water? && target == self.target
          return unless launcher.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.logic.damage_handler.heal(target, target.max_hp / 4)
          end
        end
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(target)
          return if target.dead?
          if $env.rain? || $env.hardrain?
            scene.visual.show_ability(target)
            logic.damage_handler.heal(target, target.max_hp / 8)
          else
            if $env.sunny? || $env.hardsun?
              scene.visual.show_ability(target)
              logic.damage_handler.damage_change((target.max_hp / 8).clamp(1, Float::INFINITY), target)
            end
          end
        end
      end
      register(:dry_skin, DrySkin)
      class EffectSpore < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          return if launcher&.has_ability?(:overcoat)
          return if (n = handler.logic.generic_rng.rand(10)) > 2
          status = %i[poison sleep paralysis][n]
          handler.scene.visual.show_ability(target)
          handler.logic.status_change_handler.status_change_with_process(status, launcher, target)
        end
      end
      register(:effect_spore, EffectSpore)
      class Electromorphosis < Ability
        # Create a new Wind Rider effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @activated = false
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target
          @activated = true
          handler.scene.visual.show_ability(target)
        end
        alias on_post_damage_death on_post_damage
        # Give the move base power mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def base_power_multiplier(user, target, move)
          return super unless @activated
          return super unless move.type_electric?
          @activated = false
          return 1.5
        end
      end
      register(:electromorphosis, Electromorphosis)
      class EmergencyExit < Ability
        # Create a new Emergency Exit effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @damage_dealt = 0
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return if target.ability_used
          return if target.hp_rate > 0.5 || target.effects.has?(&:out_of_reach?)
          return if skill_prevention?(hp, skill) || item_prevention?(target)
          return if launcher.has_ability?(:sheer_force) && launcher.ability_effect&.activated?
          return if handler.logic.switch_request.any? { |request| request[:who] == target }
          @damage_dealt = 0
          if @logic.battle_info.trainer_battle?
            return unless handler.logic.can_battler_be_replaced?(target)
            target.ability_used = true
            handler.scene.visual.show_ability(target)
            handler.scene.visual.wait_for_animation
            @logic.actions.reject! { |a| a.is_a?(Actions::Attack) && a.launcher == target }
            handler.logic.switch_request << {who: target}
          else
            handler.scene.visual.show_ability(target)
            @battler_s = handler.scene.visual.battler_sprite(target.bank, target.position)
            @battler_s.flee_animation
            @logic.scene.visual.wait_for_animation
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 767, target))
            @logic.battle_result = 1
          end
        end
        # Check if a move will prevents the ability from triggering
        # @param hp [Integer] number of hp (damage) dealt
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Boolean]
        def skill_prevention?(hp, skill)
          return false unless skill
          return true if skill.force_switch? || skill.be_method == :s_sky_drop
          @damage_dealt += hp
          return true if skill.is_a?(Battle::Move::Basic::MultiHit) && !skill.last_hit?
          return false if (target.hp + @damage_dealt) > target.max_hp / 2
        end
        # Check if an item effect prevents the ability from triggering
        # @param target [PFM::PokemonBattler]
        # @return [Boolean]
        def item_prevention?(target)
          return true if target.hold_item?(:eject_button)
          return false unless target.hold_berry?(target.item_db_symbol)
          hp_healed = target.item_effect&.hp_healed || 0
          return (target.hp + hp_healed) > target.max_hp / 2
        end
      end
      register(:emergency_exit, EmergencyExit)
      register(:wimp_out, EmergencyExit)
      class FlameBody < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && launcher.can_be_burn? && bchance?(0.3, @logic) && !launcher.has_ability?(:long_reach)
          handler.scene.visual.show_ability(target)
          handler.logic.status_change_handler.status_change_with_process(:burn, launcher, target)
        end
      end
      register(:flame_body, FlameBody)
      class FlareBoost < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.special? && user.burn? ? 1.5 : 1
        end
      end
      register(:flare_boost, FlareBoost)
      class FlashFire < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill&.type_fire?
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.logic.status_change_handler.status_change_with_process(:cure, target) if target.frozen?
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, @boost_enabled ? 24 : 427, target))
            @boost_enabled = true
          end
        end
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return unless skill&.type_fire?
          return unless launcher && target != launcher && launcher.can_be_lowered_or_canceled?
          return :prevent
        end
        # Function called when a stat_increase_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat increase cannot apply
        def on_stat_increase_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return unless skill&.type_fire?
          return unless launcher && target != launcher && launcher.can_be_lowered_or_canceled?
          return :prevent
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :burn
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            if skill&.status?
              handler.scene.visual.show_ability(target)
              handler.scene.display_message_and_wait(parse_text_with_pokemon(19, @boost_enabled ? 24 : 427, target))
              @boost_enabled = true
            end
          end
        end
        # Give the move mod1 mutiplier (before the +2 in the formula)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod1_multiplier(user, target, move)
          return 1 if user != @target || !@boost_enabled
          return move.type_fire? ? 1.5 : 1
        end
        # Reset the boost when leaving battle
        def reset
          @boost_enabled = false
        end
      end
      register(:flash_fire, FlashFire)
      class FlowerGift < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user.bank != @target.bank
          return move.physical? && $env.sunny? ? 1.5 : 1
        end
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if target.bank != @target.bank
          return 1 unless user.can_be_lowered_or_canceled?
          return move.special? && ($env.sunny? || $env.hardsun?) ? 1.5 : 1
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        def on_post_weather_change(handler, weather_type, last_weather)
          original_form = @target.form
          return unless @target.form_generation(-1) != original_form
          handler.scene.visual.show_ability(@target)
          handler.scene.visual.show_switch_form_animation(@target)
        end
      end
      register(:flower_gift, FlowerGift)
      class FlowerVeil < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target.bank != @target.bank
          return unless launcher && target.type_grass? && launcher.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 198, @target))
          end
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target.bank != @target.bank
          return unless launcher && target.type_grass? && launcher.can_be_lowered_or_canceled?
          return if status == :cure || launcher == target || skill&.db_symbol == :rest
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 1180, @target))
          end
        end
      end
      register(:flower_veil, FlowerVeil)
      class Fluffy < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 0.5 if move.direct? && user.can_be_lowered_or_canceled? && !user.has_ability?(:long_reach)
          return 2 if move.type == data_type(:fire).id
          return 1
        end
      end
      register(:fluffy, Fluffy)
      class Forecast < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          original_form = @target.form
          return unless @target.form_generation(-1) != original_form
          scene.visual.show_switch_form_animation(@target)
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        def on_post_weather_change(handler, weather_type, last_weather)
          original_form = @target.form
          return unless @target.form_generation(-1) != original_form
          handler.scene.visual.show_switch_form_animation(@target)
        end
      end
      register(:forecast, Forecast)
      class Forewarn < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          alive_foes = handler.logic.foes_of(with).select(&:alive?)
          return if alive_foes.empty?
          dangers = alive_foes.map do |foe|
            next([foe, foe.moveset.shuffle(random: handler.logic.generic_rng).max_by(&:power)])
          end
          danger_foe, danger_move = dangers.shuffle(random: handler.logic.generic_rng).max_by { |(_, move)| move.power }
          return if danger_move.power <= 0
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 433, danger_foe, PFM::Text::MOVE[1] => danger_move.name))
        end
      end
      register(:forewarn, Forewarn)
      class FriendGuard < Ability
        # Create a new FriendGuard effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target.bank != self.target.bank
          return 1 unless user.can_be_lowered_or_canceled?
          return 0.75
        end
      end
      register(:friend_guard, FriendGuard)
      class Frisk < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          foe_item = handler.logic.foes_of(with).find { |foe| foe.alive? && foe.battle_item_db_symbol != :__undef__ }
          return unless foe_item
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 439, with, PFM::Text::PKNICK[1] => foe_item.given_name, PFM::Text::ITEM2[2] => foe_item.item_name))
        end
      end
      register(:frisk, Frisk)
      class FullMetalBody < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return if target == launcher || !launcher
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 198, target))
          end
        end
      end
      register(:full_metal_body, FullMetalBody)
      class FurCoat < Ability
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return move.physical? ? 2 : 1
        end
      end
      register(:fur_coat, FurCoat)
      class GaleWings < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param priority [Integer]
        # @param move [Battle::Move]
        # @return [Proc, nil]
        def on_move_priority_change(user, priority, move)
          return nil if user != @target
          return nil unless move.type_fly? && user.hp == user.max_hp
          return priority + 1
        end
      end
      register(:gale_wings, GaleWings)
      class Gooey < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          if handler.logic.stat_change_handler.stat_decreasable?(:spd, launcher)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:spd, -1, launcher, launcher.has_ability?(:mirror_armor) ? target : nil)
          end
        end
      end
      register(:gooey, Gooey)
      register(:tangling_hair, Gooey)
      class GorillaTactics < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.physical? ? 1.5 : 1
        end
        # Function called when we try to check if the user cannot use a move
        # @param user [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Proc, nil]
        def on_move_disabled_check(user, move)
          return unless user == @target && user.move_history.any?
          return if user.move_history.last.db_symbol == move.db_symbol
          return if user.move_history.last.turn < user.last_sent_turn
          return proc {            move.scene.visual.show_ability(user)
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 911, user, PFM::Text::MOVE[1] => move.name))
 }
        end
      end
      register(:gorilla_tactics, GorillaTactics)
      class GrassPelt < Ability
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if target != @target
          return move.physical? && @logic.field_terrain_effect.grassy? ? 1.5 : 1
        end
      end
      register(:grass_pelt, GrassPelt)
      class GulpMissile < Ability
        FORM_ARROKUDA = :arrokuda
        FORM_PIKACHU = :pikachu
        BASE_FORM = :base
        TRIGGER_SKILLS = %i[surf waterfall]
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          catch_prey(handler, hp, target, launcher, skill) if launcher == @target
          spit_out_prey(handler, hp, target, launcher, skill) if target == @target
        end
        private
        # Catch a different prey according to the current HP
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def catch_prey(handler, hp, target, launcher, skill)
          return unless @target.form == 0 && TRIGGER_SKILLS.include?(skill.db_symbol)
          @target.form_calibrate(@target.hp_rate > 0.5 ? FORM_ARROKUDA : FORM_PIKACHU)
          handler.scene.visual.show_switch_form_animation(@target)
        end
        # Spit out the prey, causing damage and additional effects depending on the form
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def spit_out_prey(handler, hp, target, launcher, skill)
          return if @target.form == 0 || skill.status?
          damages = (launcher.max_hp / 4).clamp(1, Float::INFINITY)
          handler.scene.visual.show_ability(@target)
          handler.scene.visual.show_hp_animations([launcher], [-damages]) unless launcher.has_ability?(:magic_guard)
          case @target.form
          when 1
            handler.logic.stat_change_handler.stat_change_with_process(:dfe, -1, launcher, launcher.has_ability?(:mirror_armor) ? target : nil)
          else
            handler.logic.status_change_handler.status_change_with_process(:paralysis, launcher, target)
          end
          @target.form_calibrate(BASE_FORM)
          handler.scene.visual.show_switch_form_animation(@target)
        end
      end
      register(:gulp_missile, GulpMissile)
      class Guts < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target || user.status_effect.instance_of?(Status)
          return move.physical? ? 1.5 : 1
        end
      end
      register(:guts, Guts)
      class HadronEngine < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          unless handler.logic.field_terrain_effect.electric?
            handler.scene.visual.show_ability(with)
            handler.scene.visual.wait_for_animation
            handler.logic.fterrain_change_handler.fterrain_change(:electric_terrain)
            handler.logic.field_terrain_effect.internal_counter += 3 if with.hold_item?(:terrain_extender)
          end
        end
        # Give the ats modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def ats_modifier
          return 1 unless @logic.field_terrain_effect.electric?
          return 1.33
        end
      end
      register(:hadron_engine, HadronEngine)
      class Harvest < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          return unless @target.item_consumed && data_item(@target.consumed_item)&.socket == 4 && @target.item_db_symbol == :__undef__
          return unless bchance?(0.5) || $env.sunny? || $env.hardsun?
          scene.visual.show_ability(@target)
          logic.item_change_handler.change_item(@target.consumed_item, true, @target)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 475, @target, PFM::Text::ITEM2[1] => @target.item_name))
          target.item_effect.execute_berry_effect if target.item_effect.is_a?(Effects::Item::Berry)
        end
      end
      register(:harvest, Harvest)
      # At the end of each turn, Healer has a 30% chance of curing an adjacent ally's status condition.
      # @see https://pokemondb.net/ability/healer
      # @see https://bulbapedia.bulbagarden.net/wiki/Healer_(Ability)
      # @see https://www.pokepedia.fr/Cœur_Soin
      class Healer < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          targets = logic.adjacent_allies_of(@target)
          targets.each do |target|
            next if target.status_effect.instance_of?(Status) || bchance?(0.70, logic)
            scene.visual.show_ability(@target)
            logic.status_change_handler.status_change(:cure, target)
          end
        end
      end
      register(:healer, Healer)
      class Heatproof < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 1 unless user.can_be_lowered_or_canceled?
          return move.type == data_type(:fire).id ? 0.5 : 1
        end
      end
      register(:heatproof, Heatproof)
      class HungerSwitch < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          original_form = @target.form
          if @target.form == 0
            @target.form_calibrate(:battle)
          else
            @target.form_calibrate
          end
          unless @target.form == original_form
            @logic.scene.visual.show_switch_form_animation(@target)
            @logic.scene.visual.wait_for_animation
          end
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          who.form_calibrate if who == @target
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          target.form = 0
        end
      end
      register(:hunger_switch, HungerSwitch)
      class Hustle < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.physical? ? 1.5 : 1
        end
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if user != @target
          return move.physical? ? 0.8 : 1
        end
      end
      register(:hustle, Hustle)
      class Hydration < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target) && $env.rain?
          return if @target.dead?
          scene.visual.show_ability(@target)
          logic.status_change_handler.status_change(:cure, @target)
        end
      end
      register(:hydration, Hydration)
      class HyperCutter < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return if target == launcher || stat != :atk
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 201, target))
          end
        end
      end
      register(:hyper_cutter, HyperCutter)
      class IceBody < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target) && $env.hail?
          return if @target.hp == @target.max_hp
          return if @target.dead?
          scene.visual.show_ability(@target)
          logic.damage_handler.heal(target, target.max_hp / 16)
        end
      end
      register(:ice_body, IceBody)
      class IceFace < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target || target.effects.has?(:heal_block) || !skill&.physical?
          return unless launcher&.can_be_lowered_or_canceled?
          @original_form = @target.form
          @target.form_calibrate(:battle)
          @hail = $env.hail?
          if @target.form != @original_form
            return handler.prevent_change do
              handler.scene.visual.show_ability(target)
              handler.scene.visual.show_switch_form_animation(target)
            end
          end
        end
        def on_weather_prevention(handler, weather_type, last_weather)
          return if target != @target
          return unless weather_type == :hail && @hail == false
          @original_form = @target.form
          @target.form_calibrate
          @hail = true
          if @target.form != @original_form
            handler.prevent_change
            handler.scene.visual.show_ability(target)
            handler.scene.visual.show_switch_form_animation(target)
            super
          end
        end
        # Function called at the end of a turn
        # logic [Battle::Logic] - logic of the battle
        # scene [Battle::Scene] - battle scene
        # battlers [Array<PFM::PokemonBattler>] - all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          @hail = $env.hail?
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          target.form = 0
        end
      end
      register(:ice_face, IceFace)
      class IceScales < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 0.5 if move.special? && user.can_be_lowered_or_canceled?
          return 1
        end
      end
      register(:ice_scales, IceScales)
      class Immunity < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return if status != :poison && status != :toxic
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 252, target))
          end
        end
      end
      register(:immunity, Immunity)
      class Imposter < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          return unless (th = handler.logic.transform_handler).can_transform?(with)
          targets = handler.logic.all_alive_battlers.select { |pokemon| pokemon.bank != with.bank && pokemon.position == with.position }
          return if targets.empty?
          handler.scene.visual.show_ability(with)
          with.transform = targets.sample(random: handler.logic.generic_rng)
          handler.scene.visual.show_switch_form_animation(with)
          handler.scene.visual.wait_for_animation
          handler.scene.display_message_and_wait(parse_text_with_2pokemon(*message_id, with, with.transform))
          with.effects.add(Effects::Transform.new(handler.logic, with))
          with.type1 = data_type(:normal).id if with.transform.type1 == 0
        end
        # Return the text's CSV ids
        # @return [Array<Integer>]
        def message_id
          return 19, 644
        end
      end
      register(:imposter, Imposter)
      # Defines the Innards Out ability
      class InnardsOut < Ability
        # Create a new ability effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @hp_remains = target.hp
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill && launcher != target && launcher
          @hp_remains = target.hp
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill && launcher != target && launcher
          hp_remains = @hp_remains
          handler.scene.visual.show_ability(target)
          handler.scene.visual.show_hp_animations([launcher], [-hp_remains])
        end
      end
      register(:innards_out, InnardsOut)
      class InnerFocus < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :flinch
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
          end
        end
      end
      register(:inner_focus, InnerFocus)
      class Insomnia < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :sleep
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 318, target))
          end
        end
      end
      register(:insomnia, Insomnia)
      class Intimidate < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          alive_foes = handler.logic.foes_of(with).select(&:alive?)
          handler.scene.visual.show_ability(with) if alive_foes.any?
          alive_foes.each do |foe|
            handler.logic.stat_change_handler.stat_change_with_process(:atk, -1, foe, with)
            if foe.has_ability?(:rattled)
              handler.scene.visual.show_ability(foe)
              handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, foe, with)
            end
          end
        end
      end
      register(:intimidate, Intimidate)
      class IntrepidSword < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.scene.visual.show_ability(with)
          handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, with)
        end
      end
      register(:intrepid_sword, IntrepidSword)
      class IronFist < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return move.punching? ? 1.2 : 1
        end
      end
      register(:iron_fist, IronFist)
      class Justified < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.type_dark?
          if handler.logic.stat_change_handler.stat_increasable?(:atk, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, target)
          end
        end
      end
      register(:justified, Justified)
      class KeenEye < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return if target == launcher || stat != :acc
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 207, target))
          end
        end
      end
      register(:keen_eye, KeenEye)
      class LeafGuard < Ability
        # List of messages when leaf guard is active
        STATUS_LEAF_GUARD_MSG = {poison: 252, toxic: 252, sleep: 318, freeze: 300, paralysis: 285, burn: 270}
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          msg_id = STATUS_LEAF_GUARD_MSG[status]
          return if target != @target
          return unless msg_id && ($env.sunny? || $env.hardsun?)
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, msg_id, target))
          end
        end
      end
      register(:leaf_guard, LeafGuard)
      class Libero < Ability
        NO_ACTIVATION_MOVES = %i[s_struggle s_metronome s_me_first s_assist s_mirror_move s_nature_power s_sleep_talk]
        # Function called before the accuracy check of a move is done
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param targets [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_pre_accuracy_check(logic, scene, targets, launcher, skill)
          types = skill.definitive_types(launcher, targets.first)
          return if launcher != @target
          return if NO_ACTIVATION_MOVES.include?(skill.be_method)
          return if types.first == 0
          return unless !launcher.single_type? || !launcher.type?(types.first)
          scene.visual.show_ability(launcher)
          launcher.type1 = types.first
          launcher.type2 = 0
          launcher.type3 = 0
          text = parse_text_with_pokemon(19, 899, launcher, PFM::Text::PKNICK[0] => launcher.given_name, '[VAR TYPE(0001)]' => data_type(types.first).name)
          scene.display_message_and_wait(text)
        end
      end
      register(:libero, Libero)
      register(:protean, Libero)
      class LightningRod < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return unless move_check?(skill)
          return unless launcher != @target
          return unless (@target == target) || (skill && %i[adjacent_pokemon adjacent_foe random_foe any_other_pokemon].include?(skill.target))
          return unless launcher&.can_be_lowered_or_canceled?
          return if @logic.all_alive_battlers.any? { |battler| battler.effects.has?(:center_of_attention) }
          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.logic.stat_change_handler.stat_change_with_process(:ats, 1, @target)
          end
        end
        private
        # Check the type of the move
        # @param move [Battle::Move, nil] Potential move used
        # @return [Boolean]
        def move_check?(move)
          return move&.type_electric? || false
        end
      end
      register(:lightning_rod, LightningRod)
      class StormDrain < LightningRod
        private
        # Check the type of the move
        # @param move [Battle::Move, nil] Potential move used
        # @return [Boolean]
        def move_check?(move)
          return move&.type_water? || false
        end
      end
      register(:storm_drain, StormDrain)
      class Limber < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :paralysis
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 285, target))
          end
        end
      end
      register(:limber, Limber)
      class LiquidVoice < Ability
        # Function called when we try to get the definitive type of a move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @param type [Integer] current type of the move (potentially after effects)
        # @return [Integer, nil] new type of the move
        def on_move_type_change(user, target, move, type)
          return data_type(:water).id if move.sound_attack?
          return nil
        end
      end
      register(:liquid_voice, LiquidVoice)
      class MagmaArmor < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :freeze
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 300, target))
          end
        end
      end
      register(:magma_armor, MagmaArmor)
      class MarvelScale < Ability
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return 1 if target.status_effect.instance_of?(Status)
          return move.physical? ? 1.5 : 1
        end
      end
      register(:marvel_scale, MarvelScale)
      class MegaLauncher < Ability
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if user != @target
          return move.pulse? ? 1.5 : 1
        end
      end
      register(:mega_launcher, MegaLauncher)
      class Mimicry < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target || @logic.field_terrain == :none
          if @logic.field_terrain_effect.psychic?
            @target.change_types(data_type(:psychic).id)
          else
            if @logic.field_terrain_effect.misty?
              @target.change_types(data_type(:fairy).id)
            else
              if @logic.field_terrain_effect.grassy?
                @target.change_types(data_type(:grass).id)
              else
                if @logic.field_terrain_effect.electric?
                  @target.change_types(data_type(:electric).id)
                end
              end
            end
          end
          handler.scene.visual.show_ability(@target)
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        # @param last_fterrain [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        def on_post_fterrain_change(handler, fterrain_type, last_fterrain)
          case fterrain_type
          when :none
            @target.restore_types
          when :psychic_terrain
            @target.change_types(data_type(:psychic).id)
          when :misty_terrain
            @target.change_types(data_type(:fairy).id)
          when :grassy_terrain
            @target.change_types(data_type(:grass).id)
          when :electric_terrain
            @target.change_types(data_type(:electric).id)
          else
            return
          end
          handler.scene.visual.show_ability(@target)
        end
      end
      register(:mimicry, Mimicry)
      class MirrorArmor < Ability
        # Function called when a stat_change is about to be applied
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param power [Integer] power of the stat change
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Integer, nil] if integer, it will change the power
        def on_stat_change(handler, stat, power, target, launcher, skill)
          return unless target == @target
          return if launcher == @target && skill&.original_target.empty?
          return unless launcher&.can_be_lowered_or_canceled?
          return if power >= 0
          handler.scene.visual.show_ability(target)
          handler.scene.visual.wait_for_animation
          battlers_affected = skill&.original_target.empty? ? [launcher] : skill.original_target
          battlers_affected.each do |battler|
            next unless battler.can_fight?
            handler.logic.stat_change_handler.stat_change_with_process(stat, power, battler)
          end
          skill.original_target.clear if skill&.original_target
          return 0
        end
      end
      register(:mirror_armor, MirrorArmor)
      class MoldBreaker < Ability
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != @target
          user.ability_used = false
        end
      end
      register(:mold_breaker, MoldBreaker)
      class Moody < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          stats = Battle::Logic::StatChangeHandler::ALL_STATS
          stat_up = stats.select do |stat|
            logic.stat_change_handler.stat_increasable?(stat, @target)
          end.sample(random: logic.generic_rng)
          stat_down = stats.select do |stat|
            stat != stat_up && logic.stat_change_handler.stat_decreasable?(stat, @target)
          end.sample(random: logic.generic_rng)
          return unless stat_up || stat_down
          scene.visual.show_ability(@target)
          logic.stat_change_handler.stat_change_with_process(stat_up, 2, @target) if stat_up
          logic.stat_change_handler.stat_change_with_process(stat_down, -1, @target) if stat_down
        end
      end
      register(:moody, Moody)
      class MotorDrive < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill&.type_electric?
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
          end
        end
      end
      register(:motor_drive, MotorDrive)
      class Moxie < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if launcher == target
          return unless skill && skill&.be_method != :s_fell_stinger
          return unless launcher == @target
          return unless @target.hp > 0
          if handler.logic.stat_change_handler.stat_increasable?(:atk, @target)
            handler.scene.visual.show_ability(@target)
            handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, @target)
          end
        end
      end
      register(:moxie, Moxie)
      class Multiscale < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 0.5 if target.hp == target.max_hp && user.can_be_lowered_or_canceled?
          return 1
        end
      end
      register(:multiscale, Multiscale)
      register(:shadow_shield, Multiscale)
      class Mummy < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          return if launcher.ability_effect == :mummy
          return unless handler.logic.ability_change_handler.can_change_ability?(launcher, db_symbol)
          handler.scene.visual.show_ability(target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 405, launcher, PFM::Text::ABILITY[1] => target.ability_name))
          handler.logic.ability_change_handler.change_ability(launcher, db_symbol)
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          on_post_damage(handler, hp, target, launcher, skill)
        end
      end
      register(:mummy, Mummy)
      class NaturalCure < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if who != @target || who == with || who.status_effect.instance_of?(Status)
          who.cure
        end
      end
      register(:natural_cure, NaturalCure)
      class Neuroforce < Ability
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if user != @target
          return move.super_effective? ? 1.25 : 1
        end
      end
      register(:neuroforce, Neuroforce)
      class NeutralizingGas < Ability
        # Create a new Neutralizing Gas effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @activated = false
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          if who != with && who == @target && @activated
            handler.scene.display_message_and_wait(parse_text(60, 408))
            retrieve_abilities(handler, who, with)
            @activated = false
          end
          suppress_abilities(handler, who, with)
          if with == @target
            handler.scene.visual.show_ability(@target)
            handler.scene.visual.wait_for_animation
            handler.scene.display_message_and_wait(parse_text(60, 407))
            @activated = true
          end
        end
        # If Neutralizing Gas is currently activated by this pokemon
        # @return [Boolean]
        def activated?
          return @activated
        end
        alias activated activated?
        private
        # Suppress the ability of each battlers except the user if the conditions are fullfilled
        # @param handler [Battle::Logic::SwitchHandler]
        def suppress_abilities(handler, who, with)
          battlers = handler.logic.all_alive_battlers.reject { |battler| battler == @target }
          battlers.each do |battler|
            next if battler.effects.has?(:ability_suppressed) || battler.has_ability?(:neutralizing_gas)
            next unless handler.logic.ability_change_handler.can_change_ability?(battler, :none)
            battler.effects.add(Effects::AbilitySuppressed.new(@logic, battler))
          end
        end
        # Retrieve the ability of each battlers except the user if the conditions are fullfilled
        # @param handler [Battle::Logic::SwitchHandler]
        def retrieve_abilities(handler, who, with)
          battlers = handler.logic.all_alive_battlers.reject { |battler| battler == @target || battler == with }
          return if battlers.any? { |battler| battler.has_ability?(:neutralizing_gas) }
          battlers.each do |battler|
            next unless battler.effects.has?(:ability_suppressed)
            battler.effects.get(:ability_suppressed).kill
            battler.effects.delete_specific_dead_effect(:ability_suppressed)
            battler.ability_effect.on_switch_event(handler, battler, battler)
          end
        end
      end
      register(:neutralizing_gas, NeutralizingGas)
      class Normalize < Ability
        # Function called when we try to get the definitive type of a move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @param type [Integer] current type of the move (potentially after effects)
        # @return [Integer, nil] new type of the move
        def on_move_type_change(user, target, move, type)
          return if user != @target
          return if move.be_method == :s_weather_ball
          return data_type(:normal).id
        end
      end
      register(:normalize, Normalize)
      # A Pokémon with Overcoat does not take damage from the weather conditions sandstorm and hailstorm.
      # Also protects from powder and spore moves, as well as Effect Spore.
      # @see https://pokemondb.net/ability/overcoat
      # @see https://bulbapedia.bulbagarden.net/wiki/Overcoat_(Ability)
      # @see https://www.pokepedia.fr/Envelocape
      class Overcoat < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Boolean] if the target is immune to the move
        def on_move_ability_immunity(user, target, move)
          return false if target != @target
          return @logic.scene.visual.show_ability(target) && true if move.powder? && user.can_be_lowered_or_canceled?
          return false
        end
      end
      register(:overcoat, Overcoat)
      class OwnTempo < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :confusion
          return if launcher && !launcher.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 357, target))
          end
        end
      end
      register(:own_tempo, OwnTempo)
      class ParentalBond < Ability
        # Constant telling the be_method of the moves not affected by Parental Bond
        # @return [Array<Symbol>]
        ONLY_ONE_ATTACK = %i[s_solar_beam s_2turns s_endeavor s_ohko s_fling s_explosion s_final_gambit s_uproar s_rollout s_ice_ball s_relic_sound]
        # Constant telling which be_method can activate their effect on the second attack only
        # @return [Array<Symbol>]
        ONLY_ON_SECOND_ATTACK = %i[s_secret_power s_u_turn s_thief s_pluck s_smelling_salt s_wakeup_slap s_knock_off s_scald s_smack_down s_burn_up s_bind s_fury_cutter s_split_up s_reload s_outrage s_present s_pledge]
        # If the talent is activated or not
        # @return [Boolean]
        attr_writer :activated
        # Returns the amount of damage the launcher must take from the recoil
        # @return [Integer]
        attr_accessor :first_turn_recoil
        # Which attack number are we currently on this turn?
        # @return [Integer]
        attr_accessor :attack_number
        # Create a new Parental Bond effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @activated = false
          @first_turn_recoil = 0
          @attack_number = 0
        end
        def activated?
          return @activated
        end
        alias activated activated?
        # Return the specific proceed_internal if the condition is fulfilled
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        def specific_proceed_internal(user, targets, move)
          return :proceed_internal_parental_bond unless excluded?(move.be_method)
        end
        # Get the name of the effect
        # @return [Symbol]
        def name
          return :parental_bond
        end
        # Returns the number of attack this Ability causes
        # @return [Integer]
        def number_of_attacks
          return 2
        end
        # Check if the actual move can activate its have his effect activated
        # @return [Boolean]
        def first_effect_can_be_applied?(be_method)
          return ONLY_ON_SECOND_ATTACK.none?(be_method)
        end
        # Check if the actual move need the initial procedure (Parental Bond not working on it)
        # @return [Boolean]
        def excluded?(be_method)
          return ONLY_ONE_ATTACK.any?(be_method)
        end
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 0.50 if activated?
          return 1
        end
      end
      register(:parental_bond, ParentalBond)
      class PastelVeil < Ability
        # Poison status
        POISON = %i[poison toxic]
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target.bank != @target.bank
          return unless POISON.include?(status)
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 252, @target))
          end
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target || who == with
          targets = @logic.adjacent_allies_of((@target))
          targets.each do |target|
            next if !target.status_effect.poison? && !target.status_effect.toxic?
            @logic.scene.visual.show_ability(@target)
            @logic.status_change_handler.status_change(:cure, target)
            @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 246, @target))
          end
        end
      end
      register(:pastel_veil, PastelVeil)
      class PerishBody < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && !launcher.has_ability?(:long_reach)
          return if target.effects.has?(:perish_song) || launcher.effects.has?(:perish_song)
          target.effects.add(effect(target))
          handler.scene.visual.show_ability(target)
          @logic.scene.display_message_and_wait(parse_text(18, 125))
          launcher.effects.add(effect(launcher))
        end
        # Return the effect of the ability
        # @param target [PFM::PokemonBattler] target that will be affected by the effect
        # @return [Effects::EffectBase]
        def effect(target)
          Effects::PerishSong.new(@logic, target, 4)
        end
      end
      register(:perish_body, PerishBody)
      class Pickpocket < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target || !%i[none __undef__].include?(target.item_db_symbol)
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          return unless handler.logic.item_change_handler.can_lose_item?(launcher, target)
          return if launcher.has_ability?(:sheer_force) && launcher.ability_effect&.activated?
          handler.scene.visual.show_ability(target)
          text = parse_text_with_pokemon(*steal_text, launcher, PFM::Text::PKNICK[0] => launcher.given_name, PFM::Text::ITEM2[1] => launcher.item_name)
          handler.scene.display_message_and_wait(text)
          target.effects.get(:item_stolen).kill if target.effects.has?(:item_stolen)
          if $game_temp.trainer_battle
            @logic.item_change_handler.change_item(launcher.item_db_symbol, false, target, launcher, self)
            if launcher.from_party? && !launcher.effects.has?(:item_stolen)
              launcher.effects.add(Effects::ItemStolen.new(@logic, launcher))
            else
              @logic.item_change_handler.change_item(:none, true, launcher, launcher, self)
            end
          else
            overwrite = target.from_party? && !launcher.from_party?
            @logic.item_change_handler.change_item(launcher.item_db_symbol, overwrite, target, launcher, self)
            @logic.item_change_handler.change_item(:none, false, launcher, launcher, self)
          end
        end
        # Function returning the file number and the line id of the text
        # @return [Array<Integer>]
        def steal_text
          return 19, 460
        end
      end
      register(:pickpocket, Pickpocket)
      class Magician < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher == target || !%i[none __undef__].include?(launcher.item_db_symbol)
          return unless launcher && launcher.hp > 0
          return unless handler.logic.item_change_handler.can_lose_item?(target, launcher)
          return if skill&.recoil? && (hp / skill.recoil_factor >= launcher.hp)
          return if skill&.direct? && (target.battle_item_db_symbol == :sticky_barb || (target.battle_item_db_symbol == :rocky_helmet && (launcher.max_hp / 6 >= launcher.hp)))
          handler.scene.visual.show_ability(launcher)
          text = parse_text_with_pokemon(*steal_text, launcher, '[VAR 1400(0002)]' => nil.to_s, '[VAR ITEM2(0002)]' => target.item_name, '[VAR PKNICK(0001)]' => target.given_name)
          handler.scene.display_message_and_wait(text)
          launcher.effects.get(:item_stolen).kill if launcher.effects.has?(:item_stolen)
          if $game_temp.trainer_battle
            @logic.item_change_handler.change_item(target.item_db_symbol, false, launcher, launcher, self)
            if target.from_party? && !target.effects.has?(:item_stolen)
              target.effects.add(Effects::ItemStolen.new(@logic, target))
            else
              @logic.item_change_handler.change_item(:none, true, target, launcher, self)
            end
          else
            overwrite = launcher.from_party? && !target.from_party?
            @logic.item_change_handler.change_item(target.item_db_symbol, overwrite, launcher, launcher, self)
            @logic.item_change_handler.change_item(:none, false, target, launcher, self)
          end
        end
        # Function returning the file number and the line id of the text
        # @return [Array<Integer>]
        def steal_text
          return 19, 1063
        end
      end
      register(:magician, Magician)
      class Plus < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return 1 unless move.logic.allies_of(user).any? { |ally| ally.ability_effect.is_a?(Plus) }
          return move.special? ? 1.5 : 1
        end
      end
      register(:plus, Plus)
      register(:minus, Plus)
      class PoisonPoint < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && launcher.can_be_poisoned? && bchance?(0.3, @logic) && !launcher.has_ability?(:long_reach)
          handler.scene.visual.show_ability(target)
          handler.logic.status_change_handler.status_change_with_process(:poison, launcher, target)
        end
      end
      register(:poison_point, PoisonPoint)
      class PoisonTouch < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher == target
          return unless skill&.direct? && launcher.hp > 0 && target.can_be_poisoned? && bchance?(0.3, @logic)
          handler.scene.visual.show_ability(launcher)
          handler.logic.status_change_handler.status_change_with_process(:poison, target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 472, target))
        end
      end
      register(:poison_touch, PoisonTouch)
      class PowerConstruct < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead? || @target.form == 3 || @target.hp_rate >= 0.5
          max_hp_pre_construct = @target.max_hp
          @target.form_calibrate(:battle)
          scene.visual.show_ability(@target)
          scene.visual.show_switch_form_animation(@target)
          scene.display_message_and_wait(parse_text(60, 362))
          @target.hp += @target.max_hp - max_hp_pre_construct
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          @target.form_calibrate(:base)
        end
      end
      register(:power_construct, PowerConstruct)
      class PowerOfAlchemy < Ability
        # Create a new PowerOfAlchemy effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          user = @target
          return if target == user
          return unless @logic.ability_change_handler.can_change_ability?(user, target.ability_db_symbol)
          @logic.ability_change_handler.change_ability(user, target.ability_db_symbol)
          handler.scene.visual.show_ability(user)
          handler.scene.display_message_and_wait(parse_text(5, 222))
        end
      end
      register(:power_of_alchemy, PowerOfAlchemy)
      register(:receiver, PowerOfAlchemy)
      class PowerSpot < Ability
        # Create a new PowerSpot effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user.bank != self.target.bank
          return 1.2
        end
      end
      register(:power_spot, PowerSpot)
      class Prankster < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param priority [Integer]
        # @param move [Battle::Move]
        # @return [Proc, nil]
        def on_move_priority_change(user, priority, move)
          return nil if user != @target
          return nil unless move.status?
          return priority + 1
        end
      end
      register(:prankster, Prankster)
      class Pressure < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 487, with))
        end
      end
      register(:pressure, Pressure)
      class DesolateLand < Ability
        # Liste des temps qui peuvent changer
        WEATHERS = %i[hardsun hardrain strong_winds]
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          if with == @target
            weather_handler = handler.logic.weather_change_handler
            return unless weather_handler.weather_appliable?(env)
            handler.scene.visual.show_ability(with)
            weather_handler.weather_change(env, nil)
            handler.scene.visual.show_rmxp_animation(with, anim)
          else
            if who == @target
              return unless $env.current_weather_db_symbol == env
              return if handler.logic.all_alive_battlers.any? { |battler| primal_weather_ability?(battler) && battler != @target }
              handler.logic.weather_change_handler.weather_change(:none, 0)
              handler.scene.display_message_and_wait(parse_text(18, msg))
            end
          end
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target
          return unless $env.hardsun?
          return if handler.logic.all_alive_battlers.any? { |battler| primal_weather_ability?(battler) && battler != @target }
          handler.logic.weather_change_handler.weather_change(:none, 0)
          handler.scene.display_message_and_wait(parse_text(18, msg))
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        def on_post_weather_change(handler, weather_type, last_weather)
          return if WEATHERS.include?($env.current_weather_db_symbol)
          handler.scene.visual.show_ability(@target)
          handler.logic.weather_change_handler.weather_change(env, nil)
          handler.scene.visual.show_rmxp_animation(@target, anim)
        end
        private
        # Weather concerned
        # @return [Symbol] weather symbol
        def env
          return :hardsun
        end
        # Weather setting ability
        # @return [Symbol] ability db_symbol
        def primal_weather_ability?(pokemon)
          return pokemon.ability_db_symbol == :desolate_land
        end
        # Weather setup animation id
        # @return [Integer] id
        def anim
          return 492
        end
        # Weather clear text line
        # @return [Integer] id
        def msg
          return 272
        end
      end
      register(:desolate_land, DesolateLand)
      class PrimordialSea < DesolateLand
        private
        # Weather concerned
        # @return [db_symbol] weather
        def env
          return :hardrain
        end
        # Weather setting ability
        # @return [Symbol] ability db_symbol
        def primal_weather_ability?(pokemon)
          return pokemon.ability_db_symbol == :primordial_sea
        end
        # Weather setup animation id
        # @return [Integer] id
        def anim
          return 493
        end
        # Weather clear text line
        # @return [Integer] id
        def msg
          return 270
        end
      end
      register(:primordial_sea, PrimordialSea)
      class DeltaStream < DesolateLand
        private
        # Weather concerned
        # @return [db_symbol] weather
        def env
          return :strong_winds
        end
        # Weather setting ability
        # @return [Symbol] ability db_symbol
        def primal_weather_ability?(pokemon)
          return pokemon.ability_db_symbol == :delta_stream
        end
        # Weather setup animation id
        # @return [Integer] id
        def anim
          return 566
        end
        # Weather clear text line
        # @return [Integer] id
        def msg
          return 274
        end
      end
      register(:delta_stream, DeltaStream)
      class Protosynthesis < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @highest_stat = nil
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          return play_ability_effect(handler, with, :env) if %i[sunny hardsun].include?($env.current_weather_db_symbol)
          return play_ability_effect(handler, with, :item) if with.hold_item?(:booster_energy)
        end
        # Function called after the weather was changed (on_post_weather_change)
        # @param handler [Battle::Logic::WeatherChangeHandler]
        # @param weather_type [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        # @param last_weather [Symbol] :none, :rain, :sunny, :sandstorm, :hail, :fog
        def on_post_weather_change(handler, weather_type, last_weather)
          @highest_stat = nil if %i[sunny hardsun].include?(last_weather)
          return play_ability_effect(handler, @target, :env) if %i[sunny hardsun].include?(weather_type)
          play_ability_effect(handler, with, :item) if @target.hold_item?(:booster_energy)
        end
        # Give the atk modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def atk_modifier
          return super unless @highest_stat == :atk
          return 1.3
        end
        # Give the dfe modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfe_modifier
          return super unless @highest_stat == :dfe
          return 1.3
        end
        # Give the ats modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def ats_modifier
          return super unless @highest_stat == :ats
          return 1.3
        end
        # Give the dfs modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfs_modifier
          return super unless @highest_stat == :dfs
          return 1.3
        end
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return super unless @highest_stat == :spd
          return 1.5
        end
        private
        # Plays pokemon ability effect
        # @param handler [Battle::Logic::SwitchHandler]
        # @param pokemon [PFM::PokemonBattler]
        # @param reason [Symbol] the reason of the proc
        def play_ability_effect(handler, pokemon, reason)
          case reason
          when :env
            handler.scene.visual.show_ability(pokemon)
            handler.scene.visual.wait_for_animation
          when :item
            handler.scene.visual.show_item(pokemon)
            handler.scene.visual.wait_for_animation
            handler.logic.item_change_handler.change_item(:none, true, pokemon)
          end
          @highest_stat = highest_stat_boosted
        end
        # Function called to increase the pokémon's highest stat
        def highest_stat_boosted
          stats = {atk: @target.atk, dfe: @target.dfe, ats: @target.ats, dfs: @target.dfs, spd: @target.spd}
          highest_value = stats.values.max
          highest_stat_key = stats.key(highest_value)
          return highest_stat_key.to_sym
        end
      end
      register(:protosynthesis, Protosynthesis)
      class PunkRock < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          if user == self.target
            return move.sound_attack? ? 1.3 : 1
          else
            if target == self.target && user.can_be_lowered_or_canceled?
              return move.sound_attack? ? 0.5 : 1
            end
          end
          return 1
        end
      end
      register(:punk_rock, PunkRock)
      class PurePower < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.physical? ? 2 : 1
        end
      end
      register(:pure_power, PurePower)
      register(:huge_power, PurePower)
      class QuarkDrive < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @highest_stat = nil
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          return play_ability_effect(handler, with, :env) if handler.logic.field_terrain_effect.electric?
          return play_ability_effect(handler, with, :item) if with.hold_item?(:booster_energy)
        end
        # Function called after the terrain was changed
        # @param handler [Battle::Logic::FTerrainChangeHandler]
        # @param fterrain_type [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        # @param last_fterrain [Symbol] :none, :electric_terrain, :grassy_terrain, :misty_terrain, :psychic_terrain
        def on_post_fterrain_change(handler, fterrain_type, last_fterrain)
          @highest_stat = nil if last_fterrain == :electric_terrain
          return play_ability_effect(handler, @target, :env) if fterrain_type == :electric_terrain
          play_ability_effect(handler, with, :item) if @target.hold_item?(:booster_energy)
        end
        # Give the atk modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def atk_modifier
          return super unless @highest_stat == :atk
          return 1.3
        end
        # Give the dfe modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfe_modifier
          return super unless @highest_stat == :dfe
          return 1.3
        end
        # Give the ats modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def ats_modifier
          return super unless @highest_stat == :ats
          return 1.3
        end
        # Give the dfs modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def dfs_modifier
          return super unless @highest_stat == :dfs
          return 1.3
        end
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return super unless @highest_stat == :spd
          return 1.5
        end
        private
        # Plays pokemon ability effect
        # @param handler [Battle::Logic::SwitchHandler]
        # @param pokemon [PFM::PokemonBattler]
        # @param reason [Symbol] the reason of the proc
        def play_ability_effect(handler, pokemon, reason)
          case reason
          when :env
            handler.scene.visual.show_ability(pokemon)
            handler.scene.visual.wait_for_animation
          when :item
            handler.scene.visual.show_item(pokemon)
            handler.scene.visual.wait_for_animation
            handler.logic.item_change_handler.change_item(:none, true, pokemon)
          end
          @highest_stat = highest_stat_boosted
        end
        # Function called to increase the pokemon's highest stat
        def highest_stat_boosted
          stats = {atk: @target.atk, dfe: @target.dfe, ats: @target.ats, dfs: @target.dfs, spd: @target.spd}
          highest_value = stats.values.max
          highest_stat_key = stats.key(highest_value)
          return highest_stat_key.to_sym
        end
      end
      register(:quark_drive, QuarkDrive)
      class QueenlyMajesty < Ability
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if target.bank != @target.bank
          return false unless move.relative_priority >= 1 && move.blocable?
          return false unless user.can_be_lowered_or_canceled?
          move.scene.visual.show_ability(@target)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 911, user, '[VAR MOVE(0001)]' => move.name))
          return true
        end
      end
      register(:queenly_majesty, QueenlyMajesty)
      register(:dazzling, QueenlyMajesty)
      class QuickFeet < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return 1.5 if @target.status?
          return 1
        end
      end
      register(:quick_feet, QuickFeet)
      class RainDish < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target) && ($env.rain? || $env.hardrain?)
          return if @target.hp == @target.max_hp
          return if @target.dead?
          scene.visual.show_ability(@target)
          logic.damage_handler.heal(target, target.max_hp / 16)
        end
      end
      register(:rain_dish, RainDish)
      class Rattled < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless launcher && skill
          return unless skill.type_ghost? || skill.type_dark? || skill.type_bug?
          return if target.effects.has?(:substitute) && !skill.authentic?
          handler.scene.visual.show_ability(target)
          handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
        end
      end
      register(:rattled, Rattled)
      class Reckless < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return move.recoil? ? 1.2 : 1
        end
      end
      register(:reckless, Reckless)
      class Regenerator < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if who != @target || who == with || who.hp == who.max_hp || who.dead?
          who.hp += who.max_hp / 3
        end
      end
      register(:regenerator, Regenerator)
      class Ripen < Ability
        # Function called when a pre_item_change is checked
        # @param handler [Battle::Logic::ItemChangeHandler]
        # @param db_symbol [Symbol] Symbol ID of the item
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_pre_item_change(handler, db_symbol, target, launcher, skill)
          return unless target.hold_berry?(target.battle_item_db_symbol)
          return if target.effects.has?(:item_burnt) || target.effects.has?(:item_stolen)
          handler.scene.visual.show_ability(target)
        end
      end
      register(:ripen, Ripen)
      class Rivalry < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return 1 if (user.gender * target.gender) == 0
          return 1.25 if user.gender == target.gender
          return 0.75
        end
      end
      register(:rivalry, Rivalry)
      class RoughSkin < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          damages = (launcher.max_hp >= 8 ? launcher.max_hp / 8 : 1).clamp(1, Float::INFINITY)
          handler.scene.visual.show_ability(target)
          handler.scene.visual.show_hp_animations([launcher], [-damages])
          text = parse_text_with_pokemon(19, 430, launcher, PFM::Text::PKNICK[0] => launcher.given_name)
          handler.scene.display_message_and_wait(text)
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          damages = (launcher.max_hp >= 8 ? launcher.max_hp / 8 : 1).clamp(1, Float::INFINITY)
          handler.scene.visual.show_ability(target)
          handler.scene.visual.show_hp_animations([launcher], [-damages])
          text = parse_text_with_pokemon(19, 430, launcher, PFM::Text::PKNICK[0] => launcher.given_name)
          handler.scene.display_message_and_wait(text)
        end
      end
      register(:rough_skin, RoughSkin)
      register(:iron_barbs, RoughSkin)
      class SandForce < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return 1 unless $env.sandstorm?
          return 1.3 if move.type_steel? || move.type_rock? || move.type_ground?
          return 1
        end
      end
      register(:sand_force, SandForce)
      class SandRush < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return $env.sandstorm? ? 2 : 1
        end
      end
      register(:sand_rush, SandRush)
      class SandSpit < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill
          weather_handler = handler.logic.weather_change_handler
          return unless weather_handler.weather_appliable?(:sandstorm)
          nb_turn = target.hold_item?(:smooth_rock) ? 8 : 5
          weather_handler.weather_change(:sandstorm, nb_turn)
          handler.scene.visual.show_ability(target)
          handler.scene.visual.show_rmxp_animation(target, 494)
        end
      end
      register(:sand_spit, SandSpit)
      class SandVeil < Ability
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return $env.sandstorm? ? 0.8 : 1
        end
      end
      register(:sand_veil, SandVeil)
      class SapSipper < Ability
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if target != @target
          return false unless move.type_grass? && move.db_symbol != :aromatherapy
          return false unless user.can_be_lowered_or_canceled?
          move.scene.visual.show_ability(target)
          move.logic.stat_change_handler.stat_change_with_process(:atk, 1, target, user, move)
          return true
        end
      end
      register(:sap_sipper, SapSipper)
      class Scrappy < Ability
        # Function called when we try to get the definitive type of a move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @param type [Integer] current type of the move (potentially after effects)
        # @return [Integer, nil] new type of the move
        def on_move_type_change(user, target, move, type)
          return if user != @target
          return unless target.type_ghost?
          return move.type_normal? || move.type_fighting? ? 0 : nil
        end
      end
      register(:scrappy, Scrappy)
      class ScreenCleaner < Ability
        WALLS = %i[light_screen reflect aurora_veil]
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target || who == with
          bank_foes = handler.logic.adjacent_foes_of(@target).map(&:bank).first
          suppr_reflect(bank_foes)
          bank_allies = handler.logic.adjacent_allies_of(@target).map(&:bank).first
          suppr_reflect(bank_allies)
          handler.scene.visual.show_ability(@target) if bank_foes || bank_allies
        end
        # Function called to suppr the reflect effect
        # @param bank [Integer] bank of the battlers
        def suppr_reflect(bank)
          return false unless bank
          @logic.bank_effects[bank].each do |effect|
            next unless WALLS.include?(effect.name)
            case effect.name
            when :reflect
              @logic.scene.display_message_and_wait(parse_text(18, bank == 0 ? 132 : 133))
            when :light_screen
              @logic.scene.display_message_and_wait(parse_text(18, bank == 0 ? 136 : 137))
            else
              @logic.scene.display_message_and_wait(parse_text(18, bank == 0 ? 140 : 141))
            end
            log_info("PSDK Screen Cleaner: #{effect.name} effect removed.")
            effect.kill
          end
        end
      end
      register(:screen_cleaner, ScreenCleaner)
      class SereneGrace < Ability
        # Give the effect chance modifier given to the Pokémon with this effect
        # @param move [Battle::Move::Basic] the move the chance modifier will be applied to
        # @return [Float, Integer] multiplier
        def effect_chance_modifier(move)
          return 2
        end
      end
      register(:serene_grace, SereneGrace)
      class ShedSkin < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          return if @target.status_effect.instance_of?(Status) || bchance?(0.66, logic)
          scene.visual.show_ability(@target)
          logic.status_change_handler.status_change(:cure, @target)
        end
      end
      register(:shed_skin, ShedSkin)
      class SheerForce < Ability
        # If the talent is activated or not
        # @return [Boolean]
        attr_writer :activated
        # Create a new PowerSpot effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @activated = false
        end
        # List of the db_symbol of the moves for which their effect is not disabled by Sheer Force
        # @return [Array<Symbol>]
        EXCLUDED_DB_SYMBOLS = %i[thousand_waves fling scale_shot]
        # Return the constant listing the db_symbol of the moves for which their effect are not disabled by Sheer Force
        # @return [Array<Symbol>]
        def excluded_db_symbol
          return EXCLUDED_DB_SYMBOLS
        end
        # List of the be_method of the moves for which their effect is not disabled by Sheer Force
        # @return [Array<Symbol>]
        EXCLUDED_METHODS = %i[s_bind s_reload]
        # Return the constant listing the be_method of the moves for which their effect is not disabled by Sheer Force
        # @return [Array<Symbol>]
        def excluded_methods
          return EXCLUDED_METHODS
        end
        # If Sheer Force is currently activated
        # @return [Boolean]
        def activated?
          return @activated
        end
        alias activated activated?
        # Return the specific proceed_internal if the condition is fulfilled
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        def specific_proceed_internal(user, targets, move)
          return :proceed_internal_sheer_force unless excluded?(move)
        end
        # Get the name of the effect
        # @return [Symbol]
        def name
          return :sheer_force
        end
        # Check if a move must have his effect ignored
        # @param move [Battle::Move]
        # @return [Boolean]
        def excluded?(move)
          return false if EXCLUDED_DB_SYMBOLS.include?(move.db_symbol) || EXCLUDED_METHODS.include?(move.be_method)
          return true if move.status? || (move.battle_stage_mod.none? && move.status_effects.none? && move.method('deal_effect').owner == Battle::Move)
          return false
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          if target != @target && skill && @activated
            return if EXCLUDED_DB_SYMBOLS.include?(skill.db_symbol) || EXCLUDED_METHODS.include?(skill.be_method)
            return handler.prevent_change
          end
          return nil
        end
        # Function called when a stat_increase_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat increase cannot apply
        def on_stat_increase_prevention(handler, stat, target, launcher, skill)
          if target == @target && skill && @activated
            return if EXCLUDED_DB_SYMBOLS.include?(skill.db_symbol) || EXCLUDED_METHODS.include?(skill.be_method)
            return handler.prevent_change
          end
          return nil
        end
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          if target != @target && skill && @activated
            return if EXCLUDED_DB_SYMBOLS.include?(skill.db_symbol) || EXCLUDED_METHODS.include?(skill.be_method)
            return handler.prevent_change
          end
          return nil
        end
        # Give the move base power mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def base_power_multiplier(user, target, move)
          return 1 unless @activated
          return 1.3
        end
      end
      register(:sheer_force, SheerForce)
      class Simple < Ability
        # Function called when a stat_change is about to be applied
        # @param handler [Battle::Logic::StatChangeHandler]
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param power [Integer] power of the stat change
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Integer, nil] if integer, it will change the power
        def on_stat_change(handler, stat, power, target, launcher, skill)
          return if target != @target
          if !launcher || launcher.can_be_lowered_or_canceled?
            handler.scene.visual.show_ability(target)
            return power * 2
          end
          return nil
        end
      end
      register(:simple, Simple)
      class SlowStart < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != self.target || move.special? || user.turn_count >= 5
          return 0.5
        end
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return target.turn_count < 5 ? 1.5 : 1
        end
      end
      register(:slow_start, SlowStart)
      class SlushRush < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return $env.hail? ? 2 : 1
        end
      end
      register(:slush_rush, SlushRush)
      class SnowCloak < Ability
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return $env.hail? ? 0.8 : 1
        end
      end
      register(:snow_cloak, SnowCloak)
      class SolarPower < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.special? && $env.sunny? ? 1.5 : 1
        end
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target) && ($env.sunny? || $env.hardsun?)
          return if @target.dead?
          scene.visual.show_ability(@target)
          logic.damage_handler.damage_change((@target.max_hp / 8).clamp(1, Float::INFINITY), @target)
        end
      end
      register(:solar_power, SolarPower)
      class SoulHeart < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called after damages were applied and when target died (post_damage_death)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage_death(handler, hp, target, launcher, skill)
          return if target.bank != @target.bank || launcher == target || target == @target
          if handler.logic.stat_change_handler.stat_increasable?(:ats, @target)
            handler.scene.visual.show_ability(@target)
            handler.logic.stat_change_handler.stat_change_with_process(:ats, 1, @target)
          end
        end
      end
      register(:"soul_heart", SoulHeart)
      class Soundproof < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Boolean] if the target is immune to the move
        def on_move_ability_immunity(user, target, move)
          return false if target != @target
          return @logic.scene.visual.show_ability(target) && true if move.sound_attack? && user.can_be_lowered_or_canceled?
          return false
        end
      end
      register(:soundproof, Soundproof)
      class SpeedBoost < Ability
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          return if @target.switching? && !@switch_by_ko
          @switch_by_ko = false
          if logic.stat_change_handler.stat_increasable?(:spd, @target)
            scene.visual.show_ability(@target)
            logic.stat_change_handler.stat_change_with_process(:spd, 1, @target)
          end
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return unless with == @target
          return unless who.dead?
          return @switch_by_ko = true unless @logic.actions.empty?
        end
      end
      register(:speed_boost, SpeedBoost)
      class Stakeout < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return 1 if @target.turn_count < 1
          return target.switching? ? 2 : 1
        end
      end
      register(:stakeout, Stakeout)
      class Stalwart < Ability
        # Check if the user of this ability ignore the center of attention in the enemy bank
        # @return [Boolean]
        def ignore_target_redirection?
          return true
        end
      end
      register(:stalwart, Stalwart)
      register(:propeller_tail, Stalwart)
      class Stamina < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill
          if handler.logic.stat_change_handler.stat_increasable?(:dfe, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:dfe, 1, target)
          end
        end
      end
      register(:stamina, Stamina)
      # Stance Change allows Aegislash to switch between its Shield Forme and Blade Forme.
      # @see https://pokemondb.net/ability/stance-change
      # @see https://bulbapedia.bulbagarden.net/wiki/Stance_Change_(Ability)
      # @see https://www.pokepedia.fr/Déclic_Tactique
      class StanceChange < Ability
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != @target
          blade if move.real_base_power(user, targets.first) > 0
          shield if move.db_symbol == :king_s_shield
        end
        private
        # Apply Blade Forme        
        def blade
          original_form = @target.form
          @target.form_calibrate(:blade)
          apply_change_form(252) unless @target.form == original_form
        end
        # Apply Shield Forme        
        def shield
          original_form = @target.form
          @target.form_calibrate
          apply_change_form(253) unless @target.form == original_form
        end
        # Apply change form        
        # @param text_id [Integer] id of the message text
        def apply_change_form(text_id)
          @logic.scene.visual.show_ability(@target)
          @logic.scene.visual.show_switch_form_animation(@target)
          @logic.scene.visual.wait_for_animation
          @logic.scene.display_message_and_wait(parse_text(18, text_id))
        end
      end
      register(:stance_change, StanceChange)
      class Static < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && launcher.can_be_paralyzed? && bchance?(0.3, @logic) && !launcher.has_ability?(:long_reach)
          handler.scene.visual.show_ability(target)
          handler.logic.status_change_handler.status_change_with_process(:paralysis, launcher, target)
        end
      end
      register(:static, Static)
      class Steadfast < Ability
        # Function called when a post_status_change is performed
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_status_change(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :flinch
          handler.scene.visual.show_ability(target)
          handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
        end
      end
      register(:steadfast, Steadfast)
      class SteamEngine < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.type_water? || skill&.type_fire?
          if handler.logic.stat_change_handler.stat_increasable?(:spd, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:spd, 3, target)
          end
        end
      end
      register(:steam_engine, SteamEngine)
      class SteelySpirit < Ability
        # Create a new SteelySpirit effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user.bank != self.target.bank
          return 1 unless move.type_steel?
          return 1.5
        end
      end
      register(:steely_spirit, SteelySpirit)
      class Stench < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if launcher != @target || launcher.hold_item?(:king_s_rock) || launcher.hold_item?(:razor_fang)
          return unless skill && launcher.hp > 0 && bchance?(0.1, @logic)
          handler.scene.visual.show_ability(launcher)
          handler.logic.status_change_handler.status_change_with_process(:flinch, target, launcher, skill)
        end
      end
      register(:stench, Stench)
      class StrongJaw < Ability
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if user != @target
          return move.bite? ? 1.5 : 1
        end
      end
      register(:strong_jaw, StrongJaw)
      class Sturdy < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target || hp < target.hp || target.hp != target.max_hp || target == launcher
          return unless launcher&.can_be_lowered_or_canceled?
          @show_message = true
          return target.hp - 1
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return unless @show_message
          @show_message = false
          handler.scene.visual.show_ability(target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 514, target))
        end
      end
      register(:sturdy, Sturdy)
      class SupremeOverlord < Ability
        # Create a new SupremeOverlord effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @multiplier = 0
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          return if handler.logic.trainer_battlers.all?(&:alive?)
          handler.logic.trainer_battlers.each { |battler| @multiplier += battler.ko_count }
          @multiplier = @multiplier.clamp(0, 5)
          @multiplier = (@multiplier / 10.0).truncate(1)
          log_data("Supreme Overlord - Power of moves increased by #{1 + @multiplier}")
          handler.scene.visual.show_ability(with)
          handler.scene.visual.wait_for_animation
        end
        # Give the move base power mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def base_power_multiplier(user, target, move)
          return super unless user == @target
          return super + @multiplier
        end
      end
      register(:supreme_overlord, SupremeOverlord)
      class SurgeSurfer < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return @logic.field_terrain_effect.electric? ? 2 : 1
        end
      end
      register(:surge_surfer, SurgeSurfer)
      class SweetVeil < Ability
        # Create a new FlowerGift effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target.bank != @target.bank
          return unless status == :sleep
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(@target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 1186, target))
          end
        end
      end
      register(:sweet_veil, SweetVeil)
      class SwiftSwim < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return ($env.rain? || $env.hardrain?) ? 2 : 1
        end
      end
      register(:swift_swim, SwiftSwim)
      class Symbiosis < Ability
        # List of moves that cause the talent to proceed after the target has taken damage
        DEFERRED_MOVES = %i[fling natural_gift]
        # List of methods that make the target invalid
        INVALID_BE_METHOD = %i[s_knock_off s_thief]
        # Create a new Symbiosis effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @post_damage_activation = false
          @affect_allies = true
          @ally = nil
        end
        # Function called when a pre_item_change is checked
        # @param handler [Battle::Logic::ItemChangeHandler]
        # @param db_symbol [Symbol] Symbol ID of the item
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the item change cannot be applied
        def on_pre_item_change(handler, db_symbol, target, launcher, skill)
          return unless handler.logic.allies_of(@target).include?(target)
          @ally = target
          @post_damage_activation = should_activate?(@ally, skill)
        end
        # Function called when a post_item_change is checked
        # @param handler [Battle::Logic::ItemChangeHandler]
        # @param db_symbol [Symbol] Symbol ID of the item
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_item_change(handler, db_symbol, target, launcher, skill)
          return if @post_damage_activation
          return unless valid_target?(handler, @ally, skill)
          if handler.logic.item_change_handler.can_give_item?(@target, @ally)
            handler.scene.visual.show_ability(@target)
            handler.logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 1219, @target, PFM::Text::PKNICK[2] => @ally.name, PFM::Text::ITEM2[1] => @target.item_name))
            transfer_item(handler, @ally)
          end
        end
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return unless @post_damage_activation
          return unless valid_target?(handler, @ally, skill)
          @post_damage_activation = false
          if handler.logic.item_change_handler.can_give_item?(@target, @ally)
            handler.scene.visual.show_ability(@target)
            handler.logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 1219, @target, PFM::Text::PKNICK[2] => @ally.name, PFM::Text::ITEM2[1] => @target.item_name))
            transfer_item(handler, @ally)
          end
        end
        private
        # Check if we can give our object to the target that just lost it 
        # @param handler [Battle::Logic::DamageHandler]
        # @param ally [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Boolean]
        def valid_target?(handler, ally, skill)
          return false unless handler.logic.allies_of(@target).include?(ally)
          return false if skill && INVALID_BE_METHOD.include?(skill.be_method)
          return false if ally.effects.has?(:item_burnt)
          return true
        end
        # Check if the object should be given after the target turn
        # @param ally [PFM::PokemonBattler]
        # @param skill [Battle::Move, nil] Potential move used
        # @return [Boolean]
        def should_activate?(ally, skill)
          return true if @target.battle_item_db_symbol.to_s.include?('_gem')
          return true if skill && DEFERRED_MOVES.include?(skill.db_symbol)
          return true if ally.item_effect.is_a?(Battle::Effects::Item::TypeResistingBerry)
          return false
        end
        # Method that gives the item
        # @param handler [Battle::Logic::DamageHandler]
        # @param ally [PFM::PokemonBattler]
        def transfer_item(handler, ally)
          new_item = @target.battle_item_db_symbol
          handler.logic.item_change_handler.change_item(:none, true, @target)
          handler.logic.item_change_handler.change_item(new_item, true, ally, @target)
        end
      end
      register(:symbiosis, Symbiosis)
      class Synchronize < Ability
        # List of status Synchronize is applying
        SYNCHRONIZED_STATUS = %i[poison toxic paralysis burn]
        # Function called when a post_status_change is performed
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_status_change(handler, status, target, launcher, skill)
          return if target != @target || launcher == target || !launcher || launcher.status == target.status
          return unless SYNCHRONIZED_STATUS.include?(status)
          handler.scene.visual.show_ability(target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 1159, launcher))
          handler.status_change_with_process(status, launcher, target)
        end
      end
      register(:synchronize, Synchronize)
      class TabletsOfRuin < Ability
        # Create a new Tablets of Ruin effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @activated = false
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          remove_effect(handler, who) if who != with && who == @target && @activated
          set_effect(handler, with) if with == @target
        end
        # Function responsible for applying the effect
        # @param handler [Battle::Logic::SwitchHandler]
        # @param owner [PFM::PokemonBattler]
        def set_effect(handler, owner)
          battlers = handler.logic.all_alive_battlers.reject { |battler| battler == owner }
          return if battlers.empty?
          battlers.each do |battler|
            next if battler.has_ability?(db_symbol) || battler.effects.has?(db_symbol)
            battler.effects.add(effect_class.new(handler.logic))
          end
          handler.scene.visual.show_ability(owner)
          handler.scene.visual.wait_for_animation
          @activated = true
        end
        # Function responsible for removing the effect
        # @param handler [Battle::Logic::SwitchHandler]
        # @param owner [PFM::PokemonBattler]
        def remove_effect(handler, owner)
          battlers = handler.logic.all_alive_battlers.reject { |battler| battler == owner }
          return if battlers.empty?
          battlers.each do |battler|
            next unless battler.has_ability?(db_symbol) || battler.effects.has?(db_symbol)
            battler.effects.get(db_symbol)&.kill
            battler.effects.delete_specific_dead_effect(db_symbol)
          end
          @activated = false
        end
        # If Tablets of Ruin is currently activated by this pokemon
        # @return [Boolean]
        def activated?
          return @activated
        end
        alias activated activated?
        # Class of the Effect given by this ability
        def effect_class
          return Effects::TabletsOfRuin
        end
      end
      class BeadsOfRuin < TabletsOfRuin
        # Class of the Effect given by this ability
        def effect_class
          return Effects::BeadsOfRuin
        end
      end
      class VesselOfRuin < TabletsOfRuin
        # Class of the Effect given by this ability
        def effect_class
          return Effects::VesselOfRuin
        end
      end
      class SwordOfRuin < VesselOfRuin
        # Class of the Effect given by this ability
        def effect_class
          return Effects::SwordOfRuin
        end
      end
      register(:tablets_of_ruin, TabletsOfRuin)
      register(:beads_of_ruin, BeadsOfRuin)
      register(:vessel_of_ruin, VesselOfRuin)
      register(:sword_of_ruin, SwordOfRuin)
      class TangledFeet < Ability
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return target.confused? ? 0.5 : 1
        end
      end
      register(:tangled_feet, TangledFeet)
      class Technician < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return move.power <= 60 ? 1.5 : 1
        end
      end
      register(:technician, Technician)
      # A Pokemon with Telepathy avoids damaging moves used by its allies.
      # @see https://pokemondb.net/ability/telepathy
      # @see https://bulbapedia.bulbagarden.net/wiki/Telepathy_(Ability)
      class Telepathy < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target
          return unless launcher&.can_be_lowered_or_canceled?
          allies = handler.logic.allies_of(target)
          allies.each do |ally|
            next unless launcher == ally && hp > 0
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 469, target))
            return :prevent
          end
          return nil
        end
      end
      register(:telepathy, Telepathy)
      class ThermalExchange < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill&.type_fire?
          handler.scene.visual.show_ability(target)
          handler.scene.visual.wait_for_animation
          handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, target)
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target || target.effects.has?(:substitute)
          return unless status == :burn
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.visual.wait_for_animation
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 270, target))
          end
        end
        # Function called at the end of an action
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_post_action_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return unless @target.alive? && @target.burn?
          logic.status_change_handler.status_change(:cure, @target)
        end
      end
      register(:thermal_exchange, ThermalExchange)
      class ThickFat < Ability
        # List of types affected by thick fat
        THICK_FAT_TYPES = %i[fire ice]
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if target != self.target
          return 1 unless user.can_be_lowered_or_canceled?
          return THICK_FAT_TYPES.include?(data_type(move.type).db_symbol) ? 0.5 : 1
        end
      end
      register(:thick_fat, ThickFat)
      class TintedLens < Ability
        # Give the move mod3 mutiplier (after everything)
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def mod3_multiplier(user, target, move)
          return 1 if user != @target
          return move.not_very_effective? ? 2 : 1
        end
      end
      register(:tinted_lens, TintedLens)
      class ToughClaws < Ability
        # Get the base power multiplier of this move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Float]
        def base_power_multiplier(user, target, move)
          return 1 if user != self.target
          return move.direct? ? 1.3 : 1
        end
      end
      register(:tough_claws, ToughClaws)
      class ToxicBoost < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return 1 unless user.status_effect.global_poisoning?
          return move.physical? ? 1.5 : 1
        end
      end
      register(:toxic_boost, ToxicBoost)
      class ToxicDebris < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == @target
          return unless skill&.physical?
          effect = @logic.bank_effects[launcher.bank]&.get(:toxic_spikes)
          return if effect && effect.power >= 2
          effect.empower if effect
          handler.logic.add_bank_effect(Effects::ToxicSpikes.new(handler.logic, launcher.bank)) unless effect
          handler.scene.visual.show_ability(target)
          handler.scene.visual.wait_for_animation
          handler.scene.display_message_and_wait(parse_text(18, launcher.bank == 0 ? 158 : 159))
        end
      end
      register(:toxic_debris, ToxicDebris)
      class Trace < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          foes = handler.logic.foes_of(with).select do |foe|
            next(foe.alive? && foe.ability_db_symbol != :__undef__ && handler.logic.ability_change_handler.can_change_ability?(with, foe.ability_db_symbol))
          end
          return if foes.none?
          target = foes.sample(random: handler.logic.generic_rng)
          handler.scene.visual.show_ability(with)
          handler.logic.ability_change_handler.change_ability(with, target.ability_db_symbol)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 381, target, PFM::Text::ABILITY[1] => with.ability_name))
          with.ability_effect.on_switch_event(handler, who, with) if with.ability_effect.class != Trace
        end
      end
      register(:trace, Trace)
      class Triage < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param priority [Integer]
        # @param move [Battle::Move]
        # @return [Proc, nil]
        def on_move_priority_change(user, priority, move)
          return nil if user != @target
          return nil unless move.heal?
          return priority + 3
        end
      end
      register(:triage, Triage)
      class Truant < Ability
        # Function called when we try to use a move as the user (returns :prevent if user fails)
        # @param user [PFM::PokemonBattler]
        # @param targets [Array<PFM::PokemonBattler>]
        # @param move [Battle::Move]
        # @return [:prevent, nil] :prevent if the move cannot continue
        def on_move_prevention_user(user, targets, move)
          return if user != @target
          if user.ability_used
            move.scene.display_message_and_wait(parse_text_with_pokemon(19, 445, user))
            user.ability_used = false
            return :prevent
          end
          user.ability_used = true
        end
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return unless who == @target
          @target.ability_used = false
        end
      end
      register(:truant, Truant)
      class VoltAbsorb < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Boolean] if the target is immune to the move
        def on_move_prevention_target(user, target, move)
          return false if target != @target || @target.effects.has?(:heal_block)
          return false unless move && check_move_type?(move)
          return false unless user&.can_be_lowered_or_canceled?
          move.scene.visual.show_ability(target)
          move.scene.visual.wait_for_animation
          move.logic.damage_handler.heal(target, target.max_hp / factor)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, target.hp >= target.max_hp ? 896 : 387, target))
          return true
        end
        # Function that checks the type of the move
        # @param move [Battle::Move]
        # @return [Boolean]
        def check_move_type?(move)
          return move.type_electric?
        end
        # Returns the factor used for healing
        # @return [Integer]
        def factor
          return 4
        end
      end
      class WaterAbsorb < VoltAbsorb
        # @param move [Battle::Move]
        # @return [Boolean]
        def check_move_type?(move)
          return move.type_water?
        end
      end
      class EarthEater < VoltAbsorb
        # @param move [Battle::Move]
        # @return [Boolean]
        def check_move_type?(move)
          return move.type_ground?
        end
      end
      register(:volt_absorb, VoltAbsorb)
      register(:water_absorb, WaterAbsorb)
      register(:earth_eater, EarthEater)
      class Unaware < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if target != @target || move.critical_hit?
          return 1 unless user.can_be_lowered_or_canceled?
          return 1 / (move.physical? ? target.atk_modifier : target.ats_modifier) if move.is_a?(Move::FoulPlay)
          return 1 / (move.physical? ? user.atk_modifier : user.ats_modifier)
        end
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if user != @target || move.critical_hit?
          return 1 unless target.can_be_lowered_or_canceled?
          return 1 / (move.physical? ? target.dfe_modifier : target.dfs_modifier)
        end
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          if user == @target && target.can_be_lowered_or_canceled?
            return 1 / move.evasion_mod(target)
          else
            if target == @target && user.can_be_lowered_or_canceled?
              return 1 / move.accuracy_mod(user)
            end
          end
          return 1
        end
      end
      register(:unaware, Unaware)
      class Unburden < Ability
        # Give the speed modifier over given to the Pokemon with this effect
        # @return [Float, Integer] multiplier
        def spd_modifier
          return 2 if @target.effects.has?(:item_stolen) || @target.effects.has?(:item_burnt)
          return 2 if @target.item_consumed
          return @boost_enabled ? 2 : 1
        end
        # Function called when a post_item_change is checked
        # @param handler [Battle::Logic::ItemChangeHandler]
        # @param db_symbol [Symbol] Symbol ID of the item
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_item_change(handler, db_symbol, target, launcher, skill)
          @boost_enabled = false
          return unless db_symbol == :none
          @boost_enabled = true
          handler.scene.visual.show_ability(@target)
        end
        # Reset the boost when leaving battle
        def reset
          @boost_enabled = false
        end
      end
      register(:unburden, Unburden)
      class Unnerve < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text(18, with.bank == 0 ? 183 : 182))
        end
      end
      register(:unnerve, Unnerve)
      class VictoryStar < Ability
        # Create a new VictoryStar effect
        # @param logic [Battle::Logic]
        # @param target [PFM::PokemonBattler]
        # @param db_symbol [Symbol] db_symbol of the ability
        def initialize(logic, target, db_symbol)
          super
          @affect_allies = true
        end
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if user.bank != @target.bank
          return 1.1
        end
      end
      register(:victory_star, VictoryStar)
      class VitalSpirit < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :sleep
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 318, target))
          end
        end
      end
      register(:vital_spirit, VitalSpirit)
      class WanderingSpirit < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.direct? && launcher && launcher.hp > 0 && !launcher.has_ability?(:long_reach)
          return unless handler.logic.ability_change_handler.can_change_ability?(launcher, db_symbol)
          handler.scene.visual.show_ability(target)
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 405, launcher, PFM::Text::ABILITY[1] => target.ability_name))
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 405, target, PFM::Text::ABILITY[1] => launcher.ability_name))
          handler.logic.ability_change_handler.change_ability(launcher, db_symbol)
          handler.logic.ability_change_handler.change_ability(target, PFM::Text::ABILITY[1] => target.ability_name)
        end
      end
      register(:wandering_spirit, WanderingSpirit)
      class WaterBubble < Ability
        # Give the move [Spe]atk mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_atk_multiplier(user, target, move)
          return 1 if user != @target
          return move.type_water? ? 2 : 1
        end
        # Give the move [Spe]def mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def sp_def_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return move.type_fire? ? 1.5 : 1
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if status != :burn || target != @target
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 270, target))
          end
        end
      end
      register(:water_bubble, WaterBubble)
      class WaterCompaction < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.type_water?
          if handler.logic.stat_change_handler.stat_increasable?(:dfe, target)
            handler.scene.visual.show_ability(target)
            handler.logic.stat_change_handler.stat_change_with_process(:dfe, 2, target)
          end
        end
      end
      register(:water_compaction, WaterCompaction)
      class WaterVeil < Ability
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return unless status == :burn
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 270, target))
          end
        end
      end
      register(:water_veil, WaterVeil)
      class WeakArmor < Ability
        # Function called after damages were applied (post_damage, when target is still alive)
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        def on_post_damage(handler, hp, target, launcher, skill)
          return if target != @target || launcher == target
          return unless skill&.physical?
          handler.scene.visual.show_ability(target)
          handler.logic.stat_change_handler.stat_change_with_process(:dfe, -1, target)
          handler.logic.stat_change_handler.stat_change_with_process(:spd, 1, target)
        end
      end
      register(:weak_armor, WeakArmor)
      class WellBakedBody < Ability
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return if target != @target
          return unless skill&.type_fire?
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.visual.wait_for_animation
            handler.logic.stat_change_handler.stat_change_with_process(:dfe, 2, target)
          end
        end
      end
      register(:well_baked_body, WellBakedBody)
      class WhiteSmoke < Ability
        # Function called when a stat_decrease_prevention is checked
        # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
        # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the stat decrease cannot apply
        def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
          return if target != @target
          return unless launcher && target != launcher && launcher.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 198, target))
          end
        end
      end
      register(:white_smoke, WhiteSmoke)
      class WonderGuard < Ability
        # Function called when we try to check if the effect changes the definitive priority of the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler]
        # @param move [Battle::Move]
        # @return [Boolean] if the target is immune to the move
        def on_move_ability_immunity(user, target, move)
          return false if target != @target
          return false if move.db_symbol == :struggle
          check = move.type_modifier(user, target) <= 1 && move.real_base_power(user, target) != 0 && user.can_be_lowered_or_canceled?
          @logic.scene.visual.show_ability(@target) if check
          return check
        end
      end
      register(:wonder_guard, WonderGuard)
      class WonderSkin < Ability
        # Return the chance of hit multiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move]
        # @return [Float]
        def chance_of_hit_multiplier(user, target, move)
          return 1 if target != @target
          return 1 unless user.can_be_lowered_or_canceled?
          return move.status? ? 0.5 : 1
        end
      end
      register(:wonder_skin, WonderSkin)
      class ZenMode < Ability
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          who.form_calibrate if who == @target && who != with
          return if with != @target
          original_form = with.form
          with.form_calibrate(:battle)
          if with.form != original_form
            handler.scene.visual.show_ability(with)
            handler.scene.visual.show_switch_form_animation(with)
            handler.scene.display_message_and_wait(parse_text(18, with.form.odd? ? transform : back))
          end
        end
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return unless battlers.include?(@target)
          return if @target.dead?
          original_form = @target.form
          @target.form_calibrate(:battle)
          return if @target.form == original_form
          scene.visual.show_ability(@target)
          scene.visual.show_switch_form_animation(@target)
          scene.display_message_and_wait(parse_text(18, @target.form.odd? ? transform : back))
        end
        private
        def transform
          return 191
        end
        def back
          return 192
        end
      end
      register(:zen_mode, ZenMode)
      class Schooling < ZenMode
        private
        def transform
          return 288
        end
        def back
          return 289
        end
      end
      register(:schooling, Schooling)
      class ShieldsDown < ZenMode
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if target != @target
          return if @target.form != 0
          return unless launcher&.can_be_lowered_or_canceled?
          return handler.prevent_change do
            handler.scene.visual.show_ability(target)
          end
        end
        def transform
          return 290
        end
        def back
          return 291
        end
      end
      register(:shields_down, ShieldsDown)
      class AsOne < ChillingNeigh
        # Function called when a Pokemon has actually switched with another one
        # @param handler [Battle::Logic::SwitchHandler]
        # @param who [PFM::PokemonBattler] Pokemon that is switched out
        # @param with [PFM::PokemonBattler] Pokemon that is switched in
        def on_switch_event(handler, who, with)
          return if with != @target
          handler.scene.visual.show_ability(with)
          handler.scene.display_message_and_wait(parse_text(18, with.bank == 0 ? 183 : 182))
        end
        private
        def boosted_stat
          return :atk
        end
      end
      register(:as_one, AsOne)
      class AsOneBis < AsOne
        private
        def boosted_stat
          return :ats
        end
      end
      register(:as_one_bis, AsOneBis)
    end
    class TabletsOfRuin < EffectBase
      # Give the atk modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def atk_modifier
        return 0.75
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :tablets_of_ruin
      end
    end
    class BeadsOfRuin < EffectBase
      # Give the dfs modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def dfs_modifier
        return @logic.terrain_effects.has?(:wonder_room) ? super : 0.75
      end
      # Give the dfe modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def dfe_modifier
        return @logic.terrain_effects.has?(:wonder_room) ? 0.75 : super
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :beads_of_ruin
      end
    end
    class VesselOfRuin < EffectBase
      # Give the ats modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def ats_modifier
        return 0.75
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :vessel_of_ruin
      end
    end
    class SwordOfRuin < EffectBase
      # Give the dfs modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def dfs_modifier
        return @logic.terrain_effects.has?(:wonder_room) ? 0.75 : super
      end
      # Give the dfe modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def dfe_modifier
        return @logic.terrain_effects.has?(:wonder_room) ? super : 0.75
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        return :sword_of_ruin
      end
    end
  end
end
Hooks.register(PFM::PokemonBattler, :on_reset_states, 'PSDK reset FlashFire') do
  ability_effect.reset if ability_effect.is_a?(Battle::Effects::Ability::FlashFire)
end
Hooks.register(PFM::PokemonBattler, :on_reset_states, 'PSDK reset Unburden') do
  ability_effect.reset if ability_effect.is_a?(Battle::Effects::Ability::Unburden)
end
