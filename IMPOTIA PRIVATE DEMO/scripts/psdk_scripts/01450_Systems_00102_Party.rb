module Util
  # Module adding the give / take item functionality to a scene
  module GiveTakeItem
    # Give an item to a Pokemon
    # @param pokemon [PFM::Pokemon] pokemon that will receive the item
    # @param item [Integer, Symbol] item to give, -1 to open the bag
    # @yieldparam pokemon [PFM::Pokemon] block we call with pokemon before and after the form calibration
    # @return [Boolean] if the item was given
    def givetake_give_item(pokemon, item = -1)
      return givetake_give_egg_message(item) && false if pokemon.egg?
      if item == -1
        GamePlay.open_bag_to_give_item_to_pokemon do |scene|
          item = scene.return_data
        end
        Graphics.wait(4) {update_graphics if respond_to?(:update_graphics) }
      end
      return false if item == -1
      item = data_item(item).id
      item1 = pokemon.item_holding
      givetake_give_item_message(item1, item, pokemon)
      givetake_give_item_update_state(item1, item, pokemon)
      yield(pokemon) if block_given?
      return true unless pokemon.form_calibrate
      pokemon.hp = (pokemon.max_hp * pokemon.hp_rate).round
      yield(pokemon) if block_given?
      display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon.given_name))
      return true
    end
    # Display the give item message
    # @param item1 [Integer] taken item
    # @param item2 [Integer] given item
    # @param pokemon [PFM::Pokemon] Pokemong getting the item
    def givetake_give_item_message(item1, item2, pokemon)
      if item1 != 0 && item1 != item2
        display_message(parse_text(22, 91, PFM::Text::ITEM2[0] => pokemon.item_name, PFM::Text::ITEM2[1] => data_item(item2).name))
      else
        if item1 != item2
          display_message(parse_text(22, 90, PFM::Text::ITEM2[0] => data_item(item2).name))
        end
      end
    end
    # Display the give item message to an egg
    # @param item [Integer] given item
    def givetake_give_egg_message(item)
      display_message(parse_text(22, 94, PFM::Text::ITEM2[0] => data_item(item).name))
    end
    # Update the bag and pokemon state when giving an item
    # @param item1 [Integer] taken item
    # @param item2 [Integer] given item
    # @param pokemon [PFM::Pokemon] Pokemong getting the item
    def givetake_give_item_update_state(item1, item2, pokemon)
      pokemon.item_holding = item2
      $bag.remove_item(item2, 1)
      $bag.add_item(item1, 1) if item1 != 0
    end
    # Action of taking the item from the Pokemon
    # @param pokemon [PFM::Pokemon] pokemon we take item from
    # @yieldparam pokemon [PFM::Pokemon] block we call with pokemon before and after the form calibration
    def givetake_take_item(pokemon)
      item = pokemon.item_holding
      $bag.add_item(item, 1)
      pokemon.item_holding = 0
      yield(pokemon) if block_given?
      display_message(parse_text(23, 78, ::PFM::Text::PKNICK[0] => pokemon.given_name, ::PFM::Text::ITEM2[1] => data_item(item).name))
      return unless pokemon.form_calibrate
      pokemon.hp = (pokemon.max_hp * pokemon.hp_rate).round
      yield(pokemon) if block_given?
      display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon.given_name))
    end
  end
end
module UI
  # UI part displaying the generic information of the Pokemon in the Summary
  class Summary_Top < SpriteStack
    # List of Pokemon that shouldn't show the gender sprite
    NO_GENDER = %i[nidoranf nidoranm]
    # Create a new Memo UI for the summary
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, 0, 0, default_cache: :interface)
      init_sprite
    end
    # Set the Pokemon shown
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      super
      @gender.ox = 88 - @name.real_width
      @gender.visible = false if NO_GENDER.include?(pokemon.db_symbol) || pokemon.egg?
      @item.visible = false if pokemon.egg?
      @ball.set_bitmap(data_item(pokemon.captured_with).icon, :icon)
      @star.visible = pokemon.shiny && !pokemon.egg?
    end
    # Update the graphics
    def update_graphics
      @sprite.update
    end
    private
    def init_sprite
      @sprite = create_sprite
      @name = create_name_text
      @gender = create_gender
      @item = create_item
      @ball = create_ball
      @star = create_star
      create_status
    end
    # @return [PokemonFaceSprite]
    def create_sprite
      push(55, 119, nil, type: PokemonFaceSprite)
    end
    # @return [SymText]
    def create_name_text
      add_text(11, 8, 100, 16, :given_name, type: SymText, color: 9)
    end
    # @return [GenderSprite]
    def create_gender
      push(101, 10, nil, type: GenderSprite)
    end
    # @return [RealHoldSprite]
    def create_item
      push(72 + 6, 74 + 16, nil, type: RealHoldSprite)
    end
    # @return [Sprite]
    def create_ball
      push(97, 16, nil, ox: 16, oy: 16)
    end
    # @return [Sprite]
    def create_star
      push(11, 27, 'shiny')
    end
    def create_status
      push(10, 108, nil, type: StatusSprite)
    end
  end
  # UI part displaying the "Memo" of the Pokemon in the Summary
  class Summary_Memo < SpriteStack
    # Create a new Memo UI for the summary
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, 0, 0, default_cache: :interface)
      @invisible_if_egg = []
      init_sprite
    end
    # Set an object inivisible if the Pokemon is an egg
    # @param object [#visible=] the object that is invisible if the Pokemon is an egg
    def no_egg(object)
      @invisible_if_egg << object
      return object
    end
    # Define the pokemon shown by this UI
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      if (self.visible = !pokemon.nil?)
        super
        @invisible_if_egg.each { |sprite| sprite.visible = false } if pokemon.egg?
        fix_level_text_position
        load_text_info(pokemon)
      end
    end
    # Change the visibility of the ui
    # @param value [Boolean] new visibility
    def visible=(value)
      super
      @invisible_if_egg.each { |sprite| sprite.visible = false } if @data&.egg?
    end
    # Initialize the Memo part
    def init_memo
      texts = text_file_get(27)
      with_surface(114, 19, 95) do
        add_line(0, texts[2])
        no_egg add_line(1, texts[0])
        @level_text = no_egg(add_line(1, texts[29], dx: 1))
        no_egg add_line(2, texts[3])
        no_egg add_line(3, texts[8])
        no_egg add_line(3, texts[9], dx: 1)
        no_egg add_line(4, texts[10])
        no_egg add_line(5, texts[12])
        no_egg add_line(6, text_get(23, 7))
        with_font(20) {no_egg add_text(11, 125, 56, nil, 'EXP') }
        add_line(0, :name, 2, type: SymText, color: 1, dx: 1)
        @id = no_egg add_line(1, :id_text, 2, type: SymText, color: 1)
        @level_value = no_egg(add_line(1, :level_text, 2, type: SymText, color: 1, dx: 1))
        no_egg add_line(3, :trainer_id_text, 2, type: SymText, color: 1, dx: 1)
        no_egg add_line(4, :exp_text, 2, type: SymText, color: 1, dx: 1)
        no_egg add_line(5, :exp_remaining_text, 2, type: SymText, color: 1, dx: 1)
        no_egg add_line(6, :item_name, 2, type: SymText, color: 1, dx: 1)
      end
      no_egg add_text(114, 19 + 16 * 3, 92, 16, :trainer_name, 2, type: SymText, color: 1)
      no_egg push(241, 19 + 34, nil, type: Type1Sprite)
      no_egg push(275, 19 + 34, nil, type: Type2Sprite)
    end
    # Load the text info
    # @param pokemon [PFM::Pokemon]
    def load_text_info(pokemon)
      return load_egg_text_info(pokemon) if pokemon.egg?
      time = Time.at(pokemon.captured_at)
      time_egg = pokemon.egg_at ? Time.at(pokemon.egg_at) : time
      hash = {'[VAR NUM2(0007)]' => time_egg.strftime('%d'), '[VAR NUM2(0006)]' => time_egg.strftime('%m'), '[VAR NUM2(0005)]' => time_egg.strftime('%y'), '[VAR LOCATION(0008)]' => pokemon.egg_zone_name, '[VAR 0105(0008)]' => pokemon.egg_zone_name, '[VAR NUM3(0003)]' => pokemon.captured_level.to_s, '[VAR NUM2(0002)]' => time.strftime('%d'), '[VAR NUM2(0001)]' => time.strftime('%m'), '[VAR NUM2(0000)]' => time.strftime('%y'), '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
      mem = pokemon.memo_text || []
      text = parse_text(mem[0] || 28, mem[1] || 25, hash).gsub(/([0-9.]) ([a-z]+ *)\:/i, "\\1 \n\\2:")
      text.gsub!('Level', "\nLevel") if $options.language == 'en'
      @text_info.multiline_text = text
      @id.load_color(pokemon.shiny ? 2 : 1)
    end
    # Load the text info when it's an egg
    # @param pokemon [PFM::Pokemon]
    def load_egg_text_info(pokemon)
      time_egg = pokemon.egg_at ? Time.at(pokemon.egg_at) : Time.new
      hash = {'[VAR NUM2(0007)]' => time_egg.strftime('%d'), '[VAR NUM2(0006)]' => time_egg.strftime('%m'), '[VAR NUM2(0005)]' => time_egg.strftime('%y'), '[VAR LOCATION(0008)]' => pokemon.egg_zone_name, '[VAR 0105(0008)]' => pokemon.egg_zone_name, '[VAR NUM3(0003)]' => pokemon.captured_level.to_s, '[VAR LOCATION(0004)]' => pokemon.captured_zone_name, '[VAR 0105(0004)]' => pokemon.captured_zone_name}
      if pokemon.step_remaining > 10_240
        text = parse_text(28, 89, hash).gsub(/([0-9.]) ([a-z]+ *)\:/i) {"#{$1} \n#{$2}:" }
      else
        if pokemon.step_remaining > 2_560
          text = parse_text(28, 88, hash).gsub(/([0-9.]) ([a-z]+ *)\:/i) {"#{$1} \n#{$2}:" }
        else
          if pokemon.step_remaining > 1_280
            text = parse_text(28, 87, hash).gsub(/([0-9.]) ([a-z]+ *)\:/i) {"#{$1} \n#{$2}:" }
          else
            text = parse_text(28, 86, hash).gsub(/([0-9.]) ([a-z]+ *)\:/i) {"#{$1} \n#{$2}:" }
          end
        end
      end
      text.gsub!('Level', "\nLevel") if $options.language == 'en'
      @text_info.multiline_text = text
    end
    private
    def fix_level_text_position
      @level_text.x = @level_value.x + @level_value.width - @level_value.real_width - @level_text.real_width - 2
    end
    def init_sprite
      create_background
      init_memo
      @text_info = create_text_info
      no_egg @exp_container = push(30, 129, RPG::Cache.interface('exp_bar'))
      no_egg @exp_bar = push_sprite(create_exp_bar)
      @exp_bar.data_source = :exp_rate
    end
    def create_background
      push(0, 0, 'summary/memo')
    end
    def create_text_info
      add_text(13, 138, 294, 16, '')
    end
    def create_exp_bar
      bar = Bar.new(@viewport, 31, 130, RPG::Cache.interface('bar_exp'), 73, 2, 0, 0, 1)
      bar.data_source = :exp_rate
      return bar
    end
  end
  # UI part displaying the Stats of a Pokemon in the Summary
  class Summary_Stat < SpriteStack
    # Show the IV ?
    SHOW_IV = true
    # Show the EV ?
    SHOW_EV = true
    # Create a new Stat UI for the summary
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, 0, 0, default_cache: :interface)
      init_sprite
    end
    # Set the Pokemon shown by the UI
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      super
      fix_nature_texts(pokemon)
    end
    private
    # @param creature [PFM::Pokemon]
    def fix_nature_texts(creature)
      @nature_text.text = PFM::Text.parse(28, creature.nature_id)
      nature = creature.nature.partition.with_index { |_, i| i != 3 }.flatten(1)
      1.upto(5) do |i|
        color = nature[i] < 100 ? 23 : 22
        color = 0 if nature[i] == 100
        @stat_name_texts[i - 1].load_color(color)
      end
    end
    def init_sprite
      create_background
      init_stats
      init_ability
      @hp_container = create_hp_bg
      @hp = add_custom_sprite(create_hp_bar)
    end
    def create_background
      push(0, 0, 'summary/stats')
    end
    def init_ability
      ability_text = add_text(13, 138, 100, 16, text_get(33, 142) + ': ')
      @ability_name = add_text(13 + ability_text.real_width, 138, 294, 16, :ability_name, type: SymText, color: 1)
      @ability_descr = add_text(13, 138 + 16, 294, 16, :ability_descr, type: SymMultilineText)
    end
    def create_hp_bg
      add_sprite(11, 128, RPG::Cache.interface('menu_pokemon_hp'), rect: Rect.new(0, 0, 67, 6))
    end
    # Init the stat texts
    def init_stats
      @stat_name_texts = []
      texts = text_file_get(27)
      with_surface(114, 19, 95) do
        @nature_text = add_line(0, '')
        add_line(1, texts[15])
        @stat_name_texts << add_line(2, texts[18])
        @stat_name_texts << add_line(3, texts[20])
        @stat_name_texts << add_line(4, texts[22])
        @stat_name_texts << add_line(5, texts[24])
        @stat_name_texts << add_line(6, texts[26])
        add_line(1, :hp_text, 2, type: SymText, color: 1)
        add_line(2, :atk_basis, 2, type: SymText, color: 1)
        add_line(3, :dfe_basis, 2, type: SymText, color: 1)
        add_line(4, :ats_basis, 2, type: SymText, color: 1)
        add_line(5, :dfs_basis, 2, type: SymText, color: 1)
        add_line(6, :spd_basis, 2, type: SymText, color: 1)
      end
      init_ev_iv
    end
    # Create the HP Bar for the pokemon Copy/Paste from Menu_Party
    # @return [UI::Bar]
    def create_hp_bar
      bar = Bar.new(@viewport, 25, 129, RPG::Cache.interface('team/HPBars'), 52, 4, 0, 0, 3)
      bar.data_source = :hp_rate
      return bar
    end
    # Init the ev/iv texts
    def init_ev_iv
      offset = 102
      if SHOW_EV
        with_surface(114 + offset, 19, 95) do
          add_line(1, :ev_hp_text, type: SymText)
          add_line(2, :ev_atk_text, type: SymText)
          add_line(3, :ev_dfe_text, type: SymText)
          add_line(4, :ev_ats_text, type: SymText)
          add_line(5, :ev_dfs_text, type: SymText)
          add_line(6, :ev_spd_text, type: SymText)
        end
        offset += 44
      end
      if SHOW_IV
        with_surface(114 + offset, 19, 95) do
          add_line(1, :iv_hp_text, type: SymText)
          add_line(2, :iv_atk_text, type: SymText)
          add_line(3, :iv_dfe_text, type: SymText)
          add_line(4, :iv_ats_text, type: SymText)
          add_line(5, :iv_dfs_text, type: SymText)
          add_line(6, :iv_spd_text, type: SymText)
        end
      end
    end
  end
  # Window responsive of displaying the Level Up information when a Pokemon levels up
  class LevelUpWindow < UI::Window
    # Create a new Level Up Window
    # @param viewport [Viewport] viewport in which the Pokemon is shown
    # @param pokemon [PFM::Pokemon] Pokemon that is currently leveling up
    # @param list0 [Array] old basis stats
    # @param list1 [Array] new basis stats
    def initialize(viewport, pokemon, list0, list1)
      super(viewport, window_x, Graphics.height - window_height, window_width, window_height)
      @pokemon = pokemon
      @list0 = list0
      @list1 = list1
      create_sprites
    end
    # Update the Pokemon Icon animation
    def update
      @pokemon_icon.update
    end
    private
    # Create all the sprites inside the window
    def create_sprites
      create_pokemon_icon
      create_pokemon_name
      create_stats_texts
    end
    # Create the Pokemon Icon sprite
    def create_pokemon_icon
      @pokemon_icon = PokemonIconSprite.new(self, false)
      @pokemon_icon.data = @pokemon
    end
    # Create the Pokemon Name sprite
    def create_pokemon_name
      add_text(@pokemon_icon.width + 2, 0, 0, @pokemon_icon.height, @pokemon.given_name)
    end
    # Create all the stats texts
    def create_stats_texts
      format_str = '%d (+%d)'
      sprite_stack.with_surface(0, @pokemon_icon.height, rect.width) do
        6.times do |i|
          add_line(i + 1, text_get(22, 121 + i))
          add_line(i + 1, format(format_str, @list1[i], @list1[i] - @list0[i]), 2, color: 1)
        end
      end
    end
    # width of the Window
    def window_width
      140
    end
    # Height of the Window
    def window_height
      180
    end
    # X position of the Window
    def window_x
      Graphics.width - window_width - 2
    end
    # Y position of the Window
    def window_y
      Graphics.height - window_height
    end
  end
  # UI part displaying the Skills of the Pokemon in the Summary
  class Summary_Skills < SpriteStack
    # @return [Integer] The index of the move
    attr_reader :index
    # @return [Array<UI::Summary_Skill>] The skills
    attr_reader :skills
    # Create a new Skills UI for the summary
    # @param viewport [Viewport]
    def initialize(viewport)
      super(viewport, 0, 0, default_cache: :interface)
      init_sprite
      self.index = 0
    end
    # Set the data of the UI
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      super
      self.index = index
      update_skills(pokemon)
    end
    # Set the visibility of the UI
    # @param value [Boolean] new visibility
    def visible=(value)
      super
      @move_info.visible = value
      @skills.each { |skill| skill.visible = value }
    end
    # Set the index of the shown move
    # @param index [Integer]
    def index=(index)
      index = fix_index(index)
      @skills[@index || 0].selected = false
      @index = index.to_i
      @move_info.data = @data.skills_set[@index] if @data
      @skills[@index].selected = true
    end
    private
    def init_sprite
      push(0, 0, background_name)
      init_texts
      init_skills
    end
    # Return the background name
    # @return [String]
    def background_name
      'summary/moves'
    end
    # Update the skills shown in the UI
    # @param pokemon [PFM::Pokemon]
    def update_skills(pokemon)
      pokemon.skills_set.compact!
      @skills.each_with_index do |skill_stack, index|
        skill_stack.data = pokemon.skills_set[index]
      end
    end
    # Init the texts of the UI
    def init_texts
      texts = text_file_get(27)
      with_surface(114, 19, 95) do
        add_line(0, texts[3])
        add_line(1, texts[36])
        add_line(0, texts[37], dx: 1)
        add_line(1, texts[39], dx: 1)
      end
      @move_info = SpriteStack.new(@viewport)
      @move_info.with_surface(114, 19, 95) do
        @move_info.add_line(0, :power_text, 2, type: SymText, color: 1, dx: 1)
        @move_info.add_line(1, :accuracy_text, 2, type: SymText, color: 1, dx: 1)
        @move_info.add_line(2, :description, type: SymMultilineText, color: 1).width = 195
      end
      @move_info.push(175, 21, nil, type: TypeSprite)
      @move_info.push(175, 21 + 16, nil, type: CategorySprite)
    end
    # Init the skills of the UI
    def init_skills
      @skills = Array.new(4) { |index| Summary_Skill.new(@viewport, index) }
    end
    # Fix the index value
    # @param index [Integer] requested index
    # @return [Integer] fixed index
    def fix_index(index)
      max_index = (@data&.skills_set&.size || 1) - 1
      return 0 if max_index == 0
      if index < 0
        return fix_index_minus(index, max_index)
      else
        if index > max_index
          return fix_index_plus(index, max_index)
        end
      end
      return index
    end
    # Fix the index value when index < 0
    # @param index [Integer] requested index
    # @param max_index [Integer] the maximum index
    # @return [Integer] the new index
    def fix_index_minus(index, max_index)
      delta = index - @index.to_i
      if delta == -1
        return max_index if @index == 0
      else
        if delta == -2
          return max_index >= 3 ? 3 : 1 if @index == 1
          return max_index >= 2 ? 2 : 0 if @index == 0
        end
      end
      return 0
    end
    # Fix the index value when index > max_index
    # @param index [Integer] requested index
    # @param _max_index [Integer] the maximum index
    # @return [Integer] the new index
    def fix_index_plus(index, _max_index)
      delta = index - @index.to_i
      if delta == 2
        return 0 if @index == 0 || @index == 2
        return 1
      end
      return 0
    end
  end
  # UI part displaying a Skill in the Summary_Skills UI
  class Summary_Skill < SpriteStack
    # Array describing the various coordinates of the skills in the UI
    FINAL_COORDINATES = [[28, 138], [174, 138], [28, 170], [174, 170]]
    # Color when it's selected
    SELECTED_COLOR = Color.new(0, 200, 0, 255)
    # Color when it's not selected
    NO_SELECT_COLOR = Color.new(0, 0, 0, 0)
    # @return [Boolean] if the move is currently selected
    attr_reader :selected
    # @return [Boolean] if the move is currently being moved
    attr_reader :moving
    # Create a new skill
    # @param viewport [Viewport]
    # @param index [Integer] index of the skill in the UI
    def initialize(viewport, index)
      super(viewport, *FINAL_COORDINATES[index % FINAL_COORDINATES.size])
      @selected = false
      create_sprites
      self.moving = false
    end
    # Set the skill data
    # @param skill [PFM::Skill]
    def data=(skill)
      super
      return unless (self.visible = skill ? true : false)
      @selector.visible = @selected
      self.moving = false
    end
    # Set the visibility of the sprite
    # @param value [Boolean] new visibility
    def visible=(value)
      super(value && @data)
      @selector.visible = value && (@selected || @moving)
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
      @selector.visible = selected || @moving
    end
    # Define if the skill is being moved
    # @param moving [Boolean]
    def moving=(moving)
      @moving = moving
      if moving
        @selector.visible = true
        @selector.set_color(SELECTED_COLOR)
      else
        @selector.visible = @selected
        @selector.set_color(NO_SELECT_COLOR)
      end
    end
    private
    def create_sprites
      @selector = push(-8, 0, selector_name, type: Sprite::WithColor)
      push(0, 2, nil, type: TypeSprite)
      add_text(34, 0, 110, 16, :name, type: SymText)
      @pp_text = add_text(34, 16, 110, 16, text_get(27, 32))
      add_text(34, 16, 100, 16, pp_method, 1, type: SymText, color: 1)
    end
    # Return the name of the selector file
    # @return [String]
    def selector_name
      'summary/move_selector'
    end
    # Return the name of the method used to get the PP text
    # @return [Symbol]
    def pp_method
      :pp_text
    end
  end
  # UI displaying the Reminding move list
  class Summary_Remind < Summary_Skills
    # @return [Integer] maximum number of moves shown in the screen
    MAX_MOVES = 5
    # @return [Integer] mode passed to the {PFM::Pokemon#remindable_skills} method
    attr_accessor :mode
    # @return [Array<PFM::Skill>] list of learnable moves
    attr_reader :learnable_skills
    # Create a new Summary_Remind UI for the summary
    # @param viewport [Viewport]
    # @param pokemon [PFM::Pokemon] Pokemon that should relearn some skills
    def initialize(viewport, pokemon)
      @offset_index = 0
      @mode = 0
      super(viewport)
      self.data = pokemon
    end
    # Set the Pokemon shown
    # @param pokemon [PFM::Pokemon]
    def data=(pokemon)
      super
      fix_gender_position
      fix_nature_texts(pokemon)
    end
    # Set the index of the shown move
    # @param index [Integer]
    def index=(index)
      last_index = (@index || 0) - @offset_index
      index = fix_index(index)
      @skills[last_index].selected = false
      @index = index.to_i
      @move_info.data = @learnable_skills[@index] if @learnable_skills
      @skills[@index - @offset_index].selected = true
    end
    # Update the skills shown in the UI
    # @param pokemon [PFM::Pokemon]
    def update_skills(pokemon = @data)
      @learnable_skills = pokemon.remindable_skills(@mode).collect { |db_symbol| PFM::Skill.new(db_symbol) }
      @move_info.data = @learnable_skills[@index]
      update_skill_list
    end
    # Update the graphics
    def update_graphics
      @icon.update
    end
    private
    def fix_gender_position
      @gender.ox = 88 - @name.real_width
    end
    # @param creature [PFM::Pokemon]
    def fix_nature_texts(creature)
      @nature_text.text = PFM::Text.parse(28, creature.nature_id)
      nature = creature.nature.partition.with_index { |_, i| i != 3 }.flatten(1)
      1.upto(5) do |i|
        color = nature[i] < 100 ? 23 : 22
        color = 0 if nature[i] == 100
        @stat_name_texts[i - 1].load_color(color)
      end
    end
    def init_sprite
      super
      move(0, 71)
      @x = @y = 0
      @move_info.set_position(0, 71)
      @stack.first.set_position(0, 0)
      init_pokemon_info
    end
    # Return the background name
    # @return [String]
    def background_name
      'summary/remind'
    end
    # Init the skills of the UI
    def init_skills
      @skills = Array.new(5) { |index| Remind_Skill.new(@viewport, index) }
    end
    # Init the Pokemon Info
    def init_pokemon_info
      @name = add_text(11, 8, 100, 16, :given_name, type: SymText, color: 9)
      @gender = push(101, 10, nil, type: GenderSprite)
      @level_text = add_text(11, 8 + 14, 60, 16, text_get(27, 29), color: 9)
      add_text(14 + @level_text.real_width, 8 + 14, 95, 16, :level_text, type: SymText, color: 11)
      @icon = push(94, 20, nil, type: PokemonIconSprite)
      init_stats
    end
    # Init the stat texts
    def init_stats
      texts = text_file_get(27)
      @stat_name_texts = []
      with_surface(114, 19, 95) do
        @nature_text = add_line(0, '')
        add_line(1, texts[15])
        @stat_name_texts << add_line(2, texts[18])
        @stat_name_texts << add_line(3, texts[20])
        @stat_name_texts << add_line(1, texts[22], dx: 1)
        @stat_name_texts << add_line(2, texts[24], dx: 1)
        @stat_name_texts << add_line(3, texts[26], dx: 1)
        add_line(1, :hp_text, 2, type: SymText, color: 1)
        add_line(2, :atk_basis, 2, type: SymText, color: 1)
        add_line(3, :dfe_basis, 2, type: SymText, color: 1)
        add_line(1, :ats_basis, 2, type: SymText, color: 1, dx: 1)
        add_line(2, :dfs_basis, 2, type: SymText, color: 1, dx: 1)
        add_line(3, :spd_basis, 2, type: SymText, color: 1, dx: 1)
      end
    end
    # Update the skill list
    def update_skill_list
      @skills.each_with_index do |skill_stack, index|
        skill_stack.data = @learnable_skills[index + @offset_index]
      end
    end
    # Fix the index value
    # @param index [Integer] requested index
    # @return [Integer] fixed index
    def fix_index(index)
      max_index = (@learnable_skills&.size || 1) - 1
      if index > max_index
        index = 0
      else
        if index < 0
          index = max_index
        end
      end
      fix_offset_index(index, max_index)
      return index
    end
    # Fix the @offset_index value
    # @param index [Integer] fixed index
    # @param max_index [Integer] last possible index
    def fix_offset_index(index, max_index)
      return if max_index < MAX_MOVES
      last_offset_index = @offset_index
      mid_index = MAX_MOVES / 2
      if index > mid_index
        if index + mid_index < max_index
          @offset_index = index - mid_index
        else
          @offset_index = max_index - mid_index * 2
        end
      else
        @offset_index = 0
      end
      update_skill_list if last_offset_index != @offset_index
    end
  end
  # UI part displaying a Skill in the Summary_Remind UI
  class Remind_Skill < Summary_Skill
    # Create a new skill
    # @param viewport [Viewport]
    # @param index [Integer] index of the skill in the UI
    def initialize(viewport, index)
      super
      set_position(12, 42 + index * 32)
      @selector.x += 6
      @stack[1].y += 15
      @stack[2].x -= 32
      @stack[4].width = 60
    end
    private
    # Return the name of the selector file
    # @return [String]
    def selector_name
      'summary/remind_selector'
    end
    # Return the name of the method used to get the PP text
    # @return [Symbol]
    def pp_method
      :ppmax
    end
  end
  # Button that show basic information of a Pokemon
  class TeamButton < SpriteStack
    # Get the Item text to perform specific operations
    # @return [SymText]
    attr_reader :item_text
    # List of the Y coordinate of the button (index % 6), relative to the contents definition !
    CoordinatesY = [0, 24, 64, 88, 128, 152]
    # List of the X coordinate of the button (index % 2), relative to the contents definition !
    CoordinatesX = [0, 160]
    # List of the Y coordinate of the background textures
    TextureBackgroundY = [0, 56, 112, 168]
    # Height of the background texture
    TextureBackgroundHeight = 56
    # Get the selected state of the sprite
    # @return [Boolean]
    attr_reader :selected
    # Create a new Team button
    # @param viewport [Viewport] viewport where to show the button
    # @param index [Integer] Index of the button in the team
    def initialize(viewport, index)
      @index = index
      super(viewport, *initial_coordinates)
      create_sprites
      @selected = false
      fix_initial_position_cause_dev_is_lazy
    end
    # Set the data of the SpriteStack
    # @param data [PFM::Pokemon]
    def data=(data)
      super(data)
      update_item_text_visibility
      update_background
    end
    # Update the background according to the selected state
    def update_background
      if @data.dead?
        @background.src_rect.y = TextureBackgroundY[@selected ? 3 : 2]
      else
        @background.src_rect.y = TextureBackgroundY[@selected ? 1 : 0]
      end
    end
    # Set the selected state of the sprite
    # @param v [Boolean]
    def selected=(v)
      @selected = v
      update_background
      @item_sprite.sy = v ? 1 : 0
      @item_text.load_color(v ? 9 : 0)
    end
    # Show the item name
    def show_item_name
      @item_sprite.visible = @item_text.visible = true
    end
    # Hide the item name
    def hide_item_name
      @item_sprite.visible = @item_text.visible = false
    end
    # Refresh the button
    def refresh
      self.data = @data
    end
    # Update the graphics
    def update_graphics
      @icon.update
    end
    private
    def update_item_text_visibility
      @item_text.visible = @item_sprite.visible
    end
    def initial_coordinates
      return CoordinatesX[@index % 2], CoordinatesY[@index % 6]
    end
    def create_sprites
      @background = add_sprite(15, 7, background_name)
      @background.src_rect.height = TextureBackgroundHeight
      @icon = add_sprite(32, 24, NO_INITIAL_IMAGE, type: PokemonIconSprite)
      add_text(50, 17, 79, 16, :given_name, type: SymText, color: 9)
      add_sprite(132, 20, NO_INITIAL_IMAGE, type: GenderSprite)
      add_sprite(123, 31, 'team/Item', type: HoldSprite)
      add_text(38, 38, 61, 16, :level_pokemon_number, type: SymText, color: 9)
      add_sprite(119, 46, NO_INITIAL_IMAGE, type: StatusSprite)
      @hp = add_custom_sprite(create_hp_bar)
      with_font(20) do
        add_text(62, 34 + 5, 56, 13, :hp_text, 1, type: SymText, color: 9)
      end
      @item_sprite = add_sprite(24, 39, 'team/But_Object', 1, 2, type: SpriteSheet)
      @item_text = add_text(27, 40, 113, 16, :item_name, type: SymText)
      hide_item_name
    end
    # Position adjustment
    def fix_initial_position_cause_dev_is_lazy
      @x += 15
      @y += 7
    end
    # Return the background name
    # @return [String] name of the background
    def background_name
      'team/but_party'
    end
    # Create the HP Bar for the pokemon
    # @return [UI::Bar]
    def create_hp_bar
      bar = UI::Bar.new(@viewport, @x + 64, @y + 34, RPG::Cache.interface('team/HPBars'), 53, 4, 0, 0, 3)
      bar.data_source = :hp_rate
      return bar
    end
  end
end
module GamePlay
  # Module defining the IO of the PartyMenu
  module PartyMenuMixin
    # Return data of the Party Menu
    # @return [Integer]
    attr_accessor :return_data
    # Return the skill process to call
    # @return [Array(Proc, PFM::Pokemon, PFM::Skill), Proc, nil]
    attr_accessor :call_skill_process
    # Tell if a Pokemon was selected
    # @return [Boolean]
    def pokemon_selected?
      return return_data >= 0
    end
    # Tell if a party was selected
    # @return [Boolean]
    def party_selected?
      return false if @mode != :select
      return $game_temp.temp_team&.any?
    end
    # Get all the selected Pokemon
    # @return [Array<PFM::Pokemon>]
    def selected_pokemons
      return [] unless party_selected?
      return $game_temp.temp_team
    end
  end
  # Class that display the Party Menu interface and manage user inputs
  #
  # This class has several modes
  #   - :map => Used to select a Pokemon in order to perform stuff
  #   - :menu => The normal mode when opening this interface from the menu
  #   - :battle => Select a Pokemon to send to battle
  #   - :item => Select a Pokemon in order to use an item on it (require extend data : hash)
  #   - :hold => Give an item to the Pokemon (requires extend data : item_id)
  #   - :select => Select a number of Pokemon for a temporary team.
  #     (Number defined by $game_variables[6] and possible list of excluded Pokemon requires extend data : array)
  #
  # This class can also show an other party than the player party,
  # the party paramter is an array of Pokemon upto 6 Pokemon
  class Party_Menu < BaseCleanUpdate::FrameBalanced
    include PartyMenuMixin
    # Color mapping for the result of on_creature_choice
    ON_POKEMON_CHOICE_COLOR_MAPPING = {true => 1, false => 2, nil => 3}
    # Message mapping for the result of on_creature_choice in apt detect
    ON_POKEMON_CHOICE_MESSAGE_MAPPING = {true => 143, false => 144, nil => 142}
    # Selector Rect info
    # @return [Array]
    SelectorRect = [[0, 0, 132, 52], [0, 64, 132, 52]]
    # Height of the frame Image to actually display (to prevent button from being hidden / shadowed).
    # Set nil to keep the full height
    FRAME_HEIGHT = 214
    # Create a new Party_Menu
    # @param party [Array<PFM::Pokemon>] list of Pokemon in the party
    # @param mode [Symbol] :map => from map (select), :menu => from menu, :battle => from Battle, :item => Use an item,
    #                      :hold => Hold an item, :choice => processing a choice related proc (do not use)
    # @param extend_data [Integer, PFM::ItemDescriptor::Wrapper, Array, Symbol] extend_data informations
    # @param no_leave [Boolean] tells the interface to disallow leaving without choosing
    def initialize(party, mode = :map, extend_data = nil, no_leave: false)
      super()
      @move = -1
      @return_data = -1
      @mode = mode
      @extend_data = extend_data
      @no_leave = no_leave
      @index = 0
      @party = party
      @counter = 0
      @intern_mode = :normal
      @temp_team = []
      $game_variables[Yuki::Var::Party_Menu_Sel] = -1
      @choice_object = nil
      @running = true
    end
    # Update the inputs
    def update_inputs
      return action_A if Input.trigger?(:A)
      return action_X if Input.trigger?(:X)
      return action_Y if Input.trigger?(:Y)
      return action_B if Input.trigger?(:B)
      update_selector_move
    end
    # Update the mouse
    # @param _moved [Boolean] if the mouse moved
    def update_mouse(_moved)
      update_mouse_ctrl
    end
    # Update the scene graphics during an animation or something else
    def update_graphics
      update_selector
      @base_ui.update_background_animation
      @team_buttons.each(&:update_graphics)
    end
    alias update_during_process update_graphics
    private
    # Create the UI graphics
    def create_graphics
      create_viewport
      create_base_ui
      create_team_buttons
      create_frames
      create_selector
      init_win_text
      Graphics.sort_z
    end
    # Create the base UI
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
      auto_adjust_button
    end
    # Retrieve the button texts according to the mode
    # @return [Array<String>]
    def button_texts
      return Array.new(4) { |i| ext_text(9000, 14 + i) } if @mode != :select
      return Array.new(4, ext_text(9000, 22 + 3))
    end
    # Adjust the button display
    def auto_adjust_button
      return unless @mode == :select
      ctrl = @base_ui.ctrl
      ctrl[3], ctrl[1] = ctrl[1], ctrl[3]
      ctrl[3].set_position(*UI::GenericBase::ControlButton::COORDINATES[3])
    end
    # Create the frame sprites
    def create_frames
      @black_frame = Sprite.new(@viewport)
      @frame = Sprite.new(@viewport).set_bitmap($options.language == 'fr' ? 'team/FrameFR' : 'team/FrameEN', :interface)
    end
    # Create the team buttons
    def create_team_buttons
      @team_buttons = Array.new(@party.size) do |i|
        btn = UI::TeamButton.new(@viewport, i)
        btn.data = @party[i]
        next((btn))
      end
    end
    # Create the selector
    def create_selector
      @selector = Sprite.new(@viewport).set_bitmap('team/Cursors', :interface)
      @selector.src_rect.set(*SelectorRect[0])
      update_selector_coordinates
    end
    # Initialize the win_text according to the mode
    def init_win_text
      case @mode
      when :map, :battle, :absofusion, :separate
        return @base_ui.show_win_text(text_get(23, 17))
      when :hold
        return @base_ui.show_win_text(text_get(23, 23))
      when :item
        if @extend_data
          extend_data_button_update
          return @base_ui.show_win_text(text_get(23, 24))
        end
      when :select
        select_pokemon_button_update
        return @base_ui.show_win_text(text_get(23, 17))
      end
      @base_ui.hide_win_text
    end
    # Function that update the team button when extend_data is correct
    def extend_data_button_update
      apt_detect = @extend_data.open_skill_learn || @extend_data.stone_evolve
      @team_buttons.each do |btn|
        btn.show_item_name
        v = @extend_data.on_creature_choice(btn.data, self)
        c = ON_POKEMON_CHOICE_COLOR_MAPPING[v]
        if apt_detect
          message_id = ON_POKEMON_CHOICE_MESSAGE_MAPPING[v]
        else
          message_id = (v ? 140 : 141)
        end
        btn.item_text.load_color(c).text = parse_text(22, message_id)
      end
    end
    # Function that updates the text displayed in the team button when in :select mode
    def select_pokemon_button_update
      @team_buttons.each do |btn|
        btn.show_item_name
        c = 0
        if @temp_team.include?(btn.data)
          c = 1
          v = 155 + @temp_team.index(btn.data)
        else
          if @extend_data.is_a?(Array) && @extend_data.include?(@party[@team_buttons.index(btn)].id)
            c = 2
            v = 154
          else
            v = 153
          end
        end
        btn.item_text.load_color(c).text = fix_number(parse_text(23, v))
      end
    end
    # Update the selector
    def update_selector
      @counter += 1
      if @counter == 60
        @selector.src_rect.set(*SelectorRect[1])
      else
        if @counter >= 120
          @counter = 0
          @selector.src_rect.set(*SelectorRect[0])
        end
      end
    end
    # Show the item name
    def show_item_name
      @team_buttons.each(&:show_item_name)
    end
    # Hide the item name
    def hide_item_name
      @team_buttons.each(&:hide_item_name)
    end
    # Show the black frame for the currently selected Pokemon
    def show_black_frame
      @black_frame.set_bitmap("team/dark#{@index + 1}", :interface)
      @black_frame.visible = true
      @black_frame.src_rect.height = FRAME_HEIGHT if FRAME_HEIGHT
      1.upto(8) do |i|
        @black_frame.opacity = i * 255 / 8
        update_during_process
        Graphics.update
      end
    end
    # Hide the black frame for the currently selected Pokemon
    def hide_black_frame
      8.downto(1) do |i|
        @black_frame.opacity = i * 255 / 8
        update_during_process
        Graphics.update
      end
      @black_frame.visible = false
    end
    # Fix special characters used in some Studio texts
    def fix_number(string)
      string = string.sub('', 'er')
      string.sub!('', 'ème')
      return string
    end
    # Refresh all team buttons, update the selector and reset the index to 0
    def refresh_team_buttons
      @team_buttons.each(&:dispose)
      create_team_buttons
      update_selector_coordinates(@index = 0)
    end
    public
    # Array of actions to do according to the pressed button
    Actions = %i[action_A action_X action_Y action_B]
    # Action triggered when A is pressed
    def action_A
      case @mode
      when :menu
        action_A_menu
      else
        $game_system.se_play($data_system.decision_se)
        show_choice
      end
    end
    # Action when A is pressed and the mode is menu
    def action_A_menu
      case @intern_mode
      when :choose_move_pokemon
        action_move_current_pokemon
      when :choose_move_item
        return $game_system.se_play($data_system.buzzer_se) if @team_buttons[@index].data.item_holding == 0
        @team_buttons[@move = @index].selected = true
        @intern_mode = :move_item
        @base_ui.show_win_text(text_get(23, 22))
      when :move_pokemon
        process_switch
      when :move_item
        process_item_switch
      else
        $game_system.se_play($data_system.decision_se)
        return show_choice
      end
      $game_system.se_play($data_system.decision_se)
    end
    # Action triggered when B is pressed
    def action_B
      return if no_leave_B
      @call_skill_process = nil
      $game_system.se_play($data_system.cancel_se)
      return @choice_object.cancel if @choice_object
      if @intern_mode != :normal
        @base_ui.hide_win_text
        hide_item_name
        @team_buttons[@move].selected = false if @move != -1
        @move = -1
        return @intern_mode = :normal
      end
      if @mode == :select
        $game_temp.temp_team = []
      end
      @running = false
    end
    # Function that detect no_leave and forbit the B action to process
    # @return [Boolean] true = no leave, false = process normally
    def no_leave_B
      if @no_leave
        return false if @choice_object
        return false if @intern_mode != :normal
        $game_system.se_play($data_system.buzzer_se)
        return true
      end
      return false
    end
    # Action triggered when X is pressed
    def action_X
      $game_temp.temp_team = @temp_team if @mode == :select
      @running = false if @mode == :select && enough_pokemon? == true
      return if @mode != :menu
      return $game_system.se_play($data_system.buzzer_se) if @intern_mode != :normal || @party.size <= 1
      @base_ui.show_win_text(text_get(23, 19))
      @intern_mode = :choose_move_pokemon
    end
    # Action triggered when Y is pressed
    def action_Y
      return if @mode != :menu
      return $game_system.se_play($data_system.buzzer_se) if @intern_mode != :normal || @party.size <= 1
      @base_ui.show_win_text(text_get(23, 20))
      @intern_mode = :choose_move_item
      show_item_name
    end
    # Update the mouse interaction with the ctrl buttons
    def update_mouse_ctrl
      if @mode != :select
        update_mouse_ctrl_buttons(@base_ui.ctrl, Actions, @base_ui.win_text_visible?)
      else
        update_mouse_ctrl_buttons(@base_ui.ctrl, [nil, nil, nil, :action_X], false)
      end
    end
    # Update the movement of the Cursor
    def update_selector_move
      party_size = @team_buttons.size
      index2 = @index % 2
      if Input.trigger?(:DOWN)
        next_index = @index + 2
        next_index = index2 if next_index >= party_size
        update_selector_coordinates(@index = next_index)
      else
        if Input.trigger?(:UP)
          next_index = @index - 2
          if next_index < 0
            next_index += 6
            next_index -= 2 while next_index >= party_size
          end
          update_selector_coordinates(@index = next_index)
        else
          if index_changed(:@index, :LEFT, :RIGHT, party_size - 1)
            update_selector_coordinates
          else
            update_mouse_selector_move
          end
        end
      end
    end
    # Update the movement of the selector with the mouse
    def update_mouse_selector_move
      return unless Mouse.moved || Mouse.trigger?(:left)
      @team_buttons.each_with_index do |btn, i|
        next unless btn.simple_mouse_in?
        update_selector_coordinates(@index = i) if @index != i
        action_A if Mouse.trigger?(:left)
        return true
      end
    end
    # Update the selector coordinates
    def update_selector_coordinates(*)
      btn = @team_buttons[@index]
      @selector.set_position(btn.x + 3, btn.y + 3)
    end
    # Select the current pokemon to move with an other pokemon
    def action_move_current_pokemon
      return if @party.size <= 1
      @team_buttons[@move = @index].selected = true
      @intern_mode = :move_pokemon
      @base_ui.show_win_text(text_get(23, 21))
    end
    public
    include Util::GiveTakeItem
    # List of all choice method to call according to the current mode
    CHOICE_METHODS = {menu: :show_menu_mode_choice, choice: :show_choice_mode_choice, battle: :show_battle_mode_choice, item: :show_item_mode_choice, hold: :show_hold_mode_choice, select: :show_select_mode_choice, absofusion: :process_absofusion_mode, separate: :process_separate_mode}
    # Show the proper choice
    def show_choice
      send(*(CHOICE_METHODS[@mode] || :show_map_mode_choice))
    end
    # Return the skill color
    # @return [Integer]
    def skill_color
      return 1
    end
    # Show the choice when party is in mode :menu
    def show_menu_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      unless pokemon.egg?
        pokemon.skills_set.each_with_index do |skill, i|
          if skill && (skill.map_use > 0 || PFM::SKILL_PROCESS[skill.db_symbol])
            choices.register_choice(skill.name, i, on_validate: method(:use_pokemon_skill), color: skill_color)
          end
        end
      end
      choices.register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 8), on_validate: method(:action_move_current_pokemon), disable_detect: proc {@party.size <= 1 })
      unless pokemon.egg?
        choices.register_choice(ext_text(9009, 0), on_validate: method(:launch_reminder), disable_detect: proc {pokemon.remindable_skills == [] }) if $game_switches[Yuki::Sw::BT_Party_Menu_Reminder]
        if Yuki::FollowMe.in_lets_go_mode?
          if $storage.lets_go_follower == pokemon
            choices.register_choice(text_get(23, 165), on_validate: method(:deselect_follower))
          else
            choices.register_choice(text_get(23, 164), on_validate: method(:select_follower))
          end
        end
        choices.register_choice(text_get(23, 146), on_validate: method(:give_item)).register_choice(text_get(23, 147), on_validate: method(:take_item), disable_detect: method(:current_pokemon_has_no_item))
      end
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      @base_ui.hide_win_text if choice == 999
      hide_black_frame
    end
    # Update the scene during a choice
    # @param choices [PFM::Choice_Helper] choice interface to be able to cancel
    def update_menu_choice(choices)
      @choice_object = choices
      update_during_process
      update_mouse_ctrl
      @choice_object = nil
    end
    # Return the choice coordinates according to the current selected Pokemon
    # @param choices [PFM::Choice_Helper] choice interface to be able to cancel
    # @return [Array(Integer, Integer)]
    def get_choice_coordinates(choices)
      choice_height = 16
      height = choices.size * choice_height
      max_height = 217
      but_x = @team_buttons[@index].x + 53
      but_y = @team_buttons[@index].y + 32
      if but_y + height > max_height
        but_y -= (height - choice_height)
        but_y += choice_height while but_y < 0
      end
      return but_x, but_y
    end
    # Action of using a move of the current Pokemon
    # @param move_index [Integer] index of the move in the Pokemon moveset
    def use_pokemon_skill(move_index)
      pokemon = @party[@index]
      skill = pokemon.skills_set[move_index]
      if (@call_skill_process = PFM::SKILL_PROCESS[skill.db_symbol])
        if (type = @call_skill_process.call(pokemon, nil, true))
          if type == true
            @call_skill_process.call(pokemon, skill)
            @call_skill_process = nil
          else
            if type == :choice
              @mode = :choice
              @return_data = @index
              @base_ui.show_win_text(text_get(23, 17))
              return
            else
              if type == :block
                display_message(parse_text(22, 108))
                @base_ui.hide_win_text
                @call_skill_process = nil
                return
              end
            end
          end
        else
          @call_skill_process = [@call_skill_process, pokemon, skill]
        end
      else
        $game_temp.common_event_id = skill.map_use
      end
      @base_ui.hide_win_text
      @return_data = $game_variables[Yuki::Var::Party_Menu_Sel] = @index
      @running = false
    end
    # Action of launching the Pokemon Summary
    # @param mode [Symbol] mode used to launch the summary
    # @param extend_data [PFM::ItemDescriptor::Wrapper, nil] the extended data used to launch the summary
    def launch_summary(mode = :view, extend_data = nil)
      @base_ui.hide_win_text
      call_scene(Summary, @party[@index], mode, @party, extend_data)
      Graphics.wait(4) {update_during_process }
    end
    # Action of launching the Pokemon Reminder
    # @param mode [Integer] mode used to launch the reminder
    def launch_reminder(mode = 0)
      @base_ui.hide_win_text
      GamePlay.open_move_reminder(@party[@index], mode) { |scene| result = scene.reminded_move? }
      Graphics.wait(4) {update_during_process }
    end
    # Action of deselecting the follower
    def deselect_follower
      $storage.lets_go_follower = nil
    end
    # Action of selecting the follower
    def select_follower
      $storage.lets_go_follower = @party[@index]
    end
    # Action of giving an item to the Pokemon
    # @param item2 [Integer] id of the item to give
    # @note if item2 is -1 it'll call the Bag interface to get the item
    def give_item(item2 = -1)
      givetake_give_item(@party[@index], item2) do |pokemon|
        @team_buttons[@index].data = pokemon
        @team_buttons[@index].refresh
      end
      @base_ui.hide_win_text
    end
    # Action of taking the item from the Pokemon
    def take_item
      @base_ui.hide_win_text
      givetake_take_item(@party[@index]) do |pokemon|
        @team_buttons[@index].data = pokemon
        @team_buttons[@index].refresh
      end
    end
    # Method telling if the Pokemon has no item or not
    # @return [Boolean]
    def current_pokemon_has_no_item
      @party[@index].item_holding <= 0
    end
    # Show the choice when the party is in mode :battle
    def show_battle_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(20, 25), on_validate: method(:on_send_pokemon)).register_choice(text_get(23, 4), on_validate: method(:launch_summary))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
    end
    # When the player want to send a specific Pokemon to battle
    def on_send_pokemon
      pokemon = @party[@index]
      if pokemon.egg?
        display_message(parse_text(20, 34))
      else
        if pokemon.dead?
          display_message(parse_text(20, 33, ::PFM::Text::PKNICK[1] => pokemon.given_name))
        else
          if pokemon.position.between?(0, $game_temp.vs_type)
            display_message(parse_text(20, 32, ::PFM::Text::PKNICK[1] => pokemon.given_name))
          else
            if __last_scene&.player_actions&.any? { |action| action.is_a?(Battle::Actions::Switch) && action.with == pokemon }
              display_message(parse_text(20, 83, ::PFM::Text::PKNICK[1] => pokemon.given_name))
            else
              @return_data = @index
              @running = false
            end
          end
        end
      end
    end
    # Show the choice when the party is in mode :choice
    def show_choice_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(23, 209), on_validate: method(:on_skill_choice)).register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(text_get(23, 17)) if choice != 0
    end
    # Event that triggers when the player choose on which pokemon to apply the move
    def on_skill_choice
      pokemon = @party[@index]
      @call_skill_process.call(pokemon, nil)
      @call_skill_process = nil
      @mode = :menu
      @index = @return_data
      @return_data = -1
    end
    # Show the choice when the party is in mode :item
    def show_item_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(23, 209), on_validate: method(:on_item_use_choice)).register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(text_get(23, 24))
    end
    # Event that triggers when the player choose on which pokemon to use the item
    def on_item_use_choice
      pokemon = @party[@index]
      if @extend_data.on_creature_choice(pokemon, self)
        if @extend_data.open_skill
          launch_summary(:skill, @extend_data)
          if @extend_data.skill
            @return_data = @index
            @running = false
          end
        else
          if @extend_data.open_skill_learn
            GamePlay.open_move_teaching(pokemon, @extend_data.open_skill_learn) do |scene|
              @return_data = @index if MoveTeaching.from(scene).learnt
              @running = false
            end
          else
            @extend_data.on_creature_use(pokemon, self)
            @extend_data.bind(find_parent(Battle::Scene), pokemon)
            @return_data = @index
            @running = false
          end
        end
      else
        display_message(parse_text(22, 108))
      end
    end
    # Show the choice when the party is in mode :hold
    def show_hold_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(23, 146), on_validate: method(:on_item_give_choice)).register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(text_get(23, 23)) if choice != 0
    end
    # Event that triggers when the player choose on which pokemon to give the item
    def on_item_give_choice
      give_item(@extend_data)
      @running = false
    end
    # Show the choice when the party is in mode :select
    def show_select_mode_choice
      show_black_frame
      pokemon = @party[@index]
      extend_data = @extend_data
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      if extend_data.is_a?(Array)
        if !@temp_team.include?(pokemon) && !extend_data.include?(pokemon.id)
          choices.register_choice(text_get(23, 140), on_validate: method(:on_select))
        else
          if @temp_team.include?(pokemon) && !extend_data.include?(pokemon.id)
            choices.register_choice(text_get(23, 141), on_validate: method(:on_select))
          end
        end
      else
        if @temp_team.include?(pokemon)
          choices.register_choice(text_get(23, 141), on_validate: method(:on_select))
        else
          choices.register_choice(text_get(23, 140), on_validate: method(:on_select))
        end
      end
      choices.register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(text_get(23, 110)) if choice != 0
    end
    # Event that triggers when a Pokemon is selected in :select mode
    def on_select
      pokemon = @party[@index]
      if !@temp_team.include?(pokemon) && enough_pokemon?(:button)
        @temp_team << pokemon
      else
        if @temp_team.include?(pokemon)
          @temp_team[@temp_team.index(pokemon)] = nil
          @temp_team.compact!
        else
          return
        end
      end
      @team_buttons[@index].data = pokemon
      @team_buttons[@index].refresh
      init_win_text
    end
    # Check if the temporary team contains the right number of Pokemon
    # @param caller [Symbol] used to determine the caller of the method
    # return Boolean 
    def enough_pokemon?(caller = :validate)
      return if check_select_mon_var == true
      if caller == :button
        if @temp_team.size + 1 > $game_variables[Yuki::Var::Max_Pokemon_Select]
          display_message(text_get(23, 115 + $game_variables[Yuki::Var::Max_Pokemon_Select]))
          return false
        else
          return true
        end
      else
        if @temp_team.size < $game_variables[Yuki::Var::Max_Pokemon_Select]
          display_message(text_get(23, 109 + $game_variables[Yuki::Var::Max_Pokemon_Select]))
          return false
        else
          return true
        end
      end
    end
    # Check if the $game_variables[6]'s value is between 1 and 6
    # If not, call action_B to exit to map
    # return Boolean
    def check_select_mon_var
      if $game_variables[6] > 6 || $game_variables[6] < 1
        display_message('Wrong number of Pokemon to select. Number must be between 1 and 6.')
        action_B
        true
      else
        false
      end
    end
    # Show the choice when the party is in mode :map
    def show_map_mode_choice
      show_black_frame
      pokemon = @party[@index]
      choices = PFM::Choice_Helper.new(Yuki::ChoiceWindow::But, true, 999)
      choices.register_choice(text_get(23, 0), on_validate: method(:on_map_choice)).register_choice(text_get(23, 4), on_validate: method(:launch_summary)).register_choice(text_get(23, 1), on_validate: @base_ui.method(:hide_win_text))
      @base_ui.show_win_text(parse_text(23, 30, ::PFM::Text::PKNICK[0] => pokemon.given_name))
      x, y = get_choice_coordinates(choices)
      choice = choices.display_choice(@viewport, x, y, nil, choices, on_update: method(:update_menu_choice))
      hide_black_frame
      @base_ui.show_win_text(text_get(23, 17)) if choice != 0
    end
    # Event that triggers when the player has choosen a Pokemon
    def on_map_choice
      @return_data = $game_variables[Yuki::Var::Party_Menu_Sel] = @index
      @running = false
    end
    # Process the switch between two pokemon
    def process_switch
      return $game_system.se_play($data_system.buzzer_se) if @move == @index
      tmp = @team_buttons[@move].data
      @team_buttons[@move].selected = false
      @party[@move] = @team_buttons[@move].data = @team_buttons[@index].data
      @party[@index] = @team_buttons[@index].data = tmp
      @move = -1
      @base_ui.hide_win_text
      @intern_mode = :normal
      $game_player.make_encounter_count
    end
    # Process the switch between the items of two pokemon
    def process_item_switch
      return $game_system.se_play($data_system.buzzer_se) if @move == @index
      tmp = @team_buttons[@move].data.item_holding
      pokemon = @team_buttons[@move].data
      pokemon.item_holding = @team_buttons[@index].data.item_holding
      if pokemon.form_calibrate
        @team_buttons[@move].refresh
        display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon.given_name))
      end
      @team_buttons[@move].refresh
      pokemon = @team_buttons[@index].data
      pokemon.item_holding = tmp
      if pokemon.form_calibrate
        @team_buttons[@index].refresh
        display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon.given_name))
      end
      @team_buttons[@index].refresh
      @team_buttons[@move].selected = false
      @move = -1
      @base_ui.hide_win_text
      hide_item_name
      @intern_mode = :normal
    end
    # Process the fusion when the party is in mode :absofusion
    def process_absofusion_mode
      pokemon = @party[@index]
      extend_data = @extend_data
      if @temp_team.size == 1
        pokemon_selected = @temp_team.first
        if pokemon_selected == pokemon || !extend_data[1].include?(pokemon.db_symbol)
          display_message(text_get(22, 151))
        else
          if pokemon.dead?
            display_message(text_get(22, 152))
          else
            if pokemon.egg?
              display_message(text_get(22, 153))
            else
              pokemon_selected.absofusion(pokemon)
              refresh_team_buttons
              display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon_selected.given_name))
              @running = false
            end
          end
        end
      else
        return display_message(text_get(18, 70)) if pokemon.db_symbol != extend_data[0] || pokemon.absofusionned? || pokemon.egg? || pokemon.dead?
        @temp_team << pokemon
        display_message(text_get(22, 155))
        @base_ui.show_win_text(text_get(22, 155))
      end
    end
    # Process the separation when the party is in mode :separate
    def process_separate_mode
      pokemon = @party[@index]
      extend_data = @extend_data
      return display_message(text_get(18, 70)) if pokemon.db_symbol != extend_data || !pokemon.absofusionned? || pokemon.egg? || pokemon.dead?
      return display_message(text_get(22, 154)) if $actors.size >= 6
      pokemon.separate
      @team_buttons.each(&:dispose)
      create_team_buttons
      display_message(parse_text(22, 157, ::PFM::Text::PKNAME[0] => pokemon.given_name))
      @running = false
    end
  end
  # Scene displaying the Summary of a Pokemon
  class Summary < BaseCleanUpdate::FrameBalanced
    # @return [Integer] Last state index in this scene
    LAST_STATE = 2
    # Array of Key to press
    KEYS = [%i[DOWN LEFT RIGHT B], %i[DOWN LEFT RIGHT B], %i[A LEFT RIGHT B], %i[A LEFT RIGHT B], %i[A LEFT RIGHT B], %i[A LEFT RIGHT B]]
    # Text base indexes in the file
    TEXT_INDEXES = [[112, 113, 114, 115], [112, 116, 113, 115], [117, 114, 116, 115], [118, nil, nil, 13], [119, nil, nil, 13], [nil, nil, nil, 13]]
    # @return [Integer] Index of the choosen skill of the Pokemon
    attr_accessor :skill_selected
    # Create a new sumarry Interface
    # @param pokemon [PFM::Pokemon] Pokemon currently shown
    # @param mode [Symbol] :view if it's about viewing a Pokemon, :skill if it's about choosing the skill of the Pokemon
    # @param party [Array<PFM::Pokemon>] the party (allowing to switch Pokemon)
    # @param extend_data [PFM::ItemDescriptor::Wrapper, nil] the extend data information when we are in :skill mode
    def initialize(pokemon, mode = :view, party = [pokemon], extend_data = nil)
      super()
      @pokemon = pokemon
      @mode = mode
      @party = party
      @index = mode == :skill ? 2 : 0
      @party_index = party.index(pokemon).to_i
      @skill_selected = -1
      @skill_index = -1
      @selecting_move = false
      @extend_data = extend_data
    end
    private
    # Create all the UI of the scene & set their default content
    def create_graphics
      create_viewport
      create_base
      create_uis
      create_top_ui
      update_pokemon
    end
    # Create the generic base
    def create_base
      @base_ui = UI::GenericBaseMultiMode.new(@viewport, load_texts, KEYS, ctrl_id_state)
      init_win_text
    end
    # Create the various UI
    def create_uis
      @uis = [UI::Summary_Memo.new(@viewport), UI::Summary_Stat.new(@viewport), UI::Summary_Skills.new(@viewport)]
    end
    # Create the top UI
    def create_top_ui
      @top = UI::Summary_Top.new(@viewport)
    end
    # Initialize the win_text according to the mode
    def init_win_text
      return if @mode != :skill
      if @extend_data
        @base_ui.show_win_text(text_get(23, @extend_data.skill_message_id || 34))
      else
        @base_ui.show_win_text(ext_text(9000, 120))
      end
    end
    # Update the UI visibility according to the index
    def update_ui_visibility
      @uis.each_with_index { |ui, index| ui.visible = index == @index }
      update_ctrl_state
    end
    # Update the Pokemon shown in the UIs
    def update_pokemon
      @uis.each { |ui| ui.data = @pokemon }
      @top.data = @pokemon
      Audio.se_play(@pokemon.cry) unless @pokemon.egg?
      update_ui_visibility
    end
    # Update the control button state
    def update_ctrl_state
      @base_ui.mode = ctrl_id_state
    end
    # Retrieve the ID state of the ctrl button
    # @return [Integer] a number sent to @base_ui.mode to choose the texts to show
    def ctrl_id_state
      case @index
      when 0
        return 0
      when 1
        return 1
      when 2
        return 5 if @mode == :skill
        return 4 if @skill_index >= 0
        return 3 if @selecting_move
      end
      return 2
    end
    # Load all the text for the scene
    # @return [Array<Array<String>>]
    def load_texts
      TEXT_INDEXES.collect do |text_indexes|
        text_indexes.collect { |text_id| text_id && ext_text(9000, text_id) }
      end
    end
    public
    # Update the input interactions
    def update_inputs
      return update_inputs_skill if @mode == :skill
      return update_inputs_view if @mode == :view
      @running = false if Input.trigger?(:B)
      return true
    end
    # Update the graphics
    def update_graphics
      @base_ui.update_background_animation
      @top.update_graphics
    end
    # Update the mouse
    # @param _moved [Boolean] if the mouse moved during the current frame
    def update_mouse(_moved)
      update_mouse_ctrl
      update_mouse_move_button
    end
    private
    # Update the inputs in skill mode
    def update_inputs_skill
      update_inputs_move_index
      if Input.trigger?(:A)
        $game_system.se_play($data_system.decision_se)
        update_inputs_skills_validation
      else
        if Input.trigger?(:B)
          $game_system.se_play($data_system.cancel_se)
          @skill_selected = -1
          @running = false
        end
      end
      return true
    end
    # Perform the validation of the update_inputs_skills
    def update_inputs_skills_validation
      return unless (skill = @pokemon.skills_set[@uis[2].index])
      if @extend_data
        if @extend_data.on_skill_choice(skill, self)
          @extend_data.on_skill_use(@pokemon, skill, self)
          @extend_data.bind(find_parent(Battle::Scene), @pokemon, skill)
          @running = false
        else
          display_message(parse_text(22, 108))
        end
      else
        @skill_selected = @uis[2].index
        @running = false
      end
    end
    # Update the move index from inputs
    def update_inputs_move_index
      if Input.repeat?(:UP)
        @uis[2].index -= 2
      else
        if Input.repeat?(:DOWN)
          @uis[2].index += 2
        else
          if Input.repeat?(:LEFT)
            @uis[2].index -= 1
          else
            if Input.repeat?(:RIGHT)
              @uis[2].index += 1
            end
          end
        end
      end
    end
    # Update the inputs in view mode
    def update_inputs_view
      case @index
      when 0, 1
        update_inputs_basic
      when 2
        update_inputs_skill_ui
      end
      return true
    end
    # Update the basic inputs
    # @param allow_up_down [Boolean] if the player can press UP / DOWN in this method
    # @return [Boolean] if a key was pressed
    def update_inputs_basic(allow_up_down = true)
      allow_up_down &&= @party.size > 1
      if !@pokemon.egg? && !@selecting_move && index_changed(:@index, :LEFT, :RIGHT, LAST_STATE)
        update_ui_visibility
        return true
      else
        if allow_up_down && index_changed(:@party_index, :UP, :DOWN, @party.size - 1)
          update_switch_pokemon
          return true
        else
          if Input.trigger?(:B)
            $game_system.se_play($data_system.cancel_se)
            @skill_selected = -1
            @running = false
          end
        end
      end
      return false
    end
    # When the player wants to see another Pokemon
    def update_switch_pokemon
      @pokemon = @party[@party_index]
      @index = 0 if @pokemon.egg?
      $game_system.se_play($data_system.decision_se)
      update_pokemon
    end
    # Update when we are in the move section
    def update_inputs_skill_ui
      return if update_inputs_basic(!@selecting_move)
      @running = true if @selecting_move && !@running
      update_inputs_move_index if @selecting_move
      if Input.trigger?(:A)
        $game_system.se_play($data_system.decision_se)
        update_input_a_skill_ui
        update_ctrl_state
      else
        if Input.trigger?(:B)
          $game_system.se_play($data_system.cancel_se)
          @skill_selected = -1
          if @skill_index >= 0
            @uis[2].skills[@skill_index].moving = false
            @skill_index = -1
          else
            @running = false unless @selecting_move
            @selecting_move = false
          end
          update_ctrl_state
        end
      end
    end
    # Perform the task to do when the player press A on the skill ui
    def update_input_a_skill_ui
      return @selecting_move = true unless @selecting_move
      if @skill_index < 0
        @skill_index = @uis[2].index
        @uis[2].skills[@skill_index].moving = true
      else
        @uis[2].skills[@skill_index].moving = false
        @pokemon.swap_skills_index(@uis[2].index, @skill_index)
        @uis[2].data = @pokemon
        @skill_index = -1
      end
    end
    public
    # Actions to do on the button according to the actual ID state of the buttons
    ACTIONS = [%i[mouse_next mouse_left mouse_right mouse_quit], %i[mouse_next mouse_left mouse_right mouse_quit], %i[mouse_a mouse_left mouse_right mouse_quit], %i[mouse_a object_id object_id mouse_cancel], %i[mouse_a object_id object_id mouse_cancel], %i[object_id object_id object_id mouse_quit]]
    # List of the translated coordinates that gives a new move index
    TRANSLATED_MOUSE_COORD_DETECTION = [[x02 = 8..21, y01 = 18..23], [x13 = 24..37, y01], [x02, y23 = 25..30], [x13, y23]]
    private
    # Update the mouse action inside the moves buttons
    def update_mouse_move_button
      return if @index != 2
      @uis[2].skills.each_with_index do |skill, index|
        update_mouse_in_skill_button(skill, index)
      end
    end
    # Update the mouse action inside a move button
    # @param skill [UI::Summary_Skill] skill button
    # @param index [Integer] index of the button in the stack
    def update_mouse_in_skill_button(skill, index)
      return unless skill.visible && skill.simple_mouse_in?
      @uis[2].index = index if (@selecting_move || @mode == :skill) && Mouse.moved
      if Mouse.trigger?(:LEFT)
        if @selecting_move || @mode == :skill
          mouse_a
        else
          if @mode != :skill
            update_mouse_switch_skill(skill, index)
          end
        end
      end
    end
    # Try to quick switch moves using the tiny buttons
    # @param skill [UI::Summary_Skill] skill button
    # @param index [Integer] index of the button in the stack
    def update_mouse_switch_skill(skill, index)
      x, y = skill.stack[0].translate_mouse_coords
      TRANSLATED_MOUSE_COORD_DETECTION.each_with_index do |coords, index2|
        next unless coords.first.include?(x) && coords.last.include?(y)
        $game_system.se_play($data_system.decision_se)
        @pokemon.swap_skills_index(index, index2)
        @uis[2].data = @pokemon
      end
    end
    # Update the mouse interaction with the ctrl buttons
    def update_mouse_ctrl
      update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS[ctrl_id_state], @mode == :skill)
    end
    # Action performed when the player press on the [A] button with the mouse
    def mouse_a
      $game_system.se_play($data_system.decision_se)
      return update_inputs_skills_validation if @mode == :skill
      update_input_a_skill_ui
      update_ctrl_state
    end
    # Action performed when the player press on the [<] button with the mouse
    def mouse_left
      return if @mode == :skill || @pokemon.egg?
      $game_system.se_play($data_system.decision_se)
      @index -= 1
      @index = LAST_STATE if @index < 0
      update_ui_visibility
    end
    # Action performed when the player press on the [>] button with the mouse
    def mouse_right
      return if @mode == :skill || @pokemon.egg?
      $game_system.se_play($data_system.decision_se)
      @index += 1
      @index = 0 if @index > LAST_STATE
      update_ui_visibility
    end
    # Action performed when the player press on the [v] button with the mouse
    def mouse_next
      $game_system.se_play($data_system.decision_se)
      @party_index += 1
      @party_index = 0 if @party_index >= @party.size
      update_switch_pokemon
    end
    # Action performed when the player press on the [B] quit button with the mouse
    def mouse_quit
      $game_system.se_play($data_system.cancel_se)
      @skill_selected = -1
      @running = false
    end
    # Action performed when the player press on the [B] cancel button with the mouse
    def mouse_cancel
      $game_system.se_play($data_system.cancel_se)
      @skill_selected = -1
      if @skill_index >= 0
        @uis[2].skills[@skill_index].moving = false
        @skill_index = -1
      else
        @running = false unless @selecting_move
        @selecting_move = false
      end
      update_ctrl_state
    end
  end
end
GamePlay.party_menu_mixin = GamePlay::PartyMenuMixin
GamePlay.party_menu_class = GamePlay::Party_Menu
GamePlay.summary_class = GamePlay::Summary
