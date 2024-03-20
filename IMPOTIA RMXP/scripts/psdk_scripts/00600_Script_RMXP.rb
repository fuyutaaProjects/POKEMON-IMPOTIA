# Class describing game switches (events)
class Game_Switches < Array
  # Default initialization of game switches
  def initialize
    if $data_system
      super($data_system.switches.size, false)
    else
      super(200, false)
    end
  end
  # Converting game switches to bits
  def _dump(_level = 0)
    gsize = (size / 8 + 1)
    str = "\x00" * gsize
    gsize.times do |i|
      index = i * 8
      number = self[index] ? 1 : 0
      number |= 2 if self[index + 1]
      number |= 4 if self[index + 2]
      number |= 8 if self[index + 3]
      number |= 16 if self[index + 4]
      number |= 32 if self[index + 5]
      number |= 64 if self[index + 6]
      number |= 128 if self[index + 7]
      str.setbyte(i, number)
    end
    return str
  end
  # Loading game switches from the save file
  def self._load(args)
    var = Game_Switches.new
    args.size.times do |i|
      index = i * 8
      number = args.getbyte(i)
      var[index] = (number[0] == 1)
      var[index + 1] = (number[1] == 1)
      var[index + 2] = (number[2] == 1)
      var[index + 3] = (number[3] == 1)
      var[index + 4] = (number[4] == 1)
      var[index + 5] = (number[5] == 1)
      var[index + 6] = (number[6] == 1)
      var[index + 7] = (number[7] == 1)
    end
    return var
  end
end
# Class that describe game variables
class Game_Variables < Array
  # default initialization of game variables
  def initialize
    if $data_system
      super($data_system.variables.size, 0)
    else
      super(200, 0)
    end
  end
  # Getter
  # @param index [Integer] the index of the variable
  # @note return 0 if the variable is outside of the array.
  def [](index)
    return 0 if size <= index
    super(index)
  end
  # Setter
  # @param index [Integer] the index of the variable in the Array
  # @param value [Integer] the new value of the variable
  def []=(index, value)
    unless value.is_a?(Integer)
      raise TypeError, "Unexpected #{value.class} value. $game_variables store numbers and nothing else, use $option to store anything else."
    end
    super(size, 0) while size < index
    super(index, value)
  end
end
# Describe switches that are related to a specific event
# @author Enterbrain
class Game_SelfSwitches
  # Default initialization
  def initialize
    @data = {}
  end
  # Get the state of a self switch
  # @param key [Array] the key that identify the self switch
  # @return [Boolean]
  def [](key)
    return @data[key]
  end
  # Set the state of a self switch
  # @param key [Array] the key that identify the self switch
  # @param value [Boolean] the new value of the self switch
  def []=(key, value)
    @data[key] = value
  end
end
# Collection of Game_Actor
class Game_Actors
  # Default initialization
  def initialize
    @data = []
  end
  # Fetch Game_Actor
  # @param actor_id [Integer] id of the Game_Actor in the database
  # @return [Game_Actor, nil]
  def [](actor_id)
    return nil if actor_id > 999 || $data_actors[actor_id].nil?
    @data[actor_id] ||= Game_Actor.new(actor_id)
    return @data[actor_id]
  end
end
# @deprecated No longer used...
class Game_BattleAction
end
# @deprecated No longer used in its original use.
class Game_Battler
  #--------------------------------------------------------------------------
  # ● 公開インスタンス変数
  #--------------------------------------------------------------------------
  attr_reader :battler_name
  # バトラー ファイル名
  attr_reader :battler_hue
  # バトラー 色相
  attr_reader :hp
  # HP
  attr_reader :sp
  # SP
  attr_reader :states
  # ステート
  attr_accessor :hidden
  # 隠れフラグ
  attr_accessor :damage
  # ダメージ値
  attr_accessor :critical
  # クリティカルフラグ
  attr_accessor :animation_id
  # アニメーション ID
  attr_accessor :animation_hit
  # アニメーション ヒットフラグ
  attr_accessor :white_flash
  # 白フラッシュフラグ
  attr_accessor :blink
  # 明滅フラグ
  #--------------------------------------------------------------------------
  # ● オブジェクト初期化
  #--------------------------------------------------------------------------
  def initialize
    @battler_name = nil.to_s
    @battler_hue = 0
    @hp = 0
    @sp = 0
    @states = []
    @states_turn = {}
    @hidden = false
    @damage = nil
    @critical = false
    @animation_id = 0
    @animation_hit = false
    @white_flash = false
    @blink = false
  end
  # Strength of the battler
  def str
    return 1
  end
  # Dexterity of the battler
  def dex
    return 1
  end
  # Agility of the battler
  def agi
    return 1
  end
  # Intelligence of the battler
  def int
    return 1
  end
  # Hit amount
  def hit
    return 0
  end
  # Attack of the battler
  def atk
    return 1
  end
  # Physical defense of the battler
  def pdef
    return 1
  end
  # Magical defense of the battler
  def mdef
    return 1
  end
  # Evasion of the battler
  def eva
    return 1
  end
  # Set th HP of the battler
  def hp=(hp)
    @hp = hp.clamp(0, 1)
  end
  # Set the SP of the battler
  def sp=(sp)
    @sp = sp.clamp(0, 1)
  end
  # Is the battler dead?
  def dead?
    return false
  end
  # Does the battler exists?
  def exist?
    return true
  end
end
# @deprecated Not used by the core.
class Game_Enemy < Game_Battler
  # Create a new Game_Enemy instance
  # @param troop_id [Integer] ID of the troop
  # @param member_index [Integer] index of the member in the troop
  def initialize(troop_id, member_index)
    super()
  end
  # ID of the enemy
  def id
    return 0
  end
  # Index of the enemy
  def index
    return 0
  end
  # Name of the enemy
  def name
    return nil.to_s
  end
  # Actions of the enemy
  def actions
    return []
  end
  # Experience points of the enemy
  def exp
    return 1
  end
  # Money of the enemy
  def gold
    return 1
  end
  # Item of the enemy
  def item_id
    return 0
  end
  # Screen X position of the enemy
  def screen_x
    return 0
  end
  # Screen Y position of the enemy
  def screen_y
    return 0
  end
  # Screen Z position of the enemy
  def screen_z
    return 0
  end
end
# Class that describe a troop of enemies
class Game_Troop
  # Default initializer.
  def initialize
    @enemies = []
  end
  # Returns the list of enemies
  # @return [Array<Game_Enemy>]
  def enemies
    return @enemies
  end
  # Setup the troop with a troop from the database
  # @param troop_id [Integer] the id of the troop in the database
  def setup(troop_id)
    @enemies = []
  end
end
# Describe a player
class Game_Actor < Game_Battler
  attr_reader :name
  attr_reader :character_name
  attr_reader :character_hue
  attr_reader :battler_name
  attr_reader :level
  attr_reader :exp
  attr_reader :skills
  # Initialize a new Game_Actor
  # @param actor_id [Integer] the id of the actor in the database
  def initialize(actor_id)
    super()
    setup(actor_id)
  end
  # setup the Game_Actor object
  # @param actor_id [Integer] the id of the actor in the database
  def setup(actor_id)
    actor = $data_actors[actor_id]
    @actor_id = actor_id
    @name = actor.name
    @character_name = actor.character_name
    @character_hue = actor.character_hue
    @battler_name = actor.battler_name
    @battler_hue = actor.battler_hue
  end
  # id of the Game_Actor in the database
  # @return [Integer]
  def id
    return @actor_id
  end
  # index of the Game_Actor in the $game_party.
  # @return [Integer, nil]
  def index
    return $game_party.actors.index(self)
  end
  # @deprecated will be removed.
  def exp=(exp)
  end
  # @deprecated will be removed.
  def level=(level)
  end
  # sets the name of the Game_Actor
  # @param name [String] the name
  def name=(name)
    @name = name
  end
  # Update the graphics of the Game_Actor
  # @param character_name [String] name of the character in Graphics/Characters
  # @param character_hue [0] ignored by the cache
  # @param battler_name [String] name of the battler in Graphics/Battlers
  # @param battler_hue [0] ignored by the cache
  def set_graphic(character_name, character_hue, battler_name, battler_hue)
    @character_name = character_name
    @character_hue = character_hue
    @battler_name = battler_name
    @battler_hue = battler_hue
  end
  # @deprecated will be removed.
  def screen_x
    return 0
  end
  # @deprecated will be removed.
  def screen_y
    return 464
  end
  # @deprecated will be removed.
  def screen_z
    return 0
  end
end
# Describe a common event during the game processing
class Game_CommonEvent
  # @return [Integer] ID of the wild battle start common event
  WILD_BATTLE = 1
  # @return [Integer] ID of the appearence common event
  APPEARANCE = 2
  # @return [Integer] ID of the follower speech common event
  FOLLOWER_SPEECH = 5
  # @return [Integer] ID of the falling from hole common event
  HOLE_FALLING = 8
  # @return [Integer] ID of the enter surf common event
  SURF_ENTER = 9
  # @return [Integer] ID of the leaving surf common event
  SURF_LEAVE = 10
  # @return [Integer] ID of the headbutt common event
  HEADBUTT = 20
  # @return [Integer] ID of the waterfall common event
  WATERFALL = 26
  # @return [Integer] ID of the dive common event
  DIVE = 29
  # Initialize the Game_CommonEvent
  # @param common_event_id [Integer] id of the common event in the database
  def initialize(common_event_id)
    @common_event_id = common_event_id
    @interpreter = nil
    refresh
  end
  # Name of the common event
  def name
    return $data_common_events[@common_event_id].name
  end
  # trigger condition of the common event
  def trigger
    return $data_common_events[@common_event_id].trigger
  end
  # id of the switch that triggers the common event
  def switch_id
    return $data_common_events[@common_event_id].switch_id
  end
  # List of commands of the common event
  def list
    return $data_common_events[@common_event_id].list
  end
  # Refresh the common event. If it triggers automatically, an internal Interpreter is generated
  def refresh
    if self.trigger == 2 && $game_switches[self.switch_id] == true
      if @interpreter == nil
        @interpreter = Interpreter.new
      end
    else
      @interpreter = nil
    end
  end
  # Update the common event, if there's an internal Interpreter, it's being updated
  def update
    if @interpreter != nil
      unless @interpreter.running?
        @interpreter.setup(self.list, 0)
      end
      @interpreter.update
    end
  end
end
# The RPG Maker description of a Party
class Game_Party
  attr_reader :actors
  attr_accessor :gold
  attr_accessor :steps
  # Default initialization
  def initialize
    @actors = []
    @gold = 0
    @steps = 0
    @items = {}
    @weapons = {}
    @armors = {}
  end
  # Set up the party with default members
  def setup_starting_members
    @actors = []
    log_info("Initial party members : #{$data_system.party_members}")
    for i in $data_system.party_members
      @actors.push($game_actors[i])
    end
  end
  # Refresh the game party with right actors according to the RMXP data
  def refresh
    new_actors = []
    for i in 0...@actors.size
      if $data_actors[@actors[i].id] != nil
        new_actors.push($game_actors[@actors[i].id])
      end
    end
    @actors = new_actors
  end
  # Returns the max level in the team
  # @return [Integer] 0 if no actors
  def max_level
    return 1
  end
  # Add an actor to the party
  # @param actor_id [Integer] the id of the actor in the database
  def add_actor(actor_id)
    actor = $game_actors[actor_id]
    if @actors.size < 4 && !@actors.include?(actor)
      @actors.push(actor)
      $game_player.refresh
    end
  end
  # Remove an actor of the party
  # @param actor_id [Integer] the id of the actor in the database
  def remove_actor(actor_id)
    @actors.delete($game_actors[actor_id])
    $game_player.refresh
  end
  # gives gold to the party
  # @param n [Integer] amount of gold
  def gain_gold(n)
    @gold = [[@gold + n, 0].max, 9999999].min
  end
  # takes gold from the party
  # @param n [Integer] amount of gold
  def lose_gold(n)
    gain_gold(-n)
  end
  # Increase steps of the party
  def increase_steps
    @steps = [@steps + 1, 9999999].min
  end
end
# Class that manage Music playing, save and menu access, timer and interpreter
class Game_System
  attr_reader :map_interpreter
  # マップイベント用インタプリタ
  attr_reader :battle_interpreter
  # バトルイベント用インタプリタ
  attr_accessor :timer
  # タイマー
  attr_accessor :timer_working
  # タイマー作動中フラグ
  attr_accessor :save_disabled
  # セーブ禁止
  attr_accessor :menu_disabled
  # メニュー禁止
  attr_accessor :encounter_disabled
  # エンカウント禁止
  attr_accessor :message_position
  # 文章オプション 表示位置
  attr_accessor :message_frame
  # 文章オプション ウィンドウ枠
  attr_accessor :save_count
  # セーブ回数
  attr_accessor :magic_number
  # マジックナンバー
  # Default initializer
  def initialize
    @map_interpreter = Interpreter.new(0, true)
    @battle_interpreter = Interpreter.new(0, false)
    @timer = 0
    @timer_working = false
    @save_disabled = false
    @menu_disabled = false
    @encounter_disabled = false
    @message_position = 2
    @message_frame = 0
    @save_count = 0
    @magic_number = 0
  end
  # play the cry of a Pokémon
  # @param id [Integer] the id of the Pokémon in the database
  def cry_play(id)
    Audio.cry_play(sprintf('Audio/SE/Cries/%03dCry', id.to_i))
  end
  # Plays a BGM
  # @param bgm [RPG::AudioFile] a descriptor of the BGM
  def bgm_play(bgm)
    @playing_bgm = bgm
    if bgm && !bgm.name.empty?
      Audio.bgm_play(_utf8('Audio/BGM/' + bgm.name), bgm.volume, bgm.pitch)
    else
      Audio.bgm_stop
    end
    Graphics.frame_reset
  end
  # Stop the BGM
  def bgm_stop
    Audio.bgm_stop
  end
  # Fade the BGM out
  # @param time [Integer] the time in seconds it takes to the BGM to fade
  def bgm_fade(time)
    @playing_bgm = nil
    Audio.bgm_fade(time * 1000)
  end
  # Memorize the BGM
  def bgm_memorize
    @memorized_bgm = @playing_bgm
  end
  # Plays the Memorized BGM
  def bgm_restore
    bgm_play(@memorized_bgm)
  end
  # Memorize an other BGM with position
  # @author Nuri Yuri
  def bgm_memorize2
    @bgm_position = Audio.bgm_position
    @memorized_bgm2 = @playing_bgm
  end
  # Plays the other Memorized BGM at the right position (FmodEx Eclusive)
  # @author Nuri Yuri
  def bgm_restore2
    bgm_play(@memorized_bgm2)
    if @bgm_position
      Audio.bgm_position = @bgm_position
    end
  end
  # Plays a BGS
  # @param bgs [RPG::AudioFile] a descriptor of the BGS
  def bgs_play(bgs)
    @playing_bgs = bgs
    if bgs && !bgs.name.empty?
      Audio.bgs_play(_utf8('Audio/BGS/' + bgs.name), bgs.volume, bgs.pitch)
    else
      Audio.bgs_stop
    end
    Graphics.frame_reset
  end
  # Fade the BGS out
  # @param time [Integer] the time in seconds it takes to the BGS to fade
  def bgs_fade(time)
    @playing_bgs = nil
    Audio.bgs_fade(time * 1000)
  end
  # Memorize the BGS
  def bgs_memorize
    @memorized_bgs = @playing_bgs
  end
  # Play the memorized BGS
  def bgs_restore
    bgs_play(@memorized_bgs)
  end
  # Plays a ME
  # @param me [RPG::AudioFile] a descriptor of the ME
  def me_play(me)
    if me && !me.name.empty?
      Audio.me_play(_utf8('Audio/ME/' + me.name), me.volume, me.pitch)
    else
      Audio.me_stop
    end
    Graphics.frame_reset
  end
  # Plays a SE
  # @param se [RPG::AudioFile] a descriptor of the SE
  def se_play(se)
    if se && !se.name.empty?
      Audio.se_play(_utf8('Audio/SE/' + se.name), se.volume, se.pitch)
    end
  end
  # Stops every SE
  def se_stop
    Audio.se_stop
  end
  # Returns the playing BGM descriptor
  # @return [RPG::AudioFile]
  def playing_bgm
    return @playing_bgm
  end
  # Returns the playing BGS descriptor
  # @return [RPG::AudioFile]
  def playing_bgs
    return @playing_bgs
  end
  # Returns the name of the window skin
  # @return [String] The name of the window skin
  def windowskin_name
    return @windowskin_name || 'message'
  end
  # Sets the name of the window skin
  # @param windowskin_name [String] The name of the window skin
  def windowskin_name=(windowskin_name)
    @windowskin_name = windowskin_name
  end
  # Returns the battle BGM descriptor
  # @return [RPG::AudioFile]
  def battle_bgm
    if @battle_bgm == nil
      return $data_system.battle_bgm
    else
      return @battle_bgm
    end
  end
  # Sets the battle BGM descriptor
  # @param battle_bgm [RPG::AudioFile] descriptor
  def battle_bgm=(battle_bgm)
    @battle_bgm = battle_bgm
  end
  # Returns the battle end ME descriptor
  # @return [RPG::AudioFile]
  def battle_end_me
    if @battle_end_me == nil
      return $data_system.battle_end_me
    else
      return @battle_end_me
    end
  end
  # Sets the battle end ME descriptor
  # @param battle_end_me [RPG::AudioFile] descriptor
  def battle_end_me=(battle_end_me)
    @battle_end_me = battle_end_me
  end
  # Updates the Game System (timer)
  def update
    if @timer_working && @timer > 0
      @timer -= 1
    end
  end
end
# Class that stores a lot of Game State
class Game_Temp
  attr_accessor :map_bgm
  # マップ画面 BGM (バトル時記憶用)
  attr_accessor :message_text
  # メッセージ 文章
  attr_accessor :message_proc
  # メッセージ コールバック (Proc)
  attr_accessor :choices
  # Tableau contenant les choix
  attr_accessor :choice_start
  # 選択肢 開始行
  attr_accessor :choice_max
  # 選択肢 項目数
  attr_accessor :choice_cancel_type
  # 選択肢 キャンセルの場合
  attr_accessor :choice_proc
  # 選択肢 コールバック (Proc)
  attr_accessor :num_input_start
  # 数値入力 開始行
  attr_accessor :num_input_variable_id
  # 数値入力 変数 ID
  attr_accessor :num_input_digits_max
  # 数値入力 桁数
  attr_accessor :message_window_showing
  # メッセージウィンドウ表示中
  attr_accessor :common_event_id
  # コモンイベント ID
  attr_accessor :in_battle
  # 戦闘中フラグ
  attr_accessor :battle_calling
  # バトル 呼び出しフラグ
  attr_accessor :battle_troop_id
  # バトル トループ ID
  attr_accessor :battle_can_escape
  # バトル 逃走可能フラグ
  attr_accessor :battle_can_lose
  # バトル 敗北可能フラグ
  attr_accessor :battle_proc
  # バトル コールバック (Proc)
  # Current turn of the battle
  # - each time AI is about to get triggered, this counter increase by 1 (after player choice)
  # - starts at 0 before 1st AI trigger (meaning that launching all Pokemon phase is 0)
  # @return [Integer]
  attr_accessor :battle_turn
  attr_accessor :battle_event_flags
  # バトル イベント実行済みフラグ
  attr_accessor :battle_abort
  # バトル 中断フラグ
  attr_accessor :battle_main_phase
  # バトル メインフェーズフラグ
  attr_accessor :battleback_name
  # バトルバック ファイル名
  attr_accessor :forcing_battler
  # アクション強制対象のバトラー
  attr_accessor :shop_calling
  # ショップ 呼び出しフラグ
  attr_accessor :shop_goods
  # ショップ 商品リスト
  attr_accessor :name_calling
  # 名前入力 呼び出しフラグ
  attr_accessor :name_actor_id
  # 名前入力 アクター ID
  attr_accessor :name_max_char
  # 名前入力 最大文字数
  attr_accessor :menu_calling
  # メニュー 呼び出しフラグ
  attr_accessor :menu_beep
  # メニュー SE 演奏フラグ
  attr_accessor :save_calling
  # セーブ 呼び出しフラグ
  attr_accessor :debug_calling
  # デバッグ 呼び出しフラグ
  attr_accessor :player_transferring
  # プレイヤー場所移動フラグ
  attr_accessor :player_new_map_id
  # プレイヤー移動先 マップ ID
  attr_accessor :player_new_x
  # プレイヤー移動先 X 座標
  attr_accessor :player_new_y
  # プレイヤー移動先 Y 座標
  attr_accessor :player_new_direction
  # プレイヤー移動先 向き
  attr_accessor :transition_processing
  # トランジション処理中フラグ
  attr_accessor :transition_name
  # トランジション ファイル名
  attr_accessor :gameover
  # ゲームオーバーフラグ
  attr_accessor :to_title
  # タイトル画面に戻すフラグ
  attr_accessor :last_file_index
  # 最後にセーブしたファイルの番号
  attr_accessor :debug_top_row
  # デバッグ画面 状態保存用
  attr_accessor :debug_index
  # デバッグ画面 状態保存用
  attr_accessor :last_menu_index
  #Dernière position dans le menu
  attr_accessor :god_mode
  attr_accessor :vs_type
  attr_accessor :vs_actors
  attr_accessor :vs_enemies
  attr_accessor :enemy_battler
  attr_accessor :trainer_battle
  attr_accessor :temp_team
  # Tableau contenant une équipe temporaire
  # Name of the tileset to load instead of the normal one
  # @return [String]
  attr_accessor :tileset_name
  # Variable used to store the tileset name
  attr_accessor :tileset_temp
  # ID of the currently processed map by the maplinker (to fetch the tileset)
  # @return [String]
  attr_accessor :maplinker_map_id
  # Store the id of last repel used
  attr_accessor :last_repel_used_id
  # Initialize with default game state
  def initialize
    @map_bgm = nil
    @message_text = nil
    @message_proc = nil
    @choice_start = 99
    @choice_max = 0
    @choice_cancel_type = 0
    @choice_proc = nil
    @num_input_start = -99
    @num_input_variable_id = 0
    @num_input_digits_max = 0
    @message_window_showing = false
    @common_event_id = 0
    @in_battle = false
    @battle_calling = false
    @battle_troop_id = 0
    @battle_can_escape = false
    @battle_can_lose = false
    @battle_proc = nil
    @battle_turn = 0
    @battle_event_flags = {}
    @battle_abort = false
    @battle_main_phase = false
    @battleback_name = nil.to_s
    @forcing_battler = nil
    @shop_calling = false
    @shop_id = 0
    @name_calling = false
    @name_actor_id = 0
    @name_max_char = 0
    @menu_calling = false
    @menu_beep = false
    @save_calling = false
    @debug_calling = false
    @player_transferring = false
    @player_new_map_id = 0
    @player_new_x = 0
    @player_new_y = 0
    @player_new_direction = 0
    @transition_processing = false
    @transition_name = nil.to_s
    @gameover = false
    @to_title = false
    @last_file_index = 0
    @debug_top_row = 0
    @debug_index = 0
    @god_mode = false
    @vs_actors = 1
    @vs_enemies = 1
    @vs_type = 1
    @enemy_battler = []
    @trainer_battle = false
    @last_menu_index = 0
    @temp_team = []
    @last_repel_used_id = 0
  end
end
# Interpreter of the event commands
class Interpreter_RMXP
  # Id of the event that started the Interpreter
  # @return [Integer]
  attr_reader :event_id
  # Initialize the Interpreter
  # @param depth [Integer] depth of the Interpreter
  # @param main [Boolean] if the interpreter is the main interpreter
  def initialize(depth = 0, main = false)
    @depth = depth
    @main = main
    if depth > 100
      print('The common event call exceeded the upper boundary.')
      exit
    end
    clear
  end
  # Clear the state of the interpreter
  def clear
    @map_id = 0
    @event_id = 0
    @message_waiting = false
    @move_route_waiting = false
    @move_route_waiting_id = nil
    @button_input_variable_id = 0
    @wait_count = 0
    @child_interpreter = nil
    @branch = {}
  end
  # Launch a common event in a child interpreter
  # @param id [Integer] id of the common event
  def launch_common_event(id)
    common_event = $data_common_events[id]
    if common_event
      @child_interpreter = Interpreter.new(@depth + 1)
      @child_interpreter.setup(common_event.list, @event_id)
    end
  end
  # Setup the interpreter with a list of Commands
  # @param list [Array<RPG::Command>] list of commands
  # @param event_id [Integer] id of the event that launch the interpreter
  # @param block [Proc] the ruby commands to execute using a fiber (list is ignored if this variable is set)
  def setup(list, event_id, block = nil)
    clear
    @map_id = $game_map.map_id
    @event_id = event_id
    @list = block ? :fiber : list
    @index = 0
    @branch.clear
    create_fiber(block) if block
  end
  # Tells if the interpreter is running or not
  # @return [Boolean]
  def running?
    return !@list.nil?
  end
  # Setup the interpreter with an event (Game_Event / Game_CommonEvent) that can run
  def setup_starting_event
    $game_map.refresh if $game_map.need_refresh
    if $game_temp.common_event_id > 0
      setup($data_common_events[$game_temp.common_event_id].list, 0)
      $game_temp.common_event_id = 0
      return
    end
    $game_map.events.each_value do |event|
      next unless event.starting
      if event.trigger < 3
        event.clear_starting
        event.lock
      end
      return setup(event.list, event.id)
    end
    $data_common_events.each do |common_event|
      next unless common_event&.trigger == 1 && $game_switches[common_event.switch_id]
      return setup(common_event.list, 0)
    end
  end
  # Update the interpreter
  def update
    @loop_count = 0
    loop do
      update_loop_count
      @event_id = 0 if $game_map.map_id != @map_id
      unless @child_interpreter.nil?
        @child_interpreter.update
        @child_interpreter = nil unless @child_interpreter.running?
        break unless @child_interpreter.nil?
      end
      break if @message_waiting
      break if waiting_event?
      break(input_button) if @button_input_variable_id > 0
      break(@wait_count -= 1) if @wait_count > 0
      break unless $game_temp.forcing_battler.nil?
      break if calling_scene?
      if @list.nil?
        setup_starting_event if @main
        break if @list.nil?
      end
      break if execute_command == false
      @index += 1
    end
  end
  # Constant that holds the LiteRGSS input key to RGSS input Key
  LiteRGSS2RGSS_Input = {A: 13, B: 12, X: 14, Y: 15, L: 17, R: 18, UP: 8, DOWN: 2, LEFT: 4, RIGHT: 6, L2: 16, R2: 25, L3: 23, R3: 29, START: 22, SELECT: 21}
  # Constant that holds the RGSS input key to LiteRGSS input key
  RGSS2LiteRGSS_Input = LiteRGSS2RGSS_Input.invert
  RGSS2LiteRGSS_Input[11] = :A
  RGSS2LiteRGSS_Input.default = :HOME
  # Check if a button is triggered and store its id in a variable
  def input_button
    n = 0
    LiteRGSS2RGSS_Input.each do |key, i|
      n = i if Input.trigger?(key)
    end
    if n > 0
      $game_variables[@button_input_variable_id] = n
      $game_map.need_refresh = true
      @button_input_variable_id = 0
    end
  end
  # Setup choices in order to start a choice process
  def setup_choices(parameters)
    $game_temp.choice_max = parameters[0].size
    $game_temp.choices = parameters[0].clone.each { |s| s.force_encoding(Encoding::UTF_8) }
    $game_temp.choice_cancel_type = parameters[1]
    current_indent = @list[@index].indent
    $game_temp.choice_proc = proc { |n| @branch[current_indent] = n }
  end
  # Execute a block on a specific actor (parameter > 0) or every actors in the Party
  # @param parameter [Integer] whole party or id of an actor in the database
  def iterate_actor(parameter)
    if parameter == 0
      $game_party.actors.each { |actor| yield(actor) }
    else
      actor = $game_actors[parameter]
      yield(actor) if actor
    end
  end
  # Execute a block on a specific enemy (parameter >= 0) or every enemies in the troop
  # @param parameter [Integer] whole troop or index of an enemy in the troop
  def iterate_enemy(parameter)
    if parameter == -1
      $game_troop.enemies.each { |enemy| yield(enemy) }
    else
      enemy = $game_troop.enemies[parameter]
      yield(enemy) if enemy
    end
  end
  # Execute a block on a every enemies (parameter1 == 0) or every actors (parameter2 == -1) or a specific actor in the party
  # @param parameter1 [Integer] if 0, execute a block on every enemies
  # @param parameter2 [Integer] whole party or index of an actor in the party
  def iterate_battler(parameter1, parameter2)
    if parameter1 == 0
      iterate_enemy(parameter2) { |enemy| yield(enemy) }
    else
      if parameter2 == -1
        $game_party.actors.each { |actor| yield(actor) }
      else
        actor = $game_party.actors[parameter2]
        yield(actor) if actor
      end
    end
  end
  private
  # Test a scene is being called
  # @return [Boolean]
  def calling_scene?
    $game_temp.battle_calling || $game_temp.shop_calling || $game_temp.name_calling || $game_temp.menu_calling || $game_temp.save_calling || $game_temp.gameover
  end
  # Test if the Interpreter is currently waiting for an event
  # @return [Boolean]
  # @note This function automatically update the states it use if it returns false
  def waiting_event?
    return false unless @move_route_waiting
    if @move_route_waiting_id
      return true if @move_route_waiting_id == 0 && $game_player.move_route_forcing
      wanted_event = $game_map.events[@move_route_waiting_id]
      return true if wanted_event&.move_route_forcing || wanted_event&.path
      @move_route_waiting = false
      @move_route_waiting_id = nil
      return false
    end
    return true if $game_player.move_route_forcing
    return true if $game_map.events.any? { |_, event| event.move_route_forcing }
    @move_route_waiting = false
    return false
  end
  # Prevent the event from freezing the game if they process more than 100 commands
  def update_loop_count
    @loop_count += 1
    if @loop_count > 100
      log_debug("Event #{@event_id} executed 100 commands without giving the control back")
      Graphics.update
      @loop_count = 0
    end
  end
  # Create the Interpreter Fiber
  # @param block [Proc] the ruby commands to execute using a fiber 
  def create_fiber(block)
    raise 'Another fiber is running!' if @fiber
    @fiber = Fiber.new do
            instance_exec(&block)
    ensure
      @fiber = @list = nil

    end
  end
  public
  # Execute a command of the current event
  def execute_command
    return @fiber.resume if @fiber
    if @index >= @list.size - 1
      command_end
      return true
    end
    @parameters = @list[@index].parameters
    method_name = COMMAND_TRANSLATION[@list[@index].code]
    return true unless method_name
    return send(method_name)
  end
  # Command that end the interpretation of the current event
  def command_end
    @list = nil
    if @main && @event_id > 0
      $game_map.events[@event_id].unlock
    end
  end
  # Command that skip the next commands until it find a command with the same indent
  def command_skip
    indent = @list[@index].indent
    loop do
      if @list[@index + 1].indent == indent
        return true
      end
      @index += 1
    end
  end
  # Command that retrieve a Game_Character object
  # @param parameter [Integer, Symbol] > 0 : id of the event, 0 : current event, -1 : player or follower, Symbol : alias
  # @return [Game_Event, Game_Player, Game_Character]
  def get_character(parameter)
    parameter = $game_map.events_sym_to_id[parameter] if parameter.is_a?(Symbol)
    case parameter
    when -1
      if $game_variables[Yuki::Var::FM_Sel_Foll] > 0
        return Yuki::FollowMe.get_follower($game_variables[Yuki::Var::FM_Sel_Foll] - 1)
      end
      return $game_player
    when 0
      events = $game_map.events
      return events == nil ? nil : events[@event_id]
    else
      events = $game_map.events
      return events == nil ? nil : events[parameter]
    end
  end
  # Command that retrieve a value and negate it if wanted
  # @param operation [Integer] if 1 negate the value
  # @param operand_type [Integer] if 0 takes operand, otherwise take the game variable n°operand
  # @param operand [Integer] the value or index
  def operate_value(operation, operand_type, operand)
    if operand_type == 0
      value = operand
    else
      value = $game_variables[operand]
    end
    if operation == 1
      value = -value
    end
    return value
  end
  # Hash containing the command translation from code to method name
  COMMAND_TRANSLATION = {101 => :command_101, 102 => :command_102, 402 => :command_402, 403 => :command_403, 103 => :command_103, 104 => :command_104, 105 => :command_105, 106 => :command_106, 111 => :command_111, 411 => :command_411, 112 => :command_112, 413 => :command_413, 113 => :command_113, 115 => :command_115, 116 => :command_116, 117 => :command_117, 118 => :command_118, 119 => :command_119, 121 => :command_121, 122 => :command_122, 123 => :command_123, 124 => :command_124, 125 => :command_125, 126 => :command_126, 127 => :command_127, 128 => :command_128, 129 => :command_129, 131 => :command_131, 132 => :command_132, 133 => :command_133, 134 => :command_134, 135 => :command_135, 136 => :command_136, 201 => :command_201, 202 => :command_202, 203 => :command_203, 204 => :command_204, 205 => :command_205, 206 => :command_206, 207 => :command_207, 208 => :command_208, 209 => :command_209, 210 => :command_210, 221 => :command_221, 222 => :command_222, 223 => :command_223, 224 => :command_224, 225 => :command_225, 231 => :command_231, 232 => :command_232, 233 => :command_233, 234 => :command_234, 235 => :command_235, 236 => :command_236, 241 => :command_241, 242 => :command_242, 245 => :command_245, 246 => :command_246, 247 => :command_247, 248 => :command_248, 249 => :command_249, 250 => :command_250, 251 => :command_251, 301 => :command_301, 601 => :command_601, 602 => :command_602, 603 => :command_603, 302 => :command_302, 303 => :command_303, 311 => :command_311, 312 => :command_312, 313 => :command_313, 314 => :command_314, 315 => :command_315, 316 => :command_316, 317 => :command_317, 318 => :command_318, 319 => :command_319, 320 => :command_320, 321 => :command_321, 322 => :command_322, 331 => :command_331, 332 => :command_332, 333 => :command_333, 334 => :command_334, 335 => :command_335, 336 => :command_336, 337 => :command_337, 338 => :command_338, 339 => :command_339, 340 => :command_340, 351 => :command_351, 352 => :command_352, 353 => :command_353, 354 => :command_354, 355 => :command_355}
  public
  # Command that starts a message display, if followed by a choice/input num command,
  # displays the choice/input num in the meantime
  def command_101
    return false if $game_temp.message_text
    @message_waiting = true
    $game_temp.message_proc = proc {@message_waiting = false }
    $game_temp.message_text = @list[@index].parameters[0].force_encoding(Encoding::UTF_8) + "\n"
    loop do
      if @list[@index.next].code == 401
        $game_temp.message_text += @list[@index.next].parameters[0].force_encoding(Encoding::UTF_8) + "\n"
      else
        if @list[@index.next].code == 102
          @index += 1
          setup_choices(@list[@index].parameters)
        else
          if @list[@index.next].code == 103
            @index += 1
            $game_temp.num_input_start = -99
            $game_temp.num_input_variable_id = @list[@index].parameters[0]
            $game_temp.num_input_digits_max = @list[@index].parameters[1]
          end
        end
        return true
      end
      @index += 1
    end
    return true
  ensure
    $game_temp.message_text.gsub!(/\n([^ ])|\n /, ' \\1') if $game_switches[Yuki::Sw::MSG_Recalibrate]
  end
  # Command that display a choice if possible (no message)
  def command_102
    return false if $game_temp.message_text
    @message_waiting = true
    $game_temp.message_proc = proc {@message_waiting = false }
    $game_temp.message_text = nil.to_s
    $game_temp.choice_start = 0
    setup_choices(@parameters)
    return true
  end
  # Command that execute the choice branch depending on the choice result
  def command_402
    if @branch[@list[@index].indent] == @parameters[0]
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # Command that execute the cancel branch if the result was 4 (max option in RMXP)
  def command_403
    if @branch[@list[@index].indent] == 4
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # Display an input number if possible (no message)
  def command_103
    return false if $game_temp.message_text
    @message_waiting = true
    $game_temp.message_proc = proc {@message_waiting = false }
    $game_temp.message_text = nil.to_s
    $game_temp.num_input_start = 0
    $game_temp.num_input_variable_id = @parameters[0]
    $game_temp.num_input_digits_max = @parameters[1]
    return true
  end
  # Change the message settings (position / frame type)
  def command_104
    return false if $game_temp.message_window_showing
    $game_system.message_position = @parameters[0]
    $game_system.message_frame = @parameters[1]
    return true
  end
  # Start a store button id to variable process
  def command_105
    @button_input_variable_id = @parameters[0]
    @index += 1
    return false
  end
  # Wait 2 times the number of frame requested
  def command_106
    @wait_count = @parameters[0] * 2
    return true
  end
  # Conditionnal command
  def command_111
    result = false
    case @parameters[0]
    when 0
      result = ($game_switches[@parameters[1]] == (@parameters[2] == 0))
    when 1
      value1 = $game_variables[@parameters[1]]
      if @parameters[2] == 0
        value2 = @parameters[3]
      else
        value2 = $game_variables[@parameters[3]]
      end
      case @parameters[4]
      when 0
        result = (value1 == value2)
      when 1
        result = (value1 >= value2)
      when 2
        result = (value1 <= value2)
      when 3
        result = (value1 > value2)
      when 4
        result = (value1 < value2)
      when 5
        result = (value1 != value2)
      end
    when 2
      if @event_id > 0
        key = [$game_map.map_id, @event_id, @parameters[1]]
        if @parameters[2] == 0
          result = ($game_self_switches[key] == true)
        else
          result = ($game_self_switches[key] != true)
        end
      end
    when 3
      if $game_system.timer_working
        sec = $game_system.timer / 60
        if @parameters[2] == 0
          result = (sec >= @parameters[1])
        else
          result = (sec <= @parameters[1])
        end
      end
    when 4
      actor = $game_actors[@parameters[1]]
      if actor
        case @parameters[2]
        when 0
          result = !actor.dead?
        when 1
          result = (actor.given_name == @parameters[3])
        when 2
          result = actor.skill_learnt?(@parameters[3], true)
        when 3
          result = (actor.item_holding == @parameters[3])
        when 4
          result = (actor.current_ability == @parameters[3])
        when 5
          result = (actor.status == @parameters[3])
        end
      end
    when 5
      enemy = PFM::BattleInterface.get_enemy(@parameters[1])
      if enemy
        case @parameters[2]
        when 0
          result = !enemy.dead?
        when 1
          result = (enemy.status == @parameters[3])
        end
      end
    when 6
      if (character = get_character(@parameters[1]))
        result = (character.direction == @parameters[2])
      end
    when 7
      if @parameters[2] == 0
        result = (PFM.game_state.money >= @parameters[1])
      else
        result = (PFM.game_state.money <= @parameters[1])
      end
    when 8
      result = $bag.contain_item?(@parameters[1])
    when 9
      result = false
    when 10
      result = false
    when 11
      result = Input.press?(RGSS2LiteRGSS_Input[@parameters[1]])
    when 12
      result = eval_condition_script(@parameters[1])
    end
    @branch[@list[@index].indent] = result
    if @branch[@list[@index].indent] == true
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # Function that execute a script for the conditions
  # @param script [String]
  def eval_condition_script(script)
    last_eval = Yuki::EXC.get_eval_script
    script = script.force_encoding('UTF-8')
    Yuki::EXC.set_eval_script(script)
    result = eval(script) ? true : false
    return result
  rescue StandardError => e
    Yuki::EXC.run(e)
    return false
  ensure
    Yuki::EXC.set_eval_script(last_eval)
  end
  # Command testing the false section of condition
  def command_411
    if @branch[@list[@index].indent] == false
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # Loop command
  def command_112
    return true
  end
  # Repeat loop command (try to go back to the loop command of the same indent)
  def command_413
    indent = @list[@index].indent
    loop do
      @index -= 1
      return true if @list[@index].indent == indent
    end
  end
  # Break loop command (try to go to the end of the loop)
  def command_113
    indent = @list[@index].indent
    temp_index = @index
    loop do
      temp_index += 1
      return true if temp_index >= @list.size - 1
      if @list[temp_index].code == 413 && @list[temp_index].indent < indent
        @index = temp_index
        return true
      end
    end
  end
  # End the interpretation of the current event
  def command_115
    command_end
    return true
  end
  # erase this event
  def command_116
    $game_map.events[@event_id].erase if @event_id > 0
    @index += 1
    return false
  end
  # Call a common event
  def command_117
    if (common_event = $data_common_events[@parameters[0]])
      @child_interpreter = Interpreter.new(@depth + 1)
      @child_interpreter.setup(common_event.list, @event_id)
    end
    return true
  end
  # Label command
  def command_118
    return true
  end
  # jump to a label
  def command_119
    label_name = @parameters[0]
    temp_index = 0
    loop do
      return true if temp_index >= @list.size - 1
      if @list[temp_index].code == 118 && @list[temp_index].parameters[0] == label_name
        @index = temp_index
        return true
      end
      temp_index += 1
    end
  end
  public
  # Multiple switch set
  def command_121
    for i in @parameters[0]..@parameters[1]
      $game_switches[i] = (@parameters[2] == 0)
    end
    $game_map.need_refresh = true
    return true
  end
  # Variable set
  def command_122
    value = 0
    case @parameters[3]
    when 0
      value = @parameters[4]
    when 1
      value = $game_variables[@parameters[4]]
    when 2
      value = @parameters[4] + rand(@parameters[5] - @parameters[4] + 1)
    when 3
      value = $bag.item_quantity(@parameters[4])
    when 4
      actor = $actors[@parameters[4]]
      if actor != nil
        case @parameters[5]
        when 0
          value = actor.level
        when 1
          value = actor.exp
        when 2
          value = actor.hp
        when 3
          value = 0
        when 4
          value = actor.max_hp
        when 5
          value = 0
        when 6
          value = actor.loyalty
        when 7
          value = actor.acc_stage
        when 8
          value = actor.spd
        when 9
          value = actor.ats
        when 10
          value = actor.atk
        when 11
          value = actor.dfe
        when 12
          value = actor.dfs
        when 13
          value = actor.eva_stage
        end
      end
    when 5
      enemy = $actors[@parameters[4]]
      if enemy != nil
        case @parameters[5]
        when 0
          value = enemy.hp
        when 1
          value = 0
        when 2
          value = enemy.max_hp
        when 3
          value = 0
        when 4
          value = enemy.loyalty
        when 5
          value = enemy.acc_stage
        when 6
          value = enemy.spd
        when 7
          value = enemy.ats
        when 8
          value = enemy.atk
        when 9
          value = enemy.dfe
        when 10
          value = enemy.dfs
        when 11
          value = enemy.eva_stage
        end
      end
    when 6
      character = get_character(@parameters[4])
      if character != nil
        case @parameters[5]
        when 0
          value = character.x - ::Yuki::MapLinker.current_OffsetX
        when 1
          value = character.y - ::Yuki::MapLinker.current_OffsetY
        when 2
          value = character.direction
        when 3
          value = character.screen_x
        when 4
          value = character.screen_y
        when 5
          value = character.terrain_tag
        end
      end
    when 7
      case @parameters[4]
      when 0
        value = $game_map.map_id
      when 1
        value = $actors.size
      when 2
        value = PFM.game_state.money
      when 3
        value = PFM.game_state.steps
      when 4
        value = Graphics.frame_count / 60
      when 5
        value = $game_system.timer / 60
      when 6
        value = $game_system.save_count
      end
    end
    for i in @parameters[0]..@parameters[1]
      case @parameters[2]
      when 0
        $game_variables[i] = value
      when 1
        $game_variables[i] += value
      when 2
        $game_variables[i] -= value
      when 3
        $game_variables[i] *= value
      when 4
        if value != 0
          $game_variables[i] /= value
        end
      when 5
        if value != 0
          $game_variables[i] %= value
        end
      end
      if $game_variables[i] > 99999999
        $game_variables[i] = 99999999
      end
      if $game_variables[i] < -99999999
        $game_variables[i] = -99999999
      end
    end
    $game_map.need_refresh = true
    return true
  end
  # Self Switch set
  def command_123
    if @event_id > 0
      event = $game_map.events[@event_id]
      return unless event
      event = event.event
      key = [event.original_map || $game_map.map_id, event.original_id || @event_id, @parameters[0]]
      $game_self_switches[key] = (@parameters[1] == 0)
    end
    $game_map.need_refresh = true
    return true
  end
  # Timer start / stop
  def command_124
    if @parameters[0] == 0
      $game_system.timer = @parameters[1] * 60
      $game_system.timer_working = true
    end
    if @parameters[0] == 1
      $game_system.timer_working = false
    end
    return true
  end
  # Earn gold command
  def command_125
    value = operate_value(@parameters[0], @parameters[1], @parameters[2])
    $game_party.gain_gold(value)
    return true
  end
  # Get item command
  def command_126
    value = operate_value(@parameters[1], @parameters[2], @parameters[3])
    $bag.add_item(@parameters[0], value)
    Audio.me_play(data_item(@parameters[0]).me, 80) if value > 0
    return true
  end
  # Gain weapon command
  def command_127
    return true
  end
  # Gain armor command
  def command_128
    return true
  end
  # Add or remove actor command
  def command_129
    actor = $game_actors[@parameters[0]]
    if actor != nil
      if @parameters[1] == 0
        if @parameters[2] == 1
          $game_actors[@parameters[0]].setup(@parameters[0])
        end
        $game_party.add_actor(@parameters[0])
      else
        $game_party.remove_actor(@parameters[0])
      end
    end
    return true
  end
  # Window skin change command
  def command_131
    $game_system.windowskin_name = @parameters[0]
    return true
  end
  # Battle BGM change command
  def command_132
    $game_system.battle_bgm = @parameters[0]
    return true
  end
  # Battle end ME change command
  def command_133
    $game_system.battle_end_me = @parameters[0]
    return true
  end
  # Save disable command
  def command_134
    $game_system.save_disabled = (@parameters[0] == 0)
    return true
  end
  # Menu disable command
  def command_135
    $game_system.menu_disabled = (@parameters[0] == 0)
    return true
  end
  # Encounter disable command
  def command_136
    $game_system.encounter_disabled = (@parameters[0] == 0)
    $game_player.make_encounter_count
    return true
  end
  public
  # Warp command
  def command_201
    if $game_temp.in_battle
      return true
    end
    if $game_temp.player_transferring || $game_temp.message_window_showing || $game_temp.transition_processing
      return false
    end
    $game_temp.player_transferring = true
    if @parameters[0] == 0
      $game_temp.player_new_map_id = @parameters[1]
      $game_temp.player_new_x = @parameters[2] + ::Yuki::MapLinker.get_OffsetX
      $game_temp.player_new_y = @parameters[3] + ::Yuki::MapLinker.get_OffsetY
      $game_temp.player_new_direction = @parameters[4]
    else
      $game_temp.player_new_map_id = $game_variables[@parameters[1]]
      $game_temp.player_new_x = $game_variables[@parameters[2]] + ::Yuki::MapLinker.get_OffsetX
      $game_temp.player_new_y = $game_variables[@parameters[3]] + ::Yuki::MapLinker.get_OffsetY
      $game_temp.player_new_direction = @parameters[4]
    end
    @index += 1
    if @parameters[5] == 0
      Graphics.freeze
      $game_temp.transition_processing = true
      $game_temp.transition_name = nil.to_s
    end
    return false
  end
  # Displace command
  def command_202
    if $game_temp.in_battle
      return true
    end
    character = get_character(@parameters[0])
    if character == nil
      return true
    end
    if @parameters[1] == 0
      character.moveto(@parameters[2] + ::Yuki::MapLinker.current_OffsetX, @parameters[3] + ::Yuki::MapLinker.current_OffsetY)
    else
      if @parameters[1] == 1
        character.moveto($game_variables[@parameters[2]] + ::Yuki::MapLinker.current_OffsetX, $game_variables[@parameters[3]] + ::Yuki::MapLinker.current_OffsetY)
      else
        old_x = character.x
        old_y = character.y
        character2 = get_character(@parameters[2])
        if character2 != nil
          character.moveto(character2.x, character2.y)
          character2.moveto(old_x, old_y)
        end
      end
    end
    case @parameters[4]
    when 8
      character.turn_up
    when 6
      character.turn_right
    when 2
      character.turn_down
    when 4
      character.turn_left
    end
    return true
  end
  # Map scroll command
  def command_203
    if $game_temp.in_battle
      return true
    end
    if $game_map.scrolling?
      return false
    end
    $game_map.start_scroll(@parameters[0], @parameters[1], @parameters[2])
    return true
  end
  # Map property change command
  def command_204
    case @parameters[0]
    when 0
      $game_map.panorama_name = @parameters[1]
      $game_map.panorama_hue = @parameters[2]
    when 1
      $game_map.fog_name = @parameters[1]
      $game_map.fog_hue = @parameters[2]
      $game_map.fog_opacity = @parameters[3]
      $game_map.fog_blend_type = @parameters[4]
      $game_map.fog_zoom = @parameters[5]
      $game_map.fog_sx = @parameters[6]
      $game_map.fog_sy = @parameters[7]
    when 2
      $game_map.battleback_name = @parameters[1]
      $game_temp.battleback_name = @parameters[1]
    end
    return true
  end
  # Map Tone change command
  def command_205
    $game_map.start_fog_tone_change(@parameters[0], @parameters[1] * 2)
    return true
  end
  # Map fog opacity change command
  def command_206
    $game_map.start_fog_opacity_change(@parameters[0], @parameters[1] * 2)
    return true
  end
  # Display animation on character command
  def command_207
    character = get_character(@parameters[0])
    if character == nil
      return true
    end
    character.animation_id = @parameters[1]
    return true
  end
  # Make player transparent command
  def command_208
    $game_player.transparent = (@parameters[0] == 0)
    return true
  end
  # Move route set command
  def command_209
    character = get_character(@parameters[0])
    if character == nil
      return true
    end
    character.force_move_route(@parameters[1])
    return true
  end
  # Wait until end of events move route
  def command_210
    unless $game_temp.in_battle
      @move_route_waiting = true
    end
    return true
  end
  # Prepare transition command
  def command_221
    if $game_temp.message_window_showing
      return false
    end
    Graphics.freeze
    return true
  end
  # Execute transition command
  def command_222
    if $game_temp.transition_processing
      return false
    end
    $game_temp.transition_processing = true
    $game_temp.transition_name = @parameters[0]
    @index += 1
    return false
  end
  # Screen tone change command
  def command_223
    if @parameters[0] != Game_Screen::NEUTRAL_TONE
      $game_screen.start_tone_change(@parameters[0], @parameters[1] * 2)
    else
      $game_screen.start_tone_change(Yuki::TJN.current_tone, @parameters[1] * 2)
    end
    return true
  end
  # Flash screen command
  def command_224
    $game_screen.start_flash(@parameters[0], @parameters[1] * 2)
    return true
  end
  # Shake screen command
  def command_225
    $game_screen.start_shake(@parameters[0], @parameters[1], @parameters[2] * 2)
    return true
  end
  # Picture display command
  def command_231
    number = @parameters[0] + ($game_temp.in_battle ? 50 : 0)
    if @parameters[3] == 0
      x = @parameters[4]
      y = @parameters[5]
    else
      x = $game_variables[@parameters[4]]
      y = $game_variables[@parameters[5]]
    end
    $game_screen.pictures[number].show(@parameters[1], @parameters[2], x, y, @parameters[6], @parameters[7], @parameters[8], @parameters[9])
    return true
  end
  # Picture move command
  def command_232
    number = @parameters[0] + ($game_temp.in_battle ? 50 : 0)
    if @parameters[3] == 0
      x = @parameters[4]
      y = @parameters[5]
    else
      x = $game_variables[@parameters[4]]
      y = $game_variables[@parameters[5]]
    end
    $game_screen.pictures[number].move(@parameters[1] * 2, @parameters[2], x, y, @parameters[6], @parameters[7], @parameters[8], @parameters[9])
    return true
  end
  # Picture rotate command
  def command_233
    number = @parameters[0] + ($game_temp.in_battle ? 50 : 0)
    $game_screen.pictures[number].rotate(@parameters[1])
    return true
  end
  # Picture tone change command
  def command_234
    number = @parameters[0] + ($game_temp.in_battle ? 50 : 0)
    $game_screen.pictures[number].start_tone_change(@parameters[1], @parameters[2] * 2)
    return true
  end
  # Picture erase command
  def command_235
    number = @parameters[0] + ($game_temp.in_battle ? 50 : 0)
    $game_screen.pictures[number].erase
    return true
  end
  # Weather change command
  def command_236
    $game_screen.weather(@parameters[0], @parameters[1], @parameters[2])
    return true
  end
  # BGM play command
  def command_241
    $game_system.bgm_play(@parameters[0])
    return true
  end
  # BGM fade command
  def command_242
    $game_system.bgm_fade(@parameters[0])
    return true
  end
  # BGS play command
  def command_245
    $game_system.bgs_play(@parameters[0])
    return true
  end
  # BGS Fade command
  def command_246
    $game_system.bgs_fade(@parameters[0])
    return true
  end
  # BGM & BGS memorize command
  def command_247
    $game_system.bgm_memorize
    $game_system.bgs_memorize
    return true
  end
  # BGM & BGS restore command
  def command_248
    $game_system.bgm_restore
    $game_system.bgs_restore
    return true
  end
  # ME play command
  def command_249
    $game_system.me_play(@parameters[0])
    return true
  end
  # SE play command
  def command_250
    $game_system.se_play(@parameters[0])
    return true
  end
  # SE stop command
  def command_251
    Audio.se_stop
    return true
  end
  public
  # Start battle command
  def command_301
    if $data_troops[@parameters[0]] != nil
      $game_temp.battle_abort = true
      $game_temp.battle_calling = true
      $game_temp.battle_troop_id = @parameters[0]
      $game_temp.battle_can_escape = @parameters[1]
      $game_temp.battle_can_lose = @parameters[2]
      current_indent = @list[@index].indent
      $game_temp.battle_proc = Proc.new { |n| @branch[current_indent] = n }
    end
    @index += 1
    return false
  end
  # 勝った場合
  def command_601
    if @branch[@list[@index].indent] == 0
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # 逃げた場合
  def command_602
    if @branch[@list[@index].indent] == 1
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # 負けた場合
  def command_603
    if @branch[@list[@index].indent] == 2
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end
  # Call a shop command
  def command_302
    $game_temp.battle_abort = true
    $game_temp.shop_calling = true
    $game_temp.shop_goods = [@parameters]
    loop do
      @index += 1
      if @list[@index].code == 605
        $game_temp.shop_goods.push(@list[@index].parameters)
      else
        return false
      end
    end
  end
  # Name calling command
  def command_303
    if $data_actors[@parameters[0]] != nil
      $game_temp.battle_abort = true
      $game_temp.name_calling = true
      $game_temp.name_actor_id = @parameters[0]
      $game_temp.name_max_char = @parameters[1]
    end
    @index += 1
    return false
  end
  # Add or remove HP command
  def command_311
    return true
  end
  # Add or remove SP command
  def command_312
    return true
  end
  # Add or remove state command
  def command_313
    return true
  end
  # Heal command
  def command_314
    return true
  end
  # Add exp command
  def command_315
    return true
  end
  # Add level command
  def command_316
    return true
  end
  # Change stat command
  def command_317
    return true
  end
  # Skill learn/forget command
  def command_318
    return true
  end
  # Equip command
  def command_319
    return true
  end
  # Name change command
  def command_320
    actor = $game_actors[@parameters[0]]
    actor.name = @parameters[1] if actor
    return true
  end
  # Class change command
  def command_321
    return true
  end
  # Actor graphic change command
  def command_322
    actor = $game_actors[@parameters[0]]
    actor&.set_graphic(@parameters[1], @parameters[2], @parameters[3], @parameters[4])
    $game_player.refresh
    return true
  end
  public
  # Enemy HP change command
  def command_331
    return true
  end
  # Enemy SP change command
  def command_332
    return true
  end
  # Enemy state change command
  def command_333
    return true
  end
  # Enemy heal command
  def command_334
    return true
  end
  # Enemy show command
  def command_335
    return true
  end
  # Enemy transform command
  def command_336
    return true
  end
  # Play animation on battler
  def command_337
    return true
  end
  # Damage on battler command
  def command_338
    return true
  end
  # Battler force action command
  def command_339
    return true
  end
  # End battle command
  def command_340
    @index += 1
    return false
  end
  # Call menu command
  def command_351
    $game_temp.battle_abort = true
    $game_temp.menu_calling = true
    @index += 1
    return false
  end
  # Call save command
  def command_352
    $game_temp.battle_abort = true
    $game_temp.save_calling = true
    @index += 1
    return false
  end
  # Game Over command
  def command_353
    $game_temp.gameover = true
    return false
  end
  # Go to title command
  def command_354
    $game_temp.to_title = true
    return false
  end
  # Execute script command
  def command_355
    script = @list[@index].parameters[0] + "\n"
    loop do
      if @list[@index + 1].code == 655
        script += @list[@index + 1].parameters[0] + "\n"
      else
        break
      end
      @index += 1
    end
    eval_script(script)
    return true
  end
  # Function that execute a script
  # @param script [String]
  def eval_script(script)
    last_eval = Yuki::EXC.get_eval_script
    script = script.force_encoding('UTF-8').gsub(/\n([(,])/, "\\1\n")
    Yuki::EXC.set_eval_script(script)
    eval(script)
  rescue StandardError => e
    Yuki::EXC.run(e)
    $scene = nil
  ensure
    Yuki::EXC.set_eval_script(last_eval)
  end
end
# Hash gérant les variables locales. Des variables propres à l'évènement, 
# Permet de ne pas devoir utiliser de variable de jeu pour gérer ce qui est propre
# à un évènement
# Dans les scrpit, la variable globale $game_self_variables contient les variables
# locales
# 
# @note This script should be after Interpreter 7
# @author Leikt
class Game_SelfVariables
  # Default initialization
  def initialize
    @data = {}
  end
  # Fetch the value of a self variable
  # @param key [Array] the key that identify the self variable
  # @return [Object]
  def [](key)
    return @data[key]
  end
  # Set the value of a self variable
  # @param key [Array] the key that identify the self variable
  # @param value [Object] the new value
  def []=(key, value)
    @data[key] = value
  end
  # Perform an action on the specific variable and return the result
  # @param key [Array] the key that identify the self variable
  # @param operation [Symbol] symbol of the operation to do on the variable
  # @param value [Object] value associated to the operation
  def do(key, operation = nil, value = nil)
    @data[key] = 0 unless @data.has_key?(key)
    case operation
    when :set
      @data[key] = value
    when :del
      @data.delete(key)
    when :add
      @data[key] += value
    when :sub
      @data[key] -= value
    when :div
      @data[key] /= value
    when :mul
      @data[key] *= value
    when :mod
      @data[key] = @data[key] % value
    when :count
      @data[key] += 1
    when :uncount
      @data[key] -= 1
    when :toggle
      @data[key] = !@data[key]
    when :and
      @data[key] = (@data[key] && value)
    when :or
      @data[key] = (@data[key] || value)
    when :xor
      @data[key] = (@data[key] ^ value)
    end
    return @data[key]
  end
end
class Interpreter < Interpreter_RMXP
  # @note Details here : https://pokemonworkshop.com/forum/index.php?topic=3770.msg109814#msg109814
  # @overload get_local_variable(id_var)
  #   Get a local variable
  #   @param id_var [Symbol] the id of the variable
  # @overload get_local_variable(id_var, operation, value = nil)
  #   Perform an operation on a local variable and get the result
  #   @param id_var [Symbol] the id of the variable
  #   @param operation [Symbol] symbol of the operation to do on the variable
  #   @param value [Object] value associated to the operation
  # @overload get_local_variable(id_event, id_var)
  #   Get a local variable of a specific event
  #   @param id_event [Integer] the id of the event
  #   @param id_var [Symbol] the id of the variable
  # @overload get_local_variable(id_event, id_var, operation, value = nil)
  #   Perform an operation on a local variable of an specific event and get the result
  #   @param id_event [Integer] the id of the event
  #   @param id_var [Symbol] the id of the variable
  #   @param operation [Symbol] symbol of the operation to do on the variable
  #   @param value [Object] value associated to the operation
  # @overload get_local_variable(id_map, id_event, id_var)
  #   Get a local variable of a specific event on a specific map
  #   @param id_map [Integer] the id of the map
  #   @param id_event [Integer] the id of the event
  #   @param id_var [Symbol] the id of the variable
  # @overload get_local_variable(id_map, id_event, id_var, operation, value = nil)
  #   Perform an operation on a local variable of an specific event on a specific map and get the result
  #   @param id_map [Integer] the id of the map
  #   @param id_event [Integer] the id of the event
  #   @param id_var [Symbol] the id of the variable
  #   @param operation [Symbol] symbol of the operation to do on the variable
  #   @param value [Object] value associated to the operation
  # @return [Object]
  def get_local_variable(*args)
    if args.first.is_a?(Symbol)
      return $game_self_variables.do([@map_id, @event_id, args.first], args[1], args[2])
    else
      if args[1].is_a?(Integer)
        return $game_self_variables.do([args.first, args[1], args[2]], args[3], args[4])
      else
        return $game_self_variables.do([@map_id, args.first, args[1]], args[2], args[3])
      end
    end
    return nil
  end
  alias VL get_local_variable
  alias LV get_local_variable
  # Set a local variable
  # @param value [Object] the new value of the variable
  # @param id_var [Symbol] the id of the variable
  # @param id_event [Integer] the id of the event
  # @param id_map [Integer] the id of the map
  def set_local_variable(value, id_var, id_event = @event_id, id_map = @map_id)
    key = [id_map, id_event, id_var]
    $game_self_variables[key] = value
  end
  alias set_VL set_local_variable
  alias set_LV set_local_variable
end
