module UI
  module MoveTeaching
    # UI part displaying the background of the Skill Learn scene
    class BaseBackground < SpriteStack
      # Create the Background
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *background_coordinates, default_cache: :interface)
        create_background
      end
      private
      # Create the background
      def create_background
        add_background(background_name)
      end
      # @return [Array] the background coordinates
      def background_coordinates
        return 3, 8
      end
      # @return [String] the background name
      def background_name
        'skill_learn/skill_learn'
      end
    end
    # UI part displaying the Pokémon informations in the Skill Learn scene
    class PokemonInfos < SpriteStack
      # List of Pokemon that shouldn't show the gender sprite
      NO_GENDER = %i[nidoranf nidoranm]
      # Create sprite & some informations of the Pokémon
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 8, 15, default_cache: :interface)
        create_sprites
      end
      # Set the data of the Pokemon
      def data=(pokemon)
        super
        @gender.x = @name.x + @name.real_width + 2
        @gender.visible = false if NO_GENDER.include?(pokemon.db_symbol)
      end
      # Update the graphics
      def update_graphics
        @sprite.update
      end
      private
      def create_sprites
        @sprite = create_sprite
        @name = create_name
        @gender = create_gender
      end
      # @return [UI::PokemonFaceSprite]
      def create_sprite
        add_sprite(*sprite_coordinates, NO_INITIAL_IMAGE, type: UI::PokemonFaceSprite)
      end
      # @return Array of coordinates of the Pokémon face sprite
      def sprite_coordinates
        return 48, 110
      end
      # @return [SymText]
      def create_name
        add_text(*name_coordinates, :given_name, type: SymText, color: 10)
      end
      # @return Array of coordinates of the Pokémon name
      def name_coordinates
        return 3, -2, 0, 13
      end
      # @return [GenderSprite]
      def create_gender
        add_sprite(*gender_coordinates, NO_INITIAL_IMAGE, type: GenderSprite)
      end
      # @return Array of coordinates of the Pokémon gender
      def gender_coordinates
        return 2, 0
      end
    end
    # UI part displaying the Skill description in the Skill Learn scene
    class SkillDescription < SpriteStack
      # Create informations of the hovered skill
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 114, 16, default_cache: :interface)
        create_texts
      end
      # Set the data of the UI
      # @param skill [PFM::Skill]
      def data=(skill)
        super
        update_infos(skill)
      end
      # Set the visibility of the UI
      # @param value [Boolean] new visibility
      def visible=(value)
        super
        @skill_info.visible = value
      end
      private
      # Update the informations of the Skill
      # @param skill [PFM::Skill]
      def update_infos(skill)
        @skill_info.each { |i| i.data = skill }
      end
      # Init the texts of the skill informations
      def create_texts
        texts = text_file_get(27)
        with_surface(0, 0, 95) do
          add_line(0, texts[3])
          add_line(1, texts[36])
          add_line(0, texts[37], dx: 1)
          add_line(1, texts[39], dx: 1)
        end
        @skill_info = SpriteStack.new(@viewport)
        @skill_info.with_surface(114, 16, 95) do
          @skill_info.add_line(0, :power_text, 2, type: SymText, color: 1, dx: 1)
          @skill_info.add_line(1, :accuracy_text, 2, type: SymText, color: 1, dx: 1)
          @skill_info.add_line(2, :description, type: SymMultilineText, color: 1).width = 195
        end
        @skill_info.push(114 + 61, 16 + 1, nil, type: TypeSprite)
        @skill_info.push(114 + 61, 16 + 17, nil, type: CategorySprite)
      end
    end
    # UI part displaying the new skill informations in the Skill Learn scene
    class NewSkill < SpriteStack
      # @return [Boolean] if the move is currently selected
      attr_reader :selected
      # Create informations of the new skill to learn
      # @param viewport [Viewport]
      # @param index [Integer]
      def initialize(viewport, index)
        super(viewport, 35, 133, default_cache: :interface)
        create_texts
        create_graphics
        @new_skill_index = index
        self.selected = false
        self.visible = false
      end
      # Set the skill data
      # @param skill [PFM::Skill]
      def data=(skill)
        super
        @selector.visible = @selected
      end
      # Set the visibility of the sprite
      # @param value [Boolean] new visibility
      def visible=(value)
        super(value && @data)
        @selector.visible = @selected
      end
      # Get the visibility of the sprite
      # @return [Boolean]
      def visible
        return @stack[1].visible
      end
      # Define if the skill is selected
      # @param selected [Boolean]
      def selected=(selected)
        @selected = selected
        @selector.visible = selected
      end
      private
      # Create the texts of the new skill to learn
      def create_texts
        @new = add_text(*new_text_coordinates, new_text, color: 10)
        @name = add_text(*name_coordinates, :name, type: SymText)
        @pp_text = add_text(*pp_text_coordinates, text_get(27, 32))
        add_text(*pp_text_value_coordinates, pp_method, type: SymText)
      end
      # @return Array of coordinates of the "New" text
      def new_text_coordinates
        return 6, 2, 0, 14
      end
      # Return the "New" text
      def new_text
        return ext_text(9004, 1)
      end
      # @return Array of coordinates of the Skill name
      def name_coordinates
        return 66, 3, 0, 14
      end
      # @return Array of coordinates of the Skill pp text
      def pp_text_coordinates
        return 194 + 40, 3, 0, 14
      end
      # @return Array of coordinates of the Skill pp text value
      def pp_text_value_coordinates
        return 194, 3, 0, 14
      end
      # Create some graphics of the new skill to learn
      def create_graphics
        @selector = push(61, -2, new_selector_name, type: Sprite::WithColor)
        stack.rotate!(-1)
        @type = add_sprite(*type_coordinates, nil, type: TypeSprite)
      end
      # @return Array of coordinates of the Skill type
      def type_coordinates
        return 155, 2
      end
      # Return the name of the new_selector file
      # @return [String]
      def new_selector_name
        'skill_learn/new_move_selector'
      end
      # Return the name of the method used to get the PP text
      # @return [Symbol]
      def pp_method
        :pp_text
      end
    end
    # UI part displaying a Skill in the Skill Learn UI
    class Skill < SpriteStack
      # Array describing the various coordinates of the skills in the UI
      FINAL_COORDINATES = [[28, 156], [174, 156], [28, 188], [174, 188]]
      # Color when it's selected
      FORGET_COLOR = Color.new(0, 200, 0, 255)
      # Color when it's not selected
      NORMAL_COLOR = Color.new(0, 0, 0, 0)
      # @return [Boolean] if the move is currently selected
      attr_reader :selected
      # @return [Boolean] if the move is currently being moved
      attr_reader :forget
      # Create a new Skill
      # @param viewport [Viewport]
      # @param index [Integer] index of the skill in the UI
      def initialize(viewport, index)
        super(viewport, *FINAL_COORDINATES[index % FINAL_COORDINATES.size], default_cache: :interface)
        create_graphics
        create_texts
        @selected = false
        self.forget = false
        @skill_index = index
        self.visible = false
      end
      # Set the skill data
      # @param skill [PFM::Skill]
      def data=(skill)
        super
        return unless (self.visible = skill ? true : false)
        @selector.visible = @selected
        self.forget = false
      end
      # Set the visibility of the sprite
      # @param value [Boolean] new visibility
      def visible=(value)
        super(value && @data)
        @selector.visible = value && (@selected || @forget)
      end
      # Get the visibility of the sprite
      # @return [Boolean]
      def visible
        return @stack[1].visible
      end
      # Define if the skill is selected
      # @param selected [Boolean]
      def selected=(selected)
        @selected = selected
        @selector.visible = selected || @forget
      end
      # Define if the skill is being moved
      # @param forget [Boolean]
      def forget=(forget)
        @forget = forget
        if forget
          @selector.visible = true
          @selector.set_color(FORGET_COLOR)
        else
          @selector.visible = @selected
          @selector.set_color(NORMAL_COLOR)
        end
      end
      private
      # Create the texts of the skill
      def create_texts
        @name = add_text(*name_coordinates, :name, type: SymText)
        @pp_text = add_text(*pp_text_coordinates, text_get(27, 32))
        add_text(*pp_text_value_coordinates, pp_method, type: SymText, color: 1)
      end
      # @return Array of coordinates of the Skill name
      def name_coordinates
        return 34, 1, 0, 16
      end
      # @return Array of coordinates of the Skill pp text
      def pp_text_coordinates
        return 34 + 40, 18, 0, 16
      end
      # @return Array of coordinates of the Skill pp text value
      def pp_text_value_coordinates
        return 34, 18, 0, 16
      end
      # Create some graphics of the new skill to learn
      def create_graphics
        @selector = push(-8, 0, selector_name, type: Sprite::WithColor)
        @type = add_sprite(*type_coordinates, nil, type: TypeSprite)
      end
      # @return Array of coordinates of the Skill type
      def type_coordinates
        return 0, 2
      end
      # Return the name of the selector file
      # @return [String]
      def selector_name
        'skill_learn/move_selector'
      end
      # Return the name of the method used to get the PP text
      # @return [Symbol]
      def pp_method
        :pp_text
      end
    end
  end
end
module GamePlay
  # Module defining the IO of the move teaching scene so user know what to expect
  module MoveTeachingMixin
    # Tell if the move was learnt or not
    # @return [Boolean]
    attr_accessor :learnt
  end
  # Scene responsive of teaching a move to a Pokemon
  #
  # How to call it ?
  #   This scene has a return parameter called `learnt` telling wether the move has been learnt or not.
  #   You might use call_scene like this for this Scene:
  #     call_scene(GamePlay::MoveTeaching, pokemon, move_id) { |scene| do something with scene.learnt }
  class MoveTeaching < BaseCleanUpdate::FrameBalanced
    include UI::MoveTeaching
    include MoveTeachingMixin
    # Create a new Skill Learn scene
    # param pokemon [PFM::Pokemon]
    # param skill [Integer] or [Symbol]
    def initialize(pokemon, skill_id)
      super()
      @pokemon = pokemon
      @skill_id = skill_id
      @skill_learn = PFM::Skill.new(@skill_id)
      @skill_set_not_full = @pokemon.skills_set.size < 4
      @skills = @pokemon.skills_set
      @index = 4
      @learnt = false
      @state = :start
      @running = true
    end
    include UI::MoveTeaching
    # Update the graphics every frame
    def update_graphics
    end
    # Create the differents graphics of the UI
    def create_graphics
      super()
      create_background
      create_window
      create_pokemon_infos
      create_skill_description
      create_skills
      self.ui_visibility = false
    end
    # Set the visibility ON
    def ui_visibility=(visible)
      @base_ui.visible = visible
      @pokemon_infos.visible = visible
      @skill_description.visible = visible
      @skill_set.each { |sprite| sprite.visible = visible }
    end
    private
    # Create the background
    def create_background
      add_disposable @background = UI::BlurScreenshot.new(@viewport, @__last_scene)
    end
    # Create the window background
    def create_window
      @base_ui = BaseBackground.new(@viewport)
    end
    # Create the Pokemon infos
    def create_pokemon_infos
      @pokemon_infos = PokemonInfos.new(@viewport)
    end
    # Create the Skill description view
    def create_skill_description
      @skill_description = SkillDescription.new(@viewport)
    end
    # Create the Skills (new one + skill_set)
    def create_skills
      create_skill_set
      create_new_skill
    end
    # Create the New skill view
    def create_new_skill
      @skill_set[4] = NewSkill.new(@viewport, 4)
    end
    # Create the Skillset
    def create_skill_set
      @skill_set = Array.new(4) { |index| Skill.new(@viewport, index) }
    end
    public
    # List of methds associated to the inputs
    AIU_KEY2METHOD = {UP: :action_up, DOWN: :action_down, LEFT: :action_left, RIGHT: :action_right, A: :action_a, B: :action_b}
    # Update inputs every frame
    def update_inputs
      return message_start if @state == :start
      return false unless @state == :move_choice
      return update_buttons_inputs
    end
    private
    # Update buttons inputs
    def update_buttons_inputs
      old_index = @index
      unless automatic_input_update(AIU_KEY2METHOD)
        swap_buttons(old_index)
        return false
      end
      return true
    end
    # Swap the button selection state
    # @param old_index [Integer] previous index to make that button "not selected"
    def swap_buttons(old_index)
      @skill_set[old_index].selected = false
      @skill_set[@index].selected = true
      @skill_description.data = @index < 4 ? @pokemon.skills_set[@index] : @skill_learn
    end
    # Action when the up button is pressed
    def action_up
      return if @index == 4
      play_cursor_se
      if @index.between?(2, 3)
        @index -= 2
      else
        if @index < 2
          @index = 4
        end
      end
    end
    # Action when the down button is pressed
    def action_down
      return if @index.between?(2, 3)
      play_cursor_se
      @index == 4 ? @index = 0 : @index += 2
    end
    # Action when the left button is pressed
    def action_left
      return if @index == 0 || @index == 4
      play_cursor_se
      @index -= 1
    end
    # Action when the right button is pressed
    def action_right
      return if @index == 3 || @index == 4
      play_cursor_se
      @index += 1
    end
    # Action when the A button is pressed
    def action_a
      if @index < 4
        play_decision_se
        @skill_set[@index].forget = true
        forget
      else
        message_end
      end
    end
    # Action when the B button is pressed
    def action_b
      play_cancel_se
      message_end
    end
    public
    # Actions of the scene
    # Array containing the Yes No texts of a choice
    CHOICE_TEXTS = [[23, 85], [23, 86]]
    # Array containing the texts of the scene
    LEARNING_TEXTS = [[22, 99], [22, 100], [22, 101], [22, 102], [22, 103], [22, 106], [11, 313]]
    private
    # Message starting with the scene
    # @return [Boolean] false to ensure mouse is skipped
    def message_start
      @state = :asking
      @message_window.visible = true
      if @skill_set_not_full
        @pokemon&.learn_skill(@skill_id)
        display_learned_move_message
        @learnt = true
        @running = false
        battle_check
      else
        c = display_learning_move_question
        if c == 0
          show_ui
          which_move
        else
          if c == 1
            message_end
          end
        end
      end
      return false
    end
    # Shows "Pkmn learned xxx!"
    def display_learned_move_message
      display_message(parse_text(*LEARNING_TEXTS[5], ::PFM::Text::PKNICK[0] => @pokemon.given_name, ::PFM::Text::MOVE[1] => @skill_learn.name))
    end
    # Shows "Pkmn want to learn xxxx. Do you want to forget a move?"
    # @return [Integer] 0 = yes, 1 = no
    def display_learning_move_question
      return display_message(parse_text(*LEARNING_TEXTS[0], ::PFM::Text::PKNICK[0] => @pokemon.given_name, ::PFM::Text::MOVE[1] => @skill_learn.name), 1, text_get(*CHOICE_TEXTS[0]), text_get(*CHOICE_TEXTS[1]))
    end
    # Message ending with the scene
    def message_end
      c = display_give_up_question
      if c == 0
        display_give_up_message
        @running = false
        battle_check
      else
        if c == 1
          show_ui
          which_move
        end
      end
    end
    # Shows the give up on this move choice
    # @return [Integer] 0 = yes, 1 = no
    def display_give_up_question
      return display_message(parse_text(*LEARNING_TEXTS[3], ::PFM::Text::PKNICK[0] => @pokemon.given_name, ::PFM::Text::MOVE[1] => @skill_learn.name), 1, text_get(*CHOICE_TEXTS[0]), text_get(*CHOICE_TEXTS[1]))
    end
    # Shows the give up message
    def display_give_up_message
      display_message_and_wait(parse_text(*LEARNING_TEXTS[4], ::PFM::Text::PKNICK[0] => @pokemon.given_name, ::PFM::Text::MOVE[1] => @skill_learn.name))
    end
    # Replace the skill with the new one
    def forget
      c = display_forget_question
      if c == 0
        display_move_forgotten_new_move_learnt
        @pokemon.replace_skill_index(@index, @skill_learn.id)
        @learnt = true
        @running = false
        battle_check
      else
        if c == 1
          @skill_set[@index].forget = false
          which_move
        end
      end
    end
    # Display "You're good with having it forget xxx?"
    # @return [Integer] 0 = yes, 1 = no
    def display_forget_question
      return display_message(parse_text(*LEARNING_TEXTS[6], ::PFM::Text::MOVE[0] => @skills[@index].name), 1, text_get(*CHOICE_TEXTS[0]), text_get(*CHOICE_TEXTS[1]))
    end
    # Display the move forgotten message
    def display_move_forgotten_new_move_learnt
      display_message_and_wait(parse_text(*LEARNING_TEXTS[2], ::PFM::Text::PKNICK[0] => @pokemon.given_name, ::PFM::Text::MOVE[1] => @skills[@index].name, ::PFM::Text::MOVE[2] => @skill_learn.name))
    end
    # Method displaying the Which move should be forgotten? message
    def which_move
      @state = :move_choice
      return display_message_and_wait(parse_text(*LEARNING_TEXTS[1]))
    end
    # If the scene is called during a battle
    def battle_check
      Graphics.transition if $game_temp.in_battle
    end
    # Displays the UI
    def show_ui
      @skill_set[4].data = @skill_learn
      @pokemon.skills_set.each_with_index do |skill, index|
        @skill_set[index].data = skill
      end
      @pokemon_infos.data = @pokemon
      self.ui_visibility = true
      swap_buttons(@index)
    end
    public
    # Function responsive of updating the mouse
    def update_mouse(moved)
      return true unless moved || Mouse.trigger?(:LEFT)
      old_index = @index
      @skill_set.each_with_index do |skill, index|
        next unless skill.simple_mouse_in?
        @index = index
        swap_buttons(old_index)
        action_a unless moved
        break
      end
    end
  end
  # Compatibility with old PSDK version
  Skill_Learn = MoveTeaching
end
GamePlay.move_teaching_mixin = GamePlay::MoveTeachingMixin
GamePlay.move_teaching_class = GamePlay::MoveTeaching
