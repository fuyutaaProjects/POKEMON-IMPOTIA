module UI
  # Module containing all the Casino related UI elements
  module Casino
    # Object showing images of credit / payout element in casino UI
    class NumberDisplay < SpriteStack
      # List of files that shows the number
      FILES = ['casino/n0', 'casino/n1', 'casino/n2', 'casino/n3', 'casino/n4', 'casino/n5', 'casino/n6', 'casino/n7', 'casino/n8', 'casino/n9']
      # Delta of number between each frame
      DELTA = 3
      # Number that is currently displayed
      # @return [Integer]
      attr_reader :number
      # Target that the UI element should animatedly aim
      # @return [Integer]
      attr_accessor :target
      # Create a new NumberDipslay
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      # @param max_numbers [Integer] maximum number of numbers to display
      def initialize(viewport, x, y, max_numbers)
        super(viewport, x, y)
        width = number_width
        max_numbers.times do |i|
          add_sprite((max_numbers - i - 1) * width, 0, NO_INITIAL_IMAGE)
        end
        @number = 0
        @target = 0
      end
      # Sets the number to display
      # @param number [Integer] number to display
      def number=(number)
        @number = number
        @target = number
        update_numbers
      end
      # Update the animation
      def update
        return if done?
        if @target > @number
          @number = (@number + DELTA).clamp(@number, @target)
        else
          @number = (@number - DELTA).clamp(@target, @number)
        end
        update_numbers
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        @number == @target
      end
      private
      def update_numbers
        current_number = @number
        @stack.each do |sprite|
          sprite.bitmap = RPG::Cache.interface(FILES[current_number % 10])
          current_number /= 10
        end
      end
      def number_width
        RPG::Cache.interface(FILES.first).width
      end
    end
    # Object showing image that should be aligned
    class BandDisplay < Sprite
      # List of files that shows the images of the band
      FILES = ['casino/v1', 'casino/v2', 'casino/v3', 'casino/v4', 'casino/v5', 'casino/v6', 'casino/v7']
      @@loaded_images = []
      # Band information
      # @return [Array<Integer>]
      attr_reader :band
      # Animation speed of the band
      # @return [Integer]
      attr_accessor :animation_speed
      # Tell if the band is locked or not
      # @return [Boolean]
      attr_accessor :locked
      # Create a new BandDisplay
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      # @param band [Array<Integer>]
      # @param speed [Integer] speed of the band
      def initialize(viewport, x, y, band, speed)
        super(viewport)
        @band = band
        make_band
        set_position(x, y)
        self.opacity = 224
        @animation_speed = speed
        @locked = true
      end
      # Update the animation
      def update
        return if done?
        if @locked
          @animation_speed.times do
            src_rect.y -= 1
            break if done?
          end
        else
          src_rect.y -= @animation_speed
        end
        src_rect.y = src_rect.y % (7 * cell_height)
      end
      # Tell if the animation is done
      def done?
        return (src_rect.y % cell_height) == 0 && @locked
      end
      # Get the current value of the image shown by the band
      # @param row [Integer] row you want the value
      # @return [Integer]
      def value(row = 1)
        value_index = src_rect.y / cell_height + row
        return @band[value_index % @band.size]
      end
      private
      def make_band
        band_images = load_images
        dest_img = Image.new(cell_width, cell_height * 10)
        rect = Rect.new(0, 0, cell_width, cell_height)
        @band.each_with_index do |value, index|
          dest_img.blt(0, cell_height * index, band_images[value], rect)
        end
        bmp = Texture.new(dest_img.width, dest_img.height)
        dest_img.copy_to_bitmap(bmp)
        self.bitmap = bmp
        self.src_rect.height = 3 * cell_height
        dest_img.dispose
      end
      def cell_width
        28
      end
      def cell_height
        22
      end
      # Load the band images
      # @return [Array<Image>]
      def load_images
        if @@loaded_images.empty?
          FILES.each { |filename| @@loaded_images << RPG::Cache.interface_image(filename) }
        end
        return @@loaded_images
      end
      class << self
        public
        # Dispose all the loaded images
        def dispose_images
          @@loaded_images.each(&:dispose)
          @@loaded_images.clear
        end
      end
    end
    # Base UI for the Slot Machines
    class BaseUI < GenericBase
      private
      def background_filename
        'casino/base'
      end
    end
  end
  # Module holding all the VoltorbFlip UI elements
  module VoltorbFlip
    # Object that show a text using a method of the data object sent
    class Texts < SpriteStack
      # Format of the coin case text
      COIN_CASE_FORMAT = '%07d'
      # Format of the coin gain text
      COIN_GAIN_FORMAT = '%05d'
      # Create a new VoltorbFlip text handler
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @font_id = 20
        @title = add_text(0, 0, 320, 35, '', 1, color: 10)
        @title.bold = true
        @title.size = 22
        @coin_case = add_text(227, 172, 81, 24, '', 2, color: 7)
        @coin_case.bold = true
        @coin_case.size = 22
        @coin_gain = add_text(248, 203, 60, 24, '', 2, color: 7)
        @coin_gain.bold = true
        @coin_gain.size = 22
        @level = add_text(203, 203, 24, 24, '', color: 7)
        @level.bold = true
        @level.size = 22
      end
      # Set the title
      # @param value [String]
      def title=(value)
        @title.text = value.upcase
      end
      # Set the coin case content value
      # @param value [Integer]
      def coin_case=(value)
        @coin_case.text = format(COIN_CASE_FORMAT, value.to_i)
      end
      # Set the gain value
      # @param value [Integer]
      def coin_gain=(value)
        @coin_gain.text = format(COIN_GAIN_FORMAT, value.to_i)
      end
      # Set the level value
      # @param value [Integer]
      def level=(value)
        @level.text = format(ext_text(9000, 145), value)
      end
    end
    # Cursor shown in VoltorbFlip scene
    class Cursor < Sprite
      # The X coords on the board of the cursor
      # @return [Integer]
      attr_reader :board_x
      # The Y coords on the board of the cursor
      # @return [Integer]
      attr_reader :board_y
      # The cursor mode :normal, :memo
      # @return [Symbol]
      attr_reader :mode
      # Create a new cursor
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        set_bitmap('voltorbflip/markers', :interface)
        self.mode = :normal
        @move_count = false
        @board_x = 0
        @board_y = 0
        set_position(*get_board_position(@board_x, @board_y))
      end
      # Update the cursor mouvement, return true if the mouvement has been updated
      # @return [Boolean]
      def update_move
        return false unless @move_count
        cursor_duration = GamePlay::Casino::VoltorbFlip::CursorMoveDuration
        self.x = @move_data[0] + (@move_data[2] - @move_data[0]) * @move_count / cursor_duration
        self.y = @move_data[1] + (@move_data[3] - @move_data[1]) * @move_count / cursor_duration
        @move_count = false if (@move_count += 1) > cursor_duration
        return true
      end
      # Convert board coord in pixel coords
      # @param x [Integer] X position on the board
      # @param y [Integer] Y position on the board
      # @return [Array(Integer, Integer)] the pixel coordinate
      def get_board_position(x, y)
        if y > 4
          return GamePlay::Casino::VoltorbFlip::QuitDispX, GamePlay::Casino::VoltorbFlip::QuitDispY
        else
          if x > 4
            return GamePlay::Casino::VoltorbFlip::MemoDispX, GamePlay::Casino::VoltorbFlip::MemoDispY + y * ::GamePlay::Casino::VoltorbFlip::MemoTileSize
          else
            return GamePlay::Casino::VoltorbFlip::BoardDispX + x * ::GamePlay::Casino::VoltorbFlip::TileOffset, GamePlay::Casino::VoltorbFlip::BoardDispY + y * ::GamePlay::Casino::VoltorbFlip::TileOffset
          end
        end
      end
      # Start the cursor mouvement
      # @param dx [Integer] the number of case to move in x
      # @param dy [Integer] the number of case to move in y
      def move_on_board(dx, dy)
        if @board_y == 5 && dx != 0
          @board_x = (dx < 0 ? 4 : 5)
          @board_y = 4
        else
          @board_x += dx
          @board_y += dy
        end
        @board_x = 0 if @board_x < 0
        @board_y = 0 if @board_y < 0
        @board_x = 5 if @board_x > 5
        @board_y = 5 if @board_y > 5
        @move_count = 0
        @move_data = [x, y, *get_board_position(@board_x, @board_y)]
      end
      # Move the cursor to a dedicated board coordinate
      # @param board_x [Integer]
      # @param board_y [Integer]
      def moveto(board_x, board_y)
        set_position(*get_board_position(@board_x = board_x, @board_y = board_y))
      end
      # Set the cursor mode (affect src_rect)
      # @param value [Symbol]
      def mode=(value)
        @mode = value
        if value == :memo
          set_rect_div(1, 0, 6, 1)
        else
          set_rect_div(0, 0, 6, 1)
        end
      end
    end
    # Memo tiles in VoltorbFlip game
    class MemoTile < Sprite
      # Create a new MemoTile
      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport)
        @index = index
        set_bitmap('voltorbflip/memo_tiles', :interface)
        disable
      end
      # Tell if the tile is enabled
      # @return [Boolean]
      def enabled?
        return src_rect.y > 0
      end
      # Enable the tile
      def enable
        set_rect_div(@index, 1, 4, 2)
      end
      # Disable the tile
      def disable
        set_rect_div(@index, 0, 4, 2)
      end
    end
    # Board tile in VoltorbFlip game
    class BoardTile < SpriteStack
      # @return [Integer, :voltorb] Content of the tile
      attr_reader :content
      # Create a new BoardTile
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, default_cache: :interface)
        @tile_back = push(14, 14, 'voltorbflip/tiles')
        @tile_back.ox = 14
        @tile_back.oy = 14
        @tile_back.set_rect_div(0, 0, 5, 1)
        @tile_front = push(14, 14, 'voltorbflip/tiles')
        @tile_front.ox = 14
        @tile_front.oy = 14
        @tile_front.set_rect_div(0, 0, 5, 1)
        @tile_front.visible = false
        @markers = Array.new(4) do |i|
          s = push(-3, -3, 'voltorbflip/markers')
          s.set_rect_div(2 + i, 0, 6, 1)
          s.visible = false
          next((s))
        end
      end
      # Detect if the mouse is in the tile
      # @param mx [Integer] X coordinate of the mouse
      # @param my [Integer] Y coordinate of the mouse
      # @return [Boolean]
      def simple_mouse_in?(mx, my)
        return @tile_back.simple_mouse_in?(mx + @tile_back.ox, my + @tile_back.oy)
      end
      # Set the content of the tile (affect the src_rect of the front tile)
      # @param value [Integer, :voltorb]
      def content=(value)
        @content = value
        @tile_front.set_rect_div(value == :voltorb ? 1 : value + 1, 0, 5, 1)
      end
      # Toggle a memo marker
      # @param index [Integer] index of the memo in the marker array
      def toggle_memo(index)
        @markers[index].visible = !@markers[index].visible
      end
      # Reveal the tile
      def reveal
        return unless @tile_back.visible
        @animation = :reveal
        @animation_counter = 0
        @tile_back.visible = true
        @tile_front.visible = false
        @markers.each { |m| m.visible = false }
      end
      # Tell if the tile was revealed
      # @return [Boolean]
      def revealed?
        return @tile_front.visible
      end
      # Hide the tile
      def hide
        return unless @tile_front.visible
        @animation = :hide
        @animation_counter = 0
        @tile_back.visible = false
        @tile_front.visible = true
        @markers.each { |m| m.visible = false }
      end
      # Tell if the tile is hidden
      def hiden?
        return @tile_back.visible
      end
      # Update the animation of the tile
      # @return [Boolean] if the animation will still run
      def update_animation
        case @animation
        when :reveal
          return update_reveal_animation
        when :hide
          return update_hide_animation
        end
        return false
      end
      # Update the reveal animation
      # @return [Boolean] if the animation will still run
      def update_reveal_animation
        case @animation_counter
        when 0, 1, 2, 3, 4, 5, 6, 7
          @tile_back.zoom_x -= 1 / 8.0
        when 8
          @tile_back.visible = false
          @tile_back.zoom_x = 1
          @tile_front.visible = true
          @tile_front.zoom_x = 0
        when 9, 10, 11, 12, 13, 14, 15
          @tile_front.zoom_x += 1 / 8.0
        when 16
          @tile_front.zoom_x = 1
          @animation_counter = 0
          @animation = nil
          return self
        end
        @animation_counter += 1
        return !@animation.nil?
      end
      # Update the hide animation
      # @return [Boolean] if the animation will still run
      def update_hide_animation
        case @animation_counter
        when 0, 1, 2, 3, 4, 5, 6, 7
          @tile_front.zoom_x -= 1 / 8.0
        when 8
          @tile_front.visible = false
          @tile_front.zoom_x = 1
          @tile_back.visible = true
          @tile_back.zoom_x = 0
        when 9, 10, 11, 12, 13, 14, 15
          @tile_back.zoom_x += 1 / 8.0
        when 16
          @tile_back.zoom_x = 1
          @animation_counter = 0
          @animation = nil
          return self
        end
        @animation_counter += 1
        return !@animation.nil?
      end
    end
    # Board counter sprite
    class BoardCounter < SpriteStack
      # Create a new board counter
      # @param viewport [Viewport]
      # @param index [Integer] index of the counter
      # @param column [Boolean] if it's a counter in the column or in the row
      def initialize(viewport, index, column)
        super(viewport, default_cache: :interface)
        @tiles = []
        if column
          cx = GamePlay::Casino::VoltorbFlip::ColumnCoinDispX + index * GamePlay::Casino::VoltorbFlip::TileOffset
          cy = GamePlay::Casino::VoltorbFlip::ColumnCoinDispY
        else
          cx = GamePlay::Casino::VoltorbFlip::RowCoinDispX
          cy = GamePlay::Casino::VoltorbFlip::RowCoinDispY + index * GamePlay::Casino::VoltorbFlip::TileOffset
        end
        @coin_counter1 = push(cx, cy, 'voltorbflip/numbers')
        @coin_counter2 = push(cx + 7, cy, 'voltorbflip/numbers')
        @voltorb_counter = push(cx + 7, cy + 13, 'voltorbflip/numbers')
        @coin_counter1.set_rect_div(0, 0, 10, 1)
        @coin_counter2.set_rect_div(0, 0, 10, 1)
        @voltorb_counter.set_rect_div(0, 0, 10, 1)
      end
      # Return the count of voltorb
      # @return [Integer]
      def voltorb_count
        return @counter[0]
      end
      # Add a tile
      # @param tile [BoardTile] the added tile
      def add_tile(tile)
        @tiles.push tile
      end
      # Update the counter display according to the tile values
      def update_display
        counter = [0, 0]
        @tiles.each do |tile|
          if tile.content == :voltorb
            counter[0] += 1
          else
            counter[1] += tile.content
          end
        end
        @coin_counter1.set_rect_div(counter[1] / 10, 0, 10, 1)
        @coin_counter2.set_rect_div(counter[1] - (counter[1] / 10) * 10, 0, 10, 1)
        @voltorb_counter.set_rect_div(counter[0], 0, 10, 1)
        @counter = counter
      end
    end
    # Animations of the VoltorbFlip game
    class Animation < SpriteStack
      # Create a new animation
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @animation = nil
        @sprite = push(0, 0, '')
      end
      # Animate a tile
      # @param tile [BoardTile]
      def animate(tile)
        if (@animation = tile.content) == :voltorb
          @sprite.set_bitmap('voltorbflip_explode', :animation)
          @sprite.set_rect_div(0, 0, 8, 1)
          @sprite.ox = 4
          @sprite.oy = 5
        else
          @sprite.set_bitmap('voltorbflip_number', :animation)
          @sprite.set_rect_div(0, 0, 4, 1)
          @sprite.ox = 1
          @sprite.oy = 2
        end
        @counter = 0
        @sprite.x = tile.x
        @sprite.y = tile.y
        @sprite.ox += @sprite.src_rect.width / 4
        @sprite.oy += @sprite.src_rect.height / 4
        @sprite.visible = true
      end
      # Update the animation
      # @return [Boolean] if the animation was updated
      def update_animation
        case @animation
        when :voltorb
          update_voltorb_animation
        when 1, 2, 3
          update_number_animation
        else
          return false
        end
        return true
      end
      private
      # Update the voltorb animation
      def update_voltorb_animation
        case @counter
        when 1
          $game_system.bgm_memorize
          $game_system.bgm_fade(0.5)
        when 12
          Audio.se_play('Audio/SE/voltorbflip/volt_boom', 120)
          @sprite.set_rect_div(@counter / 6, 0, 8, 1)
        when 6, 18, 24, 30, 36
          @sprite.set_rect_div(@counter / 6, 0, 8, 1)
        when 42
          @sprite.visible = false
          @animation = nil
        end
        @counter += 1
      end
      # Update the number animation
      def update_number_animation
        case @counter
        when 0
          Audio.se_play('Audio/SE/voltorbflip/volt_card_play', 120)
        when 6, 12, 18
          @sprite.set_rect_div(@counter / 6, 0, 4, 1)
        when 24
          @sprite.visible = false
          @animation = nil
        end
        @counter += 1
      end
    end
  end
end
module GamePlay
  module Casino
    # Scene of the Slot Machines
    class SlotMachine < BaseCleanUpdate::FrameBalanced
      include UI::Casino
      # PAYOUT associated to each values
      PAYOUT_VALUES = {1 => 3, 2 => 300, 6 => 300, 3 => 12, 4 => 6}
      # Actions for the mouse
      ACTIONS = %i[action_b action_b action_b action_b]
      # Create a new SlotMachine Scene
      # @param speed [Integer] speed of the machine
      def initialize(speed)
        super()
        @speed = speed
        @update_input_method = :update_input_pay
        @payout = 1
      end
      # Update the inputs of the slot machines
      def update_inputs
        return send(@update_input_method)
      end
      # Update the graphics of the slot machines
      def update_graphics
        @bands.each(&:update)
        @credit_display.update
        @payout_display.update
      end
      # Amount of coin the player has
      # @return [Integer]
      def player_coin
        $game_variables[Yuki::Var::CoinCase]
      end
      # Set the number of coin the player has
      # @param coins [Integer]
      def player_coin=(coins)
        $game_variables[Yuki::Var::CoinCase] = coins
      end
      private
      # Input update when we want the player to pay
      def update_input_pay
        return @running = false if player_coin <= 0
        if Input.trigger?(:A)
          return play_buzzer_se if player_coin < @payout
          play_decision_se
          self.player_coin -= @payout
          @credit_display.target = player_coin
          @bands.each { |band| band.locked = false }
          @update_input_method = :update_input_band
        else
          if Input.trigger?(:B)
            action_b
          else
            if index_changed(:@payout, :DOWN, :UP, 3, 1)
              play_cursor_se
              @payout_display.number = @payout
            else
              return true
            end
          end
        end
        return false
      end
      # Input update when we want the player to stop bands
      def update_input_band
        if @bands.all?(&:locked)
          if animation_done?
            @update_input_method = :update_input_pay
          end
          return false
        else
          if Input.trigger?(:LEFT) && !@bands[0].locked
            play_cursor_se
            @bands[0].locked = true
          else
            if Input.trigger?(:UP) && !@bands[1].locked
              play_cursor_se
              @bands[1].locked = true
            else
              if Input.trigger?(:RIGHT) && !@bands[2].locked
                play_cursor_se
                @bands[2].locked = true
              else
                return true
              end
            end
          end
        end
        make_new_payout if @bands.all?(&:locked)
        return false
      end
      def update_mouse(moved)
        return if @update_input_method != :update_input_pay
        update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS, true)
      end
      def action_b
        play_cancel_se
        @running = false
      end
      # Tell if the animationes are done
      # @return [Boolean]
      def animation_done?
        @bands.all?(&:done?) && @credit_display.done? && @payout_display.done?
      end
      # Function that makes the new payout
      def make_new_payout
        payout_value = calculate_payout
        if payout_value == :replay
          return @bands.each { |band| band.locked = false }
        end
        @payout_display.number = payout_value
        @payout_display.target = @payout
        @credit_display.target = (self.player_coin += payout_value)
      end
      # Function that calculate the payout depending on the rows
      # @return [Integer, :replay]
      def calculate_payout
        rows = all_rows
        rows.each do |row|
          val = row.first
          if row.all? { |value| value == val }
            payout = PAYOUT_VALUES[val]
            return payout if payout
            return :replay if val == 0
          end
        end
        rows.each do |row|
          return 2 if row.count(5) == 1
          return 4 if row.count(5) == 2
          return 90 if row.count(2) == 2 && row.count(6) == 1
          return 90 if row.count(2) == 1 && row.count(6) == 2
        end
        return 0
      end
      # Function that returns the row depending on the payout
      # @return [Array<Array<Integer>>]
      def all_rows
        return [@bands.collect(&:value)] if @payout == 1
        all_rows = Array.new(3) { |row| @bands.collect { |band| band.value(row) } }
        return all_rows if @payout == 2
        all_rows << @bands.collect.with_index { |band, i| band.value(i) }
        all_rows << @bands.collect.with_index { |band, i| band.value(2 - i) }
        return all_rows
      end
      # Create all the required sprites
      def create_graphics
        create_viewport
        create_base_ui
        create_credit_payout
        create_bands
      end
      # Create the base UI of the slot machine
      def create_base_ui
        @base_ui = BaseUI.new(@viewport, button_texts)
      end
      # Get the button text for the generic UI
      # @return [Array<String>]
      def button_texts
        return [nil, nil, nil, ext_text(9000, 115)]
      end
      def create_credit_payout
        @credit_display = NumberDisplay.new(@viewport, 114, 188, 7)
        @credit_display.number = player_coin
        @payout_display = NumberDisplay.new(@viewport, 174, 188, 3)
        @payout_display.number = @payout
      end
      def create_bands
        @bands = Array.new(3) do |i|
          BandDisplay.new(@viewport, 104 + i * 40, 64, create_band_array, @speed)
        end
        BandDisplay.dispose_images
      end
      # Function that creates a band array
      # @return [Array<Integer>]
      def create_band_array
        band = (0...BandDisplay::FILES.size).to_a.shuffle
        return band + band[0, 3]
      end
    end
    # @private
    class VoltorbFlip < Base
      # Duration of the increment duration in frame
      # @return [Float]
      IncrementDuration = 20.0
      BoardDispX = 6
      BoardDispY = 42
      MemoDispX = 199
      MemoDispY = 44
      MemoTileDispOffX = 3
      MemoTileDispOffY = 2
      QuitDispX = 166
      QuitDispY = 202
      TileSize = 28
      TileOffset = 32
      MemoTileSize = 23
      ColumnCoinDispX = BoardDispX + MemoTileDispOffX + 9
      ColumnCoinDispY = BoardDispY + 5 * TileOffset + MemoTileDispOffY
      RowCoinDispX = BoardDispX + 5 * TileOffset + MemoTileDispOffX + 9
      RowCoinDispY = BoardDispY + MemoTileDispOffY
      CursorMoveDuration = 8.0
      # The amount of coin in the coin case
      # @return [Integer]
      attr_accessor :coin_case
      # Create the Voltorb Flip interface
      def initialize
        super()
        @coin_case = $game_variables[Yuki::Var::CoinCase]
        @coin_gain = 0
        @coin_case_increase = [0, 0]
        @coin_gain_increase = [0, 0]
        @state = 0
        @level = 1
        @viewport = Viewport.create(:main, @message_window.z - 100)
        @over_viewport = Viewport.create(:main, @message_window.z - 1)
        create_background
        create_texts
        create_board
        create_memo
        Graphics.sort_z
        generate_board
        @cursor = UI::VoltorbFlip::Cursor.new(viewport)
        @black = Sprite.new(@over_viewport).set_bitmap('transparent_black', :interface)
      end
      # Create the background sprite
      def create_background
        @background = Sprite.new(@viewport).set_bitmap('voltorbflip/empty_board', :interface)
      end
      # Initialize the texts
      def create_texts
        @ui_texts = UI::VoltorbFlip::Texts.new(@viewport)
        @ui_texts.title = ext_text(9000, 123)
        update_coin
      end
      # create the game board
      def create_board
        @board_tiles = []
        @board_counters = Array.new(5) { |i| UI::VoltorbFlip::BoardCounter.new(@viewport, i, true) } + Array.new(5) { |i| UI::VoltorbFlip::BoardCounter.new(@viewport, i, false) }
        0.upto(4) do |bx|
          0.upto(4) do |by|
            rx = BoardDispX + 3 + bx * TileOffset
            ry = BoardDispY + 3 + by * TileOffset
            s = UI::VoltorbFlip::BoardTile.new(viewport)
            s.set_position(rx, ry)
            s.content = 1
            @board_tiles.push s
            @board_counters[5 + by].add_tile(s)
            @board_counters[bx].add_tile(s)
          end
        end
        @quit_button = Sprite.new(viewport).set_bitmap('voltorbflip/markers', :interface).set_rect_div(0, 0, 6, 1)
        @quit_button.set_position(QuitDispX, QuitDispY).opacity = 0
        @animation_sprite = UI::VoltorbFlip::Animation.new(@over_viewport)
      end
      # Create the memo content
      def create_memo
        @memo_sprites = []
        4.times do |index|
          s = UI::VoltorbFlip::MemoTile.new(@viewport, index)
          s.set_position(MemoDispX + MemoTileDispOffX, MemoDispY + MemoTileDispOffY + index * MemoTileSize)
          @memo_sprites[index] = s
        end
        @memo_disabler = Sprite.new(viewport).set_bitmap('voltorbflip/memo_button', :interface).set_rect_div(1, 0, 2, 1)
        @memo_disabler.set_position(MemoDispX + MemoTileDispOffX - 1, MemoDispY + MemoTileDispOffY + 4 * MemoTileSize)
      end
      # Update the scene
      def update
        return unless super
        return if update_tiles_animation
        return if @cursor.update_move
        return if update_coin
        return if update_state
        @no_animation = false
        update_input_dir
        update_input
      end
      # Update the game state
      def update_state
        return (@running = false) if @state == 999
        case (@state / 100)
        when 0
          return update_state_menu
        when 1
          return update_state_play
        when 2
          return update_state_win
        when 3
          return update_state_fail
        when 4
          return update_suspens
        end
        return false
      end
      def update_state_menu
        case @state
        when 0
          @black.visible = true
          @player_choice = display_message(ext_text(9000, 124))
          @state += 1
        when 1
          @black.visible = true
          @player_choice = display_message(ext_text(9000, 125) % @level, 1, ext_text(9000, 126), ext_text(9000, 127), ext_text(9000, 128))
          if @player_choice == 0
            @state += 1
          else
            if @player_choice == 1
              @state = 10
            else
              @state = 999
            end
          end
        when 2
          @no_animation = true
          @board_tiles.each(&:hide)
          @state += 1
        when 3
          generate_board(@level)
          @black.visible = false
          @state = 100
        when 10
          @player_choice = display_message(ext_text(9000, 129), 1, ext_text(9000, 130), ext_text(9000, 131), ext_text(9000, 132), ext_text(9000, 133))
          if @player_choice == 0
            display_message(ext_text(9000, 134))
          else
            if @player_choice == 1
              display_message(ext_text(9000, 135))
            else
              if @player_choice == 2
                display_message(ext_text(9000, 136))
              else
                @state = 1
              end
            end
          end
        end
        return true
      end
      def update_state_play
        case @state
        when 100
          if get_board_points(true) == get_board_points
            on_win
            return true
          end
        when 110
          @player_choice = display_message(ext_text(9000, 137) % @coin_gain, 1, ext_text(9000, 95), ext_text(9000, 96))
          if @player_choice == 0
            display_message(ext_text(9000, 138) % @coin_gain)
            @coin_case_increase = get_increment(@coin_case, @coin_case + @coin_gain)
            @state += 1
          else
            @state = 100
          end
        when 111
          @no_animation = true
          @board_tiles.each(&:reveal)
          @state += 1
          return true
        when 112
          @last_level = @level
          @level = 1
          if @last_level > @level
            display_message(ext_text(9000, 139) % @level)
          end
          @coin_gain = 0
          @state = 1
        end
        return false
      end
      def update_state_win
        case @state
        when 200
          Audio.se_play('Audio/SE/voltorbflip/volt_extra_pay')
          display_message(ext_text(9000, 140))
          display_message(ext_text(9000, 141))
          display_message(ext_text(9000, 142) % @coin_gain)
          @state += 1
        when 201
          @coin_case_increase = get_increment(@coin_case, @coin_case + @coin_gain)
          @state += 1
        when 202
          @coin_gain_increase = get_increment(@coin_gain, 0)
          @state += 1
        when 203
          @no_animation = true
          @board_tiles.each(&:reveal)
          @coin_gain = 0
          @state += 1
        when 204
          @last_level = @level
          @level = [@level + 1, 5].min
          if @last_level < @level
            display_message(ext_text(9000, 143) % @level)
          end
          @state = 1
        end
        return true
      end
      def update_state_fail
        case @state
        when 300
          @counter = 0
          @state += 1
        when 301
          @state += 1 unless (@counter += 1) < 40
        when 302
          Audio.se_play('Audio/SE/voltorbflip/volt_fail', 120)
          @coin_gain_increase = get_increment(@coin_gain, 0)
          @state += 1
        when 303
          @last_level = @level
          @level = [@level, get_revealed_tile_count].min
          @coin_gain = 0
          @no_animation = true
          @board_tiles.each(&:reveal)
          @counter = 0
          @state += 1
        when 304
          @state += 1 unless (@counter += 1) < 120
        when 305
          display_message(ext_text(9000, 144))
          if @last_level > @level
            display_message(ext_text(9000, 139) % @level)
          end
          $game_system.bgm_restore
          @state = 1
        end
        return true
      end
      def update_suspens
        case @state
        when 400
          $game_system.bgm_memorize
          $game_system.bgm_fade(0.5)
          @counter = 0
          @state += 1
        when 401
          @state += 1 unless (@counter += 1) < 20
        when 402
          Audio.se_play('Audio/se/voltorbflip/volt_suspense')
          @counter = 0
          @state += 1
        when 403
          @state += 1 unless (@counter += 1) < 200
        when 404
          index = (@cursor.board_x * 5 + @cursor.board_y)
          if reveal(index)
            @state = 100
          end
          $game_system.bgm_restore
        end
        return true
      end
      # Update coin values and texts. Return true if the value is incrementing and the update must stop
      # @return [Boolean]
      def update_coin
        @ui_texts.coin_case = @coin_case
        @ui_texts.coin_gain = @coin_gain
        @ui_texts.level = @level
        if incrementing?
          @coin_case += @coin_case_increase[0]
          if @coin_case >= @coin_case_increase[1] && @coin_case_increase[0] > 0 || @coin_case <= @coin_case_increase[1] && @coin_case_increase[0] < 0
            @coin_case_increase = [0, 0]
            @coin_case = @coin_case.to_i
          end
          @coin_gain += @coin_gain_increase[0]
          if @coin_gain >= @coin_gain_increase[1] && @coin_gain_increase[0] > 0 || @coin_gain <= @coin_gain_increase[1] && @coin_gain_increase[0] < 0
            @coin_gain_increase = [0, 0]
            @coin_gain = @coin_gain.to_i
          end
          return true
        end
        return false
      ensure
        $game_variables[Yuki::Var::CoinCase] = @coin_case.to_i
      end
      # Update the keyboard inpute
      def update_input
        process_mouse_click if Mouse.trigger?(:mouse_left)
        process_button_A if Input.trigger?(:A)
        on_quit_button if Input.trigger?(:B)
      end
      # Update the keyboard direction input
      def update_input_dir
        case Input.dir4
        when 2
          @cursor.move_on_board(0, 1)
        when 4
          @cursor.move_on_board(-1, 0)
        when 6
          @cursor.move_on_board(1, 0)
        when 8
          @cursor.move_on_board(0, -1)
        end
      end
      # Update the tiles animation
      # @return [Boolean]
      def update_tiles_animation
        result = false
        @board_tiles.each do |tile|
          temp = tile.update_animation
          result ||= temp
        end
        unless @no_animation
          result ||= @animation_sprite.update_animation
          @animation_sprite.animate(result) if result.is_a?(UI::VoltorbFlip::BoardTile)
        end
        return (result == true)
      end
      # Update the cursor mode to normal or memo
      def update_cursor_mode
        @cursor.mode = @memo_sprites.select(&:enabled?).empty? ? :normal : :memo
      end
      # Process the A button
      def process_button_A
        if @cursor.board_x == 5 && @cursor.board_y <= 4
          on_memo_activate
        else
          if @cursor.board_y == 5
            on_quit_button
          else
            on_board_activate
          end
        end
      end
      # Process the click on the screen
      def process_mouse_click
        mx = Mouse.x
        my = Mouse.y
        @memo_sprites.each_with_index do |memo, index|
          next unless memo.simple_mouse_in?(mx, my)
          @cursor.moveto(5, index)
          on_memo_activate(index)
          break
        end
        if @memo_disabler.simple_mouse_in?(mx, my)
          @cursor.moveto(5, 4)
          on_memo_activate(4)
        end
        if @quit_button.simple_mouse_in?(mx, my)
          @cursor.moveto(5, 5)
          on_quit_button
        end
        @board_tiles.each_with_index do |tile, index|
          next unless tile.simple_mouse_in?(mx, my)
          x = (index / 5)
          y = index - 5 * x
          @cursor.moveto(x, y)
          on_board_activate(index)
        end
      end
      # Called when the memo is activated
      # @param y [Integer, @cursor.board_y] the row in the memo
      def on_memo_activate(y = @cursor.board_y)
        @memo_sprites.each_with_index do |memo, index|
          if index == y
            memo.enable
            @memo_disabler.set_rect_div(0, 0, 2, 1)
          else
            memo.disable
          end
        end
        @memo_disabler.set_rect_div(1, 0, 2, 1) if y == 4
        update_cursor_mode
      end
      # Called when the quit button is activated
      def on_quit_button
        @state = 110
      end
      # Called when the board is activated.
      # @param index [Integer, nil] the index of the activate tile (by default the one under the cursor).
      def on_board_activate(index = nil)
        index ||= (@cursor.board_x * 5 + @cursor.board_y)
        return if @board_tiles[index].revealed?
        if @cursor.mode == :normal
          x = (index / 5)
          y = index - 5 * x
          h_counter = @board_counters[x]
          v_counter = @board_counters[5 + y]
          if h_counter.voltorb_count + v_counter.voltorb_count >= 5
            @state = 400
          else
            reveal(index)
          end
        else
          memo_index = @memo_sprites.index(@memo_sprites.select(&:enabled?).first)
          @board_tiles[index].toggle_memo(memo_index)
        end
      end
      def reveal(index)
        @board_tiles[index].reveal
        if @board_tiles[index].content.is_a?(Integer)
          @coin_gain = 1 if @coin_gain == 0
          old_coin_gain = n_coin_gain = @coin_gain
          n_coin_gain *= @board_tiles[index].content
          @coin_gain_increase = get_increment(old_coin_gain, n_coin_gain) if old_coin_gain != n_coin_gain
          return true
        else
          on_fail
          return false
        end
      end
      def on_fail
        @state = 300
      end
      def on_win
        @state = 200
      end
      # Generate the board with the matching level
      # @param level [Integer, 1] the level of the board to generate
      def generate_board(level = 1)
        point_count = 24
        voltorb_count = 5 + 2 * level
        chance_3 = [0, 50, 60, 60, 70, 70][level]
        data = Table.new 5, 5
        available_coords = []
        point_coords = []
        5.times do |x|
          5.times do |y|
            available_coords.push [x, y]
          end
        end
        available_coords.shuffle!
        available_coords.each do |coords|
          v_row = 0
          v_col = 0
          5.times do |y|
            v_row += 1 if data[coords[0], y] < 0
          end
          5.times do |x|
            v_col += 1 if data[x, coords[1]] < 0
          end
          if v_row < 4 && v_col < 4 && voltorb_count > 0
            data[coords[0], coords[1]] = -1
            voltorb_count -= 1
          else
            data[coords[0], coords[1]] = 1
            point_count -= 1
            point_coords.push coords
          end
        end
        while point_count > 0
          c = point_coords.select do |a|
            if data[a[0], a[1]] == 2
              next(rand(100) < chance_3)
            else
              next(true)
            end
          end.first
          data[c[0], c[1]] += 1
          point_coords.delete(c) if data[c[0], c[1]] >= 3
          point_count -= 1
        end
        5.times do |x|
          5.times do |y|
            @board_tiles[x * 5 + y].content = (data[x, y] > 0 ? data[x, y] : :voltorb)
          end
        end
        @board_counters.each(&:update_display)
      end
      # Calculate the current point of the game
      # @param with_hided [Boolean, false] indicate if the hided tiles must be count too
      # @return [Integer]
      def get_board_points(with_hided = false)
        points = 0
        5.times do |x|
          5.times do |y|
            tile = @board_tiles[x * 5 + y]
            if tile.content.is_a?(Integer) && (with_hided || tile.revealed?)
              points = 1 if points.zero?
              points *= tile.content
            end
          end
        end
        return points
      end
      def get_revealed_tile_count
        return @board_tiles.select(&:revealed?).length
      end
      # Test if the coins are incrementing
      # @return [Boolean]
      def incrementing?
        return !(@coin_case_increase[0].zero? && @coin_gain_increase[0].zero?)
      end
      # Calculate the increment value [step, target]
      # @return [Array<Float, Integer>]
      def get_increment(from, to)
        return [(to - from) / IncrementDuration, to]
      end
      def create_graphics
      end
    end
  end
  # @private
  class Alph_Ruins_Puzzle
    #Choix des fichiers son
    #SE
    MOVESOUND1 = 'Audio/SE/psn'
    #mouvement sans piece
    MOVESOUND2 = 'Audio/SE/hitlow'
    #mouvement avec piece
    PLACESOUND = MOVESOUND2
    #pose de piece
    TAKESOUND = nil
    #prise de piece
    #BGM
    VICTORY_THEME = 'Audio/ME/ROSA_YourPokemonEvolved.ogg'
    #Images
    GR_CursorB = 'Puzzle_Ruines Curseur_b'
    GR_Cursor = 'Puzzle_Ruines Curseur'
    GR_Background = 'Puzzle_Ruines Fond'
    GR_Background2 = 'Puzzle_Ruines Fond2'
    #> Offset
    BaseOffsetX = 112 - 24
    BaseOffsetY = 72 - 24
    def initialize(id, id_switch)
      @viewport = Viewport.create(:main, 100)
      @id_switch = id_switch
      @background = Plane.new(@viewport)
      @background.bitmap = RPG::Cache.interface(GR_Background)
      @background2 = Sprite.new(@viewport)
      @background2.bitmap = RPG::Cache.interface(GR_Background2)
      @background2.x = 112
      @background2.y = 72
      @grid = Array.new(6) {Array.new(6) }
      @pieces = []
      @cursor_piece = nil
      @cursor = Sprite.new(@viewport)
      @cursor.bitmap = RPG::Cache.interface(GR_Cursor)
      @cursor.z = 9001
      @cursor_x = 0
      @cursor_y = 0
      @cursor_wait = 0
      bmp = RPG::Cache.interface("Puzzle_Ruines #{id}")
      @pieces = Array.new(16) do |i|
        img = Sprite.new(@viewport)
        img.bitmap = bmp
        img.src_rect.set(24 * (i / 4), 24 * (i % 4), 24, 24)
        next((img))
      end
      @pieces.each do |piece|
        verif = false
        until verif
          a = rand(3)
          case a
          when 0
            b = rand(6)
            if @grid[0][b] == nil
              verif = true
              @grid[0][b] = piece
            end
          when 1
            b = rand(6)
            if @grid[5][b] == nil
              verif = true
              @grid[5][b] = piece
            end
          when 2
            b = rand(4)
            if @grid[b + 1][0] == nil
              verif = true
              @grid[b + 1][0] = piece
            end
          end
        end
      end
      pieces_position
      @viewport.sort_z
    end
    def main
      Graphics.transition
      while $scene == self
        Graphics.update
        update
        if victory_check
          $game_switches[@id_switch] = true
          if VICTORY_THEME
            Audio.me_play(VICTORY_THEME)
            wait(80)
            wait_hit
            $scene = Scene_Map.new
          else
            wait(120)
            $scene = Scene_Map.new
          end
        end
      end
      Graphics.freeze
      dispose
    end
    def update
      if @cursor_piece == nil
        @cursor_wait += 1
        @cursor_wait = 0 if @cursor_wait > 40
        @cursor.opacity = 0 if @cursor_wait == 20
        @cursor.opacity = 255 if @cursor_wait == 0
      end
      if Input.trigger?(:B)
        return $scene = Scene_Map.new
      else
        if Input.trigger?(:DOWN)
          unless @cursor_y >= 5 || (@cursor_y == 4 && @cursor_x != 0 && @cursor_x != 5)
            @cursor_y += 1
            move
          end
        else
          if Input.trigger?(:UP)
            unless @cursor_y == 0
              @cursor_y -= 1
              move
            end
          else
            if Input.trigger?(:RIGHT)
              unless @cursor_x >= 5 || @cursor_y == 5
                @cursor_x += 1
                move
              end
            else
              if Input.trigger?(:LEFT)
                unless @cursor_x == 0 || @cursor_y == 5
                  @cursor_x -= 1
                  move
                end
              else
                if Input.trigger?(:A)
                  if @cursor_piece == nil
                    if @grid[@cursor_x][@cursor_y]
                      wait 4
                      @cursor_piece = @grid[@cursor_x][@cursor_y]
                      @grid[@cursor_x][@cursor_y] = nil
                      Audio.se_play(TAKESOUND, 80) if TAKESOUND
                      @cursor.bitmap = RPG::Cache.interface(GR_CursorB)
                      @cursor.opacity = 255
                      @cursor_wait = 0
                    end
                  else
                    if @grid[@cursor_x][@cursor_y] == nil
                      wait 4
                      @grid[@cursor_x][@cursor_y] = @cursor_piece
                      @cursor_piece = nil
                      Audio.se_play(PLACESOUND) if PLACESOUND
                      @cursor.bitmap = RPG::Cache.interface(GR_Cursor)
                    end
                  end
                else
                  return
                end
              end
            end
          end
        end
      end
      pieces_position
    end
    def dispose
      @background.dispose
      @background2.dispose
      @cursor.dispose
      @pieces.each do |p|
        p.dispose
      end
    end
    def victory_check
      4.times do |x|
        4.times do |y|
          if @grid[x + 1][y + 1] != @pieces[y + (4 * x)]
            return false
          end
        end
      end
      return true
    end
    def pieces_position
      @cursor.x = BaseOffsetX + @cursor_x * 24
      @cursor.y = BaseOffsetY + @cursor_y * 24
      for piece in @pieces
        if @cursor_piece == piece
          piece.x = BaseOffsetX + @cursor_x * 24
          piece.y = BaseOffsetY + @cursor_y * 24
          piece.z = 1
        else
          for line in @grid
            if line.include?(piece)
              x = @grid.index(line).to_i
              y = line.index(piece).to_i
              piece.x = BaseOffsetX + x * 24
              piece.y = BaseOffsetY + y * 24
              piece.z = 0
            end
          end
        end
      end
    end
    def wait(x)
      Graphics.wait(x * 3 / 2)
    end
    def wait_hit
      until Input.trigger?(:A) || Input.trigger?(:B)
        Graphics.update
      end
    end
    def move
      if @cursor_piece == nil
        Audio.se_play(MOVESOUND1, 80) if MOVESOUND1
        wait(5)
        @cursor.opacity = 255
        @cursor_wait = 0
      else
        Audio.se_play(MOVESOUND2, 80) if MOVESOUND2
        wait(5)
      end
    end
  end
end
class Interpreter
  # Start the Alpha Ruins puzzle
  # @param id [Integer] ID of the puzzle (see graphics/interface/puzzle_ruines files)
  # @param id_switch [Integer] ID of the switch to enable when winning
  def puzzle_alpha(id = 1, id_switch = Yuki::Sw::RuinsVictory)
    $game_switches[id_switch] = false
    $scene = GamePlay::Alph_Ruins_Puzzle.new(id, id_switch)
    @wait_count = 2
  end
end
