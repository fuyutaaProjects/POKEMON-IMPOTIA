# Module that holds every UI object
module UI
  # Class that helps to define a single object constitued of various sprites.
  # With this class you can move the sprites as a single sprite, change the data that generate the sprites and some other cool stuff
  class SpriteStack
    # Constant specifiying the sprite will have no image during initialization
    NO_INITIAL_IMAGE = nil
    # X coordinate of the sprite stack
    # @return [Numeric]
    attr_reader :x
    # Y coordinate of the sprite stack
    # @return [Numeric]
    attr_reader :y
    # Data used by the sprites of the sprite stack to generate themself
    attr_reader :data
    # Get the stack
    attr_reader :stack
    # Get the viewport
    # @return [Viewport]
    attr_reader :viewport
    # Create a new Sprite stack
    # @param viewport [Viewport] the viewport where the sprites will be shown
    # @param x [Numeric] the x position of the sprite stack
    # @param y [Numeric] the y position of the sprite stack
    # @param default_cache [Symbol] the RPG::Cache function to call when setting the bitmap
    def initialize(viewport, x = 0, y = 0, default_cache: :interface)
      @viewport = viewport
      @stack = []
      @x = x
      @y = y
      @default_cache = default_cache
    end
    # Push a sprite to the stack
    # @param x [Numeric] the relative x position of the sprite in the stack (sprite.x = stack.x + x)
    # @param y [Numeric] the relative y position of the sprite in the stack (sprite.y = stack.y + y)
    # @param args [Array] the arguments after the viewport argument of the sprite to create the sprite
    # @param rect [Array, nil] the src_rect.set arguments if required
    # @param type [Class] the class to use to generate the sprite
    # @param ox [Numeric] the ox of the sprite
    # @param oy [Numeric] the oy of the sprite
    # @return [Sprite] the pushed sprite
    def push(x, y, bmp, *args, rect: nil, type: Sprite, ox: 0, oy: 0)
      sprite = type.new(@viewport, *args)
      sprite.set_position(@x + x, @y + y).set_origin(ox, oy)
      sprite.set_bitmap(bmp, @default_cache) if bmp
      sprite.src_rect.set(*rect) if rect.is_a?(Array)
      sprite.src_rect = rect if rect.is_a?(Rect)
      return push_sprite(sprite)
    end
    alias add_sprite push
    # Add a text inside the stack, the offset x/y will be adjusted
    # @param x [Integer] the x coordinate of the text surface
    # @param y [Integer] the y coordinate of the text surface
    # @param width [Integer] the width of the text surface
    # @param height [Integer, nil] the height of the text surface (if nil, uses the line_height from sizeid)
    # @param str [String] the text shown by this object
    # @param align [0, 1, 2] the align of the text in its surface (best effort => no resize), 0 = left, 1 = center, 2 = right
    # @param outlinesize [Integer, nil] the size of the text outline
    # @param type [Class] the type of text
    # @param color [Integer] the id of the color
    # @return [Text] the text object
    def add_text(x, y, width, height, str, align = 0, outlinesize = Text::Util::DEFAULT_OUTLINE_SIZE, type: Text, color: nil, sizeid: nil)
      height ||= Fonts.line_height(sizeid || @font_id.to_i)
      text = type.new(@font_id.to_i, @viewport, x + @x, y - Text::Util::FOY + @y, width, height, str, align, outlinesize, color, sizeid)
      text.draw_shadow = outlinesize.nil?
      @stack << text
      return text
    end
    # Push a background image
    # @param filename [String] name of the image in the cache
    # @param rect [Array, nil] the src_rect.set arguments if required
    # @param type [Class] the class to use to generate the sprite
    # @return [Sprite]
    def add_background(filename, type: Sprite, rect: nil)
      sprite = type.new(@viewport)
      sprite.set_position(@x, @y)
      sprite.set_bitmap(filename, @default_cache)
      sprite.src_rect.set(*rect) if rect.is_a?(Array)
      sprite.src_rect = rect if rect.is_a?(Rect)
      return push_sprite(sprite)
    end
    alias add_foreground add_background
    # Push a sprite object to the stack
    # @param sprite [Sprite, Text]
    # @return [sprite]
    def push_sprite(sprite)
      @stack << sprite
      return sprite
    end
    alias add_custom_sprite push_sprite
    # Execute push operations with an alternative cache
    #
    # @example
    #   with_cache(:pokedex) { add_background('win_sprite') }
    # @param cache [Symbol] function of RPG::Cache used to load images
    def with_cache(cache)
      last_cache = @default_cache
      @default_cache = cache
      yield
    ensure
      @default_cache = last_cache
    end
    # Execute add_text operation with an alternative font
    #
    # @example
    #   with_font(2) { add_text(0, 0, 320, 32, 'Big Text', 1) }
    # @param font_id [Integer] id of the font
    def with_font(font_id)
      last_font = @font_id
      @font_id = font_id
      yield
    ensure
      @font_id = last_font
    end
    # Execute add_line with specific metrics info
    # @example
    #   with_surface(x, y, unit_width, size_id) do
    #     add_line(0, "Centered", 1)
    #     add_line(1, "Left Red", color: 2)
    #     add_line(2, "Right Blue", 2, color: 1)
    #     add_line(0, "Centered on next surface", 1, dx: 1)
    #   end
    # @param x [Integer] X position of the surface
    # @param y [Integer] Y position of the surface
    # @param unit_width [Integer] Width of the line (for alignment and offset x)
    # @param size_id [Integer] Size to use to get the right metrics
    # @param offset_width [Integer] offset between each columns when dx: is used
    def with_surface(x, y, unit_width, size_id = 0, offset_width = 2)
      last_surface_x = @surface_x
      last_surface_y = @surface_y
      last_unit_width = @surface_width
      last_size_id = @surface_size_id
      last_offset_width = @surface_offset_width
      @surface_x = x
      @surface_y = y
      @surface_width = unit_width
      @surface_size_id = size_id
      @surface_offset_width = offset_width
      yield
    ensure
      @surface_x = last_surface_x
      @surface_y = last_surface_y
      @surface_width = last_unit_width
      @surface_size_id = last_size_id
      @surface_offset_width = last_offset_width
    end
    # Add a text inside the stack using metrics given by with_surface
    # @param line_index [Integer] index of the line in the surface
    # @param str [String] the text shown by this object
    # @param align [0, 1, 2] the align of the text in its surface (best effort => no resize), 0 = left, 1 = center, 2 = right
    # @param outlinesize [Integer, nil] the size of the text outline
    # @param type [Class] the type of text
    # @param color [Integer] the id of the color
    # @param dx [Integer] offset x to use "table like" display (this value is multiplied by width)
    # @return [Text] the text object
    def add_line(line_index, str, align = 0, outlinesize = Text::Util::DEFAULT_OUTLINE_SIZE, type: Text, color: nil, dx: 0)
      x = @surface_x + dx * (@surface_width + @surface_offset_width)
      y = @surface_y + line_index * (height = Fonts.line_height(@surface_size_id || @font_id.to_i))
      text = type.new(@font_id.to_i, @viewport, x + @x, y - Text::Util::FOY + @y, @surface_width, height, str, align, outlinesize, color, @surface_size_id)
      text.draw_shadow = outlinesize.nil?
      @stack << text
      return text
    end
    # Return an element of the stack
    # @param index [Integer] index of the element in the stack
    # @return [Sprite, Text]
    def [](index)
      @stack[index]
    end
    # Return the size of the stack
    # @return [Integer]
    def size
      @stack.size
    end
    alias length size
    # Change the x coordinate of the sprite stack
    # @param value [Numeric] the new value
    def x=(value)
      delta = value - @x
      @x = value
      @stack.each { |sprite| sprite.x += delta }
    end
    # Change the y coordinate of the sprite stack
    # @param value [Numeric] the new value
    def y=(value)
      delta = value - @y
      @y = value
      @stack.each { |sprite| sprite.y += delta }
    end
    # Change the x and y coordinate of the sprite stack
    # @param x [Numeric] the new x value
    # @param y [Numeric] the new y value
    # @return [self]
    def set_position(x, y)
      delta_x = x - @x
      delta_y = y - @y
      return move(delta_x, delta_y)
    end
    # Move the sprite stack
    # @param delta_x [Numeric] number of pixel the sprite stack should be moved in x
    # @param delta_y [Numeric] number of pixel the sprite stack should be moved in y
    # @return [self]
    def move(delta_x, delta_y)
      @x += delta_x
      @y += delta_y
      @stack.each { |sprite| sprite.set_position(sprite.x + delta_x, sprite.y + delta_y) }
      return self
    end
    # Set the origin (does nothing)
    # @param _ox [Integer] new origin x
    # @param _oy [Integer] new origin y
    # @note this function is only for compatibility, it does nothing
    def set_origin(_ox, _oy)
    end
    # If the sprite stack is visible
    # @note Return the visible property of the first sprite
    # @return [Boolean]
    def visible
      return false if @stack.empty?
      return @stack.first.visible
    end
    # Change the visible property of each sprites
    # @param value [Boolean]
    def visible=(value)
      @stack.each { |sprite| sprite.visible = value }
    end
    # Detect if the mouse is in the first sprite of the stack
    # @param mx [Numeric] mouse x coordinate
    # @param my [Numeric] mouse y coordinate
    # @return [Boolean]
    def simple_mouse_in?(mx = Mouse.x, my = Mouse.y)
      return false if @stack.empty?
      return @stack.first.simple_mouse_in?(mx, my)
    end
    # Translate the mouse coordinate to mouse position inside the first sprite of the stack
    # @param mx [Numeric] mouse x coordinate
    # @param my [Numeric] mouse y coordinate
    # @return [Array(Numeric, Numeric)]
    def translate_mouse_coords(mx = Mouse.x, my = Mouse.y)
      return 0, 0 if @stack.empty?
      return @stack.first.translate_mouse_coords(mx, my)
    end
    # Set the data source of the sprites
    # @param v [Object]
    def data=(v)
      @data = v
      @stack.each do |sprite|
        sprite.data = v if sprite.respond_to?(:data=)
      end
    end
    # yield a block on each sprite
    # @param block [Proc]
    def each(&block)
      return @stack.each unless block
      @stack.each(&block)
    end
    # Dispose each sprite of the sprite stack and clear the stack
    def dispose
      @stack.each(&:dispose)
      @stack.clear
    end
    # >>> Section from Yuki::Sprite <<<
    # If the sprite has a self animation
    # @return [Boolean]
    attr_accessor :animated
    # If the sprite is moving
    # @return [Boolean]
    attr_accessor :moving
    # Update sprite (+move & animation)
    def update
      update_animation(false) if @animated
      update_position if @moving
      @stack.each { |sprite| sprite.update if sprite.respond_to?(:update) }
    end
    # Move the sprite to a specific coordinate in a certain amount of frame
    # @param x [Integer] new x Coordinate
    # @param y [Integer] new y Coordinate
    # @param nb_frame [Integer] number of frame to go to the new coordinate
    def move_to(x, y, nb_frame)
      @moving = true
      @move_frame = nb_frame
      @move_total = nb_frame
      @new_x = x
      @new_y = y
      @del_x = self.x - x
      @del_y = self.y - y
    end
    # Update the movement
    def update_position
      @move_frame -= 1
      @moving = false if @move_frame == 0
      set_position(@new_x + (@del_x * @move_frame) / @move_total, @new_y + (@del_y * @move_frame) / @move_total)
    end
    # Start an animation
    # @param arr [Array<Array(Symbol, *args)>] Array of message
    # @param delta [Integer] Number of frame to wait between each animation message
    def anime(arr, delta = 1)
      @animated = true
      @animation = arr
      @anime_pos = 0
      @anime_delta = delta
      @anime_count = 0
    end
    # Update the animation
    # @param no_delta [Boolean] if the number of frame to wait between each animation message is skiped
    def update_animation(no_delta)
      unless no_delta
        @anime_count += 1
        return if @anime_delta > @anime_count
        @anime_count = 0
      end
      anim = @animation[@anime_pos]
      send(*anim) if anim[0] != :send && anim[0].class == Symbol
      @anime_pos += 1
      @anime_pos = 0 if @anime_pos >= @animation.size
    end
    # Force the execution of the n next animation message
    # @note this method is used in animation message Array
    # @param n [Integer] Number of animation message to execute
    def execute_anime(n)
      @anime_pos += 1
      @anime_pos = 0 if @anime_pos >= @animation.size
      n.times do
        update_animation(true)
      end
      @anime_pos -= 1
    end
    # Stop the animation
    # @note this method is used in the animation message Array (because animation loops)
    def stop_animation
      @animated = false
    end
    # Change the time to wait between each animation message
    # @param v [Integer]
    def anime_delta_set(v)
      @anime_delta = v
    end
    # Gets the opacity of the SpriteStack
    # @return [Integer]
    def opacity
      return 0 unless (sprite = @stack.first)
      return sprite.opacity
    end
    # Sets the opacity of the SpriteStack
    # @param value [Integer] the new opacity value
    def opacity=(value)
      @stack.each { |sprite| sprite.opacity = value if sprite.respond_to?(:opacity=) }
    end
    # Gets the z of the SpriteStack
    # @return [Numeric]
    def z
      return 0 unless (sprite = @stack.first)
      return sprite.z
    end
    # Sets the z of the SpriteStack
    def z=(value)
      @stack.each { |sprite| sprite.z = value }
    end
  end
  # Window utility allowing to make Window easilly
  class Window < ::Window
    # Default window skin
    DEFAULT_SKIN = 'message'
    # Create a new Window
    # @param viewport [Viewport] viewport where the window is shown
    # @param x [Integer] X position of the window
    # @param y [Integer] Y position of the window
    # @param width [Integer] Width of the window
    # @param height [Integer] Height of the window
    # @param skin [String] Windowskin used to display the window
    def initialize(viewport, x = 2, y = 2, width = 316, height = 48, skin: DEFAULT_SKIN)
      super(viewport)
      lock
      initialize_window_internal(x, y, width, height, skin)
      unlock
    end
    private
    def initialize_window_internal(x, y, width, height, skin)
      set_position(x, y)
      set_size(width, height)
      self.windowskin = RPG::Cache.windowskin(skin)
      self.window_builder = current_window_builder(skin)
    end
    public
    class << self
      # Create a new window from given metrics
      # @param viewport [Viewport] viewport where the window is shown
      # @param x [Integer] x position of the window frame
      # @param y [Integer] y position of the window frame
      # @param width [Integer] width of the window contents
      # @param height [Integer] height of the window contents
      # @param skin [String] windowskin used to draw the window frame:
      # @param position [String] precision of the x/y positioning of the frame
      #   - 'top_left' : y is top side of the frame, x is left side of the frame
      #   - 'top_right' : y is top side of the frame, x is right side of the frame
      #   - 'bottom_left' : y is bottom side of the frame, x is left side of the frame
      #   - 'bottom_right' : y is bottom side of the frame, x is right side of the frame
      #   - 'middle_center' : y is middle height of the frame, x is center of the frame
      def from_metrics(viewport, x, y, width, height, skin: DEFAULT_SKIN, position: 'top_left')
        wb = window_builder(skin)
        width = (wb[4] + wb[-2] + width)
        height = (wb[5] + wb[-1] + height)
        x -= width if position.include?('right')
        x -= width / 2 if position.include?('center')
        y -= height if position.include?('bottom')
        y -= height / 2 if position.include?('middle')
        return new(viewport, x, y, width, height, skin: skin)
      end
      # Get the Window Builder according to the skin
      # @param skin [String] windowskin used to show the window
      # @return [Array<Integer>] the window builder
      def window_builder(skin)
        return Configs.window.builders[:message_box] if skin[0, 2].casecmp?('m_')
        return Configs.window.builders[:generic]
      end
    end
    # Add a text to the window
    # @see https://psdk.pokemonworkshop.fr/yard/UI/SpriteStack.html#add_text-instance_method UI::SpriteStack#add_text
    def add_text(x, y, width, height, str, align = 0, outlinesize = Text::Util::DEFAULT_OUTLINE_SIZE, type: Text, color: 0)
      sprite_stack.add_text(x, y, width, height, str, align, outlinesize, type: type, color: color)
    end
    # Add a text line to the window
    # @see https://psdk.pokemonworkshop.fr/yard/UI/SpriteStack.html#add_line-instance_method UI::SpriteStack#add_line
    def add_line(line_index, str, align = 0, outlinesize = Text::Util::DEFAULT_OUTLINE_SIZE, type: Text, color: nil, dx: 0)
      sprite_stack.add_line(line_index, str, align, outlinesize, type: type, color: color, dx: dx)
    end
    # Push a sprite to the window
    # @see https://psdk.pokemonworkshop.fr/yard/UI/SpriteStack.html#push-instance_method UI::SpriteStack#push
    def push(x, y, bmp, *args, rect: nil, type: Sprite, ox: 0, oy: 0)
      sprite_stack.push(x, y, bmp, *args, rect: rect, type: type, ox: ox, oy: oy)
    end
    # Return the stack of the window if any
    # @return [Array]
    def stack
      return (@stack&.stack || [])
    end
    # Return the sprite stack used by the window
    # @return [SpriteStack]
    def sprite_stack
      @stack ||= SpriteStack.new(self)
    end
    # Load the cursor
    def load_cursor
      cursor_rect.set(0, 0, 16, 16)
      self.cursorskin = RPG::Cache.windowskin('cursor')
    end
    private
    # Retrieve the current window_builder
    # @param skin [String]
    # @return [Array]
    def current_window_builder(skin)
      Window.window_builder(skin)
    end
  end
  # Class that display a bar on screen using the whole texture to display the bar component
  class Bar
    # Returns the rate of the bar
    # @return [Numeric] 0 ~ 1
    attr_reader :rate
    # Return the data source to get the rate info through data=
    attr_accessor :data_source
    # Create a new bar
    # @param viewport [Viewport] the viewport in which the bar is shown
    # @param x [Integer] the x position of the bar
    # @param y [Integer] the y position of the bar
    # @param bmp [Texture] the texture of the bar (including the bar states)
    # @param bw [Integer] the bar width (progress part)
    # @param bh [Integer] the bar height (progress part)
    # @param bx [Integer] the x position of the bar inside the sprite
    # @param by [Integer] the y position of the bar inside the sprite
    # @param nb_states [Integer] the number of state the bar has
    # @param background_width [Integer] the bar width (background part). Useful if the bar has a different width than its real image
    def initialize(viewport, x, y, bmp, bw, bh, bx, by, nb_states, background_width = nil)
      @background = Sprite.new(viewport).set_bitmap(bmp)
      @background.src_rect.set(0, 0, background_width, bmp.height - nb_states * bh)
      @bar = Sprite.new(viewport).set_bitmap(bmp)
      @bar.src_rect.set(0, @background.src_rect.height, 0, @bh = bh)
      @nb_states = nb_states
      @bx = bx
      @by = by
      @bw = bw
      @bar.x = (@background.x = x) + bx
      @bar.y = (@background.y = y) + by
      @rate = 0
      @data_source = nil
    end
    # Change the rate of the bar
    # @param value [Numeric] 0 ~ 1
    def rate=(value)
      value = 0 if value <= 0
      value = 1 if value >= 1
      @rate = value
      state = (value * @nb_states).to_i
      state = @nb_states - 1 if state >= @nb_states
      w = (@bw * value).ceil
      w = 1 if w == 0 && value != 0
      @bar.src_rect.set(nil, @background.src_rect.height + @bh * state, w, nil)
    end
    # Change the visible state of the bar
    # @param value [Boolean]
    def visible=(value)
      @bar.visible = @background.visible = value
    end
    # Returns the visible state of the bar
    # @return [Boolean]
    def visible
      return @bar.visible
    end
    # Returns the x position of the bar
    # @return [Integer]
    def x
      return @background.x
    end
    # Returns the y position of the bar
    # @return [Integer]
    def y
      return @background.y
    end
    # Change the x position of the bar
    # @param value [Integer]
    def x=(value)
      @background.x = value
      @bar.x = value + @bx
    end
    # Change the y position of the bar
    # @param value [Integer]
    def y=(value)
      @background.y = value
      @bar.y = value + @by
    end
    # Change the position of the bar
    # @param x [Integer]
    # @param y [Integer]
    def set_position(x, y)
      @background.set_position(x, y)
      @bar.set_position(x + @bx, y + @by)
    end
    # Returns the z position of the bar
    # @return [Integer]
    def z
      return @background.z
    end
    # Change the z position of the bar
    # @param value [Numeric]
    def z=(value)
      @background.z = value
      @bar.z = value
    end
    # Dispose the bar
    def dispose
      @background.dispose
      @bar.dispose
    end
    # Change the data value (for SpriteStack usage)
    # @param data [Object] the data where we'll call the @data_source to get the actual rate
    def data=(data)
      return unless @data_source
      self.rate = data.send(*@data_source) if (self.visible = data)
    end
  end
  # Generica base UI for most of the scenes
  class GenericBase < SpriteStack
    # @return [Array<Symbol>] keys shown in the button
    attr_reader :keys
    # @return [Array<String>] the texts shown in the button
    attr_reader :button_texts
    # @return [Array<ControlButton>] the control buttons
    attr_reader :ctrl
    # @return [Sprite]
    attr_reader :background
    # List of key by default
    DEFAULT_KEYS = %i[A X Y B]
    # List of button to hide when a text is shown
    BUTTON_TO_HIDE = 0..2
    # Create a new GenericBase UI
    # @param viewport [Viewport]
    # @param texts [Array<String>] list of texts shown in the ControlButton
    # @param keys [Array<Symbol>] list of keys used in the ControlButton
    # @param hide_background_and_button [Boolean] tell if we don't want to show the button and its bar
    def initialize(viewport, texts = [], keys = DEFAULT_KEYS, hide_background_and_button: false)
      super(viewport)
      @keys = keys
      create_graphics
      self.button_texts = texts
      if hide_background_and_button
        @button_background.visible = false
        @ctrl.each { |button| button.visible = false }
      end
    end
    # Set the keys of the buttons
    # @param value [Array<Symbol>] the 4 key to show
    def keys=(value)
      @keys = value
      @ctrl.each_with_index { |button, index| button.key = value[index] }
    end
    # Set the texts of the buttons
    # @param value [Array<String>]
    def button_texts=(value)
      @button_texts = value
      @ctrl.each_with_index do |button, index|
        next unless (button.visible = !value[index].nil?)
        button.text = value[index]
      end
    end
    # Show the "win text" (bottom text giving information to the player)
    # @param text [String] text to show
    def show_win_text(text)
      hidden_button_indexes.each { |i| @ctrl[i].visible = false }
      text_sprite = win_text
      text_sprite.visible = true
      text_sprite.text = text
      @win_text_background.visible = true
    end
    # Hide the "win text"
    def hide_win_text
      hidden_button_indexes.each { |i| @ctrl[i].visible = true }
      win_text.visible = false
      @win_text_background.visible = false
    end
    # Tell if the win text is visible
    # @return [Boolean]
    def win_text_visible?
      @win_text_background&.visible
    end
    # Update the background animation
    def update_background_animation
      @on_update_background_animation&.call
      @background_animation&.update
    end
    private
    def create_graphics
      create_background
      create_button_background
      create_control_button
    end
    def create_background
      @background = add_background(background_filename).set_z(-10)
      create_background_animation
    end
    def create_background_animation
      ya = Yuki::Animation
      duration = 0.5
      @background_animation = ya.timed_loop_animation(duration)
      @background_animation.play_before(ya.shift(duration, @background, 16, 16, 0, 0))
      @on_update_background_animation = proc do
        @background_animation.start
        @on_update_background_animation = nil
      end
    end
    def create_button_background
      @button_background = add_sprite(0, 214, button_background_filename).set_z(500)
    end
    # Return the name of the background
    # @return [String]
    def background_filename
      'team/Fond'
    end
    # Return the name of the button background
    # @return [String]
    def button_background_filename
      'tcard/button_background'
    end
    # Create the control buttons
    def create_control_button
      @ctrl = Array.new(4) { |index| ControlButton.new(@viewport, index, @keys[index]) }
    end
    # Return the win_text and create it if needed
    # @return [Text]
    def win_text
      @win_text_background ||= add_sprite(0, 217, 'team/Win_Txt').set_z(502)
      @win_text ||= add_text(5, 222, 238, 15, nil.to_s, color: 9)
      @win_text.z = 502
      @win_text
    end
    # Return the list of hidden button when win_text is shown
    # @return [#each]
    def hidden_button_indexes
      BUTTON_TO_HIDE
    end
    # Generic Button used to help the player to know what key he can press
    class ControlButton < SpriteStack
      # Array of button coordinates
      COORDINATES = [[3, 219], [83, 219], [163, 219], [243, 219]]
      # Create a new Button
      # @param viewport [Viewport]
      # @param coords_index [Integer] index of the coordinates to use in order to position the button
      # @param key [Symbol] key to show by default
      def initialize(viewport, coords_index, key)
        super(viewport, *COORDINATES[coords_index], default_cache: :pokedex)
        @background = add_background('buttons')
        @key_button = add_sprite(0, 1, NO_INITIAL_IMAGE, key, type: KeyShortcut)
        with_font(text_font) {@text = add_text(17, 3, 51, 13, nil.to_s, color: text_color(coords_index)) }
        @coords_index = coords_index
        self.pressed = false
        self.z = 501
      end
      # Set the button pressed
      # @param pressed [Boolean] if the button is pressed or not
      def pressed=(pressed)
        @background.set_rect_div(@coords_index == 3 ? 1 : 0, pressed ? 1 : 0, 2, 2)
        @background.src_rect.x += 1 if @coords_index == 3
        @background.src_rect.y += 1 if pressed
      end
      alias set_press pressed=
      # Set the text shown by the button
      # @param value [String] text to show
      def text=(value)
        return unless value.is_a?(String) || value.nil?
        @text.text = value if value
        self.visible = (value ? true : false)
      end
      # Set the key shown by the button
      # @param value [Symbol]
      def key=(value)
        return unless value.is_a?(Symbol)
        @key_button.find_key(value)
      end
      private
      # Retrieve the color of the text
      # @param coords_index [Integer] index of the coordinates to use in order to position the button
      # @return [Integer]
      def text_color(coords_index)
        coords_index == 3 ? 21 : 20
      end
      # Retrieve the id of the font used to show the text
      # @return [Integer]
      def text_font
        20
      end
    end
  end
  # Generic base allowing multiple button mode by initilizing it with all the value for keys & texts
  class GenericBaseMultiMode < GenericBase
    # @return [Integer] current mode of the UI
    attr_reader :mode
    # Create a new GenericBase UI
    # @param viewport [Viewport]
    # @param texts [Array<Array<String>>] list of texts shown in the ControlButton
    # @param keys [Array<Array<Symbol>>] list of keys used in the ControlButton
    def initialize(viewport, texts, keys, mode = 0)
      raise 'Text array & key array should have the same size' if texts.size != keys.size
      @texts_array = texts
      @keys_array = keys
      @mode = mode.clamp(0, keys.size)
      super(viewport, texts[@mode], keys[@mode])
    end
    # Set the mode to change the button display
    def mode=(value)
      @mode = value.clamp(0, @keys_array.size)
      self.button_texts = @texts_array[@mode]
      self.keys = @keys_array[@mode]
    end
  end
  # Sprite that show the 1st type of the Pokemon
  class Type1Sprite < SpriteSheet
    # Create a new Type Sprite
    # @param viewport [Viewport, nil] the viewport in which the sprite is stored
    # @param from_pokedex [Boolean] if the type is the Pokedex type (other source image)
    def initialize(viewport, from_pokedex = false)
      super(viewport, 1, each_data_type.size)
      load_texture(from_pokedex)
    end
    # Set the Pokemon used to show the type
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      self.sy = pokemon.send(*data_source) if (self.visible = (pokemon ? true : false))
    end
    private
    # Load the graphic resource
    # @param from_pokedex [Boolean] if the type is the Pokedex type (other source image)
    def load_texture(from_pokedex)
      filename = "types_#{$options.language}"
      if from_pokedex
        set_bitmap(RPG::Cache.pokedex_exist?(filename) ? filename : 'types', :pokedex)
      else
        set_bitmap(RPG::Cache.interface_exist?(filename) ? filename : 'types', :interface)
      end
    end
    # Retrieve the data source of the type sprite
    # @return [Symbol]
    def data_source
      :type1
    end
  end
  # Sprite that show the 2nd type of the Pokemon
  class Type2Sprite < Type1Sprite
    private
    # Retrieve the data source of the type sprite
    # @return [Symbol]
    def data_source
      :type2
    end
  end
  # Class that show a type image using an object that responds to #type
  class TypeSprite < Type1Sprite
    private
    # Retrieve the data source of the type sprite
    # @return [Symbol]
    def data_source
      :type
    end
  end
  # Sprite that show the gender of a Pokemon
  class GenderSprite < SpriteSheet
    # Name of the gender image in Graphics/Interface
    IMAGE_NAME = 'battlebar_gender'
    # Create a new Gender Sprite
    # @param viewport [Viewport, nil] the viewport in which the sprite is stored
    def initialize(viewport)
      super(viewport, gender_count, 1)
      set_bitmap(IMAGE_NAME, :interface)
    end
    # Set the Pokemon used to show the gender
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      self.sx = pokemon.gender if (self.visible = (pokemon ? true : false))
    end
    private
    # Define the number of gender supported by the resource
    def gender_count
      return 3
    end
  end
  # Sprite that show the status of a Pokemon
  class StatusSprite < SpriteSheet
    # Name of the image in Graphics/Interface
    IMAGE_NAME = 'statuts'
    # Name of the image in Graphics/Interface
    IMAGE_NAME_DEFAULT = 'statutsen'
    # Number of official states
    STATE_COUNT = 10
    # Create a new Status Sprite
    # @param viewport [Viewport, nil] the viewport in which the sprite is stored
    def initialize(viewport)
      super(viewport, 1, STATE_COUNT)
      filename = IMAGE_NAME + $options.language
      filename = IMAGE_NAME_DEFAULT unless RPG::Cache.interface_exist?(filename)
      set_bitmap(filename, :interface)
    end
    # Set the Pokemon used to show the status
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      self.sy = pokemon.status if (self.visible = (pokemon ? true : false))
    end
  end
  # Sprite that show the hold item if the pokemon is holding an item
  class HoldSprite < Sprite
    # Name of the image in Graphics/Interface
    IMAGE_NAME = 'hold'
    # Create a new Hold Sprite
    # @param viewport [Viewport, nil] the viewport in which the sprite is stored
    def initialize(viewport)
      super(viewport)
      set_bitmap(IMAGE_NAME, :interface)
    end
    # Set the Pokemon used to show the hold image
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      return (self.visible = false) unless pokemon
      item_id = ($game_temp.in_battle ? pokemon.battle_item : pokemon.item_holding) || 0
      self.visible = item_id.positive?
    end
  end
  # Sprite that show the actual item held if the Pokemon is holding one
  class RealHoldSprite < Sprite
    # Set the Pokemon used to show the hold image
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      return (self.visible = false) unless pokemon
      item_id = ($game_temp.in_battle ? pokemon.battle_item : pokemon.item_holding) || 0
      self.visible = item_id.positive?
      set_bitmap(data_item(item_id).icon, :icon) if visible
    end
  end
  # Class that show the category of a skill
  class CategorySprite < SpriteSheet
    # Name of the image in Graphics/Interface
    IMAGE_NAME = 'skill_categories'
    # Create a new category sprite
    # @param viewport [Viewport] viewport in which the sprite is shown
    def initialize(viewport)
      super(viewport, 1, category_count)
      set_bitmap(IMAGE_NAME, :interface)
    end
    # Set the object that responds to #atk_class
    # @param object [#atk_class, nil]
    def data=(object)
      self.sy = object.atk_class - 1 if (self.visible = (object ? true : false))
    end
    private
    def category_count
      return 3
    end
  end
  # Class that show the face sprite of a Pokemon
  class PokemonFaceSprite < Sprite
    # Create a new Pokemon FaceSprite
    # @param viewport [Viewport] Viewport in which the sprite is shown
    # @param auto_align [Boolean] if the sprite auto align itself (sets its own ox/oy when data= is called)
    def initialize(viewport, auto_align = true)
      super(viewport)
      @auto_align = auto_align
      @gif_reader = nil
    end
    # Set the pokemon
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      if (self.visible = (pokemon ? true : false))
        bmp = self.bitmap = load_bitmap(pokemon)
        auto_align(bmp, pokemon) if @auto_align
      end
    end
    # Update the face sprite
    def update
      @gif_reader&.update(bitmap)
    end
    private
    # Load the Sprite bitmap
    # @param pokemon [PFM::Pokemon]
    # @return [Texture]
    def load_bitmap(pokemon)
      bitmap&.dispose if @gif_reader
      if (@gif_reader = pokemon.send(*gif_source))
        bmp = Texture.new(@gif_reader.width, @gif_reader.height)
        @gif_reader.update(bmp)
        return bmp
      end
      return pokemon.send(*bitmap_source)
    end
    # Retrieve the bitmap source
    # @return [Symbol]
    def bitmap_source
      :battler_face
    end
    # Retreive the gif source
    # @return [Symbol]
    def gif_source
      :gif_face
    end
    # Align the sprite according to the bitmap properties
    # @param bmp [Texture] the bitmap source
    # @param pokemon [PFM::Pokemon]
    def auto_align(bmp, pokemon)
      oy = bmp.height + (self.class == PokemonFaceSprite ? pokemon.front_offset_y : 0)
      set_origin(bmp.width / 2, oy)
    end
  end
  # Class that show the back sprite of a Pokemon
  class PokemonBackSprite < PokemonFaceSprite
    private
    # Retrieve the bitmap source
    # @return [Symbol]
    def bitmap_source
      :battler_back
    end
    # Retreive the gif source
    # @return [Symbol]
    def gif_source
      :gif_back
    end
  end
  # Class that show the icon sprite of a Pokemon
  class PokemonIconSprite < SpriteSheet
    # Create a new Pokemon FaceSprite
    # @param viewport [Viewport] Viewport in which the sprite is shown
    # @param auto_align [Boolean] if the sprite auto align itself (sets its own ox/oy when data= is called)
    def initialize(viewport, auto_align = true)
      super(viewport, 2, 1)
      @auto_align = auto_align
      @max_counter = 60
      @counter = 0
    end
    # Set the pokemon
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      if (self.visible = (pokemon ? true : false))
        bmp = pokemon.icon
        @nb_x = (bmp.width / bmp.height).clamp(1, Float::INFINITY)
        self.bitmap = bmp
        auto_align(bmp) if @auto_align
        @counter = 0
        @max_counter = max_counter(pokemon)
      end
    end
    # Update the pokemon animation
    def update
      @counter += 1
      if @counter >= @max_counter
        self.sx = (@sx + 1) % 2
        @counter = 0
      end
    end
    private
    # Find the max number of frame before switching the @sx value
    # @param pokemon [PFM::Pokemon, nil]
    def max_counter(pokemon)
      return Float::INFINITY if pokemon.asleep? || pokemon.dead?
      return 20 + ((1 - pokemon.hp_rate) * 120).to_i if pokemon.status != 0
      return 10 + ((1 - pokemon.hp_rate) * 60).to_i
    end
    # Align the sprite according to the bitmap properties
    # @param bmp [Texture] the bitmap source
    def auto_align(bmp)
      set_origin(width / 2, bmp.height / 2)
    end
  end
  # Class that show the icon sprite of a Pokemon
  class PokemonFootSprite < Sprite
    # Format of the icon name
    D3 = '%03d'
    # Set the pokemon
    # @param pokemon [PFM::Pokemon, nil]
    def data=(pokemon)
      self.bitmap = RPG::Cache.foot_print(format(D3, pokemon.id)) if (self.visible = (pokemon ? true : false))
    end
  end
  # Class that show the item icon
  class ItemSprite < Sprite
    # Set the item that should be shown
    # @param item_id [Integer, Symbol, Studio::Item]
    def data=(item_id)
      item_id = item_id.db_symbol if item_id.is_a?(Studio::Item)
      set_bitmap(data_item(item_id).icon, :icon)
    end
  end
  # Class that show the category of a skill
  class AttackDummySprite < SpriteSheet
    # Name of the image shown
    IMAGE_NAME = 'battle_attack_dummy'
    # Create a new category sprite
    # @param viewport [Viewport] viewport in which the sprite is shown
    def initialize(viewport)
      super(viewport, 1, each_data_type.size)
      set_bitmap(IMAGE_NAME, :interface)
    end
    # Set the object that responds to #atk_class
    # @param object [#atk_class, nil]
    def data=(object)
      self.sy = object.type if (self.visible = (object ? true : false))
    end
  end
  # Object that show a text using a method of the data object sent
  class SymText < Text
    # Add a text inside the window, the offset x/y will be adjusted
    # @param font_id [Integer] the id of the font to use to draw the text
    # @param viewport [Viewport, nil] the viewport used to show the text
    # @param x [Integer] the x coordinate of the text surface
    # @param y [Integer] the y coordinate of the text surface
    # @param width [Integer] the width of the text surface
    # @param height [Integer] the height of the text surface
    # @param method [Symbol] the symbol of the method to call in the data object
    # @param align [0, 1, 2] the align of the text in its surface (best effort => no resize), 0 = left, 1 = center, 2 = right
    # @param outlinesize [Integer, nil] the size of the text outline
    # @param color [Integer] the id of the color
    # @param sizeid [Intger] the id of the size to use
    def initialize(font_id, viewport, x, y, width, height, method, align = 0, outlinesize = nil, color = nil, sizeid = nil)
      super(font_id, viewport, x, y, width, height, nil.to_s, align, outlinesize, color, sizeid)
      @method = method
    end
    # Set the Object used to show the text
    # @param object [Object, nil]
    def data=(object)
      return unless (self.visible = (object ? true : false))
      self.text = object.public_send(@method).to_s
    end
  end
  # Object that show a multiline text using a method of the data object sent
  class SymMultilineText < SymText
    # Set the Object used to show the text
    # @param object [Object, nil]
    def data=(object)
      return unless (self.visible = (object ? true : false))
      self.multiline_text = object.public_send(@method).to_s
    end
  end
  # Class that show the sprite of a key
  class KeyShortcut < Sprite
    # Create a new KeyShortcut sprite
    # @param viewport [Viewport]
    # @param key [Symbol, Integer] Input.trigger? argument (or Keyboard exact key if integer)
    # @param red [Boolean] pick the red texture instead of the blue texture
    def initialize(viewport, key, red = false)
      super(viewport)
      set_bitmap(red ? 'Key_ShortRed' : 'Key_Short', :pokedex)
      key.is_a?(Symbol) ? find_key(key) : show_key(key)
    end
    # KeyIndex that holds the value of the Keyboard constants in the right order according to the texture
    KeyIndex = %i[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z Num0 Num1 Num2 Num3 Num4 Num5 Num6 Num7 Num8 Num9 Space Backspace Enter LShift LControl LAlt Escape Left Right Up Down].collect(&Input::Keyboard.method(:const_get))
    kbd = Input::Keyboard
    # KeyIndex for the NumPad Keys
    NUMPAD_KEY_INDEX = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, kbd::Numpad0, kbd::Numpad1, kbd::Numpad2, kbd::Numpad3, kbd::Numpad4, kbd::Numpad5, kbd::Numpad6, kbd::Numpad7, kbd::Numpad8, kbd::Numpad9, -1, -1, -1, kbd::RShift, kbd::RControl, kbd::RAlt, -1, -1, -1, -1, -1]
    # Find the key rect in the Sprite according to the input key requested
    # @param key [Symbol] the Virtual Input Key.
    def find_key(key)
      key_array = Input::Keys[key]
      key_array.each do |i|
        if (id = KeyIndex.index(i) || NUMPAD_KEY_INDEX.index(i))
          return set_rect_div(id % 10, id / 10, 10, 5)
        end
      end
      set_rect_div(9, 4, 10, 5)
    end
    # Show the exact key (when key from initialize was an interger)
    def show_key(key)
      id = KeyIndex.index(key) || NUMPAD_KEY_INDEX.index(key) || 49
      set_rect_div(id % 10, id / 10, 10, 5)
    end
  end
  # Class that allow to show a binding of a specific key
  class KeyBinding < KeyShortcut
    # @return [Symbol] the key the button describe
    attr_reader :key
    # @return [Integer] the index of the key in the Keys[key] array
    attr_reader :index
    # Create a new KeyBinding sprite
    # @param viewport [Viewport]
    # @param key [Symbol] Input.trigger? argument
    # @param index [Integer] Index of the key in the Keys constant
    def initialize(viewport, key, index)
      @index = index
      @key = key
      super(viewport, key, false)
    end
    # Find the key rect in the Sprite according to the input key requested
    # @param key [Symbol] the Virtual Input Key.
    def find_key(key)
      key_val = Input::Keys[key][@index] || -1
      if (id = KeyIndex.index(key_val) || NUMPAD_KEY_INDEX.index(key_val))
        return set_rect_div(id % 10, id / 10, 10, 5)
      end
      set_rect_div(9, 4, 10, 5)
    end
    # Update the key
    def update
      find_key(@key)
    end
  end
  # Class that allow to show a binding of a specific key on the Joypad
  class JKeyBinding < Sprite
    # @return [Symbol] the key the button describe
    attr_reader :key
    # Create a new KeyBinding sprite
    # @param viewport [Viewport]
    # @param key [Symbol] Input.trigger? argument
    def initialize(viewport, key)
      super(viewport)
      @key = key
      set_bitmap('key_short_xbox', :pokedex)
      find_key(key)
    end
    # KeyIndex that holds the value of the key value in the order of the texture
    KeyIndex = [0, 1, 2, 3, 13, 15, 12, 14, 8, 9, 4, 5, 6, 7, 10, 11]
    # Find the key rect in the Sprite according to the input key requested
    # @param key [Symbol] the Virtual Input Key.
    def find_key(key)
      key_val = Input::Keys[key].last
      if key_val && key_val < 0
        key_val = (key_val.abs - 1) % 32
        if (id = KeyIndex.index(key_val))
          return set_rect_div(id % 8, id / 8, 8, 5)
        end
      end
      set_rect_div(0, 4, 8, 5)
    end
    # Update the key
    def update
      find_key(@key)
    end
    # Return the index of the key in the Keys[key] array
    # @return [Integer]
    def index
      return Input::Keys[key].size - 1
    end
  end
  # Sprite responsive of showing the sprite of the Ball we throw to Pokemon or to release Pokemon
  class ThrowingBallSprite < SpriteSheet
    # Array mapping the move progression to the right cell
    MOVE_PROGRESSION_CELL = [17, 16, 15, 16, 17, 18, 19, 18, 17]
    # Create a new ThrowingBallSprite
    # @param viewport [Viewport]
    # @param pokemon_or_item [PFM::Pokemon, Studio::BallItem]
    def initialize(viewport, pokemon_or_item)
      super(viewport, 1, 32)
      resolve_image(pokemon_or_item)
      self.sy = 3
    end
    # Function that adjust the sy depending on the progression of the "throw" animation
    # @param progression [Float]
    def throw_progression=(progression)
      self.sy = (progression * 4).floor.clamp(0, 3)
    end
    # Function that adjust the sy depending on the progression of the "open" animation
    # @param progression [Float]
    def open_progression=(progression)
      self.sy = (progression * 2).floor.clamp(0, 1) + 4
    end
    # Function that adjust the sy depending on the progression of the "close" animation
    # @param progression [Float]
    def close_progression=(progression)
      target = (progression * 9).floor
      if target == 9
        self.sy = 3
      else
        self.sy = target + 6
      end
    end
    # Function that adjust the sy depending on the progression of the "move" animation
    # @param progression [Float]
    def move_progression=(progression)
      self.sy = MOVE_PROGRESSION_CELL[(progression * 8).floor]
    end
    # Function that adjust the sy depending on the progression of the "break" animation
    # @param progression [Float]
    def break_progression=(progression)
      self.sy = (progression * 7).floor.clamp(0, 6) + 20
    end
    # Function that adjust the sy depending on the progression of the "caught" animation
    # @param progression [Float]
    def caught_progression=(progression)
      target = (progression * 5).floor
      if target == 5
        self.sy = 17
      else
        self.sy = 27 + target
      end
    end
    # Get the ball offset y in order to make it the same position as the Pokemon sprite
    # @return [Integer]
    def ball_offset_y
      return 8
    end
    # Get the ball offset y in order to make it look like being in trainer's hand
    # @return [Integer]
    def trainer_offset_y
      return 40
    end
    private
    # Resolve the sprite image
    # @param pokemon_or_item [PFM::Pokemon, Studio::BallItem]
    def resolve_image(pokemon_or_item)
      item = pokemon_or_item.is_a?(PFM::Pokemon) ? data_item(pokemon_or_item.captured_with) : pokemon_or_item
      unless item.is_a?(Studio::BallItem)
        log_error("The parameter #{pokemon_or_item} did not endup into Studio::BallItem object...")
        return
      end
      self.bitmap = RPG::Cache.ball(item.img)
      set_origin(width / 2, height / 2)
    end
  end
  # Class responsive of dealing with Keyboard user input (for search or other stuff like that).
  #
  # This is a Text that takes the same parameters as regular texts but has a `init` method allowing
  # to tell how much characters are allowed, what kind of character to use for empty chars and give the handler
  #
  # Example
  #   ```ruby
  #     @search = add_text(x, y, width, height, 'default_text', type: UI::UserInput)
  #     @search.init(25, '', on_new_char: method(:add_char), on_remove_char: method(:del_char))
  #     # ...
  #     def add_char(complete_string, new_char)
  #     # ...
  #     def del_char(complete_string, removed_char)
  #   ```
  class UserInput < ::Text
    # Code used to detect CTRL+V
    CTRL_V = ''
    # Code used to detect backspace
    BACK = ''
    # Init the user input
    # @param max_size [Integer] maximum size of the user input
    # @param empty_char [String] char used to replace all the remaining empty char
    # @param on_new_char [#call, nil] called when a char is added
    # @param on_remove_char [#call, nil] called when a char is removed
    def init(max_size, empty_char = '_', on_new_char: nil, on_remove_char: nil)
      @current_text = ''
      @max_size = max_size.abs
      @empty_char = empty_char
      @on_new_char = on_new_char
      @on_remove_char = on_remove_char
      load_text(text)
    end
    # Update the user input
    def update
      return unless @max_size
      return unless (text = Input.get_text)
      load_text(text)
    end
    private
    # Load the text from external source
    # @param text [String] external source
    def load_text(text)
      text = text.dup
      text.sub!(CTRL_V) {Yuki.get_clipboard }
      text.split(//).each do |char|
        if char == BACK
          last_char = @current_text[-1]
          @current_text.chop!
          @on_remove_char&.call(@current_text, last_char)
        else
          if char.getbyte(0) >= 32 && @current_text.size < @max_size
            @current_text << char
            @on_new_char&.call(@current_text, char)
          end
        end
      end
      self.text = (@empty_char.size > 0 ? @current_text.ljust(@max_size, @empty_char) : @current_text)
    end
  end
  # Class describing a text scroller (used in Credits)
  class TextScroller < SpriteStack
    # Separator for double column
    DOUBLE_COLUMN_SEP = ' || '
    # Create a new text scroller
    # @param viewport [Viewport]
    # @param texts [Array<String>]
    # @param line_height [Integer] height of a line of text
    # @param speed [Float] number of pixels / seconds
    def initialize(viewport, texts, line_height, speed)
      super(viewport, 0, 0)
      @texts = texts
      @line_height = line_height
      @speed = speed
      @next_check = 0
      @index = 0
      @h1_pool = []
      @h2_pool = []
      @h3_pool = []
      @p_pool = []
    end
    # Start the text scroll
    # @param until_all_text_hidden [Boolean] if the animation should last until the last text is offscreen
    def start(until_all_text_hidden: true)
      size = @texts.size * @line_height
      size += @viewport.rect.height if until_all_text_hidden
      preload_texts
      @animation = Yuki::Animation.move_discreet(size / @speed, self, 0, 0, 0, -size)
      @animation.start
    end
    # Update the scrolling
    def update
      spawn_next_text if y <= @next_check
      @animation.update
    end
    # Tell if the scrolling is done
    # @return [Boolean]
    def done?
      return true unless @animation
      return @animation.done?
    end
    private
    # Function responsive of spawning the next text to the screen
    def spawn_next_text
      stack.each { |text| text.visible = text.y > -@line_height }
      load_text(@texts[@index]) if @index < @texts.size
      @next_check -= @line_height
      @index += 1
    end
    # Function responsive of loading the text to the screen
    # @param text [String] markdown styled text (h1, h2, h3 or p)
    def load_text(text)
      *h, real_text = (text.start_with?('#') ? text.split(' ', 2) : text)
      if h.empty?
        return load_text_by_kind(@p_pool, :p, real_text.strip) unless real_text.include?(DOUBLE_COLUMN_SEP)
        return load_double_text(@p_pool, real_text.strip.split(DOUBLE_COLUMN_SEP))
      end
      h_type = h.first.count('#').clamp(1, 3)
      case h_type
      when 1
        load_text_by_kind(@h1_pool, :h1, real_text.strip)
      when 2
        load_text_by_kind(@h2_pool, :h2, real_text.strip)
      when 3
        load_text_by_kind(@h3_pool, :h3, real_text.strip)
      end
    end
    # Function that load a text depending on its kind
    # @param pool [Array<Text>]
    # @param kind [Symbol]
    # @param text [String]
    # @return [Text]
    def load_text_by_kind(pool, kind, text)
      recycled_text = pool.find { |txt| txt.visible == false }
      if recycled_text
        recycled_text.text = text
        recycled_text.visible = true
        recycled_text.align = text_align
      else
        @font_id = font_id(kind)
        pool << (recycled_text = add_text(0, 0, *text_surface, text, text_align, outline_size(kind), color: color_id(kind)))
      end
      recycled_text.set_position(*next_text_coordinate)
      return recycled_text
    end
    # Function that load text on double column
    # @param pool [Array<Text>]
    # @param texts [Array<String>]
    def load_double_text(pool, texts)
      recycled_text = load_text_by_kind(pool, :p, texts.first)
      recycled_text.x -= 10
      recycled_text.align = 2
      recycled_text = load_text_by_kind(pool, :p, texts.last)
      recycled_text.x += 10
      recycled_text.align = 0
    end
    # Function that give the text coordinate for the next text to show
    # @return [Array<Integer>]
    def next_text_coordinate
      return viewport.rect.width / 2, viewport.rect.height
    end
    # Function that give the text surface & align
    # @return [Array<Integer>]
    def text_surface
      return 0, @line_height
    end
    # Function that give the text align
    # @return [Integer]
    def text_align
      return 1
    end
    # Function that gives the font for a text
    # @param kind [Symbol]
    # @return [Integer]
    def font_id(kind)
      case kind
      when :h1, :h2, :h3
        return 20
      else
        return 0
      end
    end
    # Function that gives the color for a text
    # @param kind [Symbol]
    # @return [Integer]
    def color_id(kind)
      case kind
      when :h1
        return 11
      when :h2
        return 12
      when :h3
        return 13
      else
        return 10
      end
    end
    # Function that gives the outline_size for a text
    # @param kind [Symbol]
    # @return [Integer]
    def outline_size(kind)
      case kind
      when :h1, :h2, :h3
        return 1
      else
        return nil
      end
    end
    # Function that preload some text in order to make the starting a bit smoother
    def preload_texts
      nb_text = @viewport.rect.height / @line_height * 2
      nb_text.times {load_text(' ') }
      5.times do
        load_text('#  ')
        load_text('##  ')
        load_text('###  ')
      end
      stack.each { |text| text.visible = false }
    end
  end
  # Class responsive of showing a blur screenshot in the current scene
  class BlurScreenshot < ShaderedSprite
    # Create a new blur Screenshot
    # @param viewport [Viewport, nil]
    # @param last_scene [GamePlay::Base] base scene that should respond to #viewport
    def initialize(viewport = nil, last_scene)
      @last_scene = last_scene
      super(viewport || guess_viewport)
      self.shader = Shader.create(:blur)
      update_snapshot
    end
    # Dispose the sprite
    def dispose
      bitmap.dispose
      super
    end
    # Update the snapshot
    def update_snapshot
      self.bitmap = create_snapshot
      shader.set_float_uniform('resolution', [width, height])
    end
    private
    # Function that detects the viewport to use
    # @return [Viewport]
    def guess_viewport
      $scene.viewport
    end
    # Function that creates the snapshot
    # @return [Texture]
    def create_snapshot
      bitmap&.dispose
      return @last_scene.snap_to_bitmap
    rescue Exception
      return Texture.new(32, 32)
    end
  end
end
