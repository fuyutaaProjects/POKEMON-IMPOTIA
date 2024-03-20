# Module that contain helpers for various scripts
module Util
  # Item Helper
  # @author Nuri Yuri
  module Item
    # Use an item in a GamePlay::Base child class
    # @param item_id [Integer] ID of the item in the database
    # @return [PFM::ItemDescriptor::Wrapper, false] item descriptor wrapper if the item could be used
    def util_item_useitem(item_id, &result_process)
      extend_data = PFM::ItemDescriptor.actions(item_id)
      if extend_data.chen
        display_message(parse_text(22, 43))
        return false
      else
        if extend_data.no_effect
          display_message(parse_text(22, 108))
          return false
        else
          if $actors.empty? && extend_data.open_party
            display_message(parse_text(22, 119))
            return false
          else
            if extend_data.open_party
              return util_item_open_party_sequence(extend_data, result_process)
            end
          end
        end
      end
      return util_item_on_use_sequence(extend_data, result_process)
    end
    # Part where the extend_data request to open the party
    # @param extend_data [PFM::ItemDescriptor::Wrapper]
    # @param result_process [Proc, nil]
    # @return [PFM::ItemDescriptor::Wrapper, false]
    def util_item_open_party_sequence(extend_data, result_process)
      party = @team || $actors
      GamePlay.open_party_menu_to_use_item(extend_data, party) do |scene|
        if $game_temp.in_battle && scene.pokemon_selected?
          GamePlay.bag_mixin.from(self).battle_item_wrapper = extend_data
          @running = false
          next
        else
          if scene.pokemon_selected?
            $bag.remove_item(extend_data.item.id, 1) if extend_data.item.is_limited
          end
        end
        result_process&.call
      end
      return false unless @running
      return extend_data
    end
    # Part where the extend_data request to use the item
    # @param extend_data [PFM::ItemDescriptor::Wrapper]
    # @param result_process [Proc, nil]
    # @return [PFM::ItemDescriptor::Wrapper, false]
    def util_item_on_use_sequence(extend_data, result_process)
      message = parse_text(22, 46, PFM::Text::TRNAME[0] => $trainer.name, PFM::Text::ITEM2[1] => extend_data.item.exact_name)
      if extend_data.use_before_telling
        if extend_data.on_use(self) != :unused
          $bag.remove_item(extend_data.item.id, 1) if extend_data.item.is_limited
          display_message(message) if $scene == self
          if $game_temp.common_event_id > 0
            return_to_scene(Scene_Map)
          else
            result_process&.call
          end
          return extend_data
        end
        return false
      end
      $bag.remove_item(extend_data.item.id, 1) if extend_data.item.is_limited
      display_message(message)
      extend_data.on_use(self)
      result_process&.call
      return extend_data
    end
  end
end
module PFM
  # InGame Bag management
  #
  # The global Bag object is stored in $bag and PFM.game_state.bag
  # @author Nuri Yuri
  class Bag
    # Last socket used in the bag
    # @return [Integer]
    attr_accessor :last_socket
    # Last index in the socket
    # @return [Integer]
    attr_accessor :last_index
    # If the bag is locked (and react as being empty)
    # @return [Boolean]
    attr_accessor :locked
    # Set the last battle item
    # @return [Symbol]
    attr_accessor :last_battle_item_db_symbol
    # Set the last ball used
    # @return [Symbol]
    attr_accessor :last_ball_used_db_symbol
    # Tell if the bag is alpha sorted
    # @return [Boolean]
    attr_accessor :alpha_sorted
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Number of shortcut
    SHORTCUT_AMOUNT = 4
    # Create a new Bag
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state = PFM.game_state)
      self.game_state = game_state
      @items = Hash.new(0)
      @orders = [[], [], [], [], [], [], []]
      @last_socket = 1
      @last_index = 0
      @shortcut = Array.new(SHORTCUT_AMOUNT, :__undef__)
      @locked = false
      @last_battle_item_db_symbol = :__undef__
      @last_ball_used_db_symbol = :__undef__
      @alpha_sorted = false
    end
    # Convert bag to .26 format
    def convert_to_dot26
      return if @items.is_a?(Hash)
      items = Hash.new(0)
      items.merge!(@items.map.with_index { |quantity, id| [data_item(id).db_symbol, quantity] }.reject { |v| v.last == 0 }.to_h)
      items.delete(:__undef__)
      @items = items
      @orders.map! { |order| order.map { |id| data_item(id).db_symbol }.reject { |db_symbol| db_symbol == :__undef__ } }
    ensure
      @items.transform_values! { |v| v || 0 }
    end
    # If the bag contain a specific item
    # @param db_symbol [Symbol] db_symbol of the item
    # @return [Boolean]
    def contain_item?(db_symbol)
      return item_quantity(db_symbol) > 0
    end
    alias has_item? contain_item?
    # Tell if the bag is empty
    # @return [Boolean]
    def empty?
      return @items.empty?
    end
    # The quantity of an item in the bag
    # @param db_symbol [Symbol] db_symbol of the item
    # @return [Integer]
    def item_quantity(db_symbol)
      return 0 if @locked
      db_symbol = data_item(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return @items[db_symbol]
    end
    # Add items in the bag and trigger the right quest objective
    # @param db_symbol [Symbol] db_symbol of the item
    # @param nb [Integer] number of item to add
    def add_item(db_symbol, nb = 1)
      return if @locked
      return remove_item(db_symbol, -nb) if nb < 0
      db_symbol = data_item(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @items[db_symbol] += nb
      add_item_to_order(db_symbol)
      game_state.quests.add_item(db_symbol) unless game_state.bag != self
    end
    alias store_item add_item
    # Remove items from the bag
    # @param db_symbol [Symbol] db_symbol of the item
    # @param nb [Integer] number of item to remove
    def remove_item(db_symbol, nb = 999)
      return if @locked
      return add_item(db_symbol, -nb) if nb < 0
      db_symbol = data_item(db_symbol).db_symbol if db_symbol.is_a?(Integer)
      return if db_symbol == :__undef__
      @items[db_symbol] -= nb
      if @items[db_symbol] <= 0
        @items.delete(db_symbol)
        remove_item_from_order(db_symbol)
      end
    end
    alias drop_item remove_item
    # Get the order of items in a socket
    # @param socket [Integer, Symbol] ID of the socket
    # @return [Array]
    def get_order(socket)
      return [] if @locked
      return @shortcut if socket == :favorites
      return process_battle_order(socket) if socket.is_a?(Symbol)
      return (@orders[socket] ||= [])
    end
    # Reset the order of items in a socket
    # @param socket [Integer] ID of the socket
    # @return [Array] the new order
    def reset_order(socket)
      arr = get_order(socket)
      arr.select! { |db_symbol| data_item(db_symbol).socket == socket && @items[db_symbol] > 0 } unless socket == :favorites
      unless each_data_item.select { |item| item.socket == socket }.all? { |item| item.position.zero? }
        arr.sort! { |a, b| data_item(a).position <=> data_item(b).position }
      end
      @alpha_sorted = false
      return arr
    end
    alias sort_ids reset_order
    # Sort the item of a socket by their names
    # @param socket [Integer] ID of the socket
    # @param reverse [Boolean] if we want to sort reverse
    def sort_alpha(socket, reverse = false)
      if reverse
        reset_order(socket).sort! { |a, b| data_item(b).name <=> data_item(a).name }
        @alpha_sorted = false
      else
        reset_order(socket).sort! { |a, b| data_item(a).name <=> data_item(b).name }
        @alpha_sorted = true
      end
    end
    # Get the shortcuts
    # @return [Array<Symbol>]
    def shortcuts
      @shortcut ||= Array.new(SHORTCUT_AMOUNT, :__undef__)
      return @shortcut
    end
    alias get_shortcuts shortcuts
    # Get the last battle item
    # @return [Studio::Item]
    def last_battle_item
      data_item(@last_battle_item_db_symbol)
    end
    private
    # Make sure the item is in the order, if not add it
    # @param db_symbol [Symbol] db_symbol of the item
    def add_item_to_order(db_symbol)
      return if @items[db_symbol] <= 0
      socket = data_item(db_symbol).socket
      get_order(socket) << db_symbol unless get_order(socket).include?(db_symbol)
    end
    # Make sure the item is not in the order anymore
    # @param db_symbol [Symbol] db_symbol of the item
    def remove_item_from_order(db_symbol)
      return unless @items[db_symbol] <= 0
      get_order(data_item(db_symbol).socket).delete(db_symbol)
    end
  end
  class GameState
    # The bag of the player
    # @return [PFM::Bag]
    attr_accessor :bag
    on_initialize(:bag) {@bag = PFM.bag_class.new(self) }
    on_expand_global_variables(:bag) do
      $bag = @bag
      $bag.game_state = self
      $bag.convert_to_dot26 if trainer.current_version < 6659
    end
  end
end
PFM.bag_class = PFM::Bag
module UI
  # Module containing all the bag related UI
  module Bag
    # Utility showing the pocket list
    class PocketList < SpriteStack
      # @return [Integer] index of the current selected pocket
      attr_reader :index
      # Base coordinate of the active items
      ACTIVE_BASE_COORDINATES = [0, 192]
      # Base coordinate of the inactive items
      INACTIVE_BASE_COORDINATES = [0, 198]
      # Offset between each sprites
      OFFSET_X = 20
      # Array translating real pocket id to sprite piece
      POCKET_TRANSLATION = [0, 0, 1, 3, 5, 4, 2, 6, 7]
      # Name of the active image
      ACTIVE_IMAGE = 'bag/pockets_active'
      # Name of the inactive image
      INACTIVE_IMAGE = 'bag/pockets_inactive'
      # Create a new pocket list
      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>] each shown pocket by the UI
      def initialize(viewport, pocket_indexes)
        super(viewport, *INACTIVE_BASE_COORDINATES)
        create_sprites(pocket_indexes)
        @last_sprite = @stack[0]
        @index = 0
        self.z = 1
      end
      # Set the index of the current selected pocket
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, size - 1)
        @last_sprite.bitmap = RPG::Cache.interface(INACTIVE_IMAGE)
        @last_sprite.y = INACTIVE_BASE_COORDINATES.last
        (@last_sprite = @stack[@index]).bitmap = RPG::Cache.interface(ACTIVE_IMAGE)
        @last_sprite.y = ACTIVE_BASE_COORDINATES.last
      end
      private
      # @param pocket_indexes [Array<Integer>] each shown pocket by the UI
      def create_sprites(pocket_indexes)
        pocket_indexes.each do |pocket_id|
          add_pocket_sprite(pocket_id)
        end
      end
      # Add a pocket sprite
      # @param pocket_id [Integer] real ID of the pocket
      # @return [Sprite]
      def add_pocket_sprite(pocket_id)
        add_sprite(size * OFFSET_X, 0, INACTIVE_IMAGE, POCKET_TRANSLATION.size - 1, 1, type: SpriteSheet).sx = POCKET_TRANSLATION[pocket_id]
      end
    end
    # UI element showing the name of the Pocket in the bag
    class WinPocket < SpriteStack
      # Name of the background file
      BACKGROUND = 'bag/win_pocket'
      # Coordinate of the spritestack
      COORDINATES = 15, 4
      # Create a new WinPocket
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *COORDINATES)
        init_sprite
      end
      # Set the text to show
      # @param text [String] the text to show
      def text=(text)
        @text.text = text
      end
      private
      def init_sprite
        create_background
        @text = create_text
      end
      # Create the background sprite
      def create_background
        add_background(BACKGROUND).set_z(1)
      end
      # Create the text
      # @return [Text]
      def create_text
        text = add_text(5, 6, 87, 13, nil.to_s, 1, color: 10)
        text.z = 2
        return text
      end
    end
    # Scrollbar UI element for the bag
    class ScrollBar < SpriteStack
      # @return [Integer] current index of the scrollbar
      attr_reader :index
      # @return [Integer] number of possible indexes
      attr_reader :max_index
      # Number of pixel the scrollbar use to move the button
      HEIGHT = 160
      # Base Y for the scrollbar
      BASE_Y = 36
      # BASE X for the scrollbar
      BASE_X = 309
      # Background of the scrollbar
      BACKGROUND = 'bag/scroll'
      # Image of the button
      BUTTON = 'bag/button_scroll'
      # Create a new scrollbar
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, BASE_X, BASE_Y)
        @index = 0
        @max_index = 1
        init_sprite
      end
      # Set the current index of the scrollbar
      # @param value [Integer] the new index
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = BASE_Y + HEIGHT * @index / @max_index
      end
      # Set the number of possible index
      # @param value [Integer] the new max index
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end
      private
      def init_sprite
        create_background
        @button = create_button
      end
      # Create the background
      def create_background
        add_background(BACKGROUND).set_z(1)
      end
      # Create the button
      # @return [Sprite]
      def create_button
        add_sprite(-1, 0, BUTTON).set_z(2)
      end
    end
    # Class that show the bag sprite in the Bag UI
    class BagSprite < SpriteSheet
      # @return [Integer] the current socket index
      attr_reader :index
      # Array translating real pocket id to sprite piece
      POCKET_TRANSLATION = [0, 0, 1, 3, 5, 4, 2, 6, 7]
      # Coordinates of the bag
      COORDINATES = [71, 103]
      # Create a new Bah Sprite
      # @param viewport [Viewport]
      # @param pocket_indexes [Array<Integer>] each shown pocket by the UI
      def initialize(viewport, pocket_indexes)
        super(viewport, 1, POCKET_TRANSLATION.size - 1)
        @index = 0
        @pocket_indexes = pocket_indexes
        init_sprite
      end
      # Set the current socket index
      def index=(value)
        @index = value.clamp(0, @pocket_indexes.size - 1)
        self.sy = POCKET_TRANSLATION[@pocket_indexes[@index]] || 0
      end
      # Start the animation between socket
      def animate(target_index)
        @target_index = target_index.clamp(0, @pocket_indexes.size - 1)
        @counter = 0
      end
      # Update the animation
      def update
        return if done?
        if @counter < 2
          self.x = COORDINATES.first - @counter
        else
          if @counter < 4
            self.x = COORDINATES.first - 4 + @counter
          else
            if @counter == 4
              self.index = @target_index
            else
              if @counter < 6
                self.x = COORDINATES.first + @counter - 4
              else
                self.x = COORDINATES.first + 8 - @counter
              end
            end
          end
        end
        @counter += 1
      end
      # Test if the animation is done
      # @return [Boolean]
      def done?
        @counter >= 8
      end
      # Test if the animation is at the middle of its progression
      # @return [Boolean]
      def mid?
        @counter == 4
      end
      private
      def init_sprite
        set_bitmap(bag_filename, :interface)
        set_position(*COORDINATES)
        set_origin(width / 2, height / 2)
        self.z = 1
      end
      # Return the bag filename
      # @return [String]
      def bag_filename
        $trainer.playing_girl ? 'bag/bag_girl' : 'bag/bag'
      end
    end
    # List of button showing the item name
    class ButtonList < Array
      # Number of button in the list
      AMOUNT = 9
      # Offset between each button
      BUTTON_OFFSET = 25
      # Offset between active button & inative button
      ACTIVE_OFFSET = -8
      # Base X coordinate
      BASE_X = 191
      # Base Y coordinate
      BASE_Y = 18
      # @return [Integer] index of the current active item
      attr_reader :index
      # Create a new ButtonList
      def initialize(viewport)
        super(AMOUNT) do |i|
          ItemButton.new(viewport, i)
        end
        @item_list = []
        @name_list = []
        @index = 0
      end
      # Update the animation
      def update
        return unless @animation
        send(@animation)
        @counter += 1
      end
      # Test if the animation is done
      # @return [Boolean]
      def done?
        @animation.nil?
      end
      # Set the current active item index
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, @item_list.size)
        update_button_texts
      end
      # Move all the button up
      def move_up
        @animation = :move_up_animation
        @counter = 0
      end
      # Move all the button down
      def move_down
        @animation = :move_down_animation
        @counter = 0
      end
      # Set the item list
      # @param list [Array<Integer>]
      def item_list=(list)
        @item_list = list
        @name_list = @item_list.collect { |id| data_item(id).exact_name }
        @name_list << text_get(22, 7)
      end
      # Return the delta index with mouse position
      # @return [Integer]
      def mouse_delta_index
        mouse_index = find_index(&:simple_mouse_in?)
        return 0 unless mouse_index
        active_index = find_index(&:active?) || 0
        return mouse_index - active_index
      end
      private
      # Move up animation
      def move_up_animation
        each { |button| button.move(0, -BUTTON_OFFSET / 3) } if @counter < 2
        if @counter == 3
          rotate!
          each_with_index do |button, index|
            button.index = index
            button.reset
          end
          @index += 1
          last.text = button_name(start_index + size - 1)
          @animation = nil
        end
      end
      # Move down animation
      def move_down_animation
        if @counter < 2
          was_active = false
          each do |button|
            dx = was_active ? -3 : 0
            button.move(button.active? ? 3 : dx, BUTTON_OFFSET / 3)
          end
        end
        if @counter == 3
          rotate!(-1)
          each_with_index do |button, index|
            button.index = index
            button.reset
          end
          @index -= 1
          first.text = button_name(start_index)
          @animation = nil
        end
      end
      # Update the button texts
      def update_button_texts
        index = start_index
        each do |button|
          button.text = button_name(index)
          index += 1
        end
      end
      # Get the button name
      # @param index [Integer]
      # @return [String, nil]
      def button_name(index)
        index < 0 ? nil : @name_list[index]
      end
      # Return the start index of the list
      # @return [Integer]
      def start_index
        @index - 2
      end
      # Button showing the item name
      class ItemButton < SpriteStack
        # Name of the button background
        BACKGROUND = 'bag/button_list'
        # @return [Integer] Index of the button in the list
        attr_accessor :index
        # Create a new Item button
        # @param viewport [Viewport]
        # @param index [Integer]
        def initialize(viewport, index)
          @index = index
          super(viewport, BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
          create_background
          @item_name = create_text
        end
        # Is the button active
        def active?
          @index == 2
        end
        # Set the button text
        # @param text [String, nil] the item name
        def text=(text)
          return unless (self.visible = !text.nil?)
          @item_name.text = text
        end
        # Reset the button coordinate
        def reset
          set_position(BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
        end
        private
        # Create the background of the button
        def create_background
          add_background(BACKGROUND).set_z(1)
        end
        # Create the text
        # @return [Text]
        def create_text
          text = add_text(7, 4, 0, 13, nil.to_s, color: 10)
          text.z = 2
          return text
        end
      end
    end
    # Arrow telling which item is selected
    class Arrow < Sprite
      # Create a new arrow
      # @param viewport [Viewport]
      def initialize(viewport)
        super
        @counter = 0
        init_sprite
      end
      # Update the arrow animation
      def update
        if @counter == 30
          self.x -= 1
        else
          if @counter == 60
            self.x += 1
            @counter = 0
          end
        end
        @counter += 1
      end
      private
      # Initialize the sprite
      def init_sprite
        set_position(*coordinates)
        set_bitmap(image_name, :interface)
        self.z = 4
      end
      # Return the coordinate of the sprite
      # @return [Array<Integer>]
      def coordinates
        return 166, 72
      end
      # Return the name of the sprite
      # @return [String]
      def image_name
        'bag/arrow'
      end
    end
    # Class that shows the minimal item info
    class InfoCompact < SpriteStack
      # Mode of the bag
      # @return [Symbol]
      attr_reader :mode
      # Coordinate of the UI
      COORDINATES = 9, 145
      # Create a new InfoCompact
      # @param viewport [Viewport]
      # @param mode [Symbol] mode of the bag scene
      def initialize(viewport, mode)
        super(viewport, *COORDINATES)
        @mode = mode
        init_sprite
      end
      # Change the item it shows
      # @param id [Integer] ID of the item to show
      def show_item(id)
        unless (self.visible = !id.nil?)
          @icon.data = 0
          @icon.visible = true
          return @stack.first.visible = true
        end
        item = data_item(id)
        @icon.data = id
        @quantity.text = (id == 0 ? 0 : $bag.item_quantity(id)).to_s.to_pokemon_number
        @num_x.visible = @quantity.visible = item.is_limited
        @name.text = item.exact_name
        @price_text&.text = parse_text(11, 9, /\[VAR NUM7[^\]]*\]/ => (item.price / 2).to_s)
      end
      private
      def init_sprite
        create_background
        @icon = create_icon
        @num_x = create_cross
        @quantity = create_quantity_text
        @name = create_name_text
        @price_text = create_price_text
      end
      def create_background
        add_background('bag/win_info_compact').set_z(1)
      end
      # @return [ItemSprite]
      def create_icon
        add_sprite(1, 3, NO_INITIAL_IMAGE, type: ItemSprite).set_z(2)
      end
      # @return [Sprite]
      def create_cross
        add_sprite(35, 7, 'bag/num_x').set_z(2)
      end
      # @return [Text]
      def create_quantity_text
        text = add_text(41, 1, 0, 13, nil.to_s, color: 10)
        text.z = 2
        return text
      end
      # @return [Text]
      def create_name_text
        text = add_text(36, 16, 0, 13, nil.to_s, color: 24)
        text.z = 2
        return text
      end
      # @return [Text, nil]
      def create_price_text
        return nil if mode != :shop
        return add_text(140, 1, 0, 13, nil.to_s, 2, color: 10)
      end
    end
    # Class that shows the full item info (descr)
    class InfoWide < SpriteStack
      # Mode of the bag
      # @return [Symbol]
      attr_reader :mode
      # Coordinate of the UI
      COORDINATES = 0, 33
      # Create a new InfoWide
      # @param viewport [Viewport]
      # @param mode [Symbol] mode of the bag scene
      def initialize(viewport, mode)
        super(viewport, *COORDINATES)
        @mode = mode
        init_sprite
      end
      # Change the item it shows
      # @param id [Integer] ID of the item to show
      def show_item(id)
        unless (self.visible = !id.nil?)
          @icon.data = 0
          @icon.visible = true
          return @stack.first.visible = true
        end
        item = data_item(id)
        @icon.data = id
        @quantity.text = (id == 0 ? 0 : $bag.item_quantity(id)).to_s.to_pokemon_number
        @num_x.visible = @quantity.visible = item.is_limited
        @name.text = item.exact_name
        @descr.multiline_text = item.descr
        @fav_icon.visible = $bag.shortcuts.include?(item.db_symbol)
      end
      private
      def init_sprite
        create_background
        @icon = create_icon
        @num_x = create_cross
        @quantity = create_quantity_text
        @fav_icon = create_favorite_icon
        @name = create_name_text
        @descr = create_descr_text
      end
      def create_background
        add_background('bag/win_info_wide').set_z(4)
      end
      # @return [ItemSprite]
      def create_icon
        add_sprite(0, 3, NO_INITIAL_IMAGE, type: ItemSprite).set_z(5)
      end
      # @return [Sprite]
      def create_cross
        add_sprite(34, 7, 'bag/num_x').set_z(5)
      end
      # @return [Text]
      def create_quantity_text
        text = add_text(41, 1, 0, 13, nil.to_s, color: 10)
        text.z = 5
        return text
      end
      # @return [Sprite]
      def create_favorite_icon
        add_sprite(147, 6, 'bag/icon_fav').set_z(5)
      end
      # @return [Text]
      def create_name_text
        text = add_text(34, 17, 0, 13, nil.to_s, color: 24)
        text.z = 5
        return text
      end
      # @return [Text]
      def create_descr_text
        text = add_text(3, 37, 151, 16, nil.to_s)
        text.z = 5
        return text
      end
    end
    # Class that shows a search bar
    class SearchBar < SpriteStack
      # Coordinate of the search bar
      COORDINATES = 3, 220
      # @return [UI::UserInput] the search input object
      attr_reader :search_input
      # Create a new SearchBar
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *COORDINATES)
        init_sprite
        self.z = 506
      end
      # Update the search bar
      def update
        @search_input.update
      end
      private
      def init_sprite
        create_background
        @search_input = create_user_input
        create_shortcut_image
      end
      def create_background
        add_background('bag/search_bar')
      end
      # @return [UserInput]
      def create_user_input
        add_text(29, 1, 0, 13, nil.to_s, type: UserInput)
      end
      # @return [KeyShortcut]
      def create_shortcut_image
        add_sprite(216, 1, NO_INITIAL_IMAGE, Input::Keyboard::Enter, type: KeyShortcut)
      end
    end
  end
end
module GamePlay
  # Module defining the IO of the bag scene so user know what to expect
  #
  # This mixin should also be used to check if the bag scene is right:
  # @example
  #   Check the current scene is the bag
  #     GamePlay.current_scene.is_a?(GamePlay.bag_mixin)
  module BagMixin
    # ID of the item selected
    # @return [Symbol, Integer]
    attr_accessor :return_data
    # Wrapper of the choosen item in battle
    # @return [PFM::ItemDescriptor::Wrapper, nil]
    attr_accessor :battle_item_wrapper
    # Get the mode in which the bag was started
    # @return [Symbol]
    attr_reader :mode
    # Get the selected item db_symbol
    # @return [Symbol]
    def selected_item_db_symbol
      return :__undef__ if return_data == -1
      return data_item(return_data).db_symbol
    end
  end
  # Scene responsive of displaying the bag
  #
  # The bag has various modes :
  #   - :menu : when opened from the menu
  #   - :battle : when opened from the battle
  #   - :berry : when opened to plant berry
  #   - :hold : when opened to give an item to a Pokemon
  #   - :shop : when opened to sell item
  #   - :map : when an event request an item
  class Bag < BaseCleanUpdate::FrameBalanced
    include BagMixin
    # List of pocket name
    POCKET_NAMES = [nil.to_s, [:text_get, 15, 4], [:text_get, 15, 1], [:text_get, 15, 5], [:text_get, 15, 3], [:text_get, 15, 8], [:text_get, 15, 0], [:ext_text, 9000, 150], [:ext_text, 9000, 151]]
    # List of pocket index the player can see according to the modes
    POCKETS_PER_MODE = {menu: [1, 2, 6, 3, 5, 4, 8], battle: [2, 6, 4], berry: [4], hold: [1, 2, 6, 4], shop: [1, 2, 6, 3, 4]}
    POCKETS_PER_MODE.default = POCKETS_PER_MODE[:menu]
    # ID of the favorite pocket (shortcut)
    FAVORITE_POCKET_ID = 8
    # Create a new Bag Scene
    # @param mode [Symbol] mode of the bag scene allowing to choose the pocket to show
    def initialize(mode = :menu)
      super()
      @return_data = -1
      @mode = mode
      load_pockets
      @socket_index = $user_data.dig(:psdk_bag, :socket_index, mode) || $bag.last_socket || 0
      @socket_index = @socket_index.clamp(0, @last_socket_index = @pocket_indexes.size - 1)
      load_item_list
      @index = $user_data.dig(:psdk_bag, :index, mode) || $bag.last_index || 0
      @index = @index.clamp(0, @last_index)
      @compact_mode = $user_data.dig(:psdk_bag, :compact_mode) || :enabled
      @searching = false
      Mouse.wheel = 0
    end
    private
    # Ensure we store all the information for the next time we open the bag
    def main_end
      super
      $bag.last_socket = (($user_data[:psdk_bag] ||= {})[:socket_index] ||= {})[@mode] = @socket_index
      $bag.last_index = ($user_data[:psdk_bag][:index] ||= {})[@mode] = @index
      $user_data[:psdk_bag][:compact_mode] = @compact_mode
    end
    # Load the list of item (ids) for the current pocket
    def load_item_list
      if pocket_id == FAVORITE_POCKET_ID
        @item_list = $bag.get_order(:favorites)
      else
        @item_list = $bag.get_order(pocket_id)
      end
      @index = 0
      @last_index = @item_list.size
    end
    alias reload_item_list load_item_list
    # Load the pockets index & names
    def load_pockets
      @pocket_indexes = POCKETS_PER_MODE[@mode]
      @pocket_names = @pocket_indexes.collect { |id| get_text(POCKET_NAMES[id]) }
    end
    # Get the actual pocket ID
    def pocket_id
      @pocket_indexes[@socket_index]
    end
    # Change the pocket
    # @param new_index [Integer] new pocket index
    def change_pocket(new_index)
      @socket_index = new_index
      @pocket_ui.index = new_index
      update_pocket_name
      reload_item_list
      update_scroll_bar
      update_item_button_list
      update_info
    end
    public
    include UI::Bag
    # List of button text according to the mode
    CTRL_TEXTS_PER_MODE = {menu: [[:ext_text, 9000, 152], info = [:ext_text, 9000, 153], sort = [:ext_text, 9000, 154], [:ext_text, 9000, 115]], battle: [[:ext_text, 9000, 159], info, sort, cancel = [:ext_text, 9000, 17]], berry: [[:ext_text, 9000, 156], info, sort, cancel], hold: [[:ext_text, 9000, 157], info, sort, cancel], shop: [[:ext_text, 9000, 155], info, sort, cancel], map: [[:ext_text, 9000, 158], info, sort, cancel]}
    CTRL_TEXTS_PER_MODE.default = CTRL_TEXTS_PER_MODE[:menu]
    # Update the bag graphics
    def update_graphics
      @base_ui.update_background_animation
      @animation&.call
      update_arrow
    end
    private
    # Create all the graphics for the UI
    def create_graphics
      create_viewport
      create_base_ui
      create_pocket_ui
      create_scroll_bar
      create_bag_sprite
      create_item_list
      create_arrow
      create_info
      create_shadow
      create_search
      create_frame
      Graphics.sort_z
    end
    # Create the base ui
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
    end
    # Fetch the button text
    # @return [Array<String>]
    def button_texts
      CTRL_TEXTS_PER_MODE[@mode].collect { |data| get_text(data) }
    end
    # Create the frame
    def create_frame
      @frame = Sprite.new(@viewport)
      filename = "bag/overlay_#{$options.language}"
      filename = 'bag/overlay_en' unless RPG::Cache.interface_exist?(filename)
      @frame.set_bitmap(filename, :interface).set_z(32)
    end
    # Create the pocket UI
    def create_pocket_ui
      @pocket_ui = PocketList.new(@viewport, @pocket_indexes)
      @pocket_ui.index = @socket_index
      @pocket_name = WinPocket.new(@viewport)
      update_pocket_name
    end
    # Update the pocket name
    def update_pocket_name
      @pocket_name.text = @pocket_names[@socket_index]
    end
    # Create the scroll bar
    def create_scroll_bar
      @scroll_bar = ScrollBar.new(@viewport)
      update_scroll_bar
    end
    # Update the scroll bar max index
    def update_scroll_bar
      @scroll_bar.max_index = @last_index
    end
    # Create the bag sprite
    def create_bag_sprite
      @bag_sprite = BagSprite.new(@viewport, @pocket_indexes)
      @bag_sprite.index = @socket_index
    end
    # Create the item list
    def create_item_list
      @item_button_list = ButtonList.new(@viewport)
      update_item_button_list
    end
    # Update the item list
    def update_item_button_list
      @item_button_list.item_list = @item_list
      @item_button_list.index = @index
    end
    # Create the arrow
    def create_arrow
      @arrow = Arrow.new(@viewport)
    end
    # Update the arrow
    def update_arrow
      @arrow.update
    end
    # Create the info
    def create_info
      @info_compact = InfoCompact.new(@viewport, @mode)
      @info_wide = InfoWide.new(@viewport, @mode)
      update_info_visibility
      update_info
    end
    # Update the visibility of info box according to the mode
    def update_info_visibility
      compact = @compact_mode == :enabled
      @info_compact.visible = compact
      @info_wide.visible = !compact
      @bag_sprite.index = @socket_index
      @bag_sprite.visible = compact
    end
    # Update the info shown in the info box
    def update_info
      if @compact_mode == :enabled
        @info_compact.show_item(@item_list[@index])
      else
        @info_wide.show_item(@item_list[@index])
      end
    end
    # Create the shadow helping to focus on the important thing
    def create_shadow
      @shadows = {enabled: Sprite.new(@viewport).set_bitmap('bag/selec_compact_shadow', :interface).set_z(3), disabled: Sprite.new(@viewport).set_bitmap('bag/selec_wide_shadow', :interface).set_z(3)}
      @shadows.each_value { |sprite| sprite.visible = false }
    end
    # Show the shadow
    def show_shadow_frame
      @shadows[@compact_mode]&.visible = true
    end
    # Hide the shadow
    def hide_shadow_frame
      @shadows[@compact_mode]&.visible = false
    end
    # Create the search bar
    def create_search
      @search_bar = SearchBar.new(@viewport)
      @search_bar.visible = false
      @search_bar.search_input.init(25, '', on_new_char: method(:search_add), on_remove_char: method(:search_rem))
    end
    public
    # Update the bag inputs
    def update_inputs
      return false if @animation
      return update_search && update_ctrl_button && update_socket_input && update_list_input
    end
    private
    # Input update related to the socket index
    # @return [Boolean] if other update can be done
    def update_socket_input
      return true unless index_changed(:@socket_index, :LEFT, :RIGHT, @last_socket_index)
      play_cursor_se
      @bag_sprite.visible ? animate_pocket_change(@socket_index) : change_pocket(@socket_index)
      return false
    end
    # Input update related to the item list
    # @return [Boolean] if another update can be done
    def update_list_input
      index = @index
      return true unless index_changed(:@index, :UP, :DOWN, @last_index)
      play_cursor_se
      delta = @index - index
      if delta.abs == 1
        animate_list_index_change(delta)
      else
        update_item_button_list
        update_info
        @scroll_bar.index = @index
      end
      return false
    end
    # Update the search input
    # @return [Boolean] if the other action can be performed
    def update_search
      return true unless @searching
      if Input.trigger?(:A)
        @searching = false
        @search_bar.visible = false
        @base_ui.hide_win_text
        @base_ui.ctrl.last.visible = true
        Input::Keys[:A].clear.concat(@saved_keys)
      else
        @search_bar.update
        update_list_input
      end
      return false
    end
    # Update CTRL button (A/B/X/Y)
    def update_ctrl_button
      if Input.trigger?(:B)
        action_b
      else
        if Input.trigger?(:A)
          action_a
        else
          if Input.trigger?(:X)
            action_x
          else
            if Input.trigger?(:Y)
              action_y
            else
              return true
            end
          end
        end
      end
      return false
    end
    # Action related to B button
    def action_b
      play_cancel_se
      @running = false
    end
    # Action related to A button
    def action_a
      send(CHOICE_MODE_A[@mode])
    end
    # Action related to X button
    def action_x
      play_decision_se
      @compact_mode = (@compact_mode == :enabled ? :disabled : :enabled)
      update_info_visibility
      update_info
    end
    # Action related to Y button
    def action_y
      send(CHOICE_MODE_Y[@mode])
    end
    public
    private
    # Start the Pocket change animation
    # @param new_index [Integer] the new pocket index
    def animate_pocket_change(new_index)
      @bag_sprite.animate(new_index)
      @animation = proc do
        @bag_sprite.update
        next((@animation = nil)) if @bag_sprite.done?
        next unless @bag_sprite.mid?
        change_pocket(new_index)
      end
    end
    # Start the move up/down animation
    # @param delta [Integer] number of time to move up/down
    def animate_list_index_change(delta)
      count = delta.abs
      max = delta.abs
      @animation = proc do
        @item_button_list.update
        next unless @item_button_list.done?
        next(@animation = nil) if count <= 0
        @index += delta / max if max > 1
        delta > 0 ? @item_button_list.move_up : @item_button_list.move_down
        @scroll_bar.index = @index
        update_info
        count -= 1
      end
    end
    public
    # Constant that list all the choice method called when the player press A
    # depending on the bag mode
    CHOICE_MODE_A = {menu: :choice_a_menu, berry: :choice_a_berry, hold: :choice_a_hold, shop: :choice_a_shop, map: :choice_a_map, battle: :choice_a_battle}
    CHOICE_MODE_A.default = CHOICE_MODE_A[:menu]
    # Constant that list all the choice called when the player press Y
    # depending on the bag mode
    CHOICE_MODE_Y = {menu: :choice_y_menu}
    CHOICE_MODE_Y.default = CHOICE_MODE_Y[:menu]
    # Index of the search choice when pressing Y
    SEARCH_CHOICE_INDEX = 3
    private
    # Choice shown when you press A on menu mode
    def choice_a_menu
      item_id = @item_list[@index]
      return action_b if item_id.nil?
      return play_buzzer_se if item_id == 0
      item = data_item(item_id)
      play_decision_se
      show_shadow_frame
      map_usable = proc {!item.is_map_usable }
      giv_check = proc {PFM.game_state.pokemon_alive <= 0 || !item.is_holdable }
      if $bag.shortcuts.include?(item.db_symbol)
        reg_id = 14
        reg_meth = method(:unregister_item)
      else
        reg_id = 2
        reg_meth = method(:register_item)
        reg_check = map_usable
      end
      thr_check = proc {!item.is_limited }
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(22, 0), on_validate: method(:use_item), disable_detect: map_usable).register_choice(text_get(22, 3), on_validate: method(:give_item), disable_detect: giv_check).register_choice(text_get(22, reg_id), on_validate: reg_meth, disable_detect: reg_check).register_choice(text_get(22, 1), on_validate: method(:throw_item), disable_detect: thr_check).register_choice(text_get(22, 7))
      @base_ui.show_win_text(parse_text(22, 35, PFM::Text::ITEM2[0] => item.exact_name))
      y = 200 - 16 * choices.size
      choices.display_choice(@viewport, 306, y, nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      hide_shadow_frame
    end
    # Choice shown when you press Y on menu mode
    def choice_y_menu
      play_decision_se
      show_shadow_frame
      @base_ui.show_win_text(text_get(22, 79))
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(22, 81), on_validate: method(:sort_name)).register_choice(text_get(22, 84), on_validate: method(:sort_number)).register_choice(ext_text(9000, 151), on_validate: method(:sort_favorites)).register_choice(text_get(33, 130), on_validate: method(:search_item)).register_choice(text_get(22, 7))
      y = 200 - 16 * choices.size
      choice = choices.display_choice(@viewport, 306, y, nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text if choice != SEARCH_CHOICE_INDEX
      hide_shadow_frame
    end
    # Choice when the player press A in berry/map mode
    def choice_a_berry
      play_decision_se
      @running = false
      @return_data = @item_list[@index] ? data_item(@item_list[@index]).id : -1
    end
    alias choice_a_map choice_a_berry
    # Choice when the player press A in Hold mode
    def choice_a_hold
      item_id = @item_list[@index]
      return action_b if item_id.nil?
      return play_buzzer_se if item_id == 0 || !data_item(item_id).is_holdable
      play_decision_se
      @running = false
      @return_data = @item_list[@index]
    end
    # Choice when the player press A in shop mode
    def choice_a_shop
      sell_item
    end
    # Choice when the player press A in battle
    def choice_a_battle
      use_item_in_battle
    end
    public
    include Util::Item
    private
    # When player wants to use the item
    def use_item
      item_id = @item_list[index = @index]
      return play_buzzer_se unless $bag.contain_item?(item_id)
      util_item_useitem(item_id) do
        @base_ui.hide_win_text
        hide_shadow_frame
        update_bag_ui_after_action(index)
      end
    end
    # When player wants to use the item
    def use_item_in_battle
      item_id = @item_list[index = @index]
      return action_b if item_id == nil
      return play_buzzer_se unless data_item(item_id).is_battle_usable
      play_decision_se
      util_item_useitem(item_id)
      update_bag_ui_after_action(index)
    end
    # Make sure the bag UI gets update after an action
    # @param index [Integer] previous index value
    def update_bag_ui_after_action(index)
      load_item_list
      @index = index.clamp(0, @last_index)
      update_item_button_list
      update_info
    end
    # When the player wants to give an item
    def give_item
      item_id = @item_list[index = @index]
      return play_buzzer_se unless $bag.contain_item?(item_id)
      GamePlay.open_party_menu_to_give_item_to_pokemon(item_id) do
        @base_ui.hide_win_text
        hide_shadow_frame
        update_bag_ui_after_action(index)
      end
    end
    # When the player wants to register an item
    def register_item
      item_id = @item_list[@index]
      item = data_item(item_id)
      validate_meth = method(:set_shortcut)
      last_proc = proc do
        if (index = $bag.shortcuts.index(item.db_symbol)) && index < 4
          $bag.shortcuts[index] = :__undef__
        end
        $bag.shortcuts << item.db_symbol
      end
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice('↑', item.db_symbol, 0, on_validate: validate_meth).register_choice('←', item.db_symbol, 1, on_validate: validate_meth).register_choice('↓', item.db_symbol, 2, on_validate: validate_meth).register_choice('→', item.db_symbol, 3, on_validate: validate_meth).register_choice(ext_text(9000, 151), on_validate: last_proc)
      y = 200 - 16 * choices.size
      choices.display_choice(@viewport, 306, y, nil, on_update: method(:update_graphics), align_right: true)
      update_bag_ui_after_action(@index)
    end
    # Process method that set the new shortcut
    # @param db_symbol [Symbol] db_symbol of the item to register
    # @param index [Integer] index of the shortcut to change
    def set_shortcut(db_symbol, index)
      if (sh_index = $bag.shortcuts.index(db_symbol)) && sh_index > 3
        $bag.shortcuts[sh_index] = nil
      end
      $bag.shortcuts[index] = db_symbol
      $bag.shortcuts.compact!
    end
    # When the player wants to unregister an item
    def unregister_item
      item_id = @item_list[@index]
      item = data_item(item_id)
      sh_index = $bag.shortcuts.index(item.db_symbol)
      if sh_index > 3
        $bag.shortcuts[sh_index] = nil
      else
        $bag.shortcuts[sh_index] = :__undef__
      end
      $bag.shortcuts.compact!
      update_bag_ui_after_action(@index)
    end
    # When the player wants to throw an item
    def throw_item
      item_id = @item_list[index = @index]
      item = data_item(item_id)
      return play_buzzer_se unless $bag.contain_item?(item.db_symbol)
      $game_temp.num_input_variable_id = Yuki::Var::EnteredNumber
      $game_temp.num_input_digits_max = $bag.item_quantity(item.db_symbol).to_s.size
      $game_temp.num_input_start = $bag.item_quantity(item.db_symbol)
      PFM::Text.set_item_name(item.exact_name)
      display_message(parse_text(22, 38))
      value = $game_variables[Yuki::Var::EnteredNumber]
      if value > 0
        display_message(parse_text(22, 39, PFM::Text::NUM3[1] => value.to_s))
        $bag.remove_item(item.db_symbol, value)
        update_bag_ui_after_action(index)
      end
      PFM::Text.reset_variables
    end
    # When the player wants to sort the item by name
    def sort_name
      if pocket_id == FAVORITE_POCKET_ID
        shortcuts = $bag.shortcuts[0, 4]
        $bag.shortcuts.shift(4)
        $bag.sort_alpha(:favorites)
        $bag.shortcuts.unshift(*shortcuts)
      else
        $bag.sort_alpha(pocket_id)
      end
      update_bag_ui_after_action(@index)
      display_message(text_get(22, 69))
    end
    # When the player wants to sort the item by number
    def sort_number
      if pocket_id == FAVORITE_POCKET_ID
        shortcuts = $bag.shortcuts[0, 4]
        $bag.shortcuts.shift(4)
        $bag.reset_order(:favorites)
        $bag.shortcuts.unshift(*shortcuts)
      else
        $bag.reset_order(pocket_id)
      end
      update_bag_ui_after_action(@index)
      display_message(text_get(22, 86))
    end
    # When the player wants to sort by favorites
    def sort_favorites
      return if pocket_id == FAVORITE_POCKET_ID
      fav = $bag.get_order(:favorites)
      ori_list = @item_list.clone
      @item_list.sort! do |item_id_a, item_id_b|
        (fav.index(item_id_a) || (ori_list.index(item_id_a) + fav.size)) <=> (fav.index(item_id_b) || (ori_list.index(item_id_b) + fav.size))
      end
      update_bag_ui_after_action(@index)
    end
    # When the player wants to search an item
    def search_item
      @base_ui.show_win_text('')
      @base_ui.ctrl.last.visible = false
      @search_bar.visible = true
      sort_sprites
      @searching = ''
      @item_ids ||= each_data_item.map(&:id)
      @saved_keys = Input::Keys[:A].clone
      Input::Keys[:A].clear << Input::Keyboard::Enter
      @pocket_name.text = ext_text(9000, 160)
      @item_list = []
      @last_index = 0
      update_search_info
    end
    # When the search gets a new character
    # @param _full_text [String] current text in search
    # @param char [String] added char
    def search_add(_full_text, char)
      searching = Regexp.new(@searching + char, true)
      results = @item_ids.select { |id| data_item(id).exact_name =~ searching && $bag.contain_item?(id) }
      if results.empty?
        char = '.'
        searching = Regexp.new(@searching + char, true)
        results = @item_ids.select { |id| data_item(id).exact_name =~ searching && $bag.contain_item?(id) }
      end
      @item_list = results
      @last_index = results.size
      update_search_info
      @searching << char
    rescue RegexpError
      @searching << char
    end
    # When the search removes a character
    # @param _full_text [String] current text in search
    # @param _char [String] removed char
    def search_rem(_full_text, _char)
      @searching.chop!
      searching = Regexp.new(@searching, true)
      results = @item_ids.select { |id| data_item(id).exact_name =~ searching && $bag.contain_item?(id) }
      @item_list = results
      @last_index = results.size
      update_search_info
    rescue RegexpError
      0
    end
    # Update the search info
    def update_search_info
      update_item_button_list
      update_info
      update_scroll_bar
    end
    # When the player wants to sell an item
    def sell_item
      play_decision_se
      item_id = @item_list[@index]
      return action_b if item_id == nil
      price = data_item(item_id).price / 2
      PFM::Text.set_item_name(data_item(item_id).exact_name)
      if price > 0
        $game_temp.num_input_variable_id = ::Yuki::Var::EnteredNumber
        $game_temp.num_input_digits_max = $bag.item_quantity(item_id).to_s.size
        $game_temp.num_input_start = $bag.item_quantity(item_id)
        $game_temp.shop_calling = price
        display_message(parse_text(22, 170))
        $game_temp.shop_calling = false
        value = $game_variables[::Yuki::Var::EnteredNumber]
        return unless value > 0
        c = display_message(parse_text(22, 171, NUM7R => (value * price).to_s), 1, text_get(11, 27), text_get(11, 28))
        return if c != 0
        $bag.remove_item(item_id, value)
        PFM.game_state.add_money(value * price)
        update_bag_ui_after_action(@index)
        display_message(parse_text(22, 172, NUM7R => (value * price).to_s))
      else
        ::PFM::Text.set_plural(false)
        display_message(parse_text(22, 174))
      end
    ensure
      PFM::Text.reset_variables
    end
    public
    # List of action the mouse can perform with ctrl button
    ACTIONS = %i[action_a action_x action_y action_b]
    # Tell if the mouse over is enabled
    MOUSE_OVER_ENABLED = false
    # Update the mouse interactions
    # @param moved [Boolean] if the mouse moved durring the frame
    # @return [Boolean] if the thing after can update
    def update_mouse(moved)
      return update_mouse_index if Mouse.wheel != 0
      return false if moved && update_mouse_list
      return update_pocket_input && update_ctrl_button_mouse
    end
    private
    # Part where we update the mouse ctrl button
    def update_ctrl_button_mouse
      update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS)
      return false
    end
    # Part where we update the current pocket index
    def update_pocket_input
      return true unless Mouse.trigger?(:LEFT)
      new_index = @pocket_ui.stack.find_index(&:simple_mouse_in?)
      if new_index
        play_cursor_se
        @bag_sprite.visible ? animate_pocket_change(new_index) : change_pocket(new_index)
        return false
      end
      return true
    end
    # Part where we try to update the list index
    def update_mouse_list
      return false unless MOUSE_OVER_ENABLED
      delta = @item_button_list.mouse_delta_index
      return true if delta == 0 || @last_mouse_delta == delta
      update_mouse_delta_index(delta)
      return false
    ensure
      @last_mouse_delta = delta
    end
    # Part where we try to update the list index if the mouse wheel change
    def update_mouse_index
      delta = -Mouse.wheel
      update_mouse_delta_index(delta)
      Mouse.wheel = 0
      return false
    end
    # Update the list index according to a delta with mouse interaction
    # @param delta [Integer] number of index we want to add / remove
    def update_mouse_delta_index(delta)
      new_index = (@index + delta).clamp(0, @last_index)
      delta = new_index - @index
      return if delta == 0
      if delta.abs < 5
        @index = new_index if delta.abs == 1
        animate_list_index_change(delta)
      else
        @index = new_index
        update_item_button_list
        update_info
        @scroll_bar.index = @index
      end
    end
  end
  # Battle specialization of the bag
  class Battle_Bag < Bag
    # Create a new Battle_Bag
    # @param team [Array<PFM::PokemonBattler>] party that use this bag UI
    def initialize(team)
      super(:battle)
      @team = team
    end
  end
end
GamePlay.bag_mixin = GamePlay::BagMixin
GamePlay.bag_class = GamePlay::Bag
GamePlay.battle_bag_class = GamePlay::Battle_Bag
