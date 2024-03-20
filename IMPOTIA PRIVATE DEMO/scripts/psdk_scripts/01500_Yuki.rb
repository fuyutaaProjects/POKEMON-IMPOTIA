module Yuki
  # Sprite with move_to command a self "animation"
  # @author Nuri Yuri
  class Sprite < Sprite
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
      super
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
      self.x = @new_x + (@del_x * @move_frame) / @move_total
      self.y = @new_y + (@del_y * @move_frame) / @move_total
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
        return if (@anime_delta > @anime_count)
        @anime_count = 0
      end
      anim = @animation[@anime_pos]
      self.send(*anim) if anim[0] != :send && anim[0].class == Symbol
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
    # Security patch
    def eval
    end
    alias class_eval eval
    alias instance_eval eval
    alias module_eval eval
  end
  # PSDK DayNightSystem v2
  #
  # This script manage the day night tint & hour calculation
  #
  # It's inputs are :
  #   - $game_switches[Sw::TJN_NoTime] (8) : Telling not to update time
  #   - $game_switches[Sw::TJN_RealTime] (7) : Telling to use the real time (computer clock)
  #   - $game_variables[Var::TJN_Month] (15) : Month of the year (1~13 in virtual time)
  #   - $game_variables[Var::TJN_MDay] (16) : Day of the month (1~28 in virtual time)
  #   - $game_variables[Var::TJN_Week] (14) : Week since the begining (0~65535)
  #   - $game_variables[Var::TJN_WDay] (13) : Day of the week (1~7 in virtual time)
  #   - $game_variables[Var::TJN_Hour] (10) : Hour of the day (0~23)
  #   - $game_variables[Var::TJN_Min] (11) : Minute of the hour (0~59)
  #   - $game_switches[Sw::TJN_Enabled] (10) : If tone change is enabled
  #   - $game_switches[Sw::Env_CanFly] (20) : If the tone can be applied (player outside)
  #   - Yuki::TJN.force_update_tone : Calling this method will force the system to update the tint
  #   - PFM.game_state.tint_time_set : Name of the time set (symbol) to use in order to get the tone
  #
  # It's outputs are :
  #   - All the time variables (15, 16, 14, 13, 10, 11)
  #   - $game_variables[Var::TJN_Tone] : The current applied tone
  #       - 0 = Night
  #       - 1 = Sunset
  #       - 2 = Morning
  #       - 3 = Day time
  # @author Nuri Yuri
  module TJN
    # Neutral tone
    NEUTRAL_TONE = Tone.new(0, 0, 0, 0)
    # The different tones according to the time set
    TONE_SETS = {default: [Tone.new(-85, -85, -20, 0), Tone.new(-17, -51, -34, 0), Tone.new(-75, -75, -10, 0), NEUTRAL_TONE, Tone.new(17, -17, -34, 0)], winter: [Tone.new(-75, -75, -10, 0), Tone.new(-80, -80, -10, 0), Tone.new(-85, -85, -10, 0), Tone.new(-80, -80, -12, 0), Tone.new(-75, -75, -15, 0), Tone.new(-65, -65, -18, 0), Tone.new(-55, -55, -20, 0), Tone.new(-25, -35, -22, 0), Tone.new(-20, -25, -25, 0), Tone.new(-15, -20, -30, 0), Tone.new(-10, -17, -34, 0), Tone.new(5, -8, -15, 0), Tone.new(0, 0, -5, 0), Tone.new(0, 0, 0, 0), Tone.new(0, 0, 0, 0), Tone.new(-10, -25, -10, 0), Tone.new(-17, -51, -34, 0), Tone.new(-20, -43, -30, 0), Tone.new(-35, -35, -25, 0), Tone.new(-45, -45, -20, 0), Tone.new(-55, -55, -15, 0), Tone.new(-60, -60, -14, 0), Tone.new(-65, -65, -13, 0), Tone.new(-70, -70, -10, 0)]}
    # The different tones
    TONE = TONE_SETS[:default]
    # The different time sets according to the time set
    TIME_SETS = {default: summer = [22, 19, 11, 7], summer: summer, winter: [17, 16, 12, 10], fall: fall = [19, 17, 11, 9], spring: fall}
    # The time when the tone changes
    TIME = TIME_SETS[:default]
    # The number of frame that makes 1 minute in Game time
    MIN_FRAMES = 600
    # Regular number of frame the tint change has to be performed
    REGULAR_TRANSITION_TIME = 20
    @timer = 0
    @forced = false
    @current_tone_value = Tone.new(0, 0, 0, 0)
    module_function
    # Function that init the TJN variables
    def init_variables
      unless $game_switches[Sw::TJN_RealTime]
        $game_variables[Var::TJN_WDay] = 1 if $game_variables[Var::TJN_WDay] <= 0
        $game_variables[Var::TJN_MDay] = 1 if $game_variables[Var::TJN_MDay] <= 0
        $game_variables[Var::TJN_Month] = 1 if $game_variables[Var::TJN_Month] <= 0
      end
      $user_data[:tjn_events] ||= {}
    end
    # Update the tone of the screen and the game time
    def update
      @timer < one_minute ? @timer += 1 : update_time
      if @forced
        update_real_time if $game_switches[Sw::TJN_RealTime] && @timer < one_minute
        update_tone
      end
    end
    # Force the next update to update the tone
    # @param value [Boolean] true to force the next update to update the tone
    def force_update_tone(value = true)
      Graphics::FPSBalancer.global.disable_skip_for_next_rendering
      @forced = value
    end
    # Return the current tone
    # @return [Tone]
    def current_tone
      $game_switches[Sw::TJN_Enabled] ? @current_tone_value : NEUTRAL_TONE
    end
    # Function that scan all the timed event for the current map in order to update them
    # @param map_id [Integer] ID of the map where to update the timed events
    def update_timed_events(map_id = $game_map.map_id)
      curr_time = $game_system.map_interpreter.current_time
      (map_data = $user_data.dig(:tjn_events, map_id))&.each do |event_id, data|
        if data.first <= curr_time
          $game_map.need_refresh = true
          $game_system.map_interpreter.set_self_switch(true, data.last, event_id, map_id)
          data.clear
        end
      end
      map_data&.delete_if { |_key, value| value.empty? }
    end
    class << self
      private
      # Return the number of frame between each virtual minutes
      # @return [Integer]
      def one_minute
        MIN_FRAMES
      end
      # Update the game time
      # @note If the game switch Yuki::Sw::TJN_NoTime is on, there's no time update.
      # @note If the game switch Yuki::Sw::TJN_RealTime is on, the time is the computer time
      def update_time
        @timer = 0
        return if $game_switches[Sw::TJN_NoTime]
        update_tone if $game_switches[Sw::TJN_RealTime] ? update_real_time : update_virtual_time
        Scheduler.start(:on_update, self)
      end
      # Update the virtual time by adding 1 minute to the variable
      # @return [Boolean] if update_time should call update_tone
      def update_virtual_time
        update_timed_events
        return should_update_tone_each_minute unless ($game_variables[Var::TJN_Min] += 1) >= 60
        $game_variables[Var::TJN_Min] = 0
        return true unless ($game_variables[Var::TJN_Hour] += 1) >= 24
        $game_variables[Var::TJN_Hour] = 0
        if ($game_variables[Var::TJN_WDay] += 1) >= 8
          $game_variables[Var::TJN_WDay] = 1
          $game_variables[Var::TJN_Week] = 0 if ($game_variables[Var::TJN_Week] += 1) >= 0xFFFF
        end
        if ($game_variables[Var::TJN_MDay] += 1) >= 29
          $game_variables[Var::TJN_MDay] = 1
          $game_variables[Var::TJN_Month] = 1 if ($game_variables[Var::TJN_Month] += 1) >= 14
        end
        return true
      end
      # Update the real time values
      # @return [Boolean] if update_time should call update_tone
      def update_real_time
        last_hour = $game_variables[Var::TJN_Hour]
        last_min = $game_variables[Var::TJN_Min]
        @timer = MIN_FRAMES - 60 if MIN_FRAMES > 60
        time = Time.new
        $game_variables[Var::TJN_Min] = time.min
        $game_variables[Var::TJN_Hour] = time.hour
        $game_variables[Var::TJN_WDay] = time.wday
        $game_variables[Var::TJN_MDay] = time.day
        $game_variables[Var::TJN_Month] = time.month
        update_timed_events if last_min != time.min
        return should_update_tone_each_minute ? last_min != time.min : last_hour != time.hour
      end
      # Update the tone of the screen
      # @note if the game switch Yuki::Sw::TJN_Enabled is off, the tone is not updated
      def update_tone
        return unless $game_switches[Sw::TJN_Enabled]
        change_tone_to_neutral unless (day_tone = $game_switches[Sw::Env_CanFly])
        day_tone = false if $env.sunny?
        update_tone_internal(day_tone)
        $game_map.need_refresh = true
        ::Scheduler.start(:on_hour_update, $scene.class)
      ensure
        @forced = false
      end
      # Internal part of the update tone where flags are set & tone is processed
      # @param day_tone [Boolean] if we can process a tone (not inside / locked by something else)
      def update_tone_internal(day_tone)
        v = $game_variables[Var::TJN_Hour]
        timeset = current_time_set
        if v >= timeset[0]
          change_tone(0) if day_tone
          update_switches_and_variables(Sw::TJN_NightTime, 0)
        else
          if v >= timeset[1]
            change_tone(1) if day_tone
            update_switches_and_variables(Sw::TJN_SunsetTime, 1)
          else
            if v >= timeset[2]
              change_tone(3) if day_tone
              update_switches_and_variables(Sw::TJN_DayTime, 3)
            else
              if v >= timeset[3]
                change_tone(4) if day_tone
                update_switches_and_variables(Sw::TJN_MorningTime, 2)
              else
                change_tone(2) if day_tone
                update_switches_and_variables(Sw::TJN_NightTime, 0)
              end
            end
          end
        end
      end
      # Change the game tone to the neutral one
      def change_tone_to_neutral
        @current_tone_value.set(NEUTRAL_TONE.red, NEUTRAL_TONE.green, NEUTRAL_TONE.blue, NEUTRAL_TONE.gray)
        $game_screen.start_tone_change(NEUTRAL_TONE, tone_change_time)
      end
      # Change tone of the map
      # @param tone_index [Integer] index of the tone if there's no 24 tones inside the tone array
      def change_tone(tone_index)
        tones = current_tone_set
        if tones.size == 24
          delta_minutes = 60
          current_minute = $game_variables[Var::TJN_Min]
          one_minus_alpha = delta_minutes - current_minute
          current_tone = tones[$game_variables[Var::TJN_Hour]]
          next_tone = tones[($game_variables[Var::TJN_Hour] + 1) % 24]
          @current_tone_value.set((current_tone.red * one_minus_alpha + next_tone.red * current_minute) / delta_minutes, (current_tone.green * one_minus_alpha + next_tone.green * current_minute) / delta_minutes, (current_tone.blue * one_minus_alpha + next_tone.blue * current_minute) / delta_minutes, (current_tone.gray * one_minus_alpha + next_tone.gray * current_minute) / delta_minutes)
        else
          current_tone = tones[tone_index]
          @current_tone_value.set(current_tone.red, current_tone.green, current_tone.blue, current_tone.gray)
        end
        $game_screen.start_tone_change(@current_tone_value, tone_change_time)
      end
      # Time to change tone
      # @return [Integer]
      def tone_change_time
        @forced == true ? 0 : REGULAR_TRANSITION_TIME
      end
      # Get the time set
      # @return [Array<Integer>] 4 values : [night_start, evening_start, day_start, morning_start]
      def current_time_set
        TIME_SETS[PFM.game_state.tint_time_set] || TIME
      end
      # Get the tone set
      # @return [Array<Tone>] 5 values : night, evening, morning / night, day, dawn
      def current_tone_set
        TONE_SETS[PFM.game_state.tint_time_set] || TONE
      end
      # List of the switch name used by the TJN system (it's not defined here so we use another access)
      TJN_SWITCH_LIST = %i[TJN_NightTime TJN_DayTime TJN_MorningTime TJN_SunsetTime]
      # Update the state of the switches and the tone variable
      # @param switch_id [Integer] ID of the switch that should be true (all the other will be false)
      # @param variable_value [Integer] new value of $game_variables[Var::TJN_Tone]
      def update_switches_and_variables(switch_id, variable_value)
        $game_variables[Var::TJN_Tone] = variable_value
        TJN_SWITCH_LIST.each do |switch_name|
          switch_index = Sw.const_get(switch_name)
          $game_switches[switch_index] = switch_index == switch_id
        end
      end
      # If the tone should update each minute
      def should_update_tone_each_minute
        return current_tone_set.size == 24
      end
    end
  end
  # Module that manage the growth of berries.
  # @author Nuri Yuri
  #
  # The berry informations are stored in PFM.game_state.berries, a 2D Array of berry information
  #   PFM.game_state.berries[map_id][event_id] = [berry_id, stage, timer, stage_time, water_timer, water_time, water_counter, info_fertilizer]
  module Berries
    # The base name of berry character
    PLANTED_CHAR = 'Z_BP'
    # Berry data / db_symbol
    # @return [Hash{ symbol => Data }]
    BERRY_DATA = {}
    module_function
    # Init a berry tree
    # @param map_id [Integer] id of the map where the berry tree is
    # @param event_id [Integer] id of the event where the berry tree is shown
    # @param berry_id [Symbol, Integer] db_symbol or ID of the berry Item in the database
    # @param state [Integer] the growth state of the berry
    def init_berry(map_id, event_id, berry_id, state = 4)
      return unless (berry_data = BERRY_DATA[data_item(berry_id).db_symbol])
      data = find_berry_data(map_id)[event_id] = Array.new(8, 0)
      data[0] = data_item(berry_id).id
      data[1] = state
      data[3] = berry_data.time_to_grow * 15
      data[5] = data[3] - 1
    end
    # Test if a berry is on an event
    # @param event_id [Integer] ID of the event
    # @return [Boolean]
    def here?(event_id)
      return false unless (data = @data[event_id])
      return data[0] != 0
    end
    # Retrieve the ID of the berry that is planted on an event
    # @param event_id [Integer] ID of the event
    # @return [Integer]
    def get_berry_id(event_id)
      return 0 unless (data = @data[event_id])
      return data[0]
    end
    # Retrieve the Internal ID of the berry (text_id)
    # @param event_id [Integer] ID of the event
    # @return [Integer]
    def get_berry_internal_id(event_id)
      return 0 unless (data = @data[event_id])
      item_id = data[0]
      if item_id < 213
        return item_id - 149
      else
        if item_id > 685
          return item_id - 622
        end
      end
      return 0
    end
    # Retrieve the stage of a berry
    # @param event_id [Integer] ID of the event
    # @return [Integer]
    def get_stage(event_id)
      return 0 unless (data = @data[event_id])
      return data[1]
    end
    # Tell if the berry is watered
    # @param event_id [Integer] ID of the event
    # @return [Boolean]
    def watered?(event_id)
      return true unless (data = @data[event_id])
      return data[4] > 0
    end
    # Water a berry
    # @param event_id [Integer] ID of the event
    def water(event_id)
      return unless (data = @data[event_id])
      data[4] = data[5]
      data[6] += 1
    end
    # Plant a berry
    # @param event_id [Integer] ID of the event
    # @param berry_id [Integer] ID of the berry Item in the database
    def plant(event_id, berry_id)
      @data[event_id] = Array.new(8, 0) unless @data[event_id]
      return unless (berry_data = BERRY_DATA[data_item(berry_id).db_symbol])
      data = @data[event_id]
      data[0] = berry_id
      data[1] = 0
      data[3] = berry_data.time_to_grow * 15
      data[2] = data[3]
      data[4] = 0
      data[5] = data[3] - 1
      data[6] = 0
      data[7] = 0
      update_event(event_id, data)
    end
    # Take the berries from the berry tree
    # @param event_id [Integer] ID of the event
    # @return [Integer] the number of berry taken from the tree
    def take(event_id)
      return unless (data = @data[event_id])
      return unless (berry_data = BERRY_DATA[data_item(data[0]).db_symbol])
      delta = berry_data.max_yield - berry_data.min_yield
      water_times = data[6]
      amount = berry_data.min_yield + delta * water_times / 4
      $bag.add_item(data[0], amount)
      data[0] = 0
      return amount
    end
    # Initialization of the Berry management
    def init
      @data = find_berry_data($game_map.map_id)
      @data.each do |event_id, data|
        update_event(event_id, data)
      end
      MapLinker.added_events.each do |map_id, stack|
        berry_data = find_berry_data(map_id)
        stack.each do |event|
          if (data = berry_data[event.original_id])
            update_event(event.id, data)
          end
        end
      end
    end
    # Update of the berry management
    def update
      PFM.game_state.berries.each do |_, berries|
        berries.each do |event_id, data|
          next if data[0] == 0
          data[2] -= 1 if data[2] >= 0
          data[4] -= 1 if data[2] >= 0 && data[4] > 0
          next unless data[1] < 4 && (data[2] % data[3]) == 0
          data[1] += 1
          data[2] = data[3]
          update_event(event_id, data) if data.__id__ == @data[event_id].__id__
        end
      end
    end
    # Update of the berry event graphics
    # @param event_id [Integer] id of the event where the berry tree is shown
    # @param data [Array] berry data
    def update_event(event_id, data)
      return unless (event = $game_map.events[event_id])
      return event.opacity = 0 if data[0] == 0
      stage = data[1]
      event.character_name = stage == 0 ? PLANTED_CHAR : "Z_B#{data[0]}"
      event.direction = (stage == 1 ? 2 : (stage == 2 ? 4 : (stage == 3 ? 6 : 8)))
      event.opacity = 255
    end
    # Search the Berry data of the map
    # @param map_id [Integer] id of the Map
    def find_berry_data(map_id)
      data = PFM.game_state.berries ||= {}
      return data[map_id] ||= {}
    end
    # Return the berry data
    def data
      @data
    end
    # Data describing a berry in the Berry system
    class Data
      # Bitter factor of the berry
      # @return [Integer]
      attr_accessor :bitter
      # Minimum amount of berry yield
      # @return [Integer]
      attr_accessor :min_yield
      # Sour factor of the berry
      # @return [Integer]
      attr_accessor :sour
      # Maximum amount of berry yield
      # @return [Integer]
      attr_accessor :max_yield
      # Spicy factor of the berry
      # @return [Integer]
      attr_accessor :spicy
      # Dry factor of the berry
      # @return [Integer]
      attr_accessor :dry
      # Sweet factor of the berry
      # @return [Integer]
      attr_accessor :sweet
      # Time the berry take to grow
      # @return [Integer]
      attr_accessor :time_to_grow
      # Create a new berry
      # @param time_to_grow [Integer] number of hours the berry need to fully grow
      # @param min_yield [Integer] minimum quantity the berry can yield
      # @param max_yield [Integer] maximum quantity the berry can yield
      # @param taste_info [Hash{ Symbol => Integer}]
      def initialize(time_to_grow, min_yield, max_yield, taste_info)
        self.time_to_grow = time_to_grow
        self.min_yield = min_yield
        self.max_yield = max_yield
        self.bitter = taste_info[:bitter] || 0
        self.dry = taste_info[:dry] || 0
        self.sweet = taste_info[:sweet] || 0
        self.spicy = taste_info[:spicy] || 0
        self.sour = taste_info[:sour] || 0
      end
    end
    BERRY_DATA[:cheri_berry] = Data.new(12, 2, 5, spicy: 10)
    BERRY_DATA[:chesto_berry] = Data.new(12, 2, 5, dry: 10)
    BERRY_DATA[:pecha_berry] = Data.new(12, 2, 5, sweet: 10)
    BERRY_DATA[:rawst_berry] = Data.new(12, 2, 5, bitter: 10)
    BERRY_DATA[:aspear_berry] = Data.new(12, 2, 5, sour: 10)
    BERRY_DATA[:leppa_berry] = Data.new(16, 2, 5, spicy: 10, bitter: 10, sour: 10, sweet: 10)
    BERRY_DATA[:oran_berry] = Data.new(16, 2, 5, spicy: 10, bitter: 10, sour: 10, sweet: 10, dry: 10)
    BERRY_DATA[:persim_berry] = Data.new(16, 2, 5, spicy: 10, sour: 10, sweet: 10, dry: 10)
    BERRY_DATA[:lum_berry] = Data.new(48, 2, 5, spicy: 10, bitter: 10, sweet: 10, dry: 10)
    BERRY_DATA[:sitrus_berry] = Data.new(32, 2, 5, bitter: 10, sour: 10, sweet: 10, dry: 10)
    BERRY_DATA[:figy_berry] = Data.new(20, 1, 5, spicy: 15)
    BERRY_DATA[:wiki_berry] = Data.new(20, 1, 5, dry: 15)
    BERRY_DATA[:mago_berry] = Data.new(20, 1, 5, sweet: 15)
    BERRY_DATA[:aguav_berry] = Data.new(20, 1, 5, bitter: 15)
    BERRY_DATA[:iapapa_berry] = Data.new(20, 1, 5, sour: 15)
    BERRY_DATA[:razz_berry] = Data.new(8, 2, 10, dry: 10, spicy: 10)
    BERRY_DATA[:bluk_berry] = Data.new(8, 2, 10, dry: 10, sweet: 10)
    BERRY_DATA[:nanab_berry] = Data.new(8, 2, 10, bitter: 10, sweet: 10)
    BERRY_DATA[:wepear_berry] = Data.new(8, 2, 10, bitter: 10, sour: 10)
    BERRY_DATA[:pinap_berry] = Data.new(8, 2, 10, spicy: 10, sour: 10)
    BERRY_DATA[:pomeg_berry] = Data.new(32, 1, 5, spicy: 10, bitter: 10, sweet: 10)
    BERRY_DATA[:kelpsy_berry] = Data.new(32, 1, 5, sour: 10, bitter: 10, dry: 10)
    BERRY_DATA[:qualot_berry] = Data.new(32, 1, 5, sour: 10, spicy: 10, sweet: 10)
    BERRY_DATA[:hondew_berry] = Data.new(32, 1, 5, sour: 10, spicy: 10, bitter: 10, dry: 10)
    BERRY_DATA[:grepa_berry] = Data.new(32, 1, 5, sour: 10, spicy: 10, sweet: 10)
    BERRY_DATA[:tamato_berry] = Data.new(32, 1, 5, spicy: 20, dry: 10)
    BERRY_DATA[:cornn_berry] = Data.new(24, 2, 10, dry: 20, sweet: 10)
    BERRY_DATA[:magost_berry] = Data.new(24, 2, 10, bitter: 10, sweet: 20)
    BERRY_DATA[:rabuta_berry] = Data.new(24, 2, 10, bitter: 20, sour: 10)
    BERRY_DATA[:nomel_berry] = Data.new(24, 2, 10, spicy: 10, sour: 20)
    BERRY_DATA[:spelon_berry] = Data.new(60, 2, 15, spicy: 30, dry: 10)
    BERRY_DATA[:pamtre_berry] = Data.new(60, 2, 15, dry: 30, sweet: 10)
    BERRY_DATA[:watmel_berry] = Data.new(60, 2, 15, sweet: 30, bitter: 10)
    BERRY_DATA[:durin_berry] = Data.new(60, 2, 15, bitter: 30, sour: 10)
    BERRY_DATA[:belue_berry] = Data.new(60, 2, 15, sour: 30, spicy: 10)
    BERRY_DATA[:occa_berry] = Data.new(72, 1, 5, spicy: 15, sweet: 10)
    BERRY_DATA[:passho_berry] = Data.new(72, 1, 5, dry: 15, bitter: 10)
    BERRY_DATA[:wacan_berry] = Data.new(72, 1, 5, sweet: 15, sour: 10)
    BERRY_DATA[:rindo_berry] = Data.new(72, 1, 5, bitter: 15, spicy: 10)
    BERRY_DATA[:yache_berry] = Data.new(72, 1, 5, sour: 15, dry: 10)
    BERRY_DATA[:chople_berry] = Data.new(72, 1, 5, spicy: 15, bitter: 10)
    BERRY_DATA[:kebia_berry] = Data.new(72, 1, 5, dry: 15, sour: 10)
    BERRY_DATA[:shuca_berry] = Data.new(72, 1, 5, sweet: 15, spicy: 10)
    BERRY_DATA[:coba_berry] = Data.new(72, 1, 5, bitter: 15, dry: 10)
    BERRY_DATA[:payapa_berry] = Data.new(72, 1, 5, sour: 15, sweet: 10)
    BERRY_DATA[:tanga_berry] = Data.new(72, 1, 5, spicy: 20, sour: 10)
    BERRY_DATA[:charti_berry] = Data.new(72, 1, 5, dry: 20, spicy: 10)
    BERRY_DATA[:kasib_berry] = Data.new(72, 1, 5, sweet: 20, dry: 10)
    BERRY_DATA[:haban_berry] = Data.new(72, 1, 5, bitter: 20, sweet: 10)
    BERRY_DATA[:colbur_berry] = Data.new(72, 1, 5, sour: 20, bitter: 10)
    BERRY_DATA[:babiri_berry] = Data.new(72, 1, 5, spicy: 25, dry: 10)
    BERRY_DATA[:chilan_berry] = Data.new(72, 1, 5, dry: 25, sweet: 10)
    BERRY_DATA[:liechi_berry] = Data.new(96, 1, 5, spicy: 30, sweet: 30, dry: 10)
    BERRY_DATA[:ganlon_berry] = Data.new(96, 1, 5, bitter: 30, dry: 30, sweet: 10)
    BERRY_DATA[:salac_berry] = Data.new(96, 1, 5, sweet: 30, sour: 30, bitter: 10)
    BERRY_DATA[:petaya_berry] = Data.new(96, 1, 5, bitter: 30, spicy: 30, sour: 10)
    BERRY_DATA[:apicot_berry] = Data.new(96, 1, 5, sour: 30, dry: 30, spicy: 10)
    BERRY_DATA[:lansat_berry] = Data.new(96, 1, 5, bitter: 10, sour: 30, dry: 10, sweet: 30, spicy: 30)
    BERRY_DATA[:starf_berry] = Data.new(96, 1, 5, bitter: 10, sour: 30, dry: 10, sweet: 30, spicy: 30)
    BERRY_DATA[:enigma_berry] = Data.new(96, 1, 5, spicy: 40, dry: 10)
    BERRY_DATA[:micle_berry] = Data.new(96, 1, 5, dry: 40, sweet: 10)
    BERRY_DATA[:custap_berry] = Data.new(96, 1, 5, sweet: 40, bitter: 10)
    BERRY_DATA[:jaboca_berry] = Data.new(96, 1, 5, bitter: 40, sour: 10)
    BERRY_DATA[:rowap_berry] = Data.new(96, 1, 5, sour: 40, spicy: 10)
    BERRY_DATA[:rowap_berry] = Data.new(96, 1, 5, sour: 40, spicy: 10)
    BERRY_DATA[:roseli_berry] = Data.new(72, 1, 5, sour: 10, sweet: 20)
    BERRY_DATA[:kee_berry] = Data.new(96, 1, 5, sweet: 40, sour: 10)
    BERRY_DATA[:maranga_berry] = Data.new(96, 1, 5, bitter: 40, dry: 10)
    ::Scheduler.add_message(:on_update, TJN, 'Update berries using time system', 1000, self, :update)
    ::Scheduler.add_message(:on_warp_process, 'Scene_Map', 'Init baies', 99, self, :init)
    ::Scheduler.add_message(:on_init, 'Scene_Map', 'Init baies', 99, self, :init)
  end
  # Module that helps the user to edit his worldmap
  module WorldMapEditor
    module_function
    # Main function
    def main
      ScriptLoader.load_tool('PSDKEditor')
      GameData::WorldMap.load
      ($tester = Tester.allocate).data_load
      PFM::GameState.new.expand_global_var
      Studio::Text.instance_variable_set(:@lang, Configs.language.default_language_code || en)
      select_worldmap(0)
      select_zone(0)
      init
      show_help
      Graphics.transition
      until Input::Keyboard.press?(Input::Keyboard::Escape)
        Graphics.update
        update
      end
      @viewport.dispose
    end
    # Affiche l'aide
    def show_help
      cc 2
      puts 'list_zone : list all the zone'
      puts 'list_zone("name") : list the zone that match name'
      puts 'select_zone(id) : Select the zone id to place the with the mouse on the map'
      puts 'save : Save your modifications'
      puts 'clear_map : Clear the whole map'
      puts 'list_worldmap : list all the world maps'
      puts 'list_worldmap("name") : list the world maps that match name'
      puts 'select_worldmap(id) : select the world map to edit'
      puts "add_worldmap(\"image name\", text_id, [file_id]) : add the world map with the image filename without\n        extension \n	and the given name text id in file_id (by default ruby host)"
      puts 'delete_worldmap(id) : delete the worldmap and its data, be sure before use this'
      puts "set_worldmap_name(id, new_text_id, [new_file_id]) : change the name of the worldmap to the given text id and\n        \n	the given file id (by default, file is ruby host)"
      puts 'set_worldmap_image(id, "new_image") : change the file displayed for the world map'
      cc 7
    end
    # Update the scene
    def update
      wm = GamePlay::WorldMap
      update_origin(wm)
      return if (Mouse.x < 0) || (Mouse.y < 0)
      @last_x = @x
      @last_y = @y
      @x = (Mouse.x - wm::BitmapOffset) / wm::TileSize + @ox
      @y = (Mouse.y - wm::BitmapOffset) / wm::TileSize + @oy
      @map_sprite.set_origin(@ox * wm::TileSize, @oy * wm::TileSize)
      @cursor.set_position((Mouse.x / wm::TileSize) * wm::TileSize, (Mouse.y / wm::TileSize) * wm::TileSize)
      update_infobox if (@last_x != @x) || (@last_y != @y)
      return if (@x < 0) || (@y < 0)
      update_zone if Mouse.press?(:left)
      remove_zone if Mouse.press?(:right)
    end
    # Update the current zone
    def update_zone
      GameData::WorldMap.get(@current_worldmap).data[@x, @y] = @current_zone
      update_infobox
    end
    # Clear the map
    def clear_map
      max_x = @map_sprite.width / GamePlay::WorldMap::TileSize
      max_y = @map_sprite.height / GamePlay::WorldMap::TileSize
      data = Table.new(max_x, max_y)
      0.upto(data.xsize - 1) do |x|
        0.upto(data.ysize - 1) do |y|
          data[x, y] = -1
        end
      end
      GameData::WorldMap.get(@current_worldmap).data = data
    end
    # Remove the zone
    def remove_zone
      GameData::WorldMap.get(@current_worldmap).data[@x, @y] = -1
      update_infobox
    end
    # Update the origin x/y
    # @param worldmap [Class<GamePlay::WorldMap>] should contain TileSize and BitmapOffset constants
    def update_origin(worldmap)
      @ox += 1 if Input.repeat?(:RIGHT)
      max_ox = (@map_sprite.width - Graphics.width + worldmap::BitmapOffset) / worldmap::TileSize
      max_ox = 1 if max_ox <= 0
      @ox = max_ox - 1 if @ox >= max_ox
      @ox -= 1 if Input.repeat?(:LEFT)
      @ox = 0 if @ox < 0
      @oy += 1 if Input.repeat?(:DOWN)
      max_oy = (@map_sprite.height - Graphics.height + worldmap::BitmapOffset) / worldmap::TileSize
      max_oy = 1 if max_oy <= 0
      @oy = max_oy - 1 if @oy >= max_oy
      @oy -= 1 if Input.repeat?(:UP)
      @oy = 0 if @oy < 0
    end
    # Save the world map
    def save
      GameData::WorldMap.all.each_with_index do |worldmap, id|
        worldmap.id = id
        0.upto(worldmap.data.xsize - 1) do |x|
          0.upto(worldmap.data.ysize - 1) do |y|
            worldmap.data[x, y] = -1 if data_zone(worldmap.data[x, y] || -1).db_symbol == :__undef__
          end
        end
        worldmap.zone_list_from_data.each do |zone_id|
          zone = data_zone(zone_id)
          zone.worldmaps << id unless zone.worldmaps.include?(id)
        end
      end
      save_data(GameData::WorldMap.all, 'Data/PSDK/WorldMaps.rxdata')
      PSDKEditor.convert_worldmaps(forced: true)
      File.delete('Data/Studio/psdk.dat') if File.exist?('Data/Studio/psdk.dat')
      $game_system.se_play($data_system.decision_se)
    end
    # List the zone
    def list_zone(name = '')
      name = name.downcase
      each_data_zone do |zone|
        puts "#{zone.id} : #{zone.name}" if zone && zone.name.downcase.include?(name)
      end
      show_help
    end
    # Select a zone
    def select_zone(id)
      @current_zone = id
      puts data_zone(id).name
    end
    # Select a world map
    def select_worldmap(id)
      @current_worldmap = id
      worldmap = GameData::WorldMap.get(id)
      worldmap_filename = GameData::WorldMap.worldmap_image_filename(worldmap.image)
      if RPG::Cache.interface_exist?(worldmap_filename)
        bmp = RPG::Cache.interface(worldmap_filename)
        max_x = bmp.width / GamePlay::WorldMap::TileSize
        max_y = bmp.height / GamePlay::WorldMap::TileSize
        worldmap.image = worldmap.image if worldmap.data.xsize != max_x || worldmap.data.ysize != max_y
        @map_sprite&.bitmap = bmp
      end
      puts "World map #{worldmap.name} is now selected."
    end
    # Add a new world map and select it
    # @param image [String] the image of the map in graphics/interface folder
    # @param name_id [Integer] the text id in the file
    # @param file_id [String, Integer, nil] the file to pick the region name, by default the Ruby Host
    def add_worldmap(image, name_id, file_id = nil)
      GameData::WorldMap.all.push GameData::WorldMap.new(image, name_id, file_id)
      name = GameData::WorldMap.all.last.name
      puts "World map added : #{name.downcase}"
      select_worldmap(GameData::WorldMap.all.length - 1)
      clear_map
    end
    # Delete world map
    # @param id [Integer] the id of the map to delete
    def delete_worldmap(id)
      if GameData::WorldMap.all.length <= 1
        puts 'You can\'t delete the last world map'
        return nil
      end
      puts "World map deleted : #{GameData::WorldMap.get(id)&.name}"
      GameData::WorldMap.all.delete_at(id)
      select_worldmap(0)
    end
    # Display all worldmaps
    # @param name [String, ''] the name to filter
    def list_worldmap(name = '')
      name = name.downcase
      GameData::WorldMap.all.each_with_index do |wm, index|
        puts "#{index} : #{wm.name}" if wm && wm.name.downcase.include?(name)
      end
      show_help
    end
    # Change the worldmap name to the given name text id in the given file id (by default in the ruby host)
    # @param id [Integer] the id of the world map to edit
    # @param name_id [Integer] the id of the text in the file
    # @param file_id [Integer, String, nil] the file id / name by default ruby host
    def set_worldmap_name(id, name_id, file_id = nil)
      old_name = GameData::WorldMap.get(id).name
      GameData::WorldMap.get(id).name_id = name_id
      GameData::WorldMap.get(id).name_file_id = file_id
      new_name = GameData::WorldMap.get(id).name
      puts "\"#{old_name}\" has been rename to \"#{new_name}\""
    end
    # Change the worldmap image to the given one
    # @param id [Integer] the id of the world map to edit
    # @param new_image [Integer] the new filename of the image
    def set_worldmap_image(id, new_image)
      worldmap_filename = GameData::WorldMap.worldmap_image_filename(new_image)
      if RPG::Cache.interface_exist?(worldmap_filename)
        GameData::WorldMap.get(id).image = new_image
        @map_sprite.set_bitmap(worldmap_filename, :interface) if @current_worldmap == id
        puts "#{GameData::WorldMap.get(id).name}'s' image updated to #{new_image}"
      else
        puts "#{worldmap_filename} doesn't exist!"
      end
    end
    # Init the editor
    def init
      wm = GamePlay::WorldMap
      @ox = @oy = 0
      @last_x = nil
      @last_y = nil
      @x = (Mouse.x - wm::BitmapOffset) / wm::TileSize - @ox
      @y = (Mouse.y - wm::BitmapOffset) / wm::TileSize - @oy
      init_sprites
      Object.define_method(:list_zone) { |name = ''| Yuki::WorldMapEditor.list_zone(name) }
      Object.define_method(:select_zone) { |id| Yuki::WorldMapEditor.select_zone(id) }
      Object.define_method(:save) {Yuki::WorldMapEditor.save }
      Object.define_method(:clear_map) {Yuki::WorldMapEditor.clear_map }
      Object.define_method(:select_worldmap) { |id| Yuki::WorldMapEditor.select_worldmap(id) }
      Object.define_method(:add_worldmap) { |image, text_id, file_id = nil| Yuki::WorldMapEditor.add_worldmap(image, text_id, file_id) }
      Object.define_method(:delete_worldmap) { |id| Yuki::WorldMapEditor.delete_worldmap(id) }
      Object.define_method(:list_worldmap) { |name = ''| Yuki::WorldMapEditor.list_worldmap(name) }
      Object.define_method(:set_worldmap_image) { |id, value| Yuki::WorldMapEditor.set_worldmap_image(id, value) }
      Object.define_method(:set_worldmap_name) { |id, value| Yuki::WorldMapEditor.set_worldmap_name(id, value) }
      Object.define_method(:set_worldmap_back) { |id, value| Yuki::WorldMapEditor.set_worldmap_back(id, value) }
    end
    # Create the sprites
    def init_sprites
      @viewport = Viewport.create(0, 0, 640, 480, 2000)
      @map_sprite = Sprite.new(@viewport).set_bitmap(GameData::WorldMap.worldmap_image_filename(GameData::WorldMap.get(@current_worldmap).image), :interface)
      @cursor = Sprite.new(@viewport).set_bitmap('worldmap/' + 'cursor', :interface).set_rect_div(0, 0, 1, 2)
      @infobox = Text.new(0, @viewport, @map_sprite.x + GamePlay::WorldMap::BitmapOffset, @map_sprite.y + GamePlay::WorldMap::BitmapOffset - Text::Util::FOY, @map_sprite.width - 2 * GamePlay::WorldMap::BitmapOffset, 16, nil.to_s)
    end
    # Update the infobox
    def update_infobox
      zone_id = GameData::WorldMap.get(@current_worldmap).data[@x, @y]
      zone = zone_id && (zone_id >= 0) ? data_zone(zone_id) : nil
      if zone
        @infobox.visible = true
        if zone.warp.x && zone.warp.y
          color = 2
        else
          color = 0
        end
        @infobox.text = zone.name
        @infobox.load_color(color)
      else
        @infobox.visible = false
      end
    end
  end
  # Module that display various transitions on the screen
  module Transitions
    # The number of frame the transition takes to display
    NB_Frame = 60
    module_function
    # Show a circular transition (circle reduce it size or increase it)
    # @param direction [-1, 1] -1 = out -> in, 1 = in -> out
    # @note A block can be yield if given, its parameter is i (frame) and sp1 (the screenshot)
    def circular(direction = -1)
      sp1 = ShaderedSprite.new($scene.viewport || Graphics.window)
      sp1.bitmap = Texture.new(Graphics.width, Graphics.height)
      sp1.shader = shader = Shader.create(:yuki_circular)
      shader.set_float_uniform('xfactor', sp1.bitmap.width.to_f / (h = sp1.bitmap.height))
      0.upto(NB_Frame) do |i|
        yield(i, sp1) if block_given?
        j = (direction == 1 ? i : NB_Frame - i)
        shader.set_float_uniform('r4', (r = (j / NB_Frame.to_f)) ** 2)
        shader.set_float_uniform('r3', ((r * h - 10) / h) ** 2)
        shader.set_float_uniform('r2', ((r * h - 20) / h) ** 2)
        shader.set_float_uniform('r1', ((r * h - 30) / h) ** 2)
        update_graphics_60_fps
      end
      sp1.shader = shader = nil
      dispose_sprites(sp1)
    end
    # Hash that give the angle according to the direction of the player
    Directed_Angles = {-8 => 0, 8 => 180, -4 => 90, 4 => 270, -2 => 180, 2 => 0, -6 => 270, 6 => 90}
    Directed_Angles.default = 0
    # Hash that give x factor (* w/2)
    Directed_X = {-8 => 1, 8 => 1, -4 => -2, 4 => 0, -2 => 1, 2 => 1, -6 => 4, 6 => 2}
    Directed_X.default = 0
    # Hash that give the y factor (* w/2)
    Directed_Y = {-8 => -2, 8 => 0, -4 => 1, 4 => 1, -2 => 4, 2 => 2, -6 => 1, 6 => 1}
    Directed_Y.default = 0
    # Transition that goes from up -> down or right -> left
    # @param direction [-1, 1] -1 = out -> in, 1 = in -> out
    # @note A block can be yield if given, its parameter is i (frame) and sp1 (the screenshot)
    def directed(direction = -1)
      w = Graphics.width
      w2 = w * 2.0
      gp = $game_player
      dx = gp.direction.between?(4, 6) ? w2 / NB_Frame : 0
      dy = dx == 0 ? w2 / NB_Frame : 0
      dx *= -1 if gp.direction == 6
      dy *= -1 if gp.direction == 2
      d = gp.direction * direction
      sp1 = ShaderedSprite.new($scene.viewport || Graphics.window)
      sp1.bitmap = Texture.new(w, w2.to_i)
      sp1.shader = Shader.create(:yuki_directed)
      sp1.shader.set_float_array_uniform('yval', Array.new(10) { |i| (w + 10 * i) / w2 })
      sp1.set_origin(w / 2, w)
      sp1.angle = Directed_Angles[d]
      sp1.set_position(Directed_X[d] * w / 2, Directed_Y[d] * w / 2)
      NB_Frame.times do |i|
        yield(i, sp1) if block_given?
        sp1.set_position(sp1.x + dx, sp1.y + dy)
        update_graphics_60_fps
      end
      sp1.shader = nil
      dispose_sprites(sp1)
    end
    # Display a weird transition (for battle)
    # @param nb_frame [Integer] the number of frame used for the transition
    # @param radius [Float] the radius (in texture uv) of the transition effect
    # @param max_alpha [Float] the maxium alpha value for the transition effect
    # @param min_tau [Float] the minimum tau value of the transition effect
    # @param delta_tau [Float] the derivative of tau between the begining and the end of the transition
    def weird_transition(nb_frame = 60, radius = 0.25, max_alpha = 0.5, min_tau = 0.07, delta_tau = 0.07, bitmap: nil)
      sp = ShaderedSprite.new($scene.viewport || Graphics.window)
      sp.bitmap = bitmap || $scene.snap_to_bitmap
      sp.zoom = Graphics.width / sp.bitmap.width.to_f
      sp.shader = shader = Shader.create(:yuki_weird)
      sp.set_origin(sp.bitmap.width / 2, sp.bitmap.height / 2)
      sp.set_position(Graphics.width / 2, Graphics.height / 2)
      shader.set_float_uniform('radius', radius)
      0.step(nb_frame) do |i|
        yield(i, sp) if block_given?
        shader.set_float_uniform('alpha', max_alpha * i / nb_frame)
        shader.set_float_uniform('tau', min_tau + (delta_tau * i / nb_frame))
        update_graphics_60_fps
      end
      sp.shader = shader = nil
      bitmap ? sp.dispose : dispose_sprites(sp)
    end
    # Display a BW in->out Transition
    # @param transition_sprite [Sprite] a screenshot sprite
    def bw_zoom(transition_sprite)
      60.times do
        transition_sprite.zoom_x = (transition_sprite.zoom_y *= 1.005)
        update_graphics_60_fps
      end
      30.times do
        transition_sprite.zoom_x = (transition_sprite.zoom_y *= 1.01)
        transition_sprite.opacity -= 9
        update_graphics_60_fps
      end
      transition_sprite.bitmap.dispose
      transition_sprite.dispose
    end
    # TODO: rework all animations to rely on Yuki::Animation instead of using that dirty trick
    def update_graphics_60_fps
      Graphics.update
      Graphics.update while Graphics::FPSBalancer.global.skipping?
    end
    # Dispose the sprites
    # @param args [Array<Sprite>]
    def dispose_sprites(*args)
      args.each do |sprite|
        next unless sprite
        sprite.bitmap.dispose
        sprite.dispose
      end
    end
  end
  # Module that contain every constants associated to a Swicth ID of $game_switches.
  # The description of the constants are the meaning of the switch
  module Sw
    # If the player is a female
    Gender = 1
    # If the shadow are shown under the Sprite_Character
    CharaShadow = 2
    # If the Game_Event doesn't collide with other Game_Event when they slide
    ThroughEvent = 3
    # If the surf message doesn't display when the player collide with the water tiles
    NoSurfContact = 4
    # If the common event did its work as expected or not
    EV_Acted = 5
    # If the Maplinker is disabled
    MapLinkerDisabled = 6
    # If InGame time use the SystemTime
    TJN_RealTime = 7
    # If the InGame time doesn't update
    TJN_NoTime = 8
    # If the added Pokemon has been stored
    SYS_Stored = 9
    # If the time tone is shown
    TJN_Enabled = 10
    # It's the day time
    TJN_DayTime = 11
    # It's the night time
    TJN_NightTime = 12
    # It's the moring time
    TJN_MorningTime = 13
    # It's sunset time
    TJN_SunsetTime = 14
    # BW transition when going from outside to inside (No fade on the warp)
    WRP_Transition = 15
    # If the nuzlocke is enabled
    Nuzlocke_ENA = 16
    # If the player is on AccroBike (and not on the normal bike)
    EV_AccroBike = 17
    # Disable the reset_position of Yuki::FollowMe
    FM_NoReset = 18
    # If the Yuki::FollowMe system is enabled
    FM_Enabled = 19
    # If the player can use Fly thus is outside
    Env_CanFly = 20
    # If the player can use Dig thus is in a cave
    Env_CanDig = 21
    # If the Follower are repositionned like the player warp between two exterior map
    Env_FM_REP = 22
    # If the player is on the Bicycle
    EV_Bicycle = 23
    # If the player has a Pokemon with Strength and Strength is active
    EV_Strength = 24
    # If the message system calculate the line break automatically
    MSG_Recalibrate = 25
    # If the choice are shown on top left
    MSG_ChoiceOnTop = 26
    # If the message system break lines on some punctuations
    MSG_Ponctuation = 27
    # If the actor doesn't turn to the event that show the message
    MSG_Noturn = 28
    # If the Pokemon FollowMe should use Let's Go Mode
    FollowMe_LetsGoMode = 29
    # If the battle is updating the phase (inside battle event condition)
    BT_PhaseUpdate = 30
    # If the phase 1 of the battle is running (Intro)
    BT_Phase1 = 31
    # If the phase 2 of the battle is running (Action choice)
    BT_Phase2 = 32
    # If the phase 3 of the battle is running (Target choice)
    BT_Phase3 = 33
    # If the wild Pokemon fled the battle
    BT_Wild_Flee = 34
    # If the player fled the battle
    BT_Player_Flee = 35
    # If the player was defeated
    BT_Defeat = 36
    # If the player was victorious
    BT_Victory = 37
    # If the player caught the Wild Pokemon
    BT_Catch = 38
    # If the weather in Battle change the Weather outside
    MixWeather = 39
    # If the experience calculation is harder
    BT_HardExp = 40
    # If the player cant escape the battle
    BT_NoEscape = 41
    # If the battle doesn't give exp
    BT_NoExp = 42
    # If the catch is forbidden
    BT_NoCatch = 43
    # If the Moves are replaced by no moves when Pokemon are generated for battle
    BT_NO_MOVE_WHEN_DEFAULT = 44
    # If the trainer first Pokemon is sent without ball animation
    BT_NO_BALL_ANIMATION = 45
    # Authorize defeat in the battle in nuzlocke mode
    BT_AUTHORIZE_DEFEAT_NUZLOCKE = 46
    # Add the Reminder in the Party Menu
    BT_Party_Menu_Reminder = 47
    # Make the AI able to win a battle
    BT_AI_CAN_WIN = 48
    # Disable the Battleback Name reset when you go on a new map
    DISABLE_BATTLEBACK_RESET = 49
    # If exp gain is scaled by player Pokémon level
    BT_ScaledExp = 50
    # If the Water Reflection is disabled
    WATER_REFLECTION_DISABLED = 51
    # If the player is running
    EV_Run = 52
    # If the player can run
    EV_CanRun = 53
    # If the player automatically turn on himself when walking on Rapid SystemTag
    EV_TurnRapids = 54
    #Indique si le joueur tourne dans les rapides
    # If the player triggered flash
    EV_Flash = 55
    # Weather is rain
    WT_Rain = 56
    # Weather is sunset
    WT_Sunset = 57
    # Weather is sandstorm
    WT_Sandstorm = 58
    # Weather is snow
    WT_Snow = 59
    # Weather is fog
    WT_Fog = 60
    # Disable player detection by all the detection methods
    Env_Detection = 75
    # Enable/disable if pokemon die from poison in overworld
    OW_Poison = 77
    # Failure switch (do not use)
    Alola = 96
    # Victory on the Alpha Ruins game
    RuinsVictory = 97
    # If the Yuki::FollowMe system was enabled
    FM_WasEnabled = 98
    # If the Pokedex is in National Mode
    Pokedex_Nat = 99
    # If the player got the Pokedex
    Pokedex = 100
  end
  # Module that contain every constants associated to a Variable ID of $game_variables.
  # The description of the constants are the meaning of the variable
  module Var
    # Player ID (31bits)
    Player_ID = 1
    # Number of Pokemon Seen
    Pokedex_Seen = 2
    # Number of Pokemon caught
    Pokedex_Catch = 3
    # Current Box (0 is Box 1)
    Boxes_Current = 4
    # Number the in the GamePlay::InputNumber interface (default variable)
    EnteredNumber = 5
    # Number of Pokemon to select for creating temporary team
    Max_Pokemon_Select = 6
    # ID (in the database) of the trainer battle to start
    Trainer_Battle_ID = 8
    # ID of the particle data to use in order to show particle
    PAR_DatID = 9
    # InGame hour
    TJN_Hour = 10
    # InGame minute
    TJN_Min = 11
    # InGame seconds (unused)
    TJN_Sec = 12
    # InGame day of the week (1 = Monday)
    TJN_WDay = 13
    # InGame week
    TJN_Week = 14
    # InGame Month
    TJN_Month = 15
    # InGame day of the month
    TJN_MDay = 16
    # Current Tone (0 : Night, 1 : Sunset, 3 : Day, 2 : Morning)
    TJN_Tone = 17
    # Number of Following Human
    FM_N_Human = 18
    # Number of Following Pokemon (actors one)
    FM_N_Pokem = 19
    # Number of Friend's Following Pokemon
    FM_N_Friend = 20
    # The selected Follower (1 = first, 0 = none)
    FM_Sel_Foll = 21
    # ID of the map where Dig send the player out
    E_Dig_ID = 23
    # X position where Dig send the player out
    E_Dig_X = 24
    # Y position where Dig send the player out
    E_Dig_Y = 25
    # Temporary variable 1
    TMP1 = 26
    # Temporary variable 2
    TMP2 = 27
    # Temporary variable 3
    TMP3 = 28
    # Temporary variable 4
    TMP4 = 29
    # Temporary variable 5
    TMP5 = 30
    # Trainer transition type (0 = 6G, 1 = 5G)
    TrainerTransitionType = 31
    # Map Transition type (1 = Circular, 2 = Directed)
    MapTransitionID = 32
    # Level of the AI
    AI_LEVEL = 34
    # ID (in the database) of the second trainer of the duo battle
    Second_Trainer_ID = 35
    # ID (in the database) of the allied trainer of the duo battle
    Allied_Trainer_ID = 36
    # Coin case amount of coin
    CoinCase = 41
    # Index of the Pokemon that use its skill in the Party_Menu
    Party_Menu_Sel = 43
    # ID of the map where the player return (Teleport, defeat)
    E_Return_ID = 47
    # X position of the map where the player return
    E_Return_X = 48
    # Y position of the map where the player return
    E_Return_Y = 49
    # Battle mode, 0 : Normal, 1 : P2P server, 2 : P2P Client
    BT_Mode = 50
    # Id of the current player ID
    Current_Player_ID = 51
  end
  # Module that allow to mesure elapsed time between two calls of #show
  #
  # This module is muted when PSDK_CONFIG.release? = true
  #
  # Example :
  #   Yuki::ElapsedTime.start(:test)
  #   do_something
  #   Yuki::ElapsedTime.show(:test, "Something took")
  #   do_something_else
  #   Yuki::ElapsedTime.show(:test, "Something else took")
  module ElapsedTime
    @timers = {}
    @disabled_timers = [:audio_load_sound, :map_loading, :spriteset_map, :transfer_player, :maplinker]
    module_function
    # Start the time counter
    # @param name [Symbol] name of the timer
    def start(name)
      return if PSDK_CONFIG.release? || @disabled_timers.include?(name)
      @timers[name] = Time.new
    end
    # Disable a timer
    # @param name [Symbol] name of the timer
    def disable_timer(name)
      @disabled_timers << name
    end
    # Enable a timer
    # @param name [Symbol] name of the timer
    def enable_timer(name)
      @disabled_timers.delete(name)
    end
    # Show the elapsed time between the current and the last call of show
    # @param name [Symbol] name of the timer
    # @param message [String] message to show in the console
    def show(name, message)
      return if PSDK_CONFIG.release? || @disabled_timers.include?(name)
      timer = @timers[name]
      delta_time = Time.new - timer
      if delta_time > 1
        sub_show(delta_time, message, 's')
      else
        if (delta_time *= 1000) > 1
          sub_show(delta_time, message, 'ms')
        else
          if (delta_time *= 1000) > 1
            sub_show(delta_time, message, 'us')
          else
            sub_show(delta_time * 1000, message, 'ns')
          end
        end
      end
      @timers[name] = Time.new
    end
    # Show the real message in the console
    # @param delta [Float] number of unit elapsed
    # @param message [String] message to show on the terminal with the elapsed time
    # @param unit [String] unit of the elapsed time
    def sub_show(delta, message, unit)
      STDOUT.puts(format("\r[Yuki::ElapsedTime] %<message>s : %<delta>0.2f%<unit>s", message: message, delta: delta, unit: unit))
    end
  end
  # Display a choice Window
  # @author Nuri Yuri
  class ChoiceWindow < Window
    # Array of choice colors
    # @return [Array<Integer>]
    attr_accessor :colors
    # Current choix (0~choice_max-1)
    # @return [Integer]
    attr_accessor :index
    # Name of the cursor in Graphics/Windowskins/
    CursorSkin = 'Cursor'
    # Name of the windowskin in Graphics/Windowskins/
    WINDOW_SKIN = 'Message'
    # Number of choice shown until a relative display is generated
    MaxChoice = 9
    # Index that tells the system to scroll up or down everychoice (relative display)
    DeltaChoice = (MaxChoice / 2.0).round
    # Create a new ChoiceWindow with the right parameters
    # @param width [Integer, nil] width of the window; if nil => automatically calculated
    # @param choices [Array<String>] list of choices
    # @param viewport [Viewport, nil] viewport in which the window is displayed
    def initialize(width, choices, viewport = nil)
      super(viewport)
      @texts = UI::SpriteStack.new(self)
      @choices = choices
      @colors = Array.new(@choices.size, get_default_color)
      @index = $game_temp ? $game_temp.choice_start - 1 : 0
      @index = 0 if @index >= choices.size || @index < 0
      lock
      self.width = width if width
      @autocalc_width = !width
      self.cursorskin = RPG::Cache.windowskin(CursorSkin)
      define_cursor_rect
      self.windowskin = RPG::Cache.windowskin(current_windowskin)
      self.window_builder = current_window_builder
      self.active = true
      unlock
      @my = Mouse.y
    end
    # Retrieve the current layout configuration
    # @return [Configs::Project::Texts::ChoiceConfig]
    def current_layout
      config = Configs.texts.choices
      return config[$scene.class.to_s] || config[:any]
    end
    # Update the choice, if player hit up or down the choice index changes
    def update
      return @cool_down.update if @cool_down && !@cool_down.done?
      if Input.press?(:DOWN)
        update_cursor_down
      else
        if Input.press?(:UP)
          update_cursor_up
        else
          if @my != Mouse.y || Mouse.wheel != 0
            update_mouse
          end
        end
      end
      super
    end
    # Translate the color according to the layout configuration
    # @param color [Integer] color to translate
    # @return [Integer] translated color
    def translate_color(color)
      current_layout.color_mapping[color] || color
    end
    # Return the default height of a text line
    # @return [Integer]
    def default_line_height
      Fonts.line_height(current_layout.default_font)
    end
    # Return the default text color
    # @return [Integer]
    def default_color
      return translate_color(current_layout.default_color)
    end
    alias get_default_color default_color
    # Return the disable text color
    # @return [Integer]
    def disable_color
      return translate_color(7)
    end
    alias get_disable_color disable_color
    # Update the mouse action
    def update_mouse
      @my = Mouse.y
      unless Mouse.wheel == 0
        Mouse.wheel > 0 ? update_cursor_up : update_cursor_down
        return Mouse.wheel = 0
      end
      return unless simple_mouse_in?
      @texts.stack.each_with_index do |text, i|
        next unless text.simple_mouse_in?
        if @index < i
          update_cursor_down while @index < i
        else
          if @index > i
            update_cursor_up while @index > i
          end
        end
        break
      end
    end
    # Update the choice display when player hit UP
    def update_cursor_up
      if @index == 0
        (@choices.size - 1).times {update_cursor_down }
        return
      end
      if @choices.size > MaxChoice
        self.oy -= default_line_height unless @index < DeltaChoice || @index > (@choices.size - DeltaChoice)
      end
      cursor_rect.y -= default_line_height
      @index -= 1
      cool_down
    end
    # Update the choice display when player hit DOWN
    def update_cursor_down
      @index += 1
      if @index >= @choices.size
        @index -= 1
        update_cursor_up until @index == 0
        return
      end
      if @choices.size > MaxChoice
        self.oy += default_line_height unless @index < DeltaChoice || @index > (@choices.size - DeltaChoice)
      end
      cursor_rect.y += default_line_height
      cool_down
    end
    # Change the window builder and rebuild the window
    # @param builder [Array] The new window builder
    def window_builder=(builder)
      super
      build_window
    end
    # Build the window : update the height of the window and draw the options
    def build_window
      max = @choices.size
      max = MaxChoice if max > MaxChoice
      self.height = max * default_line_height + window_builder[5] + window_builder[-1]
      refresh
    end
    # Draw the options
    def refresh
      max_width = 0
      @texts.dispose
      @choices.each_index do |i|
        text = PFM::Text.parse_string_for_messages(@choices[i]).dup
        text.gsub!(/\\[Cc]\[([0-9]+)\]/) do
          @colors[i] = translate_color($1.to_i)
          next((nil))
        end
        text.gsub!(/\\d\[(.*),(.*)\]/) {$daycare.parse_poke($1.to_i, $2.to_i) }
        real_width = add_choice_text(text, i)
        max_width = real_width if max_width < real_width
      end
      self.width = max_width + window_builder[4] + window_builder[-2] + cursor_rect.width + cursor_rect.x if @autocalc_width
      self.width += 10 if current_windowskin[0, 2].casecmp?('m_')
      @texts.stack.each { |text| text.width = max_width }
    end
    # Function that adds a choice text and manage various thing like getting the actual width of the text
    # @param text [String]
    # @param i [Integer] index in the loop
    # @return [Integer] the real width of the text
    def add_choice_text(text, i)
      if (captures = text.match(/(.+) (\$[0-9]+|[0-9]+\$)$/)&.captures)
        text_obj1 = @texts.add_text(cursor_rect.width + cursor_rect.x, i * default_line_height, 0, default_line_height, captures.first, color: @colors[i])
        text_obj2 = @texts.add_text(cursor_rect.width + cursor_rect.x, i * default_line_height, 0, default_line_height, captures.last, 2, color: translate_color(get_default_color))
        return text_obj1.real_width + text_obj2.real_width + 2 * Fonts.line_height(current_layout.default_font)
      end
      text_obj = @texts.add_text(cursor_rect.width + cursor_rect.x, i * default_line_height, 0, default_line_height, text, color: @colors[i])
      return text_obj.real_width
    end
    # Define the cursor rect
    def define_cursor_rect
      cursor_rect.set(-4, @index * default_line_height, cursorskin.width, cursorskin.height)
    end
    # Tells the choice is done
    # @return [Boolean]
    def validated?
      return (Input.trigger?(:A) || (Mouse.trigger?(:left) && simple_mouse_in?))
    end
    # Return the default horizontal margin
    # @return [Integer]
    def default_horizontal_margin
      return current_layout.border_spacing
    end
    # Return the default vertical margin
    # @return [Integer]
    def default_vertical_margin
      return current_layout.border_spacing
    end
    # Retrieve the current windowskin
    # @return [String]
    def current_windowskin
      current_layout.window_skin || $game_system.windowskin_name
    end
    # Retrieve the current window_builder
    # @return [Array]
    def current_window_builder
      return UI::Window.window_builder(current_windowskin)
    end
    # Function that creates a new ChoiceWindow for the message system
    # @param window [Window] a window that has the right window_builder (to calculate the width)
    # @return [ChoiceWindow] the choice window.
    def self.generate_for_message(window)
      choice_window = new(nil, $game_temp.choices, window.viewport)
      choice_window.z = window.z + 1
      if $game_switches[::Yuki::Sw::MSG_ChoiceOnTop]
        choice_window.set_position(choice_window.default_horizontal_margin, choice_window.default_vertical_margin)
      else
        choice_window.x = window.x + window.width - choice_window.width
        if $game_system.message_position == 2
          choice_window.y = window.y - choice_window.height - choice_window.default_vertical_margin
        else
          choice_window.y = window.y + window.height + choice_window.default_vertical_margin
        end
      end
      window.viewport.sort_z
      return choice_window
    end
    private
    def cool_down
      @cool_down = Yuki::Animation.wait(0.15)
      @cool_down.start
    end
    public
    # Display a Choice "Window" but showing buttons instead of the common window
    class But < ChoiceWindow
      # Window Builder of this kind of choice window
      WindowBuilder = [11, 3, 100, 16, 12, 3]
      # Overwrite the current window_builder
      # @return [Array]
      def current_window_builder
        WindowBuilder
      end
      # Overwrite the windowskin setter
      # @param v [Texture] ignored
      def windowskin=(v)
        super(RPG::Cache.interface('team/select_button'))
      end
    end
  end
  class GifReader
    class << self
      # Create a new GifReader from archives
      # @param filename [String] name of the gif file, including the .gif extension
      # @param cache_name [Symbol] name of the cache where to load the gif file
      # @param hue [Integer] 0 = normal, 1 = shiny for Pokemon battlers
      # @return [GifReader, nil]
      def create(filename, cache_name, hue = 0)
        gif_data = RPG::Cache.send(cache_name, filename, hue)
        return log_error("Failed to load GIF: #{cache_name} => #{filename}") && nil unless gif_data
        return GifReader.new(gif_data, true)
      end
      # Check if a Gif Exists
      # @param filename [String] name of the gif file, including the .gif extension
      # @param cache_name [Symbol] name of the cache where to load the gif file
      # @param hue [Integer] 0 = normal, 1 = shiny for Pokemon battlers
      # @return [Boolean]
      def exist?(filename, cache_name, hue = 0)
        cache_exist = :"#{cache_name}_exist?"
        return RPG::Cache.send(cache_exist, filename) if hue == 0
        return RPG::Cache.send(cache_exist, filename, hue)
      end
    end
    alias old_update update
    # Update function that takes in account framerate of the game
    # @param bitmap [LiteRGSS::Bitmap] texture that receive the update
    # @return [self]
    def update(bitmap)
      old_update(bitmap) unless Graphics::FPSBalancer.global.skipping? && @was_updated
      @was_updated = true
      return self
    end
  end
  # Debugguer for PSDK (UI)
  class Debug
    # Create a new Debug instance
    def initialize
      reset_screen unless @viewport
      create_viewport
      create_main_ui
      Graphics.sort_z
    end
    # Update the debug each frame
    def update
      initialize if @viewport.disposed?
      @main_ui.update
    end
    private
    # Create the debugguer viewport
    def create_viewport
      @viewport = Viewport.new(0, 0, 1280, 720)
      @viewport.z = 0
    end
    # Create the main debugger UI
    def create_main_ui
      @main_ui = MainUI.new(@viewport)
    end
    # Reset the game screen in order to make the debugger (set the window size to 1280x720 and the scale to 1)
    def reset_screen
      settings = Graphics.window.settings
      settings[1] = 1280
      settings[2] = 720
      settings[3] = 1
      Graphics.window.settings = settings
      Graphics.reset_mouse_viewport
      PSDK_CONFIG.instance_variable_set(:@window_scale, 1)
    end
    class << self
      # Create a new debugger instance and delete the related message
      def create_debugger
        @debugger = Debug.new
        Scheduler.__remove_task(:on_update, :any, 'Yuki::Debug', 0)
        Scheduler.add_message(:on_update, :any, 'Yuki::Debug', 0, @debugger, :update)
      end
    end
    public
    # Main UI of the debugger
    class MainUI
      # @return [Integer] x position of the GUI on the screen
      SCREEN_X = 322
      # Create a new MainUI for the debug system
      # @param viewport [Viewport] viewport used to display the UI
      def initialize(viewport)
        @stack = UI::SpriteStack.new(viewport, SCREEN_X)
        @viewport = viewport
        create_class_text
        create_systag_ui
        create_groups_ui
      end
      # Update the gui
      def update
        update_class_text
        update_systag_ui
        update_groups_ui
      end
      private
      # Create the class text
      def create_class_text
        @class_text = @stack.add_text(0, 0, 320, 16, 'TEST', color: 9)
        @last_scene = nil
      end
      # Update the class text
      def update_class_text
        if $scene != @last_scene
          @last_scene = $scene
          @class_text.text = "Current scene : #{$scene.class}"
        end
      end
      # Create the systag UI
      def create_systag_ui
        @systag_ui = SystemTags.new(@viewport, @stack)
      end
      # Update the systag ui
      def update_systag_ui
        @systag_ui.update
      end
      # Create the groups UI
      def create_groups_ui
        @groups_ui = Groups.new(@viewport, @stack)
      end
      # Update the group UI
      def update_groups_ui
        @groups_ui.update
      end
    end
    public
    # Show the system tag in debug mod
    class SystemTags
      # Create a new system tags viewer
      # @param viewport [Viewport]
      # @param stack [UI::SpriteStack] main stack giving the coordinates to use
      def initialize(viewport, stack)
        @stack = UI::SpriteStack.new(viewport, stack.x, stack.y + 16, default_cache: :tileset)
        @current_tag_sprite = @stack.push(34, 16, 'prio_w', rect: [0, 0, 32, 32])
        @front_tag_sprite = @stack.push(134, 16, 'prio_w', rect: [0, 0, 32, 32])
        @stack.add_text(0, 0, 100, 16, 'Current SysTag', 1, color: 9)
        @stack.add_text(100, 0, 100, 16, 'Front SysTag', 1, color: 9)
        @terrain_tag = @stack.add_text(34, 16, 32, 16, '', 2, 1, color: 9)
      end
      # Update the view
      def update
        if $scene.is_a?(Scene_Map) && $game_player
          @stack.visible ||= true
          if @last_x != $game_player.x || @last_y != $game_player.y || @last_dir != $game_player.direction
            tag = $game_player.system_tag
            tag = tag < 384 ? 0 : tag - 384
            @current_tag_sprite.src_rect.set(tag % 8 * 32, tag / 8 * 32)
            tag = $game_player.front_system_tag
            tag = tag < 384 ? 0 : tag - 384
            @front_tag_sprite.src_rect.set(tag % 8 * 32, tag / 8 * 32)
            @terrain_tag.text = $game_player.terrain_tag.to_s
            @last_x = $game_player.x
            @last_y = $game_player.y
            @last_dir = $game_player.direction
          end
        else
          @stack.visible &&= false
        end
      end
    end
    public
    # Show the Groups in debug mod
    class Groups
      # Create a new Group viewer
      # @param viewport [Viewport]
      # @param stack [UI::SpriteStack] main stack giving the coordinates to use
      def initialize(viewport, stack)
        @stack = UI::SpriteStack.new(viewport, stack.x, stack.y + 64, default_cache: :b_icon)
        @width = viewport.rect.width - stack.x
        @height = viewport.rect.height - @stack.y
      end
      # Update the view
      def update
        if $scene.is_a?(Scene_Map) && $wild_battle
          @stack.visible ||= true
          if @last_groups != $wild_battle.groups || @last_id != $game_map.map_id
            @last_groups = $wild_battle.groups
            @last_id = $game_map.map_id
            @stack.dispose
            load_groups
          end
        else
          @stack.visible &&= false
        end
      end
      # Load the groups
      def load_groups
        @stack.add_text(0, 0, 320, 16, "Zone : #{$env.get_current_zone_data&.name}", color: 9)
        load_remaining_groups(16)
      end
      # Load the remaining groups
      # @param y [Integer] initial y position
      # @return [Integer] final y position
      def load_remaining_groups(y)
        x = 0
        $wild_battle.groups.each do |group|
          break if y >= @height
          @stack.add_text(x, y, 320, 16, "#{group.system_tag} (#{group.terrain_tag}) #{group.tool}", color: 9)
          group.encounters.each do |encounter|
            female = encounter.extra[:gender] == 2
            shiny = encounter.shiny_setup.shiny
            icon_filename = PFM::Pokemon.icon_filename(data_creature(encounter.specie).id, encounter.form, female, shiny, false)
            @stack.push(x, y, icon_filename)
            x += 32
            if x >= @width
              y += 32
              x = 0
            end
            break if y >= @height
          end
          y += 32
          x = 0
        end
        return y
      end
    end
  end
  unless PSDK_CONFIG.release?
    Scheduler.add_proc(:on_update, :any, 'Yuki::Debug', 0) do
      Debug.create_debugger if Input::Keyboard.press?(Input::Keyboard::F9)
    end
  end
  # Module containing all the animation utility
  module Animation
    pi_div2 = Math::PI / 2
    # Hash describing all the distrotion procs
    DISTORTIONS = {SMOOTH_DISTORTION: proc { |x| 1 - Math.cos(pi_div2 * x ** 1.5) ** 5 }, UNICITY_DISTORTION: proc { |x| x }, SQUARE010_DISTORTION: proc { |x| 1 - (x * 2 - 1) ** 2 }}
    # Hash describing all the time sources
    TIME_SOURCES = {GENERIC_TIME_SOURCE: Graphics.method(:current_time)}
    # Default object resolver (make the game crash)
    DEFAULT_RESOLVER = proc { |x| raise "Couldn't resolve object :#{x}" }
    module_function
    # Create a "wait" animation
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def wait(during, time_source: :GENERIC_TIME_SOURCE)
      TimedAnimation.new(during, :UNICITY_DISTORTION, time_source)
    end
    # Class calculating time offset for animation.
    #
    # This class also manage parallel & sub animation. Example :
    #   (TimedAnimation.new(1) | TimedAnimation.new(2) > TimedAnimation.new(3)).root
    #   # Is equivalent to
    #   TimedAnimation.new(1).parallel_play(TimedAnimation.new(2)).play_before(TimedAnimation.new(3)).root
    #   # Which is equivalent to : play 1 & 2 in parallel and then play 3
    #   # Note that if 2 has sub animation, its sub animation has to finish in order to see animation 3
    class TimedAnimation
      # @return [Array<TimedAnimation>] animation playing in parallel
      attr_reader :parallel_animations
      # @return [TimedAnimation, nil] animation that plays after
      attr_reader :sub_animation
      # @return [TimedAnimation] the root animation
      #   (to retreive the right animation to play when building animation using operators)
      attr_accessor :root
      # Get the begin time of the animation (if started)
      # @return [Time, nil]
      attr_reader :begin_time
      # Get the end time of the animation (if started)
      # @return [Time, nil]
      attr_reader :end_time
      # Get the time source of the animation (if started)
      # @return [#call, nil]
      attr_reader :time_source
      # Create a new TimedAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      #   convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, distortion = :UNICITY_DISTORTION, time_source = :GENERIC_TIME_SOURCE)
        @time_to_process = time_to_process.to_f
        @distortion_param = distortion
        @time_source_param = time_source
        @sub_animation = nil
        @parallel_animations = []
        @root = self
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        @distortion = DISTORTIONS[@distortion_param] || resolve(@distortion_param)
        @time_source = TIME_SOURCES[@time_source_param] || resolve(@time_source_param)
        @begin_time = @time_source.call + begin_offset
        @end_time = @begin_time + @time_to_process
        @parallel_animations.each { |animation| animation.start(begin_offset) }
        @sub_animation&.start(begin_offset + @time_to_process)
        @played_until_end = false
      end
      # Indicate if the animation is done
      # @note should always be called after start
      # @return [Boolean]
      def done?
        private_done? && @parallel_animations.all?(&:done?) && (@sub_animation ? @sub_animation.done? : true) && @played_until_end
      end
      # Update the animation internal time and call update_internal with a parameter between
      # 0 & 1 indicating the progression of the animation
      # @note should always be called after start
      def update
        return unless private_began?
        return if done?
        @parallel_animations.each(&:update)
        if private_done?
          unless @played_until_end
            update_internal(@distortion.call(1))
            @played_until_end = true
          end
          return unless @parallel_animations.all?(&:done?)
          return @sub_animation&.update
        end
        update_internal(@distortion.call((@time_source.call - @begin_time) / @time_to_process))
      end
      # Add a parallel animation
      # @param other [TimedAnimation] the parallel animation to add
      # @return [self]
      def parallel_add(other)
        @parallel_animations << other
        return self
      end
      alias_method :<<, :parallel_add
      alias_method :|, :parallel_add
      alias_method :parallel_play, :parallel_add
      # Add this animation in parallel of another animation
      # @param other [TimedAnimation] the parallel animation to add
      # @return [TimedAnimation] the animation parameter
      def in_parallel_of(other)
        other.parallel_add(self)
        return other
      end
      alias_method :>>, :in_parallel_of
      # Add a sub animation
      # @param other [TimedAnimation]
      # @return [TimedAnimation] the animation parameter
      def play_before(other)
        if @sub_animation
          @sub_animation.play_before(other)
        else
          @sub_animation = other
        end
        other.root = root
        return other
      end
      alias_method :>, :play_before
      # Define the resolver (and transmit it to all the childs / parallel)
      # @param resolver [#call] callable that takes 1 parameter and return an object
      def resolver=(resolver)
        @resolver = resolver
        @sub_animation&.resolver = resolver
        @parallel_animations.each { |animation| animation.resolver = resolver }
      end
      private
      # Indicate if this animation in particular is done (not the parallel, not the sub, this one)
      # @return [Boolean]
      def private_done?
        @time_source.call >= @end_time
      end
      # Indicate if this animation in particular has started
      def private_began?
        @time_source.call >= @begin_time
      end
      # Method you should always overwrite in order to perform the right animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
      end
      # Resolve an object from a symbol using the resolver
      # @param param [Symbol, Object]
      # @return [Object]
      def resolve(param)
        return param unless param.is_a?(Symbol)
        return (@resolver || DEFAULT_RESOLVER).call(param)
      end
    end
    # Class responsive of making "looped" animation
    #
    # This class works exactly the same as TimedAnimation putting asside it's always done and will update its sub/parallel animations.
    # When the loop duration is reached, it restart all the animations with the apprioriate offset.
    #
    # @note This kind of animation is not designed for object creation, please refrain from creating objects inside those kind of animations.
    class TimedLoopAnimation < TimedAnimation
      # Update the looped animation
      def update
        if @time_source.call > @end_time
          start(((@time_source.call - @end_time) % @time_to_process))
        end
        @parallel_animations.each(&:update)
        return unless @parallel_animations.all?(&:done?)
        @sub_animation&.update
      end
      # Start the animation but without sub_animation bug
      # (it makes no sense that the sub animation start after a looped animation)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        sub_animation = @sub_animation
        @sub_animation = nil
        super
        @sub_animation = sub_animation
        sub_animation&.start(begin_offset)
      end
      # Looped animations are always done
      def done?
        return true
      end
    end
    # Create a rotation animation
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param angle_start [Float, Symbol] start angle
    # @param angle_end [Float, Symbol] end angle
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def rotation(during, on, angle_start, angle_end, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      ScalarAnimation.new(during, on, :angle=, angle_start, angle_end, distortion: distortion, time_source: time_source)
    end
    # Create a opacity animation
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param opacity_start [Float, Symbol] start opacity
    # @param opacity_end [Float, Symbol] end opacity
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def opacity_change(during, on, opacity_start, opacity_end, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      ScalarAnimation.new(during, on, :opacity=, opacity_start, opacity_end, distortion: distortion, time_source: time_source)
    end
    # Create a scalar animation
    # @param time_to_process [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param property [Symbol] name of the property to affect (add the = sign in the symbol name)
    # @param a [Float, Symbol] origin position
    # @param b [Float, Symbol] destination position
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def scalar(time_to_process, on, property, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      return ScalarAnimation.new(time_to_process, on, property, a, b, distortion: distortion, time_source: time_source)
    end
    # Class that perform a scalar animation (set object.property to a upto b depending on the animation)
    class ScalarAnimation < TimedAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param property [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param a [Float, Symbol] origin position
      # @param b [Float, Symbol] destination position
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, property, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, distortion, time_source)
        @origin_param = a
        @end_param = b
        @on_param = on
        @property = property
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @on = resolve(@on_param)
        @origin = resolve(@origin_param)
        @delta = resolve(@end_param) - @origin
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        @on.send(@property, @origin + @delta * time_factor)
      end
    end
    # Scalar animation with offset
    class ScalarOffsetAnimation < ScalarAnimation
      # Create a new ScalarOffsetAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param property_get [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param property_set [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param a [Float, Symbol] origin position
      # @param b [Float, Symbol] destination position
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, property_get, property_set, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, on, property_set, a, b, distortion: distortion, time_source: time_source)
        @property_get = property_get
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        current_value = @on.send(@property_get)
        @on.send(@property, current_value + @origin + @delta * time_factor)
      end
    end
    # Create a new ScalarOffsetAnimation
    # @return [ScalarOffsetAnimation]
    def scalar_offset(time_to_process, on, property_get, property_set, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      return ScalarOffsetAnimation.new(time_to_process, on, property_get, property_set, a, b, distortion: distortion, time_source: time_source)
    end
    # Create a move animation (from a to b)
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param start_x [Float, Symbol] start x
    # @param start_y [Float, Symbol] start y
    # @param end_x [Float, Symbol] end x
    # @param end_y [Float, Symbol] end y
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def move(during, on, start_x, start_y, end_x, end_y, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      Dim2Animation.new(during, on, :set_position, start_x, start_y, end_x, end_y, distortion: distortion, time_source: time_source)
    end
    # Create a move animation (from a to b) with discreet values (Integer)
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param start_x [Float, Symbol] start x
    # @param start_y [Float, Symbol] start y
    # @param end_x [Float, Symbol] end x
    # @param end_y [Float, Symbol] end y
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def move_discreet(during, on, start_x, start_y, end_x, end_y, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      Dim2AnimationDiscreet.new(during, on, :set_position, start_x, start_y, end_x, end_y, distortion: distortion, time_source: time_source)
    end
    # Create a origin pixel shift animation (from a to b inside the bitmap)
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param start_x [Float, Symbol] start ox
    # @param start_y [Float, Symbol] start oy
    # @param end_x [Float, Symbol] end ox
    # @param end_y [Float, Symbol] end oy
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def shift(during, on, start_x, start_y, end_x, end_y, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      Dim2Animation.new(during, on, :set_origin, start_x, start_y, end_x, end_y, distortion: distortion, time_source: time_source)
    end
    # Class that perform a 2D animation (from point a to point b)
    class Dim2Animation < TimedAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param property [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param a_x [Float, Symbol] origin x position
      # @param a_y [Float, Symbol] origin y position
      # @param b_x [Float, Symbol] destination x position
      # @param b_y [Float, Symbol] destination y position
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, property, a_x, a_y, b_x, b_y, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, distortion, time_source)
        @origin_x_param = a_x
        @origin_y_param = a_y
        @end_x = b_x
        @end_y = b_y
        @on_param = on
        @property = property
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @on = resolve(@on_param)
        @origin_x = resolve(@origin_x_param)
        @origin_y = resolve(@origin_y_param)
        @delta_x = resolve(@end_x) - @origin_x
        @delta_y = resolve(@end_y) - @origin_y
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        @on.send(@property, @origin_x + @delta_x * time_factor, @origin_y + @delta_y * time_factor)
      end
    end
    # Create a src_rect.x animation
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property (please give sprite.src_rect)
    # @param cell_start [Integer, Symbol] start opacity
    # @param cell_end [Integer, Symbol] end opacity
    # @param width [Integer, Symbol] width of the cell
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def cell_x_change(during, on, cell_start, cell_end, width, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      DiscreetAnimation.new(during, on, :x=, cell_start, cell_end, width, distortion: distortion, time_source: time_source)
    end
    # Create a src_rect.y animation
    # @param during [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property (please give sprite.src_rect)
    # @param cell_start [Integer, Symbol] start opacity
    # @param cell_end [Integer, Symbol] end opacity
    # @param width [Integer, Symbol] width of the cell
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def cell_y_change(during, on, cell_start, cell_end, width, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      DiscreetAnimation.new(during, on, :y=, cell_start, cell_end, width, distortion: distortion, time_source: time_source)
    end
    # Class that perform a discreet number animation (set object.property to a upto b using integer values only)
    class DiscreetAnimation < TimedAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param property [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param a [Integer, Symbol] origin position
      # @param b [Integer, Symbol] destination position
      # @param factor [Integer, Symbol] factor applied to a & b to produce stuff like src_rect animation (sx * width)
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, property, a, b, factor = 1, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, distortion, time_source)
        @origin_param = a
        @end_param = b
        @factor_param = factor
        @on_param = on
        @property = property
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @on = resolve(@on_param)
        @origin = resolve(@origin_param)
        @base = @origin
        @end = resolve(@end_param)
        @delta = @end - @origin + 1
        @end, @origin = @origin, @end if @end < @origin
        @factor = resolve(@factor_param)
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        @on.send(@property, (@base + @delta * time_factor).to_i.clamp(@origin, @end) * @factor)
      end
    end
    # Class that perform a 2D animation (from point a to point b)
    class Dim2AnimationDiscreet < TimedAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param property [Symbol] name of the property to affect (add the = sign in the symbol name)
      # @param a_x [Float, Symbol] origin x position
      # @param a_y [Float, Symbol] origin y position
      # @param b_x [Float, Symbol] destination x position
      # @param b_y [Float, Symbol] destination y position
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, property, a_x, a_y, b_x, b_y, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, distortion, time_source)
        @origin_x_param = a_x
        @origin_y_param = a_y
        @end_x_param = b_x
        @end_y_param = b_y
        @on_param = on
        @property = property
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @on = resolve(@on_param)
        @origin_x = resolve(@origin_x_param)
        @origin_y = resolve(@origin_y_param)
        @delta_x = resolve(@end_x_param) - @origin_x
        @delta_y = resolve(@end_y_param) - @origin_y
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        @on.send(@property, (@origin_x + @delta_x * time_factor).to_i, (@origin_y + @delta_y * time_factor).to_i)
      end
    end
    # Class that describe a SpriteSheet animation
    class SpriteSheetAnimation < TimedAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [SpriteSheet, Symbol] object that will receive the property
      # @param cells [Array<Array<Integer>>, Symbol] all the select arguments that should be sent during the animation
      # @param rounding [Symbol] kind of rounding, can be: :ceil, :round, :floor
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, cells, rounding = :round, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, distortion, time_source)
        @cells_param = cells
        @on_param = on
        @rounding = rounding
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @on = resolve(@on_param)
        @cells = resolve(@cells_param)
        @delta_time = 1.0 / (@cells.size - 1)
        @last_cell = nil
      end
      private
      # Update the scalar animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        current_cell = (time_factor / @delta_time).send(@rounding)
        return if current_cell == @last_cell
        @on.select(*@cells[current_cell]) if @cells[current_cell]
        @last_cell = current_cell
      end
    end
    public
    module_function
    # Class executing commands for animations (takes 0 seconds to proceed and then needs no time information)
    # @note This class inherit from TimedAnimation to allow composition with it but it overwrite some components
    # @note Animation inheriting from this class has a `update_internal` with no parameters!
    class Command < TimedAnimation
      # Create a new Command
      def initialize
        @sub_animation = nil
        @parallel_animations = []
        @root = self
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        @parallel_animations.each { |animation| animation.start(begin_offset) }
        @sub_animation&.start(begin_offset)
        @played_until_end = false
      end
      # Update the animation internal time and call update_internal with no parameter
      # @note should always be called after start
      def update
        return if done?
        @parallel_animations.each(&:update)
        if private_done?
          unless @played_until_end
            @played_until_end = true
            update_internal
          end
          return unless @parallel_animations.all?(&:done?)
          return @sub_animation&.update
        end
      end
      private
      # Indicate if this animation in particular is done (not the parallel, not the sub, this one)
      # @return [Boolean]
      def private_done?
        true
      end
      # Indicate if this animation in particular has started
      def private_began?
        true
      end
      # Perform the animation action
      def update_internal
      end
    end
    # Play a BGM
    # @param filename [String] name of the file inside Audio/BGM
    # @param volume [Integer] volume to play the bgm
    # @param pitch [Integer] pitch used to play the bgm
    def bgm_play(filename, volume = 100, pitch = 100)
      AudioCommand.new(:bgm_play, filename, volume, pitch)
    end
    # Stop the bgm
    def bgm_stop
      AudioCommand.new(:bgm_stop)
    end
    # Play a BGS
    # @param filename [String] name of the file inside Audio/BGS
    # @param volume [Integer] volume to play the bgs
    # @param pitch [Integer] pitch used to play the bgs
    def bgs_play(filename, volume = 100, pitch = 100)
      AudioCommand.new(:bgs_play, filename, volume, pitch)
    end
    # Stop the bgs
    def bgs_stop
      AudioCommand.new(:bgs_stop)
    end
    # Play a ME
    # @param filename [String] name of the file inside Audio/ME
    # @param volume [Integer] volume to play the me
    # @param pitch [Integer] pitch used to play the me
    def me_play(filename, volume = 100, pitch = 100)
      AudioCommand.new(:me_play, filename, volume, pitch)
    end
    # Play a SE
    # @param filename [String] name of the file inside Audio/SE
    # @param volume [Integer] volume to play the se
    # @param pitch [Integer] pitch used to play the se
    def se_play(filename, volume = 100, pitch = 100)
      AudioCommand.new(:se_play, filename, volume, pitch)
    end
    # Animation command responsive of playing / stopping audio.
    # It sends the type command to Audio with *args as parameter.
    #
    # Example: Playing a SE
    #   AudioCommand.new(:se_play, 'audio/se/filename', 80, 80)
    class AudioCommand < Command
      # Create a new AudioCommand
      # @param type [Symbol] name of the method of Audio to call
      # @param args [Array] parameter to send to the command
      def initialize(type, *args)
        super()
        @type = type
        @args = args
        @args.each_with_index { |arg, i| @args[i] = resolve(arg) }
        @args[0] &&= 'Audio/' + @type.to_s.sub('_play', '') + '/' + @args.first
      end
      private
      # Execute the audio command
      def update_internal
        Audio.send(@type, *@args)
      end
    end
    # Create a new sprite
    # @param viewport [Symbol] viewport to use inside the resolver
    # @param name [Symbol] name of the sprite inside the resolver
    # @param type [Class] class to use in order to create the sprite
    # @param args [Array] argument to send to the sprite in order to create it (sent after viewport)
    # @param properties [Array<Array>] list of properties to call with their values
    def create_sprite(viewport, name, type, args = nil, *properties)
      SpriteCreationCommand.new(viewport, name, type, args, *properties)
    end
    # Animation command responsive of creating sprites and storing them inside the resolver
    #
    # Example :
    #   SpriteCreationCommand.new(:main, :star1, SpriteSheet, [1, 3], [:select, 0, 1], [:set_position, 160, 120])
    #   # This will create a spritesheet at the coordinate 160, 120 and display the cell 0,1
    class SpriteCreationCommand < Command
      # Create a new SpriteCreationCommand
      # @param viewport [Symbol] viewport to use inside the resolver
      # @param name [Symbol] name of the sprite inside the resolver
      # @param type [Class] class to use in order to create the sprite
      # @param args [Array] argument to send to the sprite in order to create it (sent after viewport)
      # @param properties [Array<Array>] list of properties to call with their values
      def initialize(viewport, name, type, args, *properties)
        super()
        @viewport = viewport
        @name = name
        @type = type
        @args = args
        @properties = properties
      end
      private
      # Execute the sprite creation command
      def update_internal
        sprite = @type.new(resolve(@viewport), *@args)
        @properties.each { |property| sprite.send(*property) }
        @resolver.receiver[@name] = sprite
      end
    end
    # Send a command to an object in the resolver
    # @param name [Symbol] name of the object in the resolver
    # @param command [Symbol] name of the method to call
    # @param args [Array] arguments to send to the method
    def send_command_to(name, command, *args)
      ResolverObjectCommand.new(name, command, *args)
    end
    # Dispose a sprite
    # @param name [Symbol] name of the sprite in the resolver
    def dispose_sprite(name)
      ResolverObjectCommand.new(name, :dispose)
    end
    # Animation command that sends a message to an object in the resolver
    #
    # Example :
    #   ResolverObjectCommand.new(:star1, :set_position, 0, 0)
    #   # This will call set_position(0, 0) on the star1 object in the resolver
    class ResolverObjectCommand < Command
      # Create a new ResolverObjectCommand
      # @param name [Symbol] name of the object in the resolver
      # @param command [Symbol] name of the method to call
      # @param args [Array] arguments to send to the method
      def initialize(name, command, *args)
        super()
        @name = name
        @command = command
        @args = args
      end
      private
      # Execute the command
      def update_internal
        resolve(@name).send(@command, *@args)
      end
    end
    # Try to run commands during a specific duration and giving a fair repartition of the duraction for each commands
    # @note Never put dispose command inside this command, there's risk that it does not execute
    # @param duration [Float] number of seconds (with generic time) to process the animation
    # @param animation_commands [Array<Command>]
    def run_commands_during(duration, *animation_commands)
      TimedCommands.new(duration, *animation_commands)
    end
    # Animation that try to execute all the given command at total_time / n_command * command_index
    # Example :
    #   TimedCommands.new(1,
    #     create_sprite(:main, :star1, SpriteSheet, [1, 3], [:select, 0, 0]),
    #     send_command_to(:star1, :select, 0, 1),
    #     send_command_to(:star1, :select, 0, 2),
    #   )
    #   # Will create the start at 0
    #   # Will set the second cell at 0.33
    #   # Will set the third cell at 0.66
    # @note It'll skip all the commands that are not SpriteCreationCommand if it's "too late"
    class TimedCommands < DiscreetAnimation
      # Create a new TimedCommands object
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param animation_commands [Array<Command>]
      def initialize(time_to_process, *animation_commands)
        raise 'TimedCommands requires at least one command' if animation_commands.empty?
        super(time_to_process, self, :run_command, 0, animation_commands.size - 1)
        @animation_commands = animation_commands
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        @animation_commands.each { |cmd| cmd.start(begin_offset) }
        @last_command = nil
      end
      # Define the resolver (and transmit it to all the childs / parallel)
      # @param resolver [#call] callable that takes 1 parameter and return an object
      def resolver=(resolver)
        super
        @animation_commands.each { |animation| animation.resolver = resolver }
      end
      private
      # Execute a command
      # @param index [Integer] index of the command
      def run_command(index)
        if index != @last_command
          @last_command ||= 0
          (@last_command + 1).upto(index - 1) do |command_index|
            @animation_commands[command_index].update if @animation_commands[command_index].is_a?(SpriteCreationCommand)
          end
          @animation_commands[index].update
          @last_command = index
        end
      end
    end
    public
    module_function
    # Function that creates a message locked animation
    def message_locked_animation
      return MessageLocked.new(0)
    end
    # Animation that doesn't update when message box is still visible
    class MessageLocked < TimedAnimation
      # Update the animation (if message window is not visible)
      def update
        return if $game_temp.message_window_showing || $game_temp.message_text
        super
      end
    end
    public
    # Class handling several animation at once
    class Handler < Hash
      # Update all the animations
      def update
        each_value(&:update)
        delete_if { |_, v| v.done? }
      end
      # Tell if all animation are done
      def done?
        all? { |_, v| v.done? }
      end
    end
    public
    module_function
    # Animation resposive of positinning a sprite between two other sprites
    class MoveSpritePosition < ScalarAnimation
      # Create a new ScalarAnimation
      # @param time_to_process [Float] number of seconds (with generic time) to process the animation
      # @param on [Object] object that will receive the property
      # @param a [Symbol] origin sprite position
      # @param b [Symbol] destination sprite position
      # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
      # convert it to another number (between 0 & 1) in order to distord time
      # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
      def initialize(time_to_process, on, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
        super(time_to_process, on, :x=, 0, 1, distortion: distortion, time_source: time_source)
        @origin_sprite = a
        @destination_sprite = b
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        super
        origin_sprite = resolve(@origin_sprite)
        destination_sprite = resolve(@destination_sprite)
        @delta_x = destination_sprite.x - origin_sprite.x
        @origin_x = origin_sprite.x
        @delta_y = destination_sprite.y - origin_sprite.y
        @origin_y = origin_sprite.y
        @delta_z = destination_sprite.z - origin_sprite.z
        @origin_z = origin_sprite.z
      end
      # Method you should always overwrite in order to perform the right animation
      # @param time_factor [Float] number between 0 & 1 indicating the progression of the animation
      def update_internal(time_factor)
        @on.set_position(@origin_x + @delta_x * time_factor, @origin_y + @delta_y * time_factor)
        @on.z = @origin_z + @delta_z * time_factor
      end
    end
    # Create a new ScalarAnimation
    # @param time_to_process [Float] number of seconds (with generic time) to process the animation
    # @param on [Object] object that will receive the property
    # @param a [Symbol] origin sprite position
    # @param b [Symbol] destination sprite position
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    # @return [MoveSpritePosition]
    def move_sprite_position(time_to_process, on, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
      MoveSpritePosition.new(time_to_process, on, a, b, distortion: :UNICITY_DISTORTION, time_source: :GENERIC_TIME_SOURCE)
    end
    # Create a new TimedLoopAnimation
    # @param time_to_process [Float] number of seconds (with generic time) to process the animation
    # @param distortion [#call, Symbol] callable taking one paramater (between 0 & 1) and
    # convert it to another number (between 0 & 1) in order to distord time
    # @param time_source [#call, Symbol] callable taking no parameter and giving the current time
    def timed_loop_animation(time_to_process, distortion = :UNICITY_DISTORTION, time_source = :GENERIC_TIME_SOURCE)
      TimedLoopAnimation.new(time_to_process, distortion, time_source)
    end
    # Class that help to handle animations that depends on sprite creation commands
    #
    # @example Create a fully resolved animation
    #   root_anim = Yuki::Animation.create_sprite(:viewport, :sprite, Sprite)
    #   resolved_animation = Yuki::Animation.resolved
    #   root_anim.play_before(resolved_animation)
    #   resolved_animation.play_before(...)
    #   resolved_animation.play_before(...)
    #   resolved_animation.parallel_play(...)
    #   root_anim.play_before(Yuki::Animation.dispose_sprite(:sprite))
    #
    # @note The play command of all animation played before resolved animation will be called after all previous animation were called.
    #       It's a good practice not to put something else than dispose command after a fully resolved animation.
    class FullyResolvedAnimation < TimedAnimation
      # Create a new fully resolved animation
      def initialize
        super(0)
      end
      alias timed_animation_start start
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        @begin_offset = begin_offset
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        !@begin_offset && super
      end
      # Update the animation internal time and call update_internal with a parameter between
      # 0 & 1 indicating the progression of the animation
      # @note should always be called after start
      def update
        timed_animation_start(@begin_offset) if @begin_offset
        @begin_offset = nil
        super
      end
    end
    # Create a fully resolved animation
    # @return [FullyResolvedAnimation]
    def resolved
      return FullyResolvedAnimation.new
    end
    public
    # Animation that wait for a signal in order to start the sub animation
    class SignalWaiter < Command
      # Create a new SignalWaiter
      # @param name [Symbol] name of the block in resolver to call to know if the signal is there
      # @param args [Array] optional arguments to the block
      # @param block [Proc] if provided, name will be ignored and this block will be used (it prevents this animation from being savable!)
      def initialize(name = nil, *args, &block)
        super()
        @name = name || block
        @args = args
      end
      # Start the animation (initialize it)
      # @param begin_offset [Float] offset that prevents the animation from starting before now + begin_offset seconds
      def start(begin_offset = 0)
        @temp_sub_animation = @sub_animation
        @sub_animation = nil
        super
        @block_to_call = resolve(@name)
      end
      private
      # Indicate if this animation in particular is done (not the parallel, not the sub, this one)
      # @return [Boolean]
      def private_done?
        @played_until_end || @block_to_call.call(*@args)
      end
      # Perform the animation action
      def update_internal
        @sub_animation = @temp_sub_animation
        @sub_animation&.start
      end
    end
    module_function
    # Create a new SignalWaiter animation
    # @param name [Symbol] name of the block in resolver to call to know if the signal is there
    # @param args [Array] optional arguments to the block
    # @param block [Proc] if provided, name will be ignored and this block will be used (it prevents this animation from being savable!)
    # @return [SignalWaiter]
    def wait_signal(name = nil, *args, &block)
      return SignalWaiter.new(name, *args, &block)
    end
  end
end
Hooks.register(Spriteset_Map, :finish_init, 'Yuki::TJN') do
  Yuki::TJN.force_update_tone
  Yuki::TJN.update
end
Hooks.register(Spriteset_Map, :update_fps_balanced, 'Yuki::TJN') {Yuki::TJN.update }
