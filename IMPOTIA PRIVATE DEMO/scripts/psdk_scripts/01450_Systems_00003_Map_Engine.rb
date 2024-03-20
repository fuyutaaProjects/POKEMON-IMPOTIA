module Util
  # Module that hold a warping function
  # @author Nuri Yuri
  module Warp
    module_function
    # Warp to an event of another map (below by default)
    # @param map_id [Integer] ID of the map where to warp
    # @param name_or_id [Integer, String] name or ID of the event that will be found
    # @param transition_type [Integer] 0 = no transition, 1 = circular transition, 2 = directed transition, -1 = bw transition
    # @param offset_x [Integer] offset x to add to the warp x coordinate
    # @param offset_y [Integer] offset y to add to the warp y coordinate
    # @param direction [Integer] new direction of the player
    def to(map_id, name_or_id, transition_type = 0, offset_x: 0, offset_y: 1, direction: 0)
      x, y = find_event_from(map_id, name_or_id)
      setup_transition(transition_type) unless transition_type == 0
      warp(map_id, x + offset_x, y + offset_y, direction)
    end
    # Define the transition for the warping process
    # @param type [Integer] type of transition
    def setup_transition(type)
      if type < 0
        $game_switches[::Yuki::Sw::WRP_Transition] = true
      else
        $game_variables[::Yuki::Var::MapTransitionID] = type
      end
    end
    # Warp to the specified coordinate
    # @param map_id [Integer] ID of the map where to warp
    # @param x_pos [Integer] x coordinate where to warp
    # @param y_pos [Integer] y coordinate where to warp
    # @param direction [Integer] new direction of the player
    def warp(map_id, x_pos, y_pos, direction)
      $game_temp.player_new_x = x_pos
      $game_temp.player_new_y = y_pos
      $game_temp.player_new_direction = direction
      $game_temp.player_new_map_id = map_id
      $game_temp.player_transferring = true
    end
    # Find the event coordinate in another map
    # @param map_id [Integer] ID of the map where to warp
    # @param name_or_id [Integer, String] name or ID of the event that will be found
    # @return [Array<Integer>] x & y coordinate of the event in the other map
    def find_event_from(map_id, name_or_id)
      $game_map.setup(map_id) if $game_map.map_id != map_id
      if name_or_id.is_a?(Integer)
        event = $game_map.events[name_or_id]
      else
        event = $game_map.events_list.find { |event| event.event.name == name_or_id }
      end
      return 0, 0 unless event
      return event.x, event.y
    end
  end
end
module UI
  # Show a panel about the currently visited zone on the map
  class MapPanel < SpriteStack
    # Animation delta y
    DELTA_Y = 32
    # Create a new MapPanel
    # @param viewport [Viewport]
    # @param zone [Studio::Zone]
    def initialize(viewport, zone)
      super(viewport, *initial_coordinates, default_cache: :windowskin)
      @zone = zone
      create_sprites
      self.z = 5000
      viewport.sort_z
    end
    # Update the panel animation
    def update
      return if Graphics.frozen?
      create_animation unless @animation
      @animation.update
    end
    # Tell if the animation is done and the pannel should be disposed
    def done?
      return false if Graphics.frozen?
      return true unless @animation
      return @animation.done?
    end
    private
    def create_sprites
      create_background
      create_text
    end
    def create_animation
      @animation = Yuki::Animation.wait_signal {$game_temp.transition_processing == false }
      @animation.play_before(Yuki::Animation.move_discreet(0.54, self, x, y, x, y + DELTA_Y))
      @animation.play_before(Yuki::Animation.wait(1.5))
      @animation.play_before(Yuki::Animation.move_discreet(0.54, self, x, y + DELTA_Y, x, y))
      @animation.start
    end
    def create_background
      add_background(background_filename)
    end
    def create_text
      map_name = @zone.name
      color = 10
      map_name.gsub!(/\\c\[([0-9]+)\]/) do
        color = $1.to_i
        nil
      end
      fixed_map_name = PFM::Text.parse_string_for_messages(map_name)
      add_text(0, -2, @stack.first.width, @stack.first.height, fixed_map_name, 1, color: color)
    end
    def background_filename
      attempt = "panel_#{@zone.panel_id}"
      return attempt if RPG::Cache.windowskin_exist?(attempt)
      return "pannel_#{@zone.panel_id}"
    end
    def initial_coordinates
      return [2, -30]
    end
  end
end
# Describe a picture display on the Screen
class Game_Picture
  attr_reader :number
  # ピクチャ番号
  attr_reader :name
  # ファイル名
  attr_reader :origin
  # 原点
  attr_reader :x
  # X 座標
  attr_reader :y
  # Y 座標
  attr_reader :zoom_x
  # X 方向拡大率
  attr_reader :zoom_y
  # Y 方向拡大率
  attr_reader :opacity
  # 不透明度
  attr_reader :blend_type
  # ブレンド方法
  attr_reader :tone
  # 色調
  attr_reader :angle
  # 回転角度
  attr_reader :mirror
  # Initialize the Game_Picture with default value
  # @param number [Integer] the "id" of the picture
  def initialize(number)
    @number = number
    @name = nil.to_s
    @origin = 0
    @x = 0.0
    @y = 0.0
    @zoom_x = 100.0
    @zoom_y = 100.0
    @opacity = 255.0
    @blend_type = 1
    @duration = 0
    @target_x = @x
    @target_y = @y
    @target_zoom_x = @zoom_x
    @target_zoom_y = @zoom_y
    @target_opacity = @opacity
    @tone = Tone.new(0, 0, 0, 0)
    @tone_target = Tone.new(0, 0, 0, 0)
    @tone_duration = 0
    @angle = 0
    @rotate_speed = 0
    @mirror = false
  end
  # Show a picture
  # @param name [String] The name of the image in Graphics/Pictures
  # @param origin [Integer] the origin type (top left / center)
  # @param x [Numeric] the x position on the screen
  # @param y [Numeric] the y position on the screen
  # @param zoom_x [Numeric] the zoom on the width
  # @param zoom_y [Numeric] the zoom on the height
  # @param opacity [Numeric] the opacity of the picture
  # @param blend_type [Integer] the blend_type of the picture
  def show(name, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
    @name = name
    @origin = origin
    @x = x.to_f
    @y = y.to_f
    @zoom_x = zoom_x.to_f
    @zoom_y = zoom_y.to_f
    @opacity = opacity.to_f
    @blend_type = blend_type
    @duration = 0
    @target_x = @x
    @target_y = @y
    @target_zoom_x = @zoom_x
    @target_zoom_y = @zoom_y
    @target_opacity = @opacity
    @tone = Tone.new(0, 0, 0, 0)
    @tone_target = Tone.new(0, 0, 0, 0)
    @tone_duration = 0
    @angle = 0
    @rotate_speed = 0
  end
  # Move a picture
  # @param duration [Integer] the number of frame the picture takes to move
  # @param origin [Integer] the origin type (top left / center)
  # @param x [Numeric] the x position on the screen
  # @param y [Numeric] the y position on the screen
  # @param zoom_x [Numeric] the zoom on the width
  # @param zoom_y [Numeric] the zoom on the height
  # @param opacity [Numeric] the opacity of the picture
  # @param blend_type [Integer] the blend_type of the picture
  def move(duration, origin, x, y, zoom_x, zoom_y, opacity, blend_type)
    @duration = duration
    @origin = origin
    @target_x = x.to_f
    @target_y = y.to_f
    @target_zoom_x = zoom_x.to_f
    @target_zoom_y = zoom_y.to_f
    @target_opacity = opacity.to_f
    @blend_type = blend_type
  end
  # Rotate the picture
  # @param speed [Numeric] the rotation speed (2*angle / frame)
  def rotate(speed)
    @rotate_speed = speed
  end
  # Start a tone change of the picture
  # @param tone [Tone] the new tone of the picture
  # @param duration [Integer] the number of frame the tone change takes
  def start_tone_change(tone, duration)
    @tone_target = tone.clone
    @tone_duration = duration
    if @tone_duration == 0
      @tone = @tone_target.clone
    end
  end
  # Remove the picture from the screen
  def erase
    @name = nil.to_s
  end
  # Set the mirror state of a Game_Picture
  # @param bool [Boolean] the mirror state
  def mirror=(bool)
    @mirror = bool
  end
  # Update the picture state change
  def update
    if @duration >= 1
      d = @duration
      @x = (@x * (d - 1) + @target_x) / d
      @y = (@y * (d - 1) + @target_y) / d
      @zoom_x = (@zoom_x * (d - 1) + @target_zoom_x) / d
      @zoom_y = (@zoom_y * (d - 1) + @target_zoom_y) / d
      @opacity = (@opacity * (d - 1) + @target_opacity) / d
      @duration -= 1
    end
    if @tone_duration >= 1
      d = @tone_duration
      @tone.red = (@tone.red * (d - 1) + @tone_target.red) / d
      @tone.green = (@tone.green * (d - 1) + @tone_target.green) / d
      @tone.blue = (@tone.blue * (d - 1) + @tone_target.blue) / d
      @tone.gray = (@tone.gray * (d - 1) + @tone_target.gray) / d
      @tone_duration -= 1
    end
    if @rotate_speed != 0
      @angle += @rotate_speed / 2.0
      while @angle < 0
        @angle += 360
      end
      @angle %= 360
    end
  end
end
# Update every component that affect the screen
class Game_Screen
  # Tone that is considered neutral (to let interpreter know how to handle tone & TJN)
  NEUTRAL_TONE = Tone.new(0, 0, 0, 0)
  attr_reader :tone
  # 色調
  attr_reader :flash_color
  # フラッシュ色
  attr_reader :shake
  # シェイク位置
  attr_reader :pictures
  # ピクチャ
  attr_reader :weather_type
  # 天候 タイプ
  attr_reader :weather_max
  # 天候 画像の最大数
  # default initializer
  def initialize
    @tone = Tone.new(0, 0, 0, 0)
    @tone_target = Tone.new(0, 0, 0, 0)
    @tone_duration = 0
    @flash_color = Color.new(0, 0, 0, 0)
    @flash_duration = 0
    @shake_power = 0
    @shake_speed = 0
    @shake_duration = 0
    @shake_direction = 1
    @shake = 0
    @pictures = [nil]
    for i in 1..100
      @pictures.push(Game_Picture.new(i))
    end
    @weather_type = 0
    @weather_max = 0.0
    @weather_type_target = 0
    @weather_max_target = 0.0
    @weather_duration = 0
  end
  # start a tone change process
  # @param tone [Tone] the new tone
  # @param duration [Integer] the time it takes in frame
  def start_tone_change(tone, duration)
    @tone_target = tone.clone
    @tone_duration = duration
    if @tone_duration == 0
      @tone = @tone_target.clone
    end
  end
  # start a flash process
  # @param color [Color] a color
  # @param duration [Integer] the time it takes in frame
  def start_flash(color, duration)
    @flash_color = color.clone
    @flash_duration = duration
  end
  # start a screen shake process
  # @param power [Integer] the power of the shake (distance between normal position and shake limit position)
  # @param speed [Integer] the speed of the shake (10 = 4 frame to get one shake period)
  # @param duration [Integer] the time the shake lasts
  def start_shake(power, speed, duration)
    @shake_power = power
    @shake_speed = speed
    @shake_duration = duration
  end
  # starts a weather change process
  # @param type [Integer] the type of the weather
  # @param power [Numeric] The power of the weather
  # @param duration [Integer] the time it takes to change the weather
  # @param psdk_weather [Integer, nil] the PSDK weather type
  def weather(type, power, duration, psdk_weather: nil)
    if psdk_weather
      type = psdk_weather
      $env.apply_weather(psdk_weather)
    else
      case type
      when 1, 2
        $env.apply_weather(1)
        type = 1
      when 3
        $env.apply_weather(4)
        type = 4
      else
        $env.apply_weather(0, 0)
        type = 0
      end
    end
    @weather_type_target = type
    if @weather_type_target != 0
      @weather_type = @weather_type_target
    end
    if @weather_type_target == 0
      @weather_max_target = 0.0
    else
      @weather_max_target = (power + 1) * 4.0
    end
    @weather_duration = duration
    if @weather_duration == 0
      @weather_type = @weather_type_target
      @weather_max = @weather_max_target
    end
  end
  # Update every process and picture
  def update
    if @tone_duration >= 1
      d = @tone_duration
      @tone.red = (@tone.red * (d - 1) + @tone_target.red) / d
      @tone.green = (@tone.green * (d - 1) + @tone_target.green) / d
      @tone.blue = (@tone.blue * (d - 1) + @tone_target.blue) / d
      @tone.gray = (@tone.gray * (d - 1) + @tone_target.gray) / d
      @tone_duration -= 1
    end
    if @flash_duration >= 1
      d = @flash_duration
      @flash_color.alpha = @flash_color.alpha * (d - 1) / d
      @flash_duration -= 1
    end
    if @shake_duration >= 1 || @shake != 0
      delta = (@shake_power * @shake_speed * @shake_direction) / 10.0
      if @shake_duration <= 1 && @shake * (@shake + delta) < 0
        @shake = 0
      else
        @shake += delta
      end
      if @shake > @shake_power * 2
        @shake_direction = -1
      end
      if @shake < -@shake_power * 2
        @shake_direction = 1
      end
      if @shake_duration >= 1
        @shake_duration -= 1
      end
    end
    if @weather_duration >= 1
      d = @weather_duration
      @weather_max = (@weather_max * (d - 1) + @weather_max_target) / d
      @weather_duration -= 1
      if @weather_duration == 0
        @weather_type = @weather_type_target
      end
    end
    if $game_temp.in_battle
      for i in 51..100
        @pictures[i].update
      end
    else
      for i in 1..50
        @pictures[i].update
      end
    end
  end
end
# Class that describe a Character Sprite on the Map
class Sprite_Character < RPG::Sprite
  # Zoom of a tile and factor used to fix coordinate
  TILE_ZOOM = Configs.display.tilemap_settings.character_tile_zoom
  # Zoom of a Sprite
  SPRITE_ZOOM = Configs.display.tilemap_settings.character_sprite_zoom
  # Tag that disable shadow
  SHADOW_TAG = '§'
  # Name of the shadow file
  SHADOW_FILE = '0 Ombre Translucide'
  # Enable or disable realistic shadow
  REALISTIC_SHADOW = true
  # Tag that add 1 to the superiority of the Sprite_Character
  SUP_TAG = '¤'
  # Blend mode for Reflection
  REFLECTION_BLEND_MODE = BlendMode.new
  REFLECTION_BLEND_MODE.alpha_dest_factor = BlendMode::One
  REFLECTION_BLEND_MODE.alpha_src_factor = BlendMode::Zero
  # Character displayed by the Sprite_Character
  # @return [Game_Character]
  attr_accessor :character
  # Return the Sprite bush_depth
  # @return [Integer]
  attr_reader :bush_depth
  # Initialize a new Sprite_Character
  # @param viewport [Viewport] the viewport where the sprite will be shown
  # @param character [Game_Character, Game_Event, Game_Player] the character shown
  def initialize(viewport, character = nil)
    super(viewport)
    @bush_depth_sprite = Sprite.new(viewport)
    @bush_depth_sprite.opacity = 128
    @height = 0
    init(character)
  end
  # Initialize the specific parameters of the Sprite_Character (shadow, add_z etc...)
  # @param character [Game_Character, Game_Event, Game_Player] the character shown
  def init(character)
    @character = character
    dispose_shadow
    dispose_reflection
    @bush_depth_sprite.visible = false
    @bush_depth = 0
    init_reflection
    init_add_z_shadow
    @tile_zoom = TILE_ZOOM
    @tile_id = 0
    @character_name = nil
    @pattern = 0
    @direction = 0
    update
  end
  # Initialize the add_z info & the shadow sprite of the Sprite_Character
  def init_add_z_shadow
    event = character.instance_variable_get(:@event)
    return @add_z = 2 if event && event.name.index(SUP_TAG) == 0
    @add_z = 0
    return unless $game_switches[::Yuki::Sw::CharaShadow]
    return if character.shadow_disabled && event && event.pages.size == 1
    init_shadow if !event || event.name.index(SHADOW_TAG) != 0
  end
  # Update every informations about the Sprite_Character
  def update
    super if (@_animation || @_loop_animation) && !Graphics::FPSBalancer.global.skipping?
    update_graphics if @character_name != @character.character_name || @tile_id != @character.tile_id
    return unless update_position
    update_pattern if @tile_id == 0
    self.bush_depth = @character.bush_depth
    self.opacity = (@character.transparent ? 0 : @character.opacity)
    update_load_animation if @character.animation_id != 0
    update_bush_depth if @bush_depth > 0
    update_shadow if @shadow
  end
  # Update the graphics of the Sprite_Character
  def update_graphics
    @tile_id = @character.tile_id
    @character_name = @character.character_name
    self.visible = !@character_name.empty? || @tile_id > 0
    @tile_id >= 384 ? update_tile_graphic : update_sprite_graphic
    update_reflection_graphics
  end
  # Update the sprite graphics
  def update_sprite_graphic
    self.bitmap = RPG::Cache.character(@character_name, 0)
    @cw = bitmap.width / 4
    @height = @ch = bitmap.height / 4
    set_origin(@cw / 2, @ch)
    self.zoom = SPRITE_ZOOM
    src_rect.set(@character.pattern * @cw, (@character.direction - 2) / 2 * @ch, @cw, @ch)
    @pattern = @character.pattern
    @direction = @character.direction
  end
  # Update the tile graphic of the sprite
  def update_tile_graphic
    map_data = Yuki::MapLinker.map_datas
    if !map_data || map_data.empty?
      self.bitmap = RPG::Cache.tileset($game_map.tileset_name)
      tile_id = @tile_id - 384
      tlsy = tile_id / 8 * 32
      max_size = 4096
      src_rect.set((tile_id % 8 + tlsy / max_size * 8) * 32, tlsy % max_size, 32, @height = 32)
    else
      x = @character.x
      y = @character.y
      event_map = map_data.find { |map| map.x_range.include?(x) && map.y_range.include?(y) } || map_data.first
      event_map.assign_tile_to_sprite(self, @tile_id)
      @height = 32
    end
    self.zoom = TILE_ZOOM
    set_origin(16, 32)
    @ch = 32
  end
  # Update the position of the Sprite_Character on the screen
  # @return [Boolean] if the update can continue after the call of this function or not
  def update_position
    set_position(@character.screen_x * @tile_zoom, @character.screen_y * @tile_zoom)
    @reflection&.set_position(x, y + ((@character.z - 1) * 32 * @tile_zoom).floor)
    self.z = @character.screen_z(@ch) + @add_z
    return true
  end
  # Update the pattern animation
  def update_pattern
    pattern = @character.pattern
    if @pattern != pattern
      src_rect.x = pattern * @cw
      @pattern = pattern
      @reflection&.src_rect&.x = src_rect.x
    end
    direction = @character.direction
    if @direction != direction
      src_rect.y = (direction - 2) / 2 * @ch
      @direction = direction
      @reflection&.src_rect&.y = src_rect.y
    end
  end
  # Load the animation when there's one on the character
  def update_load_animation
    $data_animations ||= load_data('Data/Animations.rxdata')
    Sprite_Character.fix_rmxp_animations
    animation = $data_animations[@character.animation_id]
    animation(animation, true)
    @character.animation_id = 0
  end
  # Update the bush depth effect
  def update_bush_depth
    bsp = @bush_depth_sprite
    bsp.z = z
    bsp.set_position(x, y)
    bsp.zoom = zoom_x
    bsp.bitmap = bitmap if bsp.bitmap != bitmap
    rc = bsp.src_rect
    h = @height
    bd = @bush_depth / 2
    (rc2 = src_rect).height = h - bd
    bsp.set_origin(ox, bd)
    rc.set(rc2.x, rc2.y + rc2.height, rc2.width, bd)
  end
  # Change the bush_depth
  # @param value [Integer]
  def bush_depth=(value)
    @bush_depth = value.to_i
    return if (@bush_depth_sprite.visible = @bush_depth > 0)
    src_rect.height = @height
    self.oy = @height
  end
  # Dispose the Sprite_Character and its shadow
  def dispose
    super
    dispose_shadow
    dispose_reflection
    @bush_depth_sprite.dispose
  end
  # Initialize the shadow display
  def init_shadow
    @shadow = Sprite.new(viewport)
    @shadow.bitmap = bmp = RPG::Cache.character(SHADOW_FILE)
    @shadow.src_rect.set(0, 0, bmp.width / 4, bmp.height / 4)
    @shadow.ox = bmp.width / 8
    @shadow.oy = bmp.height / 4
    @shadow.zoom = SPRITE_ZOOM
  end
  # Update the shadow
  def update_shadow
    @shadow.opacity = opacity
    @shadow.x = @character.shadow_screen_x * @tile_zoom
    @shadow.y = @character.shadow_screen_y * @tile_zoom
    @shadow.z = z - 1
    @shadow.visible = (!@character.jumping? || REALISTIC_SHADOW) && !@character.shadow_disabled && @character.activated?
    if REALISTIC_SHADOW
      character_offset_y_on_tiles = (@character.shadow_screen_y - @character.screen_y - 2) / 32
      if character_offset_y_on_tiles < 4
        @shadow.zoom_x = SPRITE_ZOOM - 0.25 * character_offset_y_on_tiles
        @shadow.zoom_y = SPRITE_ZOOM - 0.25 * character_offset_y_on_tiles
      else
        @shadow.zoom_x = 0
        @shadow.zoom_y = 0
      end
    end
  end
  # Dispose the shadow sprite
  def dispose_shadow
    @shadow&.dispose
    @shadow = nil
  end
  # Init the reflection sprite
  def init_reflection
    return if $game_switches[Yuki::Sw::WATER_REFLECTION_DISABLED]
    return unless @character.reflection_enabled
    @reflection = ShaderedSprite.new(viewport)
    @reflection.z = -1000
    @reflection.angle = 180
    @reflection.mirror = true
    @reflection.shader = REFLECTION_BLEND_MODE
  end
  # Update the reflection graphics
  def update_reflection_graphics
    return unless @reflection
    @reflection.bitmap = bitmap
    @reflection.set_origin(ox, oy)
    @reflection.zoom = zoom_x
    @reflection.src_rect = src_rect
  end
  # Dispose the reflection sprite
  def dispose_reflection
    @reflection&.dispose
    @reflection = nil
  end
  # Fix the animation file
  def self.fix_rmxp_animations
    if File.exist?('Data/Animations.rxdata')
      if !File.exist?('Data/Animations.psdk') || File.size('Data/Animations.rxdata') != File.size('Data/Animations.psdk')
        save_data($data_animations, 'Data/Animations.rxdata')
        log_info('Re-Saving animations, it\'ll take 2 second...')
        sleep(2)
        save_data($data_animations, 'Data/Animations.psdk')
      end
    end
  end
end
# A sprite that show a Game_Picture on the screen
class Sprite_Picture < ShaderedSprite
  # Shader of a Sprite Picture to allow color & tone processing over them
  SPRITE_SHADER = "  uniform vec4 tone;\n  const vec3 lumaF = vec3(.299, .587, .114);\n  uniform sampler2D texture;\n  void main()\n  {\n    vec4 frag = texture2D(texture, gl_TexCoord[0].xy);\n    float luma = dot(frag.rgb, lumaF);\n    frag.rgb += tone.rgb;\n    frag.rgb = mix(frag.rgb, vec3(luma), tone.w);\n    frag.a *= gl_Color.a;\n    // Result\n    gl_FragColor = frag;\n  }\n"
  # Initialize a new Sprite_Picture
  # @param viewport [Viewport] the viewport where the sprite will be shown
  # @param picture [Game_Picture] the picture
  def initialize(viewport, picture)
    super(viewport)
    self.shader = Shader.create(:full_shader)
    @picture = picture
    @gif_handle = nil
    update
  end
  # Dispose the picture
  def dispose
    dispose_bitmap
    super
  end
  # Update the picture sprite display with the information of the current Game_Picture
  def update
    super
    if @picture_name != @picture.name
      @picture_name = @picture.name
      load_bitmap
    end
    if @picture_name.empty?
      self.visible = false
      return
    end
    self.visible = true
    update_properties
    update_gif if @gif_handle
  end
  private
  # Update the picture properties on the sprite
  def update_properties
    if @picture.origin == 0
      set_origin(0, 0)
    else
      set_origin(bitmap.width / 2, bitmap.height / 2)
    end
    set_position(@picture.x, @picture.y)
    self.z = @picture.number
    self.zoom_x = @picture.zoom_x / 100.0
    self.zoom_y = @picture.zoom_y / 100.0
    self.opacity = @picture.opacity
    shader.blend_type = @picture.blend_type
    self.angle = @picture.angle
    tone = @picture.tone
    unless tone.eql?(@current_tone)
      shader.set_float_uniform('tone', tone)
      @current_tone = tone.clone
    end
    self.mirror = @picture.mirror
    self.mirror = @picture.mirror = false
  end
  # Update the gif animation
  def update_gif
    @gif_handle.update(bitmap)
  end
  # Load the picture bitmap
  def load_bitmap
    if @picture_name.empty?
      dispose_bitmap if @gif_handle
      return
    end
    if Yuki::GifReader.exist?(gif_filename = "#{@picture_name}.gif", :picture)
      @gif_handle = Yuki::GifReader.new(RPG::Cache.picture(gif_filename), true)
      self.bitmap = Texture.new(@gif_handle.width, @gif_handle.height)
    else
      set_bitmap(@picture_name, :picture)
    end
  end
  # Dispose the bitmap
  def dispose_bitmap
    bitmap.dispose if bitmap && !bitmap.disposed?
    @gif_handle = nil
  end
end
# Display the main Timer on the screen
class Sprite_Timer < Text
  # Create the timer with its surface
  def initialize(viewport = nil)
    w = 48
    super(0, viewport, Graphics.width - w, 0 - Text::Util::FOY, 48, 32, nil.to_s, 1)
    load_color(9)
    self.z = 500
    update
  end
  # Update the timer according to the frame_rate and the number of frame elapsed.
  def update
    self.visible = $game_system.timer_working
    if $game_system.timer / 60 != @total_sec
      @total_sec = $game_system.timer / 60
      min = @total_sec / 60
      sec = @total_sec % 60
      self.text = sprintf('%02d:%02d', min, sec)
    end
  end
end
# Display everything that should be displayed during the Scene_Map
class Spriteset_Map
  include Hooks
  # Retrieve the Game Player sprite
  # @return [Sprite_Character]
  attr_reader :game_player_sprite
  # Initialize a new Spriteset_Map object
  # @param zone [Integer, nil] the id of the zone where the player is
  def initialize(zone = nil)
    viewport_type = :main
    exec_hooks(Spriteset_Map, :viewport_type, binding)
    init_viewports(viewport_type)
    Yuki::ElapsedTime.start(:spriteset_map)
    exec_hooks(Spriteset_Map, :initialize, binding)
    init_tilemap
    init_panorama_fog
    init_characters
    init_player
    init_weather_picture_timer
    finish_init(zone)
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#initialize")
  end
  # Method responsive of initializing the viewports
  # @param viewport_type [Symbol]
  def init_viewports(viewport_type)
    @viewport1 = Viewport.create(viewport_type, 0)
    @viewport1.extend(Viewport::WithToneAndColors)
    @viewport1.shader = Shader.create(:map_shader)
    @viewport2 = Viewport.create(viewport_type, 200)
    @viewport3 = Viewport.create(viewport_type, 5000)
    @viewport3.extend(Viewport::WithToneAndColors)
    @viewport3.shader = Shader.create(:map_shader)
  end
  # Take a snapshot of the spriteset
  # @return [Array<Texture>]
  def snap_to_bitmaps
    @viewport1.sort_z
    @viewport2.sort_z
    @viewport3.sort_z
    background = Texture.new(@viewport1.rect.width, @viewport2.rect.width)
    background_image = Image.new(background.width, background.height)
    background_image.fill_rect(0, 0, background.width, background.height, Color.new(0, 0, 0))
    background_image.copy_to_bitmap(background)
    background_image.dispose
    return [background, @viewport1.snap_to_bitmap, @viewport2.snap_to_bitmap, @viewport3.snap_to_bitmap]
  end
  # Do the same as initialize but without viewport initialization (opti)
  # @param zone [Integer, nil] the id of the zone where the player is
  def reload(zone = nil)
    Yuki::ElapsedTime.start(:spriteset_map)
    exec_hooks(Spriteset_Map, :reload, binding)
    init_tilemap
    init_characters
    init_player
    finish_init(zone)
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#reload")
  end
  # Last step of the Spriteset initialization
  # @param zone [Integer, nil] the id of the zone where the player is
  def finish_init(zone)
    exec_hooks(Spriteset_Map, :finish_init, binding)
    Yuki::ElapsedTime.show(:spriteset_map, 'End of spriteset init took')
    update
    Graphics.sort_z
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#finish_init")
  end
  # Return the prefered tilemap class
  # @return [Class]
  def tilemap_class
    tilemap_class = Configs.display.tilemap_settings.tilemap_class
    return Object.const_get(tilemap_class) if Object.const_defined?(tilemap_class)
    return Yuki::Tilemap16px if tilemap_class.match?(/16|Yuri_Tilemap/)
    return Yuki::Tilemap
  end
  # Tilemap initialization
  def init_tilemap
    tilemap_class = self.tilemap_class
    if @tilemap.class != tilemap_class
      @tilemap&.dispose
      @tilemap = tilemap_class.new(@viewport1)
    end
    Yuki::ElapsedTime.show(:spriteset_map, 'Creating tilemap object took')
    map_datas = Yuki::MapLinker.map_datas
    Yuki::MapLinker.spriteset = self
    map_datas.each(&:load_tileset)
    Yuki::ElapsedTime.show(:spriteset_map, 'Loading tilesets took')
    @tilemap.map_datas = map_datas
    @tilemap.reset
    Yuki::ElapsedTime.show(:spriteset_map, 'Resetting the tilemap took')
  end
  # Attempt to load an autotile
  # @param filename [String] name of the autotile
  # @return [Texture] the bitmap of the autotile
  def load_autotile(filename)
    target_filename = filename + '_._tiled'
    if RPG::Cache.autotile_exist?(target_filename)
      filename = target_filename
    else
      if !filename.empty? && RPG::Cache.autotile_exist?(filename)
        Converter.convert_autotile("graphics/autotiles/#{filename}.png")
        filename = target_filename
      end
    end
    return RPG::Cache.autotile(filename)
  end
  # Panorama and fog initialization
  def init_panorama_fog
    @panorama = Plane.new(@viewport1)
    @panorama.z = -1000
    @fog = Plane.new(@viewport1)
    @fog.z = 3000
  end
  # PSDK related thing initialization
  def init_psdk_add
    exec_hooks(Spriteset_Map, :init_psdk_add, binding)
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#init_psdk_add")
  end
  Hooks.register(self, :initialize, 'PSDK Additional Spriteset Initialization') {init_psdk_add }
  Hooks.register(self, :reload, 'PSDK Additional Spriteset Initialization') {init_psdk_add }
  # Sprite_Character initialization
  def init_characters
    if (character_sprites = @character_sprites)
      return recycle_characters(character_sprites)
    end
    @character_sprites = character_sprites = []
    $game_map.events.each_value do |event|
      next unless event.can_be_shown?
      sprite = Sprite_Character.new(@viewport1, event)
      event.particle_push
      character_sprites.push(sprite)
    end
    Yuki::ElapsedTime.show(:spriteset_map, 'Slow character sprite creation took')
  end
  # Recycled Sprite_Character initialization
  # @param character_sprites [Array<Sprite_Character>] the actual stack of sprites
  def recycle_characters(character_sprites)
    i = -1
    $game_map.events.each_value do |event|
      next unless event.can_be_shown?
      character = character_sprites[i += 1]
      event.particle_push
      if character
        character.init(event)
      else
        character_sprites[i] = Sprite_Character.new(@viewport1, event)
      end
    end
    i += 1
    character_sprites.pop.dispose while i < character_sprites.size
    Yuki::ElapsedTime.show(:spriteset_map, 'Fast character sprite creation took')
  end
  # Player initialization
  def init_player
    exec_hooks(Spriteset_Map, :init_player_begin, binding)
    @character_sprites.push(@game_player_sprite = Sprite_Character.new(@viewport1, $game_player))
    $game_player.particle_push
    exec_hooks(Spriteset_Map, :init_player_end, binding)
    Yuki::ElapsedTime.show(:spriteset_map, 'init_player took')
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#init_player")
  end
  # Weather, picture and timer initialization
  def init_weather_picture_timer
    @weather = RPG::Weather.new(@viewport1)
    @picture_sprites = Array.new(50) { |i| Sprite_Picture.new(@viewport2, $game_screen.pictures[i + 1]) }
    @timer_sprite = Sprite_Timer.new(Graphics.window)
  end
  # Create the quest informer array
  def init_quest_informer
    @quest_informers = []
  end
  Hooks.register(self, :initialize, 'Quest Informer') {init_quest_informer }
  # Tell if the spriteset is disposed
  # @return [Boolean]
  def disposed?
    @viewport1.disposed?
  end
  # Spriteset_map dispose
  # @param from_warp [Boolean] if true, prepare a screenshot with some conditions and cancel the sprite dispose process
  # @return [Sprite, nil] a screenshot or nothing
  def dispose(from_warp = false)
    return take_map_snapshot if $game_switches[Yuki::Sw::WRP_Transition] && $scene.class == Scene_Map && from_warp
    return nil if from_warp
    @tilemap.dispose
    @panorama.dispose
    @fog.dispose
    @character_sprites.each(&:dispose)
    @game_player_sprite = nil
    @weather.dispose
    @picture_sprites.each(&:dispose)
    @timer_sprite.dispose
    @quest_informers.clear
    @viewport1.dispose
    @viewport2.dispose
    @viewport3.dispose
    exec_hooks(Spriteset_Map, :dispose, binding)
    return nil
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#dispose")
  end
  # Update every sprite
  def update
    update_panorama_fog
    @tilemap.ox = $game_map.display_x / 4
    @tilemap.oy = $game_map.display_y / 4
    @tilemap.update
    update_events
    update_weather_picture
    @timer_sprite.update
    @viewport1.tone = $game_screen.tone
    @viewport1.ox = $game_screen.shake
    @viewport3.color = $game_screen.flash_color
    @viewport1.update
    @viewport3.update
    exec_hooks(Spriteset_Map, :update, binding)
    Graphics::FPSBalancer.global.run {exec_hooks(Spriteset_Map, :update_fps_balanced, binding) }
    @viewport1.sort_z
    @viewport2.sort_z
  rescue ForceReturn => e
    log_error("Hooks tried to return #{e.data} in Spriteset_Map\#update")
  end
  # update event sprite
  def update_events
    @character_sprites.each(&:update)
    $game_map.event_erased = false if $game_map.event_erased
  end
  # update weather and picture sprites
  def update_weather_picture
    @weather.max = $game_screen.weather_max
    @weather.type = $game_screen.weather_type
    @weather.ox = $game_map.display_x / 4
    @weather.oy = $game_map.display_y / 4
    @weather.update
    @picture_sprites.each(&:update)
  end
  # update panorama and fog sprites
  def update_panorama_fog
    if @panorama_name != $game_map.panorama_name
      @panorama_name = $game_map.panorama_name
      @panorama_hue = $game_map.panorama_hue
      unless @panorama.texture.nil?
        @panorama.texture.dispose
        @panorama.texture = nil
      end
      @panorama.texture = RPG::Cache.panorama(@panorama_name, @panorama_hue) unless @panorama_name.empty?
      Graphics.frame_reset
    end
    if @fog_name != $game_map.fog_name
      @fog_name = $game_map.fog_name
      @fog_hue = $game_map.fog_hue
      unless @fog.texture.nil?
        @fog.texture.dispose
        @fog.texture = nil
      end
      @fog.texture = RPG::Cache.fog(@fog_name, @fog_hue) unless @fog_name.empty?
      Graphics.frame_reset
    end
    @panorama.set_origin($game_map.display_x / 8, $game_map.display_y / 8)
    @fog.zoom = $game_map.fog_zoom / 100.0
    @fog.opacity = $game_map.fog_opacity.to_i
    @fog.blend_type = $game_map.fog_blend_type
    @fog.set_origin(($game_map.display_x / 8 + $game_map.fog_ox) / 2, ($game_map.display_y / 8 + $game_map.fog_oy) / 2)
    @fog.tone = $game_map.fog_tone
  end
  # create the zone panel of the current zone
  # @param zone [Integer, nil] the id of the zone where the player is
  def create_panel(zone)
    return unless zone && data_zone(zone).panel_id > 0
    @map_panel = UI::MapPanel.new(@viewport2, data_zone(zone))
  end
  Hooks.register(self, :finish_init, 'Zone Panel') { |method_binding| create_panel(method_binding[:zone]) }
  # Dispose the zone panel
  def dispose_sp_map
    @map_panel&.dispose
    @map_panel = nil
  end
  Hooks.register(self, :reload, 'Zone Panel') {dispose_sp_map }
  Hooks.register(self, :dispose, 'Zone Panel') {dispose_sp_map }
  # Update the zone panel
  def update_panel
    return unless @map_panel
    @map_panel.update
    dispose_sp_map if @map_panel.done?
  end
  Hooks.register(self, :update, 'Zone Panel') {update_panel }
  # Change the visible state of the Spriteset
  # @param value [Boolean] the new visibility state
  def visible=(value)
    @map_panel&.visible = value
    @viewport1.visible = value
    @viewport2.visible = value
    @viewport3.visible = value
  end
  # Return the map viewport
  # @return [Viewport]
  def map_viewport
    return @viewport1
  end
  # Add a new quest informer
  # @param name [String] Name of the quest
  # @param is_new [Boolean] if the quest is new
  def inform_quest(name, is_new)
    @quest_informers << UI::QuestInformer.new(@viewport2, name, is_new, @quest_informers.size)
  end
  private
  # Take a snapshot of the map
  # @return [Sprite] the snapshot ready to be used
  def take_map_snapshot
    sp = Sprite.new(@viewport3)
    rc = @viewport3.rect
    sp.z = 10 ** 6
    sp.bitmap = $scene.snap_to_bitmap
    sp.set_position(rc.width / 2, rc.height / 2)
    sp.set_origin(sp.width / 2, sp.height / 2)
    sp.zoom = rc.width / sp.bitmap.width.to_f
    return sp
  end
  # Update the quest informer
  def update_quest_informer
    @quest_informers.each do |informer|
      informer.update
      informer.dispose if informer.done?
    end
    @quest_informers.clear if @quest_informers.all?(&:done?)
  end
  Hooks.register(self, :update, 'Quest Informer') {update_quest_informer }
  Hooks.register(Spriteset_Map, :reload, 'Spriteset_Map reloaded') do
    if $game_map.fog_name == nil.to_s && $game_switches[Yuki::Sw::Env_CanFly] && $fog_info
      $game_map.fog_name = $fog_info[0]
      $game_map.fog_hue = $fog_info[1]
      $game_map.fog_opacity = $fog_info[2]
      $game_map.fog_blend_type = $fog_info[3]
      $game_map.fog_zoom = $fog_info[4]
      $game_map.fog_sx = $fog_info[5]
      $game_map.fog_sy = $fog_info[6]
    end
  end
end
module Yuki
  # Module that manage the particle display
  # @author Nuri Yuri
  module Particles
    module_function
    # Init the particle display on a new viewport
    # @param viewport [Viewport]
    def init(viewport)
      dispose if @stack && viewport != @viewport
      @clean_stack = false
      @stack ||= []
      @named = {}
      @viewport = viewport
      @on_teleportation = false
    end
    # Update of the particles & stack cleaning if requested
    def update
      return unless ready?
      return if Graphics::FPSBalancer.global.skipping?
      @stack.each do |i|
        i.update if i && !i.disposed
      end
      return unless @clean_stack
      @clean_stack = false
      @stack.delete_if(&:disposed)
    end
    # Request to clean the stack
    def clean_stack
      @clean_stack = true
    end
    # Add a particle to the stack
    # @param character [Game_Character] the character on which the particle displays
    # @param particle_tag [Integer, Symbol] identifier of the particle in the hash
    # @param params [Hash] additional params for the particle
    # @return [Particle_Object]
    def add_particle(character, particle_tag, params = {})
      return unless ready?
      return if character.character_name.empty?
      particle_data = find_particle(character.terrain_tag, particle_tag)
      return unless particle_data
      @stack.push(particle = Particle_Object.new(character, particle_data, @on_teleportation, params))
      return particle
    end
    # Add a named particle (particle that has a specific flow)
    # @param name [Symbol] name of the particle to prevent collision
    # @param character [Game_Character] the character on which the particle displays
    # @param particle_tag [Integer, Symbol] identifier of the particle in the hash
    # @param params [Hash] additional params for the particle
    def add_named_particle(name, character, particle_tag, params = {})
      return if @named[name] && !@named[name].disposed
      @named[name] = add_particle(character, particle_tag, params)
    end
    # Add a parallax
    # @param image [String] name of the image in Graphics/Pictures/
    # @param x [Integer] x coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
    # @param y [Integer] y coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
    # @param z [Integer] z superiority in the tile viewport
    # @param zoom_x [Numeric] zoom_x of the parallax
    # @param zoom_y [Numeric] zoom_y of the parallax
    # @param opacity [Integer] opacity of the parallax (0~255)
    # @param blend_type [Integer] blend_type of the parallax (0, 1, 2)
    # @return [Parallax_Object]
    def add_parallax(image, x, y, z, zoom_x = 1, zoom_y = 1, opacity = 255, blend_type = 0)
      object = Parallax_Object.new(image, x, y, z, zoom_x, zoom_y, opacity, blend_type)
      @stack << object
      return object
    end
    # Add a building
    # @param image [String] name of the image in Graphics/Autotiles/
    # @param x [Integer] x coordinate of the building
    # @param y [Integer] y coordinate of the building
    # @param oy [Integer] offset y coordinate of the building in native resolution pixel
    # @param visible_from1 [Symbol, false] data parameter (unused there)
    # @param visible_from2 [Symbol, false] data parameter (unused there)
    # @return [Building_Object]
    def add_building(image, x, y, oy = 0, visible_from1 = false, visible_from2 = false)
      object = Building_Object.new(image, x, y, oy)
      @stack << object
      return object
    end
    # Return the viewport of in which the Particles are shown
    def viewport
      @viewport
    end
    # Tell if the system is ready to work
    # @return [Boolean]
    def ready?
      return @stack && !viewport.disposed?
    end
    # Tell the particle manager the game is warping the player. Particle will skip the :enter phase.
    # @param v [Boolean]
    def set_on_teleportation(v)
      @on_teleportation = v
    end
    # Dispose each particle
    def dispose
      return unless ready?
      @stack.each do |i|
        i.dispose if i && !i.disposed
      end
    ensure
      @stack = nil
    end
    class << self
      # Return the list of named particles
      # @return [Hash{ Symbol => Particle_Object }]
      attr_reader :named
    end
    public
    # The particle data
    Data = []
    # The empty actions
    EMPTY = {max_counter: 1, loop: false, data: []}
    module_function
    # Function that find the data for a particle according to the terrain_tag & the particle tag
    # @note This function will try $game_variables[Var::PAR_DatID] & 0 as terrain_tag if the particle_tag wasn't found
    # @param terrain_tag [Integer] terrain_tag in which the event is
    # @param particle_tag [Integer, Symbol] identifier of the particle in the hash
    def find_particle(terrain_tag, particle_tag)
      Data.dig(terrain_tag, particle_tag) || Data.dig($game_variables[Var::PAR_DatID], particle_tag) || Data.dig(0, particle_tag)
    end
    safe_code('Particle Data Loading') do
      remove_const :Data
      const_set :Data, load_data('Data/Animations/Particles.dat')
    end
  end
  class Particle_Object
    # List of action handler to know how to compute the current frame of the particle
    ACTION_HANDLERS = {}
    # Order of the particle handlers
    ACTION_HANDLERS_ORDER = []
    # Add a new action handler
    # @param name [Symbol] name of the action
    # @param before [Symbol, nil] tell to put this handler before another handler
    def self.add_handler(name, before = nil, &block)
      unless ACTION_HANDLERS_ORDER.include?(name)
        index = before ? ACTION_HANDLERS_ORDER.index(before) : nil
        index ||= ACTION_HANDLERS_ORDER.size
        ACTION_HANDLERS_ORDER.insert(index, name)
      end
      ACTION_HANDLERS[name] = block
    end
    add_handler(:state) { |data| @state = data }
    add_handler(:on_chara_move_end) { |data| execute_action(data) if @character.movable? }
    add_handler(:zoom) { |data| @sprite.zoom = data * 1 }
    add_handler(:file) do |data|
      @sprite.bitmap = RPG::Cache.particle(data)
      @ox = @sprite.bitmap.width / 2
      @oy = @sprite.bitmap.height
    end
    add_handler(:position) { |data| @position_type = data }
    add_handler(:angle) { |data| @sprite.angle = data }
    add_handler(:add_z) { |data| @add_z = data }
    add_handler(:oy_offset) { |data| @oy_off = data + @params.fetch(:oy_offset, 0) }
    add_handler(:ox_offset) { |data| @ox_off = data + @params.fetch(:ox_offset, 0) }
    add_handler(:opacity) { |data| @sprite.opacity = data }
    add_handler(:se_play) { |data| Audio.se_play(*data) }
    add_handler(:se_player_play) { |data| Audio.se_play(*data) if @character == $game_player }
    add_handler(:wait) { |data| @wait_count = data.to_i }
    add_handler(:chara) do |data|
      cw = @sprite.bitmap.width / 4
      ch = @sprite.bitmap.height / 4
      sx = @character.pattern * cw
      sy = (@character.direction - 2) / 2 * ch
      @sprite.src_rect.set(sx, sy, cw, ch)
      @ox = cw / 2
      @oy = ch / 2
    end
    add_handler(:rect) do |data|
      @sprite.src_rect.set(*data)
      @ox = data[2] / 2
      @oy = data[3]
    end
    # Zoom of a tile to adjust coordinate
    TILE_ZOOM = Configs.display.tilemap_settings.character_tile_zoom
    # if the particle is disposed
    # @return [Boolean]
    attr_reader :disposed
    # Create a particle object
    # @param character [Game_Character] the character on which the particle displays
    # @param data [Hash{Symbol => Hash}] the data of the particle
    #    field of the data hash :
    #       enter: the particle animation when character enter on the tile
    #       stay: the particle animation when character stay on the tile
    #       leave: the particle animation when character leave the tile
    #    field of the particle animation
    #       max_counter: the number of frame on the animation
    #       loop: Boolean # if the animation loops or not
    #       data: an Array of animation instructions (Hash)
    #    field of an animation instruction
    #       state: Symbol # the new state of the particle
    #       zoom: Numeric # the zoom of the particle
    #       position: Symbol # the position type of the particle (:center_pos, :character_pos)
    #       file: String # the filename of the particle in Graphics/Particles/
    #       angle: Numeric # the angle of the particle
    #       add_z: Integer # The z offset relatively to the character
    #       oy_offset: Integer # The offset in oy
    #       opacity: Integer # The opacity of the particle
    #       chara: Boolean # If the particle Texture is treaten like the Character bitmap
    #       rect: Array(Integer, Integer, Integer, Integer) # the parameter of the #set function of Rect (src_rect)
    # @param on_tp [Boolean] tells the particle to skip the :enter animation or not
    # @param params [Hash] additional params for the animation
    # @option params [Symbol] :flow define the kind of flow to use for the animation
    # @option params [Integer] :radius define the radius to use for the :update_radius_flow flow
    def initialize(character, data, on_tp = false, params = {})
      @character = character
      init_map_data(character)
      @x = character.x + @map_data.offset_x
      @y = character.y + @map_data.offset_y
      @z = character.z
      @sprite = ::Sprite.new(Particles.viewport)
      @data = data
      @counter = 0
      @position_type = :center_pos
      @state = (on_tp ? :stay : :enter)
      @state = params[:state] if params.key?(:state)
      init_zoom
      @ox = 0
      @oy = 0
      @oy_off = 0
      @ox_off = 0
      @wait_count = 0
      @params = params
      @flow = params[:flow] || :update_default_flow
    end
    # Update the particle animation
    def update
      return if disposed?
      return dispose unless @map_linker.map_datas.include?(@map_data)
      if @wait_count > 0
        @wait_count -= 1
        return update_sprite_position
      end
      update_particle_info(@data[@state]) && update_sprite_position
    end
    # Get the real x of the particle on the map
    # @return [Integer]
    def x
      return @x - @map_data.offset_x
    end
    # Get the real y of the particle on the map
    # @return [Integer]
    def y
      return @y - @map_data.offset_y
    end
    # Update the particle info
    # @param data [Hash] the data related to the current state
    # @return [Boolean] if the update_sprite_position can be done
    def update_particle_info(data)
      if @counter < data[:max_counter]
        (action = data[:data][@counter]) && exectute_action(action)
        @counter += 1
      else
        if send(@flow, data)
          return true
        else
          if !data[:loop]
            dispose
            return false
          else
            @counter = 0
          end
        end
      end
      return true
    end
    # Update the default particle state flow
    # @param data [Hash] the data related to the current state
    # @return [Boolean]
    def update_default_flow(data)
      if @state == :enter
        @state = :stay
        @counter = 0
      else
        if @state == :stay
          @state = :leave if x != @character.x || y != @character.y
          @counter = 0
        else
          return false
        end
      end
      return true
    end
    # Update the radius particle kind flow
    # @param data [Hash] the data related to the current state
    # @return [Boolean]
    def update_radius_flow(data)
      radius = Math.sqrt(($game_player.x - @character.x) ** 2 + ($game_player.y - @character.y) ** 2)
      if @state == :enter
        @state = :stay
        @counter = 0
      else
        if @state == :stay
          return false if @map_data.map_id != $game_map.map_id
          if radius > @params[:radius]
            @state = :leave
            @counter = 0
          end
        else
          if @state == :leave
            return false if @map_data.map_id != $game_map.map_id
            if (@sprite.visible = (radius <= @params[:radius]))
              @state = :enter
              @counter = 0
            end
          else
            return false
          end
        end
      end
      return true
    end
    # Execute an animation instruction
    # @param action [Hash] the animation instruction
    def exectute_action(action)
      ACTION_HANDLERS_ORDER.each do |name|
        if (data = action[name])
          instance_exec(data, &ACTION_HANDLERS[name])
        end
      end
    end
    # Update the position of the particle sprite
    def update_sprite_position
      case @position_type
      when :center_pos, :grass_pos
        @sprite.x = (((x * 128 - $game_map.display_x + 3) / 4 + 16) * @tile_zoom).floor
        @sprite.y = ((y * 128 - $game_map.display_y + 3) / 4 + 32)
        if @position_type == :center_pos || @sprite.y >= @character.screen_y
          @sprite.z = (screen_z + @add_z)
        else
          @sprite.z = (screen_z - 1)
        end
        @sprite.y = (@sprite.y * @tile_zoom).floor
        @sprite.ox = @ox + @ox_off
        @sprite.oy = @oy + @oy_off
      when :character_pos
        @sprite.x = @character.screen_x * @tile_zoom
        @sprite.y = @character.screen_y * @tile_zoom
        @sprite.z = (@character.screen_z(0) + @add_z)
        @sprite.ox = @ox + @ox_off
        @sprite.oy = @oy + @oy_off
      end
    end
    # Function that process screen z depending on original screen_y (without zoom)
    def screen_z
      (y * 128 - $game_map.display_y + 3) / 4 + 32 * @z + 31
    end
    # Dispose the particle
    def dispose
      return if disposed?
      @sprite.dispose unless @sprite.disposed?
      @sprite = nil
      @disposed = true
      Yuki::Particles.clean_stack
    end
    alias disposed? disposed
    private
    # Init the map_data info for the particle
    # @param character [Game_Event, Game_Character, Game_Player]
    def init_map_data(character)
      map_id = character.original_map if character.is_a?(Game_Event)
      map_id ||= $game_map.map_id
      @map_linker = MapLinker
      @map_data = @map_linker.map_datas.find { |data| data.map_id == map_id } || @map_linker.map_datas.first
    end
    # Initialize the zoom info
    def init_zoom
      @tile_zoom = TILE_ZOOM
      @add_z = (1 / @tile_zoom).floor
    end
  end
  # Object that describe a parallax as a particle
  # @author Nuri Yuri
  class Parallax_Object
    # If the parallax is disposed
    # @return [Boolean]
    attr_reader :disposed
    # The parallax sprite
    # @return [Sprite]
    attr_accessor :sprite
    # the factor that creates an automatic offset in x
    # @return [Numeric]
    attr_accessor :factor_x
    # the factor that creates an automatic offset in y
    # @return [Numeric]
    attr_accessor :factor_y
    # Creates a new Parallax_Object
    # @param image [String] name of the image in Graphics/Pictures/
    # @param x [Integer] x coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
    # @param y [Integer] y coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
    # @param z [Integer] z superiority in the tile viewport
    # @param zoom_x [Numeric] zoom_x of the parallax
    # @param zoom_y [Numeric] zoom_y of the parallax
    # @param opacity [Integer] opacity of the parallax (0~255)
    # @param blend_type [Integer] blend_type of the parallax (0, 1, 2)
    def initialize(image, x, y, z, zoom_x = 1, zoom_y = 1, opacity = 255, blend_type = 0)
      @sprite = ::Sprite.new(Particles.viewport, true)
      @sprite.z = z
      @sprite.zoom_x = zoom_x
      @sprite.zoom_y = zoom_y
      @sprite.opacity = opacity
      @sprite.blend_type = blend_type
      @sprite.bitmap = ::RPG::Cache.picture(image)
      @x = x + MapLinker.get_OffsetX * 16
      @y = y + MapLinker.get_OffsetY * 16
      @factor_x = 0
      @factor_y = 0
      @map_id = $game_map.map_id
      update
    end
    # Update the parallax position
    def update
      return if disposed?
      return dispose if @map_id != $game_map.map_id
      dx = $game_map.display_x / 8
      dy = $game_map.display_y / 8
      @sprite.x = (@x - dx) + (@factor_x * dx)
      @sprite.y = (@y - dy) + (@factor_y * dy)
    end
    # Dispose the parallax
    def dispose
      return if disposed?
      @sprite.dispose unless @sprite.disposed?
      @sprite = nil
      @disposed = true
      Yuki::Particles.clean_stack
    end
    alias disposed? disposed
  end
  # Object that describe a building on the Map as a Particle
  # @author Nuri Yuri
  class Building_Object
    # If the building is disposed
    # @return [Boolean]
    attr_reader :disposed
    # The building sprite
    # @return [Sprite]
    attr_accessor :sprite
    # Create a new Building_Object
    # @param image [String] name of the image in Graphics/Autotiles/
    # @param x [Integer] x coordinate of the building
    # @param y [Integer] y coordinate of the building
    # @param oy [Integer] offset y coordinate of the building in native resolution pixel
    def initialize(image, x, y, oy)
      @sprite = ::Sprite.new(Particles.viewport, true)
      @sprite.bitmap = ::RPG::Cache.autotile(image)
      @sprite.oy = @sprite.bitmap.height - oy - 16
      @x = (x + MapLinker.get_OffsetX) * 16
      @y = (y + MapLinker.get_OffsetY) * 16
      @real_y = (y + MapLinker.get_OffsetY) * 128
      @map_id = $game_map.map_id
      update
    end
    # Update the building position (x, y, z)
    def update
      return if disposed?
      return dispose if @map_id != $game_map.map_id
      dx = $game_map.display_x / 8
      dy = $game_map.display_y / 8
      @sprite.x = (@x - dx)
      @sprite.y = (@y - dy)
      @sprite.z = (@real_y - $game_map.display_y + 4) / 4 + 94
    end
    # Dispose the building
    def dispose
      return if disposed?
      @sprite.dispose unless @sprite.disposed?
      @sprite = nil
      @disposed = true
      Yuki::Particles.clean_stack
    end
    alias disposed? disposed
  end
  # MapLinker, script that emulate the links between maps. This script also display events.
  # @author Nuri Yuri
  module MapLinker
    # The offset in X until we see black borders
    OFFSET_X = Configs.display.tilemap_settings.map_linker_offset.x
    # The offset in Y until we seen black borders
    OFFSET_Y = Configs.display.tilemap_settings.map_linker_offset.y
    # The number of tiles the Maker has to let in common between each maps
    DELTA_MAKER = Configs.display.tilemap_settings.uses_old_map_linker ? 3 : 0
    # The default Map (black borders)
    DEFAULT_MAP = RPG::Map.new(20, 15)
    # The map filename format
    MAP_FORMAT = 'Data/Map%03d.rxdata'
    # List of link types for the link loading
    LINK_TYPES = %i[north east south west]
    class << self
      alias get_OffsetX void0
      alias get_OffsetY void0
      alias current_OffsetX void0
      alias current_OffsetY void0
      # Return the map datas
      # @return [Array<Yuki::Tilemap::MapData>]
      attr_reader :map_datas
      # Return the SpritesetMap object used to load the map
      # @return [Spriteset_Map]
      attr_accessor :spriteset
      # Get the added events
      # @return [Hash<Integer => Array<RPG::Event>>] Integer is map_id
      attr_reader :added_events
      # Test if the given event is from the center map or not
      # @param event [Game_Event] the event to test
      # @return [Boolean, nil]
      def from_center_map?(event)
        return !@added_events.key?(event.original_map)
      end
      # Reset the module when the RGSS resets itself
      def reset
        @link_data = nil
        @map_datas = []
        @last_events = nil
        @last_event_id = 0
        @added_events = {}
      end
      # Load a map and its linked map
      # @param map_id [Integer] the map ID
      # @return [RPG::Map] the map adjusted
      def load_map(map_id)
        Yuki::ElapsedTime.start(:maplinker)
        map_datas = load_current_map_datas(map_id)
        current_map = map_datas.first.map
        if (link_data = $game_switches[Sw::MapLinkerDisabled] ? nil : each_data_map_link.find { |map_link| map_link.map_id == map_id })
          load_map_data_from_link_data(link_data, map_datas, current_map)
        else
          reset
        end
        @map_datas = map_datas
        @added_events.delete(map_id)
        load_events
        Yuki::ElapsedTime.show(:maplinker, 'Loading the tileset & priority took')
        return current_map
      end
      # Function that loads the current map data
      # @param map_id [Integer]
      # @return [Array<Yuki::Tilemap::MapData>]
      def load_current_map_datas(map_id)
        map_datas.first&.map&.events = @last_events if @last_events
        map_datas = [@map_datas.find { |map| map.map_id == map_id } || Tilemap::MapData.new(load_map_data(map_id), map_id)]
        map_datas.first.load_position(map_datas.first.map, :self, 0)
        return map_datas
      end
      # Load the map_datas array from the link_data
      # @param link_data [Studio::MapLink]
      # @param map_datas [Array<Yuki::Tilemap::MapData>]
      # @param current_map [RPG::Map] map currently being loaded
      def load_map_data_from_link_data(link_data, map_datas, current_map)
        link_data.north_maps.each { |link| map_datas << load_map_data_from_link(link, :north, current_map) }
        link_data.east_maps.each { |link| map_datas << load_map_data_from_link(link, :east, current_map) }
        link_data.south_maps.each { |link| map_datas << load_map_data_from_link(link, :south, current_map) }
        link_data.west_maps.each { |link| map_datas << load_map_data_from_link(link, :west, current_map) }
      end
      # Load a map data from a link
      # @param link [Studio::MapLink::Link]
      # @param cardinal [:north, :south, :east, :west]
      # @param current_map [RPG::Map] map currently being loaded
      # @return [Tilemap::MapData]
      def load_map_data_from_link(link, cardinal, current_map)
        sub_map_id = link.map_id
        map_data = @map_datas.find { |map| map.map_id == sub_map_id } || Tilemap::MapData.new(load_map_data(sub_map_id), sub_map_id)
        map_data.load_position(current_map, cardinal, link.offset)
        return map_data
      end
      # Load the data of a map (with some optimizations)
      # @param map_id [Integer] the id of the Map
      # @return [RPG::Map]
      def load_map_data(map_id)
        return DEFAULT_MAP if map_id == 0
        return load_data(format(MAP_FORMAT, map_id))
      rescue StandardError
        return RPG::Map.new(20, 15)
      end
      # Return the current tileset name
      # @return [String]
      def tileset_name
        @map_datas.first.tileset_name
      end
      if Configs.display.tilemap_settings.uses_old_map_linker
        # Test if the player can warp between maps and warp him
        def test_warp
          x = $game_player.x
          y = $game_player.y
          if y <= 1
            y -= DELTA_MAKER
            return unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
            warp(target_map.map_id, x + target_map.offset_x, target_map.map.height - $game_player.y - 1)
          else
            if x >= (@map_datas.first.map.width - 1)
              x += DELTA_MAKER
              return unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
              warp(target_map.map_id, 2, y + target_map.offset_y)
            else
              if y >= (@map_datas.first.map.height - 1)
                y += DELTA_MAKER
                return unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
                warp(target_map.map_id, x + target_map.offset_x, 2)
              else
                if x <= 1
                  x -= DELTA_MAKER
                  return unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
                  warp(target_map.map_id, target_map.map.width - $game_player.x - 1, y + target_map.offset_y)
                end
              end
            end
          end
        end
      else
        # Test if the player can warp between maps and warp him
        def test_warp
          x = $game_player.x
          y = $game_player.y
          return if $game_map.valid?(x, y)
          target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) }
          warp(target_map.map_id, x + target_map.offset_x, y + target_map.offset_y) if target_map
        end
      end
      # Test if a tile is passable
      # @param x [Integer] x coordinate of the tile on the map
      # @param y [Integer] y coordinate of the tile on the map
      # @param d [Integer] direction to check
      # @param event [Game_Character]
      def passable?(x, y, d = 0, event = $game_player)
        return false unless !event || event.passage_surf_check?(system_tag(x, y))
        return false unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
        tileset = $data_tilesets[target_map.map.tileset_id]
        passages = tileset.passages
        priorities = tileset.priorities
        bit = (1 << (d / 2 - 1)) & 0x0f
        data = target_map.map.data
        x += target_map.offset_x
        y += target_map.offset_y
        2.downto(0) do |i|
          tile_id = data[x, y, i]
          return false if tile_id.nil?
          return false if passages[tile_id] & bit != 0
          return false if passages[tile_id] & 0x0f == 0x0f
          return true if priorities[tile_id] == 0
        end
        return true
      end
      # Retrieve the ID of the SystemTag on a specific tile
      # @param x [Integer] x position of the tile
      # @param y [Integer] y position of the tile
      # @return [Integer]
      # @author Nuri Yuri
      def system_tag(x, y)
        return 0 unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
        return 0 unless (system_tags = $data_system_tags[target_map.map.tileset_id])
        tiles = target_map.map.data
        x += target_map.offset_x
        y += target_map.offset_y
        2.downto(0) do |i|
          tile_id = tiles[x, y, i]
          return 0 unless tile_id
          tag_id = system_tags[tile_id]
          return tag_id if tag_id && tag_id > 0
        end
        return 0
      end
      # Check if a specific SystemTag is present on a specific tile
      # @param x [Integer] x position of the tile
      # @param y [Integer] y position of the tile
      # @param tag [Integer] ID of the SystemTag
      # @return [Boolean]
      # @author Nuri Yuri
      def system_tag_here?(x, y, tag)
        return false unless (target_map = @map_datas.find { |map| map.x_range.include?(x) && map.y_range.include?(y) })
        return false unless (system_tags = $data_system_tags[target_map.map.tileset_id])
        tiles = target_map.map.data
        x += target_map.offset_x
        y += target_map.offset_y
        return 2.downto(0).any? do |i|
          (tile_id = tiles[x, y, i]) && system_tags[tile_id] == tag
        end
      end
      private
      # Load the visible events for all maps
      def load_events
        @last_events = @map_datas.first.map.events.clone
        @last_event_id = 1000 + @last_events.size
        @map_datas.each do |map|
          next if map.side == :self
          load_events_loop(map)
        end
      end
      # Load the visible event of a map
      # @param map [Yuki::Tilemap::MapData]
      def load_events_loop(map)
        map_id = map.map_id
        events = @map_datas.first.map.events
        ox = -map.offset_x
        oy = -map.offset_y
        if map.side == :north
          min = map.map.height - OFFSET_Y - 2
          max = map.map.height - DELTA_MAKER - 1
          @last_event_id = ajust_events(map.map, min, max, ox, oy, @last_event_id, events, map_id, :y)
        else
          if map.side == :south
            @last_event_id = ajust_events(map.map, DELTA_MAKER, OFFSET_Y + 1, ox, oy, @last_event_id, events, map_id, :y)
          else
            if map.side == :east
              @last_event_id = ajust_events(map.map, DELTA_MAKER, OFFSET_X + 1, ox, oy, @last_event_id, events, map_id, :x)
            else
              min = map.map.width - OFFSET_X - 2
              max = map.map.width - DELTA_MAKER - 1
              @last_event_id = ajust_events(map.map, min, max, ox, oy, @last_event_id, events, map_id, :x)
            end
          end
        end
      end
      # Adjust the event position and id. Move them on the current map
      # @param data [RPG::Map] the map where the event normally are
      # @param min [Integer] the min position where the event can be to be cloned
      # @param max [Integer] the max position where the event can be to be cloned
      # @param ox [Integer] the offset x of the event
      # @param oy [Integer] the offset y of the event
      # @param last_event_id [Integer] the last event id
      # @param events [Hash] the event hash of the current map
      # @param map_id [Integer] the map id of the event
      # @param type [Symbol] the property checked on the event to check if they're cloned or not
      # @return [Integer] the new last_event_id
      def ajust_events(data, min, max, ox, oy, last_event_id, events, map_id, type = :x)
        added_events = @added_events[map_id] = []
        nevent = nil
        env = $env
        data.events.each do |id, event|
          next unless event.send(type).between?(min, max)
          next if env.get_event_delete_state(id, map_id)
          events[last_event_id += 1] = nevent = event.clone
          nevent.x += ox
          nevent.y += oy
          nevent.id = last_event_id
          nevent.original_id = id
          nevent.original_map = map_id
          nevent.offset_x = ox
          nevent.offset_y = oy
          added_events << nevent
        end
        return last_event_id
      end
      # Warp a player to a new map and a new location
      # @param map_id [Integer] the ID of the new map
      # @param x [Integer] the new x position of the player
      # @param y [Integer] the new y position of the player
      def warp(map_id, x, y)
        return if map_id == 0
        $game_temp.player_transferring = true
        $game_temp.player_new_map_id = map_id
        $game_temp.player_new_x = x
        $game_temp.player_new_y = y
        $game_temp.player_new_direction = $game_player.direction
      end
    end
  end
  module FollowMe
    module_function
    # Tell if the system is enabled or not
    # @return [Boolean]
    def enabled
      $game_switches[Sw::FM_Enabled]
    end
    # Enable or disabled the system
    # @param state [Boolean] new enabled state
    def enabled=(state)
      $game_switches[Sw::FM_Enabled] = state
    end
    # Get the current selected follower (to move using player moveroutes)
    # @return [Integer] 0 = no follower selected
    def selected_follower
      $game_variables[Var::FM_Sel_Foll]
    end
    # Set the selected follower
    # @param index1 [Integer] index of the follower in the follower stack starting at index 1
    def selected_follower=(index1)
      $game_variables[Var::FM_Sel_Foll] = index1.clamp(0, @followers.size)
    end
    # Get the number of human following the player (Heroes from 2 to n+1)
    # @return [Integer]
    def human_count
      $game_variables[Var::FM_N_Human]
    end
    # Set the number of human following the player
    # @param count [Integer] number of human
    def human_count=(count)
      $game_variables[Var::FM_N_Human] = count
    end
    # Get the number of pokemon following the player
    # @return [Integer]
    def pokemon_count
      $game_variables[Var::FM_N_Pokem]
    end
    # Set the number of pokemon following the player
    # @param count [Integer]
    def pokemon_count=(count)
      $game_variables[Var::FM_N_Pokem] = count
    end
    # Get the number of Pokemon from "other_party" following the player
    # @return [Integer]
    def other_pokemon_count
      $game_variables[Var::FM_N_Friend]
    end
    # Set the number of Pokemon from "other_party" following the player
    # @param count [Integer]
    def other_pokemon_count=(count)
      $game_variables[Var::FM_N_Friend] = count
    end
    # Is the FollowMe in Let's Go Mode
    # @return [Boolean]
    def in_lets_go_mode?
      $game_switches[Sw::FollowMe_LetsGoMode]
    end
    # Set the FollowMe Let's Go Mode state
    # @param mode [Boolean] true if in lets go mode
    def lets_go_mode=(mode)
      $game_switches[Sw::FollowMe_LetsGoMode] = mode
    end
    public
    @followers = []
    module_function
    # Init the FollowMe on a new viewport. Previous Follower are disposed.
    # @param viewport [Viewport] the new viewport
    def init(viewport)
      dispose if @followers
      @viewport = viewport
      @followers = []
      fix_follower_event
    end
    # Remove event follower from player when the FollowMe gets re-initialized
    def fix_follower_event
      last_follower = $game_player
      last_follower = last_follower.follower while last_follower.follower && last_follower.class != Game_Event
      $game_player.set_follower(last_follower, true) if last_follower.is_a?(Game_Event)
    end
    # Update of the Follower Management. Their graphics are updated here.
    def update
      entities = follower_entities
      return clear unless enabled
      last_follower = $game_player
      follower_event = @followers.find { |follower| follower.character.follower.is_a?(Game_Event) }&.character&.follower
      follower_event ||= last_follower.follower if last_follower.follower.is_a?(Game_Event)
      chara_update = selected_follower == 0
      last_follower.set_follower(nil, true)
      @followers.each { |follower| follower.character.set_follower(nil) }
      entities.each_with_index do |entity, index|
        last_follower = update_follower(last_follower, index, entity, chara_update)
      end
      @followers.pop&.dispose while @followers.size > entities.size
      update_follower_event(last_follower, follower_event)
    end
    # Function that attempts to set the event as last follower
    # @param last_follower [Game_Character]
    # @param follower_event [Game_Event]
    def update_follower_event(last_follower, follower_event)
      if $game_player.follower != follower_event
        $game_player.set_follower(follower_event, true)
        $game_player.follower_tail.set_follower(@followers.first.character) if @followers.first
        @followers.last&.character&.set_follower(nil)
      end
    end
    # Get the follower entities (those giving information about character_name)
    # @return [Array<#character_name>]
    def follower_entities
      player_pokemon = in_lets_go_mode? ? player_pokemon_lets_go_entity : player_pokemon_entities
      return human_entities.concat(player_pokemon).concat(other_pokemon_entities)
    end
    # Get the human follower entities
    # @return [Array<#character_name>]
    def human_entities
      human = (0...human_count).map { |i| $game_actors[i + 2] }
      human.compact!
      return human
    end
    # Get the player's pokemon follower entities
    # @return [Array<#character_name>]
    def player_pokemon_entities
      player_mon = (0...pokemon_count).map { |i| $actors[i] }
      player_mon.compact!
      player_mon.reject!(&:dead?)
      return player_mon
    end
    # Get the player's pokemon follower entity if the FollowMe mode is Let's Go
    # @return [Array<#character_name>]
    def player_pokemon_lets_go_entity
      follower = $storage.lets_go_follower
      return [] unless follower && !follower.dead? && $actors.include?(follower)
      return [follower]
    end
    # Get the friend's pokemon follower entities
    # @return [Array<#character_name>]
    def other_pokemon_entities
      other_mon = (0...other_pokemon_count).map { |i| $storage.other_party[i] }
      other_mon.compact!
      other_mon.reject!(&:dead?)
      return other_mon
    end
    # Update of a single follower
    # @param last_follower [Game_Character] the last follower (in case of Follower creation)
    # @param i [Integer] index in the @followers Array
    # @param entity [PFM::Pokemon, Game_Actor] the entity that is shown as a follower
    # @param chara_update [Boolean] if the character graphics and informations needs to be updated
    # @return [Game_Character] the character that will become the last_follower
    def update_follower(last_follower, i, entity, chara_update)
      follower = @followers[i]
      unless follower
        @followers[i] = follower = Sprite_Character.new(@viewport, Game_Character.new)
        position_character(follower.character, i)
        follower.character.z = $game_player.z
      end
      character = follower.character
      last_follower.set_follower(character)
      if chara_update
        character.character_name = entity.character_name
        character.is_pokemon = character.step_anime = entity.class == PFM::Pokemon
      end
      character.move_speed = $game_player.original_move_speed
      character.through = true
      character.update
      follower.update
      follower.z -= 1 if character.x == $game_player.x && character.y == $game_player.y
      return (@followers[i] = follower).character
    end
    # Sets the default position of a follower
    # @param c [Game_Character] the character
    # @param i [Integer] the index of the caracter in the @followers Array
    def position_character(c, i)
      return if $game_variables[Yuki::Var::FM_Sel_Foll] > 0
      c1 = (i == 0 ? $game_player : @followers[i - 1].character)
      x = c1.x
      y = c1.y
      if $game_switches[Sw::Env_CanFly] || $game_switches[Sw::FM_NoReset]
        case c1.direction
        when 2
          y -= 1
        when 4
          x += 1
        when 6
          x -= 1
        else
          y += 1
        end
      end
      c.through = false
      if c.passable?(x, y, 0)
        c.moveto(x, y)
      else
        c.moveto(c1.x, c1.y)
      end
      c.through = true
      c.direction = $game_player.direction
      c.update
    end
    # Clears the follower (and dispose them)
    def clear
      return unless @followers
      @followers.each { |i| i&.dispose }
      @followers.clear
    end
    # Retrieve a follower
    # @param i [Integer] index of the follower in the @followers Array
    # @return [Game_Character] $game_player if i is invalid
    def get_follower(i)
      if @followers && @followers[i]
        return @followers[i].character
      end
      return $game_player
    end
    # yield a block on each Followers
    # @param block [Proc] the block to call
    # @example Turn each follower down
    #   Yuki::FollowMe.each_follower { |c| c.turn_down }
    def each_follower(&block)
      @followers&.collect(&:character)&.each(&block)
    end
    # Sets the position of each follower (Warp)
    # @param args [Array<Integer, Integer, Integer>] array of x, y, direction
    def set_positions(*args)
      x = y = 0
      (args.size / 3).times do |i|
        next unless (v = @followers[i])
        c = v.character
        x = args[i * 3]
        y = args[i * 3 + 1]
        c.moveto(x, y)
        c.direction = args[i * 3 + 2]
        c.update
        c.particle_push
        v.update
      end
    end
    # Reset position of each follower to the player (entering in a building)
    def reset_position
      return unless @followers
      $game_player.reset_follower_move
      @followers.size.times do |i|
        v = @followers[i]
        c = v.character
        x, y = $game_player.x, $game_player.y
        case $game_player.direction
        when 2
          y -= 1
        when 8
          y += 1
        when 4
          x += 1
        when 6
          x -= 1
        end
        x, y = $game_player.x, $game_player.y if !$game_map.passable?(x, y, $game_player.direction)
        c.moveto(x, y)
        c.direction = $game_player.direction
        c.instance_variable_set(:@memorized_move, nil)
        c.instance_variable_set(:@memorized_move_arg, nil)
        c.update
        v.update
        v.z -= 1
      end
    end
    # Test if a character is a Follower of the player
    # @param character [Game_Character]
    def is_player_follower?(character)
      return false unless @followers
      return @followers.any? { |follower_sprite| follower_sprite.character == character }
    end
    # Set the Follower Manager in Battle mode. When getting out of battle every character will get its particle pushed.
    def set_battle_entry(v = true)
      @was_fighting = v
    end
    # Push particle of each character if the Follower Manager was in Battle mode.
    def particle_push
      each_follower(&:particle_push) if @was_fighting
      @was_fighting = false
    end
    # Dispose the follower and release resources.
    def dispose
      @followers&.each { |i| i.dispose if i && !i.disposed? }
      @followers = nil
      @viewport = nil
    end
    # Smart disable the following system (keep it active when smart_enable is called)
    def smart_disable
      return unless $game_switches[Sw::FM_Enabled]
      $game_player.set_follower(nil, true)
      set_player_follower_particles(false)
      $game_switches[Sw::FM_WasEnabled] = $game_switches[Sw::FM_Enabled]
      $game_switches[Sw::FM_Enabled] = false
    end
    # Smart disable the following system (keep it active when smart_enable is called)
    def smart_enable
      set_player_follower_particles(true)
      $game_switches[Sw::FM_Enabled] = $game_switches[Sw::FM_WasEnabled]
    end
    # Enable / Disable the particles for the player followers
    def set_player_follower_particles(value)
      each_follower do |follower|
        follower.particles_disabled = !value
      end
    end
  end
  # Class responsive of displaying the map
  class Tilemap
    # Array telling how much layer each priority layer can show
    PRIORITY_LAYER_COUNT = [3, 2, 2, 1, 1, 1]
    # Get all the map data used by the tilemap
    # @return [Array<Yuki::Tilemap::MapData>]
    attr_reader :map_datas
    # Get the ox
    # @return [Integer]
    attr_accessor :ox
    # Get the oy
    # @return [Integer]
    attr_accessor :oy
    # Create a new Tilemap
    # @param viewport [Viewport]
    def initialize(viewport)
      @viewport = viewport
      create_sprites
      @disposed = false
      @map_datas = []
      @ox = 0
      @oy = 0
      @autotile_idle_count = Configs.display.tilemap_settings.autotile_idle_frame_count
      @autotile_counter = 0
      reset
    end
    # Reset the tilemap in order to force it to draw the frame
    def reset
      @last_x = @last_y = @last_ox = @last_oy = nil
    end
    # Update the tilemap
    def update
      return if @disposed
      return if Graphics::FPSBalancer.global.skipping?
      x = @ox / 32 - 1
      y = @oy / 32 - 1
      @autotile_counter += 1
      if x != @last_x || y != @last_y || (update_autotile = (@autotile_counter % @autotile_idle_count == 0))
        @map_datas.each(&:update_counters) if update_autotile
        draw(@last_x = x, @last_y = y)
        update_position(@ox % 32, @oy % 32)
      else
        if ox != @last_ox || oy != @last_oy
          update_position(@ox % 32, @oy % 32)
        end
      end
      @last_ox = @ox
      @last_oy = @oy
    end
    # Is the tilemap disposed
    # @return [Boolean]
    def disposed?
      return @disposed
    end
    # Set the map datas
    # @param map_datas [Array<Yuki::Tilemap::MapData>]
    def map_datas=(map_datas)
      @map_datas.clear
      @map_datas.concat(map_datas.select { |data| data.is_a?(MapData) })
      reset
    end
    # Dispose the tilemap
    def dispose
      return if @disposed
      @all_sprites.each(&:dispose)
      @all_sprites = nil
      @sprites = nil
      @disposed = true
    end
    private
    # Generate the sprites of the tilemap with the right settings
    # @param tile_size [Integer] the dimension of a tile
    # @param zoom [Numeric] the global zoom of a tile
    def create_sprites(tile_size = 32, zoom = 1)
      @zoom = zoom
      viewport = @viewport
      @all_sprites = []
      @sprites = []
      nx, ny = nx_ny_configs
      3.times do |z|
        priority_array = Array.new(6) do |priority|
          if PRIORITY_LAYER_COUNT[priority] > z
            priority_layer = Array.new(ny) do |y|
              sprite = SpriteMap.new(viewport, tile_size, nx)
              sprite.set_position(-tile_size, (y - 1) * tile_size)
              sprite.tile_scale = zoom
              sprite.z = 0
              @all_sprites << sprite
              next((sprite))
            end
            next((priority_layer))
          else
            next((adjust_sprite_layer(priority, PRIORITY_LAYER_COUNT[priority])))
          end
        end
        @sprites << priority_array
      end
      @nx = nx
      @ny = ny
    end
    # Adjust the sprites variable when the priority allow only two sprites => c3 c2 c3
    # @param priority [Integer] the current priority
    # @param count [Integer] the number of layer allowed for the priority
    # @return [Sprite_Map]
    def adjust_sprite_layer(priority, count)
      return @sprites.last[priority] if count != 2
      sprite_to_return = @sprites.last[priority]
      @sprites.last[priority] = @sprites.first[priority]
      @sprites.first[priority] = sprite_to_return
      return sprite_to_return
    end
    # Get the tilemap configuration for its size
    # @return [Array<Integer>]
    def nx_ny_configs
      return Configs.display.tilemap_settings.tilemap_size.x, Configs.display.tilemap_settings.tilemap_size.y
    end
    # Update the position of each tile according to the ox / oy, also adjusts z
    # @param ox [Integer] ox of every tiles
    # @param oy [Integer] oy of every tiles
    def update_position(ox, oy)
      ox = ((ox * @zoom).ceil / @zoom).to_i if @zoom < 1
      oy = ((oy * @zoom).ceil / @zoom).to_i if @zoom < 1
      add_z = oy / 2
      @sprites.each do |layer|
        layer.each_with_index do |priority_layer, priority|
          priority_layer.each_with_index do |sprite, py|
            sprite.set_origin(ox, oy)
            sprite.z = (py + priority) * 32 - add_z if priority > 0
          end
        end
      end
    end
    # Draw the tiles (suboptimal)
    # @param x [Integer] real world x of the top left tile
    # @param y [Integer] real world y of the top left tile
    def draw_suboptimal(x, y)
      @all_sprites.each(&:reset)
      maps = map_datas
      @sprites.each_with_index do |layer, tz|
        @ny.times do |ty|
          ry = ty + y
          @nx.times do |tx|
            rx = tx + x
            map = maps.find { |data| data.x_range.include?(rx) && data.y_range.include?(ry) }
            map&.draw(x, y, tx, ty, tz, layer)
          end
        end
      end
    end
    # Draw the tiles
    # @param x [Integer] real world x of the top left tile
    # @param y [Integer] real world y of the top left tile
    def draw(x, y)
      @all_sprites.each(&:reset)
      rx = x + @nx - 1
      ry = y + @ny - 1
      map_datas.each { |map| map.draw_map(x, y, rx, ry, @sprites) }
    end
    public
    # Class containing the map Data and its resources
    class MapData
      # List of method that help to load the position
      POSITION_LOADERS = {north: :load_position_north, south: :load_position_south, east: :load_position_east, west: :load_position_west, self: :load_position_self}
      # Get access to the original map data
      # @return [RPG::Map]
      attr_reader :map
      # Get the map id
      # @return [Integer]
      attr_reader :map_id
      # Get the map X coordinate range
      # @return [Range]
      attr_reader :x_range
      # Get the map Y coordinate range
      # @return [Range]
      attr_reader :y_range
      # Get the map offset_x
      # @return [Integer]
      attr_reader :offset_x
      # Get the map offset_y
      # @return [Integer]
      attr_reader :offset_y
      # Get the tileset filename (to prevent unwanted dispose in the future)
      # @return [String]
      attr_reader :tileset_name
      # Get the side of the map
      # @return [Symbol]
      attr_reader :side
      @tileset_chunks = {}
      # Create a new MapData
      # @param map [RPG::Map]
      # @param map_id [Integer]
      def initialize(map, map_id)
        @data = map.data
        @map = map
        @map_id = map_id
        @rect = Rect.new(0, 0, 32, 32)
      end
      # Sets the position of the map in the 2D Space
      # @param map [RPG::Map] current map
      # @param side [Symbol] which side the map is (:north, :south, :east, :west)
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      def load_position(map, side, offset)
        maker_offset = MapLinker::DELTA_MAKER
        send(POSITION_LOADERS[side], map, offset, maker_offset)
        @side = side
      end
      # Get a tile from the map
      # @param x [Integer] real world x position
      # @param y [Integer] real world y position
      # @param z [Integer] z
      def [](x, y, z)
        @data[x + @offset_x, y + @offset_y, z]
      end
      # Set tile sprite to sprite
      # @param sprite [Sprite]
      # @param tile_id [Integer] ID of the tile the sprite wants
      def assign_tile_to_sprite(sprite, tile_id)
        tile_id -= 384
        sprite.bitmap = @tilesets[tile_id / 256]
        sprite.src_rect.set(tile_id % 8 * 32, (tile_id % 256) / 8 * 32, 32, 32)
      end
      # Draw the tile on the right layer
      # @param x [Integer] real world x of the top left tile
      # @param y [Integer] real world y of the top left tile
      # @param tx [Integer] x index of the tile to draw from top left tile (0)
      # @param ty [Integer] y index of the tile to draw from top left tile (0)
      # @param tz [Integer] z index of the tile to draw
      # @param layer [Array<Array<SpriteMap>>] layers of the tilemap .dig(priority, ty)
      def draw(x, y, tx, ty, tz, layer)
        tile_id = self[x + tx, y + ty, tz]
        return unless tile_id && tile_id != 0
        priority = @priorities[tile_id] || 0
        if tile_id < 384
          tileset = @autotiles[tile_id / 48 - 1]
          tileset && layer.dig(priority, ty).set(tx, tileset, @rect.set((tile_id % 48) * 32, @autotile_counter[tile_id / 48] * 32))
        else
          tile_id -= 384
          tileset = @tilesets[tile_id / 256]
          tileset && layer.dig(priority, ty).set(tx, tileset, @rect.set(tile_id % 8 * 32, (tile_id % 256) / 8 * 32))
        end
      end
      # Draw the visible part of the map
      # @param x [Integer] real world x of the top left tile
      # @param y [Integer] real world y of the top left tile
      # @param rx [Integer] real world x of the bottom right tile
      # @param ry [Integer] real world y of the bottom right tile
      # @param layers [Array<Array<Array<SpriteMap>>>] layers of the tilemap .dig(tz, priority, ty)
      def draw_map(x, y, rx, ry, layers)
        lx = x_range.min
        mx = x_range.max
        ly = y_range.min
        my = y_range.max
        bx = lx > x ? lx : x
        ex = mx > rx ? rx : mx
        by = ly > y ? ly : y
        ey = my > ry ? ry : my
        return unless bx <= ex && by <= ey
        bx.upto(ex) do |ax|
          by.upto(ey) do |ay|
            layers.each_with_index do |layer, tz|
              draw(x, y, ax - x, ay - y, tz, layer)
            end
          end
        end
      end
      # Load the tileset
      def load_tileset
        @tileset = $data_tilesets[@map.tileset_id]
        @priorities = @tileset.priorities
        load_tileset_graphics
      end
      # Update the autotiles counter (for tilemap)
      def update_counters
        @autotiles.each_with_index do |autotile, index|
          next unless autotile
          next if autotile.height <= 32
          frame_count = autotile.height / 32
          @autotile_counter[index + 1] = (@autotile_counter[index + 1] + 1) % frame_count
        end
      end
      private
      # Load the tileset graphics
      def load_tileset_graphics
        $game_temp.maplinker_map_id = @map_id
        $game_temp.tileset_temp = @tileset.tileset_name
        Scheduler.start(:on_getting_tileset_name)
        name = $game_temp.tileset_name || @tileset.tileset_name
        $game_temp.tileset_name = nil
        @tilesets = load_tileset_chunks(@tileset_name = name)
        @autotiles = @tileset.autotile_names.map { |aname| MapLinker.spriteset.load_autotile(aname) }
        @autotile_counter = Array.new(@autotiles.size + 1, 0)
      end
      # Load tileset chunks
      # @param name [Filename]
      # @return [Array<Texture>]
      def load_tileset_chunks(name)
        chunks = MapData.tileset_chunks[name]
        chunks&.compact!
        return chunks if chunks&.none?(&:disposed?)
        unless RPG::Cache.tileset_exist?(name)
          return (MapData.tileset_chunks[name] = [RPG::Cache.default_bitmap])
        end
        image = RPG::Cache.tileset_image(name)
        working_surface = Image.new(256, 1024)
        rect = Rect.new(256, 1024)
        chunks = (image.height / 1024.0).ceil.times.map do |i|
          height = ((i + 1) * 1024) > image.height ? image.height - (i * 1024) : 1024
          working_surface.blt!(0, 0, image, rect.set(0, i * 1024, 256, height))
          bmp = Texture.new(256, 1024)
          working_surface.copy_to_bitmap(bmp)
          next(bmp)
        end
        image.dispose
        working_surface.dispose
        return MapData.tileset_chunks[name] = chunks
      end
      # Load the position when map is on north
      # @param map [RPG::Map] current map
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      # @param maker_offset [Integer]
      def load_position_north(map, offset, maker_offset)
        @offset_x = -offset
        @offset_y = @map.height - maker_offset
        @x_range = offset...(offset + @map.width)
        @y_range = -@offset_y...0
      end
      # Load the position when map is on south
      # @param map [RPG::Map] current map
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      # @param maker_offset [Integer]
      def load_position_south(map, offset, maker_offset)
        @offset_x = -offset
        @offset_y = -map.height + maker_offset
        @x_range = offset...(offset + @map.width)
        @y_range = map.height...(map.height + @map.height - maker_offset)
      end
      # Load the position when map is on east
      # @param map [RPG::Map] current map
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      # @param maker_offset [Integer]
      def load_position_east(map, offset, maker_offset)
        @offset_x = -map.width + maker_offset
        @offset_y = -offset
        @x_range = map.width...(map.width + @map.width - maker_offset)
        @y_range = offset...(offset + @map.height)
      end
      # Load the position when map is on east
      # @param map [RPG::Map] current map
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      # @param maker_offset [Integer]
      def load_position_west(map, offset, maker_offset)
        @offset_x = @map.width - maker_offset
        @offset_y = -offset
        @x_range = -@offset_x...0
        @y_range = offset...(offset + @map.height)
      end
      # Load the position when map is the current one
      # @param map [RPG::Map] current map
      # @param offset [Integer] offset relative to the side of the map in the positive perpendicular position
      # @param maker_offset [Integer]
      def load_position_self(map, offset, maker_offset)
        @offset_x = 0
        @offset_y = 0
        @x_range = 0...map.width
        @y_range = 0...map.height
      end
      class << self
        # Get tileset chunks
        # @return [Hash{filename => Array<Texture>}]
        attr_reader :tileset_chunks
      end
    end
  end
  # Tilemap definition for tilemap rendered with 16x16 tiles (default)
  class Tilemap16px < Tilemap
    private
    # Generate the sprites of the tilemap with the right settings
    # @param tile_size [Integer] the dimension of a tile
    # @param zoom [Numeric] the global zoom of a tile
    def create_sprites(tile_size = 16, zoom = 0.5)
      super(tile_size, zoom)
    end
  end
end
Hooks.register(Spriteset_Map, :init_psdk_add, 'Yuki::Particles') do
  Yuki::Particles.init(@viewport1)
  Yuki::Particles.set_on_teleportation(true)
end
Hooks.register(Spriteset_Map, :init_player_end, 'Yuki::Particles') do
  Yuki::Particles.update
  Yuki::Particles.set_on_teleportation(false)
end
Hooks.register(Spriteset_Map, :update, 'Yuki::Particles') {Yuki::Particles.update }
Hooks.register(Spriteset_Map, :init_psdk_add, 'Yuki::FollowMe') {Yuki::FollowMe.init(@viewport1) }
Hooks.register(Spriteset_Map, :init_player_begin, 'Yuki::FollowMe') do
  Yuki::FollowMe.update
  Yuki::FollowMe.particle_push
end
Hooks.register(Spriteset_Map, :update_fps_balanced, 'Yuki::FollowMe') {Yuki::FollowMe.update }
# Class that describe and manipulate a Character (Player/Events)
class Game_Character
  include GameData::SystemTags
  # Id of the event in the map
  # @return [Integer]
  attr_reader :id
  # @return [Integer] X position of the event in the current map
  attr_accessor :x
  # @return [Integer] Y position of the event in the current map
  attr_accessor :y
  # @return [Integer] Z priority of the event
  attr_accessor :z
  # @return [Integer] "real" X position of the event, usually x * 128
  attr_reader :real_x
  # @return [Integer] "real" Y position of the event, usually y * 128
  attr_reader :real_y
  # @return [Integer] direction where the event is looking (2 = down, 6 = right, 4 = left, 8 = up)
  attr_accessor :direction
  # @return [Boolean] if the character is forced to move using a specific route
  attr_reader :move_route_forcing
  # @return [Boolean] if the character is traversable and it can walk through any tiles
  attr_accessor :through
  # @return [Integer] ID of the animation to play on the character
  attr_accessor :animation_id
  # @return [Integer] exponant of two added to the real_x/y when the event is moving
  attr_accessor :move_speed
  # @return [Game_Character, nil] the follower
  attr_reader :follower
  # @return [Boolean] if the character is sliding
  attr_reader :sliding
  # If the direction is fixed
  # @return [Boolean]
  attr_reader :direction_fix
  # If the character has reflection
  # @return [Boolean]
  attr_reader :reflection_enabled
  # Default initializer
  def initialize
    @id = 0
    @x = 0
    @y = 0
    @z = 1
    @real_x = 0
    @real_y = 0
    @tile_id = 0
    set_appearance(nil.to_s, 0)
    @opacity = 255
    @blend_type = 0
    @direction = 2
    @pattern = 0
    @move_route_forcing = false
    @through = false
    @animation_id = 0
    @transparent = false
    @original_direction = 2
    @original_pattern = 0
    @move_type = 0
    @move_speed = 4
    self.move_frequency = 6
    @move_route = nil
    @move_route_index = 0
    @original_move_route = nil
    @original_move_route_index = 0
    @walk_anime = true
    @step_anime = false
    @direction_fix = false
    @always_on_top = false
    @anime_count = 0
    @stop_count = 0
    @jump_count = 0
    @jump_peak = 0
    @wait_count = 0
    @slope_offset_y = 0
    @slope_y_modifier = 0
    @locked = false
    @prelock_direction = 0
    @surfing = false
    @sliding = false
    @sliding_parameter = nil
    @pattern_state = false
    @can_make_footprint = true
    @reflection_enabled = $game_player&.reflection_enabled
  end
  # Set the move_frequency (and define the max_stop_count value)
  # @param value [Numeric]
  def move_frequency=(value)
    @move_frequency = value
    @max_stop_count = (40 - value * 2) * (6 - value)
  end
  # Adjust the character position
  def straighten
    if @walk_anime || @step_anime
      @pattern = 0
      @pattern_state = false
    end
    @anime_count = 0
    @prelock_direction = 0
  end
  # Force the character to adopt a move route and save the original one
  # @param move_route [RPG::MoveRoute]
  def force_move_route(move_route)
    if @original_move_route.nil?
      @original_move_route = @move_route
      @original_move_route_index = @move_route_index
    end
    @move_route = move_route
    @move_route_index = 0
    @move_route_forcing = true
    @prelock_direction = 0
    @wait_count = 0
    move_type_custom
  end
  # Warps the character on the Map to specific coordinates.
  # Adjust the z position of the character.
  # @param x [Integer] new x position of the character
  # @param y [Integer] new y position of the character
  def moveto(x, y)
    @x = x
    @y = y
    @real_x = @x * 128
    @real_y = @y * 128
    @prelock_direction = 0
    if @follower
      @follower.moveto(x, y)
      @follower.direction = @direction
    end
    self.move_frequency = @move_frequency
    moveto_system_tag_manage
  end
  # Change the reflection of a Game_Character
  def reflection_enabled=(bool)
    @reflection_enabled = bool
  end
  private
  # Array used to detect if a character is on a bridge tile
  BRIDGE_TILES = [BridgeRL, BridgeUD]
  SLOPES_TILES = [SlopesL, SlopesR]
  # Manage the system_tag part of the moveto method
  def moveto_system_tag_manage(skip_bridges = false)
    sys_tag = system_tag
    unless skip_bridges
      if BRIDGE_TILES.include?(sys_tag)
        @z = $game_map.priorities[$game_map.get_tile(@x, @y)].to_i + 1
      else
        if ZTag.include?(sys_tag)
          @z = ZTag.index(sys_tag)
        else
          @z = 1
        end
      end
    end
    if SLOPES_TILES.include?(sys_tag)
      @slope_length = -1
      furthest_x = [@x, @x]
      [0, 2].each do |step_x|
        nx = @x
        ny = @y
        while $game_map.system_tag(nx, ny) == sys_tag
          furthest_x[step_x / 2] = nx
          nx += (step_x - 1)
          @slope_length += 1
        end
      end
      if sys_tag == SlopesR
        @slope_origin_x = furthest_x[0] * 128
      else
        @slope_origin_x = furthest_x[1] * 128
      end
      @slope_length *= -128
      update_slope_offset_y
    end
    particle_push
  end
  public
  # Return the x position of the sprite on the screen
  # @return [Integer]
  def screen_x
    return (@real_x - $game_map.display_x + 3) / 4 + 16
  end
  # Return the y position of the sprite on the screen
  # @return [Integer]
  def screen_y
    y = (@real_y - $game_map.display_y + 3) / 4 + 32
    y += @offset_screen_y if @offset_screen_y
    y += @slope_offset_y if @slope_offset_y
    if @jump_count >= @jump_peak
      n = @jump_count - @jump_peak
    else
      n = @jump_peak - @jump_count
    end
    return y - (@jump_peak * @jump_peak - n * n) / 2
  end
  # Return the x position of the shadow of the character on the screen
  # @return [Integer]
  def shadow_screen_x
    return (@real_x - $game_map.display_x + 3) / 4 + 16
  end
  # Return the y position of the shadow of the character on the screen
  # @return [Integer]
  def shadow_screen_y
    return (@real_y - $game_map.display_y + 3) / 4 + 34 + (@offset_shadow_screen_y || 0) + (@slope_offset_y || 0)
  end
  # Return the z superiority of the sprite of the character
  # @param _height [Integer] height of a frame of the character (ignored)
  # @return [Integer]
  def screen_z(_height = 0)
    return 999 if @always_on_top
    z = (@real_y - $game_map.display_y + 3) / 4 + 32 * @z
    return z + $game_map.priorities[@tile_id].to_i * 32 if @tile_id > 0
    return z + 31
  end
  # Define the function check_event_trigger_touch to prevent bugs
  def check_event_trigger_touch(*args)
  end
  # Check if the character is activate. Useful to make difference between event without active page and others.
  # @return [Boolean]
  def activated?
    true
  end
  public
  # SystemTags that trigger Surfing
  SurfTag = [TPond, TSea, RapidsL, RapidsR, RapidsU, RapidsD]
  # SystemTags that does not trigger leaving water
  SurfLTag = SurfTag + [BridgeUD, BridgeRL, RapidsL, RapidsR, RapidsU, RapidsD, AcroBikeRL, AcroBikeUD, WaterFall, JumpD, JumpL, JumpR, JumpU, TUnderWater]
  # Is the tile in front of the character passable ?
  # @param x [Integer] x position on the Map
  # @param y [Integer] y position on the Map
  # @param d [Integer] direction : 2, 4, 6, 8, 0. 0 = current position
  # @param skip_event [Boolean] if the function does not check events
  # @return [Boolean] if the front/current tile is passable
  def passable?(x, y, d, skip_event = false)
    new_x = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    new_y = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
    z = @z
    game_map = $game_map
    return false unless game_map.valid?(new_x, new_y) || instance_of?(Game_Character)
    if @through
      return true unless @sliding
      return true if $game_switches[::Yuki::Sw::ThroughEvent]
    end
    sys_tag = game_map.system_tag(new_x, new_y)
    return false unless passable_bridge_check?(x, y, d, new_x, new_y, z, game_map, sys_tag) && passage_surf_check?(sys_tag)
    return true if skip_event
    return false unless event_passable_check?(new_x, new_y, z, game_map)
    if $game_player.contact?(new_x, new_y, z)
      return false unless $game_player.through || @character_name.empty?
    end
    return false unless follower_check?(new_x, new_y, z)
    return true
  end
  # Check the bridge related passabilities
  # @param x [Integer] current x position
  # @param y [Integer] current y position
  # @param d [Integer] current direction
  # @param new_x [Integer] new x position
  # @param new_y [Integer] new y position
  # @param z [Integer] current z position
  # @param game_map [Game_Map] map object
  # @param sys_tag [Integer] current system_tag
  # @return [Boolean] if the tile is passable according to the bridge rules
  def passable_bridge_check?(x, y, d, new_x, new_y, z, game_map, sys_tag)
    bridge = @__bridge
    no_game_map = false
    if z > 1
      if bridge
        return false unless game_map.system_tag_here?(new_x, new_y, bridge[0]) || game_map.system_tag_here?(new_x, new_y, bridge[1]) || game_map.system_tag_here?(x, y, bridge[1])
      end
      case d
      when 2, 8
        no_game_map = true if sys_tag == BridgeUD
      when 4, 6
        no_game_map = true if sys_tag == BridgeRL
      end
    end
    return true if bridge || no_game_map
    return false unless game_map.passable?(x, y, d, self)
    return false unless game_map.passable?(new_x, new_y, 10 - d)
    return true
  end
  # Check the surf related passabilities
  # @param sys_tag [Integer] current system_tag
  # @return [Boolean] if the tile is passable according to the surf rules
  def passage_surf_check?(sys_tag)
    return false if !@surfing && SurfTag.include?(sys_tag)
    if @surfing
      return false unless SurfLTag.include?(sys_tag)
      return false if sys_tag == WaterFall
    end
    return true
  end
  # Check the passage related to events
  # @param new_x [Integer] new x position
  # @param new_y [Integer] new y position
  # @param z [Integer] current z position
  # @param game_map [Game_Map] map object
  # @return [Boolean] if the tile has no event that block the way
  def event_passable_check?(new_x, new_y, z, game_map)
    game_map.events.each_value do |event|
      next unless event.contact?(new_x, new_y, z)
      return false unless event.through
    end
    return true
  end
  # Check the passage related to events
  # @param new_x [Integer] new x position
  # @param new_y [Integer] new y position
  # @param z [Integer] current z position
  # @return [Boolean] if the tile has no event that block the way
  def follower_check?(new_x, new_y, z)
    unless Yuki::FollowMe.is_player_follower?(self) || self == $game_player
      Yuki::FollowMe.each_follower do |event|
        return false if event.contact?(new_x, new_y, z)
      end
    end
    return true
  end
  public
  # Update the Game_Character (manages movements and some animations)
  def update
    if jumping?
      update_jump
    else
      if moving?
        update_move
      else
        if @sliding
          update_sliding
        else
          update_stop
        end
      end
    end
    update_pattern
    return if @sliding
    return @wait_count -= 1 if @wait_count > 0
    return move_type_path if @path
    return move_type_custom if @move_route_forcing
    return if @starting || lock?
    return unless @stop_count > @max_stop_count
    case @move_type
    when 1
      move_type_random
    when 2
      move_type_toward_player
    when 3
      move_type_custom
    end
  end
  # Reset some attributes when using Fly
  def fly_reset_attributes
    @slope_offset_y = @slope_origin_x = @slope_length = nil
    @slope_y_modifier = 0
    @z = 1
    @__bridge = nil
    @state = :walking
    leave_surfing_state if @surfing
    @in_swamp = false
    leave_swamp_state if @state == :swamp
    return_to_previous_state
  end
  private
  # Update the pattern animation
  def update_pattern
    return if update_charset_animation
    return unless @anime_count > 18 - @move_speed * 2
    if (!@step_anime && @stop_count > 0) || @sliding
      @pattern = @original_pattern
      @pattern_state = false
    else
      if @is_pokemon
        @pattern = (@pattern + 1) % 4
      else
        if @step_anime
          @pattern = (@pattern + 1) % 4
        else
          @pattern += (@pattern_state ? -1 : 1)
        end
        @pattern_state = true if @pattern == 3
        @pattern_state = false if @pattern <= 1
      end
    end
    @anime_count = 0
  end
  # Update the pattern state
  def update_pattern_state
    @pattern_state = true if @pattern == 3
    @pattern_state = false if @pattern <= 1
  end
  # Update of the jump animation
  def update_jump
    @jump_count -= 1
    @real_x = ((@real_x * @jump_count + @x * 128) / (@jump_count + 1))
    @real_y = ((@real_y * @jump_count + @y * 128) / (@jump_count + 1))
    return if @jump_count > 0
    @pattern = 0
    Scheduler::EventTasks.trigger(:end_jump, self)
  end
  # Update of the move animation
  def update_move
    was_moving = moving?
    update_real_position
    update_slope_offset_y
    if @walk_anime
      @anime_count += 1.5
    else
      if @step_anime
        @anime_count += 1
      end
    end
    Scheduler::EventTasks.trigger(:end_step, self) if was_moving && !moving?
  end
  # Update the real_x/y positions
  def update_real_position
    distance = 2 ** move_speed
    @real_y = [@real_y + distance, @y * 128].min if @y * 128 > @real_y
    @real_x = [@real_x - distance, @x * 128].max if @x * 128 < @real_x
    @real_x = [@real_x + distance, @x * 128].min if @x * 128 > @real_x
    @real_y = [@real_y - distance, @y * 128].max if @y * 128 < @real_y
  end
  # Update the slope offset y if there is one
  def update_slope_offset_y
    @slope_offset_y = @slope_origin_x ? 32 * (@real_x - @slope_origin_x).abs / @slope_length : nil if @slope_origin_x
  end
  # Update no movement animation (triggers movement when staying on specific SystemTag)
  def update_stop
    if @step_anime
      @anime_count += 1
    else
      if @pattern != @original_pattern
        @anime_count += 1.5
      end
    end
    @stop_count += 1
    move_down if system_tag == MachBike && !($game_switches[::Yuki::Sw::EV_Bicycle] && @lastdir4 == 8)
  end
  # SystemTags that forces the Game_Character to move
  RapidsTag = [RapidsL, RapidsU, RapidsD, RapidsR]
  # System tag that force the player to move regardless if the system tag in front
  ROCKET_TAGS = [RocketL, RocketU, RocketD, RocketR, RocketRL, RocketRU, RocketRD, RocketRR]
  # List of translations for system tag movement
  SLIDE_TAG_TO_MOVEMENT = {TIce => :move_forward, RapidsL => :move_left, RapidsR => :move_right, RapidsU => :move_up, RapidsD => :move_down, RocketL => :move_left, RocketU => :move_up, RocketD => :move_down, RocketR => :move_right, RocketRL => :move_left, RocketRU => :move_up, RocketRD => :move_down, RocketRR => :move_right, MachBike => :move_down}
  # System tags that rotate the player
  ROTATING_SLIDING_TAGS = [RocketRL, RocketRU, RocketRD, RocketRR]
  # Update when the Game_Character slides
  def update_sliding
    return stop_slide unless can_slide?
    sys_tag = system_tag
    unless moving?
      direction = @direction
      movement = SLIDE_TAG_TO_MOVEMENT[sys_tag] || (ROCKET_TAGS.include?(@sliding_parameter) && SLIDE_TAG_TO_MOVEMENT[@sliding_parameter])
      send(*movement) if movement
      if RapidsTag.include?(sys_tag) && $game_switches[::Yuki::Sw::EV_TurnRapids] || ROTATING_SLIDING_TAGS.include?(@sliding_parameter)
        @direction = direction
        turn_left_90
      end
    end
    update_move
  end
  # Function that completely sto
  def stop_slide
    @sliding = false
    Scheduler::EventTasks.trigger(:end_slide, self)
  end
  # Function that tells if the character can slide
  # @return [Boolean]
  def can_slide?
    ROCKET_TAGS.include?(@sliding_parameter) || SlideTags.include?(sys_tag = system_tag) || sys_tag == MachBike
  end
  # Random movement (when Event is on "Move random")
  def move_type_random
    case rand(6)
    when 0..3
      move_random
    when 4
      move_forward
    when 5
      @stop_count = 0
    end
  end
  # Move toward player with some randomness
  def move_type_toward_player
    sx = @x - $game_player.x
    sy = @y - $game_player.y
    abs_sx = sx > 0 ? sx : -sx
    abs_sy = sy > 0 ? sy : -sy
    if abs_sx + abs_sy >= 20
      move_random
      return
    end
    case rand(6)
    when 0..3
      move_toward_player
    when 4
      move_random
    when 5
      move_forward
    end
  end
  # Move on a specified route
  def move_type_custom
    return unless movable?
    while @move_route_index < @move_route.list.size
      command = @move_route.list[@move_route_index]
      break if move_type_custon_exec_command(command)
    end
  end
  # Execute a move route command
  # @param command [RPG::MoveCommand]
  # @return [Boolean] if the loop calling the method should break
  def move_type_custon_exec_command(command)
    if command.code == 0
      move_type_custom_end
      return true
    end
    if command.code <= 14
      move_type_custom_move(command)
      return true
    end
    if command.code == 15
      @wait_count = command.parameters[0] * 2 - 1
      @move_route_index += 1
      return true
    end
    if command.code.between?(16, 26)
      move_type_custom_turn(command)
      return true
    end
    @move_type_custom_special_result = false
    move_type_custom_special(command)
    return @move_type_custom_special_result
  end
  # When the command is 0 we reached the end and we loop back if the repeat mode is on
  def move_type_custom_end
    if @move_route&.repeat
      @move_route_index = 0
    else
      if @move_route_forcing
        @move_route_forcing = false
        @move_route = @original_move_route
        @move_route_index = @original_move_route_index
        @original_move_route = nil
      end
      @stop_count = 0
    end
  end
  # When the command is a real move command
  # @param command [RPG::MoveCommand]
  def move_type_custom_move(command)
    case command.code
    when 1
      move_down
    when 2
      move_left
    when 3
      move_right
    when 4
      move_up
    when 5
      move_lower_left
    when 6
      move_lower_right
    when 7
      move_upper_left
    when 8
      move_upper_right
    when 9
      move_random
    when 10
      move_toward_player
    when 11
      move_away_from_player
    when 12
      move_forward
    when 13
      move_backward
    when 14
      jump(command.parameters[0], command.parameters[1])
    end
    move_type_custom_move_update_index
  end
  # Update the move_route_index if the character moved or can skip undoable route
  def move_type_custom_move_update_index
    return unless @move_route&.skippable || moving? || jumping?
    @move_route_index += 1
  end
  # When the move command is a turn command
  # @param command [RPG::MoveCommand]
  def move_type_custom_turn(command)
    case command.code
    when 16
      turn_down
    when 17
      turn_left
    when 18
      turn_right
    when 19
      turn_up
    when 20
      turn_right_90
    when 21
      turn_left_90
    when 22
      turn_180
    when 23
      turn_right_or_left_90
    when 24
      turn_random
    when 25
      turn_toward_player
    when 26
      turn_away_from_player
    end
    @move_route_index += 1
  end
  # When the move command is a special command
  # @param command [RPG::MoveCommand]
  def move_type_custom_special(command)
    case command.code
    when 27
      $game_switches[command.parameters[0]] = true
      $game_map.need_refresh = true
    when 28
      $game_switches[command.parameters[0]] = false
      $game_map.need_refresh = true
    when 29
      @move_speed = command.parameters[0]
    when 30
      self.move_frequency = command.parameters[0]
    when 31
      @walk_anime = true
    when 32
      @walk_anime = false
    when 33
      @step_anime = true
    when 34
      @step_anime = false
    when 35
      @direction_fix = true
    when 36
      @direction_fix = false
    when 37
      @through = true
    when 38
      @through = false
    when 39
      @always_on_top = true
    when 40
      @always_on_top = false
    when 41
      @tile_id = 0
      set_appearance(command.parameters[0], command.parameters[1])
      if @original_direction != command.parameters[2]
        @direction = command.parameters[2]
        @original_direction = @direction
        @prelock_direction = 0
      end
      if @original_pattern != command.parameters[3]
        @pattern = command.parameters[3]
        @original_pattern = @pattern
      end
    when 42
      @opacity = command.parameters[0]
    when 43
      @blend_type = command.parameters[0]
    when 44
      $game_system.se_play(command.parameters[0])
    when 45
      eval_script(command.parameters[0])
    end
    @move_route_index += 1
  end
  # Function that execute a script
  # @param script [String]
  def eval_script(script)
    last_eval = Yuki::EXC.get_eval_script
    script = script.force_encoding('UTF-8').gsub(/\n([(,])/, "\\1\n")
    Yuki::EXC.set_eval_script(script)
    eval(script)
  rescue StandardError => e
    Yuki::EXC.run(e)
  ensure
    Yuki::EXC.set_eval_script(last_eval)
  end
  public
  # Increase step prototype (sets @stop_count to 0)
  def increase_steps
    @stop_count = 0
  end
  # Process the slope y modifier
  def process_slope_y_modifier(y_modifier)
    @y += y_modifier
    @real_y = @y * 128
    update_slope_offset_y
  end
  public
  # Move Game_Character down
  # @param turn_enabled [Boolean] if the Game_Character turns when impossible move
  def move_down(turn_enabled = true)
    turn_down if turn_enabled
    if passable?(@x, @y, 2)
      if $game_map.system_tag(@x, @y + 1) == JumpD
        jump(0, 2, false)
        return follower_move
      end
      turn_down
      bridge_down_check(@z)
      @y += 1
      movement_process_end
      increase_steps
    else
      @sliding = false
      check_event_trigger_touch(@x, @y + 1)
    end
  end
  # Move Game_Character left
  # @param turn_enabled [Boolean] if the Game_Character turns when impossible move
  def move_left(turn_enabled = true)
    turn_left if turn_enabled
    return if stair_move_left
    y_modifier = slope_check_left
    if passable?(@x, @y + y_modifier, 4)
      if $game_map.system_tag(@x - 1, @y + y_modifier) == JumpL
        jump(-2, 0, false)
        return follower_move
      end
      turn_left
      bridge_left_check(@z)
      @x -= 1
      movement_process_end
      if y_modifier != 0
        @memorized_move = :move_toward
        @memorized_move_arg = [@x, @y]
        process_slope_y_modifier(y_modifier)
      end
      increase_steps
    else
      @sliding = false
      check_event_trigger_touch(@x - 1, @y + y_modifier)
    end
  end
  # Try to move the Game_Character on a stair to the left
  # @return [Boolean] if the player cannot perform a regular movement (success or blocked)
  def stair_move_left
    if front_system_tag == StairsL
      return true unless $game_map.system_tag(@x - 1, @y - 1) == StairsL
      move_upper_left
      return true
    else
      if system_tag == StairsR
        move_lower_left
        return true
      end
    end
    return false
  end
  # Update the slope values when moving to left
  def slope_check_left(write = true)
    front_sys_tag = front_system_tag
    return 0 unless (sys_tag = system_tag) == SlopesL || sys_tag == SlopesR || front_sys_tag == SlopesL || front_sys_tag == SlopesR
    if sys_tag != SlopesL && front_sys_tag == SlopesL
      if write
        @slope_length = 0
        nx = @x - 1
        ny = @y
        while $game_map.system_tag(nx, ny) == SlopesL
          nx -= 1
          @slope_length += 1
        end
        @slope_origin_x = @real_x
        @slope_length *= -128
      end
    else
      if sys_tag == SlopesL && front_sys_tag != SlopesL
        @slope_offset_y = @slope_origin_x = @slope_length = nil if passable?(@x, @y - 1, 4) && write
        return -1
      else
        if sys_tag != SlopesR && front_sys_tag == SlopesR
          return 1 unless passable?(@x, @y + 1, 4)
          if write
            @slope_length = 0
            nx = @x - 1
            ny = @y + 1
            while $game_map.system_tag(nx, ny) == SlopesR
              nx -= 1
              @slope_length += 1
            end
            @slope_origin_x = (nx + 1) * 128
            @slope_length *= -128
          end
          return 1
        else
          if sys_tag == SlopesR && front_sys_tag != SlopesR
            @slope_offset_y = @slope_origin_x = @slope_length = nil if write
          end
        end
      end
    end
    return 0
  end
  # Move Game_Character right
  # @param turn_enabled [Boolean] if the Game_Character turns when impossible move
  def move_right(turn_enabled = true)
    turn_right if turn_enabled
    return if stair_move_right
    y_modifier = slope_check_right
    if passable?(@x, @y + y_modifier, 6)
      if $game_map.system_tag(@x + 1, @y) == JumpR
        return (jump(2, 0, false) ? follower_move : nil)
      end
      turn_right
      bridge_right_check(@z)
      @x += 1
      movement_process_end
      if y_modifier != 0
        @memorized_move = :move_toward
        @memorized_move_arg = [@x, @y]
        process_slope_y_modifier(y_modifier)
      end
      increase_steps
    else
      @sliding = false
      check_event_trigger_touch(@x + 1, @y + y_modifier)
    end
  end
  # Try to move the Game_Character on a stair to the right
  # @return [Boolean] if the player cannot perform a regular movement (success or blocked)
  def stair_move_right
    if system_tag == StairsL
      move_lower_right
      return true
    else
      if front_system_tag == StairsR
        return true unless $game_map.system_tag(@x + 1, @y - 1) == StairsR
        move_upper_right
        return true
      end
    end
    return false
  end
  # Update the slope values when moving to right, and return y slope modifier
  # @return [Integer]
  def slope_check_right(write = true)
    front_sys_tag = front_system_tag
    return 0 unless (sys_tag = system_tag) == SlopesL || sys_tag == SlopesR || front_sys_tag == SlopesL || front_sys_tag == SlopesR
    if sys_tag != SlopesR && front_sys_tag == SlopesR
      if write
        @slope_length = 0
        nx = @x + 1
        ny = @y
        while $game_map.system_tag(nx, ny) == SlopesR
          nx += 1
          @slope_length += 1
        end
        @slope_origin_x = @real_x
        @slope_length *= -128
      end
    else
      if sys_tag == SlopesR && front_sys_tag != SlopesR
        @slope_offset_y = @slope_origin_x = @slope_length = nil if passable?(@x, @y - 1, 6) && write
        return -1
      else
        if sys_tag != SlopesL && front_sys_tag == SlopesL
          return 1 unless passable?(@x, @y + 1, 6)
          if write
            @slope_length = 0
            nx = @x + 1
            ny = @y + 1
            while $game_map.system_tag(nx, ny) == SlopesL
              nx += 1
              @slope_length += 1
            end
            @slope_origin_x = (nx - 1) * 128
            @slope_length *= -128
          end
          return 1
        else
          if sys_tag == SlopesL && front_sys_tag != SlopesL
            @slope_offset_y = @slope_origin_x = @slope_length = nil if write
          end
        end
      end
    end
    return 0
  end
  # Move Game_Character up
  # @param turn_enabled [Boolean] if the Game_Character turns when impossible move
  def move_up(turn_enabled = true)
    turn_up if turn_enabled
    if passable?(@x, @y, 8)
      if $game_map.system_tag(@x, @y - 1) == JumpU
        return (jump(0, -2, false) ? follower_move : nil)
      end
      turn_up
      bridge_up_check(@z)
      @y -= 1
      movement_process_end
      increase_steps
    else
      @sliding = false
      check_event_trigger_touch(@x, @y - 1)
    end
  end
  # Move the Game_Character lower left
  def move_lower_left
    unless @direction_fix
      @direction = (@direction == 6 ? 4 : @direction == 8 ? 2 : @direction)
    end
    if (passable?(@x, @y, 2) && passable?(@x, @y + 1, 4)) || (passable?(@x, @y, 4) && passable?(@x - 1, @y, 2))
      move_follower_to_character
      @x -= 1
      @y += 1
      if @follower && $game_variables[Yuki::Var::FM_Sel_Foll] == 0
        @memorized_move = :move_lower_left
        @memorized_move_arg = nil
        @follower.direction = @direction
      end
      movement_process_end(true)
      increase_steps
    end
  end
  # Move the Game_Character lower right
  def move_lower_right
    unless @direction_fix
      @direction = (@direction == 4 ? 6 : @direction == 8 ? 2 : @direction)
    end
    if (passable?(@x, @y, 2) && passable?(@x, @y + 1, 6)) || (passable?(@x, @y, 6) && passable?(@x + 1, @y, 2))
      move_follower_to_character
      @x += 1
      @y += 1
      if @follower && $game_variables[Yuki::Var::FM_Sel_Foll] == 0
        @memorized_move = :move_lower_right
        @memorized_move_arg = nil
        @follower.direction = @direction
      end
      movement_process_end(true)
      increase_steps
    end
  end
  # Move the Game_Character upper left
  def move_upper_left
    unless @direction_fix
      @direction = (@direction == 6 ? 4 : @direction == 2 ? 8 : @direction)
    end
    if (passable?(@x, @y, 8) && passable?(@x, @y - 1, 4)) || (passable?(@x, @y, 4) && passable?(@x - 1, @y, 8))
      move_follower_to_character
      @x -= 1
      @y -= 1
      if @follower && $game_variables[Yuki::Var::FM_Sel_Foll] == 0
        @memorized_move = :move_upper_left
        @memorized_move_arg = nil
        @follower.direction = @direction
      end
      movement_process_end(true)
      increase_steps
    end
  end
  # Move the Game_Character upper right
  def move_upper_right
    unless @direction_fix
      @direction = (@direction == 4 ? 6 : @direction == 2 ? 8 : @direction)
    end
    if (passable?(@x, @y, 8) && passable?(@x, @y - 1, 6)) || (passable?(@x, @y, 6) && passable?(@x + 1, @y, 8))
      move_follower_to_character
      @x += 1
      @y -= 1
      if @follower && $game_variables[Yuki::Var::FM_Sel_Foll] == 0
        @memorized_move = :move_upper_right
        @memorized_move_arg = nil
        @follower.direction = @direction
      end
      movement_process_end(true)
      increase_steps
    end
  end
  # Move the Game_Character to a random direction
  def move_random
    case rand(4)
    when 0
      move_down(false)
    when 1
      move_left(false)
    when 2
      move_right(false)
    when 3
      move_up(false)
    end
  end
  # Move the Game_Character to a random direction within a rectangular zone
  # @param lx [Integer] the x coordinate of the left border of the zone
  # @param rx [Integer] the x coordinate of the right border of the zone
  # @param ty [Integer] the y coordinate of the top border of the zone
  # @param dy [Integer] the y coordinate of the down border of the zone
  def move_random_within_zone(lx, rx, ty, dy)
    lx, rx = rx, lx if lx > rx
    ty, dy = dy, ty if ty > dy
    ox = ((lx + rx) / 2).floor
    oy = ((ty + dy) / 2).floor
    return move_toward(ox, oy) unless (lx..rx).include?(@x) && (ty..dy).include?(@y)
    case rand(4)
    when 0
      return if @y + 1 > dy
      move_down(false)
    when 1
      return if @x - 1 < lx
      move_left(false)
    when 2
      return if @x + 1 > rx
      move_right(false)
    when 3
      return if @y - 1 < ty
      move_up(false)
    end
  end
  # Move the Game_Character to a random direction within a rectangular zone
  # @param sys_tag_id [Integer] the ID of the systemtag the character should only move into
  def move_random_within_systemtag(sys_tag_id)
    return if system_tag != sys_tag_id
    case rand(4)
    when 0
      return if $game_map.system_tag(@x, @y + 1) != sys_tag_id
      move_down(false)
    when 1
      return if $game_map.system_tag(@x - 1, @y) != sys_tag_id
      move_left(false)
    when 2
      return if $game_map.system_tag(@x + 1, @y) != sys_tag_id
      move_right(false)
    when 3
      return if $game_map.system_tag(@x, @y - 1) != sys_tag_id
      move_up(false)
    end
  end
  # Move the Game_Character toward the player
  def move_toward_player
    sx = @x - $game_player.x
    sy = @y - $game_player.y
    return if sx == 0 && sy == 0
    abs_sx = sx.abs
    abs_sy = sy.abs
    if abs_sx == abs_sy
      rand(2) == 0 ? abs_sx += 1 : abs_sy += 1
    end
    if abs_sx > abs_sy
      sx > 0 ? move_left : move_right
      unless moving? || sy == 0
        sy > 0 ? move_up : move_down
      end
    else
      sy > 0 ? move_up : move_down
      unless moving? || sx == 0
        sx > 0 ? move_left : move_right
      end
    end
  end
  # Move the Game_Character away from the player
  def move_away_from_player
    sx = @x - $game_player.x
    sy = @y - $game_player.y
    return if sx == 0 && sy == 0
    abs_sx = sx.abs
    abs_sy = sy.abs
    if abs_sx == abs_sy
      rand(2) == 0 ? abs_sx += 1 : abs_sy += 1
    end
    if abs_sx > abs_sy
      sx > 0 ? move_right : move_left
      unless moving? || sy == 0
        sy > 0 ? move_down : move_up
      end
    else
      sy > 0 ? move_down : move_up
      unless moving? || sx == 0
        sx > 0 ? move_right : move_left
      end
    end
  end
  # Move the entity toward a specific coordinate
  def move_toward(tx, ty)
    sx = @x - tx
    sy = @y - ty
    return if sx == 0 && sy == 0
    abs_sx = sx.abs
    abs_sy = sy.abs
    if abs_sx == abs_sy
      rand(2) == 0 ? abs_sx += 1 : abs_sy += 1
    end
    if abs_sx > abs_sy
      sx > 0 ? move_left : move_right
      unless moving? || sy == 0
        sy > 0 ? move_up : move_down
      end
    else
      sy > 0 ? move_up : move_down
      unless moving? || sx == 0
        sx > 0 ? move_left : move_right
      end
    end
  end
  # Move the Game_Character forward
  def move_forward
    case @direction
    when 2
      move_down(false)
    when 4
      move_left(false)
    when 6
      move_right(false)
    when 8
      move_up(false)
    end
  end
  # Move the Game_Character backward
  def move_backward
    last_direction_fix = @direction_fix
    @direction_fix = true
    case @direction
    when 2
      move_up(false)
    when 4
      move_right(false)
    when 6
      move_left(false)
    when 8
      move_down(false)
    end
    @direction_fix = last_direction_fix
  end
  # Make the Game_Character jump
  # @param x_plus [Integer] the number of tile the Game_Character will jump on x
  # @param y_plus [Integer] the number of tile the Game_Character will jump on y
  # @param follow_move [Boolean] if the follower moves when the Game_Character starts jumping
  # @return [Boolean] if the character is jumping
  def jump(x_plus, y_plus, follow_move = true)
    jump_bridge_check(x_plus, y_plus)
    new_x = @x + x_plus
    new_y = @y + y_plus
    if (x_plus == 0 && y_plus == 0) || passable?(new_x, new_y, 0) || ($game_switches[::Yuki::Sw::EV_AccroBike] && front_system_tag == AcroBike)
      straighten
      @x = new_x
      @y = new_y
      distance = Math.sqrt(x_plus * x_plus + y_plus * y_plus).round
      @jump_peak = 10 + distance - @move_speed
      @jump_count = @jump_peak * 2
      @stop_count = 0
      @pattern = (rand(2) == 0 ? 1 : 3) unless follow_move
      movement_process_end(true)
      if follow_move && @follower && $game_variables[Yuki::Var::FM_Sel_Foll] == 0 && (x_plus != 0 || y_plus != 0)
        follower_move
        @memorized_move = :jump
        @memorized_move_arg = [x_plus, y_plus]
      end
    end
    particle_push
    return @jump_count > 0
  end
  # Perform the bridge check for the jump operation
  # @param x_plus [Integer] the number of tile the Game_Character will jump on x
  # @param y_plus [Integer] the number of tile the Game_Character will jump on y
  def jump_bridge_check(x_plus, y_plus)
    return if x_plus == 0 && y_plus == 0
    if x_plus.abs > y_plus.abs
      x_plus < 0 ? turn_left : turn_right
      bridge_left_check(@z)
    else
      y_plus < 0 ? turn_up : turn_down
      bridge_down_check(@z)
    end
  end
  # SystemTags that triggers "sliding" state
  SlideTags = [TIce, RapidsL, RapidsR, RapidsU, RapidsD, RocketL, RocketU, RocketD, RocketR, RocketRL, RocketRU, RocketRD, RocketRR]
  # End of the movement process
  # @param no_follower_move [Boolean] if the follower should not move
  # @author Nuri Yuri
  def movement_process_end(no_follower_move = false)
    follower_move unless no_follower_move
    particle_push
    if SlideTags.include?(sys_tag = system_tag) || (sys_tag == MachBike && !($game_switches[::Yuki::Sw::EV_Bicycle] && @lastdir4 == 8))
      @sliding = true
      @sliding_parameter = sys_tag
      Scheduler::EventTasks.trigger(:begin_slide, self)
    end
    z_bridge_check(sys_tag)
    detect_swamp
    if jumping?
      Scheduler::EventTasks.trigger(:begin_jump, self)
    else
      if moving?
        Scheduler::EventTasks.trigger(:begin_step, self)
      end
    end
  end
  public
  # Turn down unless direction fix
  def turn_down
    unless @direction_fix
      @direction = 2
      @stop_count = 0
    end
  end
  # Turn left unless direction fix
  def turn_left
    unless @direction_fix
      @direction = 4
      @stop_count = 0
    end
  end
  # Turn right unless direction fix
  def turn_right
    unless @direction_fix
      @direction = 6
      @stop_count = 0
    end
  end
  # Turn up unless direction fix
  def turn_up
    unless @direction_fix
      @direction = 8
      @stop_count = 0
    end
  end
  # Turn 90° to the right of the Game_Character
  def turn_right_90
    case @direction
    when 2
      turn_left
    when 4
      turn_up
    when 6
      turn_down
    when 8
      turn_right
    end
  end
  # Turn 90° to the left of the Game_Character
  def turn_left_90
    case @direction
    when 2
      turn_right
    when 4
      turn_down
    when 6
      turn_up
    when 8
      turn_left
    end
  end
  # Turn 180°
  def turn_180
    case @direction
    when 2
      turn_up
    when 4
      turn_right
    when 6
      turn_left
    when 8
      turn_down
    end
  end
  # Turn random right or left 90°
  def turn_right_or_left_90
    if rand(2) == 0
      turn_right_90
    else
      turn_left_90
    end
  end
  # Turn in a random direction
  def turn_random
    case rand(4)
    when 0
      turn_up
    when 1
      turn_right
    when 2
      turn_left
    when 3
      turn_down
    end
  end
  # Turn toward the player
  def turn_toward_player
    turn_toward_character($game_player)
  end
  # Turn toward another character
  # @param character [Game_Character]
  def turn_toward_character(character)
    sx = @x - character.x
    sy = @y - character.y
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      sx > 0 ? turn_left : turn_right
    else
      sy > 0 ? turn_up : turn_down
    end
  end
  # Turn away from the player
  def turn_away_from_player
    sx = @x - $game_player.x
    sy = @y - $game_player.y
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      sx > 0 ? turn_right : turn_left
    else
      sy > 0 ? turn_down : turn_up
    end
  end
  public
  # @return [Integer] ID of the tile shown as the event (0 = no tile)
  attr_reader :tile_id
  # @return [String] name of the character graphic used to display the event
  attr_accessor :character_name
  # @return [Intger] must be 0
  attr_accessor :character_hue
  # @return [Integer] opacity of the event when it's shown
  attr_accessor :opacity
  # @return [Integer] blending of the event (0 is the only one that actually works)
  attr_reader :blend_type
  # @return [Integer] current pattern of the character graphic shown
  attr_reader :pattern
  # @return [Boolean] if the event is invisible
  attr_accessor :transparent
  # @return [Boolean] if the event has a patern animation while staying
  attr_accessor :step_anime
  # @return [Boolean] if the shadow should be shown or not
  attr_accessor :shadow_disabled
  # @return [Integer, nil] offset y of the character on the screen
  attr_accessor :offset_screen_y
  # @return [Integer, nil] offset y of the character on the screen
  attr_accessor :offset_shadow_screen_y
  # Values that allows the shadow_disabled update in set_appearance
  SHADOW_DISABLED_UPDATE_VALUES = [false, true, nil]
  # Define the new appearance of the character
  # @param character_name [String] name of the character graphic to display
  # @param character_hue [Integer] must be 0
  def set_appearance(character_name, character_hue = 0)
    @character_name = character_name
    @character_hue = character_hue
    @shadow_disabled = character_name.empty? if @event && SHADOW_DISABLED_UPDATE_VALUES.include?(@shadow_disabled)
    change_shadow_disabled_state(true) if @surfing && !is_a?(Game_Player)
  end
  # bush_depth of the sprite of the character
  # @return [Integer]
  def bush_depth
    if @tile_id > 0 || @always_on_top
      return 0
    end
    if @jump_count == 0 && $game_map.bush?(@x, @y)
      return 12
    else
      return 0
    end
  end
  # Set the charset animation. It can be needed to set the event in direction fixed.
  # @param lines [Array<Integer>] list of the lines to animates (0,1,2,3)
  # @param duration [Integer] duration of the animation in frame (30 frames per secondes)
  # @param reverse [Boolean] <default: false> set it to true if the animation is reversed
  # @param repeat [Boolean] <default: false> set it to true if the animation is looped
  # @return [Boolean]
  def animate_from_charset(lines, duration, reverse: false, repeat: false)
    frames = []
    lines.each do |dir|
      [0, 1, 2, 3].each do |pattern|
        frames.push ((((dir + 1) * 2) << 2) | pattern)
      end
    end
    frames.reverse! if reverse
    @charset_animation = {running: true, frames: frames, delay: (duration.to_f / frames.size.to_f).round, repeat: repeat, counter: -1, index: 0}
    return update_charset_animation
  end
  # Cancel the charset animation
  def cancel_charset_animation
    @charset_animation = nil
  end
  private
  SHADOW_DISABLED_KEEP_VALUES = {NilClass => nil, nil => NilClass, FalseClass => false, false => FalseClass, TrueClass => true, true => TrueClass}
  # Change the shadow state in order to keep the old value
  # @param value [Boolean] new value
  def change_shadow_disabled_state(value)
    if value
      @shadow_disabled ||= SHADOW_DISABLED_KEEP_VALUES[@shadow_disabled]
    else
      if @shadow_disabled.is_a?(Class)
        @shadow_disabled = SHADOW_DISABLED_KEEP_VALUES[@shadow_disabled]
      end
    end
  end
  # Update the charset animation and return true if there is a charset animation
  # @return [Boolean]
  def update_charset_animation
    return false unless @charset_animation&.dig(:running)
    return true unless ((@charset_animation[:counter] += 1) % @charset_animation[:delay]) == 0
    frame = @charset_animation[:frames][@charset_animation[:index]]
    @direction = (frame >> 2)
    @pattern = (frame & 0b11)
    if (@charset_animation[:index] += 1) >= @charset_animation[:frames].length
      if @charset_animation[:repeat]
        @charset_animation[:index] = 0
      else
        @charset_animation[:running] = false
        @original_pattern = @pattern
      end
    end
    return true
  end
  public
  # @return [Integer, false] if the character is in swamp tile and the power of the swamp tile
  attr_accessor :in_swamp
  # @return [Boolean] if the character is a Pokemon (affect the step anime)
  attr_accessor :is_pokemon
  # @return [Boolean] tell if the character can make footprint on the ground or not
  attr_accessor :can_make_footprint
  # is the character moving ?
  # @return [Boolean]
  def moving?
    return (@real_x != @x * 128 || @real_y != @y * 128)
  end
  # is the character jumping ?
  # @return [Boolean]
  def jumping?
    return @jump_count > 0
  end
  # Is the character able to execute a move action
  def movable?
    !(moving? || jumping?)
  end
  # Set the Game_Character in the "surfing" mode (not able to walk on ground but able to walk on water)
  # @author Nuri Yuri
  def set_surfing
    change_shadow_disabled_state(true)
    @surfing = true
  end
  # Check if the Game_Character is in the "surfing" mode
  # @return [Boolean]
  # @author Nuri Yuri
  def surfing?
    return @surfing
  end
  # Check if the Game_Character slides
  # @return [Boolean]
  # @author Nuri Yuri
  def sliding?
    return @sliding
  end
  # Make the character look the player during a dialog
  def lock
    return if @locked
    @prelock_direction = @direction
    turn_toward_player
    @locked = true
  end
  # Is the character locked ? (looking to the player when it's activated)
  # @note in this state, the character is not able to perform automatic moveroute (rmxp conf)
  # @return [Boolean]
  def lock?
    return @locked
  end
  # Release the character, can perform its natural movements
  def unlock
    return unless @locked
    @locked = false
    return if @direction_fix
    @direction = @prelock_direction unless @prelock_direction == 0
  end
  # current terrain tag on which the character steps
  # @return [Integer, nil]
  def terrain_tag
    return $game_map.terrain_tag(@x, @y)
  end
  # Return the SystemTag where the Game_Character stands
  # @return [Integer] ID of the SystemTag
  # @author Nuri Yuri
  def system_tag
    return $game_map.system_tag(@x, @y)
  end
  # Return the db_symbol of the system tag
  # @return [Symbol]
  def system_tag_db_symbol
    GameData::SystemTags.system_tag_db_symbol(system_tag)
  end
  # Count the number of impassable tiles around the fishing spot
  # @return [Integer] The number of impassable tiles
  def fishing_creek_amount
    xf, yf = front_tile
    d = game_state.game_player.direction
    top = !($game_map.passable?(xf, yf - 1, d) && SurfTag.include?($game_map.system_tag(xf, yf - 1)))
    right = !($game_map.passable?(xf + 1, yf, d) && SurfTag.include?($game_map.system_tag(xf + 1, yf)))
    bottom = !($game_map.passable?(xf, yf + 1, d) && SurfTag.include?($game_map.system_tag(xf, yf + 1)))
    left = !($game_map.passable?(xf - 1, yf, d) && SurfTag.include?($game_map.system_tag(xf - 1, yf)))
    return [top, right, bottom, left].count { |b| b }
  end
  public
  # Remove the memorized moves of the follower
  # @author Nuri Yuri
  def reset_follower_move
    @memorized_move_arg = @memorized_move = nil if @memorized_move
    @follower&.reset_follower_move
  end
  # Move a follower
  # @author Nuri Yuri
  def follower_move
    return unless @follower
    return if @sliding && @follower.sliding && ROCKET_TAGS.include?(@sliding_parameter)
    return if $game_variables[Yuki::Var::FM_Sel_Foll] > 0 && @follower.class == Game_Character
    @follower.move_speed = @move_speed
    if @memorized_move
      @memorized_move_arg ? @follower.send(@memorized_move, *@memorized_move_arg) : @follower.send(@memorized_move)
      @memorized_move_arg = nil
      @memorized_move = nil
      return
    end
    x = @x - @follower.x
    y = @y - @follower.y
    d = @direction
    case d
    when 2
      if x < 0
        @follower.move_left
      else
        if x > 0
          @follower.move_right
        else
          if y > 1
            @follower.move_down
          else
            if y == 0
              @follower.move_up
            end
          end
        end
      end
    when 4
      if y < 0
        @follower.move_up
      else
        if y > 0
          @follower.move_down
        else
          if x < -1
            @follower.move_left
          else
            if x == 0
              @follower.move_right
            end
          end
        end
      end
    when 6
      if y < 0
        @follower.move_up
      else
        if y > 0
          @follower.move_down
        else
          if x > 1
            @follower.move_right
          else
            if x == 0
              @follower.move_left
            end
          end
        end
      end
    when 8
      if x < 0
        @follower.move_left
      else
        if x > 0
          @follower.move_right
        else
          if y < -1
            @follower.move_up
          else
            if y == 0
              @follower.move_down
            end
          end
        end
      end
    end
  end
  # Warp the follower to the event it follows
  # @author Nuri Yuri
  def move_follower_to_character
    return unless @follower
    return if $game_variables[Yuki::Var::FM_Sel_Foll] > 0
    @follower.move_follower_to_character
    @follower.x = @x
    @follower.y = @y
    @follower.increase_steps
    @follower.update
  end
  # Check if the follower slides
  # @return [Boolean]
  # @author Nuri Yuri
  def follower_sliding?
    if @follower
      return @follower.follower_sliding? unless @follower.sliding?
      return true
    end
    return false
  end
  # Define the follower of the event
  # @param follower [Game_Character, Game_Event] the follower
  # @author Nuri Yuri
  def set_follower(follower)
    @follower = follower
  end
  # Return the tail of the following queue
  # @return [Game_Character, self]
  def follower_tail
    return self unless (current_follower = @follower)
    while (next_follower = current_follower.follower)
      current_follower = next_follower
    end
    return current_follower
  end
  # Rerturn the first follower that is a Game_Event in the queue
  # @return [Game_Event, nil]
  def next_event_follower
    f = @follower
    f = f.follower while !f.nil? && !f.is_a?(Game_Event)
    return f.is_a?(Game_Event) ? f : nil
  end
  # Reset the follower stack of the current entity
  def reset_follower
    return unless (current_follower = @follower)
    while (next_follower = current_follower.follower)
      current_follower.set_follower(nil)
      current_follower = next_follower
      break unless next_follower.is_a?(Game_Event)
    end
    set_follower(nil)
  end
  public
  # Return tile position in front of the player
  # @return [Array(Integer, Integer)] the position x and y
  def front_tile
    xf = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    yf = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    return [xf, yf]
  end
  # Return the event that stand in the front of the Player
  # @return [Game_Event, nil]
  def front_tile_event
    xf = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    yf = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    $game_map.events.each_value do |event|
      return event if event.x == xf && event.y == yf
    end
    return nil
  end
  # Iterate through each front tiles including current tile
  # @param nb_steps [Integer] number of step in front of the event to iterate
  # @yieldparam x [Integer] x coordinate
  # @yieldparam y [Integer] y coordinate
  # @yieldparam d [Integer] direction
  def each_front_tiles(nb_steps)
    x = @x
    y = @y
    d = @direction
    dx = d[2] * (2 * d[1] - 1)
    dy = (1 - d[2]) * (2 * d[1] - 1)
    if block_given?
      0.upto(nb_steps) do
        yield(x, y, d)
        x += dx
        y += dy
      end
    else
      return Enumerator.new do |yielder|
        0.upto(nb_steps) { |i| yielder << [x + i * dx, y + i * dy, d] }
      end
    end
  end
  # Iterate through each front tiles including current tile
  # @param nb_steps [Integer] number of step in front of the event to iterate
  # @param dist [Integer] distance in both side of the detection
  # @yieldparam x [Integer] x coordinate
  # @yieldparam y [Integer] y coordinate
  # @yieldparam d [Integer] direction
  def each_front_tiles_rect(nb_steps, dist)
    x = @x
    y = @y
    d = @direction
    dx = d[2] * (2 * d[1] - 1)
    dy = (1 - d[2]) * (2 * d[1] - 1)
    if block_given?
      0.upto(nb_steps) do
        (dist * 2 + 1).times { |line| yield(x + (line - dist) * dy, y + (line - dist) * dx, d) }
        x += dx
        y += dy
      end
    else
      return Enumerator.new do |yielder|
        (dist * 2 + 1).times do |line|
          0.upto(nb_steps) { |i| yielder << [x + (line - dist) * dy + i * dx, y + (line - dist) * dx + i * dy, d] }
        end
      end
    end
  end
  # Check a the #front_event has a specific name
  # @return [Boolean]
  # @author Nuri Yuri
  def front_name_check(name)
    return true if front_tile_event&.event&.name == name
    return false
  end
  alias front_name_detect front_name_check
  # Return the id of the #front_tile_event
  # @return [Integer, 0] 0 if no front_tile_event
  # @author Nuri Yuri
  def front_tile_id
    return front_tile_event&.event&.id.to_i
  end
  # Return the SystemTag in the front of the Game_Character
  # @return [Integer] ID of the SystemTag
  # @author Nuri Yuri
  def front_system_tag
    xf = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    yf = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    return $game_map.system_tag(xf, yf)
  end
  # Terrain tag in front of the character
  # @return [Integer, nil]
  def front_terrain_tag
    xf = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    yf = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    return $game_map.terrain_tag(xf, yf)
  end
  # Return the db_symbol of the front system tag
  # @return [Symbol]
  def front_system_tag_db_symbol
    GameData::SystemTags.system_tag_db_symbol(front_system_tag)
  end
  # Look directly to a specific event
  # @param event_id [Integer] id of the event on the Map
  # @author Nuri Yuri
  def look_to(event_id)
    return unless (event = $game_map.events[event_id])
    delta_x = event.x - @x
    delta_y = event.y - @y
    if delta_x.abs <= delta_y.abs
      if delta_y < 0
        turn_up
      else
        turn_down
      end
    else
      if delta_x < 0
        turn_left
      else
        turn_right
      end
    end
  end
  # Look directly to the current event
  def look_this_event
    look_to($game_system.map_interpreter.event_id)
  end
  # Array of SystemTag that define stairs
  StairsTag = [StairsL, StairsD, StairsU, StairsR]
  # Dynamic move_speed value of the Game_Character, return a different value than @move_speed
  # @return [Integer] the dynamic move_speed
  # @author Nuri Yuri
  def move_speed
    return (@in_swamp == 1 ? 2 : 1) if @in_swamp
    move_speed = original_move_speed
    if move_speed > 1
      direction = @direction
      sys_tag = system_tag
      if (direction == 6 && (sys_tag == StairsR || $game_map.system_tag(@x - 1, @y) == StairsL)) || (direction == 4 && (sys_tag == StairsL || $game_map.system_tag(@x + 1, @y) == StairsR))
        move_speed -= 1
      else
        if (direction == 2 || direction == 8) && (sys_tag == StairsU || sys_tag == StairsD)
          move_speed -= 1
        end
      end
    end
    return move_speed
  end
  # Return the original move speed of the character
  # @return [Integer]
  def original_move_speed
    return @move_speed
  end
  # Check if it's possible to have contact interaction with this Game_Character at certain coordinates
  # @param x [Integer] x position
  # @param y [Integer] y position
  # @param z [Integer] z position
  # @return [Boolean]
  # @author Nuri Yuri
  def contact?(x, y, z)
    return (@x == x && y == @y && (@z - z).abs <= 1)
  end
  # Detect if the event walks in a swamp or a deep swamp and change the Game_Character states.
  # @author Nuri Yuri
  def detect_swamp
    sys_tag = system_tag
    if sys_tag == SwampBorder
      change_shadow_disabled_state(true)
      @in_swamp = 1
    else
      if sys_tag == DeepSwamp
        change_shadow_disabled_state(true)
        @in_swamp = 4 + (rand(2) == 0 ? 4 + rand(4) : 0)
      else
        change_shadow_disabled_state(false)
        @in_swamp = false
      end
    end
  end
  public
  # Adjust the Character informations related to the brige when it moves down (or up)
  # @param z [Integer] the z position
  # @author Nuri Yuri
  def bridge_down_check(z)
    if z > 1 && !@__bridge
      if (sys_tag = front_system_tag) == BridgeUD
        @__bridge = [sys_tag, system_tag]
      end
    else
      if z > 1 && @__bridge
        @__bridge = nil if @__bridge.last == system_tag
      end
    end
  end
  alias bridge_up_check bridge_down_check
  # Adjust the Character informations related to the brige when it moves left (or right)
  # @param z [Integer] the z position
  # @author Nuri Yuri
  def bridge_left_check(z)
    if z > 1 && !@__bridge
      if (sys_tag = front_system_tag) == BridgeRL
        @__bridge = [sys_tag, system_tag]
      end
    else
      if z > 1 && @__bridge
        @__bridge = nil if @__bridge.last == system_tag
      end
    end
  end
  alias bridge_right_check bridge_left_check
  # Check bridge information and adjust the z position of the Game_Character
  # @param sys_tag [Integer] the SystemTag
  # @author Nuri Yuri
  def z_bridge_check(sys_tag)
    @z = ZTag.index(sys_tag) if ZTag.include?(sys_tag)
    @z = 1 if @z < 1
    @z = 0 if @z == 1 && BRIDGE_TILES.include?(sys_tag)
    @__bridge = nil if @__bridge && @__bridge.last == sys_tag
  end
  public
  # @return [Boolean] if the particles are disabled for the Character
  attr_accessor :particles_disabled
  # Show an emotion to an event or the player
  # @param type [Symbol] the type of emotion (see wiki)
  # @param wait [Integer] the number of frame the event will wait after this command.
  # @param params [Hash] particle params
  def emotion(type, wait = 34, params = {})
    Yuki::Particles.add_particle(self, type, params)
    @wait_count = wait
    @move_type_custom_special_result = true if wait > 0
  end
  # Constant defining all the particle method to call
  PARTICLES_METHODS = {TGrass => :particle_push_grass, TTallGrass => :particle_push_tall_grass, TSand => :particle_push_sand, TSnow => :particle_push_snow, TPond => :particle_push_pond, TWetSand => :particle_push_wetsand}
  # Push a particle to the particle stack if possible
  # @author Nuri Yuri
  def particle_push
    return if @particles_disabled
    method_name = PARTICLES_METHODS[system_tag]
    send(method_name) if method_name
  end
  # Push a grass particle
  def particle_push_grass
    Yuki::Particles.add_particle(self, 1)
  end
  # Push a tall grass particle
  def particle_push_tall_grass
    Yuki::Particles.add_particle(self, 2)
  end
  # Constant telling the sand particle name to push (according to the direction)
  SAND_PARTICLE_NAME = {2 => :sand_d, 4 => :sand_l, 6 => :sand_r, 8 => :sand_u}
  # Push a sand particle
  def particle_push_sand
    particle = SAND_PARTICLE_NAME[@direction]
    Yuki::Particles.add_particle(self, particle) if particle && @can_make_footprint
  end
  # Push a wet sand particle
  def particle_push_wetsand
    Yuki::Particles.add_particle(self, :wetsand)
  end
  # Constant telling the snow particle name to push (according to the direction)
  SNOW_PARTICLE_NAME = {2 => :snow_d, 4 => :snow_l, 6 => :snow_r, 8 => :snow_u}
  # Push a snow particle
  def particle_push_snow
    particle = SNOW_PARTICLE_NAME[@direction]
    Yuki::Particles.add_particle(self, particle) if particle && @can_make_footprint
  end
  # Push a pond particle
  def particle_push_pond
    Yuki::Particles.add_particle(self, :pond) if surfing?
  end
  public
  # The current move route
  attr_reader :move_route
  # The current move route index
  attr_reader :move_route_index
  # The bridge state
  attr_accessor :__bridge
  # The current sliding state
  attr_accessor :sliding
  # The current surfing state
  attr_writer :surfing
  # The current path
  # @return [Array<RPG::MoveCommand>, :pending, nil]
  attr_accessor :path
  # Move route that is empty and serve as a template for all the generate move route (by Path Finding)
  EMPTY_MOVE_ROUTE = RPG::MoveRoute.new
  EMPTY_MOVE_ROUTE.repeat = false
  # Request a path to the target and follow it as soon as it found
  # @param to [Array<Integer, Integer>, Game_Character] the target, [x, y] or Game_Character object
  # @param radius [Integer] <default : 0> the distance from the target to consider it as reached
  # @param tries [Integer, Symbol] <default : 5> the number of tries allowed to this request, use :infinity to unlimited try count
  # @param type [Symbol]
  # @example find path to x=10 y=15 with an error radius of 5 tiles
  #   find_path(to:[10,15], radius:5)
  def find_path(to:, radius: 0, tries: Pathfinding::TRY_COUNT, type: nil)
    type ||= (to.is_a?(Array) ? :Coords : :Character)
    Pathfinding.add_request(self, [type, to, radius], tries, :DEFAULT)
    @move_route_forcing_path_finder ||= @move_route_forcing
    @move_route_forcing = true
    @move_type_custom_special_result = true
  end
  # Stop following the path if there is one and clear the agent
  def stop_path
    clear_path
    Pathfinding.remove_request(self)
  end
  # Movement induced by the Path Finding
  def move_type_path
    return if @path == :pending
    return unless movable?
    while (command = @path[@move_route_index])
      break if move_type_custon_exec_command(command)
    end
  end
  # Define the path from path_finding
  # @param path [Array<RPG::MoveCommand>]
  def define_path(path)
    @move_route_index_path_finder ||= @move_route_index
    @move_route_index = 0
    @path = path
  end
  private
  # Clear the path
  def clear_path
    @move_route_index = @move_route_index_path_finder if @move_route_index_path_finder
    @move_route_forcing = @move_route_forcing_path_finder if @move_route_index_path_finder
    @move_route_index_path_finder = @path = @move_route_forcing_path_finder = nil
  end
end
# Describe an Event during the Map display process
class Game_Event < Game_Character
  # Tag inside an event that put it in the surfing state
  SURFING_TAG = 'surf_'
  # If named like this, this event is an invisible object
  INVISIBLE_EVENT_NAME = 'OBJ_INVISIBLE'
  # Tag that sets the event in an invisible state (not triggerd unless in front of it)
  INVISIBLE_EVENT_TAG = 'invisible_'
  # Tag that tells the event to always take the character_name of the first page when page change
  AUTO_CHARSET_TAG = '$'
  # Tag that tells the event not to push particles when it moves
  PARTICLE_OFF_TAG = '[particle=off]'
  # Tag that detect offset_screen_y
  OFFSET_Y_TAG = /\[offset_y=([0-9\-]+)\]/
  # Tag that forbid the creation of a Sprite_Character for this event
  NO_SPRITE_TAG = '[sprite=off]'
  # Tag that give the event an symbol alias
  SYMBOL_ALIAS_TAG = /\[alias=([a-z\-0-9\-_]+)\]/
  # Tag enabling reflection
  REFLECTION_TAG = '[reflection=on]'
  # @return [Integer, nil] Type of trigger for the event (0: Action key, 1: Player contact, 2: Event contact, 3: Autorun, 4: Parallel process)
  attr_reader :trigger
  # @return [Array<RPG::EventCommand>] list of commands that should be executed
  attr_reader :list
  # @return [Boolean] if the event wants to start
  attr_reader :starting
  # @return [RPG::Event] the event data from the MAP
  attr_reader :event
  # @return [Boolean] if the event is an invisible event (should be in front of the event to trigger it when it doesn't have a character_name)
  attr_reader :invisible_event
  # @return [Boolean] if the event was erased (needs to be removed from the view)
  attr_reader :erased
  # @return [Integer] Original id of the event
  attr_reader :original_id
  # @return [Integer] Original map id of the event
  attr_reader :original_map
  # @return [Symbol, nil] The symbol alias of the event
  attr_reader :sym_alias
  # Initialize the Game_Event with its map_id and its RPG::Event data
  # @param map_id [Integer] id of the map where the event is instanciated
  # @param event [RPG::Event] data of the event
  def initialize(map_id, event)
    super()
    @map_id = map_id
    @event = event
    @id = @event.id
    @original_map = event.original_map || map_id
    @original_id = event.original_id || @id
    @erased = false
    @starting = false
    @through = true
    @can_parallel_execute = @original_map == map_id
    initialize_parse_name
    moveto(@event.x, @event.y)
    refresh
  end
  # Parse the event name in order to setup the event particularity
  def initialize_parse_name
    return unless (name = @event.name)
    @particles_disabled = name.include?(PARTICLE_OFF_TAG) || @event.name.include?(NO_SPRITE_TAG)
    @autocharset = name.include?(AUTO_CHARSET_TAG)
    name.sub(OFFSET_Y_TAG) {@offset_screen_y = $1.to_i }
    @surfing = name.include?(SURFING_TAG)
    @invisible_event = (name == INVISIBLE_EVENT_NAME || name.include?(INVISIBLE_EVENT_TAG))
    name.sub(SYMBOL_ALIAS_TAG) {@sym_alias = $1.to_sym }
    @reflection_enabled = name.include?(REFLECTION_TAG)
  end
  # Tell if the event can execute in parallel process or automatic process
  # @return [Boolean]
  def can_parallel_execute?
    return @can_parallel_execute
  end
  # Tell if the event can have a sprite or not
  def can_be_shown?
    return !@event.name.include?(NO_SPRITE_TAG)
  end
  # Sets @starting to false allowing the event to move with its default move route
  def clear_starting
    @starting = false
  end
  # Tells if the Event cannot start
  # @return [Boolean]
  def over_trigger?
    return false if !@character_name.empty? && !@through || @invisible_event
    return false unless $game_map.passable?(@x, @y, 0)
    return true
  end
  # Starts the event if possible
  def start
    @starting = true unless @list.empty?
  end
  # Remove the event from the map
  def erase
    @erased = true
    @x = -10
    @y = -10
    @opacity = 0
    $game_map.event_erased = true
    refresh
  end
  # Refresh the event : check if an other page is valid and if so, refresh the graphics and command list
  def refresh
    new_page = nil
    unless @erased
      @event.pages.reverse_each do |page|
        next unless page.condition.valid?(@original_map, @original_id)
        new_page = page
        break
      end
    end
    return if new_page == @page
    return unless refresh_page(new_page) && can_parallel_execute?
    @interpreter = Interpreter.new if @trigger == 4
    check_event_trigger_auto
  end
  # Check if the event touch the player and start it if so
  # @param x [Integer] the x position to check
  # @param y [Integer] the y position to check
  def check_event_trigger_touch(x, y)
    return if $game_system.map_interpreter.running?
    return unless @trigger == 2 && $game_player.contact?(x, y, @z)
    start unless jumping? && over_trigger?
  end
  # Check if the event starts automaticaly and start if so
  def check_event_trigger_auto
    if @trigger == 2 && $game_player.contact?(@x, @y, @z) && !$game_temp.player_transferring
      start if !jumping? && over_trigger?
    end
    start if @trigger == 3
  end
  # Update the Game_Character and its internal Interpreter
  def update
    super
    check_event_trigger_auto
    return unless @interpreter
    @interpreter.setup(@list, @event.id) unless @interpreter.running?
    @interpreter.update
  end
  # Use path finding to locate the current event move else
  # @param to [Array<Integer, Integer>, Game_Character] the target, [x, y] or Game_Character object
  # @param radius [Integer] <default : 0> the distance from the target to consider it as reached
  # @param tries [Integer, Symbol] <default : 5> the number of tries allowed to this request, use :infinity to unlimited try count
  # @param type [Symbol]
  # @example find path to x=10 y=15 with an error radius of 5 tiles
  #   find_path(to:[10,15], radius:5)
  def find_path(to:, radius: 0, tries: Pathfinding::TRY_COUNT, type: nil)
    super(to: to, radius: radius, tries: tries, type: type) if Yuki::MapLinker.from_center_map?(self)
  end
  # Check if the character is activate. Useful to make difference between event without active page and others.
  # @return [Boolean]
  def activated?
    return !@page.nil?
  end
  private
  # Refresh all the information of the event according to the new page
  # @param new_page [RPG::Event::Page]
  # @return [Boolean] if the refresh function can continue
  def refresh_page(new_page)
    @page = new_page
    clear_starting
    if @page.nil?
      @tile_id = 0
      set_appearance(nil.to_s)
      @move_type = 0
      @through = true
      @trigger = nil
      @list = nil
      @interpreter = nil
      return false
    end
    @tile_id = @page.graphic.tile_id
    if @autocharset
      set_appearance(@event.pages[0].graphic.character_name, @event.pages[0].graphic.character_hue)
    else
      set_appearance(@page.graphic.character_name, @page.graphic.character_hue)
    end
    if @original_direction != @page.graphic.direction
      @direction = @page.graphic.direction
      @original_direction = @direction
      @prelock_direction = 0
    end
    if @original_pattern != @page.graphic.pattern
      @pattern = @page.graphic.pattern
      @original_pattern = @pattern
    end
    @opacity = @page.graphic.opacity
    @blend_type = @page.graphic.blend_type
    @move_type = @page.move_type
    @move_speed = @page.move_speed
    self.move_frequency = @page.move_frequency
    @move_route = @page.move_route
    @move_route_index = 0
    @move_route_forcing = false
    @walk_anime = @page.walk_anime
    @step_anime = @page.step_anime
    @direction_fix = @page.direction_fix
    @through = @page.through
    @always_on_top = @page.always_on_top
    @trigger = @page.trigger
    @list = @page.list
    @interpreter = nil
    return true
  end
end
# Management of the player displacement on the Map
class Game_Player < Game_Character
  # 4 time the x position of the Game_Player sprite
  CENTER_X = Configs.display.tilemap_settings.center.x
  # 4 time the y position of the Game_Player sprite
  CENTER_Y = Configs.display.tilemap_settings.center.y
  # Name of the bump sound when the player hit a wall
  BUMP_FILE = 'audio/se/bump'
  # true if the player is on the back wheel of its Acro bike
  # @return [Boolean]
  attr_accessor :acro_appearence
  # Default initializer
  def initialize
    super
    @wturn = 0
    @bump_count = 0
    @on_acro_bike = false
    @acro_count = 0
  end
  # Adjust the map display according to the given position
  # @param x [Integer] the x position on the MAP
  # @param y [Integer] the y position on the MAP
  def center(x, y)
    if $game_map.maplinker_disabled
      max_x = ($game_map.width - Game_Map::NUM_TILE_VIEW_X) * 128
      max_y = ($game_map.height - Game_Map::NUM_TILE_VIEW_Y) * 128
      $game_map.display_x = (x * 128 - CENTER_X).clamp(0, max_x)
      $game_map.display_y = (y * 128 - CENTER_Y).clamp(0, max_y)
    else
      $game_map.display_x = x * 128 - CENTER_X
      $game_map.display_y = y * 128 - CENTER_Y
    end
  end
  # Warp the player to a specific position. The map display will be centered
  # @param x [Integer] the x position on the MAP
  # @param y [Integer] the y position on the MAP
  def moveto(x, y)
    super
    center(x, y)
    make_encounter_count
    @reflection_enabled = true if @reflection_enabled.nil?
  end
  # Manage the system_tag part of the moveto method
  def moveto_system_tag_manage
    return super(true)
  end
  # Offset Screen Y of the surf sprite when surfing
  SURF_OFFSET_Y = [2, 2, 0, 0, 0, -2, -2, 0, 0, 0]
  # Overwrite the screen_y to add the surfing animation
  # @return [Integer]
  def screen_y
    value = super
    return value unless surfing?
    return value + SURF_OFFSET_Y[Graphics.frame_count / 6 % SURF_OFFSET_Y.size]
  end
  # Increases a step and displays related things
  def increase_steps
    super
    unless @move_route_forcing || $game_system.map_interpreter.running? || $game_temp.message_window_showing || @sliding
      PFM.game_state.increase_steps
    end
  end
  # Returns the number of steps remaining to the next encounter
  def encounter_count
    return @encounter_count
  end
  # Generate the number of steps remaining to the next encounter
  def make_encounter_count
    return if $game_map.map_id == 0
    n = $game_map.encounter_step
    @encounter_count = rand(n) + rand(n) + 1
  end
  # Refresh the player graphics
  def refresh
    return set_appearance(nil.to_s) if $game_party.actors.empty?
    actor = $game_party.actors[0]
    set_appearance(actor.character_name, actor.character_hue)
    @opacity = 255
    @blend_type = 0
  end
  # Update the player movements according to inputs
  def update
    return send(@update_callback) if @update_callback
    last_moving = moving?
    if moving? || $game_system.map_interpreter.running? || @move_route_forcing || $game_temp.message_window_showing || @sliding
      if $game_system.map_interpreter.running?
        enter_in_walking_state if @state == :running
      end
    else
      player_update_move
      player_move_on_cracked_floor_update if moving? && !last_moving
    end
    @wturn -= 1 if @wturn > 0
    last_real_x = @real_x
    last_real_y = @real_y
    super
    update_scroll_map(last_real_x, last_real_y)
    update_check_trigger(last_moving) unless moving? || @sliding
  end
  # Process the slope y modifier with scrolling handling
  def process_slope_y_modifier(y_modifier)
    super(y_modifier)
    $game_map.start_scroll(y_modifier < 0 ? 8 : 2, 1, 4, false, true)
  end
  private
  # Redefine of the update_move with the auto warp from the Yuki::MapLinker
  def update_move
    super
    Yuki::MapLinker.test_warp unless moving?
  end
  # Redefine the update_stop to support some specific cycling state
  def update_stop
    update_cycling_state if @state == :cycling
    super
    update_cycling_state if @state == :cycle_stop && moving?
    return unless @in_swamp && (@state == :walking || @state == :running)
    @state == :walking ? enter_in_walking_state : enter_in_running_state
  end
  # Name of the JUMP SE
  JUMP_SE = 'audio/se/jump'
  # Redefine the update_jump to support the cracked floor
  def update_jump
    Audio.se_play(JUMP_SE) if @jump_count == @jump_peak * 2
    super
    player_move_on_cracked_floor_update unless @jump_count > 0
  end
  # Scroll the map during the update phase
  # @param last_real_x [Integer] the last real_x value of the player
  # @param last_real_y [Integer] the last real_y value of the player
  def update_scroll_map(last_real_x, last_real_y)
    if @real_y > last_real_y && @real_y - $game_map.display_y > CENTER_Y
      $game_map.scroll_down(@real_y - last_real_y)
    end
    if @real_x < last_real_x && @real_x - $game_map.display_x < CENTER_X
      $game_map.scroll_left(last_real_x - @real_x)
    end
    if @real_x > last_real_x && @real_x - $game_map.display_x > CENTER_X
      $game_map.scroll_right(@real_x - last_real_x)
    end
    if @real_y < last_real_y && @real_y - $game_map.display_y < CENTER_Y
      $game_map.scroll_up(last_real_y - @real_y)
    end
  end
  # Check the triggers during the update
  # @param last_moving [Boolean] if the player was moving before
  def update_check_trigger(last_moving)
    if last_moving && !check_event_trigger_here([1, 2])
      unless debug? && Input::Keyboard.press?(Input::Keyboard::LControl)
        @encounter_count -= 1 if @encounter_count > 1
        make_encounter_count if @encounter_count <= 1
      end
    end
    return unless Input.trigger?(:A)
    result = check_event_trigger_here([0])
    result |= check_event_trigger_there([0, 1, 2])
    return if result
    check_diving_trigger_here
  end
  # Start common event diving if the player stand on diving system tag and is surfing
  def check_diving_trigger_here
    if !@__bridge && !$game_temp.message_window_showing && $game_player.surfing? && $game_map.system_tag_here?($game_player.x, $game_player.y, ::GameData::SystemTags::TUnderWater)
      $game_temp.common_event_id = Game_CommonEvent::DIVE
    end
  end
  public
  # is the tile in front of the player passable ? / Plays a BUMP SE in some conditions
  # @param x [Integer] x position on the Map
  # @param y [Integer] y position on the Map
  # @param d [Integer] direction : 2, 4, 6, 8, 0. 0 = current position
  # @return [Boolean] if the front/current tile is passable
  def passable?(x, y, d)
    return true if debug? && Input::Keyboard.press?(Input::Keyboard::LControl)
    new_x = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    new_y = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
    return maplinker_passable?(new_x, new_y) unless $game_map.valid?(new_x, new_y)
    result = super
    result = acro_passable_check(d, result)
    return result
  end
  # Tags that are Bike bridge (jumpable on Acro Bike)
  AccroTag = [AcroBikeRL, AcroBikeUD]
  # Tags where the Bike cannot pass
  NO_BIKE_TILE = [SwampBorder, DeepSwamp, TTallGrass]
  # Test if the player can pass Bike bridge
  # @author Nuri Yuri
  def acro_passable_check(d, result)
    on_bike = (@on_acro_bike || $game_switches[::Yuki::Sw::EV_Bicycle])
    if @z > 1 && on_bike
      sys_tag = front_system_tag
      case d
      when 4, 6
        return true if sys_tag == AcroBikeRL
      when 8, 2
        return true if sys_tag == AcroBikeUD
      else
        return true if AccroTag.include?(sys_tag)
      end
      return false if @__bridge && AccroTag.include?(@__bridge.first) && !ZTag.include?(sys_tag)
      @__bridge = nil if result && ZTag.include?(sys_tag)
    else
      if on_bike
        return false if NO_BIKE_TILE.include?(front_system_tag)
      end
    end
    return result
  end
  # Check the surf related passabilities
  # @param sys_tag [Integer] current system_tag
  # @return [Boolean] if the tile is passable according to the surf rules
  def passage_surf_check?(sys_tag)
    if !@surfing && SurfTag.include?(sys_tag)
      if $game_switches[Yuki::Sw::NoSurfContact]
        event = front_tile_event
        return false unless event&.through || event&.character_name&.empty?
        $game_temp.common_event_id = Game_CommonEvent::SURF_ENTER
      end
      return false
    else
      if @surfing
        unless SurfLTag.include?(sys_tag)
          event = front_tile_event
          return false if event && !event.through && !event.character_name.empty?
          change_shadow_disabled_state(false)
          @surfing = false
          $game_temp.common_event_id = Game_CommonEvent::SURF_LEAVE
          return false
        end
        if sys_tag == WaterFall
          $game_temp.common_event_id = Game_CommonEvent::WATERFALL
          return false
        end
      end
    end
    return true
  end
  # Check the passage related to events
  # @param new_x [Integer] new x position
  # @param new_y [Integer] new y position
  # @param z [Integer] current z position
  # @param game_map [Game_Map] map object
  # @return [Boolean] if the tile has no event that block the way
  def event_passable_check?(new_x, new_y, z, game_map)
    game_map.events.each_value do |event|
      next unless event.contact?(new_x, new_y, z)
      next if event.through
      return false unless event.character_name.empty?
    end
    return true
  end
  private
  # is the tile in front of the player passable for maplinker uses
  # @param new_x [Integer] new x position on the Map
  # @param new_y [Integer] new y position on the Map
  # @return [Boolean] if the front/current tile is passable
  def maplinker_passable?(new_x, new_y)
    return false unless Yuki::MapLinker.passable?(new_x, new_y, @direction)
    return event_passable_check?(new_x, new_y, z, $game_map)
  end
  public
  # Check if there's an event trigger on the tile where the player stands
  # @param triggers [Array<Integer>] the list of triggers to check
  # @return [Boolean]
  def check_event_trigger_here(triggers)
    return false if $game_system.map_interpreter.running?
    result = false
    z = @z
    $game_map.events.each_value do |event|
      y_modifier = (@direction == 4 ? slope_check_left(false) : @direction == 6 ? slope_check_right(false) : 0)
      next unless event.contact?(@x, @y + y_modifier, z) && triggers.include?(event.trigger)
      next unless !event.jumping? && event.over_trigger?
      event.start
      result = true
    end
    return result
  end
  # Check if there's an event trigger in front of the player (when he presses A)
  # @param triggers [Array<Integer>] the list of triggers to check
  # @return [Boolean]
  def check_event_trigger_there(triggers)
    return false if $game_system.map_interpreter.running?
    result = false
    d = @direction
    new_x = @x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    new_y = @y + (d == 2 ? 1 : d == 8 ? -1 : 0) + (@direction == 4 ? slope_check_left(false) : @direction == 6 ? slope_check_right(false) : 0)
    z = @z
    $game_map.events.each_value do |event|
      next unless event.contact?(new_x, new_y, z) && triggers.include?(event.trigger)
      next if event.jumping? || event.over_trigger?
      event.start
      result = true
    end
    z = @z
    return true if result
    if $game_map.counter?(new_x, new_y)
      new_x2 = new_x + (d == 6 ? 1 : d == 4 ? -1 : 0)
      new_y2 = new_y + (d == 2 ? 1 : d == 8 ? -1 : 0)
      $game_map.events.each_value do |event|
        next unless event.contact?(new_x2, new_y2, z) && triggers.include?(event.trigger)
        next if event.jumping? || event.over_trigger?
        event.start
        result = true
      end
    end
    return true if result
    check_common_event_trigger_there(new_x, new_y, z, d)
    result ||= check_follower_trigger_there(new_x, new_y) if @follower
    return result
  end
  # Tile tha allow to use DIVE
  DIVE_TILE = [TSea, TUnderWater]
  # Check the common event call
  # @param new_x [Integer] the x position to check
  # @param new_y [Integer] the y position to check
  # @param z [Integer] the z of the event
  # @param d [Integer] the direction where to check
  def check_common_event_trigger_there(new_x, new_y, z, d)
    sys_tag = system_tag
    front_sys_tag = $game_map.system_tag(new_x, new_y)
    if terrain_tag == 6 && DIVE_TILE.include?(sys_tag)
      $game_temp.common_event_id = Game_CommonEvent::DIVE
    else
      if front_sys_tag == HeadButt
        $game_temp.common_event_id = Game_CommonEvent::HEADBUTT
      else
        if !@surfing && SurfTag.include?(front_sys_tag) && z <= 1 && $game_map.passable?(x, y, d, nil)
          if $game_map.passable?(new_x, new_y, 10 - d, self) || Yuki::MapLinker.passable?(new_x, new_y, 10 - d, nil)
            $game_temp.common_event_id = Game_CommonEvent::SURF_ENTER
          end
        end
      end
    end
  end
  # Check the follower common event call
  # @param new_x [Integer] the x position to check
  # @param new_y [Integer] the y position to check
  # @return [Boolean] if the trigger happened
  def check_follower_trigger_there(new_x, new_y)
    if @follower.x == new_x && @follower.y == new_y
      if @follower.is_a?(Game_Event)
        @follower.start
      else
        @follower.turn_toward_player
        $game_temp.common_event_id = Game_CommonEvent::FOLLOWER_SPEECH
      end
      return true
    end
    return false
  end
  # Check if the player touch an event and start it if so
  # @param x [Integer] the x position to check
  # @param y [Integer] the y position to check
  def check_event_trigger_touch(x, y)
    return false if $game_system.map_interpreter.running?
    result = false
    z = @z
    $game_map.events.each_value do |event|
      next unless event.contact?(x, y, z) && [1, 2].include?(event.trigger)
      next if event.jumping? || event.over_trigger?
      event.start
      result = true
    end
    return result
  end
  public
  # List of system tags that makes the player Jump
  JumpTags = [JumpL, JumpR, JumpU, JumpD]
  # Move or turn the player according to its input. The common event 2 can be triggered there
  # @author Nuri Yuri
  def player_update_move
    @wturn = 10 - @move_speed if @lastdir4 == 0 && !(Input.repeat?(:UP) || Input.repeat?(:DOWN) || Input.repeat?(:LEFT) || Input.repeat?(:RIGHT))
    @lastdir4 = Input.dir4
    swamp_detect = (@in_swamp && @in_swamp > 4)
    if bool = ((@wturn > 0) | swamp_detect)
      player_turn(swamp_detect)
    else
      player_move
    end
    player_update_move_bump(bool)
    player_update_move_common_events(bool)
  end
  # Turn the player on himself. Does some calibration for the Acro Bike.
  # @author Nuri Yuri
  def player_turn(swamp_detect)
    if swamp_detect && @lastdir4 != @direction && @lastdir4 != 0
      @in_swamp -= 1
    end
    last_dir = @direction
    case @lastdir4
    when 2
      turn_down
    when 4
      turn_left
    when 6
      turn_right
    when 8
      turn_up
    else
      if system_tag == Hole
        $game_temp.common_event_id = Game_CommonEvent::HOLE_FALLING
      else
        if @on_acro_bike
          update_acro_bike_turn(system_tag)
        end
      end
    end
    calibrate_acro_direction(last_dir)
  end
  # Move the player. Does some calibration for the Acro Bike.
  # @author Nuri Yuri
  def player_move
    jumping = false
    jumping_dist = 1
    if @acro_bike_bunny_hop
      return if (jumping = update_acro_bike(5, front_system_tag)) == false
      jumping_dist = 2 if JumpTags.include?(front_system_tag)
    end
    last_dir = @direction
    case @lastdir4
    when 2
      jumping ? jump(0, jumping_dist) : move_down
    when 4
      turn_left
      jumping ? jump(-jumping_dist, 0) : move_left
    when 6
      turn_right
      jumping ? jump(jumping_dist, 0) : move_right
    when 8
      jumping ? jump(0, -jumping_dist) : move_up
    end
    calibrate_acro_direction(last_dir)
    update_cycling_state if @state == :cycle_stop && moving?
  end
  # Reset the direction of the player when he's on bike bridge
  # @param last_dir [Integer] the last direction
  # @author Nuri Yuri
  def calibrate_acro_direction(last_dir)
    if @__bridge && (sys_tag = @__bridge.first)
      return if sys_tag != AcroBikeRL && sys_tag != AcroBikeUD
    end
    case @direction
    when 8, 2
      @direction = last_dir if sys_tag == AcroBikeRL
    when 4, 6
      @direction = last_dir if sys_tag == AcroBikeUD
    end
  end
  # Update the Acro Bike jump info
  # @param count [Integer] number of @acro_count frame before the player is allowed to jump
  # @param sys_tag [Integer] the current system tag
  # @return [Boolean, nil] if the player can jump (nil = not allowed to jump but can move forward)
  # @author Nuri Yuri
  def update_acro_bike(count, sys_tag)
    return false if jumping?
    if SlideTags.include?(sys_tag) || sys_tag == MachBike
      return nil
    end
    if @wturn == 0 && !$game_map.jump_passable?(@x, @y, @lastdir4)
      return nil if system_tag != AcroBike && !@__bridge
    end
    if @acro_count < count
      @acro_count += 1
      return false
    end
    @acro_count = 0
    return true
  end
  # Update the Acro Bike jump info when not moving
  # @param sys_tag [Integer] the current system tag
  # @return [Boolean, nil] if the player can jump (nil = not allowed to jump but can move forward)
  # @author Leikt
  def update_acro_bike_turn(sys_tag)
    if sys_tag == AcroBike
      if update_acro_bike(5, sys_tag)
        jump(0, 0)
      end
    else
      if Input.press?(:B)
        if update_acro_bike((@acro_bike_bunny_hop ? 5 : 35), sys_tag)
          jump(0, 0)
          @acro_bike_bunny_hop = true
        end
      else
        if !Input.press?(:B)
          @acro_bike_bunny_hop = false
        end
      end
    end
  end
  # Manage the bump part of the player_update_move
  # @param bool [Boolean] tell if the player did a fast direction change
  def player_update_move_bump(bool)
    return player_update_move_bump_restore_step_anime if moving?
    if @__last_x != @x || @__last_y != @y
      @__last_x = @x
      @__last_y = @y
      return player_update_move_bump_restore_step_anime
    end
    if @lastdir4 != 0 && !bool
      @__previous_step_anim = @step_anime if @__previous_step_anim.nil?
      @step_anime = true
      if (@__old_pattern == 3 && @pattern == 0) || (@__old_pattern == 1 && @pattern == 2)
        Audio.se_play(BUMP_FILE)
      end
    else
      player_update_move_bump_restore_step_anime
    end
    @__old_pattern = @pattern
  end
  # Restore step anime if it was changed
  def player_update_move_bump_restore_step_anime
    return if @__previous_step_anim.nil?
    @step_anime = @__previous_step_anim
    @__previous_step_anim = nil
  end
  # Manage the common event calling of player_update_move
  # @param bool [Boolean]
  def player_update_move_common_events(bool)
    if @on_acro_bike
      if !@acro_appearence && Input.press?(:B)
        @acro_appearence = true
        enter_in_wheel_state
      else
        if @acro_appearence && !Input.press?(:B) && !jumping? && !@acro_bike_bunny_hop
          @acro_appearence = false
          leave_wheel_state
        end
      end
    else
      player_update_move_running_state(bool) unless @surfing || cycling?
    end
  end
  # Manage the running update of player_update_move inside player_update_move_common_events
  # @param bool [Boolean]
  def player_update_move_running_state(bool)
    if !bool && @lastdir4 != 0 && $game_switches[::Yuki::Sw::EV_CanRun] && !$game_switches[::Yuki::Sw::EV_Run] && Input.press?(:B) && !@step_anime
      enter_in_running_state unless @state == :sinking
    else
      if $game_switches[::Yuki::Sw::EV_Run] && (@lastdir4 == 0 || !Input.press?(:B) || $game_system.map_interpreter.running? || @step_anime)
        enter_in_walking_state unless @state == :sinking
      end
    end
  end
  # Update the cracked floor when the player move on it
  def player_move_on_cracked_floor_update
    if (sys_tag = system_tag) == CrackedSoil
      $game_map.data[@x, @y, 0] = $game_map.data[@x, @y, 0] + 1
      $game_temp.common_event_id = Game_CommonEvent::HOLE_FALLING if system_tag == Hole && @move_speed < 5
    else
      if sys_tag == Hole
        $game_temp.common_event_id = Game_CommonEvent::HOLE_FALLING
      end
    end
  end
  public
  # @return [String, nil] return the charset_base used to calculate the graphic
  attr_reader :charset_base
  # Launch the player update appearance
  # @param forced_pattern [Integer] pattern after update (default : 0)
  # @author Leikt
  def update_appearance(forced_pattern = 0)
    return unless @charset_base
    set_appearance("#{@charset_base}_#{$game_switches[Yuki::Sw::Gender] ? 'f' : 'm'}#{chara_by_state}")
    @pattern = forced_pattern
    update_pattern_state
    return true
  end
  # Get the character suffix from the hash
  # @return [String] the suffix
  # @author Leikt
  def chara_by_state
    return STATE_APPEARANCE_SUFFIX[@state || enter_in_walking_state]
  end
  # Change the appearance set for the player. The argument is the base of the charset name.
  # For exemple : for the file "HeroRed001_M_walk", the charset base will be "HeroRed001"
  # @param charset_base [String, nil] the base of the charsets filenames (nil = don't use the charset_base)
  # @author Leikt
  def set_appearance_set(charset_base)
    @charset_base = charset_base
    update_appearance
  end
  public
  # Push the sand particle only if the player is not cycling
  def particle_push_sand
    super unless cycling?
  end
  public
  # Return the tail of the following queue (Game_Event exclusive)
  # @return [Game_Character, self]
  def follower_tail
    return self unless (current_follower = @follower)
    return self unless current_follower.is_a?(Game_Event)
    while (next_follower = current_follower.follower)
      break unless next_follower.is_a?(Game_Event)
      current_follower = next_follower
    end
    return current_follower
  end
  # Define the follower of the player, if the player already has event following him, it'll put them at the tail of the following events
  # @param follower [Game_Character, Game_Event] the follower
  # @param force [Boolean] param comming from Yuki::FollowMe to actually force the follower
  # @author Nuri Yuri
  def set_follower(follower, force = false)
    return @follower = follower if force
    return reset_follower unless follower
    return if @follower == follower
    return @follower = follower unless @follower
    return follower_tail.set_follower(follower) if @follower.is_a?(Game_Event)
    follower.set_follower(@follower) if follower.is_a?(Game_Event)
    @follower = follower
  end
  # Reset the follower stack to prevent any issue
  def reset_follower
    return unless (current_follower = @follower)
    while (next_follower = current_follower.follower)
      current_follower.set_follower(nil)
      current_follower = next_follower
    end
    @follower = nil
  end
  # Set the player z and all its follower z at the same tile
  # @param value [Integer] new z value
  def change_z_with_follower(value)
    @z = value
    follower = self
    while follower = follower.follower
      follower.z = value
    end
  end
  public
  # Indicate if the player is on acro bike
  # @return [Boolean]
  attr_reader :on_acro_bike
  # Define Acro Bike state of the Game_Player
  # @author Nuri Yuri
  def on_acro_bike=(state)
    @on_acro_bike = state
    @acro_count = 0
  end
  # Search an invisible item
  def search_item
    $game_map.events.each do |event_id, event|
      if event.invisible_event
        dx = (event.x - @x).abs
        dy = (event.y - @y).abs
        if dx <= 10 && dy <= 7
          Audio.se_play('audio/se/nintendo')
          $game_player = event
          turn_toward_player
          $game_player = self
          return true
        end
      end
    end
    return false
  end
  # Detect the swamp state
  def detect_swamp
    last_in_swamp = @in_swamp
    super
    if @in_swamp
      detect_swamp_entering(last_in_swamp)
      detect_deep_swamp_sinking(last_in_swamp)
    else
      detect_swamp_leaving(last_in_swamp)
    end
  end
  # Detect if we are leaving the swamp, then update the state
  # @param last_in_swamp [Integer, false] the last swamp info
  def detect_swamp_leaving(last_in_swamp)
    return unless last_in_swamp
    @state == :swamp ? enter_in_walking_state : enter_in_running_state
  end
  # Detect if we are entering in the swamp, then update the state
  # @param last_in_swamp [Integer, false] the last swamp info
  def detect_swamp_entering(last_in_swamp)
    return unless last_in_swamp
    return unless @state == :walking || @state == :running
    @state == :walking ? enter_in_walking_state : enter_in_running_state
  end
  # Detect if we should trigger the deep_swamp sinking when we detect swamp info
  # @param last_in_swamp [Integer, false] the last swamp info
  def detect_deep_swamp_sinking(last_in_swamp)
    if (last_in_swamp == false || last_in_swamp <= 1) && (@in_swamp && @in_swamp > 1)
      enter_in_sinking_state
    else
      if (last_in_swamp && last_in_swamp > 1) && !(@in_swamp && @in_swamp > 1)
        leave_sinking_state
      end
    end
  end
  public
  # Same as Game_Character but with Acro bike
  # @author Nuri Yuri
  def bridge_down_check(z)
    if z > 1 && !@__bridge
      if (sys_tag = front_system_tag) == BridgeUD || (sys_tag == AcroBikeUD && (@on_acro_bike || $game_switches[::Yuki::Sw::EV_Bicycle]))
        @__bridge = [sys_tag, system_tag]
      end
    else
      if z > 1 && @__bridge
        @__bridge = nil if @__bridge.last == system_tag && front_system_tag != @__bridge.first
      end
    end
  end
  alias bridge_up_check bridge_down_check
  # Same as Game_Character but with Acro bike
  # @author Nuri Yuri
  def bridge_left_check(z)
    if z > 1 && !@__bridge
      if (sys_tag = front_system_tag) == BridgeRL || (sys_tag == AcroBikeRL && (@on_acro_bike || $game_switches[::Yuki::Sw::EV_Bicycle]))
        @__bridge = [sys_tag, system_tag]
      end
    else
      if z > 1 && @__bridge
        @__bridge = nil if @__bridge.last == system_tag && front_system_tag != @__bridge.first
      end
    end
  end
  alias bridge_right_check bridge_left_check
  public
  # @return [Hash] List of appearence suffix according to the state
  STATE_APPEARANCE_SUFFIX = {cycling: '_cycle_roll', cycle_stop: '_cycle_stop', roll_to_wheel: '_cycle_roll_to_wheel', wheeling: '_cycle_wheel', fishing: '_fish', surf_fishing: '_surf_fish', saving: '_pokecenter', using_skill: '_pokecenter', giving_pokemon: '_pokecenter', taking_pokemon: '_pokecenter', running: '_run', walking: '_walk', surfing: '_surf', swamp: '_swamp', swamp_running: '_swamp_run', sinking: '_deep_swamp_sinking'}
  # @return [Hash] List of movement speed, movement frequency according to the state
  STATE_MOVEMENT_INFO = {walking: [3, 4], running: [4, 4], wheeling: [4, 4], cycling: [5, 4], surfing: [4, 4]}
  # @return [Symbol, nil] the update_callback
  attr_reader :update_callback
  # Update the move_speed & move_frequency parameters
  # @param state [Symbol] the name of the state to fetch the move parameter
  def update_move_parameter(state)
    @move_speed, @move_frequency = STATE_MOVEMENT_INFO[state]
    next_event_follower&.move_speed = @move_speed
  end
  # Enter in walking state (supports the swamp state)
  # @return [:walking] (It's used inside set_appearance_set when no state is defined)
  def enter_in_walking_state
    $game_switches[Yuki::Sw::EV_Run] = false if $game_switches
    @state = @in_swamp ? :swamp : :walking
    update_move_parameter(:walking)
    update_appearance(@pattern)
    return @state
  end
  # Enter in running state (supports the swamp state)
  def enter_in_running_state
    $game_switches[::Yuki::Sw::EV_Run] = true
    @state = @in_swamp ? :swamp_running : :running
    update_move_parameter(:running)
    update_appearance(@pattern)
  end
  # Enter in surfing state
  def enter_in_surfing_state
    @state = :surfing
    update_move_parameter(:surfing)
    update_appearance(@pattern)
  end
  # Leave the surfing state
  def leave_surfing_state
    change_shadow_disabled_state(false)
    @surfing = false
    return_to_previous_state
  end
  # Enter in the wheel state
  def enter_in_wheel_state
    @update_callback = :update_enter_wheel_state
    @update_callback_count = 0
    @state = :roll_to_wheel
    update_appearance(0)
  end
  # Callback called when we are entering in wheel state
  def update_enter_wheel_state
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern += 1
    return unless @pattern > 3
    @state = :wheeling
    @update_callback = nil
    update_appearance(0)
  end
  # Leave the wheel state
  def leave_wheel_state
    @update_callback = :update_leave_wheel_state
    @update_callback_count = 0
    @state = :roll_to_wheel
    update_appearance(3)
  end
  # Callback called when we are leaving in wheel state
  def update_leave_wheel_state
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern -= 1
    return unless @pattern < 0
    @state = :cycling
    @update_callback = nil
    update_appearance(0)
  end
  # Jump on the mach bike
  def enter_in_cycling_state
    $game_switches[::Yuki::Sw::EV_Bicycle] = true
    $game_switches[::Yuki::Sw::EV_AccroBike] = false
    self.on_acro_bike = false
    $game_map.need_refresh = true
    @state = moving? ? :cycling : :cycle_stop
    update_move_parameter(:cycling)
    update_appearance(@pattern)
  end
  # Jump on the acro bike
  def enter_in_acro_bike_state
    $game_switches[::Yuki::Sw::EV_Bicycle] = false
    $game_switches[::Yuki::Sw::EV_AccroBike] = true
    self.on_acro_bike = true
    $game_map.need_refresh = true
    @state = moving? ? :cycling : :cycle_stop
    update_move_parameter(:wheeling)
    update_appearance(@pattern)
  end
  # Leave the cycling state
  def leave_cycling_state
    $game_switches[::Yuki::Sw::EV_Bicycle] = false
    $game_switches[::Yuki::Sw::EV_AccroBike] = false
    self.on_acro_bike = false
    $game_map.need_refresh = true
    enter_in_walking_state
  end
  alias leave_acro_bike_state leave_cycling_state
  # Update the cycling state
  def update_cycling_state
    @state = moving? ? :cycling : :cycle_stop
    update_appearance(@pattern)
  end
  # Test if the player is cycling
  # @return [Boolean]
  def cycling?
    @state == :cycling || @state == :cycle_stop || @state == :wheeling
  end
  # Enter in fishing state
  def enter_in_fishing_state
    @offset_screen_y = 8 unless @surfing
    leave_cycling_state if cycling?
    @state = @surfing ? :surf_fishing : :fishing
    @update_callback = :update_enter_fishing_state
    @update_callback_count = 0
    update_appearance(0)
  end
  # Callback called when we are entering in wheel state
  def update_enter_fishing_state
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern += 1
    return unless @pattern > 2
    @update_callback = :update_locked_state
  end
  # Leave fishing state
  def leave_fishing_state
    @state = @surfing ? :surf_fishing : :fishing
    @update_callback = :update_leave_fishing_state
    @update_callback_count = 0
    update_appearance(3)
  end
  # Callback called when we are leaving in wheel state
  def update_leave_fishing_state
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern -= 1
    return unless @pattern < 0
    @state = @surfing ? :surfing : :walking
    @update_callback = nil
    @offset_screen_y = nil
    update_appearance(0)
  end
  # Enter in sinking state
  def enter_in_sinking_state
    @update_callback = :update_enter_sinking_state
    @update_callback_count = 0
  end
  # Callback called when we are entering in wheel state
  def update_enter_sinking_state
    if moving?
      last_real_x = @real_x
      last_real_y = @real_y
      update_move
      update_scroll_map(last_real_x, last_real_y)
      return update_pattern
    end
    unless @state == :sinking
      @state = :sinking
      update_appearance(3)
    end
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern -= 1
    return unless @pattern < 0
    @update_callback = nil
    update_appearance(0)
  end
  # Leave sinking state
  def leave_sinking_state
    @state = :sinking
    @update_callback = :update_leave_sinking_state
    @update_callback_count = 0
    update_appearance(0)
  end
  # Callback called when we are leaving in wheel state
  def update_leave_sinking_state
    @update_callback_count += 1
    return unless (@update_callback_count % 6) == 0
    @pattern += 1
    return unless @pattern > 3
    @update_callback = nil
    @pattern = 3
    enter_in_walking_state
  end
  # Enter in saving state
  def enter_in_saving_state
    @state = :saving
    @update_callback = :update_4_step_animation
    @update_callback_count = 0
    @prelock_direction = @direction
    @direction = 8
    update_appearance(0)
  end
  # Enter in using_skill state
  def enter_in_using_skill_state
    @state = :using_skill
    @update_callback = :update_4_step_animation
    @update_callback_count = 0
    @prelock_direction = @direction
    @direction = 6
    update_appearance(0)
  end
  # Enter in giving_pokemon state
  def enter_in_giving_pokemon_state
    @state = :giving_pokemon
    @update_callback = :update_giving_pokemon_state
    @update_callback_count = 0
    @prelock_direction = @direction
    @direction = 2
    update_appearance(0)
  end
  # Update the Pokemon giving animation
  def update_giving_pokemon_state
    if @direction == 2
      update_4_step_animation
      if @update_callback == :update_locked_state
        @direction = 4
        @update_callback = :update_giving_pokemon_state
      end
      return
    end
    update_4_step_animation_to_previous
  end
  # Enter in taking_pokemon state
  def enter_in_taking_pokemon_state
    @state = :taking_pokemon
    @update_callback = :update_taking_pokemon_state
    @update_callback_count = 0
    @prelock_direction = @direction
    @direction = 4
    update_appearance(3)
  end
  # Update the Pokemon taking animation
  def update_taking_pokemon_state
    if @direction == 4
      update_4_step_animation(-1)
      if @update_callback == :update_locked_state
        @direction = 2
        @update_callback = :update_taking_pokemon_state
      end
      return
    end
    update_4_step_animation_to_previous(-1)
  end
  # Callback called when we only want the character to show it's 4 pattern (it'll lock the player, use return_to_previous_state to unlock)
  # @param factor [Integer] the number added to pattern
  def update_4_step_animation(factor = 1)
    @update_callback_count += 1
    return unless (@update_callback_count % 12) == 0
    @pattern += factor
    return unless @pattern > 3 || @pattern < 0
    @update_callback = :update_locked_state
    @pattern = @pattern > 3 ? 3 : 0
  end
  # Callback called when we only want the character to show it's 4 pattern and return to previous state
  # @param factor [Integer] the number added to pattern
  def update_4_step_animation_to_previous(factor = 1)
    @update_callback_count += 1
    return unless (@update_callback_count % 12) == 0
    @pattern += factor
    return unless @pattern > 3 || @pattern < 0
    return_to_previous_state
  end
  # Return to the correct state
  def return_to_previous_state
    @update_callback = nil
    @direction = @prelock_direction if @prelock_direction > 0
    @prelock_direction = 0
    @pattern = 0
    if @surfing
      enter_in_surfing_state
    else
      if $game_switches[::Yuki::Sw::EV_Bicycle]
        enter_in_cycling_state
      else
        if $game_switches[::Yuki::Sw::EV_AccroBike]
          enter_in_acro_bike_state
        else
          enter_in_walking_state
        end
      end
    end
  end
  # Update the locked state
  def update_locked_state()
  end
  public
  # @return [Hash{map_id=>Array<map_id, offset_x, offset_y>}] list of falling hole info 
  FALLING_HOLES = {13 => [13, 1, 0]}
  # Function that makes the player warp based on hole data for each map
  def falling_hole_warp
    return unless (hole_data = FALLING_HOLES[$game_map.map_id])
    $game_temp.player_transferring = true
    $game_temp.player_new_map_id = hole_data[0]
    $game_temp.player_new_x = @x + hole_data[1]
    $game_temp.player_new_y = @y + hole_data[2]
    $game_temp.player_new_direction = @direction
  end
end
# Describe the Map processing
class Game_Map
  # The list of ability that decrease the encounter frequency
  ENC_FREQ_DEC = %i[white_smoke quick_feet stench]
  # The list of ability that increase the encounter frequency
  ENC_FREQ_INC = %i[no_guard illuminate arena_trap]
  # Ability that decrese the encounter during hail weather
  ENC_FREQ_DEC_HAIL = [:snow_cloak]
  # Ability that decrese the encounter during sandstorm weather
  ENC_FREQ_DEC_SANDSTORM = [:sand_veil]
  # Audiofile to play when the player is on mach bike
  # @return [RPG::AudioFile]
  MACH_BIKE_BGM = RPG::AudioFile.new('09 Bicycle', 100, 100)
  # Audiofile to play when the player is on acro bike
  # @return [RPG::AudioFile]
  ACRO_BIKE_BGM = MACH_BIKE_BGM.clone
  # If the Path Finding system is enabled
  PATH_FINDING_ENABLED = true
  # If the player is always on the center of the screen
  CenterPlayer = Configs.display.is_player_always_centered
  # Number of tiles the player can see in x
  NUM_TILE_VIEW_Y = 15
  # Number of tiles the player can see in y
  NUM_TILE_VIEW_X = 20
  attr_accessor :tileset_name
  # タイルセット ファイル名
  attr_accessor :autotile_names
  # オートタイル ファイル名
  attr_accessor :panorama_name
  # パノラマ ファイル名
  attr_accessor :panorama_hue
  # パノラマ 色相
  attr_accessor :fog_name
  # フォグ ファイル名
  attr_accessor :fog_hue
  # フォグ 色相
  attr_accessor :fog_opacity
  # フォグ 不透明度
  attr_accessor :fog_blend_type
  # フォグ ブレンド方法
  attr_accessor :fog_zoom
  # フォグ 拡大率
  attr_accessor :fog_sx
  # フォグ SX
  attr_accessor :fog_sy
  # フォグ SY
  attr_accessor :battleback_name
  # バトルバック ファイル名
  attr_accessor :display_x
  # 表示 X 座標 * 128
  attr_accessor :display_y
  # 表示 Y 座標 * 128
  attr_accessor :need_refresh
  # リフレッシュ要求フラグ
  attr_reader :passages
  # 通行 テーブル
  attr_reader :priorities
  # プライオリティ テーブル
  attr_reader :terrain_tags
  # 地形タグ テーブル
  # @return [Hash{Integer => Game_Event}] all the living events
  attr_reader :events
  # Return the hash of symbol associate to event id
  # @return [Hash<Symbol, Integer>]
  attr_accessor :events_sym_to_id
  attr_reader :fog_ox
  # フォグ 原点 X 座標
  attr_reader :fog_oy
  # フォグ 原点 Y 座標
  attr_reader :fog_tone
  # フォグ 色調
  # @return [Boolean] if the maplinker was disabled when the map was setup
  attr_reader :maplinker_disabled
  # Initialize the default Game_Map object
  def initialize
    @map_id = 0
    @display_x = 0
    @display_y = 0
    @maplinker_disabled = false
  end
  # setup the Game_Map object with the right Map data
  # @param map_id [Integer] the ID of the map
  def setup(map_id)
    Yuki::ElapsedTime.start(:map_loading)
    @map_id = map_id
    save_events_offset unless @events_info
    @maplinker_disabled = $game_switches[Yuki::Sw::MapLinkerDisabled]
    @map = Yuki::MapLinker.load_map(@map_id)
    Yuki::ElapsedTime.show(:map_loading, 'MapLinker.load_map took')
    load_systemtags
    tileset = $data_tilesets[@map.tileset_id]
    @tileset_name = Yuki::MapLinker.tileset_name
    @autotile_names = tileset.autotile_names
    @panorama_name = tileset.panorama_name
    @panorama_hue = tileset.panorama_hue
    @fog_name = tileset.fog_name
    @fog_hue = tileset.fog_hue
    @fog_opacity = tileset.fog_opacity
    @fog_blend_type = tileset.fog_blend_type
    @fog_zoom = tileset.fog_zoom
    @fog_sx = tileset.fog_sx
    @fog_sy = tileset.fog_sy
    @battleback_name = tileset.battleback_name
    @passages = tileset.passages
    @priorities = tileset.priorities
    @passages[0] = 0
    @priorities[0] = 5
    @terrain_tags = tileset.terrain_tags
    @display_x = 0
    @display_y = 0
    @need_refresh = false
    env = $env
    @events = {}
    @events_sym_to_id = {player: -1}
    @map.events.each do |i, event|
      next if env.get_event_delete_state(i)
      event.name.force_encoding(Encoding::UTF_8)
      e = @events[i] = Game_Event.new(@map_id, event)
      if e.sym_alias
        log_error("Alias #{e.sym_alias} appear multiple time in the map #{@map_id}.\n	Please use uniq aliases.") if @events_sym_to_id.key?(e.sym_alias)
        @events_sym_to_id[e.sym_alias] = i
      end
    end
    load_events
    load_following_events
    Yuki::ElapsedTime.show(:map_loading, 'Loading events took')
    @common_events = {}
    1.upto($data_common_events.size - 1) do |i|
      @common_events[i] = Game_CommonEvent.new(i)
    end
    Yuki::ElapsedTime.show(:map_loading, 'Loading common events took')
    @fog_ox = 0
    @fog_oy = 0
    @fog_tone = Tone.new(0, 0, 0, 0)
    @fog_tone_target = Tone.new(0, 0, 0, 0)
    @fog_tone_duration = 0
    @fog_opacity_duration = 0
    @fog_opacity_target = 0
    @scroll_direction = 2
    @scroll_rest = 0
    @scroll_speed = 4
    load_follower if @next_setup_followers
  end
  # Returns the ID of the Map
  # @return [Integer]
  def map_id
    return @map_id
  end
  # Returns the width of the map
  # @return [Integer]
  def width
    return @map.width
  end
  # Returns the height of the map
  # @return [Integer]
  def height
    return @map.height
  end
  # Returns the encounter list
  # @deprecated Not used by the Core of PSDK because not precise enough to be used
  def encounter_list
    return @map.encounter_list
  end
  # Returns the encounter steps from RMXP data
  # @return [Integer]
  def rmxp_encounter_steps
    @map.encounter_step
  end
  # Returns the encounter step of the map (including ability modifier)
  # @return [Integer] number of step the player must do before each encounter
  def encounter_step
    return rmxp_encounter_steps unless $actors
    ability = $actors[0]&.ability_db_symbol || :__undef__
    return rmxp_encounter_steps / 2 if ENC_FREQ_INC.include?(ability)
    if ENC_FREQ_DEC.include?(ability) || (ENC_FREQ_DEC_HAIL.include?(ability) && $env.hail?) || (ENC_FREQ_DEC_SANDSTORM.include?(ability) && $env.sandstorm?)
      return rmxp_encounter_steps * 2
    end
    return rmxp_encounter_steps
  end
  # Returns the tile matrix of the Map
  # @return [Table] a 3D table containing ids of tile
  def data
    return @map.data
  end
  # Auto play bgm and bgs of the map if defined
  def autoplay
    $game_system.bgm_play(current_bgm) if autoplay_bgm?
    $game_system.bgs_play(current_bgs) if autoplay_bgs?
  end
  # Refresh events and common events of the map
  def refresh
    if @map_id > 0
      @events.each_value(&:refresh)
      @common_events.each_value(&:refresh)
    end
    @need_refresh = false
  end
  # Scrolls the map down
  # @param distance [Integer] distance in y to scroll
  # @param is_priority [Boolean] used if there is a prioratary scroll running
  def scroll_down(distance, is_priority = false)
    return if @scroll_y_priority && !is_priority
    if @maplinker_disabled
      @display_y = (@display_y + distance).clamp(0, (height - NUM_TILE_VIEW_Y) * 128)
    else
      @display_y += distance
    end
  end
  # Scrolls the map left
  # @param distance [Integer] distance in -x to scroll
  # @param is_priority [Boolean] used if there is a prioratary scroll running
  def scroll_left(distance, is_priority = false)
    return if @scroll_x_priority && !is_priority
    if @maplinker_disabled
      @display_x = (@display_x - distance).clamp(0, @display_x)
    else
      @display_x -= distance
    end
  end
  # Scrolls the map right
  # @param distance [Integer] distance in x to scroll
  # @param is_priority [Boolean] used if there is a prioratary scroll running
  def scroll_right(distance, is_priority = false)
    return if @scroll_x_priority && !is_priority
    if @maplinker_disabled
      @display_x = (@display_x + distance).clamp(0, (width - NUM_TILE_VIEW_X) * 128)
    else
      @display_x += distance
    end
  end
  # Scrolls the map up
  # @param distance [Integer] distance in -y to scroll
  # @param is_priority [Boolean] used if there is a prioratary scroll running
  def scroll_up(distance, is_priority = false)
    return if @scroll_y_priority && !is_priority
    if @maplinker_disabled
      @display_y = (@display_y - distance).clamp(0, @display_y)
    else
      @display_y -= distance
    end
  end
  # Tells if the x,y coordinate is valid or not (inside of bounds)
  # @param x [Integer] the x coordinate
  # @param y [Integer] the y coordinate
  # @return [Boolean] if it's valid or not
  def valid?(x, y)
    return ((x >= 0) && (x < width) && (y >= 0) && (y < height))
  end
  # Tells if the tile front/current tile is passsable or not
  # @param x [Integer] x position on the Map
  # @param y [Integer] y position on the Map
  # @param d [Integer] direction : 2, 4, 6, 8, 0. 0 = current position
  # @param self_event [Game_Event, nil] the "tile" event to ignore
  # @return [Boolean] if the front/current tile is passable
  def passable?(x, y, d, self_event = nil)
    unless valid?(x, y)
      return false
    end
    bit = (1 << (d / 2 - 1)) & 0x0f
    events.each_value do |event|
      if (event.tile_id >= 0) && (event != self_event) && (event.x == x) && (event.y == y) && !event.through
        if @passages[event.tile_id] & bit != 0
          return false
        else
          if @passages[event.tile_id] & 0x0f == 0x0f
            return false
          else
            if @priorities[event.tile_id] == 0
              return true
            end
          end
        end
      end
    end
    2.downto(0) do |i|
      tile_id = data[x, y, i]
      if tile_id.nil?
        return false
      else
        if @passages[tile_id] & bit != 0
          return false
        else
          if @passages[tile_id] & 0x0f == 0x0f
            return false
          else
            if @priorities[tile_id] == 0
              return true
            end
          end
        end
      end
    end
    return true
  end
  # Tells if the tile is a bush tile
  # @param x [Integer] x coordinate of the tile
  # @param y [Integer] y coordinate of the tile
  # @return [Boolean]
  def bush?(x, y)
    if @map_id != 0
      2.downto(0) do |i|
        tile_id = data[x, y, i]
        if tile_id.nil?
          return false
        else
          if @passages[tile_id] & 0x40 == 0x40
            return true
          end
        end
      end
    end
    return false
  end
  # カウンター判定 (no idea, need GTranslate)
  # @param x [Integer] x coordinate of the tile
  # @param y [Integer] y coordinate of the tile
  # @return [Boolean]
  def counter?(x, y)
    if @map_id != 0
      2.downto(0) do |i|
        tile_id = data[x, y, i]
        if tile_id.nil?
          return false
        else
          if @passages[tile_id] & 0x80 == 0x80
            return true
          end
        end
      end
    end
    return false
  end
  # Returns the tag of the tile
  # @param x [Integer] x coordinate of the tile
  # @param y [Integer] y coordinate of the tile
  # @return [Integer, nil] Tag of the tile
  def terrain_tag(x, y)
    if @map_id != 0
      2.downto(0) do |i|
        tile_id = data[x, y, i]
        if tile_id.nil?
          return 0
        else
          if @terrain_tags[tile_id] && (@terrain_tags[tile_id] > 0)
            return @terrain_tags[tile_id]
          end
        end
      end
    end
    return 0
  end
  # Starts a scroll processing
  # @param direction [Integer] the direction to scroll
  # @param distance [Integer] the distance to scroll
  # @param speed [Integer] the speed of the scroll processing
  # @param x_priority [Boolean] true if the scroll is prioritary in x axis, be careful using this
  # @param y_priority [Boolean] true if the scroll is prioritary in y axis, be careful using this
  def start_scroll(direction, distance, speed, x_priority = false, y_priority = false)
    @scroll_direction = direction
    @scroll_rest = distance * 128
    @scroll_speed = speed
    @scroll_x_priority = x_priority
    @scroll_y_priority = y_priority
  end
  # is the map scrolling ?
  # @return [Boolean]
  def scrolling?
    return @scroll_rest > 0
  end
  # Starts a fog tone change process
  # @param tone [Tone] the new tone of the fog
  # @param duration [Integer] the number of frame the tone change will take
  def start_fog_tone_change(tone, duration)
    @fog_tone_target = tone.clone
    @fog_tone_duration = duration
    @fog_tone = @fog_tone_target.clone if @fog_tone_duration == 0
  end
  # Starts a fog opacity change process
  # @param opacity [Integer] the new opacity of the fog
  # @param duration [Integer] the number of frame the opacity change will take
  def start_fog_opacity_change(opacity, duration)
    @fog_opacity_target = opacity * 1.0
    @fog_opacity_duration = duration
    @fog_opacity = @fog_opacity_target if @fog_opacity_duration == 0
  end
  # Update the Map processing
  def update
    Pathfinding.update if PATH_FINDING_ENABLED
    refresh if $game_map.need_refresh
    if @scroll_rest > 0
      distance = 2 ** @scroll_speed
      case @scroll_direction
      when 2
        scroll_down(distance, @scroll_y_priority)
      when 4
        scroll_left(distance, @scroll_x_priority)
      when 6
        scroll_right(distance, @scroll_x_priority)
      when 8
        scroll_up(distance, @scroll_y_priority)
      end
      @scroll_rest -= distance
      @scroll_y_priority = @scroll_x_priority = nil unless scrolling?
    end
    @events.each_value(&:update)
    @common_events.each_value(&:update)
    @fog_ox -= @fog_sx / 8.0
    @fog_oy -= @fog_sy / 8.0
    if @fog_tone_duration >= 1
      d = @fog_tone_duration
      target = @fog_tone_target
      @fog_tone.red = (@fog_tone.red * (d - 1) + target.red) / d
      @fog_tone.green = (@fog_tone.green * (d - 1) + target.green) / d
      @fog_tone.blue = (@fog_tone.blue * (d - 1) + target.blue) / d
      @fog_tone.gray = (@fog_tone.gray * (d - 1) + target.gray) / d
      @fog_tone_duration -= 1
    end
    if @fog_opacity_duration >= 1
      d = @fog_opacity_duration
      @fog_opacity = (@fog_opacity * (d - 1) + @fog_opacity_target) / d
      @fog_opacity_duration -= 1
    end
  end
  private
  # Return the current Autoplay BGM state
  # @return [Boolean]
  def autoplay_bgm?
    @map.autoplay_bgm || $game_player.cycling?
  end
  # Return the current Autoplay BGS state
  # @return [Boolean]
  def autoplay_bgs?
    @map.autoplay_bgs
  end
  # Return the current BGM to play
  # @return [RPG::AudioFile]
  def current_bgm
    cycling_bgm || @map.bgm
  end
  # Return the current BGS to play
  # @return [RPG::AudioFile]
  def current_bgs
    @map.bgs
  end
  # Get the cycle audio file matching the current bike or nil
  # @return [RPG::AudioFile, nil]
  def cycling_bgm
    return nil unless $game_player.cycling?
    return ACRO_BIKE_BGM if $game_player.on_acro_bike
    return MACH_BIKE_BGM
  end
  public
  # Regular expression catching follower id
  FOLLOWER_ID_REGEXP = /\[follow=([0-9]+)\]/
  # If an event has been erased (helps removing it)
  # @return [Boolean]
  attr_accessor :event_erased
  # Retrieve the ID of the SystemTag on a specific tile
  # @param x [Integer] x position of the tile
  # @param y [Integer] y position of the tile
  # @return [Integer]
  # @author Nuri Yuri
  def system_tag(x, y)
    return Yuki::MapLinker.system_tag(x, y) unless valid?(x, y)
    if @map_id != 0
      tiles = data
      2.downto(0) do |i|
        tile_id = tiles[x, y, i]
        return 0 unless tile_id
        tag_id = @system_tags[tile_id]
        return tag_id if tag_id && tag_id > 0
      end
    end
    return 0
  end
  # Check if a specific SystemTag is present on a specific tile
  # @param x [Integer] x position of the tile
  # @param y [Integer] y position of the tile
  # @param tag [Integer] ID of the SystemTag
  # @return [Boolean]
  # @author Nuri Yuri
  def system_tag_here?(x, y, tag)
    return Yuki::MapLinker.system_tag_here?(x, y) unless valid?(x, y)
    if @map_id != 0
      tiles = data
      2.downto(0) do |i|
        tile_id = tiles[x, y, i]
        next unless tile_id
        return true if @system_tags[tile_id] == tag
      end
    end
    return false
  end
  # Loads the SystemTags of the map
  # @author Nuri Yuri
  def load_systemtags
    $data_system_tags[@map.tileset_id] ||= Array.new($data_tilesets[@map.tileset_id].priorities.xsize, 0)
    @system_tags = $data_system_tags[@map.tileset_id]
  end
  # Retrieve the id of a specific tile
  # @param x [Integer] x position of the tile
  # @param y [Integer] y position of the tile
  # @return [Integer] id of the tile
  # @author Nuri Yuri
  def get_tile(x, y)
    2.downto(0) do |i|
      tile = data[x, y, i]
      return tile if tile && tile > 0
    end
    return 0
  end
  # Check if the player can jump a case with the acro bike
  # @param x [Integer] x position of the tile
  # @param y [Integer] y position of the tile
  # @param d [Integer] the direction of the player
  # @return [Boolean]
  # @author Nuri Yuri
  def jump_passable?(x, y, d)
    z = $game_player.z
    new_x = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    new_y = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
    sys_tag = system_tag(new_x, new_y)
    systemtags = GameData::SystemTags
    if z <= 1 && (system_tag(x, y) == systemtags::AcroBike || sys_tag == systemtags::AcroBike)
      return true
    else
      if z > 1 && (Game_Player::AccroTag.include?(sys_tag) || sys_tag == systemtags::BridgeUD)
        return true
      end
    end
    case d
    when 2
      new_d = 8
    when 6
      new_d = 4
    when 4
      new_d = 6
    else
      new_d = 2
    end
    unless valid?(x, y) && valid?(new_x, new_y)
      return false
    end
    bit = (1 << (d / 2 - 1)) & 0x0f
    bit2 = (1 << (new_d / 2 - 1)) & 0x0f
    2.downto(0) do |i|
      tile_id = data[x, y, i]
      tile_id2 = data[new_x, new_y, i]
      if @passages[tile_id] & bit != 0 || @passages[tile_id2] & bit2 != 0
        return false
      else
        if @priorities[tile_id] == 0
          return true
        end
      end
    end
    return true
  end
  # Return the current location type
  # @return [Symbol]
  def location_type(x, y)
    zone = $env.current_zone_data
    location = zone.global_location_type if zone.respond_to?(:global_location_type)
    location ||= TERRAIN_TAGS_TABLE.select { |tag, _location| system_tag_here?(x, y, tag) }.values[0]
    location ||= zone.default_location_type if zone.respond_to?(:default_location_type)
    location ||= :__undef__
    return location
  end
  # Convert terrain tag to location symbol
  # @return [Hash<Integer, Symbol>]
  TERRAIN_TAGS_TABLE = {GameData::SystemTags::TGrass => :grass, GameData::SystemTags::TTallGrass => :grass, GameData::SystemTags::HeadButt => :grass, GameData::SystemTags::TSnow => :snow, GameData::SystemTags::TPond => :shallow_water, GameData::SystemTags::TWetSand => :shallow_water, GameData::SystemTags::SwampBorder => :shallow_water, GameData::SystemTags::DeepSwamp => :shallow_water, GameData::SystemTags::TSand => :desert, GameData::SystemTags::TCave => :cave, GameData::SystemTags::TMount => :cave, GameData::SystemTags::TIce => :icy_cave, GameData::SystemTags::TSea => :water, GameData::SystemTags::WaterFall => :water, GameData::SystemTags::RapidsL => :water, GameData::SystemTags::RapidsD => :water, GameData::SystemTags::RapidsU => :water, GameData::SystemTags::RapidsR => :water}
  # List of variable to remove in order to keep the map data safe
  IVAR_TO_REMOVE_FROM_SAVE_FILE = %i[@map @tileset_name @autotile_names @panorama_name @panorama_hue @fog_name @fog_hue @fog_opacity @fog_blend_type @fog_zoom @fog_sx @fog_sy @battleback_name @passages @priorities @terrain_tags @events @common_events @system_tags]
  # Method that prevent non wanted data save of the Game_Map object
  # @author Nuri Yuri
  def begin_save
    Pathfinding.save
    save_follower
    save_events
    arr = []
    IVAR_TO_REMOVE_FROM_SAVE_FILE.each do |ivar_name|
      arr << instance_variable_get(ivar_name)
      remove_instance_variable(ivar_name)
    end
    arr << $game_player.follower
    $game_player.instance_variable_set(:@follower, nil)
    $TMP_MAP_DATA = arr
  end
  # Method that end the save state of the Game_Map object
  # @author Nuri Yuri
  def end_save
    arr = $TMP_MAP_DATA
    IVAR_TO_REMOVE_FROM_SAVE_FILE.each_with_index do |ivar_name, index|
      instance_variable_set(ivar_name, arr[index])
    end
    $game_player.instance_variable_set(:@follower, arr.last)
    unsave_followers
    @events_info = nil
  end
  private
  # Method that save the Follower Event of the player
  def save_follower
    return unless $game_player.follower.is_a?(Game_Event)
    @next_setup_followers = []
    follower = $game_player
    while (follower = follower.follower).is_a?(Game_Event)
      @next_setup_followers << follower.id
    end
  end
  # Method that load the follower Event of the player when the map is loaded
  def load_follower
    $game_player.reset_follower
    x = $game_player.x
    y = $game_player.y
    @next_setup_followers.each do |id|
      next unless (event = @events[id])
      event.moveto(x, y)
      $game_player.set_follower(event)
    end
    unsave_followers
  end
  # Method that un-save the followers
  def unsave_followers
    remove_instance_variable(:@next_setup_followers) if @next_setup_followers
  end
  # Method that save the event position, direction & move_route info
  def save_events
    return unless @events
    @events_info = {}
    @events.each_value do |event|
      next if event.original_map != @map_id
      index = event.instance_variable_get(:@move_route_index)
      @events_info[event.original_id] = [event.x, event.y, event.z, event.direction, index, event.__bridge]
    end
    @events_info[:player] = $game_player.z
  end
  # Method that save the events & fix the event offset added by the MapLinker
  def save_events_offset
    return unless @events
    @events_info = {}
    ml_ox = Yuki::MapLinker.current_OffsetX
    ml_oy = Yuki::MapLinker.current_OffsetY
    @events.each_value do |event|
      next if event.original_map != @map_id
      event_data = event.event
      index = event.instance_variable_get(:@move_route_index)
      x = event.x - event_data.offset_x.to_i + ml_ox
      y = event.y - event_data.offset_y.to_i + ml_oy
      @events_info[event.original_id] = [x, y, event.z, event.direction, index, event.__bridge]
    end
    @events_info[:player] = $game_player.z
  end
  # Method that load the event
  def load_events
    return unless @events_info
    $game_player.z = @events_info[:player]
    return if PSDK_CONFIG.debug? && $game_system.magic_number != $data_system.magic_number
    @events_info.each do |id, info|
      next unless (event = @events[id])
      next unless event.original_map == @map_id
      event.moveto(info[0], info[1])
      event.z = info[2]
      event.direction = info[3]
      event.instance_variable_set(:@move_route_index, info[4])
      event.__bridge = info[5]
      event.clear_starting
      event.check_event_trigger_auto
    end
  ensure
    $game_player.check_event_trigger_here([1, 2])
    @events_info = nil
    $game_system.magic_number = $data_system.magic_number
  end
  # Function that loads the events that are following
  def load_following_events
    @events.each do |i, event|
      next unless event
      next unless (match = event.event.name.match(FOLLOWER_ID_REGEXP))
      follow_id = match.captures.first.to_i
      next if follow_id == i
      @events[follow_id]&.set_follower(event)
    end
  end
end
module Pathfinding
  # Amount of node to calculate in one frame (OPTIMISATION)
  OPERATION_PER_FRAME = 150
  # Amount of node by requests in one frame (OPTIMISATION)
  OPERATION_PER_REQUEST = 50
  # Cost of the reload
  COST_RELOAD = 15
  # Cost of the watch
  COST_WATCH = 9
  # Cost of the wait
  COST_WAIT = 1
  # Obstacle detection range
  OBSTACLE_DETECTION_RANGE = 9
  # Amount of try count
  TRY_COUNT = 5
  # Number of frame before two path search when the first one fail
  TRY_DELAY = 60
  # Directions to check
  PATH_DIRS = [1, 2, 3, 4]
  # Move route when waiting for a new path
  WAITING_ROUTE = RPG::MoveRoute.new
  WAITING_ROUTE.list.unshift(RPG::MoveCommand.new(15, 1))
  # Weight of the tags, the higher is the cost, the more the path will avoid it
  TAGS_WEIGHT = {GameData::SystemTags::Road => 2, GameData::SystemTags::TSand => 4, GameData::SystemTags::SwampBorder => 20, GameData::SystemTags::DeepSwamp => 30, GameData::SystemTags::MachBike => 1000, GameData::SystemTags::TGrass => 20}
  TAGS_WEIGHT.default = 10
  # Grass, ...
  # module that contains the tags weight for path calculation
  module TagsWeight
    include GameData::SystemTags
    # Default tags weight
    DEFAULT = Pathfinding::TAGS_WEIGHT
    # Test tage weight
    WILD_POKEMON = Hash.new(10)
    WILD_POKEMON[TGrass] = 2
    WILD_POKEMON[Road] = 100
    WILD_POKEMON[TSand] = 100
  end
  # Default save state
  DEFAULT_SAVE = []
  @requests = []
  @operation_per_frame = OPERATION_PER_FRAME
  @last_request_id = 0
  # Method giving a preset command (the 5 first move commands)
  PRESET_COMMANDS = Array.new(5) { |i| RPG::MoveCommand.new(i) }.method(:[])
  # Add the request to the system list and start looking for path
  # @param character [Game_Character] the character looking for a path
  # @param target [Game_Character, Array<Integer>] character or coords to reach
  # @param tries [Integer] the number of tries before giving up the path research. :infinity for infinite try count.
  # @param tags [Symbol] the name of the Pathfinding::TagsWeight constant to use to calcultate the node weight
  # @return [Boolean] if the request is successfully submitted
  def self.add_request(character, target, tries, tags)
    remove_request(character)
    @requests.push Request.new(character, Target.get(*target), tries, tags)
    return true
  end
  # Remove the request from the system list and return true if the request has been popped out.
  # @param character [Game_Character] the character to pop out
  # @return [Boolean] if the request has been popped out
  def self.remove_request(character)
    debug_clear(character.id)
    old_length = @requests.length
    @requests.delete_if { |e| e.character == character }
    @last_request_id = 0
    return (old_length > @requests.length)
  end
  # CLear all the requests
  def self.clear
    debug_clear
    @requests.clone.each { |request| remove_request(request.character) }
  end
  # Set the number of operation per frame. By default it's 150, be careful with the performance issues.
  # @param value [Integer] the new amount of operation allowed per frame
  def self.operation_per_frame=(value)
    @operation_per_frame = value
  end
  # Update the pathfinding system
  def self.update
    debug_update
    return if @requests.empty?
    request_id = @last_request_id
    operation_counter = 0
    first_update = true
    need_update = true
    while operation_counter < @operation_per_frame
      operation_counter += (current_request = @requests[request_id]).update(operation_counter, first_update)
      need_update ||= current_request.need_update
      current_request.character.stop_path if current_request.finished?
      next unless (request_id += 1) >= @requests.length
      request_id = 0
      break if !need_update || @requests.empty?
      first_update = false
      need_update = false
    end
    @last_request_id = request_id
  end
  # Create an savable array of the current requests
  # @return [Array<Pathfinding::Request>]
  def self.save
    PFM.game_state.pathfinding_requests = @requests.collect(&:save)
  end
  # Load the data from the Game State
  def self.load
    return unless Game_Map::PATH_FINDING_ENABLED
    data = PFM.game_state.pathfinding_requests
    @requests = data.collect { |d| Request.load(d) }
    @requests.delete(nil)
  end
  @debug = false
  # Enable or disable the debug mode
  # @param value [Boolean] if debug must be enabled
  def self.debug=(value)
    @debug = value
    if value && @debug_viewport.nil?
      @debug_viewport = Viewport.create(:main, 50_000)
      @debug_sprites = {}
      @debug_bitmap = RPG::Cache.animation('pathfinding_debug', 0)
      @debug_sprites_pool = []
    end
    if !value && @debug_viewport
      debug_clear
      @debug_sprites_pool.each(&:dispose)
      @debug_sprites_pool = []
      @debug_viewport.dispose
      @debug_viewport = nil
    end
  end
  # Clear the pathfinding debug data
  # @param from [Integer, nil] the id of the caracter to clear, if nil, clear all
  def self.debug_clear(from = nil)
    return unless @debug
    if from.nil?
      @debug_sprites.values.flatten.each do |s|
        s.visible = false
        @debug_sprites_pool.push s
      end
      @debug_sprites.clear
    else
      if @debug_sprites.key?(from)
        @debug_sprites[from].each do |s|
          s.visible = false
          @debug_sprites_pool.push s
        end
        @debug_sprites.delete(from)
      end
    end
  end
  # Update the pathfinding display debug
  def self.debug_update
    return unless @debug
    @debug_viewport.ox = $game_map.display_x / 8 - 24
    @debug_viewport.oy = $game_map.display_y / 8 - 16
  end
  # Add a path to display
  # @param from [Game_Character] the character who follow the path
  # @param cursor [Cursor] the cursor used to calculate the path
  # @param path [Array<Integer>] the list of moveroute command
  def self.debug_add(from, cursor, path)
    return unless @debug
    debug_clear(from.id)
    sprites = []
    x = from.x
    y = from.y
    z = from.z
    path.each_with_index do |dir, index|
      code = [dir - 1, 0, 4, 3]
      code = [dir - 1, 1, 4, 3] if index == 0
      sprites.push s = (@debug_sprites_pool.pop || Sprite.new(@debug_viewport).set_bitmap(@debug_bitmap)).set_rect_div(*code).set_position(x * 16 - 24, y * 16 - 16)
      s.visible = true
      cursor.sim_move?(x, y, z, dir)
      x = cursor.x
      y = cursor.y
      z = cursor.z
    end
    sprites.push s = (@debug_sprites_pool.pop || Sprite.new(@debug_viewport).set_bitmap(@debug_bitmap)).set_rect_div(0, 2, 4, 3).set_position(x * 16 - 24, y * 16 - 16)
    s.visible = true
    @debug_sprites[from.id] = sprites
  end
  #-------------------------------------------
  # Class that describe a pathfinding request
  #   A request has three caracteristics :
  #   - Character : the character summonning the request
  #   - Target : the target to reach
  #   - Priority : The priority of the request between others
  #
  # Algorithm steps
  # 1st step : Initialization
  #   Creation of the variables (#initialize)
  # 2nde step: Search
  #   Calculate NODES_PER_FRAME nodes per frame to optimize the process (#update_search)
  #   Nodes are calculated in #calculate_node with A* algorithm
  #   Once a path is found, or all possibilies are studied, the request start watching
  # 3rd step : Watch
  #   The Request look for obstacles on the path and restart the search (reload) if there is one
  class Request
    # The character which needs a path
    # @return [Game_Character]
    attr_reader :character
    # Indicate if the request needs update or not
    # @return [Boolean]
    attr_reader :need_update
    # Create the request
    # @param character [Game_Character] the character to give a path
    # @param target [Target] the target data
    # @param tries [Integer, Symbol] the amount of tries allowed before fail, use :infinity to have unlimited tries
    # @param tags [Symbol] the name of the Pathfinding::TagsWeight constant to use to calcultate the node weight
    def initialize(character, target, tries, tags)
      log_debug "Character \##{character.id} request created."
      @character = character
      @target = target
      @state = :search
      @cursor = Cursor.new(character)
      @open = [[0, character.x, character.y, character.z, @cursor.state, -1]]
      @closed = Table32.new($game_map.width, $game_map.height, 7)
      @character.path = :pending
      @remaining_tries = @original_remaining_tries = tries
      @need_update = true
      @tags = tags
      @tags_weight = (Pathfinding::TagsWeight.const_defined?(tags) ? Pathfinding::TagsWeight.const_get(tags) : Pathfinding::TagsWeight::DEFAULT)
      Pathfinding.debug_clear(character.id)
    end
    # Indicate if the request is search for path
    # @return [Boolean]
    def searching?
      return @state == :search
    end
    # Indicate if the request is watching for obstacle
    # @return [Boolean]
    def waiting?
      return @state == :wait
    end
    # Inidicate if the request is waiting for new try
    # @return [Boolean]
    def watching?
      return @state == :watch
    end
    # Indicate if the request is to reload
    # @return [Boolean]
    def reload?
      return @state == :reload
    end
    # Indicate if the request is ended
    # @return [Boolean]
    def finished?
      return @character.path.nil?
    end
    # Update the requests and return the number of performed actions
    # @param operation_counter [Integer] the amount of operation left
    # @param is_first_update [Boolean] indicate if it's the first update of the frame
    # @return [Integer]
    def update(operation_counter, is_first_update)
      @need_update ||= is_first_update
      case @state
      when :search
        return update_search(operation_counter)
      when :watch
        return update_watch(is_first_update)
      when :reload
        return update_reload(is_first_update)
      when :wait
        return update_wait(is_first_update)
      else
        return 1
      end
    end
    # Update the request search and return the new remaining node count
    # @param operation_counter [Integer] the amount of node per frame remaining
    # @return [Integer]
    def update_search(operation_counter)
      if @target.reached?(@character.x, @character.y, @character.z)
        @state = :watch
        return 1
      else
        if @target.check_move(@character.x, @character.y)
          @state = :reload
          return 1
        end
      end
      nodes = 0
      nodes_max = operation_counter > OPERATION_PER_REQUEST ? OPERATION_PER_REQUEST : operation_counter
      result = nil
      while nodes < nodes_max && !result
        result = calculate_node
        nodes += 1
      end
      process_result(result)
      return nodes + 1
    end
    # Process the result of the node calculation
    # @param result [Array<Integer>, nil, Symbol] the result value
    def process_result(result)
      if result == :not_found
        if @remaining_tries == :infinity || (@remaining_tries -= 1) > 0
          log_debug "Character \##{@character.id} fail to found path. Retrying..."
          @state = :wait
          @retry_countdown = TRY_DELAY
        else
          log_debug "Character \##{@character.id} fail to found path"
          @character.stop_path
        end
      else
        if result
          @remaining_tries = @original_remaining_tries
          @state = :watch
          send_path(result)
        end
      end
    end
    # Update the request when looking for obstacles
    def update_watch(is_first_update)
      return 1 unless is_first_update
      if @character.real_x % 128 + @character.real_y % 128 == 0
        if @target.check_move(@character.x, @character.y)
          log_debug "Character \##{@character.id}'s target has moved"
          @state = :reload
          return 1
        end
        if stucked?
          log_debug "Character \##{@character.id} is stucked"
          @state = :reload
        else
          if @target.reached?(@character.x, @character.y, @character.z)
            log_debug "Character \##{@character.id} reached the target"
            @character.stop_path
          end
        end
      end
      @need_update = false
      return COST_WATCH
    end
    # Update the request when waiting before retrying to find path
    def update_wait(is_first_update)
      return 1 unless is_first_update
      @retry_countdown -= 1
      @state = :reload if @retry_countdown <= 0
      @need_update = false
      return COST_WAIT
    end
    # Reload the request
    def update_reload(is_first_update)
      return 1 unless is_first_update
      log_debug "Character \##{@character.id} reload request"
      @character.path = :pending
      @open.clear
      @open.push [0, character.x, character.y, character.z, @cursor.state, -1]
      @closed.resize(0, 0, 0)
      @closed.resize($game_map.width, $game_map.height, 7)
      @state = :search
      return COST_RELOAD
    end
    # Make the character following the found path
    # @param path [Array<Integer>] The path, list of move direction
    def send_path(path)
      log_debug "Character \##{@character.id} found a path"
      Pathfinding.debug_add(@character, @cursor, path)
      @character.define_path((path << 0).collect(&PRESET_COMMANDS))
    end
    # Detect if the character is stucked
    # @return [Boolean]
    def stucked?
      route = @character.path
      return true unless route.is_a?(Array)
      route_index = @character.move_route_index
      x = @character.x
      y = @character.y
      z = @character.z
      b = @character.__bridge
      route[route_index..[route.length - 2, route_index + OBSTACLE_DETECTION_RANGE - 1].min]&.each do |command|
        return true unless @cursor.sim_move?(x, y, z, command.code, b)
        x = @cursor.x
        y = @cursor.y
        z = @cursor.z
        b = @cursor.__bridge
      end
      return false
    end
    # Calculate a node and return it if a path is found
    # @return [Object]
    def calculate_node
      return :not_found if (open = @open).empty?
      target = @target
      cursor = @cursor
      game_map = $game_map
      tags_weight = @tags_weight
      node = open.shift
      (closed = @closed)[node[1], node[2], node[3]] = node[5]
      PATH_DIRS.each do |direction|
        next unless cursor.sim_move?(node[1], node[2], node[3], direction, *node[4])
        if target.reached?(kx = cursor.x, ky = cursor.y, kz = cursor.z)
          closed[kx, ky, kz] = direction | node[1] << 4 | node[2] << 14 | node[3] << 24
          return backtrace(kx, ky, kz)
        end
        next unless closed[kx, ky, kz] == 0 && open.select { |a| a[1] == kx && a[2] == ky && a[3] == kz }.empty?
        cost = node.first + tags_weight[game_map.system_tag(kx, ky)] - ((node[5] & 0xF) == direction ? 1 : 0)
        backtrace_move = direction | node[1] << 4 | node[2] << 14 | node[3] << 24
        if open.empty?
          open[0] = [cost, kx, ky, kz, cursor.state, backtrace_move]
        else
          index = 0
          index += 1 while index < open.length && open[index].first < cost
          open.insert(index, [cost, kx, ky, kz, cursor.state, backtrace_move])
        end
      end
      return nil
    end
    # Calculate the path from the given node
    # @param tx [Integer] target x?
    # @param ty [Integer] target y?
    # @param tz [Integer] target z?
    # @return [Array<Integer>] the path
    def backtrace(tx, ty, tz)
      x = tx
      y = ty
      z = tz
      closed = @closed
      path = []
      code = closed[x, y, z]
      until code == -1
        path.unshift code & 0xF
        x = (code >> 4) & 0x3FF
        y = (code >> 14) & 0x3FF
        z = (code >> 24) & 0xF
        code = closed[x, y, z]
      end
      return path
    end
    # Gather the data ready to be saved
    # @return [Array<Object>]
    def save
      return [@character.id, @target.save, @original_remaining_tries, @tags]
    end
    # (Class method) Load the requests from the given argument
    # @param data [Array<Object>] the data generated by the save method
    def self.load(data)
      character = $game_map.events[data[0]]
      target = Target.load(data[1])
      tries = data[2]
      tags = data[3] || :DEFAULT
      return nil unless character && target && tries
      return Request.new(character, target, tries, tags)
    end
  end
  #-------------------------------------------
  # Class that describe and manipulate the simili character used in pathfinding
  class Cursor
    include GameData::SystemTags
    # SystemTags that trigger Surfing
    SurfTag = Game_Character::SurfTag
    # SystemTags that does not trigger leaving water
    SurfLTag = Game_Character::SurfLTag
    # SystemTags that triggers "sliding" state
    SlideTags = [TIce, RapidsL, RapidsR, RapidsU, RapidsD, RocketL, RocketU, RocketD, RocketR, RocketRL, RocketRU, RocketRD, RocketRR]
    # Array used to detect if a character is on a bridge tile
    BRIDGE_TILES = [BridgeRL, BridgeUD]
    attr_reader :x
    attr_reader :y
    attr_reader :z
    attr_reader :__bridge
    def initialize(character)
      @character = character
      @__bridge = character.__bridge
      @through = character.through
      @x = character.x
      @y = character.y
      @z = character.z
      @direction = character.direction
      @character_name = character.character_name
    end
    # Get the current state of the cursor
    def state
      return [@__bridge, @sliding, @surfing]
    end
    # Simulate the mouvement of the character and store the data into cursor's attributes
    # @param sx [Integer] start coords X
    # @param sy [Integer] start coords Y
    # @param sz [Integer] start coords z
    # @param code [Integer] mouvement's code
    # @param b [Array, nil] bridge metadata
    # @param slide [Boolean] slide meta data
    # @param surf [Boolean] surf meta data
    # @return [Boolean]
    def sim_move?(sx, sy, sz, code, b = @__bridge, slide = @sliding, surf = @surfing)
      moveto(sx, sy)
      @z = sz
      @__bridge = b
      @sliding = slide
      @surfing = surf
      case code
      when 1
        move_down
      when 2
        move_left
      when 3
        move_right
      when 4
        move_up
      end
      return (@x != sx || @y != sy)
    end
    private
    # Warps the character on the Map to specific coordinates.
    # Adjust the z position of the character.
    # @param x [Integer] new x position of the character
    # @param y [Integer] new y position of the character
    def moveto(x, y)
      @x = x
      @y = y
    end
    # Move Game_Character down
    def move_down
      @direction = 2
      if passable?(@x, @y, 2)
        if $game_map.system_tag(@x, @y + 1) == JumpD
          jump(0, 2)
          return
        end
        bridge_down_check(@z)
        @y += 1
        movement_process_end
      else
        @sliding = false
      end
    end
    # Move Game_Character left
    def move_left
      @direction = 4
      return if stair_move_left
      y_modifier = slope_check_left
      if passable?(@x, @y, 4)
        if $game_map.system_tag(@x - 1, @y) == JumpL
          jump(-2, 0)
          return
        end
        bridge_left_check(@z)
        @x -= 1
        @y += y_modifier
        movement_process_end
      else
        @sliding = false
      end
    end
    # Try to move the Game_Character on a stair to the left
    # @return [Boolean] if the player cannot perform a regular movement (success or blocked)
    def stair_move_left
      if front_system_tag == StairsL
        return true unless $game_map.system_tag(@x - 1, @y - 1) == StairsL
        move_upper_left
        return true
      else
        if system_tag == StairsR
          move_lower_left
          return true
        end
      end
      return false
    end
    # Update the slope values when moving to left
    def slope_check_left
      front_sys_tag = front_system_tag
      return 0 unless (sys_tag = system_tag) == SlopesL || sys_tag == SlopesR || front_sys_tag == SlopesL || front_sys_tag == SlopesR
      if sys_tag == SlopesL && front_sys_tag != SlopesL
        return -1
      else
        if sys_tag != SlopesR && front_sys_tag == SlopesR
          return 1
        end
      end
      return 0
    end
    # Move Game_Character right
    def move_right
      @direction = 6
      return if stair_move_right
      y_modifier = slope_check_right
      if passable?(@x, @y + y_modifier, 6)
        if $game_map.system_tag(@x + 1, @y) == JumpL
          jump(2, 0)
          return
        end
        bridge_left_check(@z)
        @x += 1
        @y += y_modifier
        movement_process_end
      else
        @sliding = false
      end
    end
    # Try to move the Game_Character on a stair to the right
    # @return [Boolean] if the player cannot perform a regular movement (success or blocked)
    def stair_move_right
      if system_tag == StairsL
        move_lower_right
        return true
      else
        if front_system_tag == StairsR
          return true unless $game_map.system_tag(@x + 1, @y - 1) == StairsR
          move_upper_right
          return true
        end
      end
      return false
    end
    # Update the slope values when moving to right, and return y slope modifier
    # @return [Integer]
    def slope_check_right
      front_sys_tag = front_system_tag
      return 0 unless (sys_tag = system_tag) == SlopesL || sys_tag == SlopesR || front_sys_tag == SlopesL || front_sys_tag == SlopesR
      if sys_tag == SlopesR && front_sys_tag != SlopesR
        return -1
      else
        if sys_tag != SlopesL && front_sys_tag == SlopesL
          return 1
        end
      end
      return 0
    end
    # Move Game_Character up
    def move_up
      @direction = 8
      if passable?(@x, @y, 8)
        if $game_map.system_tag(@x, @y - 1) == JumpD
          jump(0, -2)
          return
        end
        bridge_down_check(@z)
        @y -= 1
        movement_process_end
      else
        @sliding = false
      end
    end
    # Move the Game_Character lower left
    def move_lower_left
      @direction = @direction == 6 ? 4 : (@direction == 8 ? 2 : @direction)
      if (passable?(@x, @y, 2) && passable?(@x, @y + 1, 4)) || (passable?(@x, @y, 4) && passable?(@x - 1, @y, 2))
        @x -= 1
        @y += 1
        movement_process_end
      end
    end
    # Move the Game_Character lower right
    def move_lower_right
      @direction = (@direction == 4 ? 6 : @direction == 8 ? 2 : @direction)
      if (passable?(@x, @y, 2) && passable?(@x, @y + 1, 6)) || (passable?(@x, @y, 6) && passable?(@x + 1, @y, 2))
        @x += 1
        @y += 1
        movement_process_end
      end
    end
    # Move the Game_Character upper left
    def move_upper_left
      @direction = (@direction == 6 ? 4 : @direction == 2 ? 8 : @direction)
      if (passable?(@x, @y, 8) && passable?(@x, @y - 1, 4)) || (passable?(@x, @y, 4) && passable?(@x - 1, @y, 8))
        @x -= 1
        @y -= 1
        movement_process_end
      end
    end
    # Move the Game_Character upper right
    def move_upper_right
      @direction = (@direction == 4 ? 6 : @direction == 2 ? 8 : @direction)
      if (passable?(@x, @y, 8) && passable?(@x, @y - 1, 6)) || (passable?(@x, @y, 6) && passable?(@x + 1, @y, 8))
        @x += 1
        @y -= 1
        movement_process_end
      end
    end
    # Is the tile in front of the character passable ?
    # @param x [Integer] x position on the Map
    # @param y [Integer] y position on the Map
    # @param d [Integer] direction : 2, 4, 6, 8, 0. 0 = current position
    # @return [Boolean] if the front/current tile is passable
    def passable?(x, y, d)
      new_x = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
      new_y = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
      z = @z
      game_map = $game_map
      return false unless game_map.valid?(new_x, new_y)
      if @through
        return true unless @sliding
        return true if $game_switches[::Yuki::Sw::ThroughEvent]
      end
      sys_tag = game_map.system_tag(new_x, new_y)
      return false unless passable_bridge_check?(x, y, d, new_x, new_y, z, game_map, sys_tag) && passage_surf_check?(sys_tag)
      return false unless event_passable_check?(new_x, new_y, z, game_map)
      if $game_player.contact?(new_x, new_y, z)
        unless $game_player.through
          return false unless @character_name.empty?
        end
      end
      return false unless follower_check?(new_x, new_y, z)
      return true
    end
    # Check the bridge related passabilities
    # @param x [Integer] current x position
    # @param y [Integer] current y position
    # @param d [Integer] current direction
    # @param new_x [Integer] new x position
    # @param new_y [Integer] new y position
    # @param z [Integer] current z position
    # @param game_map [Game_Map] map object
    # @param sys_tag [Integer] current system_tag
    # @return [Boolean] if the tile is passable according to the bridge rules
    def passable_bridge_check?(x, y, d, new_x, new_y, z, game_map, sys_tag)
      bridge = @__bridge
      no_game_map = false
      if z > 1
        if bridge
          return false unless game_map.system_tag_here?(new_x, new_y, bridge[0]) || game_map.system_tag_here?(new_x, new_y, bridge[1]) || game_map.system_tag_here?(x, y, bridge[1])
        end
        case d
        when 2, 8
          no_game_map = true if sys_tag == BridgeUD
        when 4, 6
          no_game_map = true if sys_tag == BridgeRL
        end
      end
      return true if bridge || no_game_map
      return false unless game_map.passable?(x, y, d, self)
      return false unless game_map.passable?(new_x, new_y, 10 - d)
      return true
    end
    # Check the surf related passabilities
    # @param sys_tag [Integer] current system_tag
    # @return [Boolean] if the tile is passable according to the surf rules
    def passage_surf_check?(sys_tag)
      return false if !@surfing && SurfTag.include?(sys_tag)
      if @surfing
        return false unless SurfLTag.include?(sys_tag)
        return false if sys_tag == WaterFall
      end
      return true
    end
    # Check the passage related to events
    # @param new_x [Integer] new x position
    # @param new_y [Integer] new y position
    # @param z [Integer] current z position
    # @return [Boolean] if the tile has no event that block the way
    def follower_check?(new_x, new_y, z)
      unless Yuki::FollowMe.is_player_follower?(@character) || @character == $game_player
        Yuki::FollowMe.each_follower do |event|
          return false if event.contact?(new_x, new_y, z)
        end
      end
      return true
    end
    # Check the passage related to events
    # @param new_x [Integer] new x position
    # @param new_y [Integer] new y position
    # @param z [Integer] current z position
    # @param game_map [Game_Map] map object
    # @return [Boolean] if the tile has no event that block the way
    def event_passable_check?(new_x, new_y, z, game_map)
      game_map.events.each_value do |event|
        next unless event.contact?(new_x, new_y, z)
        return false unless event.through
      end
      return true
    end
    # Make the Game_Character jump
    # @param x_plus [Integer] the number of tile the Game_Character will jump on x
    # @param y_plus [Integer] the number of tile the Game_Character will jump on y
    # @return [Boolean] if the character is jumping
    def jump(x_plus, y_plus)
      jump_bridge_check(x_plus, y_plus)
      new_x = @x + x_plus
      new_y = @y + y_plus
      if (x_plus == 0 && y_plus == 0) || passable?(new_x, new_y, 0) || ($game_switches[::Yuki::Sw::EV_AccroBike] && front_system_tag == AcroBike)
        @x = new_x
        @y = new_y
      end
    end
    # Perform the bridge check for the jump operation
    # @param x_plus [Integer] the number of tile the Game_Character will jump on x
    # @param y_plus [Integer] the number of tile the Game_Character will jump on y
    def jump_bridge_check(x_plus, y_plus)
      return if x_plus == 0 && y_plus == 0
      if x_plus.abs > y_plus.abs
        bridge_left_check(@z)
      else
        bridge_down_check(@z)
      end
    end
    # Adjust the Character informations related to the brige when it moves left (or right)
    # @param z [Integer] the z position
    # @author Nuri Yuri
    def bridge_down_check(z)
      if (z > 1) && !@__bridge
        if (sys_tag = front_system_tag) == BridgeUD
          @__bridge = [sys_tag, system_tag]
        end
      else
        if (z > 1) && @__bridge
          @__bridge = nil if @__bridge.last == system_tag
        end
      end
    end
    alias bridge_up_check bridge_down_check
    # Check bridge information and adjust the z position of the Game_Character
    # @param z [Integer] the z level
    # @author Nuri Yuri
    def bridge_left_check(z)
      if (z > 1) && !@__bridge
        if (sys_tag = front_system_tag) == BridgeRL
          @__bridge = [sys_tag, system_tag]
        end
      else
        if (z > 1) && @__bridge
          @__bridge = nil if @__bridge.last == system_tag
        end
      end
    end
    alias bridge_right_check bridge_left_check
    # End of the movement process
    # @author Nuri Yuri
    def movement_process_end
      if SlideTags.include?(sys_tag = system_tag) || (sys_tag == MachBike && !($game_switches[::Yuki::Sw::EV_Bicycle] && @lastdir4 == 8))
        @sliding = true
        @sliding_param = sys_tag
      end
      @z = ZTag.index(sys_tag) if ZTag.include?(sys_tag)
      @z = 1 if @z < 1
      @z = 0 if (@z == 1) && BRIDGE_TILES.include?(sys_tag)
      @__bridge = nil if @__bridge && (@__bridge.last == sys_tag)
    end
    # Return the SystemTag in the front of the Game_Character
    # @return [Integer] ID of the SystemTag
    # @author Nuri Yuri
    def front_system_tag
      xf = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
      yf = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
      return $game_map.system_tag(xf, yf)
    end
    # Return the SystemTag where the Game_Character stands
    # @return [Integer] ID of the SystemTag
    # @author Nuri Yuri
    def system_tag
      return $game_map.system_tag(@x, @y)
    end
  end
  # Module that describe the pathfinding targets.
  # There is different type of targets :
  # - Coords : reach a specific point in the map
  #         find_path to:[x, y, [,z]] [, radius: Integer]
  # - Character : reach a game character object in the map
  #         find_path to:get_character(Integer)[, radius: Integer]
  # - Charcater_Reject : flee the given charcater :
  #         find_path to:get_character(Integer), type: :Character_Reject[, radius: Integer]
  # - Border : reach the border of the map (:north, :south, :east, :west)
  #         find_path to: Symbol, type: :Border[, radius: Integer]
  # Each target can be tested by the reached? method
  module Target
    # Convert the raw data to a target object
    # @param data [Array] data to convert
    # @return [Object]
    def self.get(type, *data)
      return const_defined?(type) ? const_get(type).new(*data) : nil
    end
    # Convert the saved data to a target object with
    # @param data [Array] data to convert, must be create by the target object
    # @return [Object]
    def self.load(data)
      type = data.shift
      return const_defined?(type) ? const_get(type).load(data) : nil
    end
    # Coords target type
    class Coords
      def initialize(*args)
        coords = args[0]
        @x = coords[0] + Yuki::MapLinker.get_OffsetX
        @y = coords[1] + Yuki::MapLinker.get_OffsetY
        @z = coords[2]
        @radius = args[1]
        @original_x = coords[0]
        @original_y = coords[1]
      end
      # Test if the target is reached at the fiveng coords
      # @param x [Integer] the x coordinate to test
      # @param y [Integer] the y coordinate to test
      # @param z [Integer] the x coordinate to test
      # @return [Boolean]
      def reached?(x, y, z)
        return ((@x - x).abs + (@y - y).abs) <= @radius
      end
      # Check if the character targetted has moved, considering the distance for optimisation and return true if the target is considered as moved
      # @param x [Integer] the x coordinate of the heading event
      # @param y [Integer] the y coordinate of the heading event
      # @return [Boolean]
      def check_move(x, y)
        false
      end
      # Gather the savable data
      # @return [Array<Object>]
      def save
        return [:Coords, [@original_x, @original_y, @z], @radius]
      end
      # Create new target from the given data
      # @param data [Array] saved data
      def self.load(data)
        return Coords.new(*data)
      end
    end
    # Character target type
    class Character
      def initialize(*args)
        @character = args[0]
        @radius = args[1]
        @sx = @character.x
        @sy = @character.y
      end
      # Test if the target is reached at the fiveng coords
      # @param x [Integer] the x coordinate to test
      # @param y [Integer] the y coordinate to test
      # @param z [Integer] the x coordinate to test
      # @return [Boolean]
      def reached?(x, y, z)
        return ((@character.x - x).abs + (@character.y - y).abs) <= @radius
      end
      # Check if the character targetted has moved, considering the distance for optimisation and return true if the target is considered as moved
      # @param x [Integer] the x coordinate of the heading event
      # @param y [Integer] the y coordinate of the heading event
      # @return [Boolean]
      def check_move(x, y)
        if ((c = @character).x - x).abs + (c.y - y).abs > 15
          if (@sx - c.x).abs + (@sy - c.y).abs > 10
            @sx = c.x
            @sy = c.y
            return true
          end
          return false
        end
        return @sx != (@sx = c.x) || @sy != (@sy = c.y)
      end
      # Gather the savable data
      # @return [Array<Object>]
      def save
        return [:Character, @character.id, @radius]
      end
      # Create new target from the given data
      # @param data [Array] saved data
      def self.load(data)
        data[0] = (data[0] == 0 ? $game_player : $game_map.events[data[0]])
        return Character.new(*data)
      end
    end
    # Character reject target type
    class Character_Reject
      def initialize(*args)
        @character = args[0]
        @radius = args[1]
        @sx = @character.x
        @sy = @character.y
      end
      # Test if the target is reached at the given coords
      # @param x [Integer] the x coordinate to test
      # @param y [Integer] the y coordinate to test
      # @param z [Integer] the x coordinate to test
      # @return [Boolean]
      def reached?(x, y, z)
        return ((@character.x - x).abs + (@character.y - y).abs) > @radius
      end
      # Check if the character targetted has moved, considering the distance for optimisation and return true if the target is considered as moved
      # @param x [Integer] the x coordinate of the heading event
      # @param y [Integer] the y coordinate of the heading event
      # @return [Boolean]
      def check_move(x, y)
        if ((c = @character).x - x).abs + (c.y - y).abs > 15
          if (@sx - c.x).abs + (@sy - c.y).abs > 10
            @sx = c.x
            @sy = c.y
            return true
          end
          return false
        end
        return @sx != (@sx = c.x) || @sy != (@sy = c.y)
      end
      # Gather the savable data
      # @return [Array<Object>]
      def save
        return [:Character_Reject, @character.id, @radius]
      end
      # Create new target from the given data
      # @param data [Array] saved data
      def self.load(data)
        data[0] = (data[0] == 0 ? $game_player : $game_map.events[data[0]])
        return Character_Reject.new(*data)
      end
    end
    # Border target type
    class Border
      def initialize(*args)
        @border = args[0]
        @radius = args[1]
        case @border
        when :north
          @value = @radius + Yuki::MapLinker.get_OffsetY
        when :west
          @value = @radius + Yuki::MapLinker.get_OffsetX
        when :south
          @value = $game_map.height - @radius - 1 - Yuki::MapLinker.get_OffsetY
        when :east
          @value = $game_map.width - @radius - 1 - Yuki::MapLinker.get_OffsetX
        end
      end
      # Test if the target is reached at the given coords
      # @param x [Integer] the x coordinate to test
      # @param y [Integer] the y coordinate to test
      # @param z [Integer] the x coordinate to test
      # @return [Boolean]
      def reached?(x, y, z)
        case @border
        when :north
          return y <= @value
        when :south
          return y >= @value
        when :east
          return x >= @value
        when :west
          return x <= @value
        end
        return true
      end
      # Check if the character targetted has moved, considering the distance for optimisation and return true if the target is considered as moved
      # @param x [Integer] the x coordinate of the heading event
      # @param y [Integer] the y coordinate of the heading event
      # @return [Boolean]
      def check_move(x, y)
        return false
      end
      # Gather the savable data
      # @return [Array<Object>]
      def save
        return [:Border, @border, @radius]
      end
      # Create new target from the given data
      # @param data [Array] saved data
      def self.load(data)
        return Border.new(*data)
      end
    end
  end
end
# The map gameplay scene
class Scene_Map < GamePlay::Base
  include Hooks
  include Graphics::FPSBalancer::Marker
  # Access to the spriteset of the map
  # @return [Spriteset_Map]
  attr_reader :spriteset
  # Poison flash color
  PSN_COLOR = Color.new(123, 55, 123, 128)
  # Create a new Scene_Map
  def initialize
    super
    @update_to_call = []
    Scheduler.start(:on_init, self.class)
  end
  # Update the scene process
  def update
    Graphics::FPSBalancer.global.run {auto_transfert_update }
    update_graphics
    return false if switched_to_main_rmxp_scene
    return false if Graphics::FPSBalancer.global.skipping? && message_processing?
    return false unless super
    update_scene_calling
  ensure
    @running = false if $scene != self
  end
  # Section where we update the graphics of the scene (for now only spriteset)
  def update_graphics
    @spriteset.update
  end
  # Change the viewport visibility of the scene (we overwrite it because we don't want viewport to be hidden when calling a scene)
  # @param value [Boolean]
  def visible=(value)
    @message_window.viewport.visible = value if @message_window
  end
  # Update everything related to the graphics of the map (used in Interfaces that require that)
  def sprite_set_update
    $game_screen.update
    $game_map.refresh if $game_map.need_refresh
    @spriteset.update
  end
  # Change the spriteset visibility
  # @param v [Boolean] the new visibility of the spriteset
  def sprite_set_visible=(v)
    @spriteset.visible = v
  end
  # Display the repel check sequence
  def display_repel_check
    if $bag.item_quantity($game_temp.last_repel_used_id || 0) == 0
      display_message(parse_text(39, 0))
    else
      if display_message(parse_text(39, 1), 1, text_get(25, 20), text_get(25, 21)) == 0
        PFM.game_state.set_repel_count(data_item($game_temp.last_repel_used_id).repel_count)
        $bag.remove_item($game_temp.last_repel_used_id, 1)
      end
    end
  end
  # Display the end of poisoning sequence
  # @param pokemon [PFM::Pokemon] previously poisoned pokemon
  def display_poison_end(pokemon)
    PFM::Text.set_pknick(pokemon, 0)
    display_message(parse_text(22, 110))
  end
  # Display text showing pokemon fainted from poison
  def display_poison_faint(pokemon)
    PFM::Text.set_pknick(pokemon, 0)
    display_message(parse_text(22, 185))
  end
  # Display the poisoning animation sequence
  def display_poison_animation
    Audio.se_play('Audio/SE/psn')
    $game_screen.start_flash(PSN_COLOR, 20)
    $game_screen.start_shake(1, 20, 2)
  end
  # Display the Egg hatch sequence
  # @param pokemon [PFM::Pokemon] haching pokemon
  def display_egg_hatch(pokemon)
    GamePlay.make_egg_hatch(pokemon)
    $quests.hatch_egg
  end
  # Prepare the call of a display_ method
  # @param args [Array] the send method parameter
  def delay_display_call(*args)
    @update_to_call << args
  end
  # Force the message window to close
  # @param smooth [Boolean] if the message window is closed smoothly or not
  def window_message_close(smooth)
    if smooth
      while $game_temp.message_window_showing
        Graphics.update
        @message_window.update
      end
    else
      $game_temp.message_window_showing = false
      @message_window.visible = false
      @message_window.opacity = 255
    end
  end
  # Take a snapshot of the scene
  # @note You have to dispose the bitmap you got from this function
  # @return [Texture]
  def snap_to_bitmap
    temp_view = Viewport.create(:main)
    bitmaps = @spriteset.snap_to_bitmaps
    backs = bitmaps.map { |bmp| Sprite.new(temp_view).set_bitmap(bmp) }
    if (vp = NuriYuri::DynamicLight.viewport) && !vp.disposed? && vp.visible
      shader = vp.shader
      vp.shader = nil
      top_bitmap = vp.snap_to_bitmap
      vp.shader = shader
      top = ShaderedSprite.new(temp_view).set_bitmap(top_bitmap)
      top.shader = shader
    end
    exec_hooks(Scene_Map, :snap_to_bitmap, binding)
    result = temp_view.snap_to_bitmap
    exec_hooks(Scene_Map, :snaped_to_bitmap, binding)
    top_bitmap&.dispose
    bitmaps.each(&:dispose)
    temp_view.dispose
    return result
  end
  private
  # The main process at the begin of scene
  def main_begin
    create_spriteset
    if $game_temp.player_transferring
      transfer_player
    else
      $wild_battle.reset
      $wild_battle.load_groups
    end
    fade_in(@mbf_type || DEFAULT_TRANSITION, @mbf_param || DEFAULT_TRANSITION_PARAMETER)
    $quests.check_up_signal
  end
  # Create the spriteset
  def create_spriteset
    add_disposable @spriteset = Spriteset_Map.new($env.update_zone)
    @viewport = @spriteset.map_viewport
  end
  # Section of the update where we ensure that the game player is transfering correctly
  def auto_transfert_update
    loop do
      $game_map.update
      $game_system.map_interpreter.update
      $game_player.update
      $game_system.update
      $game_screen.update
      break unless $game_temp.player_transferring
      transfer_player
      break if $game_temp.transition_processing
    end
  end
  # Section of the update where we test if the game switched to a main RMXP scene
  # @note we also process transition here
  # @return [Boolean] if a switch was done
  def switched_to_main_rmxp_scene
    if $game_temp.gameover
      $scene = Scene_Gameover.new
      return true
    else
      if $game_temp.to_title
        $scene = Scene_Title.new
        return true
      else
        if $game_temp.transition_processing
          $game_temp.transition_processing = false
          if $game_temp.transition_name.empty?
            Graphics.transition(20)
          else
            Graphics.transition(60, RPG::Cache.transition($game_temp.transition_name))
          end
        end
      end
    end
    return false
  end
  public
  # List of RMXP Group that should be treated as "wild battle"
  RMXP_WILD_BATTLE_GROUPS = [1, 30]
  @triggers = {}
  @battle_modes = []
  class << self
    # List of call_xxx trigger
    # @return [Hash{ Symbol => Proc }]
    attr_reader :triggers
    # Add a call scene in Scene_Map
    # @param method_name [Symbol] name of the method to call (no argument)
    # @param block [Proc] block to execute in order to be sure the scene callable
    def add_call_scene(method_name, &block)
      triggers[method_name] = block
    end
    # List all the battle modes
    # @return [Array<Proc>]
    attr_reader :battle_modes
    # Add a battle mode
    # @param id [Integer] ID of the battle mode
    # @param block [Proc]
    # @yieldparam scene [Scene_Map]
    def register_battle_mode(id, &block)
      battle_modes[id] = block
    end
  end
  # Ensure the battle will start without any weird behaviour
  # @param klass [Class<Battle::Scene>] class of the scene to setup
  # @param battle_info [Battle::Logic::BattleInfo]
  def setup_start_battle(klass, battle_info)
    return unless battle_info
    Graphics.freeze
    $game_temp.menu_calling = false
    $game_temp.menu_beep = false
    $game_player.make_encounter_count
    $game_temp.map_bgm = $game_system.playing_bgm.clone if $game_system.playing_bgm
    $game_system.se_play($data_system.battle_start_se)
    $game_player.straighten
    $scene = klass.new(battle_info)
    @running = false
    Yuki::FollowMe.set_battle_entry
  end
  private
  # Function responsive of testing all the scene calling and doing the job
  def update_scene_calling
    if player_menu_trigger
      unless $game_system.map_interpreter.running? || $game_system.menu_disabled || $game_player.moving? || $game_player.sliding?
        $game_temp.menu_calling = true
        $game_temp.menu_beep = true
      end
    end
    unless $game_player.moving?
      send(*@update_to_call.shift) until @update_to_call.empty?
      Scene_Map.triggers.each do |method_name, block|
        if instance_exec(&block)
          send(method_name)
          break
        end
      end
    end
  end
  add_call_scene(:call_battle) {$game_temp.battle_calling }
  add_call_scene(:call_shop) {$game_temp.shop_calling }
  add_call_scene(:call_name) {$game_temp.name_calling }
  add_call_scene(:call_menu) {$game_temp.menu_calling }
  add_call_scene(:call_save) {$game_temp.save_calling }
  add_call_scene(:call_debug) {$game_temp.debug_calling }
  add_call_scene(:call_shortcut) {Input.trigger?(:Y) unless $game_map.map_id == Configs.scene_title_config.intro_movie_map_id }
  # Detect if the player clicked on the Player sprite to open the menu
  # @return [Boolean]
  def player_menu_trigger
    return false if $game_map.map_id == Configs.scene_title_config.intro_movie_map_id
    return Input.trigger?(:X) || (Mouse.trigger?(:left) && @spriteset.game_player_sprite&.mouse_in?)
  end
  # Call the Battle scene if the play encounter Pokemon or trainer and its party has Pokemon that can fight
  def call_battle
    $game_temp.battle_calling = false
    return log_error('Battle were called but you have no Pokemon able to fight in your party') unless PFM.game_state.alive?
    battle = Scene_Map.battle_modes[$game_variables[::Yuki::Var::BT_Mode]]
    return log_error('This mode is not programmed yet in .25') unless battle.respond_to?(:call)
    battle.call(self)
  end
  register_battle_mode(0) do |scene|
    if RMXP_WILD_BATTLE_GROUPS.include?($game_temp.battle_troop_id)
      battle_info = $wild_battle.setup
    else
      battle_info = Battle::Logic::BattleInfo.from_old_psdk_settings($game_variables[Yuki::Var::Trainer_Battle_ID], $game_variables[Yuki::Var::Second_Trainer_ID], $game_variables[Yuki::Var::Allied_Trainer_ID])
    end
    scene.setup_start_battle(Battle::Scene, battle_info)
  end
  # Call the shop ui
  def call_shop
    $game_player.straighten
    items = $game_temp.shop_goods.map { |good| good[1] }
    GamePlay.open_shop(items)
    $game_temp.shop_calling = false
  end
  # Call the name input scene
  def call_name
    $game_temp.name_calling = false
    $game_player.straighten
    Graphics.freeze
    window_message_close(false)
    actor = $game_actors[$game_temp.name_actor_id]
    character = $game_temp.name_actor_id == 1 ? $game_player.character_name : actor.character_name
    GamePlay.open_character_name_input(actor.name, $game_temp.name_max_char, character.empty? ? nil : character) do |scene|
      name = scene.return_name
      $trainer.name = name if $game_temp.name_actor_id == 1
      actor.name = name
    end
  end
  # Call the Menu interface
  def call_menu
    $game_temp.menu_calling = false
    if $game_temp.menu_beep
      $game_system.se_play($data_system.decision_se)
      $game_temp.menu_beep = false
    end
    $game_player.straighten
    menu = nil
    @cfo_type = @cfi_type = :none
    GamePlay.open_menu { |menu_scene| menu = menu_scene }
    @cfo_type = @cfi_type = nil
    menu.execute_skill_process
  end
  # Call the save interface
  def call_save
    $game_player.straighten
    $game_temp.save_calling = false
    call_scene(GamePlay::Save)
  end
  # Call the debug interface (not present in PSDK)
  def call_debug
    $game_temp.debug_calling = false
    play_decision_se
    $game_player.straighten
  end
  # Call the shortcut interface
  def call_shortcut
    GamePlay.open_shortcut if $game_system.menu_disabled != true
  end
  public
  private
  # Execute the begin calculation of the transfer_player processing
  def transfer_player_begin
    Scheduler.start(:on_warp_start)
    if $game_map.map_id != $game_temp.player_new_map_id
      $game_player.x = $game_temp.player_new_x
      $game_player.y = $game_temp.player_new_y
      $game_map.setup($game_temp.player_new_map_id)
    end
    $game_temp.player_transferring = false
    $game_player.moveto($game_temp.player_new_x, $game_temp.player_new_y)
    $game_player.direction = $game_temp.player_new_direction if $game_temp.player_new_direction != 0 && !$game_player.direction_fix
    $game_player.straighten
    $game_map.update
  end
  # Teleport the play between map or inside the map
  def transfer_player
    Yuki::ElapsedTime.start(:transfer_player)
    Pathfinding.clear
    transfer_player_begin
    zone = $env.update_zone
    Scheduler.start(:on_warp_process)
    wrp_anime = $game_switches[Yuki::Sw::WRP_Transition]
    $game_switches[Yuki::Sw::WRP_Transition] = false if !$env.get_current_zone_data.is_warp_disallowed || $game_temp.transition_processing
    transition_sprite = @spriteset.dispose(true)
    Graphics.sort_z
    $game_switches[Yuki::Sw::WRP_Transition] = wrp_anime
    transfer_player_specific_transition unless transition_sprite
    @spriteset.reload(zone)
    Scheduler.start(:on_warp_end)
    Yuki::ElapsedTime.show(:transfer_player, 'Transfering player took')
    Graphics.frame_reset
    transfer_player_end(transition_sprite)
  end
  # End of the transfer player processing (transitions)
  def transfer_player_end(transition_sprite)
    if transition_sprite
      Yuki::Transitions.bw_zoom(transition_sprite)
      $game_map.autoplay
    else
      if (transition_id = $game_variables[::Yuki::Var::MapTransitionID]) > 0
        $game_variables[::Yuki::Var::MapTransitionID] = 0
        Graphics.brightness = 255
        $game_map.autoplay
        case transition_id
        when 1
          ::Yuki::Transitions.circular(1)
        when 2
          ::Yuki::Transitions.directed(1)
        end
        $game_temp.transition_processing = false
      else
        if $game_temp.transition_processing
          $game_map.autoplay
          $game_temp.transition_processing = false
          Graphics.transition(20)
        else
          $game_map.autoplay
        end
      end
    end
  end
  # Start a specific transition
  def transfer_player_specific_transition
    if (transition_id = $game_variables[::Yuki::Var::MapTransitionID]) > 0
      Graphics.transition(1) if $game_temp.transition_processing
      case transition_id
      when 1
        ::Yuki::Transitions.circular
      when 2
        ::Yuki::Transitions.directed
      end
      Graphics.brightness = 0
      Graphics.wait(15)
    end
  end
end
