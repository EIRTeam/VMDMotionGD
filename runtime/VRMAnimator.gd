extends VMDAnimatorBase

class_name VRMAnimator

var vrm: VRMTopLevel

func _ready():
	assert(get_child_count() > 0, "Must have a VRMTopLevel as the only child")
	assert(get_child(0) is VRMTopLevel, "Must have a VRMTopLevel as the only child")
	vrm = get_child(0)
	
	skeleton = vrm.get_node(vrm.vrm_skeleton) as Skeleton
	
func find_humanoid_bone(bone_name: String):
	if bone_name in vrm.vrm_meta.humanoid_bone_mapping:
		return skeleton.find_bone(vrm.vrm_meta.humanoid_bone_mapping[bone_name])
	else:
		return skeleton.find_bone(bone_name)
