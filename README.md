# VMDMotionGD

VMDMotionGD is a tool to play VMD (Vocaloid Motion Data) animation on Unity humanoid-style characters, this is a godot 3.x port of [lox9973's tool](https://gitlab.com/lox9973/VMDMotion/-/tree/master)

# Usage

Currently, this is designed to be used with [godot-vrm](https://github.com/V-Sekai/godot-vrm)

You will have to implement a VMDAnimatorBase for your specific skeleton for humanoid bone mapping and other thigns, an example VRM implementation is provided in runtine/VRMAnimator.gd, this will probably be split off in the future

Create a VRM animator, put your VRMTopLevel as a child of it
Then create a VMDPlayer

# Stuff to do 
- [x] Basic functionality (VMD loading)
- [ ] VMD camera loading
- [ ] Morph support & VRM morph support framework
- [ ] C++ port (If needed)
- [ ] 4.0 port (waiting for GDScript to become more stable)