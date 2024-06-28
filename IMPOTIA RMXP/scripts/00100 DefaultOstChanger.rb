module Battle
    class Logic
      # Class describing the informations about the battle
      class BattleInfo
        # Information of the base wild battle bgm
        # @return [Array]
        remove_const :BASE_WILD_BATTLE_BGM
        BASE_WILD_BATTLE_BGM = ['audio/bgm/wild_battle', 100, 100]
      end
    end
  end