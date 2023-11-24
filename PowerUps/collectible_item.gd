extends Sprite2D


# To add collectible items (power ups, coins, or whatever else)
# create an inherited scene from collectible_item.tscn.
# Be sure to give the root node of your inherited scene a name
# that uniquely represents that type of item.


# The collectible_item scene includes an Area2D.
# The "on area 2d body entered" signal of that Area2D 
# is connected to this method.
func _on_area_2d_body_entered(body) -> void:
	if body.has_method("collect_item"):
		# Be sure the item name itself matches the name of the power up
		# you want to use
		body.collect_item(name)
		call_deferred("queue_free")
