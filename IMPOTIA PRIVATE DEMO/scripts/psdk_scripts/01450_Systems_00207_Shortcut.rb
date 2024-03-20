module UI
  # UI component that shows a shortcut item
  class ShortcutElement < SpriteStack
    # Offset Y to prevent UI element to overlap with BaseUI
    OFFSET_Y = 28
    # @return [Integer] Index of the button in the list
    attr_accessor :index
    # Create a new Item sell button
    # @param viewport [Viewport] the viewport in which the SpriteStack will be displayed
    # @param index [Integer] index used to align the element in the UI
    # @param item_id [Integer, Symbol] ID of the item to show
    # @param key [Symbol] the key the player has to press
    def initialize(viewport, index, item_id, key)
      super(viewport)
      @index = index
      @data = item_id
      @key = key
      create_background
      adjust_position(self[0])
      create_item_name
      create_quantity
      create_key
      create_icon
    end
    private
    def create_background
      add_background('shop/button_list')
    end
    def create_item_name
      add_text(37, 8, 92, 18, data_item(@data).exact_name, 1, color: 10)
    end
    def create_quantity
      return if @data == 0 || @data == :__undef__
      add_text(130, 8, 38, 16, "ｘ#{$bag.item_quantity(@data)}".to_pokemon_number, 2, 0, color: 0)
    end
    def create_key
      add_sprite(168, 9, nil, @key, type: KeyShortcut)
    end
    def create_icon
      return if @data == 0 || @data == :__undef__
      add_sprite(3, 2, NO_INITIAL_IMAGE, type: ItemSprite).data = @data
    end
    def adjust_position(background)
      move((@viewport.rect.width - background.width) / 2, @viewport.rect.height - (background.height + 2) * @index - OFFSET_Y)
    end
  end
end
module GamePlay
  # Scene responsive of showing the shortcut menu
  class Shortcut < BaseCleanUpdate::FrameBalanced
    include ::Util::Item
    # List of shortcut key by index
    SHORTCUT_KEYS = %i[UP LEFT DOWN RIGHT]
    # List of key => method used by automatic_input_update
    AIU_KEY2METHOD = {B: :action_b, Y: :action_b}
    # Actions on mouse ctrl
    ACTIONS = %i[action_b action_b action_b action_b]
    # Create the shortcut scene
    def initialize
      super
      @items = $bag.shortcuts
    end
    # Update the inputs of the scene
    def update_inputs
      return false unless automatic_input_update(AIU_KEY2METHOD)
      SHORTCUT_KEYS.each_with_index do |key, index|
        next unless Input.trigger?(key)
        break(use(index))
      end
    end
    # Update the mouse interaction
    def update_mouse(moved)
      update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS, true)
      if Mouse.trigger?(:LEFT)
        @shortcuts.each_with_index do |stack, index|
          use(index) if stack.simple_mouse_in?
        end
      end
    end
    private
    def action_b
      play_cancel_se
      @running = false
    end
    def use(index)
      item_db_symbol = @items[index]
      if item_db_symbol == :__undef__ || !$bag.contain_item?(item_db_symbol)
        play_buzzer_se
        return
      end
      play_decision_se
      @running = false if util_item_useitem(item_db_symbol)
      close_message_window
    end
    def create_graphics
      create_viewport
      create_background
      create_base_ui
      create_elements
    end
    def create_background
      add_disposable UI::BlurScreenshot.new(@viewport, @__last_scene)
    end
    def create_elements
      count = SHORTCUT_KEYS.size
      @shortcuts = SHORTCUT_KEYS.each_with_index.map do |key, index|
        UI::ShortcutElement.new(@viewport, count - index, @items[index], key)
      end
    end
    # Create the base UI of the slot machine
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
      @base_ui.background.visible = false
    end
    # Get the button text for the generic UI
    # @return [Array<String>]
    def button_texts
      return [nil, nil, nil, ext_text(9000, 115)]
    end
  end
end
GamePlay.shortcut_class = GamePlay::Shortcut
