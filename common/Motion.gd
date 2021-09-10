extends Reference

class_name Motion

class BoneCurve:
	class BoneSampleResult:
		var position: Vector3
		var rotation: Quat
	var keyframes: Array
	
	var _bin_split_frame_number: float
	
	func binary_split_pred(f: VMD.BoneKeyframe):
		return f.frame_number >= _bin_split_frame_number
	
	func sample(frame_number: float) -> BoneSampleResult:
		var result := BoneSampleResult.new()
		
		_bin_split_frame_number = frame_number
		var out := VMDUtils.binary_split(keyframes, funcref(self, "binary_split_pred"))
		var last_frame_num := 0
		var last_position := Vector3.ZERO
		var last_rotation := Quat.IDENTITY
		
		var next_frame = out.get("first_true", null) as VMD.BoneKeyframe
		
		if keyframes.size() > 0:
			print("DAB!")
		
		if "last_false" in out:
			var last_frame := out.last_false as VMD.BoneKeyframe
			last_frame_num = last_frame.frame_number
			last_position = last_frame.position
			last_rotation = last_frame.rotation
			print("LAST FALSE")
			print("LAST FALSE")

		if next_frame == null:
			result.position = last_position
			result.rotation = last_rotation
		else:
			var x = next_frame.interp.X.inv_lerp(last_frame_num, next_frame.frame_number, frame_number)
			var y = next_frame.interp.Y.inv_lerp(last_frame_num, next_frame.frame_number, frame_number)
			var z = next_frame.interp.Z.inv_lerp(last_frame_num, next_frame.frame_number, frame_number)
			var r = next_frame.interp.rotation.inv_lerp(last_frame_num, next_frame.frame_number, frame_number)
			result.position.x = lerp(last_position.x, next_frame.position.x, x)
			result.position.y = lerp(last_position.y, next_frame.position.y, y)
			result.position.z = lerp(last_position.z, next_frame.position.z, z)
			result.rotation = last_rotation.slerp(next_frame.rotation, r)
		return result
			
	func estimate_rotation_center_from_position() -> Vector3:
		var A0: Vector3
		var A1: Vector3
		var A2: Vector3
		var B: Vector3
		
		for i in range(keyframes.size()-1):
			var p = (keyframes[i] as VMD.BoneKeyframe).position
			var b = p.length_squared()/2
			var w = p.distance_to((keyframes[i-1] as VMD.BoneKeyframe).position) + p.distance_to((keyframes[i+1] as VMD.BoneKeyframe).position)
			
			A0 += w * p.x * p
			A1 += w * p.y * p
			A2 += w * p.z * p
			B += w * b * p
			
		var trf = Transform(Basis(A0, A1, A2), Vector3.ZERO)
		return trf.inverse() * B
		
class FaceCurve:
	var keyframes := []
	
	var _bin_split_frame_number: float
	
	func binary_split_pred(f: VMD.FaceKeyframe):
		return f.frame_number >= _bin_split_frame_number
	
	func sample(frame_number: float) -> float:
		_bin_split_frame_number = frame_number
		var out := VMDUtils.binary_split(keyframes, funcref(self, "binary_split_pred"))
		var last_frame_num := 0
		var last_weight := 0.0
		

		
		if "last_false" in out:
			var last_frame := out.last_false as VMD.FaceKeyframe
			last_frame_num = last_frame.frame_number
			last_weight = last_frame.weight
		
		var next_frame = out.get("first_true", null) as VMD.FaceKeyframe
		
		if next_frame == null:
			return last_weight
			
		return inverse_lerp(last_frame_num, next_frame.frame_number, frame_number)
		
class IKCurve:
	var keyframes := []
	
	var _bin_split_frame_number: float	
	
	func binary_split_pred(f: VMD.IKKeyframe):
		return f.frame_number-1 >= _bin_split_frame_number
	
	func sample(frame_number: float) -> Dictionary:
		_bin_split_frame_number = frame_number
		var out := VMDUtils.binary_split(keyframes, funcref(self, "binary_split_pred"))
		
		if "last_false" in out:
			var keyframe = out.last_false as VMD.IKKeyframe
			return keyframe.ik_enable
		return {}
		
var bones := {}
var faces := {}
var ik := IKCurve.new()

func _init(vmds: Array):
	for i in range(vmds.size()):
		var vmd = vmds[i] as VMD
		if vmd:
			add_clip(vmd)
	process()
func add_clip(vmd: VMD):
	for i in vmd.bone_keyframes.size():
		var keyframe = vmd.bone_keyframes[i] as VMD.BoneKeyframe
		if not keyframe.name in bones:
			bones[keyframe.name] = BoneCurve.new()
		(bones[keyframe.name] as BoneCurve).keyframes.append(keyframe)
	for i in vmd.face_keyframes.size():
		var keyframe = vmd.face_keyframes[i] as VMD.FaceKeyframe
		if not keyframe.name in faces:
			faces[keyframe.name] = FaceCurve.new()
		(faces[keyframe.name] as FaceCurve).keyframes.append(keyframe)
	for i in vmd.ik_keyframes:
		var keyframe = vmd.ik_keyframes[i] as VMD.IKKeyframe
		ik.keyframes.append(keyframe)

func sort_bones(a: VMD.BoneKeyframe, b: VMD.BoneKeyframe):
	if a.frame_number < b.frame_number:
		return true
	return false

func sort_faces(a: VMD.FaceKeyframe, b: VMD.FaceKeyframe):
	if a.frame_number < b.frame_number:
		return true
	return false

func sort_ik(a: VMD.IKKeyframe, b: VMD.IKKeyframe):
	if a.frame_number < b.frame_number:
		return true
	return false

func process():
	for i in range(bones.size()):
		var curve = bones.values()[i] as BoneCurve
		curve.keyframes.sort_custom(self, "sort_bones")
	for i in range(faces.size()):
		var curve = faces.values()[i] as FaceCurve
		curve.keyframes.sort_custom(self, "sort_faces")
	ik.keyframes.sort_custom(self, "sort_ik")
