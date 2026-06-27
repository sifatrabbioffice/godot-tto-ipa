extends CharacterBody3D

@export_category("Basic Movement")
@export var SPEED: float = 2.0
@export var SPRINT_SPEED: float = 8.0
const JUMP_VELOCITY: float = 4.5

@export_category("AAA Physics")
@export var ACCELERATION: float = 8.0
@export var DECELERATION: float = 10.0
@export var AIR_CONTROL: float = 0.3
@export var ROTATION_SPEED: float = 12.0
@export var LEAN_AMOUNT: float = 0.15
@export var LEAN_SPEED: float = 8.0

enum PlayerState {IDLE, WALK, RUN, JUMP, FALL, ATTACK}
var current_state: PlayerState = PlayerState.IDLE

@onready var head: Node3D = $head
@onready var player_mesh: Node3D = $CollisionShape3D/"Standing Idle"
@onready var anim_player: AnimationPlayer = $CollisionShape3D/"Standing Idle"/AnimationPlayer

var coyote_time: float = 0.0
const COYOTE_TIME_MAX: float = 0.15

func _ready() -> void:
	if anim_player == null and is_instance_valid(player_mesh):
		for child in player_mesh.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
	# অ্যানিমেশন প্লেয়ার খুঁজে না পেলে কনসোলে মেসেজ দেবে
	if not anim_player:
		print("ERROR: AnimationPlayer not found!")

func _physics_process(delta: float) -> void:
	# গ্র্যাভিটি
	if is_on_floor():
		coyote_time = COYOTE_TIME_MAX
	else:
		coyote_time -= delta
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	# জাম্প
	if Input.is_action_just_pressed("jump") and coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_time = 0.0
		_change_state(PlayerState.JUMP)

	# অ্যাটাক (R1 বা আপনার সেট করা বাটন)
	if Input.is_action_just_pressed("attack") and is_on_floor():
		_change_state(PlayerState.ATTACK)

	# মুভমেন্ট
	var current_speed = SPRINT_SPEED if (Input.is_action_pressed("sprint") and is_on_floor()) else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0
	direction = direction.normalized()

	var current_accel = ACCELERATION if is_on_floor() else ACCELERATION * AIR_CONTROL
	var current_decel = DECELERATION if is_on_floor() else DECELERATION * 0.2

	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, current_accel * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, current_accel * delta)
		if is_instance_valid(player_mesh):
			var target_angle = atan2(direction.x, direction.z)
			var angle_diff = wrapf(target_angle - player_mesh.rotation.y, -PI, PI)
			player_mesh.rotation.y += angle_diff * ROTATION_SPEED * delta
			var speed_ratio = velocity.length() / SPRINT_SPEED
			var target_lean = clamp(-angle_diff * LEAN_AMOUNT * speed_ratio, -LEAN_AMOUNT, LEAN_AMOUNT)
			player_mesh.rotation.z = lerp(player_mesh.rotation.z, target_lean, LEAN_SPEED * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, current_decel * delta)
		velocity.z = lerp(velocity.z, 0.0, current_decel * delta)
		if is_instance_valid(player_mesh):
			player_mesh.rotation.z = lerp(player_mesh.rotation.z, 0.0, LEAN_SPEED * delta)

	_update_animation_state()
	move_and_slide()

func _change_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	if current_state == PlayerState.ATTACK and new_state != PlayerState.ATTACK:
		return
	current_state = new_state
	_apply_animation()

func _update_animation_state() -> void:
	if current_state == PlayerState.ATTACK:
		return
	if not is_on_floor():
		if velocity.y > 0.1:
			_change_state(PlayerState.JUMP)
		elif velocity.y < -0.1:
			_change_state(PlayerState.FALL)
		return
	if velocity.length() < 0.2:
		_change_state(PlayerState.IDLE)
	else:
		if Input.is_action_pressed("sprint"):
			_change_state(PlayerState.RUN)
		else:
			_change_state(PlayerState.WALK)

func _apply_animation() -> void:
	if not is_instance_valid(anim_player):
		return
	match current_state:
		PlayerState.IDLE:
			anim_player.play("anim/idle", 0.2)
		PlayerState.WALK:
			anim_player.play("anim/walk", 0.2)
		PlayerState.RUN:
			anim_player.play("anim/run", 0.2)
		PlayerState.JUMP:
			anim_player.play("anim/jump", 0.1)
		PlayerState.FALL:
			anim_player.play("anim/fall", 0.1)
		PlayerState.ATTACK:
			# 🔥 লুপ বন্ধ করার জন্য কোড
			var anim = anim_player.get_animation("anim/attack")
			if anim and anim.loop_mode != Animation.LOOP_NONE:
				anim.loop_mode = Animation.LOOP_NONE
			anim_player.play("anim/attack", 0.1)
			if not anim_player.animation_finished.is_connected(_on_attack_finished):
				anim_player.animation_finished.connect(_on_attack_finished)

func _on_attack_finished(anim_name: String) -> void:
	if anim_name == "anim/attack":
		current_state = PlayerState.IDLE
		if anim_player.animation_finished.is_connected(_on_attack_finished):
			anim_player.animation_finished.disconnect(_on_attack_finished)
