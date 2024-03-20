module Battle
  module Effects
    # Implement the ability suppression (Gastro Acid)
    class AbilitySuppressed < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :ability_suppressed
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
    end
    # Implement the Aqua Ring effect
    class AquaRing < PokemonTiedEffectBase
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return unless battlers.include?(@pokemon)
        return kill if @pokemon.dead?
        return if @pokemon.hp == @pokemon.max_hp
        heal_hp = (@pokemon.max_hp / hp_factor).clamp(1, Float::INFINITY)
        heal_hp += heal_hp * 30 / 100 if @pokemon.hold_item?(:big_root)
        logic.damage_handler.heal(@pokemon, heal_hp) do
          @logic.scene.display_message_and_wait(message)
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :aqua_ring
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
      # Get the message text
      # @return [String]
      def message
        return parse_text_with_pokemon(19, 604, @pokemon)
      end
      # Get the HP factor delt by the move
      # @return [Integer]
      def hp_factor
        return 16
      end
    end
    # Implement the attract effect
    class Attract < PokemonTiedEffectBase
      # Get the Pokemon who's this Pokemon is attracted to
      # @return [PFM::PokemonBattler]
      attr_reader :attracted_to
      # Create a new Pokemon Attract effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param attracted_to [PFM::PokemonBattler]
      def initialize(logic, target, attracted_to)
        super(logic, target)
        @attracted_to = attracted_to
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        message = parse_text_with_pokemon(19, 339, @pokemon)
        @logic.scene.display_message_and_wait(message)
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if user != @pokemon
        return unless targets.include?(@attracted_to)
        return @logic.scene.visual.show_ability(user) && kill if user.has_ability?(:oblivious)
        move.scene.display_message_and_wait(parse_text_with_pokemon(19, 333, user, PFM::Text::PKNICK[1] => @attracted_to.given_name))
        if bchance?(0.5)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 336, user))
          return :prevent
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :attract
      end
    end
    class Autotomize < PokemonTiedEffectBase
      # Constant containing the weight for each Autotomize-like move
      WEIGHT_MOVES = {autotomize: 100}
      WEIGHT_MOVES.default = 100
      # Create a new autotomize effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move] the move that created the effect
      def initialize(logic, pokemon, move)
        super(logic, pokemon)
        launch_effect(move)
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :autotomize
      end
      # Try to increase a stat of the Pokemon then change its weight
      # @param move [Battle::Move]
      def launch_effect(move)
        @pokemon.weight = (@pokemon.weight - weight(move)).clamp(0.1, Float::INFINITY)
        @logic.scene.display_message_and_wait(message)
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @pokemon.restore_weight
      end
      private
      # Return the weight loss for the move
      def weight(move)
        WEIGHT_MOVES[move.db_symbol]
      end
      # Get the right message to display
      # @return [String]
      def message
        return parse_text_with_pokemon(19, 1108, @pokemon)
      end
    end
    class BatonPass < PokemonTiedEffectBase
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        switch_stages(handler, who, with)
        switch_status(handler, who, with)
        switch_effects(handler, who, with)
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :baton_pass
      end
      private
      # Switch the stages of the pokemons
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def switch_stages(handler, who, with)
        with.atk_stage, with.ats_stage, with.dfe_stage, with.dfs_stage, with.spd_stage, with.acc_stage, with.eva_stage = who.atk_stage, who.ats_stage, who.dfe_stage, who.dfs_stage, who.spd_stage, who.acc_stage, who.eva_stage
      end
      # Switch the stages of the pokemons
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def switch_status(handler, who, with)
        handler.logic.status_change_handler.status_change_with_process(:confusion, with) if who.confused?
      end
      # Switch the effect from one to another
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def switch_effects(handler, who, with)
        who.effects.each do |effect|
          log_data("#{name} \# passed #{effect.name}") if effect.on_baton_pass_switch(with)
        end
      end
    end
    # Implement the Beak Blast effect
    class BeakBlast < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      def initialize(logic, pokemon)
        super
        self.counter = 1
      end
      # Function called after damages were applied (post_damage, when target is still alive)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage(handler, hp, target, launcher, skill)
        return unless launcher != @pokemon
        return unless skill&.direct? && launcher && launcher.hp > 0 && launcher.can_be_burn? && !launcher.has_ability?(:long_reach)
        return if @pokemon.move_history.any? { |history| history.turn == $game_temp.battle_turn }
        handler.logic.status_change_handler.status_change_with_process(:burn, launcher, target)
      end
      # Function called after damages were applied and when target died (post_damage_death)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage_death(handler, hp, target, launcher, skill)
        return unless launcher != @pokemon
        return unless skill&.direct? && launcher && launcher.hp > 0 && launcher.can_be_burn? && !launcher.has_ability?(:long_reach)
        return if @pokemon.move_history.any? { |history| history.turn == $game_temp.battle_turn }
        handler.logic.status_change_handler.status_change_with_process(:burn, launcher, target)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :beak_blast
      end
    end
    class Bestow < EffectBase
      # Initialize the effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param giver [PFM::PokemonBattler] the Pokemon that gives the item
      # @param receiver [PFM::PokemonBattler] the Pokemon that receives the item
      # @param item [Symbol] the db_symbol of the item
      def initialize(logic, giver, receiver, item)
        super(logic)
        @giver = giver
        @receiver = receiver
        @item = item
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :bestow
      end
      # Give the item back to the giver and clear the item of the receiver
      def give_back_item
        return if @receiver.bank != 0 && !@logic.battle_info.trainer_battle?
        @logic.item_change_handler.change_item(item, true, @giver)
        @logic.item_change_handler.change_item(:none, true, @receiver)
      end
    end
    # Class that describe the bind effect
    class Bind < PokemonTiedEffectBase
      # Hash giving the message info based on the db_symbol of the move
      MESSAGE_INFO = {bind: [19, 806, true], wrap: [19, 813, true], fire_spin: [19, 830, false], clamp: [19, 820, true], whirlpool: [19, 827, false], sand_tomb: [19, 836, false], magma_storm: [19, 833, false], infestation: [19, 1234, true], octolock: [59, 1978, false], snap_trap: [59, 1974, false], thunder_cage: [59, 2052, true]}
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :origin
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param origin [PFM::PokemonBattler] Pokemon that used the move dealing this effect
      # @param turn_count [Integer]
      # @param move [Battle::Move] move responsive of the effect
      def initialize(logic, pokemon, origin, turn_count, move)
        super(logic, pokemon)
        @origin = origin
        @move = move
        self.counter = turn_count
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return kill if @origin.dead?
        return if @pokemon.dead?
        return if @pokemon.has_ability?(:magic_guard)
        scene.display_message(message)
        logic.damage_handler.damage_change((@pokemon.max_hp / hp_factor).clamp(1, Float::INFINITY), @pokemon)
      end
      # Function called when testing if pokemon can switch (when he couldn't passthrough)
      # @param handler [Battle::Logic::SwitchHandler]
      # @param pokemon [PFM::PokemonBattler]
      # @param skill [Battle::Move, nil] potential skill used to switch
      # @param reason [Symbol] the reason why the SwitchHandler is called
      # @return [:prevent, nil] if :prevent, can_switch? will return false
      def on_switch_prevention(handler, pokemon, skill, reason)
        return if pokemon != @pokemon
        return kill if @origin.dead?
        return handler.prevent_change do
          handler.scene.display_message_and_wait(message)
        end
      end
      # Function called when a Pokemon has actually switched with another one
      # @param _handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param _with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(_handler, who, _with)
        kill if who == @origin
      end
      # Tell if the effect is dead or must be cleared
      # @return [Boolean]
      def dead?
        super || !@origin.can_fight?
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :bind
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 375, @pokemon, PFM::Text::MOVE[1] => @move.name))
      end
      private
      # Get the message text
      # @return [String]
      def message
        file_id, message_id, two_pokemon_message = (MESSAGE_INFO[@move.db_symbol] || [0, 0, false])
        return parse_text_with_2pokemon(file_id, message_id, @pokemon, @origin) if two_pokemon_message
        return parse_text_with_pokemon(file_id, message_id, @pokemon)
      end
      # Get the HP factor delt by the move
      # @return [Integer]
      def hp_factor
        return @origin.hold_item?(:binding_band) ? 8 : 6
      end
    end
    # Class managing Burn Up Effect
    class BurnUp < PokemonTiedEffectBase
      include Mechanics::NeutralizeType
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param type [Integer] the current type of the move
      # @param turn_count [Integer]
      def initialize(logic, pokemon, turn_count, type)
        super(logic, pokemon)
        @type = type
        neutralize_type_initialize(pokemon, turn_count)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :burn_up
      end
      private
      # Get the neutralized types
      # @return [Array<Integer>]
      def neutralyzed_types
        return [data_type(@type).id]
      end
    end
    # CantSwitch Effect
    class CantSwitch < PokemonTiedEffectBase
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :origin
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param origin [PFM::PokemonBattler] Pokemon that used the move dealing this effect
      # @param move [Battle::Move] move responsive of the effect
      def initialize(logic, pokemon, origin, move)
        super(logic, pokemon)
        @origin = origin
        @move = move
      end
      # Function called when testing if pokemon can switch (when he couldn't passthrough)
      # @param handler [Battle::Logic::SwitchHandler]
      # @param pokemon [PFM::PokemonBattler]
      # @param skill [Battle::Move, nil] potential skill used to switch
      # @param reason [Symbol] the reason why the SwitchHandler is called
      # @return [:prevent, nil] if :prevent, can_switch? will return false
      def on_switch_prevention(handler, pokemon, skill, reason)
        return if pokemon != @pokemon
        return kill if @origin.dead?
        return handler.prevent_change do
          handler.scene.display_message_and_wait(message)
        end
      end
      # Function called when a Pokemon has actually switched with another one
      # @param _handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(_handler, who, with)
        kill if who == @origin && !who.effects.has?(:baton_pass)
      end
      # Tell if the effect must be cleared
      # @return [Boolean]
      def dead?
        super || !@origin.can_fight?
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :cantswitch
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with, @origin, @move)
      end
      # Get the message text
      # @return [String]
      def message
        return parse_text_with_pokemon(19, 878, @pokemon)
      end
    end
    class CenterOfAttention < PokemonTiedEffectBase
      # The move that caused this effect
      # @return [Symbol]
      attr_reader :origin_move
      # Moves that ignore this effect
      MOVES_IGNORING_THIS_EFFECT = %i[snipe_shot]
      # Create a new Center of Attention effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turn_count [Integer] amount of turn the effect is active
      # @param origin_move [Battle::Move] the move that caused this effect
      def initialize(logic, pokemon, turn_count, origin_move)
        super(logic, pokemon)
        self.counter = turn_count
        @origin_move = origin_move
      end
      # Return the new target if the conditions are fulfilled
      # @param user [PFM::PokemonBattler] user of the move
      # @param targets [Array<PFM::PokemonBattler>] expected targets
      # @param move [Battle::Move]
      # @return [PFM::PokemonBattler] the new target if the conditions are fulfilled, the initial target otherwise
      def target_redirection(user, targets, move)
        return if user&.ability_effect&.ignore_target_redirection?
        return if MOVES_IGNORING_THIS_EFFECT.include?(move.db_symbol) || move.two_turn?
        return if @origin_move.db_symbol == :rage_powder && rage_powder_immunity?(user)
        return if @pokemon.effects.has?(:prevent_targets_move)
        return @pokemon
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :center_of_attention
      end
      private
      # Check if the user of the move has an immunity to powders moves
      # @param user [PFM::PokemonBattler] user of the move
      # @return [Boolean]
      def rage_powder_immunity?(user)
        return true if user.has_ability?(:overcoat)
        return true if user.hold_item?(:safety_goggles)
        return true if user.type_grass?
        return false
      end
    end
    # ChangeType Effects
    class ChangeType < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param type [Integer] the ID of the type to apply to the Pokemon
      def initialize(logic, pokemon, type)
        super(logic, pokemon)
        @pokemon.change_types(type, 0, 0)
      end
      # Function called when a Pokemon initialize a transformation
      # @param handler [Battle::Logic::TransformHandler]
      # @param target [PFM::PokemonBattler]
      def on_transform_event(handler, target)
        return unless @pokemon == target
        @pokemon.restore_types
        kill
      end
      # Get the effect name
      # @return [Symbol]
      def name
        :change_type
      end
    end
    class Charge < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turncount [Integer] amount of turn the effect is active
      def initialize(logic, pokemon, turncount)
        super(logic, pokemon)
        self.counter = turncount
      end
      # Give the move base power mutiplier
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def base_power_multiplier(user, target, move)
        return 1 if user != @pokemon
        return move.type_electric? ? 2 : 1
      end
      # Name of the effect
      # @return [Symbol]
      def name
        :charge
      end
    end
    # Effect describing confusion
    class Confusion < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turn_count [Integer] number of turn for the confusion (not including current turn)
      def initialize(logic, pokemon, turn_count = logic.generic_rng.rand(1..4))
        super(logic, pokemon)
        self.counter = turn_count + 1
      end
      # Return the amount of damage the Pokemon receive from confusion
      # @return [Integer]
      def confuse_damage
        return ((@pokemon.level * 2 / 5 + 2) * 40 * @pokemon.atk / @pokemon.dfe / 50).floor
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if dead? || user != @pokemon
        if @counter == 1
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 351, user))
          kill
        else
          move.scene.visual.show_rmxp_animation(user, 475)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 348, user))
          if bchance?(damage_chance)
            move.scene.visual.show_hp_animations([user], [-confuse_damage]) do
              move.scene.display_message_and_wait(parse_text(18, 83))
            end
            return :prevent
          end
        end
      end
      # Get the damage chance (between 0 & 1) of the confusion
      # @return [Float]
      def damage_chance
        0.5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :confusion
      end
    end
    # Implement Crafty Shield effect that protects Pokemon from status moves
    class CraftyShield < PokemonTiedEffectBase
      # Function called when we try to check if the target evades the move
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] expected target
      # @param move [Battle::Move]
      # @return [Boolean] if the target is evading the move
      def on_move_prevention_target(user, target, move)
        return false unless @pokemon == target && move.status? && user != target && move.db_symbol != :curse
        move.scene.display_message_and_wait(parse_text_with_pokemon(19, 803, target))
        return true
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :crafty_shield
      end
    end
    # Implement the Curse effect
    class Curse < PokemonTiedEffectBase
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return if @pokemon.dead?
        return if @pokemon.has_ability?(:magic_guard)
        hp = @pokemon.max_hp / 4
        scene.display_message_and_wait(parse_text_with_pokemon(19, 1077, @pokemon))
        logic.damage_handler.damage_change(hp.clamp(1, Float::INFINITY), @pokemon)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :curse
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
    end
    # Class that manage DestinyBond effect. Works together with Move::DestinyBond.
    # @see https://pokemondb.net/move/destiny-bond
    # @see https://bulbapedia.bulbagarden.net/wiki/Destiny_Bond_(move)
    # @see https://www.pokepedia.fr/Lien_du_Destin
    class DestinyBond < PokemonTiedEffectBase
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if dead? || user != @pokemon
        log_debug('PSDK Destiny Bond Effect: Effect removed with on_move_prevention_user.')
        kill
      end
      # Function called after damages were applied and when target died (post_damage_death)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage_death(handler, hp, target, launcher, skill)
        return if @pokemon != target
        return unless skill && launcher != target && launcher
        return if handler.logic.allies_of(target).include?(launcher)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 629, target))
        handler.scene.visual.show_hp_animations([launcher], [-launcher.hp])
      end
      def name
        :destiny_bond
      end
    end
    # Implement the Foresight effect
    # Foresight - Odor Sleuth
    class Disable < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move] move that is disabled
      def initialize(logic, pokemon, move)
        super(logic, pokemon)
        @move = move
        self.counter = 4
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        message = parse_text_with_pokemon(19, 598, @pokemon, PFM::Text::MOVE[1] => @move.name)
        @logic.scene.display_message_and_wait(message)
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if user != @pokemon || move != @move
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 595, user, PFM::Text::MOVE[1] => move.name))
        return :prevent
      end
      # Function called when we try to check if the user cannot use a move
      # @param user [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Proc, nil]
      def on_move_disabled_check(user, move)
        return if user != @pokemon || move != @move
        return proc {@logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 595, user, PFM::Text::MOVE[1] => move.name)) }
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :disable
      end
    end
    # Drowsiness make the pokemon fall asleep after a certain amount of turns, applied by Yawn
    # @see https://bulbapedia.bulbagarden.net/wiki/Yawn_(move)
    class Drowsiness < PokemonTiedEffectBase
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :origin
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param counter [Integer] (default:2)
      # @param origin [PFM::PokemonBattler] Pokemon that used the move dealing this effect
      def initialize(logic, pokemon, counter, origin)
        super(logic, pokemon)
        self.counter = counter
        @origin = origin
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 667, @pokemon))
      end
      # If the effect can proc
      # @return [Boolean]
      def triggered?
        return @counter == 1
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :drowsiness
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return unless triggered?
        return if @pokemon.dead?
        return kill if %i[electric_terrain misty_terrain].include?(logic.field_terrain) && @pokemon.grounded?
        return kill if @pokemon.status?
        return kill if @pokemon.db_symbol == :minior && @pokemon.form == 0
        logic.status_change_handler.status_change_with_process(:sleep, @pokemon, @origin)
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        kill if who == @pokemon
      end
    end
    class EchoedVoice < EffectBase
      def initialize(logic)
        super
        @successive_turns = 0
        @has_increased = false
      end
      # Increase the value of the successive turn
      def increase
        @has_increased = true
      end
      # Number of consecutive turns where the effect has been updated
      # @return [Integer]
      def successive_turns
        return @successive_turns
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return kill unless @has_increased
        @successive_turns += 1
        @has_increased = false
      end
      def name
        :echoed_voice
      end
    end
    # Implement the change type effect (Electrify)
    class Electrify < PokemonTiedEffectBase
      # Get the type ID that replace the moves
      # @return [Integer]
      attr_reader :type
      # Create a new Electrify effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param type [Integer]
      def initialize(logic, target, type = data_type(:electric).id)
        super(logic, target)
        @type = type
        self.counter = 1
      end
      # Function called when we try to get the definitive type of a move
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] expected target
      # @param move [Battle::Move]
      # @param type [Integer] current type of the move (potentially after effects)
      # @return [Integer, nil] new type of the move
      def on_move_type_change(user, target, move, type)
        return user == @pokemon ? @type : nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :change_type
      end
    end
    # Embargo prevents the target using any items for five turns. This includes both held items and items used by the trainer such as medicines.
    # @see https://pokemondb.net/move/embargo
    # @see https://bulbapedia.bulbagarden.net/wiki/Embargo_(move)
    # @see https://www.pokepedia.fr/Embargo
    class Embargo < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turncount [Integer]
      def initialize(logic, pokemon, turncount = 5)
        super(logic, pokemon)
        self.counter = turncount
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :embargo
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(delete_message)
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with, @counter)
      end
      # Message displayed when the effect prevent item usage
      # @return [String]
      def prevent_message
        parse_text_with_pokemon(19, 730, @pokemon)
      end
      # Message displayed when the effect wear off
      # @return [String]
      def delete_message
        parse_text_with_pokemon(19, 730, @pokemon)
      end
    end
    # Implement the flinch effect
    class Flinch < PokemonTiedEffectBase
      # Create a new Pokemon Attract effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      def initialize(logic, target)
        super(logic, target)
        self.counter = 1
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if user != @pokemon
        move.scene.visual.show_rmxp_animation(user, 476)
        move.scene.display_message_and_wait(parse_text_with_pokemon(19, 363, user))
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
        return if status != :flinch || dead? || target != @pokemon
        return :prevent
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :flinch
      end
    end
    # Implement the Focus Energy effect
    class FocusEnergy < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :focus_energy
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
    end
    # Move that force the next move
    class ForceNextMoveBase < PokemonTiedEffectBase
      include Mechanics::ForceNextMove
      # Create a new Forced next move effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param turncount [Integer] number of turn the effect proc (including the current one)
      def initialize(logic, target, move, targets, turncount)
        super(logic, target)
        init_force_next_move(move, targets, turncount)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :force_next_move_base
      end
      # If the effect can proc
      # @return [Boolean]
      def triggered?
        return @counter == 1
      end
    end
    # Forced Next Move for rollout so it stores additional information
    class Rollout < PokemonTiedEffectBase
      include Mechanics::ForceNextMove
      include Mechanics::SuccessiveSuccessfulUses
      # Create a new Forced next move effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param turncount [Integer] (default: 5) number of turn the effect proc (including the current one)
      def initialize(logic, target, move, targets, turncount = 2)
        super(logic, target)
        init_force_next_move(move, targets, turncount)
        init_successive_successful_uses(target, move)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :rollout
      end
    end
    # Forced Next Move for previous move of target for 3 turns
    class Encore < PokemonTiedEffectBase
      include Mechanics::ForceNextMove
      # Create a new Forced next move effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param turncount [Integer] (default: 5) number of turn the effect proc (including the current one)
      def initialize(logic, target, move, targets, turncount = 3)
        super(logic, target)
        init_force_next_move(move, targets, turncount)
      end
      def on_delete
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 562, @pokemon))
      end
      # Tell if the effect forces the next turn action into a Attack action
      # @return [Boolean]
      def force_next_turn_action?
        return false
      end
      # Get the class of the action
      # @return [Class<Actions::Attack>]
      def action_class
        Actions::Attack::Encore
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :encore
      end
    end
    # Forced Next Move for Bide
    class Bide < PokemonTiedEffectBase
      include Mechanics::ForceNextMove
      # Get the number of damage the Pokemon got during this effect
      # @return [Integer]
      attr_accessor :damages
      # Create a new Forced next move effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param counter [Integer] number of turn the move is forced to be used (including the current one)
      # @param targets [Array<PFM::PokemonBattler>]
      def initialize(logic, target, move, targets, counter = 2)
        super(logic, target)
        init_force_next_move(move, targets, counter)
        @damages = 0
      end
      # Function called after damages were applied (post_damage, when target is still alive)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage(handler, hp, target, launcher, skill)
        return if @pokemon != target || hp < 0
        @damages += hp
      end
      # Tell if the bide can unleach
      # @return [Boolean]
      def unleach?
        return @counter == 1
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :bide
      end
    end
    # Implement the Foresight effect
    # Foresight - Odor Sleuth
    class Foresight < PokemonTiedEffectBase
      # Function that computes an overwrite of the type multiplier
      # @param target [PFM::PokemonBattler]
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @param move [Battle::Move]
      # @return [Float, nil] overwriten type multiplier
      def on_single_type_multiplier_overwrite(target, target_type, type, move)
        return if target != @pokemon || target_type != data_type(:ghost).id
        return 1 if type == data_type(:normal).id
        return 1 if type == data_type(:fighting).id
        return nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :foresight
      end
    end
    # Effect that manage Fury Cutter effect
    class FuryCutter < PokemonTiedEffectBase
      include Mechanics::SuccessiveSuccessfulUses
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move]
      def initialize(logic, pokemon, move)
        super(logic, pokemon)
        init_successive_successful_uses(pokemon, move)
      end
      # Return the symbol of the effect.
      # @return [Symbol]
      def name
        :fury_cutter
      end
    end
    class FutureSight < PositionTiedEffectBase
      # Create a new position tied effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param bank [Integer] bank where the effect is tied
      # @param position [Integer] position where the effect is tied
      # @param origin [PFM::PokemonBattler]
      # @param countdown [Integer] amount of turn before the effect proc (including the current one)
      # @param move [Battle::Move]
      def initialize(logic, bank, position, origin, countdown, move)
        super(logic, bank, position)
        @origin = origin
        self.counter = countdown
        @move = move
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        return unless (target = find_target)
        @logic.scene.display_message_and_wait(message(target))
        hp = @move.damages(@origin, target)
        damage_handler = @logic.damage_handler
        damage_handler.damage_change_with_process(hp, target, @origin, @move) do
          @logic.scene.display_message_and_wait(parse_text(18, 84)) if @move.critical_hit?
          @move.efficent_message(@move.effectiveness, target) if hp > 0
        end
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :future_sight
      end
      private
      # Find the defintive target
      # @return [PFM::PokemonBattler, nil]
      def find_target
        return affected_pokemon if affected_pokemon.alive?
        proto_move = Battle::Move.new(:__undef__, 1, 1, @logic.scene)
        def proto_move.target
          :user_or_adjacent_ally
        end
        return proto_move.battler_targets(affected_pokemon, @logic).select(&:alive?).first
      end
      # Message displayed when the effect proc
      # @return [String]
      def message(target)
        parse_text_with_pokemon(19, 1086, target)
      end
    end
    # Gravity Effect
    class Gravity < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic)
        super
        self.counter = 5
      end
      # Return the chance of hit multiplier
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move]
      # @return [Float]
      def chance_of_hit_multiplier(user, target, move)
        return 5.0 / 3
      end
      # Function that computes an overwrite of the type multiplier
      # @param target [PFM::PokemonBattler]
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @param move [Battle::Move]
      # @return [Float, nil] overwriten type multiplier
      def on_single_type_multiplier_overwrite(target, target_type, type, move)
        return if target_type != data_type(:flying).id
        return 1 if type == data_type(:ground).id
        return nil
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        if move.gravity_affected?
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 1092, user))
          return :prevent
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :gravity
      end
      # Show the message when the effect gets deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 124))
      end
    end
    # Implement the Grudge effect
    class Grudge < PokemonTiedEffectBase
      # Function called after damages were applied and when target died (post_damage_death)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage_death(handler, hp, target, launcher, skill)
        return if target != @pokemon
        return unless launcher && skill&.direct?
        return unless target.successful_move_history.last.move.be_method == :s_grudge
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 635, launcher, ::PFM::Text::MOVE[1] => skill.name))
        skill.pp = 0
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        kill if who == @pokemon
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return unless battlers.include?(@pokemon)
        return if @pokemon.dead?
        kill
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :grudge
      end
    end
    # HappyHour Effect
    class HappyHour < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic)
        super
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :happy_hour
      end
    end
    # Implement the Miracle Eye effect
    class HealBlock < PokemonTiedEffectBase
      # Create a new Pokemon HealBlock effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      def initialize(logic, target)
        super(logic, target)
        self.counter = 5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :heal_block
      end
    end
    # Healing Wish Effect
    class HealingWish < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :healing_wish
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 697, with))
        handler.scene.visual.show_hp_animations([with], [with.max_hp])
        handler.logic.status_change_handler.status_change_with_process(:cure, with)
      end
    end
    class HelpingHand < PokemonTiedEffectBase
      include Mechanics::WithMarkedTargets
      # Create a new HelpingHand effect
      # @param logic [Battle::Logic]
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler]
      # @param duration [Integer]
      def initialize(logic, user, target, duration)
        super(logic, user)
        initialize_with_marked_targets(user, [target]) { |t| create_mark_effect(t, duration) }
        self.counter = duration
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :helping_hand
      end
      private
      # @param target [PFM::PokemonBattler]
      # @param duration [Integer]
      # @return [EffectBase]
      def create_mark_effect(target, duration)
        Mark.new(@logic, target, self, duration)
      end
      # Class marking the target of the HelpingHand so we cannot apply the effect twice
      class Mark < PokemonTiedEffectBase
        include Mechanics::Mark
        # Create a new mark
        # @param logic [Battle::Logic]
        # @param pokemon [PFM::PokemonBattler]
        # @param origin [HelpingHand] origin of the mark
        def initialize(logic, pokemon, origin, duration)
          super(logic, pokemon)
          initialize_mark(origin)
          self.counter = duration
        end
        # Give the move base power mutiplier
        # @param user [PFM::PokemonBattler] user of the move
        # @param target [PFM::PokemonBattler] target of the move
        # @param move [Battle::Move] move
        # @return [Float, Integer] multiplier
        def base_power_multiplier(user, target, move)
          log_data("base_power_multiplier x#{user == @pokemon ? 1.5 : super} \# helping hand")
          return user == @pokemon ? 1.5 : super
        end
        # Name of the effect
        # @return [Symbol]
        def name
          :helping_hand_mark
        end
      end
    end
    class Imprison < PokemonTiedEffectBase
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :imprison
      end
      # Check if the effect prevent the move
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_global(user, targets, move)
        return unless @logic.foes_of(@pokemon).include?(user) && @pokemon.moveset.any? { |pkm_move| move.id == pkm_move.id }
        move.logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 589, user))
        return :prevent
      end
    end
    # Ingrain Effect
    class Ingrain < CantSwitch
      # Function called when testing if pokemon can switch (when he couldn't passthrough)
      # @param handler [Battle::Logic::SwitchHandler]
      # @param pokemon [PFM::PokemonBattler]
      # @param skill [Battle::Move, nil] potential skill used to switch
      # @param reason [Symbol] the reason why the SwitchHandler is called
      # @return [:prevent, nil] if :prevent, can_switch? will return false
      def on_switch_prevention(handler, pokemon, skill, reason)
        return false unless pokemon.effects.has?(:ingrain)
        return true if skill&.be_method == :s_teleport
        return handler.prevent_change do
          handler.scene.display_message_and_wait(flee_message)
        end
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return unless battlers.include?(@pokemon)
        return if @pokemon.dead?
        heal_hp = (@pokemon.max_hp / hp_factor).clamp(1, Float::INFINITY)
        heal_hp += heal_hp * 30 / 100 if @pokemon.hold_item?(:big_root)
        logic.damage_handler.heal(@pokemon, heal_hp) do
          @logic.scene.display_message_and_wait(message)
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :ingrain
      end
      private
      # Get the message text
      # @return [String]
      def message
        return parse_text_with_pokemon(19, 739, @pokemon)
      end
      # Get the flee message text
      # @return [String]
      def flee_message
        return parse_text_with_pokemon(19, 742, @pokemon)
      end
      # Get the HP factor delt by the move
      # @return [Integer]
      def hp_factor
        return 16
      end
    end
    # IonDeluge Effect
    class IonDeluge < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic)
        super
        self.counter = 1
      end
      # Function called when we try to get the definitive type of a move
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] expected target
      # @param move [Battle::Move]
      # @param type [Integer] current type of the move (potentially after effects)
      # @return [Integer, nil] new type of the move
      def on_move_type_change(user, target, move, type)
        return data_type(:electric).id if type == data_type(:normal).id
        return nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :ion_deluge
      end
    end
    # Implement the Item Burnt effect
    class ItemBurnt < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :item_burnt
      end
    end
    # Implement the Item Stolen effect
    class ItemStolen < PokemonTiedEffectBase
      # Function called when a post_item_change is checked
      # @param handler [Battle::Logic::ItemChangeHandler]
      # @param db_symbol [Symbol] Symbol ID of the item
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_item_change(handler, db_symbol, target, launcher, skill)
        return unless target != launcher
        return if %i[none __undef__].include?(db_symbol)
        return unless db_symbol == launcher.battle_item_db_symbol
        kill
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :item_stolen
      end
    end
    # Implement the Laser Focus effect
    class LaserFocus < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :laser_focus
      end
      def initialize(logic, pokemon)
        super
        self.counter = 2
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
    end
    # Implementation of Leech Seed effect
    # This class drains the target hp to the Pokemon in the position of its user
    class LeechSeed < PositionTiedEffectBase
      include Mechanics::WithMarkedTargets
      # Create a new position LeechSeed effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param user [PFM::PokemonBattler] receiver of that effect
      # @param target [PFM::PokemonBattler] pokemon getting the damages
      def initialize(logic, user, target)
        super(logic, user.bank, user.position)
        initialize_with_marked_targets(user, [target]) { |t| Mark.new(logic, t, self, leech_power) }
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Divisor factor of the drain
      # @return [Integer]
      def leech_power
        8
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :leech_seed
      end
      # Class marking the target of the LeechSeed so we cannot apply the effect twice
      class Mark < PokemonTiedEffectBase
        include Mechanics::Mark
        # Create a new mark
        # @param logic [Battle::Logic]
        # @param pokemon [PFM::PokemonBattler]
        # @param origin [LeechSeed] origin of the mark
        # @param leech_power [Integer] base power of the leech
        def initialize(logic, pokemon, origin, leech_power)
          super(logic, pokemon)
          initialize_mark(origin)
          @leech_power = leech_power
        end
        # Function that tells if the move is affected by Rapid Spin
        # @return [Boolean]
        def rapid_spin_affected?
          return true
        end
        # Get the name of the effect
        # @return [Symbol]
        def name
          :leech_seed_mark
        end
        # Function called at the end of a turn
        # @param logic [Battle::Logic] logic of the battle
        # @param scene [Battle::Scene] battle scene
        # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
        def on_end_turn_event(logic, scene, battlers)
          return if dead?
          origin = LeechSeed.from(mark_origin)
          launcher = origin.launcher
          pkmn = logic.alive_battlers(launcher.bank).include?(launcher) ? launcher : logic.battler(origin.bank, origin.position)
          return if pkmn.nil? || pkmn.dead? || @pokemon.dead?
          return if @pokemon.has_ability?(:magic_guard)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 610, @pokemon))
          logic.damage_handler.drain(@leech_power, @pokemon, pkmn)
        end
        # Transfer the effect to the given pokemon via baton switch
        # @param with [PFM::Battler] the pokemon switched in
        # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
        def baton_switch_transfer(with)
          return Mark.new(@logic, with, @mark_origin, @leech_power)
        end
      end
    end
    # Effect describing LightScreen
    class LightScreen < PositionTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param bank [Integer] bank where the effect is tied
      # @param position [Integer] position where the effect is tied
      # @param turn_count [Integer] number of turn for the confusion (not including current turn)
      def initialize(logic, bank, position, turn_count = 5)
        super(logic, bank, position)
        self.counter = turn_count
      end
      # Give the move mod1 mutiplier (before the +2 in the formula)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def mod1_multiplier(user, target, move)
        return 1 if @bank != target.bank || move.critical_hit? || user.has_ability?(:infiltrator)
        return 1 unless move.special?
        return $game_temp.vs_type == 2 ? (2 / 3.0) : 0.5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :light_screen
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, message_id + @bank.clamp(0, 1)))
      end
      private
      # ID of the message responsive of telling the end of the effect
      # @return [Integer]
      def message_id
        return 136
      end
    end
    # Effect describing Reflect
    class Reflect < LightScreen
      # Give the move mod1 mutiplier (before the +2 in the formula)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def mod1_multiplier(user, target, move)
        return 1 if @bank != target.bank || move.critical_hit? || user.has_ability?(:infiltrator)
        return $game_temp.vs_type == 2 ? (2 / 3.0) : 0.5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :reflect
      end
      private
      # ID of the message responsive of telling the end of the effect
      # @return [Integer]
      def message_id
        return 132
      end
    end
    # Effect describing Aurora Veil
    class AuroraVeil < LightScreen
      # Give the move mod1 mutiplier (before the +2 in the formula)
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def mod1_multiplier(user, target, move)
        return 1 if @bank != target.bank || move.critical_hit? || user.has_ability?(:infiltrator)
        return $game_temp.vs_type == 2 ? (2 / 3.0) : 0.5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        :aurora_veil
      end
      private
      # ID of the message responsive of telling the end of the effect
      # @return [Integer]
      def message_id
        return 287
      end
    end
    # Implement the Lock-On and Mind Reader effect
    class LockOn < PokemonTiedEffectBase
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :target
      # Create a new Pokemon Lock-On effect
      # @param logic [Battle::Logic]
      # @param user [PFM::PokemonBattler] pokemon aiming
      # @param target [PFM::PokemonBattler] pokemon aimed
      # @param turncount [Integer] (default: 2)
      def initialize(logic, user, target, turncount = 2)
        super(logic, user)
        @target = target
        self.counter = turncount
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :lock_on
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with, @target, @counter + 1)
      end
    end
    class LuckyChant < PositionTiedEffectBase
      # Create a new Lucky Chant effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        @counter = 5
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :lucky_chant
      end
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, message_id + bank.clamp(0, 1)))
      end
      private
      # ID of the message that is responsible for telling the end of the effect
      # @return [Integer]
      def message_id
        return 152
      end
    end
    # Lunar Dance Effect
    class LunarDance < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :lunar_dance
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 694, with))
        handler.scene.visual.show_hp_animations([with], [with.max_hp])
        handler.logic.status_change_handler.status_change_with_process(:cure, with)
        with.skills_set.each { |skill| skill.pp = skill.ppmax }
      end
    end
    # Implement the change type effect (Electrify)
    class MagicCoat < PokemonTiedEffectBase
      # Create a new Electrify effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      def initialize(logic, target)
        super(logic, target)
        self.counter = 1
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :magic_coat
      end
    end
    class MagicRoom < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic, duration)
        super(logic)
        self.counter = duration
        @logic.scene.display_message_and_wait(parse_text(18, 186))
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 187))
      end
      def name
        :magic_room
      end
      # Function called when a held item wants to perform its action
      # @return [Boolean] weither or not the item can't proceed (true will stop the item)
      def on_held_item_use_prevention
        true
      end
    end
    # User becomes immune to Ground-type moves for N turns.
    class MagnetRise < PokemonTiedEffectBase
      include Mechanics::ForceFlying
      Mechanics::ForceFlying.register_force_flying_hook('PSDK flying: Magnet Rise', :magnet_rise)
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param duration [Integer] (default: 5) duration of the move (including the current turn)
      def initialize(logic, pokemon, duration = 5)
        super(logic, pokemon)
        force_flying_initialize(duration)
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :magnet_rise
      end
      private
      # Message displayed when the effect procs
      # @return [String]
      def on_proc_message
        parse_text_with_pokemon(19, 658, @pokemon)
      end
      # Message displayed when the effect wear off
      # @return [String]
      def on_delete_message
        parse_text_with_pokemon(19, 661, @pokemon)
      end
    end
    # Implement the Minimize effect
    class Minimize < PokemonTiedEffectBase
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :minimize
      end
    end
    # Implement the Miracle Eye effect
    class MiracleEye < PokemonTiedEffectBase
      # Function that computes an overwrite of the type multiplier
      # @param target [PFM::PokemonBattler]
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @param move [Battle::Move]
      # @return [Float, nil] overwriten type multiplier
      def on_single_type_multiplier_overwrite(target, target_type, type, move)
        return if target != @pokemon || target_type != data_type(:dark).id
        return 1 if type == data_type(:psychic).id
        return nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :miracle_eye
      end
    end
    class Mist < PositionTiedEffectBase
      # Create a new Mist effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        self.counter = 5
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :mist
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 144 : 145))
      end
      # Function called when a stat_decrease_prevention is checked
      # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [:prevent, nil] :prevent if the stat decrease cannot apply
      def on_stat_decrease_prevention(handler, stat, target, launcher, skill)
        return if target.bank != @bank
        return if launcher&.bank == @bank
        return handler.prevent_change do
          @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 845, target))
        end
      end
    end
    # Effect lowering Electric moves
    class MudSport < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic)
        super
        self.counter = 5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :mud_sport
      end
      # Give the move base power mutiplier
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def base_power_multiplier(user, target, move)
        return move.type_electric? ? 0.5 : 1
      end
      # Show the message when the effect gets deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 121))
      end
    end
    # Effect lowering Fire moves
    class WaterSport < MudSport
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :water_sport
      end
      # Give the move base power mutiplier
      # @param user [PFM::PokemonBattler] user of the move
      # @param target [PFM::PokemonBattler] target of the move
      # @param move [Battle::Move] move
      # @return [Float, Integer] multiplier
      def base_power_multiplier(user, target, move)
        return move.type_fire? ? 0.5 : 1
      end
      # Show the message when the effect gets deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 119))
      end
    end
    # Implement the Nightmare effect
    class Nightmare < PokemonTiedEffectBase
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return kill unless @pokemon.asleep? || @pokemon.has_ability?(:comatose)
        return if @pokemon.dead?
        return if @pokemon.has_ability?(:magic_guard)
        hp = @pokemon.max_hp / 4
        scene.display_message_and_wait(parse_text_with_pokemon(19, 324, @pokemon))
        logic.damage_handler.damage_change(hp.clamp(1, Float::INFINITY), @pokemon)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :nightmare
      end
    end
    class NoRetreat < CantSwitch
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :no_retreat
      end
    end
    class Octolock < Bind
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return kill if @origin.dead?
        return if @pokemon.dead?
        scene.display_message(message)
        logic.stat_change_handler.stat_change_with_process(:dfe, -1, @pokemon, @origin)
        logic.stat_change_handler.stat_change_with_process(:dfs, -1, @pokemon, @origin)
      end
    end
    # Implement the Out of Reach effect
    class OutOfReachBase < PokemonTiedEffectBase
      include Mechanics::OutOfReach
      # Create a new out reach effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param exceptions [Array<Symbol>] move that hit the target while out of reach
      # @param turncount [Integer] (default: 5) number of turn the effect proc (including the current one)
      def initialize(logic, pokemon, move, exceptions, turncount = 2)
        super(logic, pokemon)
        initialize_out_of_reach(pokemon, move, exceptions, turncount)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :out_of_reach_base
      end
    end
    # Effect used by Perish Song move
    class PerishSong < EffectBase
      def origin
        return nil
      end
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param pokemon [PFM::PokemonBattler] target that will be affected by the effect
      # @param countdown [Integer] number of turn before the effect proc (including the current one)
      def initialize(logic, pokemon, countdown)
        super(logic)
        @pokemon = pokemon
        self.counter = countdown
      end
      # If the effect can proc
      # @return [Boolean]
      def triggered?
        return @counter == 1
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :perish_song
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        return if @pokemon.dead?
        scene.display_message_and_wait(parse_text_with_pokemon(19, 863, @pokemon, {PFM::Text::NUMB[2] => (@counter - 1).to_s}))
        logic.damage_handler.damage_change(@pokemon.max_hp, @pokemon) if triggered?
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with, @counter)
      end
    end
    # Implement the Powder effect
    class Powder < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      def initialize(logic, pokemon)
        super
        self.counter = 1
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if user != @pokemon
        return unless move.type_fire?
        move.send(:usage_message, user)
        @logic.scene.display_message_and_wait(parse_text(18, 259, PFM::Text::MOVE[0] => move.name))
        @logic.damage_handler.damage_change((user.max_hp / 4).clamp(1, Float::INFINITY), user)
        return :prevent
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :powder
      end
    end
    class PreventTargetsMove < PokemonTiedEffectBase
      include Mechanics::WithTargets
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic, user, targets, duration = 1)
        super(logic, user)
        initialize_with_targets(targets)
        self.counter = duration
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return :prevent if targetted?(user)
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :prevent_targets_move
      end
    end
    # Implement the Protect effect
    class Protect < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param move [Battle::Move] move that applied this effect
      def initialize(logic, pokemon, move)
        super(logic, pokemon)
        @move = move
        self.counter = 1
      end
      # Function called when we try to check if the target evades the move
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] expected target
      # @param move [Battle::Move]
      # @return [Boolean] if the target is evading the move
      def on_move_prevention_target(user, target, move)
        return false if target != @pokemon
        return false unless move.blocked_by?(target, @move.db_symbol)
        return false if user.has_ability?(:unseen_fist) && move.direct?
        play_protect_effect(user, target, move)
        return true
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :protect
      end
      private
      # Function responsive of playing the protect effect if protect got triggered (inc. message)
      # @param user [PFM::PokemonBattler]
      # @param target [PFM::PokemonBattler] expected target
      # @param move [Battle::Move]
      def play_protect_effect(user, target, move)
        move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
      end
      @effect_classes = {}
      class << self
        # Register a Protect effect
        # @param db_symbol [Symbol] db_symbol of the move
        # @param klass [Class<Protect>] protect class
        def register(db_symbol, klass)
          @effect_classes[db_symbol] = klass
        end
        # Create a new effect
        # @param logic [Battle::Logic]
        # @param pokemon [PFM::PokemonBattler]
        # @param move [Battle::Move] move that applied this effect
        # @return [Protect]
        def new(logic, pokemon, move)
          klass = @effect_classes[move.db_symbol] || Protect
          object = klass.allocate
          object.send(:initialize, logic, pokemon, move)
          return object
        end
      end
      # Implement the Spiky Shield effect
      class SpikyShield < Protect
        private
        # Function responsive of playing the protect effect if protect got triggered (inc. message)
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        def play_protect_effect(user, target, move)
          hp = user.hp / 8
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
          move.scene.visual.show_hp_animations([user], [-hp]) if move.direct? && !user.has_ability?(:long_reach)
        end
      end
      Protect.register(:spiky_shield, SpikyShield)
      # Implement the King's Shield effect
      class KingsShield < Protect
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if move.status?
          return super
        end
        private
        # Function responsive of playing the protect effect if protect got triggered (inc. message)
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        def play_protect_effect(user, target, move)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
          move.scene.logic.stat_change_handler.stat_change_with_process(:atk, -1, user, user.has_ability?(:mirror_armor) ? target : nil) if move.direct? && !user.has_ability?(:long_reach)
        end
      end
      Protect.register(:king_s_shield, KingsShield)
      # Implement the Silk Trap effect
      class SilkTrap < Protect
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if target != @pokemon
          return false unless move.blocked_by?(target, @move.db_symbol) && !move.status?
          return false if user.has_ability?(:unseen_fist) && move.direct?
          play_protect_effect(user, target, move)
          return true
        end
        private
        # Function responsive of playing the protect effect if protect got triggered (inc. message)
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        def play_protect_effect(user, target, move)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
          move.scene.logic.stat_change_handler.stat_change_with_process(:spd, -1, user, user.has_ability?(:mirror_armor) ? target : nil) if move.direct? && !user.has_ability?(:long_reach)
        end
      end
      Protect.register(:silk_trap, SilkTrap)
      # Implement the Obstruct effect
      class Obstruct < SilkTrap
        private
        # Function responsive of playing the protect effect if protect got triggered (inc. message)
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        def play_protect_effect(user, target, move)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
          move.scene.logic.stat_change_handler.stat_change_with_process(:dfe, -2, user, user.has_ability?(:mirror_armor) ? target : nil) if move.direct? && (move.db_symbol != :sucker_punch || !user.has_ability?(:long_reach))
        end
      end
      Protect.register(:obstruct, Obstruct)
      # Implement the Baneful Bunker effect
      class BanefulBunker < Protect
        private
        # Function responsive of playing the protect effect if protect got triggered (inc. message)
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        def play_protect_effect(user, target, move)
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 523, target))
          handler = @logic.status_change_handler
          handler.status_change(:poison, user, message_overwrite: 234) if move.direct? && !user.has_ability?(:long_reach) && handler.status_appliable?(:poison, user)
        end
      end
      Protect.register(:baneful_bunker, BanefulBunker)
      # Implement the Mat Block effect
      class MatBlock < Protect
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if move.status?
          return super
        end
      end
      Protect.register(:mat_block, MatBlock)
      # Implement the Mat Block effect
      class Endure < PokemonTiedEffectBase
        # Create a new Pokemon tied effect
        # @param logic [Battle::Logic]
        # @param pokemon [PFM::PokemonBattler]
        # @param move [Battle::Move] move that applied this effect
        def initialize(logic, pokemon, move)
          super(logic, pokemon)
          @move = move
          @show_message = false
          self.counter = 1
        end
        # Function called when a damage_prevention is checked
        # @param handler [Battle::Logic::DamageHandler]
        # @param hp [Integer] number of hp (damage) dealt
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
        def on_damage_prevention(handler, hp, target, launcher, skill)
          return unless launcher && skill
          return if hp < target.hp
          return if target != @pokemon || dead?
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
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 514, target))
        end
      end
      Protect.register(:endure, Endure)
      # Implement the Quick Guard effect
      class QuickGuard < Protect
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if @pokemon.bank != target.bank
          return false if move.relative_priority <= 0
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 800, target))
          return true
        end
      end
      Protect.register(:quick_guard, QuickGuard)
      # Implement the Wide Guard effect
      class WideGuard < Protect
        # Function called when we try to check if the target evades the move
        # @param user [PFM::PokemonBattler]
        # @param target [PFM::PokemonBattler] expected target
        # @param move [Battle::Move]
        # @return [Boolean] if the target is evading the move
        def on_move_prevention_target(user, target, move)
          return false if @pokemon.bank != target.bank
          return false if move.is_one_target?
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 797, target))
          return true
        end
      end
      Protect.register(:wide_guard, WideGuard)
    end
    # Implement the Rage effect
    class Rage < PokemonTiedEffectBase
      # Function called after damages were applied (post_damage, when target is still alive)
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      def on_post_damage(handler, hp, target, launcher, skill)
        return if target != @pokemon
        if target.successful_move_history.last.move.be_method == :s_rage
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 532, target))
          handler.logic.stat_change_handler.stat_change_with_process(:atk, 1, target)
        else
          kill
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :rage
      end
    end
    # Class managing Roost Effect
    class Roost < PokemonTiedEffectBase
      include Mechanics::NeutralizeType
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turn_count [Integer]
      def initialize(logic, pokemon, turn_count)
        super(logic, pokemon)
        neutralize_type_initialize(pokemon, turn_count)
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :roost
      end
      private
      # Get the neutralized types
      # @return [Array<Integer>]
      def neutralyzed_types
        return [data_type(:flying).id]
      end
    end
    # The user's party is protected from status conditions.
    class Safeguard < LightScreen
      # Get the name of the effect
      # @return [Symbol]
      def name
        :safeguard
      end
      # Function called when a status_prevention is checked
      # @param handler [Battle::Logic::StatusChangeHandler]
      # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [:prevent, nil] :prevent if the status cannot be applied
      def on_status_prevention(handler, status, target, launcher, skill)
        return unless target.bank == @bank
        return if status == :cure
        return @logic.scene.visual.show_ability(launcher) if launcher&.has_ability?(:infiltrator)
        return if item_exceptions.include?(target.item_db_symbol)
        return if move_exceptions.include?(skill&.db_symbol)
        return if target.effects.has?(:drowsiness)
        @logic.scene.display_message_and_wait(parse_text_with_pokemon(19, status_prevention_message_id, target))
        return :prevent
      end
      private
      # Items that procs status even with Safeguard activated
      # @return [Array<Symbol>]
      ITEM_EXCEPTIONS = %i[flame_orb toxic_orb]
      # Items that procs status even with Safeguard activated
      # @return [Array<Symbol>]
      MOVE_EXCEPTIONS = %i[petal_dance outrage thrash]
      # Items that procs status even with Safeguard activated
      # @return [Array<Symbol>]
      def item_exceptions
        ITEM_EXCEPTIONS
      end
      # Items that procs status even with Safeguard activated
      # @return [Array<Symbol>]
      def move_exceptions
        MOVE_EXCEPTIONS
      end
      # ID of the message responsive of telling the end of the effect
      # @return [Integer]
      def message_id
        return 140
      end
      # ID of the message responsive of telling when the effect prevent a status
      def status_prevention_message_id
        return 842
      end
    end
    # SmackDown Effect
    class SmackDown < PokemonTiedEffectBase
      # Function that computes an overwrite of the type multiplier
      # @param target [PFM::PokemonBattler]
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @param move [Battle::Move]
      # @return [Float, nil] overwriten type multiplier
      def on_single_type_multiplier_overwrite(target, target_type, type, move)
        return if target_type != data_type(:flying).id
        return 1 if type == data_type(:ground).id
        return nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :smack_down
      end
    end
    class Snatch < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param turncount [Integer]
      def initialize(logic, pokemon, turncount = 1)
        super(logic, pokemon)
        self.counter = turncount
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :snatch
      end
    end
    class Spikes < PositionTiedEffectBase
      # Get the Spike power
      # @return [Integer]
      attr_reader :power
      # Create a new spike effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        @power = 1
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :spikes
      end
      # Tell if the spikes are at max power
      # @return [Boolean]
      def max_power?
        return @power >= 3
      end
      # Increase the spike power
      def empower
        @power += 1 unless max_power?
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 156 : 157))
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return unless with.grounded?
        return if with.has_ability?(:magic_guard)
        return if with.hold_item?(:heavy_duty_boots)
        factor = 10 - power * 2
        hp = (with.max_hp / factor).clamp(1, Float::INFINITY)
        handler.logic.damage_handler.damage_change(hp, with)
        handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 854, with))
      end
    end
    class StealthRock < PositionTiedEffectBase
      DMG_FACTOR = {0.25 => 3.125, 0.5 => 6.25, 1 => 12.5, 2 => 25, 4 => 50}
      # Create a new Sticky Web effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      # @param move [Battle::Move::StealthRock]
      def initialize(logic, bank, move)
        super(logic, bank, 0)
        @move = move
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :stealth_rock
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 164 : 165))
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return if with.has_ability?(:magic_guard)
        return if with.hold_item?(:heavy_duty_boots)
        calc_factor = @move.calc_factor(with) >= 1 ? @move.calc_factor(with).floor : @move.calc_factor(with)
        log_data("DMG_FACTOR: #{DMG_FACTOR[calc_factor]}")
        hp = (with.max_hp * DMG_FACTOR[calc_factor] / 100).floor.clamp(1, Float::INFINITY)
        handler.logic.damage_handler.damage_change(hp, with)
        handler.scene.display_message_and_wait(damage_message(with))
      end
      private
      # Get the message text
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def message(pokemon)
        return parse_text_with_pokemon(19, 1222, pokemon)
      end
      # Get the damage message text
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def damage_message(pokemon)
        return parse_text_with_pokemon(19, 857, pokemon)
      end
    end
    class StickyWeb < PositionTiedEffectBase
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :origin
      # Create a new Sticky Web effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      # @param origin [PFM::PokemonBattler] the Pokemon that launched the attack
      def initialize(logic, bank, origin)
        super(logic, bank, origin.position)
        @origin = origin
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :sticky_web
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 218 : 219))
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return unless with.grounded?
        return if with.has_ability?(:magic_guard)
        return if with.hold_item?(:heavy_duty_boots)
        handler.scene.display_message_and_wait(message(with))
        handler.logic.stat_change_handler.stat_change_with_process(:spd, -1, with, with.has_ability?(:mirror_armor) ? origin : nil)
      end
      # Get the message text
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def message(pokemon)
        return parse_text_with_pokemon(19, 1222, pokemon)
      end
    end
    # Stockpile raises the user's Defense and Special Defense by one stage each and charges up power for use with companion moves Spit Up or Swallow.
    # @see https://pokemondb.net/move/stockpile
    # @see https://bulbapedia.bulbagarden.net/wiki/Stockpile_(move)
    # @see https://www.pokepedia.fr/Stockage
    class Stockpile < PokemonTiedEffectBase
      # Return the amount in stockpile
      # @return [Integer]
      attr_reader :stockpile
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      def initialize(logic, pokemon)
        super
        @stockpile = 0
        @stages_bonus = Hash.new(0)
      end
      # Is the effect increasable?
      # @return [Boolean]
      def increasable?
        return @stockpile < maximum
      end
      # Is the effect usable ?
      # @return [Boolean]
      def usable?
        return @stockpile > 0
      end
      # Increase the stockpile value with animation
      # @param amount [Integer] (default: 1)
      # @return [Boolean] if the increase proc or not
      def increase(amount = 1)
        return false unless increasable?
        @stockpile += amount
        log_data("stockpile #{@stockpile}")
        @logic.scene.display_message_and_wait(on_increase_message)
        edit_stages
        return true
      end
      # Function called when the effect is being used
      # @return [Boolean] if the effect has been used or not
      def use
        return false unless usable?
        restore_stages
        @logic.scene.display_message_and_wait(on_clear_message)
        kill
        return true
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :stockpile
      end
      # Maximum stockpile
      # @return [Integer]
      def maximum
        3
      end
      private
      # Apply the change of the stat changes
      def edit_stages
        old_dfe_stage, old_dfs_stage = @pokemon.dfe_stage, @pokemon.dfs_stage
        @logic.stat_change_handler.stat_change_with_process(:dfe, 1, @pokemon)
        @logic.stat_change_handler.stat_change_with_process(:dfs, 1, @pokemon)
        @stages_bonus[:dfe] += @pokemon.dfe_stage - old_dfe_stage
        @stages_bonus[:dfs] += @pokemon.dfs_stage - old_dfs_stage
        log_data("stockpile \# increase stages <dfe:#{@pokemon.dfe_stage}(+#{@stages_bonus[:dfe]}), dfs:#{@pokemon.dfs_stage}(+#{@stages_bonus[:dfs]})>")
      end
      # Reset the effect of stockpile on stat stage
      def restore_stages
        @logic.stat_change_handler.stat_change_with_process(:dfe, -@stages_bonus[:dfe], @pokemon)
        @logic.stat_change_handler.stat_change_with_process(:dfs, -@stages_bonus[:dfs], @pokemon)
        log_data("stockpile \# restore stages <dfe:#{@pokemon.dfe_stage}, dfs:#{@pokemon.dfs_stage}>")
      end
      # Message displayed after a pokemon stockpile
      # @return [String]
      def on_increase_message
        parse_text_with_pokemon(19, 721, @pokemon, PFM::Text::NUMB[2] => @stockpile.to_s)
      end
      # Message displayed when the stockpile is being cleared
      # @return [String]
      def on_clear_message
        parse_text_with_pokemon(19, 724, @pokemon)
      end
    end
    # Implement the Substitute effect
    class Substitute < PokemonTiedEffectBase
      # Get the substitute hp
      # @return [Integer]
      attr_accessor :hp
      # Get the substitute max hp
      attr_reader :max_hp
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      def initialize(logic, pokemon)
        super
        @hp = @max_hp = pokemon.max_hp / 4
        pokemon.effects.get(:bind)&.kill if pokemon.effects.has?(:bind)
      end
      # Function called when a stat_increase_prevention is checked
      # @param handler [Battle::Logic::StatChangeHandler] handler use to test prevention
      # @param stat [Symbol] :atk, :dfe, :spd, :ats, :dfs, :acc, :eva
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [:prevent, nil] :prevent if the stat increase cannot apply
      def on_stat_increase_prevention(handler, stat, target, launcher, skill)
        return if target != @pokemon
        return :prevent if target != launcher && skill && !skill.authentic?
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
        return if target != @pokemon
        return :prevent if target != launcher && skill && !skill.authentic?
        return nil
      end
      # Function called when a damage_prevention is checked
      # @param handler [Battle::Logic::DamageHandler]
      # @param hp [Integer] number of hp (damage) dealt
      # @param target [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
      # @param skill [Battle::Move, nil] Potential move used
      # @return [:prevent, Integer, nil] :prevent if the damage cannot be applied, Integer if the hp variable should be updated
      def on_damage_prevention(handler, hp, target, launcher, skill)
        return if target != @pokemon || !skill
        return if skill.authentic?
        return if launcher&.has_ability?(:infiltrator) && !%i[transform sky_drop].include?(skill.db_symbol)
        return handler.prevent_change do
          @hp -= hp
          if @hp <= 0
            kill
            target.effects.delete_specific_dead_effect(:substitute)
            handler.scene.visual.show_switch_form_animation(target)
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 794, target))
          else
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 791, target))
          end
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
        return if target != @pokemon || !skill || status == :cure || launcher == target
        return if skill.authentic?
        return handler.prevent_change do
          handler.scene.display_message_and_wait(parse_text_with_pokemon(19, 24, target))
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :substitute
      end
      private
      # Transfer the effect to the given pokemon via baton switch
      # @param with [PFM::Battler] the pokemon switched in
      # @return [Battle::Effects::PokemonTiedEffectBase, nil] the effect to give to the switched in pokemon, nil if there is this effect isn't transferable via baton pass
      def baton_switch_transfer(with)
        return self.class.new(@logic, with)
      end
    end
    class Tailwind < PositionTiedEffectBase
      # Create a new Tailwind effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        @counter = 4
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 148 : 149))
      end
      # Give the speed modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def spd_modifier
        return 2
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :tailwind
      end
    end
    # TarShot Effect
    class TarShot < PokemonTiedEffectBase
      # Choose the type to add as a weakness according to the move_db_symbol used to add this weakness
      ADD_WEAKNESS_TO = {tar_shot: :fire}
      # Create a new TarShot effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param origin_move [Symbol] the move that caused this effect
      def initialize(logic, target, origin_move)
        super(logic, target)
        @factor05 = []
        @factor1 = []
        @factor2 = []
        @origin_move = origin_move
      end
      # Function that computes an overwrite of the type multiplier
      # @param target [PFM::PokemonBattler]
      # @param target_type [Integer] one of the type of the target
      # @param type [Integer] one of the type of the move
      # @param move [Battle::Move]
      # @return [Float, nil] overwriten type multiplier
      def on_single_type_multiplier_overwrite(target, target_type, type, move)
        return if target != @pokemon
        return unless target_type == target.type1
        return if move.type != data_type(ADD_WEAKNESS_TO[@origin_move]).id
        @factor05.clear
        @factor1.clear
        @factor2.clear
        type_check(ADD_WEAKNESS_TO[@origin_move])
        return 1 if @factor05.include?(target_type)
        return 2 if @factor1.include?(target_type)
        return 4 if @factor2.include?(target_type)
        return nil
      end
      # Compare the added type weakness with all other types
      # @param type_added [Integer] type added by the move that caused this effect
      def type_check(type_added)
        each_data_type.each do |type|
          factor = data_type(type_added).hit(type.db_symbol) <=> 1
          case factor
          when -1
            @factor05 << type.id
          when 1
            @factor2 << type.id
          else
            @factor1 << type.id
          end
        end
        return
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :tar_shot
      end
    end
    # Implement the Taunt effect
    class Taunt < PokemonTiedEffectBase
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      def initialize(logic, pokemon)
        super(logic, pokemon)
        self.counter = 3
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        message = parse_text_with_pokemon(19, 574, @pokemon)
        @logic.scene.display_message_and_wait(message)
      end
      # Function called when we try to check if the user cannot use a move
      # @param user [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Proc, nil]
      def on_move_disabled_check(user, move)
        return if user != @pokemon
        return unless move.status?
        return proc {move.scene.display_message_and_wait(parse_text_with_pokemon(19, 571, user, PFM::Text::MOVE[1] => move.name)) }
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return if user != @pokemon
        return @logic.scene.visual.show_ability(user) && kill if user.has_ability?(:oblivious)
        if move.status?
          move.scene.display_message_and_wait(parse_text_with_pokemon(19, 571, user, PFM::Text::MOVE[1] => move.name))
          return :prevent
        end
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :taunt
      end
    end
    # Telekinesis raises the target into the air for three turns, guaranteeing that all attacks against 
    # the target (except OHKO moves) will hit, regardless of Accuracy or Evasion.
    # @see https://pokemondb.net/move/telekinesis
    # @see https://bulbapedia.bulbagarden.net/wiki/Telekinesis_(move)
    # @see https://www.pokepedia.fr/L%C3%A9vikin%C3%A9sie
    # @see [Move::Telekinesis]
    class Telekinesis < PokemonTiedEffectBase
      include Mechanics::ForceFlying
      Mechanics::ForceFlying.register_force_flying_hook('PSDK flying: Telekinesis', :telekinesis)
      # Create a new Pokemon tied effect
      # @param logic [Battle::Logic]
      # @param pokemon [PFM::PokemonBattler]
      # @param duration [Integer] (default: 3) duration of the move (including the current turn)
      def initialize(logic, pokemon, duration = 3)
        super(logic, pokemon)
        force_flying_initialize(duration)
      end
      # Function giving the name of the effect
      # @return [Symbol]
      def name
        :telekinesis
      end
      private
      # Message displayed when the effect wear off
      # @return [String]
      def on_delete_message
        parse_text_with_pokemon(19, 1149, @pokemon)
      end
    end
    class ThroatChop < PokemonTiedEffectBase
      # The Pokemon that launched the attack
      # @return [PFM::PokemonBattler]
      attr_reader :origin
      # Create a new Throat Chop effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param origin [PFM::PokemonBattler] Pokemon that used the move dealing this effect
      # @param turn_count [Integer]
      # @param move [Battle::Move] move responsive of the effect
      def initialize(logic, target, origin, turn_count, move)
        super(logic, target)
        @origin = origin
        @move = move
        self.counter = turn_count
      end
      # Function called when we try to check if the user cannot use a move
      # @param user [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Proc, nil]
      def on_move_disabled_check(user, move)
        return unless move.sound_attack?
        return proc {move.scene.display_message_and_wait(parse_text_with_pokemon(59, 1860, user, PFM::Text::PKNICK[1] => user.name)) }
      end
      # Function called when we try to use a move as the user (returns :prevent if user fails)
      # @param user [PFM::PokemonBattler]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param move [Battle::Move]
      # @return [:prevent, nil] :prevent if the move cannot continue
      def on_move_prevention_user(user, targets, move)
        return unless move.sound_attack?
        move.scene.display_message_and_wait(parse_text_with_pokemon(59, 1860, user, PFM::Text::PKNICK[1] => user.name))
        return :prevent
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :throat_chop
      end
    end
    # Implement the Torment effect
    class Torment < PokemonTiedEffectBase
      UNSTOPPABLE_MOVES = %i[struggle]
      # Create a new Pokemon Torment effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      def initialize(logic, target)
        super(logic, target)
        @target = target
      end
      # Function called when we try to check if the user cannot use a move
      # @param user [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @return [Proc, nil]
      def on_move_disabled_check(user, move)
        other_move_actions = @logic.turn_actions.select do |a|
          a.is_a?(Actions::Attack) && Actions::Attack.from(a).launcher == user
        end
        return unless user == @target
        return if other_move_actions.empty?
        return if other_move_actions.any? do |move_action|
          next(true) if move.db_symbol != move_action.move.db_symbol
          next(false)
        end
        return proc {@logic.scene.display_message_and_wait(parse_text_with_pokemon(19, 580, user)) }
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :torment
      end
    end
    class ToxicSpikes < PositionTiedEffectBase
      # Get the Toxic Spikes power
      # @return [Integer]
      attr_reader :power
      # Create a new spike effect
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        @power = 1
      end
      # Function that tells if the move is affected by Rapid Spin
      # @return [Boolean]
      def rapid_spin_affected?
        return true
      end
      # Get the effect name
      # @return [Symbol]
      def name
        return :toxic_spikes
      end
      # Increase the spike power
      def empower
        @power += 1
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, @bank == 0 ? 160 : 161))
      end
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return kill if with.grounded? && with.type_poison?
        return if with.grounded? && with.type_steel?
        return unless with.grounded?
        return if with.hold_item?(:heavy_duty_boots)
        status = @power == 1 ? :poison : :toxic
        handler.logic.status_change_handler.status_change_with_process(status, with)
      end
    end
    # Implement the Transform effect
    class Transform < PokemonTiedEffectBase
      # Function called when a Pokemon has actually switched with another one
      # @param handler [Battle::Logic::SwitchHandler]
      # @param who [PFM::PokemonBattler] Pokemon that is switched out
      # @param with [PFM::PokemonBattler] Pokemon that is switched in
      def on_switch_event(handler, who, with)
        return if who != @pokemon || with == @pokemon
        @pokemon.transform = nil
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :transform
      end
    end
    # TrickRoom Effect
    class TrickRoom < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      def initialize(logic)
        super
        self.counter = 5
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :trick_room
      end
      # Show the message when the effect gets deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 122))
      end
    end
    class UpRoar < PokemonTiedEffectBase
      include Mechanics::ForceNextMove
      # Create a new Forced next move effect
      # @param logic [Battle::Logic]
      # @param target [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param counter [Integer] number of turn the move is forced to be used (including the current one)
      # @param targets [Array<PFM::PokemonBattler>]
      def initialize(logic, target, move, targets, counter)
        super(logic, target)
        init_force_next_move(move, targets, counter)
        @logic.scene.display_message_and_wait(provoke_message(@pokemon))
        wake_up_pokemons
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        message = triggered? ? calm_down_message(@pokemon) : continue_message(@pokemon)
        @logic.scene.display_message_and_wait(message)
      end
      # Is the effect in its last turn ?
      # @return [Boolean]
      def triggered?
        @counter == 1
      end
      # Name of the effect
      # @return [Symbol]
      def name
        :uproar
      end
      class SleepPrevention < EffectBase
        # Create a new effect
        # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
        # @param origin [PFM::PokemonBattler] origin of the effect
        def initialize(logic, origin)
          super(logic)
          @origin = origin
          self.counter = 3
        end
        # Function called when a status_prevention is checked
        # @param handler [Battle::Logic::StatusChangeHandler]
        # @param status [Symbol] :poison, :toxic, :confusion, :sleep, :freeze, :paralysis, :burn, :flinch, :cure
        # @param target [PFM::PokemonBattler]
        # @param launcher [PFM::PokemonBattler, nil] Potential launcher of a move
        # @param skill [Battle::Move, nil] Potential move used
        # @return [:prevent, nil] :prevent if the status cannot be applied
        def on_status_prevention(handler, status, target, launcher, skill)
          return if status != :sleep || @origin.dead?
          return handler.prevent_change do
            message_id = skill&.target == :user ? 712 : 709
            handler.scene.display_message_and_wait(parse_text_with_pokemon(19, message_id, target))
          end
        end
        # Name of the effect
        # @return [Symbol]
        def name
          :uproar_sleep_prevention
        end
      end
      private
      # Wake up all the asleep pokemons
      def wake_up_pokemons
        @logic.all_alive_battlers.each do |battler|
          next unless battler.asleep?
          @logic.status_change_handler.status_change_with_process(:cure, battler, message_overwrite: wake_up_message_id)
        end
      end
      # Id of the message displayed when the uproar wake up a battler
      # @return [Integer]
      def wake_up_message_id
        706
      end
      # Message displayed at the beginning of the uproar
      # @param user [PFM::PokemonBattler] the user of the upraor
      # @return [String]
      def provoke_message(user)
        parse_text_with_pokemon(19, 703, user)
      end
      # Message displayed at the end of the turn when the uproar continue
      # @param user [PFM::PokemonBattler] the user of the upraor
      # @return [String]
      def continue_message(user)
        parse_text_with_pokemon(19, 715, user)
      end
      # Message displayed at the end of the uproar
      # @param user [PFM::PokemonBattler] the user of the upraor
      # @return [String]
      def calm_down_message(user)
        parse_text_with_pokemon(19, 718, user)
      end
    end
    class Wish < PositionTiedEffectBase
      # Create a new position tied effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param bank [Integer] bank where the effect is tied
      # @param position [Integer] position where the effect is tied
      def initialize(logic, bank, position, hp)
        super(logic, bank, position)
        @pokemon = @logic.battler(bank, position)
        @hp = hp
        @counter = 2
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        pkm = @logic.battler(bank, position)
        return unless pkm&.alive?
        @logic.damage_handler.heal(pkm, @hp, test_heal_block: false) do
          @logic.scene.display_message_and_wait(message)
        end
      end
      def name
        return :wish
      end
      # Get the message text
      # @return [String]
      def message
        parse_text_with_pokemon(19, 700, @pokemon)
      end
    end
    class WonderRoom < EffectBase
      # Create a new effect
      # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
      # @param duration [Integer] duration of the effect
      def initialize(logic, targets, duration)
        super(logic)
        @logic.scene.display_message_and_wait(parse_text(18, 184))
        @targets = targets
        self.counter = duration
        switch_stats
      end
      # Function called when the effect has been deleted from the effects handler
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 185))
        switch_stats
      end
      def name
        :wonder_room
      end
      private
      # Switch the stats
      def switch_stats
        @targets.each do |target|
          next unless @logic.all_alive_battlers.include?(target)
          target.dfe_basis, target.dfs_basis = target.dfs_basis, target.dfe_basis
          log_error("#{target.name} Dfe:#{target.dfe_basis} Dfs:#{target.dfs_basis}")
        end
      end
    end
    class Rainbow < PositionTiedEffectBase
      # Create a new Rainbow effect (Water Pledge + Fire Pledge)
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        self.counter = 4
        effect_creation_text
      end
      # Give the effect chance modifier given to the Pokémon with this effect
      # @param move [Battle::Move::Basic] the move the chance modifier will be applied to
      # @return [Float, Integer] multiplier
      def effect_chance_modifier(move)
        return move.status_effects.any? { |move_status| move_status.status == :flinch } ? 1 : 2
      end
      # Display the message associated with the effect's creation
      def effect_creation_text
        @logic.scene.display_message_and_wait(parse_text(18, 170 + bank.clamp(0, 1)))
      end
      # Method called when the Effect is deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 172 + bank.clamp(0, 1)))
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :rainbow
      end
    end
    class SeaOfFire < PositionTiedEffectBase
      # Create a new Sea of Fire effect (Grass Pledge + Fire Pledge)
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        self.counter = 4
        effect_creation_text
      end
      # Function called at the end of a turn
      # @param logic [Battle::Logic] logic of the battle
      # @param scene [Battle::Scene] battle scene
      # @param battlers [Array<PFM::PokemonBattler>] all alive battlers
      def on_end_turn_event(logic, scene, battlers)
        battlers.each do |battler|
          next if battler.bank != @bank || battler.type_fire?
          logic.damage_handler.damage_change(sea_of_fire_effect(battler), battler)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 1162, battler))
        end
      end
      # Display the message associated with the effect's creation
      def effect_creation_text
        @logic.scene.display_message_and_wait(parse_text(18, 174 + bank.clamp(0, 1)))
      end
      # Method called when the Effect is deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 176 + bank.clamp(0, 1)))
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :sea_of_fire
      end
      private
      # Return the damage dealt to a Pokémon by the Sea of Fire effect
      def sea_of_fire_effect(target)
        return (target.max_hp / 8).clamp(1, Float::INFINITY)
      end
    end
    class Swamp < PositionTiedEffectBase
      # Create a Swamp effect (Grass Pledge + Water Pledge)
      # @param logic [Battle::Logic]
      # @param bank [Integer] bank where the effect acts
      def initialize(logic, bank)
        super(logic, bank, 0)
        self.counter = 4
        effect_creation_text
      end
      # Give the speed modifier over given to the Pokemon with this effect
      # @return [Float, Integer] multiplier
      def spd_modifier
        return 0.25
      end
      # Display the message associated with the effect's creation  
      def effect_creation_text
        @logic.scene.display_message_and_wait(parse_text(18, 178 + bank.clamp(0, 1)))
      end
      # Method called when the Effect is deleted
      def on_delete
        @logic.scene.display_message_and_wait(parse_text(18, 180 + bank.clamp(0, 1)))
      end
      # Get the name of the effect
      # @return [Symbol]
      def name
        return :swamp
      end
    end
  end
end
