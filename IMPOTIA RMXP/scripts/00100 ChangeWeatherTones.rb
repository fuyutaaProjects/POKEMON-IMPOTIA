# Because sunny is way too powerful
module RPG
    # Class that display weather
    class Weather
      # Tone used to simulate the sun weather
      remove_const :SunnyTone
      SunnyTone = Tone.new(45, 25, 0, 20)
    end
end