module GameData
  # Module that describes the Mining Game database and its derived methods
  module MiningGame
    module_function
    # Sign that indicate a part of the ITEM exist on a specific tile of a layout
    # @return true
    def x
      return true
    end
    # Sign that indicate a part of the ITEM does not exist on a specific tile of a layout
    # @return false
    def o
      return false
    end
    # Register an item
    # @param db_symbol [Symbol] db_symbol of the item
    # @param probability [Integer] chance of the item to appear
    # @param layout [Array<Array<boolean>>] layout of the item
    # @param accepted_max_rotation [Integer] ask Rey about it
    def register_item(db_symbol, probability, layout, accepted_max_rotation)
      DATA_ITEM[db_symbol] = {probability: probability, layout: layout, accepted_max_rotation: accepted_max_rotation}
    end
    # Register an iron
    # @param symbol [Symbol] unique name of the iron
    # @param probability [Integer] chance of the iron to appear
    # @param layout [Array<Array<boolean>>] layout of the iron
    # @param accepted_max_rotation [Integer] ask Rey about it
    def register_iron(symbol, probability, layout, accepted_max_rotation)
      DATA_IRON[symbol] = {probability: probability, layout: layout, accepted_max_rotation: accepted_max_rotation}
    end
    # The data list of each item that exist for the MiningGame
    # probability is an Integer and states how many chances out of the total of chances the item will be picked by the system.
    # layout is a [Array<Array>] where each sub-Array is assigned to one line; x means a part of the ITEM is here, o means that's not the case.
    # accepted_max_rotation is an Integer (between 0 and 3) determining the max rotation the sprite can have (90x degrees, x being accepted_max_rotation).
    DATA_ITEM = {}
    register_item(:blue_shard, 20, [[x, x, x], [x, x, x], [x, x, o]], 3)
    register_item(:green_shard, 20, [[x, x, x, x], [x, x, x, x], [x, x, o, x]], 3)
    register_item(:red_shard, 20, [[x, x, x], [x, x, o], [x, x, x]], 3)
    register_item(:yellow_shard, 20, [[x, o, x, o], [x, x, x, o], [x, x, x, x]], 3)
    register_item(:everstone, 1, [[x, x, x, x], [x, x, x, x]], 3)
    register_item(:dawn_stone, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:dusk_stone, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:fire_stone, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:ice_stone, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:leaf_stone, 1, [[o, x, o], [x, x, x], [x, x, x], [x, x, x]], 1)
    register_item(:moon_stone, 1, [[o, x, x, x], [x, x, x, o]], 1)
    register_item(:shiny_stone, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:sun_stone, 1, [[o, x, o], [x, x, x], [x, x, x]], 3)
    register_item(:thunder_stone, 1, [[o, x, x], [x, x, x], [x, x, o]], 3)
    register_item(:water_stone, 1, [[x, x, x], [x, x, x], [x, x, o]], 3)
    register_item(:damp_rock, 5, [[x, x, x], [x, x, x], [x, o, x]], 3)
    register_item(:hard_stone, 5, [[x, x], [x, x]], 0)
    register_item(:heart_scale, 20, [[x, o], [x, x]], 3)
    register_item(:heat_rock, 5, [[x, o, x, o], [x, x, x, x], [x, x, x, x]], 3)
    register_item(:icy_rock, 5, [[o, x, x, o], [x, x, x, x], [x, x, x, x], [x, o, o, x]], 3)
    register_item(:iron_ball, 5, [[x, x, x], [x, x, x], [x, x, x]], 0)
    register_item(:light_clay, 5, [[x, o, x, o], [x, x, x, o], [x, x, x, x], [o, x, o, x]], 3)
    register_item(:max_revive, 1, [[x, x, x], [x, x, x], [x, x, x]], 3)
    register_item(:odd_keystone, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x], [x, x, x, x]], 3)
    register_item(:rare_bone, 1, [[x, o, o, o, o, x], [x, x, x, x, x, x], [x, o, o, o, o, x]], 1)
    register_item(:revive, 5, [[o, x, o], [x, x, x], [o, x, o]], 1)
    register_item(:smooth_rock, 5, [[o, o, x, o], [x, x, x, o], [o, x, x, x], [o, x, o, o]], 3)
    register_item(:star_piece, 5, [[o, x, o], [x, x, x], [o, x, o]], 0)
    register_item(:draco_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:dread_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:earth_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:fist_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:flame_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:icicle_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:insect_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:iron_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:meadow_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:mind_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:pixie_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:sky_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:splash_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:spooky_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:stone_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:toxic_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:zap_plate, 1, [[x, x, x, x], [x, x, x, x], [x, x, x, x]], 1)
    register_item(:armor_fossil, 5, [[o, x, x, x, o], [o, x, x, x, o], [x, x, x, x, x], [o, x, x, x, o]], 3)
    register_item(:claw_fossil, 5, [[o, o, x, x], [o, x, x, x], [o, x, x, x], [x, x, x, o], [x, x, o, o]], 3)
    register_item(:dome_fossil, 5, [[x, x, x, x, x], [x, x, x, x, x], [x, x, x, x, x], [o, x, x, x, o]], 3)
    register_item(:helix_fossil, 5, [[o, x, x, x], [x, x, x, x], [x, x, x, x], [x, x, x, o]], 3)
    register_item(:old_amber, 5, [[o, x, x, x], [x, x, x, x], [x, x, x, x], [x, x, x, o]], 1)
    register_item(:root_fossil, 5, [[x, x, x, x, o], [x, x, x, x, x], [x, x, o, x, x], [o, o, o, x, x], [o, o, x, x, o]], 3)
    register_item(:skull_fossil, 5, [[x, x, x, x], [x, x, x, x], [x, x, x, x], [o, x, x, o]], 3)
    # The data list of each iron that exist for the MiningGame
    # probability is an Integer and states how many chances out of the total of chances the item will be picked by the system.
    # layout is a [Array<Array>] where each sub-Array is assigned to one line; x means a part of the ITEM is here, o means that's not the case.
    # accepted_max_rotation is an Integer (between 0 and 3) determining the max rotation the sprite can have (90x degrees, x being accepted_max_rotation).
    DATA_IRON = {}
    register_iron(:anti_stair, 20, [[x, o], [x, x], [o, x]], 1)
    register_iron(:big_square, 20, [[x, x, x], [x, x, x], [x, x, x]], 0)
    register_iron(:line, 20, [[x, x, x, x]], 1)
    register_iron(:rectangle, 20, [[x, x, x, x], [x, x, x, x]], 1)
    register_iron(:square, 20, [[x, x], [x, x]], 0)
    register_iron(:stair, 20, [[o, x], [x, x], [x, o]], 1)
    register_iron(:t_tetrimino, 20, [[o, x, o], [x, x, x]], 3)
    # Return the total of the chances to get a certain item
    # @return [Integer]
    def total_chance
      count = 0
      DATA_ITEM.each_key do |key|
        count += DATA_ITEM[key.to_sym][:probability]
      end
      return count
    end
    # Return the total of the chances to get a certain iron
    # @return [Integer]
    def iron_total_chance
      count = 0
      DATA_IRON.each_key do |key|
        count += DATA_IRON[key.to_sym][:probability]
      end
      return count
    end
  end
end
module PFM
  # Class describing the Hall_of_Fame logic
  class MiningGame
    # If the player is playing the mini-game for the first time
    # @return [Boolean]
    attr_accessor :first_time
    # If the player has access to the new dynamite tool
    # @return [Boolean]
    attr_accessor :dynamite_unlocked
    # Tells how many items the player has dug
    # @return [Integer]
    attr_accessor :nb_items_dug
    # Tells how many times the player has launched the mini-game
    # @return [Integer]
    attr_accessor :nb_game_launched
    # Tells how many times the player succeeded in the mini-game (every items dug)
    # @return [Integer]
    attr_accessor :nb_game_success
    # Tells how many times the player failed in the mini-game (wall collapsing)
    # @return [Integer]
    attr_accessor :nb_game_failed
    # Tells how many times the player used the pickaxe
    # @return [Integer]
    attr_accessor :nb_pickaxe_hit
    # Tells how many times the player used the mace
    # @return [Integer]
    attr_accessor :nb_mace_hit
    # Tells how many times the player used the dynamite
    # @return [Integer]
    attr_accessor :nb_dynamite_hit
    # Set the difficulty of the game (true = no yellow tiles at beginning)
    # @return [Boolean]
    attr_accessor :hard_mode
    def initialize
      @first_time = true
      @dynamite_unlocked = @hard_mode = false
      @nb_items_dug = @nb_game_launched = @nb_game_success = @nb_game_failed = @nb_pickaxe_hit = @nb_mace_hit = @nb_dynamite_hit = 0
    end
    # Class handling the grid for the mining game
    class GridHandler
      # Constant telling the minimum amount of item possible on a grid
      MIN_ITEM_COUNT = 2
      # Constant telling the maximum amount of item possible on a grid
      MAX_ITEM_COUNT = 5
      # Constant telling at how many unsuccessful tries the system switched from full randomness to semi-randomness
      # A lower number means the system will switch to a more mechanical way earlier
      # Might yield unexpected result, !!! Change with caution !!!
      # @return [Integer]
      SWITCH_METHOD_TRIES = 25
      # Constant telling the max number of tries the system has to randomly place an item or an iron
      # A higher number means a better probability of success but also means a higher loading time
      # !!! Change with caution !!!
      # @return [Integer]
      MAX_TRIES_ALLOWED = 50
      # Get the grid width
      # @return [Integer]
      attr_reader :width
      # Get the grid height
      # @return [Integer]
      attr_reader :height
      # Get the tile states
      # @return [Array<Array<Integer>>]
      attr_reader :arr_tiles_state
      # Get the list of diggable items
      # @return [Array<Diggable>]
      attr_reader :arr_items
      # Get the list of irons
      # @return [Array<Diggable>]
      attr_reader :arr_irons
      # Create a new grid handler
      # @param wanted_items [Array<Symbol>, nil] list of wanted items
      # @param item_count [Integer, nil] maximum number of items
      # @param grid_width [Integer] width of the grid
      # @param grid_height [Integer] height of the grid
      def initialize(wanted_items, item_count, grid_width, grid_height)
        @item_count = (item_count || wanted_items&.size || rand(MIN_ITEM_COUNT..MAX_ITEM_COUNT)).clamp(MIN_ITEM_COUNT, MAX_ITEM_COUNT)
        @wanted_items = (map_symbol2hash(wanted_items) || randomize_items(@item_count)).take(@item_count)
        @width = grid_width
        @height = grid_height
        @nb_irons = rand(4..7)
        @arr_irons = []
        @ready = false
        @arr_tiles_state = Array.new(@height) {Array.new(@width, 0) }
        @mgt = Random::MINING_GAME_TILES
        initialize_grid_content
      end
      # Tell if the mining game grid is ready
      # @return [Boolean]
      def ready?
        return @ready
      end
      # Check if a diggable is present at the said coordinate and return it if it's an item
      # @param x [Integer] x coordinate where we went to find the diggable
      # @param y [Integer] y coordinate where we went to find the diggable
      # @return [Diggable, Boolean] Diggable instance if item, true if iron, false if nothing
      def check_presence_of_diggable(x, y)
        diggable = @arr_items.find { |item| (item.x...item.x + item.width).cover?(x) && (item.y...item.y + item.height).cover?(y) }
        if diggable
          return diggable if diggable.pattern[y - diggable.y][x - diggable.x]
        end
        diggable = @arr_irons.find { |item| (item.x...item.x + item.width).cover?(x) && (item.y...item.y + item.height).cover?(y) }
        if diggable
          return true if diggable.pattern[y - diggable.y][x - diggable.x]
        end
        return false
      end
      private
      # Generate a random array of items to dig
      # @param nb_items [Integer] number of items to generate
      # @return [Array<Hash>]
      def randomize_items(nb_items)
        arr = []
        data = GameData::MiningGame::DATA_ITEM
        rng_item = Random::MINING_GAME_ITEM
        chance_range = 0..GameData::MiningGame.total_chance
        until arr.size == nb_items
          nb = rng_item.rand(chance_range)
          count = 0
          data.each do |key, item|
            count += item[:probability]
            next unless nb < count
            unless key == :heart_scale
              break if arr.index { |i| i[:symbol] == key }
            end
            break(arr.push(**item, symbol: key))
          end
        end
        return arr
      end
      # Initialize the grid content using a thread to profit of Graphics.update on slow computer
      def initialize_grid_content
        @ready = false
        Thread.new do
          t = Time.new
          launch_tile_state_procedure
          launch_item_placement_procedure
          launch_iron_placement_procedure
          log_debug("Generation took #{Time.new - t} seconds")
          @ready = true
        end
      end
      # Function that places the hiding tiles on the grid
      def launch_tile_state_procedure
        @rand_tile_state = (PFM.game_state.mining_game.hard_mode ? 6 : 2)
        until all_tile_placed?
          @probability = 100
          @rand_tile_state -= 1
          case PFM.game_state.mining_game.hard_mode
          when true
            @rand_tile_state = 6 if @rand_tile_state == 2
          when false
            @rand_tile_state = 6 if @rand_tile_state == 1
            @rand_tile_state = 2 if @rand_tile_state == 3
          end
          @rand_tile_state = 4 if @rand_tile_state == 5
          arr = first_tile
          @arr_tiles_state[arr[0][0]][arr[0][1]] = @rand_tile_state
          arr = update_tiles_state(arr) until arr.empty?
        end
      end
      # Tell if all tiles are placed
      # @return [Boolean]
      def all_tile_placed?
        return @arr_tiles_state.all? { |array| array.none?(0) }
      end
      # Get the first unplaced tile
      # @return [Array<Array(Integer, Integer)>]
      def first_tile
        arr = nil
        until arr
          tile = @arr_tiles_state[a = @mgt.rand(@height)][b = @mgt.rand(@width)]
          arr = [[a, b]] if tile == 0
        end
        return arr
      end
      # Function that update the state of all the adjacent tiles from arr tiles
      def update_tiles_state(arr)
        arr = get_any_adjacent_tile(arr)
        set_state_in_array(arr, @rand_tile_state)
        return arr
      end
      # Function that gives all the possible adjacent tiles and update probabilities
      def get_any_adjacent_tile(arr)
        new_arr = []
        arr.each do |(y, x)|
          add_north_tile(new_arr, y, x)
          add_south_tile(new_arr, y, x)
          add_west_tile(new_arr, y, x)
          add_east_tile(new_arr, y, x)
        end
        @probability -= 33 unless @probability < 33
        @probability = 5 if @probability < 5
        return new_arr
      end
      # Function that add the north tile to new_arr if possible
      # @param new_arr [Array]
      # @param y [Integer]
      # @param x [Integer]
      def add_north_tile(new_arr, y, x)
        y -= 1
        new_arr << [y, x] if y > -1 && @arr_tiles_state[y][x] == 0 && !new_arr.include?([y, x]) && @mgt.rand(0..100) < @probability
      end
      # Function that add the south tile to new_arr if possible
      # @param new_arr [Array]
      # @param y [Integer]
      # @param x [Integer]
      def add_south_tile(new_arr, y, x)
        y += 1
        new_arr << [y, x] if y < @height && @arr_tiles_state[y][x] == 0 && !new_arr.include?([y, x]) && @mgt.rand(0..100) < @probability
      end
      # Function that west the south tile to new_arr if possible
      # @param new_arr [Array]
      # @param y [Integer]
      # @param x [Integer]
      def add_west_tile(new_arr, y, x)
        x -= 1
        new_arr << [y, x] if x > -1 && @arr_tiles_state[y][x] == 0 && !new_arr.include?([y, x]) && @mgt.rand(0..100) < @probability
      end
      # Function that west the south tile to new_arr if possible
      # @param new_arr [Array]
      # @param y [Integer]
      # @param x [Integer]
      def add_east_tile(new_arr, y, x)
        x += 1
        new_arr << [y, x] if x < @width && @arr_tiles_state[y][x] == 0 && !new_arr.include?([y, x]) && @mgt.rand(0..100) < @probability
      end
      # Function that sets the state to all tiles contained in arr
      # @param arr [Array<Array(Integer, Integer)>] array of tile coordinate
      # @param state [Integer]
      def set_state_in_array(arr, state)
        arr.each do |(y, x)|
          @arr_tiles_state[y][x] = state
        end
      end
      # Function that place all the items on the grid
      def launch_item_placement_procedure
        @arr_items = create_diggables(@wanted_items)
        place_diggable(@arr_items)
      end
      # Function that create all the digable objects
      # @param items [Array<Hash>]
      # @return [Array<Diggable>]
      def create_diggables(items)
        return items.map { |hash| Diggable.new(hash) }
      end
      # Function that maps an Array of Symbol to Hashes in order to make sure they're mappable to diggable
      # @param arr [Array<Symbol>]
      # @return [Array<Hash>]
      def map_symbol2hash(arr)
        return nil unless arr
        data = GameData::MiningGame::DATA_ITEM
        arr = arr.map { |sym| sym.is_a?(Symbol) ? sym : data_item(sym).db_symbol }
        arr.select! { |item| data.keys.include? item }
        arr = arr.map do |sym|
          next({**data[sym], symbol: sym})
        end
        return nil if arr.empty?
        return arr
      rescue TypeError
        raise "Invalid Mining Game Item in #{arr}"
      end
      # Function that place the diggable on the map
      # @param array [Array<Diggable>]
      def place_diggable(array)
        attempt = 0
        array.sort_by!(&:area_size).reverse!
        array.each do |diggable|
          attempt += 1
          diggable.set_new_rotation
          if attempt <= SWITCH_METHOD_TRIES
            diggable.x, diggable.y = random_diggable_position(diggable)
          else
            if attempt <= MAX_TRIES_ALLOWED
              diggable.x, diggable.y = alternate_random_diggable_position(diggable)
            else
              if attempt > MAX_TRIES_ALLOWED
                diggable.x, diggable.y = final_random_diggable_position(diggable)
              end
            end
          end
          if check_diggable_well_placed(diggable)
            diggable.placed = true
            attempt = 0
          else
            redo unless attempt > MAX_TRIES_ALLOWED
            attempt = 0
            diggable.is_an_item ? @arr_items.delete(diggable) : @arr_irons.delete(diggable)
            next
          end
        end
      end
      # Function that generates a random position for a diggable
      # @param diggable [Diggable] the diggable used to clamp the width and height
      # @return [Array(Integer, Integer)]
      def random_diggable_position(diggable)
        return rand(@width - diggable.width), rand(@height - diggable.height)
      end
      # Function that generates a random position using a quarter of the screen for the diggable
      # @param diggable [Diggable] the diggable used to clamp the width and height
      # @return [Array(Integer, Integer)]
      def alternate_random_diggable_position(diggable)
        new_width = @width - diggable.width
        new_height = @height - diggable.height
        @possible_rand ||= [[0...(new_width / 2), 0...(new_height / 2)], [0...(new_width / 2), (new_height / 2)...new_height], [(new_width / 2)...new_width, 0...(new_height / 2)], [(new_width / 2)...new_width, (new_height / 2)...new_height]]
        sample = @possible_rand.sample
        return rand(sample[0]), rand(sample[1])
      end
      # Function that tries to map available spaces depending on the diggable and return one randomly
      # Will return 0, 0 if impossible
      # @param diggable [Diggable]
      # @return [Array(Integer, Integer)]
      def final_random_diggable_position(diggable)
        possible_combination = []
        nb_tries = (diggable.accepted_rotation + 1).clamp(1, 2)
        nb_tries.times do |i|
          possible_combination.clear
          diggable.set_specific_rotation(i)
          new_width = @width - diggable.width
          new_height = @height - diggable.height
          (0..new_width).each do |line|
            (0..new_height).each do |column|
              diggable.x = line
              diggable.y = column
              possible_combination << [line, column] if check_diggable_well_placed(diggable)
            end
          end
          break if possible_combination.any?
        end
        return 0, 0 if possible_combination.empty?
        return *possible_combination.sample
      end
      # Function that check if a diggable is well placed
      # @param diggable [Diggable]
      # @return [Boolean]
      def check_diggable_well_placed(diggable)
        return false if (diggable.x + diggable.width - 1) >= @width
        return false if (diggable.y + diggable.height - 1) >= @height
        return @arr_items.none? { |item| item.overlap?(diggable) } && @arr_irons.none? { |iron| iron.overlap?(diggable) }
      end
      # Function that place all the irons on the grid
      def launch_iron_placement_procedure
        @arr_irons = create_diggables(randomize_irons)
        place_diggable(@arr_irons)
      end
      # Function that randomize the irons and their
      def randomize_irons
        arr = []
        data = GameData::MiningGame::DATA_IRON
        rng_iron = Random::MINING_GAME_OBSTACLES
        change_range = 0..GameData::MiningGame.total_chance
        until arr.size == @nb_irons
          nb = rng_iron.rand(change_range)
          count = 0
          data.each do |key, iron|
            count += iron[:probability]
            next unless nb < count
            break(arr.push(**iron, symbol: key))
          end
        end
        return arr
      end
    end
    # Class handling the property of a diggable element
    class Diggable
      # The x position of the diggable
      # @return [Integer]
      attr_accessor :x
      # The y position of the diggable
      # @return [Integer]
      attr_accessor :y
      # The width of the diggable
      # @return [Integer]
      attr_accessor :width
      # The height of the diggable
      # @return [Integer]
      attr_accessor :height
      # The symbol of the item the Diggable represent
      # @return [Symbol]
      attr_accessor :symbol
      # The original pattern of the diggable
      # @return [Array<Array<Boolean>>]
      attr_accessor :origin_pattern
      # The current pattern of the diggable
      # @return [Array<Array<Boolean>>]
      attr_accessor :pattern
      # The accepted rotation of the diggable
      # @return [Integer]
      attr_accessor :accepted_rotation
      # The current rotation of the diggable
      # @return [Integer]
      attr_accessor :rotation
      # If the diggable is an item or not (then it's an iron)
      # @return [Boolean]
      attr_accessor :is_an_item
      # If the diggable is placed or not
      # @return [Boolean]
      attr_accessor :placed
      # If the diggable is revealed
      # @return [Boolean]
      attr_accessor :revealed
      def initialize(hash)
        @x = @y = 0
        @symbol = hash[:symbol]
        @origin_pattern = @pattern = hash[:layout].map(&:clone)
        @accepted_rotation = hash[:accepted_max_rotation]
        @rotation = 0
        set_new_rotation
        @is_an_item = GameData::MiningGame::DATA_ITEM.keys.include?(@symbol)
        @placed = @revealed = false
      end
      # Set a new rotation to the diggable and change values accordingly
      def set_new_rotation
        @rotation = @accepted_rotation != 0 ? rand(0..@accepted_rotation) : 0
        rotate_object
        set_width_and_length
      end
      # Set a specific rotation to the diggable and change values accordingly
      # @param rotation [Integer]
      def set_specific_rotation(rotation)
        @rotation = rotation.clamp(0, @accepted_rotation)
        rotate_object
        set_width_and_length
      end
      # Test if another diggable is overlapping this diggable
      # @param diggable [Diggable]
      # @return [Boolean]
      def overlap?(diggable)
        return false if self == diggable || !@placed
        return true if range_overlapping?(@x..(@x + @width - 1), (diggable.x..diggable.x + diggable.width)) && range_overlapping?(@y..(@y + @height - 1), (diggable.y..diggable.y + diggable.height))
      end
      # Give the area size (for sorting purpose)
      def area_size
        area_size = 0
        pattern.each { |line| area_size += line.size }
        return area_size
      end
      private
      # Rotate the pattern according to the new rotation
      def rotate_object
        arr = @origin_pattern
        @rotation.times {arr = arr.transpose.each(&:reverse!) }
        @pattern = arr
      end
      # Set the width and height of the diggable depending on current pattern
      def set_width_and_length
        @width = @pattern[0].size
        @height = @pattern.size
      end
      # Check if two ranges are overlapping
      def range_overlapping?(range1, range2)
        return true if range1.begin <= range2.end && range2.begin <= range1.end
        return false
      end
    end
  end
  class GameState
    # Stats and booleans relative to the Mining Game
    # @return [PFM::MiningGame]
    attr_accessor :mining_game
    on_player_initialize(:mining_game) {@mining_game = PFM::MiningGame.new }
    on_expand_global_variables(:mining_game) do
      @mining_game ||= PFM::MiningGame.new
    end
  end
end
module UI
  module MiningGame
    # Class that describes the Background of the Mining Game
    class Background < Sprite
      # Create the background
      # @param viewport [Viewport] the viewport of the scene
      def initialize(viewport)
        super(viewport)
        set_position(0, 0)
        set_bitmap(background_filename, :interface)
      end
      private
      # The filename of the background depending on the use of the dynamite or not
      # @return [String]
      def background_filename
        PFM.game_state.mining_game.dynamite_unlocked ? 'mining_game/background2' : 'mining_game/background'
      end
    end
    # Class that describes the Diggable_Sprite object
    class Diggable_Sprite < ShaderedSprite
      # Create the Diggable_Sprite
      # @param viewport [Viewport] the viewport of the scene
      # @param item [PFM::MiningGame::Diggable] the item/iron object
      def initialize(viewport, item)
        super(viewport)
        @item = item
        set_bitmap(image_path + @item.symbol.to_s, :interface)
        self.angle = (4 - @item.rotation) * 90 unless @item.rotation == 0
        set_origin(*correct_origin)
        self.x = @item.x * 16
        self.y = @item.y * 16 + 32
      end
      private
      # Return the correct pathname for the image
      # @return [String]
      def image_path
        str = 'mining_game/'
        str += @item.is_an_item == true ? 'items/' : 'irons/'
        return str
      end
      # Return the correct origin point for after rotating the image
      # @return [Array<Integer>]
      def correct_origin
        case @item.rotation
        when 0
          return 0, 0
        when 1
          return 0, height
        when 2
          return width, height
        when 3
          return width, 0
        end
      end
    end
    # Class that describes the Diggable_Stack
    class Diggable_Stack < SpriteStack
      # @return [Array<UI::MiningGame::Diggable_Sprite] the array containing every items' sprite
      attr_accessor :item_arr
      # @return [Array<UI::MiningGame::Diggable_Sprite] the array containing every irons' sprite
      attr_accessor :iron_arr
      # Create the Diggable_Stack
      # @param viewport [Viewport] the viewport of the scene
      # @param item_arr [Array<PFM::MiningGame::Diggable] the array containing the items to dig
      # @param iron_arr [Array<PFM::MiningGame::Diggable] the array containing the irons to not dig
      def initialize(viewport, item_arr, iron_arr)
        super(viewport, initial_x, initial_y)
        @item_arr = []
        @iron_arr = []
        item_arr.each { |item| @item_arr.push(Diggable_Sprite.new(@viewport, item)) }
        iron_arr.each { |obstacle| @iron_arr.push(Diggable_Sprite.new(@viewport, obstacle)) }
      end
      private
      # Return the x coordinate of the SpriteStack
      # @return [Integer]
      def initial_x
        return 0
      end
      # Return the y coordinate of the SpriteStack
      # @return [Integer]
      def initial_y
        return 32
      end
    end
    # Class that describes the Hit_Counter_Sprite
    class Hit_Counter_Sprite < SpriteSheet
      # @return [Integer] the current state
      attr_accessor :state
      # @return [Symbol] the symbol corresponding to the Hit_Counter_Sprite number (:first or :not_first)
      attr_accessor :reason
      # Create the Hit_Counter_Sprite
      # @param viewport [Viewport] the viewport of the scene
      # @param reason [Symbol] the symbol corresponding to the Hit_Counter_Sprite number
      def initialize(viewport, reason)
        @reason = reason
        super(viewport, number_of_image_x, number_of_image_y)
        set_bitmap(bitmap_filename, :interface)
        @state = -1
        set_visible
      end
      # Change the state of the Hit_Counter_Sprite
      def change_state
        @state += 1
        update_sheet
        set_visible unless @state > 0
      end
      # Return the number of images on a same column
      # @return [Integer]
      def number_of_image_y
        if @reason == :first
          return 9
        else
          return 7
        end
      end
      private
      # Return the number of images on a same line
      # @return [Integer]
      def number_of_image_x
        return 1
      end
      # Return the right image filename
      # @return [String]
      def bitmap_filename
        if @reason == :first
          return 'mining_game/crack_begin'
        else
          return 'mining_game/cracks'
        end
      end
      # Update the sheet appearance
      def update_sheet
        self.sy = @state
        update
      end
      # Set the visibility of the sprite
      def set_visible
        self.visible = (@state >= 0)
      end
    end
    # Class that describes the SpriteStack containing all the Hit_Counter_Sprite
    class Hit_Counter_Stack < SpriteStack
      # X Coordinates of first and second Hit_Counter_Sprite
      COORD_X = [206, 182]
      # The X space between all Hit_Counter_Sprite (except first and second)
      SPACE_BETWEEN_CRACKS = 24
      # Y Coordinates of first and every other Hit_Counter_Sprite
      COORD_Y = [0, 2]
      # Max number of Cracks
      NUMBER_OF_CRACKS = 10
      # Max number of hits the wall can take
      MAX_NB_HIT = 61
      # @return [Integer] the current number of hit
      attr_accessor :nb_hit
      # Create the Hit_Counter_Stack
      # @param viewport [Viewport] the viewport of the scene
      def initialize(viewport)
        super(viewport, 0, 0)
        @nb_hit = 0
        NUMBER_OF_CRACKS.times { |i| add_sprite(get_x(i), get_y(i), nil, i == 0 ? :first : :not_first, type: Hit_Counter_Sprite) }
      end
      # Method that send the correct number of hits
      # @param reason [Symbol] the symbol of the tool used to hit
      def send_hit(reason)
        hit = send(reason)
        stack.each_with_index do |crack, index|
          next if crack.state == crack.number_of_image_y - 1
          break if hit == 0
          break if @nb_hit == MAX_NB_HIT
          until crack.state == crack.number_of_image_y - 1
            crack.change_state
            stack[index + 1]&.change_state if crack.state == crack.number_of_image_y - 1 && index != 0
            hit -= 1
            @nb_hit += 1
            break if hit == 0
            break if @nb_hit == MAX_NB_HIT
          end
        end
      end
      # Check if the current number of hits is equal the max amount of hit
      # @return [Boolean]
      def max_cracks?
        return @nb_hit == MAX_NB_HIT
      end
      private
      # Get the good X coordinates for setting the Hit_Counter_Sprite
      # @param i [Integer] the index of the Hit_Counter_Sprite
      # @return [Integer]
      def get_x(i)
        if i == 0
          return COORD_X[0]
        else
          return COORD_X[1] - SPACE_BETWEEN_CRACKS * (i - 1)
        end
      end
      # Get the good Y coordinates for setting the Hit_Counter_Sprite
      # @param i [Integer] the index of the Hit_Counter_Sprite
      # @return [Integer]
      def get_y(i)
        if i == 0
          return COORD_Y[0]
        else
          return COORD_Y[1]
        end
      end
      # Return the number of hit for the pickaxe
      # @return [Integer]
      def pickaxe
        return 1
      end
      # Return the number of hit for the mace
      # @return [Integer]
      def mace
        return 2
      end
      # Return the number of hit for the dynamite
      # @return [Integer]
      def dynamite
        return 8
      end
    end
    # Class that describes the Tiles sprite
    class Tiles < SpriteSheet
      # @return [Integer] state of the tile
      attr_accessor :state
      # Create the Tiles
      # @param viewport [Viewport]
      # @param state [Integer] the state the image is initialized on (between 0 and 6)
      def initialize(viewport, state)
        super(viewport, possible_state_number, number_of_y_images)
        @state = state
        update_sx
      end
      # Update the state of the sheet
      def update_sx
        self.sx = @state
      end
      # Lower the state and update the image in consequence
      # @param reason [Symbol] the reason of lowering
      def lower_state(reason)
        if %i[pickaxe mace].include? reason
          @state -= 2
        else
          if reason == :side_pickaxe
            @state -= 1
          else
            if reason == :side_dynamite
              @state -= 4
            else
              if reason == :dynamite
                @state -= 6
              end
            end
          end
        end
        @state = 0 if @state < 0
        update_sx
      end
      private
      # The number of column of the sheet
      # @return [Integer]
      def number_of_y_images
        return 1
      end
      # The number of possible state of a tile
      # @return [Integer]
      def possible_state_number
        return 7
      end
    end
    # Class that describes the Tiles_Stack object
    class Tiles_Stack < SpriteStack
      # @return [Array<UI::MiningGame::Tiles] the array containing all the Tiles sprite
      attr_accessor :tile_array
      # Create the Tiles_Stack
      # @param viewport [Viewport] the viewport of the scene
      # @param arr [Array<Array<Integer>>] the array containing the arrays containing the tiles (columns<lines<tiles state>>)
      def initialize(viewport, arr)
        super(viewport, initial_x, initial_y)
        @tile_array = Array.new(arr.size) {[] }
        arr.each_with_index do |line, y_index|
          line.each_with_index do |state, x_index|
            push(texture_length * x_index, texture_width * y_index, bitmap_filename, state, type: Tiles)
          end
        end
        stack.each_with_index { |tile, index| @tile_array[index / 16] << tile }
      end
      # Get the Tiles sprite at given coordinates
      # @param x [Integer]
      # @param y [Integer]
      # @return [UI::MiningGame::Tiles] the tile required
      def get_tile(x, y)
        return @tile_array[y][x]
      end
      # Get the Tiles sprite adjacent to the one at given coordinates
      # @param x [Integer]
      # @param y [Integer]
      # @return [Array<UI::MiningGame::Tiles>] the tiles required
      def get_adjacent_of(x, y)
        arr = []
        arr << get_tile(x - 1, y) unless x == 0
        arr << get_tile(x + 1, y) unless x == @tile_array[0].size - 1
        arr << get_tile(x, y - 1) unless y == 0
        arr << get_tile(x, y + 1) unless y == @tile_array.size - 1
        return arr
      end
      private
      # Return the initial x coordinate of Tiles_Stack
      # @return [Integer]
      def initial_x
        return 0
      end
      # Return the initial x coordinate of Tiles_Stack
      # @return [Integer]
      def initial_y
        return 32
      end
      # Return the texture length
      # @return [Integer]
      def texture_length
        return 16
      end
      # Return the texture width
      # @return [Integer]
      def texture_width
        return 16
      end
      # Return the filename of the image
      # @return [String]
      def bitmap_filename
        return 'mining_game/tiles'
      end
    end
    # Class describing the Tool_Sprite object
    class Tool_Sprite < SpriteSheet
      # @return [Symbol] the symbol of the currently used tool
      attr_accessor :tool
      # Create the Tool_Sprite
      def initialize(viewport)
        super(viewport, number_image_x, number_image_y)
        change_tool(GamePlay::MiningGame::TOOLS[0])
        self.visible = false
      end
      # Increase x attribute by nb
      # @param nb [Integer]
      def add_to_x(nb)
        self.x = x + nb
      end
      # Decrease x attribute by nb
      # @param nb [Integer]
      def sub_to_x(nb)
        self.x = x - nb
      end
      # Increase y attribute by nb
      # @param nb [Integer]
      def add_to_y(nb)
        self.y = y + nb
      end
      # Decrease y attribute by nb
      # @param nb [Integer]
      def sub_to_y(nb)
        self.y = y - nb
      end
      # Set the next frame of the sheet
      def new_frame
        if sx + 1 == nb_x
          self.sx = 0
        else
          self.sx += 1
        end
        update
      end
      # Change the tool image
      # @param sym_tool [Symbol] the symbol of the currently used tool
      def change_tool(sym_tool)
        self.tool = sym_tool
        change_image
      end
      private
      # Return the number of images on a same line
      # @return [Integer]
      def number_image_x
        return 2
      end
      # Return the number of images on a same column
      # @return [Integer]
      def number_image_y
        return 1
      end
      # Set the new image of the sheet
      def change_image
        set_bitmap("mining_game/#{tool}_sprite", :interface) if GamePlay::MiningGame::TOOLS.include? tool
      end
    end
    # Class that describes the buttons that let the player choose his tool
    class Tool_Buttons < SpriteStack
      # Coordinates in no dynamite mode
      COORD_Y_2_TOOLS = [0, 80]
      # Coordinates in dynamite mode
      COORD_Y_3_TOOLS = [0, 64, 128]
      # Symbols of the tools
      TOOL_FILENAME = ['pickaxe', 'mace', 'dynamite']
      # @return [Integer] the currently selected button
      attr_accessor :index
      # @return [Array<SpriteSheet>] the array containing each button
      attr_accessor :buttons
      # @return [Yuki::Animation::TimedAnimation] the animation played when selecting a button
      attr_accessor :animation
      # Create the tool buttons
      # @param viewport [Viewport] the viewport of the scene
      def initialize(viewport)
        super(viewport, *initial_coordinates)
        @index = 0
        @animation = nil
        nb_tool = PFM.game_state.mining_game.dynamite_unlocked ? 3 : 2
        coord_y = PFM.game_state.mining_game.dynamite_unlocked ? COORD_Y_3_TOOLS : COORD_Y_2_TOOLS
        @buttons = []
        nb_tool.times { |i| buttons << add_sprite(0, coord_y[i], "mining_game/#{TOOL_FILENAME[i]}", 2, 1, type: SpriteSheet) }
        @button_click_anim = add_sprite(0, 0, 'mining_game/button_anim', 3, 3, type: SpriteSheet)
        @button_click_anim.visible = false
        button_state_change
      end
      # Change the state of each button depending on the one that is hit
      # @param index [Integer] the index of the hitted button
      # @return [Symbol] the symbol of the new tool to use
      def change_buttons_state(index)
        @index = index
        button_state_change
        button_animation
        return TOOL_FILENAME[index].to_sym
      end
      private
      # Initial coordinates of the SpriteStack
      # @return [Array<Integer>]
      def initial_coordinates
        if PFM.game_state.mining_game.dynamite_unlocked
          return 273, 52
        else
          return 273, 76
        end
      end
      # Change the tool buttons state and set the new tool
      # @return [Symbol] the symbol of the new tool to use
      def button_state_change
        @stack.each_with_index { |button, i| button.sx = i == @index ? 1 : 0 }
      end
      # Method that setup the button hit animation
      # @return [Yuki::Animation::TimedAnimation]
      def button_animation
        anim = Yuki::Animation
        @animation = anim.wait(0.01)
        @animation.play_before(anim.send_command_to(@button_click_anim, :sy=, @index)).parallel_add(anim.send_command_to(@button_click_anim, :sx=, 0)).parallel_add(anim.send_command_to(@button_click_anim, :x=, @stack[@index].x - 6)).parallel_add(anim.send_command_to(@button_click_anim, :y=, @stack[@index].y - 8)).parallel_add(anim.send_command_to(@button_click_anim, :visible=, true)).parallel_add(anim.se_play('choose'))
        @animation.play_before(anim.wait(0.04))
        @animation.play_before(anim.send_command_to(@button_click_anim, :sx=, @button_click_anim.sx + 1))
        @animation.play_before(anim.wait(0.04))
        @animation.play_before(anim.send_command_to(@button_click_anim, :sx=, @button_click_anim.sx + 1))
        @animation.play_before(anim.wait(0.04))
        @animation.play_before(anim.send_command_to(@button_click_anim, :visible=, false))
        @animation.start
      end
    end
    # Class that describes the Tool_Hit_Sprite object
    class Tool_Hit_Sprite < Tool_Sprite
      # Create the Tool_Hit_Sprite
      # @param viewport [Viewport] the viewport of the scene
      def initialize(viewport)
        super(viewport)
      end
      # Number of images on the same line
      # @return [Integer]
      def number_image_x
        return 5
      end
      # Set the new image of the sheet
      def change_image
        set_bitmap("mining_game/#{tool}_anim", :interface) if GamePlay::MiningGame::TOOLS.include? tool
      end
    end
  end
end
module GamePlay
  # Class that describes the functionment of the scene
  class MiningGame < BaseCleanUpdate::FrameBalanced
    # Constant that stock the Database of the Mining Game
    DATA = GameData::MiningGame::DATA_ITEM
    # The base music of the scene
    DEFAULT_MUSIC = 'audio/bgm/mining_game'
    # The number of tiles per lines in the table
    NB_X_TILES = 16
    # The number of tiles per columns in the table
    NB_Y_TILES = 13
    # IDs of the text displayed when playing for the first time
    FIRST_TIME_TEXT = [[9005, 6], [9005, 7], [9005, 8], [9005, 10], [9005, 11], [9005, 12]]
    # IDs of the text displayed when playing for the first time (dynamite mode)
    FIRST_TIME_TEXT_ALTERNATIVE = [9005, 9]
    # List of the usable tools
    TOOLS = %i[pickaxe mace dynamite]
    # Pathname of the SE folder
    SE_PATH = 'audio/se/mining_game'
    # @return [UI::MiningGame::Tiles_Stack]
    attr_accessor :tiles_stack
    # @return [Array<PFM::MiningGame::Diggable>]
    attr_accessor :arr_items_won
    # Initialize the UI
    # @overload initialize(item_count, music_filename = DEFAULT_MUSIC)
    #   @param item_count [Integer, nil] the number of items to search (nil for random between 2 and 5)
    #   @param music_filename [String] the filename of the music to play
    #   @param grid_handler [PFM::MiningGame::GridHandler, nil] hand-chosen grid handler
    # @overload initialize(wanted_item_db_symbols, music_filename = DEFAULT_MUSIC)
    #   @param wanted_item_db_symbols [Array<Symbol>] the array containing the specific items (comprised between 1 and 5 items)
    #   @param music_filename [String] the filename of the music to play
    #   @param grid_handler [PFM::MiningGame::GridHandler, nil] hand-chosen grid handler
    def initialize(param = nil, music_filename = DEFAULT_MUSIC, grid_handler: nil)
      super()
      PFM.game_state.mining_game.nb_game_launched += 1
      @handler = grid_handler
      @handler ||= PFM::MiningGame::GridHandler.new(param.is_a?(Array) ? param : nil, param.is_a?(Integer) ? param : nil, NB_X_TILES, NB_Y_TILES)
      @current_tool = :pickaxe
      @arr_items_won = []
      @animation = nil
      @transition_animation = nil
      @ui_state = :mouse
      @mbf_type = :mining_game
      @saved_grid_debug = false
      Audio.bgm_play(music_filename)
      @running = true
    end
    private
    # Method that execute the ping sound and might trigger the texts displayed the first time the player plays
    def launch_ping_text
      @transition_animation = nil
      Audio.se_play(File.join(SE_PATH, 'ping'))
      Graphics.wait(60)
      ping_text
      if PFM.game_state.mining_game.first_time
        Graphics.wait(60)
        first_time_text
      end
    end
    public
    include UI::MiningGame
    private
    # Create the graphics
    def create_graphics
      super
      Graphics.update until @handler.ready?
      create_snapshot
      create_background
      create_tool_buttons
      create_diggable_stacks
      create_tiles_stack
      create_hit_counter
      create_tool_hit_sprite
      create_iron_hit_sprite
      create_tool_sprite
      create_transition_sprite
      start_transition_in_animation
      Graphics.sort_z
    end
    # Update the graphics that needs to be updated (and @animation)
    def update_graphics
      @tool_buttons.animation.update if @tool_buttons.animation && !@tool_buttons.animation.done?
      @transition_animation&.update
      return unless @ui_state == :animation
      return if !@animation || @animation.done?
      @animation.update
      @tool_sprite.update
      @tool_hit_sprite.update
      @ui_state = :mouse if @animation.done?
    end
    # Create the viewports
    def create_viewport
      super
      @sup_viewport = Viewport.create(:main, @viewport.z + 1)
    end
    # Create the map snapshot
    def create_snapshot
      return unless @__last_scene&.viewport
      @snapshot = Sprite.new(@sup_viewport)
      add_disposable(@snapshot.bitmap = @__last_scene.viewport.snap_to_bitmap)
    end
    # Create the transition sprite
    def create_transition_sprite
      @transition = Sprite.new(@sup_viewport)
      @transition.set_bitmap('mining_game/black_background', :interface)
      @transition.set_position(0, -@transition.height)
    end
    # Create the background
    def create_background
      @background = Background.new(@viewport)
    end
    # Create the tool buttons
    def create_tool_buttons
      @tool_buttons = Tool_Buttons.new(@viewport)
    end
    # Create the stack of diggables
    def create_diggable_stacks
      @diggable_stack = Diggable_Stack.new(@viewport, @handler.arr_items, @handler.arr_irons)
    end
    # Create the stack of tiles
    def create_tiles_stack
      @tiles_stack = Tiles_Stack.new(@viewport, @handler.arr_tiles_state)
    end
    # Create the hit counter
    def create_hit_counter
      @hit_counter_stack = Hit_Counter_Stack.new(@viewport)
    end
    # Create the tool's sprite
    def create_tool_sprite
      @tool_sprite = Tool_Sprite.new(@viewport)
    end
    # Create the tool's hit sprite
    def create_tool_hit_sprite
      @tool_hit_sprite = Tool_Hit_Sprite.new(@viewport)
    end
    # Create the iron's hit sprite
    def create_iron_hit_sprite
      @iron_hit_sprite = Sprite.new(@viewport)
      @iron_hit_sprite.set_bitmap('mining_game/iron_hit', :interface).visible = false
    end
    public
    private
    # Launch the procedure of clicking the tile and everything that ensue
    # @param x [Integer] the x coordinate of the clicked on tile
    # @param y [Integer] the y coordinate of the clicked on tile
    def tile_click(x, y)
      array = []
      array << @tiles_stack.get_tile(x, y)
      array.concat(@tiles_stack.get_adjacent_of(x, y))
      array.each_with_index do |tile, index|
        if @current_tool == :pickaxe
          reason = (index == 0 ? :pickaxe : :side_pickaxe)
        else
          if @current_tool == :dynamite
            reason = (index == 0 ? :dynamite : :side_dynamite)
          else
            reason = :mace
          end
        end
        tile.lower_state(reason)
      end
      @hit_counter_stack.send_hit(@current_tool)
      add_hit_to_stats
      diggables = []
      diggables << @handler.check_presence_of_diggable(x, y)
      diggables << @handler.check_presence_of_diggable(x - 1, y)
      diggables << @handler.check_presence_of_diggable(x + 1, y)
      diggables << @handler.check_presence_of_diggable(x, y - 1)
      diggables << @handler.check_presence_of_diggable(x, y + 1)
      reveal = @tiles_stack.get_tile(x, y).state == 0
      newly_revealed = false
      diggables.each do |diggable|
        if diggable.is_a? PFM::MiningGame::Diggable
          check = check_reveal_of_items(diggable)
          if check
            unless @arr_items_won.include? diggable
              @arr_items_won << diggable
              diggable.revealed = newly_revealed = true
            end
          end
        end
      end
      play_hit_animation(x, y, diggables[0], reveal, newly_revealed)
    end
    # Change the tool currently used
    # @param value [Integer] the value of the button pressed to change the tool
    def change_tool(value)
      case value
      when 0
        @current_tool = :pickaxe
      when 1
        @current_tool = :mace
      when 2
        @current_tool = :dynamite
      end
    end
    # Add one to the stat of the currently used item
    def add_hit_to_stats
      case @current_tool
      when :pickaxe
        PFM.game_state.mining_game.nb_pickaxe_hit += 1
      when :mace
        PFM.game_state.mining_game.nb_mace_hit += 1
      when :dynamite
        PFM.game_state.mining_game.nb_dynamite_hit += 1
      end
    end
    public
    private
    # Play all the animations resulting from a hit
    # @param x [Integer] the x coordinate of the tile
    # @param y [Integer] the y coordinate of the tile
    # @param diggable [PFM::MiningGame::Diggable, Boolean] either the actual object or a boolean (true for iron, false otherwise)
    # @param reveal [Boolean] true if the Diggable is revealed or already revealed otherwise false
    # @param newly_revealed [Boolean] if the item is fully revealed for the first time
    def play_hit_animation(x, y, diggable, reveal, newly_revealed)
      @ui_state = :animation
      @tool_sprite.change_tool(@current_tool)
      @tool_hit_sprite.change_tool(@current_tool)
      @tool_sprite.set_position(x * 16 + 14, y * 16 + 32 - 20)
      @tool_sprite.visible = true
      @tool_hit_sprite.set_position(x * 16 - 17, y * 16 + 32 - 17).visible = false
      @iron_hit_sprite.set_position(x * 16 - 17, y * 16 + 32 - 17).visible = false
      anim = Yuki::Animation
      @animation = anim.wait(0.01)
      @animation.play_before(anim.wait(0.01)).parallel_add(tool_sprite_anim(diggable, reveal, newly_revealed)).parallel_add(tool_hit_sprite_anim(diggable, reveal)).parallel_add(sound_anim(diggable, reveal, newly_revealed))
      @animation.start
    end
    # Setup the animation for @tool_sprite
    # @param diggable [PFM::MiningGame::Diggable, Boolean] either the actual object or a boolean (true for iron, false otherwise)
    # @param reveal [Boolean] if an item is revealed by the hit
    # @param newly_revealed [Boolean] if an item is fully revealed for the first time
    # @return [Yuki::Animation::ResolverObjectCommand]
    def tool_sprite_anim(diggable, reveal, newly_revealed)
      anim = Yuki::Animation
      animation = anim.send_command_to(@tool_sprite, :sx=, 0)
      animation.play_before(anim.wait(0.03))
      if @current_tool != :dynamite
        animation.play_before(anim.wait(0.01)).parallel_add(anim.send_command_to(@tool_sprite, :sub_to_x, 8)).parallel_add(anim.send_command_to(@tool_sprite, :add_to_y, 8))
        animation.play_before(anim.wait(0.12))
        animation.play_before(anim.wait(0.01)).parallel_add(anim.send_command_to(@tool_sprite, :new_frame)).parallel_add(anim.send_command_to(@tool_sprite, :add_to_x, 8)).parallel_add(anim.send_command_to(@tool_sprite, :sub_to_y, 8))
        animation.play_before(anim.wait(0.06))
        animation.play_before(anim.wait(0.01)).parallel_add(anim.send_command_to(@tool_sprite, :add_to_x, 3))
        animation.play_before(anim.wait(0.10))
        animation.play_before(anim.send_command_to(@tool_sprite, :sub_to_x, 3))
        animation.play_before(anim.wait(0.10))
      else
        animation.play_before(anim.wait(0.06))
        animation.play_before(anim.wait(0.01)).parallel_add(anim.send_command_to(@tool_sprite, :sub_to_x, 15)).parallel_add(anim.send_command_to(@tool_sprite, :add_to_y, 15)).parallel_add(anim.send_command_to(@tool_sprite, :new_frame))
        animation.play_before(anim.wait(0.06))
        animation.play_before(anim.wait(0.01))
        animation.play_before(anim.send_command_to(@tool_sprite, :sub_to_x, 3))
        animation.play_before(anim.wait(0.10))
        animation.play_before(anim.wait(0.01)).parallel_add(anim.send_command_to(@tool_sprite, :add_to_x, 6))
        animation.play_before(anim.wait(0.10))
        animation.play_before(anim.send_command_to(@tool_sprite, :sub_to_x, 3))
        animation.play_before(anim.wait(0.10))
      end
      animation.play_before(anim.send_command_to(@tool_sprite, :visible=, false))
      return animation
    end
    # Setup the animation for @tool_hit_sprite or @iron_hit_sprite
    # @param diggable [PFM::MiningGame::Diggable, Boolean] either the actual object or a boolean (true for iron, false otherwise)
    # @param reveal [Boolean] if an item is revealed by the hit
    # @return [Yuki::Animation::ResolverObjectCommand]
    def tool_hit_sprite_anim(diggable, reveal)
      anim = Yuki::Animation
      nb = diggable ? 1 : 0
      sprite = (diggable == true && reveal) ? @iron_hit_sprite : @tool_hit_sprite
      animation = anim.send_command_to(sprite, :visible=, true)
      animation.play_before(anim.send_command_to(@tool_hit_sprite, :sx=, nb)) unless diggable == true
      animation.play_before(anim.wait(0.03))
      animation.play_before(anim.send_command_to(sprite, :visible=, false)) if !diggable.is_a? PFM::MiningGame::Diggable
      animation.play_before(anim.send_command_to(@tool_hit_sprite, :new_frame)) if diggable.is_a? PFM::MiningGame::Diggable
      animation.play_before(anim.wait(0.06))
      animation.play_before(anim.send_command_to(sprite, :visible=, true)) if !diggable.is_a? PFM::MiningGame::Diggable
      animation.play_before(anim.send_command_to(@tool_hit_sprite, :new_frame)) if diggable.is_a? PFM::MiningGame::Diggable
      animation.play_before(anim.wait(0.02))
      animation.play_before(anim.send_command_to(@tool_hit_sprite, :new_frame)) if diggable.is_a? PFM::MiningGame::Diggable
      animation.play_before(anim.wait(0.04))
      animation.play_before(anim.send_command_to(sprite, :visible=, false))
      animation.play_before(anim.wait(0.03))
      animation.play_before(anim.send_command_to(sprite, :visible=, true))
      animation.play_before(anim.wait(0.03))
      animation.play_before(anim.send_command_to(sprite, :visible=, false))
      return animation
    end
    # Setup the Audio part of the animation
    # @param diggable [PFM::MiningGame::Diggable, Boolean] either the actual object or a boolean (true for iron, false otherwise)
    # @param reveal [Boolean] if an item is revealed by the hit
    # @param newly_revealed [Boolean] if an item is fully revealed for the first time
    # @return [Yuki::Animation::TimedAnimation]
    def sound_anim(diggable, reveal, newly_revealed)
      anim = Yuki::Animation
      animation = anim.wait(0)
      animation.play_before(anim.se_play("mining_game/#{@current_tool}")) if diggable != true || reveal == false
      animation.play_before(anim.se_play('mining_game/iron')) if diggable == true && reveal
      animation.play_before(anim.wait(0.10))
      animation.play_before(anim.se_play('mining_game/reveal')) if (diggable.is_a? PFM::MiningGame::Diggable) && reveal
      animation.play_before(anim.wait(0.07))
      animation.play_before(anim.se_play('mining_game/fully_reveal')) if newly_revealed
      return animation
    end
    # Play the wall collapsing animation
    def start_wall_collapse_anim
      @transition_animation = Yuki::Animation.send_command_to(@transition, :visible=, true)
      @transition_animation.play_before(black_in_animation)
      @transition_animation.play_before(Yuki::Animation.message_locked_animation)
      @transition_animation.play_before(Yuki::Animation.send_command_to(self, :launch_loose_message))
      @transition_animation.start
    end
    # Start the transition_in animation
    def start_transition_in_animation
      @transition_animation = black_in_animation
      @transition_animation.play_before(Yuki::Animation.send_command_to(@snapshot, :visible=, false))
      @transition_animation.play_before(black_out_animation)
      @transition_animation.play_before(Yuki::Animation.send_command_to(@transition, :visible=, false))
      @transition_animation.play_before(Yuki::Animation.message_locked_animation)
      @transition_animation.play_before(Yuki::Animation.send_command_to(self, :launch_ping_text))
      @transition_animation.start
    end
    # Get the black sprite in animation
    def black_in_animation
      return Yuki::Animation.move(0.5, @transition, 0, -@transition.height, 0, 0)
    end
    # Get the black sprite out animation
    def black_out_animation
      return Yuki::Animation.move(0.5, @transition, 0, 0, 0, -@transition.height)
    end
    public
    private
    # Dull method, only here to check the win condition
    # @return [Boolean] false if @running == false
    def update_inputs
      return save_instance_for_debug if Input::Keyboard.press?(Input::Keyboard::LControl) && !@saved_grid_debug
      return false if @transition_animation && !@transition_animation.done?
      return false if @running == false
      check_win_lose_condition if @ui_state != :animation
      return true
    end
    # Save the current instance of the Mining Game in a file
    def save_instance_for_debug
      @saved_grid_debug = true
      Yuki::EXC.mining_game_reproduction(@handler)
    end
    # Check if a diggable item has been revealed
    # @param item [PFM::MiningGame::Diggable]
    # @return [Boolean]
    def check_reveal_of_items(item)
      return true if item.revealed
      return item.pattern.each_with_index.all? do |line, index_y|
        next(line.each_with_index.all? do |square, index_x|
          check = !square
          check = @tiles_stack.get_tile(item.x + index_x, item.y + index_y).state == 0 unless check
          next(check)
        end)
      end
    end
    # Method that play the text displayed for the first time the player plays
    def first_time_text
      FIRST_TIME_TEXT.size.times do |i|
        if i == 2
          str = PFM.game_state.mining_game.dynamite_unlocked ? FIRST_TIME_TEXT_ALTERNATIVE : FIRST_TIME_TEXT[i]
          display_message(ext_text(*str))
        else
          display_message(ext_text(*FIRST_TIME_TEXT[i]))
        end
      end
      PFM.game_state.mining_game.first_time = false
    end
    # ID of the ping text
    PING_TEXT = [9005, 4]
    # Method that play the ping text
    def ping_text
      PFM::Text.set_variable('[NB_ITEM]', @handler.arr_items.size.to_s)
      display_message(ext_text(*PING_TEXT))
      PFM::Text.reset_variables
    end
    # Check if the game is won or lost, and if none of the two then return
    def check_win_lose_condition
      if @arr_items_won.size == @handler.arr_items.size
        win
        end_of_game
      else
        if @hit_counter_stack.max_cracks?
          lose
        end
      end
    end
    # ID of the text for the lose scenario
    LOSE_TEXT = [9005, 13]
    # Method that play the lose condition
    def lose
      PFM.game_state.mining_game.nb_game_failed += 1
      Audio.se_play(File.join(SE_PATH, 'collapse'))
      start_wall_collapse_anim
    end
    # Show the message starting lost
    def launch_loose_message
      display_message_and_wait(ext_text(*LOSE_TEXT))
      end_of_game
    end
    # ID of the text for the win scenario
    WIN_TEXT = [9005, 14]
    # Method that play the win condition
    def win
      PFM.game_state.mining_game.nb_game_success += 1
      Audio.se_play(File.join(SE_PATH, 'win'))
      display_message(ext_text(*WIN_TEXT))
    end
    # ID of the text used to tell what items were excavated
    ITEM_WON_TEXT = [9005, 15]
    # Method that end the game and exit the scene
    def end_of_game
      @arr_items_won.each do |item|
        PFM::Text.set_variable('[NAME_ITEM]', data_item(item.symbol).name)
        Audio.me_play('audio/me/ROSA_ItemObtained')
        display_message_and_wait(ext_text(*ITEM_WON_TEXT))
        PFM.game_state.bag.add_item(item.symbol)
      end
      PFM.game_state.mining_game.nb_items_dug += @arr_items_won.size
      @running = false
    end
    public
    private
    # Check if the mouse was used to click on a tile or on a button
    # @param _moved [Boolean] if the mouse moved
    # @return [Boolean]
    def update_mouse(_moved)
      return false unless Mouse.moved || Mouse.trigger?(:left)
      return false unless @ui_state == :mouse
      @tiles_stack.tile_array.each_with_index do |line, index_y|
        line.each_with_index do |tile, index_x|
          next unless tile.simple_mouse_in?
          if Mouse.trigger?(:left)
            tile_click(index_x, index_y)
            return true
          end
        end
      end
      @tool_buttons.buttons.each_with_index do |button, index|
        next unless button.simple_mouse_in?
        if Mouse.trigger?(:left)
          @current_tool = @tool_buttons.change_buttons_state(index)
          return true
        end
      end
      return false
    end
  end
end
