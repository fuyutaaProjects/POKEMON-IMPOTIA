require 'json'
require 'net/http'
 
ENV['SSL_CERT_FILE'] ||= './lib/cert.pem' if $0 == 'Game.rb' # Launched from PSDK

module DiscordWebhooks
  DISCORD_WEBHOOK_URI = {
    :default => URI('https://discord.com/api/webhooks/1317555699231887360/ocL0_ARAq6t8mOZb_GC2gYt6pLQeMEAcwuQQPpd7SULjsR6a2sqsjmh9FFxm_AmxEzdR')
    #, :example => URI("url2")
  }

  module_function
  
  # @overload post(data)
  # Post data to the default DISCORD_WEBHOOK_URI
  # @param data [Hash] the webhook data
  # @overload post(url, data)
  # Post data to a Discord Webhook using an URL or an URI
  # @param url [URI, String] the Discord Webhook
  # @param data [Hash] the webhook data
  # @param key [String] the key in DISCORD_WEBHOOK_URI
  def post(url, data = url, key = :default)
    url = DISCORD_WEBHOOK_URI[key] if url.is_a?(Hash)
    url = URI(url) if url.is_a?(String)
    begin
      Net::HTTP.post(url, data.to_json, "Content-Type" => "application/json")
    rescue Exception
    end
  end

  def post_test
    player_name = $trainer&.name
    DiscordWebhooks.post("username": "Professeur Cactus",
    "avatar_url": "https://media.discordapp.net/attachments/1125034441039941762/1317572110675218442/cactus-modified.png?ex=675f2c26&is=675ddaa6&hm=0792468f296ceea746474dd3be5b3d0835884f8bff1624e75d0e5c6031545cb3&=&format=webp&quality=lossless",
    "embeds": [
      {
        "title": "",
        "description": "#{player_name || 'Unknown'} est très freaky",
        "color": 0,
        "footer": {
        },
      }
    ],
    "attachments": [])
  end

  def gym_defeated(badge_number)
    player_name = $trainer&.name || "Unknown"
  
    # Table des champions avec leur genre (masculin, féminin ou pluriel)
    champions = {
      1 => { name: "Alvis", gender: "le champion" },
      2 => { name: "Moïra", gender: "la championne" },
      3 => { name: "Yvar", gender: "le champion" },
      4 => { name: "Tiberius", gender: "le champion" },
      5 => { name: "Petra", gender: "la championne" },
      6 => { name: "Elme et Alfred", gender: "les champions" }, # Pluriel pour arène 6
      7 => { name: "Nova", gender: "la championne" },
      8 => { name: "Youri", gender: "le champion" }
    }
  
    # Récupérer les informations du champion
    champion_info = champions[badge_number] || { name: "un champion inconnu", gender: "le champion(ne)" }
    champion_name = champion_info[:name]
    champion_gender = champion_info[:gender]
  
    # Créer le message
    message = "#{player_name} a battu #{champion_gender} #{champion_name} !"
  
    # Envoyer le webhook Discord
    DiscordWebhooks.post(
      "username": "Professeur Cactus",
      "avatar_url": "https://media.discordapp.net/attachments/1125034441039941762/1317572110675218442/cactus-modified.png?ex=675f2c26&is=675ddaa6&hm=0792468f296ceea746474dd3be5b3d0835884f8bff1624e75d0e5c6031545cb3&=&format=webp&quality=lossless",
      "embeds": [
        {
          "title": "",
          "description": message,
          "color": 0,
          "footer": {},
        }
      ],
      "attachments": []
    )
  end  
end

