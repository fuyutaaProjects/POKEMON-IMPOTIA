module PFM
  # Player PC storage
  #
  # The main object is stored in $storage and PFM.game_state.storage
  # @author Nuri Yuri
  class Storage
    # Maximum amount of box
    MAX_BOXES = 15
    # Maximum amount of battle box
    MAX_BATTLE_BOX = 16
    # Size of a box
    BOX_SIZE = 30
    # Number of box theme (background : Graphics/PC/f_id, title : Graphics/PC/title_id
    NB_THEMES = 32
    # Tell if the Pokemon gets healed & cured when stored
    HEAL_AND_CURE_POKEMON = true
    # The party of the other actor (friend)
    # @return [Array<PFM::Pokemon>]
    attr_accessor :other_party
    # The id of the current box
    # @return [Integer]
    attr_accessor :current_box
    # The id of the current battle box
    # @return [Integer]
    attr_accessor :current_battle_box
    # The Let's Go Follower
    # @return [PFM::Pokemon]
    attr_accessor :lets_go_follower
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Get the battle boxes
    # @return [Array<BattleBox>]
    attr_accessor :battle_boxes
    # Create a new storage
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state)
      self.game_state = game_state
      @boxes = Array.new(MAX_BOXES) { |index| Box.new(BOX_SIZE, send(*box_name_init(index)), index + 1) }
      @battle_boxes = Array.new(MAX_BATTLE_BOX) { |index| BattleBox.new("\##{index + 1}") }
      @current_box = 0
      @current_battle_box = 0
      update_event_variables
      @other_party = []
    end
    # Auto convert the data to the new format
    def auto_convert
      if @names
        @boxes.map!.with_index { |box, index| Box.new(0, @names[index], @themes[index], box) }
        remove_instance_variable(:@names)
        remove_instance_variable(:@themes)
      end
      @battle_boxes ||= Array.new(MAX_BATTLE_BOX) { |index| BattleBox.new("\##{index + 1}") }
      @current_battle_box ||= 0
    end
    # Store a pokemon to the PC
    # @param pokemon [PFM::Pokemon] the Pokemon to store
    # @return [Boolean] if the Pokemon has been stored
    def store(pokemon)
      unless store_in_current_box(pokemon)
        switch_to_box_with_space
        store_in_current_box(pokemon)
      end
      return true
    end
    # Get the current box object
    # @note Any modification will be ignored
    # @return [PFM::Storage::Box]
    def current_box_object
      return @boxes[current_box % @boxes.size].clone
    end
    # Retrieve a box content
    # @param index [Integer] the index of the box
    # @return [Array<PFM::Pokemon, nil>]
    def get_box_content(index)
      return @boxes[index % @boxes.size].content
    end
    alias get_box get_box_content
    # Return a box name
    # @param index [Integer] the index of the box
    # @return [String]
    def get_box_name(index)
      return @boxes[index % @boxes.size].name
    end
    # Change the name of a box
    # @param index [Integer] the index of the box
    # @param name [String] the new name
    def set_box_name(index, name)
      @boxes[index % @boxes.size].name = name.to_s
    end
    # Get the name of a box (initialize)
    # @param index [Integer] the index of the box
    def box_name_init(index)
      return [:text_get, 16, index]
    end
    # Get a box theme
    # @param index [Integer] the index of the box
    # @return [Integer] the id of the box theme
    def get_box_theme(index)
      return @boxes[index % @boxes.size].theme
    end
    # Change the theme of a box
    # @param index [Integer] the index of the box
    # @param theme [Integer] the id of the box theme
    def set_box_theme(index, theme)
      @boxes[index % @boxes.size].theme = theme.to_i
    end
    # Remove a Pokemon in the current box and return what whas removed at the index
    # @param index [Integer] index of the Pokemon in the current box
    # @return [PFM::Pokemon, nil] the pokemon removed
    def remove_pokemon_at(index)
      pokemon = @boxes[@current_box].content[index]
      @boxes[@current_box].content[index] = nil
      return pokemon
    end
    alias remove remove_pokemon_at
    # Is the slot "index" containing a Pokemon ?
    # @param index [Integer] index of the entity in the current box
    # @return [Boolean]
    def slot_contain_pokemon?(index)
      return @boxes[@current_box].content[index].class == ::PFM::Pokemon
    end
    # Return the Pokemon at an index in the current box
    # @param index [Integer] index of the Pokemon in the current box
    # @return [PFM::Pokemon, nil]
    def info(index)
      return @boxes[@current_box].content[index]
    end
    # Store a Pokemon at a specific index in the current box
    # @param pokemon [PFM::Pokemon] the Pokemon to store
    # @param index [Integer] index of the Pokemon in the current box
    # @note The pokemon is healed when stored
    def store_pokemon_at(pokemon, index)
      @boxes[@current_box].content[index] = pokemon
      return unless HEAL_AND_CURE_POKEMON
      pokemon.cure
      pokemon.hp = pokemon.max_hp
    end
    # Return the amount of box in the storage
    # @return [Integer]
    def box_count
      return @boxes.size
    end
    alias max_box box_count
    # Check if there's a Pokemon alive in the box (egg or not)
    # @return [Boolean]
    def any_pokemon_alive?
      return @boxes.any? do |box|
        next(box.content.any? { |pokemon| pokemon && !pokemon.dead? })
      end || @battle_boxes.any? do |box|
        next(box.content.any? { |pokemon| pokemon && !pokemon.dead? })
      end
    end
    alias any_pokemon_alive any_pokemon_alive?
    # Count the number of Pokemon available in the box
    # @param include_dead [Boolean] if the counter include the "dead" Pokemon
    # @return [Integer]
    def count_pokemon(include_dead = true)
      return @boxes.sum do |box|
        box.content.count { |pokemon| pokemon && (include_dead || !pokemon.dead?) }
      end
    end
    # Yield a block on each Pokemon of storage
    # @yieldparam pokemon [PFM::Pokemon]
    def each_pokemon
      @boxes.each do |box|
        box.content.each do |pokemon|
          yield(pokemon) if pokemon
        end
      end
    end
    # Yield a block on each Pokemon of storage and check if any answers to the block
    # @yieldparam pokemon [PFM::Pokemon]
    # @return [Boolean]
    def any_pokemon?
      @boxes.any? do |box|
        box.content.any? do |pokemon|
          yield(pokemon) if pokemon
        end
      end
    end
    # Delete a box
    # @param index [Integer] index of the box to delete
    def delete_box(index)
      @boxes.delete_at(index)
    end
    # Add a new box
    # @param name [String] name of the new box
    def add_box(name)
      @boxes.push(Box.new(BOX_SIZE, name, 1))
    end
    private
    # Store a pokemon in the current box
    # @param pokemon [PFM::Pokemon] the Pokemon to store
    # @return [Boolean] if the Pokemon has been stored
    def store_in_current_box(pokemon)
      position = @boxes[@current_box]&.content&.index(nil)
      return false if @boxes[@current_box].nil? || position.nil?
      store_pokemon_at(pokemon, position)
      return true
    end
    # Find a box with space and change @current_box if found
    # @return [Boolean] if a box with space could be found
    def switch_to_box_with_space
      box_index = @boxes.find_index { |box| box.content.include?(nil) }
      if box_index.nil?
        add_box(text_get(16, 1).sub('2', (@boxes.size + 1).to_s))
        box_index = @boxes.size - 1
      end
      @current_box = box_index
      update_event_variables
      return true
    end
    def update_event_variables
      game_state.game_variables[gv_current_box] = @current_box
      game_state&.game_map&.need_refresh = true
    end
    # Get the ID of the current box variable
    # @return [Integer]
    def gv_current_box
      return Yuki::Var::Boxes_Current
    end
    class << self
      # Get the box size
      # @return [Integer]
      def box_size
        BOX_SIZE
      end
    end
    public
    # Class responsive of storing various thing and holding some information about the storage
    class Box
      # Name of the storage
      # @return [String]
      attr_accessor :name
      # Theme of the storage
      # @return [Integer]
      attr_accessor :theme
      # Content of the storage
      # @return [Array<PFM::Pokemon>]
      attr_reader :content
      # Create a new box
      # @param box_size [Integer] size of the box
      # @param name [String] name of the box
      # @param theme [Integer] theme of the box
      # @param content_overload [Array] content to force in this object
      def initialize(box_size, name, theme, content_overload = nil)
        @content = content_overload || Array.new(box_size)
        @name = name
        @theme = theme
      end
    end
    public
    # Class Responsive of holding a team that can be used for battles
    class BattleBox
      # Name of the storage
      # @return [String]
      attr_accessor :name
      # Content of the storage
      # @return [Array<PFM::Pokemon>]
      attr_reader :content
      # Create a new battle box
      # @param name [String] name of the box
      # @param content_overload [Array] content to force in this object
      def initialize(name, content_overload = nil)
        @content = content_overload || Array.new(6)
        @name = name
      end
    end
  end
  class GameState
    # The PC storage of the player
    # @return [PFM::Storage]
    attr_accessor :storage
    on_player_initialize(:storage) {@storage = PFM.storage_class.new(self) }
    on_expand_global_variables(:storage) do
      $storage = @storage
      @storage.game_state = self
      @storage.auto_convert
    end
  end
end
PFM.storage_class = PFM::Storage
module UI
  # Module containg all the storage UI
  module Storage
    # Sprite showing the current box mode
    class ModeSprite < SpriteSheet
      # Get the mode
      # @return [Symbol]
      attr_reader :mode
      # List of sheet index for all modes
      SHEET_INDEXES = {pokemon: 3, item: 4, battle: 6, box: 5}
      # Constant telling how much section there's in the sprite
      SHEET_SIZE = [1, 7]
      # Create a new ModeSprite
      # @param viewport [Viewport] viewport used to display the sprite
      # @param mode_handler [ModeHandler] class responsive of handling the mode
      def initialize(viewport, mode_handler)
        super(viewport, *SHEET_SIZE)
        load_texture
        mode_handler.add_mode_ui(self)
        position_sprite
      end
      # Set the mode
      # @param mode [Symbol]
      def mode=(mode)
        @mode = mode
        index = SHEET_INDEXES[mode]
        if index.is_a?(Integer)
          self.sy = index
        else
          select(*index)
        end
      end
      private
      # Set the right sprite position
      def position_sprite
        set_position(84, 5)
        self.z = 31
      end
      # Load the texture
      def load_texture
        set_bitmap('pc/modes', :interface)
      end
    end
    # Sprite showing the current selection mode
    class SelectionModeSprite < SpriteSheet
      # Get the current mode
      # @return [Symbol] :detailed, :fast, :grouped
      attr_reader :selection_mode
      # List of sheet index for all modes
      SHEET_INDEXES = {detailed: 0, fast: 1, grouped: 2}
      # Constant telling how much section there's in the sprite
      SHEET_SIZE = [1, 7]
      # Create a new SelectionModeSprite
      # @param viewport [Viewport] viewport used to display the sprite
      # @param mode_handler [ModeHandler] class responsive of handling the mode
      def initialize(viewport, mode_handler)
        super(viewport, *SHEET_SIZE)
        load_texture
        mode_handler.add_selection_mode_ui(self)
        position_sprite
      end
      # Set the selection_mode
      # @param selection_mode [Symbol]
      def selection_mode=(selection_mode)
        @selection_mode = selection_mode
        index = SHEET_INDEXES[selection_mode]
        if index.is_a?(Integer)
          self.sy = index
        else
          select(*index)
        end
      end
      private
      # Set the right sprite position
      def position_sprite
        set_position(25, 5)
        self.z = 31
      end
      # Load the texture
      def load_texture
        set_bitmap('pc/modes', :interface)
      end
    end
    # Sprite showing the current selection mode
    class WinMode < SpriteSheet
      # Get the current mode
      # @return [Symbol] :pokemon, :item, :battle, :box
      attr_reader :mode
      # List of sheet index for all modes
      SHEET_INDEXES = {pokemon: 0, item: 1, battle: 2, box: nil}
      # Constant telling how much section there's in the sprite
      SHEET_SIZE = [1, 3]
      # Create a new ModeSprite
      # @param viewport [Viewport] viewport used to display the sprite
      # @param mode_handler [ModeHandler] class responsive of handling the mode
      def initialize(viewport, mode_handler)
        super(viewport, *SHEET_SIZE)
        load_texture
        mode_handler.add_mode_ui(self)
        position_sprite
      end
      # Set the mode
      # @param mode [Symbol]
      def mode=(mode)
        @mode = mode
        index = SHEET_INDEXES[mode]
        self.visible = !index.nil?
        if index.is_a?(Integer)
          self.sy = index
        else
          if index.is_a?(Array)
            select(*index)
          end
        end
      end
      private
      # Set the right sprite position
      def position_sprite
        self.z = 30
      end
      # Load the texture
      def load_texture
        set_bitmap('pc/win_modes', :interface)
      end
    end
    # Background of the box
    class BoxBackground < ShaderedSprite
      # Get current box data
      # @return [PFM::Storage::Box]
      attr_reader :data
      # Set current box data
      # @param box [PFM::Storage::Box]
      def data=(box)
        set_bitmap(format('pc/f_%<theme>d', theme: box.theme), :interface)
      end
    end
    # Background for the name of the box
    class BoxNameBackground < ShaderedSprite
      # Get current box data
      # @return [PFM::Storage::Box]
      attr_reader :data
      # Set current box data
      # @param box [PFM::Storage::Box]
      def data=(box)
        set_bitmap(format('pc/t_%<theme>d', theme: box.theme), :interface)
      end
    end
    # Class responsive of showing a rapid search
    class RapidSearch < UI::SpriteStack
      # Create a new rapid search
      # @param viewport [Viewport]
      def initialize(viewport)
        super
        create_stack
      end
      # Update the user input
      def update
        return unless visible
        @user_input.update
      end
      # Get the text of the user input
      # @return [String]
      def text
        @user_input.text
      end
      # Reset the search
      def reset
        @user_input.text = ''
      end
      private
      def create_stack
        create_background
        create_user_input
      end
      def create_background
        add_sprite(0, 217, 'pc/win_txt').set_z(20)
      end
      def create_user_input
        @user_input = add_text(0, 217, 0, 23, '', type: UI::UserInput, color: 9)
        @user_input.init(20)
      end
    end
    # Class responsive of showing a Detailed search
    class DetailedSearch < UI::SpriteStack
      # Name of the button image
      BUTTON_IMAGE = 'button_list_ext'
      # Create a new DetailedSearch
      # @param viewport [Viewport]
      def initialize(viewport)
        super
        create_stack
      end
    end
    # Class responsive of showing the cursor
    class Cursor < ShaderedSprite
      # Get the index
      # @return [Integer]
      attr_reader :index
      # Get the inbox property /!\ Always update this before index
      # @return [Boolean]
      attr_reader :inbox
      # Get the select box mode
      # @return [Boolean]
      attr_reader :select_box
      # Get the current selection mode
      # @return [Symbol]
      attr_reader :selection_mode
      # Get the current mode
      # @return [Symbol]
      attr_reader :mode
      # Box initial position
      BOX_INITIAL_POSITION = [17, 42]
      # Party positions
      PARTY_POSITIONS = [[233, 50], [281, 66], [233, 98], [281, 115], [233, 146], [281, 162]]
      # List of graphics depending on the selection mode
      ARROW_IMAGES = {battle: 'pc/arrow_red', pokemon: 'pc/arrow_blue', grouped: 'pc/arrow_green', item: 'pc/arrow_yellow'}
      # Create a new cusror object
      # @param viewport [Viewport]
      # @param index [Integer] index of the cursor where it is
      # @param inbox [Boolean] If the cursor is in box or not
      # @param mode_handler [ModeHandler]
      def initialize(viewport, index, inbox, mode_handler)
        super(viewport)
        @max_index_box = PFM.storage_class.box_size - 1
        @max_index_battle = PARTY_POSITIONS.size - 1
        @inbox = inbox
        @index = index % (max_index + 1)
        mode_handler.add_selection_mode_ui(self)
        mode_handler.add_mode_ui(self)
        update_position
        set_z(31)
      end
      # Update the animation
      def update
        @animation&.update
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        return @animation ? @animation.done? : true
      end
      # Get the max index
      # @return [Integer]
      def max_index
        return @inbox ? @max_index_box : @max_index_battle
      end
      # Set the current index
      # @param index [Integer]
      def index=(index)
        @index = index % (max_index + 1)
        update_position_with_animation
      end
      # Force an index (mouse operation)
      # @param inbox [Boolean]
      # @param index [Integer]
      def force_index(inbox, index)
        @select_box = false
        @inbox = inbox
        @index = index % (max_index + 1)
        update_position
        self.visible = false
      end
      # Set the inbox property
      # @param inbox [Boolean]
      def inbox=(inbox)
        @select_box = false if inbox
        @inbox = inbox
        update_graphics
        update if @inbox
      end
      # Set the selec box property
      # @param select_box [Boolean]
      def select_box=(select_box)
        @inbox = false if select_box
        @select_box = select_box
        set_position(67, 14)
        update_graphics
      end
      # Set the current selection mode
      # @param selection_mode [Symbol]
      def selection_mode=(selection_mode)
        @selection_mode = selection_mode
        update_graphics
      end
      # Set the current mode
      # @param mode [Symbol]
      def mode=(mode)
        @mode = mode
        update_graphics
      end
      private
      def update_graphics
        self.visible = !@select_box
        graphic = ARROW_IMAGES[@selection_mode] || ARROW_IMAGES[@mode]
        set_bitmap(graphic, :interface)
      end
      def update_position
        if @inbox
          x_pos, y_pos = *BOX_INITIAL_POSITION
          set_position(x_pos + 32 * (@index % 6), y_pos + 32 * (@index / 6))
        else
          set_position(*PARTY_POSITIONS[@index])
        end
      end
      def update_position_with_animation
        ori_x = x
        ori_y = y
        update_position
        @animation = Yuki::Animation.move(0.05, self, ori_x, ori_y, x, y)
        @animation.start
      end
    end
    # Class responsive of handling the mode for the PC UI
    class ModeHandler
      # Get the current mode
      # @return [Symbol] :pokemon, :item, :battle, :box
      attr_reader :mode
      # List the available modes
      AVAILABLE_MODES = %i[pokemon item battle]
      # box mode disabled for now
      # Get the current selection mode
      # @return [Symbol] :detailed, :fast, :grouped
      attr_reader :selection_mode
      # List the available modes
      AVAILABLE_SELECTION_MODES = %i[detailed fast grouped]
      # Create a new Mode Handler
      # @param selection_mode [Symbol] :detailed, :fast or :grouped
      def initialize(mode, selection_mode)
        @mode_uis = []
        @select_mode_uis = []
        self.mode = mode
        self.selection_mode = selection_mode
      end
      # Add a mode ui
      # @param mode_ui [#mode=]
      def add_mode_ui(mode_ui)
        @mode_uis << mode_ui
        mode_ui.mode = @mode
      end
      # Add a selection mode ui
      # @param selection_mode_ui [#selection_mode=]
      def add_selection_mode_ui(selection_mode_ui)
        @select_mode_uis << selection_mode_ui
        selection_mode_ui.selection_mode = @selection_mode
      end
      # Set the mode of the UIs
      # @param mode [Symbol]
      def mode=(mode)
        raise "Bad mode got #{mode} expected #{AVAILABLE_MODES.join(',')}" unless AVAILABLE_MODES.include?(mode)
        @mode = mode
        @mode_uis.each { |ui| ui.mode = mode }
      end
      # Set the mode of the UIs
      # @param selection_mode [Symbol]
      def selection_mode=(selection_mode)
        unless AVAILABLE_SELECTION_MODES.include?(selection_mode)
          raise "Bad selection mode got #{selection_mode} expected #{AVAILABLE_SELECTION_MODES.join(',')}"
        end
        @selection_mode = selection_mode
        @select_mode_uis.each { |ui| ui.selection_mode = selection_mode }
      end
      # Swap the mode
      # @return [Symbol]
      def swap_mode
        self.mode = AVAILABLE_MODES[AVAILABLE_MODES.index(@mode) + 1] || AVAILABLE_MODES.first
      end
      # Swap the selection mode
      # @return [Symbol]
      def swap_selection_mode
        self.selection_mode = AVAILABLE_SELECTION_MODES[AVAILABLE_SELECTION_MODES.index(@selection_mode) + 1] || AVAILABLE_SELECTION_MODES.first
      end
    end
    # Class that handle all the logic related to cursor movement between each party of the UI
    class CursorHandler
      # Create a cusor handler
      # @param cursor [Cursor]
      def initialize(cursor)
        @cursor = cursor
        @row_index = 0
        @column_index = 0
      end
      # Get the cursor mode
      # @return [Symbol] :box, :party, :box_choice
      def mode
        return :box if @cursor.inbox
        return :box_choice if @cursor.select_box
        return :party
      end
      # Get the index of the cursor
      # @return [Integer]
      def index
        @cursor.index
      end
      # Move the cursor to the right
      # @return [Boolean] if the action was a success
      def move_right
        @cursor.visible = true
        return false if @cursor.select_box
        return @cursor.inbox ? move_right_inbox : move_right_party
      end
      # Move the cursor to the left
      # @return [Boolean] if the action was a success
      def move_left
        @cursor.visible = true
        return false if @cursor.select_box
        return @cursor.inbox ? move_left_inbox : move_left_party
      end
      # Move the cursor up
      # @return [Boolean] if the action was a success
      def move_up
        @cursor.visible = true
        if @cursor.inbox && @cursor.index <= 5
          @row_index = @cursor.index
          @cursor.select_box = true
        else
          if @cursor.select_box
            @cursor.inbox = true
            @cursor.index = @row_index + 24
          else
            @cursor.index -= @cursor.inbox ? 6 : 2
          end
        end
        return true
      end
      # Move the cursor down
      # @return [Boolean] if the action was a success
      def move_down
        @cursor.visible = true
        if @cursor.select_box
          @cursor.inbox = true
          @cursor.index = @cursor.index
        else
          @cursor.index += @cursor.inbox ? 6 : 2
        end
        return true
      end
      private
      # Move the cursor to the right in the box
      # @return [Boolean] if the action was a success
      def move_right_inbox
        if @cursor.index % 6 == 5
          @column_index = @cursor.index
          @cursor.inbox = false
          @cursor.index = (@cursor.index / 11.5).floor * 2
        else
          @cursor.index += 1
        end
        return true
      end
      # Move the cursor to the right in the party
      # @return [Boolean] if the action was a success
      def move_right_party
        if @cursor.index.odd?
          @cursor.inbox = true
          @cursor.index = @column_index - 5
        else
          @cursor.index += 1
        end
        return true
      end
      # Move the cursor to the left in the box
      # @return [Boolean] if the action was a success
      def move_left_inbox
        if @cursor.index % 6 == 0
          @column_index = @cursor.index + 5
          @cursor.inbox = false
          @cursor.index = @cursor.index / 9 * 2
          @cursor.index += 1
        else
          @cursor.index -= 1
        end
        return true
      end
      # Move the cursor to the left in the party
      # @return [Boolean] if the action was a success
      def move_left_party
        if @cursor.index.even?
          @cursor.inbox = true
          @cursor.index = @column_index
        else
          @cursor.index -= 1
        end
        return true
      end
    end
    # Class responsive of handling the selection
    class SelectionHandler
      # Set the current storage object
      # @return [PFM::Storage]
      attr_writer :storage
      # Set the current cursor handler
      # @return [CursorHandler]
      attr_writer :cursor
      # Set the current party
      # @return [Array<PFM::Pokemon>]
      attr_writer :party
      # Create a new selection handler
      # @param mode_handler [ModeHandler] object responsive of handling the mode
      def initialize(mode_handler)
        @mode_handler = mode_handler
        @box_selections = {}
        @battle_selections = {}
        @party_selection = []
        @cursor = nil
        @storage = nil
        @party = nil
      end
      # Update the current selection
      def update_selection
        @box&.update_selection(@box_selections[@storage.current_box] || [])
        @party_display&.update_selection(@mode_handler.mode == :battle ? @battle_selections[@storage.current_battle_box] || [] : @party_selection)
      end
      # Tell if all selection are empty
      # @return [Boolean]
      def empty?
        @box_selections.all? { |_, v| v.empty? } && @battle_selections.all? { |_, v| v.empty? } && @party_selection.empty?
      end
      # Select or deselect the current index
      def select
        if @cursor.mode == :box
          arr = (@box_selections[@storage.current_box] ||= [])
        else
          if @mode_handler.mode == :battle
            arr = (@battle_selections[@storage.current_battle_box] ||= [])
          else
            arr = @party_selection
          end
        end
        if arr.include?(index = @cursor.index)
          arr.delete(index)
        else
          arr << index
        end
      end
      # Move the current selection of pokemon to the current cursor
      # @return [Boolean] if the operation was a success
      def move_pokemon_to_cursor
        size = current_object_size
        return false if selection_size > size
        set_pokemon = current_object_setter
        get_pokemon = current_object_getter
        index = @cursor.index
        process = proc do |box, i|
          pokemon = get_pokemon.call(index)
          pokemon_stored = set_pokemon.call(index, box[i])
          reset_form(pokemon_stored)
          index = (index + 1) % size
          box[i] = pokemon
        end
        each_box_selection(&process)
        each_battle_selection(&process)
        each_party_selection(&process)
        clear
        @party.compact!
        return true
      end
      # Move the current selection of items to the current cursor
      # @return [Boolean] if the operation was a success
      def move_items_to_cursor
        size = current_object_content_size
        return false if selection_size > size
        get_pokemon = current_object_getter
        index = @cursor.index
        process = proc do |box, i|
          next unless box[i]
          pokemon = get_pokemon.call(index)
          index = (index + 1) % size
          redo unless pokemon
          box[i].item_holding, pokemon.item_holding = pokemon.item_holding, box[i].item_holding
          box[i].form_calibrate
          pokemon.form_calibrate
        end
        each_box_selection(&process)
        each_battle_selection(&process)
        each_party_selection(&process)
        clear
        return true
      end
      # Release all selected Pokemon
      def release_selected_pokemon
        process = proc do |box, i|
          box[i] = nil
        end
        each_box_selection(&process)
        each_battle_selection(&process)
        each_party_selection(&process)
        clear
        @party.compact!
      end
      # Clear the selection
      def clear
        @box_selections.clear
        @battle_selections.clear
        @party_selection.clear
      end
      # Define the box selection display
      # @param box [#update_selection(arr)]
      def box_selection_display=(box)
        @box = box
      end
      # Define the party selection display
      # @param party_display [#update_selection(arr)]
      def party_selection_display=(party_display)
        @party_display = party_display
      end
      # Get all selected Pokemon
      # @return [Array<PFM::Pokemon>]
      def all_selected_pokemon
        selection = []
        process = proc { |box, i| selection << box[i] if box[i] }
        each_box_selection(&process)
        each_battle_selection(&process)
        each_party_selection(&process)
        return selection
      end
      # Get all selected Pokemon in party
      # @return [Array<PFM::Pokemon>]
      def all_selected_pokemon_in_party
        return @party_selection.map { |i| @party[i] }.compact
      end
      private
      # Get the selection size
      # @return [Integer]
      def selection_size
        @box_selections.sum { |_, v| v.size } + @battle_selections.sum { |_, v| v.size } + @party_selection.size
      end
      # Get the current object size
      # @return [Integer]
      def current_object_size
        if @cursor.mode == :box
          return @storage.current_box_object.content.size
        else
          if @mode_handler.mode == :battle
            return @storage.battle_boxes[@storage.current_battle_box].content.size
          else
            return 6
          end
        end
      end
      # Get the current object actual content size
      # @return [Integer]
      def current_object_content_size
        if @cursor.mode == :box
          return @storage.current_box_object.content.compact.size
        else
          if @mode_handler.mode == :battle
            return @storage.battle_boxes[@storage.current_battle_box].content.compact.size
          else
            return @party.compact.size
          end
        end
      end
      # Get the current object setter
      # @return [#call(index, value)]
      def current_object_setter
        if @cursor.mode == :box
          return @storage.current_box_object.content.method(:[]=)
        else
          if @mode_handler.mode == :battle
            return @storage.battle_boxes[@storage.current_battle_box].content.method(:[]=)
          else
            return @party.method(:[]=)
          end
        end
      end
      # Get the current object getter
      # @return [#call(index)]
      def current_object_getter
        if @cursor.mode == :box
          return @storage.current_box_object.content.method(:[])
        else
          if @mode_handler.mode == :battle
            return @storage.battle_boxes[@storage.current_battle_box].content.method(:[])
          else
            return @party.method(:[])
          end
        end
      end
      # Iterate through all box selection
      # @yieldparam box [Array<PFM::Pokemon>] current box object
      # @yieldparam i [Integer] current selection
      def each_box_selection
        @box_selections.each do |index, selections|
          box = @storage.get_box_content(index)
          selections.each do |i|
            yield(box, i)
          end
        end
      end
      # Iterate through all battle box selection
      # @yieldparam box [Array<PFM::Pokemon>] current battle box object
      # @yieldparam i [Integer] current selection
      def each_battle_selection
        @battle_selections.each do |index, selections|
          box = @storage.battle_boxes[index].content
          selections.each do |i|
            yield(box, i)
          end
        end
      end
      # Iterate through all party selection
      # @yieldparam party [Array<PFM::Pokemon>] current party object
      # @yieldparam i [Integer] current selection
      def each_party_selection
        @party_selection.each do |i|
          yield(@party, i)
        end
      end
      # Reset the form of the Pokemon
      # @param pokemon [PFM::Pokemon] the pokemon stored
      def reset_form(pokemon)
        return unless pokemon
        list = %i[shaymin]
        pokemon.form_calibrate(:none) if list.include?(pokemon.db_symbol)
      end
    end
    # Stack responsive of showing the full PC UI
    class Composition < UI::SpriteStack
      # Get the mode handler
      # @return [ModeHandler]
      attr_reader :mode_handler
      # Get the party
      # @return [Array<PFM::Pokemon>]
      attr_reader :party
      # Get the storage object
      # @return [PFM::Storage]
      attr_reader :storage
      # Get the current box index
      # @return [Integer]
      attr_reader :box_index
      # Get the summary object
      # @return [Summary]
      attr_reader :summary
      # Get the cursor object
      # @return [CursorHandler]
      attr_reader :cursor_handler
      # Get the selection handler
      # @return [SelectionHandler]
      attr_reader :selection_handler
      # Y Offset of the cursor while inside of the box
      OFFSET_Y_CURSOR = [0, -1, -2, -3, -4, -5, -5, -4, -3, -2, -1, 0]
      # Y Offset of the cursor while outside of the box
      OFFSET_Y_CURSOR_OUT_OF_THE_BOX = [15, 30, 63, 79, 111, 126]
      # Create a new Composition
      # @param viewport [Viewport] viewport used to display the sprites
      # @param mode [Symbol] :pokemon, :item, :battle or :box
      # @param selection_mode [Symbol] :detailed, :fast or :grouped
      def initialize(viewport, mode, selection_mode)
        super(viewport)
        @mode_handler = ModeHandler.new(mode, selection_mode)
        @selection_handler = SelectionHandler.new(@mode_handler)
        @animation = nil
        @storage = nil
        @party = nil
        @box_index = 0
        create_stack
        @selection_handler.cursor = @cursor_handler
      end
      # Update the composition state
      def update
        @root&.update
        @summary.update
        @cursor.update
        return if !@animation || @animation.done?
        @animation.update
      end
      # Tell if the animation is done
      # @return [boolean]
      def done?
        all_done = @summary.done? && @cursor.done?
        return @animation ? all_done && @animation.done? : all_done
      end
      # Start animation for right arrow
      # @param middle_animation [Yuki::Animation::TimedAnimation] animation played in the middle of this animation
      def animate_right_arrow(middle_animation = nil)
        arrow = @arrow_right
        @animation = Yuki::Animation::ScalarAnimation.new(0.05, arrow, :x=, arrow.x, arrow.x + 2)
        @animation.play_before(middle_animation) if middle_animation
        @animation.play_before(Yuki::Animation::ScalarAnimation.new(0.05, arrow, :x=, arrow.x + 2, arrow.x))
        @animation.start
      end
      # Start animation for left arrow
      # @param middle_animation [Yuki::Animation::TimedAnimation] animation played in the middle of this animation
      def animate_left_arrow(middle_animation = nil)
        arrow = @arrow_left
        @animation = Yuki::Animation::ScalarAnimation.new(0.05, arrow, :x=, arrow.x, arrow.x - 2)
        @animation.play_before(middle_animation) if middle_animation
        @animation.play_before(Yuki::Animation::ScalarAnimation.new(0.05, arrow, :x=, arrow.x - 2, arrow.x))
        @animation.start
      end
      # Set the storage object
      # @param storage [PFM::Storage]
      def storage=(storage)
        @storage = storage
        @box_stack.data = storage.current_box_object
        @selection_handler.storage = storage
      end
      # Set the party object
      # @param party [Array<PFM::Pokemon>]
      def party=(party)
        @party = party
        @selection_handler.party = party
        @party_box ||= PFM::Storage::BattleBox.new('party', party)
        shown_party = @mode_handler.mode == :battle ? storage.battle_boxes[storage.current_battle_box] : @party_box
        @party_stack.data = shown_party
      end
      # Tell if the mouse is hovering a pokemon sprite & update cursor index in consequence
      # @return [Boolean]
      def hovering_pokemon_sprite?
        if @cursor.inbox
          return true if @box_stack.pokemon_sprites[@cursor.index].simple_mouse_in?
        else
          if !@cursor.select_box
            return true if @party_stack.pokemon_sprites[@cursor.index].simple_mouse_in?
          end
        end
        index = @party_stack.pokemon_sprites.index(&:simple_mouse_in?)
        if index
          @cursor.force_index(false, index)
          return true
        end
        index = @box_stack.pokemon_sprites.index(&:simple_mouse_in?)
        if index
          @cursor.force_index(true, index)
          return true
        end
        return false
      end
      # Tell if the mouse hover the mode indicator
      # @return [Boolean]
      def hovering_mode_indicator?
        return @mode_indicator.simple_mouse_in?
      end
      # Tell if the mouse hover the selection mode indicator
      # @return [Boolean]
      def hovering_selection_mode_indicator?
        return @selection_mode_indicator.simple_mouse_in?
      end
      # Tell if the box option is hovered
      # @return [Boolean]
      def hovering_box_option?
        if @box_stack.box_option_hovered?
          @cursor.select_box = true
          return true
        else
          return false
        end
      end
      # Tell if the right arrow is hovered
      # @return [Boolean]
      def hovering_right_arrow?
        return @arrow_right.simple_mouse_in?
      end
      # Tell if the left arrow is hovered
      # @return [Boolean]
      def hovering_left_arrow?
        return @arrow_left.simple_mouse_in?
      end
      # Tell if the right arrow of party stack is hovered
      # @return [Boolean]
      def hovering_party_right_arrow?
        return @party_stack.hovering_right_arrow?
      end
      # Tell if the left arrow of party stack is hovered
      # @return [Boolean]
      def hovering_party_left_arrow?
        return @party_stack.hovering_left_arrow?
      end
      private
      def create_stack
        create_box_stack
        create_frames
        create_modes
        create_win_txt
        create_arrows
        create_party_stack
        create_summary
        create_cursor
      end
      def create_box_stack
        @box_stack = push_sprite(BoxStack.new(@viewport, @mode_handler, @selection_handler))
      end
      def create_party_stack
        @party_stack = push_sprite(PartyStack.new(@viewport, @mode_handler, @selection_handler))
      end
      def create_frames
        add_background('pc/frame').set_z(32)
        @frame_split = add_sprite(207, 25, 'pc/frame_split').set_z(33)
      end
      def create_modes
        @mode_background = push_sprite(WinMode.new(@viewport, @mode_handler))
        @mode_indicator = push_sprite(ModeSprite.new(@viewport, @mode_handler))
        @selection_mode_indicator = push_sprite(SelectionModeSprite.new(@viewport, @mode_handler))
      end
      def create_win_txt
        @win_txt = add_sprite(0, 217, 'pc/win_txt').set_z(30)
        @win_txt.visible = false
        @win_txt_input = push_sprite(UserInput.new(0, @viewport, 2, 217, 200, 23, ''))
        @win_txt_input.z = 30
        @win_txt_input.visible = false
      end
      def create_arrows
        @arrow_left = add_sprite(6, 29, 'pc/arrow_frame_l').set_z(2)
        @arrow_right = add_sprite(134, 29, 'pc/arrow_frame_r').set_z(2)
      end
      def create_summary
        @summary = push_sprite(Summary.new(@viewport, true))
      end
      def create_cursor
        @cursor = Cursor.new(@viewport, 0, true, @mode_handler)
        @cursor_origin = @cursor.send(:y)
        @root = Yuki::Animation::TimedLoopAnimation.new(1.2)
        @cursor_anim = Yuki::Animation::DiscreetAnimation.new(1.2, self, :move_cursor, 0, OFFSET_Y_CURSOR.size - 1)
        @root.play_before(@cursor_anim)
        @root.start
        @cursor_handler = CursorHandler.new(@cursor)
      end
      # Function that moves the cursor according to the positioning of the cursor, creating the cursor moving up and down animation
      # @param index [Integer]
      def move_cursor(index)
        if @cursor.inbox
          if @cursor.index < 6
            @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index]
          else
            if @cursor.index.between?(6, 11)
              @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] + 32
            else
              if @cursor.index.between?(12, 17)
                @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] + 64
              else
                if @cursor.index.between?(18, 23)
                  @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] + 96
                else
                  if @cursor.index >= 24
                    @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] + 128
                  end
                end
              end
            end
          end
        else
          @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] + OFFSET_Y_CURSOR_OUT_OF_THE_BOX[@cursor.index] if @cursor.index.between?(0, 5)
        end
        if @cursor.select_box
          @cursor.y = @cursor_origin + OFFSET_Y_CURSOR[index] - 30
        end
      end
    end
    # Stack responsive of showing a box
    class BoxStack < UI::SpriteStack
      # Get the current mode
      # @return [Symbol]
      attr_reader :mode
      # Create a new box stack
      # @param viewport [Viewport]
      # @param mode_handler [ModeHandler] object responsive of handling the mode
      # @param selection_handler [SelectionHandler] object responsive of handling the selection
      def initialize(viewport, mode_handler, selection_handler)
        super(viewport)
        @selection = []
        create_stack
        mode_handler.add_mode_ui(self)
        selection_handler.box_selection_display = self
      end
      # Tell if the name background is hovered in order to show the option menu
      # @return [Boolean]
      def box_option_hovered?
        return @name_background.simple_mouse_in?
      end
      # Update the selection
      # @param selection [Array<Integer>] list of selected indexes
      def update_selection(selection)
        @select_buttons.each_with_index do |button, index|
          button.visible = selected = selection.include?(index)
          @pokemon_icons[index].y = @pokemon_shadows[index].y - (selected ? 4 : 0)
        end
        @selection = selection
      end
      # Update the data
      # @param data [PFM::Storage::Box]
      def data=(data)
        super
        self.mode = @mode
        update_selection(@selection)
      end
      # Make the pokemon gray depending on a criteria
      # @yieldparam pokemon [PFM::Pokemon]
      def gray_pokemon
        @pokemon_icons.each_with_index do |icon, index|
          pokemon = @data.content[index]
          icon.shader = (pokemon && yield(pokemon) ? @gray_shader : nil)
        end
      end
      # Set the mode
      # @param mode [Symbol]
      def mode=(mode)
        mode == :item ? update_sprites_to_item : update_sprites_to_other
        @mode = mode
      end
      # Get the Pokemon sprites
      # @return [Array<Sprite>]
      def pokemon_sprites
        @pokemon_shadows
      end
      private
      def create_stack
        create_box_background
        create_box_name_background
        create_box_name
        create_slots
        create_select_button
        create_pokemons
      end
      def create_box_background
        push_sprite(BoxBackground.new(@viewport))
      end
      def create_box_name_background
        add_sprite(15, 22, 'pc/name_frame')
        @name_background = add_sprite(20, 27, NO_INITIAL_IMAGE, type: BoxNameBackground).set_z(3)
      end
      def create_box_name
        add_text(20, 27, 108, 17, :name, 1, type: SymText, color: 9).z = 4
      end
      def create_slots
        add_sprite(10, 56, 'pc/slots').set_z(2)
      end
      def create_select_button
        bmp = RPG::Cache.interface('pc/select')
        @select_buttons = Array.new(PFM.storage_class.box_size) do |i|
          sprite = add_sprite(7 + 32 * (i % 6), 53 + 32 * (i / 6), bmp).set_z(3)
          sprite.visible = false
          next(sprite)
        end
      end
      def create_pokemons
        shadow_shader = Shader.create(:color_shader)
        shadow_shader.set_float_uniform('color', Color.new(57, 59, 67))
        @gray_shader = Shader.create(:tone_shader)
        @gray_shader.set_float_uniform('tone', Tone.new(0, 0, 0, 255))
        pokemon_count = PFM.storage_class.box_size
        @pokemon_shadows = Array.new(pokemon_count) do |i|
          sprite = add_sprite(8 + 32 * (i % 6), 54 + 32 * (i / 6), NO_INITIAL_IMAGE, i, type: PokemonIcon).set_z(4)
          sprite.shader = shadow_shader
          next(sprite)
        end
        @pokemon_icons = Array.new(pokemon_count) do |i|
          sprite = add_sprite(8 + 32 * (i % 6), 54 + 32 * (i / 6), NO_INITIAL_IMAGE, i, type: PokemonIcon).set_z(4)
          next(sprite)
        end
        @pokemon_items = Array.new(pokemon_count) do |i|
          sprite = add_sprite(8 + 32 * (i % 6), 54 + 32 * (i / 6), NO_INITIAL_IMAGE, i, type: PokemonItemIcon).set_z(4)
          next(sprite)
        end
      end
      # Update sprites to item mode
      def update_sprites_to_item
        @pokemon_items.each { |i| i.opacity = 255 }
        @pokemon_icons.each_with_index do |s, i|
          s.opacity = 128
          s.shader = @pokemon_items[i].visible ? nil : @gray_shader
        end
      end
      # Update sprites to other modes
      def update_sprites_to_other
        @pokemon_items.each { |i| i.opacity = 0 }
        @pokemon_icons.each do |i|
          i.opacity = 255
          i.shader = nil
        end
      end
    end
    # Icon of a creature in the storage UI
    class PokemonIcon < UI::PokemonIconSprite
      def initialize(viewport, index)
        super(viewport, false)
        @index = index
      end
      # Set the box data
      # @param box [PFM::Storage::Box]
      def data=(box)
        super(box.content[@index])
      end
      # Tell if the mouse is in the sprite
      def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
        mx, my = translate_mouse_coords(mouse_x, mouse_y)
        return mx.between?(0, 31) && my.between?(0, 31)
      end
    end
    # Icon of a held item in the storage UI
    class PokemonItemIcon < UI::ItemSprite
      def initialize(viewport, index)
        super(viewport)
        @index = index
        self.opacity = 0
      end
      # Set the box data
      # @param box [PFM::Storage::Box]
      def data=(box)
        item_id = box.content[@index]&.item_db_symbol
        super(item_id) if (self.visible = (item_id && item_id != :__undef__))
      end
    end
    # Stack responsive of showing a party
    class PartyStack < UI::SpriteStack
      # Get the current mode
      # @return [Symbol]
      attr_reader :mode
      # List of images according to the mode
      SLOT_IMAGES = {pokemon: 'pc/party_pkmn', item: 'pc/party_items', battle: 'pc/party_battle'}
      # List of coordinate for Pokemon sprite
      POKEMON_COORDINATES = [[224, 64], [272, 80], [224, 112], [272, 128], [224, 160], [272, 176]]
      # Create a new party stack
      # @param viewport [Viewport]
      # @param mode_handler [ModeHandler] object responsive of handling the mode
      # @param selection_handler [SelectionHandler] object responsive of handling the selection
      def initialize(viewport, mode_handler, selection_handler)
        super(viewport)
        create_stack
        mode_handler.add_mode_ui(self)
        selection_handler.party_selection_display = self
        @selection = []
      end
      # Update the selection
      # @param selection [Array<Integer>] current selected Pokemon
      def update_selection(selection)
        @select_buttons.each_with_index do |button, index|
          button.visible = selected = selection.include?(index)
          @pokemon_icons[index].y = @pokemon_shadows[index].y - (selected ? 4 : 0)
        end
        @selection = selection
      end
      # Update the data
      # @param data [PFM::Storage::BattleBox]
      def data=(data)
        super
        update_selection(@selection)
        self.mode = @mode
        @box_name.visible = @mode == :battle
      end
      # Make the pokemon gray depending on a criteria
      # @yieldparam pokemon [PFM::Pokemon]
      def gray_pokemon
        @pokemon_icons.each_with_index do |icon, index|
          pokemon = @data.content[index]
          icon.shader = (pokemon && yield(pokemon) ? @gray_shader : nil)
        end
      end
      # Set the mode
      # @param mode [Symbol]
      def mode=(mode)
        mode == :item ? update_sprites_to_item : update_sprites_to_other
        @mode = mode
        @slots.set_bitmap(SLOT_IMAGES[mode], :interface) if (@slots.visible = mode != :box)
        @box_name.visible = @left_arrow.visible = @right_arrow.visible = mode == :battle
        @txt_party.visible = !@box_name.visible
      end
      # Get the Pokemon sprites
      # @return [Array<Sprite>]
      def pokemon_sprites
        @pokemon_shadows
      end
      # Tell if the left arrow is hovered
      # @return [Boolean]
      def hovering_left_arrow?
        @left_arrow.simple_mouse_in?
      end
      # Tell if the right arrow is hovered
      # @return [Boolean]
      def hovering_right_arrow?
        @right_arrow.simple_mouse_in?
      end
      private
      def create_stack
        create_txt_party
        create_box_name
        create_slots
        create_select_button
        create_pokemons
        create_arrows
      end
      def create_txt_party
        @txt_party = add_sprite(234, 37, 'pc/txt_party_').set_z(2)
      end
      def create_box_name
        @box_name = add_text(226, 37, 75, 16, :name, 1, 1, type: UI::SymText, color: 10)
        @box_name.z = 2
        @box_name.bold = true
      end
      def create_slots
        @slots = add_sprite(221, 61, NO_INITIAL_IMAGE).set_z(2)
      end
      def create_select_button
        bmp = RPG::Cache.interface('pc/select')
        @select_buttons = Array.new(6) do |i|
          x, y = POKEMON_COORDINATES[i]
          sprite = add_sprite(x - 1, y - 1, bmp).set_z(3)
          sprite.visible = false
          next(sprite)
        end
      end
      def create_pokemons
        shadow_shader = Shader.create(:color_shader)
        shadow_shader.set_float_uniform('color', Color.new(57, 59, 67))
        @gray_shader = Shader.create(:tone_shader)
        @gray_shader.set_float_uniform('tone', Tone.new(0, 0, 0, 255))
        pokemon_count = 6
        @pokemon_shadows = Array.new(pokemon_count) do |i|
          sprite = add_sprite(*POKEMON_COORDINATES[i], NO_INITIAL_IMAGE, i, type: PokemonIcon).set_z(4)
          sprite.shader = shadow_shader
          next(sprite)
        end
        @pokemon_icons = Array.new(pokemon_count) do |i|
          sprite = add_sprite(*POKEMON_COORDINATES[i], NO_INITIAL_IMAGE, i, type: PokemonIcon).set_z(4)
          next(sprite)
        end
        @pokemon_items = Array.new(pokemon_count) do |i|
          sprite = add_sprite(*POKEMON_COORDINATES[i], NO_INITIAL_IMAGE, i, type: PokemonItemIcon).set_z(4)
          next(sprite)
        end
      end
      def create_arrows
        @left_arrow = add_sprite(214, 38, NO_INITIAL_IMAGE, :L, type: UI::KeyShortcut).set_z(2)
        @right_arrow = add_sprite(301, 38, NO_INITIAL_IMAGE, :R, type: UI::KeyShortcut).set_z(2)
      end
      # Update sprites to item mode
      def update_sprites_to_item
        @pokemon_items.each { |i| i.opacity = 255 }
        @pokemon_icons.each_with_index do |s, i|
          s.opacity = 128
          s.shader = @pokemon_items[i].visible ? nil : @gray_shader
        end
      end
      # Update sprites to other modes
      def update_sprites_to_other
        @pokemon_items.each { |i| i.opacity = 0 }
        @pokemon_icons.each do |i|
          i.opacity = 255
          i.shader = nil
        end
      end
    end
    # Stack responsive of showing a summary
    class Summary < UI::SpriteStack
      # Tell if the UI is reduced or not
      # @return [Boolean]
      attr_reader :reduced
      # Position of the summary depending on the state
      POSITION = [[210, 200], [210, 10]]
      # Position of the letter depending on the state
      LETTER_POSITION = [[1, 0], [95, 15]]
      # Time between each text transition
      TEXT_TRANSITION_TIME = 2
      # Create a new summary object
      # @param viewport [Viewport]
      # @param reduced [Boolean] if the UI is initially reduced or not
      def initialize(viewport, reduced)
        super(viewport, *POSITION[1])
        @reduced = reduced
        @invisible_if_egg = []
        @animation = nil
        @last_time = Graphics.current_time
        @last_text = 0
        create_stack
        reset_text_visibility
        set_position(*POSITION[0]) if reduced
      end
      # Update the composition state
      def update
        @sprite&.update
        update_text_transition
        return if !@animation || @animation.done?
        @animation.update
      end
      # Set an object invisible if the Pokemon is an egg
      # @param object [#visible=] the object that is invisible if the Pokemon is an egg
      def no_egg(object)
        @invisible_if_egg << object
        return object
      end
      # Update the shown pokemon
      def data=(pokemon)
        super
        @pokemon = pokemon
        if @sprite.visible
          reset_text_visibility
          @invisible_if_egg.each { |sprite| sprite.visible = false } if @pokemon&.egg?
        end
      end
      # Tell if the animation is done
      # @return [boolean]
      def done?
        return true unless @animation
        return @animation.done?
      end
      # Reduce the UI (start animation)
      def reduce
        return if @reduced
        @animation = Yuki::Animation.move_discreet(0.2, self, *POSITION[1], *POSITION[0])
        @animation.start
        @reduced = true
      end
      # Show the UI (start animation)
      def show
        return unless @reduced
        @animation = Yuki::Animation.move_discreet(0.2, self, *POSITION[0], *POSITION[1])
        @animation.start
        @reduced = false
      end
      private
      # Function that updates the text transition
      def update_text_transition
        return unless @sprite.visible
        return if @pokemon.egg?
        if (Graphics.current_time - @last_time) >= TEXT_TRANSITION_TIME
          @transitionning_texts[@last_text].visible = false
          @last_text += 1
          @last_text %= @transitionning_texts.size
          @transitionning_texts[@last_text].visible = true
          @last_time = Graphics.current_time
        end
      end
      def create_stack
        create_background
        create_press_letter
        create_pokemon
      end
      def create_background
        add_background('pc/resume').set_z(5)
      end
      def create_press_letter
        add_sprite(*LETTER_POSITION[0], NO_INITIAL_IMAGE, :Y, type: UI::KeyShortcut).set_z(6)
        add_sprite(*LETTER_POSITION[1], NO_INITIAL_IMAGE, :Y, type: UI::KeyShortcut).set_z(6)
      end
      def create_pokemon
        no_egg @id_text = add_text(2, 17, 0, 16, :id_text, color: 10, type: SymText)
        @id_text.z = 6
        add_text(15, 25, 79, 15, :name, 1, color: 10, type: SymText).z = 6
        @sprite = add_sprite(55, 142, NO_INITIAL_IMAGE, type: UI::PokemonFaceSprite).set_z(6)
        add_text(15, 143, 79, 15, :given_name, 1, color: 10, type: SymText).z = 6
        no_egg add_sprite(96, 146, NO_INITIAL_IMAGE, type: UI::GenderSprite).set_z(6)
        no_egg add_sprite(62, 161, 'pc/lv_')
        no_egg add_text(76, 62, 0, 15, :level_text, color: 10, type: SymText)
        no_egg add_sprite(5, 172, NO_INITIAL_IMAGE, type: UI::Type1Sprite).set_z(6)
        no_egg add_sprite(57, 172, NO_INITIAL_IMAGE, type: UI::Type2Sprite).set_z(6)
        @transitionning_texts = [add_text(8, 189, 0, 15, :nature_text, color: 10, type: SymText), add_text(8, 189, 0, 15, :ability_name, color: 10, type: SymText), add_text(8, 189, 0, 15, :item_name, color: 10, type: SymText)]
        @transitionning_texts.each { |text| no_egg(text) }
      end
      def reset_text_visibility
        @transitionning_texts.each do |tt|
          tt.visible = false
          tt.z = 6
        end
        @transitionning_texts[@last_text].visible = true
      end
    end
  end
end
module GamePlay
  # Storage scene
  class PokemonStorage < BaseCleanUpdate
    # List of keys supported by the base UI depending on the mode
    BASE_UI_KEYS = [regular = %i[A X Y B], regular, %i[A L R B], regular, regular, regular, %i[A LEFT RIGHT B], regular]
    # List of texts shown by the base UI depending on the mode
    BASE_UI_TEXTS = [regular = [[:ext_text, 9007, 14], [:get_text, nil], [:ext_text, 9007, 16], [:ext_text, 9007, 15]], regular, [[:ext_text, 9007, 14], [:ext_text, 9007, 18], [:ext_text, 9007, 19], [:ext_text, 9007, 15]], [[:ext_text, 9007, 14], [:ext_text, 9007, 23], [:ext_text, 9007, 16], [:ext_text, 9007, 20]], [[:ext_text, 9007, 14], [:get_text, nil], [:ext_text, 9007, 16], [:ext_text, 9007, 20]], [[:ext_text, 9007, 17], [:get_text, nil], [:ext_text, 9007, 16], [:ext_text, 9007, 20]], [[:ext_text, 9007, 21], [:ext_text, 9007, 18], [:ext_text, 9007, 19], [:ext_text, 9007, 15]], [[:get_text, nil], [:get_text, nil], [:get_text, nil], [:ext_text, 9007, 22]]]
    # Hash describing which mode to choose in the base UI when we're in detailed mode
    MODE_TO_BASE_UI_MODE = {pokemon: 0, item: 1, battle: 2}
    # Create a new Storage Scene
    # @param storage [PFM::Storage] the current storage object
    # @param party [Array<PFM::Pokemon>]
    def initialize(storage = $storage, party = $actors)
      super()
      @storage = storage
      @party = party
      @index = storage.current_box
      @battle_index = 0
      @mouse_actions = BASE_UI_KEYS.map { |arr| arr.map { |v| AIU_KEY2METHOD[v] || :action_b } }
      @moving_pokemon = false
      Mouse.wheel = 0
    end
    # Update the graphics of the Storage scene
    def update_graphics
      @composition.update
      @base_ui&.update_background_animation
    end
    private
    def create_graphics
      create_viewport
      create_base_ui
      create_composition
    end
    def create_composition
      mode = $user_data.dig(:storage, :mode) || :pokemon
      selection_mode = $user_data.dig(:storage, :selection_mode) || :detailed
      @composition = UI::Storage::Composition.new(@viewport, mode, selection_mode)
      @composition.storage = @storage
      @composition.party = @party
      @mode_handler = @composition.mode_handler
      @summary = @composition.summary
      @cursor = @composition.cursor_handler
      @selection = @composition.selection_handler
      update_summary
    end
    def create_base_ui
      @base_ui = UI::GenericBaseMultiMode.new(@viewport, base_ui_texts, BASE_UI_KEYS)
    end
    # Get all the base UI texts
    # @return [Array<Array<String>>]
    def base_ui_texts
      BASE_UI_TEXTS.map { |arr| arr.map { |v| send(*v) } }
    end
    public
    # Refresh everything in the UI
    def refresh
      @composition.storage = @storage
      @composition.party = @party
      update_summary
      update_mode
      @selection.update_selection
    end
    private
    # Function responsive of changing the box
    # @param moved_right [Boolean] if the player supposedly pressed right
    def change_box(moved_right)
      @index = (@index + (moved_right ? 1 : -1)) % @storage.box_count
      animation = Yuki::Animation.send_command_to(self, :update_box_shown)
      moved_right ? @composition.animate_right_arrow(animation) : @composition.animate_left_arrow(animation)
    end
    # Function that updates the box shown
    def update_box_shown
      play_cursor_se
      @storage.current_box = @index
      refresh
    end
    # Update the summary
    def update_summary
      if @cursor.mode == :box
        @composition.summary.data = @storage.current_box_object.content[@cursor.index]
      else
        @summary.reduce
      end
    end
    # Clear the selection
    def clear_selection
      @selection_box.clear
      @selection_party.clear
      refresh
    end
    # Update the mode of the base_ui
    def update_mode
      return unless @base_ui
      if @cursor.mode == :box_choice
        @base_ui.mode = 6
      else
        if @mode_handler.selection_mode == :detailed
          @base_ui.mode = MODE_TO_BASE_UI_MODE[@mode_handler.mode]
        else
          if @selection.empty?
            if @mode_handler.selection_mode == :fast
              @base_ui.mode = 4
            else
              @base_ui.mode = 3
            end
          else
            if @mode_handler.selection_mode == :fast
              @base_ui.mode = 5
            else
              @base_ui.mode = 3
            end
          end
        end
      end
    end
    # Tell if we can leave the storage
    # @return [Boolean]
    def can_leave_storage?
      return @party.any?(&:alive?) || !@storage.any_pokemon_alive
    end
    # Tell if the current box is not empty
    # @return [Boolean]
    def current_box_non_empty?
      return @storage.current_box_object.content.any?
    end
    # Tell if the pokemon can be released
    def pokemon_can_be_released?
      return false if @selection.all_selected_pokemon_in_party.any?
      return (@cursor.mode == :box || (@mode_handler.mode == :battle && @cursor.mode == :party)) && @party.any?(&:alive?)
    end
    public
    # List of Action depending on the selection mode
    SELECTION_MODE_ACTIONS = {detailed: :action_a_detailed, fast: :action_a_fast, grouped: :action_a_grouped}
    # List of method called by automatic_input_update when pressing on a key
    AIU_KEY2METHOD = {A: :action_a, B: :action_b, X: :action_x, Y: :action_y, L: :action_l, R: :action_r, L2: :action_l2, R2: :action_r2, LEFT: :action_left, RIGHT: :action_right, UP: :action_up, DOWN: :action_down}
    # Update the input of the scene
    def update_inputs
      return false unless @composition.done?
      return automatic_input_update(AIU_KEY2METHOD)
    end
    private
    # When the player press B we quit the computer
    def action_b
      if @moving_pokemon
        play_decision_se
        @selection.clear
        @base_ui.hide_win_text
        refresh
        @moving_pokemon = false
      else
        if @mode_handler.selection_mode != :detailed
          if @selection.empty?
            play_buzzer_se
          else
            play_decision_se
            @selection.clear
            refresh
          end
        else
          if can_leave_storage?
            Audio.se_play('audio/se/computerclose')
            @running = false
          else
            display_message_and_wait(text_get(33, 88), 1)
          end
        end
      end
    end
    # When the player press A we act depending on the state
    def action_a
      if @moving_pokemon
        action_a_fast_swap
        if @selection.all_selected_pokemon.empty?
          @moving_pokemon = false
          @base_ui.hide_win_text
        end
      else
        if @cursor.mode == :box_choice
          play_decision_se
          choice_box_option
        else
          send(SELECTION_MODE_ACTIONS[@mode_handler.selection_mode])
        end
      end
    end
    # When the player press X
    def action_x
      return play_buzzer_se if @moving_pokemon
      if @mode_handler.selection_mode == :detailed
        play_buzzer_se
      else
        @selection.empty? ? play_buzzer_se : action_a_fast_swap
      end
    end
    # When the player press A in detailed selection
    def action_a_detailed
      if @selection.empty?
        choice_single_pokemon
      else
        choice_selected_pokemon
      end
    end
    # When the player press A in fast mode, we select and then swap
    def action_a_fast
      if @selection.empty?
        @selection.select
        refresh
      else
        if @cursor.mode != :box_choice
          action_a_fast_swap
        else
          play_buzzer_se
        end
      end
    end
    # Action when the player need to swap pokemon (in fast mode)
    def action_a_fast_swap
      if @mode_handler.mode == :item
        result = @selection.move_items_to_cursor
      else
        result = @selection.move_pokemon_to_cursor
      end
      result ? play_decision_se : play_buzzer_se
      refresh
    end
    # Action when the player press A in grouped mode
    def action_a_grouped
      @selection.select
      play_decision_se
      refresh
    end
    # When the player press RIGHT
    def action_right
      return change_box(true) if @cursor.mode == :box_choice
      @cursor.move_right ? play_cursor_se : play_buzzer_se
      update_summary
      update_mode
    end
    # When the player press LEFT
    def action_left
      return change_box(false) if @cursor.mode == :box_choice
      @cursor.move_left ? play_cursor_se : play_buzzer_se
      update_summary
      update_mode
    end
    # When the player press UP
    def action_up
      @cursor.move_up ? play_cursor_se : play_buzzer_se
      update_summary
      update_mode
    end
    # When the player press DOWN
    def action_down
      @cursor.move_down ? play_cursor_se : play_buzzer_se
      update_summary
      update_mode
    end
    # When player press L we update the battle_box index
    def action_l
      return play_buzzer_se if @mode_handler.mode != :battle
      play_cursor_se
      @storage.current_battle_box = (@storage.current_battle_box - 1) % @storage.battle_boxes.size
      refresh
    end
    # When player press R we update the battle_box index
    def action_r
      return play_buzzer_se if @mode_handler.mode != :battle
      play_cursor_se
      @storage.current_battle_box = (@storage.current_battle_box + 1) % @storage.battle_boxes.size
      refresh
    end
    # When player press R2, the mode changes
    def action_r2
      play_cursor_se
      @mode_handler.swap_mode
      refresh
    end
    # When player press L2, the selection mode changes
    def action_l2
      return play_buzzer_se if @moving_pokemon
      play_cursor_se
      @mode_handler.swap_selection_mode
      refresh
    end
    # When the player press Y, the summary is shown
    def action_y
      return play_buzzer_se if @cursor.mode != :box
      play_cursor_se
      @summary.reduced ? @summary.show : @summary.reduce
    end
    public
    # Update the mouse action
    def update_mouse(moved)
      if Mouse.wheel != 0
        mouse_wheel_action
      else
        if Mouse.trigger?(:LEFT)
          mouse_left_action
        else
          if Mouse.trigger?(:RIGHT)
            mouse_right_action
          else
            if moved
              mouse_moved_action
            else
              update_mouse_ctrl_buttons(@base_ui.ctrl, @mouse_actions[@base_ui.mode])
            end
          end
        end
      end
      return false
    end
    private
    # Action when clicking left
    def mouse_left_action
      if @composition.hovering_left_arrow? || @composition.hovering_right_arrow?
        change_box(@composition.hovering_right_arrow?)
      else
        if @composition.hovering_box_option?
          action_a
        else
          if @mode_handler.mode == :battle && @composition.hovering_party_left_arrow?
            action_l
          else
            if @mode_handler.mode == :battle && @composition.hovering_party_right_arrow?
              action_r
            else
              if @composition.hovering_pokemon_sprite?
                action_a
              else
                if @composition.hovering_mode_indicator?
                  action_r2
                else
                  if @composition.hovering_selection_mode_indicator?
                    action_l2
                  else
                    update_mouse_ctrl_buttons(@base_ui.ctrl, @mouse_actions[@base_ui.mode])
                  end
                end
              end
            end
          end
        end
      end
    end
    # Action when clicking right
    def mouse_right_action
      action_x
    end
    # Action when the mouse moved
    def mouse_moved_action
      last_index = @cursor.index
      @composition.hovering_pokemon_sprite?
      update_summary if last_index != @cursor.index
    end
    # Action when a Mouse.wheel event appear
    def mouse_wheel_action
      @storage.current_box = (@storage.current_box + (Mouse.wheel > 0 ? -1 : 1)) % @storage.max_box
      refresh
      Mouse.wheel = 0
    end
    public
    # List of options shown when choosing the box option
    CHOICE_BOX_OPTIONS = [[:text_get, 33, 45], [:text_get, 33, 44], [:ext_text, 9007, 3], [:text_get, 33, 38]]
    # Message shown when choosing the box option
    MESSAGE_BOX_OPTIONS = [:ext_text, 9007, 0]
    # "What to do with %<box>s?"
    # List of options shown when choosing something for a single pokemon
    SINGLE_POKEMON_CHOICE = [[:text_get, 33, 39], [:text_get, 33, 41], [:text_get, 33, 80], [:text_get, 33, 79], [:text_get, 33, 42], [:text_get, 33, 81]]
    # Message shown when manipulating a single Pokemon
    SINGLE_POKEMON_MESSAGE = [:ext_text, 9007, 1]
    # "What to do with %<name>s?"
    # Message shown when we manipulate various Pokemon
    SELECTED_POKEMON_MESSAGE = [:ext_text, 9007, 2]
    private
    # Choice shown when we want to change box option
    def choice_box_option
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(send(*CHOICE_BOX_OPTIONS[0]), on_validate: method(:change_box_name)).register_choice(send(*CHOICE_BOX_OPTIONS[1]), on_validate: method(:change_box_theme)).register_choice(send(*CHOICE_BOX_OPTIONS[2]), on_validate: method(:add_new_box)).register_choice(send(*CHOICE_BOX_OPTIONS[3]), on_validate: method(:remove_box), disable_detect: method(:current_box_non_empty?))
      @base_ui.show_win_text(format(send(*MESSAGE_BOX_OPTIONS), box: @storage.current_box_object.name))
      choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      refresh
    end
    # Get the choice coordinates
    # @param choices [PFM::Choice_Helper]
    # @return [Array(Integer, Integer)]
    def choice_coordinates(choices)
      height = choices.size * 16 + 6
      return 318, 216 - height
    end
    # Choice shown when we didn't selected any pokemon
    def choice_single_pokemon
      @selection.clear
      @selection.select
      @current_pokemon = @selection.all_selected_pokemon.first
      if @current_pokemon.nil?
        @selection.clear
        return play_buzzer_se
      end
      play_decision_se
      can_item_be_taken = proc {@current_pokemon.item_holding == 0 }
      not_releasable = proc {!pokemon_can_be_released? }
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(get_text(SINGLE_POKEMON_CHOICE[0]), on_validate: method(:move_pokemon)).register_choice(get_text(SINGLE_POKEMON_CHOICE[1]), on_validate: method(:show_pokemon_summary)).register_choice(get_text(SINGLE_POKEMON_CHOICE[2]), on_validate: method(:give_item_to_pokemon)).register_choice(get_text(SINGLE_POKEMON_CHOICE[3]), on_validate: method(:take_item_from_pokemon), disable_detect: can_item_be_taken).register_choice(get_text(SINGLE_POKEMON_CHOICE[5]), on_validate: method(:release_pokemon), disable_detect: not_releasable)
      @base_ui.show_win_text(format(send(*SINGLE_POKEMON_MESSAGE), name: @current_pokemon.given_name))
      refresh
      @base_ui.mode = 7
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      if choice != 0
        @base_ui.hide_win_text
        @selection.clear
        refresh
      else
        update_mode
      end
    end
    # Choice shown when we selected various pokemon
    def choice_selected_pokemon
      @current_pokemons = @selection.all_selected_pokemon
      return play_buzzer_se if @current_pokemons.empty?
      play_decision_se
      not_releasable = proc {!pokemon_can_be_released? }
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(get_text(SINGLE_POKEMON_CHOICE[0]), on_validate: method(:move_selected_pokemon)).register_choice(get_text(SINGLE_POKEMON_CHOICE[1]), on_validate: method(:show_selected_pokemon_summary)).register_choice(get_text(SINGLE_POKEMON_CHOICE[5]), on_validate: method(:release_selected_pokemon), disable_detect: not_releasable)
      @base_ui.show_win_text(format(send(*SELECTED_POKEMON_MESSAGE), count: @current_pokemons.size))
      @base_ui.mode = 7
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      if choice != 0
        @base_ui.hide_win_text
        refresh
      else
        update_mode
      end
    end
    public
    include Util::GiveTakeItem
    # Message shown when we want to rename a box
    BOX_NAME_MESSAGE = [:ext_text, 9007, 4]
    # Message shown when choosing the theme
    BOX_THEME_CHOICE_MESSAGE = [:ext_text, 9007, 5]
    # Message shown when we want to give a name to the new box
    BOX_NEW_NAME_MESSAGE = [:ext_text, 9007, 6]
    # New box name
    BOX_NEW_DEFAULT_NAME = [:ext_text, 9007, 7]
    # Message shown to confirm if we want to remove the box
    REMOVE_BOX_MESSAGE = [:ext_text, 9007, 8]
    # Choice option for remove box confirmation
    REMOVE_BOX_CHOICES = [[:text_get, 33, 84], [:text_get, 33, 83]]
    # Message shown when we want to move a Pokemon
    MOVE_POKEMON_MESSAGE = [:ext_text, 9007, 9]
    # Message shown when we want to move several Pokemon
    MOVE_SELECTED_POKEMON_MESSAGE = [:ext_text, 9007, 10]
    # Message shown when we try to release a Pokemon
    RELEASE_POKEMON_MESSAGE1 = [:ext_text, 9007, 11]
    # Choice option for release pokemon confirmation
    RELEASE_POKEMON_CHOICES = [[:text_get, 33, 84], [:text_get, 33, 83]]
    # Message shown when we try to release several Pokemon
    RELEASE_SELECTED_POKEMON_MESSAGE = [:ext_text, 9007, 12]
    private
    # Change the current box name
    def change_box_name
      box = @storage.current_box_object.name
      GamePlay.open_box_name_input(box) { |scene| @storage.set_box_name(@storage.current_box, scene.return_name) }
    end
    # Change the current box theme
    def change_box_theme
      original_theme = @storage.current_box_object.theme
      max_index = max_theme_index
      @box_theme_index = original_theme
      @base_ui.show_win_text(format(send(*BOX_THEME_CHOICE_MESSAGE), box: @storage.current_box_object.name))
      loop do
        update_graphics
        Graphics.update
        if index_changed(:@box_theme_index, :LEFT, :RIGHT, max_index, 1)
          @storage.set_box_theme(@storage.current_box, @box_theme_index)
          refresh
          play_cursor_se
        else
          if Input.trigger?(:B)
            @storage.set_box_theme(@storage.current_box, original_theme)
            refresh
            play_cancel_se
            break
          else
            if Input.trigger?(:A)
              play_decision_se
              break
            end
          end
        end
      end
      @base_ui.hide_win_text
    end
    # Get the number of themes
    def max_theme_index
      16
    end
    # Add a new box
    def add_new_box
      box = format(send(*BOX_NEW_DEFAULT_NAME), id: @storage.max_box + 1)
      GamePlay.open_box_name_input(box) { |scene| @storage.add_box(scene.return_name) }
      @storage.current_box = @storage.max_box - 1
    end
    # Remove the box
    def remove_box
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 0)
      choices.register_choice(send(*REMOVE_BOX_CHOICES[0])).register_choice(send(*REMOVE_BOX_CHOICES[1]))
      @base_ui.show_win_text(format(send(*REMOVE_BOX_MESSAGE), box: @storage.current_box_object.name))
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      @storage.delete_box(@storage.current_box) if choice == 1
      @storage.current_box = @storage.current_box
    end
    # Move the selected Pokemon
    def move_pokemon
      @moving_pokemon = true
      @base_ui.show_win_text(format(send(*MOVE_POKEMON_MESSAGE), name: @current_pokemon.given_name))
    end
    # Show the summary of a Pokemon
    def show_pokemon_summary
      if @cursor.mode == :box
        party = @storage.current_box_object.content
      else
        if @mode_handler.mode == :battle
          party = @storage.battle_boxes[@storage.current_battle_box].content
        else
          party = @party
        end
      end
      GamePlay.open_summary(@current_pokemon, party.compact)
    end
    # Give an item to a Pokemon
    def give_item_to_pokemon
      givetake_give_item(@current_pokemon) {refresh }
    end
    # Take item from Pokemon
    def take_item_from_pokemon
      givetake_take_item(@current_pokemon)
    end
    # Release a Pokemon
    def release_pokemon
      return display_message(text_get(33, 108)) if @current_pokemon.db_symbol == :kyurem && @current_pokemon.absofusionned?
      name = @current_pokemon.given_name
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 0)
      choices.register_choice(send(*RELEASE_POKEMON_CHOICES[0])).register_choice(send(*RELEASE_POKEMON_CHOICES[1]))
      @base_ui.show_win_text(format(send(*RELEASE_POKEMON_MESSAGE1), name: name))
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      if choice == 1
        display_message(parse_text_with_pokemon(33, 102, @current_pokemon))
        @selection.release_selected_pokemon
        refresh
        display_message_and_wait(parse_text_with_pokemon(33, 103, @current_pokemon))
      end
    end
    # Move all selected Pokemon
    def move_selected_pokemon
      @moving_pokemon = true
      @base_ui.show_win_text(format(send(*MOVE_SELECTED_POKEMON_MESSAGE), count: @current_pokemons.size))
    end
    # Show the summary of the selected Pokemon
    def show_selected_pokemon_summary
      GamePlay.open_summary(@current_pokemons.compact.first, @current_pokemons)
    end
    # Release the selected Pokemon
    def release_selected_pokemon
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 0)
      choices.register_choice(send(*RELEASE_POKEMON_CHOICES[0])).register_choice(send(*RELEASE_POKEMON_CHOICES[1]))
      @base_ui.show_win_text(format(send(*RELEASE_SELECTED_POKEMON_MESSAGE), count: @current_pokemons.size))
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      @base_ui.hide_win_text
      if choice == 1
        @selection.release_selected_pokemon
        refresh
      end
    end
  end
  # Mixin definin the Input/Output of the PokemonTradeStorage class
  module PokemonTradeStorageMixin
    # Get the selected Pokemon index (1~30) = current box, (31~36) = party
    # @return [Integer, nil]
    attr_reader :return_data
    # Tell if a Pokemon was selected
    # @return [Boolean]
    def pokemon_selected?
      return false unless return_data
      return !selected_pokemon.nil?
    end
    # Get the selected Pokemon
    # @return [PFM::Pokemon, nil]
    def selected_pokemon
      return $storage.info(return_data - 1) if pokemon_selected_in_box?
      return $actors[return_data - 31] if pokemon_selected_in_party?
      return nil
    end
    # Tell if the selected Pokemon is from box
    # @return [Boolean]
    def pokemon_selected_in_box?
      return false unless return_data
      return return_data.to_i.between?(1, 30)
    end
    # Tell if the selected Pokemon is from party
    # @return [Boolean]
    def pokemon_selected_in_party?
      return false unless return_data
      return return_data.to_i.between?(31, 36)
    end
  end
  # Storage scene in trading context
  class PokemonTradeStorage < PokemonStorage
    include PokemonTradeStorageMixin
    # Message shown to tell to choose a Pokemon
    CHOOSE_POKEMON_MESSAGE = [:ext_text, 9007, 13]
    # "Choose a Pokemon to trade."
    # List of option when pressing A
    TRADE_OPTIONS = [[:ext_text, 9000, 90], [:text_get, 33, 41], [:text_get, 33, 82]]
    private
    def create_graphics
      super
      show_pokemon_choice
    end
    def show_pokemon_choice
      @base_ui.show_win_text(get_text(CHOOSE_POKEMON_MESSAGE))
    end
    alias action_x play_buzzer_se
    alias action_a_detailed play_buzzer_se
    alias action_a_fast play_buzzer_se
    alias action_a_fast_swap play_buzzer_se
    alias action_a_grouped play_buzzer_se
    alias action_l play_buzzer_se
    alias action_r play_buzzer_se
    alias action_r2 play_buzzer_se
    alias action_l2 play_buzzer_se
    def action_a
      return play_buzzer_se if @cursor.mode == :box_choice
      @selection.select
      refresh
      @current_pokemon = @selection.all_selected_pokemon.first
      choice_trade
      @selection.clear
      refresh
    end
    def action_b
      c = display_message(ext_text(9000, 87), 2, text_get(33, 83), text_get(33, 84))
      @return_data = nil
      @running = false if c == 0
    end
    def choice_trade
      return play_buzzer_se if @current_pokemon.nil?
      return display_message(parse_text(33, 118)) if @current_pokemon.absofusionned?
      play_decision_se
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(send(*TRADE_OPTIONS[0]), on_validate: method(:trade_pokemon)).register_choice(send(*TRADE_OPTIONS[1]), on_validate: method(:show_pokemon_summary)).register_choice(send(*TRADE_OPTIONS[2]))
      @base_ui.show_win_text(format(send(*SINGLE_POKEMON_MESSAGE), name: @current_pokemon.given_name))
      @base_ui.mode = 7
      choice = choices.display_choice(@viewport, *choice_coordinates(choices), nil, on_update: method(:update_graphics), align_right: true)
      show_pokemon_choice if choice != 0
    end
    def trade_pokemon
      if (index = @party.index(@current_pokemon))
        @return_data = 31 + index
      else
        @return_data = 1 + @cursor.index
      end
      @running = false
    end
  end
end
GamePlay.pokemon_storage_class = GamePlay::PokemonStorage
GamePlay.pokemon_trade_storage_mixin = GamePlay::PokemonTradeStorageMixin
GamePlay.pokemon_trade_storage_class = GamePlay::PokemonTradeStorage
