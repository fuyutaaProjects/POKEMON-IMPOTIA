module Battle
  # Generic class describing a move
  class Move
    include Hooks
    # @return [Hash{Symbol => Class}] list of the registered moves
    REGISTERED_MOVES = Hash.new(Move)
    # ID of the move in the database
    # @return [Integer]
    attr_reader :id
    # Number of pp the move currently has
    # @return [Integer]
    attr_reader :pp
    # Maximum number of ppg the move currently has
    # @return [Integer]
    attr_reader :ppmax
    # if the move has been used
    # @return [Boolean]
    attr_accessor :used
    # Number of time the move was used consecutively
    # @return [Integer]
    attr_accessor :consecutive_use_count
    # @return [Battle::Logic]
    attr_reader :logic
    # @return [Battle::Scene]
    attr_reader :scene
    # @return [Battle::Move]
    attr_accessor :original
    # Number of damage dealt last time the move was used (to be used with move history)
    # @return [Integer]
    attr_accessor :damage_dealt
    # The original target of the move (to be used with Magic Bounce/Coat)
    # @return [Array<PFM::PokemonBattler>]
    attr_accessor :original_target
    # Create a new move
    # @param db_symbol [Symbol] db_symbol of the move in the database
    # @param pp [Integer] number of pp the move currently has
    # @param ppmax [Integer] maximum number of pp the move currently has
    # @param scene [Battle::Scene] current battle scene
    def initialize(db_symbol, pp, ppmax, scene)
      data = data_move(db_symbol)
      @id = data.id
      @db_symbol = data.db_symbol
      @pp = pp
      @ppmax = ppmax
      @used = false
      @consecutive_use_count = 0
      @effectiveness = 1
      @damage_dealt = 0
      @original_target = []
      @scene = scene
      @logic = scene.logic
    end
    # Format move for logging purpose
    # @return [String]
    def to_s
      "<PM:#{name},#{@consecutive_use_count} pp=#{@pp}>"
    end
    alias inspect to_s
    # Clone the move and give a reference to the original one
    def clone
      clone = super
      clone.original ||= self
      raise 'This function looks badly implement, just want to know where it is called'
    end
    # Return the data of the skill
    # @return [Studio::Move]
    def data
      return data_move(@db_symbol || @id)
    end
    # Return the name of the skill
    def name
      return data.name
    end
    # Return the skill description
    # @return [String]
    def description
      return data.description
    end
    # Return the battle engine method of the move
    # @return [Symbol]
    def be_method
      return data.be_method
    end
    alias symbol be_method
    # Return the text of the PP of the skill
    # @return [String]
    def pp_text
      "#{@pp} / #{@ppmax}"
    end
    # Return the actual base power of the move
    # @return [Integer]
    def power
      data.power
    end
    alias base_power power
    # Return the text of the power of the skill (for the UI)
    # @return [String]
    def power_text
      power = data.power
      return text_get(11, 12) if power == 0
      return power.to_s
    end
    # Return the current type of the move
    # @return [Integer]
    def type
      data_type(data.type).id
    end
    # Return the current accuracy of the move
    # @return [Integer]
    def accuracy
      data.accuracy
    end
    # Return the accuracy text of the skill (for the UI)
    # @return [String]
    def accuracy_text
      acc = data.accuracy
      return text_get(11, 12) if acc == 0
      return acc.to_s
    end
    # Return the priority of the skill
    # @param user [PFM::PokemonBattler] user for the priority check
    # @return [Integer]
    def priority(user = nil)
      priority = data.priority - Logic::MOVE_PRIORITY_OFFSET
      return priority unless user
      logic.each_effects(user) do |e|
        new_priority = e.on_move_priority_change(user, priority, self)
        return new_priority if new_priority
      end
      return priority
    end
    ## Move priority
    def relative_priority
      return priority + Logic::MOVE_PRIORITY_OFFSET
    end
    # Return the chance of effect of the skill
    # @return [Integer]
    def effect_chance
      return data.effect_chance == 0 ? 100 : data.effect_chance
    end
    # Get all the status effect of a move
    # @return [Array<Studio::Move::MoveStatus>]
    def status_effects
      return data.move_status
    end
    # Return the target symbol the skill can aim
    # @return [Symbol]
    def target
      return data.battle_engine_aimed_target
    end
    # Return the critical rate index of the skill
    # @return [Integer]
    def critical_rate
      return data.critical_rate
    end
    # Is the skill affected by gravity
    # @return [Boolean]
    def gravity_affected?
      return data.is_gravity
    end
    # Return the stat stage modifier the skill can apply
    # @return [Array<Studio::Move::BattleStageMod>]
    def battle_stage_mod
      return data.battle_stage_mod
    end
    # Is the skill direct ?
    # @return [Boolean]
    def direct?
      return data.is_direct
    end
    # Is the skill affected by Mirror Move
    # @return [Boolean]
    def mirror_move_affected?
      return data.is_mirror_move
    end
    # Is the skill blocable by Protect and skill like that ?
    # @return [Boolean]
    def blocable?
      return data.is_blocable
    end
    # Does the skill has recoil ?
    # @return [Boolean]
    def recoil?
      false
    end
    # Returns the recoil factor
    # @return [Integer]
    def recoil_factor
      4
    end
    # Returns the drain factor
    # @return [Integer]
    def drain_factor
      2
    end
    # Is the skill a punching move ?
    # @return [Boolean]
    def punching?
      return data.is_punch
    end
    # Is the skill a sound attack ?
    # @return [Boolean]
    def sound_attack?
      return data.is_sound_attack
    end
    # Is the skill a slicing attack ?
    # @return [Boolean]
    def slicing_attack?
      return data.is_slicing_attack
    end
    # Does the skill unfreeze
    # @return [Boolean]
    def unfreeze?
      return data.is_unfreeze
    end
    # Is the skill a wind attack ?
    # @return [Boolean]
    def wind_attack?
      return data.is_wind
    end
    # Does the skill trigger the king rock
    # @return [Boolean]
    def trigger_king_rock?
      return data.is_king_rock_utility
    end
    # Is the skill snatchable ?
    # @return [Boolean]
    def snatchable?
      return data.is_snatchable
    end
    # Is the skill affected by magic coat ?
    # @return [Boolean]
    def magic_coat_affected?
      return data.is_magic_coat_affected
    end
    # Is the skill physical ?
    # @return [Boolean]
    def physical?
      return data.category == :physical
    end
    # Is the skill special ?
    # @return [Boolean]
    def special?
      return data.category == :special
    end
    # Is the skill status ?
    # @return [Boolean]
    def status?
      return data.category == :status
    end
    # Return the class of the skill (used by the UI)
    # @return [Integer] 1, 2, 3
    def atk_class
      return 2 if special?
      return 3 if status?
      return 1 if physical?
    end
    # Return the symbol of the move in the database
    # @return [Symbol]
    def db_symbol
      return @db_symbol
    end
    # Change the PP
    # @param value [Integer] the new pp value
    def pp=(value)
      @pp = value.to_i.clamp(0, @ppmax)
    end
    # Was the move a critical hit
    # @return [Boolean]
    def critical_hit?
      @critical
    end
    # Was the move super effective ?
    # @return [Boolean]
    def super_effective?
      @effectiveness >= 2
    end
    # Was the move not very effective ?
    # @return [Boolean]
    def not_very_effective?
      @effectiveness > 0 && @effectiveness < 1
    end
    # Tell if the move is a ballistic move
    # @return [Boolean]
    def ballistics?
      return data.is_ballistics
    end
    # Tell if the move is biting move
    # @return [Boolean]
    def bite?
      return data.is_bite
    end
    # Tell if the move is a dance move
    # @return [Boolean]
    def dance?
      return data.is_dance
    end
    # Tell if the move is a pulse move
    # @return [Boolean]
    def pulse?
      return data.is_pulse
    end
    # Tell if the move is a heal move
    # @return [Boolean]
    def heal?
      return data.is_heal
    end
    # Tell if the move is a two turn move
    # @return [Boolean]
    def two_turn?
      return data.is_charge
    end
    # Tell if the move is a powder move
    # @return [Boolean]
    def powder?
      return data.is_powder
    end
    # Tell if the move is a move that can bypass Substitute
    # @return [Boolean]
    def authentic?
      return data.is_authentic
    end
    # Tell if the move is an OHKO move
    # @return [Boolean]
    def ohko?
      return false
    end
    # Tell if the move is a move that switch the user if that hit
    # @return [Boolean]
    def self_user_switch?
      return false
    end
    # Tell if the move is a move that forces target switch
    # @return [Boolean]
    def force_switch?
      return false
    end
    # Is the move doing something before any other attack ?
    # @return [Boolean]
    def pre_attack?
      false
    end
    # Tells if the move hits multiple times
    # @return [Boolean]
    def multi_hit?
      return false
    end
    # Get the effectiveness
    attr_reader :effectiveness
    class << self
      # Retrieve a registered move
      # @param symbol [Symbol] be_method of the move
      # @return [Class<Battle::Move>]
      def [](symbol)
        REGISTERED_MOVES[symbol]
      end
      # Register a move
      # @param symbol [Symbol] be_method of the move
      # @param klass [Class] class of the move
      def register(symbol, klass)
        raise format('%<klass>s is not a "Move" and cannot be registered', klass: klass) unless klass.ancestors.include?(Move)
        REGISTERED_MOVES[symbol] = klass
      end
    end
    # Range of the R random factor
    R_RANGE = 85..100
    # Method calculating the damages done by the actual move
    # @note : I used the 4th Gen formula : https://www.smogon.com/dp/articles/damage_formula
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @note The formula is the following:
    #       (((((((Level * 2 / 5) + 2) * BasePower * [Sp]Atk / 50) / [Sp]Def) * Mod1) + 2) *
    #         CH * Mod2 * R / 100) * STAB * Type1 * Type2 * Mod3)
    # @return [Integer]
    def damages(user, target)
      log_data("\# damages(#{user}, #{target}) for #{db_symbol}")
      @effectiveness = 1
      @critical = logic.calc_critical_hit(user, target, critical_rate)
      log_data("@critical = #{@critical} \# critical_rate = #{critical_rate}")
      damage = user.level * 2 / 5 + 2
      log_data("damage = #{damage} \# #{user.level} * 2 / 5 + 2")
      damage = (damage * calc_base_power(user, target)).floor
      log_data("damage = #{damage} \# after calc_base_power")
      damage = (damage * calc_sp_atk(user, target)).floor / 50
      log_data("damage = #{damage} \# after calc_sp_atk / 50")
      damage = (damage / calc_sp_def(user, target)).floor
      log_data("damage = #{damage} \# after calc_sp_def")
      damage = (damage * calc_mod1(user, target)).floor + 2
      log_data("damage = #{damage} \# after calc_mod1 + 2")
      damage = (damage * calc_ch(user, target)).floor
      log_data("damage = #{damage} \# after calc_ch")
      damage = (damage * calc_mod2(user, target)).floor
      log_data("damage = #{damage} \# after calc_mod2")
      damage *= logic.move_damage_rng.rand(calc_r_range)
      damage /= 100
      log_data("damage = #{damage} \# after rng")
      types = definitive_types(user, target)
      damage = (damage * calc_stab(user, types)).floor
      log_data("damage = #{damage} \# after stab")
      damage = (damage * calc_type_n_multiplier(target, :type1, types)).floor
      log_data("damage = #{damage} \# after type1")
      damage = (damage * calc_type_n_multiplier(target, :type2, types)).floor
      log_data("damage = #{damage} \# after type2")
      damage = (damage * calc_type_n_multiplier(target, :type3, types)).floor
      log_data("damage = #{damage} \# after type3")
      damage = (damage * calc_mod3(user, target)).floor
      log_data("damage = #{damage} \# after mod3")
      target_hp = target.effects.get(:substitute).hp if (target.effects.has?(:substitute) && !user.has_ability?(:infiltrator) && !self.authentic?)
      target_hp ||= target.hp
      damage = damage.clamp(1, target_hp)
      log_data("damage = #{damage} \# after clamp")
      return damage
    end
    # Get the real base power of the move (taking in account all parameter)
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Integer]
    def real_base_power(user, target)
      return power
    end
    private
    # Base power calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Integer]
    def calc_base_power(user, target)
      base_power = real_base_power(user, target)
      return logic.each_effects(user, target).reduce(base_power) do |product, e|
        (product * e.base_power_multiplier(user, target, self)).floor
      end
    end
    # [Spe]atk calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Integer]
    def calc_sp_atk(user, target)
      ph_move = physical?
      result = calc_sp_atk_basis(user, target, ph_move)
      result = (result * calc_atk_stat_modifier(user, target, ph_move)).floor
      logic.each_effects(user, target) do |e|
        result = (result * e.sp_atk_multiplier(user, target, self)).floor
      end
      return result
    end
    # Get the basis atk for the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @param ph_move [Boolean] true: physical, false: special
    # @return [Integer]
    def calc_sp_atk_basis(user, target, ph_move)
      return ph_move ? user.atk_basis : user.ats_basis
    end
    # Statistic modifier calculation: ATK/ATS
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @param ph_move [Boolean] true: physical, false: special
    # @return [Integer]
    def calc_atk_stat_modifier(user, target, ph_move)
      modifier = ph_move ? user.atk_modifier : user.ats_modifier
      modifier = modifier > 1 ? modifier : 1 if critical_hit?
      return modifier
    end
    EXPLOSION_SELF_DESTRUCT_MOVE = %i[explosion self_destruct]
    # [Spe]def calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Integer]
    def calc_sp_def(user, target)
      ph_move = physical?
      result = calc_sp_def_basis(user, target, ph_move)
      result = (result * calc_def_stat_modifier(user, target, ph_move)).floor
      logic.each_effects(user, target) do |e|
        result = (result * e.sp_def_multiplier(user, target, self)).floor
      end
      return result
    end
    # Get the basis dfe/dfs for the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @param ph_move [Boolean] true: physical, false: special
    # @return [Integer]
    def calc_sp_def_basis(user, target, ph_move)
      return ph_move ? target.dfe_basis : target.dfs_basis
    end
    # Statistic modifier calculation: DFE/DFS
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @param ph_move [Boolean] true: physical, false: special
    # @return [Integer]
    def calc_def_stat_modifier(user, target, ph_move)
      modifier = ph_move ? target.dfe_modifier : target.dfs_modifier
      modifier = modifier > 1 ? 1 : modifier if critical_hit?
      return modifier
    end
    # CH calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Numeric]
    def calc_ch(user, target)
      crit_dmg_rate = 1
      crit_dmg_rate *= 1.5 if critical_hit?
      crit_dmg_rate *= 1.5 if critical_hit? && user.has_ability?(:sniper)
      return crit_dmg_rate
    end
    # Mod1 multiplier calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Numeric]
    def calc_mod1(user, target)
      result = 1
      logic.each_effects(user, target) do |e|
        result *= e.mod1_multiplier(user, target, self)
      end
      result *= calc_mod1_tvt(target)
      return result
    end
    # Calculate the TVT mod
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Numeric]
    def calc_mod1_tvt(target)
      return 1 if one_target? || $game_temp.vs_type == 1
      if self.target == :all_foe
        count = logic.allies_of(target).size + 1
      else
        count = logic.adjacent_allies_of(target).size + 1
      end
      return count > 1 ? 0.75 : 1
    end
    # Mod2 multiplier calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Numeric]
    def calc_mod2(user, target)
      update_use_count(user)
      result = 1
      logic.each_effects(user, target) do |e|
        result *= e.mod2_multiplier(user, target, self)
      end
      return result
    end
    # Update the move use count
    # @param user [PFM::PokemonBattler] user of the move
    def update_use_count(user)
      if user.last_successful_move_is?(db_symbol)
        @consecutive_use_count += 1
      else
        @consecutive_use_count = 0
      end
    end
    # "Calc" the R range value
    # @return [Range]
    def calc_r_range
      R_RANGE
    end
    # Mod3 calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Numeric]
    def calc_mod3(user, target)
      result = 1
      logic.each_effects(user, target) do |e|
        result *= e.mod3_multiplier(user, target, self)
      end
      return result
    end
    public
    # Is the skill a specific type ?
    # @param type_id [Integer] ID of the type
    def type?(type_id)
      return type == type_id
    end
    # Is the skill typeless ?
    # @return [Boolean]
    def typeless?
      return type?(data_type(:__undef__).id)
    end
    # Is the skill type normal ?
    # @return [Boolean]
    def type_normal?
      return type?(data_type(:normal).id)
    end
    # Is the skill type fire ?
    # @return [Boolean]
    def type_fire?
      return type?(data_type(:fire).id)
    end
    alias type_feu? type_fire?
    # Is the skill type water ?
    # @return [Boolean]
    def type_water?
      return type?(data_type(:water).id)
    end
    alias type_eau? type_water?
    # Is the skill type electric ?
    # @return [Boolean]
    def type_electric?
      return type?(data_type(:electric).id)
    end
    alias type_electrique? type_electric?
    # Is the skill type grass ?
    # @return [Boolean]
    def type_grass?
      return type?(data_type(:grass).id)
    end
    alias type_plante? type_grass?
    # Is the skill type ice ?
    # @return [Boolean]
    def type_ice?
      return type?(data_type(:ice).id)
    end
    alias type_glace? type_ice?
    # Is the skill type fighting ?
    # @return [Boolean]
    def type_fighting?
      return type?(data_type(:fighting).id)
    end
    alias type_combat? type_fighting?
    # Is the skill type poison ?
    # @return [Boolean]
    def type_poison?
      return type?(data_type(:poison).id)
    end
    # Is the skill type ground ?
    # @return [Boolean]
    def type_ground?
      return type?(data_type(:ground).id)
    end
    alias type_sol? type_ground?
    # Is the skill type fly ?
    # @return [Boolean]
    def type_flying?
      return type?(data_type(:flying).id)
    end
    alias type_vol? type_flying?
    alias type_fly? type_flying?
    # Is the skill type psy ?
    # @return [Boolean]
    def type_psychic?
      return type?(data_type(:psychic).id)
    end
    alias type_psy? type_psychic?
    # Is the skill type insect/bug ?
    # @return [Boolean]
    def type_insect?
      return type?(data_type(:bug).id)
    end
    alias type_bug? type_insect?
    # Is the skill type rock ?
    # @return [Boolean]
    def type_rock?
      return type?(data_type(:rock).id)
    end
    alias type_roche? type_rock?
    # Is the skill type ghost ?
    # @return [Boolean]
    def type_ghost?
      return type?(data_type(:ghost).id)
    end
    alias type_spectre? type_ghost?
    # Is the skill type dragon ?
    # @return [Boolean]
    def type_dragon?
      return type?(data_type(:dragon).id)
    end
    # Is the skill type steel ?
    # @return [Boolean]
    def type_steel?
      return type?(data_type(:steel).id)
    end
    alias type_acier? type_steel?
    # Is the skill type dark ?
    # @return [Boolean]
    def type_dark?
      return type?(data_type(:dark).id)
    end
    alias type_tenebre? type_dark?
    # Is the skill type fairy ?
    # @return [Boolean]
    def type_fairy?
      return type?(data_type(:fairy).id)
    end
    alias type_fee? type_fairy?
    public
    # Function that calculate the type modifier (for specific uses)
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler]
    # @return [Float]
    def type_modifier(user, target)
      types = definitive_types(user, target)
      n = calc_type_n_multiplier(target, :type1, types) * calc_type_n_multiplier(target, :type2, types) * calc_type_n_multiplier(target, :type3, types)
      return n
    end
    # STAB calculation
    # @param user [PFM::PokemonBattler] user of the move
    # @param types [Array<Integer>] list of definitive types of the move
    # @return [Numeric]
    def calc_stab(user, types)
      if types.any? { |type| user.type1 == type || user.type2 == type || user.type3 == type }
        return 2 if user.has_ability?(:adaptability)
        return 1.5
      end
      return 1
    end
    # Get the types of the move with 1st type being affected by effects
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Array<Integer>] list of types of the move
    def definitive_types(user, target)
      type = self.type
      exec_hooks(Move, :move_type_change, binding)
      return [*type]
    ensure
      log_data(format('types = %<types>s # ie: %<ie>s', types: type.to_s, ie: [*type].map { |t| data_type(t).name }.join(', ')))
    end
    private
    # Calc TypeN multiplier of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @param type_to_check [Symbol] type to check on the target
    # @param types [Array<Integer>] list of types the move has
    # @return [Numeric]
    def calc_type_n_multiplier(target, type_to_check, types)
      target_type = target.send(type_to_check)
      result = types.inject(1) { |product, type| product * calc_single_type_multiplier(target, target_type, type) }
      if @effectiveness >= 0
        @effectiveness *= result
        log_data("multiplier of #{type_to_check} (#{data_type(target_type).name}) = #{result} => new_eff = #{@effectiveness}")
      end
      return result
    end
    # Calc the single type multiplier
    # @param target [PFM::PokemonBattler] target of the move
    # @param target_type [Integer] one of the type of the target
    # @param type [Integer] one of the type of the move
    # @return [Float] definitive multiplier
    def calc_single_type_multiplier(target, target_type, type)
      exec_hooks(Move, :single_type_multiplier_overwrite, binding)
      return data_type(type).hit(data_type(target_type).db_symbol)
    rescue Hooks::ForceReturn => e
      log_data("\# calc_single_type_multiplier(#{target}, #{target_type}, #{type})")
      log_data("\# FR: calc_single_type_multiplier #{e.data} from #{e.hook_name} (#{e.reason})")
      return e.data
    end
    class << self
      # Function that registers a move_type_change hook
      # @param reason [String] reason of the move_type_change registration
      # @yieldparam user [PFM::PokemonBattler]
      # @yieldparam target [PFM::PokemonBattler]
      # @yieldparam move [Battle::Move]
      # @yieldparam type [Integer] current type of the move
      # @yieldreturn [Integer, nil] new move type
      def register_move_type_change_hook(reason)
        Hooks.register(Move, :move_type_change, reason) do |hook_binding|
          result = yield(hook_binding.local_variable_get(:user), hook_binding.local_variable_get(:target), self, hook_binding.local_variable_get(:type))
          hook_binding.local_variable_set(:type, result) if result.is_a?(Integer)
        end
      end
      # Function that registers a single_type_multiplier_overwrite hook
      # @param reason [String] reason of the single_type_multiplier_overwrite registration
      # @yieldparam target [PFM::PokemonBattler]
      # @yieldparam target_type [Integer] one of the type of the target
      # @yieldparam type [Integer] one of the type of the move
      # @yieldparam move [Battle::Move]
      # @yieldreturn [Float, nil] overwritten
      def register_single_type_multiplier_overwrite_hook(reason)
        Hooks.register(Move, :single_type_multiplier_overwrite, reason) do |hook_binding|
          result = yield(hook_binding.local_variable_get(:target), hook_binding.local_variable_get(:target_type), hook_binding.local_variable_get(:type), self)
          force_return(result) if result
        end
      end
    end
    Move.register_move_type_change_hook('PSDK Effect process') do |user, target, move, type|
      move.logic.each_effects(user, target) do |e|
        result = e.on_move_type_change(user, target, move, type)
        type = result if result.is_a?(Integer)
      end
      next(type)
    end
    Move.register_single_type_multiplier_overwrite_hook('PSDK Effect process') do |target, target_type, type, move|
      overwrite = nil
      move.logic.each_effects(target) do |e|
        next if overwrite
        result = e.on_single_type_multiplier_overwrite(target, target_type, type, move)
        overwrite = result if result
      end
      next(overwrite)
    end
    Move.register_single_type_multiplier_overwrite_hook('PSDK Freeze-Dry') do |_, target_type, _, move|
      next(2) if move.db_symbol == :freeze_dry && target_type == data_type(:water).id
      next(nil)
    end
    Move.register_single_type_multiplier_overwrite_hook('PSDK Grounded: Levitate & Air Balloon') do |target, _, type|
      next(0) if type == data_type(:ground).id && !target.grounded?
      next(nil)
    end
    public
    # Return the chance of hit of the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Float]
    def chance_of_hit(user, target)
      log_data("\# chance_of_hit(#{user}, #{target}) for #{db_symbol}")
      if bypass_chance_of_hit?(user, target)
        log_data('# chance_of_hit: bypassed')
        return 100
      end
      factor = logic.each_effects(user, target).reduce(1) { |product, e| product * e.chance_of_hit_multiplier(user, target, self) }
      factor *= accuracy_mod(user)
      factor *= evasion_mod(target)
      log_data("result = #{factor * accuracy}")
      return factor * accuracy
    end
    # Check if the move bypass chance of hit and cannot fail
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] target of the move
    # @return [Boolean]
    def bypass_chance_of_hit?(user, target)
      return true if user.effects.get(:lock_on)&.target == target
      return true if user.has_ability?(:no_guard) || target.has_ability?(:no_guard)
      return true if db_symbol == :blizzard && $env.hail?
      return true if (status? && target == user) || accuracy <= 0
      return true if db_symbol == :toxic && user.type_poison?
      return false
    end
    # Return the accuracy modifier of the user
    # @param user [PFM::PokemonBattler]
    # @return [Float]
    def accuracy_mod(user)
      return user.stat_multiplier_acceva(user.acc_stage)
    end
    # Return the evasion modifier of the target
    # @param target [PFM::PokemonBattler]
    # @return [Float]
    def evasion_mod(target)
      return target.stat_multiplier_acceva(-target.eva_stage)
    end
    public
    # List of symbol describe a one target aim
    OneTarget = %i[any_other_pokemon random_foe adjacent_pokemon adjacent_foe user user_or_adjacent_ally adjacent_ally]
    # List of symbol that doesn't show any choice of target
    TargetNoAsk = %i[adjacent_all_foe all_foe adjacent_all_pokemon all_pokemon user all_ally all_ally_but_user random_foe]
    # Does the skill aim only one Pokemon
    # @return [Boolean]
    def one_target?
      return OneTarget.include?(target)
    end
    alias is_one_target? one_target?
    # Check if an attack that targets multiple people is targeting only one
    # @param user [PFM::PokemonBattler] user of the move
    # @return [Boolean]
    def one_target_from_zone_attack(user)
      return battler_targets(user, logic).length == 1
    end
    # Does the skill doesn't show a target choice
    # @return [Boolean]
    def no_choice_skill?
      return TargetNoAsk.include?(target)
    end
    alias is_no_choice_skill? no_choice_skill?
    alias affects_bank? void_false
    # List the targets of this move
    # @param pokemon [PFM::PokemonBattler] the Pokemon using the move
    # @param logic [Battle::Logic] the battle logic allowing to find the targets
    # @return [Array<PFM::PokemonBattler>] the possible targets
    # @note use one_target? to select the target inside the possible result
    def battler_targets(pokemon, logic)
      case target
      when :adjacent_pokemon, :adjacent_all_pokemon
        return logic.adjacent_foes_of(pokemon).concat(logic.adjacent_allies_of(pokemon))
      when :adjacent_foe, :adjacent_all_foe
        return logic.adjacent_foes_of(pokemon)
      when :all_foe, :random_foe
        return logic.foes_of(pokemon)
      when :all_pokemon
        return logic.foes_of(pokemon).concat(logic.allies_of(pokemon)) << pokemon
      when :user
        return [pokemon]
      when :user_or_adjacent_ally
        return [pokemon].concat(logic.adjacent_allies_of(pokemon))
      when :adjacent_ally
        return logic.allies_of(pokemon)
      when :all_ally
        return [pokemon].concat(logic.allies_of(pokemon))
      when :all_ally_but_user
        return logic.allies_of(pokemon)
      when :any_other_pokemon
        return logic.foes_of(pokemon).concat(logic.allies_of(pokemon))
      end
      return [pokemon]
    end
    public
    # Tell if forced next move decreases PP
    # @return [Boolean]
    attr_accessor :forced_next_move_decrease_pp
    # Show the effectiveness message
    # @param effectiveness [Numeric]
    # @param target [PFM::PokemonBattler]
    def efficent_message(effectiveness, target)
      if effectiveness > 1
        scene.display_message_and_wait(parse_text_with_pokemon(19, 6, target))
      else
        if effectiveness > 0 && effectiveness < 1
          scene.display_message_and_wait(parse_text_with_pokemon(19, 15, target))
        end
      end
    end
    # Function starting the move procedure
    # @param user [PFM::PokemonBattler] user of the move
    # @param target_bank [Integer] bank of the target
    # @param target_position [Integer]
    def proceed(user, target_bank, target_position)
      return if user.hp <= 0
      @damage_dealt = 0
      possible_targets = battler_targets(user, logic).select { |target| target&.alive? }
      possible_targets.sort_by(&:spd)
      return proceed_one_target(user, possible_targets, target_bank, target_position) if one_target?
      possible_targets.reverse!
      possible_targets.select! { |pokemon| pokemon.bank == target_bank } unless no_choice_skill?
      specific_procedure = check_specific_procedure(user, possible_targets)
      return send(specific_procedure, user, possible_targets) if specific_procedure
      return proceed_internal(user, possible_targets)
    end
    # Proceed the procedure before any other attack.
    # @param user [PFM::PokemonBattler]
    def proceed_pre_attack(user)
      nil && user
    end
    private
    # Function starting the move procedure for 1 target
    # @param user [PFM::PokemonBattler] user of the move
    # @param possible_targets [Array<PFM::PokemonBattler>] expected targets
    # @param target_bank [Integer] bank of the target
    # @param target_position [Integer]
    def proceed_one_target(user, possible_targets, target_bank, target_position)
      right_target = possible_targets.find { |pokemon| pokemon.bank == target_bank && pokemon.position == target_position }
      right_target ||= possible_targets.find { |pokemon| pokemon.bank == target_bank && (pokemon.position - target_position).abs == 1 }
      right_target ||= possible_targets.find { |pokemon| pokemon.bank == target_bank }
      right_target = target_redirected(user, right_target)
      specific_procedure = check_specific_procedure(user, [right_target].compact)
      return send(specific_procedure, user, [right_target].compact) if specific_procedure
      return proceed_internal(user, [right_target].compact)
    end
    # Internal procedure of the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def proceed_internal(user, targets)
      user.add_move_to_history(self, targets)
      return unless (actual_targets = proceed_internal_precheck(user, targets))
      post_accuracy_check_effects(user, actual_targets)
      post_accuracy_check_move(user, actual_targets)
      play_animation(user, targets)
      deal_damage(user, actual_targets) && effect_working?(user, actual_targets) && deal_status(user, actual_targets) && deal_stats(user, actual_targets) && deal_effect(user, actual_targets)
      user.add_successful_move_to_history(self, actual_targets)
      @scene.visual.set_info_state(:move_animation)
      @scene.visual.wait_for_animation
    end
    # Internal procedure of the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [Array<PFM::PokemonBattler, nil] list of the right target to the move if success
    # @note this function is responsive of calling on_move_failure and checking all the things related to target/user in regard of move usability
    # @note it is forbiden to change anything in this function if you don't know what you're doing, the && and || are not ther because it's cute
    def proceed_internal_precheck(user, targets)
      return unless move_usable_by_user(user, targets) || (on_move_failure(user, targets, :usable_by_user) && false)
      usage_message(user)
      pre_accuracy_check_effects(user, targets)
      return scene.display_message_and_wait(parse_text(18, 106)) if targets.all?(&:dead?) && (on_move_failure(user, targets, :no_target) || true)
      if pp == 0 && !(user.effects.has?(&:force_next_move?) && !@forced_next_move_decrease_pp)
        return (scene.display_message_and_wait(parse_text(18, 85)) || true) && on_move_failure(user, targets, :pp) && nil
      end
      decrease_pp(user, targets)
      return unless !(actual_targets = proceed_move_accuracy(user, targets)).empty? || (on_move_failure(user, targets, :accuracy) && false)
      user, actual_targets = proceed_battlers_remap(user, actual_targets)
      actual_targets = accuracy_immunity_test(user, actual_targets)
      return if actual_targets.none? && (on_move_failure(user, targets, :immunity) || true)
      return actual_targets
    end
    # Test move accuracy
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [Array] the actual targets
    def proceed_move_accuracy(user, targets)
      if bypass_accuracy?(user, targets)
        log_data('# proceed_move_accuracy: bypassed')
        return targets
      end
      return targets.select do |target|
        accuracy_dice = logic.move_accuracy_rng.rand(100)
        hit_chance = chance_of_hit(user, target)
        log_data("\# target= #{target}, \# accuracy= #{hit_chance}, value = #{accuracy_dice} (testing=#{hit_chance > 0}, failure=#{accuracy_dice >= hit_chance})")
        if accuracy_dice >= hit_chance
          text = hit_chance > 0 ? 213 : 24
          scene.display_message_and_wait(parse_text_with_pokemon(19, text, target))
          next(false)
        end
        next(true)
      end
    end
    # Tell if the move accuracy is bypassed
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [Boolean]
    def bypass_accuracy?(user, targets)
      if targets.all? { |target| user.effects.get(:lock_on)&.target == target }
        log_data('# accuracy= 100 (:lock_on effect)')
        return true
      end
      return true if user.has_ability?(:no_guard) || targets.any? { |target| target.has_ability?(:no_guard) }
      return true if db_symbol == :blizzard && $env.hail?
      return true if accuracy <= 0
      return false
    end
    # Show the usage failure when move is not usable by user
    # @param user [PFM::PokemonBattler] user of the move
    def show_usage_failure(user)
      usage_message(user)
      scene.display_message_and_wait(parse_text(18, 74))
    end
    # Show the move usage message
    # @param user [PFM::PokemonBattler] user of the move
    def usage_message(user)
      @scene.visual.hide_team_info
      message = parse_text_with_pokemon(8999 - Studio::Text::CSV_BASE, 12, user, PFM::Text::PKNAME[0] => user.given_name, PFM::Text::MOVE[0] => name)
      scene.display_message_and_wait(message)
      PFM::Text.reset_variables
    end
    # Method that remap user and targets if needed
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [PFM::PokemonBattler, Array<PFM::PokemonBattler>] user, targets
    def proceed_battlers_remap(user, targets)
      if snatchable? && logic.all_alive_battlers.any? { |pkm| pkm != user && pkm.effects.has?(:snatch) }
        snatcher = logic.all_alive_battlers.max_by { |pkm| pkm != user && pkm.effects.has?(:snatch) ? pkm.spd : -1 }
        snatcher.effects.get(:snatch).kill
        logic.scene.display_message_and_wait(parse_text_with_2pokemon(19, 754, snatcher, user))
        return snatcher, [snatcher]
      end
      return user, targets
    end
    # Method responsive testing accuracy and immunity.
    # It'll report the which pokemon evaded the move and which pokemon are immune to the move.
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [Array<PFM::PokemonBattler>]
    def accuracy_immunity_test(user, targets)
      return targets.select do |pokemon|
        if target_immune?(user, pokemon)
          scene.display_message_and_wait(parse_text_with_pokemon(19, 210, pokemon))
          next(false)
        else
          if move_blocked_by_target?(user, pokemon)
            next(false)
          end
        end
        next(true)
      end
    end
    # Test if the target is immune
    # @param user [PFM::PokemonBattler]
    # @param target [PFM::PokemonBattler]
    # @return [Boolean]
    def target_immune?(user, target)
      return true if prankster_immunity?(user, target)
      return true if powder? && target.type_grass? && user != target
      return true if user != target && ability_immunity?(user, target)
      return false if status?
      types = definitive_types(user, target)
      @effectiveness = -1
      return calc_type_n_multiplier(target, :type1, types) == 0 || calc_type_n_multiplier(target, :type2, types) == 0 || calc_type_n_multiplier(target, :type3, types) == 0
    end
    # Test if the target has an immunity due to the type of move & ability
    # @param user [PFM::PokemonBattler]
    # @param target [PFM::PokemonBattler]
    # @return [Boolean]
    def ability_immunity?(user, target)
      logic.each_effects(target) do |e|
        return true if e.on_move_ability_immunity(user, target, self)
      end
      return false
    end
    # Test if the target has an immunity to the Prankster ability due to its type
    # @param user [PFM::PokemonBattler]
    # @param target [PFM::PokemonBattler]
    # @return [Boolean]
    def prankster_immunity?(user, target)
      return false if user == target
      return false unless target.type_dark?
      return false unless user.ability_effect.db_symbol == :prankster
      return user.ability_effect.on_move_priority_change(user, 1, self) == 2
    end
    # Calls the pre_accuracy_check method for each effects
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def pre_accuracy_check_effects(user, targets)
      creatures = [user] + targets
      logic.each_effects(*creatures) do |e|
        e.on_pre_accuracy_check(logic, scene, targets, user, self)
      end
    end
    # Calls the post_accuracy_check method for each effects
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] expected targets
    def post_accuracy_check_effects(user, actual_targets)
      creatures = [user] + actual_targets
      logic.each_effects(*creatures) do |e|
        e.on_post_accuracy_check(logic, scene, actual_targets, user, self)
      end
    end
    # Decrease the PP of the move
    # @param user [PFM::PokemonBattler]
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def decrease_pp(user, targets)
      return if user.effects.has?(&:force_next_move?) && !@forced_next_move_decrease_pp
      self.pp -= 1
      self.pp -= 1 if @logic.foes_of(user).any? { |foe| foe.alive? && foe.has_ability?(:pressure) }
    end
    # Function which permit things to happen before the move's animation
    def post_accuracy_check_move(user, actual_targets)
      return true
    end
    # Play the move animation
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def play_animation(user, targets)
      return unless $options.show_animation
      @scene.visual.set_info_state(:move_animation)
      @scene.visual.wait_for_animation
      play_animation_internal(user, targets)
      @scene.visual.set_info_state(:move, targets + [user])
      @scene.visual.wait_for_animation
    end
    # Play the move animation (only without all the decoration)
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def play_animation_internal(user, targets)
      animations = MoveAnimation.get(self, :first_use)
      if animations
        MoveAnimation.play(animations, @scene.visual, user, targets)
      else
        @scene.visual.show_move_animation(user, targets, self)
      end
    end
    # Function that deals the damage to the pokemon
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    def deal_damage(user, actual_targets)
      return true
    end
    # Function applying recoil damage to the user
    # @param hp [Integer]
    # @param user [PFM::PokemonBattler]
    def recoil(hp, user)
      return false if user.has_ability?(:rock_head) && !%i[struggle shadow_rush shadow_end].include?(db_symbol)
      return special_recoil(hp, user) if user.has_ability?(:parental_bond)
      @logic.damage_handler.damage_change((hp / recoil_factor).to_i.clamp(1, Float::INFINITY), user)
      @scene.display_message_and_wait(parse_text_with_pokemon(19, 378, user))
    end
    # Function applying recoil damage to the user 
    # @note Only for Parental Bond !!
    # @param hp [Integer]
    # @param user [PFM::PokemonBattler]
    def special_recoil(hp, user)
      if user.ability_effect.first_turn_recoil == 0
        user.ability_effect.first_turn_recoil = hp
        return false
      end
      hp += user.ability_effect.first_turn_recoil
      user.ability_effect.first_turn_recoil = 0
      @logic.damage_handler.damage_change((hp / recoil_factor).to_i.clamp(1, Float::INFINITY), user)
      @scene.display_message_and_wait(parse_text_with_pokemon(19, 378, user))
    end
    # Test if the effect is working
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    # @return [Boolean]
    def effect_working?(user, actual_targets)
      exec_hooks(Move, :effect_working, binding)
      return true
    end
    # Array mapping the status effect to an action
    STATUS_EFFECT_MAPPING = %i[nothing poison paralysis burn sleep freeze confusion flinch toxic]
    # Function that deals the status condition to the pokemon
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    def deal_status(user, actual_targets)
      return true if status_effects.empty?
      dice = @logic.generic_rng.rand(0...100)
      status = status_effects.find do |status_effect|
        next(true) if status_effect.luck_rate > dice
        dice -= status_effect.luck_rate
        next(false)
      end || status_effects[0]
      actual_targets.each do |target|
        @logic.status_change_handler.status_change_with_process(status.status, target, user, self)
      end
      return true
    end
    # Function that deals the stat to the pokemon
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    def deal_stats(user, actual_targets)
      return true if battle_stage_mod.empty?
      actual_targets.each do |target|
        battle_stage_mod.each do |stage|
          next if stage.count == 0
          @logic.stat_change_handler.stat_change_with_process(stage.stat, stage.count, target, user, self)
        end
      end
      return true
    end
    # Function that deals the effect to the pokemon
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    def deal_effect(user, actual_targets)
      return true
    end
    # Event called if the move failed
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @param reason [Symbol] why the move failed: :usable_by_user, :accuracy, :immunity, :pp
    def on_move_failure(user, targets, reason)
      return false
    end
    # Function that execute another move (Sleep Talk, Metronome)
    # @param move [Battle::Move] has to be cloned before calling the method
    # @param target_bank [Integer]
    # @param target_position [Integer]
    def use_another_move(move, user, target_bank = nil, target_position = nil)
      if target_bank.nil? || target_position.nil?
        targets = move.battler_targets(user, @logic)
        if targets.any? { |target| target.bank != user.bank }
          choosen_target = targets.reject { |target| target.bank == user.bank }.first
        else
          choosen_target = targets.first
        end
        target_bank = choosen_target.bank
        target_position = choosen_target.position
      end
      action = Actions::Attack.new(@scene, move, user, target_bank, target_position)
      action.execute
    end
    # Return the new target if redirected or the initial target
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [PFM::PokemonBattler] the target
    def target_redirected(user, targets)
      logic.each_effects(*logic.adjacent_foes_of(user)) do |e|
        new_target = e.target_redirection(user, targets, self)
        return new_target if new_target
      end
      return targets
    end
    public
    # Check if an Effects imposes a specific proceed_internal
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @return [Symbol, nil] the symbol of the proceed_internal to call, nil if no specific procedure
    def check_specific_procedure(user, targets)
      logic.each_effects(user) do |e|
        specific_procedure = e.specific_proceed_internal(user, targets, self)
        return specific_procedure if specific_procedure
      end
      return nil
    end
    # Internal procedure of the move for Parental Bond Ability
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def proceed_internal_parental_bond(user, targets)
      user.add_move_to_history(self, targets)
      return unless (actual_targets = proceed_internal_precheck(user, targets))
      post_accuracy_check_effects(user, actual_targets)
      post_accuracy_check_move(user, actual_targets)
      play_animation(user, targets)
      nb_loop = user.ability_effect&.number_of_attacks || 1
      nb_loop.times do |nb_attack|
        next unless nb_attack == 0 || ((one_target_from_zone_attack(user) || one_target?) && !multi_hit? && !status?)
        next(@scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => nb_attack.to_s))) if targets.any?(&:dead?)
        if nb_attack >= 1
          user.ability_effect&.activated = true
          scene.visual.show_ability(user)
        end
        user.ability_effect.attack_number = nb_attack
        deal_damage(user, actual_targets) && effect_working?(user, actual_targets) && deal_status(user, actual_targets) && deal_stats(user, actual_targets) && (user.ability_effect&.first_effect_can_be_applied?(be_method) || nb_attack > 0) && deal_effect(user, actual_targets)
      end
      @scene.display_message_and_wait(parse_text(18, 33, PFM::Text::NUMB[1] => nb_loop.to_s)) if user.ability_effect&.activated
      user.ability_effect&.activated = false
      user.add_successful_move_to_history(self, actual_targets)
      @scene.visual.set_info_state(:move_animation)
      @scene.visual.wait_for_animation
    end
    # Internal procedure of the move for Sheer Force Ability
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    def proceed_internal_sheer_force(user, targets)
      user.add_move_to_history(self, targets)
      return unless (actual_targets = proceed_internal_precheck(user, targets))
      post_accuracy_check_effects(user, actual_targets)
      post_accuracy_check_move(user, actual_targets)
      play_animation(user, targets)
      user.ability_effect&.activated = true
      deal_damage(user, actual_targets) && effect_working?(user, actual_targets) && deal_status(user, actual_targets) && deal_stats(user, actual_targets) && deal_effect_sheer_force(user, actual_targets)
      user.ability_effect&.activated = false
      user.add_successful_move_to_history(self, actual_targets)
      @scene.visual.set_info_state(:move_animation)
      @scene.visual.wait_for_animation
    end
    # Function that deals the effect to the pokemon
    # @param user [PFM::PokemonBattler] user of the move
    # @param actual_targets [Array<PFM::PokemonBattler>] targets that will be affected by the move
    def deal_effect_sheer_force(user, actual_targets)
      if user.ability_effect&.excluded_db_symbol&.include?(db_symbol) || user.ability_effect&.excluded_methods&.include?(be_method)
        return deal_effect(user, actual_targets)
      end
      return false
    end
    public
    # Function that tests if the user is able to use the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param targets [Array<PFM::PokemonBattler>] expected targets
    # @note Thing that prevents the move from being used should be defined by :move_prevention_user Hook
    # @return [Boolean] if the procedure can continue
    def move_usable_by_user(user, targets)
      log_data("\# move_usable_by_user(#{user}, #{targets})")
      PFM::Text.set_variable(PFM::Text::PKNICK[0], user.given_name)
      PFM::Text.set_variable(PFM::Text::MOVE[1], name)
      exec_hooks(Move, :move_prevention_user, binding)
      return true
    rescue Hooks::ForceReturn => e
      log_data("\# FR: move_usable_by_user #{e.data} from #{e.hook_name} (#{e.reason})")
      return e.data
    ensure
      PFM::Text.reset_variables
    end
    # Function that tells if the move is disabled
    # @param user [PFM::PokemonBattler] user of the move
    # @return [Boolean]
    def disabled?(user)
      disable_reason(user) ? true : false
    end
    # Get the reason why the move is disabled
    # @param user [PFM::PokemonBattler] user of the move
    # @return [#call] Block that should be called when the move is disabled
    def disable_reason(user)
      return proc { } if pp == 0
      exec_hooks(Move, :move_disabled_check, binding)
      return nil
    rescue Hooks::ForceReturn => e
      log_data("\# disable_reason(#{user})")
      log_data("\# FR: disable_reason #{e.data} from #{e.hook_name} (#{e.reason})")
      return e.data
    end
    # Function that tests if the targets blocks the move
    # @param user [PFM::PokemonBattler] user of the move
    # @param target [PFM::PokemonBattler] expected target
    # @note Thing that prevents the move from being used should be defined by :move_prevention_target Hook.
    # @return [Boolean] if the target evade the move (and is not selected)
    def move_blocked_by_target?(user, target)
      log_data("\# move_blocked_by_target?(#{user}, #{target})")
      exec_hooks(Move, :move_prevention_target, binding) if user != target
      return false
    rescue Hooks::ForceReturn => e
      log_data("\# FR: move_blocked_by_target? #{e.data} from #{e.hook_name} (#{e.reason})")
      return e.data
    end
    # Detect if the move is protected by another move on target
    # @param target [PFM::PokemonBattler]
    # @param symbol [Symbol]
    def blocked_by?(target, symbol)
      return blocable? && target.effects.has?(:protect) && target.last_successful_move_is?(symbol)
    end
    class << self
      # Function that registers a move_prevention_user hook
      # @param reason [String] reason of the move_prevention_user registration
      # @yieldparam user [PFM::PokemonBattler]
      # @yieldparam targets [Array<PFM::PokemonBattler>]
      # @yieldparam move [Battle::Move]
      # @yieldreturn [:prevent, nil] :prevent if the move cannot continue
      def register_move_prevention_user_hook(reason)
        Hooks.register(Move, :move_prevention_user, reason) do |hook_binding|
          force_return(false) if yield(hook_binding.local_variable_get(:user), hook_binding.local_variable_get(:targets), self) == :prevent
        end
      end
      # Function that registers a move_disabled_check hook
      # @param reason [String] reason of the move_disabled_check registration
      # @yieldparam user [PFM::PokemonBattler]
      # @yieldparam move [Battle::Move]
      # @yieldreturn [Proc, nil] the code to execute if the move is disabled
      def register_move_disabled_check_hook(reason)
        Hooks.register(Move, :move_disabled_check, reason) do |hook_binding|
          result = yield(hook_binding.local_variable_get(:user), self)
          force_return(result) if result.respond_to?(:call)
        end
      end
      # Function that registers a move_prevention_target hook
      # @param reason [String] reason of the move_prevention_target registration
      # @yieldparam user [PFM::PokemonBattler]
      # @yieldparam target [PFM::PokemonBattler] expected target
      # @yieldparam move [Battle::Move]
      # @yieldreturn [Boolean] if the target is evading the move
      def register_move_prevention_target_hook(reason)
        Hooks.register(Move, :move_prevention_target, reason) do |hook_binding|
          force_return(true) if yield(hook_binding.local_variable_get(:user), hook_binding.local_variable_get(:target), self)
        end
      end
    end
  end
  Move.register_move_prevention_user_hook('PSDK Move prev user: Effects') do |user, targets, move|
    next(move.logic.each_effects(user, *targets) do |effect|
      result = effect.on_move_prevention_user(user, targets, move)
      break(result) if result
    end)
  end
  Move.register_move_prevention_target_hook('PSDK Move prev target: Effects') do |user, target, move|
    next(move.logic.each_effects(user, target) do |effect|
      break(true) if effect.on_move_prevention_target(user, target, move) == true
    end == true)
  end
  Move.register_move_disabled_check_hook('PSDK Move disable check: Effects') do |user, move|
    next(move.logic.each_effects(user) do |effect|
      effect_proc = effect.on_move_disabled_check(user, move)
      break(effect_proc) if effect_proc.is_a?(Proc)
    end)
  end
  Move.register_move_disabled_check_hook('PSDK .24 moves disabled') do |_, move|
    next if move.class != Battle::Move
    next(proc {move.scene.display_message_and_wait('\\c[2]This move is not implemented!\\c[0]') })
  end
  Hooks.register(Move, :effect_working, 'Magic Bounce Ability') do |move_binding|
    move = self
    user = move_binding.local_variable_get(:user)
    actual_targets = move_binding.local_variable_get(:actual_targets)
    next unless move.magic_coat_affected?
    next unless user.can_be_lowered_or_canceled?(move.status? && actual_targets.any? { |target| target.has_ability?(:magic_bounce) })
    if move.affects_bank?
      blocker = actual_targets.find { |target| target.has_ability?(:magic_bounce) }
      move.scene.visual.show_ability(blocker)
      move.scene.visual.wait_for_animation
      @original_target = actual_targets
      actual_targets.clear << user
      next
    end
    actual_targets.map! do |target|
      next(target) unless target.has_ability?(:magic_bounce)
      move.scene.visual.show_ability(target)
      move.scene.visual.wait_for_animation
      @original_target << target
      next(user)
    end
  end
  Hooks.register(Move, :effect_working, 'Magic Coat effect') do |move_binding|
    move = self
    user = move_binding.local_variable_get(:user)
    actual_targets = move_binding.local_variable_get(:actual_targets)
    next unless move.magic_coat_affected?
    next unless user.can_be_lowered_or_canceled?(move.status? && actual_targets.any? { |target| target.effects.has?(:magic_coat) })
    if move.affects_bank?
      @original_target = actual_targets
      actual_targets.clear << user
      next
    end
    actual_targets.map! do |target|
      next(target) unless target.has_ability?(:magic_coat)
      @original_target << target
      next(user)
    end
  end
end
