module UI
  # Base UI for name input scenes
  class NameInputBaseUI < GenericBase
    alias create_button_background void
    alias update_background_animation void
    # @param viewport [LiteRGSS::Viewport]
    # @param last_scene [GamePlay::BaseCleanUpdate]
    def initialize(viewport, last_scene)
      @last_scene = last_scene
      super(viewport)
    end
    private
    def create_background
      @background = UI::BlurScreenshot.new(@viewport, @last_scene)
      $scene.add_disposable(@background)
    end
    def create_control_button
      @ctrl = []
    end
  end
  # Name Input UI window
  class NameInputUI < Window
    # Return the chars the user has inserted
    # @return [Array<String>]
    attr_reader :chars
    # Character used to indicate there's no char there
    NO_CHAR = '_'
    # Create a new NameInputUI
    # @param viewport [Viewport]
    # @param max_size [Integer] maximum size of the name
    # @param chars [Array<String>] chars initialize there
    # @param character [PFM::Pokemon, String, nil] the character to display
    # @param phrase [String] the phrase to display in order to justify the name input
    def initialize(viewport, max_size, chars, character, phrase)
      super(viewport, *window_parameters, skin: default_windowskin)
      @character = character
      @phrase = phrase
      @chars = chars
      @index = 0
      @max_size = max_size
      create_graphics
      @counter = 0
    end
    # Add a character to the input
    # @param char [String]
    def add_char(char)
      return if @chars.size >= @max_size
      @chars.push(char)
      refresh_chars
    end
    # Remove a character from the input
    def remove_char
      @chars.pop
      refresh_chars
    end
    # Update the window (caret)
    def update
      @counter += 1
      if @counter == 30
        @inputs[@chars.size]&.visible = false
      else
        if @counter == 60
          @inputs[@chars.size]&.visible = true
          @counter = 0
        end
      end
      @character_sprite&.update
    end
    private
    # Return the default window parameters (x, y, width, height)
    # @return [Array<Integer>]
    def window_parameters
      [2, 2, 316, 64]
    end
    # Return the default windowskin
    # @return [String]
    def default_windowskin
      DEFAULT_SKIN
    end
    # Create the graphics inside the window
    def create_graphics
      create_character_sprite
      create_phrase
      create_inputs
      refresh_chars
    end
    # Create the character sprite
    def create_character_sprite
      if @character.is_a?(PFM::Pokemon)
        @character_sprite = PokemonIconSprite.new(self, false)
        @character_sprite.data = @character
      else
        if @character.is_a?(String)
          @character_sprite = Sprite.new(self)
          @character_sprite.set_bitmap(@character, :character)
          @character_sprite.src_rect.set(nil, nil, @character_sprite.width / 4, @character_sprite.height / 4)
        else
          return
        end
      end
      @character_sprite.set_position(*character_sprite_position)
      @character_sprite.set_origin(@character_sprite.width / 2, @character_sprite.height)
    end
    def character_sprite_position
      return 16, base_y + 2 * delta_y
    end
    # Create the phrase texte
    def create_phrase
      @phrase_text = add_text(base_x, base_y, 0, 16, @phrase)
    end
    # Create the text inputs elements
    def create_inputs
      @inputs = Array.new(@max_size) do |i|
        add_text(base_x + i * delta_x, base_y + delta_y, delta_x, delta_y, NO_CHAR, 1)
      end
    end
    def base_x
      40
    end
    def delta_x
      8
    end
    def base_y
      8
    end
    def delta_y
      16
    end
    def refresh_chars
      @inputs.each_with_index do |input, index|
        input.text = chars[index] || NO_CHAR
        input.visible = true
      end
      @counter = 0
    end
  end
  # UI element showing input number (for number choice & selling)
  class InputNumber < SpriteStack
    # Image used as source for the UI build
    IMAGE_SOURCE = 'numin_bg'
    # List of coordinates used to know how to build the UI from the image
    IMAGE_COMPOSITION = {left: [0, 0, 33, 44], number: [33, 0, 24, 44], separator: [57, 0, 6, 44], right: [83, 0, 10, 44], money_add: [94, 0, 68, 44]}
    # Padding for money text
    MONEY_PADDING = 2
    # Minimum value
    # @return [Integer]
    attr_accessor :min
    # Maximum value
    # @return [Integer]
    attr_accessor :max
    # Currently inputed number
    # @return [Integer]
    attr_reader :number
    # Create a new Input number
    # @param viewport [Viewport]
    # @param max_digits [Integer] maximum number of digit
    # @param default_number [Integer] default number
    # @param accept_negatives [Boolean] if we can provide negative values
    def initialize(viewport, max_digits, default_number = 0, accept_negatives = false)
      super(viewport)
      @max_digits = max_digits
      @accept_negatives = accept_negatives
      @digit_index = 0
      @max = (10 ** @max_digits) - 1
      @min = accept_negatives ? -@max : 0
      @width_accounting_sprites = []
      @texts = []
      create_sprites
      self.number = default_number
      @default_number = @number
    end
    # Update the UI element
    def update
      if Input.repeat?(:DOWN)
        self.number -= 10 ** @digit_index
      else
        if Input.repeat?(:UP)
          self.number += 10 ** @digit_index
        else
          if Input.trigger?(:LEFT)
            @digit_index = (@digit_index + 1).clamp(0, @max_digits - 1)
          else
            if Input.trigger?(:RIGHT)
              @digit_index = (@digit_index - 1).clamp(0, @max_digits - 1)
            else
              if Input.trigger?(:B)
                self.number = @default_number
              else
                return
              end
            end
          end
        end
      end
      draw_digits
    end
    # Set the number shown by the UI
    # @param number [Integer]
    def number=(number)
      @number = number.clamp(@min, @max)
      draw_digits
    end
    # Get the width of the UI
    # @return [Integer]
    def width
      @width_accounting_sprites.map(&:width).reduce(0, :+)
    end
    # Get the height of the UI
    # @return [Integer]
    def height
      @stack.first&.height || 0
    end
    private
    def create_sprites
      create_left
      create_center
      create_right
      create_money
      define_position
    end
    def create_left
      @width_accounting_sprites << add_background(IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:left])
    end
    def create_center
      current_x = @width_accounting_sprites.last.width
      width = IMAGE_COMPOSITION[:number][-2]
      height = IMAGE_COMPOSITION[:number][-1]
      1.step(@max_digits - 1) do
        @width_accounting_sprites << add_sprite(current_x, 0, IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:number])
        @texts << add_text(current_x, 0, width, height, nil.to_s, 1)
        current_x += @width_accounting_sprites.last.width
        @width_accounting_sprites << add_sprite(current_x, 0, IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:separator])
        current_x += @width_accounting_sprites.last.width
      end
      @width_accounting_sprites << add_sprite(current_x, 0, IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:number])
      @texts << add_text(current_x, 0, width, height, nil.to_s, 1)
      current_x += @width_accounting_sprites.last.width
    end
    def create_right
      @width_accounting_sprites << add_sprite(width, 0, IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:right])
    end
    def create_money
      return unless $game_temp.shop_calling
      current_x = width
      width = IMAGE_COMPOSITION[:money_add][-2]
      height = IMAGE_COMPOSITION[:money_add][-1]
      @width_accounting_sprites << add_sprite(current_x, 0, IMAGE_SOURCE, rect: IMAGE_COMPOSITION[:money_add])
      @money_text = add_text(current_x + MONEY_PADDING, 0, width, height, nil.to_s)
    end
    def draw_digits
      @money_text&.text = parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (@number * $game_temp.shop_calling).to_s)
      @number.to_s.rjust(@max_digits, ' ').each_char.with_index do |char, index|
        @texts[index].text = char
        @texts[index].load_color((@max_digits - @digit_index - 1) == index ? 1 : 0)
      end
    end
    def define_position
      self.x = @viewport.rect.width - width
    end
  end
end
module GamePlay
  # Module defining the IO of the NameInput scene so user know what to expect
  module NameInputMixin
    # Return the choosen name
    # @return [String]
    attr_reader :return_name
  end
  # Name input scene
  class NameInput < GamePlay::BaseCleanUpdate::FrameBalanced
    include NameInputMixin
    # Hint shown about how to enter name
    DEFAULT_HINT = [:ext_text, 9000, 162]
    # "Use your keyboard and press ENTER"
    # GUESSED PHRASE when not given
    GUESSED_PHRASE = [:ext_text, 9000, 163]
    # "How would you name %<name>s?"
    # Create a new NameInput scene
    # @param default_name [String] the choosen name if no choice
    # @param max_length [Integer] the maximum number of characters in the choosen name
    # @param character [PFM::Pokemon, String, nil] the character to display
    # @param phrase [String, nil] phrase to show in order to display the name
    def initialize(default_name, max_length, character = nil, phrase: nil)
      super()
      @return_name = @default_name = default_name[0, max_length].dup.force_encoding(Encoding::UTF_8)
      @input_name = @default_name.chars
      @max_length = max_length
      @character = character
      @phrase = phrase || guess_phrase
    end
    # Update the inputs of the scene
    # @return [Boolean] if the other "input" related updates can be called
    def update_inputs
      if (text = Input.get_text)
        update_name(text.chars)
        return false
      end
      return joypad_update_inputs && true
    end
    # Update the graphics of the scene
    def update_graphics
      @base_ui&.update_background_animation
      @name_input_ui&.update
      @hint_ui&.update
    end
    # Make main return self for compatibility
    # @return [self]
    def main
      super
      return self
    end
    private
    def guess_phrase
      name = @character.is_a?(PFM::Pokemon) ? @character.name : @default_name
      format(get_text(GUESSED_PHRASE), name: name)
    end
    def create_graphics
      create_viewport
      create_base_ui
      create_name_input_ui
      create_hint_ui
      create_joypad_ui
    end
    # Update the displayed name (according to a list of chars)
    # @param chars [Array<String>] all the chars that controls the name (add / remove / validate)
    # @param from_clipboard [Boolean] if the chars comes from the clipboard
    def update_name(chars, from_clipboard = false)
      chars.each do |char|
        ord = char.ord
        if char_valid?(ord)
          @name_input_ui.add_char(char)
        else
          if ord == 13 && !from_clipboard
            confirm_name
          else
            if ord == 8
              @name_input_ui.remove_char
            else
              if ord == 22 && !from_clipboard
                update_name(Yuki.get_clipboard.to_s.chars, true)
              end
            end
          end
        end
      end
    end
    def confirm_name
      @return_name = @name_input_ui.chars.join if @name_input_ui.chars.any?
      @running = false
    end
    def joypad_update_inputs
      return true
    end
    def create_base_ui
      @base_ui = UI::NameInputBaseUI.new(@viewport, @__last_scene)
    end
    def create_name_input_ui
      @name_input_ui = UI::NameInputUI.new(@viewport, @max_length, @input_name, @character, @phrase)
    end
    def create_hint_ui
      @hint_ui = UI::Window.new(@viewport, 2, 190, 316, 48)
      @hint_text = @hint_ui.add_text(0, 0, 316 - @hint_ui.window_builder[-2] - @hint_ui.window_builder[4], 16, '')
      @hint_text.multiline_text = get_text(DEFAULT_HINT)
    end
    def create_joypad_ui
      return nil
    end
    # Function that checks if a character is valid depending on its ordinal
    # @param ord [Integer] value of the char in numbers
    # @return [Boolean]
    def char_valid?(ord)
      ord >= 32
    end
  end
  # Number input scene
  class NumberInput < NameInput
    private
    def create_joypad_ui
      return nil
    end
    # Function that checks if a character is valid depending on its ordinal
    # @param ord [Integer] value of the char in numbers
    # @return [Boolean]
    def char_valid?(ord)
      ord.between?(48, 57)
    end
  end
end
GamePlay.string_input_mixin = GamePlay::NameInputMixin
GamePlay.string_input_class = GamePlay::NameInput
