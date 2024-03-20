module UI
  # Button that is shown in the main menu
  class PSDKMenuButton < SpriteStack
    # Basic coordinate of the button on screen
    BASIC_COORDINATE = [192, 16]
    # Offset between each button
    OFFSET_COORDINATE = [0, 24]
    # Offset between selected position and unselected position
    SELECT_POSITION_OFFSET = [-6, 0]
    # List of text message to send in order to get the right text
    TEXT_MESSAGES = [[:text_get, 14, 1], [:text_get, 14, 0], [:text_get, 14, 2], [:text_get, 14, 3], [:text_get, 14, 5], [:text_get, 14, 4], [:ext_text, 9000, 26], [:text_get, 14, 2]]
    # Angle variation of the icon in one direction
    ANGLE_VARIATION = 15
    # @return [Boolean] selected
    attr_reader :selected
    # Create a new PSDKMenuButton
    # @param viewport [Viewport]
    # @param real_index [Integer] real index of the button in the menu
    # @param positional_index [Integer] index used to position the button on screen
    def initialize(viewport, real_index, positional_index)
      x = BASIC_COORDINATE.first + positional_index * OFFSET_COORDINATE.first
      y = BASIC_COORDINATE.last + positional_index * OFFSET_COORDINATE.last
      super(viewport, x, y)
      @real_index = real_index
      @real_index = 7 if real_index == 2 && $trainer.playing_girl
      @selected = false
      add_background('menu_button')
      @icon = add_sprite(12, 0, 'menu_icons', 2, 8, type: SpriteSheet)
      @icon.select(0, @real_index)
      @icon.set_origin(@icon.width / 2, @icon.height / 2)
      @icon.set_position(@icon.x + @icon.ox, @icon.y + @icon.oy)
      add_text(40, 0, 0, 23, send(*TEXT_MESSAGES[@real_index]).sub(PFM::Text::TRNAME[0], $trainer.name))
    end
    # Update the button animation
    def update
      return unless @selected
      if @counter < (2 * ANGLE_VARIATION)
        @icon.angle -= 1
      else
        if @counter < (4 * ANGLE_VARIATION)
          @icon.angle += 1
        else
          return @counter = 0
        end
      end
      @counter += 1
    end
    # Set the selected state
    # @param value [Boolean]
    def selected=(value)
      return if value == @selected
      if value
        move(*SELECT_POSITION_OFFSET)
        @icon.select(1, @real_index)
        @icon.angle = ANGLE_VARIATION
      else
        move(-SELECT_POSITION_OFFSET.first, -SELECT_POSITION_OFFSET.last)
        @icon.select(0, @real_index)
        @icon.angle = 0
      end
      @selected = value
      @counter = 0
    end
  end
end
module GamePlay
  # Module defining the IO of the menu scene so user know what to expect
  module MenuMixin
    # Get the process that is executed when a skill is used somewhere
    # @return [Array, Proc]
    attr_accessor :call_skill_process
    # Execute the skill process
    def execute_skill_process
      return unless @call_skill_process
      case @call_skill_process
      when Array
        return if @call_skill_process.empty?
        block = @call_skill_process.shift
        block.call(*@call_skill_process)
        @call_skill_process = nil
      when Proc
        @call_skill_process.call
        @call_skill_process = nil
      end
    end
  end
  # Main menu UI
  #
  # Rewritten thanks to Jaizu demand
  class Menu < BaseCleanUpdate::FrameBalanced
    include MenuMixin
    # List of action according to the "image_index" to call
    ACTION_LIST = %i[open_dex open_party open_bag open_tcard open_option open_save open_quit]
    # Entering - leaving animation offset
    ENTERING_ANIMATION_OFFSET = 150
    # Entering - leaving animation duration
    ENTERING_ANIMATION_DURATION = 15
    # Create a new menu
    def initialize
      super
      init_conditions
      init_indexes
      @call_skill_process = nil
      @index = $game_temp.last_menu_index
      @index = 0 if @index >= @image_indexes.size
      @max_index = @image_indexes.size - 1
      @quiting = false
      @entering = true
      @counter = 0
      @in_save = false
      @mbf_type = @mef_type = :noen if $scene.is_a?(Scene_Map)
    end
    # Create all the graphics
    def create_graphics
      create_viewport
      create_background
      create_buttons
      init_entering
    end
    # End of the scene
    def main_end
      super
      $game_temp.last_menu_index = @index
    end
    # Update the input interaction
    # @return [Boolean] if no input was detected
    def update_inputs
      return false if @entering || @quiting
      if index_changed(:@index, :UP, :DOWN, @max_index)
        play_cursor_se
        update_buttons
      else
        if Input.trigger?(:A)
          action
        else
          if Input.trigger?(:B)
            @running = false
          else
            return true
          end
        end
      end
      return false
    end
    # Update the mouse interaction
    # @param moved [Boolean] if the mouse moved
    # @return [Boolean]
    def update_mouse(moved)
      @buttons.each_with_index do |button, index|
        next unless button.simple_mouse_in?
        if moved
          last_index = @index
          @index = index
          if last_index != index
            update_buttons
            play_cursor_se
          end
        else
          if Mouse.trigger?(:LEFT)
            @index = index
            update_buttons
            play_decision_se
            action
          end
        end
        return false
      end
      return true
    end
    # Update the graphics
    def update_graphics
      unless @running || @quiting
        @quiting = true
        @running = true
        @__last_scene.spriteset.visible = true if @__last_scene.is_a?(Scene_Map)
      end
      if @entering
        update_entering_animation
      else
        if @quiting
          update_quitting_animation
        else
          @buttons.each(&:update)
        end
      end
    end
    # Overload the visible= to allow save to keep the curren background
    # @param value [Boolean]
    def visible=(value)
      if @in_save
        @buttons.each { |button| button.visible = value }
      else
        super(value)
      end
    end
    private
    # Animation played during enter sequence
    def update_entering_animation
      @buttons.each { |button| button.move(-ENTERING_ANIMATION_OFFSET / ENTERING_ANIMATION_DURATION, 0) }
      @background.opacity += 255 / ENTERING_ANIMATION_DURATION
      @counter += 1
      if @counter >= ENTERING_ANIMATION_DURATION
        @counter = 0
        @entering = false
        update_buttons
        @background.opacity = 255
        @__last_scene.spriteset.visible = false if @__last_scene.is_a?(Scene_Map)
      end
    end
    # Animation played during the quit sequence
    def update_quitting_animation
      @buttons.each { |button| button.move(ENTERING_ANIMATION_OFFSET / ENTERING_ANIMATION_DURATION, 0) }
      @background.opacity -= 255 / ENTERING_ANIMATION_DURATION
      @counter += 1
      @running = false if @counter >= ENTERING_ANIMATION_DURATION
    end
    # Create the conditional array telling which scene is enabled
    def init_conditions
      @conditions = [$game_switches[Yuki::Sw::Pokedex], $actors.any?, !$bag.locked, true, true, !$game_system.save_disabled, true]
    end
    # Init the image_indexes array
    def init_indexes
      @image_indexes = @conditions.collect.with_index { |condition, index| condition ? index : nil }
      @image_indexes.compact!
    end
    # Create the background image (blur)
    def create_background
      add_disposable @background = UI::BlurScreenshot.new(@viewport, @__last_scene)
      @background.opacity -= 255 / ENTERING_ANIMATION_DURATION * ENTERING_ANIMATION_DURATION
    end
    # Create the menu buttons
    def create_buttons
      @buttons = Array.new(@image_indexes.size) do |i|
        UI::PSDKMenuButton.new(@viewport, @image_indexes[i], i)
      end
    end
    # Update the menu button states
    def update_buttons
      @buttons.each_with_index { |button, index| button.selected = index == @index }
    end
    # Init the entering animation
    def init_entering
      @buttons.each { |button| button.move(ENTERING_ANIMATION_OFFSET, 0) }
    end
    # Perform the action to do at the current index
    def action
      play_decision_se
      send(ACTION_LIST[@image_indexes[@index]])
    end
    # Open the Dex UI
    def open_dex
      GamePlay.open_dex
    end
    # Open the Party_Menu UI
    def open_party
      GamePlay.open_party_menu do |scene|
        Yuki::FollowMe.update
        @background.update_snapshot
        if scene.call_skill_process
          @call_skill_process = scene.call_skill_process
          @running = false
          Graphics.transition
        end
      end
    end
    # Open the Bag UI
    def open_bag
      GamePlay.open_bag
      Graphics.transition unless @running
    end
    # Open the TCard UI
    def open_tcard
      GamePlay.open_player_information
    end
    # Open the Save UI
    def open_save
      @in_save = true
      call_scene(Save) do |scene|
        @running = false if scene.saved
        Graphics.transition
      end
      @in_save = false
    end
    # Open the Options UI
    def open_option
      GamePlay.open_options do |scene|
        if scene.modified_options.include?(:language)
          @running = false
          Graphics.transition
        end
      end
    end
    # Quit the scene
    def open_quit
      @running = false
    end
  end
end
GamePlay.menu_mixin = GamePlay::MenuMixin
GamePlay.menu_class = GamePlay::Menu
