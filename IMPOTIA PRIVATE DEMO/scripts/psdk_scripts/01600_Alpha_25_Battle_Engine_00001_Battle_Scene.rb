# Module that holds all the Battle related classes
module Battle
  # Base classe of all the battle scene
  class Scene < GamePlay::Base
    include Hooks
    # @return [Battle::Visual]
    attr_reader :visual
    # @return [Battle::Logic]
    attr_reader :logic
    # @return [Battle::Logic::BattleInfo]
    attr_reader :battle_info
    # @return [UI::Message::Window]
    attr_reader :message_window
    # @return [Array]
    attr_reader :player_actions
    # @return [Array<AI::Base>]
    attr_reader :artificial_intelligences
    # Set the next update from outside (flee)
    # @return [Symbol]
    attr_accessor :next_update
    # Create a new Battle Scene
    # @param battle_info [Battle::Logic::BattleInfo] informations about the battle
    # @note This method create the banks, the AI, the pokemon battlers and the battle logic
    #       It should call the logic_init event
    def initialize(battle_info)
      super(false, 10_001)
      @battle_info = battle_info
      $game_temp.vs_type = battle_info.vs_type
      $game_temp.trainer_battle = battle_info.trainer_battle?
      $game_temp.in_battle = true
      @logic = create_logic
      @logic.load_rng
      @logic.load_battlers
      @visual = create_visual
      @artificial_intelligences = create_ais
      @next_update = :pre_transition
      @player_actions = []
      @battle_result = -1
      @battle_events = {}
      @skip_frame = false
      @viewport = @visual.viewport
      create_message_proc
      load_events(logic.battle_info.battle_id)
      call_event(:logic_init)
    end
    # Safe to_s & inspect
    def to_s
      format('#<%<class>s:%<id>08X visual=%<visual>s logic=%<logic>s>', class: self.class, id: __id__, visual: @visual.inspect, logic: @logic.inspect)
    end
    alias inspect to_s
    # Disable the Graphics.transition
    def main_begin()
    end
    # Update the scene
    def update
      @visual.update
      return unless super && !@visual.locking?
      next_update_process
    end
    # Process the next update method
    def next_update_process
      @skip_frame = true
      while @skip_frame
        @skip_frame = false
        log_debug("Calling #{@next_update} phase")
        send(@next_update)
      end
    end
    # Dispose the battle scene
    def dispose
      super
      @visual.dispose
    end
    # Take a snapshot of the scene
    # @note You have to dispose the bitmap you got from this function
    # @return [Texture]
    def snap_to_bitmap
      temp_view = Viewport.create(:main)
      bitmaps = @visual.snap_to_bitmaps
      bitmaps.map { |bmp| Sprite.new(temp_view).set_bitmap(bmp) }
      result = temp_view.snap_to_bitmap
      bitmaps.each(&:dispose)
      temp_view.dispose
      return result
    end
    private
    # Create a new logic object
    # @return [Battle::Logic]
    def create_logic
      return Battle::Logic.new(self)
    end
    # Create a new visual
    # @return [Battle::Visual]
    def create_visual
      return Battle::Visual.new(self)
    end
    # Create all the AIs
    # @return [Array<Battle::AI::Base>]
    def create_ais
      exec_hooks(Scene, :create_ais, binding)
      return @battle_info.ai_levels.flat_map.with_index do |ai_bank, bank|
        ai_bank.map.with_index do |ai_level, party_id|
          ai_level && AI::Base.registered(ai_level).new(self, bank, party_id, ai_level) || nil
        end
      end.compact
    end
    # Method that call @visual.show_pre_transition and change @next_update to :transition_animation
    def pre_transition
      Audio.bgm_play(*@battle_info.battle_bgm)
      @visual.show_pre_transition
      @next_update = :transition_animation
    end
    # Method that call @visual.show_transition and change @next_update to :player_action_choice
    # @note It should call the battle_begin event
    def transition_animation
      @visual.show_transition
      @next_update = :show_enter_event
    end
    # Method that call all the switch event for the Pokemon that entered the battle in the begining
    def show_enter_event
      @logic.all_alive_battlers.sort_by(&:spd).reverse.each do |battler|
        @logic.switch_handler.execute_switch_events(battler, battler)
      end
      call_event(:battle_begin)
      @next_update = :player_action_choice
    end
    # Create the message proc ensuring the scene is still updated
    def create_message_proc
      @__display_message_proc = proc do
        unless @visual.locking?
          should_unlock = true
          @visual.lock
        end
        @visual.unlock if should_unlock
      end
    end
    # Return the message class used by this scene
    # @return [Class]
    def message_class
      return Message
    end
    public
    # Tell if the ia should force a switch in case of no foe alive
    # @return [Boolean]
    def force_ia_switch?
      return if logic.actions.empty?
      @logic.bank_count.times do |bank|
        next if @logic.alive_battlers(bank).any?(&:from_party?)
        alive_foes = (@logic.alive_battlers_without_check(bank).select { |p| p if p.position == -1 }).compact
        return true if @logic.battler_count(bank).zero? && alive_foes.any?
      end
      return false
    end
    private
    # Method that ask for the player choice (it calls @visual.show_player_choice)
    def player_action_choice
      return @next_update = :update_battle_phase if force_ia_switch?
      return @next_update = :trigger_all_AI if no_player_action? && $game_switches[Yuki::Sw::BT_AI_CAN_WIN]
      return @next_update = :battle_end unless can_player_make_another_action_choice?
      choice, forced_action = @visual.show_player_choice(@player_actions.size)
      log_debug("Player action choice : #{choice} / #{forced_action}")
      case choice
      when :attack
        @next_update = :skill_choice
      when :bag
        @next_update = :item_choice
      when :pokemon
        @next_update = :switch_choice
      when :flee
        flee_attempt
      when :cancel
        while (action = @player_actions.pop)
          clean_action(action)
          break unless action&.is_a?(Actions::Base)
        end
      when :try_next
        @player_actions << Actions::Base.new(self)
      when :action
        return if forced_action.is_a?(Actions::Item) && special_item_choice_action(forced_action.item_wrapper)
        @player_actions << forced_action
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
      else
        @next_update = :battle_end
      end
    ensure
      @skip_frame = true
    end
    # Method that asks for the skill the current Pokemon should use
    def skill_choice
      pokemon = logic.battler(0, @player_actions.size)
      if !pokemon.can_move?
        move = Battle::Move[:s_struggle].new(:struggle, 1, 1, self)
        @player_actions << Actions::Attack.new(self, move, pokemon, 1, pokemon.position)
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
      else
        if @visual.show_skill_choice(@player_actions.size)
          @next_update = :target_choice
        else
          @next_update = :player_action_choice
        end
      end
    ensure
      @skip_frame = true
    end
    # Method that asks the target of the choosen move
    def target_choice
      launcher, skill, target_bank, target_position, mega = @visual.show_target_choice
      effect = launcher&.effects&.get(&:force_next_move?)
      if launcher && skill
        action_class = effect ? effect.action_class : Actions::Attack
        next_action = action_class.new(self, skill, launcher, target_bank, target_position)
        if mega
          @player_actions << [next_action, Actions::Mega.new(self, launcher)]
        else
          @player_actions << next_action
        end
        log_debug("Action : #{@player_actions.last}") if debug?
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
      else
        @next_update = effect ? :player_action_choice : :skill_choice
      end
    ensure
      @skip_frame = true
    end
    # Check if the player can make another action choice
    # @note push empty hash where Pokemon cannot be controlled
    # @return [Boolean]
    def can_player_make_another_action_choice?
      next_relative_mon = @player_actions.size.upto(@battle_info.vs_type - 1).find_index do |position|
        next(false) unless (pokemon = @logic.battler(0, position))
        next(pokemon.alive? && pokemon.from_player_party?)
      end
      return false unless next_relative_mon
      next_relative_mon.times {@player_actions << Actions::Base.new(self) }
      return true
    end
    # Tell if the player is not allowed to take any actions
    # @return [Boolean]
    def no_player_action?
      return true if @no_player_action
      return @logic.all_battlers.none?(&:from_party?) || (@logic.alive_battlers(0).any? && @logic.alive_battlers(0).none?(&:from_party?))
    end
    # Method that asks the item to use
    def item_choice
      item_wrapper = @visual.show_item_choice
      if item_wrapper
        return if special_item_choice_action(item_wrapper)
        @player_actions << Actions::Item.new(self, item_wrapper, @logic.battler(0, @player_actions.size).bag, @logic.battler(0, @player_actions.size))
        log_debug("Action : #{@player_actions.last}") if debug?
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
      else
        @next_update = :player_action_choice
      end
    end
    # Method that test if the item_wrapper has different logic and execute is
    # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
    # @return [Boolean] if the battle should not continue normally
    def special_item_choice_action(item_wrapper)
      case item_wrapper.item
      when Studio::FleeingItem
        @logic.battle_result = 1
        @next_update = :battle_end
      when Studio::BallItem
        caught(item_wrapper) unless catch_prevented(item_wrapper)
      else
        return false
      end
      $bag.last_battle_item_db_symbol = item_wrapper.item.db_symbol
      return true
    end
    # Begin the Pokemon giving procedure
    # @param battler [PFM::PokemonBattler] pokemon that was just caught
    # @param ball [Studio::BallItem]
    def give_pokemon_procedure(battler, ball)
      pkmn = battler.original
      Audio.bgm_play(*@battle_info.victory_bgm)
      message_window.blocking = true
      message_window.wait_input = true
      battler.captured_with = ball.id
      update_pokemon_related_quests(pkmn)
      $wild_battle.remove_roaming_pokemon(pkmn)
      display_message_and_wait(parse_text(18, 67, PKNAME[0] => pkmn.name))
      update_pokedex_related_infos(pkmn)
      rename_sequence(pkmn) if $options.catch_rename
      battler.loyalty = 200 if ball&.db_symbol == :friend_ball
      $game_system.map_interpreter.add_pokemon(pkmn)
      if $game_switches[Yuki::Sw::SYS_Stored]
        display_message_and_wait(parse_text(30, 1, PKNICK[0] => pkmn.given_name, '[VAR BOX(0001)]' => $storage.get_box_name($storage.current_box)))
      end
    end
    # Pokemon related quests update
    # @param pkmn [PFM::Pokemon] pokemon that was just caught
    def update_pokemon_related_quests(pkmn)
      $quests.catch_pokemon(pkmn)
      $quests.beat_pokemon(pkmn.db_symbol)
    end
    # Pokemon related Pokedex update
    # @param pkmn [PFM::Pokemon] pokemon that was just caught
    def update_pokedex_related_infos(pkmn)
      unless $pokedex.creature_caught?(pkmn.id)
        $pokedex.mark_captured(pkmn.id)
        if $pokedex.enabled?
          display_message_and_wait(parse_text(18, 68, PKNAME[0] => pkmn.name))
          GamePlay.open_dex_to_show_pokemon(pkmn)
        end
      end
    end
    # Rename question and scene
    # @param pkmn [PFM::Pokemon] pokemon that was just caught
    def rename_sequence(pkmn)
      if display_message_and_wait(parse_text(30, 0, PKNAME[0] => pkmn.name), 0, text_get(25, 20), text_get(25, 21)) == 0
        GamePlay.open_pokemon_name_input(pkmn) { |scene| pkmn.given_name = scene.return_name }
      end
    end
    # Method that asks the pokemon to switch with
    def switch_choice
      pokemon_to_send = @visual.show_pokemon_choice
      if pokemon_to_send
        pokemon_to_switch = @logic.battler(0, @player_actions.size)
        @player_actions << Actions::Switch.new(self, pokemon_to_switch, pokemon_to_send)
        log_debug("Action : #{@player_actions.last}") if debug?
        @next_update = can_player_make_another_action_choice? ? :player_action_choice : :trigger_all_AI
      else
        @next_update = :player_action_choice
      end
    end
    # Clean the action that was removed from the stack (Make sure we don't lock things)
    def clean_action(action)
      return unless action
      if action.is_a?(Actions::Switch)
        action = Actions::Switch.from(action)
        action.who.switching = false
        action.with.switching = false
      end
    end
    # Method that checks if the flee is possible
    def flee_attempt
      @message_window.width = @visual.viewport.rect.width if @visual.viewport
      @message_window.wait_input = true
      return debug_terminate_trainer_battle if debug? && logic.battle_info.trainer_battle? && Input::Keyboard.press?(Input::Keyboard::LControl)
      result = @logic.flee_handler.attempt(@player_actions.size)
      if result == :success
        @logic.battle_result = 1
        @next_update = :battle_end
      else
        if result == :blocked
          @next_update = :player_action_choice
        else
          @next_update = :trigger_all_AI
        end
      end
    end
    def debug_terminate_trainer_battle
      choice = display_message_and_wait('Do you want to terminate this battle?', 1, 'Yes', 'No')
      return if choice == 1
      choice = display_message_and_wait('Do you want to treat as a win or a lose?', 1, 'Win', 'Lose')
      @logic.battle_result = choice == 0 ? 0 : 2
      @logic.debug_end_of_battle = true
      @next_update = :battle_end
    end
    # Method that checks if nuzlocke mode prevents capture
    # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
    # @return [Boolean] if nuzlocke mode prevents capture
    def catch_prevented(item_wrapper)
      return false unless PFM.game_state.nuzlocke.enabled? && PFM.game_state.nuzlocke.catching_locked_here?
      message_window.blocking = true
      message_window.wait_input = true
      display_message_and_wait(ext_text(8999, 20))
      $bag.add_item(item_wrapper.item.id, 1)
      @next_update = :player_action_choice
      return true
    end
    # Method to caught a Pokémon
    # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
    def caught(item_wrapper)
      if (caught = logic.catch_handler.try_to_catch_pokemon(logic.alive_battlers(1)[0], logic.alive_battlers(0)[0], item_wrapper.item))
        logic.battle_info.caught_pokemon = logic.alive_battlers(1)[0]
        give_pokemon_procedure(logic.battle_info.caught_pokemon, item_wrapper.item)
        @logic.battle_phase_end_caught
      end
      @next_update = caught ? :battle_end : :trigger_all_AI
      should_activate_ball_fetch?(item_wrapper)
    end
    # Method to know if BallFetch should activate or not
    # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
    def should_activate_ball_fetch?(item_wrapper)
      result = logic.all_alive_battlers.select { |battler| battler.has_ability?(:ball_fetch) && logic.trainer_battlers.include?(battler) }
      return if result.empty?
      $bag.last_ball_used_db_symbol = item_wrapper.item.db_symbol
      @logic.ball_fetch_on_field = result.sort_by(&:spd).reverse
    end
    public
    private
    # Method that trigger all the AI
    # @note It should first trigger the trainer_dialog event and for each AI trigger the AI_force_action event
    def trigger_all_AI
      @logic.update_battler_turn_count
      call_event(:trainer_dialog)
      @artificial_intelligences.each_with_index do |ai, index|
        log_debug("Triggering AI\##{index} (#{ai.class})...")
        actions = call_event(:AI_force_action, ai, index)
        if actions
          @logic.add_actions(actions)
        else
          @logic.add_actions(ai.trigger)
        end
      end
      @next_update = :start_battle_phase
    end
    public
    private
    # Method that add the actions of the player, sort them and let the main phase process
    def start_battle_phase
      log_info('Starting battle phase')
      @logic.add_actions(@player_actions.flatten)
      @player_actions.clear
      @logic.sort_actions
      @message_window.width = @visual.viewport.rect.width if @visual.viewport
      @message_window.wait_input = true
      @next_update = :update_battle_phase
    end
    # Method that makes the battle logic perform an action
    # @note Should call the after_action_dialog event
    def update_battle_phase
      return if @logic.perform_next_action
      call_event(:after_action_dialog)
      if @logic.can_battle_continue?
        @logic.battle_phase_end
        @next_update = @logic.can_battle_continue? ? :player_action_choice : :battle_end
      else
        @next_update = :battle_end
      end
    end
    # Method that perform everything that needs to be performed at battle end (phrases etc...) and gives back the master to Scene_Map
    def battle_end
      log_info('Exiting battle')
      @battle_result = @logic.battle_result
      @logic.battle_end_handler.process
      $game_temp.in_battle = false
      $game_temp.battle_proc&.call(@battle_result)
      $game_temp.battle_proc = nil
      return_to_last_scene
    end
    # Method that tells to return to the last scene (Scene_Map)
    def return_to_last_scene
      $scene = Scene_Map.new
      @running = false
    end
    public
    class << self
      # Set the current battle scene
      # @return [Battle::Scene]
      attr_writer :current
      # Register an event for the battle
      # @param name [Symbol] name of the event
      # @param block [Proc] code of the event
      def register_event(name, &block)
        @current.send(:register_event, name, &block)
      end
    end
    private
    # Register an event for the battle
    # @param name [Symbol] name of the event
    # @param block [Proc] code of the event
    def register_event(name, &block)
      @battle_events[name] = block
      log_debug("Battle event #{name} registered")
    end
    # Call a named event to let the Maker put some personnal configuration of the battle
    # @param name [Symbol] name of the event
    # @param args [Array] arguments of the event if any
    def call_event(name, *args)
      return unless (event = @battle_events[name]) && event.is_a?(Proc)
      log_debug("Calling #{name} battle event.")
      event.call(self, *args)
    end
    # Load the battle event
    # @note events are stored inside Data/Events/Battle/{id} name.rb (if not compiled)
    #   or inside Data/Events/Battle/{id}.yarb (if compiled) is a 5 digit number (zero padding at the begining)
    # @param id [Integer] id of the battle
    def load_events(id)
      return if id < 0
      Scene.current = self
      id = format('%05d', id)
      PSDK_CONFIG.release? ? load_yarb_events(id) : load_ruby_events(id)
    end
    if PSDK_CONFIG.release?
      # Load the events from a YARB file
      # @param id [String] the id of the event (00051 for 51)
      def load_yarb_events(id)
        filename = "Data/Events/Battle/#{id}.yarbc"
        return unless File.exist?(filename)
        RubyVM::InstructionSequence.load_from_binary(Zlib::Inflate.inflate(load_data(filename))).eval
      end
    else
      # Load the events from a ruby file
      # @param id [String] the id of the event (00051 for 51)
      def load_ruby_events(id)
        filename = Dir["Data/Events/Battle/#{id}*.rb"].first
        return unless filename && File.exist?(filename)
        log_debug("Load battle events from #{filename}")
        eval(File.read(filename), TOPLEVEL_BINDING)
      end
    end
    public
    # Message Window of the Battle
    class Message < UI::Message::Window
      # Number of 60th of second to wait while message does not wait for user input
      MAX_WAIT = 120
      # Default windowskin of the message
      WINDOW_SKIN = 'message_box'
      # If the message will wait user to validate the message forever
      # @return [Boolean]
      attr_accessor :blocking
      # If the message wait for the user to press a key before skiping
      # @return [Boolean]
      attr_accessor :wait_input
      # Create a new window
      def initialize(...)
        super(...)
        @wait_input = false
        @blocking = false
        @skipper_wait_animation = nil
      end
      # Process the wait user input phase
      def wait_user_input
        create_skipper_wait_animation unless @skipper_wait_animation
        @skipper_wait_animation&.update
        super
      end
      # Skip the update of wait input
      # @return [Boolean] if the update of wait input should be skipped
      def update_wait_input_skip
        return super if @wait_input
        terminate_message
        return true
      end
      # Autoskip the wait input
      # @return [Boolean]
      def update_wait_input_auto_skip
        return super || (!$game_system.battle_interpreter.running? && @skipper_wait_animation&.done? && !@blocking)
      end
      # Terminate the message display
      def terminate_message
        super
        @skipper_wait_animation = nil
      end
      # Function that create the skipper wait animation
      def create_skipper_wait_animation
        @skipper_wait_animation = Yuki::Animation.wait(MAX_WAIT / 60.0)
        @skipper_wait_animation.start
      end
      # Retrieve the current window position
      # @note Always return :bottom if the battler interpreter is not running
      # @return [Symbol, Array]
      def current_position
        return super if $game_system.battle_interpreter.running?
        return :bottom
      end
      # Battle Windowskin
      # @return [String]
      def current_windowskin
        @windowskin_overwrite || WINDOW_SKIN
      end
      # Retrieve the current window_builder
      # @return [Array]
      def current_window_builder
        return [16, 10, 288, 30, 16, 10] if current_windowskin == WINDOW_SKIN
        return super
      end
      # Translate the color according to the layout configuration
      # @param color [Integer] color to translate
      # @return [Integer] translated color
      def translate_color(color)
        return current_layout.color_mapping[color] || 10 + color if current_windowskin == WINDOW_SKIN
        return super
      end
      # Return the default horizontal margin
      # @return [Integer]
      def default_horizontal_margin
        return 0 if current_windowskin == WINDOW_SKIN
        return super
      end
      # Return the default vertical margin
      # @return [Integer]
      def default_vertical_margin
        return 0 if current_windowskin == WINDOW_SKIN
        return super
      end
    end
  end
end
# Module that hold all the Battle UI elements
module BattleUI
  # Module that implements the Going In & Out animation for each sprites/stacks of the UI
  #
  # To work this module requires `animation_handler` to return a `Yuki::Animation::Handler` !
  module GoingInOut
    # @!method animation_handler
    #   Get the animation handler
    #   @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    # Tell the element to go into the scene
    def go_in
      delta = go_in_out_delta
      animation_handler[:in_out] ||= go_in_animation
      animation_handler[:in_out].start(delta)
      @__in_out = :in
    end
    # Tell the element to go out of the scene
    # @param forced_delta [Float] set the forced delta to force the animation to be performed with a specific delta
    def go_out(forced_delta = nil)
      delta = forced_delta || go_in_out_delta
      animation_handler[:in_out] ||= go_out_animation
      animation_handler[:in_out].start(delta)
      @__in_out = :out
    end
    # Tell if the UI element is in
    # @note By default a UI element is considered as in because it's initialized in its in position
    # @return [Boolean]
    def in?
      return !out?
    end
    # Tell if the UI element is out
    # @return [Boolean]
    def out?
      return @__in_out == :out
    end
    private
    # Creates the go_in animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      return Yuki::Animation.wait(0)
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      return Yuki::Animation.wait(0)
    end
    # Get the delta to use to accord with the previous going-in-out animation
    # @return [Float]
    def go_in_out_delta
      return 0 if animation_handler[:in_out]&.done?
      delta = (animation_handler[:in_out] ? animation_handler[:in_out].time_source.call - animation_handler[:in_out].end_time : 0)
      return delta.clamp(-Float::INFINITY, 0)
    end
  end
  # Module that implements the Hide & Show animation for each sprites/stacks of the UI
  #
  # To work this module requires `animation_handler` to return a `Yuki::Animation::Handler` !
  #
  # You can specify a `hide_show_duration` function to overwrite the duration of this animation
  module HideShow
    # @!method animation_handler
    #   Get the animation handler
    #   @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    # Tell the element to show in the scene
    def show
      delta = hide_show_delta
      animation_handler[:hide_show] = show_animation
      animation_handler[:hide_show].start(delta)
    end
    # Tell the element to hide from scene
    def hide
      delta = hide_show_delta
      animation_handler[:hide_show] = hide_animation
      animation_handler[:hide_show].start(delta)
    end
    private
    # Creates the hide animation
    # @return [Yuki::Animation::TimedAnimation]
    def hide_animation
      ya = Yuki::Animation
      animation = ya.opacity_change(hide_show_duration, self, opacity, 0)
      animation.play_before(ya.send_command_to(self, :visible=, false))
      return animation
    end
    # Creates the show animation
    # @param target_opacity [Integer] the desired opacity (if you need non full opacity)
    # @return [Yuki::Animation::TimedAnimation]
    def show_animation(target_opacity = 255)
      ya = Yuki::Animation
      animation = ya.send_command_to(self, :visible=, true)
      animation.play_before(ya.opacity_change(hide_show_duration, self, 0, target_opacity))
      return animation
    end
    # Get the delta to use to accord with the previous hiding/showing animation
    # @return [Float]
    def hide_show_delta
      return 0 if animation_handler[:hide_show]&.done?
      delta = (animation_handler[:hide_show]&.end_time ? animation_handler[:hide_show].time_source.call - animation_handler[:hide_show].end_time : 0)
      return delta.clamp(-Float::INFINITY, 0)
    end
    # get the duration of the hide show animation
    # @return [Float]
    def hide_show_duration
      return 0.1
    end
  end
  # Module helping to position any sprite that can get several positions depending on the battle mode
  #
  # All class including this module should define the following methods
  #   - `scene` that returns the current Battle Scene
  #   - `position` that returns the position of the current object in its bank (0, 1, 2, ...)
  #   - `bank` that returns the bank of the current object (0 = ally, 1 = enemies)
  #   - `base_position_v1` that returns the base position of the object in 1v1 battles
  #   - `base_position_v2` that returns the base position of the object in 2v2+ battles
  #   - `offset_position_v2` that returns the offset of the object depending on its bank (this offset is multiplied to position)
  #
  # This module will define a `sprite_position` function that will compute the x & y position this element should get
  module MultiplePosition
    # Tell if the sprite is from the enemy side
    # @return [Boolean]
    def enemy?
      return bank == 1
    end
    private
    # Get the sprite position
    # @return [Array(Integer, Integer)]
    def sprite_position
      if scene.battle_info.vs_type == 1
        x, y = base_position_v1
      else
        x, y = base_position_v2
        dx, dy = offset_position_v2
        x += dx * position
        y += dy * position
      end
      return x, y
    end
  end
  # Abstraction for the exp distribution so you can do right things
  module ExpDistributionAbstraction
    # Get the scene
    # @return [Battle::Scene]
    attr_reader :scene
    private
    # Get the list of Pokemon that can get exp (are from player party)
    # @return [Array<PFM::PokemonBattler>]
    def find_expable_pokemon
      return 2.times.map do |bank|
        6.times.map { |position| @scene.logic.battler(bank, position) }.compact.select(&:from_party?)
      end.flatten
    end
    # Map Pokemon to originals with form
    # @param pokemon [Array<PFM::PokemonBattler>]
    # @return [Array<PFM::Pokemon>]
    # @note Do not call this function twice, it's caching for safety reasons
    def map_to_original_with_forms(pokemon)
      return @__original_pokemon if @__original_pokemon
      @__original_forms = pokemon.map { |battler| battler.original.form }
      @__original_pokemon = pokemon.map do |battler|
        original = battler.original
        original.instance_variable_set(:@form, battler.form) unless battler.transform || battler.illusion
        next(original)
      end
      return @__original_pokemon
    end
    # Restore the form to originals
    def restore_form_to_originals
      @__original_pokemon&.each_with_index do |original, index|
        original.instance_variable_set(:@form, @__original_forms[index] || 0)
      end
      @__original_pokemon = nil
    end
    # Align exp of all original mon to the battlers
    # @param battlers [Array<PFM::PokemonBattler>]
    def align_exp(battlers)
      battlers.each do |battler|
        battler.exp = battler.original.exp
      end
    end
    # Function that shows level up of a Pokemon
    # @param pokemon [PFM::PokemonBattler]
    # @yieldparam original [PFM::PokemonBattler] the original battler in case you need it
    # @yieldparam list [Array<Array>] stat list due to level up
    def show_level_up(pokemon)
      original = pokemon.original
      original.hp = pokemon.hp unless pokemon.transform
      list = original.level_up_stat_refresh
      yield(original, list)
      level_up_message(pokemon)
      scene.logic.evolve_request << pokemon unless scene.logic.evolve_request.include?(pokemon)
    end
    # Show the level up message
    # @param receiver [PFM::PokemonBattler]
    # @param show_message [Boolean] tell if the level up message should be shown
    def level_up_message(receiver, show_message: false)
      original = receiver.original
      PFM::Text.set_num3(original.level.to_s, 1)
      scene.display_message_and_wait(parse_text(18, 62, '[VAR 010C(0000)]' => original.given_name)) if show_message
      PFM::Text.reset_variables
      if original.can_learn_skill_at_this_level?
        moveset_before = original.skills_set.clone
        original.check_skill_and_learn
        receiver.level_up_copy_moveset(moveset_before) if original.skills_set != moveset_before
      end
      receiver.level_up_copy
    end
  end
  # Abstraction helping to design player choice a way that complies to what Visual expect to handle
  module PlayerChoiceAbstraction
    # @!parse
    #   include GenericChoice
    # The result :attack, :bag, :pokemon, :flee, :cancel, :try_next, :action
    # @return [Symbol, nil]
    attr_reader :result
    # The possible action made by the player (other than choosing a sub action)
    # @return [Battle::Actions::Base]
    attr_reader :action
    # Get the index
    # @return [Integer]
    attr_reader :index
    # Reset the choice
    # @param can_switch [Boolean]
    def reset(can_switch)
      @action = nil
      @result = nil
      @can_switch = can_switch
      @index = 0
      scene.visual.set_info_state(:choice)
      super() if @super_reset
    end
    # If the player made a choice
    # @return [Boolean]
    def validated?
      !@result.nil? && (respond_to?(:done?, true) ? done? : true)
    end
    # Force the action to use an item
    # @param item [Studio::Item]
    def use_item(item)
      item_wrapper = PFM::ItemDescriptor.actions(item.id)
      return use_item_on_creature_choice(item_wrapper) if item_wrapper.on_creature_choice?
      @result = :action
      user = scene.logic.battler(0, scene.player_actions.size)
      item_wrapper.bind(scene, user)
      $bag.remove_item(item_wrapper.item.db_symbol, 1) if item_wrapper.item.is_limited && item_wrapper.item.is_a?(Studio::BallItem)
      @action = Battle::Actions::Item.new(scene, item_wrapper, $bag, user)
    end
    private
    # Use an item that needs to pick a Pokemon
    # @param item_wrapper [PFM::ItemDescriptor::Wrapper]
    def use_item_on_creature_choice(item_wrapper)
      party = scene.logic.all_battlers.select(&:from_party?)
      GamePlay.open_party_menu_to_use_item(item_wrapper, party) do |result|
        next unless result.pokemon_selected?
        next if result.call_skill_process
        item_wrapper.bind(scene, user = party[result.return_data])
        $bag.remove_item(item_wrapper.item.id, 1) if item_wrapper.item.is_limited && item_wrapper.item.is_a?(Studio::BallItem)
        @action = Battle::Actions::Item.new(scene, item_wrapper, $bag, user)
        @result = :action
      end
    end
    # Set the choice as wanting to switch pokemon
    # @return [Boolean] if the operation was a success
    def choice_pokemon
      return false unless @can_switch
      @result = :pokemon
      return true
    end
    # Set the choice as wanting to flee
    # @return [Boolean] if the operation was a success
    def choice_flee
      return false unless @can_switch
      @result = :flee
      return true
    end
    # Set the choice as wanting to use a move
    # @return [Boolean] if the operation was a success
    def choice_attack
      @result = :attack
      return true
    end
    # Set the choice as wanting to use an item from bag
    # @return [Boolean] if the operation was a success
    def choice_bag
      @result = :bag
      return true
    end
    # Set the choice as wanting to cancel the choice
    # @return [Boolean] if the operation was a success
    def choice_cancel
      return false if scene.player_actions.empty?
      @result = :cancel
      return true
    end
    # Show failure for specific choice like Pokemon & Flee
    # @param play_buzzer [Boolean] tell if the buzzer sound should be played
    # @param show_hide [Boolean] tell if the choice should be hidden during the failure show
    def show_switch_choice_failure(play_buzzer: true, show_hide: true)
      $game_system.se_play($data_system.buzzer_se) if play_buzzer
      if show_hide
        hide
        scene.visual.animations << animation_handler[:hide_show]
        scene.visual.wait_for_animation
      end
      (handler = scene.logic.switch_handler).can_switch?(scene.logic.battler(0, scene.player_actions.size))
      handler.process_prevention_reason
      show if show_hide
    end
  end
  # Abstraction helping to design skill choice a way that complies to what Visual expect to handle
  module SkillChoiceAbstraction
    # @!parse
    #   include GenericChoice
    # The selected move
    # @return [Battle::Move, :cancel]
    attr_reader :result
    # The pokemon the player choosed a move
    # @return [PFM::PokemonBattler]
    attr_reader :pokemon
    # Tell if the mega evolution is enabled
    # @return [Boolean]
    attr_accessor :mega_enabled
    # Get the index
    # @return [Integer]
    attr_reader :index
    # Reset the Skill choice
    # @param pokemon [PFM::PokemonBattler]
    def reset(pokemon)
      @pokemon = pokemon
      @mega_enabled = false
      self.data = pokemon if respond_to?(:data=, true)
      @index = @last_indexes[pokemon].to_i.clamp(0, max_index)
      update_button_opacity
      super() if @super_reset
    end
    # Ensure the info are reset properly with current Encore'd Pokemon
    # @param pokemon [PFM::PokemonBattler]
    # @param move [Battle::Move]
    def encore_reset(pokemon, move)
      @pokemon = pokemon
      @mega_enabled = false
      @index = @last_indexes[pokemon].to_i.clamp(0, max_index)
      @result = move
    end
    # If the player made a choice
    # @return [Boolean]
    def validated?
      !@result.nil? && (respond_to?(:done?, true) ? done? : true)
    end
    private
    # Give the max index of the choice
    # @return [Integer]
    def max_index
      return 4
    end
    # Set the choice as wanting to cancel the choice
    # @return [Boolean] if the operation was a success
    def choice_cancel
      @result = :cancel
      return true
    end
    # Set the choice of the move to use
    # @param index [Integer]
    # @return [Boolean]
    def choice_move(index = @index)
      move = @pokemon.moveset[index]
      unless move.disable_reason(@pokemon)
        @result = move
        return true
      end
      return false
    end
    # Show the move choice failure
    # @param index [Integer]
    def show_move_choice_failure(index = @index)
      move = @pokemon.moveset[@index]
      move.disable_reason(@pokemon)&.call
    end
  end
  # Abstraction of the Target Selection to comply with what the Visual expect
  module TargetSelectionAbstraction
    # The position (bank, position) of the choosen target
    # @return [Array, :cancel]
    attr_accessor :result
    # If the player made a choice
    # @return [Boolean]
    def validated?
      !@result.nil? && (respond_to?(:done?, true) ? done? : true)
    end
    private
    # Function that initialize the required data to ensure every necessary instance variables are set
    # @param launcher [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @param logic [Battle::Logic]
    def initialize_data(launcher, move, logic)
      @launcher = launcher
      @move = move
      @logic = logic
      @row_size = logic.battle_info.vs_type
      @targets = move.battler_targets(launcher, logic).select(&:alive?)
      @allow_selection = !move.no_choice_skill?
      @mons = generate_mon_list
      @index = find_best_index
    end
    # Choose the target
    # @return [Boolean] if the operation was a success
    def choose_target
      if @targets.empty?
        @result = [1, 0]
        return true
      end
      target = @allow_selection ? @buttons[@index].data : @targets.first
      target = @targets.sample(random: @logic.generic_rng) if @move.target == :random_foe
      if @targets.include?(target)
        @result = [target.bank, target.position]
        return true
      end
      return false
    end
    # Tell that the player cancelled
    # @return [Boolean]
    def choice_cancel
      @result = :cancel
      return true
    end
    # Generate the list of mons shown by the UI
    # @return [Array<PFM::PokemonBattler>]
    def generate_mon_list
      2.times.map do |bank|
        @logic.battle_info.vs_type.times.map do |position|
          @logic.battler(bank, position)
        end
      end.reverse.flatten
    end
    # Find the best possible index as default index
    # @return [Integer]
    def find_best_index
      return @mons.index(@targets.first).to_i
    end
  end
  # Sprite of a Pokemon in the battle
  class PokemonSprite < ShaderedSprite
    include GoingInOut
    include MultiplePosition
    # Constant giving the deat Delta Y (you need to adjust that so your screen animation are OK when Pokemon are KO)
    DELTA_DEATH_Y = 32
    # Tell if the sprite is currently selected
    # @return [Boolean]
    attr_accessor :selected
    # Get the Pokemon shown by the sprite
    # @return [PFM::PokemonBattler]
    attr_reader :pokemon
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the position of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :position
    # Get the bank of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :bank
    # Get the scene linked to this object
    # @return [Battle::Scene]
    attr_reader :scene
    # Create a new PokemonSprite
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    def initialize(viewport, scene)
      super(viewport)
      @shadow = ShaderedSprite.new(viewport)
      @shadow.shader = Shader.create(:battle_shadow)
      @animation_handler = Yuki::Animation::Handler.new
      @bank = 0
      @position = 0
      @scene = scene
    end
    # Update the sprite
    def update
      @animation_handler.update
      @gif&.update(bitmap) unless pokemon&.dead?
    end
    # Tell if the sprite animations are done
    # @return [Boolean]
    def done?
      return @animation_handler.done?
    end
    # Set the Pokemon
    # @param pokemon [PFM::PokemonBattler]
    def pokemon=(pokemon)
      @pokemon = pokemon
      if pokemon
        @position = pokemon.position
        @bank = pokemon.bank
        load_battler
        reset_position
      end
    end
    # Play the cry of the Pokemon
    # @param dying [Boolean] if the Pokemon is dying
    def cry(dying = false)
      return unless pokemon
      Audio.se_play(pokemon.cry, 100, dying ? 80 : 100)
    end
    # Set the origin of the sprite & the shadow
    # @param ox [Numeric]
    # @param oy [Numeric]
    # @return [self]
    def set_origin(ox, oy)
      @shadow.set_origin(ox, oy)
      super
    end
    # Set the zoom of the sprite
    # @param zoom [Float]
    def zoom=(zoom)
      @shadow.zoom = zoom
      super
    end
    # Set the position of the sprite
    # @param x [Numeric]
    # @param y [Numeric]
    # @return [self]
    def set_position(x, y)
      @shadow.set_position(x, y)
      super
    end
    # Set the y position of the sprite
    # @param y [Numeric]
    def y=(y)
      @shadow.y = y
      super
    end
    # Set the x position of the sprite
    # @param x [Numeric]
    def x=(x)
      @shadow.x = x
      super
    end
    # Set the opacity of the sprite
    # @param opacity [Integer]
    def opacity=(opacity)
      @shadow.opacity = opacity
      super
    end
    # Set the bitmap of the sprite
    # @param bitmap [Texture]
    def bitmap=(bitmap)
      @shadow.bitmap = bitmap
      super
    end
    # Set the visibility of the sprite
    # @param visible [Boolean]
    def visible=(visible)
      @shadow.visible = visible
      super
    end
    # Creates the flee animation
    # @return [Yuki::Animation::TimedAnimation]
    def flee_animation
      bx = enemy? ? viewport.rect.width + width : -width
      ya = Yuki::Animation
      animation = ya.move(0.5, self, x, y, bx, y)
      animation.parallel_add(ya::ScalarAnimation.new(0.5, self, :opacity=, 255, 0))
      animation.parallel_add(ya.se_play('fleee', 100, 60))
      animation.start
      animation_handler[:in_out] = animation
    end
    private
    # Reset the battler position
    def reset_position
      set_position(*sprite_position)
      self.z = basic_z_position
      set_origin(width / 2, height)
    end
    # Return the basic z position of the battler
    def basic_z_position
      z = @pokemon.bank == 0 ? 501 : 1
      z += @pokemon.position
      return z
    end
    # Get the base position of the Pokemon in 1v1
    # @return [Array(Integer, Integer)]
    def base_position_v1
      return 242, 138 if enemy?
      return 78, 184
    end
    # Get the base position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def base_position_v2
      return 202, 133 if enemy?
      return 58, 179
    end
    # Get the offset position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def offset_position_v2
      return 60, 10
    end
    # Load the battler of the Pokemon
    def load_battler
      if @last_pokemon&.id != @pokemon.id || @last_pokemon&.form != @pokemon.form || @last_pokemon&.code != @pokemon.code
        bitmap.dispose if @gif
        remove_instance_variable(:@gif) if instance_variable_defined?(:@gif)
        gif = pokemon.bank != 0 ? pokemon.gif_face : pokemon.gif_back
        if gif
          @gif = gif
          self.bitmap = Texture.new(gif.width, gif.height)
          gif.draw(bitmap)
        else
          self.bitmap = pokemon.bank != 0 ? pokemon.battler_face : pokemon.battler_back
        end
      end
      @last_pokemon = @pokemon.clone
    end
    # Creates the go_in animation (Exiting the ball)
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      no_ball_trainer = $game_switches[Yuki::Sw::BT_NO_BALL_ANIMATION] && enemy?
      return follower_go_in_animation if pokemon.is_follower || no_ball_trainer
      return regular_go_in_animation
    end
    # Creates the go_out animation (Entering the ball if not KO, shading out if KO)
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      return ko_go_out_animation if pokemon.dead?
      return follower_go_out_animation if pokemon.is_follower
      return regular_go_out_animation
    end
    # Creates the go_in animation of a "follower" pokemon
    # @return [Yuki::Animation::TimedAnimation]
    def follower_go_in_animation
      x, y = sprite_position
      bx = enemy? ? viewport.rect.width + width : -width
      $game_switches[Yuki::Sw::BT_NO_BALL_ANIMATION] = false if enemy?
      ya = Yuki::Animation
      animation = ya.send_command_to(self, :visible=, true)
      animation.play_before(ya.send_command_to(self, :zoom=, sprite_zoom))
      animation.play_before(ya.send_command_to(self, :opacity=, 255))
      animation.play_before(ya.move(0.1, self, bx, y, x, y))
      animation.play_before(ya.send_command_to(self, :cry))
      return animation
    end
    # Creates the regular go in animation (not follower)
    # @return [Yuki::Animation::TimedAnimation]
    def regular_go_in_animation
      ya = Yuki::Animation
      animation = ya.send_command_to(self, :visible=, true)
      animation.play_before(ya.send_command_to(self, :zoom=, 0))
      animation.play_before(ya.send_command_to(self, :opacity=, 255))
      animation.play_before(ya.send_command_to(self, :set_position, *sprite_position))
      poke_out = ya.scalar(0.1, self, :zoom=, 0, sprite_zoom)
      ball_animation = enemy? ? enemy_ball_animation(poke_out) : actor_ball_animation(poke_out)
      animation.play_before(ball_animation)
      animation.play_before(ya.send_command_to(self, :cry))
      return animation
    end
    # Creates the go_out animation of a "follower" pokemon
    # @return [Yuki::Animation::TimedAnimation]
    def follower_go_out_animation
      x, y = sprite_position
      bx = enemy? ? viewport.rect.width + width : -width
      return Yuki::Animation.move(0.1, self, x, y, bx, y)
    end
    # Creates the regular go out animation (not follower)
    # @return [Yuki::Animation::TimedAnimation]
    def regular_go_out_animation
      ya = Yuki::Animation
      animation = ya.send_command_to(self, :zoom=, sprite_zoom)
      animation.play_before(go_back_ball_animation(ya.scalar(0.1, self, :zoom=, sprite_zoom, 0)))
      return animation
    end
    # Create the go_out animation of a KO pokemon
    # @return [Yuki::Animation::TimedAnimation]
    def ko_go_out_animation
      ya = Yuki::Animation
      animation = ya.send_command_to(self, :cry, true)
      going_down = ya.opacity_change(0.1, self, opacity, 0)
      animation.play_before(going_down)
      going_down.parallel_add(ya.move(0.1, self, x, y, x, y + DELTA_DEATH_Y))
      return animation
    end
    # Create the ball animation of the actor Pokemon
    # @param pokemon_going_out_of_ball_animation [Yuki::Animation::TimedAnimation]
    # @return [Yuki::Animation::TimedAnimation]
    def actor_ball_animation(pokemon_going_out_of_ball_animation)
      sprite = UI::ThrowingBallSprite.new(viewport, @pokemon)
      sprite.set_position(-sprite.ball_offset_y, y - sprite.trainer_offset_y)
      ya = Yuki::Animation
      animation = ya.scalar_offset(0.5, sprite, :y, :y=, 0, -64, distortion: :SQUARE010_DISTORTION)
      animation.parallel_play(ya.move(0.5, sprite, -sprite.ball_offset_y, y - sprite.trainer_offset_y, x, y - sprite.ball_offset_y))
      animation.parallel_play(ya.scalar(0.5, sprite, :throw_progression=, 0, 1))
      animation.parallel_play(ya.se_play(*sending_ball_se))
      animation.play_before(ya.se_play(*opening_ball_se))
      animation.play_before(ya.scalar(0.1, sprite, :open_progression=, 0, 1))
      animation.play_before(ya.send_command_to(sprite, :dispose))
      animation.play_before(pokemon_going_out_of_ball_animation)
      return animation
    end
    # Create the ball animation of the enemy Pokemon
    # @param pokemon_going_out_of_ball_animation [Yuki::Animation::TimedAnimation]
    # @return [Yuki::Animation::TimedAnimation]
    def enemy_ball_animation(pokemon_going_out_of_ball_animation)
      sprite = UI::ThrowingBallSprite.new(viewport, @pokemon)
      sprite.set_position(*sprite_position)
      sprite.y -= sprite.ball_offset_y
      ya = Yuki::Animation
      animation = ya.wait(0.2)
      animation.play_before(ya.se_play(*opening_ball_se))
      animation.play_before(ya.scalar(0.1, sprite, :open_progression=, 0, 1))
      animation.play_before(ya.send_command_to(sprite, :dispose))
      animation.play_before(pokemon_going_out_of_ball_animation)
      return animation
    end
    # Create the ball animation of the Pokemon going back in ball
    # @param pokemon_going_in_the_ball_animation [Yuki::Animation::TimedAnimation]
    # @return [Yuki::Animation::TimedAnimation]
    def go_back_ball_animation(pokemon_going_in_the_ball_animation)
      sprite = UI::ThrowingBallSprite.new(viewport, @pokemon)
      sprite.set_position(*sprite_position)
      sprite.y -= sprite.ball_offset_y
      ya = Yuki::Animation
      animation = ya.wait(0.2)
      animation.play_before(ya.se_play(*back_ball_se))
      animation.play_before(ya.scalar(0.1, sprite, :open_progression=, 0, 1))
      animation.play_before(ya.send_command_to(sprite, :dispose))
      animation.play_before(pokemon_going_in_the_ball_animation)
      return animation
    end
    # SE played when the ball is sent
    def sending_ball_se
      return 'fall'
    end
    # SE played when the ball is opening
    def opening_ball_se
      return 'pokeopen'
    end
    # SE played when the Pokemon back to the ball
    def back_ball_se
      return 'pokeopen'
    end
    # Pokemon sprite zoom
    # @return [Integer]
    def sprite_zoom
      return 1
    end
  end
  # Object that show the Battle Bar of a Pokemon in Battle
  # @note Since .25 InfoBar completely ignore bank & position info about Pokemon to make thing easier regarding positionning
  class InfoBar < UI::SpriteStack
    include UI
    include GoingInOut
    include MultiplePosition
    # The information of the HP Bar
    HP_BAR_INFO = [92, 4, 0, 0, 6]
    # bw, bh, bx, by, nb_states
    # The information of the Exp Bar
    EXP_BAR_INFO = [88, 2, 0, 0, 1]
    # Get the Pokemon shown by the InfoBar
    # @return [PFM::PokemonBattler]
    attr_reader :pokemon
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the position of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :position
    # Get the bank of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :bank
    # Get the scene linked to this object
    # @return [Battle::Scene]
    attr_reader :scene
    # Create a new InfoBar
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param pokemon [PFM::Pokemon]
    # @param bank [Integer]
    # @param position [Integer]
    def initialize(viewport, scene, pokemon, bank, position)
      super(viewport)
      @animation_handler = Yuki::Animation::Handler.new
      @bank = bank
      @position = position
      @scene = scene
      create_sprites
      self.pokemon = pokemon
    end
    # Update the InfoBar
    def update
      @animation_handler.update
    end
    # Tell if the InfoBar animations are done
    # @return [Boolean]
    def done?
      return @animation_handler.done?
    end
    # Sets the Pokemon shown by this bar
    # @param pokemon [PFM::Pokemon]
    def pokemon=(pokemon)
      @pokemon = pokemon
      refresh
    end
    # Refresh the bar contents
    def refresh
      if @pokemon
        self.visible = true
        self.data = @pokemon
        set_position(*sprite_position) if in?
      else
        self.visible = false
      end
    end
    # Set the Creature to show in the Info Bar
    def data=(pokemon)
      super
      @star.visible = pokemon.shiny && !pokemon.egg?
    end
    private
    # Get the base position of the Pokemon in 1v1
    # @return [Array(Integer, Integer)]
    def base_position_v1
      return 184, 9 if enemy?
      return 2, 198
    end
    # Get the base position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def base_position_v2
      return 48, 9 if enemy?
      return 2, 195
    end
    # Get the offset position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def offset_position_v2
      return 136, 3 if enemy?
      return 136, -3
    end
    def create_sprites
      create_background
      create_hp
      create_exp
      create_name
      create_catch_sprite
      create_gender_sprite
      create_level
      create_status
      @star = create_star
    end
    def create_background
      @background = add_sprite(0, 0, NO_INITIAL_IMAGE, type: Background)
    end
    def create_hp
      @hp_background = add_sprite(*hp_background_coordinates, 'battle/battlebar_')
      @hp_bar = push_sprite Bar.new(@viewport, *hp_bar_coordinates, RPG::Cache.interface('battle/bars_hp'), *HP_BAR_INFO)
      @hp_bar.data_source = :hp_rate
      @hp_text = add_text(66, 17, 0, 10, enemy? ? :void_string : :hp_pokemon_number, type: SymText, color: 10)
    end
    def create_exp
      return if enemy?
      add_sprite(36, 30, 'battle/battlebar_exp')
      @exp_bar = push_sprite Bar.new(@viewport, 37, 31, RPG::Cache.interface('battle/bars_exp'), *EXP_BAR_INFO)
      @exp_bar.data_source = :exp_rate
    end
    def hp_background_coordinates
      return enemy? ? [8, 12] : [18, 12]
    end
    def hp_bar_coordinates
      return enemy? ? [x + 23, y + 13] : [x + 33, y + 13]
    end
    def create_name
      with_font(20) do
        @name = add_text(8, -4, 0, 16, :given_name, 0, 1, color: 10, type: SymText)
      end
    end
    def create_catch_sprite
      add_sprite(118, 10, 'battle/ball', type: PokemonCaughtSprite)
    end
    def create_gender_sprite
      add_sprite(81, -3, NO_INITIAL_IMAGE, type: GenderSprite)
    end
    def create_level
      add_text(91, -6, 0, 16, :level_pokemon_number, 0, 1, color: 10, type: SymText)
    end
    def create_status
      add_sprite(8, 19, NO_INITIAL_IMAGE, type: StatusSprite)
    end
    def create_star
      return push(119, -4, 'shiny') if enemy?
      return push(6, 10, 'shiny')
    end
    # Creates the go_in animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      origin_y = enemy? ? -@background.height : @viewport.rect.height + @background.height
      return Yuki::Animation.move_discreet(0.2, self, x, origin_y, *sprite_position)
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      target_y = enemy? ? -@background.height : @viewport.rect.height + @background.height
      return Yuki::Animation.move_discreet(0.2, self, *sprite_position, x, target_y)
    end
    # Class showing the ball sprite if the Pokemon is enemy and caught
    class PokemonCaughtSprite < ShaderedSprite
      # Set the Pokemon Data
      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        self.visible = pokemon.bank != 0 && $pokedex.creature_caught?(pokemon.id)
      end
    end
    # Class showing the right background depending on the pokemon
    class Background < ShaderedSprite
      # Set the Pokemon Data
      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        return unless (self.visible = pokemon)
        set_bitmap(background_filename(pokemon), :interface)
      end
      # Name of the background based on the creature shown
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def background_filename(pokemon)
        return 'battle/battlebar_enemy' if pokemon.bank != 0
        return 'battle/battlebar_actor' if pokemon.from_party?
        return 'battle/battlebar_ally'
      end
    end
  end
  # Object that display the Battle Party Balls of a trainer in Battle
  #
  # Remaining Pokemon, Pokemon with status
  class TrainerPartyBalls < UI::SpriteStack
    include UI
    include GoingInOut
    include MultiplePosition
    # X coordinate of the first ball in the stack depending on the bank
    BALL_X = [3, 7]
    # Y coordinate of the first ball in the stack depending on the bank
    BALL_Y = [-3, -3]
    # Delta X between each balls
    BALL_DELTA = 14
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the position
    # @return [Integer]
    attr_reader :position
    # Get the bank of the party shown
    # @return [Integer]
    attr_reader :bank
    # Get the scene linked to this object
    # @return [Battle::Scene]
    attr_reader :scene
    # Create a new Trainer Party Balls
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param bank [Integer]
    def initialize(viewport, scene, bank)
      super(viewport)
      @animation_handler = Yuki::Animation::Handler.new
      @bank = bank
      @position = 0
      @scene = scene
      create_graphics
      set_position(*sprite_position)
      refresh
      go_out(-999)
      update
    end
    # Update all the animation of this UI element
    def update
      @animation_handler.update
    end
    # Refresh the content of the bar
    def refresh
      self.data = 6.times.map { |i| @scene.logic.battler(@bank, i) }
    end
    # Tell if the UI has done displaying its animation
    # @return [Boolean]
    def done?
      return @animation_handler.done?
    end
    private
    # Get the base position of the Pokemon in 1v1
    # @return [Array(Integer, Integer)]
    def base_position_v1
      return @viewport.rect.width, 0 if enemy? && !@scene.battle_info.trainer_battle?
      return 227, 48 if enemy?
      return 0, 173
    end
    alias base_position_v2 base_position_v1
    # Get the offset position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def offset_position_v2
      return 0, 0
    end
    # Creates the go_in animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      origin_x = enemy? ? @viewport.rect.width : -@background.width
      return Yuki::Animation.move_discreet(0.2, self, origin_x, y, *sprite_position)
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      target_x = enemy? ? @viewport.rect.width : -@background.width
      return Yuki::Animation.move_discreet(0.2, self, *sprite_position, target_x, y)
    end
    def create_graphics
      create_background
      create_balls
    end
    def create_background
      @background = add_background(enemy? ? 'battle/ball_win_enemy' : 'battle/ball_win_actor')
    end
    def create_balls
      base_x = BALL_X[@bank] || 0
      base_y = BALL_Y[@bank] || 0
      @balls = 6.times.map do |i|
        add_sprite(base_x + i * BALL_DELTA, base_y, NO_INITIAL_IMAGE, i, type: BallSprite)
      end
    end
    # Class showing a ball in the TrainerPartyBalls UI
    class BallSprite < Sprite
      # Create a new ball
      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport)
        @index = index
      end
      # Update the data
      # @param party [Array<PFM::PokemonBattler>]
      def data=(party)
        pokemon = party[@index]
        set_bitmap(image_filename(pokemon), :interface)
      end
      # Get the filename of the image to show as ball sprite
      # @param pokemon [PFM::PokemonBattler]
      def image_filename(pokemon)
        return 'battle/ball_null' unless pokemon
        return 'battle/ball_dead' if pokemon.dead?
        return 'battle/ball_sick' if pokemon.status != 0
        return 'battle/ball_normal'
      end
    end
  end
  # Sprite of a Trainer in the battle
  class TrainerSprite < ShaderedSprite
    include GoingInOut
    include MultiplePosition
    # Number of pixels the sprite has to move in other to fade away from the scene
    FADE_AWAY_PIXEL_COUNT = 160
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the position of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :position
    # Get the bank of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :bank
    # Get the scene linked to this object
    # @return [Battle::Scene]
    attr_reader :scene
    # Define the number of frames inside a back trainer
    BACK_FRAME_COUNT = 2
    # Create a new TrainerSprite
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param battler [String] name of the battler in graphics/battlers
    # @param bank [Integer] Bank where the Trainer is
    # @param position [Integer] position of the battler in the Array
    # @param battle_info [Battle::Logic::BattleInfo]
    def initialize(viewport, scene, battler, bank, position, battle_info)
      super(viewport)
      @animation_handler = Yuki::Animation::Handler.new
      @scene = scene
      @bank = bank
      @position = position
      @battle_info = battle_info
      set_bitmap(battler, :battler)
      src_rect.height = bitmap.height / BACK_FRAME_COUNT if @bank == 0
      reset_position
    end
    # Update the sprite
    def update
      @animation_handler.update
    end
    # Tell if the sprite animations are done
    # @return [Boolean]
    def done?
      return @animation_handler.done?
    end
    # Set the battler on its next frame
    # @note Frames are ordered on the vertical axis
    def show_next_frame
      new_y = src_rect.y + src_rect.height
      src_rect.y = new_y if new_y < bitmap.height
    end
    # Set the battler on its previous frame
    # @note Frames are ordered on the vertical axis
    def show_previous_frame
      new_y = src_rect.y - src_rect.height
      src_rect.y = new_y if new_y >= 0
    end
    private
    # Reset the battler position
    def reset_position
      set_position(*sprite_position)
      self.z = basic_z_position
      set_origin(width / 2, height)
    end
    # Return the basic z position of the battler
    def basic_z_position
      z = @bank == 0 ? 501 : 1
      z += @position
      return z
    end
    # Get the base position of the Trainer in 1v1
    # @return [Array(Integer, Integer)]
    def base_position_v1
      return 242, 108 if enemy?
      return 78, 188
    end
    # Get the base position of the Trainer in 2v2+
    # @return [Array(Integer, Integer)]
    def base_position_v2
      if enemy?
        return 202, 103 if @scene.battle_info.battlers[1].size >= 2
        return 242, 108
      end
      return 58, 188
    end
    # Get the offset position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def offset_position_v2
      return 60, 0 unless enemy?
      return 60, 10
    end
    # Creates the go_in animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      origin_x = sprite_position[0] + (enemy? ? FADE_AWAY_PIXEL_COUNT : -FADE_AWAY_PIXEL_COUNT)
      return Yuki::Animation.move_discreet(0.5, self, origin_x, y, *sprite_position)
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      target_x = sprite_position[0] + (enemy? ? FADE_AWAY_PIXEL_COUNT : -FADE_AWAY_PIXEL_COUNT)
      return Yuki::Animation.move_discreet(0.5, self, *sprite_position, target_x, y)
    end
  end
  # Sprite of a Trainer in the battle
  class AbilityBar < UI::SpriteStack
    include UI
    include GoingInOut
    include MultiplePosition
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the position of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :position
    # Get the bank of the pokemon shown by the sprite
    # @return [Integer]
    attr_reader :bank
    # Get the scene linked to this object
    # @return [Battle::Scene]
    attr_reader :scene
    # Get if the animation out should be not played automatically
    # @return [Boolean]
    attr_reader :no_go_out
    # Create a new Ability Bar
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param bank [Integer]
    # @param position [Integer]
    def initialize(viewport, scene, bank, position)
      super(viewport)
      @scene = scene
      @bank = bank
      @position = position
      @animation_handler = Yuki::Animation::Handler.new
      @no_go_out = false
      create_sprites
      set_position(*sprite_position)
    end
    # Update the animations
    def update
      @animation_handler.update
    end
    # Tell if the animations are done
    # @return [Boolean]
    def done?
      return @animation_handler.done?
    end
    # @!method animation_handler
    #   Get the animation handler
    #   @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    # Tell the ability to go into the scene
    # @param [Boolean] no_go_out Set if the animation out should be not played automatically
    def go_in_ability(no_go_out = false)
      delta = go_in_out_delta
      animation_handler[:in_out] ||= go_in_animation(no_go_out)
      animation_handler[:in_out].start(delta)
      @__in_out = :in
    end
    private
    # Get the base position of the Pokemon in 1v1
    # @return [Array(Integer, Integer)]
    def base_position_v1
      return 177, 145 if enemy?
      return 2, 59
    end
    alias base_position_v2 base_position_v1
    # Get the offset position of the Pokemon in 2v2+
    # @return [Array(Integer, Integer)]
    def offset_position_v2
      return 0, 38
    end
    # Creates the go_in animation
    # @param [Boolean] no_go_out Set if the out animation should be not played automatically
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation(no_go_out)
      @no_go_out = no_go_out
      origin_x = enemy? ? @viewport.rect.width : -@background.width
      animation = Yuki::Animation.move_discreet(0.1, self, origin_x, y, *sprite_position)
      return animation if @no_go_out
      animation.play_before(Yuki::Animation.wait(1.2))
      animation.play_before(go_out_animation)
      return animation
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      @no_go_out = false
      target_x = enemy? ? @viewport.rect.width : -@background.width
      return Yuki::Animation.move_discreet(0.1, self, *sprite_position, target_x, y)
    end
    def create_sprites
      create_background
      create_text
      create_icon
    end
    def create_background
      @background = add_sprite(0, 0, NO_INITIAL_IMAGE, type: Background)
    end
    def create_text
      add_text(*text_coordinates, 0, 16, :ability_name, color: 10, type: SymText)
    end
    def text_coordinates
      return enemy? ? [41, 10] : [14, 10]
    end
    def create_icon
      add_sprite(*icon_coordinates, NO_INITIAL_IMAGE, false, type: PokemonIconSprite)
    end
    def icon_coordinates
      return enemy? ? [2, 1] : [107, 1]
    end
    # Class showing the right background depending on the pokemon
    class Background < ShaderedSprite
      # Set the Pokemon Data
      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        return unless (self.visible = pokemon)
        set_bitmap(background_filename(pokemon), :interface)
      end
      # Name of the background based on the creature shown
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def background_filename(pokemon)
        return 'battle/ability_bar_enemy' if pokemon.bank != 0
        return 'battle/ability_bar_actor' if pokemon.from_party?
        return 'battle/ability_bar_ally'
      end
    end
  end
  # Sprite of a Trainer in the battle
  class ItemBar < AbilityBar
    private
    def create_text
      add_text(*text_coordinates, 0, 16, :item_name, color: 10, type: SymText)
    end
  end
  # Sprite showing a cursor (being animated)
  class Cursor < ShaderedSprite
    # Get the origin x
    attr_reader :origin_x
    # Get the origin y
    attr_reader :origin_y
    # Get the target x
    attr_reader :target_x
    # Get the target y
    attr_reader :target_y
    # Create a new cursor
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport)
      @origin_x = 0
      @origin_y = 0
      @target_x = 0
      @target_y = 0
    end
    # Register the positions so the cursor can animate itself
    def register_positions
      @origin_x = x
      @origin_y = y
      @target_x = x - 5
      @target_y = y
    end
    # Update the sprite
    def update
      @animation&.update
    end
    # Set the visibility
    # @param visible [Boolean]
    def visible=(visible)
      return if self.visible == visible
      super
      stop_animation unless visible
      start_animation if visible
    end
    alias call send
    # Stops the animation
    def stop_animation
      @animation = nil
    end
    # Create and start the cursor animation
    # @return [Yuki::Animation::TimedLoopAnimation]
    def start_animation
      root = Yuki::Animation::TimedLoopAnimation.new(1)
      root.play_before(Yuki::Animation.move(0.5, self, :origin_x, :origin_y, :target_x, :target_y))
      root.play_before(Yuki::Animation.move(0.5, self, :target_x, :target_y, :origin_x, :origin_y))
      root.resolver = self
      root.start
      return @animation = root
    end
  end
  # Class that allow a choice do be made
  #
  # The object tells the player validated on #validated? and the result is stored inside #result
  #
  # The object should be updated through #update otherwise no validation is possible
  #
  # When result was taken, the scene should call #reset to undo the validated state
  #
  # The goal of this class is to provide the cursor handling. You have to define the buttons!
  # Here's the list of methods you should define
  #   - create_buttons
  #   - create_sub_choice (add the subchoice as a stack item! & store it in @sub_choice)
  #   - validate (set the result to the proper value)
  #   - update_key_index
  #
  # To allow flexibility (sub actions) this generic choice allow you to define a "sub generic" choice
  # that only needs to responds to #update, #reset and #done? in @sub_choice
  class GenericChoice < UI::SpriteStack
    include UI
    include HideShow
    include GoingInOut
    # Offset X of the cursor compared to the element it shows
    CURSOR_OFFSET_X = -10
    # Offset Y of the cursor compared to the element it shows
    CURSOR_OFFSET_Y = 6
    # Get the animation handler
    # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
    attr_reader :animation_handler
    # Get the scene
    # @return [Battle::Scene]
    attr_reader :scene
    # Create a new GenericChoice
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    def initialize(viewport, scene)
      super(viewport, viewport.rect.width)
      @scene = scene
      @animation_handler = Yuki::Animation::Handler.new
      @index = 0
      create_sprites
      @__in_out = :out
    end
    # Update the Window cursor
    def update
      @animation_handler.update
      return unless in?
      super
      return unless done?
      return if validated?
      return validate if validating?
      return cancel if canceling?
      last_index = @index
      update_key_index
      update_mouse_index
      update_cursor if last_index != @index
    end
    # Tell if all animations are done
    # @return [Boolean]
    def done?
      return false if @sub_choice && !@sub_choice.done?
      return @animation_handler.done?
    end
    # Reset the choice
    def reset
      @result = nil
      @sub_choice&.reset
      update_cursor(true)
    end
    private
    def create_sprites
      create_buttons
      create_sub_choice
      create_cursor
    end
    def create_sub_choice
      return nil
    end
    def create_cursor
      @cursor = add_sprite(0, 0, 'battle/arrow', type: Cursor)
    end
    # Get the buttons
    # @return [Array<Sprite>]
    def buttons
      return @buttons
    end
    # Update the cursor position
    # @param silent [Boolean] if the update shouldn't make noise
    def update_cursor(silent = false)
      if silent
        @cursor.set_position(buttons[@index].x + cursor_offset_x, buttons[@index].y + cursor_offset_y)
        @cursor.register_positions
        update_button_opacity
      else
        root = (ya = Yuki::Animation).send_command_to(@cursor, :stop_animation)
        root.play_before(ya.move(0.1, @cursor, @cursor.x, @cursor.y, buttons[@index].x + cursor_offset_x, buttons[@index].y + cursor_offset_y))
        root.play_before(ya.send_command_to(@cursor, :register_positions))
        root.play_before(ya.send_command_to(@cursor, :start_animation))
        root.play_before(ya.send_command_to(self, :update_button_opacity))
        root.start
        animation_handler[:cursor] = root
        $game_system.se_play($data_system.cursor_se)
      end
      self.data = @data
    end
    # Set the button opacity
    def update_button_opacity
      buttons.each_with_index { |button, index| button.opacity = index == @index ? 255 : 179 }
    end
    # Get the cursor offset x
    # @return [Integer]
    def cursor_offset_x
      return CURSOR_OFFSET_X
    end
    # Get the cursor offset y
    # @return [Integer]
    def cursor_offset_y
      return CURSOR_OFFSET_Y
    end
    # Tell if the player is validating his choice
    def validating?
      return Input.trigger?(:A) || (Mouse.trigger?(:LEFT) && @buttons.any?(&:simple_mouse_in?))
    end
    # Tell if the player is canceling his choice
    def canceling?
      return Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
    end
    # Update the mouse index if the mouse moved
    def update_mouse_index
      return unless Mouse.moved
      @buttons.each_with_index do |sp, index|
        break(@index = index) if sp.simple_mouse_in? && sp.visible
      end
    end
    # Creates the go_in animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_in_animation
      ya = Yuki::Animation
      root = ya.move_discreet(0.1, self, @viewport.rect.width, y, 0, y)
      root.play_before(ya.send_command_to(@cursor, :register_positions))
      root.play_before(ya.send_command_to(@cursor, :start_animation))
      return root
    end
    # Creates the go_out animation
    # @return [Yuki::Animation::TimedAnimation]
    def go_out_animation
      ya = Yuki::Animation
      root = ya.send_command_to(@cursor, :stop_animation)
      root.play_before(ya.move_discreet(0.1, self, 0, y, @viewport.rect.width, y))
      return root
    end
    # Make the button bounce
    def bounce_button
      button = buttons[@index]
      ya = Yuki::Animation
      ttl = 0.05
      root = ya.move_discreet(ttl, button, button.x, button.y, button.x, button.y - 3)
      root.play_before(ya.move_discreet(ttl, button, button.x, button.y - 3, button.x, button.y))
      root.start
      animation_handler[:button_bounce] = root
    end
  end
  # Class that allow the player to make the choice of the action he want to do
  #
  # The object tells the player validated on #validated? and the result is stored inside #result
  #
  # The object should be updated through #update otherwise no validation is possible
  #
  # When result was taken, the scene should call #reset to undo the validated state
  class PlayerChoice < GenericChoice
    include UI
    include PlayerChoiceAbstraction
    # Coordinate of each buttons
    BUTTON_COORDINATE = [[172, 172], [246, 182], [162, 201], [236, 211]]
    # Create a new PlayerChoice Window
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    def initialize(viewport, scene)
      @can_switch = true
      @super_reset = true
      super(viewport, scene)
    end
    private
    def create_buttons
      @buttons = 4.times.map do |i|
        add_sprite(*BUTTON_COORDINATE[i], NO_INITIAL_IMAGE, i, type: Button)
      end
    end
    def create_sub_choice
      @sub_choice = add_sprite(0, 0, NO_INITIAL_IMAGE, @scene, self, type: SubChoice)
    end
    # Validate the player choice
    def validate
      bounce_button
      case @index
      when 0
        success = choice_attack
      when 1
        success = choice_bag
      when 2
        success = choice_pokemon
      when 3
        success = choice_flee
      else
        return
      end
      return show_switch_choice_failure unless success
      $game_system.se_play($data_system.decision_se)
    end
    # Cancel the player choice
    def cancel
      choice_cancel ? $game_system.se_play($data_system.cancel_se) : $game_system.se_play($data_system.buzzer_se)
    end
    # Update the index if a key was pressed
    def update_key_index
      if Input.trigger?(:UP)
        @index = (@index - 2).clamp(0, 3)
      else
        if Input.trigger?(:LEFT)
          @index = (@index - 1).clamp(0, 3)
        else
          if Input.trigger?(:RIGHT)
            @index = (@index + 1).clamp(0, 3)
          else
            if Input.trigger?(:DOWN)
              @index = (@index + 2).clamp(0, 3)
            end
          end
        end
      end
    end
    # Creates the show animation
    # @param target_opacity [Integer] the desired opacity (if you need non full opacity)
    # @return [Yuki::Animation::TimedAnimation]
    def show_animation(target_opacity = 255)
      animation = super
      animation.play_before(Yuki::Animation.send_command_to(self, :update_button_opacity))
      return animation
    end
    # Button of the player choice
    class Button < SpriteSheet
      # Create a new Player Choice button
      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport, 4, 1)
        self.index = index
        set_bitmap(image_filename, :interface)
      end
      alias index sx
      alias index= sx=
      # Get the filename of the sprite
      # @return [String]
      def image_filename
        return 'battle/actions_'
      end
    end
    # Element showing a special button
    class SpecialButton < UI::SpriteStack
      # Create a new special button
      # @param viewport [Viewport]
      # @param type [Symbol] :last_item or :info
      def initialize(viewport, type)
        super(viewport)
        @type = type
        create_sprites
      end
      # Update the special button content
      def refresh
        @text.text = @type == :info ? 'Information' : $bag.last_battle_item.name
      end
      private
      def create_sprites
        add_background(@type == :info ? 'battle/button_y' : 'battle/button_x')
        @text = add_text(23, 4, 0, 16, nil.to_s, color: 10)
        add_sprite(3, 3, NO_INITIAL_IMAGE, @type == :info ? :Y : :X, type: UI::KeyShortcut)
      end
    end
    # UI showing the info about the last used item
    class ItemInfo < UI::SpriteStack
      include HideShow
      # Get the animation handler
      # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
      attr_reader :animation_handler
      # Create a new Item Info box
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @animation_handler = Yuki::Animation::Handler.new
        create_sprites
      end
      # Set the data shown by the UI
      # @param item [Studio::Item]
      def data=(item)
        super
        @remaining.text = $bag.item_quantity(item.db_symbol).to_s
      end
      # Update the sprite
      def update
        @animation_handler.update
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        return @animation_handler.done?
      end
      private
      def create_sprites
        @background = add_background('battle/background')
        @item_box = add_sprite(0, 61, 'battle/last_item_box')
        @y = 61
        @item_name = add_text(14, 13, 0, 16, :exact_name, color: 0, type: UI::SymText)
        @item_icon = add_sprite(240, 2, NO_INITIAL_IMAGE, type: UI::ItemSprite)
        @remaining = add_text(287, 13, 0, 16, nil.to_s, 0)
        @description = add_text(14, 34, 284, 16, :descr, color: 0, type: UI::SymMultilineText)
        @use_text = add_text(151, 88, 0, 16, text_get(22, 0), color: 0)
        @icon = add_sprite(129, 88, NO_INITIAL_IMAGE, :X, type: UI::KeyShortcut)
      end
    end
    # UI element showing the sub_choice and interacting with the parent choice
    class SubChoice < UI::SpriteStack
      # Create the sub choice
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      # @param choice [PlayerChoice]
      def initialize(viewport, scene, choice)
        super(viewport)
        @scene = scene
        @choice = choice
        create_sprites
      end
      # Update the button
      def update
        super
        @item_info.update
        done? ? update_done : update_not_done
      end
      # Tell if the choice is done
      def done?
        return !@item_info.visible && !@bar_visibility
      end
      # Reset the sub choice
      def reset
        @item_info.visible = false
        @bar_visibility = false
        @last_item_button.refresh
        @info_button.refresh
      end
      private
      # Update the button when it's done letting the player choose
      def update_done
        action_y if Input.trigger?(:Y)
        action_x if Input.trigger?(:X) && !@bar_visibility
      end
      # Update the button when it's waiting for player actions
      def update_not_done
        return action_y if @bar_visibility && (Input.trigger?(:Y) || Input.trigger?(:A) || Input.trigger?(:B))
        return unless @item_info.done?
        action_b if Input.trigger?(:B)
        action_a if Input.trigger?(:A) || Input.trigger?(:X)
      end
      # Action triggered when pressing Y
      def action_y
        if @bar_visibility
          @choice.show
          @scene.visual.hide_info_bars(bank: 0)
        else
          @choice.hide
          @scene.visual.show_info_bars(bank: 0)
        end
        @bar_visibility = !@bar_visibility
      end
      # Action triggered when pressing X
      def action_x
        item = $bag.last_battle_item
        if item.id == 0 || !$bag.contain_item?(item.id)
          $game_system.se_play($data_system.buzzer_se)
          return
        end
        @item_info.data = item
        @item_info.show
        @choice.hide
        @scene.visual.show_info_bars(bank: 0) unless @bar_visibility
        $game_system.se_play($data_system.decision_se)
      end
      # Action triggered when pressing A
      def action_a
        item = $bag.last_battle_item
        if item.id == 0 || !$bag.contain_item?(item.id)
          $game_system.se_play($data_system.buzzer_se)
          return
        end
        $game_system.se_play($data_system.decision_se)
        @choice.use_item(item)
        @item_info.hide
        @scene.visual.hide_info_bars(bank: 0) unless @bar_visibility
        @choice.show
      end
      # Action triggered when pressing B
      def action_b
        @item_info.hide
        @choice.show
        @scene.visual.hide_info_bars(bank: 0) unless @bar_visibility
        $game_system.se_play($data_system.cancel_se)
      end
      def create_sprites
        create_special_buttons
        create_item_info
      end
      def create_special_buttons
        @last_item_button = add_sprite(12, 214, NO_INITIAL_IMAGE, :last_item, type: SpecialButton)
        @info_button = add_sprite(2, 188, NO_INITIAL_IMAGE, :info, type: SpecialButton)
      end
      def create_item_info
        @item_info = ItemInfo.new(@viewport)
        @item_info.visible = false
      end
    end
  end
  # Class that allow to choose the skill of the Pokemon
  #
  #
  # The object tells the player validated on #validated? and the result is stored inside #result
  #
  # The object should be updated through #update otherwise no validation is possible
  #
  # When result was taken, the scene should call #reset to undo the validated state
  class SkillChoice < GenericChoice
    include SkillChoiceAbstraction
    # Coordinate of each buttons
    BUTTON_COORDINATE = [[198, 124], [198, 153], [198, 182], [198, 211]]
    # Create a new SkillChoice UI
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    def initialize(viewport, scene)
      @last_indexes = {}
      @mega_enabled = false
      @super_reset = true
      super(viewport, scene)
    end
    private
    # Give the max index of the choice
    # @return [Integer]
    def max_index
      return @buttons.rindex(&:visible)
    end
    def create_buttons
      @buttons = 4.times.map do |i|
        add_sprite(*BUTTON_COORDINATE[i], NO_INITIAL_IMAGE, i, type: MoveButton)
      end
    end
    # Set the button opacity
    def update_button_opacity
      base_index = BUTTON_COORDINATE.size - buttons.count(&:visible)
      buttons.each_with_index do |button, index|
        next unless button.visible
        button.opacity = index == @index ? 255 : 204
        x, y = *BUTTON_COORDINATE[base_index + index]
        button.set_position(x + (@index == index ? -10 : 0) + @x, y + @y)
      end
    end
    # Get the cursor offset_x
    # @return [Integer]
    def cursor_offset_x
      return super if @buttons[@index].x != (BUTTON_COORDINATE[@index].first + @x)
      super - 10
    end
    def create_sub_choice
      @info = add_sprite(0, 0, NO_INITIAL_IMAGE, self, type: MoveInfo)
      @sub_choice = add_sprite(0, 0, NO_INITIAL_IMAGE, @scene, self, type: SubChoice)
    end
    # Validate the user choice
    def validate
      bounce_button
      if choice_move
        @last_indexes[pokemon] = @index
        $game_system.se_play($data_system.decision_se)
      else
        $game_system.se_play($data_system.buzzer_se)
        @scene.message_window.blocking = true
        @scene.message_window.wait_input = true
        show_move_choice_failure
      end
    end
    # Cancel the player choice
    def cancel
      choice_cancel
      $game_system.se_play($data_system.cancel_se)
    end
    # Update the index if a key was pressed
    def update_key_index
      if Input.repeat?(:UP)
        @index = (@index - 1) % @buttons.count(&:visible)
      else
        if Input.repeat?(:DOWN)
          @index = (@index + 1) % @buttons.count(&:visible)
        end
      end
    end
    # Button of a move
    class MoveButton < UI::SpriteStack
      # Get the index
      # @return [Integer]
      attr_reader :index
      # Create a new Move button
      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport)
        @index = index
        create_sprites
      end
      # Set the data
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        @data = move = pokemon.moveset[@index]
        if (self.visible = move)
          @background.sy = move.type
          @text.data = move
        end
      end
      # Make sure sprite is visible only if the data is right
      # @param visible [Boolean]
      def visible=(visible)
        super(visible && @data)
      end
      private
      def create_sprites
        @background = add_sprite(0, 0, 'battle/types', 1, each_data_type.size, type: SpriteSheet)
        @text = add_text(28, 6, 0, 16, :name, color: 10, type: UI::SymText)
      end
    end
    # Element showing the information of the current move
    class MoveInfo < UI::SpriteStack
      # Create a new MoveInfo
      # @param viewport [Viewport]
      # @param move_choice [SkillChoice]
      def initialize(viewport, move_choice)
        super(viewport)
        @move_choice = move_choice
        create_sprites
      end
      # Set the move shown by the UI
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super(move = pokemon.moveset[@move_choice.index])
        return unless move
        if move.pp == 0
          @pp_background.sy = 0
        else
          if move.pp <= move.ppmax / 2
            @pp_background.sy = 1
          else
            @pp_background.sy = 2
          end
        end
      end
      private
      def create_sprites
        @pp_background = add_sprite(122, 214, 'battle/pp_box', 1, 3, type: SpriteSheet)
        @pp_text = add_text(146, 218, 0, 16, :pp_text, 1, color: 10, type: UI::SymText)
      end
    end
    # Element showing the full description about the currently selected move
    class MoveDescription < UI::SpriteStack
      include HideShow
      # Get the animation handler
      # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
      attr_reader :animation_handler
      # Create a new MoveDescription
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @animation_handler = Yuki::Animation::Handler.new
        create_sprites
      end
      # Update the sprite
      def update
        @animation_handler.update
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        return @animation_handler.done?
      end
      private
      def create_sprites
        @background = add_background('battle/background')
        @box = add_sprite(0, 61, 'battle/description_box')
        @y = 61
        @skill_name = add_text(14, 13, 0, 16, :name, type: UI::SymText)
        @power_text = add_text(133, 13, 0, 16, text_get(27, 37), color: 10)
        @power_value = add_text(210, 13, 0, 16, :power_text, 2, type: UI::SymText)
        @accuracy_text = add_text(229, 13, 0, 16, text_get(27, 39), color: 10)
        @accuracy_value = add_text(306, 13, 0, 16, :accuracy_text, 2, type: UI::SymText)
        @description = add_text(14, 34, 284, 16, :description, color: 0, type: UI::SymMultilineText)
        @category_text = add_text(117, 88, 0, 16, text_get(27, 36), color: 10)
        @move_category = add_sprite(175, 89, NO_INITIAL_IMAGE, type: UI::CategorySprite)
      end
    end
    # Element showing a special button
    class SpecialButton < UI::SpriteStack
      # Create a new special button
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      # @param type [Symbol] :mega or :descr
      def initialize(viewport, scene, type)
        super(viewport)
        @scene = scene
        @type = type
        create_sprites
      end
      # Set the data of the button
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super
        self.visible = (@type == :descr || @scene.logic.mega_evolve.can_pokemon_mega_evolve?(pokemon)) && true
      end
      # Update the special button content
      # @param mega [Boolean]
      def refresh(mega = false)
        @text.text = @type == :descr ? 'Description' : 'Mega evolution'
        @background.set_bitmap(mega ? 'battle/button_mega_activated' : 'battle/button_mega', :interface) if @type == :mega
      end
      # Set the visibility of the button
      # @param visible [Boolean]
      def visible=(visible)
        super(visible && (@type == :descr || (@data && @scene.logic.mega_evolve.can_pokemon_mega_evolve?(@data))))
      end
      private
      def create_sprites
        @background = add_background(@type == :descr ? 'battle/button_x' : 'battle/button_mega')
        @text = add_text(23, @type == :descr ? 4 : 9, 0, 16, nil.to_s, color: 10)
        add_sprite(3, @type == :descr ? 3 : 9, NO_INITIAL_IMAGE, @type == :descr ? :X : :Y, type: UI::KeyShortcut)
      end
    end
    # UI element showing the sub_choice and interacting with the parent choice
    class SubChoice < UI::SpriteStack
      # Create the sub choice
      # @param viewport [Viewport]
      # @param scene [Battle::Scene]
      # @param choice [SkillChoice]
      def initialize(viewport, scene, choice)
        super(viewport)
        @scene = scene
        @choice = choice
        create_sprites
      end
      # Update the button
      def update
        super
        @move_description.update
        done? ? update_done : update_not_done
      end
      # Tell if the choice is done
      def done?
        return !@move_description.visible
      end
      # Reset the sub choice
      def reset
        @move_description.visible = false
        @descr_button.refresh
        @mega_button.refresh(@choice.mega_enabled)
      end
      private
      # Update the button when it's done letting the player choose
      def update_done
        action_y if Input.trigger?(:Y)
        action_x if Input.trigger?(:X)
      end
      # Update the button when it's waiting for player actions
      def update_not_done
        return unless @move_description.done?
        action_b if Input.trigger?(:B) || Input.trigger?(:X)
      end
      # Action triggered when pressing Y
      def action_y
        return $game_system.se_play($data_system.buzzer_se) unless @mega_button.visible
        @choice.mega_enabled = !@choice.mega_enabled
        @mega_button.refresh(@choice.mega_enabled)
        $game_system.se_play($data_system.decision_se)
      end
      # Action triggered when pressing X
      def action_x
        unless (move = @choice.pokemon.moveset[@choice.index])
          $game_system.se_play($data_system.buzzer_se)
          return
        end
        @move_description.data = move
        @move_description.show
        @choice.hide
        @scene.visual.show_info_bars(bank: 0)
        $game_system.se_play($data_system.decision_se)
      end
      # Action triggered when pressing B
      def action_b
        @move_description.hide
        @choice.show
        @scene.visual.hide_info_bars(bank: 0)
        $game_system.se_play($data_system.cancel_se)
      end
      def create_sprites
        create_special_buttons
        create_move_description
      end
      def create_special_buttons
        @descr_button = add_sprite(12, 214, NO_INITIAL_IMAGE, @scene, :descr, type: SpecialButton)
        @mega_button = add_sprite(2, 183, NO_INITIAL_IMAGE, @scene, :mega, type: SpecialButton)
      end
      def create_move_description
        @move_description = MoveDescription.new(@viewport)
        @move_description.visible = false
      end
    end
  end
  # UI element responsive of letting the Player choose which creature to aim
  class TargetSelection < UI::SpriteStack
    include TargetSelectionAbstraction
    # Tell if moves with no choice should not show that UI
    SKIP_NO_CHOICE_SKILL = true
    # Create a new TargetSelection
    # @param viewport [Viewport]
    # @param launcher [PFM::PokemonBattler]
    # @param move [Battle::Move]
    # @param logic [Battle::Logic]
    def initialize(viewport, launcher, move, logic)
      super(viewport)
      initialize_data(launcher, move, logic)
      @animation_handler = Yuki::Animation::Handler.new
      create_sprites
      update_cursor(true) if @allow_selection
    end
    # Update the Window cursor
    def update
      super
      return @animation_handler.update unless @animation_handler.done?
      return if validated?
      return validate if Input.trigger?(:A) || Mouse.trigger?(:LEFT)
      return cancel if Input.trigger?(:B) || Mouse.trigger?(:RIGHT)
      return unless @allow_selection
      last_index = @index
      update_key_index
      update_mouse_index
      update_cursor if last_index != @index && @allow_selection
    end
    private
    def update_key_index
      if Input.repeat?(:UP)
        @index = (@index - @row_size) % @buttons.size
      else
        if Input.repeat?(:RIGHT)
          @index = (@index + 1) % @buttons.size
        else
          if Input.repeat?(:LEFT)
            @index = (@index - 1) % @buttons.size
          else
            if Input.repeat?(:DOWN)
              @index = (@index + @row_size) % @buttons.size
            end
          end
        end
      end
    end
    def update_mouse_index
      return unless Mouse.moved
      @buttons.each_with_index do |button, index|
        break(@index = index) if button.simple_mouse_in?
      end
    end
    def create_sprites
      add_background('battle/background')
      @buttons = @mons.map.with_index do |pokemon, index|
        push_sprite(Button.new(@viewport, index, @row_size, pokemon, @launcher, @move, @targets.include?(pokemon)))
      end
    end
    # Validate the player choice
    def validate
      if choose_target
        $game_system.se_play($data_system.decision_se)
      else
        $game_system.se_play($data_system.buzzer_se)
      end
    end
    # Cancel the player choice
    def cancel
      choice_cancel
      $game_system.se_play($data_system.cancel_se)
    end
    # Update the cursor position
    # @param silent [Boolean] if the cursor se should not be played
    def update_cursor(silent = false)
      return finalize_cursor_update(false) if silent
      create_cursor_move_animation
    end
    # Create the cursor move animation
    def create_cursor_move_animation
      cursor = @buttons.find(&:selected).cursor
      selected_cursor = @buttons[@index].cursor
      animation = Yuki::Animation.move(0.2, cursor, cursor.x, cursor.y, selected_cursor.origin_x, selected_cursor.origin_y)
      animation.play_before(Yuki::Animation.send_command_to(self, :finalize_cursor_update, true))
      animation.start
      @animation_handler[:cursor_move] = animation
    end
    # Finalize the cursor update
    def finalize_cursor_update(play_sound)
      @buttons.each_with_index { |button, index| button.selected = @index == index }
      $game_system.se_play($data_system.cursor_se) if play_sound
    end
    class << self
      # Tell if the UI can be shown or not
      # @param move [Battle::Move]
      # @param pokemon [PFM::PokemonBattler]
      # @param logic [Battle::Logic]
      # @return [Boolean]
      def cannot_show?(move, pokemon, logic)
        (move.no_choice_skill? && SKIP_NO_CHOICE_SKILL) || move.battler_targets(pokemon, logic).empty?
      end
    end
    # Button shown by the UI to get what's selected
    class Button < UI::SpriteStack
      # Get the selected state of the button
      # @return [Boolean]
      attr_reader :selected
      # Get the cursor
      # @return [Cursor]
      attr_reader :cursor
      # Create a new button
      # @param viewport [Viewport]
      # @param index [Integer]
      # @param row_size [Integer]
      # @param pokemon [PFM::PokemonBattler]
      # @param launcher [PFM::PokemonBattler]
      # @param move [Battle::Move]
      # @param is_target [Boolean]
      def initialize(viewport, index, row_size, pokemon, launcher, move, is_target)
        super(viewport, *process_coordinates(index, row_size))
        create_sprites
        @move = move
        @selected = is_target
        @is_target = is_target
        @launcher = launcher
        self.data = pokemon
      end
      # Set the selected state about the button
      # @param selected [Boolean]
      def selected=(selected)
        @selected = selected
        @cursor.set_position(@x - 10, @y + 12)
        @cursor.register_positions
        @cursor.visible = selected
      end
      # Set the Pokemon shown
      # @param pokemon [PFM::PokemonBattler]
      def data=(pokemon)
        super(pokemon)
        self.visible = pokemon&.alive?
        unless visible
          @background.visible = true
          return
        end
        @gender.x = @name.x + @name.real_width + 5
        @icon.opacity = @is_target ? 255 : 128
        @efficiency_text.text = load_efficiency_text(pokemon)
        @efficiency_text.visible = @is_target
        self.selected = @selected
      end
      private
      def create_sprites
        @background = add_background(NO_INITIAL_IMAGE, type: Background)
        @icon = add_sprite(1, 1, NO_INITIAL_IMAGE, false, type: UI::PokemonIconSprite)
        @name = add_text(41, 16, 0, 16, :name, color: 10, type: UI::SymText)
        @gender = add_sprite(5, 16, NO_INITIAL_IMAGE, type: UI::GenderSprite)
        @efficiency_text = add_text(18, 35, 102, 16, nil.to_s, 1, color: 10)
        @cursor = add_sprite(-10, 12, 'battle/arrow', type: Cursor)
        @cursor.z = 1
        @cursor.register_positions
        @cursor.visible = false
      end
      # @param pokemon [PFM::PokemonBattler]
      # @return [String]
      def load_efficiency_text(pokemon)
        efficiency = @move.type_modifier(@launcher, pokemon)
        return ext_text(8999, 23) if efficiency >= 2
        return ext_text(8999, 24) if efficiency == 0
        return ext_text(8999, 25) if efficiency < 1
        return ext_text(8999, 22)
      end
      def process_coordinates(index, row_size)
        x = index % row_size
        y = index / row_size
        return (29 - 10 * y + 141 * x), 65 + y * 58
      end
      # Background of the target
      class Background < Sprite
        # Set the Pokemon shown
        # @param pokemon [PFM::PokemonBattler]
        def data=(pokemon)
          return unless pokemon
          set_bitmap(image_name(pokemon), :interface)
        end
        private
        # Get the image that should be shown by the UI
        # @param pokemon [PFM::PokemonBattler]
        def image_name(pokemon)
          return 'battle/target_bar_enemy' if pokemon.bank != 0
          return 'battle/target_bar_ally' unless pokemon.from_party?
          return 'battle/target_bar_player'
        end
      end
    end
  end
  # UI element showing the exp distribution
  class ExpDistribution < UI::SpriteStack
    include UI
    include ExpDistributionAbstraction
    # Create a new exp distribution
    # @param viewport [Viewport]
    # @param scene [Battle::Scene]
    # @param exp_data [Hash{ PFM::PokemonBattler => Integer }] info about experience each pokemon should receive
    def initialize(viewport, scene, exp_data)
      super(viewport)
      @scene = scene
      @pokemon = find_expable_pokemon
      @originals = map_to_original_with_forms(@pokemon)
      @exp_data = exp_data.dup
      @done = false
      create_sprites
    end
    # Update the scene
    def update
      if @statistics
        update_statistics
      else
        @animation.update
      end
      @bars.each(&:update)
    end
    # Test if the scene is done distributing experience
    # @return [Boolean]
    def done?
      return @done
    end
    # Start the exp distribution animation
    def start_animation
      animations = @exp_data.map do |pokemon, exp|
        create_exp_animation_for(pokemon, exp)
      end.compact
      return restore_form_to_originals.then {align_exp(@pokemon) } if (@done = animations.empty?)
      @animation = Yuki::Animation.se_play('exp_sound')
      animations.each { |(animation, _)| @animation.parallel_add(animation) }
      @animation.play_before(Yuki::Animation.send_command_to(Audio, :se_stop))
      animations.each do |(_, pokemon)|
        @animation.play_before(Yuki::Animation.send_command_to(self, :show_level_up, pokemon)) if pokemon
      end
      @animation.play_before(Yuki::Animation.send_command_to(self, :start_animation))
      @animation.start
      @animation.update
    end
    private
    def update_statistics
      @bars.each(&:update)
      return if $game_temp.message_window_showing
      return unless Input.trigger?(:A) || Mouse.trigger?(:LEFT)
      @statistics.go_out
      @scene.visual.animations << @statistics
      @scene.visual.wait_for_animation
      @bars.each { |bar| bar.leveling_up = false }
      @statistics.dispose
      @statistics = nil
    end
    def create_sprites
      push_sprite(BlurScreenshot.new(@viewport, @scene))
      @bars = @pokemon.map.with_index do |pokemon, index|
        push_sprite(PokemonInfo.new(@viewport, index, @originals[index], @exp_data[pokemon].to_i))
      end
    end
    # Function that shows level up of a Pokemon
    # @param pokemon [PFM::PokemonBattler]
    def show_level_up(pokemon)
      super(pokemon) do |original, list|
        Audio.me_play('audio/me/rosa_levelup')
        index = @pokemon.index(pokemon)
        @bars[index].leveling_up = true if index
        @statistics = Statistics.new(@viewport, original, list[0], list[1])
        @statistics.go_in
        @scene.visual.animations << @statistics
        @bars[index].data = original if index
      end
      @scene.visual.scene_update_proc {update_statistics } while @statistics
    end
    # Function that create an exp animation for a specific pokemon
    # @param pokemon [PFM::PokemonBattler]
    # @param exp [Integer] total exp he should receive
    # @return [Array(Yuki::Animation::TimedAnimation, PFM::PokemonBattler), nil]
    def create_exp_animation_for(pokemon, exp)
      original = pokemon.original
      return nil if exp <= 0 || original.max_level == original.level
      target_exp = original.exp + exp
      next_exp_value = original.exp_lvl.clamp(0, target_exp)
      @exp_data[pokemon] -= next_exp_value - original.exp
      original_exp = original.exp
      exp_rate = original.exp_rate
      original.exp = next_exp_value
      time_to_process = ((original.exp_rate - exp_rate) * 2).clamp(0, (next_exp_value - original_exp).abs / 60.0)
      animation = Yuki::Animation::DiscreetAnimation.new(time_to_process, original, :exp=, original_exp, next_exp_value)
      return [animation, original.exp == original.exp_lvl ? pokemon : nil]
    end
    # UI element showing the basic information
    class PokemonInfo < UI::SpriteStack
      # The information of the Exp Bar
      EXP_BAR_INFO = [79, 2, 0, 0, 1]
      # Tell if the pokemon is leveling up or not
      # @return [Boolean]
      attr_reader :leveling_up
      # Coordinate where the UI element is supposed to show
      COORDINATES = [[17, 10], [162, 20], [17, 50], [162, 60], [17, 90], [162, 100]]
      # Create a new Pokemon Info
      # @param viewport [Viewport]
      # @param index [Integer]
      # @param pokemon [PFM::Pokemon]
      # @param exp_received [Integer]
      def initialize(viewport, index, pokemon, exp_received)
        super(viewport, *COORDINATES[index])
        @exp_received = exp_received
        @leveling_up = false
        create_sprites
        create_animation
        self.data = pokemon
      end
      # Update the animation
      def update
        @animation.update
        @exp_bar.data = @pokemon
      end
      # Set the data shown by the UI element
      # @param pokemon [PFM::Pokemon]
      def data=(pokemon)
        @pokemon = pokemon
        super(pokemon)
        @gender.x = @x + 42 + @name.real_width
        @level_up_arrow.visible = leveling_up
      end
      # Set if the Pokemon is leveling up or not
      # @param leveling_up [Boolean]
      def leveling_up=(leveling_up)
        @leveling_up = leveling_up
        self.data = @pokemon
      end
      private
      def create_sprites
        @background = add_background('battle/expbar')
        @name = add_text(37, 3, 0, 16, :given_name, color: 10, type: UI::SymText)
        @gender = add_sprite(5, 6, NO_INITIAL_IMAGE, type: UI::GenderSprite)
        with_font(20) do
          @level = add_text(37, 18, 0, 13, :level_text2, color: 10, type: UI::SymText)
          @exp_obtained = add_text(116, 18, 0, 13, "+#{@exp_received}", 2, color: 10) if @exp_received > 0
        end
        create_exp_bar
        @level_up_arrow = add_sprite(124, 7, 'battle/exp_level_up', 3, 1, type: SpriteSheet)
        @pokemon_icon = add_sprite(1, 2, NO_INITIAL_IMAGE, false, type: UI::PokemonIconSprite)
      end
      def create_exp_bar
        @exp_bar = push_sprite UI::Bar.new(@viewport, @x + 37, @y + 29, RPG::Cache.interface('battle/bars_exp_distrib'), *EXP_BAR_INFO)
        @exp_bar.data_source = :exp_rate
      end
      def create_animation
        animation = Yuki::Animation::TimedLoopAnimation.new(1)
        animation.play_before(Yuki::Animation::DiscreetAnimation.new(1, @level_up_arrow, :sx=, 0, 2))
        animation.start
        @animation = animation
      end
    end
    # UI element showing the new statistics
    class Statistics < UI::SpriteStack
      include GoingInOut
      # Get the animation handler
      # @return [Yuki::Animation::Handler{ Symbol => Yuki::Animation::TimedAnimation}]
      attr_reader :animation_handler
      # Position of the sprite when it's in
      IN_POSITION = [0, 144]
      # Create a new Statistics UI
      # @param viewport [Viewport]
      # @param pokemon [PFM::Pokemon] Pokemon that is currently leveling up
      # @param list0 [Array<Integer>] old basis stats
      # @param list1 [Array<Integer>] new basis stats
      def initialize(viewport, pokemon, list0, list1)
        super(viewport, 0, viewport.rect.height)
        @animation_handler = Yuki::Animation::Handler.new
        @list0 = list0
        @list1 = list1
        create_sprites
        @__in_out = :out
        self.data = pokemon
      end
      # Tell if the animation is done
      # @return [Boolean]
      def done?
        @animation_handler.done?
      end
      # Update the animation
      def update
        @animation_handler.update
      end
      private
      def create_sprites
        @background = add_background('battle/exp_stats_bar')
        @name = add_text(160, 9, 0, 16, :given_name, 1, color: 0, type: UI::SymText)
        @gender = add_sprite(220, 11, NO_INITIAL_IMAGE, type: UI::GenderSprite)
        create_stats_texts
      end
      # Create all the stats texts
      def create_stats_texts
        6.times do |i|
          ox = 156 * (i / 3)
          oy = 19 * (i % 3)
          add_text(13 + ox, 31 + oy, 0, 16, text_get(22, 121 + i), color: 10)
          add_text(130 + ox, 31 + oy, 0, 16, @list1[i].to_s, 2, color: 0)
          add_text(139 + ox, 31 + oy, 0, 16, "+#{@list1[i] - @list0[i]}", color: 16)
        end
      end
      # Creates the go_in animation
      # @return [Yuki::Animation::TimedAnimation]
      def go_in_animation
        return Yuki::Animation.move_discreet(0.1, self, x, @viewport.rect.height, *IN_POSITION)
      end
      # Creates the go_out animation
      # @return [Yuki::Animation::TimedAnimation]
      def go_out_animation
        return Yuki::Animation.move_discreet(0.1, self, *IN_POSITION, x, @viewport.rect.height)
      end
    end
  end
end
