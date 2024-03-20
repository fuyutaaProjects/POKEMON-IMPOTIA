# Nuri Yuri's external script module
module NuriYuri
  # Module managing the dynamic light system for PSDK
  module DynamicLight
    # @return [Array<Array>] List of light
    #   The first array component tell if it's a normal light (:normal, centered on the character)
    #   or if it's a directed light (:direction, in the direction of the character)
    #   The second component is the sprite shown under the map (light mask)
    #   The third component is the sprite shown in the map viewport for special effect mostly on top of the character
    LIGHTS = [[:normal, 'dynamic_light/circle_320'], [:direction, 'dynamic_light/flash_light_mask', 'dynamic_light/flash_light_color'], [:normal, 'dynamic_light/circle_96']]
    # @return [Array<Hash>] List of light animation, Hash key are opacity: & zoom: (array of value)
    ANIMATIONS = [{zoom: [1], opacity: [255]}, {zoom: Array.new(120) { |i| 0.70 + 0.05 * Math.cos(6.28 * i / 120) }, opacity: Array.new(120) { |i| 240 + (15 * Math.cos(6.28 * i / 120)).to_i }}, {zoom: Array.new(120) { |i| 0.95 + 0.05 * Math.cos(6.28 * i / 120) }, opacity: [255]}]
    module_function
    # Start the dynamic light processing
    # @param block [Proc] given_block that tells to start the DynamicLight process on the next update
    def start(&block)
      return unless $scene.is_a?(Scene_Map)
      return start_delay(&block) if block
      stop(true)
      @started = true
      create_viewport
      load_blendmode
      register
      @delay = nil
    end
    # Stop the dynamic light processing
    # @param from_start [Boolean] tell if stop was called from start to prevent useless viewport dispose
    def stop(from_start = false)
      return unless $scene.is_a?(Scene_Map)
      PFM.game_state.nuri_yuri_dynamic_light.clear
      @started = false
      unregister
      clear_stack
      dispose_viewport unless from_start
    end
    # Start delayed to the warp_end process
    # @yield [dl] given_block that tells to start the DynamicLight process on the next update
    # @yieldparam dl [DynamicLight] this module
    def start_delay
      return unless $scene.is_a?(Scene_Map)
      @stack ||= []
      unregister
      @delay = proc do
        start
        yield(self)
      end
      @started = true
      Scheduler.add_message(:on_warp_end, Scene_Map, 'NuriYuri::DynamicLight', 100, self, :update)
    end
    # Stop delayed to the warp_end process
    def stop_delay
      return unless $scene.is_a?(Scene_Map)
      @stack ||= []
      @delay = proc {stop }
      Scheduler.__remove_task(:on_update, Scene_Map, 'NuriYuri::DynamicLight', 100)
    end
    # Tells if the DynamicLight is started and running or not
    # @return [Integer]
    def started?
      return @started ||= false
    end
    # Update the lights
    def update
      @delay&.call
      @stack.each(&:update)
    end
    # Add a new light to the stack
    # @param chara_id [Integer] ID of the character (0 = player, -n = follower n, +n = event id)
    # @param light_type [Integer] Type of the light we'll display on the character
    # @param animation_type [Integer] Type of the animation performed on the light
    # @param zoom_count [Integer] initial value of the zoom_count
    # @param opacity_count [Integer] initial value of the opacity_count
    # @param args [Array] extra parameters
    # @param type [Class] Type of the sprite used to simulate the light
    # @return [Integer] ID of the light in the light stack, if -1 => one of the parameter is invalid
    def add(chara_id, light_type, animation_type = 0, zoom_count = 0, opacity_count = 0, *args, type: DynamicLightSprite)
      return -2 unless $scene.is_a?(Scene_Map) && @viewport
      return -1 unless light_type.between?(0, LIGHTS.size - 1)
      return -1 unless animation_type.between?(0, ANIMATIONS.size - 1)
      if chara_id < 0
        character = determine_follower_character(chara_id)
      else
        if chara_id == 0
          character = $game_player
        else
          character = $game_map.events[chara_id]
        end
      end
      return -1 unless character
      @stack << type.new(character, light_type, animation_type, zoom_count, opacity_count, *args)
      light_id = @stack.last.light_id = @stack.size - 1
      PFM.game_state.nuri_yuri_dynamic_light << {params: [chara_id, light_type, animation_type, zoom_count, opacity_count, *args], on: true, type: type}
      return light_id
    end
    # Recursively get to the asked follower and return the result
    # @param chara_id [Integer]
    # @return [Game_Character, Game_Event, nil] the Game_Character/Game_Event is it exists, else nil
    def determine_follower_character(chara_id)
      entity = $game_player
      chara_id.abs.times {entity = entity&.follower }
      return entity
    end
    # Switch a light on
    # @param light_id [Integer] ID of the light in the light stack
    def switch_on(light_id)
      return unless @stack
      return if light_id < 0
      light = @stack[light_id]
      if light
        light.on = true
        PFM.game_state.nuri_yuri_dynamic_light[light_id][:on] = true
      end
    end
    # Switch a light off
    # @param light_id [Integer] ID of the light in the light stack
    def switch_off(light_id)
      return unless @stack
      return if light_id < 0
      light = @stack[light_id]
      if light
        light.on = false
        PFM.game_state.nuri_yuri_dynamic_light[light_id][:on] = false
      end
    end
    # Retrieve the light sprite
    # @param light_id ID of the light in the light stack
    # @return [DynamicLightSprite, nil]
    def light_sprite(light_id)
      return nil unless @stack
      return nil if light_id < 0
      @stack[light_id]
    end
    # Register the update task
    def register
      Scheduler.add_message(:on_update, Scene_Map, 'NuriYuri::DynamicLight', 100, self, :update)
      Scheduler.add_message(:on_warp_end, Scene_Map, 'NuriYuri::DynamicLight', 100, self, :update)
      nil
    end
    # Unregister the update task
    def unregister
      Scheduler.__remove_task(:on_update, Scene_Map, 'NuriYuri::DynamicLight', 100)
      Scheduler.__remove_task(:on_transition, Scene_Map, 'NuriYuri::DynamicLight', 100)
      Scheduler.__remove_task(:on_warp_end, Scene_Map, 'NuriYuri::DynamicLight', 100)
      nil
    end
    # Clear the light task
    def clear_stack
      @stack ||= []
      @stack.each { |light| light.dispose unless light.disposed? }
    ensure
      @stack.clear
    end
    # Create the viewport
    def create_viewport
      @viewport = Viewport.create(:main, 1) if !@viewport || @viewport.disposed?
      Graphics.sort_z
    end
    # Dispose the light viewport
    def dispose_viewport
      @viewport.dispose
    end
    # Load the light blend_mode
    def load_blendmode
      shader = BlendMode.new
      shader.color_src_factor = BlendMode::DstColor
      shader.color_dest_factor = BlendMode::OneMinusSrcColor
      shader.color_equation = BlendMode::Subtract
      shader.alpha_src_factor = BlendMode::SrcAlpha
      shader.alpha_dest_factor = BlendMode::DstAlpha
      shader.alpha_equation = BlendMode::Add
      @viewport.shader = shader
    end
    # Part called when Scene_Map init itself (in order to reload all the lights)
    def on_map_init
      PFM.game_state.nuri_yuri_dynamic_light ||= []
      light_info_stack = PFM.game_state.nuri_yuri_dynamic_light.clone
      unless light_info_stack.empty?
        @delay = proc do
          start
          light_info_stack.each do |light_info|
            id = add(*light_info[:params], type: light_info[:type])
            switch_off(id) unless light_info[:on]
          end
        end
        Scheduler.add_message(:on_transition, Scene_Map, 'NuriYuri::DynamicLight', 100, self, :update)
      end
    end
    # Return the viewport of the DynamicLight system
    # @return [Viewport]
    def viewport
      @viewport
    end
    # Clean everything on soft reset
    def on_soft_reset
      unregister
      @stack ||= []
      @stack.clear
    end
    unless PARGV[:worldmap] || PARGV[:"animation-editor"] || PARGV[:test] || PARGV[:tags]
      Scheduler.add_message(:on_init, Scene_Map, 'NuriYuri::DynamicLight', 0, self, :on_map_init)
      Graphics.on_start do
        soft_reset = Yuki.const_get(:SoftReset)
        Scheduler.add_message(:on_transition, soft_reset, 'NuriYuri::DynamicLight', 100, self, :on_soft_reset)
      end
    end
    public
    # Sprite that simulate the dynamic light
    class DynamicLightSprite < ::Sprite
      # Offset of the light in :direction mode
      DIRECTION_OFFSET = -12
      # Offset of the light in other modes
      NORMAL_OFFSET = -8
      # Zoom of a tile to process coodinate properly
      TILE_ZOOM = Configs.display.tilemap_settings.character_tile_zoom
      # @return [Integer] ID of the light in the stack
      attr_accessor :light_id
      # Create a new DynamicLightSprite
      # @param character [Game_Character]
      # @param light_type [Integer] Type of the light we'll display on the character
      # @param animation_type [Integer] Type of the animation performed on the light
      # @param zoom_count [Integer] initial value of the zoom_count
      # @param opacity_count [Integer] initial value of the opacity_count
      def initialize(character, light_type, animation_type = 0, zoom_count = 0, opacity_count = 0)
        super(DynamicLight.viewport)
        @character = character
        load_light(LIGHTS[light_type])
        animation = ANIMATIONS[animation_type]
        @zoom_list = animation[:zoom]
        @zoom_count = zoom_count
        @opacity_list = animation[:opacity]
        @opacity_count = opacity_count
        @tile_zoom = TILE_ZOOM
      end
      # Update the sprite
      def update
        @opacity_count = (@opacity_count + 1) % @opacity_list.size
        @zoom_count = (@zoom_count + 1) % @zoom_list.size
        return unless visible
        self.zoom = @zoom_list[@zoom_count]
        self.opacity = @opacity_list[@opacity_count]
        set_position((@character.screen_x * @tile_zoom).floor, (@character.screen_y * @tile_zoom).floor + @offset_y)
        sub_sprite_update if @sub_sprite
        update_direction if @mode == :direction
      end
      alias on visible
      # Change the sprite visibility
      # @param value [Boolean]
      def visible=(value)
        super
        @sub_sprite.visible = value if @sub_sprite
      end
      # Dispose the sprite
      def dispose
        @sub_sprite&.dispose
        super
      end
      alias on= visible=
      private
      # Update the direction of the sprite
      def update_direction
        if @direction != @character.direction
          @direction = @character.direction
          case @direction
          when 2
            self.angle = 180
          when 4
            self.angle = 90
          when 6
            self.angle = -90
          else
            self.angle = 0
          end
          update_sub_sprite_angle
        end
      end
      # Update the sub sprite
      def sub_sprite_update
        return unless visible
        @sub_sprite.zoom = zoom_x
        @sub_sprite.set_position(x, y)
      end
      # Update the sub sprite angle
      def update_sub_sprite_angle
        return unless @sub_sprite
        @sub_sprite.angle = angle
        if angle == 0
          @sub_sprite.z = @character.screen_z - 1
        else
          @sub_sprite.z = 10_000
        end
      end
      # Load the light images
      # @param light_array [Array] informations about the light
      def load_light(light_array)
        @mode = light_array.first
        set_bitmap(light_array[1], :particle)
        if @mode == :direction
          set_origin(bitmap.width / 2, bitmap.height)
          @offset_y = DIRECTION_OFFSET
        else
          set_origin(bitmap.width / 2, bitmap.height / 2)
          @offset_y = NORMAL_OFFSET
        end
        if light_array[2]
          @sub_sprite = Sprite.new($scene.spriteset.map_viewport)
          @sub_sprite.set_bitmap(light_array[2], :particle)
          if @mode == :direction
            @sub_sprite.set_origin(@sub_sprite.bitmap.width / 2, @sub_sprite.bitmap.height)
          else
            @sub_sprite.set_origin(@sub_sprite.bitmap.width / 2, @sub_sprite.bitmap.height / 2 + NORMAL_OFFSET)
          end
        end
      end
    end
    public
    # Sprite that simulate the dynamic light and can be scaled
    class ScalableDLS < DynamicLightSprite
      # Create a new ScalableDynamicLightSprite
      # @param character [Game_Character]
      # @param light_type [Integer] Type of the light we'll display on the character
      # @param animation_type [Integer] Type of the animation performed on the light
      # @param zoom_count [Integer] initial value of the zoom_count
      # @param opacity_count [Integer] initial value of the opacity_count
      # @param init_scale [Numeric] initial scale of the object
      def initialize(character, light_type, animation_type = 0, zoom_count = 0, opacity_count = 0, init_scale = 1)
        super(character, light_type, animation_type, zoom_count, opacity_count)
        @scale = init_scale
        @init_scale = init_scale
        @target_scale = init_scale
        @target_scale_count = 0
        @target_scale_max = 0
      end
      # Change the zoom of the sprite
      # @param value [Numeric] New zoom
      def zoom=(value)
        super(@scale == 1 ? value : value * @scale)
      end
      # Retrieve the current scale of the sprite (without the animation effect)
      # @return [Numeric]
      def scale
        @target_scale
      end
      # Update the sprite
      def update
        if visible
          if @target_scale_count < @target_scale_max
            @scale = @init_scale + @target_scale_count * (@target_scale - @init_scale) / @target_scale_max
            @target_scale_count += 1
          end
        end
        super
      end
      # Tell the sprite to scale
      # @param target_scale [Numeric] target value the sprite should scale
      # @param duration [Integer] number of frame the sprite should take to scale
      def scale_to(target_scale, duration = 0)
        @target_scale_count = 0
        if duration < 1
          @init_scale = @scale = @target_scale = target_scale
          @target_scale_max = 0
        else
          @init_scale = @scale
          @target_scale = target_scale.to_f
          @target_scale_max = duration
        end
        PFM.game_state.nuri_yuri_dynamic_light[@light_id][:params][5] = target_scale
      end
    end
  end
end
module PFM
  class GameState
    # Access to the information of the current dynamic light state (Battle / Save)
    attr_accessor :nuri_yuri_dynamic_light
  end
end
