module PFM
  # Class defining a Pokemon during a battle, it aim to copy its properties but also to have the methods related to the battle.
  class PokemonBattler < Pokemon
    include Hooks
    # List of properties to copy
    COPIED_PROPERTIES = %i[@id @form @given_name @code @ability @nature @iv_hp @iv_atk @iv_dfe @iv_spd @iv_ats @iv_dfs @ev_hp @ev_atk @ev_dfe @ev_spd @ev_ats @ev_dfs @trainer_id @trainer_name @step_remaining @loyalty @exp @hp @status @status_count @item_holding @captured_with @captured_in @captured_at @captured_level @gender @skill_learnt @ribbons @character @exp_rate @hp_rate @egg_at @egg_in]
    # List of properties to copy with transform
    TRANSFORM_COPIED_PROPERTIES = %i[@id @form @nature @ev_hp @ev_atk @ev_dfe @ev_spd @ev_ats @ev_dfs]
    # List of @battle_properties to copy with transform
    TRANSFORM_BP_METHODS = %i[ability weight height type1 type2 gender shiny atk_basis dfe_basis ats_basis dfs_basis spd_basis atk_stage dfe_stage ats_stage dfs_stage spd_stage]
    # Setter cache for the Transform properties to write
    TRANSFORM_SETTER_CACHE = TRANSFORM_BP_METHODS.to_h { |key| [key, :"#{key}="] }
    # List of properties to copy with Illusion
    ILLUSION_COPIED_PROPERTIES = %i[@id @form @gender @given_name @code @captured_with]
    # List of properties to copy back to original
    BACK_PROPERTIES = %i[@id @form @trainer_id @trainer_name @step_remaining @loyalty @hp @status @status_count @item_holding @captured_with @captured_in @captured_at @captured_level @gender @character @hp_rate]
    # @return [Array<Battle::Move>] the moveset of the Pokemon
    attr_reader :moveset
    # @return [Integer] number of turn the Pokemon is in battle
    attr_accessor :turn_count
    alias battle_turns turn_count
    # Last turn the Pokemon fought
    # @return [Integer]
    attr_accessor :last_battle_turn
    # Last turn the pokemon was sent out
    # @return [Integer]
    attr_accessor :last_sent_turn
    # @return [Battle::Move] last move that hit the pokemon
    attr_accessor :last_hit_by_move
    # @return [Integer] 3rd type (Mega / Move effect)
    attr_accessor :type3
    # @return [Integer] the ID of the party that control the Pokemon in the bank
    attr_accessor :party_id
    # @return [Integer] Bank where the Pokemon is supposed to be
    attr_accessor :bank
    # @return [Integer] Position of the Pokemon in the bank
    attr_accessor :position
    # @return [Integer] Place in the team of the Pokemon
    attr_accessor :place_in_party
    # Get the original Pokemon
    # @return [PFM::Pokemon]
    attr_reader :original
    # Get the move history
    # @return [Array<MoveHistory>]
    attr_reader :move_history
    # Get the damage history
    # @return [Array<DamageHistory>]
    attr_reader :damage_history
    # Get the successful move history
    # @return [Array<SuccessfulMoveHistory>]
    attr_reader :successful_move_history
    # Get the encounter list
    # @return [Array<PFM::PokemonBattler>]
    attr_reader :encounter_list
    # Get the information if the Pokemon is actually a follower or not (changing its go-in-out animation)
    # @return [Boolean]
    attr_accessor :is_follower
    # Get the bag of the battler
    # @return [PFM::Bag]
    attr_accessor :bag
    # Tell if the Pokemon already distributed its experience during the battle
    # @return [Boolean]
    attr_accessor :exp_distributed
    # Get the item held during battle
    # @return [Integer]
    attr_accessor :battle_item
    # Get the data associated to the item if needed
    # @return [Array]
    attr_reader :battle_item_data
    # @return [Boolean] set switching state
    attr_writer :switching
    # Mimic move that was replace by another move with its index
    # @return [Array<Battle::Move, Integer>]
    attr_accessor :mimic_move
    # Tell if the Pokemon has its item consumed
    # @return [Boolean]
    attr_accessor :item_consumed
    # @return [Symbol] the symbol of the consumed item
    attr_accessor :consumed_item
    # @return [Integer] number of times the pokémon has been knocked out
    attr_accessor :ko_count
    # Get the transform pokemon
    # @return [PFM::PokemonBattler]
    attr_reader :transform
    # Get the Illusion pokemon
    # @return [PFM::PokemonBattler]
    attr_reader :illusion
    # Create a new PokemonBattler from a Pokemon
    # @param original [PFM::Pokemon] original Pokemon (protected during the battle)
    # @param scene [Battle::Scene] current battle scene
    # @param max_level [Integer] new max level for Online battle
    def initialize(original, scene, max_level = Float::INFINITY)
      @original = original
      @battle_properties = {}
      @transform = @illusion = nil
      @scene = scene
      copy_properties
      copy_moveset
      @battle_stage = Array.new(7, 0)
      reset_states
      @battle_max_level = max_level
      @level = original.level < max_level ? original.level : max_level
      @type3 = 0
      @bank = 0
      @position = -1
      @place_in_party = 0
      @battle_item_data = []
      @battle_item = @item_holding
      @last_battle_turn = -1
      @last_sent_turn = -1
      @move_history = []
      @damage_history = []
      @successful_move_history = []
      @encounter_list = []
      @mega_evolved = false
      @exp_distributed = false
      @item_consumed = false
      @consumed_item = :__undef__
      @ko_count = 0
      self.hp = hp_rate > 0 ? (max_hp * hp_rate).to_i.clamp(1, max_hp) : 0
      initialize_set_is_follower
    end
    # Is the Pokemon able to fight ?
    # @return [Boolean]
    def can_fight?
      log_error("The pokemon #{self} has undefined position, it should be -1 if not in battle") unless @position
      return @position && @position >= 0 && !dead?
    end
    # Format the Battler for logging purpose
    # @return [String]
    def to_s
      "<PB:#{name},#{@bank},#{@position} lv=#{@level} hp=#{@hp_rate.round(3)} st=#{@status}>"
    end
    alias inspect to_s
    def from_party?
      $actors.include?(@original)
    end
    # Return if the Pokemon is in the player current team
    # @ Return [Boolean]
    def from_player_party?
      @party_id == 0 && @bank == 0
    end
    # Return the db_symbol of the current ability of the Pokemon
    # @return [Symbol]
    def ability_db_symbol
      return data_ability(ability || -1).db_symbol
    end
    # Return the db_symbol of the current ability of the Pokemon for battle
    # @return [Symbol]
    def battle_ability_db_symbol
      return :__undef__ if effects.has?(:ability_suppressed) && $scene.is_a?(Battle::Scene)
      return ability_db_symbol
    end
    # Tell if the pokemon has an ability
    # @param db_symbol [Symbol] db_symbol of the ability
    # @return [Boolean]
    def has_ability?(db_symbol)
      return battle_ability_db_symbol == db_symbol
    end
    # Return the db_symbol of the current item the Pokemon is holding
    # @return [Symbol]
    def item_db_symbol
      data_item(@battle_item || -1).db_symbol
    end
    # Get the item for battle
    # @return [Symbol]
    def battle_item_db_symbol
      return :__undef__ if @scene.logic.terrain_effects.has?(&:on_held_item_use_prevention)
      return :__undef__ if battle_ability_db_symbol == :klutz
      return item_db_symbol
    end
    # Tell if the pokemon hold an item
    # @param db_symbol [Symbol] db_symbol of the item
    # @return [Boolean]
    def hold_item?(db_symbol)
      return false if @scene.logic.terrain_effects.has?(&:on_held_item_use_prevention)
      return false if effects.has?(:item_stolen) || effects.has?(:item_burnt)
      return false if db_symbol == :__undef__
      return battle_item_db_symbol == db_symbol
    end
    # Tell if the pokemon hold a berry
    # @param db_symbol [Symbol] db_symbol of the item
    # @return [Boolean]
    def hold_berry?(db_symbol)
      return false unless data_item(db_symbol)&.socket == 4
      return hold_item?(db_symbol)
    end
    # Add a move to the move history
    # @param move [Battle::Move]
    # @param targets [Array<PFM::PokemonBattler>]
    def add_move_to_history(move, targets)
      @move_history << MoveHistory.new(move, targets, attack_order)
    end
    # Add a damage to the damage history
    # @note This method should only be used for successful damages!!!
    # @param damage [Integer]
    # @param launcher [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @param ko [Boolean]
    def add_damage_to_history(damage, launcher, move, ko)
      @damage_history << DamageHistory.new(damage, launcher, move, ko)
    end
    # Add a successful move to the successful move history
    # @note This method should only be used for successful moves!!!
    # @param move [Battle::Move]
    # @param targets [Array<PFM::PokemonBattler>]
    def add_successful_move_to_history(move, targets)
      @successful_move_history << SuccessfulMoveHistory.new(move, targets, attack_order)
    end
    # Add a battler to the encounter list
    # @note The battler is not added if it is already present in the list
    # @param battler [PFM::PokemonBattler]
    def add_battler_to_encounter_list(battler)
      @encounter_list << battler unless @encounter_list.include?(battler)
    end
    # Delete a battler to the encounter list
    # @param battler [PFM::PokemonBattler]
    def delete_battler_to_encounter_list(battler)
      @encounter_list.delete(battler)
    end
    # Test if the Pokemon has encountered the battler
    # @param battler [PFM::PokemonBattler]
    def encountered?(battler)
      return @encounter_list.include?(battler)
    end
    # Test if the last move was of a certain symbol
    # @param db_symbol [Symbol] symbol of the move
    def last_move_is?(db_symbol)
      return @move_history.last&.db_symbol == db_symbol
    end
    # Test if the last successful move was of a certain symbol
    # @param db_symbol [Symbol] symbol of the move
    def last_successful_move_is?(db_symbol)
      return @successful_move_history.last&.db_symbol == db_symbol
    end
    # Test if the Pokemon can use a move
    # @return [Boolean]
    def can_move?
      return false if moveset.all? { |move| move.pp == 0 || move.disabled?(self) }
      return true
    end
    # List of abilities that ignore abilities
    ABILITIES_IGNORING_ABILITIES = %i[mold_breaker teravolt turboblaze]
    # List of moves that ignore abilities
    MOVES_IGNORING_ABILITIES = %i[sunsteel_strike moongeist_beam photon_geyser]
    # Test if the Pokemon can have a lowering stat or have its move canceled (return false if the Pokemon has mold breaker)
    #
    # List of ability that should be affected:
    # :battle_armor|:clear_body|:damp|:dry_skin|:filter|:flash_fire|:flower_gift|:heatproof|:hyper_cutter|:immunity|:inner_focus|:insomnia|
    # :keen_eye|:leaf_guard|:levitate|:lightning_rod|:limber|:magma_armor|:marvel_scale|:motor_drive|:oblivious|:own_tempo|:sand_veil|:shell_armor|
    # :shield_dust|:simple|:snow_cloak|:solid_rock|:soundproof|:sticky_hold|:storm_drain|:sturdy|:suction_cups|:tangled_feet|:thick_fat|:unaware|:vital_spirit|
    # :volt_absorb|:water_absorb|:water_veil|:white_smoke|:wonder_guard|:big_pecks|:contrary|:friend_guard|:heavy_metal|:light_metal|:magic_bounce|:multiscale|
    # :sap_sipper|:telepathy|:wonder_skin|:aroma_veil|:bulletproof|:flower_veil|:fur_coat|:overcoat|:sweet_veil|:dazzling|:disguise|:fluffy|:queenly_majesty|
    # :water_bubble|:mirror_armor|:punk_rock|:ice_scales|:ice_face|:pastel_veil||:armor_tail|:earth_eater|:good_as_gold|:purifying_salt|:well_backed_body|:wind_rider
    # @param test [Boolean] if the test should be done
    # @return [Boolean] potential changed result
    def can_be_lowered_or_canceled?(test = true)
      return false unless test
      return test unless current_ability_ignoring_ability? || current_move_ignoring_ability?
      unless ability_used
        @scene.visual.show_ability(self)
        self.ability_used = true
      end
      return false
    end
    # Tell if the Pokémon has a ability ignoring ability
    # @return [Boolean]
    def current_ability_ignoring_ability?
      return true if ABILITIES_IGNORING_ABILITIES.include?(self.battle_ability_db_symbol)
      result = $scene.logic.turn_actions.any? do |a|
        a.is_a?(Battle::Actions::Attack) && Battle::Actions::Attack.from(a).launcher == self && self.has_ability?(:mycelium_might) && Battle::Actions::Attack.from(a).move.status?
      end
      return result
    end
    # Tell if the Pokemon has an ability ignoring abilities
    # @return [Boolean]
    def current_move_ignoring_ability?
      return $scene.logic.turn_actions.any? do |a|
        a.is_a?(Battle::Actions::Attack) && Battle::Actions::Attack.from(a).launcher == self && MOVES_IGNORING_ABILITIES.include?(Battle::Actions::Attack.from(a).move.db_symbol)
      end
    end
    # Return the Pokemon rareness
    # @return [Integer]
    def rareness
      @original.rareness
    end
    # Return the base HP
    # @return [Integer]
    def base_hp
      data.base_hp
    end
    # Copy all the properties back to the original pokemon
    def copy_properties_back_to_original
      return if @scene.battle_info.max_level
      return if Storage::HEAL_AND_CURE_POKEMON && @scene.battle_info.caught_pokemon == self && !$actors.include?(self.original)
      @battle_properties.clear
      self.transform = nil
      self.illusion = nil
      original = @original
      BACK_PROPERTIES.each do |ivar_name|
        original.instance_variable_set(ivar_name, instance_variable_get(ivar_name))
      end
      @moveset.each_with_index do |move, i|
        @original.skills_set[i]&.pp = move.pp
      end
    end
    # Function that resets everything from the pokemon once it got switched out of battle
    def reset_states
      @battle_stage.map! {0 }
      @battle_properties.clear
      exec_hooks(PFM::PokemonBattler, :on_reset_states, binding)
      @switching = false
      @turn_count = 0
      @type1 = @type2 = @type3 = nil
      if mimic_move
        @moveset[mimic_move.last] = mimic_move.first
        @moveset.compact!
        @mimic_move = nil
      end
    end
    # if the pokemon is switching during this turn
    # @return [Boolean]
    def switching?
      @switching
    end
    # Confuse the Pokemon
    # @param _ [Boolean] (ignored)
    # @return [Boolean] if the pokemon has been confused
    def status_confuse(_ = false)
      return false if dead? || confused?
      effects.add(Battle::Effects::Confusion.new(@scene.logic, self))
      return true
    end
    # Is the Pokemon confused?
    # @return [Boolean]
    def confused?
      return effects.has?(:confusion)
    end
    # Apply the flinch effect
    # @param forced [Boolean] this parameter is ignored since flinch effect is volatile
    def apply_flinch(forced = false)
      old_effect = effects.get(:flinch)
      return if old_effect && !old_effect.dead?
      effects.add(Battle::Effects::Flinch.new(@scene.logic, self))
    end
    # Transform this pokemon into another pokemon
    # @param pokemon [PFM::PokemonBattler, nil]
    def transform=(pokemon)
      @transform = pokemon
      return unless @moveset
      copy_transform_properties
      copy_transform_moveset
    end
    # Setup the Illusion of the Pokémon
    def illusion=(pokemon)
      @illusion = pokemon
      copy_illusion_properties
    end
    # Is the pokemon affected by the terrain ?
    # @return [Boolean]
    def affected_by_terrain?
      return grounded? && !effects.has?(&:out_of_reach?)
    end
    # Neutralize a type on the Pokemon
    # @param types [Array<Integer>]
    # @param default [Integer] (default: id of :normal) type applied when no other types are defined
    def ignore_types(*types, default: data_type(:normal).id)
      self.type1, self.type2, self.type3 = [type1, type2, type3].reject { |t| types.include?(t) }
      self.type1 = default unless type1
    end
    # Change the type of the pokemons
    # @param types [Array<Integer>]
    def change_types(*types)
      self.type1, self.type2, self.type3 = types
    end
    # Is the Pokemon typeless?
    # @return [Boolean]
    def typeless?
      return type1 == 0 && type2 == 0 && type3 == 0
    end
    # Copy the moveset upon level up
    # @param moveset_before [Array<PFM::Skill>]
    def level_up_copy_moveset(moveset_before)
      if moveset_before.size < original.skills_set.size
        indexes = moveset_before.size.upto(original.skills_set.size - 1).to_a
      else
        indexes = (moveset_before - original.skills_set).map { |i| moveset_before.index(i) }
      end
      moveset = @transform ? @moveset_before_transform : @moveset
      moveset = @moveset unless @moveset_before_transform
      indexes.each do |i|
        next unless (skill = original.skills_set[i])
        moveset[i] = Battle::Move[skill.symbol].new(skill.id, skill.pp, skill.ppmax, @scene)
      end
    end
    # Copy some important data upon level up
    def level_up_copy
      self.level = @original.level
      self.exp = @original.exp
      return level_up_stat_refresh if @transform
      self.hp = original.hp
      %i[@ev_hp @ev_atk @ev_dfe @ev_spd @ev_ats @ev_dfs].each do |ivar_name|
        instance_variable_set(ivar_name, original.instance_variable_get(ivar_name))
      end
    end
    private
    # Copy the properties of the original pokemon
    def copy_properties
      original = @original
      COPIED_PROPERTIES.each do |ivar_name|
        instance_variable_set(ivar_name, original.instance_variable_get(ivar_name))
      end
      copy_transform_properties if @transform
      copy_illusion_properties if @illusion
    end
    # Copy the properties of a transformed pokemon
    def copy_transform_properties
      if @transform
        @properties_before_transform = TRANSFORM_COPIED_PROPERTIES.map { |ivar_name| instance_variable_get(ivar_name) }
        TRANSFORM_COPIED_PROPERTIES.each { |ivar| instance_variable_set(ivar, @transform.instance_variable_get(ivar)) }
        @battle_properties_before_transform = TRANSFORM_BP_METHODS.map { |key| send(key) }
        TRANSFORM_SETTER_CACHE.each { |key, setter| send(setter, @transform.send(key)) }
      else
        if @properties_before_transform
          TRANSFORM_COPIED_PROPERTIES.map.with_index { |ivar_name, index| instance_variable_set(ivar_name, @properties_before_transform[index]) }
          TRANSFORM_BP_METHODS.map.with_index { |key, index| send(TRANSFORM_SETTER_CACHE[key], @battle_properties_before_transform[index]) }
          @properties_before_transform = nil
        end
      end
    end
    # Copy the properties of a pokemon under Illusion
    def copy_illusion_properties
      if @illusion
        change_types(type1, type2, type3)
        @properties_before_illusion ||= ILLUSION_COPIED_PROPERTIES.map { |ivar_name| instance_variable_get(ivar_name) }
        ILLUSION_COPIED_PROPERTIES.each do |ivar_name|
          instance_variable_set(ivar_name, @illusion.instance_variable_get(ivar_name))
        end
      else
        if @properties_before_illusion
          ILLUSION_COPIED_PROPERTIES.map.with_index { |ivar_name, index| instance_variable_set(ivar_name, @properties_before_illusion[index]) }
          @properties_before_illusion = nil
        end
      end
    end
    # Copy the moveset of the original Pokemon
    def copy_moveset
      @skills_set = @moveset = @original.skills_set.map do |skill|
        next(Battle::Move[skill.symbol].new(skill.db_symbol, skill.pp, skill.ppmax, @scene))
      end
      @moveset << Battle::Move.new(:__undef__, 0, 9001, @scene) if @moveset.empty?
    end
    # Copy the moveset of the pokemon it transforms
    def copy_transform_moveset
      if @transform
        @moveset_before_transform ||= @moveset
        @skills_set = @moveset = @transform.skills_set.map do |skill|
          next(Battle::Move[skill.symbol].new(skill.id, 5, 5, @scene))
        end
        @moveset << Battle::Move.new(0, 0, 9001, @scene) if @moveset.empty?
      else
        if @moveset_before_transform
          @moveset = @skills_set = @moveset_before_transform
          @moveset_before_transform = nil
        end
      end
    end
    # Function that sets the is_follower variable (for animation purpose)
    def initialize_set_is_follower
      return @is_follower = false unless $actors.include?(original) && defined?(Yuki::FollowMe)
      return @is_follower = false unless Yuki::FollowMe.enabled
      @is_follower = $actors.index(original).to_i < Yuki::FollowMe.pokemon_count
    end
    public
    # List of the UIs able to omit the Illusion form of the Pokemon
    # @return [Array<Class>]
    ILLUSION_PROOF_SCENES = [GamePlay::Party_Menu, GamePlay::Summary]
    # Return the current ID of the Pokemon
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the id saved before Illusion was triggered
    # @return [Integer]
    def id
      if @illusion && ILLUSION_PROOF_SCENES.include?($scene.class)
        index = ILLUSION_COPIED_PROPERTIES.index(:@id)
        return @properties_before_illusion[index]
      end
      return @id
    end
    # Return the current form of the Pokemon
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the form saved before Illusion was triggered
    # @return [Integer]
    def form
      if @illusion && ILLUSION_PROOF_SCENES.include?($scene.class)
        index = ILLUSION_COPIED_PROPERTIES.index(:@form)
        return @properties_before_illusion[index]
      end
      return @form
    end
    # Return the current given name of the Pokemon
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the given_name saved before Illusion was triggered
    # @return [String]
    def given_name
      if @illusion && ILLUSION_PROOF_SCENES.include?($scene.class)
        index = ILLUSION_COPIED_PROPERTIES.index(:@given_name)
        return @properties_before_illusion[index] || name
      end
      return super
    end
    # Return the current name of the Pokemon
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the name of the original
    # @return [String]
    def name
      return Studio::Text.get(0, @step_remaining == 0 ? (@illusion && !ILLUSION_PROOF_SCENES.include?($scene.class) ? @id : original.id) : 0)
    end
    # Return the current code of the Pokemon
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the code saved before Illusion was triggered
    # @return [Integer]
    def code
      if @illusion && ILLUSION_PROOF_SCENES.include?($scene.class)
        index = ILLUSION_COPIED_PROPERTIES.index(:@code)
        return @properties_before_illusion[index]
      end
      return @code
    end
    # Return the current ball ID the Pokemon was captured with
    # If the current UI is one defined in PFM::PokemonBattler::ILLUSION_PROOF_SCENES
    # then it'll send the ball id saved before Illusion was triggered
    # @return [Integer]
    def captured_with
      if @illusion && ILLUSION_PROOF_SCENES.include?($scene.class)
        index = ILLUSION_COPIED_PROPERTIES.index(:@captured_with)
        return @properties_before_illusion[index]
      end
      return @captured_with
    end
    # Return the cry file name of the Pokemon
    # If the Pokemon is under the effect of Illusion, returns the cry from the target of the ability
    # @return [String]
    def cry
      return @illusion&.cry if @illusion && !ILLUSION_PROOF_SCENES.include?($scene.class)
      return super
    end
    # Return the battler's combat property
    # @return [Integer]
    def atk_basis
      return @battle_properties[:atk_basis] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def atk_basis=(value)
      @battle_properties[:atk_basis] = value
    end
    # Restore the battler's property original value
    def restore_atk_basis
      @battle_properties.delete(:atk_basis)
    end
    # Return the battler's combat property
    # @return [Integer]
    def ats_basis
      return @battle_properties[:ats_basis] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def ats_basis=(value)
      @battle_properties[:ats_basis] = value
    end
    # Restore the battler's property original value
    def restore_ats_basis
      @battle_properties.delete(:ats_basis)
    end
    # Return the battler's combat property
    # @return [Integer]
    def dfe_basis
      return @battle_properties[:dfe_basis] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def dfe_basis=(value)
      @battle_properties[:dfe_basis] = value
    end
    # Restore the battler's property original value
    def restore_dfe_basis
      @battle_properties.delete(:dfe_basis)
    end
    # Return the battler's combat property
    # @return [Integer]
    def dfs_basis
      return @battle_properties[:dfs_basis] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def dfs_basis=(value)
      @battle_properties[:dfs_basis] = value
    end
    # Restore the battler's property original value
    def restore_dfs_basis
      @battle_properties.delete(:dfs_basis)
    end
    # Return the battler's combat property
    # @return [Integer]
    def spd_basis
      return @battle_properties[:spd_basis] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def spd_basis=(value)
      @battle_properties[:spd_basis] = value
    end
    # Restore the battler's property original value
    def restore_spd_basis
      @battle_properties.delete(:spd_basis)
    end
    # Return the battler's combat property
    # @return [Integer]
    def nature_id
      return @battle_properties[:nature_id] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def nature_id=(value)
      @battle_properties[:nature_id] = value
    end
    # Restore the battler's property original value
    def restore_nature_id
      @battle_properties.delete(:nature_id)
    end
    # Return the battler's combat property
    # @return [Integer]
    def ability
      return @battle_properties[:ability] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def ability=(value)
      return log_error("Wrong ability id : #{value}") if data_ability(value).id != value && !value.nil?
      @battle_properties[:ability] = value
    end
    # Restore the battler's property original value
    def restore_ability
      @ability = original.ability
    end
    # Return the battler's combat property
    # @return [Integer]
    def height
      return @battle_properties[:height] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def height=(value)
      @battle_properties[:height] = value
    end
    # Restore the battler's property original value
    def restore_height
      @battle_properties.delete(:height)
    end
    # Return the battler's combat property
    # @return [Integer]
    def weight
      w = @battle_properties[:weight] || super
      w *= 2 if has_ability?(:heavy_metal)
      w /= 2 if has_ability?(:light_metal)
      return w
    end
    # Set the battler's combat property
    # @param value [Integer]
    def weight=(value)
      @battle_properties[:weight] = value
    end
    # Restore the battler's property original value
    def restore_weight
      @battle_properties.delete(:weight)
    end
    # Return the battler's combat property
    # @return [Integer]
    def gender
      if @illusion && $scene.is_a?(GamePlay::Party_Menu)
        index = ILLUSION_COPIED_PROPERTIES.index(:@gender)
        return @battle_properties[:gender] || @properties_before_illusion[index]
      end
      return @battle_properties[:gender] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def gender=(value)
      return log_info("Gender changed to #{value}") && @battle_properties[:gender] = value.clamp(0, 2) if value.is_a?(Integer)
      @battle_properties[:gender] = super
    end
    # Restore the battler's property original value
    def restore_gender
      @battle_properties.delete(:gender)
    end
    # Return the battler's combat property
    # @return [Integer]
    def rareness
      return @battle_properties[:rareness] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def rareness=(value)
      @battle_properties[:rareness] = value.clamp(0, 255)
    end
    # Restore the battler's property original value
    def restore_rareness
      @battle_properties.delete(:rareness)
    end
    # Return the battler's combat property
    # @return [Integer]
    def type1
      return @battle_properties[:type1] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def type1=(value)
      @battle_properties[:type1] = value
    end
    # Restore the battler's property original value
    def restore_type1
      @battle_properties.delete(:type1)
    end
    # Return the battler's combat property
    # @return [Integer]
    def type2
      return @battle_properties[:type2] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def type2=(value)
      @battle_properties[:type2] = value
    end
    # Restore the battler's property original value
    def restore_type2
      @battle_properties.delete(:type2)
    end
    # Return the battler's combat property
    # @return [Integer]
    def type3
      return @battle_properties[:type3] || super
    end
    # Set the battler's combat property
    # @param value [Integer]
    def type3=(value)
      @battle_properties[:type3] = value
    end
    # Restore the battler's property original value
    def restore_type3
      @battle_properties.delete(:type3)
    end
    # Restore all Pokemon types
    def restore_types
      restore_type1
      restore_type2
      restore_type3
    end
    public
    # Minimal value of the stat modifier level (stage)
    MIN_STAGE = -6
    # Maximal value of the stat modifier level (stage)
    MAX_STAGE = 6
    # Return the current atk
    # @return [Integer]
    def atk
      raw_atk = (atk_basis * atk_modifier).floor
      return @scene.logic.each_effects(self).reduce(raw_atk) do |product, e|
        (product * e.atk_modifier).floor
      end
    end
    # Return the current dfe
    # @return [Integer]
    def dfe
      raw_dfe = (dfe_basis * dfe_modifier).floor
      return @scene.logic.each_effects(self).reduce(raw_dfe) do |product, e|
        (product * e.dfe_modifier).floor
      end
    end
    # Return the current spd
    # @return [Integer]
    def spd
      raw_spd = (spd_basis * spd_modifier).floor
      return @scene.logic.each_effects(self).reduce(raw_spd) do |product, e|
        (product * e.spd_modifier).floor
      end
    end
    # Return the current ats
    # @return [Integer]
    def ats
      raw_ats = (ats_basis * ats_modifier).floor
      return @scene.logic.each_effects(self).reduce(raw_ats) do |product, e|
        (product * e.ats_modifier).floor
      end
    end
    # Return the current dfs
    # @return [Integer]
    def dfs
      raw_dfs = (dfs_basis * dfs_modifier).floor
      return @scene.logic.each_effects(self).reduce(raw_dfs) do |product, e|
        (product * e.dfs_modifier).floor
      end
    end
    # Return the atk modifier
    # @return [Float] the multiplier
    def atk_modifier
      return stat_multiplier_regular(atk_stage)
    end
    # Return the dfe modifier
    # @return [Float] the multiplier
    def dfe_modifier
      return stat_multiplier_regular(dfe_stage)
    end
    # Return the spd modifier
    # @return [Float] the multiplier
    def spd_modifier
      return stat_multiplier_regular(spd_stage)
    end
    # Return the ats modifier
    # @return [Float] the multiplier
    def ats_modifier
      return stat_multiplier_regular(ats_stage)
    end
    # Return the dfs modifier
    # @return [Float] the multiplier
    def dfs_modifier
      return stat_multiplier_regular(dfs_stage)
    end
    # Return the atk stage
    # @return [Integer]
    def atk_stage
      return @battle_stage[Configs.stats.atk_stage_index]
    end
    # Return the dfe stage
    # @return [Integer]
    def dfe_stage
      return @battle_stage[Configs.stats.dfe_stage_index]
    end
    # Return the spd stage
    # @return [Integer]
    def spd_stage
      return @battle_stage[Configs.stats.spd_stage_index]
    end
    # Return the ats stage
    # @return [Integer]
    def ats_stage
      return @battle_stage[Configs.stats.ats_stage_index]
    end
    # Return the dfs stage
    # @return [Integer]
    def dfs_stage
      return @battle_stage[Configs.stats.dfs_stage_index]
    end
    # Return the evasion stage
    # @return [Integer]
    def eva_stage
      return @battle_stage[Configs.stats.eva_stage_index]
    end
    # Return the accuracy stage
    # @return [Integer]
    def acc_stage
      return @battle_stage[Configs.stats.acc_stage_index]
    end
    # Return the regular stat multiplier
    # @param stage [Integer] the value of the stage
    # @return [Float] the multiplier
    def stat_multiplier_regular(stage)
      if stage >= 0
        return (2 + stage) / 2.0
      else
        return 2.0 / (2 - stage)
      end
    end
    # Return the accuracy related stat multiplier
    # @param stage [Integer] the value of the stage
    # @return [Float] the multiplier
    def stat_multiplier_acceva(stage)
      if stage >= 0
        return (3 + stage) / 3.0
      else
        return 3.0 / (3 - stage)
      end
    end
    # Change a stat stage
    # @param stat_id [Integer] id of the stat : 0 = atk, 1 = dfe, 2 = spd, 3 = ats, 4 = dfs, 5 = eva, 6 = acc
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_stat(stat_id, amount)
      last_value = @battle_stage[stat_id]
      @battle_stage[stat_id] = (@battle_stage[stat_id] + amount).clamp(MIN_STAGE, MAX_STAGE)
      return @battle_stage[stat_id] - last_value
    end
    # Change the atk stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_atk(amount)
      return change_stat(Configs.stats.atk_stage_index, amount)
    end
    # Change the dfe stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_dfe(amount)
      return change_stat(Configs.stats.dfe_stage_index, amount)
    end
    # Change the spd stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_spd(amount)
      return change_stat(Configs.stats.spd_stage_index, amount)
    end
    # Change the ats stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_ats(amount)
      return change_stat(Configs.stats.ats_stage_index, amount)
    end
    # Change the dfs stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_dfs(amount)
      return change_stat(Configs.stats.dfs_stage_index, amount)
    end
    # Change the eva stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_eva(amount)
      return change_stat(Configs.stats.eva_stage_index, amount)
    end
    # Change the acc stage
    # @param amount [Integer] the amount to change on the stat stage
    # @return [Integer] the difference between the current and the last stage value
    def change_acc(amount)
      return change_stat(Configs.stats.acc_stage_index, amount)
    end
    # Set a stat stage
    # @param stat_id [Integer] id of the stat : 0 = atk, 1 = dfe, 2 = spd, 3 = ats, 4 = dfs, 5 = eva, 6 = acc
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def set_stat_stage(stat_id, value)
      return @battle_stage[stat_id] = value.clamp(MIN_STAGE, MAX_STAGE)
    end
    # Set the acc stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def acc_stage=(value)
      return set_stat_stage(Configs.stats.acc_stage_index, value)
    end
    # Set the spd stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def spd_stage=(value)
      return set_stat_stage(Configs.stats.spd_stage_index, value)
    end
    # Set the atk stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def atk_stage=(value)
      return set_stat_stage(Configs.stats.atk_stage_index, value)
    end
    # Set the ats stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def ats_stage=(value)
      return set_stat_stage(Configs.stats.ats_stage_index, value)
    end
    # Set the dfe stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def dfe_stage=(value)
      return set_stat_stage(Configs.stats.dfe_stage_index, value)
    end
    # Set the dfs stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def dfs_stage=(value)
      return set_stat_stage(Configs.stats.dfs_stage_index, value)
    end
    # Set the eva stage
    # @param value [Integer] the new value of the stat stage
    # @return [Integer] the new stat stage value
    def eva_stage=(value)
      return set_stat_stage(Configs.stats.eva_stage_index, value)
    end
    public
    # Check if the pokemon is grounded
    # @return [Boolean]
    def grounded?
      exec_hooks(PokemonBattler, :force_grounded, binding)
      exec_hooks(PokemonBattler, :force_flying, binding)
      return true
    rescue Hooks::ForceReturn => e
      log_data("\# pokemon = #{self}")
      log_data("\# FR: grounded? #{e.data} from #{e.hook_name} (#{e.reason})")
      return e.data
    end
    class << self
      # Register a hook forcing Pokemon to be grounded
      # @param reason [String] reason of the force_grounded hook
      # @yieldparam pokemon [PFM::PokemonBattler]
      # @yieldparam scene [Battle::Scene]
      # @yieldreturn [Boolean] if the Pokemon is forced to be grounded
      def register_force_grounded_hook(reason)
        Hooks.register(PokemonBattler, :force_grounded, reason) do
          force_return(true) if yield(self, @scene)
        end
      end
      # Register a hook forcing Pokemon to be flying (ie not grounded)
      # @param reason [String] reason of the force_flying hook
      # @yieldparam pokemon [PFM::PokemonBattler]
      # @yieldparam scene [Battle::Scene]
      # @yieldreturn [Boolean] if the Pokemon is forced to be "flying"
      def register_force_flying_hook(reason)
        Hooks.register(PokemonBattler, :force_flying, reason) do
          force_return(false) if yield(self, @scene)
        end
      end
    end
    register_force_grounded_hook('PSDK grounded: Gravity') { |_, scene| scene.logic.terrain_effects.has?(:gravity) }
    register_force_grounded_hook('PSDK grounded: Iron Ball') { |pokemon| pokemon.hold_item?(:iron_ball) }
    register_force_grounded_hook('PSDK grounded: Smack Down') { |pokemon| pokemon.effects.has?(:smack_down) }
    register_force_grounded_hook('PSDK grounded: Ingrain') { |pokemon| pokemon.effects.has?(:ingrain) }
    register_force_flying_hook('PSDK flying: Air Balloon') { |pokemon| pokemon.hold_item?(:air_balloon) }
    register_force_flying_hook('PSDK flying: Fly type') { |pokemon, _| pokemon.type_fly? }
    register_force_flying_hook('PSDK flying: Levitate') { |pokemon| pokemon.has_ability?(:levitate) }
    public
    # Get the effect handler
    # @return [Battle::Effects::EffectsHandler]
    attr_reader :effects
    Hooks.register(PFM::PokemonBattler, :on_reset_states, 'PSDK reset effects') do
      @effects = Battle::Effects::EffectsHandler.new
    end
    # Evaluate all the effects related to this Pokemon
    # @param yielder [Proc] proc to call with the effect
    def evaluate_effects(yielder)
      yielder.call(status_effect)
      yielder.call(ability_effect)
      yielder.call(item_effect)
      effects.each(&yielder)
      @scene.logic.position_effects[bank][position]&.each(&yielder)
    end
    # Get the status effect
    # @return [Battle::Effects::Status]
    def status_effect
      if !@status_effect || @status_effect.status_id != @status
        @status_effect = Battle::Effects::Status.new(@scene.logic, self, Configs.states.symbol(@status))
      end
      return @status_effect
    end
    # Get the ability effect
    # @return [Battle::Effects::Ability]
    def ability_effect
      db_symbol = battle_ability_db_symbol
      db_symbol = :__undef__ unless has_ability?(db_symbol)
      @ability_effect = Battle::Effects::Ability.new(@scene.logic, self, db_symbol) if !@ability_effect || @ability_effect.db_symbol != db_symbol
      return @ability_effect
    end
    # Get the item effect
    # @return [Battle::Effects::Item]
    def item_effect
      db_symbol = battle_item_db_symbol
      db_symbol = :__undef__ unless hold_item?(db_symbol)
      @item_effect = Battle::Effects::Item.new(@scene.logic, self, db_symbol) if !@item_effect || @item_effect.db_symbol != db_symbol
      return @item_effect
    end
    public
    # Class defining an history of move use
    class MoveHistory
      # Get the turn when it was used
      # @return [Integer]
      attr_reader :turn
      # Get the move that was used
      # @return [Battle::Move]
      attr_reader :move
      # Get the target that were affected by the move
      # @return [Array<PFM::PokemonBattler>]
      attr_reader :targets
      # Get the actual move object that was used
      # @return [Battle::Move]
      attr_reader :original_move
      # Get the attack order of the Pokemon
      # @return [Integer]
      attr_reader :attack_order
      # Create a new Move History
      # @param move [Battle::Move]
      # @param targets [Array<PFM::PokemonBattler>]
      # @param attack_order [Integer]
      def initialize(move, targets, attack_order)
        @original_move = move
        @move = move.dup
        @turn = $game_temp.battle_turn
        @targets = targets
        @attack_order = attack_order
      end
      # Tell if the move was used during last turn
      # @return [Boolean]
      def last_turn?
        return @turn == $game_temp.battle_turn - 1
      end
      # Tell if the move was used during the current turn
      # @return [Boolean]
      def current_turn?
        return @turn == $game_temp.battle_turn
      end
      # Get the db_symbol of the move
      # @return [Symbol]
      def db_symbol
        return @move.db_symbol
      end
    end
    # History specialization for successful moves
    class SuccessfulMoveHistory < MoveHistory
    end
    public
    # Class defining an history of damages took
    class DamageHistory
      # Get the turn when it was used
      # @return [Integer]
      attr_reader :turn
      # Get the amount of damage took
      # @return [Integer]
      attr_reader :damage
      # Get the launcher that cause the damages
      # @return [PFM::PokemonBattler, nil]
      attr_reader :launcher
      # Get the move that cause the damages
      # @return [Battle::Move, nil]
      attr_reader :move
      # Get if the Pokemon was knocked out
      # @return [Boolean]
      attr_reader :ko
      # Create a new Damage History
      # @param damage [Integer]
      # @param launcher [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param ko [Boolean]
      def initialize(damage, launcher, move, ko)
        @turn = $game_temp.battle_turn
        @damage = damage
        @launcher = launcher
        @move = move
        @ko = ko
      end
      # Tell if the move was used during last turn
      # @return [Boolean]
      def last_turn?
        return @turn == $game_temp.battle_turn - 1
      end
      # Tell if the move was used during the current turn
      # @return [Boolean]
      def current_turn?
        return @turn == $game_temp.battle_turn
      end
    end
  end
end
