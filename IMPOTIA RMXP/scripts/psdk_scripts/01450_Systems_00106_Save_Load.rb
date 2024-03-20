module Configs
  # Configuration of the saves
  class SaveConfig
    # Number of save the player can have
    # @return [Integer] 0 = infinite
    attr_accessor :maximum_save_count
    # Get the header of the save file (preventing other fangames to read the save if changed)
    # @return [String]
    attr_accessor :save_header
    # Get the save key (preventing other fangames to read the save if changed)
    # @return [Integer]
    attr_accessor :save_key
    # Get the base filename of the save
    # @return [String]
    attr_accessor :base_filename
    # Tell if the player is allowed to save over another save
    # @return [Boolean]
    attr_accessor :can_save_on_any_save
    # Tell if the player can have unlimited saves
    # @return [Boolean]
    def unlimited_saves?
      @maximum_save_count == 0
    end
    # Tell if the player is restricted to 1 save
    # @return [Boolean]
    def single_save?
      @maximum_save_count == 1
    end
  end
  module Project
    # Allow configuration of the saves from being accessed through the Project module
    Save = SaveConfig
  end
  register(:save_config, 'save_config', :json, true, SaveConfig)
end
module UI
  # UI element showing the save information
  class SaveSign < SpriteStack
    # Get the index of the save
    # @return [Integer]
    attr_accessor :save_index
    # Get the visual index of the save sign
    # @return [Integer]
    attr_accessor :visual_index
    # String shown when a save is corrupted
    CORRUPTED_MESSAGE = 'Corrupted Save File'
    # String shown when a save is not corrupted and can be choosen
    SAVE_INDEX_MESSAGE = 'Save %d'
    # Create a new save sign
    # @param viewport [Viewport]
    # @param visual_index [Integer]
    def initialize(viewport, visual_index)
      super(viewport, *coordinates(visual_index))
      create_sprites
      @save_index = 0
      @visual_index = visual_index
    end
    # Set the data of the SaveSign
    # @param value [PFM::GameState, Symbol] :new if new game, :corrupted if corrupted
    def data=(value)
      @data = value
      self.visible = true
      case value
      when :new
        show_new_game
      when :corrupted
        show_corrupted
      when :hidden
        self.visible = false
      else
        show_data(value)
      end
      @cursor&.visible = @visual_index == 0
    end
    # Update the animation
    def update
      super
      @animation&.update
    end
    # Tell if the animation is done
    # @return [Boolean]
    def done?
      return true unless @animation
      return @animation.done?
    end
    # Start the animation of moving between index
    # @param target_visual_index [Integer]
    def move_to_visual_index(target_visual_index)
      real_visual_index = @visual_index == -1 && target_visual_index == 3 ? -2 : target_visual_index
      real_visual_index = @visual_index == 3 && real_visual_index == -1 ? 4 : real_visual_index
      @cursor.visible = false
      @animation = Yuki::Animation.move_discreet(0.1, self, *coordinates(@visual_index), *coordinates(real_visual_index))
      @animation.play_before(Yuki::Animation.send_command_to(self, :set_position, *coordinates(target_visual_index)))
      @animation.play_before(Yuki::Animation.send_command_to(self, :animate_cursor)) if target_visual_index == 0
      @animation.start
      @visual_index = target_visual_index
    end
    # Animate the cursor when moving
    def animate_cursor
      @cursor.visible = true
      @animation = Yuki::Animation::TimedLoopAnimation.new(1)
      @animation.play_before(Yuki::Animation.wait(1))
      parallel = Yuki::Animation.send_command_to(@cursor, :sy=, 0)
      parallel.play_before(Yuki::Animation.wait(0.5))
      parallel.play_before(Yuki::Animation.send_command_to(@cursor, :sy=, 1))
      @animation.parallel_add(parallel)
      @animation.start
    end
    # Get the coordinate of the element based on its coordinate
    # @param visual_index [Integer] visual index of the UI element
    # @return [Array<Integer>]
    def coordinates(visual_index)
      return [base_x + visual_index * spacing_x, base_y + visual_index * spacing_y]
    end
    private
    def show_new_game
      @swap_sprites.each { |sp| sp.visible = false }
      @background.load('load/box_new', :interface)
      @cursor.load('load/cursor_corrupted_new', :interface)
      @new_corrupted_text.text = ext_text(9000, 0)
    end
    def show_corrupted
      @swap_sprites.each { |sp| sp.visible = false }
      @background.load('load/box_corrupted', :interface)
      @cursor.load('load/cursor_corrupted_new', :interface)
      @new_corrupted_text.text = corrupted_message
    end
    # Show the save data
    # @param value [PFM::GameState]
    def show_data(value)
      @swap_sprites.each { |sp| sp.visible = true }
      @background.load('load/box_main', :interface)
      @cursor.load('load/cursor_main', :interface)
      @save_text.text = format(save_index_message, @save_index)
      @new_corrupted_text.visible = false
      show_save_data(value)
    end
    # Show the save data
    # @param value [PFM::GameState]
    def show_save_data(value)
      @player_sprite.load(value.game_player.character_name, :character)
      @player_sprite.set_origin(@player_sprite.width / 2, @player_sprite.height)
      $game_actors = value.game_actors
      $game_variables = value.game_variables
      @location_text.text = PFM::Text.parse_string_for_messages(value.env.current_zone_name)
      @player_name.text = value.trainer.name
      @badge_value&.text = value.trainer.badge_counter.to_s
      @pokedex_value&.text = value.pokedex.creature_seen.to_s
      @time_value&.text = value.trainer.play_time_text
      @pokemon_sprites.each_with_index do |sprite, index|
        sprite.data = value.actors[index]
      end
    ensure
      $game_actors = PFM.game_state&.game_actors
      $game_variables = PFM.game_state&.game_variables
    end
    def create_sprites
      @swap_sprites = []
      create_background
      create_cursor
      create_player_sprite
      create_player_name
      create_save_text
      create_save_info_text
      create_pokemon_sprites
    end
    def create_background
      @background = add_sprite(0, 0, NO_INITIAL_IMAGE)
    end
    def create_cursor
      @cursor = add_sprite(-4, -4, NO_INITIAL_IMAGE, 1, 2, type: SpriteSheet)
    end
    def create_player_sprite
      @player_sprite = add_sprite(44, 62, NO_INITIAL_IMAGE, 4, 4, type: SpriteSheet)
      @swap_sprites << @player_sprite
    end
    def create_player_name
      @player_name = add_text(45, 63, 0, 16, '', 1, color: player_name_color)
      @swap_sprites << @player_name
    end
    def create_save_text
      @save_text = add_text(0, 1, 226, 16, '', 1)
      @new_corrupted_text = add_text(0, 4, 226, 16, '', 1, color: 10)
      @swap_sprites << @save_text
    end
    def create_save_info_text
      @location_text = add_text(91, 19, 0, 16, '', color: location_color)
      @swap_sprites << @location_text
      @badge_text = add_text(91, 35, 0, 16, text_get(25, 1), color: info_color)
      @swap_sprites << @badge_text
      @badge_value = add_text(216, 35, 0, 16, '', 2, color: info_color)
      @swap_sprites << @badge_value
      @pokedex_text = add_text(91, 51, 0, 16, text_get(25, 3), color: info_color)
      @swap_sprites << @pokedex_text
      @pokedex_value = add_text(216, 51, 0, 16, '', 2, color: info_color)
      @swap_sprites << @pokedex_value
      @time_text = add_text(91, 67, 0, 16, text_get(25, 5), color: info_color)
      @swap_sprites << @time_text
      @time_value = add_text(216, 67, 0, 16, '', 2, color: info_color)
      @swap_sprites << @time_value
    end
    def create_pokemon_sprites
      @pokemon_sprites = Array.new(6) { |i| add_sprite(24 + i * 35, 99, NO_INITIAL_IMAGE, type: PokemonIconSprite) }
      @swap_sprites.concat(@pokemon_sprites)
    end
    def player_name_color
      9
    end
    def location_color
      0
    end
    def info_color
      26
    end
    def corrupted_message
      CORRUPTED_MESSAGE
    end
    def save_index_message
      SAVE_INDEX_MESSAGE
    end
    def base_x
      47
    end
    def base_y
      51
    end
    def spacing_x
      240
    end
    def spacing_y
      0
    end
  end
end
module GamePlay
  # Load game scene
  class Load < BaseCleanUpdate
    # Create a new GamePlay::Load scene
    def initialize
      super()
      Studio::Text.load
      @running = true
      @index = 0
      @all_saves = load_all_saves
      @all_saves.clear if @all_saves.size == 1 && @all_saves.first.nil?
      @mode = :waiting_input
    end
    # Update the load scene graphics
    def update_graphics
      @base_ui&.update_background_animation
      @signs.each(&:update)
    end
    # Tell if the Title should automatically create a new game instead
    # @return [Boolean]
    def should_make_new_game?
      @all_saves.empty?
    end
    private
    def create_graphics
      super
      create_base_ui
      create_shadow
      create_frame
      create_signs
    end
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
    end
    def button_texts
      [nil, nil, nil, ext_text(9000, 115)]
    end
    def create_shadow
      @shadow = Sprite.new(@viewport)
      @shadow.load('load/shadow_save', :interface)
      @shadow.visible = false
    end
    def create_frame
      @frame = Sprite.new(@viewport)
      @frame.load('load/frame_load', :interface)
    end
    def create_signs
      @signs = (-1).upto(3).map do |i|
        UI::SaveSign.new(viewport, i)
      end
      load_sign_data
      @signs[1].animate_cursor
    end
    def load_sign_data
      max_save = Configs.save_config.maximum_save_count
      unlimited = Configs.save_config.unlimited_saves?
      @signs.each_with_index do |sign, i|
        index = i + @index - 1
        next(sign.data = :hidden) if index < 0 || index > @all_saves.size || (index >= max_save && !unlimited)
        data = @all_saves[index]
        next(sign.data = index >= @all_saves.size ? :new : :corrupted) unless data
        sign.save_index = index + 1
        sign.data = data
      end
    end
    public
    private
    # Function responsive of loading all the existing saves
    # @return [Array<PFM::GameState>]
    def load_all_saves
      save_index = Save.save_index
      game_state = PFM.game_state
      Save.save_index = 0
      base_filename = Save.save_filename
      return [Save.load(base_filename)] if Configs.save_config.single_save?
      all_saves = Dir["#{base_filename}*"].reject { |i| i.end_with?('.bak') }.map { |i| i.sub(base_filename, '').gsub(/[^0-9]/, '').to_i }
      all_saves.reject! { |i| i > Configs.save_config.maximum_save_count } unless Configs.save_config.unlimited_saves?
      last_save = all_saves.max || 0
      return last_save.times.map do |i|
        Save.save_index = i + 1
        next(Save.load(no_load_parameter: true))
      end
    ensure
      Save.save_index = save_index
      $pokemon_party = PFM.game_state = game_state
    end
    public
    # CTRL button actions
    ACTIONS = %i[action_a action_a action_a action_b]
    # Update the load scene inputs
    def update_inputs
      return false unless @signs.first.done?
      rotate_signs if @mode == :rotating
      if Input.trigger?(:A)
        action_a
      else
        if Input.trigger?(:B)
          action_b
        else
          if Input.repeat?(:LEFT)
            action_left
          else
            if Input.repeat?(:RIGHT)
              action_right
            end
          end
        end
      end
    end
    # Update the load scene mouse interactions
    def update_mouse(*)
      if Mouse.wheel_delta > 0
        action_left
      else
        if Mouse.wheel_delta < 0
          action_right
        else
          if Mouse.trigger?(:LEFT) && @signs[1].simple_mouse_in?
            action_a
          else
            if Mouse.trigger?(:RIGHT)
              action_b
            else
              update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS)
              return
            end
          end
        end
      end
      Mouse.wheel = 0
    end
    private
    def rotate_signs
      @signs.rotate!(@signs.first.visual_index == 0 ? -1 : 1)
      load_sign_data
      @mode = :waiting_input
    end
    def action_left
      last_visible_index = @all_saves.size
      if @index == 0
        @index = last_visible_index
      else
        @index -= 1
      end
      play_cursor_se
      @mode = :rotating
      @signs.each do |sign|
        sign.move_to_visual_index(sign.visual_index == 3 ? -1 : sign.visual_index + 1)
      end
    end
    def action_right
      last_visible_index = @all_saves.size
      if @index == last_visible_index
        @index = 0
      else
        return if @index >= last_visible_index
        return if (!Configs.save_config.unlimited_saves? && (@index + 1) >= Configs.save_config.maximum_save_count)
        @index += 1
      end
      play_cursor_se
      @mode = :rotating
      @signs.each do |sign|
        sign.move_to_visual_index(sign.visual_index == -1 ? 3 : sign.visual_index - 1)
      end
    end
    def action_b
      play_decision_se
      @running = false
      $scene = Scheduler.get_boot_scene
    end
    def action_a
      play_decision_se
      Save.save_index = Configs.save_config.single_save? ? 0 : @index + 1
      if @index < @all_saves.size && @all_saves[@index]
        Graphics.update
        load_game
      else
        create_new_game
      end
    end
    public
    # Create a new game and start it
    def create_new_game
      create_new_party
      PFM.game_state.expand_global_var
      PFM.game_state.load_parameters
      $trainer.redefine_var
      $scene = Scene_Map.new
      Yuki::TJN.force_update_tone
      @running = false
    end
    private
    # Load the current game
    def load_game
      @all_saves[@index].expand_global_var
      PFM.game_state.load_parameters
      $game_system.se_play($data_system.cursor_se)
      $game_map.setup($game_map.map_id)
      $game_player.moveto($game_player.x, $game_player.y)
      $game_party.refresh
      $game_system.bgm_play($game_system.playing_bgm)
      $game_system.bgs_play($game_system.playing_bgs)
      $game_map.update
      $game_temp.message_window_showing = false
      $trainer.load_time
      Pathfinding.load
      $trainer.redefine_var
      Yuki::FollowMe.set_battle_entry
      PFM.game_state.env.reset_zone
      $scene = Scene_Map.new
      Yuki::TJN.force_update_tone
      @running = false
    end
    # Creaye a new Pokemon Party object and ask the language if possible
    def create_new_party
      PFM.game_state = PFM::GameState.new(false, Configs.language.default_language_code)
      PARGV.update_game_opts("--lang=#{Configs.language.default_language_code}") if @all_saves.empty?
    end
  end
  # Scene responsive of displaying the language choice when creating a new game
  class Language_Choice < BaseCleanUpdate::FrameBalanced
    # If the change of index is animated
    ANIME_CHANGE = true
    # Number of frame for index change
    ANIME_FRAMES = 6
    # Initialize the scene
    def initialize
      super()
      @running = true
      @lang_list = Configs.language.choosable_language_code
      @index = @lang_list.find_index(Configs.language.default_language_code)
      @counter = 0
    end
    # Create the graphics
    def create_graphics
      create_viewport
      @stack = UI::SpriteStack.new(@viewport)
      @frame = @stack.add_sprite(0, 0, 'language/frame')
      @flag_left = @stack.add_sprite(-76, 85, nil)
      @flag_left.opacity = 192
      @flag_center = @stack.add_sprite(91, 81, nil)
      @flag_center.opacity = 255
      @flag_right = @stack.add_sprite(258, 85, nil)
      @flag_right.opacity = 192
      @flag_right.zoom = @flag_left.zoom = 0.9
      @cursor = @stack.add_sprite(91 - 4, 81 - 4, 'language/cursors', 1, 2, type: SpriteSheet)
      @base_ui = UI::GenericBase.new(@viewport, hide_background_and_button: true)
      update_index
    end
    # Update the graphics
    def update_graphics
      @base_ui.update_background_animation
      @counter += 1
      if @counter >= 60
        @counter = 0
      else
        if @counter >= 30
          @cursor.sy = 0
        else
          @cursor.sy = 1
        end
      end
    end
    # Update the inputs
    def update_inputs
      if Input.repeat?(:LEFT)
        @index = @index != 0 ? @index - 1 : @lang_list.size - 1
        move(false) if ANIME_CHANGE
        update_index
      else
        if Input.repeat?(:RIGHT)
          @index = @index != @lang_list.size - 1 ? @index + 1 : 0
          move(true) if ANIME_CHANGE
          update_index
        end
      end
      if Input.trigger?(:A)
        @running = false
        Configs.language.default_language_code = @lang_list[@index]
      end
    end
    private
    # Update the index
    def update_index
      left_index = @index != 0 ? @index - 1 : @lang_list.size - 1
      right_index = @index != @lang_list.size - 1 ? @index + 1 : 0
      @flag_left.set_bitmap("language/flags/flag_#{@lang_list[left_index]}", :interface)
      @flag_center.set_bitmap("language/flags/flag_#{@lang_list[@index]}", :interface)
      @flag_right.set_bitmap("language/flags/flag_#{@lang_list[right_index]}", :interface)
    end
    # Move animation
    # TODO: Use real animation istead of code!
    # @param left [Boolean] if we're moving left
    def move(left)
      @cursor.visible = false
      @flag_center.zoom = 0.9
      @flag_center.x = 85
      @flag_center.opacity = 192
      left ? move_left_animation : move_right_animation
      @flag_left.x = -76
      @flag_center.x = 91
      @flag_center.opacity = 255
      @flag_center.y = 81
      @flag_center.zoom = 1.0
      @flag_right.x = 258
      update_index
      @cursor.visible = true
      @stack.stack.pop.dispose
    end
    # Animation when moving left
    def move_left_animation
      filename = "language/flags/flag_#{@lang_list[(@index - 2) % @lang_list.size]}"
      tmp = @stack.add_sprite(@flag_right.x + @flag_right.width + 37, 85, filename)
      tmp.opacity = 192
      tmp.zoom = 0.9
      ANIME_FRAMES.times do
        @flag_center.x -= 167 / ANIME_FRAMES
        @flag_left.x -= 167 / ANIME_FRAMES
        @flag_right.x -= 167 / ANIME_FRAMES
        tmp.x -= 167 / ANIME_FRAMES
        update_graphics
        Graphics.update
      end
    end
    # Animation when moving right
    def move_right_animation
      filename = "language/flags/flag_#{@lang_list[(@index + 2) % @lang_list.size]}"
      tmp = @stack.add_sprite(@flag_left.x - @flag_left.width - 37, 85, filename)
      tmp.opacity = 192
      tmp.zoom = 0.9
      ANIME_FRAMES.times do
        @flag_center.x += 167 / ANIME_FRAMES
        @flag_left.x += 167 / ANIME_FRAMES
        @flag_right.x += 167 / ANIME_FRAMES
        tmp.x += 167 / ANIME_FRAMES
        update_graphics
        Graphics.update
      end
    end
  end
  # Save game scene
  class Save < Load
    # MultiSave file format
    MULTI_SAVE_FORMAT = '%s-%d'
    # List of the usable root path for the save state
    SAVE_ROOT_PATHS = ['.', ENV['APPDATA'] || Dir.home, Dir.home]
    @save_index = 0
    # @return [Boolean] if the game was saved
    attr_reader :saved
    # Create a new GamePlay::Save
    def initialize
      super
      make_save_directory
      @saved = false
      @index = Configs.save_config.single_save? ? 0 : Save.save_index - 1
      @index = 0 if @index < 0
    end
    # Return the current GameState object
    # @return [GameState, nil]
    def current_game_state
      PFM.game_state || Save.load
    end
    # Save the game (method allowing hooks on the save)
    def save_game
      Save.save
    end
    private
    def create_frame
      @frame = Sprite.new(@viewport)
      @frame.load('load/frame_save', :interface)
    end
    def button_texts
      [text_get(14, 4), nil, nil, ext_text(9000, 115)]
    end
    # Function creating the save directory
    def make_save_directory
      directory = File.dirname(Save.save_filename)
      Dir.mkdir!(directory)
    end
    undef create_new_game
    public
    private
    def action_left
      return play_buzzer_se unless Configs.save_config.can_save_on_any_save
      super
    end
    def action_right
      return play_buzzer_se unless Configs.save_config.can_save_on_any_save
      super
    end
    def action_b
      play_decision_se
      @running = false
    end
    def action_a
      Save.save_index = Configs.save_config.single_save? ? 0 : @index + 1
      save_game
      @saved = true
      @running = false
      play_save_se
    end
    def play_save_se
      play_decision_se
    end
    public
    # @return [Hash] all the before save hooks
    BEFORE_SAVE_HOOKS = {game_map: proc {$game_map.begin_save }, encounters_history: proc {$wild_battle.begin_save }}
    # @return [Hash] all the after save hooks
    AFTER_SAVE_HOOKS = {game_map: proc {$game_map.end_save }, encounters_history: proc {$wild_battle.end_save }}
    class << self
      # @return [Integer] index of the save file (to allow multi-save)
      attr_accessor :save_index
      # Save a game
      # @param filename [String, nil] name of the save file (nil = auto name the save file)
      # @param no_file [Boolean] tell if the save should not be saved to file and just be returned
      def save(filename = nil, no_file = false)
        return 'NONE' unless $game_temp
        clear_states
        update_save_info
        BEFORE_SAVE_HOOKS.each_value(&:call)
        save_data = Configs.save_config.save_header.dup.force_encoding(Encoding::ASCII_8BIT)
        save_data << encrypt(Marshal.dump(PFM.game_state))
        save_file(filename || Save.save_filename, save_data) unless no_file
        AFTER_SAVE_HOOKS.each_value(&:call)
        return save_data
      end
      # Load a game
      # @param filename [String, nil] name of the save file (nil = auto name the save file)
      # @param no_load_parameter [Boolean] if the system should not call load_parameters
      # @return [PFM::GameState, nil] The save data (nil = no save data / data corruption)
      # @note Change PFM.game_state
      def load(filename = nil, no_load_parameter: false)
        filename ||= Save.save_filename
        return nil unless File.exist?(filename)
        header = Configs.save_config.save_header
        data = File.binread(filename)
        file_header = data[0...(header.size)]
        return nil if file_header != header
        PFM.game_state = Marshal.load(encrypt(data[header.size..-1]))
        PFM.game_state.load_parameters unless no_load_parameter
        return PFM.game_state
      rescue LoadError, StandardError
        log_error("Corrupted save error: #{$!.class} => #{$!.message}")
        return nil
      end
      # Get the root path of the save for the game
      def save_root_path
        SAVE_ROOT_PATHS.find(&File.method(:writable?)) || ''
      end
      # Get the filename of the current save
      def save_filename
        root = save_root_path.tr('\\', '/').encode(Encoding::UTF_8)
        game_name = root.start_with?('.') ? '' : ".#{Configs.infos.game_title}/"
        base_filename = Configs.save_config.base_filename
        filename = (@save_index > 0 ? format(MULTI_SAVE_FORMAT, base_filename, @save_index) : base_filename)
        return format('%<root>s/%<game_name>s%<filename>s', root: root, game_name: game_name, filename: filename)
      end
      private
      # Function that encrypt / decrypt the save
      # @param data [String]
      # @return [String]
      def encrypt(data)
        return data if Configs.save_config.save_key == 0
        data << "\x00\x00\x00"
        key = Configs.save_config.save_key
        return data.unpack('I*').map { |i| i ^ key }.pack('I*')
      end
      # Function that clears the sate
      def clear_states
        $game_temp.message_proc = nil
        $game_temp.choice_proc = nil
        $game_temp.battle_proc = nil
        $game_temp.message_window_showing = false
      end
      # Function that update the save info (current game version, current PSDK version etc...)
      def update_save_info
        $game_system.save_count += 1
        $trainer.update_play_time
        $trainer.current_version = PSDK_VERSION
        $trainer.game_version = Configs.infos.game_version
      end
      # Function that actually save the file
      # @param filename [String]
      # @param save_data [String] save_data
      def save_file(filename, save_data)
        backup_filename = "#{filename}.bak"
        File.delete(backup_filename) if File.exist?(backup_filename)
        File.rename(filename, backup_filename) if File.exist?(filename)
        File.binwrite(filename, save_data)
        if File.binread(filename) != save_data
          $scene.display_message_and_wait(text_get(26, 19))
          File.rename(backup_filename, filename) if File.exist?(backup_filename)
        end
      rescue Exception
        $scene.display_message_and_wait(text_get(26, 19))
      end
    end
  end
end
