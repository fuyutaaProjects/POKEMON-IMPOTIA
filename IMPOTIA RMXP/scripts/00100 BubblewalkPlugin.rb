class Game_Character
  # Show an emotion to an event or the player
  # @param type [Symbol] the type of emotion (see wiki)
  # @param wait [Integer] the number of frame the event will wait after this command.
  # @param params [Hash] particle params

  PARTICLES_METHODS[TUnderWater] = :particle_push_bubblewalk

  def particle_push_bubblewalk
    Yuki::Particles.add_particle(self, :bubblewalk)
  end
end 