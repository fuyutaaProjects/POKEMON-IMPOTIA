# Interpreter of the event script commands
class Interpreter < Interpreter_RMXP
  # Detect if the event can spot the player and move to the player
  # @param nb_pas [Integer] number of step the event should do to spot the player
  # @return [Boolean] if the event spot the player or not
  # @example To detect the player 7 tiles in front of the event, put in a condition :
  #   player_spotted?(7)
  # @author Nuri Yuri
  def player_spotted?(nb_pas)
    return r = false if player_detection_disabled?
    c = $game_map.events[@event_id]
    return r = false if (c.x - $game_player.x).abs > nb_pas || (c.y - $game_player.y).abs > nb_pas
    return r = false if c.z != $game_player.z
    return r = true if Input.trigger?(:A) && $game_player.front_tile_event == c
    it = c.each_front_tiles(nb_pas)
    px, py, * = it.find { |x, y| $game_player.x == x && $game_player.y == y }
    return false unless px && py
    lx, ly, * = it.find { |x, y, d| !c.passable?(x, y, d) }
    return false unless lx && ly
    return r = ((lx - px).abs <= 1 && (ly - py).abs <= 1)
  ensure
    if r
      $game_switches[::Yuki::Sw::EV_Run] = false
      $game_temp.common_event_id = Game_CommonEvent::APPEARANCE
    end
  end
  alias trainer_spotted player_spotted?
  # Detect if the event can spot the player in a certain rect in frond of itself
  # @param nb_pas [Integer] number of step the event should do to spot the player
  # @param dist [Integer] distance in both side of the detection
  # @return [Boolean] if the event spot the player or not
  def player_spotted_rect?(nb_pas, dist)
    return r = false if player_detection_disabled?
    c = $game_map.events[@event_id]
    return r = false if (c.x - $game_player.x).abs > nb_pas || (c.y - $game_player.y).abs > nb_pas
    return r = false if c.z != $game_player.z
    return r = true if Input.trigger?(:A) && $game_player.front_tile_event == c
    it = c.each_front_tiles_rect(nb_pas, dist)
    px, py, * = it.find { |x, y| $game_player.x == x && $game_player.y == y }
    return false unless px && py
    lx, ly, * = it.find { |x, y, d| !c.passable?(x, y, d) }
    return false unless lx && ly || c.through
    lx = $game_player.x
    ly = $game_player.y
    return r = ((lx - px).abs <= 1 && (ly - py).abs <= 1)
  ensure
    if r
      $game_switches[::Yuki::Sw::EV_Run] = false
      $game_temp.common_event_id = Game_CommonEvent::APPEARANCE
    end
  end
  alias trainer_spotted_rect player_spotted_rect?
  # Detect if the event can spot the player and move to the player with direction relative detection
  # @param up [Integer] number of step to the up direction
  # @param down [Integer] number of step to the down direction
  # @param left [Integer] number of step to the left direction
  # @param right [Integer] number of step to the right direction
  # @example The event turn left and bottom but does not have the same vision when turned bottom
  #   player_spotted_directional?(left: 7, bottom: 3)
  # @return [Boolean] if the event spotted the player
  def player_spotted_directional?(up: nil, down: nil, left: nil, right: nil)
    case $game_map.events[@event_id].direction
    when 2
      return player_spotted?(down || up || left || right || 1)
    when 8
      return player_spotted?(up || down || left || right || 1)
    when 4
      return player_spotted?(left || right || up || down || 1)
    when 6
      return player_spotted?(right || left || up || down || 1)
    end
    return false
  end
  # Detect the player in a specific direction
  # @param nb_pas [Integer] the number of step between the event and the player
  # @param direction [Symbol, Integer] the direction : :right, 6, :down, 2, :left, 4, :up or 8
  # @return [Boolean]
  # @author Nuri Yuri
  def detect_player(nb_pas, direction)
    return false if player_detection_disabled?
    c = $game_map.events[@event_id]
    dx = $game_player.x - c.x
    dy = $game_player.y - c.y
    case direction
    when :right, 6
      return (dy == 0 && dx >= 0 && dx <= nb_pas)
    when :down, 2
      return (dx == 0 && dy >= 0 && dy <= nb_pas)
    when :left, 4
      return (dy == 0 && dx <= 0 && dx >= -nb_pas)
    else
      return (dx == 0 && dy <= 0 && dy >= -nb_pas)
    end
  end
  # Detect the player in a rectangle around the event
  # @param nx [Integer] the x distance of detection between the event and the player
  # @param ny [Integer] the y distance of detection between the event and the player
  # @return [Boolean]
  # @author Nuri Yuri
  def detect_player_rect(nx, ny)
    return false if player_detection_disabled?
    c = $game_map.events[@event_id]
    dx = ($game_player.x - c.x).abs
    dy = ($game_player.y - c.y).abs
    return (dx <= nx && dy <= ny)
  end
  # Detect the player in a circle around the event
  # @param r [Numeric] the square radius (r = R²) of the circle around the event
  # @return [Boolean]
  # @author Nuri Yuri
  def detect_player_circle(r)
    return false if player_detection_disabled?
    c = $game_map.events[@event_id]
    dx = $game_player.x - c.x
    dy = $game_player.y - c.y
    return ((dx * dx) + (dy * dy)) <= r
  end
  # Delete the current event forever
  def delete_this_event_forever
    $env.set_event_delete_state(@event_id)
    $game_map.events[@event_id]&.erase
  end
  # Delete the provided event forever
  # @param event_id [Integer]
  def delete_event_forever(event_id)
    return false unless $game_map.events[event_id]
    log_info("Event #{event_id} #{$game_map.events[event_id].event.name} was deleted forever.")
    $env.set_event_delete_state(event_id)
    $game_map.events[event_id]&.erase
  end
  alias delete_event delete_event_forever
  # Wait for the end of the movement of this particular character
  # @param event_id [Integer] <default : calling event's> the id of the event to watch
  def wait_character_move_completion(event_id = @event_id)
    @move_route_waiting = true
    @move_route_waiting_id = event_id
  end
  alias attendre_fin_deplacement_cet_event wait_character_move_completion
  alias wait_event wait_character_move_completion
  alias attendre_event wait_character_move_completion
  # Detect if a specified tile (in layer 3) is in the specified zone
  # @param x [Integer] the coordinate x of the zone
  # @param y [Integer] the coordinate y of the zone
  # @param width [Integer] the width of the zone
  # @param height [Integer] the height of the zone
  # @param tile_id [Integer] the tile's id in the tileset
  # @return [Boolean] "true" if the tile is detected in the zone, else "false"
  # @example To detect if there is non-cracked ice floor tile in a zone going from
  #      X = 15 (included) to 24 and Y = 10 (included) to 15, you have to write : 
  #      detect_invalid_tile(15, 10, 10, 6, 394)
  #      To calculate tile_id the formula is this one : 384 + tileset_x + tileset_y * 8
  #      For example : the tile is the third of the second line we then have tileset_x = 2, tileset_y = 1 which gives 394.
  def detect_invalid_tile(x, y, width, height, tile_id)
    ox = Yuki::MapLinker.get_OffsetX
    oy = Yuki::MapLinker.get_OffsetY
    rangex = (x + ox)...(x + ox + width)
    rangey = (y + oy)...(y + oy + height)
    gm = $game_map
    return rangex.any? { |tx| rangey.any? { |ty| gm.get_tile(tx, ty) == tile_id } }
  end
  # Save the current fog
  # @return [Array] the fog info
  def save_this_fog
    $fog_info = [$game_map.fog_name, $game_map.fog_hue, $game_map.fog_opacity, $game_map.fog_blend_type, $game_map.fog_zoom, $game_map.fog_sx, $game_map.fog_sy]
  end
  # Clear the saved fog
  def clear_saved_fog
    $fog_info = nil
  end
  private
  # Tell if detecting the player is disabled
  # @return [Boolean]
  def player_detection_disabled?
    return $game_switches[Yuki::Sw::Env_Detection]
  end
  public
  # Add a pokemon to the party or store it in the PC
  # @param pokemon_or_id [Integer, Symbol, PFM::Pokemon] the ID of the pokemon in the database or a Pokemon
  # @param level [Integer] the level of the Pokemon (if ID given)
  # @param shiny [Boolean, Integer] true means the Pokemon will be shiny, 0 means it'll have no chance to be shiny, other number are the chance (1 / n) the pokemon can be shiny.
  # @return [PFM::Pokemon, nil] if nil, the Pokemon couldn't be stored in the PC or added to the party. Otherwise it's the Pokemon that was added.
  # @author Nuri Yuri
  def add_pokemon(pokemon_or_id, level = 5, shiny = false)
    return internal_add_pokemon_final(pokemon_or_id) if pokemon_or_id.is_a?(PFM::Pokemon)
    return internal_add_pokemon_check_level_shiny(pokemon_or_id, level, shiny, :add_pokemon) if pokemon_or_id.is_a?(Integer)
    return internal_add_pokemon_check_symbol(pokemon_or_id, level, shiny, :add_pokemon) if pokemon_or_id.is_a?(Symbol)
    raise 'Argument Error : Pokémon ID cannot be string' if pokemon_or_id.is_a?(String)
    nil
  end
  alias ajouter_pokemon add_pokemon
  alias ajouter_stocker_pokemon add_pokemon
  # Store a Pokemon in the PC
  # @param pokemon_or_id [Integer, Symbol, PFM::Pokemon] the ID of the pokemon in the database or a Pokemon
  # @param level [Integer] the level of the Pokemon (if ID given)
  # @param shiny [Boolean, Integer] true means the Pokemon will be shiny, 0 means it'll have no chance to be shiny, other number are the chance (1 / n) the pokemon can be shiny.
  # @return [PFM::Pokemon, nil] if nil, the Pokemon couldn't be stored in the PC. Otherwise it's the Pokemon that was added.
  # @author Nuri Yuri
  def store_pokemon(pokemon_or_id, level = 5, shiny = false)
    return internal_store_pokemon_final(pokemon_or_id) if pokemon_or_id.is_a?(PFM::Pokemon)
    return internal_add_pokemon_check_level_shiny(pokemon_or_id, level, shiny, :store_pokemon) if pokemon_or_id.is_a?(Integer)
    return internal_add_pokemon_check_symbol(pokemon_or_id, level, shiny, :store_pokemon) if pokemon_or_id.is_a?(Symbol)
    raise 'Argument Error : Pokémon ID cannot be string' if pokemon_or_id.is_a?(String)
    nil
  end
  alias stocker_pokemon store_pokemon
  # Add a pokemon (#add_pokemon) with specific informations
  # @param hash [Hash] the parameters of the Pokemon, see PFM::Pokemon#generate_from_hash.
  # @return [PFM::Pokemon, nil] see #add_pokemon
  # @author Nuri Yuri
  def add_specific_pokemon(hash)
    pokemon_id = hash[:id]
    case pokemon_id
    when Integer
      raise "Database Error : The Pokémon \##{pokemon_id} doesn't exists." if each_data_creature.none? { |creature| creature.id == pokemon_id }
    when Symbol
      raise "Database Error : The Pokémon with db_symbol #{pokemon_id} doesn't exists." if each_data_creature.none? { |creature| creature.db_symbol == pokemon_id }
    end
    return add_pokemon(PFM::Pokemon.generate_from_hash(hash))
  end
  alias ajouter_pokemon_param add_specific_pokemon
  # withdraw a Pokemon from the Party
  # @param id [Integer, Symbol] the id of the Pokemon you want to withdraw
  # @param counter [Integer] the number of Pokemon with this id to withdraw
  # @author Nuri Yuri
  def withdraw_pokemon(id, counter = 1)
    id = data_creature(id).id
    $actors.delete_if do |pokemon|
      next(false) unless pokemon.id == id && counter > 0
      next((counter -= 1))
    end
  end
  alias retirer_pokemon withdraw_pokemon
  # withdraw a Pokemon from the party at a specific position in the Party
  # @param index [Integer] the position (0~5) in the party.
  def withdraw_pokemon_at(index)
    $actors.delete_at(index)
  end
  alias retirer_pokemon_index withdraw_pokemon_at
  # Learn a skill to a Pokemon
  # @param pokemon [PFM::Pokemon, Integer] the Pokemon that will learn the skill (use $actors[index] for a Pokemon in the party). An integer will automatically search into the party
  # @param id_skill [Integer, Symbol] the id of the skill in the database
  # @return [Boolean] if the move was learnt or not
  # @author Nuri Yuri
  def skill_learn(pokemon, id_skill)
    pokemon = $actors[pokemon] if pokemon.is_a?(Integer)
    move = data_move(id_skill)
    raise "Database Error : Skill \##{id_skill} doesn't exists." if move.db_symbol == :__undef__
    raise "Pokemon Error: #{pokemon} doesn't exists" unless pokemon.is_a?(PFM::Pokemon)
    @wait_count = 2
    result = nil
    GamePlay.open_move_teaching(pokemon, move.db_symbol) do |scene|
      result = scene.learnt
    end
    return result
  end
  alias enseigner_capacite skill_learn
  # Play the cry of a Pokemon
  # @param id [Integer, Symbol] the id of the Pokemon in the database
  # @param volume [Integer] the volume of the cry
  # @param tempo [Integer] the tempo/pitch of the cry
  def cry_pokemon(id, volume: 100, tempo: 100)
    creature = data_creature(id)
    raise "Database Error : The Pokémon \##{id} doesn't exists." if creature.db_symbol == :__undef__
    Audio.se_play(format('Audio/SE/Cries/%03dCry', creature.id), volume, tempo)
  end
  # Show the rename interface of a Pokemon
  # @param index_or_pokemon [Integer, PFM::Pokemon] the Pokemon or the index of the Pokemon in the party (0~5)
  # @param num_char [Integer] the number of character the Pokemon can have in its name.
  # @author Nuri Yuri
  def rename_pokemon(index_or_pokemon, num_char = 12)
    if index_or_pokemon.is_a?(Integer)
      pokemon = $actors[index_or_pokemon]
      raise "IndexError : Pokemon at index #{index_or_pokemon} couldn't be found." unless pokemon
    else
      pokemon = index_or_pokemon
    end
    $scene.window_message_close(false) if $scene.class == Scene_Map
    GamePlay.open_pokemon_name_input(pokemon, num_char) { |name_input| pokemon.given_name = name_input.return_name }
    @wait_count = 2
  end
  alias renommer_pokemon rename_pokemon
  # Add a pokemon to the party or store it in the PC and rename it
  # @param pokemon_or_id [Integer, Symbol, PFM::Pokemon] the ID of the pokemon in the database or a Pokemon
  # @param level [Integer] the level of the Pokemon (if ID given)
  # @param shiny [Boolean, Integer] true means the Pokemon will be shiny, 0 means it'll have no chance to be shiny, other number are the chance (1 / n) the pokemon can be shiny.
  # @param num_char [Integer] the number of character the Pokemon can have in its name.
  # @return [PFM::Pokemon, nil] if nil, the Pokemon couldn't be stored in the PC or added to the party. Otherwise it's the Pokemon that was added.
  # @author Nuri Yuri
  def add_rename_pokemon(pokemon_or_id, level = 5, shiny = false, num_char = 12)
    pokemon = add_pokemon(pokemon_or_id, level, shiny)
    rename_pokemon(pokemon, num_char) if pokemon
    return pokemon
  end
  alias ajouter_renommer_pokemon add_rename_pokemon
  # Add an egg to the Party (or in the PC)
  # @param id [Integer, Hash, Symbol, PFM::Pokemon] the id of the Pokemon, its db_symbol, a hash describing it (see: #generate_from_hash), or the Pokemon itself
  # @return [PFM::Pokemon, nil]
  # @author Nuri Yuri
  def add_egg(id)
    if id.is_a?(PFM::Pokemon)
      pokemon = id
    else
      creature = data_creature(id.is_a?(Hash) ? id[:id] : id)
      raise "Database Error : The Pokémon \##{id} doesn't exists." if creature.db_symbol == :__undef__
      pokemon = id.is_a?(Hash) ? PFM::Pokemon.generate_from_hash(id) : PFM::Pokemon.new(id, 1)
    end
    pokemon.egg_init
    pokemon.memo_text = [28, 31]
    return add_pokemon(pokemon)
  end
  alias ajouter_oeuf add_egg
  # Start a wild battle
  # @author Nuri Yuri
  # @overload call_battle_wild(id, level, shiny, no_shiny)
  #   @param id [Integer, Symbol] id of the Pokemon in the database
  #   @param level [Integer] level of the Pokemon
  #   @param shiny [Boolean] if the Pokemon is shiny
  #   @param no_shiny [Boolean] if the Pokemon cannot be shiny
  # @overload call_battle_wild(id, level, *args)
  #   @param id [PFM::Pokemon, Symbol] First Pokemon in the wild battle.
  #   @param level [Object] ignored
  #   @param args [Array<PFM::Pokemon>] other pokemon in the wild battle.
  # @overload call_battle_wild(id, level, *args)
  #   @param id [Integer, Symbol] id of the Pokemon in the database
  #   @param level [Integer] level of the first Pokemon
  #   @param args [Array<Integer, Integer>] array of id, level of the other Pokemon in the wild battle.
  def call_battle_wild(id, level, *args)
    id = data_creature(id).id if id.is_a?(Symbol)
    if args[0].is_a?(Numeric) || args[0].is_a?(Symbol) || args[0].class == PFM::Pokemon || id.class == PFM::Pokemon
      args[0] = data_creature(args[0]).id if args[0].is_a?(Symbol)
      $wild_battle.start_battle(id, level, *args)
    else
      $wild_battle.start_battle(::PFM::Pokemon.new(id, level, args[0], args[1] == true))
    end
    @wait_count = 2
  end
  alias demarrer_combat call_battle_wild
  # Save some Pokemon of the team somewhere and remove them from the party
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_party
  # @param indexes [Array, Range] list of index in the team
  # @param no_save [Boolean] if the Pokémon are not saved.
  # @author Nuri Yuri
  def steal_pokemon(indexes, id_storage = nil, no_save = false)
    pokemons = []
    indexes.each do |i|
      pokemons << $actors[i]
    end
    pokemons.compact!
    pokemons.each do |pokemon|
      $actors.delete(pokemon)
    end
    unless no_save
      var_id = id_storage ? "@_str_#{id_storage}".to_sym : :@other_party
      $storage.instance_variable_set(var_id, pokemons)
    end
  end
  # Retrieve previously stolen Pokemon ( /!\ uses #add_pokemon)
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_party
  # @author Nuri Yuri
  def retrieve_stolen_pokemon(id_storage = nil)
    var_id = id_storage ? "@_str_#{id_storage}".to_sym : :@other_party
    party = $storage.instance_variable_get(var_id)
    return nil if party.empty?
    party.each do |pokemon|
      add_pokemon(pokemon) if pokemon
    end
    $storage.remove_instance_variable(var_id) if id_storage
  end
  alias retreive_stolen_pokemon retrieve_stolen_pokemon
  # Start an online Trade
  # @param server [Boolean] if the player is the server
  def start_trade(server)
    GamePlay::Trade.new(server).main
    Graphics.transition
    @wait_count = 2
  end
  # Show the Pokemon dex info
  # @overload show_pokemon(pokemon)
  #   @param pokemon [PFM::Pokemon] the Pokemon to show in the dex
  # @overload show_pokemon(pokemon_id)
  #   @param pokemon_id [Integer, Symbol] ID of the Pokemon in the dex
  def show_pokemon(pokemon_id)
    pokemon_id = data_creature(pokemon_id).id if pokemon_id.is_a?(Symbol)
    if pokemon_id.is_a?(PFM::Pokemon)
      GamePlay.open_dex_to_show_pokemon(pokemon_id)
    else
      GamePlay.open_dex_to_show_page(pokemon_id)
    end
    @wait_count = 2
  end
  # Returns the db_symbol of the type of the Pokemon's Hidden Power
  # @param index_or_pokemon [Integer, PFM::Pokemon] the Pokemon or the index of the Pokemon in the party (0~5)
  # @author Rey
  def pokemon_hidden_power(index_or_pokemon)
    if index_or_pokemon.is_a?(Integer)
      pokemon = $actors[index_or_pokemon]
      raise "IndexError : Pokemon at index #{index_or_pokemon} couldn't be found." unless pokemon
    else
      pokemon = index_or_pokemon
    end
    iv_list = Battle::Move::HiddenPower::IV_LIST
    index = 0
    iv_list.each_with_index { |iv, i| index += (pokemon.send(iv) & 1) * 2 ** i }
    index = (index * (Battle::Move::HiddenPower::TYPES_TABLE.length - 1) / 63).floor
    return Battle::Move::HiddenPower::TYPES_TABLE[index]
  end
  public
  # Try to add Pokemon to the party or store the Pokemon in the storage system
  # @param pokemon [PFM::Pokemon]
  # @return [PFM::Pokemon]
  def internal_add_pokemon_final(pokemon)
    return_value = PFM.game_state.add_pokemon(pokemon)
    if return_value.is_a?(Integer)
      $game_switches[Yuki::Sw::SYS_Stored] = true
    else
      if return_value
        $game_switches[Yuki::Sw::SYS_Stored] = false
      else
        raise "Management Error :\nThe last Pokémon couldn't added to the team\nor to the storage system..."
      end
    end
    return pokemon
  end
  # Check the symbol of the Pokemon and send the Pokemon to method_name
  # @param pokemon_or_id [Symbol] Symbol ID of the Pokemon in the database
  # @param level [Integer] level of the Pokemon to add
  # @param shiny [Integer, Boolean] the shiny chance
  # @param method_name [Symbol] Method to use in order to add the Pokemon somewhere
  # @return [PFM::Pokemon]
  def internal_add_pokemon_check_symbol(pokemon_or_id, level, shiny, method_name)
    id = data_creature(pokemon_or_id).id
    raise "Database Error : The Pokémon #{pokemon_or_id} doesn't exists." if id == 0
    send(method_name, id, level, shiny)
  end
  # Check the input parameters and send the Pokemon to method_name
  # @param pokemon_id [Integer] ID of the Pokemon in the database
  # @param level [Integer] level of the Pokemon to add
  # @param shiny [Integer, Boolean] the shiny chance
  # @param method_name [Symbol] Method to use in order to add the Pokemon somewhere
  # @return [PFM::Pokemon]
  def internal_add_pokemon_check_level_shiny(pokemon_id, level, shiny, method_name)
    do_not_add = false
    do_not_add = "Database Error : The Pokémon \##{pokemon_id} doesn't exists." if data_creature(pokemon_id).db_symbol == :__undef__
    if level < 1 || level > PFM.game_state.level_max_limit
      do_not_add << 10 if do_not_add
      do_not_add = "#{do_not_add}Level Error : level #{level} is out of bound."
    end
    raise do_not_add if do_not_add
    shiny = rand(shiny) == 0 if shiny.is_a?(Integer) && shiny > 0
    pokemon = PFM::Pokemon.new(pokemon_id, level.abs, shiny, shiny == 0)
    return send(method_name, pokemon)
  end
  # Try to add Pokemon to the party or store the Pokemon in the storage system
  # @param pokemon [PFM::Pokemon]
  # @return [PFM::Pokemon]
  def internal_store_pokemon_final(pokemon)
    return_value = $storage.store(pokemon)
    raise 'Management Error : The Pokemon couldn\'t be stored...' unless return_value
    $game_switches[Yuki::Sw::SYS_Stored] = true
    return pokemon
  end
  public
  # Call the move reminder UI with the choosen Pokemon and a specific mode (0 by default)
  # @param pokemon [PFM::Pokemon]
  # @param mode [Integer] see {GamePlay::Move_Reminder#initialize}
  # @return [Boolean] if the Pokemon learnt a move or not
  def move_reminder(pokemon = $actors[$game_variables[::Yuki::Var::Party_Menu_Sel]], mode = 0)
    result = false
    GamePlay.open_move_reminder(pokemon, mode) { |scene| result = scene.reminded_move? }
    @wait_count = 2
    return result
  end
  alias maitre_capacites move_reminder
  # Detect if the move reminder can remind a move to the selected pokemon
  # @param mode [Integer] see {GamePlay::Move_Reminder#initialize}
  # @return [Boolean] if the scene can be called
  def can_move_reminder_be_called?(mode = 0)
    var = $game_variables[::Yuki::Var::Party_Menu_Sel]
    return false if var < 0 || var >= $actors.size
    return $actors[var].remindable_skills(mode).any? && !$actors[var].egg?
  end
  alias maitre_capacites_appelable? can_move_reminder_be_called?
  public
  # Return the current time in minute
  # @return [Integer]
  def current_time
    return ((time = Time.new).to_i / 60 + time.gmtoff / 60) if $game_switches[Yuki::Sw::TJN_RealTime]
    $game_variables[Yuki::Var::TJN_Min] + $game_variables[Yuki::Var::TJN_Hour] * 60 + (($game_variables[Yuki::Var::TJN_MDay] - 1) % 7) * 1440 + ($game_variables[Yuki::Var::TJN_Week]) * 10_080
  end
  # Store a timed event (will enable the desired local switch when the timer reached the amount of minutes)
  # @param amount_of_minutes [Integer] number of minute from now to enable the switch
  # @param local_switch_letter [String] letter of the local switch to enable in order to trigger the event
  # @param event_id [Integer] event id that should be activated
  # @param map_id [Integer] map where the event should be located
  # @example Setting an event in 24h for the current event (local switch D)
  #   trigger_event_in(24 * 60, 'D')
  def trigger_event_in(amount_of_minutes, local_switch_letter, event_id = @event_id, map_id = @map_id)
    next_time = current_time + amount_of_minutes
    (($user_data[:tjn_events] ||= {})[map_id] ||= {})[event_id] = [next_time, local_switch_letter]
    set_self_switch(false, local_switch_letter, event_id, map_id)
    $game_map.need_refresh = true
  end
  # Get the remaining time until the trigger (in minutes)
  # @param event_id [Integer] event id that should be activated
  # @param map_id [Integer] map where the event should be located
  # @return [Integer]
  def timed_event_remaining_time(event_id = @event_id, map_id = @map_id)
    return ($user_data.dig(:tjn_events, map_id, event_id)&.first || current_time) - current_time
  end
  public
  # Return the $game_variables
  # @return [Game_Variables]
  def gv
    $game_variables
  end
  # Return the $game_switches
  # @return [Game_Switches]
  def gs
    $game_switches
  end
  # Return the $game_temp
  # @return [Game_Temp]
  def gt
    $game_temp
  end
  # Return the $game_map
  # @return [Game_Map]
  def gm
    $game_map
  end
  # Return the $game_player
  # @return [Game_Player]
  def gp
    $game_player
  end
  # Return the $game_map.events[id]
  # @return [Game_Event]
  def ge(id = @event_id)
    gm.events[id]
  end
  # Return the party object (game state)
  # @return [PFM::GameState]
  def party
    PFM.game_state
  end
  # Return the NuriYuri::DynamicLight module
  # @return [NuriYuri::DynamicLight]
  def dynamic_light
    return NuriYuri::DynamicLight
  end
  alias dyn_light dynamic_light
  # Start the storage PC
  def start_pc
    Audio.se_play('audio/se/computeropen')
    GamePlay.open_pokemon_storage_system
  end
  alias demarrer_pc start_pc
  # Show an emotion to an event or the player
  # @param type [Symbol] the type of emotion (see wiki)
  # @param char_id [Integer] the ID of the event (> 0), the current event (0) or the player (-1)
  # @param wait [Integer] the number of frame the event will wait after this command.
  # @param params [Hash] particle
  # @note The available emotion type are :
  #   - :exclamation
  #   - :exclamation2
  #   - :poison
  #   - :interrogation
  #   - :music
  #   - :love
  #   - :joy
  #   - :sad
  #   - :happy
  #   - :angry
  #   - :sulk
  #   - :nocomment
  # @example Displaying the poison emotion :
  #   emotion(:poison)
  # @example Displaying the poison emotion on the player (with offset) :
  #   emotion(:poison, -1, 34, oy_offset: 10)
  def emotion(type, char_id = 0, wait = 34, params = {})
    Yuki::Particles.add_particle(get_character(char_id), type, params)
    @wait_count = wait
  end
  # Show an emotion on multiple events and/or the player
  # @param type [Symbol] the type of emotion (see wiki)
  # @param chars_id [Array<Integer>] the ID of the event (> 0), the current event (0) or the player (-1)
  # @param wait [Integer] the number of frame the event will wait after this command.
  # @param params [Hash] particle
  # @note See the #emotion method comments for the available emotion type
  # @example Displaying the poison emotion on the player and multiple NPCs (with offset) :
  #   emotion_on_multiple_npc(:poison, [-1, 5, 8, 15], 34, oy_offset: 10)
  def emotion_on_multiple_npc(type, chars_id = [0], wait = 34, params = {})
    chars_id.each { |char_id| emotion(type, char_id, wait, params) }
  end
  alias emotion_on_multiple_pnj emotion_on_multiple_npc
  # List of command cods that needs to be skipped in order to detect the from event calling call
  FEC_SKIP_CODES = [108, 121, 122]
  # Check if the front event calls a common event (in its first non comment commands)
  # @param common_event [Integer] the id of the common event in the database
  # @return [Boolean]
  # @author Nuri Yuri
  def front_event_calling(common_event)
    event = $game_player.front_tile_event
    if event&.list
      @event_id = event.id if @event_id == 0
      i = 0
      i += 1 while FEC_SKIP_CODES.include?(event.list[i]&.code)
      return true if event.list[i] && event.list[i].code == 117 && event.list[i].parameters[0] == common_event
    end
    return false
  end
  # Check if an event is calling a common event (in its first non comment commands)
  # @param common_event [Integer] the id of the common event
  # @param event_id [Integer] the id of the event on the MAP
  # @return [Boolean]
  def event_calling(common_event, event_id)
    if (event = $game_map.events[event_id]) && event.list
      i = 0
      i += 1 while FEC_SKIP_CODES.include?(event.list[i]&.code)
      return true if event.list[i] && event.list[i].code == 117 && event.list[i].parameters[0] == common_event
    end
    return false
  end
  # Start a choice with more option than RMXP allows.
  # @param variable_id [Integer] the id of the Variable where the choice will be store.
  # @param cancel_type [Integer] the choice that cancel (-1 = no cancel)
  # @param choices [Array<String>] the list of possible choice.
  # @author Nuri Yuri
  def choice(variable_id, cancel_type, *choices)
    setup_choices([choices, cancel_type])
    $game_temp.choice_proc = proc { |choix| $game_variables[variable_id] = choix + 1 }
  end
  # Open the world map
  # @param arg [Symbol] the mode of the world map, :view or :fly
  # @param wm_id [Integer] the world map id to display
  # @author Nuri Yuri
  def carte_du_monde(arg = :view, wm_id = $env.get_worldmap)
    arg = arg.bytesize == 3 ? :fly : :view if arg.instance_of?(String)
    if arg == :fly
      GamePlay.open_town_map_to_fly(wm_id)
    else
      GamePlay.open_town_map(wm_id)
    end
    @wait_count = 2
  end
  alias world_map carte_du_monde
  # Save the game without asking
  def force_save
    GamePlay::Save.save
  end
  alias forcer_sauvegarde force_save
  # Set the value of a self_switch
  # @param value [Boolean] the new value of the switch
  # @param self_switch [String] the name of the self switch ("A", "B", "C", "D")
  # @param event_id [Integer] the id of the event that see the self switch
  # @param map_id [Integer] the id of the map where the event see the self switch
  # @author Leikt
  def set_self_switch(value, self_switch, event_id = @event_id, map_id = @map_id)
    key = [map_id, event_id, self_switch]
    $game_self_switches[key] = (value == true)
    $game_map.events[event_id].refresh if $game_map.map_id == map_id
  end
  alias set_ss set_self_switch
  # Get the value of a self_switch
  # @param self_switch [String] the name of the self switch ("A", "B", "C", "D")
  # @param event_id [Integer] the id of the event that see the self switch
  # @param map_id [Integer] the id of the map where the event see the self switch
  # @return [Boolean] the value of the self switch
  # @author Leikt
  def get_self_switch(self_switch, event_id = @event_id, map_id = @map_id)
    key = [map_id, event_id, self_switch]
    return $game_self_switches[key] || false
  end
  alias get_ss get_self_switch
  # Show the party menu in order to select a Pokemon
  # @param id_var [Integer] id of the variable in which the index will be store (-1 = no selection)
  # @param party [Array<PFM::Pokemon>] the array of Pokemon to show in the menu
  # @param mode [Symbol] the mode of the Menu (:map, :menu, :item, :hold, :battle)
  # @param extend_data [Integer, PFM::ItemDescriptor::Wrapper, Array, Symbol] extend_data informations
  # @author Nuri Yuri
  def call_party_menu(id_var = ::Yuki::Var::Party_Menu_Sel, party = $actors, mode = :map, extend_data = nil)
    block = proc { |scene| $game_variables[id_var] = scene.return_data }
    case mode
    when :map
      GamePlay.open_party_menu_to_select_pokemon(party, &block)
    when :item
      GamePlay.open_party_menu_to_use_item(extend_data, party, &block)
    when :hold
      GamePlay.open_party_menu_to_give_item_to_pokemon(extend_data, party, &block)
    when :select
      GamePlay.open_party_menu_to_select_a_party(party, PFM.game_state.game_variables[Yuki::Var::Max_Pokemon_Select], extend_data)
      $game_variables[id_var] = -1
    when :absofusion
      GamePlay.open_party_menu_to_absofusion_pokemon(party, *extend_data)
      $game_variables[id_var] = -1
    when :separate
      GamePlay.open_party_menu_to_separate_pokemon(party, extend_data)
      $game_variables[id_var] = -1
    else
      GamePlay.open_party_menu(party, &block)
    end
    @wait_count = 2
  end
  alias appel_menu_equipe call_party_menu
  # Show the quest book
  def quest_book
    GamePlay::QuestUI.new.main
    Graphics.transition
    @wait_count = 2
  end
  alias livre_quetes quest_book
  alias quest_ui quest_book
  # Add a parallax
  # @overload add_parallax(image, x, y, z, zoom_x = 1, zoom_y = 1, opacity = 255, blend_type = 0)
  #   @param image [String] name of the image in Graphics/Pictures/
  #   @param x [Integer] x coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
  #   @param y [Integer] y coordinate of the parallax from the first pixel of the Map (16x16 tiles /!\)
  #   @param z [Integer] z superiority in the tile viewport
  #   @param zoom_x [Numeric] zoom_x of the parallax
  #   @param zoom_y [Numeric] zoom_y of the parallax
  #   @param opacity [Integer] opacity of the parallax (0~255)
  #   @param blend_type [Integer] blend_type of the parallax (0, 1, 2)
  def add_parallax(*args)
    Yuki::Particles.add_parallax(*args)
  end
  # Return the PFM::Text module
  # @return [PFM::Text]
  def pfm_text
    return PFM::Text
  end
  # Return the index of the choosen Pokemon or call a method of GameState to find the right Pokemon
  # @param method_name [Symbol] identifier of the method
  # @param args [Array] parameters to send to the method
  def pokemon_index(method_name, *args)
    index = $game_variables[Yuki::Var::Party_Menu_Sel].to_i
    index = party.send(method_name, *args) if index < 0
    return index
  end
  # Use path finding to locate the current event move else
  # @param to [Array<Integer, Integer>, Game_Character] the target, [x, y] or Game_Character object
  # @param radius [Integer] <default : 0> the distance from the target to consider it as reached
  # @param tries [Integer, Symbol] <default : 5> the number of tries allowed to this request, use :infinity to unlimited try count
  # @param type [Symbol]
  # @example find path to x=10 y=15 with an error radius of 5 tiles
  #   find_path(to:[10,15], radius:5)
  def find_path(to:, radius: 0, tries: Pathfinding::TRY_COUNT, type: nil)
    get_character(@event_id).find_path(to: to, radius: radius, tries: tries, type: type)
  end
  # Shortcut for get_character(@event_id).stop_path
  def stop_path
    get_character(@event_id).stop_path
  end
  # Shortcut defining the pathfinding request and wait for the end of the path following
  # @param x [Integer] x coords to reach
  # @param y [Integer] y coords to reach
  # @param ms [Integer] <default : 5> movement speed
  def fast_travel(x, y = nil, ms = 5)
    $game_player.move_speed = ms
    if y
      $game_player.find_path to: [x, y]
    else
      $game_player.find_path to: x, type: :Border
    end
  end
  # Shortcut for get_character(@event_id).animate_from_charset(*args)
  # @param lines [Array<Integer>] list of the lines to animates (0,1,2,3)
  # @param duration [Integer] duration of the animation in frame (60frame per secondes)
  # @param reverse [Boolean] <default: false> set it to true if the animation is reversed
  # @param repeat [Boolean] <default: false> set it to true if the animation is looped
  # @return [Boolean]
  def animate_from_charset(lines, duration, reverse: false, repeat: false)
    return get_character(@event_id).animate_from_charset(lines, duration, reverse: reverse, repeat: repeat)
  end
  # Shortcut for wait_character_move_completion(0)
  # Wait for the end of the player movement
  def wait_for_player
    wait_character_move_completion 0
  end
  alias attendre_joueur wait_for_player
  # Open the casino gameplay
  # @param arg [Symbol] the mode of the casino :voltorb_flip, :slotmachine, ...
  # @param speed [Integer] speed of the slot machine
  # @author Nuri Yuri
  def casino(arg = :voltorb_flip, speed = 2)
    return if $game_variables[Yuki::Var::CoinCase] <= 0
    case arg
    when :voltorb_flip
      casino = GamePlay::Casino::VoltorbFlip.new
    when :slotmachine
      casino = GamePlay::Casino::SlotMachine.new(speed)
    else
      return
    end
    casino.main
    Graphics.transition
    @wait_count = 2
  end
  # Open the Hall of Fame UI
  # @param filename_bgm [String] the bgm to play during the Hall of Fame
  # @param context_of_victory [Symbol] the symbol to put as the context of victory
  def hall_of_fame(filename_bgm = 'audio/bgm/Hall-of-Fame', context_of_victory = :league)
    GamePlay.open_hall_of_fame(filename_bgm, context_of_victory)
    @wait_count = 2
  end
  # Open the Mining Game UI
  # @overload mining_game(item_count, music_filename = GamePlay::MiningGame::DEFAULT_MUSIC)
  #   @param item_count [Integer] the number of items to search
  #   @param music_filename [String] the filename of the music to play
  #   @param delete_after [Boolean] if the event should be deleted forever afterward
  #   @param grid_handler [PFM::MiningGame::GridHandler, nil] a specific GridHandler for this instance of the Mining Game
  # @overload mining_game(wanted_item_db_symbols, music_filename = GamePlay::MiningGame::DEFAULT_MUSIC)
  #   @param wanted_item_db_symbols [Array<Symbol>] the array containing the specific items (comprised between 1 and 5 items)
  #   @param music_filename [String] the filename of the music to play
  #   @param delete_after [Boolean] if the event should be deleted forever afterward
  #   @param grid_handler [PFM::MiningGame::GridHandler, nil] a specific GridHandler for this instance of the Mining Game
  def mining_game(param = nil, music_filename = GamePlay::MiningGame::DEFAULT_MUSIC, delete_after: true, grid_handler: nil)
    message_id = $game_map.events[@event_id].event.name.downcase.include?('miningrock') ? 2 : 0
    if PFM.game_state.bag.contain_item?(:explorer_kit)
      if yes_no_choice(ext_text(9005, message_id))
        $game_system.bgm_memorize
        $game_system.bgm_fade(0.2)
        $scene.call_scene(GamePlay::MiningGame, param, music_filename, grid_handler: grid_handler, fade_out_params: [:mining_game, 0])
        $game_system.bgm_restore
        @wait_count = 2
        delete_this_event_forever if delete_after
      end
    else
      message(ext_text(9005, message_id + 1))
      @wait_count = 2
    end
  end
  # Mirror a RMXP Picture
  # @param id [Integer] the picture id
  # @param bool [Boolean] the mirroring state
  def mirror_picture(id, bool = true)
    $game_screen.pictures[id].mirror = bool
  end
  # Give a certain amount of exp to one Pokemon
  # @param index [Integer] the Pokemon index
  # @param amount [Integer] the amount of exp to give
  def give_exp(index, amount)
    index = index.clamp(0, $actors.size - 1)
    return if $actors[index].level >= $pokemon_party.level_max_limit || $actors[index].egg?
    @amount = amount
    pokemon = $actors[index]
    exp_to_next_lvl = pokemon.exp_lvl - pokemon.exp
    while @amount >= exp_to_next_lvl
      break if pokemon.level >= $pokemon_party.level_max_limit
      pokemon.exp += exp_to_next_lvl
      @amount -= exp_to_next_lvl
      exp_to_next_lvl = pokemon.exp_lvl - pokemon.exp
      if pokemon.exp >= pokemon.exp_lvl
        pokemon.level_up_stat_refresh
        Audio.me_play(PFM::ItemDescriptor::LVL_SOUND)
        PFM::Text.set_num3(pokemon.level.to_s, 1)
        message(parse_text(18, 62, '[VAR 010C(0000)]' => pokemon.given_name))
        PFM::Text.reset_variables
        pokemon.check_skill_and_learn
        id, form = pokemon.evolve_check
        GamePlay.make_pokemon_evolve(pokemon, id, form, true) if id
      end
    end
    pokemon.exp += @amount unless pokemon.level >= $pokemon_party.level_max_limit
  end
  # Give a certain amount of exp to every Pokemon in party
  # @param amount [Integer] the amount of exp to give
  def give_exp_all(amount)
    $actors.size.times { |i| give_exp(i, amount) }
  end
  # Give a certain amount of level to one Pokemon
  # @param index [Integer] the Pokemon index
  # @param amount [Integer] the amount of level to give
  def give_level(index, amount)
    return if $actors[index].level >= $pokemon_party.level_max_limit || $actors[index].egg?
    amount.times do |i|
      break if $actors[index].level >= $pokemon_party.level_max_limit
      $actors[index].level_up_stat_refresh
      Audio.me_play(PFM::ItemDescriptor::LVL_SOUND)
      PFM::Text.set_num3($actors[index].level.to_s, 1)
      message(parse_text(18, 62, '[VAR 010C(0000)]' => $actors[index].given_name))
      PFM::Text.reset_variables
      $actors[index].check_skill_and_learn
      id, form = $actors[index].evolve_check
      GamePlay.make_pokemon_evolve($actors[index], id, form, true) if id
    end
  end
  # Give a certain amount of level to every Pokemon in party
  # @param amount [Integer] the amount of level to give
  def give_level_all(amount)
    $actors.size.times { |i| give_level(i, amount) }
  end
  public
  # If the put item in pocket message is not shown
  MODE_SWOOSH = true
  # Add an item to the bag if possible, will delete the event forever
  # @param item_id [Integer, Symbol] id of the item in the database
  # @param no_delete [Boolean] bypass the deletion of the event
  # @param text_id [Integer] ID of the text used when the item is found
  # @param no_space_text_id [Integer] ID of the text when the player has not enough space in the bag
  # @param count [Integer] number of item to add
  # @param color [Integer] color to put on the item name
  def add_item(item_id, no_delete = false, text_id: 4, no_space_text_id: 7, color: 11, count: 1)
    db_symbol = item_id.is_a?(Symbol) ? item_id : data_item(item_id).db_symbol
    if (max = Configs.settings.max_bag_item_count) > 0 && ($bag.item_quantity(db_symbol) + count) >= max
      add_item_no_space(db_symbol, no_space_text_id, color)
    else
      item_text, socket = add_item_show_message_got(db_symbol, text_id, color, count: count)
      if count == 1 && !MODE_SWOOSH
        pocket_name = GamePlay::Bag::POCKET_NAMES[socket]
        pocket_name = send(*pocket_name) if pocket_name.is_a?(Array)
        show_message(:bag_store_item_in_pocket, item_1: item_text, header: SYSTEM_MESSAGE_HEADER, PFM::Text::TRNAME[0] => $trainer.name, '[VAR 0112(0002)]' => pocket_name)
      end
      $bag.add_item(db_symbol, count)
      delete_this_event_forever unless no_delete
    end
    @wait_count = 2
  end
  # Pick an item on the ground (and delete the event)
  # @param item_id [Integer, Symbol] id of the item in the database
  # @param count [Integer] number of item
  # @param no_delete [Boolean] if the event should not be delete forever
  def pick_item(item_id, count = 1, no_delete = false)
    add_item(item_id, no_delete, text_id: 4, count: count)
  end
  # Give an item to the player
  # @param item_id [Integer, Symbol] id of the item in the database
  # @param count [Integer] number of item
  def give_item(item_id, count = 1)
    text_id = data_item(item_id).socket == 5 ? 1 : 0
    add_item(item_id, true, text_id: text_id, count: count)
  end
  private
  # Show the too bad no space phrase in the add_item command
  # @param item_id [Integer]
  # @param no_space_text_id [Integer] ID of the text when the player has not enough space in the bag
  # @param color [Integer] color to put on the item name
  def add_item_no_space(item_id, no_space_text_id, color)
    item_text = "\\c[#{color}]#{data_item(item_id).exact_name}\\c[10]"
    MESSAGES[:bag_full_text] = proc {text_get(41, no_space_text_id) }
    show_message(:bag_full_text, item_1: item_text, header: SYSTEM_MESSAGE_HEADER, PFM::Text::TRNAME[0] => $trainer.name)
  end
  # Show the item got text
  # @param item_id [Integer]
  # @param text_id [Integer] ID of the text used when the item is found
  # @param color [Integer] color to put on the item name
  # @param end_color [Integer] color used after the item name
  # @return [Array<String, Integer>] the name of the item with the decoration and its socket
  def add_item_show_message_got(item_id, text_id, color, end_color = 10, count: 1)
    item = data_item(item_id)
    item_text = "\\c[#{color}]#{count == 1 ? item.name : item.plural_name}\\c[#{end_color}]"
    socket = item.socket
    Audio.me_play(item.me, 80)
    if item.is_a?(Studio::TechItem)
      text_id = text_id <= 3 ? 3 : 6
      MESSAGES[:hm_got_text] = proc {text_get(41, text_id) }
      move_name = data_move(Studio::TechItem.from(item).move_db_symbol).name
      show_message(:hm_got_text, item_1: item_text, header: SYSTEM_MESSAGE_HEADER, PFM::Text::TRNAME[0] => $trainer.name, PFM::Text::MOVE[2] => "\\c[#{color}]#{move_name}\\c[10]")
    else
      MESSAGES[:item_got_text] = proc {text_get(41, text_id) }
      show_message(:item_got_text, item_1: item_text, header: SYSTEM_MESSAGE_HEADER, PFM::Text::TRNAME[0] => $trainer.name, '[VAR 1402(0001)]' => "#{count} ")
    end
    return item_text, socket
  end
  public
  # Show a message with eventually a choice
  # @param string [String] message to show
  # @param cancel_type [Integer] option used to cancel (1 indexed position, 0 means no cancel)
  # @param choices [Array<String>] all the possible choice
  # @note This function should only be called from text events!
  # @example Simple message
  #   message("It's a message!")
  # @example Message from CSV files
  #   message(ext_text(csv_id, index))
  # @example Message with choice
  #   choice_result = message("You are wonkru or you are the enemy of wonkru!\nChoose !", 1, 'Wonkru', '*Knifed*')
  # @return [Integer] the choosen choice (0 indexed this time)
  def message(string, cancel_type = 0, *choices)
    return rmxp_message(string, 1, *choices) unless @fiber
    choice_result = 0
    Fiber.yield(false) while $game_temp.message_text
    $game_player.look_to(@event_id) unless $game_switches[::Yuki::Sw::MSG_Noturn]
    @message_waiting = true
    $game_temp.message_proc = proc {@message_waiting = false }
    $game_temp.message_text = string
    if choices.any?
      $game_temp.choice_cancel_type = cancel_type
      $game_temp.choices = choices
      $game_temp.choice_max = choices.size
      $game_temp.choice_proc = proc { |n| choice_result = n }
    end
    Fiber.yield(true)
    return choice_result
  end
  # Show a yes no choice
  # @param message [String] message shown by the event
  # @param yes [String] string used as yes
  # @param no [String] string used as no
  # @example Simple yes/no choice (in a condition)
  #   yes_no_choice('Do you want to continue?')
  # @example Boy/Girl choice (in a condition, validation will mean boy)
  #   yes_no_choice('Are you a boy?[WAIT 60] \nOr are you a girl?', 'Boy', 'Girl')
  # @return [Boolean] if the yes option was choosen
  def yes_no_choice(message, yes = nil, no = nil)
    yes ||= text_get(11, 27)
    no ||= text_get(11, 28)
    return rmxp_message(message, 1, yes.dup, no.dup) == 0 unless @fiber
    return message(message, 2, yes.dup, no.dup) == 0
  end
  private
  # Call the RMXP message
  # @param message [String] message to display
  # @param start [Integer] choice start
  # @param choices [Array<String>] choices
  # @return [Integer]
  def rmxp_message(message, start, *choices)
    @message_waiting = true
    result = $scene.display_message(message, start, *choices)
    @message_waiting = false
    return result
  end
  public
  include Util::SystemMessage if const_defined?(:Util)
  # Name of the file used as Received Pokemon ME (with additional parameter like volume)
  RECEIVED_POKEMON_ME = ['audio/me/rosa_yourpokemonevolved', 80]
  # Header of the system messages
  SYSTEM_MESSAGE_HEADER = ':[windowskin=m_18]:\\c[10]'
  # Default BGM used for trainer battle (sent to AudioFile so no audio/bgm)
  DEFAULT_TRAINER_BGM = ['xy_trainer_battle', 100, 100]
  # Default eye bgm for trainer encounter (direct, requires audio/bgm)
  DEFAULT_EYE_BGM = ['audio/bgm/pkmrs-enc1', 100, 100]
  # Default exclamation SE for trainer encounter (direct, requires audio/se)
  DEFAULT_EXCLAMATION_SE = ['audio/se/015-jump01', 65, 95]
  # Duration of the exclamation particle
  EXCLAMATION_PARTICLE_DURATION = 54
  # Receive Pokemon sequence, when the player is given a Pokemon
  # @param pokemon_or_id [Integer, Symbol, PFM::Pokemon] the ID of the pokemon in the database or a Pokemon
  # @param level [Integer] the level of the Pokemon (if ID given)
  # @param shiny [Boolean, Integer] true means the Pokemon will be shiny, 0 means it'll have no chance to be shiny, other number are the chance (1 / n) the pokemon can be shiny.
  # @return [PFM::Pokemon, nil] if nil, the Pokemon couldn't be stored in the PC or added to the party. Otherwise it's the Pokemon that was added.
  def receive_pokemon_sequence(pokemon_or_id, level = 5, shiny = false)
    pokemon = add_pokemon(pokemon_or_id, level, shiny)
    if pokemon
      Audio.me_play(*RECEIVED_POKEMON_ME)
      show_message(:received_pokemon, pokemon: pokemon, header: SYSTEM_MESSAGE_HEADER)
      original_name = pokemon.given_name
      while yes_no_choice(load_message(:give_nickname_question))
        rename_pokemon(pokemon)
        if pokemon.given_name == original_name || yes_no_choice(load_message(:is_nickname_correct_qesion, pokemon: pokemon))
          break
        else
          pokemon.given_name = original_name
        end
      end
      pokemon_stored_sequence(pokemon) if $game_switches[Yuki::Sw::SYS_Stored]
      PFM::Text.reset_variables
    end
    return pokemon
  end
  # Show the "Pokemon was sent to BOX $" message
  # @param pokemon [PFM::Pokemon] Pokemon sent to the box
  def pokemon_stored_sequence(pokemon)
    show_message(:pokemon_stored_to_box, pokemon: pokemon, '[VAR BOXNAME]' => $storage.get_box_name($storage.current_box), header: SYSTEM_MESSAGE_HEADER)
  end
  # Start a trainer battle
  # @param trainer_id [Integer] ID of the trainer in Studio
  # @param bgm [String, Array] BGM to play for battle
  # @param disable [String] Name of the local switch to disable (if defeat)
  # @param enable [String] Name of the local switch to enable (if victory)
  # @param troop_id [Integer] ID of the troop to use : 3 = trainer, 4 = Gym Leader, 5 = Elite, 6 = Champion
  # @example Start a simple trainer battle
  #   start_trainer_battle(5) # 5 is the trainer 5 in Studio
  # @example Start a trainer battle agains a gym leader
  #   start_trainer_battle(5, bgm: '28 Pokemon Gym', troop_id: 4)
  def start_trainer_battle(trainer_id, bgm: DEFAULT_TRAINER_BGM, disable: 'A', enable: 'B', troop_id: 3)
    set_self_switch(false, disable, @event_id)
    original_battle_bgm = $game_system.battle_bgm
    $game_system.battle_bgm = RPG::AudioFile.new(*bgm)
    $game_variables[Yuki::Var::Trainer_Battle_ID] = trainer_id
    $game_temp.battle_abort = true
    $game_temp.battle_calling = true
    $game_temp.battle_troop_id = troop_id
    $game_temp.battle_can_escape = false
    $game_temp.battle_can_lose = false
    $game_temp.battle_proc = proc do |n|
      yield if block_given?
      $game_variables[Yuki::Var::Trainer_Battle_ID] = 0
      $game_variables[Yuki::Var::Second_Trainer_ID] = 0
      $game_variables[Yuki::Var::Allied_Trainer_ID] = 0
      set_self_switch(true, enable, @event_id) if n == 0
      $game_system.battle_bgm = original_battle_bgm
    end
  end
  # Start a trainer battle
  # @param trainer_id [Integer] ID of the trainer in Studio
  # @param second_trainer_id [Integer] ID of the second trainer in Studio
  # @param bgm [String, Array] BGM to play for battle
  # @param disable [String] Name of the local switch to disable (if defeat)
  # @param enable [String] Name of the local switch to enable (if victory)
  # @param troop_id [Integer] ID of the troop to use : 3 = trainer, 4 = Gym Leader, 5 = Elite, 6 = Champion
  def start_double_trainer_battle(trainer_id, second_trainer_id, bgm: DEFAULT_TRAINER_BGM, disable: 'A', enable: 'B', troop_id: 3, &block)
    start_trainer_battle(trainer_id, bgm: bgm, disable: disable, enable: enable, troop_id: troop_id, &block)
    $game_variables[Yuki::Var::Second_Trainer_ID] = second_trainer_id
  end
  # Start a trainer battle
  # @param trainer_id [Integer] ID of the trainer in Studio
  # @param second_trainer_id [Integer] ID of the second trainer in Studio
  # @param friend_trainer_id [Integer] ID of the friend trainer in Studio
  # @param bgm [String, Array] BGM to play for battle
  # @param disable [String] Name of the local switch to disable (if defeat)
  # @param enable [String] Name of the local switch to enable (if victory)
  # @param troop_id [Integer] ID of the troop to use : 3 = trainer, 4 = Gym Leader, 5 = Elite, 6 = Champion
  def start_double_trainer_battle_with_friend(trainer_id, second_trainer_id, friend_trainer_id, bgm: DEFAULT_TRAINER_BGM, disable: 'A', enable: 'B', troop_id: 3, &block)
    start_trainer_battle(trainer_id, bgm: bgm, disable: disable, enable: enable, troop_id: troop_id, &block)
    $game_variables[Yuki::Var::Second_Trainer_ID] = second_trainer_id
    $game_variables[Yuki::Var::Allied_Trainer_ID] = friend_trainer_id
  end
  # Sequence to call before start trainer battle
  # @param phrase [String] the full speech of the trainer
  # @param eye_bgm [String, Array] BGM to play during the speech
  # @param exclamation_se [String, Array] SE to play when the trainer detect the player
  # @example Simple eye sequence
  #   trainer_eye_sequence('Hello!')
  # @example Eye sequence with another eye_bgm
  #   trainer_eye_sequence('Hello!', eye_bgm: 'audio/bgm/pkmrs-enc7')
  def trainer_eye_sequence(phrase, eye_bgm: DEFAULT_EYE_BGM, exclamation_se: DEFAULT_EXCLAMATION_SE)
    character = get_character(@event_id)
    character.turn_toward_player
    front_coordinates = $game_player.front_tile
    unless character.x == front_coordinates.first && character.y == front_coordinates.last
      Audio.se_play(*exclamation_se)
      emotion(:exclamation)
      EXCLAMATION_PARTICLE_DURATION.times do
        move_player_and_update_graphics
      end
    end
    Audio.bgm_play(*eye_bgm)
    while (($game_player.x - character.x).abs + ($game_player.y - character.y).abs) > 1
      character.move_toward_player
      move_player_and_update_graphics while character.moving?
    end
    character.turn_toward_player
    $game_player.turn_toward_character(character)
    text = PFM::Text.parse_string_for_messages(phrase)
    message(text)
    @wait_count = 2
  end
  # Sequence that perform NPC trade
  # @param index [Integer] index of the Pokemon in the party
  # @param pokemon [PFM::Pokemon] Pokemon that is traded with
  def npc_trade_sequence(index, pokemon)
    return unless $actors[index].is_a?(PFM::Pokemon)
    actor = $actors[index]
    $actors[index] = pokemon
    $pokedex.mark_seen(pokemon.db_symbol, pokemon.form, forced: true)
    $pokedex.mark_captured(pokemon.db_symbol)
    message("#{actor.given_name} is being traded with #{pokemon.name}!")
    id, form = pokemon.evolve_check(:trade, actor) || pokemon.evolve_check(:tradeWith, actor)
    GamePlay.make_pokemon_evolve(pokemon, id, form, true) if id
  end
  private
  def move_player_and_update_graphics
    Graphics::FPSBalancer.global.run do
      $game_player.update
      $game_map.update
      $scene.spriteset.update
    end
    Graphics.update
  end
  public
  # Open a shop
  # @overload open_shop(items, prices)
  #   @param symbol_or_list [Symbol]
  #   @param prices [Hash] (optional)
  # @overload open_shop(items,prices)
  #   @param symbol_or_list [Array<Integer, Symbol>]
  #   @param prices [Hash] (optional)
  def open_shop(symbol_or_list, prices = {}, show_background: true)
    $scene.call_scene(GamePlay::Shop, symbol_or_list, prices, show_background: show_background)
    @wait_count = 2
  end
  alias ouvrir_magasin open_shop
  # Create a limited shop (in the main PFM::Shop object)
  # @param symbol_of_shop [Symbol] the symbol to link to the new shop
  # @param items_sym [Array<Symbol, Integer>] the array containing the symbols/id of the items to sell
  # @param items_quantity [Array<Integer>] the array containing the quantity of the items to sell
  # @param shop_rewrite [Boolean] if the system must completely overwrite an already existing shop
  def add_limited_shop(symbol_of_shop, items_sym = [], items_quantity = [], shop_rewrite: false)
    PFM.game_state.shop.create_new_limited_shop(symbol_of_shop, items_sym, items_quantity, shop_rewrite: shop_rewrite)
  end
  alias ajouter_un_magasin_limite add_limited_shop
  # Add items to a limited shop
  # @param symbol_of_shop [Symbol] the symbol of the existing shop
  # @param items_to_refill [Array<Symbol, Integer>] the array of the items' db_symbol/id
  # @param quantities_to_refill [Array<Integer>] the array of the quantity to refill
  def add_items_to_limited_shop(symbol_of_shop, items_to_refill = [], quantities_to_refill = [])
    PFM.game_state.shop.refill_limited_shop(symbol_of_shop, items_to_refill, quantities_to_refill)
  end
  alias ajouter_objets_magasin add_items_to_limited_shop
  # Remove items from a limited shop
  # @param symbol_of_shop [Symbol] the symbol of the existing shop
  # @param items_to_remove [Array<Symbol, Integer>] the array of the items' db_symbol/id
  # @param quantities_to_remove [Array<Integer>] the array of the quantity to remove
  def remove_items_from_limited_shop(symbol_of_shop, items_to_remove, quantities_to_remove)
    PFM.game_state.shop.remove_from_limited_shop(symbol_of_shop, items_to_remove, quantities_to_remove)
  end
  alias enlever_objets_magasin remove_items_from_limited_shop
  # Open a Pokemon shop
  # @overload open_shop(items, prices)
  #   @param symbol_or_list [Symbol]
  #   @param prices [Hash] (optional)
  #   @param show_background [Boolean] (optional)
  # @overload open_shop(items,prices)
  #   @param symbol_or_list [Array<Integer, Symbol>]
  #   @param prices [Array<Integer>]
  #   @param param [Array<Hash, Integer>]
  #   @param show_background [Boolean] (optional)
  def pokemon_shop_open(symbol_or_list, prices = [], param = [], show_background: true)
    if symbol_or_list.is_a?(Symbol)
      GamePlay.open_existing_pokemon_shop(symbol_or_list, prices.is_a?(Hash) ? prices : {}, show_background: show_background)
    else
      GamePlay.open_pokemon_shop(symbol_or_list, prices, param, show_background: show_background)
    end
    @wait_count = 2
  end
  alias ouvrir_magasin_pokemon pokemon_shop_open
  # Create a limited Pokemon Shop
  # @param sym_new_shop [Symbol] the symbol to link to the new shop
  # @param list_id [Array<Integer>] the array containing the id of the Pokemon to sell
  # @param list_price [Array<Integer>] the array containing the prices of the Pokemon to sell
  # @param list_param [Array] the array containing the infos of the Pokemon to sell
  # @param list_quantity [Array<Integer>] the array containing the quantity of the Pokemon to sell
  # @param shop_rewrite [Boolean] if the system must completely overwrite an already existing shop
  def add_new_pokemon_shop(sym_new_shop, list_id, list_price, list_param, list_quantity = [], shop_rewrite: false)
    PFM.game_state.shop.create_new_pokemon_shop(sym_new_shop, list_id, list_price, list_param, list_quantity, shop_rewrite: shop_rewrite)
  end
  alias ajouter_nouveau_magasin_pokemon add_new_pokemon_shop
  # Add Pokemon to a Pokemon Shop
  # @param symbol_of_shop [Symbol] the symbol of the shop
  # @param list_id [Array<Integer>] the array containing the id of the Pokemon to sell
  # @param list_price [Array<Integer>] the array containing the prices of the Pokemon to sell
  # @param list_param [Array] the array containing the infos of the Pokemon to sell
  # @param list_quantity [Array<Integer>] the array containing the quantity of the Pokemon to sell
  # @param pkm_rewrite [Boolean] if the system must completely overwrite the existing Pokemon
  def add_pokemon_to_shop(symbol_of_shop, list_id, list_price, list_param, list_quantity = [], pkm_rewrite: false)
    PFM.game_state.shop.refill_pokemon_shop(symbol_of_shop, list_id, list_price, list_param, list_quantity, pkm_rewrite: pkm_rewrite)
  end
  alias ajouter_pokemon_au_magasin add_pokemon_to_shop
  # Remove Pokemon from a Pokemon Shop
  # @param symbol_of_shop [Symbol] the symbol of the existing shop
  # @param remove_list_mon [Array<Integer>] the array of the Pokemon id
  # @param param_form [Array<Hash>] the form of the Pokemon to delete (only if there is more than one form of a Pokemon in the list)
  # @param quantities_to_remove [Array<Integer>] the array of the quantity to remove
  def remove_pokemon_from_shop(symbol_of_shop, remove_list_mon, param_form, quantities_to_remove = [])
    PFM.game_state.shop.remove_from_pokemon_shop(symbol_of_shop, remove_list_mon, param_form, quantities_to_remove)
  end
  alias enlever_pokemon_du_magasin remove_pokemon_from_shop
  public
  # Save the bag somewhere and make it empty in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_bag
  # @author Beef'
  def empty_and_save_bag(id_storage = nil)
    var_id = id_storage ? "@_str_bag_#{id_storage}".to_sym : :@other_bag
    bag = Marshal.load(Marshal.dump($bag))
    $bag = PFM.game_state.bag = PFM::Bag.new
    $storage.instance_variable_set(var_id, bag)
  end
  # Retrieve the saved bag when emptied ( /!\ empty the current bag)
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_bag
  # @author Beef'
  def retrieve_saved_bag(id_storage = nil)
    var_id = id_storage ? "@_str_bag_#{id_storage}".to_sym : :@other_bag
    bag = $storage.instance_variable_get(var_id)
    return nil if bag.empty?
    $bag = PFM.game_state.bag = bag
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Combined the saved bag with the current bag
  # @param id_storage [String] the specific name of the storage, if nil $storage.other_bag is picked
  # @author Beef'
  def combine_with_saved_bag(id_storage = nil)
    var_id = id_storage ? "@_str_bag_#{id_storage}".to_sym : :@other_bag
    saved_bag = $storage.instance_variable_get(var_id)
    return nil if saved_bag.empty?
    each_data_item.each do |item|
      item_db_symbol = item.db_symbol
      $bag.add_item(item_db_symbol, saved_bag.item_quantity(item_db_symbol))
    end
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Save the trainer somewhere and make it empty in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_trainer
  # @author Beef'
  def empty_and_save_trainer(id_storage = nil)
    var_id = id_storage ? "@_str_trainer_#{id_storage}".to_sym : :@other_trainer
    trainer = Marshal.load(Marshal.dump($trainer))
    $trainer = PFM.game_state.trainer = PFM::Trainer.new
    $storage.instance_variable_set(var_id, trainer)
  end
  # Retrieve the saved trainer 
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_trainer
  # @author Beef'
  def retrieve_saved_trainer(id_storage = nil)
    var_id = id_storage ? "@_str_trainer_#{id_storage}".to_sym : :@other_trainer
    trainer = $storage.instance_variable_get(var_id)
    return nil unless trainer.is_a? PFM::Trainer
    $trainer = PFM.game_state.trainer = trainer
    PFM.game_state.game_switches[Yuki::Sw::Gender] = $trainer.playing_girl
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Save the pokedex somewhere and make it empty in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_pokedex
  # @author Beef'
  def empty_and_save_pokedex(id_storage = nil)
    var_id = id_storage ? "@_str_pokedex_#{id_storage}".to_sym : :@other_pokedex
    pokedex = Marshal.load(Marshal.dump($pokedex))
    $pokedex = PFM.game_state.pokedex = PFM::Pokedex.new
    $storage.instance_variable_set(var_id, pokedex)
  end
  # Retrieve the saved pokedex when emptied
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_pokedex
  # @author Beef'
  def retrieve_saved_pokedex(id_storage = nil)
    var_id = id_storage ? "@_str_pokedex_#{id_storage}".to_sym : :@other_pokedex
    pokedex = $storage.instance_variable_get(var_id)
    return nil unless pokedex.is_a? PFM::Pokedex
    $pokedex = PFM.game_state.pokedex = pokedex
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Combined the saved pokedex with the current pokedex
  # @param id_storage [String] the specific name of the storage, if nil $storage.other_pokedex is picked
  # @author Beef'
  def combine_with_saved_pokedex(id_storage = nil, empty_pokedex: false)
    var_id = id_storage ? "@_str_pokedex_#{id_storage}".to_sym : :@other_pokedex
    saved_pokedex = $storage.instance_variable_get(var_id)
    return nil unless saved_pokedex.is_a? PFM::Pokedex
    each_data_creature.each do |pkmn|
      pkmn_db_symbol = pkmn.db_symbol
      $pokedex.mark_seen(pkmn_db_symbol) if saved_pokedex.creature_seen?(pkmn_db_symbol)
      $pokedex.mark_captured(pkmn_db_symbol) if saved_pokedex.creature_caught?(pkmn_db_symbol)
    end
    $storage.remove_instance_variable(var_id) if id_storage && empty_pokedex
  end
  # Save the money somewhere and make it null in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_money
  # @author Beef'
  def empty_and_save_money(id_storage = nil)
    var_id = id_storage ? "@_str_money_#{id_storage}".to_sym : :@other_money
    money = Marshal.load(Marshal.dump(PFM.game_state.money))
    PFM.game_state.money = 0
    $storage.instance_variable_set(var_id, money)
  end
  # Retrieve the saved money 
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_money
  # @author Beef'
  def retrieve_saved_money(id_storage = nil)
    var_id = id_storage ? "@_str_money_#{id_storage}".to_sym : :@other_money
    money = $storage.instance_variable_get(var_id)
    return nil unless money.is_a? Integer
    PFM.game_state.money = money
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Combined the saved money with the current money 
  # @param id_storage [String] the specific name of the storage, if nil $storage.other_money is picked
  # @author Beef'
  def combine_with_saved_money(id_storage = nil)
    var_id = id_storage ? "@_str_money_#{id_storage}".to_sym : :@other_money
    saved_money = $storage.instance_variable_get(var_id)
    return nil unless saved_money.is_a? Integer
    PFM.game_state.add_money(saved_money)
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Save the appearance somewhere and set the default in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_appearance
  # @author Beef'
  def empty_and_save_appearance(id_storage = nil)
    var_id = id_storage ? "@_str_appearance_#{id_storage}".to_sym : :@other_appearance
    charset_base = Marshal.load(Marshal.dump($game_player.charset_base))
    $game_player.set_appearance_set(nil.to_s)
    $storage.instance_variable_set(var_id, charset_base)
  end
  # Retrieve the saved appearance 
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_appearance
  # @author Beef'
  def retrieve_saved_appearance(id_storage = nil)
    var_id = id_storage ? "@_str_appearance_#{id_storage}".to_sym : :@other_appearance
    charset_base = $storage.instance_variable_get(var_id)
    return nil unless charset_base.is_a? String
    $game_player.set_appearance_set(charset_base)
    $storage.remove_instance_variable(var_id) if id_storage
  end
  # Save the team somewhere and make it empty in the point of view of the player.
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_party
  # @author Nuri Yuri
  def empty_and_save_party(id_storage = nil)
    var_id = id_storage ? "@_str_#{id_storage}".to_sym : :@other_party
    $actors.compact!
    party = Marshal.load(Marshal.dump($actors))
    $actors.clear
    $storage.instance_variable_set(var_id, party)
  end
  # Retrieve the saved team when emptied ( /!\ empty the current team)
  # @param id_storage [String] the specific name of the storage, if nil sent to $storage.other_party
  # @author Nuri Yuri
  def retrieve_saved_party(id_storage = nil)
    var_id = id_storage ? "@_str_#{id_storage}".to_sym : :@other_party
    party = $storage.instance_variable_get(var_id)
    return nil if party.empty?
    $actors.each do |pokemon|
      $storage.store(pokemon)
    end
    $actors = PFM.game_state.actors = party
    $storage.remove_instance_variable(var_id) if id_storage
  end
  alias retreive_saved_party retrieve_saved_party
  # Switch from one player to another, in term of party, trainer, money, pokedex and appearance (all optional)
  # @param from_player_id [String] the specific name of the storage to save to.
  # @param to_player_id [String] the specific name of the storage to load from.
  # @author Beef'
  def switch_player(from_player_id, to_player_id, switch_bag: true, switch_party: true, switch_trainer: true, switch_appearance: true, switch_money: true, switch_pokedex: true)
    if switch_bag
      empty_and_save_bag(from_player_id)
      retrieve_saved_bag(to_player_id)
    end
    if switch_party
      empty_and_save_party(from_player_id)
      retrieve_saved_party(to_player_id)
    end
    if switch_trainer
      empty_and_save_trainer(from_player_id)
      retrieve_saved_trainer(to_player_id)
    end
    if switch_appearance
      empty_and_save_appearance(from_player_id)
      retrieve_saved_appearance(to_player_id)
    end
    if switch_money
      empty_and_save_money(from_player_id)
      retrieve_saved_money(to_player_id)
    end
    if switch_pokedex
      empty_and_save_pokedex(from_player_id)
      retrieve_saved_pokedex(to_player_id)
    end
  end
  # Switch from one player to another, in term of party, trainer, money, pokedex and appearance (all optional)
  # The Yuki::Var::Current_Player_ID must be defined beforehand
  # @param to_player_id [String] the specific name of the storage to load from.
  # @author Beef'
  def switch_player_safe(to_player_id, switch_bag: true, switch_party: true, switch_trainer: true, switch_appearance: true, switch_money: true, switch_pokedex: true)
    from_player_id = $game_variables[Yuki::Var::Current_Player_ID]
    return nil if to_player_id == from_player_id
    switch_player(from_player_id, to_player_id, switch_bag: switch_bag, switch_party: switch_party, switch_trainer: switch_trainer, switch_appearance: switch_appearance, switch_money: switch_money, switch_pokedex: switch_pokedex)
    $game_variables[Yuki::Var::Current_Player_ID] = to_player_id
  end
end
