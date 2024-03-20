module Battle
  # Class that manage all the thing that are visually seen on the screen
  class Visual
    # @return [Hash] List of the parallel animation
    attr_reader :parallel_animations
    # @return [Array] List of the animation
    attr_reader :animations
    # @return [Viewport] the viewport used to show the sprites
    attr_reader :viewport
    # @return [Viewport] the viewport used to show some UI part
    attr_reader :viewport_sub
    # @return [Array] the element to dispose on #dispose
    attr_reader :to_dispose
    # Create a new visual instance
    # @param scene [Scene] scene that hold the logic object
    def initialize(scene)
      @scene = scene
      @screenshot = take_snapshot
      @battlers = {}
      @info_bars = {}
      @team_info = {}
      @ability_bars = {}
      @item_bars = {}
      @animations = []
      @animatable = []
      @parallel_animations = {}
      @to_dispose = []
      @locking = false
      create_graphics
      create_battle_animation_handler
      @viewport&.sort_z
    end
    # Safe to_s & inspect
    def to_s
      format('#<%<class>s:%<id>08X>', class: self.class, id: __id__)
    end
    alias inspect to_s
    # Update the visuals
    def update
      @animations.each(&:update)
      @animations.delete_if(&:done?)
      @parallel_animations.each_value(&:update)
      @gif_container&.update(@background.bitmap)
      update_battlers
      update_info_bars
      update_team_info
      update_ability_bars
      update_item_bars
    end
    # Dispose the visuals
    def dispose
      @to_dispose.each(&:dispose)
      @animations.clear
      @parallel_animations.clear
      @viewport.dispose
      @viewport_sub.dispose
    end
    # Tell if the visual are locking the battle update (for transition purpose)
    def locking?
      @locking
    end
    # Unlock the battle scene
    def unlock
      @locking = false
    end
    # Lock the battle scene
    def lock
      if block_given?
        raise 'Race condition' if locking?
        @locking = true
        yield
        return @locking = false
      end
      @locking = true
    end
    # Display animation & stuff like that by updating the scene
    # @yield [] yield the given block without argument
    # @note this function raise if the visual are not locked
    def scene_update_proc
      raise 'Unlocked visual while trying to update scene!' unless @locking
      yield
      @scene.update
      Graphics.update
    end
    # Wait for all animation to end (non parallel one)
    def wait_for_animation
      was_locked = @locking
      lock unless was_locked
      scene_update_proc {update } until @animations.all?(&:done?) && @animatable.all?(&:done?)
      unlock unless was_locked
    end
    # Snap all viewports to bitmap
    # @return [Array<Texture>]
    def snap_to_bitmaps
      return [@viewport, @viewport_sub].map(&:snap_to_bitmap)
    end
    private
    # Create all the graphics for the visuals
    def create_graphics
      create_viewport
      create_background
      create_battlers
      create_player_choice
      create_skill_choice
    end
    # Create the Visual viewport
    def create_viewport
      @viewport = Viewport.create(:main, 500)
      @viewport.extend(Viewport::WithToneAndColors)
      @viewport.shader = Shader.create(:map_shader)
      @viewport_sub = Viewport.create(:main, 501)
    end
    # Create the default background
    def create_background
      bg_name = background_name
      if Yuki::GifReader.exist?("#{bg_name}.gif", :battleback)
        @background = Sprite.new(viewport)
        @gif_container = Yuki::GifReader.create("#{bg_name}.gif", :battleback)
        @background.bitmap = Bitmap.new(@gif_container.width, @gif_container.height)
        @background.x = @background.y = 0
        @to_dispose << @background.bitmap
      else
        @background = ShaderedSprite.new(@viewport).set_bitmap(bg_name, :battleback)
      end
    end
    # Return the background name according to the current state of the player
    # @return [String]
    def background_name
      @scene.battle_info.find_background_name_to_display do |filename|
        next(RPG::Cache.battleback_exist?(filename) || Yuki::GifReader.exist?("#{filename}.gif", :battleback))
      end
    end
    # Create the battler sprites (Trainer + Pokemon)
    def create_battlers
      infos = @scene.battle_info
      (logic = @scene.logic).bank_count.times do |bank|
        infos.battlers[bank].each_with_index do |battler, position|
          sprite = BattleUI::TrainerSprite.new(@viewport, @scene, battler, bank, position, infos)
          store_battler_sprite(bank, -position - 1, sprite)
        end
        infos.vs_type.times do |position|
          sprite = BattleUI::PokemonSprite.new(@viewport, @scene)
          sprite.pokemon = logic.battler(bank, position)
          @animatable << sprite
          store_battler_sprite(bank, position, sprite)
          create_info_bar(bank, position)
          create_ability_bar(bank, position)
          create_item_bar(bank, position)
        end
        create_team_info(bank)
      end
      hide_info_bars(true)
    end
    # Update the battler sprites
    def update_battlers
      @battlers.each_value do |battlers|
        battlers.each_value(&:update)
      end
    end
    # Update the info bars
    def update_info_bars
      @info_bars.each_value do |info_bars|
        info_bars.each(&:update)
      end
    end
    # Create an ability bar
    # @param bank [Integer]
    # @param position [Integer]
    def create_ability_bar(bank, position)
      @ability_bars[bank] ||= []
      @ability_bars[bank][position] = sprite = BattleUI::AbilityBar.new(@viewport_sub, @scene, bank, position)
      @animatable << sprite
      sprite.go_out(-3600)
    end
    # Update the Ability bars
    def update_ability_bars
      @ability_bars.each_value do |ability_bars|
        ability_bars.each(&:update)
      end
    end
    # Update the item bars
    def update_item_bars
      @item_bars.each_value do |item_bars|
        item_bars.each(&:update)
      end
    end
    # Create an item bar
    # @param bank [Integer]
    # @param position [Integer]
    def create_item_bar(bank, position)
      @item_bars[bank] ||= []
      @item_bars[bank][position] = sprite = BattleUI::ItemBar.new(@viewport_sub, @scene, bank, position)
      @animatable << sprite
      sprite.go_out(-3600)
    end
    # Create the info bar for a bank
    # @param bank [Integer]
    # @param position [Integer]
    def create_info_bar(bank, position)
      info_bars = (@info_bars[bank] ||= [])
      pokemon = @scene.logic.battler(bank, position)
      info_bars[position] = sprite = BattleUI::InfoBar.new(@viewport_sub, @scene, pokemon, bank, position)
      @animatable << sprite
    end
    # Create the Trainer Party Ball
    # @param bank [Integer]
    def create_team_info(bank)
      @team_info[bank] = sprite = BattleUI::TrainerPartyBalls.new(@viewport_sub, @scene, bank)
      @animatable << sprite
    end
    # Update the team info
    def update_team_info
      @team_info.each_value(&:update)
    end
    # Create the player choice
    def create_player_choice
      @player_choice_ui = BattleUI::PlayerChoice.new(@viewport_sub, @scene)
    end
    # Create the skill choice
    def create_skill_choice
      @skill_choice_ui = BattleUI::SkillChoice.new(@viewport_sub, @scene)
    end
    # Create the battle animation handler
    def create_battle_animation_handler
      PSP.make_sprite(@viewport)
      @move_animator = PSP
    end
    # Take a snapshot
    # @return [Texture]
    def take_snapshot
      $scene.snap_to_bitmap
    end
    public
    # Method that show the pre_transition of the battle
    def show_pre_transition
      @transition = battle_transition.new(@scene, @screenshot)
      @animations << @transition
      @transition.pre_transition
      @locking = true
    end
    # Method that show the trainer transition of the battle
    def show_transition
      @animations << @transition
      @transition.transition
      @locking = true
    end
    # Function storing a battler sprite in the battler Hash
    # @param bank [Integer] bank where the battler should be
    # @param position [Integer, Symbol] Position of the battler
    # @param sprite [Sprite] battler sprite to set
    def store_battler_sprite(bank, position, sprite)
      @battlers[bank] ||= {}
      @battlers[bank][position] = sprite
    end
    # Retrieve the sprite of a battler
    # @param bank [Integer] bank where the battler should be
    # @param position [Integer, Symbol] Position of the battler
    # @return [BattleUI::PokemonSprite, nil] the Sprite of the battler if it has been stored
    def battler_sprite(bank, position)
      @battlers.dig(bank, position)
    end
    private
    # Return the current battle transition
    # @return [Class]
    def battle_transition
      collection = $game_temp.trainer_battle ? TRAINER_TRANSITIONS : WILD_TRANSITIONS
      transition_class = collection[$game_variables[Yuki::Var::TrainerTransitionType]]
      log_debug("Choosen transition class : #{transition_class}")
      return transition_class
    end
    # Show the debug transition
    def show_debug_transition
      2.times do |bank|
        @scene.battle_info.battlers[bank].each_with_index do |battler, position|
          battler_sprite(bank, -position - 1)&.visible = false
        end
      end
      Graphics.transition(1)
    end
    # List of Wild Transitions
    # @return [Hash{ Integer => Class<Transition::Base> }]
    WILD_TRANSITIONS = {}
    # List of Trainer Transitions
    # @return [Hash{ Integer => Class<Transition::Base> }]
    TRAINER_TRANSITIONS = {}
    public
    # Method that shows the trainer choice
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    # @return [Symbol, Array(Symbol, Hash), nil] :attack, :bag, :pokemon, :flee, :cancel, :try_next
    def show_player_choice(pokemon_index)
      if (pokemon = @scene.logic.battler(0, pokemon_index)).effects.has?(&:force_next_turn_action?)
        effect = pokemon.effects.get(&:force_next_turn_action?)
        return :action, effect.make_action
      end
      show_player_choice_begin(pokemon_index)
      show_player_choice_loop
      show_player_choice_end(pokemon_index)
      return @player_choice_ui.result, @player_choice_ui.action
    end
    # Show the message "What will X do"
    # @param pokemon_index [Integer]
    def spc_show_message(pokemon_index)
      @scene.message_window.wait_input = false
    end
    private
    # Begining of the show_player_choice
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    def show_player_choice_begin(pokemon_index)
      pokemon = @scene.logic.battler(0, pokemon_index)
      @locking = true
      @player_choice_ui.reset(@scene.logic.switch_handler.can_switch?(pokemon))
      if @player_choice_ui.out?
        @player_choice_ui.go_in
        @animations << @player_choice_ui
        wait_for_animation
      end
      spc_show_message(pokemon_index)
      spc_start_bouncing_animation(pokemon_index)
    end
    # Loop process of the player choice
    def show_player_choice_loop
      loop do
        @scene.update
        @player_choice_ui.update
        Graphics.update
        break if @player_choice_ui.validated?
      end
    end
    # End of the show_player_choice
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    def show_player_choice_end(pokemon_index)
      @player_choice_ui.go_out
      @animations << @player_choice_ui
      if @player_choice_ui.result != :attack
        spc_stop_bouncing_animation(pokemon_index)
        wait_for_animation
      end
      @locking = false
    end
    # Start the IdlePokemonAnimation (bouncing)
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    def spc_start_bouncing_animation(pokemon_index)
      return if @parallel_animations[IdlePokemonAnimation]
      sprite = battler_sprite(0, pokemon_index)
      bar = @info_bars.dig(0, pokemon_index)
      @parallel_animations[IdlePokemonAnimation] = IdlePokemonAnimation.new(self, sprite, bar)
    end
    # Stop the IdlePokemonAnimation (bouncing)
    # @param _pokemon_index [Integer] Index of the Pokemon in the party
    def spc_stop_bouncing_animation(_pokemon_index)
      @parallel_animations[IdlePokemonAnimation]&.remove
    end
    public
    # Method that show the skill choice and store it inside an instance variable
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    # @return [Boolean] if the player has choose a skill
    def show_skill_choice(pokemon_index)
      return :try_next if spc_cannot_use_this_pokemon?(pokemon_index)
      effect = @scene.logic.battler(0, pokemon_index).effects.get(&:force_next_move?)
      if effect
        @skill_choice_ui.encore_reset(@scene.logic.battler(0, pokemon_index), effect.move)
        return true
      end
      show_skill_choice_begin(pokemon_index)
      show_skill_choice_loop
      show_skill_choice_end(pokemon_index)
      return @skill_choice_ui.result != :cancel
    end
    # Method that show the target choice once the skill was choosen
    # @return [Array<PFM::PokemonBattler, Battle::Move, Integer(bank), Integer(position), Boolean(mega)>, nil]
    def show_target_choice
      return stc_result if stc_cannot_choose_target?
      show_target_choice_begin
      show_target_choice_loop
      show_target_choice_end
      return stc_result(@target_selection_window.result)
    ensure
      @target_selection_window&.dispose
      @target_selection_window = nil
    end
    private
    # Begin of the skill_choice
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    def show_skill_choice_begin(pokemon_index)
      spc_start_bouncing_animation(pokemon_index)
      @locking = true
      wait_for_animation
      @skill_choice_ui.reset(@scene.logic.battler(0, pokemon_index))
      @skill_choice_ui.go_in
      @animations << @skill_choice_ui
      wait_for_animation
    end
    # Loop of the skill_choice
    def show_skill_choice_loop
      loop do
        @scene.update
        @skill_choice_ui.update
        Graphics.update
        break if @skill_choice_ui.validated?
      end
    end
    # End of the skill_choice
    # @param pokemon_index [Integer] Index of the Pokemon in the party
    def show_skill_choice_end(pokemon_index)
      spc_stop_bouncing_animation(pokemon_index)
      @skill_choice_ui.go_out
      @animations << @skill_choice_ui
      wait_for_animation
      @locking = false
    end
    # Show the Target Selection Window
    def show_target_choice_begin
      @locking = true
      @target_selection_window = BattleUI::TargetSelection.new(@viewport_sub, @skill_choice_ui.pokemon, @skill_choice_ui.result, @scene.logic)
      spc_start_bouncing_animation(@skill_choice_ui.pokemon.position)
    end
    # Loop of the target choice
    def show_target_choice_loop
      loop do
        @scene.update
        @target_selection_window.update
        Graphics.update
        break if @target_selection_window.validated?
      end
    end
    # End of the target choice
    def show_target_choice_end
      spc_stop_bouncing_animation(@skill_choice_ui.pokemon.position)
      @locking = false
    end
    # Make the result of show_target_choice method
    # @param result [Array, :auto, :cancel]
    def stc_result(result = :auto)
      return @skill_choice_ui.pokemon if result == :cancel && @skill_choice_ui.pokemon.effects.get(&:force_next_move?)
      return nil if result == :cancel
      arr = [@skill_choice_ui.pokemon, @skill_choice_ui.result]
      if result.is_a?(Array)
        arr.concat(result)
      else
        if result == :auto
          targets = @skill_choice_ui.result.battler_targets(@skill_choice_ui.pokemon, @scene.logic)
          if targets.empty?
            arr.concat([1, 0])
          else
            arr << targets.first.bank
            arr << targets.first.position
          end
        else
          return nil
        end
      end
      arr << @skill_choice_ui.mega_enabled
      return arr
    end
    # Tell if the Pokemon can be used or not
    # @return [Boolean] if the Pokemon cannot be used
    def spc_cannot_use_this_pokemon?(pokemon_index)
      return @scene.logic.battler(0, pokemon_index)&.party_id != 0
    end
    # Tell if we can choose a target
    # @return [Boolean]
    def stc_cannot_choose_target?
      return @scene.logic.battle_info.vs_type == 1 || BattleUI::TargetSelection.cannot_show?(@skill_choice_ui.result, @skill_choice_ui.pokemon, @scene.logic)
    end
    public
    # Variable giving the position of the battlers to show from bank 0 in bag UI
    BAG_PARTY_POSITIONS = 0..5
    # Method that show the item choice
    # @return [PFM::ItemDescriptor::Wrapper, nil]
    def show_item_choice
      data_to_return = nil
      GamePlay.open_battle_bag(retrieve_party) do |battle_bag_scene|
        data_to_return = battle_bag_scene.battle_item_wrapper
      end
      log_debug("show_item_choice returned #{data_to_return}")
      return data_to_return
    end
    # Method that show the pokemon choice
    # @param forced [Boolean]
    # @return [PFM::PokemonBattler, nil]
    def show_pokemon_choice(forced = false)
      data_to_return = nil
      GamePlay.open_party_menu_to_switch(party = retrieve_party, forced) do |scene|
        data_to_return = party[scene.return_data] if scene.pokemon_selected?
      end
      log_debug("show_pokemon_choice returned #{data_to_return}")
      return data_to_return
    end
    private
    # Method that returns the party for the Bag & Party scene
    # @return [Array<PFM::PokemonBattler>]
    def retrieve_party
      return @scene.logic.all_battlers.select(&:from_player_party?)
    end
    public
    # Hide all the bars
    # @param no_animation [Boolean] skip the going out animation
    # @param bank [Integer, nil] bank where the info bar should be hidden
    def hide_info_bars(no_animation = false, bank: nil)
      enum = bank ? [@info_bars[bank]].each : @info_bars.each_value
      enum.each do |info_bars|
        if no_animation
          info_bars.each { |bar| bar.visible = false }
        else
          info_bars.each { |bar| bar.go_out unless bar.out? }
        end
      end
    end
    # Show all the bars
    # @param bank [Integer, nil] bank where the info bar should be hidden
    def show_info_bars(bank: nil)
      enum = bank ? [@info_bars[bank]].each : @info_bars.each_value
      enum.each do |info_bars|
        info_bars.each do |bar|
          bar.pokemon = bar.pokemon
          next(bar.visible = false) unless bar.pokemon&.alive?
          bar.go_in unless bar.in?
        end
      end
    end
    # Show a specific bar
    # @param pokemon [PFM::PokemonBattler] the pokemon that should be shown by the bar
    def show_info_bar(pokemon)
      bar = @info_bars.dig(pokemon.bank, pokemon.position)
      return log_error("No battle bar at position #{pokemon.bank}, #{pokemon.position}") unless bar
      bar.pokemon = pokemon
      return if pokemon.dead?
      bar.go_in unless bar.in?
    end
    # Show a specific bar
    # @param pokemon [PFM::PokemonBattler] the pokemon that was shown by the bar
    def hide_info_bar(pokemon)
      bar = @info_bars.dig(pokemon.bank, pokemon.position)
      return log_error("No battle bar at position #{pokemon.bank}, #{pokemon.position}") unless bar
      bar.go_out unless bar.out?
    end
    # Refresh a specific bar (when Pokemon loses HP or change state)
    # @param pokemon [PFM::PokemonBattler] the pokemon that was shown by the bar
    def refresh_info_bar(pokemon)
      bar = @info_bars.dig(pokemon.bank, pokemon.position)
      @team_info[pokemon.bank]&.refresh
      return log_error("No battle bar at position #{pokemon.bank}, #{pokemon.position}") unless bar
      bar.refresh
    end
    # Set the state info
    # @param state [Symbol] kind of state (:choice, :move, :move_animation)
    # @param pokemon [Array<PFM::PokemonBattler>] optional list of Pokemon to show (move)
    def set_info_state(state, pokemon = nil)
      if state == :choice
        show_info_bars(bank: 1)
        hide_info_bars(bank: 0)
        show_team_info
      else
        if state == :move
          hide_info_bars
          pokemon&.each { |target| show_info_bar(target) }
        else
          if state == :move_animation
            hide_info_bars
            hide_team_info
          end
        end
      end
    end
    # Show team info
    def show_team_info
      @team_info.each_value do |info|
        info.refresh
        info.go_in unless info.in?
      end
    end
    # Hide team info
    def hide_team_info
      @team_info.each_value { |info| info.go_out unless info.out? }
    end
    public
    # Show HP animations
    # @param targets [Array<PFM::PokemonBattler>]
    # @param hps [Array<Integer>]
    # @param effectiveness [Array<Integer, nil>]
    # @param messages [Proc] messages shown right before the post processing
    def show_hp_animations(targets, hps, effectiveness = [], &messages)
      lock do
        wait_for_animation
        animations = targets.map.with_index do |target, index|
          show_info_bar(target)
          if hps[index] && hps[index] == 0
            next(Battle::Visual::FakeHPAnimation.new(@scene, target, effectiveness[index]))
          else
            if hps[index]
              next(Battle::Visual::HPAnimation.new(@scene, target, hps[index], effectiveness[index]))
            end
          end
        end
        scene_update_proc {animations.each(&:update) } until animations.all?(&:done?)
        messages&.call
        show_kos(targets)
      end
    end
    # Show KO animations
    # @param targets [Array<PFM::PokemonBattler>]
    def show_kos(targets)
      targets = targets.select(&:dead?)
      return if targets.empty?
      play_ko_se
      targets.each do |target|
        battler_sprite(target.bank, target.position).go_out
        hide_info_bar(target)
      end
      targets.each do |target|
        @scene.display_message_and_wait(parse_text_with_pokemon(19, 0, target, PFM::Text::PKNICK[0] => target.given_name))
        target.status = 0
      end
    end
    # Show the ability animation
    # @param target [PFM::PokemonBattler]
    # @param [Boolean] no_go_out Set if the out animation should be not played automatically
    def show_ability(target, no_go_out = false)
      ability_bar = @ability_bars[target.bank][target.position]
      item_bar = @item_bars[target.bank][target.position]
      return unless ability_bar
      ability_bar.data = target
      ability_bar.go_in_ability(no_go_out)
      if !item_bar || item_bar.done?
        ability_bar.z = 0
      else
        ability_bar.z = item_bar.z + 1
      end
    end
    # Hide the ability animation (no effect if no_go_out = false)
    # @param target [PFM::PokemonBattler]
    def hide_ability(target)
      ability_bar = @ability_bars[target.bank][target.position]
      return unless ability_bar || ability_bar.no_go_out
      ability_bar.go_out
    end
    # Show the item user animation
    # @param target [PFM::PokemonBattler]
    def show_item(target)
      ability_bar = @ability_bars[target.bank][target.position]
      item_bar = @item_bars[target.bank][target.position]
      return unless item_bar
      item_bar.data = target
      item_bar.go_in_ability
      item_bar.z = ability_bar.z + 1 unless !ability_bar || ability_bar.done?
      if !ability_bar || ability_bar.done?
        item_bar.z = 0
      else
        item_bar.z = ability_bar.z + 1
      end
    end
    # Show the pokemon switch form animation
    # @param target [PFM::PokemonBattler]
    def show_switch_form_animation(target)
      battler_sprite(target.bank, target.position)&.pokemon = target
    end
    # Make a move animation
    # @param user [PFM::PokemonBattler]
    # @param targets [Array<PFM::PokemonBattler>]
    # @param move [Battle::Move]
    def show_move_animation(user, targets, move)
      return unless $options.show_animation
      $data_animations ||= load_data('Data/Animations.rxdata')
      id = move.id
      user_sprite = battler_sprite(user.bank, user.position)
      target_sprite = battler_sprite(targets.first.bank, targets.first.position)
      original_rect = @viewport.rect.clone
      @viewport.rect.height = Viewport::CONFIGS[:main][:height]
      lock {@move_animator.move_animation(user_sprite, target_sprite, id, user.bank != 0) }
      @viewport.rect = original_rect
    end
    # Show a dedicated animation
    # @param target [PFM::PokemonBattler]
    # @param id [Integer]
    def show_rmxp_animation(target, id)
      return unless $options.show_animation
      wait_for_animation
      $data_animations ||= load_data('Data/Animations.rxdata')
      lock {@move_animator.animation(battler_sprite(target.bank, target.position), id, target.bank != 0) }
    end
    # Show the exp distribution
    # @param exp_data [Hash{ PFM::PokemonBattler => Integer }] info about experience each pokemon should receive
    def show_exp_distribution(exp_data)
      lock do
        exp_ui = BattleUI::ExpDistribution.new(@viewport_sub, @scene, exp_data)
        @scene.display_message_and_wait(ext_text(8999, 21))
        exp_ui.start_animation
        scene_update_proc {exp_ui.update } until exp_ui.done?
        exp_ui.dispose
      end
      exp_data.each_key { |pokemon| refresh_info_bar(pokemon) if pokemon.can_fight? }
    end
    # Show the catching animation
    # @param target_pokemon [PFM::PokemonBattler] pokemon being caught
    # @param ball [Studio::BallItem] ball used
    # @param nb_bounce [Integer] number of time the ball move
    # @param caught [Integer] if the pokemon got caught
    def show_catch_animation(target_pokemon, ball, nb_bounce, caught)
      origin = battler_sprite(0, 0)
      target = battler_sprite(target_pokemon.bank, target_pokemon.position)
      sprite = UI::ThrowingBallSprite.new(origin.viewport, ball)
      animation = create_throw_ball_animation(sprite, target, origin)
      create_move_ball_animation(animation, sprite, nb_bounce)
      caught ? create_caught_animation(animation, sprite) : create_break_animation(animation, sprite, target)
      animation.start
      @animations << animation
      wait_for_animation
    end
    private
    # Create the throw ball animation
    # @param sprite [UI::ThrowingBallSprite]
    # @param target [Sprite]
    # @param origin [Sprite]
    # @return [Yuki::Animation::TimedAnimation]
    def create_throw_ball_animation(sprite, target, origin)
      ya = Yuki::Animation
      sprite.set_position(-sprite.ball_offset_y, origin.y - sprite.trainer_offset_y)
      animation = ya.scalar_offset(0.4, sprite, :y, :y=, 0, -64, distortion: :SQUARE010_DISTORTION)
      animation.parallel_play(ya.move(0.4, sprite, sprite.x, sprite.y, target.x, target.y - sprite.trainer_offset_y))
      animation.parallel_play(ya.scalar(0.4, sprite, :throw_progression=, 0, 1))
      animation.parallel_play(ya.se_play(*sending_ball_se))
      animation.play_before(ya.scalar(0.2, sprite, :open_progression=, 0, 1))
      animation.play_before(ya.scalar(0.2, target, :zoom=, sprite_zoom, 0))
      animation.play_before(ya.se_play(*opening_ball_se))
      animation.play_before(ya.scalar(0.5, sprite, :close_progression=, 0, 1))
      fall_animation = ya.scalar(1, sprite, :y=, target.y - sprite.ball_offset_y, target.y - sprite.trainer_offset_y, distortion: fall_distortion)
      sound_animation = ya.wait(0.2)
      sound_animation.play_before(ya.se_play(*bouncing_ball_se))
      sound_animation.play_before(ya.wait(0.4))
      sound_animation.play_before(ya.se_play(*bouncing_ball_se))
      sound_animation.play_before(ya.wait(0.4))
      sound_animation.play_before(ya.se_play(*bouncing_ball_se))
      animation.play_before(fall_animation)
      fall_animation.parallel_play(sound_animation)
      return animation
    end
    def fall_distortion
      return proc { |x| (Math.cos(2.5 * Math::PI * x) * Math.exp(-2 * x)).abs }
    end
    # Create the move animation
    # @param animation [Yuki::Animation::TimedAnimation]
    # @param sprite [UI::ThrowingBallSprite]
    # @param nb_bounce [Integer]
    def create_move_ball_animation(animation, sprite, nb_bounce)
      ya = Yuki::Animation
      animation.play_before(ya.wait(0.5))
      nb_bounce.clamp(0, 3).times do
        animation.play_before(ya.se_play(*moving_ball_se))
        animation.play_before(ya.scalar(0.5, sprite, :move_progression=, 0, 1))
        animation.play_before(ya.wait(0.5))
      end
    end
    # Create the move animation
    # @param animation [Yuki::Animation::TimedAnimation]
    # @param sprite [UI::ThrowingBallSprite]
    def create_caught_animation(animation, sprite)
      ya = Yuki::Animation
      animation.play_before(ya.se_play(*catching_ball_se))
      animation.play_before(ya.scalar(0.5, sprite, :caught_progression=, 0, 1))
    end
    # Create the move animation
    # @param animation [Yuki::Animation::TimedAnimation]
    # @param sprite [UI::ThrowingBallSprite]
    # @param target [Sprite]
    def create_break_animation(animation, sprite, target)
      ya = Yuki::Animation
      animation.play_before(ya.se_play(*break_ball_se))
      animation.play_before(ya.scalar(0.5, sprite, :break_progression=, 0, 1))
      animation.play_before(ya.scalar(0.2, target, :zoom=, 0, sprite_zoom))
      animation.play_before(ya.send_command_to(sprite, :dispose))
    end
    # Sprite zoom of the Pokemon battler
    def sprite_zoom
      return 1
    end
    # SE played when a Pokemon is K.O.
    def play_ko_se
      Audio.se_play('Audio/SE/Down.wav', 100, 80)
    end
    # SE played when the ball is sent
    def sending_ball_se
      return 'fall', 100, 120
    end
    # SE played when the ball is opening
    def opening_ball_se
      return 'pokeopen'
    end
    # SE played when the ball is bouncing
    def bouncing_ball_se
      return 'pokerebond'
    end
    # SE played when the ball is moving
    def moving_ball_se
      return 'pokemove'
    end
    # SE played when the Pokemon is caught
    def catching_ball_se
      return 'pokeopenbreak', 100, 180
    end
    # SE played when the Pokemon escapes from the ball
    def break_ball_se
      return 'pokeopenbreak'
    end
    public
    # Animation shown when a Creature is currently selected and wait for the player to choose its actions
    class IdlePokemonAnimation
      # Pixel offset for each index of the sprite
      OFFSET_SPRITE = [0, 1, 2, 3, 4, 5, 5, 4, 3, 2, 1, 0]
      # Pixel offset for each index of the bar
      OFFSET_BAR = [0, -1, -2, -3, -4, -5, -5, -4, -3, -2, -1, 0]
      # Create a new IdlePokemonAnimation
      # @param visual [Battle::Visual]
      # @param pokemon [BattleUI::PokemonSprite]
      # @param bar [BattleUI::InfoBar]
      def initialize(visual, pokemon, bar)
        @visual = visual
        @pokemon = pokemon
        @pokemon_origin = pokemon.send(:sprite_position)
        @bar = bar
        @bar_origin = bar.send(:sprite_position)
        @animation = create_animation
      end
      # Function that updates the idle animation
      def update
        @animation.update
      end
      # Function that rmoves the idle animation from the visual
      def remove
        @pokemon.y = @pokemon_origin.last if @pokemon.in?
        @bar.y = @bar_origin.last if @bar.in?
        @visual.parallel_animations.delete(self.class)
      end
      private
      # Function that create the animation
      # @return [Yuki::Animation::TimedLoopAnimation]
      def create_animation
        root = Yuki::Animation::TimedLoopAnimation.new(1.2)
        pokemon_anim = Yuki::Animation::DiscreetAnimation.new(1.2, self, :move_pokemon, 0, OFFSET_SPRITE.size - 1)
        bar_anim = Yuki::Animation::DiscreetAnimation.new(1.2, self, :move_bar, 0, OFFSET_BAR.size - 1)
        pokemon_anim.parallel_add(bar_anim)
        root.play_before(pokemon_anim)
        root.start
        return root
      end
      # Function that moves the bar using the relative offset specified by 
      def move_bar(index)
        return if @bar.out?
        @bar.y = @bar_origin.last + OFFSET_BAR[index]
      end
      # Function that moves the pokemon using the relative offset specified by 
      def move_pokemon(index)
        return if @pokemon.out?
        @pokemon.y = @pokemon_origin.last + OFFSET_SPRITE[index]
      end
    end
    public
    # Animation of HP getting down/up
    class HPAnimation < Yuki::Animation::DiscreetAnimation
      # Create the HP Animation
      # @param scene [Battle::Scene] scene responsive of holding all the battle information
      # @param target [PFM::PokemonBattler] Pokemon getting its HP down/up
      # @param quantity [Integer] quantity of HP the Pokemon is getting
      # @param effectiveness [Integer, nil] optional param to play the effectiveness sound if that comes from using a move
      def initialize(scene, target, quantity, effectiveness = nil)
        @scene = scene
        @target = target
        @target_hp = (target.hp + (quantity == 0 ? -1 : quantity)).clamp(0, target.max_hp)
        time = (quantity.clamp(-target.hp, target.max_hp).abs.to_f / 60).clamp(0.2, 1)
        super(time, target, :hp=, target.hp, @target_hp)
        create_sub_animation
        start
        effectiveness_sound(effectiveness) if quantity != 0 && effectiveness
      end
      # Update the animation
      def update
        super
        @scene.visual.refresh_info_bar(@target)
      end
      # Detect if the animation if done
      # @return [Boolean]
      def done?
        return false unless super
        final_hp_refresh
        return true
      end
      # Play the effectiveness sound
      def effectiveness_sound(effectiveness)
        if effectiveness == 1
          Audio.se_play('Audio/SE/hit')
        else
          if effectiveness > 1
            Audio.se_play('Audio/SE/hitplus')
          else
            Audio.se_play('Audio/SE/hitlow')
          end
        end
      end
      private
      # Function that refreshes the bar to the final value
      def final_hp_refresh
        @target.hp = @target_hp while @target_hp != @target.hp
        @scene.visual.refresh_info_bar(@target)
      end
      # Function that creates the sub animation
      def create_sub_animation
        play_before(Yuki::Animation.send_command_to(self, :final_hp_refresh))
        if @target_hp > 0
          play_before(Yuki::Animation.wait((1 - @time_to_process).clamp(0.25, 1)))
        else
          play_before(Yuki::Animation.wait(0.1))
        end
      end
    end
    public
    # Waiting animation if 0 HP are dealt
    class FakeHPAnimation < Yuki::Animation::TimedAnimation
      # Create the HP Animation
      # @param scene [Battle::Scene] scene responsive of holding all the battle information
      # @param target [PFM::PokemonBattler] Pokemon getting its HP down/up
      # @param effectiveness [Integer, nil] optional param to play the effectiveness sound if that comes from using a move
      def initialize(scene, target, effectiveness = nil)
        @scene = scene
        @target = target
        time = 1
        super(time)
        start
        effectiveness_sound(effectiveness) if effectiveness
      end
      # Update the animation
      def update
        super
        @scene.visual.refresh_info_bar(@target)
      end
      # Detect if the animation if done
      # @return [Boolean]
      def done?
        return false unless super
        @scene.visual.refresh_info_bar(@target)
        return true
      end
      # Play the effectiveness sound
      def effectiveness_sound(effectiveness)
        if effectiveness == 1
          Audio.se_play('Audio/SE/hit')
        else
          if effectiveness > 1
            Audio.se_play('Audio/SE/hitplus')
          else
            Audio.se_play('Audio/SE/hitlow')
          end
        end
      end
    end
    public
    # Module holding all the Battle transition
    module Transition
      # Base class of all transitions
      class Base
        # Create a new transition
        # @param scene [Battle::Scene]
        # @param screenshot [Texture]
        def initialize(scene, screenshot)
          @scene = scene
          @visual = scene.visual
          @viewport = @visual.viewport
          @screenshot = screenshot
          @animations = []
          @to_dispose = [screenshot]
        end
        # Update the transition
        def update
          @animations.each(&:update)
        end
        # Tell if the transition is done
        # @return [Boolean]
        def done?
          return @animations.all?(&:done?)
        end
        # Dispose the transition (safely clean all things that needs to be disposed)
        def dispose
          @to_dispose.each do |disposable|
            disposable.dispose unless disposable.disposed?
          end
        end
        # Start the pre transition (fade in)
        #
        # - Initialize **all** the sprites
        # - Create all the pre-transition animations
        # - Force Graphics transition if needed.
        def pre_transition
          create_all_sprites
          @animations.clear
          transition = create_pre_transition_animation
          transition.play_before(Yuki::Animation.send_command_to(@visual, :unlock))
          @animations << transition
          Graphics.transition(1)
          @animations.each(&:start)
        end
        # Start the transition (fade out)
        #
        # - Create all the transition animation
        # - Add all the message to the animation
        # - Add the send enemy Pokemon animation
        # - Add the send actor Pokemon animation
        def transition
          @animations.clear
          @scene.message_window.visible = true
          @scene.message_window.blocking = true
          @scene.message_window.stay_visible = true
          @scene.message_window.wait_input = true
          ya = Yuki::Animation
          main = create_fade_out_animation
          main.play_before(create_sprite_move_animation)
          @animations << main
          @animations << create_background_animation
          @animations << create_paralax_animation
          main.play_before(ya.message_locked_animation).play_before(ya.send_command_to(self, :show_appearing_message)).play_before(ya.send_command_to(@scene.visual, :show_team_info)).play_before(ya.send_command_to(self, :start_enemy_send_animation))
          @animations.each(&:start)
        end
        # Function that starts the Enemy send animation
        def start_enemy_send_animation
          log_debug('start_enemy_send_animation')
          ya = Yuki::Animation
          animation = create_enemy_send_animation
          animation.parallel_add(ya.send_command_to(self, :show_enemy_send_message))
          animation.play_before(ya.message_locked_animation)
          animation.play_before(ya.send_command_to(self, :start_actor_send_animation))
          animation.start
          @animations << animation
        end
        # Function that starts the Actor send animation
        def start_actor_send_animation
          log_debug('start_actor_send_animation')
          ya = Yuki::Animation
          animation = create_player_send_animation
          animation.parallel_add(ya.message_locked_animation.play_before(ya.send_command_to(self, :show_player_send_message)))
          animation.play_before(ya.send_command_to(@visual, :unlock)).play_before(ya.send_command_to(self, :dispose))
          animation.start
          @animations << animation
        end
        private
        # Function that creates all the sprites
        #
        # Please, call super of this function if you want to get the screenshot sprite!
        def create_all_sprites
          @screenshot_sprite = ShaderedSprite.new(@viewport)
          @screenshot_sprite.bitmap = @screenshot
          @screenshot_sprite.z = 100_000
        end
        # Function that creates the Yuki::Animation related to the pre transition
        # @return [Yuki::Animation::TimedAnimation]
        def create_pre_transition_animation
          animation = Yuki::Animation.send_command_to(Graphics, :freeze)
          animation.play_before(Yuki::Animation.send_command_to(@screenshot_sprite, :dispose))
          return animation
        end
        # Function that create the fade out animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_fade_out_animation
          return Yuki::Animation.send_command_to(Graphics, :transition)
        end
        # Function that create the sprite movement animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_sprite_move_animation
          return Yuki::Animation.wait(0)
        end
        # Function that creates the background movement animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_background_animation
          return Yuki::Animation.wait(0)
        end
        # Function that create the paralax animation
        # @return [Yuki::Animation::TimedLoopAnimation]
        def create_paralax_animation
          return Yuki::Animation::TimedLoopAnimation.new(100)
        end
        # Function that create the animation of the enemy sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_enemy_send_animation
          return Yuki::Animation.wait(0)
        end
        # Function that create the animation of the player sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_player_send_animation
          return Yuki::Animation.wait(0)
        end
        # Function that shows the message about Wild appearing / Trainer wanting to fight
        def show_appearing_message
          @scene.display_message(appearing_message)
          @scene.message_window.blocking = false
        end
        # Return the "appearing/issuing" message
        # @return [String]
        def appearing_message
          return @scene.battle_info.trainer_battle? ? Message.trainer_issuing_a_challenge : Message.wild_battle_appearance
        end
        # Function that shows the message about enemy sending its Pokemon
        def show_enemy_send_message
          return unless @scene.battle_info.trainer_battle?
          @scene.display_message(enemy_send_message)
        end
        # Return the "Enemy sends out" message
        # @return [String]
        def enemy_send_message
          return Message.trainer_sending_pokemon_start
        end
        # Function that shows the message about player sending its Pokemon
        def show_player_send_message
          @scene.message_window.stay_visible = false
          @scene.display_message(player_send_message)
        end
        # Return the third message shown
        # @return [String]
        def player_send_message
          return Message.player_sending_pokemon_start
        end
        # Get the enemy Pokemon sprites
        # @return [Array<ShaderedSprite>]
        def enemy_pokemon_sprites
          sprites = $game_temp.vs_type.times.map do |i|
            @scene.visual.battler_sprite(1, i)
          end.compact.select(&:pokemon).select { |sprite| sprite.pokemon.alive? }
          return sprites
        end
        # Get the actor sprites (and hide the mons)
        # @return [Array<ShaderedSprite>]
        def actor_sprites
          sprites = $game_temp.vs_type.times.map do |i|
            @scene.visual.battler_sprite(0, i)&.zoom = 0
            next(@scene.visual.battler_sprite(0, -i - 1))
          end.compact
          return sprites
        end
        # Get the actor Pokemon sprites
        # @return [Array<ShaderedSprite>]
        def actor_pokemon_sprites
          sprites = $game_temp.vs_type.times.map do |i|
            @scene.visual.battler_sprite(0, i)
          end.compact.select(&:pokemon).select { |sprite| sprite.pokemon.alive? }
          return sprites
        end
        # Function that gets the enemy sprites (and hide the mons)
        # @return [Array<ShaderedSprite>]
        def enemy_sprites
          sprites = $game_temp.vs_type.times.map do |i|
            @scene.visual.battler_sprite(1, i)&.zoom = 0
            next(@scene.visual.battler_sprite(1, -i - 1))
          end.compact
          return sprites
        end
      end
      # Trainer transition of Red/Blue/Yellow games
      class RBYTrainer < Base
        # Constant giving the X displacement done by the sprites
        DISPLACEMENT_X = 360
        private
        # Return the pre_transtion sprite name
        # @return [String]
        def pre_transition_sprite_name
          'rbj/trainer'
        end
        # Function that creates all the sprites
        def create_all_sprites
          super
          create_top_sprite
          create_enemy_sprites
          create_actors_sprites
        end
        # Function that creates the top sprite
        def create_top_sprite
          @top_sprite = ShaderedSprite.new(@viewport)
          @top_sprite.z = @screenshot_sprite.z * 2
          @top_sprite.set_bitmap(pre_transition_sprite_name, :transition)
          @top_sprite.zoom = @viewport.rect.width / @top_sprite.width.to_f
          @top_sprite.y = (@viewport.rect.height - @top_sprite.height * @top_sprite.zoom_y) / 2
          @top_sprite.shader = Shader.create(:rby_trainer)
        end
        # Function that creates the enemy sprites
        def create_enemy_sprites
          @enemy_sprites = enemy_sprites
          @enemy_sprites.each do |sprite|
            sprite.x -= DISPLACEMENT_X
          end
        end
        # Function that creates the actor sprites
        def create_actors_sprites
          @actor_sprites = actor_sprites
          @actor_sprites.each do |sprite|
            sprite.x += DISPLACEMENT_X
          end
        end
        # Function that creates the Yuki::Animation related to the pre transition
        # @return [Yuki::Animation::TimedAnimation]
        def create_pre_transition_animation
          transitioner = proc { |t| @top_sprite.shader.set_float_uniform('t', t) }
          ya = Yuki::Animation
          animation = ya::ScalarAnimation.new(2.75, transitioner, :call, 0, 1)
          animation.play_before(ya.send_command_to(@viewport.color, :set, 0, 0, 0, 255))
          animation.play_before(ya.send_command_to(@top_sprite, :dispose))
          animation.play_before(ya.send_command_to(@screenshot_sprite, :dispose))
          animation.play_before(ya.wait(0.25))
          return animation
        end
        # Function that create the fade out animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_fade_out_animation
          animation = Yuki::Animation.send_command_to(@viewport.color, :set, 0, 0, 0, 0)
          animation.play_before(Yuki::Animation.send_command_to(Graphics, :transition, 15))
          return animation
        end
        # Function that create the sprite movement animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_sprite_move_animation
          ya = Yuki::Animation
          animations = @enemy_sprites.map do |sp|
            ya.move(0.8, sp, sp.x, sp.y, sp.x + DISPLACEMENT_X, sp.y)
          end
          animation = animations.pop
          animations.each { |a| animation.parallel_add(a) }
          @actor_sprites.each do |sp|
            animation.parallel_add(ya.move(0.8, sp, sp.x, sp.y, sp.x - DISPLACEMENT_X, sp.y))
          end
          @enemy_sprites.each { |sp| animation.play_before(ya.send_command_to(sp, :shader=, nil)) }
          cries = @enemy_sprites.select { |sp| sp.respond_to?(:cry) }
          cries.each { |sp| animation.play_before(ya.send_command_to(sp, :cry)) }
          return animation
        end
        # Function that create the animation of the player sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_player_send_animation
          ya = Yuki::Animation
          animations = @actor_sprites.map do |sp|
            next(ya.move(1, sp, sp.x, sp.y, -sp.width, sp.y).parallel_play(ya.wait(0.2).play_before(ya.send_command_to(sp, :show_next_frame)).root))
          end
          animation = animations.pop
          animations.each { |anim| animation.parallel_add(anim) }
          actor_pokemon_sprites.each do |sp|
            animation.play_before(ya.send_command_to(sp, :go_in))
          end
          animation.play_before(ya.wait(0.2))
          return animation
        end
        # Function that create the animation of the enemy sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_enemy_send_animation
          ya = Yuki::Animation
          animations = @enemy_sprites.map do |sp|
            next(ya.move(0.8, sp, sp.x, sp.y, @viewport.rect.width + sp.width, sp.y).parallel_play(ya.wait(0.2).play_before(ya.send_command_to(sp, :show_next_frame)).root))
          end
          animation = animations.pop
          animations.each { |anim| animation.parallel_add(anim) }
          enemy_pokemon_sprites.each do |sp|
            animation.play_before(ya.send_command_to(sp, :go_in))
          end
          return animation
        end
      end
      # Wild transition of Red/Blue/Yellow games
      class RBYWild < Base
        # Constant giving the X displacement done by the sprites
        DISPLACEMENT_X = 360
        private
        # Return the pre_transtion cells
        # @return [Array]
        def pre_transition_cells
          return 10, 3
        end
        # Return the pre_transtion sprite name
        # @return [String]
        def pre_transition_sprite_name
          'rbj/pre_wild'
        end
        # Function that creates all the sprites
        def create_all_sprites
          super
          create_top_sprite
          create_enemy_sprites
          create_actors_sprites
        end
        # Function that creates the top sprite
        def create_top_sprite
          @top_sprite = SpriteSheet.new(@viewport, *pre_transition_cells)
          @top_sprite.z = @screenshot_sprite.z * 2
          @top_sprite.set_bitmap(pre_transition_sprite_name, :transition)
          @top_sprite.zoom = @viewport.rect.width / @top_sprite.width.to_f
          @top_sprite.y = (@viewport.rect.height - @top_sprite.height * @top_sprite.zoom_y) / 2
          @top_sprite.visible = false
        end
        # Function that creates the enemy sprites
        def create_enemy_sprites
          @shader = Shader.create(:color_shader)
          @shader.set_float_uniform('color', [0, 0, 0, 1])
          @enemy_sprites = enemy_pokemon_sprites
          @enemy_sprites.each do |sprite|
            sprite.shader = @shader
            sprite.x -= DISPLACEMENT_X
          end
        end
        # Function that creates the actor sprites
        def create_actors_sprites
          @actor_sprites = actor_sprites
          @actor_sprites.each do |sprite|
            sprite.x += DISPLACEMENT_X
          end
        end
        # Function that creates the Yuki::Animation related to the pre transition
        # @return [Yuki::Animation::TimedAnimation]
        def create_pre_transition_animation
          flasher = proc do |x|
            sin = Math.sin(x)
            col = sin.ceil.clamp(0, 1) * 255
            alpha = (sin.abs2.round(2) * 180).to_i
            @viewport.color.set(col, col, col, alpha)
          end
          ya = Yuki::Animation
          animation = ya::ScalarAnimation.new(1.5, flasher, :call, 0, 6 * Math::PI)
          animation.play_before(ya.send_command_to(@viewport.color, :set, 0, 0, 0, 0))
          animation.play_before(ya.send_command_to(@top_sprite, :visible=, true))
          animation.play_before(create_fadein_animation)
          animation.play_before(ya.send_command_to(@viewport.color, :set, 0, 0, 0, 255))
          animation.play_before(ya.send_command_to(@top_sprite, :dispose))
          animation.play_before(ya.send_command_to(@screenshot_sprite, :dispose))
          animation.play_before(ya.wait(0.25))
          return animation
        end
        # Function that creates the fade in animation
        def create_fadein_animation
          cells = (@top_sprite.nb_x * @top_sprite.nb_y).times.map { |i| [i % @top_sprite.nb_x, i / @top_sprite.nb_x] }
          return Yuki::Animation::SpriteSheetAnimation.new(0.5, @top_sprite, cells)
        end
        # Function that create the fade out animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_fade_out_animation
          animation = Yuki::Animation.send_command_to(@viewport.color, :set, 0, 0, 0, 0)
          animation.play_before(Yuki::Animation.send_command_to(Graphics, :transition, 15))
          return animation
        end
        # Function that create the sprite movement animation
        # @return [Yuki::Animation::TimedAnimation]
        def create_sprite_move_animation
          ya = Yuki::Animation
          animations = @enemy_sprites.map do |sp|
            ya.move(0.8, sp, sp.x, sp.y, sp.x + DISPLACEMENT_X, sp.y)
          end
          animation = animations.pop
          animations.each { |a| animation.parallel_add(a) }
          @actor_sprites.each do |sp|
            animation.parallel_add(ya.move(0.8, sp, sp.x, sp.y, sp.x - DISPLACEMENT_X, sp.y))
          end
          @enemy_sprites.each { |sp| animation.play_before(ya.send_command_to(sp, :shader=, nil)) }
          cries = @enemy_sprites.select { |sp| sp.respond_to?(:cry) }
          cries.each { |sp| animation.play_before(ya.send_command_to(sp, :cry)) }
          return animation
        end
        # Function that create the animation of the player sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_player_send_animation
          ya = Yuki::Animation
          animations = @actor_sprites.map do |sp|
            next(ya.move(1, sp, sp.x, sp.y, -sp.width, sp.y).parallel_play(ya.wait(0.2).play_before(ya.send_command_to(sp, :show_next_frame)).root))
          end
          animation = animations.pop
          animations.each { |anim| animation.parallel_add(anim) }
          actor_pokemon_sprites.each do |sp|
            animation.play_before(ya.send_command_to(sp, :go_in))
          end
          animation.play_before(ya.wait(0.2))
          return animation
        end
      end
      # Trainer transition of DPP Gym Leader
      class DPPGymLeader < RBYTrainer
        # Start x coordinate of the bar
        BAR_START_X = 320
        # Y coordinate of the bar
        BAR_Y = 64
        # VS image x coordinate
        VS_X = 64
        # VS image y offset
        VS_OFFSET_Y = 30
        # Mugshot final x coordinate
        MUGSHOT_FINAL_X = BAR_START_X - 100
        # Mugshot pre final x coordinate (animation purposes)
        MUGSHOT_PRE_FINAL_X = MUGSHOT_FINAL_X - 20
        # Text offset Y
        TEXT_OFFSET_Y = 36
        # Update the transition
        def update
          super
          @default_battler_name = @scene.battle_info.battlers[1][0]
          @viewport.update
        end
        private
        # Get the enemy trainer name
        # @return [String]
        def trainer_name
          @scene.battle_info.names[1][0]
        end
        # Get the resource name according to the current state of the player and requested prefix
        # @return [String]
        def resource_name(prefix)
          resource_filename = @scene.battle_info.find_background_name_to_display(prefix) do |filename|
            next(RPG::Cache.battleback_exist?(filename))
          end
          unless RPG::Cache.battleback_exist?(resource_filename)
            log_debug("Defaulting to file #{prefix}_#{@default_battler_name}")
            resource_filename = "#{prefix}_#{@default_battler_name}"
          end
          return resource_filename
        end
        # Function that creates the top sprite
        def create_top_sprite
          @bar = Sprite.new(@viewport)
          @bar.load(resource_name('vs_bar/bar_dpp'), :battleback)
          @bar.set_position(BAR_START_X, BAR_Y)
        end
        # Function that creates the vs sprites
        def create_vs_sprites
          @vs_full = Sprite.new(@viewport).load('vs_bar/vs_white', :battleback).set_origin_div(2, 2).set_position(VS_X, BAR_Y + VS_OFFSET_Y)
          @vs_border = Sprite.new(@viewport).load('vs_bar/vs_green', :battleback).set_origin_div(2, 2).set_position(VS_X, BAR_Y + VS_OFFSET_Y)
          @vs_woop_woop = Sprite.new(@viewport).load('vs_bar/vs_green', :battleback).set_origin_div(2, 2).set_position(VS_X, BAR_Y + VS_OFFSET_Y)
          @vs_full.visible = @vs_border.visible = @vs_woop_woop.visible = false
        end
        # Function that creates the mugshot of the trainer
        def create_mugshot_sprite
          @mugshot = Sprite.new(@viewport).load(resource_name('vs_bar/mugshot'), :battleback).set_position(BAR_START_X, BAR_Y)
          @mugshot.shader = Shader.create(:color_shader)
          @mugshot.shader.set_float_uniform('color', [0, 0, 0, 0.8])
          @mugshot_text = Text.new(0, @viewport, -1, BAR_Y + TEXT_OFFSET_Y, 0, 16, trainer_name, 2, nil, 10)
        end
        def dispose_all_pre_transition_sprites
          @screenshot_sprite.dispose
          @bar.dispose
          @vs_full.dispose
          @vs_border.dispose
          @vs_woop_woop.dispose
          @mugshot.dispose
          @mugshot_text.dispose
          @viewport.color.set(0, 0, 0, 255)
        end
        # Function that creates all the sprites
        def create_all_sprites
          super
          create_vs_sprites
          create_mugshot_sprite
        end
        # Function that creates the Yuki::Animation related to the pre transition
        # @return [Yuki::Animation::TimedAnimation]
        def create_pre_transition_animation
          ya = Yuki::Animation
          anim = ya.move(0.25, @bar, BAR_START_X, BAR_Y, 0, BAR_Y)
          anim.play_before(create_parallel_loop(ya))
          anim.play_before(ya.send_command_to(self, :dispose_all_pre_transition_sprites))
          return anim
        end
        # @param [Module<Yuki::Animation>] ya
        def create_parallel_loop(ya)
          return ya.wait(4).parallel_play(create_bar_loop_animation(ya)).parallel_play(create_screenshot_shadow_animation(ya)).parallel_play(create_vs_woop_woop_animation(ya)).parallel_play(create_pre_transition_fade_out_animation(ya))
        end
        # @param [Module<Yuki::Animation>] ya
        def create_vs_woop_woop_animation(ya)
          vs_woop_woop_anim = ya.wait(0.5)
          vs_woop_woop_anim.play_before(ya.send_command_to(self, :show_vs))
          vs_woop_woop_anim.play_before(ya.scalar(0.15, @vs_woop_woop, :zoom=, 2, 1))
          vs_woop_woop_anim.play_before(ya.scalar(0.15, @vs_woop_woop, :zoom=, 2, 1))
          vs_woop_woop_anim.play_before(ya.scalar(0.15, @vs_woop_woop, :zoom=, 2, 1))
          vs_woop_woop_anim.play_before(ya.send_command_to(@vs_full, :visible=, true))
          vs_woop_woop_anim.play_before(ya.move(0.4, @mugshot, BAR_START_X, BAR_Y, MUGSHOT_PRE_FINAL_X, BAR_Y))
          vs_woop_woop_anim.play_before(ya.move(0.15, @mugshot, MUGSHOT_PRE_FINAL_X, BAR_Y, MUGSHOT_FINAL_X, BAR_Y))
          vs_woop_woop_anim.play_before(ya.move_discreet(0.35, @mugshot_text, 0, @mugshot_text.y, MUGSHOT_PRE_FINAL_X, @mugshot_text.y))
          return vs_woop_woop_anim
        end
        # @param [Module<Yuki::Animation>] ya
        def create_pre_transition_fade_out_animation(ya)
          transitioner = proc { |t| @viewport.shader.set_float_uniform('color', [1, 1, 1, t]) }
          fade_out = ya.wait(3.25)
          fade_out.play_before(ya.scalar(0.5, transitioner, :call, 0, 1))
          return fade_out
        end
        # @param [Module<Yuki::Animation>] ya
        def create_screenshot_shadow_animation(ya)
          shadow_anim = ya.wait(1.5)
          shadow_anim.play_before(ya.send_command_to(self, :make_screenshot_shadow))
          return shadow_anim
        end
        # @param [Module<Yuki::Animation>] ya
        def create_bar_loop_animation(ya)
          anim = ya.timed_loop_animation(0.25)
          movement = ya.move(0.25, @bar, 0, BAR_Y, -256, BAR_Y)
          return anim.parallel_play(movement)
        end
        def make_screenshot_shadow
          @screenshot_sprite.shader = Shader.create(:color_shader)
          @screenshot_sprite.shader.set_float_uniform('color', [0, 0, 0, 0.5])
          @mugshot.shader.set_float_uniform('color', [0, 0, 0, 0.0])
          @viewport.flash(Color.new(255, 255, 255), 20)
        end
        def show_vs
          @vs_border.visible = @vs_woop_woop.visible = true
        end
      end
      # Trainer Transition of gen6
      class Gen6Trainer < Base
        # Unitary deltaX of the background
        DX = -Math.cos(-3 * Math::PI / 180)
        # Unitary deltaY of the background
        DY = Math.sin(-3 * Math::PI / 180)
        private
        # Function that creates all the sprites
        def create_all_sprites
          super
          create_background
          create_degrade
          create_halos
          create_battlers
          create_shader
          @viewport.sort_z
        end
        def create_background
          @background = Sprite.new(@viewport).set_origin(@viewport.rect.width, @viewport.rect.height)
          @background.set_position(@viewport.rect.width / 2, @viewport.rect.height / 2)
          @background.set_bitmap('battle_bg', :transition)
          @background.angle = -3
          @background.z = @screenshot_sprite.z - 1
          @to_dispose << @background
        end
        def create_degrade
          @degrade = Sprite.new(@viewport).set_origin(0, 90).set_position(0, 90).set_bitmap('battle_deg', :transition)
          @degrade.zoom_y = 0.10
          @degrade.opacity = 255 * @degrade.zoom_y
          @degrade.z = @background.z
          @to_dispose << @degrade
        end
        def create_halos
          @halo1 = Sprite.new(@viewport).set_bitmap('battle_halo1', :transition)
          @halo1.z = @background.z
          @to_dispose << @halo1
          @halo2 = Sprite.new(@viewport).set_origin(-640, 0).set_bitmap('battle_halo2', :transition)
          @halo2.z = @background.z
          @to_dispose << @halo2
          @halo3 = Sprite.new(@viewport).set_origin(-640, 0).set_position(640, 0).set_bitmap('battle_halo2', :transition)
          @halo3.z = @background.z
          @to_dispose << @halo3
        end
        def create_battlers
          filename = @scene.battle_info.battlers[1][0]
          @battler = Sprite.new(@viewport).set_bitmap(filename + '_sma', :battler)
          @battler.set_position(-@battler.width / 4, @viewport.rect.height)
          @battler.set_origin(@battler.width / 2, @battler.height)
          @battler.z = @background.z
          @battler2 = Sprite.new(@viewport).set_bitmap(filename + '_big', :battler)
          @battler2.set_position(@viewport.rect.width / 2, @viewport.rect.height)
          @battler2.set_origin(@battler2.width / 2, @battler2.height)
          @battler2.z = @background.z
          @battler2.opacity = 0
          @actor_sprites = actor_sprites
        end
        def create_shader
          @shader = Shader.create(:battle_backout)
          6.times do |i|
            @shader.set_texture_uniform("bk#{i}", RPG::Cache.transition("black_out0#{i}"))
          end
          @screenshot_sprite.shader = @shader
          @shader_time_update = proc { |t| @shader.set_float_uniform('time', t) }
        end
        def create_pre_transition_animation
          root = Yuki::Animation::ScalarAnimation.new(1.2, @shader_time_update, :call, 0, 1)
          root.play_before(Yuki::Animation.send_command_to(Graphics, :freeze))
          root.play_before(Yuki::Animation.send_command_to(@screenshot_sprite, :dispose))
          return root
        end
        def create_background_animation
          background_setter = proc do |i|
            t = (1 - Math.cos(2 * Math::PI * i)) / 10 + i
            d = (t * 1200) % 120
            @background.set_position(d * DX + @viewport.rect.width / 2, d * DY + @viewport.rect.height / 2)
          end
          root = Yuki::Animation::TimedLoopAnimation.new(10)
          root.play_before(Yuki::Animation::ScalarAnimation.new(10, background_setter, :call, 0, 1))
          root.parallel_play(halo = Yuki::Animation::TimedLoopAnimation.new(0.5))
          halo.play_before(h1 = Yuki::Animation::ScalarAnimation.new(0.5, @halo2, :ox=, 0, 640))
          h1.parallel_play(Yuki::Animation::ScalarAnimation.new(0.5, @halo3, :ox=, 0, 640))
          return root
        end
        def create_paralax_animation
          root = Yuki::Animation.wait(0.1)
          root.play_before(Yuki::Animation::ScalarAnimation.new(0.4, @degrade, :zoom_y=, 0.10, 1.25))
          root.parallel_play(Yuki::Animation.opacity_change(0.2, @degrade, 0, 255))
          root.play_before(Yuki::Animation::ScalarAnimation.new(0.1, @degrade, :zoom_y=, 1.25, 1))
          return root
        end
        def create_sprite_move_animation
          root = Yuki::Animation.move(0.6, @battler, @battler.x, @battler.y, @viewport.rect.width / 2, @battler.y)
          root.play_before(Yuki::Animation.wait(0.3))
          root.play_before(fade = Yuki::Animation.opacity_change(0.4, @battler, 255, 0))
          fade.parallel_play(Yuki::Animation.opacity_change(0.4, @battler2, 0, 255))
          return root
        end
        def create_enemy_send_animation
          enemy_sprites.each { |sp| sp.visible = false }
          root = Yuki::Animation.move(0.4, @battler2, @battler2.x, @battler2.y, @battler2.x - 40, @battler2.y)
          root.play_before(go = Yuki::Animation.move(0.4, @battler2, @battler2.x - 40, @battler2.y, @viewport.rect.width * 1.5, @battler2.y))
          go.parallel_play(Yuki::Animation.opacity_change(0.4, @battler2, 255, 0))
          root.play_before(Yuki::Animation.send_command_to(Graphics, :freeze))
          root.play_before(Yuki::Animation.send_command_to(self, :hide_all_sprites))
          root.play_before(Yuki::Animation.send_command_to(Graphics, :transition))
          enemy_pokemon_sprites.each do |sp|
            root.play_before(Yuki::Animation.send_command_to(sp, :go_in))
          end
          return root
        end
        # Function that create the animation of the player sending its Pokemon
        # @return [Yuki::Animation::TimedAnimation]
        def create_player_send_animation
          ya = Yuki::Animation
          animations = @actor_sprites.map do |sp|
            next(ya.move(1, sp, sp.x, sp.y, -sp.width, sp.y).parallel_play(ya.wait(0.2).play_before(ya.send_command_to(sp, :show_next_frame)).root))
          end
          animation = animations.pop
          animations.each { |anim| animation.parallel_add(anim) }
          actor_pokemon_sprites.each do |sp|
            animation.play_before(ya.send_command_to(sp, :go_in))
          end
          animation.play_before(ya.wait(0.2))
          return animation
        end
        def hide_all_sprites
          @to_dispose.each do |sprite|
            sprite.visible = false if sprite.is_a?(Sprite)
          end
        end
      end
      # Trainer Transition of gen6
      class Gen4Trainer < RBYTrainer
        private
        # Return the pre_transtion cells
        # @return [Array]
        def pre_transition_cells
          return 3, 4
        end
        # Return the pre_transtion sprite name
        # @return [String]
        def pre_transition_sprite_name
          return '4g/trainer_4g_1', '4g/trainer_4g_2'
        end
        # Function that creates the top sprite
        def create_top_sprite
          @top_sprite = SpriteSheet.new(@viewport, *pre_transition_cells)
          @top_sprite.z = @screenshot_sprite.z * 2
          @top_sprite.set_bitmap(pre_transition_sprite_name[0], :transition)
          @top_sprite.zoom = @viewport.rect.width / @top_sprite.width.to_f
          @top_sprite.ox = @top_sprite.width / 2
          @top_sprite.oy = @top_sprite.height / 2
          @top_sprite.x = @viewport.rect.width / 2
          @top_sprite.y = @viewport.rect.height / 2
          @top_sprite.visible = false
        end
        # Function that creates the Yuki::Animation related to the pre transition
        # @return [Yuki::Animation::TimedAnimation]
        def create_pre_transition_animation
          flasher = proc do |x|
            sin = Math.sin(x)
            col = 0
            alpha = (sin.abs2.round(2) * 270).to_i
            @viewport.color.set(col, col, col, alpha)
          end
          ya = Yuki::Animation
          animation = ya::ScalarAnimation.new(0.7, flasher, :call, 0, 2 * Math::PI)
          animation.play_before(ya.send_command_to(@viewport.color, :set, 0, 0, 0, 0))
          animation.play_before(ya.send_command_to(@top_sprite, :visible=, true))
          animation.play_before(create_fadein_animation)
          animation.play_before(ya.send_command_to(@viewport.color, :set, 0, 0, 0, 255))
          animation.play_before(ya.send_command_to(@top_sprite, :dispose))
          animation.play_before(ya.send_command_to(@screenshot_sprite, :dispose))
          animation.play_before(ya.wait(0.25))
          return animation
        end
        # Function that creates the fade in animation
        def create_fadein_animation
          cells = (@top_sprite.nb_x * @top_sprite.nb_y).times.map { |i| [i % @top_sprite.nb_x, i / @top_sprite.nb_x] }
          ya = Yuki::Animation
          animation = ya::ScalarAnimation.new(0.4, @top_sprite, :zoom=, 0.2, @viewport.rect.width / @top_sprite.width.to_f)
          animation << ya::ScalarAnimation.new(0.4, @top_sprite, :angle=, 90, -360)
          animation.play_before(ya::SpriteSheetAnimation.new(0.2, @top_sprite, cells))
          animation.play_before(ya.send_command_to(@top_sprite, :set_bitmap, pre_transition_sprite_name[1], :transition))
          animation.play_before(ya::SpriteSheetAnimation.new(0.2, @top_sprite, cells))
          animation.play_before(ya.send_command_to(@top_sprite, :dispose))
          RPG::Cache.transition(pre_transition_sprite_name[1])
          return animation
        end
      end
    end
    WILD_TRANSITIONS.default = Transition::Base
    TRAINER_TRANSITIONS.default = Transition::Base
    public
    TRAINER_TRANSITIONS[2] = Transition::RBYTrainer
    public
    WILD_TRANSITIONS[2] = Transition::RBYWild
    WILD_TRANSITIONS[1] = Transition::RBYWild
    WILD_TRANSITIONS[0] = Transition::RBYWild
    public
    TRAINER_TRANSITIONS[3] = Transition::DPPGymLeader
    public
    TRAINER_TRANSITIONS[0] = Transition::Gen6Trainer
    public
    TRAINER_TRANSITIONS[1] = Transition::Gen4Trainer
  end
  # Module holding all the message function used by the battle engine
  module Message
    include PFM::Text
    @battle_info = nil
    @logic = nil
    module_function
    # Setup the message system
    # @param logic [Battle::Logic] the current battle logic
    def setup(logic)
      @battle_info = logic.battle_info
      @logic = logic
      @text = PFM::Text
    end
    # A Wild Pokemon appeared
    # @return [String]
    def wild_battle_appearance
      sentence_index = @battle_info.wild_battle_reason.to_i % 7
      name = @logic.battler(1, 0)&.name
      @text.reset_variables
      @text.parse(18, 1 + sentence_index, PKNAME[0] => name.to_s)
    end
    # Trainer issuing a challenge
    # @return [String]
    def trainer_issuing_a_challenge
      @text.reset_variables
      @text.set_plural(@battle_info.names[1].size > 1)
      @battle_info.names[1].size > 1 ? trainer_issuing_a_challenge_multi : trainer_issuing_a_challenge_single
    end
    # Player sending out its Pokemon
    # @return [String]
    def player_sending_pokemon_start
      @text.reset_variables
      @text.set_plural(false)
      @battle_info.names[0].size > 1 ? player_sending_pokemon_start_multi : player_sending_pokemon_start_single
    end
    # Trainer sending out their Pokemon
    # @return [String]
    def trainer_sending_pokemon_start
      @text.reset_variables
      @text.set_plural(@battle_info.trainer_is_couple)
      text = []
      @battle_info.names[1].each_with_index do |name, index|
        if (class_name = @battle_info.classes[1][index])
          text << trainer_sending_pokemon_start_class(name, class_name, index)
        else
          text << trainer_sending_pokemon_start_no_class(name, index)
        end
      end
      text.join("\n")
    end
    # Trainer issuing a challenge with 2 trainers
    # @return [String]
    def trainer_issuing_a_challenge_multi
      text_id = @battle_info.classes[1].empty? ? 11 : 10
      if @battle_info.classes[1].empty?
        hash = {TRNAME[0] => @battle_info.names[1][0], TRNAME[1] => @battle_info.names[1][1]}
      else
        hash = {TRNAME[1] => @battle_info.names[1][0], TRNAME[3] => @battle_info.names[1][1], '[VAR 010E(0000)]' => @battle_info.classes[1][0], '[VAR 010E(0002)]' => @battle_info.classes[1][1] || @battle_info.classes[1][0]}
        hash['[VAR 019E(0000)]'] = "#{hash['[VAR 010E(0000)]']} #{hash[TRNAME[1]]}"
        hash['[VAR 019E(0002)]'] = "#{hash['[VAR 010E(0002)]']} #{hash[TRNAME[3]]}"
      end
      @text.parse(18, text_id, hash)
    end
    # Trainer issuing a challenge with one trainer
    # @return [String]
    def trainer_issuing_a_challenge_single
      text_id = @battle_info.classes[1].empty? ? 9 : 8
      if @battle_info.classes[1].empty?
        hash = {TRNAME[0] => @battle_info.names[1][0]}
      else
        hash = {TRNAME[1] => @battle_info.names[1][0], '[VAR 010E(0000)]' => @battle_info.classes[1][0]}
        hash['[VAR 019E(0000)]'] = "#{hash['[VAR 010E(0000)]']} #{hash[TRNAME[1]]}"
      end
      @text.parse(18, text_id, hash)
    end
    # When there's a friend trainer and we launch the Pokemon
    # @return [String]
    def player_sending_pokemon_start_multi
      text = [@text.parse(18, 18, PKNICK[1] => @logic.battler(0, 0).name, TRNAME[0] => @battle_info.names[0][0])]
      if @battle_info.classes[0][1]
        @text.set_pknick(@logic.battler(0, 1), 2)
        hash = {TRNAME[1] => @battle_info.names[0][1], '[VAR 010E(0000)]' => @battle_info.classes[0][1]}
        hash['[VAR 019E(0000)]'] = "#{hash['[VAR 010E(0000)]']} #{hash[TRNAME[1]]}"
        text << @text.parse(18, 15, hash)
      else
        @text.set_pknick(@logic.battler(0, 1), 1)
        text << @text.parse(18, 18, TRNAME[0] => @battle_info.names[0][0])
      end
      text.join("\n")
    end
    # When were' alone and we launch the Pokemon
    # @return [String]
    def player_sending_pokemon_start_single
      (count = @logic.battler_count(0)).times do |i|
        @text.set_pknick(@logic.battler(0, i), i)
      end
      return @text.parse(18, 14) if count == 3
      return @text.parse(18, 13) if count == 2
      return @text.parse(18, 12)
    ensure
      @text.reset_variables
    end
    # When the trainer has a class and it sends out its Pokemon
    # @param name [String] name of the trainer
    # @param class_name [String] class of the trainer
    # @param index [String] index of the trainer in the name array
    # @return [String]
    def trainer_sending_pokemon_start_class(name, class_name, index)
      hash = {TRNAME[1] => name, '[VAR 010E(0000)]' => class_name}
      hash['[VAR 019E(0000)]'] = "#{class_name} #{name}"
      arr = Array.new(@battle_info.vs_type) { |i| @logic.battler(1, i) }
      arr.select! { |pokemon| pokemon&.party_id == index }
      arr.each_with_index { |pokemon, i| @text.set_pknick(pokemon, i + 2) }
      return @text.parse(18, 15 + arr.size - 1, hash)
    ensure
      @text.reset_variables
    end
    # When the trainer has no class and it sends out its Pokemon
    # @param name [String] name of the trainer
    # @param index [String] index of the trainer in the name array
    # @return [String]
    def trainer_sending_pokemon_start_no_class(name, index)
      arr = Array.new(@battle_info.vs_type) { |i| @logic.battler(1, i) }
      arr.select! { |pokemon| pokemon&.party_id == index }
      arr.each_with_index { |pokemon, i| @text.set_pknick(pokemon, i + 2) }
      return @text.parse(18, 18 + arr.size - 1, TRNAME[0] => name)
    ensure
      @text.reset_variables
    end
  end
end
Graphics.on_start do
  Shader.register(:rby_trainer, 'graphics/shaders/rbytrainer.frag')
end
