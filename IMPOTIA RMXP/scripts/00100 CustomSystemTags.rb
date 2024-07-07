=begin
-----------------------------Extract from GameData_SystemTags.rb-----------------------------

# Module that defines every data class, data reader module or constants
module GameData
  # Module that contain the ids of every SystemTag
  # @author Nuri Yuri
  module SystemTags
    module_function

    # Generation of the SystemTag id
    # @param x [Integer] X coordinate of the SystemTag on the w_prio tileset
    # @param y [Integer] Y coordinate of the SystemTag on the w_prio tileset
    def gen(x, y)
      return 384 + x + (y * 8)
    end
    # SystemTag that is used to remove the effet of SystemTags like TSea or TPond.
    Empty = gen 0, 0
    # Ice SystemTag, every instance of Game_Character slide on it.
    TIce = gen 1, 0
    # Grass SystemTag, used to display grass particles and start Wild Pokemon Battle.
    TGrass = gen 5, 0

-----------------------------Extracts from Background.rb-----------------------------
module Battle
  class Logic
    class BattleInfo
      # Name of the background according to their processed zone_type
      BACKGROUND_NAMES = %w[back_building back_grass back_tall_grass back_taller_grass back_cave
                            back_mount back_sand back_pond back_sea back_under_water back_ice back_snow]
      # List of of suffix for the timed background. Order is morning, day, sunset, night.
      # @return [Array<Array<String>>]
      TIMED_BACKGROUND_SUFFIXES = [%w[morning day], %w[day], %w[sunset night], %w[night]]
      # Get the background name
      # @return [String]
      attr_accessor :background_name

      ...

      # Function that returns the background name based on the system tag
      # @return [String]
      def system_tag_background_name
        zone_type = $env.get_zone_type
        zone_type += 1 if zone_type > 0 || $env.grass?
        return BACKGROUND_NAMES[zone_type].to_s
      end


-----------------------------Extracts from Environnement.rb-----------------------------

    # Return the zone type
    # @param ice_prio [Boolean] when on snow for background, return ice ID if player is on ice
    # @return [Integer] 1 = tall grass, 2 = taller grass, 3 = cave, 4 = mount, 5 = sand, 6 = pond, 7 = sea, 8 = underwater, 9 = snow, 10 = ice, 0 = building
    def get_zone_type(ice_prio = false)
      if tall_grass?
        return 1
      elsif very_tall_grass?
        return 2
      elsif cave?
        return 3
      elsif mount?
        return 4
      elsif sand?
        return 5
      elsif pond?
        return 6
      elsif sea?
        return 7
      elsif under_water?
        return 8
      elsif snow?
        return ((ice_prio && ice?) ? 10 : 9)
      elsif ice?
        return 10
      else
        return 0
      end
    end

    # Convert a system_tag to a zone_type
    # @param system_tag [Integer] the system tag
    # @return [Integer] same as get_zone_type
    def convert_zone_type(system_tag)
      case system_tag
      when TGrass
        return 1
      when TTallGrass
        return 2
      when TCave
        return 3
      when TMount
        return 4
      when TSand
        return 5
      when TPond
        return 6
      when TSea
        return 7
      when TUnderWater
        return 8
      when TSnow
        return 9
      when TIce
        return 10
      else
        return 0
      end
    end

=end

module GameData
  module SystemTags
    YellowSandGrass = gen 0, 12

    # Those two lines allow to reuse the original system_tag_db_symbol as psdk_system_tag_db_symbol
    # Since it's a module_function we need to declare the alias as module_function ;)
    alias_method :psdk_system_tag_db_symbol, :system_tag_db_symbol
    module_function :psdk_system_tag_db_symbol

    module_function # <= that was the missing piece ;)

    def system_tag_db_symbol(system_tag)
      return :custom_yellow_sand_grass if system_tag == YellowSandGrass
      return psdk_system_tag_db_symbol(system_tag)
    end
  end
end

Battle::Logic::BattleInfo::BACKGROUND_NAMES.push('back_yellow_sand_grass')

module CustomSystemTagsOverwrites
  # Return the zone type
  # @param ice_prio [Boolean] when on snow for background, return ice ID if player is on ice
  # @return [Integer] 1 = tall grass, 2 = taller grass, 3 = cave, 4 = mount, 5 = sand, 6 = pond, 7 = sea, 8 = underwater, 9 = snow, 10 = ice, 0 = building
  def get_zone_type(ice_prio = false)
    return 11 if custom_yellow_sand_grass?
    return super(ice_prio)
  end

  # Is the player underwater ?
  # @return [Boolean]
  def custom_yellow_sand_grass?
    return @game_state.game_player.system_tag == GameData::SystemTags::YellowSandGrass
  end

  # Convert a system_tag to a zone_type
  # @param system_tag [Integer] the system tag
  # @return [Integer] same as get_zone_type
  def convert_zone_type(system_tag)
    return 11 if system_tag == GameData::SystemTags::YellowSandGrass
    return super(system_tag)
  end
end

PFM::Environment.prepend(CustomSystemTagsOverwrites)

Game_Character::PARTICLES_METHODS[GameData::SystemTags::YellowSandGrass] = :particle_push_grass