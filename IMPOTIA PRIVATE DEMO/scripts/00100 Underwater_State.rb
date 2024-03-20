class Game_Player
    STATE_APPEARANCE_SUFFIX[:underwater] = '_underwater'
    STATE_MOVEMENT_INFO[:underwater] = [4, 4] # Same as surf
    def enter_in_underwater_state
      @state = :underwater
      update_move_parameter(:underwater)
      update_appearance(@pattern)
    end
  end