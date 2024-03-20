module PFM
  # Class describing the shop logic
  class Shop
    # Hash containing the defined shops
    # @return [Hash{Symbol => Hash{Symbol => Integer}}]
    attr_accessor :shop_list
    # Hash containing the defined Pokemon shops
    # @return [Hash{Symbol => Array}]
    attr_accessor :pokemon_shop_list
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Create a new shop handler
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state = PFM.game_state)
      @shop_list = {}
      @pokemon_shop_list = {}
      @game_state = game_state
    end
    # Create a new limited Shop
    # @param symbol_of_shop [Symbol] the symbol to link to the new shop
    # @param items_sym [Array<Symbol, Integer>] the array containing the symbols/id of the items to sell
    # @param items_quantity [Array<Integer>] the array containing the quantity of the items to sell
    # @param shop_rewrite [Boolean] if the system must completely overwrite an already existing shop
    def create_new_limited_shop(symbol_of_shop, items_sym = [], items_quantity = [], shop_rewrite: false)
      return refill_limited_shop(symbol_of_shop, items_sym, items_quantity) if @shop_list.key?(symbol_of_shop) && !shop_rewrite
      @shop_list.delete(symbol_of_shop) if @shop_list.key?(symbol_of_shop) && shop_rewrite
      @shop_list[symbol_of_shop] = {}
      refill_limited_shop(symbol_of_shop, items_sym, items_quantity)
    end
    # Refill an already existing shop with items (Create the shop if it does not exist)
    # @param symbol_of_shop [Symbol] the symbol of the existing shop
    # @param items_to_refill [Array<Symbol, Integer>] the array of the items' db_symbol/id
    # @param quantities_to_refill [Array<Integer>] the array of the quantity to refill
    def refill_limited_shop(symbol_of_shop, items_to_refill = [], quantities_to_refill = [])
      if @shop_list.key?(symbol_of_shop)
        items_to_refill.each_with_index do |id, index|
          key = @shop_list[symbol_of_shop].keys.index { |hash_key| data_item(hash_key).db_symbol == data_item(id).db_symbol }
          id = data_item(id).id
          @shop_list[symbol_of_shop][id] = 0 unless key
          @shop_list[symbol_of_shop][id] += quantities_to_refill[index] || 1
          @shop_list[symbol_of_shop][id] = 1 unless data_item(id).is_limited
        end
      else
        create_new_limited_shop(symbol_of_shop, items_to_refill, quantities_to_refill)
      end
    end
    # Remove items from an already existing shop (return if do not exist)
    # @param symbol_of_shop [Symbol] the symbol of the existing shop
    # @param items_to_remove [Array<Symbol, Integer>] the array of the items' db_symbol/id
    # @param quantities_to_remove [Array<Integer>] the array of the quantity to remove
    def remove_from_limited_shop(symbol_of_shop, items_to_remove, quantities_to_remove)
      return log_debug('You can\'t remove items from a non-existing shop') unless @shop_list.key?(symbol_of_shop)
      items_to_remove.each_with_index do |id, index|
        key = @shop_list[symbol_of_shop].keys.index { |hash_key| data_item(hash_key).db_symbol == data_item(id).db_symbol }
        id = data_item(id).id
        next unless key
        @shop_list[symbol_of_shop][id] -= (quantities_to_remove[index].nil? ? Float::INFINITY : quantities_to_remove[index])
        @shop_list[symbol_of_shop].delete(id) if @shop_list[symbol_of_shop][id] <= 0
      end
    end
    # Create a new Pokemon Shop
    # @param sym_new_shop [Symbol] the symbol to link to the new shop
    # @param list_id [Array<Integer>] the array containing the id of the Pokemon to sell
    # @param list_price [Array<Integer>] the array containing the prices of the Pokemon to sell
    # @param list_param [Array] the array containing the infos of the Pokemon to sell
    # @param list_quantity [Array<Integer>] the array containing the quantity of the Pokemon to sell
    # @param shop_rewrite [Boolean] if the system must completely overwrite an already existing shop
    def create_new_pokemon_shop(sym_new_shop, list_id, list_price, list_param, list_quantity = [], shop_rewrite: false)
      return refill_pokemon_shop(sym_new_shop, list_id, list_price, list_param, list_quantity) if @pokemon_shop_list.key?(sym_new_shop) && !shop_rewrite
      @pokemon_shop_list.delete(sym_new_shop) if @pokemon_shop_list.key?(sym_new_shop) && shop_rewrite
      @pokemon_shop_list[sym_new_shop] = []
      refill_pokemon_shop(sym_new_shop, list_id, list_price, list_param, list_quantity)
    end
    # Refill an already existing Pokemon Shop (create it if it does not exist)
    # @param symbol_of_shop [Symbol] the symbol of the shop
    # @param list_id [Array<Integer>] the array containing the id of the Pokemon to sell
    # @param list_price [Array<Integer>] the array containing the prices of the Pokemon to sell
    # @param list_param [Array] the array containing the infos of the Pokemon to sell
    # @param list_quantity [Array<Integer>] the array containing the quantity of the Pokemon to sell
    # @param pkm_rewrite [Boolean] if the system must completely overwrite the existing Pokemon
    def refill_pokemon_shop(symbol_of_shop, list_id, list_price = [], list_param = [], list_quantity = [], pkm_rewrite: false)
      if @pokemon_shop_list.key?(symbol_of_shop)
        list_id.each_with_index do |id, index|
          register_new_pokemon_in_shop(symbol_of_shop, id, list_price[index], list_param[index], list_quantity[index], rewrite: pkm_rewrite)
        end
        sort_pokemon_shop(symbol_of_shop)
      else
        create_new_pokemon_shop(symbol_of_shop, list_id, list_price, list_param, list_quantity)
      end
    end
    # Remove Pokemon from an already existing shop (return if do not exist)
    # @param symbol_of_shop [Symbol] the symbol of the existing shop
    # @param remove_list_mon [Array<Integer>] the array of the Pokemon id
    # @param param_form [Array<Hash>] the form of the Pokemon to delete (only if there is more than one form of a Pokemon in the list)
    # @param quantities_to_remove [Array<Integer>] the array of the quantity to remove
    def remove_from_pokemon_shop(symbol_of_shop, remove_list_mon, param_form = [], quantities_to_remove = [])
      return log_debug('You can\'t remove Pokemon from a non-existing shop') unless @pokemon_shop_list.key?(symbol_of_shop)
      pkm_list = @pokemon_shop_list[symbol_of_shop]
      remove_list_mon.each_with_index do |id, index|
        form = param_form[index].is_a?(Hash) ? param_form[index][:form].to_i : 0
        result = pkm_list.find_index { |hash| data_creature(hash[:id]).db_symbol == data_creature(id).db_symbol && hash[:form].to_i == form }
        next unless result
        pkm_list[result][:quantity] -= (quantities_to_remove[index].nil? ? Float::INFINITY : quantities_to_remove[index])
        pkm_list.delete_at(result) if pkm_list[result][:quantity] <= 0
      end
      @pokemon_shop_list[symbol_of_shop] = pkm_list
      sort_pokemon_shop(symbol_of_shop)
    end
    # Register the Pokemon into the Array under certain conditions
    # @param sym_shop [Symbol] the symbol of the shop
    # @param id [Integer] the ID of the Pokemon to register
    # @param price [Integer] the price of the Pokemon
    # @param param [Hash] the hash of the Pokemon (might be a single Integer)
    # @param quantity [Integer] the quantity of the Pokemon to register
    # @param rewrite [Boolean] if an existing Pokemon should be rewritten or not
    def register_new_pokemon_in_shop(sym_shop, id, price, param, quantity, rewrite: false)
      return unless price && param
      param = {level: param} if param.is_a?(Integer)
      index_condition = proc { |hash| data_creature(hash[:id]).db_symbol == data_creature(id).db_symbol && hash[:form].to_i == param[:form].to_i }
      if (result = @pokemon_shop_list[sym_shop].index(&index_condition)) && rewrite
        @pokemon_shop_list[sym_shop].delete_at(result)
      else
        if (result = @pokemon_shop_list[sym_shop].index(&index_condition))
          return @pokemon_shop_list[sym_shop][result][:quantity] += quantity || 1
        end
      end
      hash_pkm = param.dup
      hash_pkm[:id] = data_creature(id).db_symbol
      hash_pkm[:price] = price
      hash_pkm[:quantity] = quantity || 1
      @pokemon_shop_list[sym_shop] << hash_pkm
    end
    # Sort the Pokemon Shop list
    # @param symbol_of_shop [Symbol] the symbol of the shop to sort
    def sort_pokemon_shop(symbol_of_shop)
      @pokemon_shop_list[symbol_of_shop].sort_by! { |hash| [data_creature(hash[:id]).id, hash[:form].to_i] }
    end
  end
  class GameState
    # The list of the limited shops
    # @return [PFM::Shop]
    attr_accessor :shop
    on_player_initialize(:shop) {@shop = PFM.shop_class.new(self) }
    on_expand_global_variables(:shop) do
      @shop ||= PFM.shop_class.new(self)
      @shop.pokemon_shop_list ||= {}
      @shop.game_state = self
    end
  end
end
PFM.shop_class = PFM::Shop
module UI
  module Shop
    # Window displaying the money amount
    class MoneyWindow < SpriteStack
      # X coordinate of the money window
      COORD_X = 7
      # Y coordinate of the money window
      COORD_Y = 4
      # Black color
      BLACK_COLOR = Color.new(0, 0, 0)
      # White color
      WHITE_COLOR = Color.new(255, 255, 255)
      # Initializing the money window graphics and texts
      # @param viewport [Viewport] viewport in which the SpriteStack will be displayed
      def initialize(viewport)
        super(viewport, COORD_X, COORD_Y)
        @money_window = add_background('shop/money_window')
        @money_text = add_text(5, 7, 34, 11, parse_text(11, 6) + ' :')
        @money_text.fill_color = WHITE_COLOR
        @money_text.draw_shadow = false
        @money_quantity = add_text(52, 8, 66, 9, nil.to_s, 2)
        @money_quantity.fill_color = WHITE_COLOR
        @money_quantity.draw_shadow = false
        self.z = 4
      end
      # Update the money text
      # @param text [String] the new string to display
      def text=(text)
        @money_quantity.text = text
      end
    end
    # Banner sprite for the shop
    class ShopBanner < Sprite
      # Base name of the banner (without language modifier)
      FILENAME = 'shop/banner_'
      # Initialize the graphism for the shop banner
      # @param viewport [Viewport] viewport in which the Sprite will be displayed
      def initialize(viewport)
        super(viewport)
        set_bitmap(FILENAME, :interface)
        set_z(4)
      end
    end
    # List of items in the UI
    class ItemList < Array
      # Number of button in the list
      AMOUNT = 3
      # Offset between each button
      BUTTON_OFFSET = 38
      # Offset between active button & inative button
      ACTIVE_OFFSET = -14
      # Base X coordinate
      BASE_X = 128
      # Base Y coordinate
      BASE_Y = 30
      # @return [Integer] index of the current active item
      attr_reader :index
      # Create a new ButtonList
      # @param viewport [Viewport] viewport in which the SpriteStack will be displayed
      def initialize(viewport)
        super(AMOUNT) do |i|
          ListButton.new(viewport, i)
        end
        @item_list = []
        @name_list = []
        @price_list = []
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
        @index = index.clamp(0, @item_list.size - 1)
        update_button_texts
        update_button_price
        update_button_icon
      end
      # Move all the buttons up
      def move_up
        @animation = :move_up_animation
        @counter = 0
      end
      # Move all the buttons down
      def move_down
        @animation = :move_down_animation
        @counter = 0
      end
      # Set the item list
      # @param list [Array<Integer>]
      def item_list=(list)
        @item_list = list
        @name_list = @item_list.collect { |id| data_item(id).exact_name }
      end
      # Set the price list
      # @param list [Array<Integer>]
      def item_price=(list)
        @price_list = list
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
          update_button_price
          update_button_icon
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
          update_button_price
          update_button_icon
          first.text = button_name(start_index)
          @animation = nil
        end
      end
      # Update the buttons texts
      def update_button_texts
        index = start_index
        each do |button|
          button.text = button_name(index)
          index += 1
        end
      end
      # Update the buttons price
      def update_button_price
        index = start_index
        each do |button|
          button.price = button_price(index)
          index += 1
        end
      end
      # Update the buttons icon
      def update_button_icon
        index = start_index
        each do |button|
          button.icon_data = @item_list[index]
          index += 1
        end
      end
      # Get the button name
      # @param index [Integer]
      # @return [String, nil]
      def button_name(index)
        index < 0 ? nil : @name_list[index]
      end
      # Get the button name
      # @param index [Integer]
      # @return [String, nil]
      def button_price(index)
        index < 0 ? nil : @price_list[index]
      end
      # Return the start index of the list
      # @return [Integer]
      def start_index
        @index - 1
      end
      # Button for an item in the list
      class ListButton < SpriteStack
        # @return [Integer] Index of the button in the list
        attr_accessor :index
        # Create a new Item sell button
        # @param viewport [Viewport] the viewport in which the SpriteStack will be displayed
        # @param index [Integer]
        def initialize(viewport, index)
          @index = index
          super(viewport, BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
          add_background('shop/button_list').set_z(1)
          @item_name = add_text(37, 8, 92, 18, nil.to_s, 1, color: 10)
          @item_name.z = 2
          @item_price = add_text(133, 8, 37, 17, nil.to_s, 2, color: 0)
          @item_price.draw_shadow = false
          @item_price.z = 2
          @item_icon = add_sprite(3, 2, NO_INITIAL_IMAGE, type: ItemSprite)
          @item_icon.z = 3
        end
        # Is the button active
        def active?
          @index == 1
        end
        # Set the button text
        # @param text [String, nil] the item name
        def text=(text)
          return unless (self.visible = !text.nil?)
          @item_name.text = text
        end
        # Set the item price
        # @param price [Integer, nil] the item price
        def price=(price)
          return unless (self.visible = !price.nil?)
          @item_price.text = price.to_s
        end
        # Set the item icon
        # @param icon [Integer] the item id for the icon
        def icon_data=(icon)
          if self.visible == false
            @item_icon.set_bitmap(nil)
          else
            @item_icon.data = icon
          end
        end
        # Reset the button coordinate
        def reset
          set_position(BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
        end
      end
    end
    # Arrow of the shop UI
    class Arrow < UI::Bag::Arrow
      # Initialize the arrow Sprite for the UI
      # @param viewport [Viewport] the viewport in which the Sprite will be displayed
      def initialize(viewport)
        super
        set_position(*arrow_pos)
        set_bitmap(arrow_filename, :interface)
        self.z = 4
        @counter = 0
      end
      # Position of the arrow sprite
      def arrow_pos
        return 105, 79
      end
      # Name of the arrow sprite
      def arrow_filename
        'shop/arrow'
      end
    end
    # UI element showing the item description
    class ItemDesc < SpriteStack
      # Initialize the item description window graphisms and texts
      # @param viewport [Viewport] the viewport in which the SpriteStack will be displayed
      def initialize(viewport)
        super(viewport, 7, 144)
        create_sprites
        self.z = 4
      end
      # Update the text of the item's name
      # @param name [String] the string of the item's name
      def name=(name)
        @item_desc_name.text = name
      end
      # Update the description text for the item
      # @param text [String] the string of the item's description
      def text=(text)
        @item_desc_text.multiline_text = text
      end
      # Update the number of currently possessed same item
      # @param nb [Integer] the number of the currrently shown item in the player bag
      def nb_item=(nb)
        @nb_item_bag.text = nb.to_s
      end
      # Update the number of the item in stock
      # @param nb [Integer] the number of the currently shown item in stock
      def nb_in_stock=(nb)
        @item_in_stock.text = ext_text(9003, 0) + nb.to_s
      end
      private
      def create_sprites
        @item_desc_window = add_background('shop/item_desc_window')
        @item_desc_name = add_text(22, 8, 150, 9, nil.to_s)
        @item_desc_name.draw_shadow = false
        @item_desc_text = add_text(10, 22, 286, 16, nil.to_s)
        @item_desc_text.draw_shadow = false
        @item_in_stock = add_text(23, 73, 145, 13, nil.to_s, color: 10)
        @item_in_stock.draw_shadow = false
        @img_item_in_bag = add_sprite(256, 76, 'shop/img_item_in_bag')
        @nb_item_bag = add_text(276, 76, 23, 8, nil.to_s, color: 10)
        @nb_item_bag.draw_shadow = false
      end
    end
    # UI element showing the scrollbar of the shop
    class ScrollBar < SpriteStack
      # @return [Integer] current index of the scrollbar
      attr_reader :index
      # @return [Integer] number of possible indexes
      attr_reader :max_index
      # Number of pixel the scrollbar use to move the button
      HEIGHT = 90
      # Base Y for the scrollbar
      BASE_Y = 33
      # Create a new scrollbar
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 310, BASE_Y)
        add_background('shop/scroll').set_z(1)
        @button = add_sprite(-1, 0, 'shop/button_scroll').set_z(2)
        @index = 0
        @max_index = 1
      end
      # Set the current index of the scrollbar
      # @param value [Integer] the new index
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = (BASE_Y + 3) + HEIGHT * @index / @max_index
      end
      # Set the number of possible index
      # @param value [Integer] the new max index
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end
    end
    # List of Creatures for the shop UI
    class PkmList < Array
      # Number of button in the list
      AMOUNT = 4
      # Offset between each button
      BUTTON_OFFSET = 38
      # Offset between active button & inative button
      ACTIVE_OFFSET = -14
      # Base X coordinate
      BASE_X = 128
      # Base Y coordinate
      BASE_Y = 30
      # @return [Integer] index of the current active item
      attr_reader :index
      # Create a new ButtonList
      # @param viewport [Viewport] viewport in which the SpriteStack will be displayed
      def initialize(viewport)
        super(AMOUNT) do |i|
          ListButtonPkm.new(viewport, i)
        end
        @item_list = []
        @name_list = []
        @price_list = []
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
        @index = index.clamp(0, @item_list.size - 1)
        update_button_texts
        update_button_price
        update_button_icon
      end
      # Move all the buttons up
      def move_up
        @animation = :move_up_animation
        @counter = 0
      end
      # Move all the buttons down
      def move_down
        @animation = :move_down_animation
        @counter = 0
      end
      # Set the item list
      # @param list [Array<Integer>]
      def item_list=(list)
        @item_list = list
        @name_list = @item_list.collect { |hash| data_creature(hash[:id]).name }
      end
      # Set the price list
      # @param list [Array<Integer>]
      def item_price=(list)
        @price_list = list
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
          update_button_price
          update_button_icon
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
          update_button_price
          update_button_icon
          first.text = button_name(start_index)
          @animation = nil
        end
      end
      # Update the buttons texts
      def update_button_texts
        index = start_index
        each do |button|
          button.text = button_name(index)
          index += 1
        end
      end
      # Update the buttons price
      def update_button_price
        index = start_index
        each do |button|
          button.price = button_price(index)
          index += 1
        end
      end
      # Update the buttons icon
      def update_button_icon
        index = start_index
        each do |button|
          button.icon_data = @item_list[index]
          index += 1
        end
      end
      # Get the button name
      # @param index [Integer]
      # @return [String, nil]
      def button_name(index)
        index < 0 ? nil : @name_list[index]
      end
      # Get the button name
      # @param index [Integer]
      # @return [String, nil]
      def button_price(index)
        index < 0 ? nil : @price_list[index]
      end
      # Return the start index of the list
      # @return [Integer]
      def start_index
        @index - 1
      end
      # Button for a Creature in the list
      class ListButtonPkm < SpriteStack
        # @return [Integer] Index of the button in the list
        attr_accessor :index
        # Create a new Item sell button
        # @param viewport [Viewport] the viewport in which the SpriteStack will be displayed
        # @param index [Integer]
        def initialize(viewport, index)
          @index = index
          super(viewport, BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
          create_sprites
        end
        # Is the button active
        def active?
          @index == 1
        end
        # Set the button text
        # @param text [String, nil] the item name
        def text=(text)
          return unless (self.visible = !text.nil?)
          @item_name.text = text
        end
        # Set the price text of the button
        # @param text [String, nil] set nil to hide
        def price=(text)
          return unless (self.visible = !text.nil?)
          @item_price.text = text[:price].to_s
        end
        # Set the item icon
        # @param pkm_hash [Hash] the Pokemon hash for the icon
        def icon_data=(pkm_hash)
          if self.visible == false
            @item_icon.set_bitmap(nil)
          else
            @item_icon.data = (PFM::Pokemon.generate_from_hash(pkm_hash))
          end
        end
        # Reset the button coordinate
        def reset
          set_position(BASE_X + (active? ? ACTIVE_OFFSET : 0), BASE_Y + BUTTON_OFFSET * index)
        end
        private
        def create_sprites
          add_background('shop/button_list').set_z(1)
          @item_name = add_text(37, 8, 92, 18, nil.to_s, 1, color: 10)
          @item_name.z = 2
          @item_price = add_text(133, 8, 37, 17, nil.to_s, 2, color: 0)
          @item_price.draw_shadow = false
          @item_price.z = 2
          @item_icon = add_sprite(2, 0, false, NO_INITIAL_IMAGE, type: PokemonIconSprite)
          @item_icon.z = 3
        end
      end
    end
    # Description of a creature in the Shop UI
    class PkmDesc < SpriteStack
      # White color
      WHITE_COLOR = Color.new(255, 255, 255)
      # Initialize the item description window graphisms and texts
      # @param viewport [Viewport] the viewport in which the SpriteStack will be displayed
      def initialize(viewport)
        super(viewport, 7, 184)
        create_sprites
        self.z = 4
      end
      # Update the text of the item's name
      # @param name [String] the string of the item's name
      def name=(name)
        @item_desc_name.text = name
      end
      # Update the level text for the Pokemon
      # @param text [String] the string of the Pokemon's level
      def text=(text)
        @item_desc_text.text = parse_text(27, 29) + " #{text}"
      end
      # Update the species text for the Pokemon
      # @param species [String] the string of the Pokemon's species
      def species=(species)
        @item_desc_species.text = species
      end
      # Update the number of the Pokémon in stock
      # @param nb [Integer] the number of the currently shown item in stock
      def nb_in_stock=(nb)
        @item_in_stock.text = ext_text(9003, 0) + nb.to_s
      end
      private
      def create_sprites
        @item_desc_window = add_background('shop/pkm_desc_window')
        @item_desc_name = add_text(20, 9, 150, 9, nil.to_s)
        @item_desc_name.draw_shadow = false
        @item_desc_name.fill_color = WHITE_COLOR
        @item_desc_text = add_text(14, 26, 286, 16, nil.to_s)
        @item_desc_text.draw_shadow = false
        @item_desc_species = add_text(58, 26, 286, 16, nil.to_s)
        @item_desc_species.draw_shadow = false
        @item_in_stock = add_text(205, 27, 145, 13, nil.to_s, color: 10)
        @item_in_stock.draw_shadow = false
      end
    end
    # Scrollbar for the Creature shop
    class PkmScrollBar < SpriteStack
      # @return [Integer] current index of the scrollbar
      attr_reader :index
      # @return [Integer] number of possible indexes
      attr_reader :max_index
      # Number of pixel the scrollbar use to move the button
      HEIGHT = 128
      # Base Y for the scrollbar
      BASE_Y = 33
      # Create a new scrollbar
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 310, BASE_Y)
        add_background('shop/pkm_scroll').set_z(1)
        @button = add_sprite(-1, 0, 'shop/button_scroll').set_z(2)
        @index = 0
        @max_index = 1
      end
      # Set the current index of the scrollbar
      # @param value [Integer] the new index
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = (BASE_Y + 3) + HEIGHT * @index / @max_index
      end
      # Set the number of possible index
      # @param value [Integer] the new max index
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end
    end
  end
end
module GamePlay
  # Shop scene
  class Shop < BaseCleanUpdate::FrameBalanced
    # Create a new Item Shop
    # @overload initialize(symbol_shop)
    #   @param symbol_shop [Symbol] the symbol of the shop to open
    # @overload initialize(symbol_shop, price_overwritten)
    #   @param symbol_shop [Symbol] the symbol of the shop to open
    #   @param price_overwrite [Hash] the hash containing the new price (value) of an item id (key)
    # @overload initialize(list_id_object)
    #   @param list_id_object [Array<Symbol>] the array containing the id of the items to sell
    # @overload initialize(list_id_object, price_overwrite)
    #   @param list_id_object [Array<Symbol>] the array containing the id of the items to sell
    #   @param price_overwrite [Hash] the hash containing the new price (value) of an id (key)
    # @example Opening an already defined shop with limited items
    #   GamePlay::Shop.new(:shop_pewter_city) # Will open the Shop with symbol :shop_pewter_city (the shop must be already defined beforehand)
    # @example Opening an already defined shop with limited items but with temporarily overwritten price
    #   GamePlay::Shop.new(:shop_pewter_city, {17: 300, 25: 3000}) # Will open the Shop with symbol :shop_pewter_city while overwritting the price for items with ID 17 or 25
    # @example Opening a simple unlimited shop with items, using their original prices
    #   GamePlay::Shop.new([1, 2, 3, 4]) # Will open a Shop selling Master balls, Ultra Balls, Great Balls and Poké Balls at their original price
    # @example Opening a simple unlimited shop with items while overwritting temporarily the original price
    #   GamePlay::Shop.new([4, 17], {4: 100, 17: 125}) # Will open a Shop selling Poké Balls at 100 Pokédollars and Potions at 125 Pokédollars
    def initialize(symbol_or_list, price_overwrite = {}, show_background: true)
      super()
      return if symbol_or_list == false
      @force_close = nil
      @shop = PFM.game_state.shop
      @show_background = :show_background
      @symbol_or_list = symbol_or_list
      @price_overwrite = price_overwrite
      @what_was_buyed = []
      load_item_list
      unless @force_close == true
        @index = @index.clamp(0, @last_index)
        @running = true
      end
    end
    private
    # Launch the process that gets all lists
    def load_item_list
      @item_quantity = []
      get_list_item
      get_definitive_list_price
      check_if_shop_empty
      @index = 0
      @last_index = @list_item.size - 1
    end
    alias reload_item_list load_item_list
    # Create the initial list from symbol_or_list
    def get_list_item
      if @symbol_or_list.is_a? Symbol
        if @shop.shop_list.key?(@symbol_or_list)
          @list_item = @shop.shop_list[@symbol_or_list].keys
          @item_quantity = []
          @list_item.each { |id| @item_quantity << @shop.shop_list[@symbol_or_list][id] }
        else
          raise 'Shop with symbol :' + @symbol_or_list.to_s + ' must be created before calling it'
          @running = false
        end
      else
        if @symbol_or_list.is_a? Array
          @list_item = @symbol_or_list
          check_if_shop_empty
        end
      end
      @index = 0
      @last_index = @list_item.size - 1
    end
    # Get the definitive lists by checking the @price_overwrite variable
    def get_definitive_list_price
      arr = []
      temp_list_item = []
      temp_item_quantity = []
      price = 0
      @list_item.each_with_index do |item, index|
        price = @price_overwrite.key?(item) ? @price_overwrite[item] : data_item(item).price
        next if price <= 0
        next if !data_item(item).is_limited && $bag.contain_item?(item)
        arr << price
        temp_list_item << @list_item[index]
        temp_item_quantity << @item_quantity[index] unless @item_quantity.empty?
      end
      @list_item = temp_list_item
      @item_quantity = temp_item_quantity unless @item_quantity.empty?
      @list_price = arr
    end
    # Method that checks if the shop is empty, closing it if that's the case
    def check_if_shop_empty
      if @list_item.empty?
        $game_variables[::Yuki::Var::TMP1] = (@what_was_buyed.empty? ? -1 : 3)
        @force_close = true
        update_mouse(false)
      end
    end
    public
    include UI::Shop
    # Create the different graphics for the UI
    def create_graphics
      super()
      unless @force_close
        create_base_ui if @show_background
        create_money_window
        create_shop_banner
        create_item_list
        create_arrow
        create_item_desc_window
        create_scrollbar
        Graphics.sort_z
      end
    end
    # Update the graphics every frame
    def update_graphics
      unless @force_close
        @base_ui.update_background_animation if @show_background
        @animation&.call
        update_arrow
      end
    end
    # Create the generic background for the UI
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, hide_background_and_button: true)
    end
    # Create the money window showing the player money
    def create_money_window
      @gold_window = MoneyWindow.new(@viewport)
      update_money_text
    end
    # Update the money the player has
    def update_money_text
      @gold_window.text = parse_text(11, 9, NUM7R => PFM.game_state.money.to_s)
    end
    # Create the banner spelling "shop" in different languages
    def create_shop_banner
      @banner = ShopBanner.new(@viewport)
    end
    # Create the item list for the items to sell
    def create_item_list
      @item_list = ItemList.new(@viewport)
      update_item_button_list
    end
    # Update the item list
    def update_item_button_list
      @item_list.item_list = @list_item
      @item_list.item_price = @list_price
      @item_list.index = @index
    end
    # Create the selection arrow
    def create_arrow
      @arrow = Arrow.new(@viewport)
    end
    # Update the selection arrow animation
    def update_arrow
      @arrow.update
    end
    # Create the item description window
    def create_item_desc_window
      @item_desc_window = ItemDesc.new(@viewport)
      update_item_desc
    end
    # Method that calls all the informations updating method of the description window
    def update_item_desc
      update_item_desc_name(data_item(@list_item[@index]).name)
      update_item_desc_text(data_item(@list_item[@index]).description)
      update_nb_item($bag.item_quantity(@list_item[@index]))
      update_in_stock_item(@item_quantity[@index]) if @item_quantity != []
    end
    # Update the name of the item currently shown
    def update_item_desc_name(name)
      @item_desc_window.name = name
    end
    # Update the description of the item currently shown
    def update_item_desc_text(text)
      @item_desc_window.text = text
    end
    # Update the number of the actual item possessed by the player
    def update_nb_item(nb)
      @item_desc_window.nb_item = nb
    end
    # Update the number of the actual item currently in stock
    def update_in_stock_item(nb)
      @item_desc_window.nb_in_stock = nb
    end
    # Create the scrollbar
    def create_scrollbar
      @scroll_bar = ScrollBar.new(@viewport)
      update_scrollbar
    end
    # Update the scrollbar's max index information
    def update_scrollbar
      @scroll_bar.max_index = @last_index
    end
    public
    # Update the inputs every frame
    def update_inputs
      unless @force_close
        return false if @animation
        return update_ctrl_button && update_list_input
      end
    end
    private
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
        update_item_desc
        @scroll_bar.index = @index
      end
      return false
    end
    # Update CTRL button (A/B)
    def update_ctrl_button
      if Input.trigger?(:B)
        action_b
      else
        if Input.trigger?(:A)
          action_a
        else
          return true
        end
      end
      return false
    end
    # Action related to B button
    def action_b
      play_cancel_se
      $game_variables[::Yuki::Var::TMP1] = how_do_the_player_leave
      @running = false
    end
    # Action related to A button
    def action_a
      if PFM.game_state.money >= @list_price[@index]
        launch_buy_sequence
      else
        display_message(parse_text(11, 24))
      end
    end
    public
    private
    # Start the move up/down animation
    # @param delta [Integer] number of time to move up/down
    def animate_list_index_change(delta)
      count = delta.abs
      max = delta.abs
      @animation = proc do
        @item_list.update
        next unless @item_list.done?
        next(@animation = nil) if count <= 0
        @index += delta / max if max > 1
        delta > 0 ? @item_list.move_up : @item_list.move_down
        @scroll_bar.index = @index
        update_item_desc
        count -= 1
      end
    end
    public
    private
    # Name of the SE to play when an item is bought
    BUY_SE = 'Audio/SE/purchase_sound'
    # Launch the buy sequence
    def launch_buy_sequence
      if data_item(@list_item[@index]).is_limited == false
        buy_unlimited_use_item
      else
        buy_limited_use_item
      end
    end
    # Method describing the process of buying an unlimited use item
    def buy_unlimited_use_item
      price = @list_price[@index].to_s
      item = data_item(@list_item[@index])
      if item.socket == 3 && item.is_a?(Studio::TechItem)
        id_text = 35
        move_name = data_move(Studio::TechItem.from(item).move_db_symbol).name
        ct_num = item.name.gsub(/[^0-9]/, '')
        hash = {NUM3[0] => ct_num, MOVE[1] => move_name, NUM7R => price}
      else
        id_text = 94
        item_name = item.exact_name
        hash = {ITEM2[0] => item_name, NUM7R => price}
      end
      c = display_message(parse_text(11, id_text, hash), 1, text_get(11, 27), text_get(11, 28))
      money_checkout(1) if c == 0
    end
    # Method describing the process of buying an amount of limited use items
    def buy_limited_use_item
      return if amount_selection(@list_price[@index], @list_item[@index])
      return if $game_variables[::Yuki::Var::EnteredNumber] == 0
      quantity = $game_variables[::Yuki::Var::EnteredNumber]
      return if confirm_buy(@list_price[@index], @list_item[@index], quantity)
      money_checkout(quantity)
    end
    # Ask the player if he wants to buy the item
    # @param price [Integer] price of the item
    # @param item_id [Integer] ID of the item
    # @param quantity [Integer] number of item to buy
    # @return [Boolean] if the buy_item procedure should immediately exit
    def confirm_buy(price, item_id, quantity)
      if quantity > 0
        item_str = quantity > 1 ? ext_text(9001, data_item(item_id).id) : data_item(item_id).exact_name
        message = parse_text(11, 25, ITEM2[0] => item_str, NUM2[1] => quantity.to_s, NUM7R => (quantity * price).to_s)
        c = display_message(message, 1, text_get(11, 27), text_get(11, 28))
        return c != 0
      end
      return true
    end
    # Make the player choose the amount of the item he wants to buy
    # @param price [Integer] price of the item
    # @param item_id [Integer] ID of the item
    # @return [Boolean] if the buy_item procedure should immediately exit
    def amount_selection(price, item_id)
      max_amount = PFM.game_state.money / price
      if (max = Configs.settings.max_bag_item_count) > 0
        max -= $bag.item_quantity(item_id)
        if max <= 0
          display_message(parse_text(11, 31))
          return true
        end
        max_amount = max if max < max_amount
      end
      max_amount = @item_quantity[@index] if @symbol_or_list.is_a?(Symbol) && @item_quantity[@index] < max_amount
      $game_temp.num_input_variable_id = ::Yuki::Var::EnteredNumber
      $game_temp.num_input_digits_max = max_amount.to_s.size
      $game_temp.num_input_start = max_amount
      $game_temp.shop_calling = price
      display_message(parse_text(11, 23, ITEMPLUR1[0] => determine_article, ITEM2[0] => ext_text(9001, data_item(item_id).id)))
      $game_temp.shop_calling = false
      return false
    end
    VOWELS = ['A', 'E', 'I', 'O', 'U', 'Y']
    def determine_article
      case $options.language
      when 'fr'
        name = data_item(@list_item[@index]).name
        return name.start_with?(*VOWELS) ? 'd\'' : 'de '
      else
        return ''
      end
    end
    # Take the good amount of money from the player and some other things
    # @param nb [Integer] the number of items that the player is buying
    def money_checkout(nb)
      display_message(parse_text(11, 29))
      PFM.game_state.lose_money(nb * @list_price[@index])
      update_money_text
      Audio.se_play(BUY_SE)
      $bag.add_item(@list_item[@index], nb)
      @what_was_buyed << @list_item[@index] unless @what_was_buyed.any? { |item| item == @list_item[@index] }
      buy_item_special_offer(nb)
      @shop.remove_from_limited_shop(@symbol_or_list, [@list_item[@index]], [nb]) if @symbol_or_list.is_a?(Symbol)
      update_shop_ui_after_buying(@index)
    end
    # Execute the special offer of the shop when the player bough an item
    # @param quantity [Integer] Number of item bought
    def buy_item_special_offer(quantity)
      if (1..16).include?(@list_item[@index]) && quantity >= 10
        display_message(text_get(11, 32))
        $bag.add_item(12, (quantity / 10))
      end
    end
    # Make sure the Shop UI gets updated after buying something
    # @param index [Integer] previous index value
    def update_shop_ui_after_buying(index)
      reload_item_list
      unless @force_close
        @index = index.clamp(0, @last_index)
        @item_list.index = @index
        update_item_button_list
        update_scrollbar
        update_item_desc
        update_money_text
      end
    end
    # Check the scenario in which the player leaves
    # @return [Integer] the number of the scenario for the player leaving
    def how_do_the_player_leave
      return @what_was_buyed.size.clamp(0, 2)
    end
    public
    # Tell if the mouse over is enabled
    MOUSE_OVER_ENABLED = false
    # Update the mouse interactions
    # @param moved [Boolean] if the mouse moved durring the frame
    # @return [Boolean] if the thing after can update
    def update_mouse(moved)
      if @force_close
        @running = false
      else
        return update_mouse_index if Mouse.wheel != 0
        return false if moved && update_mouse_list
      end
    end
    private
    # Part where we try to update the list index
    def update_mouse_list
      return false unless MOUSE_OVER_ENABLED
      delta = @item_list.mouse_delta_index
      return true if delta == 0 || @last_mouse_delta == delta
      update_mouse_delta_index(delta)
      return false
    ensure
      @last_mouse_delta = delta
    end
    # Part where we try to update the list index if the mouse wheel change
    def update_mouse_index
      delta = -Mouse.wheel
      update_mouse_delta_index(delta) unless @list_item.size == 1
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
        @scroll_bar.index = @index
      end
    end
  end
  # Creature shop scene
  class Pokemon_Shop < Shop
    # Create a new Pokemon Shop
    # @overload initialize(symbol_shop)
    #   @param symbol_shop [Symbol] the symbol of the pokemon shop to open
    # @overload initialize(symbol_shop, prices)
    #   @param symbol_shop [Symbol] the symbol of the pokemon shop to open
    #   @param prices [Hash] the hash containing the new price (value) of a pokemon id (key)
    # @overload initialize(list_id_pokemon, prices, parameters)
    #   @param list_id_pkm [Array] the array containing the id of the pokemon to sell
    #   @param prices [Array] the array containing the price of each pokemon
    # @example Opening an already defined shop with limited Pokemon
    #   GamePlay::Pokemon_Shop.new(:pkm_shop_celadon) # Will open the Shop with symbol :pkm_shop_celadon (the shop must be already defined beforehand)
    # @example Opening an already defined shop with limited pokemon but with temporarily overwritten price
    #   GamePlay::Pokemon_Shop.new(:pkm_shop_celadon, {17: 300, 25: 3000}) # Will open the Shop with symbol :pkm_shop_celadon while overwritting the price for pokemon with ID 17 or 25
    # @example Opening a simple pokemon shop
    #   GamePlay::Pokemon_Shop.new([25, 52], [2500, 500], [50, { level: 15, form: 1 }]) # Will open a Shop selling Pikachu lvl 50 at 2500 P$ and Alolan Meowth lvl 15 at 500 P$
    def initialize(symbol_or_list, prices = {}, parameters = [], show_background: true)
      super(false)
      @force_close = nil
      @shop = PFM.game_state.shop
      @show_background = :show_background
      @symbol_or_list = symbol_or_list
      @prices = prices
      @parameters = parameters
      @what_was_buyed = []
      load_item_list
      unless @force_close == true
        @index = @index.clamp(0, @last_index)
        @running = true
      end
    end
    private
    # Launch the process that gets all lists
    def load_item_list
      @list_item = Array.new
      get_list_item
      get_definitive_list_price
      check_if_shop_empty
      @index = 0
      @last_index = @list_item.size - 1
    end
    alias reload_item_list load_item_list
    # Create the initial list from symbol_or_list
    def get_list_item
      if @symbol_or_list.is_a? Symbol
        if @shop.pokemon_shop_list.key?(@symbol_or_list)
          @list_item = @shop.pokemon_shop_list[@symbol_or_list]
        else
          raise 'Pokemon Shop with symbol :' + @symbol_or_list.to_s + ' must be created before calling it'
          @running = false
        end
      else
        if @symbol_or_list.is_a? Array
          @symbol_or_list.each_with_index do |id, index|
            @list_item[index] = Hash.new
            @list_item[index][:id] = id
            @parameters[index].class == Hash ? @list_item[index].merge!(@parameters[index]) : @list_item[index][:level] = @parameters[index]
            @list_item[index][:price] = @prices[index].to_i != 0 ? @prices[index] : 0
          end
        end
      end
      check_if_shop_empty
      @index = 0
      @last_index = @list_item.size - 1
    end
    # Get the definitive lists by checking the @price_overwrite variable
    def get_definitive_list_price
      temp_list_item = []
      price = 0
      @list_item.each_with_index do |hash, index|
        if @symbol_or_list.class == Symbol
          price = @prices.key?(hash[:id]) ? @prices[hash[:id]] : @list_item[index][:price]
        else
          price = @list_item[index][:price]
        end
        next if price <= 0
        @list_item[index][:price] = price
        temp_list_item << @list_item[index]
      end
      @list_item = temp_list_item
    end
    # Method that checks if the shop is empty, closing it if that's the case
    def check_if_shop_empty
      if @list_item.empty?
        $game_variables[::Yuki::Var::TMP1] = (@what_was_buyed.empty? ? -1 : 3)
        @force_close = true
        update_mouse(false)
      end
    end
    public
    include UI::Shop
    # Update the graphics every frame
    def update_graphics
      unless @force_close
        @base_ui.update_background_animation if @show_background
        @animation&.call
        update_arrow
      end
    end
    # Create the item list for the items to sell
    def create_item_list
      @item_list = PkmList.new(@viewport)
      update_item_button_list
    end
    # Update the item list
    def update_item_button_list
      @item_list.item_list = @item_list.item_price = @list_item
      @item_list.index = @index
    end
    # Create the item description window
    def create_item_desc_window
      @item_desc_window = PkmDesc.new(@viewport)
      update_item_desc
    end
    # Method that calls all the informations updating method of the description window
    def update_item_desc
      update_item_desc_name(data_creature(@list_item[@index][:id]).name)
      update_item_desc_text(@list_item[@index][:level])
      update_pkm_specie_text(data_creature(@list_item[@index][:id]).species)
      update_in_stock_item(@list_item[@index][:quantity]) if @symbol_or_list.class == Symbol
    end
    # Update the name of the item currently shown
    def update_item_desc_name(name)
      @item_desc_window.name = name
    end
    # Update the description of the item currently shown
    def update_item_desc_text(text)
      @item_desc_window.text = text
    end
    # Update the specie text of the currently shown creature
    def update_pkm_specie_text(species)
      @item_desc_window.species = species
    end
    # Update the number of the actual item currently in stock
    def update_in_stock_item(nb)
      @item_desc_window.nb_in_stock = nb
    end
    # Create the scrollbar
    def create_scrollbar
      @scroll_bar = PkmScrollBar.new(@viewport)
      update_scrollbar
    end
    public
    private
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
        update_item_desc
        @scroll_bar.index = @index
      end
      return false
    end
    # Action related to A button
    def action_a
      if PFM.game_state.money >= @list_item[@index][:price]
        buy_pokemon
      else
        display_message(parse_text(11, 24))
      end
    end
    public
    private
    # Method describing the process of buying an unlimited use item
    def buy_pokemon
      price = @list_item[@index][:price].to_s
      id_text = 94
      pkm_name = data_creature(@list_item[@index][:id]).name
      hash = {ITEM2[0] => pkm_name, NUM7R => price}
      c = display_message(parse_text(11, id_text, hash), 1, text_get(11, 27), text_get(11, 28))
      money_checkout(1) if c == 0
    end
    # Take the good amount of money from the player and some other things
    # @param nb [Integer] the number of items that the player is buying
    def money_checkout(nb)
      display_message(parse_text(11, 29))
      PFM.game_state.lose_money(nb * @list_item[@index][:price])
      pokemon = PFM::Pokemon.generate_from_hash(@list_item[@index])
      PFM.game_state.add_pokemon(pokemon)
      @what_was_buyed << @list_item[@index][:id] unless @what_was_buyed.include?(@list_item[@index][:id])
      @shop.remove_from_pokemon_shop(@symbol_or_list, [@list_item[@index][:id]], [@list_item[@index]], [1]) if @symbol_or_list.is_a?(Symbol)
      update_shop_ui_after_buying(@index)
    end
    # Make sure the Shop UI gets updated after buying something
    # @param index [Integer] previous index value
    def update_shop_ui_after_buying(index)
      reload_item_list
      unless @force_close
        @index = index.clamp(0, @last_index)
        @item_list.index = @index
        update_item_button_list
        update_scrollbar
        update_item_desc
        update_money_text
      end
    end
    # Check the scenario in which the player leaves
    # @return [Integer] the number of the scenario for the player leaving
    def how_do_the_player_leave
      return 0 if @what_was_buyed.empty?
      return 1 if @what_was_buyed.size == 1
      if @what_was_buyed.size >= 2 && @what_was_buyed[0] != @what_was_buyed[1]
        return 2
      else
        return 1
      end
    end
    public
    # Tell if the mouse over is enabled
    MOUSE_OVER_ENABLED = false
    private
    # Part where we try to update the list index if the mouse wheel change
    def update_mouse_index
      delta = -Mouse.wheel
      update_mouse_delta_index(delta) unless @list_item.size == 1
      Mouse.wheel = 0
      return false
    end
  end
end
GamePlay.shop_class = GamePlay::Shop
GamePlay.pokemon_shop_class = GamePlay::Pokemon_Shop
