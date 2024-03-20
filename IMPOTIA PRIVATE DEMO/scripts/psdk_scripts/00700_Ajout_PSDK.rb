module Graphics
  class << self
    private
    def io_initialize
      STDOUT.sync = true unless STDOUT.tty?
      return if PSDK_CONFIG.release?
      return if PARGV.game_launched_by_studio?
      @cmd_thread = create_command_thread
    rescue StandardError
      puts 'Failed to initialize IO related things'
    end
    Hooks.register(Graphics, :init_sprite, 'PSDK Graphics io_initialize') {io_initialize }
    # Create the Command thread
    def create_command_thread
      Thread.new do
        loop do
                    log_info('Type help to get a list of the commands you can use.')
          print 'Command: '
          @__cmd_to_eval = STDIN.gets.chomp
          sleep
        rescue StandardError
          @cmd_thread = nil
          @__cmd_to_eval = nil
          break

        end
      end
    end
    # Eval a command from the console
    def update_cmd_eval
      return unless (cmd = @__cmd_to_eval)
      @__cmd_to_eval = nil
      begin
        puts Object.instance_eval(cmd)
      rescue StandardError, SyntaxError
        print "\r"
        puts "#{$!.class} : #{$!.message}"
        puts $!.backtrace
      end
      @cmd_thread&.wakeup
    end
    Hooks.register(Graphics, :post_update_internal, 'PSDK Graphics update_cmd_eval') {update_cmd_eval }
  end
  class << self
    # Function that resets the mouse viewport
    def reset_mouse_viewport
      @mouse_fps_viewport&.rect&.set(0, 0, width, height)
    end
    private
    def mouse_fps_create_graphics
      @mouse_fps_viewport = Viewport.new(0, 0, width, height, 999_999)
      unregitser_viewport(@mouse_fps_viewport)
    end
    Hooks.register(Graphics, :init_sprite, 'PSDK Graphics mouse_fps_create_graphics') {mouse_fps_create_graphics }
    def reset_fps_info
      @ruby_time = @current_time = @before_g_update = @last_fps_update_time = Time.new
      reset_gc_time
      reset_ruby_time
      @last_frame_count = Graphics.frame_count
    end
    Hooks.register(Graphics, :frame_reset, 'PSDK Graphics reset_fps_info') {reset_fps_info }
    def update_gc_time(delta_time)
      @gc_accu += delta_time
      @gc_count += 1
    end
    def reset_gc_time
      @gc_count = 0
      @gc_accu = 0.0
    end
    def update_ruby_time(delta_time)
      @ruby_accu += delta_time
      @ruby_count += 1
      @before_g_update = Time.new
    end
    def reset_ruby_time
      @ruby_count = 0
      @ruby_accu = 0.0
    end
    def init_fps_text
      @ingame_fps_text = Text.new(0, @mouse_fps_viewport, 0, 0, w = Graphics.width - 2, 13, '', 2, 1, 9)
      @gpu_fps_text = Text.new(0, @mouse_fps_viewport, 0, 16, w, 13, '', 2, 1, 9)
      @ruby_fps_text = Text.new(0, @mouse_fps_viewport, 0, 32, w, 13, '', 2, 1, 9)
      fps_visibility(PARGV[:"show-fps"])
    end
    Hooks.register(Graphics, :init_sprite, 'PSDK Graphics init_fps_text') {init_fps_text }
    def fps_visibility(visible)
      @ingame_fps_text.visible = @gpu_fps_text.visible = @ruby_fps_text.visible = visible
    end
    def fps_update
      update_ruby_time(Time.new - @ruby_time)
      fps_visibility(!@ingame_fps_text.visible) if !@last_f2 && Sf::Keyboard.press?(Sf::Keyboard::F2)
      @last_f2 = Sf::Keyboard.press?(Sf::Keyboard::F2)
      dt = @current_time - @last_fps_update_time
      if dt >= 1
        @last_fps_update_time = @current_time
        @ingame_fps_text.text = "FPS: #{((Graphics.frame_count - @last_frame_count) / dt).round}" if dt * 10 >= 1
        @last_frame_count = Graphics.frame_count
        @gpu_fps_text.text = "GPU FPS: #{(@gc_count / @gc_accu).round}" unless @gc_count == 0 || @gc_accu == 0
        @ruby_fps_text.text = "Ruby FPS: #{(@ruby_count / @ruby_accu).round}" unless @ruby_count == 0 || @ruby_accu == 0
        reset_gc_time
        reset_ruby_time
      end
    end
    Hooks.register(Graphics, :pre_update_internal, 'PSDK Graphics fps_update') {fps_update }
    Hooks.register(Graphics, :update_freeze, 'PSDK Graphics fps_update') {fps_update }
    Hooks.register(Graphics, :update_transition_internal, 'PSDK Graphics fps_update') {fps_update }
    Hooks.register(Graphics, :post_transition, 'PSDK Graphics reset_fps_info') {reset_fps_info }
    def fps_gpu_update
      update_gc_time(Time.new - @before_g_update)
      @ruby_time = Time.new
    end
    Hooks.register(Graphics, :post_update_internal, 'PSDK Graphics fps_gpu_update') {fps_gpu_update }
    def mouse_create_graphics
      return if (@no_mouse = (Configs.devices.is_mouse_disabled && %i[tags worldmap].none? { |arg| PARGV[arg] }))
      @mouse = Sprite.new(@mouse_fps_viewport)
      if (mouse_skin = Configs.devices.mouse_skin) && RPG::Cache.windowskin_exist?(mouse_skin)
        @mouse.bitmap = RPG::Cache.windowskin(mouse_skin)
      end
    end
    Hooks.register(Graphics, :init_sprite, 'PSDK Graphics mouse_create_graphics') {mouse_create_graphics }
    def mouse_update_graphics
      return if @no_mouse
      @mouse.visible = Mouse.in?
      return unless Mouse.moved
      @mouse.set_position(Mouse.x, Mouse.y)
    end
    Hooks.register(Graphics, :pre_update_internal, 'PSDK Graphics mouse_update_graphics') {mouse_update_graphics }
    Hooks.register(Graphics, :update_freeze, 'PSDK Graphics mouse_update_graphics') {mouse_update_graphics }
    Hooks.register(Graphics, :update_transition_internal, 'PSDK Graphics mouse_update_graphics') {mouse_update_graphics }
  end
  reset_fps_info
  on_start do
    Graphics.load_icon
  end
  class << self
    # Load the window icon
    def load_icon
      return unless RPG::Cache.icon_exist?('game')
      windowskin_vd = RPG::Cache.instance_variable_get(:@icon_data)
      data = windowskin_vd&.read_data('game')
      image = data ? Image.new(data, true) : Image.new('graphics/icons/game.png')
      window.icon = image
      image.dispose
    end
    alias original_swap_fullscreen swap_fullscreen
    # Define swap_fullscreen so the icon is taken in account
    def swap_fullscreen
      original_swap_fullscreen
      load_icon
    end
  end
  # Class helping to balance FPS on FPS based things
  class FPSBalancer
    @globally_enabled = true
    @last_f3_up = Time.new - 10
    # Create a new FPSBalancer
    def initialize
      @frame_to_execute = 0
      @last_frame_rate = 0
      @frame_delta = 1
      @last_interval_index = 0
    end
    # Update the metrics of the FPSBalancer
    def update
      update_intervals if @last_frame_rate != Graphics.frame_rate
      current_index = (Graphics.current_time.usec / @frame_delta).floor
      if current_index == @last_interval_index
        @frame_to_execute = 0
      else
        if current_index > @last_interval_index
          @frame_to_execute = current_index - @last_interval_index
        else
          @frame_to_execute = Graphics.frame_rate - @last_interval_index + current_index
        end
      end
      @last_interval_index = current_index
      if Sf::Keyboard.press?(Sf::Keyboard::F3)
        FPSBalancer.last_f3_up = Graphics.current_time
      else
        if FPSBalancer.last_f3_up == Graphics.last_time
          FPSBalancer.globally_enabled = !FPSBalancer.globally_enabled
          FPSBalancer.last_f3_up -= 1
        end
      end
    end
    # Run code according to FPS Balancing (block will be executed only if it's ok)
    # @param block [Proc] code to execute as much as needed
    def run(&block)
      return unless block_given?
      return block.call unless FPSBalancer.globally_enabled
      @frame_to_execute.times(&block)
    end
    # Tell if the balancer is skipping frames
    def skipping?
      FPSBalancer.globally_enabled && @frame_to_execute == 0
    end
    # Force all the scripts to render if we're about to do something important
    def disable_skip_for_next_rendering
      return unless FPSBalancer.globally_enabled
      @frame_to_execute = 1
    end
    private
    def update_intervals
      @last_frame_rate = Graphics.frame_rate
      @frame_delta = 1_000_000.0 / @last_frame_rate
      @last_interval_index = (Graphics.current_time.usec / @frame_delta).floor - 1
      @last_interval_index += Graphics.frame_rate if @last_interval_index < 0
    end
    Hooks.register(Graphics, :post_transition, 'Reset interval after transition') do
      FPSBalancer.global.send(:update_intervals)
    end
    class << self
      # Get if the FPS balancing is globally enabled
      # @return [Boolean]
      attr_accessor :globally_enabled
      # Get last time F3 was pressed
      # @return [Time]
      attr_accessor :last_f3_up
      # Get the global balancer
      # @return [FPSBalancer]
      attr_reader :global
    end
    # Marker allowing the game to know the scene should be frame balanced
    module Marker
      # Function telling the object is supposed to be frame balanced
      def frame_balanced?
        return true
      end
    end
    @global = new
  end
  class << self
    alias original_update update
    # Update with fps balancing
    def update
      FPSBalancer.global.update
      if FPSBalancer.global.skipping? && !frozen? && $scene.is_a?(FPSBalancer::Marker)
        fps_update if respond_to?(:fps_update, true)
        update_no_input
        fps_gpu_update if respond_to?(:fps_gpu_update, true)
      else
        original_update
      end
    end
  end
end
class Object
  # Method that shows the help
  def help
    cc 0x75
    puts "\r#{'PSDK Help'.center(80)}"
    cc 0x07
    print "Here's the list of the command you can enter in this terminal.\nRemember that you're executing actual Ruby code.\nWhen an ID is 005 or 023 you have to write 5 or 23, the 0-prefix should never appear in the command you enter.\n"
    cc 0x06
    print "Warp the player to another map :\e[37m\n  - Debugger.warp(map_id, x, y)\e[36m\nTest a trainer battle :\e[37m\n  - Debugger.battle_trainer(trainer_id)\e[36m\nAdd a Pokemon to the party :\e[37m\n  - S.MI.add_pokemon(id, level)\e[36m\nAdd a Pokemon defined by a Hash to the party :\e[37m\n  - S.MI.add_specific_pokemon(hash)\e[36m\nRemove a Pokemon from the Party :\e[37m\n  - S.MI.withdraw_pokemon_at(index)\e[36m\nLearn a skill to a Pokemon :\e[37m\n  - S.MI.skill_learn(pokemon, skill_id)\n  - S.MI.skill_learn($actors[index_in_the_party], skill_id)\e[36m\nAdd an egg to the party :\e[37m\n  - S.MI.add_egg(id)\e[36m\nStart a wild battle :\e[37m\n  - S.MI.call_battle_wild(id, level)\n  - S.MI.call_battle_wild(id1, level1, id2, level2) \e[32m\# 2v2\e[37m\n  - S.MI.call_battle_wild(pokemon, nil)\n  - S.MI.call_battle_wild(pokemon1, nil, pokemon2)\e[36m\nSave the game :\e[37m\n  - S.MI.force_save\n"
  end
  # Parse a text from the text database with specific informations and a pokemon
  # @param file_id [Integer] ID of the text file
  # @param text_id [Integer] ID of the text in the file
  # @param pokemon [PFM::Pokemon] pokemon that will introduce an offset on text_id (its name is also used)
  # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
  # @return [String] the text parsed and ready to be displayed
  def parse_text_with_pokemon(file_id, text_id, pokemon, additionnal_var = nil)
    PFM::Text.parse_with_pokemon(file_id, text_id, pokemon, additionnal_var)
  end
  # Parse a text from the text database with 2 pokemon & specific information
  # @param file_id [Integer] ID of the text file
  # @param text_id [Integer] ID of the text in the file
  # @param pokemon1 [PFM::Pokemon] pokemon we're talking about
  # @param pokemon2 [PFM::Pokemon] pokemon who originated the "problem" (eg. bind)
  # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
  # @return [String] the text parsed and ready to be displayed
  def parse_text_with_2pokemon(file_id, text_id, pokemon1, pokemon2, additionnal_var = nil)
    PFM::Text.parse_with_2pokemon(file_id, text_id, pokemon1, pokemon2, additionnal_var)
  end
  # Parse a text from the text database with specific informations
  # @param file_id [Integer] ID of the text file
  # @param text_id [Integer] ID of the text in the file
  # @param additionnal_var [nil, Hash{String => String}] additional remplacements in the text
  # @return [String] the text parsed and ready to be displayed
  def parse_text(file_id, text_id, additionnal_var = nil)
    PFM::Text.parse(file_id, text_id, additionnal_var)
  end
  # Get a text front the text database
  # @param file_id [Integer] ID of the text file
  # @param text_id [Integer] ID of the text in the file
  # @return [String] the text
  def text_get(file_id, text_id)
    Studio::Text.get(file_id, text_id)
  end
  # Get a list of text from the text database
  # @param file_id [Integer] ID of the text file
  # @return [Array<String>] the list of text contained in the file.
  def text_file_get(file_id)
    Studio::Text.get_file(file_id)
  end
  # Clean an array containing object responding to #name (force utf-8)
  # @param arr [Array<#name>]
  # @return [arr]
  def _clean_name_utf8(arr)
    utf8 = Encoding::UTF_8
    arr.each { |o| o&.name&.force_encoding(utf8) }
    return arr
  end
  # Get a text front the external text database
  # @param file_id [Integer] ID of the text file
  # @param text_id [Integer] ID of the text in the file
  # @return [String] the text
  def ext_text(file_id, text_id)
    Studio::Text.get_external(file_id, text_id)
  end
  # Play decision SE
  def play_decision_se
    $game_system&.se_play($data_system&.decision_se)
  end
  # Play cursor SE
  def play_cursor_se
    $game_system&.se_play($data_system&.cursor_se)
  end
  # Play buzzer SE
  def play_buzzer_se
    $game_system&.se_play($data_system&.buzzer_se)
  end
  # Play cancel SE
  def play_cancel_se
    $game_system&.se_play($data_system&.cancel_se)
  end
  # Play the Equip SE
  def play_equip_se
    $game_system&.se_play($data_system&.equip_se)
  end
  # Play the Shop SE
  def play_shop_se
    $game_system&.se_play($data_system&.shop_se)
  end
  # Play the Save SE
  def play_save_se
    $game_system&.se_play($data_system&.save_se)
  end
  # Play the Load SE
  def play_load_se
    $game_system&.se_play($data_system&.load_se)
  end
  # Play the Escape SE
  def play_escape_se
    $game_system&.se_play($data_system&.escape_se)
  end
  # Play the Actor collapse SE
  def play_actor_collapse_se
    $game_system&.se_play($data_system&.actor_collapse_se)
  end
  # Play the Enemy collapse SE
  def play_enemy_collapse_se
    $game_system&.se_play($data_system&.enemy_collapse_se)
  end
end
# Module that allows you to schedule some tasks and run them at the right time
#
# The Scheduler has a @tasks Hash that is organized the following way:
#   @tasks[reason][class] = [tasks]
#   reason is one of the following reasons :
#     on_update: during Graphics.update
#     on_scene_switch: before going outside of the #main function of the scene (if called)
#     on_dispose: during the dispose process
#     on_init: at the begining of #main before Graphics.transition
#     on_warp_start: at the begining of player warp process (first action)
#     on_warp_process: after the player has been teleported but before the states has changed
#     on_warp_end: before the transition starts
#     on_hour_update: When the current hour change (ex: refresh groups)
#     on_getting_tileset_name: When the Map Engine search for the correct tileset name
#     on_transition: When Graphics.transition is called
#   class is a Class Object related to the scene where the Scheduler starts
#
# The Sheduler also has a @storage Hash that is used by the tasks to store informations
module Scheduler
  module_function
  # Initialize the Scheduler with no task and nothing in the storage
  def init
    @tasks = {on_update: {}, on_scene_switch: {}, on_dispose: {}, on_init: {}, on_warp_start: {}, on_warp_process: {}, on_warp_end: {}, on_hour_update: {}, on_getting_tileset_name: {}, on_transition: {}}
    @storage = {}
  end
  init
  # Start tasks that are related to a specific reason
  # @param reason [Symbol] reason explained at the top of the page
  # @param klass [Class, :any] the class of the scene
  def start(reason, klass = $scene.class)
    task_hash = @tasks[reason]
    return unless task_hash
    if klass != :any
      start(reason, :any)
      klass = klass.to_s
    end
    task_array = task_hash[klass]
    return unless task_array
    task_array.each(&:start)
  end
  # Remove a task
  # @param reason [Symbol] the reason
  # @param klass [Class, :any] the class of the scene
  # @param name [String] the name that describe the task
  # @param priority [Integer] its priority
  def __remove_task(reason, klass, name, priority)
    task_array = @tasks.dig(reason, klass.is_a?(Symbol) ? klass : klass.to_s)
    return unless task_array
    priority = -priority
    task_array.delete_if { |obj| obj.priority == priority && obj.name == name }
  end
  # add a task (and sort them by priority)
  # @param reason [Symbol] the reason
  # @param klass [Class, :any] the class of the scene
  # @param task [ProcTask, MessageTask] the task to run
  def __add_task(reason, klass, task)
    task_hash = @tasks[reason]
    return unless task_hash
    klass = klass.to_s unless klass.is_a?(Symbol)
    task_array = task_hash[klass] || []
    task_hash[klass] = task_array
    task_array << task
    task_array.sort! { |a, b| a.priority <=> b.priority }
  end
  # Description of a Task that execute a Proc
  class ProcTask
    # Priority of the task
    # @return [Integer]
    attr_reader :priority
    # Name that describe the task
    # @return [String]
    attr_reader :name
    # Initialize a ProcTask with its name, priority and the Proc it executes
    # @param name [String] name that describe the task
    # @param priority [Integer] the priority of the task
    # @param proc_object [Proc] the proc (with no param) of the task
    def initialize(name, priority, proc_object)
      @name = name
      @priority = -priority
      @proc = proc_object
    end
    # Invoke the #call method of the proc
    def start
      @proc.call
    end
  end
  # Add a proc task to the Scheduler
  # @param reason [Symbol] the reason
  # @param klass [Class] the class of the scene
  # @param name [String] the name that describe the task
  # @param priority [Integer] the priority of the task
  # @param proc_object [Proc] the Proc object of the task (kept for compatibility should not be defined)
  # @param block [Proc] the Proc object of the task
  def add_proc(reason, klass, name, priority, proc_object = nil, &block)
    proc_object = block if block
    __add_task(reason, klass, ProcTask.new(name, priority, proc_object))
  end
  # Describe a Task that send a message to a specific object
  class MessageTask
    # Priority of the task
    # @return [Integer]
    attr_reader :priority
    # Name that describe the task
    # @return [String]
    attr_reader :name
    # Initialize a MessageTask with its name, priority, the object and the message to send
    # @param name [String] name that describe the task
    # @param priority [Integer] the priority of the task
    # @param object [Object] the object that receive the message
    # @param message [Array<Symbol, *args>] the message to send
    def initialize(name, priority, object, message)
      @name = name
      @priority = -priority
      @object = object
      @message = message
    end
    # Send the message to the object
    def start
      @object.send(*@message)
    end
  end
  # Add a message task to the Scheduler
  # @param reason [Symbol] the reason
  # @param klass [Class, :any] the class of the scene
  # @param name [String] name that describe the task
  # @param priority [Integer] the priority of the task
  # @param object [Object] the object that receive the message
  # @param message [Array<Symbol, *args>] the message to send
  def add_message(reason, klass, name, priority, object, *message)
    __add_task(reason, klass, MessageTask.new(name, priority, object, message))
  end
  # Return the object of the Boot Scene (usually Scene_Title)
  # @return [Object]
  def get_boot_scene
    if PARGV[:tags]
      ScriptLoader.load_tool('Editors/SystemTags')
      return Editors::SystemTags.new
    end
    return Yuki::WorldMapEditor if PARGV[:worldmap]
    return Yuki::AnimationEditor if PARGV[:"animation-editor"]
    test = PARGV[:test].to_s
    return Scene_Title.new if test.empty?
    test = "tests/#{test}.rb"
    return Tester.new(test) if File.exist?(test)
    return Scene_Title.new
  end
  public
  # Module that aim to add task triggered by events actions
  #
  # List of the event actions :
  #   - begin_step
  #   - begin_jump
  #   - begin_slide
  #   - end_step
  #   - end_jump
  #   - end_slide
  #
  # Events can be specified with the following criteria
  #   - map_id / :any : ID of the map where the task can trigger
  #   - event_id / :any : ID of the event that trigger the task (-1 = player, -2 its first follower, -3 its second, ...)
  #
  # Parameter sent to the task :
  #   - event : Game_Character object that triggered the task
  #   - event_id : ID of the event that triggered the task (for :any tasks)
  #   - map_id : ID of the map where the task was triggered (for :any tasks)
  #
  # Important note : The system will detect the original id & map of the events (that's why the event object is sent & its id)
  module EventTasks
    @tasks = {}
    module_function
    # Add a new task
    # @param task_type [Symbol] one of the specific tasks
    # @param description [String] description allowing to retrieve the task
    # @param event_id [Integer, :any] id of the event that triggers the task
    # @param map_id [Integer, :any] id of the map where the task triggers
    # @param task [Proc] task executed
    def on(task_type, description, event_id = :any, map_id = :any, &task)
      tasks = (@tasks[task_type] ||= {})
      tasks = (tasks[map_id] ||= {})
      tasks = (tasks[event_id] ||= {})
      tasks[description] = task
    end
    # Trigger a specific task
    # @param task_type [Symbol] one of the specific tasks
    # @param event [Game_Character] event triggering the task
    def trigger(task_type, event)
      return unless (tasks = @tasks[task_type])
      event_id = resolve_id(event)
      map_id = resolve_map_id(event)
      if (map_tasks = tasks[map_id])
        if (event_tasks = map_tasks[event_id])
          event_tasks.each_value { |task| task.call(event, event_id, map_id) }
        end
        if (event_tasks = map_tasks[:any])
          event_tasks.each_value { |task| task.call(event, event_id, map_id) }
        end
      end
      if (map_tasks = tasks[:any])
        if (event_tasks = map_tasks[event_id])
          event_tasks.each_value { |task| task.call(event, event_id, map_id) }
        end
        if (event_tasks = map_tasks[:any])
          event_tasks.each_value { |task| task.call(event, event_id, map_id) }
        end
      end
    end
    # Resolve the id of the event
    # @param event [Game_Character]
    # @return [Integer]
    def resolve_id(event)
      if event.is_a?(Game_Event)
        return event.original_id
      else
        if event == $game_player
          return -1
        end
      end
      id = -1
      follower = $game_player
      while (follower = follower.follower)
        id -= 1
        return id if follower == event
      end
      return 0
    end
    # Resolve the id of the event
    # @param event [Game_Character]
    # @return [Integer]
    def resolve_map_id(event)
      return event.original_map if event.is_a?(Game_Event)
      return $game_map.map_id
    end
    # Remove a task
    # @param task_type [Symbol] one of the specific tasks
    # @param description [String] description allowing to retrieve the task
    # @param event_id [Integer, :any] id of the event that triggers the task
    # @param map_id [Integer, :any] id of the map where the task triggers
    def delete(task_type, description, event_id, map_id)
      return unless (tasks = @tasks[task_type])
      return unless (tasks = tasks[map_id])
      return unless (tasks = tasks[event_id])
      tasks.delete(description)
    end
  end
end
Hooks.register(Graphics, :transition, 'PSDK Graphics.transition') {Scheduler.start(:on_transition) }
Hooks.register(Graphics, :update, 'PSDK Graphics.update') {Scheduler.start(:on_update) }
Scheduler::EventTasks.on(:end_jump, 'Dust after jumping') do |event|
  next if event.particles_disabled
  particle = Game_Character::SurfTag.include?(event.system_tag) ? :water_dust : :dust
  Yuki::Particles.add_particle(event, particle)
end
Scheduler::EventTasks.on(:end_step, 'Repel count', -1) {PFM.game_state.repel_update }
Scheduler::EventTasks.on(:end_step, 'Daycare', -1) {$daycare.update }
Scheduler::EventTasks.on(:end_step, 'Loyalty check', -1) {PFM.game_state.loyalty_update }
Scheduler::EventTasks.on(:end_step, 'PoisonUpdate', -1) {PFM.game_state.poison_update }
Scheduler::EventTasks.on(:end_step, 'Hatch check', -1) {PFM.game_state.hatch_check_update }
Scheduler::EventTasks.on(:begin_step, 'BattleStarting', -1) {PFM.game_state.battle_starting_update }
# Class designed to test an interface or a script
class Tester
  @@args = nil
  @@class = nil
  # Create a new test
  # @param script [String] filename of the script to test
  def initialize(script)
    @script = script
    $tester = self
    Object.define_method(:reload) {$tester.load_script }
    Object.define_method(:restart) {$tester.restart_scene }
    Object.define_method(:quit) {$tester.quit_test }
    data_load
    PFM::GameState.new.expand_global_var
    @thread = Thread.new do
      while true
        sleep(0.1)
        if Input::Keyboard.press?(Input::Keyboard::F9)
          print "\rMouse coords = %d,%d\nCommande : " % [Mouse.x, Mouse.y]
          sleep(0.5)
        end
      end
    end
    load_script
    show_test_message
    @unlocked = true
  rescue Exception
    manage_exception
  end
  # Main process of the tester
  def main
    Graphics.update until @unlocked
    $scene = @@class.new(*@@args)
    $scene.main
    if $scene != self
      $scene = nil
      @thread.kill
    end
  rescue Exception
    manage_exception
  end
  # Retart the scene
  # @return [true]
  def restart_scene
    $scene.instance_variable_set(:@running, false)
    $scene = self
    @unlocked = true
    return true
  end
  # Show the test message
  def show_test_message
    cc 0x02
    puts "Testing script #{@script}"
    cc 0x07
    puts 'Type : '
    puts 'reload to reload the script'
    puts 'restart to restart the scene'
    puts 'quit to quit the test'
    print 'Commande : '
  end
  # Quit the test
  def quit_test
    restart_scene
    $scene = nil
  end
  # Load the script
  # @return [true]
  def load_script
    script = File.open(@script, 'r') { |f| break((f.read(f.size))) }
    eval(script, $global_binding, @script)
    return true
  end
  # Manage the exception
  def manage_exception
    raise if $!.class == LiteRGSS::DisplayWindow::ClosedWindowError
    puts Yuki::EXC.build_error_log($!)
    cc 0x01
    puts 'Test locked, type reload and restart to unlock'
    cc 0x07
    restart_scene
    @unlocked = false
  end
  # Define the class and the arguments of it to test
  # @param klass [Class] the class to test
  # @param args [Array] the arguments
  def self.start(klass, *args)
    @@class = klass
    @@args = args
  end
  # Load the RMXP Data
  def data_load
    unless $data_actors
      $data_actors = _clean_name_utf8(load_data('Data/Actors.rxdata'))
      $data_classes = load_data('Data/Classes.rxdata')
      $data_enemies = _clean_name_utf8(load_data('Data/Enemies.rxdata'))
      $data_troops = _clean_name_utf8(load_data('Data/Troops.rxdata'))
      $data_tilesets = _clean_name_utf8(load_data('Data/Tilesets.rxdata'))
      $data_common_events = _clean_name_utf8(load_data('Data/CommonEvents.rxdata'))
      $data_system = load_data_utf8('Data/System.rxdata')
    end
    $game_system = Game_System.new
    $game_temp = Game_Temp.new
  end
end
module LiteRGSS
  class Text
    # Utility module to manage text easly in user interfaces.
    # @deprecated DO NOT FUCKING USE THIS. Use SpriteStack instead.
    module Util
      # Default outlinesize, nil gives a 0 and keep shadow processing, 0 or more disable shadow processing
      DEFAULT_OUTLINE_SIZE = nil
      # Offset induced by the Font
      FOY = 2
      #4
      # Returns the text viewport
      # @return [Viewport]
      def text_viewport
        return @text_viewport
      end
      # Change the text viewport
      def text_viewport=(v)
        @text_viewport = v if v.is_a?(Viewport)
      end
      # Initialize the texts
      # @param font_id [Integer] the default font id of the texts
      # @param viewport [Viewport, nil] the viewport
      def init_text(font_id = 0, viewport = nil, z = 1000)
        log_error('init_text is deprecated')
        @texts = [] unless @texts.class == Array
        @text_viewport = viewport
        @font_id = font_id
        @text_z = z
      end
      # Add a text inside the window, the offset x/y will be adjusted
      # @param x [Integer] the x coordinate of the text surface
      # @param y [Integer] the y coordinate of the text surface
      # @param width [Integer] the width of the text surface
      # @param height [Integer] the height of the text surface
      # @param str [String] the text shown by this object
      # @param align [0, 1, 2] the align of the text in its surface (best effort => no resize), 0 = left, 1 = center, 2 = right
      # @param outlinesize [Integer, nil] the size of the text outline
      # @param type [Class] the type of text
      # @return [Text] the text object
      def add_text(x, y, width, height, str, align = 0, outlinesize = DEFAULT_OUTLINE_SIZE, type: Text)
        log_error('add_text from Text::Util is deprecated')
        if @window && @window.viewport == @text_viewport
          x += (@ox + @window.x)
          y += (@oy + @window.y)
        end
        text = type.new(@font_id, @text_viewport, x, y - FOY, width, height, str.to_s, align, outlinesize)
        text.z = @window ? @window.z + 1 : @text_z
        text.draw_shadow = outlinesize.nil?
        @texts << text
        return text
      end
      # Dispose the texts
      def text_dispose
        log_error('text_dispose is deprecated')
        @texts.each { |text| text.dispose unless text.disposed? }
        @texts.clear
      end
      # Yield a block on each undisposed text
      def text_each
        log_error('text_each is deprecated')
        return unless block_given?
        @texts.each { |text| yield(text) unless text.disposed? }
      end
    end
    # Set a multiline text
    # @param value [String] Multiline text that should be ajusted to be display on multiple lines
    def multiline_text=(value)
      sw = text_width(' ') + 1
      x = 0
      max_width = width
      words = ''
      value.split(/ /).compact.each do |word|
        if word.include?("\n")
          word, next_word = word.split("\n")
          w = text_width(word)
          words << "\n" if x + w > max_width
          x = 0
          words << word << "\n" << next_word << ' '
          x += (text_width(next_word) + sw)
        else
          w = text_width(word)
          if x + w > max_width
            x = 0
            words << "\n"
          end
          words << word << ' '
          x += (w + sw)
        end
      end
      self.text = ' ' if words == text
      self.text = words
    end
  end
end
# SpriteSheet is a class that helps the maker to display a sprite from a Sprite Sheet on the screen
class SpriteSheet < ShaderedSprite
  # Return the number of sprite on the x axis of the sheet
  # @return [Integer]
  attr_reader :nb_x
  # Return the number of sprite on the y axis of the sheet
  # @return [Integer]
  attr_reader :nb_y
  # Return the x sprite index of the sheet
  # @return [Integer]
  attr_reader :sx
  # Return the y sprite index of the sheet
  # @return [Integer]
  attr_reader :sy
  # Create a new SpriteSheet
  # @param viewport [Viewport, nil] where to display the sprite
  # @param nb_x [Integer] the number of sprites on the x axis in the sheet
  # @param nb_y [Integer] the number of sprites on the y axis in the sheet
  def initialize(viewport, nb_x, nb_y)
    super(viewport)
    @nb_x = nb_x > 0 ? nb_x : 1
    @nb_y = nb_y > 0 ? nb_y : 1
    @sx = 0
    @sy = 0
  end
  # Change the bitmap of the sprite
  # @param value [Texture, nil]
  def bitmap=(value)
    ret = super(value)
    if value
      w = value.width / @nb_x
      h = value.height / @nb_y
      src_rect.set(@sx * w, @sy * h, w, h)
    end
    return ret
  end
  # Change the number of cells the sheet supports on the x axis
  # @param nb_x [Integer] number of cell on the x axis
  def nb_x=(nb_x)
    @nb_x = nb_x.clamp(1, Float::INFINITY)
    self.bitmap = bitmap
  end
  # Change the number of cells the sheet supports on the y axis
  # @param nb_y [Integer] number of cell on the y axis
  def nb_y=(nb_y)
    @nb_y = nb_y.clamp(1, Float::INFINITY)
    self.bitmap = bitmap
  end
  # Redefine the number of cells the sheet supports on both axis
  # @param nb_x [Integer] number of cell on the x axis
  # @param nb_y [Integer] number of cell on the y axis
  def resize(nb_x, nb_y)
    @nb_x = nb_x.clamp(1, Float::INFINITY)
    @nb_y = nb_y.clamp(1, Float::INFINITY)
    self.bitmap = bitmap
  end
  # Change the x sprite index of the sheet
  # @param value [Integer] the x sprite index of the sheet
  def sx=(value)
    @sx = value % @nb_x
    src_rect.x = @sx * src_rect.width
  end
  # Change the y sprite index of the sheet
  # @param value [Integer] the y sprite index of the sheet
  def sy=(value)
    @sy = value % @nb_y
    src_rect.y = @sy * src_rect.height
  end
  # Select a sprite on the sheet according to its x and y index
  # @param sx [Integer] the x sprite index of the sheet
  # @param sy [Integer] the y sprite index of the sheet
  # @return [self]
  def select(sx, sy)
    @sx = sx % @nb_x
    @sy = sy % @nb_y
    src_rect.set(@sx * src_rect.width, @sy * src_rect.height, nil, nil)
    return self
  end
end
# A module that helps the PSDK_DEBUG to perform some commands
module Debugger
  # Warp Error message
  WarpError = 'Aucune map de cet ID'
  # Name of the map to load to prevent warp error
  WarpMapName = 'Data/Map%03d.rxdata'
  module_function
  # Warp command
  # @param id [Integer] ID of the map to warp
  # @param x [Integer] X position
  # @param y [Integer] Y position
  # @author Nuri Yuri
  def warp(id, x = -1, y = -1)
    map = load_data(format(WarpMapName, id)) rescue nil
    return WarpError unless map
    if y < 0
      unless __find_maker_warp(id)
        __find_map_warp(map)
      end
    else
      $game_temp.player_new_x = x + ::Yuki::MapLinker.get_OffsetX
      $game_temp.player_new_y = y + ::Yuki::MapLinker.get_OffsetY
    end
    $game_temp.player_new_direction = 0
    $game_temp.player_new_map_id = id
    $game_temp.player_transferring = true
  end
  # Fight a specific trainer by its ID
  # @param id [Integer] ID of the trainer in Studio
  # @param bgm [Array(String, Integer, Integer)] bgm description of the trainer battle
  # @param troop_id [Integer] ID of the RMXP Troop to use
  def battle_trainer(id, bgm = Interpreter::DEFAULT_TRAINER_BGM, troop_id = 3)
    original_battle_bgm = $game_system.battle_bgm
    $game_system.battle_bgm = RPG::AudioFile.new(*bgm)
    $game_variables[Yuki::Var::Trainer_Battle_ID] = id
    $game_temp.battle_abort = true
    $game_temp.battle_calling = true
    $game_temp.battle_troop_id = troop_id
    $game_temp.battle_can_escape = false
    $game_temp.battle_can_lose = false
    $game_temp.battle_proc = proc do |n|
      $game_system.battle_bgm = original_battle_bgm
    end
  end
  # Find the normal position where the player should warp in a specific map
  # @param id [Integer] id of the map
  # @return [Boolean] if a normal position has been found
  # @author Nuri Yuri
  def __find_maker_warp(id)
    each_data_zone do |data|
      if data.maps.include?(id)
        if data.warp.x && data.warp.y
          $game_temp.player_new_x = data.warp.x + ::Yuki::MapLinker.get_OffsetX
          $game_temp.player_new_y = data.warp.y + ::Yuki::MapLinker.get_OffsetY
          return true
        end
        break
      end
    end
    return false
  end
  # Find an alternative position where to warp
  # @param map [RPG::Map] the map data
  # @author Nuri Yuri
  def __find_map_warp(map)
    warp_x = cx = map.width / 2
    warp_y = cy = map.height / 2
    lowest_radius = ((cx * cy) * 2) ** 2
    map.events.each_value do |event|
      radius = (cx - event.x) ** 2 + (cy - event.y) ** 2
      if (radius < lowest_radius)
        if (__warp_command_found(event.pages))
          warp_x = event.x
          warp_y = event.y
          lowest_radius = radius
        end
      end
    end
    $game_temp.player_new_x = warp_x + ::Yuki::MapLinker.get_OffsetX
    $game_temp.player_new_y = warp_y + ::Yuki::MapLinker.get_OffsetY
  end
  # Detect a teleport command in the pages of an event
  # @param pages [Array<RPG::Event::Page>] the list of event page
  # @return [Boolean] if a command has been found
  # @author Nuri Yuri
  def __warp_command_found(pages)
    pages.each do |page|
      page.list.each do |command|
        return true if command.code == 201
      end
    end
    false
  end
end
class Sprite
  # Detect if the mouse is in the sprite (without rotation and stuff like that)
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Boolean]
  # @author Nuri Yuri
  def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
    if viewport
      return false unless viewport.simple_mouse_in?(mouse_x, mouse_y)
      mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y)
    end
    bx = x
    by = y
    return false if mouse_x < bx || mouse_y < by
    bx += src_rect.width
    by += src_rect.height
    return false if mouse_x >= bx || mouse_y >= by
    true
  end
  # Detect if the mouse is in the sprite (without rotation)
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Boolean]
  # @author Nuri Yuri
  def mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
    if viewport
      return false unless viewport.simple_mouse_in?(mouse_x, mouse_y)
      mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y)
    end
    bx = x - ox * (zx = zoom_x)
    by = y - oy * (zy = zoom_y)
    return false if mouse_x < bx || mouse_y < by
    bx += src_rect.width * zx
    by += src_rect.height * zy
    return false if mouse_x >= bx || mouse_y >= by
    true
  end
  # Convert mouse coordinate on the screen to mouse coordinates on the sprite
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Array(Integer, Integer)] the mouse coordinates on the sprite
  # @author Nuri Yuri
  def translate_mouse_coords(mouse_x = Mouse.x, mouse_y = Mouse.y)
    mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y) if viewport
    mouse_x -= x
    mouse_y -= y
    rect = src_rect
    mouse_x += rect.x
    mouse_y += rect.y
    return mouse_x, mouse_y
  end
end
class Text
  # Detect if the mouse is in the sprite (without rotation and stuff like that)
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Boolean]
  # @author Nuri Yuri
  def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
    if viewport
      return false unless viewport.simple_mouse_in?(mouse_x, mouse_y)
      mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y)
    end
    bx = x
    by = y
    return false if mouse_x < bx || mouse_y < by
    bx += width
    by += height
    return false if mouse_x >= bx || mouse_y >= by
    true
  end
  # Convert mouse coordinate on the screen to mouse coordinates on the sprite
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Array(Integer, Integer)] the mouse coordinates on the sprite
  # @author Nuri Yuri
  def translate_mouse_coords(mouse_x = Mouse.x, mouse_y = Mouse.y)
    mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y) if viewport
    mouse_x -= x
    mouse_y -= y
    return mouse_x, mouse_y
  end
end
class Viewport
  # Detect if the mouse is in the sprite (without rotation and stuff like that)
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Boolean]
  # @author Nuri Yuri
  def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
    vp_rect = rect
    if vp_rect.x <= mouse_x && (vp_rect.x + vp_rect.width) > mouse_x && vp_rect.y <= mouse_y && (vp_rect.y + vp_rect.height) > mouse_y
      return true
    end
    return false
  end
  # Convert mouse coordinate on the screen to mouse coordinates on the sprite
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Array(Integer, Integer)] the mouse coordinates on the sprite
  # @author Nuri Yuri
  def translate_mouse_coords(mouse_x = Mouse.x, mouse_y = Mouse.y)
    vp_rect = rect
    return mouse_x - vp_rect.x + ox, mouse_y - vp_rect.y + oy
  end
end
class Window
  # Detect if the mouse is in the window
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Boolean]
  # @author Nuri Yuri
  def simple_mouse_in?(mouse_x = Mouse.x, mouse_y = Mouse.y)
    if viewport
      return false unless viewport.simple_mouse_in?(mouse_x, mouse_y)
      mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y)
    end
    bx = x
    by = y
    return false if mouse_x < bx || mouse_y < by
    bx += width
    by += height
    return false if mouse_x >= bx || mouse_y >= by
    true
  end
  # Convert mouse coordinate on the screen to mouse coordinates on the window
  # @param mouse_x [Integer] the mouse x position on the screen
  # @param mouse_y [Integer] the mouse y position on the screen
  # @return [Array(Integer, Integer)] the mouse coordinates on the window
  # @author Nuri Yuri
  def translate_mouse_coords(mouse_x = Mouse.x, mouse_y = Mouse.y)
    if viewport
      mouse_x, mouse_y = viewport.translate_mouse_coords(mouse_x, mouse_y)
    end
    rect = self.rect
    mouse_x -= rect.x - ox
    mouse_y -= rect.y - oy
    return mouse_x, mouse_y
  end
end
