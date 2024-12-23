class Interpreter
  def get_choices
    # Vérification de la présence des items dans le sac
    carnet = $bag.has_item?(:carnet_annote)
    corde = $bag.has_item?(:corde_descalade)
    partition = $bag.has_item?(:partition_froissee)
    roche = $bag.has_item?(:roche_a_cristaux_rares)

    # Calcul du code correspondant en fonction des items présents
    choices = 0
    choices += 1 if carnet
    choices += 2 if corde
    choices += 4 if partition
    choices += 8 if roche

    gv[130] = choices
  end
end  

# inventory_mapping = {
#   0 => "no item",
#   1 => "carnet annoté",
#   2 => "corde d'aventurière",
#   3 => "carnet annoté et corde d'aventurière",
#   4 => "partition froissée",
#   5 => "carnet annoté et partition froissée",
#   6 => "corde d'aventurière et partition froissée",
#   7 => "carnet annoté, corde d'aventurière et partition froissée",
#   8 => "roche à minerais rares",
#   9 => "carnet annoté et roche à minerais rares",
#   10 => "corde d'aventurière et roche à minerais rares",
#   11 => "carnet annoté, corde d'aventurière et roche à minerais rares",
#   12 => "partition froissée et roche à minerais rares",
#   13 => "carnet annoté, partition froissée et roche à minerais rares",
#   14 => "corde d'aventurière, partition froissée et roche à minerais rares",
#   15 => "carnet annoté, corde d'aventurière, partition froissée et roche à minerais rares"
# }

