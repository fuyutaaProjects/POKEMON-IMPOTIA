# Class describing the PSDK Config
module ScriptLoader
  # PSDK config info so the game knows what's the context at start
  class PSDKConfig
    # @return [Integer] the window scale
    attr_reader :window_scale
    # @return [Boolean] if the game runs in fullscreen
    attr_reader :running_in_full_screen
    # @return [Boolean] if the game runs in VSYNC
    attr_reader :vsync_enabled
    # @return [Integer] OffsetX of all the viewports
    attr_reader :viewport_offset_x
    # @return [Integer] OffsetY of all the viewports
    attr_reader :viewport_offset_y
    # Tell if the game is in Release mode
    # @return [Boolean]
    def release?
      @release = File.exist?('Data/Scripts.dat') if @release.nil?
      return @release
    end
    # Tell if the game is in Debug mode
    # @return [Boolean]
    def debug?
      @debug = !release? && ARGV.include?('debug') if @debug.nil?
      return @debug
    end
    # Function that choose the best resolution
    # @return [Array<Integer>]
    def choose_best_resolution
      @window_scale = Configs.display.window_scale
      @vsync_enabled = Configs.graphic.vsync_enabled
      @running_in_full_screen = Configs.display.is_fullscreen
      fix_scale
      fix_vsync
      fix_full_screen
      return editors_resolution if running_editor?
      native = [Configs.display.game_resolution.x, Configs.display.game_resolution.y]
      @viewport_offset_x = 0
      @viewport_offset_y = 0
      if @running_in_full_screen
        desired = [native.first * @window_scale, native.last * @window_scale].map(&:round)
        all_res = LiteRGSS::DisplayWindow.list_resolutions
        return native if all_res.include?(desired)
        if all_res.include?(native)
          @window_scale = 1
          return native
        end
        return find_best_matching_resolution(native, desired, all_res)
      else
        return native
      end
    end
    private
    # Function that fix the scale
    def fix_scale
      @window_scale = (PARGV[:scale] || @window_scale).to_i
      @window_scale = 2 if @window_scale < 0.1
      if PARGV[:scale] && ARGV.include?(new_opt = "--scale=#{PARGV[:scale].to_i}")
        PARGV.update_game_opts(new_opt)
      end
    end
    # Function that fix the fullscreen
    def fix_full_screen
      param = PARGV[:fullscreen] || PSDK_PLATFORM == :android
      @running_in_full_screen = (param.nil? ? @running_in_full_screen : param) == true
    end
    # Function that fix the vsync param
    def fix_vsync
      @vsync_enabled = !PARGV[:"no-vsync"]
    end
    # Return the editor resolution
    # @return [Array<Integer>]
    def editors_resolution
      @window_scale = 1
      @running_in_full_screen = false
      @viewport_offset_x = 0
      @viewport_offset_y = 0
      return [640, 480]
    end
    # Tell if the game is running an editor
    def running_editor?
      return PARGV[:tags] || PARGV[:worldmap]
    end
    # Function that tries to find the best resolution in all_res according to native & desired
    # @param native [Array<Integer>] native screen resolution
    # @param desired [Array<Integer>] desired screen resolution
    # @param all_res [Array<Array>] all the compatible resolution
    # @return [Array<Integer>]
    def find_best_matching_resolution(native, desired, all_res)
      current_ratio = LiteRGSS::DisplayWindow.desktop_width / LiteRGSS::DisplayWindow.desktop_height >= 1 ? 1 : -1
      all_res = all_res.select { |res| ((res.first / res.last) >= 1 ? 1 : -1) == current_ratio }.sort
      unless (desired_res = all_res.find { |res| res.first >= desired.first && res.last >= desired.last })
        @window_scale = 1
        unless (desired_res = all_res.find { |res| res.first >= native.first && res.last >= native.last })
          desired_res = all_res.last
        end
      end
      @viewport_offset_x = ((desired_res.first / @window_scale - native.first) / 2).round
      @viewport_offset_y = ((desired_res.last / @window_scale - native.last) / 2).round
      return [desired_res.first / @window_scale, desired_res.last / @window_scale].map(&:round)
    end
  end
end
# Constant containing all the PSDK Config
PSDK_CONFIG = ScriptLoader::PSDKConfig.allocate
# Ruby Object class
class Object
  private
  # Is the game in debug ?
  # @return [Boolean]
  def debug?
    PSDK_CONFIG.debug?
  end
end
$DEBUG = false
# Module responsive of savely execute piece of code at the end of the whole script loading
module SafeExec
  # Safe constants to evaluate when everything is loaded
  SAFE_CONSTANTS = {}
  # List of safe piece of code to execute
  SAFE_CODE = {}
  module_function
  # Load the safe constants/codes and clear the hash
  def load
    SAFE_CONSTANTS.each_value do |consts|
      consts.each_value(&:call)
    end
    SAFE_CONSTANTS.clear
    SAFE_CODE.each_value do |codes|
      codes.each_value(&:call)
    end
    SAFE_CODE.clear
  end
end
# Safely define a constant (make its value valid once every scripts got loaded)
# @param name [Symbol] name of the constant in the class where it should be defined
# @param value [Proc] code to execute to give the proper constant value
# @note This is not suited for cyclic redundancy (C::A = D::B; D::B = C::E). The value should never be passed as &block.
#   The final value of the constant can be changed by calling safe_const again.
# @example Defining a constant dependant of a class that is not already loaded :
#   class MyClass
#     MY_CONST = safe_const(:MY_CONST) { DependingOnClass::OTHER_CONST * 3 }
#   end
#   # This prevents uninitialized constant DependingOnClass
def safe_const(name, &value)
  receiver = value.binding.receiver
  receiver = Object if receiver.class == Object
  return (SafeExec::SAFE_CONSTANTS[receiver] ||= {})[name] = proc do
    receiver.instance_eval do
      remove_const name
      const_set name, yield
    end
  end
end
# Safely execute a piece of code
# @param name [String] Name of the code if it needs to be removed
# @param value [Proc] code to execute
def safe_code(name, &value)
  receiver = value.binding.receiver
  receiver = Object if receiver.class == Object
  return (SafeExec::SAFE_CODE[receiver] ||= {})[name] = value
end
# Module responsive of adding the Hook functionality to a class and its childs
#
# How to use it:
#   # 1. Include the Hooks module to your class so exec_hooks become visible (and it's possible to register a hook)
#   include Hooks
#
#   # 2. Make a method that supports hooks
#   def my_method(params)
#     exec_hooks(NameOfTheClass, :name_of_prehook, binding) # Not mandatory
#     # do some stuff
#     exec_hooks(NameOfTheClass, :name_of_posthook, binding) # Not mandatory
#     return normal_return
#   rescue Hooks::ForceReturn => e
#     return e.data # What the hooks forced to return
#   end
#
#   # 3. To register a hook call the function from Hooks
#   Hooks.register(NameOfTheClass, :name_of_the_hook, 'Reason so you can delete it') do |hook_binding|
#     # Do something with self (object that called the hook) and hook_binding current binding
#   end
module Hooks
  # Exception that help managing overwritten return from Hooks
  class ForceReturn < StandardError
    # Data that should be returned
    attr_accessor :data
    # Reason that has forced the return
    attr_accessor :reason
    # Name of the hook that forced the return
    attr_accessor :hook_name
    # Constant value for hooks functionality
    CONST = new('Return forced')
  end
  # Extension adding reason parameter to blocks
  module Reason
    # Get the reason
    # @return [String]
    def reason
      @reason
    end
    # Set the reason
    # @param reason [String]
    def reason=(reason)
      @reason = reason
    end
  end
  # Function that execute the hooks
  # @param klass [Class] class containing the hook information
  # @param name [Symbol] name of the hook list
  # @param method_binding [Binding] binding of the method so the hook can modify locals
  # @raise [ForceReturn]
  def exec_hooks(klass, name, method_binding)
    hooks = klass.instance_variable_get(:@__hooks)&.[](name)
    ForceReturn::CONST.hook_name = name
    hooks&.each do |hook|
      ForceReturn::CONST.reason = hook.reason
      instance_exec(method_binding, &hook)
    end
  end
  # Function that force the return from the hook
  # @param object [Object] object to return
  def force_return(object)
    ForceReturn::CONST.data = object
    raise ForceReturn::CONST
  end
  class << self
    # Function that register a hook
    # @param klass [Class] class containing the hook information
    # @param name [Symbol] name of the hook list
    # @param reason [String] reason for the hook (so we can remove it)
    # @param block [Proc] actuall hook
    # @yield [hook_binding] hook called when requested
    # @yieldparam hook_binding [Binding] binding from the calling method
    def register(klass, name, reason = nil, &block)
      log_error(format('A proc named %<name>s was defined without reason in %<class>s', name: name, class: klass)) unless reason
      hooks = (klass.instance_variable_get(:@__hooks)[name] ||= [])
      hooks << block
      block.extend(Reason)
      block.reason = reason || 'None'
    rescue NoMethodError
      raise 'Hooks was not included to that class!'
    end
    # Function that removes a hook with a reason
    # @param klass [Class] class containing the hook information
    # @param name [Symbol] name of the hook list
    # @param reason [String] reason for the hook
    def remove(klass, name, reason = 'None')
      hooks = klass.instance_variable_get(:@__hooks)&.[](name)
      hooks&.reject! { |hook| hook.reason == reason }
    end
    # Function that removes a hook with a reason
    # @param klass [Class] class containing the hook information
    # @param reason [String] reason for the hook
    def remove_without_name(klass, reason = 'None')
      klass.instance_variable_get(:@__hooks)&.each_value do |hooks|
        hooks&.reject! { |hook| hook.reason == reason }
      end
    end
    # Function called when Hooks is included
    # @param klass [Class] klass receiving the hooks
    def included(klass)
      klass.instance_variable_set(:@__hooks, {})
    end
  end
end
# Module responsive of giving access to various configuration contained into Data/configs
#
# @example How to create a basic configuration
#   module Configs
#     class MyConfigDescription
#       # Define attributes etc...
#       def initialize # <= Configs will call this without argument so you can set default value if file does not exist
#       end
#     end
#     # @!method self.my_config_accessor
#     #   @return [MyConfigDescription]
#     register(:my_config_accessor, 'my_config', :json, false, MyConfigDescription)
#   end
module Configs
  @all_registered_configs = {}
  # List of keys from file to ruby world
  KEY_TRANSLATIONS = {isMouseDisabled: :is_mouse_disabled, mouseSkin: :mouse_skin, gameResolution: :game_resolution, windowScale: :window_scale, isFullscreen: :is_fullscreen, isPlayerAlwaysCentered: :is_player_always_centered, tilemapSettings: :tilemap_settings, introMovieMapId: :intro_movie_map_id, bgmName: :bgm_name, bgmDuration: :bgm_duration, isLanguageSelectionEnabled: :language_selection_enabled, additionalSplashes: :additional_splashes, controlWaitTime: :control_wait, maximumSave: :maximum_save_count, saveKey: :save_key, saveHeader: :save_header, baseFilename: :base_filename, isCanSaveOnAnySave: :can_save_on_any_save, projectSplash: :project_splash, lineHeight: :line_height, scrollSpeed: :speed, leaderSpacing: :leader_spacing, chiefProjectTitle: :chief_project_title, chiefProjectName: :chief_project_name, gameCredits: :game_credits, pokemonMaxLevel: :max_level, isAlwaysUseForm0ForEvolution: :always_use_form0_for_evolution, isUseForm0WhenNoEvolutionData: :use_form0_when_no_evolution_data, maxBagItemCount: :max_bag_item_count, isSmoothTexture: :smooth_texture, isVsyncEnabled: :vsync_enabled, gameTitle: :game_title, gameVersion: :game_version, defaultLanguage: :default_language_code, choosableLanguageCode: :choosable_language_code, choosableLanguageTexts: :choosable_language_texts}
  # Name of the file that must exist if we want to successfully load scripts
  SCRIPTS_REQUIRED_CONFIG = 'Data/configs/display_config.json'
  class << self
    # Register a new config
    # @param name [Symbol] name of the config
    # @param filename [String] name of the file inside Data/configs
    # @param type [Symbol] type of the config file: :yml or :json
    # @param preload [Boolean] if the file need to be preloaded
    # @param klass [Class] class describing the config content
    def register(name, filename, type, preload, klass)
      @all_registered_configs[name] = {filename: filename, type: type, klass: klass}
      if preload
        load_file_data(name)
      else
        define_singleton_method(name) {load_file_data(name) }
      end
    end
    private
    # Function that loads the file data
    # @param name [Symbol] name of the file data to load
    # @return [Object, nil] whatever was loaded or initialized
    def load_file_data(name)
      return unless (info = @all_registered_configs[name])
      rxdata_filename = format('Data/configs/%<filename>s.rxdata', filename: clean_filename(info[:filename]))
      if PSDK_CONFIG.release?
        data = load_data(rxdata_filename)
        define_singleton_method(name) {data }
        return data
      end
      real_filename = format('Data/configs/%<filename>s.%<ext>s', filename: info[:filename], ext: info[:type])
      dirname = File.dirname(real_filename)
      Dir.mkdir!(dirname) unless Dir.exist?(dirname)
      data = load_config_data(info, rxdata_filename, real_filename)
      define_singleton_method(name) {data }
      return data
    end
    # Function that cleans the filename for rxdata files
    # @param filename [String]
    # @return [String]
    def clean_filename(filename)
      filename.gsub('/', '_')
    end
    # Function that load the config data in non-release mode
    # @param info [Hash]
    # @param rxdata_filename [String]
    # @param real_filename [String]
    def load_config_data(info, rxdata_filename, real_filename)
      if File.exist?(real_filename) && File.exist?(rxdata_filename) && (File.mtime(real_filename) <= File.mtime(rxdata_filename))
        return load_data(rxdata_filename)
      else
        if File.exist?(real_filename)
          log_info("Loading config file #{real_filename}")
          file_content = File.read(real_filename)
          data = info[:type] == :yml ? YAML.unsafe_load(file_content) : JSON.parse(file_content, symbolize_names: true)
          if data.is_a?(Hash)
            pre_data = data
            data = info[:klass].new
            pre_data.each do |key, value|
              next if key == :klass
              data.send("#{KEY_TRANSLATIONS[key] || key}=", value)
            end
          else
            if !data.is_a?(info[:klass])
              raise "Invalid klass #{data.class} for file #{real_filename}, expected #{info[:klass]}"
            end
          end
        else
          if real_filename == SCRIPTS_REQUIRED_CONFIG
            ScriptLoader.load_tool('PSDKEditor')
            PSDK_CONFIG.send(:initialize)
            PSDKEditor.convert_display_settings
            PSDKEditor.convert_texts_settings
            PSDKEditor.convert_infos_settings
            return load_config_data(info, rxdata_filename, real_filename)
          else
            log_info("Creating config file #{real_filename}")
            data = File.exist?(rxdata_filename) ? load_data(rxdata_filename) : info[:klass].new
            File.write(real_filename, info[:type] == :yml ? YAML.dump(data) : JSON.dump(data))
          end
        end
      end
      save_data(data, rxdata_filename)
      return data
    end
  end
  # Module holding all the project config
  module Project
    # Device configuration
    class Devices
      # Is mouse disabled
      # @return [Boolean]
      attr_accessor :is_mouse_disabled
      # Skin of the mouse
      # @return [String]
      attr_accessor :mouse_skin
    end
    # Display configuration of the project
    class Display
      # Get the game resolution
      # @return [Point]
      attr_reader :game_resolution
      # Get the default window scale
      # @return [Integer]
      attr_accessor :window_scale
      # Is the game running in fullscreen
      # @return [Boolean]
      attr_accessor :is_fullscreen
      # Is the player always centered on the screen
      # @return [Boolean]
      attr_accessor :is_player_always_centered
      # Get the tilemap settings
      # @return [TilemapSettings]
      attr_reader :tilemap_settings
      # Data structure describing a point
      class Point
        # Get the x coodinate
        # @return [Integer]
        attr_reader :x
        # Get the y coordinate
        # @return [Integer]
        attr_reader :y
        def initialize(x, y)
          @x = x
          @y = y
        end
      end
      # Data class describing Tilemap configuration
      class TilemapSettings
        # Get the tilemap class
        # @return [String]
        attr_reader :tilemap_class
        # Get the size of the tilemap
        # @return [Point]
        attr_reader :tilemap_size
        # Get the number of frame autotiles does not animate
        # @return [Integer]
        attr_reader :autotile_idle_frame_count
        # Get the zoom of the tiles as character
        # @return [Float]
        attr_reader :character_tile_zoom
        # Get the zoom of the sprite as character
        # @return [Float]
        attr_reader :character_sprite_zoom
        # Get the center of the screen in sub pixel size
        # @return [Point]
        attr_reader :center
        # Get the map linker offset
        # @return [Point]
        attr_reader :map_linker_offset
        # Tell if the game uses the old map linker settings
        # @return [Boolean]
        attr_reader :uses_old_map_linker
        def initialize(v)
          @tilemap_class = v[:tilemapClass]
          @tilemap_size = Point.new(v[:tilemapSize][:x], v[:tilemapSize][:y])
          @autotile_idle_frame_count = v[:autotileIdleFrameCount]
          @character_tile_zoom = v[:characterTileZoom]
          @character_sprite_zoom = v[:characterSpriteZoom]
          @center = Point.new(v[:center][:x], v[:center][:y])
          @map_linker_offset = Point.new(v[:maplinkerOffset][:x], v[:maplinkerOffset][:y])
          @uses_old_map_linker = v[:isOldMaplinker]
        end
      end
      def game_resolution=(res)
        @game_resolution = Point.new(res[:x] || 320, res[:y] || 240)
      end
      def tilemap_settings=(v)
        @tilemap_settings = TilemapSettings.new(v)
      end
    end
    # Option configurations
    class GameOptions
      # Get the order of options
      # @return [Array<Symbol>]
      attr_reader :order
      def order=(v)
        @order = v.map(&:to_sym)
      end
      # Set the options of the game
      # @param v [nil]
      def options=(v)
      end
    end
    # Text display configurations
    class Texts
      # Get the font config
      # @return [Font]
      attr_reader :fonts
      # Get the message config
      # @return [Hash<String => MessageConfig>]
      attr_reader :messages
      # Get the choice config
      # @return [Hash<String => ChoiceConfig>]
      attr_reader :choices
      def fonts=(v)
        @fonts = Font.new(v)
      end
      def messages=(v)
        @messages = v.map { |k, val| [k == :any ? :any : k.to_s, MessageConfig.new(val)] }.to_h
      end
      def choices=(v)
        @choices = v.map { |k, val| [k == :any ? :any : k.to_s, ChoiceConfig.new(val)] }.to_h
      end
      # Font configuration
      class Font
        # Is the game supporting the pokemon number feature
        # @return [Boolean]
        attr_reader :supports_pokemon_number
        # Get all the ttf files the game uses
        # @return [Array<Hash>]
        attr_reader :ttf_files
        # Get all the alt size the game uses
        # @return [Array<Hash>]
        attr_reader :alt_sizes
        def initialize(v)
          @supports_pokemon_number = v[:isSupportsPokemonNumber]
          @ttf_files = v[:ttfFiles]
          @alt_sizes = v[:altSizes]
        end
      end
      # Configuration of choice box
      class ChoiceConfig
        # Get the window skin
        # @return [String, nil]
        attr_reader :window_skin
        # Get the border spacing
        # @return [Integer]
        attr_reader :border_spacing
        # Get the default font
        # @return [Integer]
        attr_reader :default_font
        # Get the default color
        # @return [Integer]
        attr_reader :default_color
        # Get the color_mapping
        # @return [Hash{ Integer => Integer }]
        attr_reader :color_mapping
        def initialize(v)
          @window_skin = v[:windowSkin]
          @border_spacing = v[:borderSpacing]
          @default_font = v[:defaultFont]
          @default_color = v[:defaultColor]
          @color_mapping = v[:colorMapping].transform_keys { |k| k.to_s.to_i }
        end
      end
      # Configuration of messages boxes
      class MessageConfig < ChoiceConfig
        # Get the window skin of the name box
        # @return [String, nil]
        attr_reader :name_window_skin
        # Get the number of lines the message has
        # @return [Integer]
        attr_reader :line_count
        def initialize(v)
          super(v)
          @name_window_skin = v[:nameWindowSkin]
          @line_count = v[:lineCount]
        end
      end
    end
    # Generic settings
    class Settings
      # Get the maximum level
      # @return [Integer]
      attr_accessor :max_level
      # Tell if evolution always uses form 0 to fetch evolution data
      # @return [Boolean]
      attr_accessor :always_use_form0_for_evolution
      # Tell if we use form 0 of current creature when current form has no data
      # @return [Boolean]
      attr_accessor :use_form0_when_no_evolution_data
      # Tell how much quantity of an item can be stored in the bag
      # @return [Integer]
      attr_accessor :max_bag_item_count
    end
    # Graphic configuration of the game
    class Graphic
      # Tell if the textures should be smooth
      # @return [Boolean]
      attr_accessor :smooth_texture
      # Tell if the vsync should be enabled
      # @return [Boolean]
      attr_accessor :vsync_enabled
    end
    # Information about the game
    class Infos
      # Get the game title
      # @return [String]
      attr_accessor :game_title
      # Get the game version
      # @return [Integer]
      attr_accessor :game_version
    end
    # Language configuration
    class Language
      # Give the default language code
      # @return [String]
      attr_accessor :default_language_code
      # Get the list of language user can choose
      # @return [Array<String>]
      attr_accessor :choosable_language_code
      # Get the name of the languages
      # @return [Array<String>]
      attr_accessor :choosable_language_texts
    end
  end
  register(:devices, 'devices_config', :json, false, Project::Devices)
  register(:display, 'display_config', :json, false, Project::Display)
  register(:game_options, 'game_options_config', :json, false, Project::GameOptions)
  register(:texts, 'texts_config', :json, false, Project::Texts)
  register(:settings, 'settings_config', :json, false, Project::Settings)
  register(:graphic, 'graphic_config', :json, false, Project::Graphic)
  register(:infos, 'infos_config', :json, false, Project::Infos)
  register(:language, 'language_config', :json, false, Project::Language)
end
# Namespace that contains modules and classes written by Nuri Yuri
# @author Nuri Yuri
module Yuki
  # Module that allows the game to write and Error.log file if the Exception is not a SystemExit or a Reset
  #
  # Creation date : 2013, update : 26/09/2017
  # @author Nuri Yuri
  module EXC
    # Name of the current Game/Software
    Software = 'Pokémon SDK'
    module_function
    # Method that runs #build_error_log if the Exception is not a SystemExit or a Reset.
    # @overload run(e)
    #   The log is sent to Error.log
    #   @param e [Exception] the exception thrown by Ruby
    # @overload run(e, io)
    #   The log is sent to an io
    #   @param e [Exception] the exception thrown by Ruby
    #   @param io [#<<] the io that receive the log
    def run(e, io = nil)
      log_debug(e.inspect)
      return if e.class == LiteRGSS::DisplayWindow::ClosedWindowError
      raise if (e.message.empty? || e.class.to_s == 'Reset') && !e.is_a?(Interrupt)
      error_log = build_error_log(e)
      if io
        io << error_log
      else
        File.binwrite('Error.log', error_log)
        puts "The game crashed!\nThe error is stored in Error.log.\n"
      end
      dot_25_battle_reproduction($scene) if defined?(Battle::Scene) && $scene.is_a?(Battle::Scene)
      show_error_window(error_log) if $scene
    end
    # Method that build the error log.
    # @param e [Exception] the exception thrown by Ruby
    # @return [String] the log readable by anybody
    def build_error_log(e)
      str = ''
      return build_system_stack_error_log(e, str) if e.is_a?(SystemStackError)
      return unless e.backtrace_locations
      source_arr = e.backtrace_locations[0]
      source_name = fix_source_path(source_arr.path.to_s)
      source_line = source_arr.lineno
      str << 'Erreur de script'.center(80, '=')
      str << format("\r\nMessage :\r\n%<message>s\r\n\r\n", message: e.message.to_s.sub(/\#<([^ ]+).*>/, '#<\\1>').gsub(/[\r\n]+/, "\r\n"))
      str << format("Type : %<type>s\r\n", type: e.class)
      str << format("Script : %<script>s\r\n", script: source_name)
      str << format("Ligne : %<line>d\r\n", line: source_line)
      str << format("Date : %<date>s\r\n", date: Time.new.strftime('%d/%m/%Y %H:%M:%S'))
      str << format("Game Version : %<game_version>s\r\n", game_version: Configs.infos.game_version)
      str << format("Logiciel : %<software>s %<version>s\r\n", software: Software, version: PSDK_VERSION_STRING)
      str << format("Script used by eval command : \r\n%<script>s\r\n\r\n", script: @eval_script) if @eval_script
      str << 'Backtraces'.center(80, '=')
      str << "\r\n"
      index = e.backtrace_locations.size
      e.backtrace_locations.each do |i|
        index -= 1
        source_name = fix_source_path(i.path.to_s)
        str << format("[%<index>s] : %<script>s | ligne %<line>d %<method>s\r\n", index: index, script: source_name, line: i.lineno, method: i.base_label)
      end
      str << 'Fin du log'.center(80, '=')
      Yuki.set_clipboard(str)
      return str
    end
    # Function that corrects the source path
    # @param source_name [String] the source name path
    # @return [String] the fixed source name
    def fix_source_path(source_name)
      source = source_name.sub(File.expand_path('.'), nil.to_s).sub(File.expand_path(File.join(__FILE__, '../../..')), nil.to_s)
      unless source.sub!(%r{/pokemonsdk/scripts/(.*)}, '\\1 (PSDK)') || source.sub!(%r{/scripts/(.*)}, '\\1 (user)')
        source << (source.include?('/lib/') ? ' (ruby)' : ' (RMXP)')
      end
      return source
    end
    # Sets the script used by the eval command
    # @param script [String, nil] the script used in the eval command
    def set_eval_script(script)
      if script
        @eval_script = script
      else
        @eval_script = nil
      end
    end
    # Get the eval script used by the current eval command
    # @return [String, nil]
    def get_eval_script
      return @eval_script
    end
    # Build the SystemStackError message
    # @param e [SystemStackError]
    # @param str
    def build_system_stack_error_log(e, str)
      str << format("Message :\r\n%<message>s\r\n", message: e.message.to_s.gsub(/[\r\n]+/, "\r\n"))
      str << format("Type : %<type>s\r\n", type: e.class)
      str << format("Date : %<date>s\r\n", date: Time.new.strftime('%d/%m/%Y %H:%M:%S'))
      str << format("Game Version : %<game_version>s\r\n", game_version: Configs.infos.game_version)
      str << format("Logiciel : %<software>s %<version>s\r\n", software: Software, version: PSDK_VERSION_STRING)
      str << format("Script used by eval command : \r\n%<script>s\r\n", script: @eval_script) if @eval_script
      str << (e.backtrace || ['Unkown Sources...']).join("\r\n")
      return str
    end
    # Function building the reproduction file
    # @param scene [Battle::Scene]
    def dot_25_battle_reproduction(scene)
      PFM.game_state.game_temp = Game_Temp.new
      $game_map.begin_save
      compressed_data = Zlib::Deflate.deflate(Marshal.dump([PFM.game_state, scene.battle_info]), Zlib::BEST_COMPRESSION)
      File.binwrite('battle.dat', compressed_data)
    end
    # Function building the reproduction file for the Mining Game
    # @param grid_handler [PFM::MiningGame::GridHandler]
    def mining_game_reproduction(grid_handler)
      compressed_data = Zlib::Deflate.deflate(Marshal.dump(grid_handler), Zlib::BEST_COMPRESSION)
      File.binwrite('mining_game.dat', compressed_data)
    end
    # Function that shows the error window
    # @param log [String]
    def show_error_window(log)
      if defined?(GamePlay::Save)
        save_data = defined?(Battle::Scene) && $scene.is_a?(Battle::Scene) ? File.binread('battle.dat') : GamePlay::Save.save(nil, true)
        ErrorWindow.new.run(log, save_data)
      else
        ErrorWindow.new.run(log)
      end
    end
  end
  # Show an error window
  class ErrorWindow
    # Open the error window and let the user aknowledge it
    # @param error_text [String] Text stored inside Error.log
    # @param data_to_add [Array<String>] data to add to the error log as pictures
    def run(error_text, *data_to_add)
      texts_to_show = cleanup_error_log(error_text)
      if defined?(ScriptLoader.load_tool)
        ScriptLoader.load_tool('SaveToPicture')
        images_to_show = data_to_add.map { |i| SaveToPicture.run(data: i) }
        images_to_show << SaveToPicture.run(data: error_text)
      end
      show_window_and_wait(texts_to_show, images_to_show || [])
    end
    private
    # Function that generates the text to show
    # @param error_text [String]
    # @return [Array<String>]
    def cleanup_error_log(error_text)
      sections = error_text.split(/=+[^=]+=+\r*\n/).reject(&:empty?)
      backtraces = sections[1].split("\n")[0, 5].join("\n")
      message = sections[0].sub('Message', 'A script error happened')
      return message, "Backtraces:\n#{backtraces}"
    end
    # Function that shows the window and wait for the user to do something
    # @param texts_to_show [Array<String>] text to show into the window
    # @param images [Array<Image>]
    def show_window_and_wait(texts_to_show, images)
      @running = true
      if PSDK_PLATFORM == :macos
        show_window_and_wait_internal(texts_to_show, images) {update_graphics }
      else
        Thread.new {show_window_and_wait_internal(texts_to_show, images) }
        update_graphics while @running
      end
    end
    # Function that execute the window processing
    # @param texts_to_show [Array<String>] text to show into the window
    # @param images [Array<Image>]
    def show_window_and_wait_internal(texts_to_show, images)
      window = LiteRGSS::DisplayWindow.new('Error', 960, 480, 1, 32, 20, false, false, false)
      create_text(window, texts_to_show)
      to_dispose = create_and_arrange_images(window, images)
      window.on_closed = proc {@running = false }
      while @running
        window.update
        yield if block_given?
      end
      to_dispose.each { |bmp| bmp.dispose unless bmp.disposed? }
    end
    # Function that updates the ingame graphics
    def update_graphics
      Graphics.window&.update
      sleep(0.1)
    rescue Exception
      sleep(0.1)
    end
    # Function that create the text to show into the window
    # @param window [LiteRGSS::Window]
    # @param texts_to_show [Array<String>]
    def create_text(window, texts_to_show)
      text = LiteRGSS::Text.new(0, window, window.width - 2, 96, 0, 16, texts_to_show[1], 2)
      text.draw_shadow = false
      text.fill_color = Color.new(220, 220, 220, 255)
      text.size = 13
      text = LiteRGSS::Text.new(0, window, 0, 0, 0, 16, append_message(texts_to_show[0]))
      text.draw_shadow = false
      text.fill_color = Color.new(220, 220, 220, 255)
      text.size = 13
    end
    # Function that append the text to show with a message
    # @param input [String]
    # @return [String]
    def append_message(input)
      if $game_system&.map_interpreter&.running?
        eid = $game_system.map_interpreter.event_id
        event = $game_map.events&.[](eid)&.event
        event_info = "\nEventID: #{eid} (#{event&.x}, #{event&.y}) | MapID: #{$game_map.map_id}"
      end
      return "#{input.strip}#{event_info}\n\nTake a snapshot of this window and report the issue if you can't fix it yourself!"
    end
    # Function that displays the images in reverse order starting from bottom right of the screen
    # @param window [LiteRGSS::Window]
    # @param images [Array<Image>]
    # @return [Array<Texture>]
    def create_and_arrange_images(window, images)
      y = window.height
      x = window.width
      min_y = y
      return images.map do |image|
        bmp = Texture.new(image.width, image.height)
        image.copy_to_bitmap(bmp)
        if (x - image.width) < 0
          x = window.width
          y = min_y
        end
        x -= image.width
        iy = y - image.height
        min_y = [iy, min_y].min
        LiteRGSS::Sprite.new(window).set_position(x, iy).bitmap = bmp
        image.dispose
        x -= 1
        next(bmp)
      end
    end
  end
end
# Function responsive of reloading the saved battle
def reload_battle
  return log_error('There is no battle') unless File.exist?('battle.dat')
  PFM.game_state, battle_info = Marshal.load(Zlib::Inflate.inflate(File.binread('battle.dat')))
  PFM.game_state.expand_global_var
  PFM.game_state.load_parameters
  $game_map.setup($game_map.map_id)
  Graphics.freeze
  $scene = Battle::Scene.new(battle_info)
end
# Function responsive of reloading the saved mining game instance
# @return [PFM::MiningGame::GridHandler]
def reload_mining_game
  return Marshal.load(Zlib::Inflate.inflate(File.binread('mining_game.dat')))
end
