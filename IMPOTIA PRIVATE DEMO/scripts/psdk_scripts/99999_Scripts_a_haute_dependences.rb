unless ARGV.include?('studio')
  module GameData
    class Base
    end
    class Item < Base
      class << self
        def [](id)
          data_item(id)
        end
      end
    end
    Text = Studio::Text
  end
end
module Scheduler
  add_proc(:on_warp_start, ::Scene_Map, 'Registering positions', 1000) do
    @storage[:was_outside] = $game_switches[Yuki::Sw::Env_CanFly]
    @storage[:old_player_x] = $game_player.x - Yuki::MapLinker.current_OffsetX
    @storage[:old_player_y] = $game_player.y - Yuki::MapLinker.current_OffsetY
    @storage[:old_player_id] = $game_map.map_id
    $env.reset_worldmap_position
    $game_player.reset_follower
  end
  add_proc(:on_warp_start, ::Scene_Map, 'Calculation of follower positions', 999) do
    @storage[:follower_arr] = arr = []
    add_x = $game_temp.player_new_x - $game_player.x
    add_y = $game_temp.player_new_y - $game_player.y
    Yuki::FollowMe.each_follower do |i|
      arr << (i.x + add_x)
      arr << (i.y + add_y)
      arr << i.direction
    end
  end
  add_proc(:on_warp_start, ::Scene_Map, 'Reset Battleback name', 999) do
    $game_temp.battleback_name = nil.to_s unless $game_switches[Yuki::Sw::DISABLE_BATTLEBACK_RESET]
  end
  add_proc(:on_warp_process, ::Scene_Map, 'Getting off the bike if required & reset Strength', 100) do
    if $env.get_current_zone_data.is_warp_disallowed
      if $game_switches[::Yuki::Sw::EV_Bicycle]
        $game_system.map_interpreter.launch_common_event(11)
        $game_system.map_interpreter.update
      else
        if $game_switches[::Yuki::Sw::EV_AccroBike]
          $game_system.map_interpreter.launch_common_event(33)
          $game_system.map_interpreter.update
        end
      end
    end
    $game_switches[::Yuki::Sw::EV_Strength] = false
  end
  add_proc(:on_warp_end, ::Scene_Map, 'Reposition followers + system update', 1000) do
    unless Game_Character::SurfTag.include? $game_player.system_tag
      $game_player.leave_surfing_state
    end
    if (@storage[:was_outside] && $game_switches[Yuki::Sw::Env_CanFly]) || $game_switches[Yuki::Sw::Env_FM_REP]
      $game_switches[Yuki::Sw::Env_FM_REP] = false
      Yuki::FollowMe.set_positions(*@storage[:follower_arr])
    else
      Yuki::FollowMe.reset_position unless $game_switches[Yuki::Sw::FM_NoReset]
      $game_switches[Yuki::Sw::FM_NoReset] = false
    end
    Yuki::FollowMe.update
    Yuki::Particles.update
    PFM::Wild_RoamingInfo.unlock
    $wild_battle.reset
    $wild_battle.reset_encounters_history
    $wild_battle.load_groups
  end
  add_proc(:on_warp_end, ::Scene_Map, 'Dig', 999) do
    if @storage[:was_outside] && $game_switches[Yuki::Sw::Env_CanDig]
      $game_variables[Yuki::Var::E_Dig_ID] = @storage[:old_player_id]
      $game_variables[Yuki::Var::E_Dig_X] = @storage[:old_player_x]
      $game_variables[Yuki::Var::E_Dig_Y] = @storage[:old_player_y]
    end
  end
  add_proc(:on_scene_switch, ::Scene_Title, 'TJN Correction for the first save', 1000) do
    next unless $scene.is_a?(Scene_Map)
    Yuki::TJN.init_variables
  end
  add_proc(:on_scene_switch, ::GamePlay::Load, 'TJN Correction if a save already exists', 1000) do
    next unless $scene.is_a?(Scene_Map)
    Yuki::TJN.init_variables
  end
  add_proc(:on_warp_start, ::Scene_Map, 'Trigger timed events', 1000) do
    Yuki::TJN.update_timed_events($game_temp.player_new_map_id)
  end
  add_proc(:on_hour_update, ::Scene_Map, 'Updating groups', 1000) do
    $wild_battle.reset
    $wild_battle.load_groups
  end
  add_proc(:on_hour_update, ::Scene_Map, 'Updating Shaymin\'s form', 1000) do
    selected = $actors.select { |pkmn| pkmn.db_symbol == :shaymin }
    selected.each { |pkmn| pkmn.form_calibrate(:none) if $env.sunset? || $env.night? }
  end
  add_proc(:on_scene_switch, GamePlay::Load, 'Correction of forms', 1000) do
    next unless $scene.is_a?(Scene_Map)
    log_info('Correcting the form of a Pokémon')
    block = proc { |pokemon| pokemon&.form_calibrate(:load) }
    $actors.each(&block)
    $storage.each_pokemon(&block)
    $wild_battle.each_roaming_pokemon(&block)
  end
  add_proc(:on_update, :any, 'KeyBinding addition', 0) do
    if $scene.class != GamePlay::KeyBinding
      if Input::Keyboard.press?(Input::Keyboard::F1) && !$game_temp&.message_window_showing
        Studio::Text.load unless $options
        GamePlay::KeyBinding.new.main
        Graphics.transition
      end
    end
  end
  add_proc(:on_scene_switch, GamePlay::Load, 'Fix quests', 1001) do
    next unless $scene.is_a?(Scene_Map)
    next if PFM.game_state.trainer.current_version > 6407
    log_info('Fixing quest data')
    PFM.game_state.quests.import_from_dot24
  end
  add_proc(:on_scene_switch, GamePlay::Load, 'Update quests saves', 1000) do
    next unless $scene.is_a?(Scene_Map)
    next if PFM.game_state.trainer.current_version > 6660
    log_info('Fixing quest data by replacing ID by db_symbol')
    PFM.game_state.quests.update_quest_data_for_studio
  end
  add_message(:on_dispose, Scene_Map, 'Dispose the particles', 1000, Yuki::Particles, :dispose)
  add_message(:on_dispose, Scene_Map, 'Dispose the FollowMe', 1000, Yuki::FollowMe, :dispose)
end
unless PARGV[:worldmap] || PARGV[:"animation-editor"] || PARGV[:test] || PARGV[:tags]
  Scheduler.add_proc(:on_update, :any, 'SoftReset', 10 ** 99) do
    if Input::Keyboard.press?(Input::Keyboard::F12) && $scene.class != Yuki::SoftReset
      $scene&.instance_variable_set(:@running, false)
      $scene = Yuki::SoftReset.new
      cc 0x03
      puts 'Soft resetting...'
      cc 0x07
      raise Reset, ''
    end
  end
  module Yuki
    # Class that manage the soft reset
    class SoftReset
      # Main process of the scene
      def main
        Scheduler.start(:on_transition)
        Audio.__reset__
        ObjectSpace.each_object(::Viewport) { |v| v.dispose unless v.disposed? }
        GC.start
        ObjectSpace.each_object(::Sprite) { |s| s.dispose unless s.disposed? }
        ObjectSpace.each_object(::Text) { |t| t.dispose unless t.disposed? }
        ObjectSpace.each_object(::Texture) { |b| b.dispose unless b.disposed? }
        Pathfinding.debug = false
        PFM.game_state = nil
        GC.start
        ts = 0.1
        sleep(ts) while Input::Keyboard.press?(Input::Keyboard::F12)
      end
      # Prevent any kind of update
      def update
        return
      end
      # Prevent the messages from being shown
      def display_message(*)
        return
      end
    end
  end
  # Error class used to signal a Reset request (F12)
  class Reset < StandardError
  end
end
