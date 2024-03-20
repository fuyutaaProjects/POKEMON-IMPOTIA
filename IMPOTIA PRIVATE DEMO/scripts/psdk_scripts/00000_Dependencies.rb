class Object
  # Array representing an empty optional key hash
  EMPTY_OPTIONAL = [].freeze
  # Default error message
  VALIDATE_PARAM_ERROR = 'Parameter %<param_name>s sent to %<method_name>s is incorrect : %<reason>s'
  # Exception message
  EXC_MSG = 'Invalid param value passed to %s#%s, see previous errors to know what are the invalid params'
  # Function that validate the input paramters
  # @note To use a custom message, define a validate_param_message
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_names [Array<Symbol>] list of the names of the params
  # @param param_values [Hash] hash associating a param value to the expected type (description)
  # @example Param with a static type
  #   validate_param(:meth, :param, param => Type)
  # @example Param with various allowed types
  #   validate_param(:meth, :param, param => [Type1, Type2])
  # @example Param using a validation method
  #   validate_param(:meth, :param, param => :validation_method)
  # @example Param using a complex structure (Array of String)
  #   validate_param(:meth, :param, param => { Array => String })
  # @example Param using a complex structure (Array of Symbol, Integer, String, repetetive)
  #   validate_param(:meth, :param, param => { Array => [Symbol, Integer, String], :cyclic => true, min: 3, max: 9})
  # @example Param using a complex structure (Hash)
  #   validate_param(:meth, :param, param => { Hash => { key1: Type, key2: Type2, key3: [String, Symbol] },
  #                                            :optional => [:key2] })
  def validate_param(method_name, *param_names, param_values)
    index = 0
    exception = false
    param_values.each do |param_value, param_types|
      exception |= validate_param_value(method_name, param_names[index], param_value, param_types)
      index += 1
    end
    raise ArgumentError, format(EXC_MSG, self.class, method_name) if exception
  end
  # Function that does nothing and return nil
  # @example
  #   alias function_to_disable void
  def void(*args)
    return nil
  end
  # Function that does nothing and return true
  # @example
  #   alias function_to_disable void_true
  def void_true(*args)
    return true
  end
  # Function that does nothing and return false
  # @example
  #   alias function_to_disable void_false
  def void_false(*args)
    return false
  end
  # Function that does nothing and return 0
  # @example
  #   alias function_to_disable void0
  def void0(*args)
    return 0
  end
  # Function that does nothing and return []
  # @example
  #   alias function_to_disable void_array
  def void_array(*args)
    return nil.to_a
  end
  # Function that does nothing and return ""
  # @example
  #   alias function_to_disable void_array
  def void_string(*args)
    return nil.to_s
  end
  private
  # Function that validate a single parameter
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Class] expected type for param
  # @return [Boolean] if an exception should be raised when all parameters will be checked
  def validate_param_value(method_name, param_name, value, types)
    if types.is_a?(Module)
      return value.is_a?(types) ? false : validate_param_error_simple(method_name, param_name, value, types)
    else
      if types.is_a?(Symbol)
        return send(types, value) ? false : validate_param_error_method(method_name, param_name, value, types)
      else
        if types.is_a?(Array)
          return false if types.any? { |type| value.is_a?(type) }
          return validate_param_error_multiple(method_name, param_name, value, types)
        end
      end
    end
    return validate_param_complex_value(method_name, param_name, value, types)
  end
  # Function that shows an error on a parameter that should be validated by its type
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Class] expected type for param
  # @return [true] there's an exception to raise
  def validate_param_error_simple(method_name, param_name, value, types)
    reason = "should be a #{types}; is a #{value.class} with value of #{value.inspect}."
    log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
    return true
  end
  # Function that shows an error on a parameter that should be validated by a method
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Symbol] expected type for param
  # @return [true] there's an exception to raise
  def validate_param_error_method(method_name, param_name, value, types)
    reason = "hasn't validated criteria from #{types} method, value=#{value.inspect}."
    log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
    return true
  end
  # Function that shows an error on a parameter that should be validated by its type
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Array<Class>] expected type for param
  # @return [true] there's an exception to raise
  def validate_param_error_multiple(method_name, param_name, value, types)
    exp_types = types.join(', ').sub(/\,([^\,]+)$/, ' or a\\1')
    reason = "should be a #{exp_types}; is a #{value.class} with value of #{value.inspect}."
    log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
    return true
  end
  # Function that validate a single complex value parameter
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Hash] expected type for param
  # @return [Boolean] if an exception should be raised when all parameters will be checked
  def validate_param_complex_value(method_name, param_name, value, types)
    error = false
    if (sub_type = types[Array])
      return validate_param_error_simple(method_name, param_name, value, Array) unless value.is_a?(Array)
      validate_param_complex_value_size(method_name, param_name, value, types)
      if sub_type.is_a?(Module)
        value.each_with_index do |sub_val, index|
          error |= validate_param_value(method_name, "#{param_name}[#{index}]", sub_val, sub_type)
        end
      else
        if sub_type.is_a?(Array)
          value.each_with_index do |sub_val, index|
            sub_typec = sub_type[index % sub_type.size]
            error |= validate_param_value(method_name, "#{param_name}[#{index}]", sub_val, sub_typec)
          end
        end
      end
    else
      if (type = types[Hash])
        return validate_param_error_simple(method_name, param_name, value, Hash) unless value.is_a?(Hash)
        optional = types[:optional] || EMPTY_OPTIONAL
        type.each do |key, sub_type2|
          unless value.key?(key)
            next if optional.include?(key)
            reason = "key #{key.inspect} is mandatory."
            log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
            next(error = true)
          end
          error |= validate_param_value(method_name, "#{param_name}[#{key.inspect}]", value[key], sub_type2)
        end
      end
    end
    return error
  end
  # Function that validate the size of a complex array value
  # @param method_name [Symbol] name of the method which its param are being validated
  # @param param_name [Symbol] name of the param that is being validated
  # @param value [Object] value of the param
  # @param types [Hash] expected type for param
  # @return [Boolean] if an exception should be raised when all parameters will be checked
  def validate_param_complex_value_size(method_name, param_name, value, types)
    error = false
    if (min = types[:min]) && min > value.size
      reason = "param should contain at least #{min} values and contain #{value.size} values"
      log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
      error = true
    end
    if (max = types[:max]) && max < value.size
      reason = "param should not contain more than #{max} values and contain #{value.size} values"
      log_error(format(validate_param_message, param_name: param_name, method_name: method_name, reason: reason))
      error = true
    end
    return error
  end
  # Return the common error message
  # @return [String]
  def validate_param_message
    VALIDATE_PARAM_ERROR
  end
end
# Class that describe a collection of characters
class String
  # Convert numeric related chars of the string to corresponding chars in the Pokemon DS font family
  # @return [self]
  # @author Nuri Yuri
  def to_pokemon_number
    return self unless Configs.texts.fonts.supports_pokemon_number
    tr!('0123456789n/', '│┤╡╢╖╕╣║╗╝‰▓')
    return self
  end
end
# Binding class of Ruby
class Binding
  alias [] local_variable_get
  alias []= local_variable_set
end
# Kernel module of Ruby
module Kernel
  # Infer the object as the specified class (lint)
  # @return [self]
  def from(other)
    raise "Object of class #{other.class} cannot be casted as #{self}" unless other.is_a?(self)
    return other
  end
end
# Class that describes RGBA colors in integer scale (0~255)
class Color < LiteRGSS::Color
end
# Class that describe tones (added/modified colors to the surface)
class Tone < LiteRGSS::Tone
end
# Class that defines a rectangular surface of a Graphical element
class Rect < LiteRGSS::Rect
end
# Class that stores an image loaded from file or memory into the VRAM
class Texture < LiteRGSS::Bitmap
  # List of supported extensions
  SUPPORTED_EXTS = ['.png', '.PNG', '.jpg']
  # Initialize the texture, add automatically the extension to the filename
  # @param filename [String] Filename or FileData
  # @param from_mem [Boolean] load the file from memory (then filename is FileData)
  def initialize(filename, from_mem = nil)
    if from_mem || File.exist?(filename)
      super
    else
      if (new_filename = SUPPORTED_EXTS.map { |e| filename + e }.find { |f| File.exist?(f) })
        super(new_filename)
      else
        super(16, 16)
      end
    end
  end
end
# Class that stores an image loaded from file or memory into the VRAM
# @deprecated Please stop using bitmap to talk about texture!
class Bitmap < LiteRGSS::Bitmap
  # Create a new Bitmap
  def initialize(*args)
    log_error('Please stop using Bitmap!')
    super
  end
end
# Class that is dedicated to perform Image operation in Memory before displaying those operations inside a texture
class Image < LiteRGSS::Image
end
# BlendMode applicable to a Sprite/Viewport
class BlendMode < LiteRGSS::BlendMode
end
# Module responsive of showing graphics into the main window
module Graphics
  include Hooks
  extend Hooks
  @on_start = []
  @viewports = []
  @frozen = 0
  @frame_rate = 60
  @current_time = Time.new
  @has_focus = true
  @frame_count = 0
  @fullscreen_toggle_enabled = true
  class << self
    # Get the game window
    # @return [LiteRGSS::DisplayWindow]
    attr_reader :window
    # Get the global frame count
    # @return [Integer]
    attr_accessor :frame_count
    # Get the framerate
    # @return [Integer]
    attr_accessor :frame_rate
    # Get the current time
    # @return [Time]
    attr_reader :current_time
    # Get the time when the last frame was executed
    # @return [Time]
    attr_reader :last_time
    # Tell if it is allowed to go fullscreen with ALT+ENTER
    attr_accessor :fullscreen_toggle_enabled
    # Tell if the graphics window has focus
    # @return [Boolean]
    def focus?
      return @has_focus
    end
    # Tell if the graphics are frozen
    # @return [Boolean]
    def frozen?
      @frozen > 0
    end
    # Tell how much time there was since last frame
    # @return [Float]
    def delta
      return @current_time - @last_time
    end
    # Get the brightness of the main game window
    # @return [Integer]
    def brightness
      return window&.brightness || 0
    end
    # Set the brightness of the main game window
    # @param brightness [Integer]
    def brightness=(brightness)
      window&.brightness = brightness
    end
    # Get the height of the graphics
    # @return [Integer]
    def height
      return window.height
    end
    # Get the width of the graphics
    # @return [Integer]
    def width
      return window.width
    end
    # Get the shader of the graphics
    # @return [Shader]
    def shader
      return window&.shader
    end
    # Set the shader of the graphics
    # @param shader [Shader, nil]
    def shader=(shader)
      window&.shader = shader
    end
    # Freeze the graphics
    def freeze
      return unless @window
      @frozen_sprite.dispose if @frozen_sprite && !@frozen_sprite.disposed?
      @frozen_sprite = LiteRGSS::ShaderedSprite.new(window)
      @frozen_sprite.bitmap = snap_to_bitmap
      @frozen = 10
    end
    # Resize the window screen
    # @param width [Integer]
    # @param height [Integer]
    def resize_screen(width, height)
      window&.resize_screen(width, height)
    end
    # Snap the graphics to bitmap
    # @return [LiteRGSS::Bitmap]
    def snap_to_bitmap
      all_viewport = viewports_in_order.select(&:visible)
      tmp = LiteRGSS::Viewport.new(window, 0, 0, width, height)
      bk = Image.new(width, height)
      bk.fill_rect(0, 0, width, height, Color.new(0, 0, 0, 255))
      sp = LiteRGSS::Sprite.new(tmp)
      sp.bitmap = LiteRGSS::Bitmap.new(width, height)
      bk.copy_to_bitmap(sp.bitmap)
      texture_to_dispose = all_viewport.map do |vp|
        shader = vp.shader
        vp.shader = nil
        texture = vp.snap_to_bitmap
        vp.shader = shader
        sprite = LiteRGSS::ShaderedSprite.new(tmp)
        sprite.shader = shader
        sprite.bitmap = texture
        sprite.set_position(vp.rect.x, vp.rect.y)
        next(texture)
      end
      texture_to_dispose << bk
      texture_to_dispose << sp.bitmap
      result_texture = tmp.snap_to_bitmap
      texture_to_dispose.each(&:dispose)
      tmp.dispose
      return result_texture
    end
    # Start the graphics
    def start
      return if @window
      @window = LiteRGSS::DisplayWindow.new(Configs.infos.game_title, *PSDK_CONFIG.choose_best_resolution, PSDK_CONFIG.window_scale, 32, 0, PSDK_CONFIG.vsync_enabled, PSDK_CONFIG.running_in_full_screen, !Configs.devices.mouse_skin)
      @on_start.each(&:call)
      @on_start.clear
      @last_time = @current_time = Time.new
      Input.register_events(@window)
      Mouse.register_events(@window)
      @window.on_lost_focus = proc {@has_focus = false }
      @window.on_gained_focus = proc {@has_focus = true }
      @window.on_closed = proc do
        @window = nil
        next(true)
      end
      init_sprite
    end
    # Stop the graphics
    def stop
      window&.dispose
      @window = nil
    end
    # Transition the graphics between a scene to another
    # @param frame_count_or_sec [Integer, Float] integer = frames, float = seconds; duration of the transition
    # @param texture [Texture] texture used to perform the transition (optional)
    def transition(frame_count_or_sec = 8, texture = nil)
      return unless @window
      exec_hooks(Graphics, :transition, binding)
      return if frame_count_or_sec <= 0 || !@frozen_sprite
      transition_internal(frame_count_or_sec, texture)
      exec_hooks(Graphics, :post_transition, binding)
    rescue Hooks::ForceReturn => e
      return e.data
    ensure
      @frozen_sprite&.bitmap&.dispose
      @frozen_sprite&.shader = nil
      @frozen_sprite&.dispose
      @frozen_sprite = nil
      @frozen = 0
    end
    # Update graphics window content & events. This method might wait for vsync before updating events
    def update
      return unless @window
      return update_freeze if frozen?
      exec_hooks(Graphics, :update, bnd = binding)
      exec_hooks(Graphics, :pre_update_internal, bnd)
      Input.swap_states
      Mouse.swap_states
      window.update
      @last_time = @current_time
      @current_time = Time.new
      @frame_count += 1
      exec_hooks(Graphics, :post_update_internal, bnd)
    rescue Hooks::ForceReturn => e
      return e.data
    end
    # Update the graphics window content. This method might wait for vsync before returning
    def update_no_input
      return unless @window
      window.update_no_input
      @last_time = @current_time
      @current_time = Time.new
    end
    # Update the graphics window event without drawing anything.
    def update_only_input
      return unless @window
      Input.swap_states
      Mouse.swap_states
      window.update_only_input
      @last_time = @current_time
      @current_time = Time.new
    end
    # Make the graphics wait for an amout of time
    # @param frame_count_or_sec [Integer, Float] Integer => frames, Float = actual time
    # @yield
    def wait(frame_count_or_sec)
      return unless @window
      total_time = frame_count_or_sec.is_a?(Float) ? frame_count_or_sec : frame_count_or_sec.to_f / frame_rate
      initial_time = Graphics.current_time
      next_time = initial_time + total_time
      while Graphics.current_time < next_time
        Graphics.update
        yield if block_given?
      end
    end
    # Register an event on start of graphics
    # @param block [Proc]
    def on_start(&block)
      @on_start << block
    end
    # Register a viewport to the graphics (for special handling)
    # @param viewport [Viewport]
    # @return [self]
    def register_viewport(viewport)
      return self unless viewport.is_a?(Viewport)
      @viewports << viewport unless @viewports.include?(viewport)
      return self
    end
    # Unregister a viewport
    # @param viewport [Viewport]
    # @return [self]
    def unregitser_viewport(viewport)
      @viewports.delete(viewport)
      return self
    end
    # Reset frame counter (for FPS reason)
    def frame_reset
      exec_hooks(Graphics, :frame_reset, binding)
    end
    # Init the Sprite used by the Graphics module
    def init_sprite
      exec_hooks(Graphics, :init_sprite, binding)
    end
    # Sort the graphics in z
    def sort_z
      @window&.sort_z
    end
    # Swap the fullscreen state
    def swap_fullscreen
      settings = window.settings
      settings[7] = !settings[7]
      window.settings = settings
    end
    # Set the screen scale factor
    # @param scale [Float] scale of the screen
    def screen_scale=(scale)
      settings = window.settings
      settings[3] = scale
      window.settings = settings
    end
    private
    # Update the frozen state of graphics
    def update_freeze
      return if @frozen <= 0
      @frozen -= 1
      if @frozen == 0
        log_error('Graphics were frozen for too long, calling transition...')
        transition
      else
        exec_hooks(Graphics, :update_freeze, binding)
      end
    end
    # Get the registered viewport in order
    # @return [Array<Viewport>]
    def viewports_in_order
      viewports = @viewports.reject(&:disposed?)
      viewports.sort! do |a, b|
        next(a.z <=> b.z) if a.z != b.z
        next(a.__index__ <=> b.__index__)
      end
      return viewports
    end
    # Actual execution of the transition internal
    # @param frame_count_or_sec [Integer, Float] integer = frames, float = seconds; duration of the transition
    # @param texture [Texture] texture used to perform the transition (optional)
    def transition_internal(frame_count_or_sec, texture)
      total_time = frame_count_or_sec.is_a?(Float) ? frame_count_or_sec : frame_count_or_sec.to_f / frame_rate
      initial_time = Graphics.current_time
      next_time = initial_time + total_time
      @frozen_sprite.shader = Shader.create(texture ? :graphics_transition : :graphics_transition_static)
      @frozen_sprite.shader.set_texture_uniform('nextFrame', next_frame = snap_to_bitmap)
      @frozen_sprite.shader.set_texture_uniform('transition', texture) if texture
      viewports = viewports_in_order
      visibilities = viewports.map(&:visible)
      viewports.each { |v| v.visible = false }
      sort_z
      while (current_time = Time.new) < next_time
        @frozen_sprite.shader.set_float_uniform('param', ((current_time - initial_time) / total_time).clamp(0, 1))
        exec_hooks(Graphics, :update_transition_internal, binding)
        window.update
        @last_time = @current_time
        @current_time = Time.new
      end
      viewports.each_with_index { |v, i| v.visible = visibilities[i] }
      next_frame.dispose
    end
  end
  # Shader used to perform transition
  TRANSITION_FRAG_SHADER = "uniform float param;\nuniform sampler2D texture;\nuniform sampler2D transition;\nuniform sampler2D nextFrame;\nconst float sensibilite = 0.05;\nconst float scale = 1.0 + sensibilite;\nvoid main()\n{\n  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);\n  vec4 tran = texture2D(transition, gl_TexCoord[0].xy);\n  float pixel = max(max(tran.r, tran.g), tran.b);\n  pixel -= (param * scale);\n  if(pixel < sensibilite)\n  {\n    vec4 nextFrag = texture2D(nextFrame, gl_TexCoord[0].xy);\n    frag = mix(frag, nextFrag, max(0.0, sensibilite + pixel / sensibilite));\n  }\n  gl_FragColor = frag;\n}\n"
  # Shader used to perform static transition
  STATIC_TRANSITION_FRAG_SHADER = "uniform float param;\nuniform sampler2D texture;\nuniform sampler2D nextFrame;\nvoid main()\n{\n  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);\n  vec4 nextFrag = texture2D(nextFrame, gl_TexCoord[0].xy);\n  frag = mix(frag, nextFrag, max(0.0, param));\n  gl_FragColor = frag;\n}\n"
end
# Module responsive of giving information about user Inputs
#
# The virtual keys of the Input module are : :A, :B, :X, :Y, :L, :R, :L2, :R2, :L3, :R3, :START, :SELECT, :HOME, :UP, :DOWN, :LEFT, :RIGHT
module Input
  # Alias for the Keyboard module
  Keyboard = Sf::Keyboard
  # Range giving dead zone of axis
  DEAD_ZONE = -20..20
  # Range outside of which a trigger is considered on an exis
  NON_TRIGGER_ZONE = -50..50
  # Sensitivity in order to take a trigger in account on joystick movement
  AXIS_SENSITIVITY = 10
  # Cooldown delta of Input.repeat?
  REPEAT_COOLDOWN = 0.25
  # Time between each signals of Input.repeat? after cooldown
  REPEAT_SPACE = 0.08
  @last_down_times = Hash.new { |hash, key| hash[key] = Graphics.current_time }
  @next_trigger_times = Hash.new { |hash, key| hash[key] = Graphics.current_time }
  @last_state = Hash.new {false }
  @current_state = Hash.new {false }
  @main_joy = 0
  @x_axis = Sf::Joystick::POV_X
  @y_axis = Sf::Joystick::POV_Y
  @x_joy_axis = Sf::Joystick::X
  @y_joy_axis = Sf::Joystick::Y
  @last_text = nil
  # List of keys the input knows
  Keys = {A: [Sf::Keyboard::C, Sf::Keyboard::Space, Sf::Keyboard::Enter, Sf::Keyboard::C, -1], B: [Sf::Keyboard::X, Sf::Keyboard::Backspace, Sf::Keyboard::Escape, Sf::Keyboard::RShift, -2], X: [Sf::Keyboard::V, Sf::Keyboard::Num3, Sf::Keyboard::Slash, Sf::Keyboard::V, -3], Y: [Sf::Keyboard::B, Sf::Keyboard::Num1, Sf::Keyboard::Quote, Sf::Keyboard::B, -4], L: [Sf::Keyboard::F, Sf::Keyboard::F, Sf::Keyboard::LBracket, Sf::Keyboard::F, -5], R: [Sf::Keyboard::G, Sf::Keyboard::G, Sf::Keyboard::RBracket, Sf::Keyboard::G, -6], L2: [Sf::Keyboard::R, Sf::Keyboard::R, Sf::Keyboard::R, Sf::Keyboard::R, -7], R2: [Sf::Keyboard::T, Sf::Keyboard::T, Sf::Keyboard::T, Sf::Keyboard::T, -8], L3: [Sf::Keyboard::Num4, Sf::Keyboard::Y, Sf::Keyboard::Y, Sf::Keyboard::Y, -9], R3: [Sf::Keyboard::Num5, Sf::Keyboard::U, Sf::Keyboard::U, Sf::Keyboard::U, -10], START: [Sf::Keyboard::J, Sf::Keyboard::RControl, Sf::Keyboard::J, Sf::Keyboard::J, -8], SELECT: [Sf::Keyboard::H, Sf::Keyboard::LControl, Sf::Keyboard::H, Sf::Keyboard::L, -7], HOME: [Sf::Keyboard::M, Sf::Keyboard::LSystem, Sf::Keyboard::RSystem, Sf::Keyboard::M, 255], UP: [Sf::Keyboard::Up, Sf::Keyboard::Z, Sf::Keyboard::W, Sf::Keyboard::Numpad8, -13], DOWN: [Sf::Keyboard::Down, Sf::Keyboard::S, Sf::Keyboard::S, Sf::Keyboard::Numpad2, -14], LEFT: [Sf::Keyboard::Left, Sf::Keyboard::Q, Sf::Keyboard::A, Sf::Keyboard::Numpad4, -15], RIGHT: [Sf::Keyboard::Right, Sf::Keyboard::D, Sf::Keyboard::D, Sf::Keyboard::Numpad6, -16]}
  # List of key ALIAS
  ALIAS_KEYS = {up: :UP, down: :DOWN, left: :LEFT, right: :RIGHT, a: :A, b: :B, x: :X, y: :Y, start: :START, select: :SELECT}
  # List of Axis mapping (axis => key_neg, key_pos)
  AXIS_MAPPING = {Sf::Joystick::Z => %i[R2 L2]}
  @previous_axis_positions = Hash.new { |hash, key| hash[key] = Hash.new {0 } }
  @joysticks_connected = []
  class << self
    # Get the main joystick
    # @return [Integer]
    attr_accessor :main_joy
    # Get the X axis
    attr_accessor :x_axis
    # Get the Y axis
    attr_accessor :y_axis
    # Get the Joystick X axis
    attr_accessor :x_joy_axis
    # Get the Joystick Y axis
    attr_accessor :y_joy_axis
    # Get the 4 direction status
    # @return [Integer] 2 = down, 4 = left, 6 = right, 8 = up, 0 = none
    def dir4
      return 6 if press?(:RIGHT)
      return 4 if press?(:LEFT)
      return 2 if press?(:DOWN)
      return 8 if press?(:UP)
      return 0
    end
    # Get the 8 direction status
    # @return [Integer] see NumPad to know direction
    def dir8
      if press?(:DOWN)
        return 1 if press?(:LEFT)
        return 3 if press?(:RIGHT)
        return 2
      else
        if press?(:UP)
          return 7 if press?(:LEFT)
          return 9 if press?(:RIGHT)
          return 8
        end
      end
      return dir4
    end
    # Get the last entered text
    # @return [String, nil]
    def get_text
      return nil unless Graphics.focus?
      return @last_text
    end
    # Get the axis position of a joystick
    # @param id [Integer] ID of the joystick
    # @param axis [Integer] axis
    # @return [Integer]
    def joy_axis_position(id, axis)
      Sf::Joystick.axis_position(id, axis)
    end
    # Tell if a key is pressed
    # @param key [Symbol] name of the key
    # @return [Boolean]
    def press?(key)
      return false unless Graphics.focus?
      key = ALIAS_KEYS[key] || key unless Keys[key]
      return @current_state[key]
    end
    # Tell if a key was triggered
    # @param key [Symbol] name of the key
    # @return [Boolean]
    def trigger?(key)
      return false unless Graphics.focus?
      key = ALIAS_KEYS[key] || key unless Keys[key]
      return @current_state[key] && !@last_state[key]
    end
    # Tell if a key was released
    # @param key [Symbol] name of the key
    # @return [Boolean]
    def released?(key)
      return false unless Graphics.focus?
      key = ALIAS_KEYS[key] || key unless Keys[key]
      return @last_state[key] && !@current_state[key]
    end
    # Tell if a key is repeated (0.25s then each 0.08s)
    # @param key [Symbol] name of the key
    # @return [Boolean]
    def repeat?(key)
      return false unless Graphics.focus?
      key = ALIAS_KEYS[key] || key unless Keys[key]
      return false unless @current_state[key]
      return true if trigger?(key)
      delta = Graphics.current_time - @last_down_times[key]
      return false if delta < REPEAT_COOLDOWN
      return false if @last_down_times[key] > Graphics.current_time
      return true
    end
    # Swap the states (each time input gets updated)
    def swap_states
      @last_state.merge!(@current_state)
      @last_down_times.each do |key, value|
        next unless repeat?(key)
        delta = Graphics.current_time - value
        @last_down_times[key] = Graphics.current_time - (REPEAT_COOLDOWN - REPEAT_SPACE) if delta >= REPEAT_COOLDOWN
      end
      @last_text = nil
    end
    # Register all events in the window
    # @param window [LiteRGSS::DisplayWindow]
    def register_events(window)
      window.on_text_entered = proc { |text| on_text_entered(text) }
      window.on_key_pressed = proc { |key, alt| on_key_down(key, alt) }
      window.on_key_released = proc { |key| on_key_up(key) }
      window.on_joystick_button_pressed = proc { |id, button| on_joystick_button_pressed(id, button) }
      window.on_joystick_button_released = proc { |id, button| on_joystick_button_released(id, button) }
      window.on_joystick_connected = proc { |id| on_joystick_connected(id) }
      window.on_joystick_disconnected = proc { |id| on_joystick_disconnected(id) }
      window.on_joystick_moved = proc { |id, axis, position| on_axis_moved(id, axis, position) }
    end
    private
    # Set the last entered text
    # @param text [String]
    def on_text_entered(text)
      @last_text = text
    end
    # Set a key up
    # @param key [Integer]
    # @param alt [Boolean] if the alt key is pressed
    def on_key_down(key, alt = false)
      return Graphics.swap_fullscreen if alt && key == Sf::Keyboard::Enter && Graphics.fullscreen_toggle_enabled
      vkey, = Keys.find { |_, v| v.include?(key) }
      return unless vkey
      @current_state[vkey] = true
      @last_down_times[vkey] = Graphics.current_time unless @last_state[vkey]
    end
    # Set a key down
    # @param key [Integer]
    def on_key_up(key)
      vkey, = Keys.find { |_, v| v.include?(key) }
      return unless vkey
      @current_state[vkey] = false
    end
    # Trigger a key depending on the joystick axis movement
    # @param id [Integer] id of the joystick
    # @param axis [Integer] axis
    # @param position [Integer] new position
    def on_axis_moved(id, axis, position)
      on_joystick_connected(id)
      return if id != main_joy
      last_position = @previous_axis_positions[id][axis]
      return if (position - last_position).abs <= AXIS_SENSITIVITY
      @previous_axis_positions[id][axis] = position
      if id == main_joy
        return on_axis_x(position) if axis == x_axis || axis == x_joy_axis
        return on_axis_y(position) if axis == y_axis
        return on_axis_joy_y(position) if axis == y_joy_axis
      end
      return unless (mapping = AXIS_MAPPING[axis])
      if DEAD_ZONE.include?(position)
        @current_state[mapping.first] = @current_state[mapping.last] = false
        return
      else
        if position.positive?
          @current_state[e = mapping.last] = true
          @last_down_times[e] = Graphics.current_time unless @last_state[e]
          @current_state[mapping.first] = false
        else
          @current_state[e = mapping.first] = true
          @last_down_times[e] = Graphics.current_time unless @last_state[e]
          @current_state[mapping.last] = false
        end
      end
    end
    # Trigger a RIGHT or LEFT thing depending on x axis position
    # @param position [Integer] new position
    def on_axis_x(position)
      if NON_TRIGGER_ZONE.include?(position)
        @current_state[:LEFT] = @current_state[:RIGHT] = false
        return
      else
        if position.positive?
          @current_state[:RIGHT] = true
          @last_down_times[:RIGHT] = Graphics.current_time unless @last_state[:RIGHT]
          @current_state[:LEFT] = false
        else
          @current_state[:LEFT] = true
          @last_down_times[:LEFT] = Graphics.current_time unless @last_state[:LEFT]
          @current_state[:RIGHT] = false
        end
      end
    end
    # Trigger a UP or DOWN thing depending on y axis position (D-Pad)
    # @param position [Integer] new position
    def on_axis_y(position)
      if NON_TRIGGER_ZONE.include?(position)
        @current_state[:UP] = @current_state[:DOWN] = false
        return
      else
        if position.positive?
          @current_state[:UP] = true
          @last_down_times[:UP] = Graphics.current_time unless @last_state[:UP]
          @current_state[:DOWN] = false
        else
          @current_state[:DOWN] = true
          @last_down_times[:DOWN] = Graphics.current_time unless @last_state[:DOWN]
          @current_state[:UP] = false
        end
      end
    end
    # Trigger a UP or DOWN thing depending on y axis position (Joystick)
    # @param position [Integer] new position
    def on_axis_joy_y(position)
      if NON_TRIGGER_ZONE.include?(position)
        @current_state[:UP] = @current_state[:DOWN] = false
        return
      else
        if position.positive?
          @current_state[:DOWN] = true
          @last_down_times[:DOWN] = Graphics.current_time unless @last_state[:DOWN]
          @current_state[:UP] = false
        else
          @current_state[:UP] = true
          @last_down_times[:UP] = Graphics.current_time unless @last_state[:UP]
          @current_state[:DOWN] = false
        end
      end
    end
    # Add the joystick to the list of connected joysticks and the new joystick connected becomes the main joystick
    # @param id [Integer] id of the joystick
    def on_joystick_connected(id)
      return if @joysticks_connected.include?(id)
      @joysticks_connected << id
      @main_joy = id
    end
    # Remove the joystick to the list of connected joysticks and change the main joystick if other joystick are connected
    # @param id [Integer] id of the joystick
    def on_joystick_disconnected(id)
      @joysticks_connected.delete(id)
      @main_joy = @joysticks_connected.empty? ? 0 : @joysticks_connected.last
    end
    # Set a key down if the button pressed comes of main joystick
    # @param id [Integer] id of the joystick
    # @param button [Integer]
    def on_joystick_button_pressed(id, button)
      on_key_down(-button - 1) if id == main_joy
    end
    # Set a key up if the button released comes of main joystick
    # @param id [Integer] id of the joystick
    # @param button [Integer]
    def on_joystick_button_released(id, button)
      on_key_up(-button - 1) if id == main_joy
    end
  end
end
# Module responsive of giving global state of mouse Inputs
#
# The buttons of the mouse are : :LEFT, :MIDDLE, :RIGHT, :X1, :X2
module Mouse
  @last_state = Hash.new {false }
  @current_state = Hash.new {false }
  # Mapping between button & symbols
  BUTTON_MAPPING = {Sf::Mouse::LEFT => :LEFT, Sf::Mouse::RIGHT => :RIGHT, Sf::Mouse::Middle => :MIDDLE, Sf::Mouse::XButton1 => :X1, Sf::Mouse::XButton2 => :X2}
  # List of alias button
  BUTTON_ALIAS = {left: :LEFT, right: :RIGHT, middle: :MIDDLE}
  @wheel = 0
  @wheel_delta = 0
  @x = -999_999
  @y = -999_999
  @in_screen = true
  @moved = false
  class << self
    # Mouse wheel position
    # @return [Integer]
    attr_accessor :wheel
    # Mouse wheel delta
    # @return [Integer]
    attr_reader :wheel_delta
    # Get the mouse x position
    # @return [Integer]
    attr_reader :x
    # Get the mouse y position
    # @return [Integer]
    attr_reader :y
    # Get if the mouse moved since last frame
    # @return [Boolean]
    attr_reader :moved
    # Tell if a button is pressed on the mouse
    # @param button [Symbol]
    # @return [Boolean]
    def press?(button)
      button = BUTTON_ALIAS[button] || button
      return @current_state[button]
    end
    # Tell if a button was triggered on the mouse
    # @param button [Symbol]
    # @return [Boolean]
    def trigger?(button)
      button = BUTTON_ALIAS[button] || button
      return @current_state[button] && !@last_state[button]
    end
    # Tell if a button was released on the mouse
    # @param button [Symbol]
    # @return [Boolean]
    def released?(button)
      button = BUTTON_ALIAS[button] || button
      return @last_state[button] && !@current_state[button]
    end
    # Tell if the mouse is in the screen
    # @return [Boolean]
    def in?
      return @in_screen
    end
    # Swap the state of the mouse
    def swap_states
      @last_state.merge!(@current_state)
      @moved = false
      @wheel_delta = 0
    end
    # Register event related to the mouse
    # @param window [LiteRGSS::DisplayWindow]
    def register_events(window)
      return if Configs.devices.is_mouse_disabled && %i[tags worldmap].none? { |arg| PARGV[arg] }
      window.on_touch_began = proc { |finger_id, x, y|         on_mouse_entered
        on_mouse_moved(x, y)
        on_button_pressed(Sf::Mouse::LEFT)
 }
      window.on_touch_moved = proc { |finger, x, y| on_mouse_moved(x, y) }
      window.on_touch_ended = proc { |finger_id, x, y|         on_button_released(Sf::Mouse::LEFT)
        on_mouse_moved(x, y)
        on_mouse_left
 }
      window.on_mouse_wheel_scrolled = proc { |wheel, delta| on_wheel_scrolled(wheel, delta) }
      window.on_mouse_button_pressed = proc { |button| on_button_pressed(button) }
      window.on_mouse_button_released = proc { |button| on_button_released(button) }
      window.on_mouse_moved = proc { |x, y| on_mouse_moved(x, y) }
      window.on_mouse_entered = proc {on_mouse_entered }
      window.on_mouse_left = proc {on_mouse_left }
    end
    private
    # Update the mouse wheel state
    # @param wheel [Integer]
    # @param delta [Float]
    def on_wheel_scrolled(wheel, delta)
      return unless wheel == Sf::Mouse::VerticalWheel
      @wheel += delta.to_i
      @wheel_delta += delta.to_i
    end
    # Update the button state
    # @param button [Integer]
    def on_button_pressed(button)
      @current_state[BUTTON_MAPPING[button]] = true
    end
    # Update the button state
    # @param button [Integer]
    def on_button_released(button)
      @current_state[BUTTON_MAPPING[button]] = false
    end
    # Update the mouse position
    # @param x [Integer]
    # @param y [Integer]
    def on_mouse_moved(x, y)
      settings = Graphics.window.settings
      if settings[7]
        @x = (x * settings[1] / LiteRGSS::DisplayWindow.desktop_width)
        @y = (y * settings[2] / LiteRGSS::DisplayWindow.desktop_height)
      else
        @x = (x / PSDK_CONFIG.window_scale).floor
        @y = (y / PSDK_CONFIG.window_scale).floor
      end
      @moved = true
    end
    # Update the mouse status when it enters the screen
    def on_mouse_entered
      @in_screen = true
    end
    # Update the mouse status when it leaves the screen
    def on_mouse_left
      @in_screen = false
    end
  end
end
# Class that describes a surface of the screen where texts and sprites are shown (with some global effect)
class Viewport < LiteRGSS::Viewport
  # Hash containing all the Viewport configuration (:main, :sub etc...)
  CONFIGS = {}
  @global_offset_x = nil
  @global_offset_y = nil
  # Filename for viewport compiled config
  VIEWPORT_CONF_COMP = 'Data/Viewport.rxdata'
  # Filename for viewport uncompiled config
  VIEWPORT_CONF_TEXT = 'Data/Viewport.json'
  # Tell if the viewport needs to sort
  # @return [Boolean]
  attr_accessor :need_to_sort
  # Create a new viewport
  # @param x [Integer] x coordinate of the viewport on screen
  # @param y [Integer] y coordinate of the viewport on screen
  # @param width [Integer] width of the viewport
  # @param height [Integer] height of the viewport
  # @param z [Integer] z coordinate of the viewport
  def initialize(x, y, width, height, z = nil)
    super(Graphics.window, x, y, width, height)
    self.z = z if z
    @need_to_sort = true
    Graphics.register_viewport(self)
  end
  # Dispose a viewport
  # @return [self]
  def dispose
    Graphics.unregitser_viewport(self)
    super
  end
  class << self
    # Generating a viewport with one line of code
    # @overload create(screen_name_symbol, z = nil)
    #   @param screen_name_symbol [:main, :sub] describe with screen surface the viewport is (loaded from maker options)
    #   @param z [Integer, nil] superiority of the viewport
    # @overload create(x, y = 0, width = 1, height = 1, z = nil)
    #   @param x [Integer] x coordinate of the viewport
    #   @param y [Integer] y coordinate of the viewport
    #   @param width [Integer] width of the viewport
    #   @param height [Integer] height of the viewport
    #   @param z [Integer, nil] superiority of the viewport
    # @overload create(opts)
    #   @param opts [Hash] opts of the viewport definition
    #   @option opts [Integer] :x (0) x coordinate of the viewport
    #   @option opts [Integer] :y (0) y coordinate of the viewport
    #   @option opts [Integer] :width (320) width of the viewport
    #   @option opts [Integer] :height (240) height of the viewport
    #   @option opts [Integer, nil] :z (nil) superiority of the viewport
    # @return [Viewport] the generated viewport
    def create(x, y = 0, width = 1, height = 1, z = 0)
      if x.is_a?(Hash)
        z = x[:z] || z
        y = x[:y] || 0
        width = x[:width] || Configs.display.game_resolution.x
        height = x[:height] || Configs.display.game_resolution.y
        x = x[:x] || 0
      else
        if x.is_a?(Symbol)
          return create(CONFIGS[x], 0, 1, 1, y)
        end
      end
      gox = @global_offset_x || PSDK_CONFIG.viewport_offset_x || 0
      goy = @global_offset_y || PSDK_CONFIG.viewport_offset_y || 0
      v = Viewport.new(x + gox, y + goy, width, height, z)
      return v
    end
    # Load the viewport configs
    def load_configs
      unless PSDK_CONFIG.release?
        unless File.exist?(VIEWPORT_CONF_COMP) && File.exist?(VIEWPORT_CONF_TEXT)
          if File.exist?(VIEWPORT_CONF_TEXT)
            save_data(JSON.parse(File.read(VIEWPORT_CONF_TEXT), symbolize_names: true), VIEWPORT_CONF_COMP)
          else
            vp_conf = {main: {x: 0, y: 0, width: 320, height: 240}}
            File.write(VIEWPORT_CONF_TEXT, vp_conf.to_json)
            sleep(1)
            save_data(vp_conf, VIEWPORT_CONF_COMP)
          end
        end
        if File.mtime(VIEWPORT_CONF_TEXT) > File.mtime(VIEWPORT_CONF_COMP)
          log_debug('Updating Viewport Configuration...')
          save_data(JSON.parse(File.read(VIEWPORT_CONF_TEXT), symbolize_names: true), VIEWPORT_CONF_COMP)
        end
      end
      CONFIGS.merge!(load_data(VIEWPORT_CONF_COMP))
    end
  end
  # Format the viewport to string for logging purposes
  def to_s
    return '#<Viewport:disposed>' if disposed?
    return format('#<Viewport:%08x : %00d>', __id__, __index__)
  end
  alias inspect to_s
  # Flash the viewport
  # @param color [LiteRGSS::Color] the color used for the flash processing
  def flash(color, duration)
    self.shader ||= Shader.create(:color_shader_with_background)
    color ||= Color.new(0, 0, 0)
    @flash_color = color
    @flash_color_running = color.dup
    @flash_counter = 0
    @flash_duration = duration.to_f
  end
  # Update the viewport
  def update
    if @flash_color
      alpha = 1 - @flash_counter / @flash_duration
      @flash_color_running.alpha = @flash_color.alpha * alpha
      self.shader.set_float_uniform('color', @flash_color_running)
      @flash_counter += 1
      if @flash_counter >= @flash_duration
        self.shader.set_float_uniform('color', [0, 0, 0, 0])
        @flash_color_running = @flash_color = nil
      end
    end
  end
  # Module defining a shader'd entity that has .color and .tone methods (for flash or other purpose)
  module WithToneAndColors
    # Extended class of Tone allowing setters to port back values to the shader and its tied entity
    class Tone < LiteRGSS::Tone
      # Create a new Tied Tone
      # @param viewport [Viewport, Sprite] element on which the tone is tied
      # @param r [Integer] red color
      # @param g [Integer] green color
      # @param b [Integer] blue color
      # @param g2 [Integer] gray factor
      def initialize(viewport, r, g, b, g2)
        @viewport = viewport
        super(r, g, b, g2)
        update_viewport
      end
      # Set the attribute (according to how it works in normal class)
      # @param args [Array<Integer>]
      def set(*args)
        r = red
        g = green
        b = blue
        g2 = gray
        super
        update_viewport if r != red || g != green || b != blue || g2 != gray
      end
      # Set the red value
      # @param v [Integer]
      def red=(v)
        return if v == red
        super
        update_viewport
      end
      # Set the green value
      # @param v [Integer]
      def green=(v)
        return if v == green
        super
        update_viewport
      end
      # Set the blue value
      # @param v [Integer]
      def blue=(v)
        return if v == blue
        super
        update_viewport
      end
      # Set the gray value
      # @param v [Integer]
      def gray=(v)
        return if v == gray
        super
        update_viewport
      end
      private
      # Update the viewport tone shader attribute
      def update_viewport
        @viewport.shader&.set_float_uniform('tone', self)
      end
    end
    # Extended class of Color allowing setters to port back values to the shader and its tied entity
    class Color < LiteRGSS::Color
      # Create a new Tied Color
      # @param viewport [Viewport, Sprite] element on which the color is tied
      # @param r [Integer] red color
      # @param g [Integer] green color
      # @param b [Integer] blue color
      # @param a [Integer] alpha factor
      def initialize(viewport, r, g, b, a)
        @viewport = viewport
        super(r, g, b, a)
        update_viewport
      end
      # Set the attribute (according to how it works in normal class)
      # @param args [Array<Integer>]
      def set(*args)
        r = red
        g = green
        b = blue
        a = alpha
        super
        update_viewport if r != red || g != green || b != blue || a != alpha
      end
      # Set the red value
      # @param v [Integer]
      def red=(v)
        return if v == red
        super
        update_viewport
      end
      # Set the green value
      # @param v [Integer]
      def green=(v)
        return if v == green
        super
        update_viewport
      end
      # Set the blue value
      # @param v [Integer]
      def blue=(v)
        return if v == blue
        super
        update_viewport
      end
      # Set the alpha value
      # @param v [Integer]
      def alpha=(v)
        return if v == alpha
        super
        update_viewport
      end
      private
      # Update the viewport color shader attribute
      def update_viewport
        @viewport.shader&.set_float_uniform('color', self)
      end
    end
    # Set color of the viewport
    # @param value [Color]
    def color=(value)
      color.set(value.red, value.green, value.blue, value.alpha)
    end
    # Color of the viewport
    # @return [Color]
    def color
      @color ||= Color.new(self, 0, 0, 0, 0)
    end
    # Set the tone
    # @param value [Tone]
    def tone=(value)
      tone.set(value.red, value.green, value.blue, value.gray)
    end
    # Tone of the viewport
    # @return [Tone]
    def tone
      @tone ||= Tone.new(self, 0, 0, 0, 0)
    end
  end
end
Graphics.on_start {Viewport.load_configs }
# Class that describe a sprite shown on the screen or inside a viewport
class Sprite < LiteRGSS::ShaderedSprite
  # RGSS Compatibility "update" the sprite
  def update
    return nil
  end
  # define the superiority of the sprite
  # @param z [Integer] superiority
  # @return [self]
  def set_z(z)
    self.z = z
    return self
  end
  # define the pixel of the bitmap that is shown at the coordinate of the sprite.
  # The width and the height is divided by ox and oy to determine the pixel
  # @param ox [Numeric] factor of division of width to get the origin x
  # @param oy [Numeric] factor of division of height to get the origin y
  # @return [self]
  def set_origin_div(ox, oy)
    self.ox = bitmap.width / ox
    self.oy = bitmap.height / oy
    return self
  end
  # Define the surface of the bitmap that is shown on the screen surface
  # @param x [Integer] x coordinate on the bitmap
  # @param y [Integer] y coordinate on the bitmap
  # @param width [Integer] width of the surface
  # @param height [Integer] height of the surface
  # @return [self]
  def set_rect(x, y, width, height)
    src_rect.set(x, y, width, height)
    return self
  end
  # Define the surface of the bitmap that is shown with division of it
  # @param x [Integer] the division index to show on x
  # @param y [Integer] the division index to show on y
  # @param width [Integer] the division of width of the bitmap to show
  # @param height [Integer] the division of height of the bitmap to show
  # @return [self]
  def set_rect_div(x, y, width, height)
    width = bitmap.width / width
    height = bitmap.height / height
    src_rect.set(x * width, y * height, width, height)
    return self
  end
  # Set the texture show on the screen surface
  # @overload load(filename, cache_symbol)
  #   @param filename [String] the name of the image
  #   @param cache_symbol [Symbol] the symbol method to call with filename argument in RPG::Cache
  #   @param auto_rect [Boolean] if the rect should be automatically set
  # @overload load(bmp)
  #   @param texture [Texture, nil] the bitmap to show
  # @return [self]
  def load(texture, cache = nil, auto_rect = false)
    if cache && texture.is_a?(String)
      self.bitmap = RPG::Cache.send(cache, texture)
      set_rect_div(0, 0, 4, 4) if auto_rect && cache == :character
    else
      self.bitmap = texture
    end
    return self
  end
  alias set_bitmap load
  # Define a sprite that mix with a color
  class WithColor < Sprite
    # Create a new Sprite::WithColor
    # @param viewport [LiteRGSS::Viewport, nil]
    def initialize(viewport = nil)
      super(viewport)
      self.shader = Shader.create(:color_shader)
    end
    # Set the Sprite color
    # @param array [Array(Numeric, Numeric, Numeric, Numeric), LiteRGSS::Color] the color (values : 0~1.0)
    # @return [self]
    def color=(array)
      shader.set_float_uniform('color', array)
      return self
    end
    alias set_color color=
  end
end
# @deprecated Please use Sprite directly
class ShaderedSprite < Sprite
end
# Class simulating repeating texture
class Plane < Sprite
  # Shader of the Plane sprite
  SHADER = "// Viewport tone (required)\nuniform vec4 tone;\n// Viewport color (required)\nuniform vec4 color;\n// Zoom configuration\nuniform vec2 zoom;\n// Origin configuration\nuniform vec2 origin;\n// Texture size configuration\nuniform vec2 textureSize;\n// Texture source\nuniform sampler2D texture;\n// Plane Texture (what's zoomed origined etc...)\nuniform sampler2D planeTexture;\n// Screen size\nuniform vec2 screenSize;\n// Gray scale transformation vector\nconst vec3 lumaF = vec3(.299, .587, .114);\n// Main process\nvoid main()\n{\n  // Coordinate on the screen in pixel\n  vec2 screenCoord = gl_TexCoord[0].xy * screenSize;\n  // Coordinaet in the texture in pixel (including zoom)\n  vec2 bmpCoord = mod(origin + screenCoord / zoom, textureSize) / textureSize;\n  vec4 frag = texture2D(planeTexture, bmpCoord);\n  // Tone&Color process\n  frag.rgb = mix(frag.rgb, color.rgb, color.a);\n  float luma = dot(frag.rgb, lumaF);\n  frag.rgb += tone.rgb;\n  frag.rgb = mix(frag.rgb, vec3(luma), tone.w);\n  frag.a *= gl_Color.a;\n  // Result\n  gl_FragColor = frag * texture2D(texture, gl_TexCoord[0].xy);\n}\n"
  # Get the real texture
  # @return [Texture]
  attr_reader :texture
  # Return the visibility of the plane
  # @return [Boolean]
  attr_reader :visible
  # Return the color of the plane /!\ this is unlinked set() won't change the color
  # @return [Color]
  attr_reader :color
  # Return the tone of the plane /!\ this is unlinked set() won't change the color
  # @return [Tone]
  attr_reader :tone
  # Return the blend type
  # @return [Integer]
  attr_reader :blend_type
  # Create a new plane
  # @param viewport [Viewport]
  def initialize(viewport)
    super(viewport)
    self.shader = Shader.new(SHADER)
    self.working_texture = Plane.texture
    self.tone = Tone.new(0, 0, 0, 0)
    self.color = Color.new(255, 255, 255, 0)
    @blend_type = 0
    @texture = nil
    @origin = [0, 0]
    self.visible = true
    set_origin(0, 0)
    @zoom = [1, 1]
    self.zoom = 1
    shader.set_float_uniform('screenSize', [width, height])
  end
  alias working_texture= bitmap=
  alias working_texture bitmap
  # Set the texture of the plane
  # @param texture [Texture]
  def texture=(texture)
    @texture = texture
    if texture.is_a?(LiteRGSS::Bitmap)
      shader.set_texture_uniform('planeTexture', texture)
      shader.set_float_uniform('textureSize', [texture.width, texture.height])
    end
    self.visible = @visible
  end
  alias bitmap= texture=
  alias bitmap texture
  # Set the visibility of the plane
  # @param visible [Boolean]
  def visible=(visible)
    super(visible && @texture.is_a?(LiteRGSS::Bitmap) ? true : false)
    @visible = visible
  end
  # Set the zoom of the Plane
  # @param zoom [Float]
  def zoom=(zoom)
    @zoom[0] = @zoom[1] = zoom
    shader.set_float_uniform('zoom', @zoom)
  end
  # Set the zoom_x of the Plane
  # @param zoom [Float]
  def zoom_x=(zoom)
    @zoom[0] = zoom
    shader.set_float_uniform('zoom', @zoom)
  end
  # Get the zoom_x of the Plane
  # @return [Float]
  def zoom_x
    @zoom[0]
  end
  # Set the zoom_y of the Plane
  # @param zoom [Float]
  def zoom_y=(zoom)
    @zoom[1] = zoom
    shader.set_float_uniform('zoom', @zoom)
  end
  # Get the zoom_y of the Plane
  # @return [Float]
  def zoom_y
    @zoom[1]
  end
  # Set the origin of the Plane
  # @param ox [Float]
  # @param oy [Float]
  def set_origin(ox, oy)
    @origin[0] = ox
    @origin[1] = oy
    shader.set_float_uniform('origin', @origin)
  end
  # Set the ox of the Plane
  # @param origin [Float]
  def ox=(origin)
    @origin[0] = origin
    shader.set_float_uniform('origin', @origin)
  end
  # Get the ox of the Plane
  # @return [Float]
  def ox
    @origin[0]
  end
  # Set the oy of the Plane
  # @param origin [Float]
  def oy=(origin)
    @origin[1] = origin
    shader.set_float_uniform('origin', @origin)
  end
  # Get the oy of the Plane
  # @return [Float]
  def oy
    @origin[1]
  end
  # Set the color of the Plane
  # @param color [Color]
  def color=(color)
    if color != @color && color.is_a?(Color)
      shader.set_float_uniform('color', color)
      @color ||= color
      @color.set(color.red, color.green, color.blue, color.alpha)
    end
  end
  # Set the tone of the Plane
  # @param tone [Tone]
  def tone=(tone)
    if tone != @tone && tone.is_a?(Tone)
      shader.set_float_uniform('tone', tone)
      @tone ||= tone
      @tone.set(tone.red, tone.green, tone.blue, tone.gray)
    end
  end
  # Set the blend type
  # @param blend_type [Integer]
  def blend_type=(blend_type)
    shader.blend_type = blend_type
    @blend_type = blend_type
  end
  class << self
    # Get the generic plane texture
    # @return [Texture]
    def texture
      if !@texture || @texture.disposed?
        @texture = Texture.new(Graphics.width, Graphics.height)
        image = Image.new(Graphics.width, Graphics.height)
        Graphics.height.times do |y|
          image.fill_rect(0, y, Graphics.width, 1, Color.new(255, 255, 255, 255))
        end
        image.copy_to_bitmap(@texture)
        image.dispose
      end
      return @texture
    end
  end
  undef x
  undef x=
  undef y
  undef y=
  undef set_position
end
# Class that describes a text shown on the screen or inside a viewport
class Text < LiteRGSS::Text
end
# Class used to show a Window object on screen.
#
# A Window is an object that has a frame (built from #window_builder and #windowskin) and some contents that can be Sprites or Texts.
class Window < LiteRGSS::Window
end
# Class allowing to draw Shapes in a viewport
class Shape < LiteRGSS::Shape
end
# Class that allow to draw tiles on a row
class SpriteMap < LiteRGSS::SpriteMap
end
module LiteRGSS
  module Fonts
    @line_heights = []
    class << self
      # Load a line height for a specific font
      # @param font_id [Integer] ID of the font
      # @param line_height [Integer] new line height for the font
      def load_line_height(font_id, line_height)
        @line_heights[font_id] = line_height
      end
      # Get the line height for a specific font
      # @param font_id [Integer] ID of the font
      # @return [Integer]
      def line_height(font_id)
        @line_heights[font_id] || 16
      end
    end
  end
end
# Alias access to the Fonts module
Fonts = LiteRGSS::Fonts
Graphics.on_start do
  Configs.texts.fonts.ttf_files.each do |ttf_file|
    id = ttf_file[:id]
    LiteRGSS::Fonts.load_font(id, "Fonts/#{ttf_file[:name]}.ttf")
    LiteRGSS::Fonts.set_default_size(id, ttf_file[:size])
    LiteRGSS::Fonts.load_line_height(id, ttf_file[:lineHeight])
  end
  Configs.texts.fonts.alt_sizes.each do |size|
    id = size[:id]
    LiteRGSS::Fonts.set_default_size(id, size[:size])
    LiteRGSS::Fonts.load_line_height(id, size[:lineHeight])
  end
end
# Shader loaded applicable to a Sprite/Viewport or Graphics
#
# Special features:
#   Shader.register(name_sym, frag_file, vert_file = nil, tone_process: false, color_process: false, alpha_process: false)
#     This function registers a shader as name name_sym
#       if frag_file contains `void main()` it'll assume its the file contents of the shader
#       otherwise it'll assume it's the filename and load it from disc
#       if vert_file is nil, it won't load the vertex shader
#       if vert_file contains `void main()` it'll assume it's the file contents of the shader
#       otherwise it'll assume it's the filename and load it from disc
#       tone_process adds tone process to the shader (fragment color needs to be called frag), it'll add the required constant and uniforms (tone)
#       color_process adds the color process to the shader (fragment color needs to be called frag), it'll add the required uniforms (color)
#       alpha_process adds the alpha process to the shader (fragment color needs to be called frag), it'll use gl_Color.a
#   Shader.create(name_sym)
#     This function instanciate a shader by it's name_sym so you don't have to load the files several time and you have all the correct data
# @note `#version 120` will be automatically added to the begining of the file if not present
class Shader < LiteRGSS::Shader
  # Shader version based on the platform
  SHADER_VERSION = PSDK_PLATFORM == :macos ? "#version 120\n" : "#version 130\n"
  # Color uniform
  COLOR_UNIFORM = "\\0uniform vec4 color;\n"
  # Color process
  COLOR_PROCESS = "\n  frag.rgb = mix(frag.rgb, color.rgb, color.a);\\0"
  # Tone uniform
  TONE_UNIFORM = "\\0uniform vec4 tone;\nconst vec3 lumaF = vec3(.299, .587, .114);\n"
  # Tone process
  TONE_PROCESS = "\n  float luma = dot(frag.rgb, lumaF);\n  frag.rgb = mix(frag.rgb, vec3(luma), tone.w);\n  frag.rgb += tone.rgb;\\0"
  # Alpha process
  ALPHA_PROCESS = "\n  frag.a *= gl_Color.a;\\0"
  # Default shader when there's nothing to do
  DEFAULT_SHADER = "#{SHADER_VERSION}\nuniform sampler2D texture;\nvoid main() {\n  vec4 frag = texture2D(texture, gl_TexCoord[0].xy);\n  gl_FragColor = frag;\n}\n"
  # Part detecting the shader code begin
  SHADER_CONTENT_DETECTION = 'void main()'
  # Part detecting the shader version pre-processor
  SHADER_VERSION_DETECTION = '#version '
  # Part responsive of detecting where to add the processes
  SHADER_FRAG_FEATURE_ADD = /\n( |)+gl_FragColor( |)+=/
  # Part responsive of detecting where to add the uniforms
  SHADER_UNIFORM_ADD = /\#version[^\n]+\n/
  @registered_shaders = {}
  class << self
    # Register a new shader by it's name
    # @param name_sym [Symbol] name of the shader
    # @param frag_file [String] file content or filename of the frag shader, the function will look at void main() to know
    # @param vert_file [String] file content or filename of the vertex shader, the function will look at void main() to know
    # @param tone_process [Boolean] if the function should add tone_process to the shader
    # @param color_process [Boolean] if the function should add color_process to the shader
    # @param alpha_process [Boolean] if the function should add alpha_process to the shader
    def register(name_sym, frag_file, vert_file = nil, tone_process: false, color_process: false, alpha_process: false)
      frag = load_shader_file(frag_file)
      vert = vert_file && load_shader_file(vert_file)
      frag = add_frag_color(frag) if color_process
      frag = add_frag_tone(frag) if tone_process
      frag = add_frag_alpha(frag) if alpha_process
      @registered_shaders[name_sym] = [vert, frag].compact
    end
    # Function that creates a shader by its name
    # @param name_sym [Symbol] name of the shader
    # @return [Shader]
    def create(name_sym)
      Shader.new(*@registered_shaders[name_sym])
    end
    # Load a shader data from a file
    # @param filename [String] name of the file in Graphics/Shaders
    # @return [String] the shader string
    def load_to_string(filename)
      log_error("Calling Shader.load_to_string is deprecated, please use Shader.create(name) instead to get the right shader.\nThe game will sleep 10 seconds to make sure you see this message")
      sleep(10)
      return File.read("graphics/shaders/#{filename.downcase}.txt")
    rescue StandardError
      log_error("Failed to load shader #{filename}, sprite using this shader will not display correctly")
      return @registered_shaders[:full_shader]&.last || DEFAULT_SHADER
    end
    private
    # Function that loads the shader file
    # @param filecontent_or_name [String]
    # @return [String]
    def load_shader_file(filecontent_or_name)
      contents = filecontent_or_name.include?(SHADER_CONTENT_DETECTION) ? filecontent_or_name : File.read(filecontent_or_name)
      return SHADER_VERSION + contents unless contents.include?(SHADER_VERSION_DETECTION)
      return contents
    end
    # Function that adds the color processing to shader
    # @param shader [String] shader code
    # @return [String]
    def add_frag_color(shader)
      return shader.sub(SHADER_UNIFORM_ADD, COLOR_UNIFORM).sub(SHADER_FRAG_FEATURE_ADD, COLOR_PROCESS)
    end
    # Function that adds the tone processing to shader
    # @param shader [String] shader code
    # @return [String]
    def add_frag_tone(shader)
      return shader.sub(SHADER_UNIFORM_ADD, TONE_UNIFORM).sub(SHADER_FRAG_FEATURE_ADD, TONE_PROCESS)
    end
    # Function that adds the alpha processing to shader
    # @param shader [String] shader code
    # @return [String]
    def add_frag_alpha(shader)
      return shader.sub(SHADER_FRAG_FEATURE_ADD, ALPHA_PROCESS)
    end
  end
  safe_code('Default shader loading') do
    Graphics.on_start do
      background_color_shader = DEFAULT_SHADER.sub(SHADER_FRAG_FEATURE_ADD, "\n  frag.a = max(frag.a, color.a);\\0")
      register(:map_shader, background_color_shader, tone_process: true, color_process: true)
      register(:tone_shader, DEFAULT_SHADER, tone_process: true, alpha_process: true)
      register(:color_shader, DEFAULT_SHADER, color_process: true, alpha_process: true)
      register(:color_shader_with_background, background_color_shader, color_process: true, alpha_process: true)
      register(:full_shader, DEFAULT_SHADER, tone_process: true, color_process: true, alpha_process: true)
      register(:yuki_circular, 'graphics/shaders/yuki_transition_circular.txt')
      register(:yuki_directed, 'graphics/shaders/yuki_transition_directed.txt')
      register(:yuki_weird, 'graphics/shaders/yuki_transition_weird.txt')
      register(:blur, 'graphics/shaders/blur.txt')
      register(:battle_shadow, 'graphics/shaders/battle_shadow.frag', 'graphics/shaders/battle_shadow.vert')
      register(:battle_backout, 'graphics/shaders/battle_backout.frag')
      register(:graphics_transition, Graphics::TRANSITION_FRAG_SHADER)
      register(:graphics_transition_static, Graphics::STATIC_TRANSITION_FRAG_SHADER)
    end
  end
end
# @private
module RPG
  class Animation
    attr_accessor :id
    attr_accessor :name
    attr_accessor :animation_name
    attr_accessor :animation_hue
    attr_accessor :position
    attr_accessor :frame_max
    attr_accessor :frames
    attr_accessor :timings
    class Frame
      attr_accessor :cell_max
      attr_accessor :cell_data
    end
    class Timing
      attr_accessor :frame
      attr_accessor :se
      attr_accessor :flash_scope
      attr_accessor :flash_color
      attr_accessor :flash_duration
      attr_accessor :condition
    end
  end
  class AudioFile
    def initialize(name = '', volume = 100, pitch = 100)
      @name = name
      @volume = volume
      @pitch = pitch
    end
    attr_accessor :name
    attr_accessor :volume
    attr_accessor :pitch
  end
  class Class
    class Learning
    end
  end
  class CommonEvent
    attr_accessor :id
    attr_accessor :name
    attr_accessor :trigger
    attr_accessor :switch_id
    attr_accessor :list
  end
  class Enemy
    attr_accessor :id
    attr_accessor :name
    attr_accessor :battler_name
    attr_accessor :battler_hue
    attr_accessor :maxhp
    attr_accessor :str
    attr_accessor :dex
    attr_accessor :agi
    attr_accessor :int
    attr_accessor :atk
    attr_accessor :pdef
    attr_accessor :mdef
    attr_accessor :eva
    attr_accessor :element_ranks
    attr_accessor :state_ranks
    attr_accessor :actions
    attr_accessor :exp
    attr_accessor :gold
    attr_accessor :item_id
    attr_accessor :weapon_id
    attr_accessor :armor_id
    attr_accessor :treasure_prob
    class Action
    end
  end
  class Event
    attr_accessor :id
    attr_accessor :name
    attr_accessor :x
    attr_accessor :y
    attr_accessor :pages
    # Properties dedicated to the MapLinker
    attr_accessor :original_id, :original_map, :offset_x, :offset_y
    class Page
      attr_accessor :condition
      attr_accessor :graphic
      attr_accessor :move_type
      attr_accessor :move_speed
      attr_accessor :move_frequency
      attr_accessor :move_route
      attr_accessor :walk_anime
      attr_accessor :step_anime
      attr_accessor :direction_fix
      attr_accessor :through
      attr_accessor :always_on_top
      attr_accessor :trigger
      attr_accessor :list
      class Condition
        # Return if the page condition is currently valid
        # @param map_id [Integer] ID of the map where the event is
        # @param event_id [Integer] ID of the event
        # @return [Boolean] if the page is valid
        def valid?(map_id, event_id)
          return false if @switch1_valid && !$game_switches[@switch1_id]
          return false if @switch2_valid && !$game_switches[@switch2_id]
          return false if @variable_valid && $game_variables[@variable_id] < @variable_value
          if @self_switch_valid
            return false unless $game_self_switches[[map_id, event_id, @self_switch_ch]]
          end
          return true
        end
        attr_accessor :switch1_valid
        attr_accessor :switch2_valid
        attr_accessor :variable_valid
        attr_accessor :self_switch_valid
        attr_accessor :switch1_id
        attr_accessor :switch2_id
        attr_accessor :variable_id
        attr_accessor :variable_value
        attr_accessor :self_switch_ch
      end
      class Graphic
        attr_accessor :tile_id
        attr_accessor :character_name
        attr_accessor :character_hue
        attr_accessor :direction
        attr_accessor :pattern
        attr_accessor :opacity
        attr_accessor :blend_type
      end
    end
  end
  class EventCommand
    attr_accessor :code
    attr_accessor :indent
    attr_accessor :parameters
  end
  class Map
    def initialize(width, height)
      @tileset_id = 1
      @width = width
      @height = height
      @autoplay_bgm = false
      @bgm = RPG::AudioFile.new
      @autoplay_bgs = false
      @bgs = RPG::AudioFile.new('', 80)
      @encounter_list = []
      @encounter_step = 30
      @data = Table.new(width, height, 3)
      @data.fill(0)
      @events = {}
    end
    attr_accessor :tileset_id
    attr_accessor :width
    attr_accessor :height
    attr_accessor :autoplay_bgm
    attr_accessor :bgm
    attr_accessor :autoplay_bgs
    attr_accessor :bgs
    attr_accessor :encounter_list
    attr_accessor :encounter_step
    attr_accessor :data
    attr_accessor :events
  end
  class MapInfo
    attr_accessor :name
    attr_accessor :parent_id
    attr_accessor :order
    attr_accessor :expanded
    attr_accessor :scroll_x
    attr_accessor :scroll_y
  end
  class MoveCommand
    def initialize(code = 0, parameters = [])
      @code = code
      @parameters = parameters
    end
    attr_accessor :code
    attr_accessor :parameters
  end
  class MoveRoute
    def initialize
      @repeat = true
      @skippable = false
      @list = [RPG::MoveCommand.new]
    end
    attr_accessor :repeat
    attr_accessor :skippable
    attr_accessor :list
  end
  class Sprite < ::Sprite
    attr_accessor :blend_type
    attr_accessor :bush_depth
    attr_accessor :tone
    attr_accessor :color
    def flash(*args)
    end
    def color
      return Color.new(0, 0, 0, 0)
    end
    def tone
      return Tone.new(0, 0, 0, 0)
    end
    @@_animations = []
    @@_reference_count = {}
    def initialize(viewport = nil)
      super(viewport)
      @_whiten_duration = 0
      @_appear_duration = 0
      @_escape_duration = 0
      @_collapse_duration = 0
      @_damage_duration = 0
      @_animation_duration = 0
      @_blink = false
    end
    def dispose
      dispose_damage
      dispose_animation
      dispose_loop_animation
      super
    end
    def whiten
      self.blend_type = 0
      self.color.set(255, 255, 255, 128)
      self.opacity = 255
      @_whiten_duration = 16
      @_appear_duration = 0
      @_escape_duration = 0
      @_collapse_duration = 0
    end
    def appear
      self.blend_type = 0
      self.color.set(0, 0, 0, 0)
      self.opacity = 0
      @_appear_duration = 16
      @_whiten_duration = 0
      @_escape_duration = 0
      @_collapse_duration = 0
    end
    def escape
      self.blend_type = 0
      self.color.set(0, 0, 0, 0)
      self.opacity = 255
      @_escape_duration = 32
      @_whiten_duration = 0
      @_appear_duration = 0
      @_collapse_duration = 0
    end
    def collapse
      self.blend_type = 1
      self.color.set(255, 64, 64, 255)
      self.opacity = 255
      @_collapse_duration = 48
      @_whiten_duration = 0
      @_appear_duration = 0
      @_escape_duration = 0
    end
    def damage(value, critical)
      dispose_damage
      if value.is_a?(Numeric)
        damage_string = value.abs.to_s
      else
        damage_string = value.to_s
      end
      bitmap = Texture.new(160, 48)
      bitmap.font.name = 'Arial Black'
      bitmap.font.size = 32
      bitmap.font.color.set(0, 0, 0)
      bitmap.draw_text(-1, 12 - 1, 160, 36, damage_string, 1)
      bitmap.draw_text(+1, 12 - 1, 160, 36, damage_string, 1)
      bitmap.draw_text(-1, 12 + 1, 160, 36, damage_string, 1)
      bitmap.draw_text(+1, 12 + 1, 160, 36, damage_string, 1)
      if value.is_a?(Numeric) && value < 0
        bitmap.font.color.set(176, 255, 144)
      else
        bitmap.font.color.set(255, 255, 255)
      end
      bitmap.draw_text(0, 12, 160, 36, damage_string, 1)
      if critical
        bitmap.font.size = 20
        bitmap.font.color.set(0, 0, 0)
        bitmap.draw_text(-1, -1, 160, 20, 'CRITICAL', 1)
        bitmap.draw_text(+1, -1, 160, 20, 'CRITICAL', 1)
        bitmap.draw_text(-1, +1, 160, 20, 'CRITICAL', 1)
        bitmap.draw_text(+1, +1, 160, 20, 'CRITICAL', 1)
        bitmap.font.color.set(255, 255, 255)
        bitmap.draw_text(0, 0, 160, 20, 'CRITICAL', 1)
      end
      @_damage_sprite = ::Sprite.new(self.viewport)
      @_damage_sprite.bitmap = bitmap
      @_damage_sprite.ox = 80
      @_damage_sprite.oy = 20
      @_damage_sprite.x = self.x
      @_damage_sprite.y = self.y - self.oy / 2
      @_damage_sprite.z = 3000
      @_damage_duration = 40
    end
    def animation(animation, hit)
      dispose_animation
      @_animation = animation
      return if @_animation == nil
      @_animation_hit = hit
      @_animation_duration = @_animation.frame_max
      animation_name = @_animation.animation_name
      animation_hue = @_animation.animation_hue
      bitmap = RPG::Cache.animation(animation_name, animation_hue)
      if @@_reference_count.include?(bitmap)
        @@_reference_count[bitmap] += 1
      else
        @@_reference_count[bitmap] = 1
      end
      @_animation_sprites = []
      if @_animation.position != 3 || !@@_animations.include?(animation)
        for i in 0..15
          sprite = ::Sprite.new(self.viewport)
          sprite.bitmap = bitmap
          sprite.visible = false
          @_animation_sprites.push(sprite)
        end
        unless @@_animations.include?(animation)
          @@_animations.push(animation)
        end
      end
      update_animation
    end
    def loop_animation(animation)
      return if animation == @_loop_animation
      dispose_loop_animation
      @_loop_animation = animation
      return if @_loop_animation == nil
      @_loop_animation_index = 0
      animation_name = @_loop_animation.animation_name
      animation_hue = @_loop_animation.animation_hue
      bitmap = RPG::Cache.animation(animation_name, animation_hue)
      if @@_reference_count.include?(bitmap)
        @@_reference_count[bitmap] += 1
      else
        @@_reference_count[bitmap] = 1
      end
      @_loop_animation_sprites = []
      for i in 0..15
        sprite = ::Sprite.new(self.viewport)
        sprite.bitmap = bitmap
        sprite.visible = false
        @_loop_animation_sprites.push(sprite)
      end
      update_loop_animation
    end
    def dispose_damage
      if @_damage_sprite != nil
        @_damage_sprite.bitmap.dispose
        @_damage_sprite.dispose
        @_damage_sprite = nil
        @_damage_duration = 0
      end
    end
    def dispose_animation
      if @_animation_sprites != nil
        sprite = @_animation_sprites[0]
        if sprite != nil
          @@_reference_count[sprite.bitmap] -= 1
          if @@_reference_count[sprite.bitmap] == 0
            sprite.bitmap.dispose
          end
        end
        for sprite in @_animation_sprites
          sprite.dispose
        end
        @_animation_sprites = nil
        @_animation = nil
      end
    end
    def dispose_loop_animation
      if @_loop_animation_sprites != nil
        sprite = @_loop_animation_sprites[0]
        if sprite != nil
          @@_reference_count[sprite.bitmap] -= 1
          if @@_reference_count[sprite.bitmap] == 0
            sprite.bitmap.dispose
          end
        end
        for sprite in @_loop_animation_sprites
          sprite.dispose
        end
        @_loop_animation_sprites = nil
        @_loop_animation = nil
      end
    end
    def blink_on
      unless @_blink
        @_blink = true
        @_blink_count = 0
      end
    end
    def blink_off
      if @_blink
        @_blink = false
        self.color.set(0, 0, 0, 0)
      end
    end
    def blink?
      @_blink
    end
    def effect?
      @_whiten_duration > 0 || @_appear_duration > 0 || @_escape_duration > 0 || @_collapse_duration > 0 || @_damage_duration > 0 || @_animation_duration > 0
    end
    def update
      super
      if @_whiten_duration > 0
        @_whiten_duration -= 1
        self.color.alpha = 128 - (16 - @_whiten_duration) * 10
      end
      if @_appear_duration > 0
        @_appear_duration -= 1
        self.opacity = (16 - @_appear_duration) * 16
      end
      if @_escape_duration > 0
        @_escape_duration -= 1
        self.opacity = 256 - (32 - @_escape_duration) * 10
      end
      if @_collapse_duration > 0
        @_collapse_duration -= 1
        self.opacity = 256 - (48 - @_collapse_duration) * 6
      end
      if @_damage_duration > 0
        @_damage_duration -= 1
        case @_damage_duration
        when 38..39
          @_damage_sprite.y -= 4
        when 36..37
          @_damage_sprite.y -= 2
        when 34..35
          @_damage_sprite.y += 2
        when 28..33
          @_damage_sprite.y += 4
        end
        @_damage_sprite.opacity = 256 - (12 - @_damage_duration) * 32
        if @_damage_duration == 0
          dispose_damage
        end
      end
      if @_animation != nil && (Graphics.frame_count % 2 == 0)
        @_animation_duration -= 1
        update_animation
      end
      if @_loop_animation != nil && (Graphics.frame_count % 2 == 0)
        update_loop_animation
        @_loop_animation_index += 1
        @_loop_animation_index %= @_loop_animation.frame_max
      end
      if @_blink
        @_blink_count = (@_blink_count + 1) % 32
        if @_blink_count < 16
          alpha = (16 - @_blink_count) * 6
        else
          alpha = (@_blink_count - 16) * 6
        end
        self.color.set(255, 255, 255, alpha)
      end
      @@_animations.clear
    end
    def update_animation
      if @_animation_duration > 0
        frame_index = @_animation.frame_max - @_animation_duration
        cell_data = @_animation.frames[frame_index].cell_data
        position = @_animation.position
        animation_set_sprites(@_animation_sprites, cell_data, position)
        for timing in @_animation.timings
          if timing.frame == frame_index
            animation_process_timing(timing, @_animation_hit)
          end
        end
      else
        dispose_animation
      end
    end
    def update_loop_animation
      frame_index = @_loop_animation_index
      cell_data = @_loop_animation.frames[frame_index].cell_data
      position = @_loop_animation.position
      animation_set_sprites(@_loop_animation_sprites, cell_data, position)
      for timing in @_loop_animation.timings
        if timing.frame == frame_index
          animation_process_timing(timing, true)
        end
      end
    end
    def animation_set_sprites(sprites, cell_data, position)
      for i in 0..15
        sprite = sprites[i]
        pattern = cell_data[i, 0]
        if sprite == nil || pattern == nil || pattern == -1
          sprite.visible = false if sprite != nil
          next
        end
        sprite.visible = true
        sprite.src_rect.set(pattern % 5 * 192, pattern / 5 * 192, 192, 192)
        if position == 3
          if self.viewport != nil
            sprite.x = self.viewport.rect.width / 2
            sprite.y = self.viewport.rect.height - 160
          else
            sprite.x = 320
            sprite.y = 240
          end
        else
          sprite.x = self.x - self.ox + self.src_rect.width / 2
          sprite.y = self.y - self.oy + self.src_rect.height / 2
          sprite.y -= self.src_rect.height / 4 if position == 0
          sprite.y += self.src_rect.height / 4 if position == 2
        end
        sprite.x += cell_data[i, 1]
        sprite.y += cell_data[i, 2]
        sprite.z = 2000
        sprite.ox = 96
        sprite.oy = 96
        sprite.zoom_x = cell_data[i, 3] / 100.0
        sprite.zoom_y = cell_data[i, 3] / 100.0
        sprite.angle = cell_data[i, 4]
        sprite.mirror = (cell_data[i, 5] == 1)
        sprite.opacity = cell_data[i, 6] * self.opacity / 255.0
        sprite.blend_type = cell_data[i, 7]
      end
    end
    def animation_process_timing(timing, hit)
      if (timing.condition == 0) || (timing.condition == 1 && hit == true) || (timing.condition == 2 && hit == false)
        if timing.se.name != ''
          se = timing.se
          Audio.se_play('Audio/SE/' + se.name, se.volume, se.pitch)
        end
        case timing.flash_scope
        when 1
          self.flash(timing.flash_color, timing.flash_duration * 2)
        when 2
          if self.viewport != nil
            self.viewport.flash(timing.flash_color, timing.flash_duration * 2)
          end
        when 3
          self.flash(nil, timing.flash_duration * 2)
        end
      end
    end
    def x=(x)
      sx = x - self.x
      if sx != 0
        if @_animation_sprites != nil
          for i in 0..15
            @_animation_sprites[i].x += sx
          end
        end
        if @_loop_animation_sprites != nil
          for i in 0..15
            @_loop_animation_sprites[i].x += sx
          end
        end
      end
      super
    end
    def y=(y)
      sy = y - self.y
      if sy != 0
        if @_animation_sprites != nil
          for i in 0..15
            @_animation_sprites[i].y += sy
          end
        end
        if @_loop_animation_sprites != nil
          for i in 0..15
            @_loop_animation_sprites[i].y += sy
          end
        end
      end
      super
    end
  end
  class System
    attr_accessor :magic_number
    attr_accessor :party_members
    attr_accessor :elements
    attr_accessor :switches
    attr_accessor :variables
    attr_accessor :windowskin_name
    attr_accessor :title_name
    attr_accessor :gameover_name
    attr_accessor :battle_transition
    attr_accessor :title_bgm
    attr_accessor :battle_bgm
    attr_accessor :battle_end_me
    attr_accessor :gameover_me
    attr_accessor :cursor_se
    attr_accessor :decision_se
    attr_accessor :cancel_se
    attr_accessor :buzzer_se
    attr_accessor :equip_se
    attr_accessor :shop_se
    attr_accessor :save_se
    attr_accessor :load_se
    attr_accessor :battle_start_se
    attr_accessor :escape_se
    attr_accessor :actor_collapse_se
    attr_accessor :enemy_collapse_se
    attr_accessor :words
    attr_accessor :test_battlers
    attr_accessor :test_troop_id
    attr_accessor :start_map_id
    attr_accessor :start_x
    attr_accessor :start_y
    attr_accessor :battleback_name
    attr_accessor :battler_name
    attr_accessor :battler_hue
    attr_accessor :edit_map_id
    class TestBattler
      attr_accessor :actor_id
      attr_accessor :level
      attr_accessor :weapon_id
      attr_accessor :armor1_id
      attr_accessor :armor2_id
      attr_accessor :armor3_id
      attr_accessor :armor4_id
    end
    class Words
    end
  end
  class Tileset
    attr_accessor :id
    attr_accessor :name
    attr_accessor :tileset_name
    attr_accessor :autotile_names
    attr_accessor :panorama_name
    attr_accessor :panorama_hue
    attr_accessor :fog_name
    attr_accessor :fog_hue
    attr_accessor :fog_opacity
    attr_accessor :fog_blend_type
    attr_accessor :fog_zoom
    attr_accessor :fog_sx
    attr_accessor :fog_sy
    attr_accessor :battleback_name
    attr_accessor :passages
    attr_accessor :priorities
    attr_accessor :terrain_tags
  end
  class Troop
    attr_accessor :id
    attr_accessor :name
    attr_accessor :members
    attr_accessor :pages
    class Member
      attr_accessor :enemy_id
      attr_accessor :x
      attr_accessor :y
      attr_accessor :hidden
    end
    class Page
      attr_accessor :condition
      attr_accessor :span
      attr_accessor :list
      class Condition
        attr_accessor :turn_valid
        attr_accessor :enemy_valid
        attr_accessor :actor_valid
        attr_accessor :switch_valid
        attr_accessor :turn_a
        attr_accessor :turn_b
        attr_accessor :enemy_index
        attr_accessor :enemy_hp
        attr_accessor :actor_id
        attr_accessor :actor_hp
        attr_accessor :switch_id
      end
    end
  end
  class Actor
    attr_accessor :id
    attr_accessor :name
    attr_accessor :initial_level
    attr_accessor :final_level
    attr_accessor :exp_basis
    attr_accessor :exp_inflation
    attr_accessor :character_name
    attr_accessor :character_hue
    attr_accessor :battler_name
    attr_accessor :battler_hue
    attr_accessor :parameters
    attr_accessor :weapon_id
    attr_accessor :armor1_id
    attr_accessor :armor2_id
    attr_accessor :armor3_id
    attr_accessor :armor4_id
    attr_accessor :weapon_fix
    attr_accessor :armor1_fix
    attr_accessor :armor2_fix
    attr_accessor :armor3_fix
    attr_accessor :armor4_fix
  end
  # Script that cache bitmaps when they are reusable.
  # @author Nuri Yuri
  module Cache
    # Array of load methods to call when the game starts
    LOADS = %i[load_animation load_autotile load_ball load_battleback load_battler load_character load_fog load_icon load_panorama load_particle load_pc load_picture load_pokedex load_title load_tileset load_transition load_interface load_foot_print load_b_icon load_poke_front load_poke_back]
    # Extension of gif files
    GIF_EXTENSION = '.gif'
    # Common filename of the image to load
    Common_filename = 'Graphics/%s/%s'
    # Common filename with .png
    Common_filename_format = format('%s.png', Common_filename)
    # Notification message when an image couldn't be loaded properly
    Notification_title = 'Failed to load graphic'
    # Path where autotiles are stored from Graphics
    Autotiles_Path = 'autotiles'
    # Path where animations are stored from Graphics
    Animations_Path = 'animations'
    # Path where ball are stored from Graphics
    Ball_Path = 'ball'
    # Path where battlebacks are stored from Graphics
    BattleBacks_Path = 'battlebacks'
    # Path where battlers are stored from Graphics
    Battlers_Path = 'battlers'
    # Path where characters are stored from Graphics
    Characters_Path = 'characters'
    # Path where fogs are stored from Graphics
    Fogs_Path = 'fogs'
    # Path where icons are stored from Graphics
    Icons_Path = 'icons'
    # Path where interface are stored from Graphics
    Interface_Path = 'interface'
    # Path where panoramas are stored from Graphics
    Panoramas_Path = 'panoramas'
    # Path where particles are stored from Graphics
    Particles_Path = 'particles'
    # Path where pc are stored from Graphics
    PC_Path = 'pc'
    # Path where pictures are stored from Graphics
    Pictures_Path = 'pictures'
    # Path where pokedex images are stored from Graphics
    Pokedex_Path = 'pokedex'
    # Path where titles are stored from Graphics
    Titles_Path = 'titles'
    # Path where tilesets are stored from Graphics
    Tilesets_Path = 'tilesets'
    # Path where transitions are stored from Graphics
    Transitions_Path = 'transitions'
    # Path where windowskins are stored from Graphics
    Windowskins_Path = 'windowskins'
    # Path where footprints are stored from Graphics
    Pokedex_FootPrints_Path = 'pokedex/footprints'
    # Path where pokeicon are stored from Graphics
    Pokedex_PokeIcon_Path = 'pokedex/pokeicon'
    # Path where pokefront are stored from Graphics
    Pokedex_PokeFront_Path = ['pokedex/pokefront', 'pokedex/pokefrontshiny']
    # Path where pokeback are stored from Graphics
    Pokedex_PokeBack_Path = ['pokedex/pokeback', 'pokedex/pokebackshiny']
    module_function
    # Gets the default bitmap
    # @note Should be used in scripts that require a bitmap be doesn't perform anything on the bitmap
    def default_bitmap
      @default_bitmap = Texture.new(16, 16) if @default_bitmap&.disposed?
      @default_bitmap
    end
    # Dispose every bitmap of a cache table
    # @param cache_tab [Hash{String => Texture}] cache table where bitmaps should be disposed
    def dispose_bitmaps_from_cache_tab(cache_tab)
      cache_tab.each_value { |bitmap| bitmap.dispose if bitmap && !bitmap.disposed? }
      cache_tab.clear
    end
    # Test if a file exist
    # @param filename [String] filename of the image
    # @param path [String] path of the image inside Graphics/
    # @param file_data [Yuki::VD] "virtual directory"
    # @return [Boolean] if the image exist or not
    def test_file_existence(filename, path, file_data = nil)
      return true if file_data&.exists?(filename.downcase)
      return true if File.exist?(format(Common_filename_format, path, filename).downcase)
      return true if File.exist?(format(Common_filename, path, filename).downcase)
      false
    end
    # Loads an image (from cache, disk or virtual directory)
    # @param cache_tab [Hash{String => Texture}] cache table where bitmaps are being stored
    # @param filename [String] filename of the image
    # @param path [String] path of the image inside Graphics/
    # @param file_data [Yuki::VD] "virtual directory"
    # @param image_class [Class] Texture or Image depending on the desired process
    # @return [Texture]
    # @note This function displays a desktop notification if the image is not found.
    #       The resultat bitmap is an empty 16x16 bitmap in this case.
    def load_image(cache_tab, filename, path, file_data = nil, image_class = Texture)
      complete_filename = format(Common_filename, path, filename).downcase
      return bitmap = image_class.new(16, 16) if File.directory?(complete_filename) || filename.empty?
      return File.binread(complete_filename) if File.exist?(complete_filename)
      bitmap = cache_tab.fetch(filename, nil)
      if !bitmap || bitmap.disposed?
        filename_ext = "#{complete_filename}.png"
        bitmap = image_class.new(filename_ext) if File.exist?(filename_ext) || !file_data.exists?(filename.downcase)
        bitmap = load_image_from_file_data(filename, file_data, image_class) if (!bitmap || bitmap.disposed?) && file_data
        bitmap ||= image_class.new(16, 16)
      end
      return bitmap
    rescue StandardError
      log_error "#{Notification_title} #{complete_filename}"
      return bitmap = image_class.new("\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0 \0\0\0 \x02\x03\0\0\0\x0e\x14\x92g\0\0\0\tPLTE\0\0\0\xff\xff\xff\xff\0\0\xcd^\xb7\x9c\0\0\0>IDATx\x01\x85\xcf1\x0e\0 \x08CQ\x17\xef\xe7\xd2\x85\xfb\xb1\xf4\x94&$Fm\x07\xfe\xf4\x06B`x\x13\xd5z\xc0\xea\x07 H \x04\x91\x02\xd2\x01E\x9e\xcd\x17\xd1\xc3/\xecg\xecSk\x03[\xafg\x99\xe2\xed\xcfV\0\0\0\0IEND\xaeB`\x82", true)
    ensure
      cache_tab[filename] = bitmap if bitmap.is_a?(Texture)
    end
    # Loads an image from virtual directory with the right encoding
    # @param filename [String] filename of the image
    # @param file_data [Yuki::VD] "virtual directory"
    # @param image_class [Class] Texture or Image depending on the desired process
    # @return [Texture] the image loaded from the virtual directory
    def load_image_from_file_data(filename, file_data, image_class)
      bitmap_data = file_data.read_data(filename.downcase)
      return bitmap_data if filename.end_with?(GIF_EXTENSION)
      bitmap = image_class.new(bitmap_data, true) if bitmap_data
      bitmap
    end
    # Load/unload the animation cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_animation(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@animation_cache)
      else
        @animation_cache = {}
        @animation_data = Yuki::VD.new(PSDK_PATH + '/master/animation', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def animation_exist?(filename)
      test_file_existence(filename, Animations_Path, @animation_data)
    end
    # Load an animation image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def animation(filename, _hue = 0)
      load_image(@animation_cache, filename, Animations_Path, @animation_data)
    end
    # Load/unload the autotile cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_autotile(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@autotile_cache)
      else
        @autotile_cache = {}
        @autotile_data = Yuki::VD.new(PSDK_PATH + '/master/autotile', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def autotile_exist?(filename)
      test_file_existence(filename, Autotiles_Path, @autotile_data)
    end
    # Load an autotile image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def autotile(filename, _hue = 0)
      load_image(@autotile_cache, filename, Autotiles_Path, @autotile_data)
    end
    # Load/unload the ball cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_ball(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@ball_cache)
      else
        @ball_cache = {}
        @ball_data = Yuki::VD.new(PSDK_PATH + '/master/ball', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def ball_exist?(filename)
      test_file_existence(filename, Ball_Path, @ball_data)
    end
    # Load ball animation image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def ball(filename, _hue = 0)
      load_image(@ball_cache, filename, Ball_Path, @ball_data)
    end
    # Load/unload the battleback cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_battleback(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@battleback_cache)
      else
        @battleback_cache = {}
        @battleback_data = Yuki::VD.new(PSDK_PATH + '/master/battleback', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def battleback_exist?(filename)
      test_file_existence(filename, BattleBacks_Path, @battleback_data)
    end
    # Load a battle back image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def battleback(filename, _hue = 0)
      load_image(@battleback_cache, filename, BattleBacks_Path, @battleback_data)
    end
    # Load/unload the battler cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_battler(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@battler_cache)
      else
        @battler_cache = {}
        @battler_data = Yuki::VD.new(PSDK_PATH + '/master/battler', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def battler_exist?(filename)
      test_file_existence(filename, Battlers_Path, @battler_data)
    end
    # Load a battler image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def battler(filename, _hue = 0)
      load_image(@battler_cache, filename, Battlers_Path, @battler_data)
    end
    # Load/unload the character cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_character(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@character_cache)
      else
        @character_cache = {}
        @character_data = Yuki::VD.new(PSDK_PATH + '/master/character', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def character_exist?(filename)
      test_file_existence(filename, Characters_Path, @character_data)
    end
    # Load a character image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def character(filename, _hue = 0)
      load_image(@character_cache, filename, Characters_Path, @character_data)
    end
    # Load/unload the fog cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_fog(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@fog_cache)
      else
        @fog_cache = {}
        @fog_data = Yuki::VD.new(PSDK_PATH + '/master/fog', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def fog_exist?(filename)
      test_file_existence(filename, Fogs_Path, @fog_data)
    end
    # Load a fog image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def fog(filename, _hue = 0)
      load_image(@fog_cache, filename, Fogs_Path, @fog_data)
    end
    # Load/unload the icon cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_icon(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@icon_cache)
      else
        @icon_cache = {}
        @icon_data = Yuki::VD.new(PSDK_PATH + '/master/icon', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def icon_exist?(filename)
      test_file_existence(filename, Icons_Path, @icon_data)
    end
    # Load an icon
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def icon(filename, _hue = 0)
      load_image(@icon_cache, filename, Icons_Path, @icon_data)
    end
    # Load/unload the interface cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_interface(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@interface_cache)
      else
        @interface_cache = {}
        @interface_data = Yuki::VD.new(PSDK_PATH + '/master/interface', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def interface_exist?(filename)
      test_file_existence(filename, Interface_Path, @interface_data)
    end
    # Load an interface image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def interface(filename, _hue = 0)
      if interface_exist?(filename_with_language = filename + ($options&.language || 'en')) || interface_exist?(filename_with_language = filename + 'en')
        filename = filename_with_language
      end
      load_image(@interface_cache, filename, Interface_Path, @interface_data)
    end
    # Load an interface "Image" (to perform some background process)
    # @param filename [String] name of the image in the folder
    # @return [Image]
    def interface_image(filename)
      if interface_exist?(filename_with_language = filename + ($options&.language || 'en')) || interface_exist?(filename_with_language = filename + 'en')
        filename = filename_with_language
      end
      load_image(@interface_cache, filename, Interface_Path, @interface_data, Image)
    end
    # Load/unload the panorama cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_panorama(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@panorama_cache)
      else
        @panorama_cache = {}
        @panorama_data = Yuki::VD.new(PSDK_PATH + '/master/panorama', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def panorama_exist?(filename)
      test_file_existence(filename, Panoramas_Path, @panorama_data)
    end
    # Load a panorama image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def panorama(filename, _hue = 0)
      load_image(@panorama_cache, filename, Panoramas_Path, @panorama_data)
    end
    # Load/unload the particle cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_particle(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@particle_cache)
      else
        @particle_cache = {}
        @particle_data = Yuki::VD.new(PSDK_PATH + '/master/particle', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def particle_exist?(filename)
      test_file_existence(filename, Particles_Path, @particle_data)
    end
    # Load a particle image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def particle(filename, _hue = 0)
      load_image(@particle_cache, filename, Particles_Path, @particle_data)
    end
    # Load/unload the pc cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_pc(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@pc_cache)
      else
        @pc_cache = {}
        @pc_data = Yuki::VD.new(PSDK_PATH + '/master/pc', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def pc_exist?(filename)
      test_file_existence(filename, PC_Path, @pc_data)
    end
    # Load a pc image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def pc(filename, _hue = 0)
      load_image(@pc_cache, filename, PC_Path, @pc_data)
    end
    # Load/unload the picture cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_picture(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@picture_cache)
      else
        @picture_cache = {}
        @picture_data = Yuki::VD.new(PSDK_PATH + '/master/picture', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def picture_exist?(filename)
      test_file_existence(filename, Pictures_Path, @picture_data)
    end
    # Load a picture image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def picture(filename, _hue = 0)
      load_image(@picture_cache, filename, Pictures_Path, @picture_data)
    end
    # Load/unload the pokedex cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_pokedex(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@pokedex_cache)
      else
        @pokedex_cache = {}
        @pokedex_data = Yuki::VD.new(PSDK_PATH + '/master/pokedex', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def pokedex_exist?(filename)
      test_file_existence(filename, Pokedex_Path, @pokedex_data)
    end
    # Load a pokedex image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def pokedex(filename, _hue = 0)
      load_image(@pokedex_cache, filename, Pokedex_Path, @pokedex_data)
    end
    # Load/unload the title cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_title(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@title_cache)
      else
        @title_cache = {}
        @title_data = Yuki::VD.new(PSDK_PATH + '/master/title', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def title_exist?(filename)
      test_file_existence(filename, Titles_Path, @title_data)
    end
    # Load a title image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def title(filename, _hue = 0)
      load_image(@title_cache, filename, Titles_Path, @title_data)
    end
    # Load/unload the tileset cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_tileset(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@tileset_cache)
      else
        @tileset_cache = {}
        @tileset_data = Yuki::VD.new(PSDK_PATH + '/master/tileset', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def tileset_exist?(filename)
      test_file_existence(filename, Tilesets_Path, @tileset_data)
    end
    # Load a tileset image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def tileset(filename, _hue = 0)
      load_image(@tileset_cache, filename, Tilesets_Path, @tileset_data)
    end
    # Load a tileset "Image" (to perform some background process)
    # @param filename [String] name of the image in the folder
    # @return [Image]
    def tileset_image(filename)
      load_image(@tileset_cache, filename, Tilesets_Path, @tileset_data, Image)
    end
    # Load/unload the transition cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_transition(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@transition_cache)
      else
        @transition_cache = {}
        @transition_data = Yuki::VD.new(PSDK_PATH + '/master/transition', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def transition_exist?(filename)
      test_file_existence(filename, Transitions_Path, @transition_data)
    end
    # Load a transition image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def transition(filename, _hue = 0)
      load_image(@transition_cache, filename, Transitions_Path, @transition_data)
    end
    # Load/unload the windoskin cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_windowskin(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@windowskin_cache)
      else
        @windowskin_cache = {}
        @windowskin_data = Yuki::VD.new(PSDK_PATH + '/master/windowskin', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def windowskin_exist?(filename)
      test_file_existence(filename, Windowskins_Path, @windowskin_data)
    end
    # Load a windowskin image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def windowskin(filename, _hue = 0)
      load_image(@windowskin_cache, filename, Windowskins_Path, @windowskin_data)
    end
    # Load/unload the foot print cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_foot_print(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@foot_print_cache)
      else
        @foot_print_cache = {}
        @foot_print_data = Yuki::VD.new(PSDK_PATH + '/master/foot_print', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def foot_print_exist?(filename)
      test_file_existence(filename, Pokedex_FootPrints_Path, @foot_print_data)
    end
    # Load a foot print image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def foot_print(filename, _hue = 0)
      load_image(@foot_print_cache, filename, Pokedex_FootPrints_Path, @foot_print_data)
    end
    # Load/unload the pokemon icon cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_b_icon(flush_it = false)
      if flush_it
        dispose_bitmaps_from_cache_tab(@b_icon_cache)
      else
        @b_icon_cache = {}
        @b_icon_data = Yuki::VD.new(PSDK_PATH + '/master/b_icon', :read)
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @return [Boolean]
    def b_icon_exist?(filename)
      test_file_existence(filename, Pokedex_PokeIcon_Path, @b_icon_data)
    end
    # Load a Pokemon icon image
    # @param filename [String] name of the image in the folder
    # @param _hue [Integer] ingored (compatibility with RMXP)
    # @return [Texture]
    def b_icon(filename, _hue = 0)
      load_image(@b_icon_cache, filename, Pokedex_PokeIcon_Path, @b_icon_data)
    end
    # Load/unload the pokemon front cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_poke_front(flush_it = false)
      if flush_it
        @poke_front_cache.each { |cache_tab| dispose_bitmaps_from_cache_tab(cache_tab) }
      else
        @poke_front_cache = Array.new(Pokedex_PokeFront_Path.size) {{} }
        @poke_front_data = [Yuki::VD.new(PSDK_PATH + '/master/poke_front', :read), Yuki::VD.new(PSDK_PATH + '/master/poke_front_s', :read)]
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @param hue [Integer] if the front is shiny or not
    # @return [Boolean]
    def poke_front_exist?(filename, hue = 0)
      test_file_existence(filename, Pokedex_PokeFront_Path.fetch(hue), @poke_front_data[hue])
    end
    # Load a pokemon face image
    # @param filename [String] name of the image in the folder
    # @param hue [Integer] 0 = normal, 1 = shiny
    # @return [Texture]
    def poke_front(filename, hue = 0)
      load_image(@poke_front_cache.fetch(hue), filename, Pokedex_PokeFront_Path.fetch(hue), @poke_front_data[hue])
    end
    # Load/unload the pokemon back cache
    # @param flush_it [Boolean] if we need to flush the cache
    def load_poke_back(flush_it = false)
      if flush_it
        @poke_back_cache.each { |cache_tab| dispose_bitmaps_from_cache_tab(cache_tab) }
      else
        @poke_back_cache = Array.new(Pokedex_PokeBack_Path.size) {{} }
        @poke_back_data = [Yuki::VD.new(PSDK_PATH + '/master/poke_back', :read), Yuki::VD.new(PSDK_PATH + '/master/poke_back_s', :read)]
      end
    end
    # Test if the image exist in the folder
    # @param filename [String]
    # @param hue [Integer] if the back is shiny or not
    # @return [Boolean]
    def poke_back_exist?(filename, hue = 0)
      test_file_existence(filename, Pokedex_PokeBack_Path.fetch(hue), @poke_back_data[hue])
    end
    # Load a pokemon back image
    # @param filename [String] name of the image in the folder
    # @param hue [Integer] 0 = normal, 1 = shiny
    # @return [Texture]
    def poke_back(filename, hue = 0)
      load_image(@poke_back_cache.fetch(hue), filename, Pokedex_PokeBack_Path.fetch(hue), @poke_back_data[hue])
    end
    # Meta defintion of the cache loading without hue (shiny processing)
    Cache_meta_without_hue = "      LOADS << :load_%<cache_name>s\n      %<cache_constant>s_Path = '%<cache_path>s'\n      module_function\n\n      def load_%<cache_name>s(flush_it = false)\n        unless flush_it\n          @%<cache_name>s_cache = {}\n          @%<cache_name>s_data = Yuki::VD.new(PSDK_PATH + '/master/%<cache_name>s', :read)\n        else\n          dispose_bitmaps_from_cache_tab(@%<cache_name>s_cache)\n        end\n      end\n\n      def %<cache_name>s_exist?(filename)\n        test_file_existence(filename, %<cache_constant>s_Path, @%<cache_name>s_data)\n      end\n\n      def %<cache_name>s(filename, _hue = 0)\n        load_image(@%<cache_name>s_cache, filename, %<cache_constant>s_Path, @%<cache_name>s_data)\n      end\n\n      def extract_%<cache_name>s(path = '')\n        path += %<cache_constant>s_Path\n        ori = Dir.pwd\n        Dir.mkdir!(path.downcase)\n        Dir.chdir(path.downcase)\n        @%<cache_name>s_data.get_filenames.each do |filename|\n          if filename.include?('/')\n            dirname = File.dirname(filename)\n            Dir.mkdir!(dirname) unless Dir.exist?(dirname)\n          end\n          was_cached = @%<cache_name>s_cache[filename] != nil\n          bmp = %<cache_name>s(filename)\n          bmp.to_png_file(filename + '.png')\n          bmp.dispose unless was_cached\n        end\n      ensure\n        Dir.chdir(ori)\n      end\n"
    # Meta definition of the cache loading with hue (shiny processing)
    Cache_meta_with_hue = "      LOADS << :load_%<cache_name>s\n      %<cache_constant>s_Path = [%<cache_path>s]\n      module_function\n\n      def load_%<cache_name>s(flush_it = false)\n        unless flush_it\n          @%<cache_name>s_cache = Array.new(%<cache_constant>s_Path.size) { {} }\n          @%<cache_name>s_data = [\n            Yuki::VD.new(PSDK_PATH + '/master/%<cache_name>s', :read),\n            Yuki::VD.new(PSDK_PATH + '/master/%<cache_name>s_s', :read)]\n        else\n          @%<cache_name>s_cache.each { |cache_tab| dispose_bitmaps_from_cache_tab(cache_tab) }\n        end\n      end\n\n      def %<cache_name>s_exist?(filename, hue = 0)\n        test_file_existence(filename, %<cache_constant>s_Path.fetch(hue), @%<cache_name>s_data[hue])\n      end\n\n      def %<cache_name>s(filename, hue = 0)\n        load_image(@%<cache_name>s_cache.fetch(hue), filename, %<cache_constant>s_Path.fetch(hue), @%<cache_name>s_data[hue])\n      end\n\n      def extract_%<cache_name>s(path = '', hue = 0)\n        path += %<cache_constant>s_Path[hue]\n        ori = Dir.pwd\n        Dir.mkdir!(path.downcase)\n        Dir.chdir(path.downcase)\n        @%<cache_name>s_data[hue].get_filenames.each do |filename|\n          if filename.include?('/')\n            dirname = File.dirname(filename)\n            Dir.mkdir!(dirname) unless Dir.exist?(dirname)\n          end\n          was_cached = @%<cache_name>s_cache[hue][filename] != nil\n          bmp = %<cache_name>s(filename, hue)\n          bmp.to_png_file(filename + '.png')\n          bmp.dispose unless was_cached\n        end\n      ensure\n        Dir.chdir(ori)\n      end\n"
    # Execute a meta code generation (undef when done)
    def meta_exec(line, name, constant, path, meta_code = Cache_meta_without_hue)
      module_eval(format(meta_code, cache_name: name, cache_constant: constant, cache_path: path), __FILE__, line)
    end
  end
  # Class that display weather
  class Weather
    # Tone used to simulate the sun weather
    SunnyTone = Tone.new(90, 50, 0, 40)
    # Array containing all the texture initializer in the order of the type
    INIT_TEXTURE = %i[init_rain init_rain init_zenith init_sand_storm init_snow init_fog]
    # Array containing all the weather update methods in the order of the type
    UPDATE_METHODS = %i[update_rain update_rain update_zenith update_sandstorm update_snow update_fog]
    # Methods symbols telling how to set the new type of weather according to the index
    SET_TYPE_METHODS = []
    # Boolean telling if the set_type is managed by PSDK or not
    SET_TYPE_PSDK_MANAGED = []
    # Number of sprite to generate
    MAX_SPRITE = 61
    # Top factor of the max= adjustment (max * top / bottom)
    MAX_TOP = 3
    # Bottom factor of the max= adjustment (max * top / bottom)
    MAX_BOTTOM = 2
    # Return the weather type
    # @return [Integer]
    attr_reader :type
    # Return the max amount of sprites
    # @return [Integer]
    attr_reader :max
    # Return the origin x
    # @return [Numeric]
    attr_reader :ox
    # Return the origin y
    # @return [Numeric]
    attr_reader :oy
    # Create the Weather object
    # @param viewport [Viewport]
    # @note : type 0 = None, 1 = Rain, 2 = Sun/Zenith, 3 = Darud Sandstorm, 4 = Hail, 5 = Foggy
    def initialize(viewport = nil)
      @type = 0
      @max = 0
      @ox = 0
      @oy = 0
      init_sprites(viewport)
    end
    # Update the sprite display
    def update
      return if @type == 0
      return if Graphics::FPSBalancer.global.skipping?
      send(UPDATE_METHODS[@type])
    end
    # Dispose the interface
    def dispose
      @sprites.each(&:dispose)
      @snow_bitmap&.dispose if SET_TYPE_PSDK_MANAGED[4]
    end
    # Update the ox
    # @param ox [Numeric]
    def ox=(ox)
      return if @ox == (ox / 2)
      @ox = ox / 2
      @sprites.each { |sprite| sprite.ox = @ox }
    end
    # Update the oy
    # @param oy [Numeric]
    def oy=(oy)
      return if @oy == (oy / 2)
      @oy = oy / 2
      @sprites.each { |sprite| sprite.oy = @oy }
    end
    # Update the max number of sprites to show
    # @param max [Integer]
    def max=(max)
      max = max.to_i * MAX_TOP / MAX_BOTTOM
      return if @max == max
      @max = [[max, 0].max, MAX_SPRITE - 1].min
      @sprites.each_with_index do |sprite, i|
        sprite.visible = (i <= @max) if sprite
      end
    end
    # Change the Weather type
    # @param type [Integer]
    def type=(type)
      @last_type = @type
      return if @type == type
      @type = type
      send(symbol = INIT_TEXTURE[type])
      log_debug("init_texture called : #{symbol}")
      send(symbol = SET_TYPE_METHODS[type])
      log_debug("set_type called : #{symbol}")
      if SET_TYPE_PSDK_MANAGED[2] && @last_type == 2 && !$game_switches[Yuki::Sw::TJN_Enabled]
        $game_screen.start_tone_change(Yuki::TJN::TONE[3], 40)
      end
    ensure
      if @last_type != @type
        @sprites.first.set_origin(@ox, @oy) if @type != 5 && SET_TYPE_PSDK_MANAGED[5]
        Yuki::TJN.force_update_tone(0) if @type != 2 && SET_TYPE_PSDK_MANAGED[2]
      end
    end
    private
    # Initialize the sprites
    # @param viewport [Viewport]
    def init_sprites(viewport)
      @sprites = Array.new(MAX_SPRITE) do
        sprite = Sprite.new(viewport)
        sprite.z = 1000
        sprite.visible = false
        sprite.opacity = 0
        class << sprite
          attr_accessor :counter
        end
        sprite.counter = 0
        next((sprite))
      end
    end
    # Create the sand_storm bitmap
    def init_sand_storm
      return if @sand_storm_bitmaps && !@sand_storm_bitmaps.first.disposed? && !@sand_storm_bitmaps.last.disposed?
      @sand_storm_bitmaps = [RPG::Cache.animation('sand_storm_big'), RPG::Cache.animation('sand_storm_sm')]
    end
    # Create the rain bitmap
    def init_rain
      return if @rain_bitmap && !@rain_bitmap.disposed?
      @rain_bitmap = RPG::Cache.animation('rain_frames')
    end
    # Create the snow bitmap
    def init_snow
      return if @snow_bitmap && !@snow_bitmap.disposed?
      color1 = Color.new(255, 255, 255, 255)
      color2 = Color.new(255, 255, 255, 128)
      @snow_bitmap = Texture.new(6, 6)
      @snow_bitmap.fill_rect(0, 1, 6, 4, color2)
      @snow_bitmap.fill_rect(1, 0, 4, 6, color2)
      @snow_bitmap.fill_rect(1, 2, 4, 2, color1)
      @snow_bitmap.fill_rect(2, 1, 2, 4, color1)
      @snow_bitmap.update
    end
    # Initialize the zenith stuff
    def init_zenith
      return
    end
    # Initialize the fog bitmap
    def init_fog
      return if @fog_bitmap && !@fog_bitmap.disposed?
      @fog_bitmap = RPG::Cache.animation('fog')
    end
    # Set the weather type as rain (special animation)
    def set_type_rain
      @type = 1
      bitmap = @rain_bitmap
      @sprites.each_with_index do |sprite, i|
        sprite.visible = (i <= @max)
        sprite.bitmap = bitmap
        sprite.src_rect.set(0, 0, 16, 32)
        sprite.counter = 0
      end
    end
    # Set the weather type as sandstorm (different bitmaps)
    def set_type_sandstorm
      @type = 3
      big = @sand_storm_bitmaps.first
      sm = @sand_storm_bitmaps.last
      49.times do |i|
        next unless (sprite = @sprites[i])
        sprite.visible = true
        sprite.bitmap = big
        sprite.opacity = (7 - (i % 7)) * 128 / 7
        sprite.x = 64 * (i % 7) - 64 + @ox
        sprite.y = 64 * (i / 7) - 80 + @oy
      end
      49.upto(MAX_SPRITE - 1) do |i|
        next unless (sprite = @sprites[i])
        sprite.bitmap = sm
        sprite.x = -999 + @ox
      end
    end
    # Called when type= is called with snow id
    def set_type_snow
      set_type_reset_sprite(@snow_bitmap)
    end
    # Called when type= is called with 0
    def set_type_none
      set_type_reset_sprite(nil)
    end
    # Called when type= is called with sunny id
    def set_type_sunny
      $game_screen.start_tone_change(SunnyTone, @last_type == @type ? 1 : 40)
      set_type_reset_sprite(nil)
    end
    # Set the weather type as fog
    def set_type_fog
      @type = 5
      sprite = @sprites.first
      sprite.bitmap = @fog_bitmap
      sprite.set_origin(0, 0)
      sprite.set_position(0, 0)
      sprite.src_rect.set(0, 0, 320, 240)
      sprite.opacity = 0
      1.upto(MAX_SPRITE - 1) do |i|
        next unless (sprite = @sprites[i])
        sprite.bitmap = nil
      end
    end
    # Reset the sprite when type= is called (and it's managed)
    # @param bitmap [Texture]
    def set_type_reset_sprite(bitmap)
      @sprites.each_with_index do |sprite, i|
        next unless sprite
        sprite.bitmap = bitmap
        sprite.visible = (@max.positive? && i <= @max)
        sprite.src_rect.set(0, 0, bitmap.width, bitmap.height) if bitmap
        sprite.counter = 0
      end
    end
    # Update the rain weather
    def update_rain
      0.upto(@max) do |i|
        break unless (sprite = @sprites[i])
        sprite.counter += 1
        if sprite.src_rect.x < 16
          sprite.x -= 4
          sprite.y += 8
        end
        if sprite.counter > 15 && (sprite.counter % 5) == 0
          sprite.src_rect.x += (sprite.src_rect.x == 0 ? 32 : 16)
          sprite.opacity = 0 if sprite.src_rect.x >= 64
        end
        x = sprite.x - @ox
        y = sprite.y - @oy
        if sprite.opacity < 64 || x < -50 || x > 400 || y < -175 || y > 275
          sprite.x = rand(400) - 25 + @ox
          sprite.y = rand(400) - 100 + @oy
          sprite.opacity = 255
          sprite.counter = 0
          sprite.src_rect.x = ((rand(15) == 0) ? 16 : 0)
          sprite.counter = 15 if sprite.src_rect.x == 16
        end
      end
    end
    # Update the sunny weather
    def update_zenith
      sprite = @sprites.first
      sprite.counter += 1
      sprite.counter = 0 if sprite.counter > 320
      $game_screen.tone.blue = Integer(20 * Math.sin(Math::PI * sprite.counter / 160))
    end
    # Update the sandstorm weather
    def update_sandstorm
      0.upto(@max) do |i|
        break unless (sprite = @sprites[i])
        sprite.x += 8
        sprite.y += 1
        if i < 49
          sprite.x -= 384 if sprite.x - @ox > 320
          sprite.y -= 384 if sprite.y - @oy > 304
          sprite.opacity += 4 if sprite.opacity < 255
        else
          sprite.counter += 1
          sprite.x -= Integer(8 * Math.sin(Math::PI * sprite.counter / 10))
          sprite.y -= Integer(4 * Math.cos(Math::PI * sprite.counter / 10))
          sprite.opacity -= 8
        end
        x = sprite.x - @ox
        y = sprite.y - @oy
        if sprite.opacity < 64 || x < -50 || x > 400 || y < -175 || y > 275
          next if i < 49
          sprite.x = rand(400) - 25 + @ox
          sprite.y = rand(400) - 100 + @oy
          sprite.opacity = 255
          sprite.counter = 0
        end
      end
    end
    # Update the snow weather
    def update_snow
      0.upto(@max) do |i|
        break unless (sprite = @sprites[i])
        sprite.x -= 1
        sprite.y += 4
        sprite.opacity -= 8
        x = sprite.x - @ox
        y = sprite.y - @oy
        if sprite.opacity < 64 || x < -50 || x > 400 || y < -175 || y > 275
          sprite.x = rand(400) - 25 + @ox
          sprite.y = rand(400) - 100 + @oy
          sprite.opacity = 255
          sprite.counter = 0
        end
      end
    end
    # Update the fog weather
    def update_fog
      sprite = @sprites.first
      sprite.set_origin(0, 0)
      sprite.opacity = @max * 255 / 60
    end
    class << self
      # Register a new type= method call
      # @param type [Integer] the type of weather
      # @param symbol [Symbol] if the name of the method to call
      # @param psdk_managed [Boolean] if it's managed by PSDK (some specific code in the type= method)
      def register_set_type(type, symbol, psdk_managed)
        SET_TYPE_METHODS[type] = symbol
        SET_TYPE_PSDK_MANAGED[type] = psdk_managed
      end
    end
    register_set_type(0, :set_type_none, true)
    register_set_type(1, :set_type_rain, true)
    register_set_type(2, :set_type_sunny, true)
    register_set_type(3, :set_type_sandstorm, true)
    register_set_type(4, :set_type_snow, true)
    register_set_type(5, :set_type_fog, true)
  end
end
# Module that defines every data class, data reader module or constants
module GameData
  # Module that contain the ids of every SystemTag
  # @author Nuri Yuri
  module SystemTags
    module_function
    # Generation of the SystemTag id
    # @param x [Integer] X coordinate of the SystemTag on the w_prio tileset
    # @param y [Integer] Y coordinate of the SystemTag on the w_prio tileset
    def gen(x, y)
      return 384 + x + (y * 8)
    end
    # SystemTag that is used to remove the effet of SystemTags like TSea or TPond.
    Empty = gen 0, 0
    # Ice SystemTag, every instance of Game_Character slide on it.
    TIce = gen 1, 0
    # Grass SystemTag, used to display grass particles and start Wild Pokemon Battle.
    TGrass = gen 5, 0
    # Taller grass SystemTag, same purpose as TGrass.
    TTallGrass = gen 6, 0
    # Cave SystemTag, used to start Cave Wild Pokemon Battle.
    TCave = gen 7, 0
    # Mount SystemTag, used to start Mount Wild Pokemon Battle.
    TMount = gen 5, 1
    # Sand SystemTag, used to start Sand Pokemon Battle.
    TSand = gen 6, 1
    # Wet sand SystemTag, used to display a particle when walking on it, same purpose as TSand.
    TWetSand = gen 2, 0
    # Pond SystemTag, used to start Pond/River Wild Pokemon Battle.
    TPond = gen 7, 1
    # Sea SystemTag, used to start Sea/Ocean Wild Pokemon Battle.
    TSea = gen 5, 2
    # Under water SystemTag, used to start Under water Wild Pokemon Battle.
    TUnderWater = gen 6, 2
    # Snow SystemTag, used to start Snow Wild Pokemon Battle.
    TSnow = gen 7, 2
    # SystemTag that is used by the pathfinding system as a road.
    Road = gen 7, 5
    # Defines a Ledge SystemTag where you can jump to the right.
    JumpR = gen 0, 1
    # Defines a Ledge SystemTag where you can jump to the left.
    JumpL = gen 0, 2
    # Defines a Ledge SystemTag where you can jump down.
    JumpD = gen 0, 3
    # Defines a Ledge SystemTag where you can jump up.
    JumpU = gen 0, 4
    # Defines a WaterFall (aid for events).
    WaterFall = gen 3, 0
    # Define a HeadButt tile
    HeadButt = gen 4, 0
    # Defines a tile that force the player to move left.
    RapidsL = gen 1, 1
    # Defines a tile that force the player to move down.
    RapidsD = gen 2, 1
    # Defines a tile that force the player to move up.
    RapidsU = gen 3, 1
    # Defines a tile that force the player to move Right.
    RapidsR = gen 4, 1
    # Defines a Swamp tile.
    SwampBorder = gen 5, 4
    # Defines a Swamp tile that is deep (player can be stuck).
    DeepSwamp = gen 6, 4
    # Defines a upper left stair.
    StairsL = gen 1, 4
    # Defines a up stair when player moves up.
    StairsD = gen 2, 4
    # Defines a up stair when player moves down.
    StairsU = gen 3, 4
    # Defines a upper right stair.
    StairsR = gen 4, 4
    # Defines the left slope
    SlopesL = gen 7, 3
    # Defines the right slope
    SlopesR = gen 7, 4
    # Defines a Ledge "passed through" by bunny hop (Acro bike).
    AcroBike = gen 6, 3
    # Defines a bike bridge that only allow right and left movement (and up down jump with acro bike).
    AcroBikeRL = gen 4, 3
    # Same as AcroBikeRL but up and down with right and left jump.
    AcroBikeUD = gen 3, 3
    # Defines a tile that require high speed to pass through (otherwise you fall down).
    MachBike = gen 5, 3
    # Defines a tile that require high speed to not fall in a Hole.
    CrackedSoil = gen 1, 3
    # Defines a Hole tile.
    Hole = gen 2, 3
    # Defines a bridge (crossed up down).
    BridgeUD = gen 2, 2
    # Defines a bridge (crossed right/left).
    BridgeRL = gen 4, 2
    # Define tiles that change the z property of a Game_Character.
    ZTag = [gen(0, 5), gen(1, 5), gen(2, 5), gen(3, 5), gen(4, 5), gen(5, 5), gen(6, 5)]
    # Defines a tile that force the character to move left until he hits a wall.
    RocketL = gen 0, 6
    # Defines a tile that force the character to move down until he hits a wall.
    RocketD = gen 1, 6
    # Defines a tile that force the character to move up until he hits a wall.
    RocketU = gen 2, 6
    # Defines a tile that force the character to move Right until he hits a wall.
    RocketR = gen 3, 6
    # Defines a tile that force the character to move left until he hits a wall. (With Rotation)
    RocketRL = gen 4, 6
    # Defines a tile that force the character to move down until he hits a wall. (With Rotation)
    RocketRD = gen 5, 6
    # Defines a tile that force the character to move up until he hits a wall. (With Rotation)
    RocketRU = gen 6, 6
    # Defines a tile that force the character to move Right until he hits a wall. (With Rotation)
    RocketRR = gen 7, 6
    # Gives the db_symbol of the system tag
    # @param system_tag [Integer]
    # @return [Symbol]
    def system_tag_db_symbol(system_tag)
      case system_tag
      when TGrass
        return :grass
      when TTallGrass
        return :tall_grass
      when TCave
        return :cave
      when TMount
        return :mountain
      when TSand
        return :sand
      when TPond
        return :pond
      when TSea
        return :sea
      when TUnderWater
        return :under_water
      when TSnow
        return :snow
      when TIce
        return :ice
      when HeadButt
        return :headbutt
      else
        return :regular_ground
      end
    end
  end
end
module Yuki
  # Class that helps to read Virtual Directories
  #
  # In reading mode, the Virtual Directories can be loaded to RAM if MAX_SIZE >= VD.size
  #
  # All the filenames inside the Yuki::VD has to be downcased filename in utf-8
  #
  # Note : Encryption is up to the developper and no longer supported on the basic script
  class VD
    # @return [String] the filename of the current Yuki::VD
    attr_reader :filename
    # Is the debug info on ?
    DEBUG_ON = ARGV.include?('debug-yuki-vd')
    # The max size of the file that can be loaded in memory
    MAX_SIZE = 10 * 1024 * 1024
    # 10Mo
    # List of allowed modes
    ALLOWED_MODES = %i[read write update]
    # Size of the pointer at the begin of the file
    POINTER_SIZE = 4
    # Unpack method of the pointer at the begin of the file
    UNPACK_METHOD = 'L'
    # Create a new Yuki::VD file or load it
    # @param filename [String] name of the Yuki::VD file
    # @param mode [:read, :write, :update] if we read or write the virtual directory
    def initialize(filename, mode)
      @mode = mode = fix_mode(mode)
      @filename = filename
      send("initialize_#{mode}")
    end
    # Read a file data from the VD
    # @param filename [String] the file we want to read its data
    # @return [String, nil] the data of the file
    def read_data(filename)
      return nil unless @file
      pos = @hash[filename]
      return nil unless pos
      @file.pos = pos
      size = @file.read(POINTER_SIZE).unpack1(UNPACK_METHOD)
      return @file.read(size)
    end
    # Test if a file exists in the VD
    # @param filename [String]
    # @return [Boolean]
    def exists?(filename)
      @hash[filename] != nil
    end
    # Write a file with its data in the VD
    # @param filename [String] the file name
    # @param data [String] the data of the file
    def write_data(filename, data)
      return unless @file
      @hash[filename] = @file.pos
      @file.write([data.bytesize].pack(UNPACK_METHOD))
      @file.write(data)
    end
    # Add a file to the Yuki::VD
    # @param filename [String] the file name
    # @param ext_name [String, nil] the file extension
    def add_file(filename, ext_name = nil)
      sub_filename = ext_name ? "#{filename}.#{ext_name}" : filename
      write_data(filename, File.binread(sub_filename))
    end
    # Get all the filename
    # @return [Array<String>]
    def get_filenames
      @hash.keys
    end
    # Close the VD
    def close
      return unless @file
      if @mode != :read
        pos = [@file.pos].pack(UNPACK_METHOD)
        @file.write(Marshal.dump(@hash))
        @file.pos = 0
        @file.write(pos)
      end
      @file.close
      @file = nil
    end
    private
    # Initialize the Yuki::VD in read mode
    def initialize_read
      @file = File.new(filename, 'rb')
      pos = @file.pos = @file.read(POINTER_SIZE).unpack1(UNPACK_METHOD)
      @hash = Marshal.load(@file)
      load_whole_file(pos) if pos < MAX_SIZE
    rescue Errno::ENOENT
      @file = nil
      @hash = {}
      log_error(format('%<filename>s not found', filename: filename)) if DEBUG_ON
    end
    # Load the VD in the memory
    # @param size [Integer] size of the VD memory
    def load_whole_file(size)
      @file.pos = 0
      data = @file.read(size)
      @file.close
      @file = StringIO.new(data, 'rb+')
      @file.pos = 0
    end
    # Initialize the Yuki::VD in write mode
    def initialize_write
      @file = File.new(filename, 'wb')
      @file.pos = POINTER_SIZE
      @hash = {}
    end
    # Initialize the Yuki::VD in update mode
    def initialize_update
      @file = File.new(filename, 'rb+')
      pos = @file.pos = @file.read(POINTER_SIZE).unpack1(UNPACK_METHOD)
      @hash = Marshal.load(@file)
      @file.pos = pos
    end
    # Fix the input mode in case it's a String
    # @param mode [Symbol, String]
    # @return [Symbol] one of the value of ALLOWED_MODES
    def fix_mode(mode)
      return mode if ALLOWED_MODES.include?(mode)
      r = (mode = mode.downcase).include?('r')
      w = mode.include?('w')
      plus = mode.include?('+')
      return :update if plus || (r && w)
      return :read if r
      return :write
    end
  end
end
# The RGSS Audio module
module Audio
  @music_volume = 100
  @sfx_volume = 100
  module_function
  # Get volume of bgm and me
  # @return [Integer] a value between 0 and 100
  def music_volume
    return @music_volume
  end
  # Set the volume of bgm and me
  # @param value [Integer] a value between 0 and 100
  def music_volume=(value)
    value = value.to_i.abs
    @music_volume = value < 101 ? value : 100
    if Object.const_defined?(:FMOD)
      adjust_volume(@bgm_channel, @music_volume)
      adjust_volume(@me_channel, @music_volume)
    else
      if Object.const_defined?(:SFMLAudio)
        adjust_volume(@bgm_sound, @music_volume)
        adjust_volume(@me_sound, @music_volume)
      end
    end
  end
  # Get volume of sfx
  # @return [Integer] a value between 0 and 100
  def sfx_volume
    return @sfx_volume
  end
  # Set the volume of sfx
  # @param value [Integer] a value between 0 and 100
  def sfx_volume=(value)
    value = value.to_i.abs
    @sfx_volume = value < 101 ? value : 100
    if Object.const_defined?(:FMOD)
      adjust_volume(@bgs_channel, @sfx_volume)
    else
      if Object.const_defined?(:SFMLAudio)
        adjust_volume(@bgs_sound, @sfx_volume)
      end
    end
  end
  # A weird alias of #se_play
  def cry_play(filename, volume = 100, pitch = 100)
    se_play(filename, volume, pitch)
  end
  # Tells if a cry file exists or not
  # @param filename [String] the name of the cry file
  # @return [Boolean]
  def cry_exist?(filename)
    return File.exist?(filename)
  end
  public
  # Module that cache sounds during the game
  module Cache
    @sound_cache = {}
    @sound_count = {}
    @sound_loads = []
    module_function
    # Start the Audio cache
    def start
      return if @thread
      @thread = Thread.new do
        loop do
          sleep
          load_files
        end
      end
    end
    # Start the file loading
    def load
      @thread.wakeup
    end
    # Load the files
    def load_files
      loads = @sound_loads.clone
      @sound_loads.clear
      Thread.new do
        while (filename = loads.pop)
          next((@sound_count[filename] = 5)) if @sound_cache[filename]
          t = Time.new
          @sound_cache[filename] = File.open(filename, 'rb') { |f| f.read(f.size) }
          @sound_count[filename] = 5
          log_info "\rAudio::Cache : #{filename} loaded in #{Time.new - t}s" unless PSDK_CONFIG.release?
        end
      end
    end
    # Create a bgm sound used to play the BGM
    # @param filename [String] the correct filename of the sound
    # @param flags [Integer, nil] the FMOD flags for the creation
    # @return [FMOD::Sound] the sound
    def create_sound_sound(filename, flags = nil)
      Yuki::ElapsedTime.start(:audio_load_sound)
      if (file_data = @sound_cache[filename])
        @sound_count[filename] += 1
      else
        file_data = File.binread(filename)
        Yuki::ElapsedTime.show(:audio_load_sound, 'Loading sound from disk took')
      end
      gm_filename = filename.include?('.mid') && File.exist?('gm.dls') ? 'gm.dls' : nil
      sound_info = FMOD::SoundExInfo.new(file_data.bytesize, nil, nil, nil, nil, nil, gm_filename)
      sound = FMOD::System.createSound(file_data, create_sound_get_flags(flags), sound_info)
      sound.instance_variable_set(:@extinfo, sound_info)
      Yuki::ElapsedTime.show(:audio_load_sound, 'Creating sound object took')
      return sound
    rescue Errno::ENOENT
      log_error("Failed to load sound : #{filename}")
      return nil
    end
    # Return the expected flag for create_sound_sound
    # @param flags [Integer, nil] the FMOD flags for the creation
    # @return [Integer]
    def create_sound_get_flags(flags)
      return (flags | FMOD::MODE::OPENMEMORY | FMOD::MODE::CREATESTREAM) if flags
      return (FMOD::MODE::LOOP_NORMAL | FMOD::MODE::FMOD_2D | FMOD::MODE::OPENMEMORY | FMOD::MODE::CREATESTREAM)
    end
    # Flush the sound cache if the sounds are not lapsed
    def flush_sound
      to_delete = []
      @sound_cache.each_key do |filename|
        to_delete << filename if (@sound_count[filename] -= 1) <= 0
      end
      to_delete.reverse_each do |filename|
        log_info "Audio::Cache : #{filename} released."
        @sound_count.delete(filename)
        @sound_cache.delete(filename)
      end
    end
    # Preload a sound
    # @param filename [String]
    def preload_sound(filename)
      filename = Audio.search_filename(filename)
      return unless sound_exist?(filename)
      @sound_loads << filename
    end
    # Test if a sound exist
    # @param filename [String]
    def sound_exist?(filename)
      return File.exist?(filename)
    end
  end
end
if Object.const_defined?(:FMOD)
  module Audio
    FMOD::System.init(32, FMOD::INIT::NORMAL)
    # Time it takes to fade in (in ms)
    FadeInTime = 1000
    @bgm_sound = nil
    @bgm_channel = nil
    @bgs_sound = nil
    @bgs_channel = nil
    @me_sound = nil
    @me_channel = nil
    @se_sounds = {}
    @fading_sounds = {}
    @cries_stack = []
    @was_playing_callback = nil
    @bgm_mutex = Mutex.new
    @bgs_mutex = Mutex.new
    @me_mutex = Mutex.new
    # List of extension that FmodEx can read (used to find files from names without ext name)
    EXT = ['.ogg', '.mp3', '.wav', '.mid', '.aac', '.wma', '.it', '.xm', '.mod', '.s3m', '.midi', '.flac']
    module_function
    # plays a BGM and stop the current one
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the BGM between 0 and 100
    # @param pitch [Integer] speed of the BGM in percent
    # @param fade_in [Boolean, Integer] if the BGM fades in when different (or time in ms)
    def bgm_play(file_name, volume = 100, pitch = 100, fade_in = true)
      Thread.new do
        synchronize(@bgm_mutex) {bgm_play_internal(file_name, volume, pitch, fade_in) }
      end
    end
    # plays a BGM and stop the current one
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the BGM between 0 and 100
    # @param pitch [Integer] speed of the BGM in percent
    # @param fade_in [Boolean, Integer] if the BGM fades in when different (or time in ms)
    def bgm_play_internal(file_name, volume, pitch, fade_in)
      volume = volume * @music_volume / 100
      filename = search_filename(file_name)
      was_playing = was_sound_previously_playing?(file_name.downcase, @bgm_name, @bgm_sound, @bgm_channel, fade_in)
      @bgm_name = file_name.downcase
      fade_in = (fade_in && @bgm_sound && !was_playing)
      release_fading_sounds((was_playing || fade_in) ? nil : @bgm_sound)
      unless was_playing
        @bgm_sound = @bgm_channel = nil
        return unless (@bgm_sound = Cache.create_sound_sound(filename))
        autoloop(@bgm_sound)
      end
      @bgm_channel = FMOD::System.playSound(@bgm_sound, true) unless was_playing && @bgm_channel
      adjust_channel(@bgm_channel, volume, pitch)
      @bgm_channel.setDelay(@me_bgm_restart, 0, fade_in = false) if @me_bgm_restart && @me_bgm_restart > @bgm_channel.getDSPClock.last
      fade(fade_in == true ? FadeInTime : fade_in, @bgm_channel, 0, 1.0) if fade_in
      @fading_sounds.delete(@bgm_sound)
    rescue FMOD::Error
      if File.exist?(filename)
        log_error("Le fichier #{file_name} n'a pas pu être lu...\nErreur : #{$!.message}")
      else
        log_error("Le fichier #{filename} n'a pas été trouvé !")
      end
      bgm_stop
    ensure
      call_was_playing_callback
    end
    # Returns the BGM position
    # @return [Integer]
    def bgm_position
      synchronize(@bgm_mutex) do
        return @bgm_channel.getPosition(FMOD::TIMEUNIT::PCM) if @bgm_channel
      end
      return 0
    rescue FMOD::Error
      return 0
    end
    # Set the BGM position
    # @param position [Integer]
    def bgm_position=(position)
      synchronize(@bgm_mutex) do
        @bgm_channel&.setPosition(position, FMOD::TIMEUNIT::PCM)
      end
    rescue StandardError
      log_error("bgm_position= : #{$!.message}")
    end
    # Fades the BGM
    # @param time [Integer] fade time in ms
    def bgm_fade(time)
      synchronize(@bgm_mutex) do
                return unless @bgm_channel
        return unless (sound = @bgm_sound)
        return if @fading_sounds[sound]
        fade(time, @fading_sounds[sound] = @bgm_channel)
        @bgm_channel = nil
      rescue FMOD::Error
        @fading_sounds.delete(sound)
        @bgm_channel = nil

      end
    end
    # Stop the BGM
    def bgm_stop
      synchronize(@bgm_mutex) do
        return unless @bgm_channel
        @bgm_channel.stop
        @bgm_channel = nil
      end
    rescue FMOD::Error => e
      @bgm_channel = nil
      puts e.message if debug?
    end
    # plays a BGS and stop the current one
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the BGS between 0 and 100
    # @param pitch [Integer] speed of the BGS in percent
    # @param fade_in [Boolean, Integer] if the BGS fades in when different (Integer = time to fade)
    def bgs_play(file_name, volume = 100, pitch = 100, fade_in = true)
      Thread.new do
        synchronize(@bgs_mutex) {bgs_play_internal(file_name, volume, pitch, fade_in) }
      end
    end
    # plays a BGS and stop the current one
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the BGS between 0 and 100
    # @param pitch [Integer] speed of the BGS in percent
    # @param fade_in [Boolean, Integer] if the BGS fades in when different (Integer = time to fade)
    def bgs_play_internal(file_name, volume, pitch, fade_in)
      volume = volume * @sfx_volume / 100
      filename = search_filename(file_name)
      was_playing = was_sound_previously_playing?(file_name.downcase, @bgs_name, @bgs_sound, @bgs_channel, fade_in)
      @bgs_name = file_name.downcase
      fade_in = (fade_in && @bgs_sound && !was_playing)
      release_fading_sounds((was_playing || fade_in) ? nil : @bgs_sound)
      unless was_playing
        @bgs_sound = @bgs_channel = nil
        return unless (@bgs_sound = Cache.create_sound_sound(filename))
        autoloop(@bgs_sound)
      end
      @bgs_channel = FMOD::System.playSound(@bgs_sound, true) unless was_playing && @bgs_channel
      adjust_channel(@bgs_channel, volume, pitch)
      fade(fade_in == true ? FadeInTime : fade_in, @bgs_channel, 0, 1.0) if fade_in
      @fading_sounds.delete(@bgs_sound)
    rescue FMOD::Error
      if File.exist?(filename)
        cc 0x01
        log_error("Le fichier #{file_name} n'a pas pu être lu...\nErreur : #{$!.message}")
      else
        log_error("Le fichier #{filename} n'a pas été trouvé !")
      end
      bgs_stop
    ensure
      call_was_playing_callback
    end
    # Fades the BGS
    # @param time [Integer] fade time in ms
    def bgs_fade(time)
      synchronize(@bgs_mutex) do
                return unless @bgs_channel
        return unless (sound = @bgs_sound)
        return if @fading_sounds[sound]
        fade(time, @fading_sounds[sound] = @bgs_channel)
        @bgs_channel = nil
      rescue FMOD::Error
        @fading_sounds.delete(sound)
        @bgs_channel = nil

      end
    end
    # Stop the BGS
    def bgs_stop
      synchronize(@bgs_mutex) do
        return unless @bgs_channel
        @bgs_channel.stop
        @bgs_channel = nil
      end
    rescue FMOD::Error => e
      @bgs_channel = nil
      puts e.message if debug?
    end
    # plays a ME and stop the current one, the BGM will be paused during the ME play
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the ME between 0 and 100
    # @param pitch [Integer] speed of the ME in percent
    # @param preserve_bgm [Boolean] tell the function not to pause the bgm
    def me_play(file_name, volume = 100, pitch = 100, preserve_bgm = false)
      Thread.new do
        synchronize(@bgm_mutex) do
          synchronize(@me_mutex) do
            me_play_internal(file_name, volume, pitch, preserve_bgm)
          end
        end
      end
    end
    # plays a ME and stop the current one, the BGM will be paused during the ME play
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the ME between 0 and 100
    # @param pitch [Integer] speed of the ME in percent
    # @param preserve_bgm [Boolean] tell the function not to pause the bgm
    def me_play_internal(file_name, volume, pitch, preserve_bgm)
      volume = volume * @music_volume / 100
      filename = search_filename(file_name)
      was_playing = was_sound_previously_playing?(file_name.downcase, @me_name, @me_sound, @me_channel)
      @me_name = file_name.downcase
      release_fading_sounds(was_playing ? nil : @me_sound)
      unless was_playing
        @me_sound = @me_channel = nil
        return unless (@me_sound = Cache.create_sound_sound(filename, FMOD::MODE::LOOP_OFF | FMOD::MODE::FMOD_2D))
      end
      @me_channel = FMOD::System.playSound(@me_sound, true)
      adjust_channel(@me_channel, volume, pitch)
      @fading_sounds.delete(@me_sound)
      return if preserve_bgm
      if @bgm_channel
        length = @me_sound.getLength(FMOD::TIMEUNIT::PCM) * 100
        length /= pitch
        @bgm_channel.setDelay(@me_bgm_restart = @bgm_channel.getDSPClock.last + length, 0, false)
      else
        @me_bgm_restart = nil
      end
    rescue FMOD::Error
      if File.exist?(filename)
        cc 0x01
        log_error("Le fichier #{file_name} n'a pas pu être lu...\nErreur : #{$!.message}")
      else
        log_error("Le fichier #{filename} n'a pas été trouvé !")
      end
      me_stop
    ensure
      call_was_playing_callback
    end
    # Fades the ME
    # @param time [Integer] fade time in ms
    def me_fade(time)
      synchronize(@me_mutex) do
                return unless @me_channel
        return unless (sound = @me_sound)
        return if @fading_sounds[sound]
        fade(time, @me_channel)
      rescue FMOD::Error => e
        puts e.message if debug?
      ensure
        if @bgm_channel
          sr = FMOD::System.getSoftwareFormat.first
          delay = @bgm_channel.getDSPClock.last + Integer(time * sr / 1000)
          @bgm_channel.setDelay(delay, 0, false) if !@me_bgm_restart || @me_bgm_restart > delay
        end
        @me_channel = nil

      end
    end
    # Stop the ME
    def me_stop
      synchronize(@me_mutex) do
        return unless @me_channel
        @bgm_channel&.setDelay(0, 0, false)
        @me_channel.stop
        @me_channel = nil
      end
    rescue FMOD::Error => e
      @me_channel = nil
      puts e.message if debug?
    end
    # plays a SE if possible
    # @param file_name [String] name of the audio file
    # @param volume [Integer] volume of the SE between 0 and 100
    # @param pitch [Integer] speed of the SE in percent
    def se_play(file_name, volume = 100, pitch = 100)
      volume = volume * @sfx_volume / 100
      filename = search_filename(file_name)
      unless (sound = @se_sounds[file_name])
        sound = FMOD::System.createStream(filename, FMOD::MODE::LOOP_OFF | FMOD::MODE::FMOD_2D, nil)
        if filename.include?('/cries/')
          @cries_stack << sound
          @cries_stack.shift.release if @cries_stack.size > 5
        else
          @se_sounds[file_name] = sound
        end
      end
      channel = FMOD::System.playSound(sound, true)
      channel.setPriority(250)
      channel.setVolume(volume / 100.0)
      channel.setPitch(pitch / 100.0)
      channel.setPaused(false)
    rescue FMOD::Error
      if !File.exist?(filename)
        log_error("Le fichier #{filename} n'a pas été trouvé !")
      else
        if $!.message.delete('FmodError ').to_i == 46
          p @se_sounds
          se_stop
          retry
        else
          cc 0x01
          log_error("Le fichier #{file_name} n'a pas pu être lu...\nErreur : #{$!.message}")
        end
      end
    end
    # Stops every SE
    def se_stop
      @se_sounds.each_value(&:release)
      @cries_stack.each(&:release)
      @cries_stack.clear
      @se_sounds.clear
    end
    # Search the real filename of the audio file
    # @param file_name [String] filename of the audio file
    # @return [String] real filename if found or file_name
    def search_filename(file_name)
      file_name = file_name.downcase
      return file_name if File.exist?(file_name)
      EXT.each do |ext|
        filename = file_name + ext
        return filename if File.exist?(filename)
      end
      return file_name
    end
    # Auto loop a music
    # @param sound [FMOD::Sound] the sound that contain the data
    # @note Only works with createSound and should be called before the channel creation
    def autoloop(sound)
      start = sound.getTag('LOOPSTART', 0)[2].to_i rescue nil
      length = sound.getTag('LOOPLENGTH', 0)[2].to_i rescue nil
      unless start && length
        index = 0
        while (tag = sound.getTag('TXXX', index) rescue nil)
          index += 1
          next unless tag[2].is_a?(String)
          name, data = tag[2].split("\x00")
          if name == 'LOOPSTART' && !start
            start = data.to_i
          else
            if name == 'LOOPLENGTH' && !length
              length = data.to_i
            end
          end
        end
      end
      return unless start && length
      log_info "LOOP: #{start} -> #{start + length}" unless PSDK_CONFIG.release?
      sound.setLoopPoints(start, FMOD::TIMEUNIT::PCM, start + length, FMOD::TIMEUNIT::PCM)
    end
    # Fade a channel
    # @param time [Integer] number of miliseconds to perform the fade
    # @param channel [FMOD::Channel] the channel to fade
    # @param start_value [Numeric]
    # @param end_value [Numeric]
    def fade(time, channel, start_value = 1.0, end_value = 0)
      sr = FMOD::System.getSoftwareFormat.first
      pdsp = channel.getDSPClock.last
      stop_time = pdsp + Integer(time * sr / 1000)
      channel.addFadePoint(pdsp, start_value)
      channel.addFadePoint(stop_time, end_value)
      channel.setDelay(0, stop_time + 20, false) if end_value == 0
      channel.setVolumeRamp(true)
      channel.instance_variable_set(:@stop_time, stop_time)
    end
    # Fade in out a channel
    # @param channel [FMOD::Channel] the channel to fade
    # @param fadeout_time [Integer] number of miliseconds to perform the fade out
    # @param sleep_time [Integer] number of miliseconds to wait before fading in
    # @param fadein_time [Integer] number of miliseconds to perform the fade in
    # @param sleep_type [Symbol] tell the sleep_time type (:ms, :pcm)
    # @param lowest_volume [Integer] lowest volume in %
    def fade_in_out(channel, fadeout_time, sleep_time, fadein_time, sleep_type = :ms, lowest_volume = 0.0)
      sr = FMOD::System.getSoftwareFormat.first
      pdsp = channel.getDSPClock.last
      sleep_time = sleep_time * sr / 1000 if sleep_type == :ms
      p1_time = pdsp + Integer(fadeout_time * sr / 1000)
      p2_time = pdsp + Integer(fadeout_time * sr / 1000) + sleep_time
      p3_time = pdsp + Integer((fadeout_time + fadein_time) * sr / 1000) + sleep_time
      channel.addFadePoint(pdsp, 1.0)
      channel.addFadePoint(p1_time, lowest_volume)
      channel.addFadePoint(p2_time, lowest_volume)
      channel.addFadePoint(p3_time, 1.0)
      channel.setVolumeRamp(true)
    end
    # Try to release all fading sounds that are done fading
    # @param additionnal_sound [FMOD::Sound, nil] a sound that should be released with the others
    # @note : Warning ! Doing sound.release before channel.anything make the channel invalid and raise an FMOD::Error
    def release_fading_sounds(additionnal_sound)
      unless @fading_sounds.empty?
        sound_guardian = [@bgm_sound, @bgs_sound, @me_sound]
        sounds_to_delete = []
        @fading_sounds.each do |sound, channel|
                    additionnal_sound = nil if additionnal_sound == sound
          next unless channel_stop_time_exceeded(channel)
          sounds_to_delete << sound
          channel.stop
          next if sound_guardian.include?(sound)
          sound.release
        rescue FMOD::Error
          next

        end
        sounds_to_delete.each { |sound| @fading_sounds.delete(sound) }
      end
      additionnal_sound&.release
    end
    # Return if the channel time is higher than the stop time
    # @note will return true if the channel handle is invalid
    # @param channel [FMOD::Channel]
    # @return [Boolean]
    def channel_stop_time_exceeded(channel)
      return channel.getDSPClock.last >= channel.instance_variable_get(:@stop_time).to_i
    rescue FMOD::Error
      return true
    end
    # Function that detects if the previous playing sound is the same as the next one
    # @param filename [String] the filename of the sound
    # @param old_filename [String] the filename of the old sound
    # @param sound [FMOD::Sound] the previous playing sound
    # @param channel [FMOD::Channel, nil] the previous playing channel
    # @param fade_out [Boolean, Integer] if the channel should fades out (Integer = time to fade)
    # @note If the sound wasn't the same, the channel will be stopped if not nil
    # @return [Boolean]
    def was_sound_previously_playing?(filename, old_filename, sound, channel, fade_out = false)
      return false unless sound
      return true unless filename != old_filename
      return false unless channel && (channel.isPlaying rescue false)
      if fade_out && !@fading_sounds[sound]
        fade_time = fade_out == true ? FadeInTime : fade_out
        @was_playing_callback = proc {fade(fade_time, @fading_sounds[sound] = channel) }
      else
        @was_playing_callback = proc {channel.stop }
      end
      return false
    end
    # Adjust channel volume and pitch
    # @param channel [Fmod::Channel]
    # @param volume [Numeric] target volume
    # @param pitch [Numeric] target pitch
    def adjust_channel(channel, volume, pitch)
      channel.setPriority([@bgm_channel, @me_channel, @bgs_channel].index(channel) || 128)
      channel.setVolume(volume / 100.0)
      channel.setPitch(pitch / 100.0)
      channel.setPaused(false)
    end
    # Adjust the volume of a channel
    # @param channel [Fmod::Channel]
    # @param volume [Numeric]
    def adjust_volume(channel, volume)
      return unless channel
      channel.setVolume(volume / 100.0)
    end
    # Automatically call the "was playing callback"
    def call_was_playing_callback
      @was_playing_callback&.call
      @was_playing_callback = nil
    rescue StandardError
      @was_playing_callback = nil
    end
    # Reset the sound engine
    def __reset__
      bgm_stop
      bgs_stop
      me_stop
      se_stop
      @bgm_sound = nil
      @bgs_sound = nil
      @me_sound = nil
      @se_sounds = {}
      @fading_sounds = {}
      @was_playing_callback = nil
    end
    # Synchronize a mutex
    # @param mutex [Mutex] the mutex to safely synchronize
    # @param block [Proc] the block to call
    def synchronize(mutex, &block)
      return yield if mutex.locked? && mutex.owned?
      mutex.synchronize(&block)
    end
    # Update the Audio
    def update
      FMOD::System.update
    end
  end
else
  if Object.const_defined?(:SFMLAudio)
    module Audio
      @bgm_sound = SFMLAudio::Music.new
      @bgm_fade_settings = nil
      @bgs_sound = SFMLAudio::Music.new
      @bgs_fade_settings = nil
      @me_sound = SFMLAudio::Sound.new
      @me_buffer = SFMLAudio::SoundBuffer.new
      @me_fade_settings = nil
      @se_sounds = {}
      @cries_stack = []
      EXT = ['.ogg', '.mp3', '.wav', '.flac']
      module_function
      def bgm_play(file_name, volume = 100, pitch = 100, fade_in = true)
        bgm_stop
        return unless (memory = load_file_data(file_name))
        @bgm_sound.open_from_memory(memory)
        autoloop(@bgm_sound, memory)
        @bgm_sound.set_loop(true)
        @bgm_sound.set_pitch(pitch / 100.0)
        @bgm_sound.set_volume(volume * @music_volume / 100.0)
        @bgm_sound.play unless @me_sound.playing?
        @bgm_was_playing = true
      end
      def bgm_position
        return 0 if @bgm_sound.stopped?
        return (@bgm_sound.get_playing_offset * @bgm_sound.get_sample_rate).to_i
      end
      def bgm_position=(position)
        return if @bgm_sound.stopped?
        @bgm_sound.set_playing_offset(position / @bgm_sound.get_sample_rate.to_f)
      rescue StandardError
        log_error("bgm_position= : #{$!.message}")
      end
      def bgm_fade(time)
        return if @bgm_sound.stopped?
        @bgm_fade_settings = [Time.new, @bgm_sound.get_volume, time / 1000.0]
      end
      def bgm_stop
        @bgm_fade_settings = nil
        @bgm_was_playing = false
        return if @bgm_sound.stopped?
        @bgm_sound.stop
      end
      def bgs_play(file_name, volume = 100, pitch = 100, fade_in = true)
        bgs_stop
        return unless (memory = load_file_data(file_name))
        @bgs_sound.open_from_memory(memory)
        autoloop(@bgs_sound, memory)
        @bgs_sound.set_loop(true)
        @bgs_sound.set_pitch(pitch / 100.0)
        @bgs_sound.set_volume(volume * @sfx_volume / 100.0)
        @bgs_sound.play
      end
      def bgs_fade(time)
        return if @bgs_sound.stopped?
        @bgs_fade_settings = [Time.new, @bgs_sound.get_volume, time / 1000.0]
      end
      def bgs_stop
        @bgs_fade_settings = nil
        return if @bgs_sound.stopped?
        @bgs_sound.stop
      end
      def me_play(file_name, volume = 100, pitch = 100, preserve_bgm = false)
        me_stop
        return unless (memory = load_file_data(file_name))
        @me_buffer.load_from_memory(memory)
        @me_sound.set_buffer(@me_buffer)
        @me_sound.set_pitch(pitch / 100.0)
        @me_sound.set_volume(volume * @music_volume / 100.0)
        @me_sound.play
        @bgm_sound.pause if @bgm_sound.playing? && !preserve_bgm
        @me_replay_bgm = true
      end
      def me_fade(time)
        return if @me_sound.stopped?
        @me_fade_settings = [Time.new, @me_sound.get_volume, time / 1000.0]
      end
      def me_stop
        @me_fade_settings = nil
        @bgm_sound.play if @bgm_was_playing && !@bgm_sound.stopped? && @me_replay_bgm
        @me_replay_bgm = false
        return if @me_sound.stopped?
        @me_sound.stop
      end
      def se_play(file_name, volume = 100, pitch = 100)
        unless (sound = @se_sounds[file_name])
          return unless (memory = load_file_data(file_name))
          sound = SFMLAudio::Sound.new
          buffer = SFMLAudio::SoundBuffer.new
          buffer.load_from_memory(memory)
          sound.set_buffer(buffer)
          if file_name.downcase.include?('/cries/')
            @cries_stack << sound
            @cries_stack.shift.stop if @cries_stack.size > 5
          else
            @se_sounds[file_name] = sound
          end
        end
        sound.stop if sound.playing?
        sound.set_pitch(pitch / 100.0)
        sound.set_volume(volume * @sfx_volume / 100.0)
        sound.play
      end
      def se_stop
        @se_sounds.each_value(&:stop)
        @cries_stack.each(&:stop)
        @cries_stack.clear
        @se_sounds.clear
      end
      def adjust_volume(channel, volume)
        return unless channel
        channel.setVolume(volume / 100.0)
      end
      def load_file_data(filename)
        real_filename = search_filename(filename)
        unless File.exist?(real_filename)
          log_error("The audio file #{real_filename} couldn't be loaded")
          return nil
        end
        return File.binread(real_filename)
      end
      def search_filename(file_name)
        file_name = file_name.downcase
        return file_name if File.exist?(file_name)
        EXT.each do |ext|
          filename = file_name + ext
          return filename if File.exist?(filename)
        end
        return file_name
      end
      def autoloop(music, memory)
        data = memory[0, 2048]
        start_index = data.index('LOOPSTART=')
        length_index = data.index('LOOPLENGTH=')
        return unless start_index && length_index
        start = data[start_index + 10, 20].to_i
        lenght = data[length_index + 11, 20].to_i
        log_info("LOOP: #{start} -> #{start + lenght}") unless PSDK_CONFIG.release?
        frequency = music.get_sample_rate.to_f
        music.set_loop_points(start / frequency, lenght / frequency)
      end
      def __reset__
        bgm_stop
        bgs_stop
        me_stop
        se_stop
        @se_sounds = {}
        @bgm_fade_settings = nil
        @bgs_fade_settings = nil
        @me_fade_settings = nil
      end
      def update
        bgm_stop if @bgm_fade_settings && update_fade(@bgm_sound, *@bgm_fade_settings)
        bgs_stop if @bgs_fade_settings && update_fade(@bgs_sound, *@bgs_fade_settings)
        me_stop if @me_fade_settings && update_fade(@me_sound, *@me_fade_settings)
        me_stop if @bgm_was_playing && @me_replay_bgm && @me_sound.stopped?
      end
      def update_fade(sound, start_time, volume, duration)
        current_duration = Graphics.current_time - start_time
        return true if current_duration >= duration
        sound.set_volume(volume * (1 - current_duration / duration))
        return false
      end
    end
  else
    module Audio
      log_error('FMOD not found!')
      module_function
      def bgm_play(file_name, volume = 100, pitch = 100, fade_in = true)
      end
      def bgm_position
        return 0
      end
      def bgm_position=(position)
      end
      def bgs_play(file_name, volume = 100, pitch = 100, fade_in = true)
      end
      def me_play(file_name, volume = 100, pitch = 100, preserve_bgm = false)
      end
      def se_play(file_name, volume = 100, pitch = 100)
      end
      def bgm_fade(time)
      end
      def bgs_fade(time)
      end
      def me_fade(time)
      end
      def bgm_stop
      end
      def bgs_stop
      end
      def me_stop
      end
      def se_stop
      end
      def __reset__
      end
      def update
      end
    end
  end
end
Graphics.on_start do
  Audio::Cache.start
end
# Module that helps to convert stuff
module Converter
  module_function
  # Convert a tileset to a PSDK readable PSDK tileset (if required)
  # @param filename [String]
  # @param max_size [Integer] Maximum Size of the texture in the Graphic Card
  # @param min_size [Integer] Minimum Size of the texture for weak Graphic Card
  # @example Converter.convert_tileset("Graphics/tilesets/tileset.png")
  def convert_tileset(filename, max_size = 4096, min_size = 1024)
    return unless File.exist?(filename.downcase)
    img = Image.new(filename.downcase)
    new_filename = filename.downcase.gsub('.png', '_._ingame.png')
    if img.height > (min_size / 256 * min_size)
      log_error("#{filename} is too big for weak Graphic Card !")
      min_size = max_size
    end
    if img.height > (max_size / 256 * max_size)
      log_error("#{filename} is too big for most Graphic Card !")
      return
    end
    nb_col = (img.height / min_size.to_f).ceil
    if nb_col > 32
      log_error("#{filename} cannot be converted to #{new_filename}, there's too much tiles.")
      return
    end
    new_image = Image.new(256 * nb_col, min_size)
    nb_col.times do |i|
      height = min_size
      height = img.height - (i * min_size) if (i * min_size + height) > img.height
      new_image.blt(256 * i, 0, img, Rect.new(0, i * min_size, 256, height))
    end
    new_image.to_png_file(new_filename)
    log_info("#{filename} converted to #{new_filename}!")
    img.dispose
    new_image.dispose
  end
  # Convert an autotile file to a specific autotile file
  # @param filename [String]
  # @example Converter.convert_autotile("Graphics/autotiles/eauca.png")
  def convert_autotile(filename)
    autotiles = [Image.new(filename)]
    bmp_arr = Array.new(48) { |i| generate_autotile_bmp(i + 48, autotiles) }
    bmp = Image.new(48 * 32, bmp_arr.first.height)
    bmp_arr.each_with_index do |sub_bmp, i|
      bmp.blt(32 * i, 0, sub_bmp, sub_bmp.rect)
    end
    bmp.to_png_file(new_filename = filename.gsub('.png', '_._tiled.png'))
    bmp.dispose
    bmp_arr.each(&:dispose)
    autotiles.first.dispose
    log_info("#{filename} converted to #{new_filename}!")
  end
  # The autotile builder data
  Autotiles = [[[27, 28, 33, 34], [5, 28, 33, 34], [27, 6, 33, 34], [5, 6, 33, 34], [27, 28, 33, 12], [5, 28, 33, 12], [27, 6, 33, 12], [5, 6, 33, 12]], [[27, 28, 11, 34], [5, 28, 11, 34], [27, 6, 11, 34], [5, 6, 11, 34], [27, 28, 11, 12], [5, 28, 11, 12], [27, 6, 11, 12], [5, 6, 11, 12]], [[25, 26, 31, 32], [25, 6, 31, 32], [25, 26, 31, 12], [25, 6, 31, 12], [15, 16, 21, 22], [15, 16, 21, 12], [15, 16, 11, 22], [15, 16, 11, 12]], [[29, 30, 35, 36], [29, 30, 11, 36], [5, 30, 35, 36], [5, 30, 11, 36], [39, 40, 45, 46], [5, 40, 45, 46], [39, 6, 45, 46], [5, 6, 45, 46]], [[25, 30, 31, 36], [15, 16, 45, 46], [13, 14, 19, 20], [13, 14, 19, 12], [17, 18, 23, 24], [17, 18, 11, 24], [41, 42, 47, 48], [5, 42, 47, 48]], [[37, 38, 43, 44], [37, 6, 43, 44], [13, 18, 19, 24], [13, 14, 43, 44], [37, 42, 43, 48], [17, 18, 47, 48], [13, 18, 43, 48], [1, 2, 7, 8]]]
  # The source rect (to draw autotiles)
  SRC = Rect.new(0, 0, 16, 16)
  # Generate one tile of an autotile
  # @param id [Integer] id of the tile
  # @param autotiles [Array<Texture>] autotiles bitmaps
  # @return [Texture] the calculated bitmap
  def generate_autotile_bmp(id, autotiles)
    autotile = autotiles[id / 48 - 1]
    return Image.new(32, 32) if !autotile || autotile.width < 96
    src = SRC
    id %= 48
    tiles = Autotiles[id >> 3][id & 7]
    frames = autotile.width / 96
    bmp = Image.new(32, frames * 32)
    frames.times do |x|
      anim = x * 96
      4.times do |i|
        tile_position = tiles[i] - 1
        src.set(tile_position % 6 * 16 + anim, tile_position / 6 * 16, 16, 16)
        bmp.blt(i % 2 * 16, i / 2 * 16 + x * 32, autotile, src)
      end
    end
    return bmp
  end
end
Graphics.on_start do
  RPG::Cache::LOADS.each do |k|
    RPG::Cache.send(k)
  end
  RPG::Cache.instance_eval do
    undef meta_exec
    remove_const :Cache_meta_without_hue
    remove_const :Cache_meta_with_hue
  end
end
