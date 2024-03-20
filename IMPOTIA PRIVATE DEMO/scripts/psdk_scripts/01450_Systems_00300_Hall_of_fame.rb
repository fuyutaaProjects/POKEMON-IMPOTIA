module PFM
  # Class describing the Hall_of_Fame logic
  class Hall_of_Fame
    # Array containing every victory of the player
    # @return [Array]
    attr_accessor :player_victory
    # Get the game state responsive of the whole game state
    # @return [PFM::GameState]
    attr_accessor :game_state
    # Create a new hall of fame
    # @param game_state [PFM::GameState] variable responsive of containing the whole game state for easier access
    def initialize(game_state = PFM.game_state)
      @player_victory = []
      @game_state = game_state
    end
    # Register a win in the Pokemon League for the player
    # @param mode [Symbol] the symbol designing the type of victory : possible victory are :league and :title_defense
    def register_victory(mode = :league)
      pokemon_array = []
      @game_state.actors.each { |pkm| pokemon_array << pkm.clone }
      victory = {mode: mode, team: pokemon_array, play_time: PFM.game_state.trainer.play_time_text, entry_date: Time.new}
      @player_victory << victory
    end
  end
  class GameState
    # The list of the victory in the Pokemon League
    # @return [PFM::Hall_of_Fame]
    attr_accessor :hall_of_fame
    on_player_initialize(:hall_of_fame) {@hall_of_fame = PFM.hall_of_fame_class.new(self) }
    on_expand_global_variables(:hall_of_fame) do
      @hall_of_fame ||= PFM.hall_of_fame_class.new(self)
      @hall_of_fame.game_state = self
    end
  end
end
PFM.hall_of_fame_class = PFM::Hall_of_Fame
module UI
  # Module holding the Hall of fame UI elements
  module Hall_of_Fame
    # The class that define the type background displayed during phase 1
    class Type_Background < SpriteStack
      # The non-translucent backgrounds
      # @return [Array<Sprite>]
      attr_accessor :type_foregrounds
      # The translucent backgrounds
      # @return [Array<Sprite>]
      attr_accessor :type_backgrounds
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @type_backgrounds = Array.new($actors.size) {add_sprite(*foreground_pos, NO_INITIAL_IMAGE) }
        @type_foregrounds = Array.new($actors.size) {add_sprite(*foreground_pos, NO_INITIAL_IMAGE) }
        $actors.each_with_index do |pkm, index|
          @type_foregrounds[index].set_bitmap('hall_of_fame/' + pkm.type1.to_s, :interface).opacity = 0
          @type_backgrounds[index].set_bitmap('hall_of_fame/' + pkm.type1.to_s, :interface).opacity = 0
        end
      end
      private
      # The initial position of the foregrounds
      # @return [Array<Integer>] the coordinates
      def foreground_pos
        return 0, 0
      end
      # The initial position of the backgrounds
      # @return [Array<Integer>] the coordinates
      def background_move
        return 0, 0
      end
    end
    # Class that define the stack containing the Pokemon's battlers
    class Pokemon_Battler_Stack < SpriteStack
      # All the colors based on 1st type of the creature
      COLORS = [[0, 0, 0, 255], [188, 187, 187, 255], [224, 56, 24, 255], [8, 124, 248, 255], [248, 208, 64, 255], [32, 192, 80, 255], [125, 186, 228, 255], [190, 74, 39, 255], [178, 74, 155, 255], [183, 122, 36, 255], [78, 176, 228, 255], [212, 108, 170, 255], [176, 213, 115, 255], [173, 126, 94, 255], [136, 111, 186, 255], [75, 155, 217, 255], [172, 178, 188, 255], [184, 85, 140, 255], [221, 139, 180, 255]]
      # X Left
      X_LEFT = -48
      # X Right
      X_RIGHT = 78
      # X Right color
      X_COLOR_RIGHT = 88
      # The Array containing every back sprites of the player team
      # @return [Array<UI::PokemonBackSprite>]
      attr_accessor :battlebacks
      # The Array containing every front sprites of the player team
      # @return [Array<UI::PokemonFaceSprite>]
      attr_accessor :battlefronts
      # The Array containing every colored back sprites of the player team
      # @return [Array<Sprite::WithColor>]
      attr_accessor :withcolorbacks
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @withcolorbacks = Array.new($actors.size) {add_sprite(*withcolor_initial_pos, NO_INITIAL_IMAGE, type: Sprite::WithColor) }
        @battlebacks = Array.new($actors.size) {add_sprite(*back_initial_pos, NO_INITIAL_IMAGE, type: PokemonBackSprite) }
        @battlefronts = Array.new($actors.size) {add_sprite(*front_initial_pos, NO_INITIAL_IMAGE, type: PokemonFaceSprite) }
        $actors.each_with_index do |pkm, index|
          @battlebacks[index].data = pkm
          @battlefronts[index].data = pkm
          @withcolorbacks[index].set_bitmap(@battlefronts[index].bitmap)
          set_origin_withcolorbacks
          r, g, b, a = COLORS[pkm.type1]
          @withcolorbacks[index].set_color(Color.new(r, g, b, a))
        end
      end
      private
      # The initial position of the back battlers
      # @return [Array<Integer>] the coordinates
      def back_initial_pos
        return 368, 220
      end
      # The initial position of the front battlers
      # @return [Array<Integer>] the coordinates
      def front_initial_pos
        return -48, 220
      end
      # The initial position of the colored shadows
      # @return [Array<Integer>] the coordinates
      def withcolor_initial_pos
        return -96, 220
      end
      # Set the correct origin for each Sprite::WithColor
      def set_origin_withcolorbacks
        @withcolorbacks.each_with_index do |sprite, index|
          sprite.set_origin(@battlefronts[index].ox, @battlefronts[index].oy)
        end
      end
    end
    # Class that define the Star Animation
    class Star_Animation < SpriteSheet
      # The counter for the animation
      # @return [Integer]
      attr_accessor :counter
      # Tell if the animation is finished or not
      # @return [Boolean]
      attr_accessor :finished
      # Initialize the SpriteSheet
      # @param viewport [Viewport]
      # @param frame_count [Integer] how many frames between each anim update
      # @param repeat [Boolean] if the animation has to repeat itself
      def initialize(viewport, frame_count = 2, repeat: false)
        super(viewport, 6, 1)
        set_bitmap('hall_of_fame/stars', :interface)
        set_position(x, y)
        self.opacity = 0
        @frame_count = frame_count
        @repeat = repeat
        @finished = false
        @counter = 0
        @reversing = false
      end
      # Update the animation depending on the @frame_count
      def update
        return if @finished
        if @counter == @frame_count
          @counter = 0
          if @reversing == true
            self.sx -= 1
            if self.sx == 0
              self.opacity = 0
              @reversing = false
              @finished = true if !@repeat
            end
          else
            if @reversing == false
              self.opacity = 255 if self.sx == 0
              self.sx += 1
              @reversing = true if self.sx == 5
            end
          end
        end
        @counter += 1
      end
    end
    # Class that define the Pokemon text box stack
    class Pokemon_Text_Box < SpriteStack
      # White color
      WHITE_COLOR = Color.new(255, 255, 255)
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      # @param pkm [PFM::Pokemon] the Pokemon's data
      def initialize(viewport, pkm)
        super(viewport, *spritesheet_coordinates)
        @box = add_sprite(0, 0, bmp_filename, 1, number_of_types, type: SpriteSheet)
        @box.mirror = true
        @box.sy = pkm.type1
        @name_text = add_text(*name_text_coordinates, pkm.given_name)
        @name_text.fill_color = WHITE_COLOR
        @name_text.draw_shadow = false
        @lvl_text = add_text(*lvl_text_coordinates, parse_text(27, 29) + " #{pkm.level}", 2)
        @lvl_text.fill_color = WHITE_COLOR
        @lvl_text.draw_shadow = false
      end
      # The base filename of the window
      # @return [String]
      def bmp_filename
        'hall_of_fame/type_window'
      end
      # The base coordinates of the name text
      # @return [Array<Integer>] the coordinates
      def name_text_coordinates
        return 8, 5, 98, 16
      end
      # The base coordinates of the level text
      # @return [Array<Integer>] the coordinates
      def lvl_text_coordinates
        return 121, 5, 35, 16
      end
      # Get the width of the box
      # @return [Integer] the width of the box sprite
      def width
        @box.width
      end
      # Check how many types the game has
      # @return [Integer] the number of types
      def number_of_types
        return each_data_type.size
      end
      # The SpriteStack initial coordinates
      # @return [Array<Integer>] the coordinates
      def spritesheet_coordinates
        return 320, 200
      end
    end
    # Class that define the Congratulation text box stack
    class Congratulation_Text_Box < SpriteStack
      # White color
      WHITE_COLOR = Color.new(255, 255, 255)
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      # @param pkm [PFM::Pokemon] the Pokemon's data
      def initialize(viewport, pkm)
        super(viewport, *spritesheet_coordinates)
        @box = add_sprite(0, 0, bmp_filename, 1, number_of_types, type: SpriteSheet)
        @box.sy = pkm.type1
        @text = add_text(*text_coordinates, parse_text(32, 109))
        @text.fill_color = WHITE_COLOR
        @text.draw_shadow = false
      end
      # The base filename of the window
      # @return [String]
      def bmp_filename
        'hall_of_fame/type_window'
      end
      # The base coordinates of the text
      # @return [Array<Integer>] the coordinates
      def text_coordinates
        return 28, 5, 152, 16
      end
      # Check how many types the game has
      # @return [Integer] the number of types
      def number_of_types
        return each_data_type.size
      end
      # Get the width of the box
      # @return [Integer] the width of the box sprite
      def width
        @box.width
      end
      # The SpriteStack initial coordinates
      # @return [Array<Integer>] the coordinates
      def spritesheet_coordinates
        return -184, 20
      end
    end
    # Class that define the Pokemon Stars animation
    class Pokemon_Stars_Animation < SpriteStack
      # All the X coordinate for the stars around Creature
      X_ARRAY = [67, 16, 90, 40, 65, 30]
      # All the Y coordinate for the stars around Creature
      Y_ARRAY = [20, 32, 90, 54, 48, 90]
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *spritestack_coordinates)
        @stars = Array.new(6) { |i| add_sprite(X_ARRAY[i], Y_ARRAY[i], NO_INITIAL_IMAGE, type: Star_Animation) }
        @anim_counter = 0
      end
      # The SpriteStack initial coordinates
      # @return [Array<Integer>] the coordinates
      def spritestack_coordinates
        return 25, 125
      end
      # Update each star animation
      def update
        @stars.each_with_index do |star, index|
          star.update if @anim_counter > (index * 10)
        end
        @anim_counter += 1
      end
      # Reset the star animation to replay it when needed
      def reset
        return if @anim_counter == 0
        @anim_counter = 0
        @stars.each do |star|
          star.finished = false
        end
      end
    end
    # Class that define the Graveyard Animation stack
    class Graveyard_Animation_Stack < SpriteStack
      # The array containing every ShaderedSprite
      # @return [Array<ShaderedSprite>]
      attr_accessor :sprites
      # The array containing every Dead_Pokemon_Text SpriteStack
      # @return [Array<UI::Hall_of_Fame::Dead_Pokemon_Text>]
      attr_accessor :text_boxes
      # Sprite X Right
      SPRITE_X_RIGHT = 422
      # Sprite X Middle
      SPRITE_X_MIDDLE = 112
      # Sprite X Left
      SPRITE_X_LEFT = -198
      # Sprite Y
      SPRITE_Y = 100
      # Box X Right
      BOX_X_RIGHT = 320
      # Box X Middle
      BOX_X_MIDDLE = 10
      # Box X Left
      BOX_X_LEFT = -300
      # Box Y
      BOX_Y = 80
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @animation = nil
        @anim_count = 0
        @graveyard = PFM.game_state.nuzlocke.graveyard
        @sprites = Array.new(@graveyard.size) {add_sprite(*initial_pos_sprites, NO_INITIAL_IMAGE, type: ShaderedSprite) }
        @shader = Shader.create(:full_shader)
        @shader.set_float_uniform('color', [1, 1, 1, 0])
        @shader.set_float_uniform('tone', [0, 0, 0, 1])
        @sprites.each_with_index do |sprite, i|
          sprite.set_bitmap(@graveyard[i].battler_face)
          sprite.shader = @shader
        end
        @text_boxes = Array.new(@graveyard.size) {Dead_Pokemon_Text.new(viewport, *initial_pos_boxes) }
        @text_boxes.each_with_index do |box, i|
          box.text = @graveyard[i]
        end
      end
      private
      # The sprites initial coordinates
      # @return [Array<Integer>] the coordinates
      def initial_pos_sprites
        return SPRITE_X_RIGHT, SPRITE_Y
      end
      # The boxes initial coordinates
      # @return [Array<Integer>] the coordinates
      def initial_pos_boxes
        return BOX_X_RIGHT, BOX_Y
      end
    end
    # Class that define the Dead Pokemon text
    class Dead_Pokemon_Text < SpriteStack
      # White Color
      WHITE_COLOR = Color.new(255, 255, 255)
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y)
        @box = add_sprite(0, 0, bmp_filename)
        @text = add_text(*text_coordinate, nil.to_s, 1)
        @text.fill_color = WHITE_COLOR
        @text.draw_shadow = false
      end
      # The base filename of the window
      # @return [String]
      def bmp_filename
        'hall_of_fame/text_window'
      end
      # The base coordinates of the text
      # @return [Array<Integer>] the coordinates
      def text_coordinate
        return 39, 5, 222, 16
      end
      # Change the text according to the data sent
      # @param pkm [PFM::Pokemon] the dead Pokemon we want the name of
      def text=(pkm)
        @text.text = ext_text(9004, 0) + ' ' + pkm.given_name
      end
    end
    # Class that define the turning Pokeball
    class Turning_Pokeball < Sprite
      # Initialize the Sprite
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        set_bitmap(bitmap_filename, :interface)
        set_origin(*new_origin)
        self.opacity = 0
      end
      # The base filename of the image
      # @return [String]
      def bitmap_filename
        return 'hall_of_fame/ball'
      end
      # The new origin of the Sprite
      # @return [Array<Integer>]
      def new_origin
        return 228, 228
      end
      # Update the angle of the ball
      def update_anim
        self.angle += 1
        self.angle = 0 if angle == 360
      end
    end
    # Class that define the Party Battler stack
    class Party_Battler_Stack < SpriteStack
      # The Array containing the front battlers of the Pokemon
      # @return [Array<UI::PokemonFaceSprite>]
      attr_accessor :pokemon_arr
      # The trainer battler
      # @return [Sprite]
      attr_accessor :trainer_battler
      # X coordinates for the party elements
      X_PARTY = [99, 221, 69, 251, 38, 282]
      # Y coordinates for the party elements
      Y_PARTY = [180, 150, 120]
      # Y coordinate for the trainer
      Y_TRAINER = 102
      # Trainer sprite filename based on its gender
      PLAYER_SPRITE_NAME = {true => 'hall_of_fame/female', false => 'hall_of_fame/male'}
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @pokemon_arr = Array.new($actors.size) { |i| add_sprite(*pkm_initial_coordinates(i), NO_INITIAL_IMAGE, type: PokemonFaceSprite) }
        @pokemon_arr.reverse!
        @trainer_battler = add_sprite(*trainer_initial_coordinates, PLAYER_SPRITE_NAME[$trainer.playing_girl])
        @pokemon_arr.each_with_index { |sprite, index| sprite.data = ($actors[index]) }
      end
      # The Pokemon initial coordinates
      # @return [Array<Integer>] the coordinates
      def pkm_initial_coordinates(index)
        x = index.even? ? -48 : 368
        y = Y_PARTY[index / 2]
        return x, y
      end
      # The trainer sprite initial coordinates
      # @return [Array<Integer>] the coordinates
      def trainer_initial_coordinates
        return 112, -96
      end
    end
    # Class that define the League Champion text box stack
    class League_Champion_Text_Box < SpriteStack
      attr_accessor :text
      # Final Y coordinate
      Y_FINAL = 10
      # White color
      WHITE_COLOR = Color.new(255, 255, 255, 255)
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *initial_coordinates)
        @box = add_sprite(0, 0, box_filename)
        @text = add_text(*text_coordinates, parse_text(32, 111), 1)
        @text.fill_color = WHITE_COLOR
        @text.draw_shadow = false
        @text.opacity = 0
      end
      # The SpriteStack initial coordinates
      # @return [Array<Integer>] the coordinates
      def initial_coordinates
        return 10, -28
      end
      # The base filename of the window
      # @return [String]
      def box_filename
        'hall_of_fame/text_window_congrats'
      end
      # Get the constant's value
      # @return [Integer]
      def y_final
        Y_FINAL
      end
      # The base coordinates of the text
      # @return [Array<Integer>] the coordinates
      def text_coordinates
        return 40, 5, 220, 16
      end
    end
    # Class that define the Trainer Infos text box stack
    class Trainer_Infos_Text_Box < SpriteStack
      # The name text
      # @return [Text]
      attr_accessor :name
      # The id_no text
      # @return [Text]
      attr_accessor :id_no
      # The play_time text
      # @return [Text]
      attr_accessor :play_time
      # Final Y coordinate
      Y_FINAL = 202
      # White color
      WHITE_COLOR = Color.new(255, 255, 255, 255)
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *initial_coordinates)
        @box = add_sprite(0, 0, box_filename)
        @name = add_text(*name_coordinates, $trainer.name, 0)
        @id_no = add_text(*id_no_coordinates, format('%<text>s %<id>05d', text: text_get(34, 2), id: $trainer.id % 100_000), 0)
        @play_time = add_text(*play_time_coordinates, PFM.game_state.trainer.play_time_text, 2, type: Text)
        @name.fill_color = WHITE_COLOR
        @name.draw_shadow = false
        @name.opacity = 0
        @id_no.fill_color = WHITE_COLOR
        @id_no.draw_shadow = false
        @id_no.opacity = 0
        @play_time.fill_color = WHITE_COLOR
        @play_time.draw_shadow = false
        @play_time.opacity = 0
      end
      # The SpriteStack initial coordinates
      # @return [Array<Integer>] the coordinates
      def initial_coordinates
        return 10, 240
      end
      # The base filename of the window
      # @return [String]
      def box_filename
        'hall_of_fame/text_window'
      end
      # Get the constant's value
      # @return [Integer]
      def y_final
        Y_FINAL
      end
      # The base coordinates of the name text
      # @return [Array<Integer>] the coordinates
      def name_coordinates
        return 42, 5, 57, 16
      end
      # The base coordinates of the id_no text
      # @return [Array<Integer>] the coordinates
      def id_no_coordinates
        return 113, 5, 88, 16
      end
      # The base coordinates of the play_time text
      # @return [Array<Integer>] the coordinates
      def play_time_coordinates
        return 202, 5, 55, 16
      end
    end
    # Class that define the End Stars animation stack
    class End_Stars_Animation < SpriteStack
      # Initialize the SpriteStack
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport)
        @stars = Array.new(20) {Star_Animation.new(viewport, 5, repeat: true) }
        @stars.each { |star| star.set_position(rand(320), rand(240)) }
        @counter = 0
      end
      # Update each star's animation
      def update
        @stars.each_with_index do |star, index|
          if star.sx == 0
            star.set_position(rand(320), rand(240))
          end
          star.update if (index * 10) <= @counter
        end
        @counter += 1
      end
    end
  end
end
module GamePlay
  class Hall_of_Fame < BaseCleanUpdate
    # The default BGM to play
    DEFAULT_BGM = 'audio/bgm/Hall-of-Fame'
    # Initialize the scene
    # @param filename_bgm [String] the bgm to play during the Hall of Fame
    # @param context_of_victory [Symbol] the symbol to put as the context of victory
    def initialize(filename_bgm = DEFAULT_BGM, context_of_victory = :league)
      super()
      @filename_bgm = filename_bgm
      @anim_count = 0
      @animation_state = 0
      @graveyard = PFM.game_state.nuzlocke.graveyard
      @nuz_anim = Graveyard_Animation_Stack
      @pkm_sprite_anim = Pokemon_Battler_Stack
      @parallel_update = false
      PFM.game_state.hall_of_fame.register_victory(context_of_victory)
      play_music
    end
    # Play the music, nothing else
    def play_music
      Audio.bgm_play(@filename_bgm) unless @filename_bgm.empty?
    end
    # Get the cry's filename of the Pokemon at index equal to @anim_count
    # @return [String] the filename of the cry
    def pkm_cry_filename
      str = $actors[@anim_count].cry.sub('Audio/SE/', '')
      return str
    end
    include UI::Hall_of_Fame
    # Create the graphics for the UI
    def create_graphics
      super()
      create_background
      create_type_background
      create_pokemon_battler_stack
      create_pokemon_text_boxes
      create_congratulation_text_boxes
      create_pokemon_stars_animation
      create_graveyard_anim
      create_turning_ball
      create_party_battler_stack
      create_league_champion_text_box
      create_trainer_infos_text_box
      create_end_stars
    end
    # Launch each phase of the animation then update the looping animations
    def update_graphics
      case @animation_state
      when 0
        animation_phase_1
      when 1
        if PFM.game_state.nuzlocke.enabled? && !@graveyard.empty?
          animation_phase_2
        else
          @animation_state += 1
        end
      when 2
        animation_phase_3
      when 3
        update_turning_ball
        update_end_stars_anim
      end
    end
    # Create the background
    def create_background
      @background = Sprite.new(@viewport)
      @background.set_bitmap('hall_of_fame/black_background', :interface)
    end
    # Create the type background that is displayed during phase 1
    def create_type_background
      @type_background = Type_Background.new(@viewport)
    end
    # Create the stack containing the Pokemon's battler that is displayed during phase 1
    def create_pokemon_battler_stack
      @pkm_battler_stack = Pokemon_Battler_Stack.new(@viewport)
    end
    # Create the stars animation that is displayed during phase 1
    def create_pokemon_stars_animation
      @pkm_stars_anim = Pokemon_Stars_Animation.new(@viewport)
    end
    # Update the stars animation (only during phase 1, updated by launch_animation)
    def update_pokemon_stars_animation
      @pkm_stars_anim.update
    end
    # Create the boxes containing the text about the Pokemon that are displayed during phase 1
    def create_pokemon_text_boxes
      @pkm_text_boxes = []
      $actors.each do |pkm|
        @pkm_text_boxes << Pokemon_Text_Box.new(@viewport, pkm)
      end
    end
    # Create the congratulations boxes that are displayed during phase 1
    def create_congratulation_text_boxes
      @congrats_text_boxes = []
      $actors.each do |pkm|
        @congrats_text_boxes << Congratulation_Text_Box.new(@viewport, pkm)
      end
    end
    # Create the stack that contains everything needed for phase 2 animation
    def create_graveyard_anim
      @graveyard_stack = Graveyard_Animation_Stack.new(@viewport)
    end
    # Create the turning ball that is displayed during phase 3
    def create_turning_ball
      @ball = Turning_Pokeball.new(@viewport)
    end
    # Update the turning ball animation during phase 3 and after
    def update_turning_ball
      @ball.update_anim
    end
    # Create the stack containing every battlers displayed during phase 3
    def create_party_battler_stack
      @party_battler = Party_Battler_Stack.new(@viewport)
    end
    # Create the box containing the league champion text displayed during phase 3
    def create_league_champion_text_box
      @league_champ_box = League_Champion_Text_Box.new(@viewport)
    end
    # Create the box containing the trainer texts displayed during phase 3
    def create_trainer_infos_text_box
      @trainer_infos_box = Trainer_Infos_Text_Box.new(@viewport)
    end
    # Create the final stars animation that is displayed after phase 3
    def create_end_stars
      @end_stars_anim = End_Stars_Animation.new(@viewport)
    end
    # Update the final stars animation after phase 3
    def update_end_stars_anim
      @end_stars_anim.update
    end
    # Launch the given animation
    # @param animation [Yuki::Animation] the animation to run
    def launch_animation(animation)
      animation.start
      until animation.done?
        parallel_animating if @parallel_update
        animation.update
        Graphics.update
      end
    end
    # Update some parallel animation if the context demand it
    def parallel_animating
      if @animation_state == 0
        update_pokemon_stars_animation
      else
        if @animation_state == 2
          update_turning_ball
        end
      end
    end
    private
    def animation_phase_1
      @anim_count = 0
      launch_animation(p1_anim_1)
      until @anim_count == $actors.size
        launch_animation(p1_anim_2(p1_resolver_anim_2))
        launch_animation(p1_anim_3(p1_resolver_anim_3))
        launch_animation(p1_anim_4(p1_resolver_anim_4))
        @parallel_update = true
        launch_animation(p1_anim_5(p1_resolver_anim_5))
        @parallel_update = false
        @pkm_stars_anim.reset
        launch_animation(p1_anim_6(p1_resolver_anim_6))
        launch_animation(p1_anim_7(p1_resolver_anim_7))
        @anim_count += 1
      end
      @animation_state += 1
    end
    def p1_resolver_anim_2
      resolver = {sprite_from_x: @pkm_battler_stack.battlebacks[@anim_count].x, sprite_from_y: @pkm_battler_stack.battlebacks[@anim_count].y, sprite_to_x: @pkm_sprite_anim::X_LEFT, sprite: @pkm_battler_stack.battlebacks[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_resolver_anim_3
      resolver = {up_box_from_x: @congrats_text_boxes[@anim_count].x, up_box_from_y: @congrats_text_boxes[@anim_count].y, up_box_to_x: @congrats_text_boxes[@anim_count].x + @congrats_text_boxes[@anim_count].width, up_box: @congrats_text_boxes[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_resolver_anim_4
      type2_to_opacity = $actors[@anim_count].type1 == 10 ? 0 : 127
      resolver = {down_box_from_x: @pkm_text_boxes[@anim_count].x, down_box_from_y: @pkm_text_boxes[@anim_count].y, down_box_to_x: @pkm_text_boxes[@anim_count].x - @pkm_text_boxes[@anim_count].width, down_box: @pkm_text_boxes[@anim_count], type_from_opacity: @type_background.type_foregrounds[@anim_count].opacity, type_to_opacity: 127, type: @type_background.type_foregrounds[@anim_count], type2_from_opacity: @type_background.type_backgrounds[@anim_count].opacity, type2_to_opacity: type2_to_opacity, type2: @type_background.type_backgrounds[@anim_count], sprite_from_x: @pkm_battler_stack.battlefronts[@anim_count].x, sprite_from_y: @pkm_battler_stack.battlefronts[@anim_count].y, sprite_to_x: @pkm_sprite_anim::X_RIGHT, sprite: @pkm_battler_stack.battlefronts[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_resolver_anim_5
      resolver = {sprite2_from_x: @pkm_battler_stack.battlefronts[@anim_count].x, sprite2_from_y: @pkm_battler_stack.withcolorbacks[@anim_count].y, sprite2_to_x: @pkm_sprite_anim::X_COLOR_RIGHT, sprite2: @pkm_battler_stack.withcolorbacks[@anim_count], type2_from_x: @type_background.type_backgrounds[@anim_count].x, type2_from_y: @type_background.type_backgrounds[@anim_count].y, type2_to_x: @type_background.type_backgrounds[@anim_count].x - 15, type2_to_x2: @type_background.type_backgrounds[@anim_count].x - 20, type2: @type_background.type_backgrounds[@anim_count], sound: pkm_cry_filename}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_resolver_anim_6
      resolver = {type2_from_x: @type_background.type_backgrounds[@anim_count].x, type2_from_y: @type_background.type_backgrounds[@anim_count].y, type2_to_x: @type_background.type_backgrounds[@anim_count].x - 5, type2: @type_background.type_backgrounds[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_resolver_anim_7
      resolver = {type_from_opacity: @type_background.type_foregrounds[@anim_count].opacity, type_to_opacity: 0, type: @type_background.type_foregrounds[@anim_count], up_box_from_x: @congrats_text_boxes[@anim_count].x, up_box_from_y: @congrats_text_boxes[@anim_count].y, up_box_to_x: @congrats_text_boxes[@anim_count].x - @congrats_text_boxes[@anim_count].width, up_box: @congrats_text_boxes[@anim_count], down_box_from_x: @pkm_text_boxes[@anim_count].x, down_box_from_y: @pkm_text_boxes[@anim_count].y, down_box_to_x: @pkm_text_boxes[@anim_count].x + @pkm_text_boxes[@anim_count].width, down_box: @pkm_text_boxes[@anim_count], sprite_from_x: @pkm_battler_stack.battlefronts[@anim_count].x, sprite_from_y: @pkm_battler_stack.battlefronts[@anim_count].y, sprite_to_x: @pkm_sprite_anim::X_LEFT, sprite: @pkm_battler_stack.battlefronts[@anim_count], sprite2_from_x: @pkm_battler_stack.withcolorbacks[@anim_count].x, sprite2_from_y: @pkm_battler_stack.withcolorbacks[@anim_count].y, sprite2_to_x: @pkm_sprite_anim::X_LEFT, sprite2: @pkm_battler_stack.withcolorbacks[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p1_anim_1
      animation = Yuki::Animation.instance_eval {wait(2) }.root
      return animation
    end
    def p1_anim_2(resolver)
      animation = Yuki::Animation.instance_eval {move(0.5, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) }.root
      animation.resolver = resolver
      return animation
    end
    def p1_anim_3(resolver)
      animation = Yuki::Animation.instance_eval {move_discreet(0.2, :up_box, :up_box_from_x, :up_box_from_y, :up_box_to_x, :up_box_from_y) }.root
      animation.resolver = resolver
      return animation
    end
    def p1_anim_4(resolver)
      animation = Yuki::Animation.instance_eval {move_discreet(0.2, :down_box, :down_box_from_x, :down_box_from_y, :down_box_to_x, :down_box_from_y) | opacity_change(0.2, :type, :type_from_opacity, :type_to_opacity) >> opacity_change(0.2, :type2, :type2_from_opacity, :type2_to_opacity) > opacity_change(0.5, :type, 127, 255) | move(0.2, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) | se_play('hall_of_fame_sound') }.root
      animation.resolver = resolver
      return animation
    end
    def p1_anim_5(resolver)
      sound = pkm_cry_filename
      animation = Yuki::Animation.instance_eval {se_play(sound) | move(1, :sprite2, :sprite2_from_x, :sprite2_from_y, :sprite2_to_x, :sprite2_from_y) | move(1.5, :type2, :type2_from_x, :type2_from_y, :type2_to_x, :type2_from_y) }.root
      animation.resolver = resolver
      return animation
    end
    def p1_anim_6(resolver)
      animation = Yuki::Animation.instance_eval {opacity_change(0.5, :type2, 127, 0) | move(0.5, :type2, :type2_from_x, :type2_from_y, :type2_to_x, :type2_from_y) > wait(1) }.root
      animation.resolver = resolver
      return animation
    end
    def p1_anim_7(resolver)
      animation = Yuki::Animation.instance_eval {opacity_change(0.5, :type, :type_from_opacity, :type_to_opacity) > move(0.2, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) | move(0.25, :sprite2, :sprite2_from_x, :sprite2_from_y, :sprite2_to_x, :sprite2_from_y) > move_discreet(0.2, :down_box, :down_box_from_x, :down_box_from_y, :down_box_to_x, :down_box_from_y) > move_discreet(0.2, :up_box, :up_box_from_x, :up_box_from_y, :up_box_to_x, :up_box_from_y) > wait(0.3) }.root
      animation.resolver = resolver
      return animation
    end
    public
    private
    def animation_phase_2
      @anim_count = 0
      until @anim_count == @graveyard.size + 1
        case @anim_count
        when 0
          launch_animation(p2_anim_1(p2_resolver_anim_1.method(:fetch)))
        when @graveyard.size
          launch_animation(p2_anim_3(p2_resolver_anim_3.method(:fetch)))
        else
          launch_animation(p2_anim_2_repeat(p2_resolver_anim_2_repeat.method(:fetch)))
        end
        @anim_count += 1
      end
      @animation_state += 1
    end
    def p2_resolver_anim_1
      resolver = {sprite_from_x: @graveyard_stack.sprites[@anim_count].x, sprite_from_y: @graveyard_stack.sprites[@anim_count].y, sprite_to_x: @nuz_anim::SPRITE_X_MIDDLE, sprite: @graveyard_stack.sprites[@anim_count], box_from_x: @graveyard_stack.text_boxes[@anim_count].x, box_from_y: @graveyard_stack.text_boxes[@anim_count].y, box_to_x: @nuz_anim::BOX_X_MIDDLE, box: @graveyard_stack.text_boxes[@anim_count]}
      return resolver
    end
    def p2_resolver_anim_2_repeat
      resolver = p2_resolver_anim_1
      more_resolver = {sprite2_from_x: @graveyard_stack.sprites[@anim_count - 1].x, sprite2_from_y: @graveyard_stack.sprites[@anim_count - 1].y, sprite2_to_x: @nuz_anim::SPRITE_X_LEFT, sprite2: @graveyard_stack.sprites[@anim_count - 1], box2_from_x: @graveyard_stack.text_boxes[@anim_count - 1].x, box2_from_y: @graveyard_stack.text_boxes[@anim_count - 1].y, box2_to_x: @nuz_anim::BOX_X_LEFT, box2: @graveyard_stack.text_boxes[@anim_count - 1]}
      resolver.merge!(more_resolver)
      return resolver
    end
    def p2_resolver_anim_3
      resolver = {sprite_from_x: @graveyard_stack.sprites[@anim_count - 1].x, sprite_from_y: @graveyard_stack.sprites[@anim_count - 1].y, sprite_to_x: @nuz_anim::SPRITE_X_LEFT, sprite: @graveyard_stack.sprites[@anim_count - 1], box_from_x: @graveyard_stack.text_boxes[@anim_count - 1].x, box_from_y: @graveyard_stack.text_boxes[@anim_count - 1].y, box_to_x: @nuz_anim::BOX_X_LEFT, box: @graveyard_stack.text_boxes[@anim_count - 1]}
      return resolver
    end
    def p2_anim_1(resolver)
      animation = Yuki::Animation.instance_eval {move(1, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) | move_discreet(1, :box, :box_from_x, :box_from_y, :box_to_x, :box_from_y) > wait(2) }.root
      animation.resolver = resolver
      return animation
    end
    def p2_anim_2_repeat(resolver)
      animation = Yuki::Animation.instance_eval {move(1, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) | move_discreet(1, :box, :box_from_x, :box_from_y, :box_to_x, :box_from_y) | move(1, :sprite2, :sprite2_from_x, :sprite2_from_y, :sprite2_to_x, :sprite2_from_y) | move_discreet(1, :box2, :box2_from_x, :box2_from_y, :box2_to_x, :box2_from_y) > wait(2) }.root
      animation.resolver = resolver
      return animation
    end
    def p2_anim_3(resolver)
      animation = Yuki::Animation.instance_eval {move(1, :sprite, :sprite_from_x, :sprite_from_y, :sprite_to_x, :sprite_from_y) | move_discreet(1, :box, :box_from_x, :box_from_y, :box_to_x, :box_from_y) > wait(1) }.root
      animation.resolver = resolver
      return animation
    end
    public
    private
    def animation_phase_3
      @anim_count = 0
      launch_animation(p3_anim_1(p3_resolver_anim_1))
      @parallel_update = true
      @test = true
      launch_animation(p3_anim_2(p3_resolver_anim_2))
      @test = false
      launch_animation(p3_anim_3(p3_resolver_anim_3))
      until @anim_count == $actors.size
        launch_animation(p3_anim_4(p3_resolver_anim_4))
        @anim_count += 1
      end
      @parallel_update = false
      @animation_state += 1
    end
    def p3_resolver_anim_1
      resolver = {ball_from_opacity: @ball.opacity, ball_to_opacity: 255, ball: @ball}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p3_resolver_anim_2
      resolver = {trainer_from_x: @party_battler.trainer_battler.x, trainer_from_y: @party_battler.trainer_battler.y, trainer_to_y: Party_Battler_Stack::Y_TRAINER, trainer: @party_battler.trainer_battler, box_from_x: @league_champ_box.x, box_from_y: @league_champ_box.y, box_to_y: @league_champ_box.y_final, box: @league_champ_box, box2_from_x: @trainer_infos_box.x, box2_from_y: @trainer_infos_box.y, box2_to_y: @trainer_infos_box.y_final, box2: @trainer_infos_box}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p3_resolver_anim_3
      resolver = {text_from_opacity: 0, text_to_opacity: 255, text: @league_champ_box.text, text2: @trainer_infos_box.name, text3: @trainer_infos_box.id_no, text4: @trainer_infos_box.play_time}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p3_resolver_anim_4
      resolver = {pokemon_from_x: @party_battler.pokemon_arr[@anim_count].x, pokemon_from_y: @party_battler.pokemon_arr[@anim_count].y, pokemon_to_x: Party_Battler_Stack::X_PARTY[@anim_count], pokemon_to_y: Party_Battler_Stack::Y_PARTY[@anim_count / 2], pokemon: @party_battler.pokemon_arr[@anim_count]}
      resolver = resolver.method(:fetch)
      return resolver
    end
    def p3_anim_1(resolver)
      animation = Yuki::Animation.instance_eval {opacity_change(0.1, :ball, :ball_from_opacity, :ball_to_opacity) }.root
      animation.resolver = resolver
      return animation
    end
    def p3_anim_2(resolver)
      animation = Yuki::Animation.instance_eval {move(0.5, :trainer, :trainer_from_x, :trainer_from_y, :trainer_from_x, :trainer_to_y) > move_discreet(0.5, :box, :box_from_x, :box_from_y, :box_from_x, :box_to_y) > wait(0.1) > move_discreet(0.5, :box2, :box2_from_x, :box2_from_y, :box2_from_x, :box2_to_y) > wait(0.5) }.root
      animation.resolver = resolver
      return animation
    end
    def p3_anim_3(resolver)
      animation = Yuki::Animation.instance_eval {opacity_change(0.1, :text, :text_from_opacity, :text_to_opacity) > wait(0.3) > opacity_change(0.1, :text2, :text_from_opacity, :text_to_opacity) > wait(0.3) > opacity_change(0.1, :text3, :text_from_opacity, :text_to_opacity) > wait(0.3) > opacity_change(0.1, :text4, :text_from_opacity, :text_to_opacity) > wait(0.3) }.root
      animation.resolver = resolver
      return animation
    end
    def p3_anim_4(resolver)
      if @anim_count <= 1
        time = 0.4
      else
        if @anim_count <= 3
          time = 0.35
        else
          time = 0.3
        end
      end
      animation = Yuki::Animation.instance_eval {move(time, :pokemon, :pokemon_from_x, :pokemon_from_y, :pokemon_to_x, :pokemon_to_y) > wait(0.5) }.root
      animation.resolver = resolver
      return animation
    end
    public
    # Update the inputs only at the end of the animation
    def update_inputs
      if @animation_state == 3
        if Input.trigger?(:B) || Input.trigger?(:A)
          Audio.bgm_stop
          @running = false
        end
      end
    end
  end
end
GamePlay.hall_of_fame_class = GamePlay::Hall_of_Fame
