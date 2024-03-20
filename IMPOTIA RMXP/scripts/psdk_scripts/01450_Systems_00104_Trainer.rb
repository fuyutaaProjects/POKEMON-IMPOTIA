module PFM
  # The actor trainer data informations
  #
  # Main object stored in $trainer and PFM.game_state.trainer
  # @author Nuri Yuri
  class Trainer
    # Time format
    TIME_FORMAT = '%02d:%02d'
    # Name of the trainer as a boy (Default to Palbolsky)
    # @return [String]
    attr_accessor :name_boy
    # Name of the trainer as a girl (Default to Yuri)
    # @return [String]
    attr_accessor :name_girl
    # If the player is playing the girl trainer
    # @return [Boolean]
    attr_accessor :playing_girl
    # The internal ID of the trainer as a boy
    # @return [Integer]
    attr_accessor :id_boy
    # The internal ID of the trainer as a girl. It's equal to id_boy ^ 0x28F4AB4C
    # @return [Integer]
    attr_accessor :id_girl
    # The time in second when the Trainer object has been created (computer time)
    # @return [Integer]
    attr_accessor :start_time
    # The time the player has played as this Trainer object
    # @return [Integer]
    attr_accessor :play_time
    # The badges this trainer object has collected
    # @return [Array<Boolean>]
    attr_accessor :badges
    # The ID of the current region in which the trainer is
    # @return [Integer]
    attr_accessor :region
    # The game version in which this object has been saved or created
    # @return [Integer]
    attr_accessor :game_version
    # The current version de PSDK (update management). It's saved like game_version
    # @return [Integer]
    attr_accessor :current_version
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Create a new Trainer
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state = PFM.game_state)
      @name_boy = default_male_name
      @name_girl = default_female_name
      @game_state = game_state
      game_state.game_switches[Yuki::Sw::Gender] = @playing_girl = false
      game_state.game_variables[Yuki::Var::Player_ID] = @id_boy = rand(0x3FFFFFFF)
      @id_girl = (@id_boy ^ 0x28F4AB4C)
      @start_time = Time.new.to_i
      @play_time = 0
      @badges = Array.new(6 * 8, false)
      @region = 0
      @game_version = Configs.infos.game_version
      @current_version = PSDK_VERSION
      @time_counter = 0
      load_time
    end
    # Return the name of the trainer
    # @return [String]
    def name
      return @playing_girl ? @name_girl : @name_boy
    end
    # Change the name of the trainer
    # @param value [String] the new value of the trainer name
    def name=(value)
      if @playing_girl
        @name_girl = value
      else
        @name_boy = value
      end
      id_current_player = $game_variables[Yuki::Var::Current_Player_ID]
      game_state.game_actors[id_current_player].name = value
    end
    # Return the id of the trainer
    # @return [Integer]
    def id
      return @playing_girl ? @id_girl : @id_boy
    end
    # Redefine some variable RMXP uses with the right values
    def redefine_var
      game_state.game_variables[Yuki::Var::Player_ID] = id
      id_current_player = $game_variables[Yuki::Var::Current_Player_ID] = $game_variables[Yuki::Var::Current_Player_ID].clamp(1, Float::INFINITY)
      game_state.game_actors[id_current_player].name = name
    end
    # Load the time counter with the current time
    def load_time
      @time_counter = Time.new.to_i
    end
    # Return the time counter (current time - time counter)
    # @return [Integer]
    def time_counter
      counter = Time.new.to_i - @time_counter
      return counter < 0 ? 0 : counter
    end
    # Update the play time and reload the time counter
    # @return [Integer] the play time
    def update_play_time
      @play_time += time_counter
      load_time
      return @play_time
    end
    # Return the number of badges the trainer got
    # @return [Integer]
    def badge_counter
      @badges.count { |badge| badge == true }
    end
    # Set the got state of a badge
    # @param badge_num [1, 2, 3, 4, 5, 6, 7, 8] the badge
    # @param region [Integer] the region id (starting by 1)
    # @param value [Boolean] the got state of the badge
    def set_badge(badge_num, region = 1, value = true)
      region -= 1
      badge_num -= 1
      if (region * 8) >= @badges.size
        log_error('Le jeu ne prévoit pas de badge pour cette région. PSDK_ERR n°000_006')
      else
        if badge_num < 0 || badge_num > 7
          log_error('Le numéro de badge indiqué est invalide, il doit être entre 1 et 8. PSDK_ERR n°000_007')
        else
          @badges[(region * 8) + badge_num] = value
        end
      end
    end
    # Has the player got the badge ?
    # @param badge_num [1, 2, 3, 4, 5, 6, 7, 8] the badge
    # @param region [Integer] the region id (starting by 1)
    # @return [Boolean]
    def badge_obtained?(badge_num, region = 1)
      region -= 1
      badge_num -= 1
      if (region * 8) >= @badges.size
        log_error('Le jeu ne prévoit pas de badge pour cette région. PSDK_ERR n°000_006')
      else
        if badge_num < 0 || badge_num > 7
          log_error('Le numéro de badge indiqué est invalide, il doit être entre 1 et 8. PSDK_ERR n°000_007')
        else
          return @badges[(region * 8) + badge_num]
        end
      end
      return false
    end
    alias has_badge? badge_obtained?
    # Set the gender of the trainer
    # @param playing_girl [Boolean] if the trainer will be a girl
    def define_gender(playing_girl)
      @playing_girl = playing_girl
      game_state.game_switches[Yuki::Sw::Gender] = playing_girl
      game_state.game_variables[Yuki::Var::Player_ID] = id
      id_current_player = $game_variables[Yuki::Var::Current_Player_ID]
      game_state.game_actors[id_current_player].name = name
    end
    alias set_gender define_gender
    # Return the play time text (without updating it)
    # @return [String]
    def play_time_text
      time = @play_time
      hours = time / 3600
      minutes = (time - 3600 * hours) / 60
      return format(TIME_FORMAT, hours, minutes)
    end
    private
    # Return the default male name
    # @return [String]
    def default_male_name
      ext_text(9000, 2)
    end
    # Return the default female name
    # @return [String]
    def default_female_name
      ext_text(9000, 3)
    end
  end
  class GameState
    # The informations about the player and the game
    # @return [PFM::Trainer]
    attr_accessor :trainer
    on_player_initialize(:trainer) {@trainer = PFM.player_info_class.new(self) }
    on_expand_global_variables(:trainer) do
      $trainer = @trainer
      @trainer.game_state = self
    end
  end
end
PFM.player_info_class = PFM::Trainer
module GamePlay
  # Scene displaying the trainer card
  class TCard < BaseCleanUpdate::FrameBalanced
    # Coordinates of the player sprite
    PLAYER_COORDINATES = [222, 49]
    # Surface given to the player sprite
    PLAYER_SURFACE = [80, 73]
    # Coordinate of the first badge
    BADGE_ORIGIN_COORDINATE = [14, 30]
    # Offset between badges (x/y)
    BADGE_OFFSET = [48, 49]
    # Size of a badge in the badge image
    BADGE_SIZE = [32, 32]
    # Nmber of badge we can show in this UI
    BADGE_COUNT = 8
    # Create a new TCard interface
    def initialize
      super(true)
    end
    # Function that returns the actual play time of the trainer
    # @return [String] playtime formated like this %02d:%02d
    def current_play_time
      time = $trainer.update_play_time
      hours = time / 3600
      minutes = (time - 3600 * hours) / 60
      format('%<hours>02d %<sep>s %<mins>02d', hours: hours, sep: text_get(25, 6), mins: minutes)
    end
    # Make the UI act according to the inputs each frame
    def update_inputs
      return @running = false if Input.trigger?(:B)
      return true
    end
    # Called when mouse can be updated (put your mouse related code inside)
    # @param _moved [Boolean] boolean telling if the mouse moved
    def update_mouse(_moved)
      if Mouse.trigger?(:left)
        @mouse_button_cancel.set_press(@mouse_button_cancel.simple_mouse_in?)
      else
        if Mouse.released?(:left)
          @running = false if @mouse_button_cancel.simple_mouse_in?
          @mouse_button_cancel.set_press(false)
        end
      end
      return true
    end
    # Update the background animation
    def update_graphics
      @base_ui.update_background_animation
    end
    private
    # Create the UI Graphics
    def create_graphics
      create_viewport
      create_base_ui
      create_sub_background
      create_trainer_sprite
      create_badge_sprites
      create_texts
    end
    # Create the main background sprite
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
      @mouse_button_cancel = @base_ui.ctrl.last
    end
    # Create the sub background sprite (the dark surfaces in the TCard)
    def create_sub_background
      @sub_background = Sprite.new(@viewport).set_bitmap('tcard/background', :interface)
    end
    # Create the trainer sprite
    def create_trainer_sprite
      gender = $game_switches[1] ? '_f' : '_m'
      gp = $game_player
      filename = "tcard/#{gp.charset_base}#{gender}" if RPG::Cache.interface_exist?("tcard/#{gp.charset_base}#{gender}")
      filename ||= "tcard/#{$game_player.charset_base}"
      @trainer_sprite = Sprite.new(@viewport).set_bitmap(filename, :interface)
      @trainer_sprite.set_origin((@trainer_sprite.width - PLAYER_SURFACE.first) / 2, (@trainer_sprite.height - PLAYER_SURFACE.last) / 2)
      @trainer_sprite.set_position(*PLAYER_COORDINATES)
    end
    # Create the badge sprites
    def create_badge_sprites
      @badges = Array.new(BADGE_COUNT) do |index|
        sprite = Sprite.new(@viewport).set_bitmap('tcard/badges', :interface)
        sprite.set_position(BADGE_ORIGIN_COORDINATE.first + (index % 2) * BADGE_OFFSET.first, BADGE_ORIGIN_COORDINATE.last + (index / 2) * BADGE_OFFSET.last)
        sprite.src_rect.set((index % 2) * BADGE_SIZE.first, (index / 2) * BADGE_SIZE.last, *BADGE_SIZE)
        sprite.visible = $trainer.has_badge?(index + 1)
        next((sprite))
      end
    end
    # Create the texts
    def create_texts
      @texts = UI::SpriteStack.new(@viewport)
      create_start_time
      create_money
      create_name
      create_do
      create_badge
      create_play_time
    end
    def create_start_time
      @texts.add_text(4, 4, 0, 16, "#{text_get(34, 14)} #{Time.at($trainer.start_time).strftime('%d/%m/%Y')}", color: 9)
    end
    def create_money
      @texts.add_text(225, 4, 88, 16, "#{PFM.game_state.money}$", 2, color: 9)
    end
    def create_name
      @texts.add_text(217, 26, 96, 16, $trainer.name, 1, color: 9)
    end
    def create_do
      @texts.add_text(217, 128, 96, 16, format('%<text>s %<id>05d', text: text_get(34, 2), id: $trainer.id % 100_000), color: 9)
    end
    def create_badge
      @texts.add_text(122, 156, 190, 16, "#{text_get(25, 1)} #{$trainer.badge_counter}", color: 9)
    end
    def create_play_time
      @texts.add_text(122, 190, 190, 16, "#{text_get(25, 5)} #{current_play_time}", color: 9)
    end
    # Get the button text for the generic UI
    # @return [Array<String>]
    def button_texts
      return [nil, nil, nil, ext_text(9000, 115)]
    end
  end
end
GamePlay.player_info_class = GamePlay::TCard
