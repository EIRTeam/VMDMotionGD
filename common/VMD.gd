extends Reference

class_name VMD
		
class BoneKeyframe:
	
	class BoneInterp:
		var X: VMDUtils.BezierInterpolator
		var Y: VMDUtils.BezierInterpolator
		var Z: VMDUtils.BezierInterpolator
		var rotation: VMDUtils.BezierInterpolator
		func _init(_X: VMDUtils.BezierInterpolator, _Y: VMDUtils.BezierInterpolator, _Z: VMDUtils.BezierInterpolator, _rotation: VMDUtils.BezierInterpolator):
			X = _X
			Y = _Y
			Z = _Z
			rotation = _rotation
	
	var name: String
	var frame_number: int
	var position: Vector3
	var rotation: Quat
	var interp: BoneInterp
	
	func read(file: File):
		name = VMDUtils.read_string(file, 15)
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		position = VMDUtils.read_vector3(file)
		rotation = VMDUtils.read_quat(file)
		interp = BoneInterp.new(
			VMDUtils.read_bezier(file, 4), VMDUtils.read_bezier(file, 4),
			VMDUtils.read_bezier(file, 4), VMDUtils.read_bezier(file, 4)
		)
		
class FaceKeyframe:
	var name: String
	var frame_number: int
	var weight: float
	
	func read(file: File):
		name = VMDUtils.read_string(file, 15)
		frame_number = file.get_32()
		weight = file.get_float()
		
class CameraKeyframe:
	class CameraInterp:
		var X: VMDUtils.BezierInterpolator
		var Y: VMDUtils.BezierInterpolator
		var Z: VMDUtils.BezierInterpolator
		var R: VMDUtils.BezierInterpolator
		var dist: VMDUtils.BezierInterpolator
		var angle: VMDUtils.BezierInterpolator
	var frame_number: int
	var distance: float
	var position: Vector3
	var rotation: Vector3
	var interp = CameraInterp.new()
	var angle: float
	var perspective: bool
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		distance = file.get_float()
		position = VMDUtils.read_vector3(file)
		rotation = VMDUtils.read_vector3(file)
		interp.X = VMDUtils.read_bezier_camera(file, 1)
		interp.Y = VMDUtils.read_bezier_camera(file, 1)
		interp.Z = VMDUtils.read_bezier_camera(file, 1)
		interp.R = VMDUtils.read_bezier_camera(file, 1)
		interp.dist = VMDUtils.read_bezier_camera(file, 1)
		interp.angle = VMDUtils.read_bezier_camera(file, 1)
		angle = VMDUtils.unsigned32_to_signed(file.get_32())
		perspective = file.get_buffer(1)[0] != 0
	
class LightKeyframe:
	var frame_number: int
	var light_color: Color
	var position: Vector3
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		light_color = Color(file.get_float(), file.get_float(), file.get_float(), 1.0)
		position = VMDUtils.read_vector3(file)
	
class SelfShadowKeyframe:
	var frame_number: int
	var type: int
	var distance: float
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		type = file.get_8()
		distance = file.get_float()

class IKKeyframe:
	var frame_number: int
	var display: bool
	var ik_enable: Dictionary

	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		display = bool(file.get_8())
		var ik_enable_count = VMDUtils.unsigned32_to_signed(file.get_32())
		for i in range(ik_enable_count):
			var ik_enable_bone = VMDUtils.read_string(file, 20)
			ik_enable[ik_enable_bone] = bool(file.get_8())


var version: String
var name: String
var bone_keyframes: Array = []
var face_keyframes: Array = []
var camera_keyframes: Array = []
var light_keyframes: Array = []
var self_shadow_keyframes: Array = []
var ik_keyframes: Array = []

var bone_tracks = {}

class GetAxisAngleOut:
	var angle: float
	var axis: Vector3

func get_axis_angle(quat: Quat) -> GetAxisAngleOut:
	var aao = GetAxisAngleOut.new()
	aao.angle = 2 * acos(quat.w)
	var r = 1.0 / sqrt(1.0-quat.w * quat.w)
	aao.axis.x = quat.x * r
	aao.axis.y = quat.y * r
	aao.axis.z = quat.z * r
	return aao

func optimize_bone_track(t0: BoneKeyframe, t1: BoneKeyframe, t2: BoneKeyframe, allowed_linear_err: float, allowed_angular_err: float, max_optimizable_angle: float, norm: Vector3):
	var t1_time = t1.frame_number / 30.0
	var t2_time = t2.frame_number / 30.0
	var t0_time = t0.frame_number / 30.0
	var c = (t1_time - t0_time) / (t2_time - t0_time)
	var t = [-1.0, -1.0, -1.0]
	# translation
	
	var v0 := t0.position
	var v1 := t1.position
	var v2 := t2.position
	
	if v0.is_equal_approx(v2):
		if not v0.is_equal_approx(v1):
			return false
	else:
		var pd := v2-v0
		var d0 = pd.dot(v0)
		var d1 = pd.dot(v1)
		var d2 = pd.dot(v2)
		
		if d1 < d0 or d1 > d2:
			return false
		
		var d = Geometry.get_closest_point_to_segment(v1, v0, v2).distance_to(v1)

		if d > pd.length() * allowed_linear_err:
			return false
		
		if norm != Vector3() and acos(pd.normalized().dot(norm)) > allowed_angular_err:
			return false
			
		t[0] = (d1 - d0) /  (d2 - d0)
	
	# rotation
	
	var q0 := t0.rotation
	var q1 := t1.rotation
	var q2 := t2.rotation
	
	if q0.is_equal_approx(q2):
		if not q0.is_equal_approx(q1):
			return false
	else:
		var r02 = (q0.inverse() * q2).normalized()
		var r01 = (q0.inverse() * q1).normalized()
		
		if r02.w == 1 or r01.w == 1:
			return false
		
		var aao02 := get_axis_angle(r02)
		var aao01 := get_axis_angle(r01)
		
		var v02 := aao02.axis
		var a02 := aao02.angle
		var v01 := aao01.axis
		var a01 := aao01.angle
		
		if abs(a02) > max_optimizable_angle:
			return false
		if v01.dot(v02) < 0:
			#make sure both rotations go the same way to compare
			v02 = -v02
			a02 = -a02
		
		var err_01 = acos(v01.normalized().dot(v02.normalized())) / PI
		if err_01 > allowed_angular_err:
			#not rotating in the same axis
			return false
			
		
		if a01 * a02 < 0:
			#not rotating in the same direction
			return false
			
		var tr = a01 / a02
		if tr < 0 or tr > 1:
			return false #rotating too much or too less
			
		t[1] = tr
		
	var erase = false
	
	if t[0] == -1 and t[1] == -1:
		erase = true
	else:
		erase = true
		var lt = -1.0
		for j in range(2):
			if t[j] != -1:
				lt = t[j]
				for k in range(j+1, 2):
					if t[k] == -1:
						continue
					if abs(lt-t[k]) > allowed_linear_err:
						erase = false
						break
				break
		if lt == -1:
			return false
		if erase:
			if abs(lt - c) > allowed_linear_err:
				erase = false
	return erase
func optimize_bone_tracks(allowed_linear_err: float, allowed_angular_err: float, max_optimizable_range: float):
	var prev_erased := false
	var first_erased: BoneKeyframe
	var norm: Vector3
	
	for track in bone_tracks:
		var i = 1
		while i < bone_tracks[track].size() -1:
			var t0 = bone_tracks[track][i-1]
			var t1 = bone_tracks[track][i]
			var t2 = bone_tracks[track][i+1]
			
			var erase = optimize_bone_track(t0, t1, t2, allowed_linear_err, allowed_angular_err, max_optimizable_range, norm)
			if erase and not prev_erased:
				norm = (t2.position - t1.position).normalized()
			if prev_erased and optimize_bone_track(t0, first_erased, t2, allowed_linear_err, allowed_angular_err, max_optimizable_range, norm):
				erase = false
			if erase:
				if not prev_erased:
					first_erased = t1
					prev_erased = true
				bone_tracks[track].remove(i)
				i -= 1
			else:
				prev_erased = false
				norm = Vector3()
			i += 1

func extract_bone_tracks():
	for i in range(bone_keyframes.size()):
		var bk = bone_keyframes[i]
		if not bk.name in bone_tracks:
			bone_tracks[bk.name] = []
		bone_tracks[bk.name].append(bk)

func read(file: File) -> int:
	version = VMDUtils.read_string(file, 30)
	name = VMDUtils.read_string(file, 20)

	print("VMD File!\nVersion: %s\nModel: %s" % [version, name])

	if not version.begins_with("Vocaloid Motion Data"):
		printerr("Invalid VMD file")
		return ERR_FILE_CORRUPT

	var bone_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(bone_frame_count):
		var bk = BoneKeyframe.new()
		bk.read(file)
		bone_keyframes.append(bk)

	if file.get_position() == file.get_len():
		return OK
		
	var face_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(face_frame_count):
		var fk = FaceKeyframe.new()
		fk.read(file)
		face_keyframes.append(fk)
	
	if file.get_position() == file.get_len():
		return OK
		
	var camera_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(camera_frame_count):
		var ck = CameraKeyframe.new()
		ck.read(file)
		camera_keyframes.append(ck)
		
	if file.get_position() == file.get_len():
		return OK
		
	var light_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(light_frame_count):
		var lk = LightKeyframe.new()
		lk.read(file)
		light_keyframes.append(lk)
		
	if file.get_position() == file.get_len():
		return OK
		
	var self_shadow_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(self_shadow_frame_count):
		var ssk = SelfShadowKeyframe.new()
		ssk.read(file)
		self_shadow_keyframes.append(ssk)
		
	var ik_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(ik_frame_count):
		var ikk = IKKeyframe.new()
		ikk.read(file)
		ik_keyframes.append(ikk)
		
	return OK
	

