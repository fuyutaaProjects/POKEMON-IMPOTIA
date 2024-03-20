module Util
  # Module that help showing system message.
  #
  # How to use it :
  # ```ruby
  #   include Util::SystemMessage
  #   # ...
  #     show_message(:message_name) # Basic message
  #     if yes_no_choice(load_message(:message_name)) # Choice from interpreter
  #       show_message(:message_name, pokemon: pokemon) # Will set PKNICK[0] & PKNAME[0]
  #       show_message(:message_name, pokemon_1: pokemon) # Will set PKNICK[1] & PKNAME[1]
  #       show_message(:message_name, item: item_id, pokemon: pokemon) # Will set ITEM2[0], PKNICK[0] & PKNAME[0]
  #       show_message_and_wait(:message_name) # Will wait until the message box disappear
  # ```
  #
  # How to define ":message_name"s :
  #   - Simple message (from RH) : `Util::SystemMessage::MESSAGES[:message_name] = [:text_get, id, line]`
  #   - Complex message : `Util::SystemMessage::MESSAGES[:message_name] = proc { |opts| next(message_contents) }`
  # Note : opts are the optionnals arguments sent to show_message
  module SystemMessage
    # List of message by name
    MESSAGES = {received_pokemon: [:ext_text, 8999, 15], give_nickname_question: [:ext_text, 8999, 16], is_nickname_correct_qesion: [:ext_text, 8999, 17], pokemon_stored_to_box: [:ext_text, 8999, 18], bag_store_item_in_pocket: [:text_get, 41, 9], pokemon_shop_unavailable: [:ext_text, 9003, 1]}
    # Capture regexp
    HAS_NUMBER_REG = /_([0-9]+)$/
    # Tell if the key contain pokemon
    IS_POKEMON = /^pokemon/
    # Tell if the key contain item
    IS_ITEM = /^item/
    # Tell if the key contain num1
    IS_NUMBER1 = /^num1/
    # Tell if the key contain num2
    IS_NUMBER2 = /^num2/
    # Tell if the key contain num3
    IS_NUMBER3 = /^num3/
    module_function
    # Load a message
    # @param message_name [Symbol] ID of the message in MESSAGES
    # @param opts [Hash] options (additional text replacement)
    def load_message(message_name, opts = nil)
      PFM::Text.reset_variables
      parse_opts(opts) if opts
      message_data = MESSAGES[message_name]
      string = message_data.is_a?(Array) ? send(*message_data) : message_data.call(opts)
      string = opts[:header] + string if opts&.key?(:header)
      return PFM::Text.parse_string_for_messages(string.dup)
    ensure
      PFM::Text.reset_variables
    end
    # Show a message
    # @param message_name [Symbol] ID of the message in MESSAGES
    # @param opts [Hash] options (additional text replacement)
    def show_message(message_name, opts = nil)
      message_text = load_message(message_name, opts)
      if is_a?(Interpreter)
        message(message_text)
      else
        if is_a?(Scene_Map) || is_a?(GamePlay::Base)
          display_message(message_text)
        else
          $scene.display_message(message_text)
        end
      end
    end
    # Show a message
    # @param message_name [Symbol] ID of the message in MESSAGES
    # @param opts [Hash] options (additional text replacement)
    def show_message_and_wait(message_name, opts = nil)
      message_text = load_message(message_name, opts)
      if is_a?(GamePlay::Base)
        return display_message_and_wait(message_text)
      else
        if is_a?(Interpreter)
          message(message_text)
        else
          $scene.display_message(message_text)
        end
      end
    end
    # Parse the message opts
    # @param opts [Hash] options (additional text replacement)
    def parse_opts(opts)
      text_handler = PFM::Text
      opts.each do |key, value|
        next(text_handler.set_variable(key, value)) if key.is_a?(String)
        number = key.match(HAS_NUMBER_REG)&.captures&.first&.to_i || 0
        if key.match?(IS_POKEMON)
          text_handler.set_pkname(value, number)
          text_handler.set_pknick(value, number)
        else
          if key.match?(IS_ITEM)
            text_handler.set_item_name(value, number)
          else
            if key.match?(IS_NUMBER1)
              text_handler.set_num1(value, number)
            else
              if key.match?(IS_NUMBER2)
                text_handler.set_num2(value, number)
              else
                if key.match?(IS_NUMBER3)
                  text_handler.set_num3(value, number)
                end
              end
            end
          end
        end
      end
    end
  end
end
Interpreter.include(Util::SystemMessage)
module PFM
  # Module responsive of holding the whole Message logic
  module Message
    # Module parsing a message to a set of instruction the message displayer can show
    module Parser
      @code_replacer = []
      # Function that parses the message text so it's easier to work with it
      # @param text [String] original message text
      # @return [Message::Properties] the initial message properties
      def convert_text_to_properties(text)
        parsed_text = Text.parse_string_for_messages(text.dup).dup
        Parser.code_replacer.each { |replacer| replacer&.call(parsed_text) }
        return Properties.new(parsed_text)
      end
      # Function that generate the instructions based on properties & text surface
      # @param properties [Properties] Message box properties
      # @param width [Integer] width of the surface used to draw the message
      # @param width_computer [WidthComputer] object helping to compute the width of the words
      def make_instructions(properties, width, width_computer)
        instructions = Instructions.new(properties, width, width_computer)
        instructions.parse
        return instructions
      end
      class << self
        # Get the list of code replacer
        # @return [Array<Proc>]
        attr_reader :code_replacer
        # Register a text marker to make text easier to parse
        # @param regexp [Regexp] regexp to parse
        # @param code [Integer] code to use for easier parsing (must be positive integer)
        # @yieldparam captures [Array<String>] list of all captures from the regexp
        # @yieldreturn [Array] array of element not containing "[" or "]"
        # @note If no block is given, the function will assume the regexp has 1 match
        def register_marker(regexp, code)
          if block_given?
            @code_replacer[code] = proc do |text|
              text.gsub!(regexp) do
                parameters = yield(Regexp.last_match.captures)
                parameters = [parameters] unless parameters.is_a?(Array)
                next("#{code.chr}[#{parameters.join(',')}]")
              end
            end
          else
            @code_replacer[code] = proc { |text| text.gsub!(regexp, "#{code.chr}[\\1]") }
          end
        end
      end
      register_marker(/\\c\[([0-9]+)\]/i, 1)
      register_marker(/\[WAIT ([0-9]+)\]/i, 2)
      register_marker(/\\s\[([bir]+)\]/i, 3) do |(style)|
        next(0) if style.include?('r')
        next(1) if style == 'b'
        next(2) if style == 'i'
        next(3)
      end
      register_marker(/\\\^/, 4) {0 }
      register_marker(/\\spd\[([0-9]+)\]/, 5)
      register_marker(/\\img\[([^\]]+)\]/, 15)
    end
    # Class holding all the properties for the currently showing message
    class Properties
      # All the properties that can be set in :[]: with the function to call to compute the property parameters
      # @return [Hash{String=>Symbol}]
      PROPERTIES = {'name' => :parse_speaker_name, 'face' => :parse_speaker_face, 'city' => :parse_city_filename, 'can_skip' => :parse_can_skip, 'windowskin' => :parse_window_skin, 'lookto' => :look_to_event, 'align' => :parse_message_align}
      # Parsed text of the message
      # @return [String]
      attr_reader :parsed_text
      # Tell that the message should show the gold window
      # @return [Boolean]
      attr_accessor :show_gold_window
      # Get the name to show
      # @return [String, nil]
      attr_reader :name
      # Get the color of the name to show
      # @return [Integer, nil]
      attr_reader :name_color
      # Get all the faces to show
      # @return [Array<Face>]
      attr_reader :faces
      # Get the city image to show
      # @return [String, nil]
      attr_reader :city_filename
      # Tell if user can skip the message using directional keys
      # @return [Boolean]
      attr_reader :can_skip_message
      # Get the windowsking overwrite of the current message
      # @return [String]
      attr_reader :windowskin_overwrite
      # Get the ID of the event to look to
      # @return [Integer]
      attr_reader :look_to
      # Get the message alignment
      # @return [Symbol] :left, :right, :center
      attr_reader :align
      # Create a new Properties object
      # @param parsed_text [String]
      def initialize(parsed_text)
        @parsed_text = parsed_text
        @show_gold_window = false
        @can_skip_message = false
        @name = nil
        @name_color = nil
        @faces = []
        @align = :left
        preparse_properties
      end
      # Process the lookto operation
      def process_look_to
        return if @look_to == 0 || !@look_to
        $game_player.look_to(@look_to)
      end
      private
      # Parse the speaker name
      # @param info_str [String] name of the speaker
      def parse_speaker_name(info_str)
        name, color = info_str.split(/,([0-9])/)
        @name = name
        @name_color = color.to_i
      end
      # Parse the face of a speaker
      # @param info_str [String] infos about the face (position,name,opacity,mirror)
      def parse_speaker_face(info_str)
        position, name, opacity, mirror = info_str.split(',')
        face = Face.new
        face.position = position.to_i
        face.name = name
        face.opacity = opacity ? opacity.to_i.clamp(0, 255) : 255
        face.mirror = mirror == true
        @faces << face
      end
      # Parse the image setting of the city
      # @param name [String] name of the image in Pictures
      def parse_city_filename(name)
        @city_filename = name
      end
      # Parse the can skip authorisation
      # @param _ignored [String] ignored param
      def parse_can_skip(_ignored)
        @can_skip_message = true
      end
      # Parse the message box windowsking change
      # @param windowskin [String] name of the temporary windowskin
      def parse_window_skin(windowskin)
        @windowskin_overwrite = windowskin
      end
      # Turn the player toward the event of it's choice
      # @param event [String] the info about the chosen event
      # @example example of event
      #   If you want your player to turn to the talking event, write :[lookto=] or :[lookto=0]
      #   If you want your player to turn to another event, write :[lookto=X] where X is the event's id
      #   Take care to always write the id without the first 0. Example : 036 should always be written 36.
      def look_to_event(event)
        @look_to = event.to_i
      end
      # Parse the message alignment
      # @param align [String] position of text
      def parse_message_align(align = 'left')
        @align = align.to_sym
      end
      # Function that pre parse the properties so they're all set to the right value
      def preparse_properties
        self.show_gold_window = true if parsed_text.match?(/\\[Gg]/)
        parsed_text.gsub!(/\\[Gg]/, '')
        parsed_text.gsub!(/:\[([^\]]+)\]:/) {parse_properties($1) }
        parsed_text.gsub!(Text::S_000, '\\')
      end
      # Parse all the properties of a message set through :[prop_name1=a;prop_name2=a,b]:
      # @param unparsed_props [String] all the properties that were not currently parsed
      # @return nil
      def parse_properties(unparsed_props)
        unparsed_props.split(';').each do |property_string|
          property, values = property_string.split('=', 2)
          next unless (method_name = PROPERTIES[property])
          send(method_name, values)
        end
        return nil
      end
      # Class describing a face to show
      class Face
        # Get the face position
        # @return [Integer]
        attr_accessor :position
        # Get the face name (filename)
        # @return [String]
        attr_accessor :name
        # Get the face opacity
        # @return [Integer]
        attr_accessor :opacity
        # Get the face mirror state
        # @return [Boolean]
        attr_accessor :mirror
      end
    end
    # Parse & List all the instructions to draw the message box content
    class Instructions
      # Regexp used to detect markers
      MARKER_REGEXP = /([\x01-\x0F]\[[^\]]+\])/
      # Regexp to grab the marker data
      MARKER_DATA = /\[([^\]]+)\]/
      # Regexp that split text with space but preserver space in split output
      SPACE_SPLIT_PRESERVE_REGEXP = /( )/
      # ID of image marker
      IMAGE_MARKER_ID = 15
      # ID of big text marker
      BIG_TEXT_MARKER_ID = 4
      # Create a new Instructions instance
      # @param properties [Properties] Message box properties
      # @param width [Integer] width of the surface used to draw the message
      # @param width_computer [WidthComputer] object helping to compute the width of the words
      def initialize(properties, width, width_computer)
        @properties = properties
        @width = width
        @width_computer = width_computer
        @is_big = false
        @lines = []
      end
      # Parse the message
      def parse
        @total_width = 0
        @current_line = []
        split_text_and_markers.each do |data|
          next(parse_marker(data)) if marker?(data)
          next(parse_text(data))
        end
        push_line
        @lines.pop while @lines.any? && (@lines.last.empty? || @lines.last.first == NewLine)
        @lines.last.pop if @lines.any? && @lines.last.any? && @lines.last.last == NewLine
      end
      # Start instruction procesing
      def start_processing
        @line = 0
        @index = 0
      end
      # Tell if processing is done
      # @return [Boolean]
      def done_processing?
        return true unless @line && @index
        return @lines[@line].nil?
      end
      # Get current instruction and prepare next instruction
      # @return [Text, Marker, NewLine, nil]
      def get
        return nil if done_processing?
        instruction = @lines[@line][@index]
        @index += 1
        if @lines[@line].size <= @index
          @index = 0
          @line += 1
        end
        return instruction
      end
      # Get the width of the current line
      # @return [Integer]
      def current_line_width
        return 0 if done_processing?
        return @lines[@line].sum(&:width)
      end
      private
      # Split the text in a way markers can be converted to marker instruction easilly
      # @return [Array<String>]
      def split_text_and_markers
        return @properties.parsed_text.split(MARKER_REGEXP).reject(&:empty?)
      end
      # Detect if the string is a marker
      # @param string [String]
      # @return [Boolean]
      def marker?(string)
        string.match?(MARKER_REGEXP)
      end
      # Get the width of the text
      # @param text [String]
      # @return [Integer]
      def width_of(text)
        @is_big ? @width_computer.big_width(text) : @width_computer.normal_width(text)
      end
      # Function that parse a marker
      # @param marker [String]
      def parse_marker(marker)
        marker_id = marker.getbyte(0)
        return parse_image_marker(marker) if marker_id == IMAGE_MARKER_ID
        @is_big = true if marker_id == BIG_TEXT_MARKER_ID
        @current_line << Marker.new(marker_id, marker.match(MARKER_DATA).captures.first)
      end
      # Function that parse a image marker
      # @param marker [String]
      def parse_image_marker(marker)
        marker_id = marker.getbyte(0)
        data = marker.match(MARKER_DATA).captures.first
        image_name, cache, * = data.split(',')
        cache ||= :picture
        image = RPG::Cache.send(cache, image_name)
        will_overflow?(image.width) ? push_line(image.width) : @total_width += image.width
        @current_line << Marker.new(marker_id, data, image.width)
      end
      # Function that parses text
      # @param text [String]
      def parse_text(text)
        text.include?("\n") ? parse_text_with_new_line(text) : parse_text_without_new_line(text)
      end
      # Function that parses text containing new lines.
      # Will not push new line if a new line was created by the last word or will be created by next word.
      # @param text [String]
      def parse_text_with_new_line(text)
        text.split(/(\n)/).each do |sub_text|
          if sub_text == "\n"
            push_line unless @total_width == 0 || @total_width == @width
          else
            parse_text_without_new_line(sub_text)
          end
        end
      end
      # Function that parses text not containing new lines
      # @param text [String]
      def parse_text_without_new_line(text)
        text_width = width_of(text)
        return parse_text_that_break_in_several_lines(text) if will_overflow?(text_width)
        @total_width += text_width
        @current_line << Text.new(text, text_width)
      end
      # Function that parse a text that will break in several line because it's long
      # @param text [String]
      def parse_text_that_break_in_several_lines(text)
        sub_texts = text.split(SPACE_SPLIT_PRESERVE_REGEXP).reverse
        buffer = ''.dup
        while (sub_text = sub_texts.pop)
          sub_text_width = width_of(sub_text)
          if will_overflow?(sub_text_width)
            @current_line << Text.new(buffer.dup, width_of(buffer)) unless buffer.empty?
            buffer.clear
            push_line
            next if sub_text == ' '
          end
          @total_width += sub_text_width
          buffer << sub_text
        end
        @current_line << Text.new(buffer, width_of(buffer)) unless buffer.empty?
      end
      # Test if the current element width will overflow
      # @param width [Integer]
      # @return [Boolean]
      def will_overflow?(width)
        @total_width + width > @width
      end
      # Function that pushes a new line
      # @param new_line_total_width [Integer] current width of the new line
      def push_line(new_line_total_width = 0)
        @total_width = new_line_total_width
        @lines << @current_line
        @current_line << NewLine unless @current_line.last == NewLine
        @current_line = []
      end
      # Class that describes a Marker
      class Marker
        # Get the marker ID
        # @return [Integer]
        attr_reader :id
        # Get the marker data
        # @return [String]
        attr_reader :data
        # Get the width of the marker
        # @return [Integer]
        attr_reader :width
        # Create a new Marker
        # @param id [Integer] ID of the marker
        # @param data [String] data of the marker
        # @param width [Integer] width of the marker
        def initialize(id, data, width = 0)
          @id = id
          @data = data
          @width = width
        end
      end
      # Class that describe a text object
      class Text
        # Get the text to show
        # @return [String]
        attr_reader :text
        # Get the width of the text
        # @return [Integer]
        attr_reader :width
        # Create a new text object
        # @param text [String] text to show
        # @param width [Integer] width of the text to show
        def initialize(text, width)
          @text = text
          @width = width
        end
      end
      # Module that describe a new line
      module NewLine
        module_function
        # Get the width of the new line
        # @return [Integer]
        def width
          return 0
        end
      end
    end
    # Class that helps to compute the width of the words
    class WidthComputer
      # Create a new WidthComputer
      # @param text_normal [LiteRGSS::Text]
      # @param text_big [LiteRGSS::Text]
      def initialize(text_normal, text_big)
        @text_normal = text_normal
        @text_big = text_big
      end
      # Get the normal width of the text
      # @param text [String]
      # @return [Integer]
      def normal_width(text)
        @text_normal.text_width(text)
      end
      # Get the width of the text when it's big
      # @param text [String]
      # @return [Integer]
      def big_width(text)
        @text_big.text_width(text)
      end
      # Tell if any of the text is disposed
      # @return [Boolean]
      def disposed?
        return @text_big.disposed? || @text_normal.disposed?
      end
    end
    # Module responsive of helping the message window with states
    #
    # In order to have everything working properly, the class including this module needs to define:
    # - message_width : Returns an integer telling the width of the message window we want to process (can use @properties)
    # - width_computer : Returns [PFM::Message::WidthComputer] object helping to compute the width of the words/texts
    module State
      include Parser
      # If the message doesn't wait the player to hit A to terminate
      # @return [Boolean]
      attr_accessor :auto_skip
      # If the window message doesn't fade out
      # @return [Boolean]
      attr_accessor :stay_visible
      # The last unprocessed text the window has shown
      # @return [String, nil]
      attr_reader :last_text
      protected
      # Get the current instruction
      # @return [Instructions::Text, Instructions::Marker, Instructions::Marker, nil]
      attr_reader :current_instruction
      # Get the instructions
      # @return [Instructions]
      attr_reader :instructions
      # Get the properties
      # @return [Properties]
      attr_reader :properties
      public
      # Initialize the states
      def initialize(...)
        @auto_skip = false
        @stay_visible = false
        @last_text = nil
        super(...)
      end
      # Tell if the message window need to show a message
      # @return [Boolean]
      def need_to_show_message?
        return false if showing_message? && @instructions
        return $game_temp.message_text.is_a?(String)
      end
      # Tell if the message window need to wait for user input
      # @return [Boolean]
      def need_to_wait_user_input?
        return showing_message? && done_drawing_message? && !$game_temp.message_text.nil?
      end
      # Parse the new message and set the window into showing message state
      def parse_and_show_new_message
        @last_text = $game_temp.message_text
        @properties = convert_text_to_properties($game_temp.message_text)
        @instructions = make_instructions(@properties, message_width, width_computer)
        @instructions.start_processing
        @current_instruction = nil
        $game_temp.message_window_showing = true
      end
      # Load the next instruction
      def load_next_instruction
        @current_instruction = @instructions.get
      end
      # Test if we're at the end of the line
      # @return [Boolean]
      def at_end_of_line?
        return @current_instruction == Instructions::NewLine
      end
      # Test if we're done drawing the message
      # @return [Boolean]
      def done_drawing_message?
        return (@instructions&.done_processing? || !@instructions) && !current_instruction
      end
      # Tell if the message window is showing a message
      # @return [Boolean]
      def showing_message?
        return $game_temp.message_window_showing
      end
      # Tell if the message window need to show a choice
      # @return [Boolean]
      def need_to_show_choice?
        return $game_temp.choice_max > 0
      end
      # Tell if the message window need to show a number input
      # @return [Boolean]
      def need_to_show_number_input?
        return $game_temp.num_input_digits_max > 0
      end
      private
      # Terminate the message display
      def terminate_message
        self.active = false
        self.pause = false
        $game_temp.message_proc&.call
        reset_game_temp_message_info
        reset_overwrites
        init_fade_out
        @instructions = nil
        @auto_skip = false
      end
      # Reset all the states of the message_window
      def reset_states
        @properties = nil
        @instructions = nil
        @current_instruction = nil
        $game_temp.message_window_showing = false
      end
      # Reset the $game_temp stuff
      def reset_game_temp_message_info
        $game_temp.message_text = nil
        $game_temp.message_proc = nil
        $game_temp.choice_start = 99
        $game_temp.choice_max = 0
        $game_temp.choice_cancel_type = 0
        $game_temp.choice_proc = nil
        $game_temp.num_input_start = -99
        $game_temp.num_input_variable_id = 0
        $game_temp.num_input_digits_max = 0
      end
    end
  end
end
module UI
  # Module responsive of holding the whole message ui aspect
  module Message
    # Module implementing the overwrite functionality
    module TemporaryOverwrites
      # @return [Symbol, Array, nil] Overwrite the message position for the current message
      # @note Values can be : :top, :middle, :bottom, :left, :right, [x, y]
      attr_accessor :position_overwrite
      # @return [String, nil] Change the windowskin of the window
      attr_accessor :windowskin_overwrite
      # @return [String, nil] Change the windowskin of the name
      attr_accessor :nameskin_overwrite
      # @return [Integer, nil] Overwrite the number of line for the current message
      attr_accessor :line_number_overwrite
      # @return [Integer, nil] Overwrite the width of the window
      attr_accessor :width_overwrite
      # Initialize the overwrites
      def initialize(...)
        reset_overwrites
        super(...)
      end
      # Reset all the overwrite when the message has been shown
      def reset_overwrites
        @position_overwrite = @windowskin_overwrite = @nameskin_overwrite = nil
        @line_number_overwrite = @width_overwrite = nil
      end
    end
    # Module defining the Message layout
    module Layout
      # Name of the pause skin in Graphics/Windowskins/
      PAUSE_SKIN = 'Pause2'
      # Windowskin for the name window
      NAME_SKIN = 'message'
      include TemporaryOverwrites
      # Attribute that holds the UI::InputNumber object
      # @return [UI::InputNumber]
      attr_accessor :input_number_window
      protected
      # Get the text stack
      # @return [UI::SpriteStack]
      attr_reader :text_stack
      # Get the sub_stack
      # @return [UI::SpriteStack]
      attr_reader :sub_stack
      public
      # Initialize the states
      def initialize(...)
        super(...)
        @text_stack = UI::SpriteStack.new(self)
        @sub_stack = UI::SpriteStack.new(viewport)
        init_window
        self.visible = false
      end
      # Retrieve the current layout configuration based on the scene
      # @return [Configs::Project::Texts::MessageConfig]
      def current_layout
        config = Configs.texts.messages
        return config[$scene.class.to_s] || config[:any]
      end
      # Dispose the layout
      # @param with_viewport [Boolean] tell to also dispose the viewport of the layout
      def dispose(with_viewport: false)
        vp = viewport
        super()
        @sub_stack.dispose
        vp.dispose if with_viewport
      end
      private
      # Initialize the window Parameter
      def init_window
        self.z = 10_000
        lock
        update_windowskin
        init_pause_coordinates
        self.pauseskin = RPG::Cache.windowskin(PAUSE_SKIN)
        self.back_opacity = ($game_system.message_frame == 0 ? 255 : 0)
        unlock
      end
      def init_pause_coordinates
        self.pause_x = width - 13
        self.pause_y = height - 16
      end
      # Calculate the current window position
      def calculate_position
        x = default_horizontal_margin
        case current_position
        when :top
          y = default_vertical_margin
        when :middle
          y = (viewport.rect.height - height) / 2
        when :bottom, :left
          y = viewport.rect.height - default_vertical_margin - height
        when :right
          y = viewport.rect.height - default_vertical_margin - height
          x = viewport.rect.height - x - width
        end
        set_position(x, y)
      end
      # Update the windowskin
      def update_windowskin
        windowskin_name = current_windowskin
        return calculate_position if @windowskin_name == windowskin_name
        self.window_builder = current_window_builder
        self.windowskin = RPG::Cache.windowskin(@windowskin_name = windowskin_name)
        set_size(window_width, window_height)
        calculate_position
      end
      # Retrieve the current window position
      # @return [Symbol, Array]
      def current_position
        position = position_overwrite || $game_system.message_position
        case position
        when 0
          return :top
        when 1
          return :middle
        when 2
          return :bottom
        end
        position
      end
      # Retrieve the current window_builder
      # @return [Array]
      def current_window_builder
        return UI::Window.window_builder(current_windowskin)
      end
      # Retrieve the current windowskin
      # @return [String]
      def current_windowskin
        windowskin_overwrite || properties&.windowskin_overwrite || current_layout.window_skin || $game_system.windowskin_name
      end
      # Retrieve the current windowskin of the name window
      # @return [String]
      def current_name_windowskin
        nameskin_overwrite || current_layout.name_window_skin || NAME_SKIN
      end
      # Return the window width
      # @return [Integer]
      def window_width
        @width_overwrite || default_width
      end
      # Return the message width
      def message_width
        width = window_width - (wb = current_window_builder)[4] - wb[-2]
        return width - default_horizontal_margin - RPG::Cache.picture(properties.city_filename).width if properties&.city_filename
        return width
      end
      # Return the window height
      def window_height
        base_height = (wb = current_window_builder)[5] + wb[-1]
        base_height + default_line_height * line_number
      end
      # Return the number of lines
      def line_number
        @line_number_overwrite || default_line_number
      end
      # Return the default window width
      # @return [Integer]
      def default_width
        viewport.rect.width - default_horizontal_margin * 2
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
      # Return the default line number
      # @return [Integer]
      def default_line_number
        return current_layout.line_count
      end
      # Return the default line height
      def default_line_height
        return Fonts.line_height(current_layout.default_font)
      end
      # Return the default text color
      # @return [Integer]
      def default_color
        return current_layout.default_color
      end
      alias get_default_color default_color
      # Return the default text style
      # @return [Integer]
      def default_style
        return 0
      end
      alias get_default_style default_style
      # Is text displaying bigger (marker 4 compatibility)
      def bigger_text?
        @style.anybits?(0x04)
      end
      public
      # Generate the choice window
      def generate_choice_window
        @choice_window = Yuki::ChoiceWindow.generate_for_message(self)
      end
      # Generate the number input window
      def generate_input_number_window
        @input_number_window = UI::InputNumber.new(viewport, $game_temp.num_input_digits_max)
        if $game_system.message_position == 0
          @input_number_window.y = y + height + 2
        else
          @input_number_window.y = y - @input_number_window.height - 2
        end
        @input_number_window.z = z + 1
        @input_number_window.max = $game_temp.num_input_start if $game_temp.num_input_start > 0
        @input_number_window.update
      end
      # Show a window that tells the player how much money he got
      def show_gold_window
        return if @gold_window && !@gold_window.disposed?
        @gold_window = UI::Window.from_metrics(viewport, 318, 2, 48, 32, position: 'top_right')
        @gold_window.z = z + 1
        @gold_window.sprite_stack.with_surface(0, 0, 44) do
          @gold_window.add_line(0, text_get(11, 6))
          @gold_window.add_line(1, PFM::Text.parse(11, 9, ::PFM::Text::NUM7R => PFM.game_state.money.to_s), 2)
        end
        @sub_stack.push_sprite(@gold_window)
      end
      # Function that test if sub window can be updated (choice / number)
      # @return [Boolean]
      def can_sub_window_be_updated?
        !Graphics::FPSBalancer.global.skipping? || Input.trigger?(:A) || Input.trigger?(:B) || Input.repeat?(:DOWN) || Input.repeat?(:UP) || Input.repeat?(:RIGHT) || Input.repeat?(:LEFT)
      end
      # Show the name window
      def show_name_window
        return if @name_window && !@name_window.disposed?
        wb = current_window_builder
        name_y = y + (current_position == :top ? height + default_vertical_margin : (-wb[5] - wb[-1] - default_line_height - default_vertical_margin))
        text_width = width_computer.normal_width(properties.name)
        @name_window = UI::Window.from_metrics(viewport, x, name_y, text_width, default_line_height, skin: current_name_windowskin)
        @sub_stack.push_sprite(Text.new(0, @name_window, 0, -Text::Util::FOY, 0, default_line_height, properties.name, 0, nil, properties.name_color))
        @sub_stack.push_sprite(@name_window)
      end
      # Show the city image
      def show_city_image
        @city_sprite = Sprite.new(viewport)
        @city_sprite.z = z + 1
        @city_sprite.load(properties.city_filename, :picture)
        @city_sprite.set_position(x + (wb = current_window_builder)[4], y + wb[5])
        @sub_stack.push_sprite(@city_sprite)
      end
      # Show a face
      # @param face [PFM::Message::Properties::Face]
      def show_face(face)
        sprite = Sprite.new(viewport)
        sprite.load(face.name, :battler)
        sprite.set_position(parse_speaker_position(face.position), face_speaker_y)
        sprite.set_origin(sprite.width / 2, sprite.height)
        def sprite.opacity=(v)
          return @opacity = v unless @opacity
          super(v * @opacity / 255)
        end
        sprite.opacity = face.opacity
        sprite.mirror = face.mirror
        @sub_stack.push_sprite(sprite)
      end
      # Function that translate the position to a coordinate
      # @param position [Integer] position given by the maker
      # @return [Integer] the x position
      def parse_speaker_position(position)
        position = viewport.rect.width + position if position < 0
        return position
      end
      # Return the face_speaker y position
      # @return [Integer]
      def face_speaker_y
        return viewport.rect.height
      end
      # Load the sub layout based on properties
      def load_sub_layout
        @sub_stack.dispose
        properties.faces.each { |face| show_face(face) }
        show_name_window if properties.name
        show_city_image if properties.city_filename
        show_gold_window if properties.show_gold_window
        properties.process_look_to
        viewport.sort_z
      end
    end
    # Module defining how the message transition to the screen
    module Transition
      private
      # Initialize the fade-in operation
      def init_fade_in
        self.contents_opacity = 0 if text_stack.stack.empty?
        self.visible = true
        text_stack.dispose
        init_window
        yield if block_given?
        self.opacity = 255
        transition_duration = (255.0 - contents_opacity) / fade_in_opacity_speed
        @fade_in_animation = Yuki::Animation.scalar(transition_duration, self, :contents_opacity=, contents_opacity, 255)
        @fade_in_animation.parallel_play(Yuki::Animation.opacity_change(transition_duration, sub_stack, contents_opacity, 255))
        @fade_in_animation.start
        @fade_out_animation = nil
      end
      # Update the fade-in animation
      def update_fade_in
        return unless @fade_in_animation
        @fade_in_animation.update
        @fade_in_animation = nil if @fade_in_animation.done?
      end
      # Get the number of opacity unit per second for the fade in
      def fade_in_opacity_speed
        1440
      end
      # Initialize the fade-out operation
      def init_fade_out
        return $game_temp.message_window_showing = false if stay_visible && $game_temp.message_window_showing
        transition_duration = 255.0 / fade_out_opacity_speed
        @fade_out_animation = Yuki::Animation.opacity_change(transition_duration, self, 255, 0)
        @fade_out_animation.parallel_play(Yuki::Animation.opacity_change(transition_duration, sub_stack, 255, 0))
        @fade_out_animation.play_before(Yuki::Animation.send_command_to(self, :finalize_fade_out))
        @fade_out_animation.start
        @fade_in_animation = nil
      end
      # Finalize the fade-out operation
      def finalize_fade_out
        text_stack.dispose
        sub_stack.dispose
        self.visible = false
        self.opacity = 255
        reset_states
      end
      # Update the fade-out animation
      def update_fade_out
        return unless @fade_out_animation
        @fade_out_animation.update
        @fade_out_animation = nil if @fade_out_animation.done?
      end
      # Get the number of opacity unit per second for the fade in
      def fade_out_opacity_speed
        2880
      end
      def init_new_line_transition
        duration = default_line_height.to_f / new_line_transition_speed
        self.pause = true
        @line_transition_animation = create_pre_line_transition_animation
        @line_transition_animation.play_before(Yuki::Animation.scalar(duration, self, :oy=, oy, oy + default_line_height))
        @line_transition_animation.play_before(Yuki::Animation.send_command_to(self, :finalize_new_line_transition))
        @line_transition_animation.start
      end
      def create_pre_line_transition_animation
        return Yuki::Animation.wait_signal do
          if interacting?
            play_decision_se
            self.pause = false
          end
          next(!pause)
        end
      end
      # Test if the new line transition is done
      # @return [Boolean]
      def new_line_transition_done?
        return true unless @line_transition_animation
        return @line_transition_animation.done?
      end
      # Test if the new line transition is necessary
      # @return [Boolean]
      def need_new_line_transition?
        @text_y >= default_line_height * (line_number - 1)
      end
      # Update the new line transition
      def update_new_line_transition
        return unless @line_transition_animation
        @line_transition_animation.update
        @line_transition_animation = nil if new_line_transition_done?
      end
      # Execute the post process of the new line transition
      def finalize_new_line_transition
        self.oy = 0
        @text_y = default_line_height * (line_number - 1)
        text_stack.each do |text|
          text.y -= default_line_height
          text.dispose if text.y <= -default_line_height
        end
        text_stack.stack.delete_if(&:disposed?)
      end
      # Get the speed of the new line transition
      def new_line_transition_speed
        60
      end
    end
    # Module defining the drawing methods of messages
    module Draw
      private
      # Start to draw the message
      def start_drawing
        parse_and_show_new_message
        init_fade_in {load_sub_layout }
      end
      # Update the text drawing
      def update_draw
        init_text_drawing unless current_instruction
        until need_internal_drawing_update?
          load_next_instruction
          process_instruction
        end
        update_draw_internal
      end
      # Function that tells if the system needs an internal text drawing
      def need_internal_drawing_update?
        return instructions.done_processing? unless current_instruction
        return false if current_instruction.is_a?(PFM::Message::Instructions::Marker) && current_instruction.id != 2
        return !new_line_transition_done? if at_end_of_line?
        return !@text_animation.done? if current_instruction.is_a?(PFM::Message::Instructions::Text)
        return !@wait_animation.done? if @wait_animation
        return true
      end
      # Update the real drawing (animations) of the message
      def update_draw_internal
        return update_new_line_transition if at_end_of_line?
        @wait_animation&.update
        @text_animation.update
      end
      # Process the instructions
      def process_instruction
        return process_marker if current_instruction.is_a?(PFM::Message::Instructions::Marker)
        return start_text_animation if current_instruction.is_a?(PFM::Message::Instructions::Text)
        return process_end_of_line if at_end_of_line?
      end
      # Start the text animation
      def start_text_animation
        sizeid = bigger_text? ? 1 : current_layout.default_font
        text = text_stack.add_text(@text_x, @text_y, 0, default_line_height, current_instruction.text, color: @color, sizeid: sizeid)
        @text_x += current_instruction.width
        load_text_style(text)
        speed = (@current_speed == 0 ? $options&.message_speed : @current_speed) || 1
        text_updater = proc { |v| text.nchar_draw = v.to_i }
        duration = current_instruction.text.size / (speed * character_speed.to_f)
        @text_animation = Yuki::Animation.scalar(duration, text_updater, :call, 0, current_instruction.text.size)
        @text_animation.start
        @wait_animation = nil
      end
      # Test if the player is reading a panel and skips by moving
      def panel_skip?
        properties.can_skip_message && Input.dir4 != 0 && Input.dir4 != $game_player.direction
      end
      # Process the end of line
      def process_end_of_line
        init_new_line_transition if need_new_line_transition?
        @text_x = initial_text_line_x
        @text_y += default_line_height
      end
      # Load the text style
      # @param text [Text]
      def load_text_style(text)
        text.bold = true if (@style & 1) != 0
        text.italic = true if (@style & 2) != 0
        if bigger_text?
          text.size = Fonts.get_default_size(1)
          text.y += 4
        end
      end
      # Get the character speed (number of character / seconds at lowest speed)
      def character_speed
        return 60
      end
      # Initialize the text drawing
      def init_text_drawing
        set_origin(0, 0)
        @text_y = 0
        @text_x = initial_text_line_x
        @current_speed = 0
        @color = translate_color(get_default_color)
        @style = get_default_style
        @last_instruction = nil
      end
      # Get the initial x position of the text for the current line
      # @return [Integer]
      def initial_text_line_x
        x_offset = @city_sprite && !@city_sprite.disposed? ? @city_sprite.width + default_horizontal_margin : 0
        case properties.align
        when :right
          return message_width - instructions.current_line_width
        when :center
          return x_offset + (message_width - x_offset - instructions.current_line_width) / 2
        else
          return x_offset
        end
      end
      # Translate the color according to the layout configuration
      # @param color [Integer] color to translate
      # @return [Integer] translated color
      def translate_color(color)
        current_layout.color_mapping[color] || color
      end
      public
      # Function that process the markers of the message (property modifier)
      def process_marker
        marker = current_instruction
        marker_method = :"process_marker#{marker.id}"
        send(marker_method, marker) if respond_to?(marker_method)
        @text_x += marker.width
      end
      # Process the color marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_color_marker(marker)
        @color = translate_color(marker.data.to_i)
      end
      alias process_marker1 process_color_marker
      # Process the wait marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_wait_marker(marker)
        @wait_animation = Yuki::Animation.wait(marker.data.to_f / 60)
        @wait_animation.start
      end
      alias process_marker2 process_wait_marker
      # Process the style marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_style_marker(marker)
        style = marker.data.to_i
        @style = @style & 0x04 | style
      end
      alias process_marker3 process_style_marker
      # Process the big text marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_big_text_marker(marker)
        @style |= 0x04
      end
      alias process_marker4 process_big_text_marker
      # Process the speed marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_speed_marker(marker)
        @current_speed = marker.data.to_i
      end
      alias process_marker5 process_speed_marker
      # Process the picture marker
      # @param marker [PFM::Message::Instructions::Marker]
      def process_picture_marker(marker)
        filename, cache, dx, dy = marker.data.split(',')
        sprite = Sprite.new(self)
        sprite.set_position(@text_x + dx.to_i, @text_y + dy.to_i)
        sprite.load(filename, cache.to_sym)
        text_stack.push_sprite(sprite)
      end
      alias process_marker15 process_picture_marker
    end
    # Module describing the whole user input process
    module WaitUserInput
      private
      # Process the wait user input phase
      def wait_user_input
        return update_choice if need_to_show_choice?
        return update_input_number if need_to_show_number_input?
        return update_wait_input
      end
      # Show the Input Number Window
      # @return [Boolean] if the update function skips
      def update_input_number
        generate_input_number_window unless @input_number_window
        @input_number_window.update if can_sub_window_be_updated?
        if interacting?
          play_decision_se
          $game_variables[$game_temp.num_input_variable_id] = @input_number_window.number
          $game_map.need_refresh = true
          @input_number_window.dispose
          @input_number_window = nil
          terminate_message
        end
      end
      # Show the choice during update
      # @return [Boolean] if the update function skips
      def update_choice
        generate_choice_window unless @choice_window
        @choice_window.update if can_sub_window_be_updated?
        if $game_temp.choice_cancel_type > 0 && cancelling?
          play_cancel_se
          $game_temp.choice_proc.call($game_temp.choice_cancel_type - 1)
        else
          if @choice_window.validated?
            play_decision_se
            $game_temp.choice_proc.call(@choice_window.index)
          else
            return
          end
        end
        terminate_message
        @choice_window.dispose
        @choice_window = nil
      end
      # Skip the update of wait input
      # @return [Boolean] if the update of wait input should be skipped
      def update_wait_input_skip
        return false
      end
      # Autoskip the wait input
      # @return [Boolean]
      def update_wait_input_auto_skip
        return @auto_skip
      end
      # Wait for the user to press enter before moving forward
      def update_wait_input
        return if update_wait_input_skip
        self.pause = true
        if interacting?
          $game_system.se_play($data_system.cursor_se)
          terminate_message
        else
          if update_wait_input_auto_skip || panel_skip?
            terminate_message
          end
        end
      end
      # Tell if the user is interacting
      def interacting?
        return Input.trigger?(:A) || (Mouse.trigger?(:left) && simple_mouse_in?)
      end
      # Tell if the user is cancelling
      def cancelling?
        return Input.trigger?(:B) || (Mouse.trigger?(:right) && simple_mouse_in?)
      end
    end
    # Definition of the Message Window UI element
    class Window < ::Window
      include Layout
      include Transition
      include Draw
      include WaitUserInput
      include PFM::Message::Parser
      include PFM::Message::State
      # Update the window
      def update
        super unless Graphics::FPSBalancer.global.skipping?
        return update_fade_out if done_drawing_message? && $game_temp.message_text.nil?
        return start_drawing if need_to_show_message?
        return wait_user_input if need_to_wait_user_input?
        update_draw
      ensure
        update_fade_in
      end
      private
      # Get the width computer of this window
      # @return [PFM::Message::WidthComputer]
      def width_computer
        if !@width_computer || @width_computer.disposed?
          normal_text = Text.new(current_layout.default_font, viewport, 0, 0, 0, default_line_height, ' ')
          big_text = Text.new(1, viewport, 0, 0, 0, default_line_height * 2, ' ')
          @width_computer = PFM::Message::WidthComputer.new(normal_text, big_text)
        end
        return @width_computer
      end
    end
  end
end
module GamePlay
  # Module responsive of adding the display message functionality to a class
  module DisplayMessage
    # Message the displays when a GamePlay scene has been initialized without message processing and try to display a message
    MESSAGE_ERROR = 'This interface has no MessageWindow, you cannot call display_message'
    # Error message when display_message is called from "itself"
    MESSAGE_PROCESS_ERROR = 'display_message was called inside display_message. Please fix your scene update.'
    # The message window
    # @return [UI::Message::Window, nil]
    attr_reader :message_window
    # Prevent the update to process if the message are still processing
    # @return [Boolean]
    def message_processing?
      @message_window&.showing_message?
    end
    # Tell if the display_message function can be called
    # @return [Boolean]
    def can_display_message_be_called?
      !@still_in_display_message
    end
    # Force the message window to "close" (but does not update scene)
    # @yield yield to allow some process before updating the message window
    def close_message_window
      return unless @message_window
      while message_processing?
        Graphics.update
        yield if block_given?
        @message_window.update
      end
    end
    # Return the message class used
    # @return [Class<UI::Message::Window>]
    def message_class
      UI::Message::Window
    end
    # Set the visibility of message
    # @param visible [Boolean]
    def message_visible=(visible)
      return unless @message_window
      @message_window.viewport.visible = visible
    end
    # Get the visibility of message
    # @return [Boolean]
    def message_visible
      return false unless @message_window
      @message_window.viewport.visible
    end
    # Display a message with choice or not
    # @param message [String] the message to display
    # @param start [Integer] the start choice index (1..nb_choice)
    # @param choices [Array<String>] the list of choice options
    # @param block [Proc] block to call while message updates
    # @return [Integer, nil] the choice result
    def display_message(message, start = 1, *choices, &block)
      raise ScriptError, MESSAGE_ERROR unless @message_window
      raise ScriptError, MESSAGE_PROCESS_ERROR unless @message_done_processing && can_display_message_be_called?
      block ||= @__display_message_proc
      setup_message_display(message, start, choices)
      until @message_done_processing
        message_update_scene
        block&.call
      end
      Graphics.update
      return @message_choice
    ensure
      @still_in_display_message = false
    end
    # Display a message with choice or not. This method will wait the message window to disappear
    # @param message [String] the message to display
    # @param start [Integer] the start choice index (1..nb_choice)
    # @param choices [Array<String>] the list of choice options
    # @param block [Proc] block to call while message updates
    # @return [Integer, nil] the choice result
    def display_message_and_wait(message, start = 1, *choices, &block)
      block ||= @__display_message_proc
      choice = display_message(message, start, *choices, &block)
      @still_in_display_message = true
      close_message_window(&block)
      return choice
    ensure
      @still_in_display_message = false
    end
    private
    # Initialize the window related interface of the UI
    # @param no_message [Boolean] if the scene is created wihout the message management
    # @param message_z [Integer] the z superiority of the message
    # @param message_viewport_args [Array] if empty : [:main, message_z] will be used.
    def message_initialize(no_message, message_z, message_viewport_args)
      return if no_message
      message_viewport_args = [:main, message_z] if message_viewport_args.empty?
      @message_window = message_class.new(Viewport.create(*message_viewport_args), self)
      @message_window.z = message_z
      @message_done_processing = true
      @still_in_display_message = false
    end
    # Setup the message display
    # @param message [String]
    # @param start [Integer] the start choice index (1..nb_choice)
    # @param choices [Array<String>] the list of choice options
    def setup_message_display(message, start, choices)
      @message_done_processing = false
      @still_in_display_message = true
      @message_choice = nil
      $game_system.map_interpreter.instance_variable_set(:@message_waiting, true) if (was_scene_map = $scene.is_a?(Scene_Map))
      $game_temp.message_text = message
      $game_temp.message_proc = proc do
        @message_done_processing = true
        $game_system.map_interpreter.instance_variable_set(:@message_waiting, false) if was_scene_map
      end
      if choices.any?
        $game_temp.choice_max = choices.size
        $game_temp.choice_cancel_type = choices.size
        $game_temp.choice_proc = proc { |i| @message_choice = i }
        $game_temp.choice_start = start
        $game_temp.choices = choices
      end
    end
    # Update the message
    def message_update
      message_window&.update
    end
    # Update the scene inside the message waiting loop
    # @note this internally calls message_update
    def message_update_scene
      Graphics.update
      respond_to?(:update) ? update : message_update
    end
    # Dispose the message
    def message_dispose
      return unless @message_window
      @message_window.dispose(with_viewport: true)
      @message_window = nil
    end
    # Function performing some tests to prevent softlock from messages at certain points
    def message_soft_lock_prevent
      if $game_temp.message_window_showing
        log_error('Message were still showing!')
        $game_temp.message_window_showing = false
      end
    end
  end
  class Base
    include DisplayMessage
  end
end
