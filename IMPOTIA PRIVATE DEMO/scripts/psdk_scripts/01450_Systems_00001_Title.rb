module Configs
  # Definition of the scene title config
  class SceneTitleConfig
    # Get the intro movie map id
    # @return [Integer] 0 = No intro movie
    attr_accessor :intro_movie_map_id
    # Get the duration of the title music before it restarts
    # @return [Integer] duration in pcm samples
    attr_accessor :bgm_duration
    # Get the name of the bgm to play
    # @return [String]
    attr_accessor :bgm_name
    # Get the information if the language selection is enabled or not
    # @return [Boolean]
    attr_accessor :language_selection_enabled
    # Get the additional splash played after the PSDK splash
    # @return [Array<String>]
    attr_accessor :additional_splashes
    # Get the duration the controls has to wait before showing
    # @return [Float]
    attr_accessor :control_wait
  end
  module Project
    # Allow SceneTitleConfig from being accessed from Project::SceneTitle
    SceneTitle = SceneTitleConfig
  end
  register(:scene_title_config, 'scene_title_config', :json, true, SceneTitleConfig)
end
# Scene responsive of showing the title of the game
#
# It's being the first scene called when starting game without specific arguments.
# It's also the scene that gets called when the game soft resets.
#
# @note Due to how Scene_Title is designed, create_graphics will not be overloaded so the default viewport will be created
#       and other required graphics will be initialized / disposed when needed
class Scene_Title < GamePlay::BaseCleanUpdate
  # Create a new Scene_Title
  def initialize
    data_load
    super(true)
    @current_state = :psdk_splash_initialize
    @current_state = :action_play_game if debug? && ARGV.include?('skip_title')
    @splash_counter = 0
    @bgm_duration = Configs.scene_title_config.bgm_duration
    @movie_map_id = Configs.scene_title_config.intro_movie_map_id || 0
    Audio.bgm_stop
  end
  # Update the input of the scene
  def update_inputs
    return false unless !@splash_animation || @splash_animation.done?
    return false unless !@title_controls || @title_controls.done?
    if @current_state != :title_animation
      send(@current_state)
      return false
    else
      if @bgm_duration && Audio.bgm_position >= @bgm_duration
        @running = false
        $scene = Scene_Title.new
        return false
      end
    end
    if Input.trigger?(:A)
      action_a
    else
      if Input.trigger?(:UP)
        action_up
      else
        if Input.trigger?(:DOWN)
          action_down
        else
          return true
        end
      end
    end
    return false
  end
  # Update the graphics
  def update_graphics
    @splash_animation&.update
    @title_controls&.update
  end
  # Update the mouse
  def update_mouse(*)
    return unless @title_controls
    if @title_controls.index == 1 && @title_controls.play_bg.mouse_in?
      play_cursor_se
      @title_controls.index = 0
    else
      if @title_controls.index == 0 && @title_controls.credit_bg.mouse_in?
        play_cursor_se
        @title_controls.index = 1
      else
        if Mouse.trigger?(:LEFT)
          action_a if @title_controls.play_bg.mouse_in? || @title_controls.credit_bg.mouse_in?
        end
      end
    end
  end
  private
  # Load the RMXP Data
  def data_load
    unless $data_actors || @all_load_data_threads
      thread_load('Data/Actors.rxdata') { |d| $data_actors = d }
      thread_load('Data/Classes.rxdata', clean: false) { |d| $data_classes = d }
      thread_load('Data/Enemies.rxdata') { |d| $data_enemies = d }
      thread_load('Data/Troops.rxdata') { |d| $data_troops = d }
      thread_load('Data/Tilesets.rxdata') { |d| $data_tilesets = d }
      thread_load('Data/CommonEvents.rxdata') { |d| $data_common_events = d }
      thread_load('Data/System.rxdata', clean: false) { |d| $data_system = d }
    end
    $game_system = Game_System.new
    $game_temp = Game_Temp.new
  end
  # Function that loads a data through a thread
  # @param filename [String] name of the file to load
  # @param clean [Boolean] if the utf-8 objects names should be cleaned
  # @yieldparam data [Object] the loaded data
  def thread_load(filename, clean: true)
    @all_load_data_threads ||= []
    @all_load_data_threads << Thread.new do
      Thread.current.abort_on_exception = true
      data = load_data(filename)
      data = _clean_name_utf8(data) if clean
      yield(data)
    end
  end
  # Function that tells if all data was loaded
  # @return [Boolean]
  def all_data_loaded?
    return $data_actors unless @all_load_data_threads
    return @all_load_data_threads.none?(&:status)
  end
  public
  private
  def action_a
    if @title_controls.index == 0
      Graphics.update until all_data_loaded?
      action_play_game
    else
      action_show_credits
    end
  end
  def action_up
    return play_buzzer_se if @title_controls.index == 0
    play_cursor_se
    @title_controls.index = 0
  end
  def action_down
    return play_buzzer_se if @title_controls.index == 1
    play_cursor_se
    @title_controls.index = 1
  end
  def action_play_game
    Yuki::MapLinker.reset
    Audio.bgm_stop
    $scene = GamePlay::Load.new
    if $scene.should_make_new_game?
      self.visible = false
      $scene.create_new_game
    end
    @running = false
  end
  def action_show_credits
    $scene = GamePlay::CreditScene.new
    @running = false
  end
  public
  private
  # Show the intro movie map
  # @param map_id [Integer] ID of the map
  def start_intro_movie(map_id)
    Graphics.update until all_data_loaded?
    Graphics.freeze
    @viewport.visible = false
    $tester = true
    $tester = nil
    Yuki::MapLinker.reset
    PFM::GameState.new(false, PFM.game_state&.options&.language || Configs.language.default_language_code).expand_global_var
    $game_party.setup_starting_members
    $game_map.setup(map_id)
    $game_player.moveto(Yuki::MapLinker.get_OffsetX, Yuki::MapLinker.get_OffsetY)
    $game_player.refresh
    $game_map.autoplay
    scene = $scene
    $scene = Scene_Map.new
    $scene.main
    $scene = scene
    GamePlay::Save.load
    @viewport.visible = true
    Graphics.transition
  end
  public
  private
  # Function that creates the PSDK splash
  def psdk_splash_initialize
    @background = Sprite.new(@viewport)
    @background.opacity = 0
    @background.load('splash', :title)
    @current_state = :title_animation
    create_splash_animation('nintendo')
  end
  # Function that initialize the next splash
  def next_splash_initialize
    @background.bitmap.dispose unless @background.bitmap.disposed?
    splashes = Configs.scene_title_config.additional_splashes
    if splashes.size > @splash_counter
      @background.load(splashes[@splash_counter], :title)
      @splash_counter += 1
      create_splash_animation
    else
      @current_state = :title_animation
      create_title_animation
    end
  end
  # Function that create a splash animation
  # @param se_filename [String] filename of the SE to play
  def create_splash_animation(se_filename = nil)
    if se_filename
      @splash_animation = Yuki::Animation.se_play(se_filename)
      @splash_animation.play_before(Yuki::Animation.opacity_change(0.4, @background, 0, 255))
    else
      @splash_animation = Yuki::Animation.opacity_change(0.4, @background, 0, 255)
    end
    @splash_animation.play_before(Yuki::Animation.wait(1.0))
    @splash_animation.play_before(Yuki::Animation.opacity_change(0.4, @background, 255, 0))
    @splash_animation.play_before(Yuki::Animation.send_command_to(self, :next_splash_initialize))
    @splash_animation.start
  end
  public
  private
  # Create the title animation
  def create_title_animation
    checkup_language
    GamePlay::Save.save_index = Configs.save_config.single_save? ? 0 : 1
    Studio::Text.load unless GamePlay::Save.load
    start_intro_movie(@movie_map_id) if @movie_map_id > 0
    create_title_graphics
    Audio.bgm_play(*Configs.scene_title_config.bgm_name)
  end
  # Function that create the title graphics
  def create_title_graphics
    create_title_background
    create_title_title
    create_title_controls
  end
  def create_title_background
    @background.load('background', :title)
    @background.opacity = 255
  end
  def create_title_title
    @title = Sprite.new(@viewport)
    @title.z = 200
    @title.load('title', :title)
  end
  def create_title_controls
    @title_controls = UI::TitleControls.new(@viewport)
  end
  def checkup_language
    return if Configs.language.choosable_language_code.empty? || !Configs.scene_title_config.language_selection_enabled
    base_filename = GamePlay::Save.save_filename
    call_scene(GamePlay::Language_Choice) if Dir["#{base_filename}*"].reject { |i| i.end_with?('.bak') }.empty?
  end
end
module UI
  # UI component showing the controls of the title screen (Play / Credits)
  class TitleControls < SpriteStack
    # Get the index of the selection
    # @return [Integer]
    attr_reader :index
    # Get the play bg button
    # @return [Sprite]
    attr_reader :play_bg
    # Get the credit bg button
    # @return [Sprite]
    attr_reader :credit_bg
    def initialize(viewport)
      super(viewport, 0, 240, default_cache: :title)
      create_sprites
      self.index = 0
      @wait_duration = Configs.scene_title_config.control_wait || 0.5
      create_animation
    end
    # Set the index of the selection
    # @param index [Integer]
    def index=(index)
      @index = index
      @play_bg.visible = index == 0
      @credit_bg.visible = index == 1
    end
    # Update the animation
    def update
      super
      @animation.update
    end
    # Tell if the controls are done transitionning
    # @return [Boolean]
    def done?
      @animation.done?
    end
    private
    # Create all the necessary sprites for the title controls
    def create_sprites
      create_button_shader
      create_play_bg
      create_credits_bg
      create_play_text
      create_credit_text
    end
    # Function that creates the button shader
    def create_button_shader
      @shader = Shader.create(:title_button)
      @shader_time_update = proc { |t| @shader.set_float_uniform('t', t) }
    end
    def create_play_bg
      @play_bg = add_sprite(160, 168, 'shader_bg')
      @play_bg.ox = @play_bg.width / 2
      @play_bg.shader = @shader
    end
    def create_credits_bg
      @credit_bg = add_sprite(160, 192, 'shader_bg')
      @credit_bg.ox = @credit_bg.width / 2
      @credit_bg.shader = @shader
    end
    def create_play_text
      @font_id = 20
      add_text(160, 170, 0, 24, text_get(32, 77).capitalize, 1, 1, color: 9)
    end
    def create_credit_text
      @font_id = 20
      add_text(160, 194, 0, 24, 'Credits', 1, 1, color: 9)
    end
    # Create the animation
    def create_animation
      @animation = Yuki::Animation.wait(@wait_duration)
      @animation.play_before(Yuki::Animation.move_discreet(0.5, self, 0, 240, 0, 0))
      @animation.play_before(Yuki::Animation.send_command_to(self, :create_loop_animation))
      @animation.start
    end
    # Create the loop animation
    def create_loop_animation
      @animation = Yuki::Animation::TimedLoopAnimation.new(2)
      wait = Yuki::Animation.wait(2)
      shader_animation = Yuki::Animation::ScalarAnimation.new(2, @shader_time_update, :call, 0, 1)
      wait.parallel_add(shader_animation)
      @animation.play_before(wait)
      @animation.start
    end
  end
end
Graphics.on_start do
  Shader.register(:title_button, 'graphics/shaders/title_button.frag')
end
