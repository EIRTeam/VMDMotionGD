extends Spatial

class_name VMDAnimatorBase

var skeleton: Skeleton

func find_humanoid_bone(bone: String) -> int:
	return -1

func get_human_scale() -> float:
	return VMDUtils.get_bone_global_rest(skeleton, find_humanoid_bone("hips")).origin.y
