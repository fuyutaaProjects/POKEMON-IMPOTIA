require 'json'
require 'net/http'
require 'openssl'

module DiscordWebhooks
  # Ton URL Webhook (Vérifie qu'elle est toujours valide sur Discord)
  WEBHOOK_URL = ''
  
  # Image de profil (Attention : utilise un lien permanent type Imgur, pas un lien discordapp temporaire)
  AVATAR_URL = "https://media.discordapp.net/attachments/1466884787204653066/1466884852522418389/wise_tree.jpg" 

  module_function

  # Fonction d'envoi générique
  def post(payload)
    uri = URI(WEBHOOK_URL)
    
    # Configuration de la connexion HTTP
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    # CRUCIAL POUR RMXP : On désactive la vérification stricte du SSL
    # Cela permet de contourner les erreurs de certificat obsolète
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE 

    # Préparation de la requête
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    request.body = payload.to_json

    # Envoi avec gestion d'erreur visible
    begin
      response = http.request(request)
      
      # Affiche le résultat dans la console (F12 ou cmd)
      if response.code.to_i >= 200 && response.code.to_i < 300
        p "[DiscordWebhooks] Succès ! (Code: #{response.code})"
      else
        p "[DiscordWebhooks] Échec Discord : #{response.code} - #{response.body}"
      end
    rescue Exception => e
      p "[DiscordWebhooks] ERREUR CRITIQUE : #{e.message}"
      p e.backtrace
    end
  end

  # Fonction spécifique pour les champions d'arène
  def gym_defeated(badge_number)
    # Récupération sécurisée du nom du joueur
    player_name = (defined?($trainer) && $trainer) ? $trainer.name : "Joueur Test"
  
    # Configuration des champions
    champions = {
      1 => { name: "Alvis", gender: "le champion" },
      2 => { name: "Moïra", gender: "la championne" },
      3 => { name: "Yvar", gender: "le champion" },
      4 => { name: "Tiberius", gender: "le champion" },
      5 => { name: "Petra", gender: "la championne" },
      6 => { name: "Elme et Alfred", gender: "les champions" },
      7 => { name: "Nova", gender: "la championne" },
      8 => { name: "Youri", gender: "le champion" }
    }
  
    # Sélection du champion
    info = champions[badge_number] || { name: "Inconnu", gender: "le champion" }
    description_text = "#{player_name} a battu #{info[:gender]} #{info[:name]} !"
  
    # Construction du message (Payload)
    payload = {
      username: "Impotia Webhook",
      avatar_url: AVATAR_URL,
      embeds: [
        {
          title: "Victoire d'Arène !",
          description: description_text,
          color: 5814783, # Une couleur verte un peu stylée
        }
      ]
    }
  
    # Envoi
    post(payload)
  end

  # Fonction de test simple
  def post_test
    post({
      username: "Professeur Cactus",
      content: "Ceci est un test de connexion depuis RMXP. Si tu lis ça, ça marche !"
    })
  end
end