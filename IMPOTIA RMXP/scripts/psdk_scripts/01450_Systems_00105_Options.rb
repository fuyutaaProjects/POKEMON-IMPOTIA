module PFM
  # The options data
  #
  # The options are stored in $options and PFM.game_state.options
  # @author Nuri Yuri
  class Options
    # The volume of the BGM and ME
    # @return [Integer]
    attr_reader :music_volume
    # The volume of the BGS and SE
    # @return [Integer]
    attr_reader :sfx_volume
    # The speed of the message display
    # @return [Integer]
    attr_reader :message_speed
    # If the battle ask to switch pokemon or not
    # @return [Boolean]
    attr_accessor :battle_mode
    # If the battle show move animations
    # @return [Boolean]
    attr_accessor :show_animation
    # If the battle ask to rename Pokémon at capture
    # @return [Boolean]
    attr_accessor :catch_rename
    # The lang id of the Studio::Text loads
    # @return [String]
    attr_reader :language
    # The message frame
    # @return [String]
    attr_reader :message_frame
    # The display resolution
    # @return [Integer]
    attr_reader :screen_scale
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Create a new Option object with a language
    # @param starting_language [String] the lang id the game will start
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(starting_language, game_state = PFM.game_state)
      @music_volume = 100
      @sfx_volume = 100
      @message_speed = 3
      @battle_mode = true
      @show_animation = true
      @catch_rename = true
      @language = starting_language
      @screen_scale = Graphics.window.settings[3]
      @game_state = game_state
      self.message_frame = Configs.window.message_frame_filenames.first
    end
    # Change the master volume
    # @param value [Integer] the new master volume
    def music_volume=(value)
      return unless value.between?(0, 100)
      @music_volume = Audio.music_volume = value
    end
    # Change the SFX volume
    # @param value [Integer] the new sfx volume
    def sfx_volume=(value)
      return unless value.between?(0, 100)
      @sfx_volume = Audio.sfx_volume = value
    end
    # Change both music & sfx volume at the same time
    # @param value [Integer] the new volume
    def master_volume=(value)
      self.music_volume = value
      self.sfx_volume = value
    end
    alias master_volume music_volume
    # Change the in game lang (reload the texts)
    # @param value [String] the new lang id
    def language=(value)
      return unless Studio::Text::Available_Langs.include?(value)
      @language = value
      Studio::Text.load
    end
    alias set_language language=
    # Change the message speed
    # @param value [Integer] the new message speed
    def message_speed=(value)
      @message_speed = value.clamp(1, 999)
    end
    # Change the message frame
    # @param value [String] the new message frame
    def message_frame=(value)
      return unless Configs.window.message_frame_filenames.include?(value)
      @message_frame = value
      $game_system&.windowskin_name = @message_frame
    end
    # Change the display resolution
    # @param value [Integer] the new display resolution
    def screen_scale=(value)
      Graphics.screen_scale = value
      @screen_scale = value
    end
  end
  class GameState
    # The game options
    # @return [PFM::Options]
    attr_accessor :options
    on_player_initialize(:options) {@options = PFM.options_class.new(@starting_language, self) }
    on_expand_global_variables(:options) do
      $options = @options
      @options.game_state = self
    end
  end
end
PFM.options_class = PFM::Options
module UI
  module Options
    # Class that shows the option description
    class Description < SpriteStack
      # Create a new InfoWide
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 0, 45)
        create_sprites
      end
      private
      def create_sprites
        add_background('options/description')
        @name = add_text(3, 19, 0, 13, :name, type: SymText, color: 25)
        @descr = add_text(3, 37, 151, 16, :description, type: SymMultilineText)
      end
    end
    # Arrow telling which option is selected
    class Arrow < Sprite
      # Create a new arrow
      # @param viewport [Viewport]
      def initialize(viewport)
        super
        set_bitmap('options/arrow', :interface)
        set_origin(0, height / 2)
        @counter = 0
      end
      # Update the arrow animation
      def update
        if @counter == 30
          self.x += 1
        else
          if @counter == 60
            self.x -= 1
            @counter = 0
          end
        end
        @counter += 1
      end
    end
    # Button UI element
    class Button < SpriteStack
      # Offset Y of each options
      OPTION_OFFSET_Y = 40
      # Base X of each options
      OPTION_BASE_X = 19
      # Offset X of each options
      OPTION_OFFSET_X = 4
      # Option modified by the button
      # @return [GamePlay::Options::Helper]
      attr_reader :option
      # Current value shown by the button
      # @return [Option]
      attr_reader :value
      # Create a new Option Button
      # @param viewport [Viewport]
      # @param index [Integer] index of the option in the order
      # @param option [GamePlay::Options::Helper]
      def initialize(viewport, index, option)
        super(viewport, OPTION_BASE_X, OPTION_OFFSET_Y * index)
        @option = option
        @value = option.current_value
        @option_background = add_background('options/option')
        @option_name = add_text(8, 3, 0, 16, @option.name, color: 10)
        @option_value = add_text(14, 19, 96, 16, value_text, 1)
      end
      # Return the value index
      # @return [Integer]
      def value_index
        return @value if @option.type == :slider
        @option.values.index(@value) || 0
      end
      # Set the current value shown by the button
      # @param new_value [Object]
      def value=(new_value)
        @value = new_value
        @option_value.text = value_text
      end
      # Retreive the option value text
      # @return [String]
      def value_text
        return format(@option.values_text, @value) if @option.type == :slider
        @option.values_text[value_index]
      end
      # Reload the name of the button for when the language is changed in the options
      def reload_texts
        @option_name.text = @option.name
        @option_value.text = value_text
      end
    end
  end
  # Class that allow to see the KeyBinding for the PSDK virtual key
  #
  # This object has two indexes :
  #   - main_index : It's the index of the PSDK Key we want to see
  #   - key_index : It's the index of the Binding we want to change
  #       if key_index is negative, it's not showing the index sprite
  #
  # This object has a blink state linked to #update_blink allowing to tell the key is currently being edited
  class KeyBindingViewer < SpriteStack
    # X position of the first text
    FT_X = 12
    # X position of the second text
    ST_X = 72
    # X position of the last text & the first button
    LT_X = 208
    # Y position of the first key text
    FKT_Y = 26
    # @return [Boolean] if the UI is in blinking mode
    attr_reader :blinking
    # @return [Integer] the main index
    attr_reader :main_index
    # @return [Integer] the key index
    attr_reader :key_index
    # Create a new KeyBindingViewer
    def initialize(viewport)
      super(viewport, 3, 48)
      create_sprites
      @counter = 0
      self.main_index = 0
      self.key_index = -1
      self.blinking = false
    end
    # List of the Key to create with their information (PSDK name, Descr)
    KEYS = [[:A, 4, 13], [:B, 5, 14], [:X, 6, 15], [:Y, 7, 16], [:UP, 8, 17], [:DOWN, 9, 18], [:RIGHT, 10, 19], [:LEFT, 11, 20]]
    # Update the blink animation
    def update_blink
      return unless @blinking
      @counter += 1
      if @counter == 30
        @buttons[@main_index * 5 + @key_index]&.visible = false
      else
        if @counter >= 60
          @buttons[@main_index * 5 + @key_index]&.visible = true
          @counter = 0
        end
      end
    end
    # Update all the buttons
    def update
      @buttons.each(&:update)
    end
    # Set the blinking state
    # @param value [Boolean] the new blinking state
    def blinking=(value)
      @blinking = value
      @counter = 0
      @buttons[@main_index * 5 + @key_index]&.visible = true unless value
    end
    # Set the new main index value
    # @param value [Integer]
    def main_index=(value)
      value = KEYS.size - 1 if value < 0
      value = 0 if value >= KEYS.size
      @main_index = value
      @sub_selector.y = @main_selector.y = @y + FKT_Y + 16 * value + 1
    end
    # Set the new key index value
    # @param value [Integer]
    def key_index=(value)
      value = -1 if value < 0
      @key_index = value
      if value == -1
        @sub_selector.visible = false
      else
        @sub_selector.visible = true
        @sub_selector.x = @x + LT_X + 16 * value + 1
      end
    end
    # Get the current key (to update the Input::Keys)
    # @return [Symbol]
    def current_key
      return :A if @key_index < 0
      @buttons[@main_index * 5 + @key_index]&.key || :A
    end
    # Get the current key index according to the button
    def current_key_index
      return -1 if @key_index < 0
      @buttons[@main_index * 5 + @key_index]&.index || 0
    end
    private
    def create_sprites
      push(0, 0, 'key_binding/cadre')
      @main_selector = push(FT_X - 1, FKT_Y + 1, 'key_binding/selecteur_blue')
      @sub_selector = push(LT_X + 1, FKT_Y + 1, 'key_binding/selecteur_red')
      create_top_line
      create_keys
    end
    # Create the top line
    def create_top_line
      add_text(FT_X, 5, 100, 16, ext_text(8998, 0), color: 9)
      add_text(ST_X, 5, 100, 16, ext_text(8998, 1), color: 9)
      add_text(LT_X, 5, 100, 16, ext_text(8998, 2), color: 9)
    end
    # Create all the key texts & button
    def create_keys
      @buttons = []
      KEYS.each_with_index do |key_info, index|
        create_key(index, *key_info)
      end
    end
    # Create a single key line
    # @param index [Integer] Index of the key in the array
    # @param name [Symbol] name of the key in Input
    # @param psdk_text_id [Integer] id of the text telling the name of the key
    # @param descr_text_id [Integer] id of the text telling what the key does
    def create_key(index, name, psdk_text_id, descr_text_id)
      add_text(FT_X, FKT_Y + 16 * index, 100, 16, ext_text(8998, psdk_text_id))
      add_text(ST_X, FKT_Y + 16 * index, 100, 16, ext_text(8998, descr_text_id))
      4.times do |i|
        @buttons << push(LT_X + i * 16, FKT_Y + 16 * index, nil, name, i, type: KeyBinding)
      end
      @buttons << push(LT_X + 64, FKT_Y + 16 * index, nil, name, type: JKeyBinding)
    end
  end
end
module GamePlay
  # Mixin allowing people to know what's the output of the Option scene
  module OptionsMixin
    # List of options that were modifies
    # @return [Array<Symbol>]
    attr_reader :modified_options
  end
  class Options < BaseCleanUpdate::FrameBalanced
    # List of valid option type
    VALID_OPTION_TYPE = %i[choice slider]
    # How to get message frames
    MESSAGE_FRAME = 'GameData::Windows::MESSAGE_FRAME'
    # How to get message frame names
    MESSAGE_FRAME_NAMES = 'GameData::Windows::MESSAGE_FRAME_NAMES'
    # All the pre-defined options
    PREDEFINED_OPTIONS = {message_speed: [:message_speed, :choice, [1, 2, 3], [[:text_get, 42, 4], [:text_get, 42, 5], [:text_get, 42, 6]], [:text_get, 42, 3], [:text_get, 42, 7], :message_speed], message_frame: [:message_frame, :choice, MESSAGE_FRAME, MESSAGE_FRAME_NAMES, [:ext_text, 9000, 165], [:ext_text, 9000, 166], :message_frame], volume: [:volume, :slider, {min: 0, max: 100, increment: 1}, '%d%%', [:ext_text, 9000, 29], [:ext_text, 9000, 30], :master_volume], battle_animation: [:battle_animation, :choice, [true, false], [[:text_get, 42, 9], [:text_get, 42, 10]], [:text_get, 42, 8], [:text_get, 42, 11], :show_animation], battle_style: [:battle_style, :choice, [true, false], [[:text_get, 42, 13], [:text_get, 42, 14]], [:text_get, 42, 12], [:text_get, 42, 15], :battle_mode], screen_scale: [:screen_scale, :choice, [1, 2, 3, 4], [[:ext_text, 9008, 2], [:ext_text, 9008, 3], [:ext_text, 9008, 4], [:ext_text, 9008, 5]], [:ext_text, 9008, 1], [:ext_text, 9008, 0], :screen_scale], language: [:language, :choice, 'Configs#language#choosable_language_code', 'Configs#language#choosable_language_texts', [:ext_text, 9000, 167], [:ext_text, 9000, 168], :language]}
    private
    # Add an option to the option stack
    # @param name [Symbol] name used in order to "sort" the options
    # @param type [Symbol] type of option (:choice, :slider)
    # @param options_info [Array, Hash, String] info telling the option system what value to take
    # @param options_text [Array, String] texts or getter used to show the values
    # @param option_name [Array, String] GamePlay::Base#get_text argument for the option name
    # @param option_descr [Array, String] GamePlay::Base#get_text argument for the option description
    # @param attribute [Symbol] attribute used inside $options
    # @note If the parameter name is not inside Configs.game_options.order this option will not be shown
    def add_option(name, type, options_info, options_text, option_name, option_descr, attribute)
      raise 'Invalid option type' unless VALID_OPTION_TYPE.include?(type)
      options_info = parse_string(options_info) if options_info.is_a?(String)
      options_text = parse_string(options_text) if options_text.is_a?(String)
      options_text = options_text.map { |option_text| get_text(option_text) } unless options_text.is_a?(String)
      option_name = get_text(option_name)
      option_descr = get_text(option_descr)
      getter = attribute
      setter = "#{getter}="
      return if options_info.is_a?(Array) && options_info.size <= 1
      @options[name] = Helper.new(type, options_info, options_text, option_name, option_descr, getter, setter)
    end
    # Parser allowing to retrieve the right value
    # @param str [String]
    def parse_string(str)
      return str if str.include?('%')
      constants, *attributes = str.split('#')
      return Configs.window.message_frame_filenames if constants == MESSAGE_FRAME
      return Configs.window.message_frame_names if constants == MESSAGE_FRAME_NAMES
      value = Object.const_get(constants)
      while (attribute = attributes.shift)
        value = value.send(attribute) unless attribute.empty?
      end
      return value
    end
    # Option helper allowing to work with a specific option (get next value, set it etc...)
    class Helper
      # Option type
      # @return [Symbol]
      attr_reader :type
      # Option values
      # @return [Array]
      attr_reader :values
      # Option value text(s)
      # @return [Array<String>, String]
      attr_accessor :values_text
      # Option name
      # @return [String]
      attr_accessor :name
      # Option description
      # @return [String]
      attr_accessor :description
      # Option getter (on $options)
      # @return [Symbol]
      attr_reader :getter
      # Option setter (on $options)
      # @return [Symbol]
      attr_reader :setter
      # Create a new option
      # @param args [Array] options arguments
      def initialize(*args)
        @type = args[0]
        @values = args[1]
        @values_text = args[2]
        @name = args[3]
        @description = args[4]
        @getter = args[5]
        @setter = args[6]
      end
      # Retreive the current value
      # @return [Object]
      def current_value
        value = $options.send(getter)
        if @type == :slider
          value = value.clamp(@values[:min], @values[:max])
          return value - (value % @values[:increment])
        end
        value_index = @values.index(value)
        return @values[value_index || 0]
      end
      # Retreive the next value
      # @return [Object]
      def next_value
        value = $options.send(getter)
        return (value + @values[:increment]).clamp(@values[:min], @values[:max]) if @type == :slider
        value_index = @values.index(value)
        new_value = @values[(value_index || 0) + 1]
        new_value = @values.first if new_value.nil?
        return new_value
      end
      # Retreive the prev value
      # @return [Object]
      def prev_value
        value = $options.send(getter)
        return (value - @values[:increment]).clamp(@values[:min], @values[:max]) if @type == :slider
        value_index = @values.index(value)
        return @values.last if value_index == 0
        new_value = @values[(value_index || 0) - 1]
        new_value = @values.first if new_value.nil?
        return new_value
      end
      # Update the option value
      # @param new_value [Object]
      def update_value(new_value)
        if @type != :slider
          value_index = @values.index(new_value)
          new_value = @values[value_index || 0]
        end
        $options.send(setter, new_value)
      end
    end
    public
    include OptionsMixin
    # List of action the mouse can perform with ctrl button
    ACTIONS = %i[save_options save_options save_options save_options]
    # Maximum number of button shown in the UI for options (used to calculate arrow position)
    MAX_BUTTON_SHOWN = 4
    # Create a new Options scene
    def initialize
      super
      @options = {}
      @order = Configs.game_options.order
      @order.delete(:language) if Configs.language.choosable_language_code.none?
      @order.delete_if { |sym| !PREDEFINED_OPTIONS[sym] }
      load_options
      @modified_options = []
      @index = 0
      @max_index = 0
      @options_copy = $options.clone
    end
    # Update the options input
    def update_inputs
      if index_changed!(:@index, :UP, :DOWN, @max_index)
        play_cursor_se
        update_list
        @description.data = current_option
        return false
      end
      if Input.trigger?(:A) && @order[@index] == :message_frame
        display_message(@buttons[@index].value_text)
        return false
      end
      return save_options if Input.trigger?(:B)
      return update_input_option_value
    end
    # Update the mouse interactions
    # @param moved [Boolean] if the mouse moved durring the frame
    # @return [Boolean] if the thing after can update
    def update_mouse(moved)
      update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS, true)
      return false
    end
    # Update the options graphics
    def update_graphics
      @base_ui&.update_background_animation
      @arrow&.update
    end
    private
    def load_options
      @order.each { |sym| add_option(*PREDEFINED_OPTIONS[sym]) }
    end
    def create_graphics
      create_viewport
      create_base_ui
      create_description
      create_buttons
      create_frame
    end
    def create_viewport
      super
      rect = @viewport.rect
      x = rect.x + 160
      y = rect.y + 45
      @button_viewport = Viewport.create(x, y, 156, 156, 10_000)
    end
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
    end
    # Get the button text for the generic UI
    # @return [Array<String>]
    def button_texts
      return [nil, nil, nil, ext_text(9000, 115)]
    end
    def create_description
      @description = UI::Options::Description.new(@viewport)
      @description.data = @options[@order.first]
    end
    def create_buttons
      @buttons = @order.map.with_index do |sym, index|
        next(nil) unless @options[sym]
        UI::Options::Button.new(@button_viewport, index, @options[sym])
      end.compact
      @arrow = UI::Options::Arrow.new(@button_viewport)
      @arrow.oy -= (@buttons.first&.stack&.first&.height || 0) / 2
      @max_index = @buttons.size - 1
    end
    def create_frame
      @frame = Sprite.new(@viewport).set_bitmap('options/frame', :interface)
    end
    def update_list
      @arrow.y = @buttons[@index].stack.first.y
      @button_viewport.oy = 0
      return unless (@max_index + 1) > MAX_BUTTON_SHOWN
      return if @index < MAX_BUTTON_SHOWN / 2
      offset_y = (@index - MAX_BUTTON_SHOWN / 2 + 1).clamp(0, @buttons.size - MAX_BUTTON_SHOWN)
      @button_viewport.oy = offset_y * UI::Options::Button::OPTION_OFFSET_Y
    end
    # Function that try to update the option value
    # @return [Boolean]
    def update_input_option_value
      new_value = nil
      if Input.repeat?(:RIGHT)
        new_value = current_option.next_value
      else
        if Input.repeat?(:LEFT)
          new_value = current_option.prev_value
        end
      end
      return true if new_value.nil?
      if new_value != current_option.current_value
        play_cursor_se
        @buttons[@index].value = new_value
        current_option.update_value(new_value)
        reload_texts if @options.key(@buttons[@index].option) == :language
      else
        play_buzzer_se
      end
      return false
    end
    # Reload the texts of the UI dynamically when the language is changed
    def reload_texts
      @buttons.each do |button|
        sym = @options.key(button.option)
        options_text = PREDEFINED_OPTIONS[sym][3]
        if options_text.is_a?(String)
          button.option.values_text = parse_string(options_text)
        else
          button.option.values_text = options_text.map { |option_text| get_text(option_text) }
        end
        button.option.name = get_text(PREDEFINED_OPTIONS[sym][4])
        button.option.description = get_text(PREDEFINED_OPTIONS[sym][5])
      end
      @buttons.each(&:reload_texts)
    end
    # Method that save the options and quit the scene
    # @return [false]
    def save_options
      @modified_options = @order.select do |option_symbol|
        option = @options[option_symbol]
        next(@options_copy.send(option.getter) != option.current_value)
      end
      PARGV.update_game_opts("--scale=#{$options.screen_scale}")
      return @running = false
    end
    # Return the current option
    # @return [GamePlay::Options::Helper]
    def current_option
      @options[@order[@index]]
    end
  end
  # Class that show the KeyBinding UI and allow to change it
  class KeyBinding < BaseCleanUpdate
    # List of keys use by the 3 modes
    KEYS = [%i[A RIGHT DOWN B]] * 3
    # List of mouse action in navigation mode
    MOUSE_ACTION_NAV = %i[action_a_nav action_a_nav action_down_nav action_b_nav]
    # List of mouse action in selection mode
    MOUSE_ACTION_SEL = %i[action_a_sel action_right_sel action_down_sel action_b_sel]
    # List of mouse action in blink mode
    MOUSE_ACTION_BLK = %i[action_b_blink action_b_blink action_b_blink action_b_blink]
    # Create a new KeyBinding UI
    def initialize
      super
      @cool_down = 0
    end
    # Create the grahics of the KeyBinding scene
    def create_graphics
      create_viewport
      create_base_ui
      create_overlay
      create_ui
      Graphics.sort_z
    end
    # Update the graphics
    def update_graphics
      @base_ui.update_background_animation
      @ui.update_blink
    end
    # Update the inputs
    def update_inputs
      return @cool_down -= 1 if @cool_down > 0
      if @ui.key_index == -1
        update_navigation_input
      else
        if @ui.blinking
          update_key_binding
        else
          update_key_selection
        end
      end
    end
    # Update the mouse
    # @param _moved [Boolean] if the mouse moved
    def update_mouse(_moved)
      if @ui.blinking
        actions = MOUSE_ACTION_BLK
      else
        if @ui.key_index >= 0
          actions = MOUSE_ACTION_SEL
        else
          actions = MOUSE_ACTION_NAV
        end
      end
      update_mouse_ctrl_buttons(@base_ui.ctrl, actions, @base_ui.win_text_visible?)
    end
    private
    # Update the inputs during the naviation
    def update_navigation_input
      if Input.trigger?(:B)
        return action_b_nav
      else
        if Input.trigger?(:A) || Input.trigger?(:RIGHT)
          action_a_nav
        else
          if Input.trigger?(:LEFT)
            @ui.key_index = 4
          else
            if Input.trigger?(:DOWN)
              action_down_nav
            else
              if Input.trigger?(:UP)
                @ui.main_index -= 1
              end
            end
          end
        end
      end
    end
    # When the player presses A in navigation mode
    def action_a_nav
      @ui.key_index = 0
      @base_ui.mode = 1
    end
    # When the player presses DOWN in navigation mode
    def action_down_nav
      @ui.main_index += 1
    end
    # When the player presses B in navigation mode
    def action_b_nav
      KeyBinding.save_inputs
      return @running = false
    end
    # Update the key selection
    def update_key_selection
      if Input.trigger?(:B)
        action_b_sel
      else
        if Input.trigger?(:A)
          return action_a_sel
        else
          if Input.trigger?(:LEFT)
            @ui.key_index = (@ui.key_index - 1).clamp(0, 4)
          else
            if Input.trigger?(:RIGHT)
              action_right_sel
            else
              if Input.trigger?(:DOWN)
                action_down_sel
              else
                if Input.trigger?(:UP)
                  @ui.main_index -= 1
                end
              end
            end
          end
        end
      end
    end
    # When the player presses A in selection mode
    def action_a_sel
      return display_message(ext_text(8998, 28)) if @ui.key_index == 4 && !Sf::Joystick.connected?(Input.main_joy)
      @ui.blinking = true
      @cool_down = 10
      @base_ui.mode = 2
      @base_ui.show_win_text(ext_text(8998, 29))
    end
    # When the player presses RIGHT in selection mode
    def action_right_sel
      return (@ui.key_index = (@ui.key_index + 1) % 5) if Mouse.released?(:LEFT)
      @ui.key_index = (@ui.key_index + 1).clamp(0, 4)
    end
    # When the player presses DOWN in selection mode
    def action_down_sel
      @ui.main_index += 1
    end
    # When the player presses B in selection mode
    def action_b_sel
      @ui.key_index = -1
      @base_ui.mode = 0
    end
    # Update the key detection during the UI blinking
    def update_key_binding
      if @ui.key_index < 4
        UI::KeyShortcut::KeyIndex.each do |key_value|
          return validate_key(key_value) if Input::Keyboard.press?(key_value)
        end
        UI::KeyShortcut::NUMPAD_KEY_INDEX.each do |key_value|
          return validate_key(key_value) if key_value >= 0 && Input::Keyboard.press?(key_value)
        end
      else
        unless Sf::Joystick.connected?(Input.main_joy)
          action_b_blink
          return display_message(ext_text(8998, 28))
        end
        return action_b_blink if Input::Keyboard.press?(Input::Keyboard::Escape)
        0.upto(Sf::Joystick.button_count(Input.main_joy)) do |key_value|
          if Sf::Joystick.press?(Input.main_joy, key_value)
            return validate_key((-key_value - 1) - 32 * Input.main_joy)
          end
        end
      end
    end
    # When the player presses "B" in blink mode
    def action_b_blink
      @base_ui.hide_win_text
      @ui.blinking = false
      @base_ui.mode = 1
    end
    # Validate the key change
    # @param key_value [Integer] the value of the key in Keyboard
    def validate_key(key_value)
      if key_value == Input::Keyboard::Escape
        ch = display_message_and_wait(ext_text(8998, 31), 1, ext_text(8998, 32), ext_text(8998, 33))
        return if ch == 0
      end
      Input::Keys[@ui.current_key][@ui.current_key_index] = key_value
      @ui.update
    ensure
      action_b_blink
    end
    # Create the base ui
    def create_base_ui
      @base_ui = UI::GenericBaseMultiMode.new(@viewport, button_texts, KEYS)
    end
    # Create the overlay sprite
    def create_overlay
      @overlay = Sprite.new(@viewport).set_bitmap('key_binding/overlay_', :interface)
    end
    # Create the UI
    def create_ui
      @ui = UI::KeyBindingViewer.new(@viewport)
    end
    # Get the button text for the generic UI
    # @return [Array<Array<String>>]
    def button_texts
      return [[ext_text(8998, 22), ext_text(8998, 22), ext_text(9000, 112), ext_text(9000, 115)], [ext_text(8998, 26), ext_text(8998, 22), ext_text(9000, 112), ext_text(9000, 13)], [nil, nil, nil, ext_text(9000, 13)]]
    end
    public
    class << self
      # Load the Inputs
      def load_inputs
        unless File.exist?(input_filename)
          normalize_inputs
          save_inputs
        end
        load_inputs_internal
        normalize_inputs
      rescue StandardError
        normalize_inputs
        save_inputs
      end
      # Perform the internal operation of loading the inputs
      def load_inputs_internal
        data = YAML.unsafe_load(File.read(input_filename), fallback: false)
        raise 'Bad Input data' unless data.is_a?(Hash)
        UI::KeyBindingViewer::KEYS.each do |infos|
          key = infos[0]
          next unless (key_values = data[key])
          Input::Keys[key].clear
          Input::Keys[key].concat(key_values.collect(&:to_i))
        end
        Input.main_joy = data[:main_joy] || Input.main_joy
        if data[:x_axis].is_a?(Symbol) && Input.const_defined?(data[:x_axis])
          Input.x_axis = Input.const_get(data[:x_axis])
        end
        if data[:y_axis].is_a?(Symbol) && Input.const_defined?(data[:y_axis])
          Input.y_axis = Input.const_get(data[:y_axis])
        end
      end
      # Normalize the Input::Keys contents in order to have a correct display in the UI
      def normalize_inputs
        Input::Keys.each do |_key, key_array|
          next if key_array.size >= 5
          first_key = key_array[0] || 0
          joy_key = key_array.find { |value| value < 0 } || first_key
          (key_array.size - (joy_key == first_key ? 0 : 1)).upto(3) do |index|
            key_array[index] = first_key
          end
          key_array[4] = joy_key
        end
      end
      # Save the inputs in the right file
      def save_inputs
        data = {main_joy: Input.main_joy}
        data[:x_axis] = Input.constants.find { |e| Input.const_get(e) == Input.x_axis }
        data[:y_axis] = Input.constants.find { |e| Input.const_get(e) == Input.y_axis }
        UI::KeyBindingViewer::KEYS.each do |infos|
          data[infos[0]] = Input::Keys[infos[0]].clone
        end
        File.open(input_filename, 'w') { |f| YAML.dump(data, f) }
      end
      # Return the filename with path of the inputs.yml file
      def input_filename
        directory = File.dirname(Save.save_filename)
        Dir.mkdir!(directory) unless Dir.exist?(directory)
        File.join(directory, 'input.yml')
      end
    end
    Graphics.on_start {load_inputs }
  end
end
GamePlay.options_mixin = GamePlay::OptionsMixin
GamePlay.options_class = GamePlay::Options
