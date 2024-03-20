module PFM
  # The quest management
  #
  # The main object is stored in $quests and PFM.game_state.quests
  class Quests
    # Tell if the system should check the signal when we test finished?(id) or failed?(id)
    AUTO_CHECK_SIGNAL_ON_TEST = true
    # Tell if the system should check the signal when we check the quest termination
    AUTO_CHECK_SIGNAL_ON_ALL_OBJECTIVE_VALIDATED = false
    # The list of active_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :active_quests
    # The list of finished_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :finished_quests
    # The list of failed_quests
    # @return [Hash<Integer => Quest>]
    attr_accessor :failed_quests
    # The signals that inform the game what quest started or has been finished
    # @return [Hash<start: Array<Integer>, finish: Array<Integer>, failed: Array<Integer>>]
    attr_accessor :signal
    # Create a new Quest management object
    def initialize
      @active_quests = {}
      @finished_quests = {}
      @failed_quests = {}
      @signal = {start: [], finish: [], failed: []}
    end
    # Start a new quest if possible
    # @param quest_id [Integer] the ID of the quest in the database
    # @return [Boolean] if the quest started
    def start(quest_id)
      return false if data_quest(quest_id).db_symbol == :__undef__
      return false if finished?(quest_id)
      return false if @active_quests.fetch(quest_id, nil)
      @active_quests[quest_id] = Quest.new(quest_id)
      @signal[:start] << quest_id
      return true
    end
    # Return an active quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def active_quest(quest_id)
      return @active_quests[quest_id]
    end
    # Return a finished quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def finished_quest(quest_id)
      return @finished_quests[quest_id]
    end
    # Return a failed quest by its id
    # @param quest_id [Integer]
    # @return [Quest]
    def failed_quest(quest_id)
      return @failed_quests[quest_id]
    end
    # Show a goal of a quest
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    def show_goal(quest_id, goal_index)
      return unless (quest = active_quest(quest_id))
      quest.data_set(:goals_visibility, goal_index, true)
    end
    # Tell if a goal is shown or not
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    # @return [Boolean]
    def goal_shown?(quest_id, goal_index)
      return false unless (quest = active_quest(quest_id))
      return quest.data_get(:goals_visibility, goal_index, false)
    end
    # Get the goal data index (if array like items / speak_to return the index of the goal in the array info from
    # data/quest data)
    # @param quest_id [Integer] the ID of the quest in the database
    # @param goal_index [Integer] the index of the goal in the goal order
    # @return [Integer]
    def get_goal_data_index(quest_id, goal_index)
      raise ScriptError, 'This method should be removed!!!!'
      if (quest = @active_quests.fetch(quest_id, nil)).nil?
        if (quest = @finished_quests.fetch(quest_id, nil)).nil?
          return 0 if (quest = @failed_quests.fetch(quest_id, nil)).nil?
        end
      end
      goal_sym = quest[:order][goal_index]
      cnt = 0
      quest[:order].each_with_index do |sym, i|
        break if i >= goal_index
        cnt += 1 if sym == goal_sym
      end
      return cnt
    end
    # Inform the manager that a NPC has been beaten
    # @param quest_id [Integer] the ID of the quest in the database
    # @param npc_name_index [Integer] the index of the name of the NPC in the quest data
    # @return [Boolean] if the quest has been updated
    def beat_npc(quest_id, npc_name_index)
      return false unless (quest = active_quest(quest_id))
      return false unless quest.objective?(:objective_beat_npc, npc_name_index)
      old_count = quest.data_get(:npc_beaten, npc_name_index, 0)
      quest.data_set(:npc_beaten, npc_name_index, old_count + 1)
      check_quest(quest_id)
      return true
    end
    # Inform the manager that a NPC has been spoken to
    # @param quest_id [Integer] the ID of the quest in the database
    # @param npc_name_index [Integer] the index of the name of the NPC in the quest data
    # @return [Boolean] if the quest has been updated
    def speak_to_npc(quest_id, npc_name_index)
      return false unless (quest = active_quest(quest_id))
      return false unless quest.objective?(:objective_speak_to, npc_name_index)
      quest.data_set(:spoken, npc_name_index, true)
      check_quest(quest_id)
      return true
    end
    # Inform the manager that an item has been added to the bag of the Player
    # @param item_id [Integer] ID of the item in the database
    def add_item(item_id)
      item_db_symbol = data_item(item_id).db_symbol
      active_quests.each_value do |quest|
        if quest.objective?(:objective_obtain_item, item_db_symbol)
          old_count = quest.data_get(:obtained_items, item_db_symbol, 0)
          quest.data_set(:obtained_items, item_db_symbol, old_count + 1)
          check_quest(quest.quest_id)
          next
        end
        next unless quest.objective?(:objective_obtain_item, item_id)
        old_count = quest.data_get(:obtained_items, item_id, 0)
        quest.data_set(:obtained_items, item_id, old_count + 1)
        check_quest(quest.quest_id)
      end
    end
    # Inform the manager that a Pokemon has been beaten
    # @param pokemon_symbol [Symbol] db_symbol of the Pokemon in the database
    def beat_pokemon(pokemon_symbol)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_beat_pokemon, pokemon_symbol)
        old_count = quest.data_get(:pokemon_beaten, pokemon_symbol, 0)
        quest.data_set(:pokemon_beaten, pokemon_symbol, old_count + 1)
        check_quest(quest.quest_id)
      end
    end
    # Inform the manager that a Pokemon has been captured
    # @param pokemon [PFM::Pokemon] the Pokemon captured
    def catch_pokemon(pokemon)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_catch_pokemon)
        quest_data = data_quest(quest.quest_id)
        quest_data.objectives.each do |objective|
          next unless objective.objective_method_name == :objective_catch_pokemon
          pokemon_id = objective.objective_method_args.first
          next unless quest.objective_catch_pokemon_test(pokemon_id, pokemon)
          pokemon_id = pokemon_id[:id] if pokemon_id.is_a?(Hash)
          old_count = quest.data_get(:pokemon_caught, pokemon_id, 0)
          quest.data_set(:pokemon_caught, pokemon_id, old_count + 1)
          check_quest(quest.quest_id)
        end
      end
    end
    # Inform the manager that a Pokemon has been seen
    # @param pokemon_symbol [Symbol] db_symbol of the Pokemon in the database
    def see_pokemon(pokemon_symbol)
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_see_pokemon, pokemon_symbol)
        quest.data_set(:pokemon_seen, pokemon_symbol, true)
        check_quest(quest.quest_id)
      end
    end
    # Inform the manager an egg has been found
    def egg_found
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_obtain_egg)
        old_count = quest.data_get(:obtained_eggs, 0)
        quest.data_set(:obtained_eggs, old_count + 1)
        check_quest(quest.quest_id)
      end
    end
    alias get_egg egg_found
    # Inform the manager an egg has hatched
    def hatch_egg
      active_quests.each_value do |quest|
        next unless quest.objective?(:objective_hatch_egg)
        old_count = quest.data_get(:hatched_eggs, nil, 0)
        quest.data_set(:hatched_eggs, nil, old_count + 1)
        check_quest(quest.quest_id)
      end
    end
    # Check the signals and display them
    def check_up_signal
      return unless $scene.is_a?(Scene_Map)
      if @signal[:start].any?
        start_names = @signal[:start].map { |quest_id| data_quest(quest_id).name }
        show_quest_inform(start_names, true)
      end
      if @signal[:finish].any?
        finish_names = @signal[:finish].collect { |quest_id| data_quest(quest_id).name }
        show_quest_inform(finish_names, false)
        @signal[:finish].each do |quest_id|
          @finished_quests[quest_id] = @active_quests[quest_id] if @active_quests[quest_id]
          @active_quests.delete(quest_id)
        end
      end
      @signal[:start].clear
      @signal[:finish].clear
    end
    # Check if a quest is done or not
    # @param quest_id [Integer] ID of the quest in the database
    def check_quest(quest_id)
      return unless (quest = active_quest(quest_id))
      return if @signal[:finish].include?(quest_id)
      return unless quest.finished?
      @signal[:finish] << quest_id
      check_up_signal if AUTO_CHECK_SIGNAL_ON_ALL_OBJECTIVE_VALIDATED
    end
    # Is a quest finished ?
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean]
    def finished?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return !@finished_quests.fetch(quest_id, nil).nil?
    end
    # Is a quest failed ?
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean]
    def failed?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return !@failed_quests.fetch(quest_id, nil).nil?
    end
    # Get the earnings of a quest
    # @param quest_id [Integer] ID of the quest in the database
    # @return [Boolean] if the earning were givent to the player
    def get_earnings(quest_id)
      return false unless (quest = finished_quest(quest_id))
      return false if quest.data_get(:earnings_distributed, false)
      quest.distribute_earnings
      return true
    end
    # Does the earning of a quest has been taken
    # @param quest_id [Integer] ID of the quest in the database
    def earnings_got?(quest_id)
      check_up_signal if AUTO_CHECK_SIGNAL_ON_TEST
      return false unless (quest = finished_quest(quest_id))
      return quest.data_get(:earnings_distributed, false)
    end
    # Import the quest data from dot 24 version of PSDK
    def import_from_dot24
      mapper = -> ((id, quest)) { [id, convert_quest_from_dot24_to_dot25(id, quest)] }
      @active_quests = @active_quests.map(&mapper).to_h
      @finished_quests = @finished_quests.map(&mapper).to_h
      @failed_quests = @failed_quests.map(&mapper).to_h
    end
    # Update teh quest data for Studio
    def update_quest_data_for_studio
      mapper = -> ((id, quest)) { [id, convert_quest_for_studio(id, quest)] }
      @active_quests = @active_quests.map(&mapper).to_h
      @finished_quests = @finished_quests.map(&mapper).to_h
      @failed_quests = @failed_quests.map(&mapper).to_h
    end
    private
    # Convert a quest from .24 to .25
    # @param id [Integer] ID of the quest
    # @param quest [Hash]
    # @return [PFM::Quests::Quest]
    def convert_quest_from_dot24_to_dot25(id, quest)
      return quest if quest.is_a?(PFM::Quests::Quest)
      mapper = -> (v, i) { [i, v] }
      new_quest = PFM::Quests::Quest.new(id)
      objectives = data_quest(id).objectives
      new_quest.data_set(:goals_visibility, quest[:shown])
      new_quest.data_set(:earnings_distributed, quest[:earnings])
      new_quest.data_set(:npc_beaten, quest[:npc_beaten].map.with_index(&mapper).to_h) if quest[:npc_beaten]
      new_quest.data_set(:spoken, quest[:spoken].map.with_index(&mapper).to_h) if quest[:spoken]
      import_data_id_like_objective(objectives, quest, new_quest, :objective_obtain_item, :obtained_items, :items)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_beat_pokemon, :pokemon_beaten, :pokemon_beaten)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_catch_pokemon, :pokemon_caught, :pokemon_catch)
      import_data_id_like_objective(objectives, quest, new_quest, :objective_see_pokemon, :pokemon_seen, :pokemon_seen)
      new_quest.data_set(:obtained_eggs, quest[:egg_counter]) if quest[:egg_counter]
      new_quest.data_set(:hatched_eggs, nil, quest[:egg_hatched]) if quest[:egg_hatched]
      return new_quest
    end
    # Convert a quest for Studio
    # @param id [Integer] ID of the quest
    # @param quest [PFM::Quests::Quest]
    def convert_quest_for_studio(id, quest)
      return false unless quest.is_a?(PFM::Quests::Quest)
      new_quest = quest.clone
      quest_data = new_quest.instance_variable_get(:@data)
      transform_keys_in_hash(quest_data[:obtained_items], :item) if quest_data.key?(:obtained_items)
      transform_keys_in_hash(quest_data[:pokemon_beaten]) if quest_data.key?(:pokemon_beaten)
      transform_keys_in_hash(quest_data[:pokemon_caught]) if quest_data.key?(:pokemon_caught)
      transform_keys_in_hash(quest_data[:pokemon_seen]) if quest_data.key?(:pokemon_seen)
      return new_quest
    end
    # Transform keys in quest data hash
    # @param data [Hash] the data hash to update
    # @param type [Symbol] the objective type (:pokemon, :item)
    def transform_keys_in_hash(data, type = :pokemon)
      a = data.select { |k, _| k.is_a?(Integer) }.transform_keys { |k| type == :pokemon ? data_creature(k).db_symbol : data_item(k).db_symbol }
      data.select! { |k, _| k.is_a?(Symbol) }
      data.merge!(a) { |_, old_v, new_v| old_v + new_v }
    end
    # Import data from ID like objective
    # @param objectives [Array<Studio::Quest::Objective>]
    # @param quest [Hash] old quest
    # @param new_quest [PFM::Quests::Quest] new quest
    # @param test_method_name [Symbol] test method name of the objective
    # @param new_key [Symbol] new symbol key for the objective in new quest
    # @param old_key [Symbol] old symbol key for the objective in old quest
    def import_data_id_like_objective(objectives, quest, new_quest, test_method_name, new_key, old_key)
      return unless quest[old_key]
      objectives = objectives.select { |objective| objective.objective_method_name == test_method_name }
      objectives.each_with_index do |objective, i|
        new_quest.data_set(new_key, objective.objective_method_args.first, quest[old_key][i])
      end
    end
    # Give a specific earning
    # @param earning [Hash]
    def give_earning(earning)
      if earning[:money]
        PFM.game_state.add_money(earning[:money])
      else
        if earning[:item]
          $bag.add_item(earning[:item], earning[:item_amount])
        else
          if earning[:pokemon]
            pokemon_data = earning[:pokemon]
            PFM.game_state.add_pokemon(pokemon_data.is_a?(Hash) ? PFM::Pokemon.generate_from_hash(pokemon_data) : PFM::Pokemon.new(pokemon_data, 5))
          end
        end
      end
    end
    # Show the new/finished quest info
    # @param names [Array<String>]
    # @param is_new [Boolean]
    def show_quest_inform(names, is_new)
      return unless $scene.is_a?(Scene_Map)
      helper = $scene.spriteset
      names.each { |name| helper.inform_quest(name, is_new) }
    end
    public
    # Class describing a running quest
    class Quest
      # Get the quest id
      # @return [Integer]
      attr_reader :quest_id
      # Create a new quest
      # @param quest_id [Integer] ID of the quest
      def initialize(quest_id)
        @quest_id = quest_id
        @data = {}
        quest = data_quest(quest_id)
        data_set(:goals_visibility, quest.objectives.map { |objective| !objective.hidden_by_default })
      end
      # Get a specific data information
      # @param path [Array<Symbol, Integer>] path used to obtain the data
      # @param default [Object] default value
      # @return [Object, default]
      def data_get(*path, default)
        return @data.dig(*path) || default
      end
      # Set a specific data information
      # @param path [Array<Symbol, Integer>] path used to obtain the data
      # @param value [Object]
      def data_set(*path, value)
        data = @data
        last_part = path.pop
        path.each do |part|
          data = (data[part] ||= {})
        end
        data[last_part] = value
      end
      # Test if the quest has a specific kind of objective
      # @param objective_method_name [Symbol] name of the method to call to validate the objective
      # @param args [Array] double check to ensure the arguments match the test
      # @return [Boolean]
      def objective?(objective_method_name, *args)
        quest = data_quest(quest_id)
        objective_visibility = data_get(:goals_visibility, nil.to_a)
        quest.objectives.each_with_index do |objective, index|
          next if objective.hidden_by_default && !objective_visibility[index]
          next unless objective.objective_method_name == objective_method_name
          next unless args.each_with_index.all? { |arg, i| objective.objective_method_args[i] == arg }
          return true
        end
        return false
      end
      # Distribute the earning of the quest
      def distribute_earnings
        data = data_quest(@quest_id)
        data.earnings.each do |earning|
          send(earning.earning_method_name, *earning.earning_args)
        end
        data_set(:earnings_distributed, true)
      end
      # Tell if all the objective of the quest are finished
      # @return [Boolean]
      def finished?
        data = data_quest(@quest_id)
        return data.objectives.all? do |objective|
          send(objective.objective_method_name, *objective.objective_method_args)
        end
      end
      # Get the list of objective texts with their validation state
      # @return [Array<Array(String, Boolean)>]
      # @note Does not return text of hidden objectives
      def objective_text_list
        objective_visibility = data_get(:goals_visibility, nil.to_a)
        data = data_quest(@quest_id)
        visible_objectives = data.objectives.select.with_index { |_, index| objective_visibility[index] }
        return visible_objectives.map do |objective|
          [send(objective.text_format_method_name, *objective.objective_method_args), send(objective.objective_method_name, *objective.objective_method_args)]
        end
      end
      # Check the specific pokemon criterion in catch_pokemon
      # @param pkm [Hash, Integer] the criterions of the Pokemon
      #
      #   The criterions are :
      #     nature: opt Integer # ID of the nature of the Pokemon
      #     type: opt Integer # One required type id
      #     min_level: opt Integer # The minimum level the Pokemon should have
      #     max_level: opt Integer # The maximum level the Pokemon should have
      #     level: opt Integer # The level the Pokemon must be
      # @param pokemon [PFM::Pokemon] the Pokemon that should be check with the criterions
      # @return [Boolean] if the Pokemon pokemon check the criterions
      def objective_catch_pokemon_test(pkm, pokemon)
        return pokemon.id == pkm unless pkm.is_a?(Hash)
        return false if pkm[:id] && !(pokemon.id == pkm[:id] || pokemon.db_symbol == pkm[:id])
        return false if pkm[:nature] && pokemon.nature_id != pkm[:nature]
        return false if pkm[:type] && pokemon.type1 != pkm[:type] && pokemon.type2 != pkm[:type]
        return false if pkm[:type2] && pokemon.type1 != pkm[:type2] && pokemon.type2 != pkm[:type2]
        return false if pkm[:min_level] && pokemon.level <= pkm[:min_level]
        return false if pkm[:max_level] && pokemon.level >= pkm[:max_level]
        return false if pkm[:level] && pokemon.level != pkm[:level]
        return true
      end
      private
      # Test if the objective speak to is validated
      # @param index [Integer] index of the npc
      # @param _name [String] name of the npc (ignored)
      # @return [Boolean]
      def objective_speak_to(index, _name)
        return data_get(:spoken, index, false)
      end
      # Get the text related to the speak to objective
      # @param _index [Integer] index of the npc (ignored)
      # @param name [String] name of the npc
      # @return [String]
      def text_speak_to(_index, name)
        return format(ext_text(9000, 53), name: name)
      end
      # Test if the objective obtain item is validated
      # @param item_symbol [Integer] db_symbol of the item in the database
      # @param amount [Integer] number of item to obtain
      # @return [Boolean]
      def objective_obtain_item(item_symbol, amount)
        return data_get(:obtained_items, item_symbol, 0) >= amount
      end
      # Text of the obtain item objective
      # @param item_symbol [Integer] db_symbol of the item in the database
      # @param amount [Integer] number of item to obtain
      # @return [String]
      def text_obtain_item(item_symbol, amount)
        found = data_get(:obtained_items, item_symbol, 0).clamp(0, amount)
        name = data_item(item_symbol).name
        return format(ext_text(9000, 52), amount: amount, item_name: name, found: found)
      end
      # Test if the objective see pokemon is validated
      # @param pokemon_symbol [Symbol] db_symbol of the pokemon to see
      # @param amount [Integer] number of pokemon to see
      # @return [Boolean]
      def objective_see_pokemon(pokemon_symbol, amount = 1)
        return data_get(:pokemon_seen, pokemon_symbol, false)
      end
      # Text of the see pokemon objective
      # @param pokemon_symbol [Symbol] db_symbol of the pokemon to see
      # @param amount [Integer] number of pokemon to see
      # @return [String]
      def text_see_pokemon(pokemon_symbol, amount = 1)
        return format(ext_text(9000, 54), name: data_creature(pokemon_symbol).name)
      end
      # Test if the beat pokemon objective is validated
      # @param pokemon_symbol [Symbol] db_symbol of the pokemon to beat
      # @param amount [Integer] number of pokemon to beat
      # @return [Boolean]
      def objective_beat_pokemon(pokemon_symbol, amount)
        return data_get(:pokemon_beaten, pokemon_symbol, 0) >= amount
      end
      # Text of the beat pokemon objective
      # @param pokemon_symbol [Symbol] db_symbol of the pokemon to beat
      # @param amount [Integer] number of pokemon to beat
      # @return [String]
      def text_beat_pokemon(pokemon_symbol, amount)
        name = data_creature(pokemon_symbol).name
        found = data_get(:pokemon_beaten, pokemon_symbol, 0).clamp(0, amount)
        return format(ext_text(9000, 55), amount: amount, name: name, found: found)
      end
      # Test if the catch pokemon objective is validated
      # @param pokemon_data [Hash] data of the pokemon to catch
      # @param amount [Integer] number of pokemon to beat
      # @return [Boolean]
      def objective_catch_pokemon(pokemon_data, amount)
        return data_get(:pokemon_caught, pokemon_data[:id], 0) >= amount
      end
      # Text of the catch pokemon objective
      # @param pokemon_data [Integer] data of the pokemon to beat
      # @param amount [Integer] number of pokemon to beat
      # @return [String]
      def text_catch_pokemon(pokemon_data, amount)
        name = text_catch_pokemon_name(pokemon_data)
        found = data_get(:pokemon_caught, pokemon_data[:id], 0).clamp(0, amount)
        format(ext_text(9000, 56), amount: amount, name: name, found: found)
      end
      # Get the exact text for the name of the caught pokemon
      # @param data [Integer, Hash]
      # @return [String]
      def text_catch_pokemon_name(data)
        return data_creature(data).name if data.is_a?(Integer)
        str = data[:id] ? data_creature(data[:id]).name.dup : 'Pokémon'
        str << format(ext_text(9000, 63), data_type(data[:type]).name) if data[:type]
        str << format(ext_text(9000, 64), text_get(8, data[:nature])) if data[:nature]
        if (id = data[:min_level])
          str << format(ext_text(9000, 66), id)
          str << format(ext_text(9000, 67), data[:max_level]) if data[:max_level]
        else
          if (id = data[:max_level])
            str << format(ext_text(9000, 68), id)
          end
        end
        str << format(ext_text(9000, 65), data[:level]) if data[:level]
        return str
      end
      # Test if the beat NPC objective is validated
      # @param index [Integer] index of the npc
      # @param _name [String] name of the npc (ignored)
      # @param amount [Integer] number of time the npc should be beaten
      # @return [Boolean]
      def objective_beat_npc(index, _name, amount)
        return data_get(:npc_beaten, index, 0) >= amount
      end
      # Text of the beat NPC objective
      # @param index [Integer] index of the npc
      # @param name [String] name of the npc
      # @param amount [Integer] number of time the npc should be beaten
      # @return [String]
      def text_beat_npc(index, name, amount)
        if amount > 1
          found = data_get(:npc_beaten, index, 0).clamp(0, amount)
          return format(ext_text(9000, 57), amount: amount, name: name, found: found)
        end
        return format(ext_text(9000, 58), name: name)
      end
      # Test if the obtain egg objective is validated
      # @param amount [Integer] amount of egg to obtain
      # @return [Boolean]
      def objective_obtain_egg(amount)
        return data_get(:obtained_eggs, 0) >= amount
      end
      # Text of the obtain egg objective
      # @param amount [Integer] amount of egg to obtain
      # @return [Boolean]
      def text_obtain_egg(amount)
        if amount > 1
          found = data_get(:obtained_eggs, 0).clamp(0, amount)
          return format(ext_text(9000, 59), amount: amount, found: found)
        end
        return ext_text(9000, 60)
      end
      # Test if the hatch egg objective is validated
      # @param unk [nil] ???
      # @param amount [Integer] amount of egg to obtain
      # @return [Boolean]
      def objective_hatch_egg(unk, amount)
        return data_get(:hatched_eggs, unk, 0) >= amount
      end
      # Text of the hatch egg objective
      # @param unk [nil] ???
      # @param amount [Integer] amount of egg to obtain
      # @return [Boolean]
      def text_hatch_egg(unk, amount)
        if amount > 1
          found = data_get(:hatched_eggs, unk, 0).clamp(0, amount)
          return format(ext_text(9000, 61), amount: amount, found: found)
        end
        return ext_text(9000, 62)
      end
      # Getting money from a quest
      # @param amount [Integer] amount of money gotten
      def earning_money(amount)
        return if data_get(:earnings, :money, false)
        PFM.game_state.add_money(amount)
        data_set(:earnings, :money, true)
      end
      # Earning money text
      # @param amount [Integer] amount of money gotten
      # @return [String]
      def text_earn_money(amount)
        return parse_text(11, 9, ::PFM::Text::NUM7R => amount.to_s)
      end
      # Getting item from a quest
      # @param item_id [Integer, Symbol] ID of the item to give
      # @param amount [Integer] number of item to give
      def earning_item(item_id, amount)
        item_id = data_item(item_id).db_symbol unless item_id.is_a?(Symbol)
        return if data_get(:earnings, :items, item_id, false)
        $bag.add_item(item_id, amount)
        data_set(:earnings, :items, item_id, true)
      end
      # Earning item text
      # @param item_id [Integer, Symbol] ID of the item to give
      # @param amount [Integer] number of item to give
      def text_earn_item(item_id, amount)
        return format('%<amount>d %<name>s', amount: amount, name: data_item(item_id).name)
      end
      # Getting Pokemon from a quest
      # @param data [Integer, Symbol, Hash] data of the Pokémon to give
      def earning_pokemon(data)
        pokemon = data.is_a?(Hash) ? PFM::Pokemon.generate_from_hash(data) : PFM::Pokemon.new(data, 5)
        return if data_get(:earnings, :pokemon, pokemon, false)
        PFM.game_state.add_pokemon(pokemon)
        data_set(:earnings, :pokemon, pokemon, true)
      end
      # Earning Pokemon text
      # @param data [Integer, Symbol, Hash] data of the Pokémon to give
      def text_earn_pokemon(data)
        pokemon_id = data.is_a?(Hash) ? data[:id] : data
        return format('1 %<name>s', name: data_creature(pokemon_id).name)
      end
      # Getting egg from a quest
      # @param data [Integer, Symbol, Hash] data of the egg to give
      def earning_egg(data)
        pokemon = data.is_a?(Hash) ? PFM::Pokemon.generate_from_hash(data) : PFM::Pokemon.new(data, 1)
        pokemon.egg_init
        pokemon.memo_text = [28, 31]
        return if data_get(:earnings, :egg, pokemon, false)
        PFM.game_state.add_pokemon(pokemon)
        data_set(:earnings, :egg, pokemon, true)
      end
      # Earning egg text
      # @param data [Integer, Symbol, Hash] data of the egg to give
      def text_earn_egg(data)
        return format('1 %<egg>s', egg: text_file_get(0)[0])
      end
    end
  end
  class GameState
    # The player quests informations
    # @return [PFM::Quests]
    attr_accessor :quests
    safe_code('Setup Quest in GameState') do
      on_player_initialize(:quests) {@quests = PFM::Quests.new }
      on_expand_global_variables(:quests) do
        $quests = @quests
      end
    end
  end
end
module UI
  module Quest
    # Scrollbar UI element for quest
    class ScrollBar < SpriteStack
      # @return [Integer] current index of the scrollbar
      attr_reader :index
      # @return [Integer] number of possible indexes
      attr_reader :max_index
      # Number of pixel the scrollbar use to move the button
      HEIGHT = 153
      # Base Y for the scrollbar
      BASE_Y = 38
      # Create a new scrollbar
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, 310, BASE_Y)
        add_background('quest/scroll')
        @button = add_sprite(-1, 0, 'quest/button_scroll')
        @index = 0
        @max_index = 1
      end
      # Set the current index of the scrollbar
      # @param value [Integer] the new index
      def index=(value)
        @index = value.clamp(0, @max_index)
        @button.y = ((BASE_Y + 4) + HEIGHT * @index / @max_index)
      end
      # Set the number of possible index
      # @param value [Integer] the new max index
      def max_index=(value)
        @max_index = value <= 0 ? 1 : value
        self.index = 0
      end
    end
    # Arrow telling which item is selected
    class Arrow < Sprite
      # Create a new arrow
      # @param viewport [Viewport]
      def initialize(viewport)
        super
        @animation = nil
        init_sprite
      end
      # Update the arrow animation
      def update
        @animation.update
      end
      private
      # Initialize the sprite
      def init_sprite
        set_position(*coordinates)
        set_bitmap(image_name, :interface)
        self.z = 4
        set_animation
      end
      # Return the coordinate of the sprite
      # @return [Array<Integer>]
      def coordinates
        return 3, 46
      end
      # Return the name of the sprite
      # @return [String]
      def image_name
        'quest/arrow'
      end
      # Set the looped animation of the arrow
      def set_animation
        anim = Yuki::Animation
        @animation = anim.timed_loop_animation(0.5)
        wait = anim.wait(0.5)
        movement = anim.move(0.25, self, x, y, x - 2, y)
        movement.play_before(anim.move(0.25, self, x - 2, y, x, y))
        wait.parallel_add(movement)
        @animation.play_before(wait)
        @animation.start
      end
    end
    # Quest Button UI element
    class QuestButton < SpriteStack
      attr_accessor :hidden
      # Return the quest linked to this button
      # @return PFM::Quests::Quest
      attr_reader :quest
      # Initialize the QuestButton component
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      # @param quest [PFM::Quests::Quest]
      # @param status [Symbol] if the quest is a primary, a secondary, or a finished quest
      def initialize(viewport, x, y, quest, status)
        super(viewport, x, y)
        @viewport = viewport
        @quest = quest
        @status = status
        @hidden = false
        create_frame
        create_title
        self.quest = quest
      end
      # Get the animation corresponding to the mode the button switches in
      # @param mode [Symbol]
      # @return [Yuki::Animation::ScalarAnimation]
      def change_mode(mode)
        return (mode == :deployed ? opening_animation : compacting_animation)
      end
      # Reload all sub-component with a new quest
      # @param quest [PFM::Quests::Quest]
      def quest=(quest)
        self.visible = !quest.nil?
        @hidden = quest.nil?
        return if quest.nil?
        @quest = quest
        @title.text = quest_data.name
      end
      private
      def create_frame
        @frame = add_sprite(0, 0, frame_filepath)
        @frame.set_rect(0, 0, @frame.width, 20)
        @frame_border = add_sprite(0, 17, 'quest/win_border')
      end
      def create_title
        @title = add_text(26, 5, 235, 13, '', color: 10)
      end
      # Get the animation for when the button is closing
      # @return [Yuki::Animation::ScalarAnimation]
      def compacting_animation
        anim = Yuki::Animation
        animation = anim.scalar(0.5, @frame.src_rect, :height=, 107, 20, distortion: :SMOOTH_DISTORTION)
        animation.parallel_add(anim.scalar(0.5, @frame_border, :y=, @frame_border.y, y + 17, distortion: :SMOOTH_DISTORTION))
        return animation
      end
      # Get the animation for when the button is opening
      # @return [Yuki::Animation::ScalarAnimation]
      def opening_animation
        anim = Yuki::Animation
        animation = anim.scalar(0.5, @frame.src_rect, :height=, 20, 107, distortion: :SMOOTH_DISTORTION)
        animation.parallel_add(anim.scalar(0.5, @frame_border, :y=, @frame_border.y, y + 104, distortion: :SMOOTH_DISTORTION))
        return animation
      end
      # Get the right filepath for the frame
      # @return [String]
      def frame_filepath
        return 'quest/win_active' if @status == :primary
        return 'quest/win_active' if @status == :secondary
        return 'quest/win_finished' if @status == :finished
        return 'quest/win_active'
      end
      # Return the data for the current quest stocked
      # @return [Studio::Quest]
      def quest_data
        return data_quest(@quest.quest_id)
      end
    end
    # Reward Screen composition
    class RewardScreen < SpriteStack
      # Coordinate of all the reward buttons
      REWARD_COORDINATE = [[3, 1], [137, 1], [3, 36], [137, 36]]
      # Initialize the RewardScreen component
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      def initialize(viewport, x, y)
        super(viewport, x, y)
        @quest = nil
        @index_display = 0
        create_prize_back
      end
      # Scroll the rewards if there's more than 4 rewards
      # @param direction [Symbol] :left of :right
      def scroll_rewards(direction)
        return if quest_data.earnings.size < 5
        @index_display += (direction == :left ? -1 : 1)
        @index_display = 0 if @index_display > quest_data.earnings.size / 4
        @index_display = quest_data.earnings.size / 4 if @index_display < 0
        regenerate_rewards(true)
      end
      # Reload all sub-component with a new quest
      # @param quest [PFM::Quests::Quest]
      def quest=(quest)
        @quest = quest
        @index_display = 0
        regenerate_rewards
      end
      private
      def create_prize_back
        @prize_back = add_sprite(0, 0, 'quest/prize_back')
      end
      def create_rewards
        coord = REWARD_COORDINATE
        @rewards = []
        4.times do |i|
          @rewards << push_sprite(RewardButton.new(viewport, x + coord[i][0], y + coord[i][1], quest_data.earnings[i + (@index_display * 4)]))
        end
      end
      # Regeneration procedure of the rewards
      # @param bool [Boolean] if RewardScreen should be visible afterward
      def regenerate_rewards(bool = false)
        @rewards.each(&:dispose) unless @rewards.nil?
        create_rewards
        self.visible = bool
      end
      # Return the data for the current quest stocked
      # @return [Studio::Quest]
      def quest_data
        return data_quest(@quest.quest_id)
      end
    end
    # Reward button UI element
    class RewardButton < SpriteStack
      # Create the RewardButton
      # @param viewport [Viewport]
      # @param x [Integer]
      # @param y [Integer]
      # @param reward [Studio::Quest::Earning, nil]
      def initialize(viewport, x, y, reward)
        super(viewport, x, y)
        @viewport = viewport
        @reward = reward
        create_frame
        if @reward
          determine_reward
          create_icon
          create_reward_name
          create_reward_quantity
        end
      end
      private
      def create_frame
        @frame = add_sprite(0, 0, 'quest/prize_button')
      end
      # Determine the reward and set the right text and icons
      def determine_reward
        hash = send(@reward.earning_method_name)
        @icon_type = hash[:type]
        @reward_id = hash[:id]
        @reward_name = hash[:name]
        @reward_quantity = hash[:quantity]
      end
      def create_icon
        if @icon_type == UI::PokemonIconSprite
          @icon = add_sprite(1, 1, NO_INITIAL_IMAGE, false, type: @icon_type)
          pokemon = PFM::Pokemon.new(@reward_id, 1)
          pokemon.egg_init if @reward.earning_method_name == :earning_egg
          @icon.data = pokemon
        else
          @icon = add_sprite(1, 1, NO_INITIAL_IMAGE, type: @icon_type)
          @icon.data = @reward_id
        end
      end
      def create_reward_name
        @reward_name = add_text(34, 17, 92, 10, @reward_name, color: 24)
      end
      def create_reward_quantity
        @reward_quantity = add_text(35, 3, 92, 10, "x#{@reward_quantity}", color: 10)
      end
      # Hash defining how the reward should be created if it's money
      # @return [Hash]
      def earning_money
        return {type: UI::ItemSprite, id: 223, name: 'Money', quantity: @reward.earning_args[0]}
      end
      # Hash defining how the reward should be created if it's an item
      # @return [Hash]
      def earning_item
        return {type: UI::ItemSprite, id: @reward.earning_args[0], name: data_item(@reward.earning_args[0]).name, quantity: @reward.earning_args[1]}
      end
      # Hash defining how the reward should be created if it's a Pokemon
      # @return [Hash]
      def earning_pokemon
        data = @reward.earning_args[0]
        pokemon_id = data.is_a?(Hash) ? data[:id] : data
        return {type: UI::PokemonIconSprite, id: pokemon_id, name: data_creature(pokemon_id).name, quantity: 1}
      end
      # Hash defining how the reward should be created if it's a egg
      # @return [Hash]
      def earning_egg
        data = @reward.earning_args[0]
        pokemon_id = data.is_a?(Hash) ? data[:id] : data
        return {type: UI::PokemonIconSprite, id: pokemon_id, name: text_file_get(0)[0], quantity: 1}
      end
    end
    # UI element displaying a quest category
    class CategoryDisplay < SpriteStack
      # All the category text getters
      TEXT_CATEGORY = {primary: [:ext_text, 9006, 5], secondary: [:ext_text, 9006, 6], finished: [:ext_text, 9006, 7]}
      # Initialize the QuestButton component
      # @param viewport [Viewport]
      # @param category [Symbol] the initial category the player spawns in (here for future compability)
      def initialize(viewport, category)
        super(viewport, *coordinates)
        @viewport = viewport
        @category = category
        create_frame
        create_category_text
        create_arrow_frames
      end
      # Update the category text depending on the new category
      # @param category [Symbol]
      def update_category_text(category)
        @category = category
        @text.text = send(*TEXT_CATEGORY[@category])
        update_arrows
      end
      private
      def create_frame
        @frame = add_sprite(0, 0, 'quest/win_cat')
      end
      def create_category_text
        @text = add_text(*text_coordinates, 88, 0, send(*TEXT_CATEGORY[@category]), 1, color: 10)
      end
      def create_arrow_frames
        @left_arrow = add_sprite(-10, 6, 'quest/arrow_frame_l')
        @right_arrow = add_sprite(@frame.width + 2, 6, 'quest/arrow_frame_r')
        update_arrows
      end
      def coordinates
        return 28, 4
      end
      def text_coordinates
        return 5, 13
      end
      # Update the states of the arrows according to current category
      def update_arrows
        case @category
        when :primary
          @left_arrow.visible = false
        when :secondary
          @left_arrow.visible = true
          @right_arrow.visible = true
        when :finished
          @right_arrow.visible = false
        end
      end
    end
    # Frame UI element for quests
    class QuestFrame < Sprite
      # Name of the file holding the quest frame
      FILENAME = 'quest/frame'
      # Initialize the graphism for the shop banner
      # @param viewport [Viewport] viewport in which the Sprite will be displayed
      def initialize(viewport)
        super(viewport)
        set_bitmap(FILENAME, :interface)
      end
    end
    # UI element listing the quests
    class QuestList < SpriteStack
      # Number of buttons generated
      NB_QUEST_BUTTON = 7
      # Offset between each button
      BUTTON_OFFSET = 28
      # Base X coordinate
      BASE_X = 19
      # Base Y coordinate
      BASE_Y = 41
      # @return [Integer] index of the current active item
      attr_reader :index
      # @return [Array<QuestButton>]
      attr_reader :buttons
      # @return [Symbol] the pace of the timing (:slow, :medium, :fast)
      attr_writer :timing
      # Create a new QuestList
      # @param viewport [Viewport] viewport in which the SpriteStack will be displayed
      # @param quest_hash [Hash] the hash containing the quests
      # @param category [Symbol] the current category the UI spawns in
      def initialize(viewport, quest_hash, category)
        super(viewport)
        @quest_hash = quest_hash
        @quest_array = quest_hash.map { |_key, value| value }
        @timing = :slow
        @category = category
        @index = 0
        create_quest_buttons
      end
      # Return the number of buttons registered in the stack
      # @return [Integer]
      def number_of_buttons
        return @quest_array.size
      end
      # Set the current active item index
      # @param index [Integer]
      def index=(index)
        @index = index.clamp(0, @quest_array.size - 1)
      end
      # Move all the buttons up
      def move_up
        @buttons.last.quest = @quest_array[index - 1]
        animation = move_up_animation
        @buttons.rotate!(-1)
        self.index = index - 1
        return animation
      end
      # Move all the buttons down
      def move_down
        @buttons.last.quest = @quest_array[index + (NB_QUEST_BUTTON - 1)]
        animation = move_down_animation
        @buttons.rotate!(1)
        self.index = index + 1
        return animation
      end
      # Tell if the current index is the same as the last quest for this category
      def last_index?
        return index == @quest_array.size - 1
      end
      # Change the right button mode and return the animation
      # @param mode [Symbol]
      # @return [Yuki::Animation::ScalarAnimation]
      def change_mode(mode)
        anim = Yuki::Animation
        animation = @buttons[0].change_mode(mode)
        coord = (mode == :compact ? -87 : 87)
        (1..5).each do |i|
          bt = @buttons[i]
          animation.parallel_add(anim.move_discreet(0.5, bt, bt.x, bt.y, bt.x, @buttons[i].y + coord, distortion: :SMOOTH_DISTORTION))
        end
        return animation
      end
      private
      def create_quest_buttons
        @buttons = []
        NB_QUEST_BUTTON.times do |i|
          push_sprite(button = QuestButton.new(viewport, BASE_X, BASE_Y + BUTTON_OFFSET * i, @quest_array[i], @category))
          button.visible = @quest_array[i] ? true : false
          @buttons << button
        end
      end
      # Hash that contains each timing for the scrolling
      # @return [Hash<Float>]
      TIMING = {slow: 0.25, medium: 0.15, fast: 0.05}
      # Return the right timing for animations
      # @return [Float]
      def timing
        return TIMING[@timing] || 0.25
      end
      # Move down animation (when the player press the UP KEY)
      # @return Yuki::Animation::TimedAnimation
      def move_down_animation
        anim = Yuki::Animation
        animation = anim.wait(0)
        @buttons.each_with_index do |button, i|
          if i == NB_QUEST_BUTTON - 1 && !button.hidden
            animation.parallel_add(anim.send_command_to(button, :visible=, true))
            animation.parallel_add(anim.opacity_change(timing, button, 0, 255, distortion: :SMOOTH_DISTORTION))
          else
            if i == 0
              animation.parallel_add(anim.opacity_change(timing, button, 255, 0, distortion: :SMOOTH_DISTORTION)).play_before(anim.send_command_to(button, :visible=, false))
            end
          end
          move = anim.move_discreet(timing, button, button.x, button.y, button.x, button.y - BUTTON_OFFSET, distortion: :SMOOTH_DISTORTION)
          move.play_before(anim.move_discreet(0, button, button.x, button.y, button.x, BASE_Y + BUTTON_OFFSET * (NB_QUEST_BUTTON - 1), distortion: :SMOOTH_DISTORTION)) if i == 0
          animation.parallel_add(move)
        end
        animation.start
        return animation
      end
      # Move up animation
      # @return Yuki::Animation::TimedAnimation
      def move_up_animation
        anim = Yuki::Animation
        animation = anim.wait(0)
        @buttons.each_with_index do |button, i|
          if i == NB_QUEST_BUTTON - 1
            animation.parallel_add(anim.send_command_to(button, :visible=, true))
            animation.parallel_add(anim.opacity_change(timing, button, 0, 255, distortion: :SMOOTH_DISTORTION))
            animation.parallel_add(anim.move_discreet(timing, button, button.x, BASE_Y - BUTTON_OFFSET, button.x, BASE_Y, distortion: :SMOOTH_DISTORTION))
          else
            if i == NB_QUEST_BUTTON - 2
              animation.parallel_add(anim.opacity_change(timing, button, 255, 0, distortion: :SMOOTH_DISTORTION)).play_before(anim.send_command_to(button, :visible=, false))
            end
            animation.parallel_add(anim.move_discreet(timing, button, button.x, button.y, button.x, button.y + BUTTON_OFFSET, distortion: :SMOOTH_DISTORTION))
          end
        end
        animation.start
        return animation
      end
      # Return the start index of the list
      # @return [Integer]
      def start_index
        @index - 1
      end
    end
    # UI element showing the object list
    class ObjectiveList < SpriteStack
      # Initialize the ObjectiveList component
      # @param viewport [Viewport]
      def initialize(viewport)
        super(viewport, *coordinates)
        @max_index = 0
        @index_text = 0
        create_text
        create_arrows
      end
      # Update the text depending on the forwarded data
      # @param data [Array<Array<String, Boolean>>]
      def update_text(data)
        @text.y = y
        @index_text = 0
        text = ''
        @max_index = data.size - 4
        @max_index = 0 if @max_index < 0
        data.each_with_index do |arr, i|
          color = arr[1] ? '\\c[13]' : '\\c[12]'
          text += arr[0]
          text += "\n" if i < data.size - 1
        end
        @text.multiline_text = text
        update_arrows
      end
      # Scroll the text in the right direction if there's more than 4 objectives
      # @param direction [Symbol] :UP or :DOWN
      def scroll_text(direction)
        return if @max_index <= 4
        return if @index_text == 0 && direction == :UP
        return if @index_text == @max_index && direction == :DOWN
        coord = direction == :UP ? 16 : -16
        @index_text += direction == :UP ? -1 : 1
        @text.y = @text.y + coord
        update_arrows
      end
      private
      def create_text
        @text = add_text(0, 0, 272, 16, '')
      end
      def create_arrows
        @arrow_up = push_sprite(Sprite.new(viewport))
        @arrow_up.set_bitmap('quest/arrow_choice', :interface)
        @arrow_up.angle = 90
        @arrow_up.set_origin(@arrow_up.width, 0)
        @arrow_up.set_position(257, 3)
        @arrow_up.visible = false
        @arrow_down = push_sprite(Sprite.new(viewport))
        @arrow_down.set_bitmap('quest/arrow_choice', :interface)
        @arrow_down.angle = -90
        @arrow_down.set_origin(0, @arrow_down.height)
        @arrow_down.set_position(257, 59)
        @arrow_down.visible = false
      end
      # Update the text arrows depending on the current position of the text
      def update_arrows
        return @arrow_up.opacity = @arrow_down.opacity = 0 if @max_index <= 3
        @arrow_up.opacity = @index_text == 0 ? 0 : 255
        @arrow_down.opacity = @index_text == @max_index ? 0 : 255
      end
      def coordinates
        return 0, 0
      end
    end
    # UI Composition of the quest scene
    class Composition < SpriteStack
      # Get the scrollbar element
      # @return [UI::Quest::ScrollBar]
      attr_accessor :scrollbar
      # Get the current state of the button
      # @return [Symbol]
      attr_accessor :button_state
      # Create the Composition of the scene
      # @param viewport [Viewport]
      # @param sub_viewport [Viewport]
      # @param sub_viewport2 [Viewport]
      # @param quests [PFM::Quests]
      def initialize(viewport, sub_viewport, sub_viewport2, quests)
        super(viewport)
        @viewport = viewport
        @sub_viewport = sub_viewport
        @sub_viewport2 = sub_viewport2
        @quests = quests
        @animation_handler = Yuki::Animation::Handler.new
        @category = :primary
        @state = :compact
        create_quest_list
        create_frame
        create_category_window
        create_scrollbar
        create_arrow
        create_quest_description
        create_quest_current_objective
        create_quest_rewards
        create_quest_objective_list
        update_max_index_scrollbar
        update_scrollbar
      end
      # Update all animations
      def update
        @arrow.update
        return if @animation_handler.empty?
        @animation_handler.update
      end
      # Tells if all animations are done
      # @return [Boolean]
      def done?
        return @animation_handler.done?
      end
      # Update the current category and launch the corresponding procedure
      # @param new_category [Symbol]
      def update_category(new_category)
        return if @category == new_category
        old_category = @category
        @category = new_category
        @category_display.update_category_text(@category)
        swap_lists(old_category)
        update_max_index_scrollbar
        update_scrollbar
        update_arrow
      end
      # Get the current QuestList index
      # @return [Integer]
      def index
        return current_list&.index || 0
      end
      # Input the direction of the scrolling
      # @param direction [Symbol]
      # @param timing [Symbol] the timing of the scrolling
      def input_direction(direction, timing = :slow)
        return if current_list.last_index? && direction == :DOWN
        return if current_list.index == 0 && direction == :UP
        move_list(direction, timing)
        update_scrollbar if @scrollbar.visible == true
      end
      # Change the mode of the first button
      # @param mode [Symbol]
      def change_mode_quest(mode)
        reload_deployed_components if mode == :deployed
        animation = current_list.change_mode(mode)
        anim = Yuki::Animation
        coord = mode == :deployed ? 87 : -87
        coord2 = mode == :deployed ? 63 : -63
        animation.parallel_add(anim.scalar(0.5, @sub_viewport.rect, :height=, @sub_viewport.rect.height, @sub_viewport.rect.height + coord, distortion: :SMOOTH_DISTORTION))
        objective_list_anim = anim.wait(0.12)
        objective_list_anim.play_before(anim.send_command_to(@sub_viewport2, :visible=, true)) if mode == :deployed
        objective_list_anim.play_before(anim.scalar(0.28, @sub_viewport2.rect, :height=, @sub_viewport2.rect.height, @sub_viewport2.rect.height + coord2, distortion: :SMOOTH_DISTORTION))
        objective_list_anim.play_before(anim.send_command_to(@sub_viewport2, :visible=, false)) if mode != :deployed
        animation.parallel_add(objective_list_anim)
        animation.start
        @animation_handler[:deploy] = animation if animation
      end
      # Change the state in the deployed mode
      # @param mode [Symbol]
      def change_deployed_mode(mode)
        @description.visible = (mode == :descr)
        @rewards.visible = (mode == :rewards)
        @objective_list.visible = (mode == :objectives)
      end
      # Swap through the rewards depending on the direction
      # @param direction [Symbol]
      def swap_rewards(direction)
        @rewards.scroll_rewards(direction)
      end
      # Scroll through the objective list depending on the direction
      # @param direction [Symbol]
      def scroll_objective_list(direction)
        @objective_list.scroll_text(direction)
      end
      # Get the current QuestList
      # @return [QuestList, nil]
      def current_list
        return @sym_to_list[@category]
      end
      private
      def create_frame
        @frame = QuestFrame.new(@viewport)
      end
      def create_arrow
        @arrow = push_sprite(UI::Quest::Arrow.new(viewport))
        @arrow.visible = current_list ? true : false
      end
      def create_category_window
        @category_display = CategoryDisplay.new(@viewport, @category)
      end
      def create_scrollbar
        @scrollbar = ScrollBar.new(@viewport)
      end
      def create_quest_list
        unless @quests.active_quests.empty?
          list = @quests.active_quests.select { |_k, v| data_quest(v.quest_id).is_primary }
          @quest_list_primary = QuestList.new(@viewport, list, :primary) unless list.keys.empty?
        end
        unless @quests.active_quests.empty?
          list = @quests.active_quests.reject { |_k, v| data_quest(v.quest_id).is_primary }
          unless list.keys.empty?
            @quest_list_secondary = QuestList.new(@viewport, list, :secondary)
            @quest_list_secondary.opacity = 0
          end
        end
        unless @quests.finished_quests.empty?
          @quest_list_finished = QuestList.new(@viewport, @quests.finished_quests, :finished)
          @quest_list_finished.opacity = 0
        end
        @sym_to_list = {primary: @quest_list_primary, secondary: @quest_list_secondary, finished: @quest_list_finished}
      end
      def create_quest_description
        @description = Text.new(0, @sub_viewport, 27, 62, 272, 16, '')
        update_quest_description unless current_list.nil?
        @sub_viewport.rect.height = 61
      end
      def update_quest_description
        @description.multiline_text = data_quest(current_list.buttons[0].quest.quest_id).description
      end
      def create_quest_current_objective
        @current_objective = Text.new(0, @sub_viewport, 27, 129, 272, 16, '', 0, nil, 10)
        update_quest_current_objective if current_list
      end
      def update_quest_current_objective
        data = current_list.buttons[0].quest.objective_text_list
        data = data.find { |objective| objective[1] == false }
        data = data ? data[0] : ''
        @current_objective.text = data
      end
      def create_quest_rewards
        @rewards = RewardScreen.new(@sub_viewport, 25, 63)
        update_quest_rewards unless current_list.nil?
        @rewards.visible = false
      end
      def update_quest_rewards
        @rewards.quest = current_list.buttons[0].quest
      end
      def create_quest_objective_list
        @objective_list = ObjectiveList.new(@sub_viewport2)
        update_quest_objective_list unless current_list.nil?
        @objective_list.visible = false
        @sub_viewport2.rect.height = 1
      end
      def update_quest_objective_list
        data = current_list.buttons[0].quest.objective_text_list
        @objective_list.update_text(data)
      end
      # Engage the swapping between old and new category
      # @param old_category [Symbol]
      def swap_lists(old_category)
        arr_categories = GamePlay::QuestUI::CATEGORIES
        direction_of_swap = (arr_categories.index(old_category) < arr_categories.index(@category) ? :left : :right)
        @animation_handler[:swap_lists] = swap_list_animation(old_category, direction_of_swap)
      end
      # The timing of the animations
      # @return [Float]
      TIMING = 0.5
      # Return the animation for the list swapping
      # @param old_category [Symbol]
      # @param direction [Symbol] the direction of the swapping
      # @return [Yuki::Animation::TimedAnimation]
      def swap_list_animation(old_category, direction)
        anim = Yuki::Animation
        animation = anim.wait(0.01)
        if (list = @sym_to_list[old_category])
          direction2 = direction == :left ? 320 : -320
          animation.play_before(anim.move_discreet(TIMING, list, 0, list.y, 0 - direction2, list.y, distortion: :SMOOTH_DISTORTION)).parallel_play(anim.opacity_change(TIMING, @sym_to_list[old_category], 255, 0, distortion: :SMOOTH_DISTORTION))
          animation.play_before(anim.wait(TIMING))
        end
        if (list = current_list)
          direction2 = direction == :left ? 320 : -320
          animation.play_before(anim.move_discreet(TIMING, current_list, 0 + direction2, list.y, 0, list.y, distortion: :SMOOTH_DISTORTION)).parallel_play(anim.opacity_change(TIMING, current_list, 0, 255, distortion: :SMOOTH_DISTORTION))
        end
        animation.start
        return animation
      end
      # Update the maximum index of the scrollbar
      def update_max_index_scrollbar
        nb_button = current_list&.number_of_buttons || 0
        @scrollbar.max_index = (nb_button == 0 ? nb_button : nb_button - 1)
      end
      # Update the scrollbar's current index
      def update_scrollbar
        if current_list
          @scrollbar.visible = current_list.number_of_buttons > 1
          @scrollbar.index = current_list&.index || 0
        else
          @scrollbar.visible = false
        end
      end
      # Update the visible attribute of arrow depending on if there's quest in a category or not
      def update_arrow
        @arrow.visible = !current_list.nil?
      end
      # Move the list in the given direction at the given timing
      # @param direction [Symbol]
      # @param timing [Symbol]
      def move_list(direction, timing)
        current_list.timing = timing
        animation = direction == :UP ? current_list&.move_up : current_list&.move_down
        @animation_handler[:move_list] = animation if animation
      end
      # Reload all components involved in the deployed mode
      def reload_deployed_components
        update_quest_description
        update_quest_current_objective
        update_quest_rewards
        update_quest_objective_list
      end
    end
  end
  # UI element shown on the screen to inform the player a quest was started, failed or finished
  class QuestInformer < SpriteStack
    # Name of the ME to play
    ME_TO_PLAY = 'audio/me/rosa_keyitemobtained'
    # Base Y of the informer
    BASE_Y = 34
    # Offset Y between each informer
    OFFSET_Y = 24
    # Offset X between the two textes
    OFFSET_TEXT_X = 4
    # Lenght of a transition
    TRANSITION_LENGHT = 30
    # Lenght of the text move
    TEXT_MOVE_LENGHT = 30
    # Time the player has to read the text
    TEXT_REMAIN_LENGHT = 90
    # Create a new quest informer UI
    # @param viewport [Viewport]
    # @param name [String] Name of the quest
    # @param is_new [Boolean] if the quest is new
    # @param index [Integer] index of the quest
    def initialize(viewport, name, is_new, index)
      super(viewport, 0, BASE_Y + index * OFFSET_Y)
      @background = add_background('quest/quest_bg')
      @background.opacity = 0
      text = ext_text(9000, is_new ? 147 : 148)
      @info_text = add_text(0, 3, 0, 16, text, 0, 0, color: is_new ? 13 : 12)
      @name_text = add_text(@info_text.real_width + OFFSET_TEXT_X, 3, 0, 16, name, 0, 0)
      @max_x = (viewport.rect.width - @name_text.real_width) / 2
      @info_ini_x = @info_text.x = -(@max_x * 2 + @name_text.x)
      @name_ini_x = @name_text.x = -(@max_x * 2)
      @counter = 0
      play_sound(index)
    end
    # Update the animation for the quest informer
    def update
      return if Graphics::FPSBalancer.global.skipping?
      if @counter < TRANSITION_LENGHT
        @background.opacity = (@counter + 1) * 255 / TRANSITION_LENGHT
      else
        if @counter < PHASE2
          base_x = (@counter - TRANSITION_LENGHT + 1) * @max_x * 3 / TEXT_MOVE_LENGHT
          @info_text.x = base_x + @info_ini_x
          @name_text.x = base_x + @name_ini_x
        else
          if @counter.between?(PHASE3, PHASE_END)
            @info_text.opacity = @name_text.opacity = @background.opacity = (PHASE_END - @counter) * 255 / TRANSITION_LENGHT
          end
        end
      end
      @counter += 1
    end
    # Tell if the animation is finished
    def done?
      (@background.disposed? || @background.opacity == 0) && @counter >= PHASE_END
    end
    private
    # Play the Quest got sound
    # @param index [Integer]
    def play_sound(index)
      Audio.me_play(ME_TO_PLAY) if index == 0
    end
  end
end
Graphics.on_start do
  UI::QuestInformer.class_eval do
    const_set :PHASE2, UI::QuestInformer::TRANSITION_LENGHT + UI::QuestInformer::TEXT_MOVE_LENGHT
    const_set :PHASE3, UI::QuestInformer::PHASE2 + UI::QuestInformer::TEXT_REMAIN_LENGHT
    const_set :PHASE_END, UI::QuestInformer::PHASE3 + UI::QuestInformer::TRANSITION_LENGHT
  end
end
module GamePlay
  class QuestUI < BaseCleanUpdate::FrameBalanced
    # List of the categories of the quests
    # @return [Array<Symbol>]
    CATEGORIES = %i[primary secondary finished]
    # Initialize the whole Quest UI
    # @param quests [PFM::Quests] the quests to send to the Quest UI
    def initialize(quests = PFM.game_state.quests)
      super()
      @category = :primary
      @quest_deployed = :compact
      @deployed_mode = :descr
      @last_key = nil
      @key_counter = 0
      @quests = quests
    end
    def update_graphics
      @base_ui.update_background_animation
      @composition.update
    end
    private
    def create_graphics
      super
      create_base_ui
      create_composition
      Graphics.sort_z
    end
    def create_viewport
      super
      @sub_viewport = Viewport.create(:main, 20_000)
      @sub_viewport2 = Viewport.create(27, 62, 272, 64, 21_000)
    end
    def create_base_ui
      @base_ui = UI::GenericBase.new(@viewport, button_texts)
    end
    def button_texts
      [ext_text(9006, 0), nil, nil, ext_text(9000, 115)]
    end
    # Return the text for the A button
    # @return [String]
    def a_button_text
      return @quest_deployed == :compact ? ext_text(9006, 0) : nil
    end
    # Return the text for the B button
    # @return [String]
    def b_button_text
      return @quest_deployed == :compact ? ext_text(9000, 115) : ext_text(9006, 4)
    end
    # Return the text for the X button
    # @return [String]
    def x_button_text
      hash = {descr: ext_text(9006, 2), rewards: ext_text(9006, 3), objectives: ext_text(9006, 1)}
      return hash[@deployed_mode]
    end
    def create_composition
      @composition = UI::Quest::Composition.new(@viewport, @sub_viewport, @sub_viewport2, @quests)
    end
    # Tell if the first button is currently deployed
    # @return [Boolean]
    def deployed?
      return @quest_deployed == :deployed
    end
    # Commute the variable telling if the first button is compacted or deployed
    def commute_quest_deployed
      @quest_deployed = (@quest_deployed == :compact ? :deployed : :compact)
    end
    public
    private
    # Update the text of the A button depending on if the quests are deployed or not
    def update_a_button_text
      @base_ui.ctrl[0].text = a_button_text
    end
    # Update the text of the B button depending on if the quests are deployed or not
    def update_b_button_text
      @base_ui.ctrl[3].text = b_button_text
    end
    # Update the text of the B button depending on if the quests are deployed or not
    def update_x_button_text
      @base_ui.ctrl[1].text = @quest_deployed == :deployed ? x_button_text : nil
    end
    # Change the category depending on the input
    # @param trigger [Symbol] :left or :right
    def change_category(trigger)
      arr = CATEGORIES
      current_category = arr.index(@category)
      current_category += trigger == :left ? -1 : 1
      current_category = current_category.clamp(0, arr.size - 1)
      @composition.update_category(@category = arr[current_category])
    end
    # Launch the quest switching mode procedure
    def switch_quest_mode
      return unless @composition.current_list
      commute_quest_deployed
      @composition.change_mode_quest(@quest_deployed)
      @composition.change_deployed_mode(@deployed_mode)
      update_a_button_text
      update_b_button_text
      update_x_button_text
    end
    public
    # List of method called by automatic_input_update when pressing on a key
    AIU_KEY2METHOD = {A: :action_a, X: :action_x, Y: :action_y, B: :action_b, LEFT: :action_left, RIGHT: :action_right}
    # Update the input of the scene
    def update_inputs
      return false unless @composition.done?
      return false unless automatic_input_update(AIU_KEY2METHOD)
      return false unless check_up_down_keys
    end
    private
    # Return the keys used to scroll
    # @return [Array<Symbol>]
    SCROLL_KEYS = %i[UP DOWN]
    # Check if the scroll keys are triggered or pressed depending on the context3
    # @return [Boolean] if update_inputs should continue
    def check_up_down_keys
      direction = timing = nil
      SCROLL_KEYS.each do |key|
        bool = deployed? ? Input.trigger?(key) : Input.press?(key)
        next unless bool
        direction = key
        @key_counter = @last_key == key ? @key_counter + 1 : 0
        @last_key = key
        if @key_counter >= 5
          timing = :fast
        else
          if @key_counter >= 2
            timing = :medium
          else
            timing = :slow
          end
        end
        action_scroll(direction, timing)
        return false
      end
      @last_key = nil
      return true
    end
    # Action related to A button
    def action_a
      return if deployed?
      switch_quest_mode
    end
    # Action related to B button
    def action_b
      return switch_quest_mode if deployed?
      play_cancel_se
      @running = false
    end
    # Action related to X button
    def action_x
      return unless deployed?
      case @deployed_mode
      when :descr
        @deployed_mode = :rewards
      when :rewards
        @deployed_mode = :objectives
      when :objectives
        @deployed_mode = :descr
      end
      update_x_button_text
      @composition.change_deployed_mode(@deployed_mode)
    end
    # Action related to Y button
    def action_y
    end
    # When the player press LEFT
    def action_left
      return @composition.swap_rewards(:left) if deployed? && @deployed_mode == :rewards
      return if deployed?
      change_category(:left)
    end
    # When the player press RIGHT
    def action_right
      return @composition.swap_rewards(:right) if deployed? && @deployed_mode == :rewards
      return if deployed?
      change_category(:right)
    end
    # Return the right scroll action depending on the context
    # @param direction [Symbol]
    # @param timing [Symbol]
    def action_scroll(direction, timing = :slow)
      return unless @composition.current_list
      return @composition.scroll_objective_list(direction) if deployed? && @deployed_mode == :objectives
      return if deployed?
      @composition.input_direction(direction, timing)
    end
    public
    # List of action the mouse can perform with ctrl button
    ACTIONS = %i[action_a action_x action_y action_b]
    # Update the mouse interactions
    # @param moved [Boolean] if the mouse moved durring the frame
    # @return [Boolean] if the thing after can update
    def update_mouse(moved)
      unless deployed?
        return update_mouse_index if Mouse.wheel != 0
        return false if moved
      end
      return update_ctrl_button_mouse
    end
    private
    # Part where we update the mouse ctrl button
    def update_ctrl_button_mouse
      update_mouse_ctrl_buttons(@base_ui.ctrl, ACTIONS)
      return false
    end
    # Part where we try to update the list index if the mouse wheel change
    def update_mouse_index
      delta = -Mouse.wheel
      update_mouse_delta_index(delta)
      Mouse.wheel = 0
      return false
    end
    # Update the list index according to a delta with mouse interaction
    # @param delta [Integer] number of index we want to add / remove
    def update_mouse_delta_index(delta)
      nb_button = @composition.current_list&.number_of_buttons || 0
      new_index = (@composition.index + delta).clamp(0, nb_button == 0 ? nb_button : nb_button - 1)
      delta = new_index - @composition.index
      return if delta == 0
      direction = delta < 0 ? :UP : :DOWN
      timing = delta.abs < 5 ? :medium : :fast
      action_scroll(direction, timing)
    end
  end
end
GamePlay.quest_ui_class = GamePlay::QuestUI
