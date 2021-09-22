extends VMDAnimatorBase

class_name VRMAnimator

var vrm: VRMTopLevel

func _ready():
	assert(get_child_count() > 0, "Must have a VRMTopLevel as the only child")
	assert(get_child(0) is VRMTopLevel, "Must have a VRMTopLevel as the only child")
	vrm = get_child(0)
	
	skeleton = vrm.get_node(vrm.vrm_skeleton) as Skeleton
	var right_arm_bone = find_humanoid_bone("rightUpperArm")
	var left_arm_bone = find_humanoid_bone("leftUpperArm")
	if right_arm_bone != -1:
		var br = skeleton.get_bone_rest(right_arm_bone)
		br.basis = Basis(Vector3.FORWARD, deg2rad(30)) * br.basis
		skeleton.set_bone_rest(right_arm_bone, br)
	
	if left_arm_bone != -1:
		var br = skeleton.get_bone_rest(left_arm_bone)
		br.basis = Basis(Vector3.FORWARD, deg2rad(-30)) * br.basis
		skeleton.set_bone_rest(left_arm_bone,  br)
	
func find_humanoid_bone(bone_name: String):
	if bone_name in vrm.vrm_meta.humanoid_bone_mapping:
		return skeleton.find_bone(vrm.vrm_meta.humanoid_bone_mapping[bone_name])
	else:
		return skeleton.find_bone(bone_name)
