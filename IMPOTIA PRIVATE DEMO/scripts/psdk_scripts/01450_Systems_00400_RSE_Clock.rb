module GamePlay
  # Module Holding all the modules to include for the RSEClock
  module RSEClockHelpers
    # Module defining the logic of the RSEClock
    module Logic
      # Get the hour that was set on the clock
      # @return [Integer]
      attr_reader :hour
      # Get the minute that was set on the clock
      attr_reader :minute
      # Create a new RSEClock
      # @param hour [Integer] hour to start the clock
      # @param minute [Integer] minute to start the clock
      def initialize(hour = 0, minute = 0)
        super(false)
        @hour = hour
        @minute = minute
        @choice_result = nil
        initialize_state_machine
      end
      private
      # Increase the minutes
      def increase_minutes
        @minute += 1
        update_hour
      end
      # Decrease the minutes
      def decrease_minutes
        @minute -= 1
        update_hour
      end
      # Update the hour based on minutes
      def update_hour
        @hour += @minute / 60
        @hour %= 24
        @minute = @minute % 60
      end
    end
    # Module defining the UI of the RSE Clock
    module UI
      private
      def create_graphics
        create_viewport
        create_background
        create_clock
        create_am_pm
        create_minute_aiguille
        create_hour_aiguille
      end
      def create_background
        @background = ::UI::BlurScreenshot.new(viewport, __last_scene)
      end
      def create_clock
        @clock = Sprite.new(viewport).load('clock/clock', :interface)
        @clock.set_origin_div(2, 2).set_position(viewport.rect.width / 2, viewport.rect.height / 2)
      end
      def create_am_pm
        @am_pm = SpriteSheet.new(viewport, 1, 2).load('clock/am_pm', :interface).set_position(@clock.x - 14, @clock.y + 24)
      end
      def create_minute_aiguille
        @minute_aiguille = Sprite.new(viewport).load('clock/minute', :interface).set_position(@clock.x, @clock.y).set_origin(6, 44)
      end
      def create_hour_aiguille
        @hour_aiguille = Sprite.new(viewport).load('clock/hour', :interface).set_position(@clock.x, @clock.y).set_origin(5, 24)
      end
      def update_aiguilles
        @hour_aiguille.angle = -(hour % 12) * 30 - minute / 2
        @minute_aiguille.angle = -minute * 6
        @am_pm.sy = hour / 12
        @waiter = Yuki::Animation.wait(0.016)
        @waiter.start
      end
      def update_waiter
        @waiter.update
        @sm_execute_next_state = @waiter.done?
      end
    end
    # Module defining the questions asked by the RSEClock
    module Questions
      private
      def ask_confirmation
        @choice_result = nil
        yes ||= text_get(11, 27)
        no ||= text_get(11, 28)
        if display_message(question_string, 1, yes, no) == 0
          @choice_result = :YES
        else
          @choice_result = :NO
        end
      end
      def question_string
        format('Is it %<hour>02d:%<minute>02d?', hour: hour, minute: minute)
      end
    end
  end
  # Scene asking the player to provide the time
  #
  # How to use:
  # 1. Set time with no initial time
  #   call_scene(GamePlay::RSEClock) { |scene| @time = "#{scene.hour}:#{scene.minute}"}
  # 2. Set time with initial time
  #   call_scene(GamePlay::RSEClock, hour, minute) { |scene| @time = "#{scene.hour}:#{scene.minute}"}
  class RSEClock < GamePlay::StateMachine
    include GamePlay::RSEClockHelpers::Logic
    include GamePlay::RSEClockHelpers::UI
    include GamePlay::RSEClockHelpers::Questions
    # Constant holding all the update method to call depending on the state
    STATE_UPDATE_METHODS = {init: :update_init, choice: :update_choice, inc_min: :update_inc_min, dec_min: :update_dec_min, wait: :update_wait, confirmation: :update_confirmation, out: :update_out}
    private
    # Function that initialize the state machine, please, do not forget to call this function where it makes sense (depending on dependencies)
    def initialize_state_machine
      @smi_a = Input.trigger?(:A)
      @smi_left = Input.press?(:LEFT)
      @smi_right = Input.press?(:RIGHT)
      @smi_choice = @choice_result
      @smi_waiter_done = @waiter&.done?
      @sm_state = :init
    end
    # Function that call the right update method, don't forget to call it if you're not inheriting from a class that calls it
    def update_state_machine
      send(STATE_UPDATE_METHODS[@sm_state])
    end
    def update_init
      update_aiguilles
      @sm_state = :choice
    end
    def tansitioning_from_choice_to_inc_min?
      @smi_right == true
    end
    def tansitioning_from_choice_to_dec_min?
      @smi_left == true
    end
    def tansitioning_from_choice_to_confirmation?
      @smi_a == true
    end
    def update_state_from_choice
      return @sm_state = :inc_min if tansitioning_from_choice_to_inc_min?
      return @sm_state = :dec_min if tansitioning_from_choice_to_dec_min?
      return @sm_state = :confirmation if tansitioning_from_choice_to_confirmation?
    end
    def update_choice_inputs
      @smi_right = Input.press?(:RIGHT)
      @smi_left = Input.press?(:LEFT)
      @smi_a = Input.trigger?(:A)
    end
    def update_choice
      update_choice_inputs
      update_state_from_choice
    end
    def update_inc_min
      increase_minutes
      update_aiguilles
      @sm_state = :wait
    end
    def update_dec_min
      decrease_minutes
      update_aiguilles
      @sm_state = :wait
    end
    def tansitioning_from_wait_to_choice?
      @smi_waiter_done == true
    end
    def update_state_from_wait
      return @sm_state = :choice if tansitioning_from_wait_to_choice?
    end
    def update_wait_inputs
      @smi_waiter_done = @waiter&.done?
    end
    def update_wait
      update_waiter
      update_wait_inputs
      update_state_from_wait
    end
    def tansitioning_from_confirmation_to_out?
      @smi_choice == :YES
    end
    def tansitioning_from_confirmation_to_choice?
      @smi_choice == :NO
    end
    def update_state_from_confirmation
      return @sm_state = :out if tansitioning_from_confirmation_to_out?
      return @sm_state = :choice if tansitioning_from_confirmation_to_choice?
    end
    def update_confirmation_inputs
      @smi_choice = @choice_result
    end
    def update_confirmation
      ask_confirmation
      update_confirmation_inputs
      update_state_from_confirmation
    end
    def update_out
      exit_state_machine
    end
  end
end
__LINE__.to_i
