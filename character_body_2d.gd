extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const DEATH_Y = 500
const ROOM_WIDTH = 1400

@export_category("Movement")
@export var max_speed := 300.0
@export var ground_acceleration := 2200.0
@export var ground_deceleration := 2600.0
@export var air_acceleration := 1400.0
@export var air_deceleration := 1000.0

@export_category("Jump")
@export var jump_velocity := -400.0
@export var gravity := 1500.0
@export var fall_gravity_multiplier := 1.35
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12

@export_category("Dash")
@export var dash_speed := 850.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.65

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0

var is_dashing := false
var is_hurt := false
var is_dead := false

var last_direction := 1.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_timers(delta)
	handle_input()

	if is_dashing:
		handle_dash(delta)
	else:
		handle_gravity(delta)
		handle_jump()
		handle_horizontal_movement(delta)

	move_and_slide()

	if global_position.x > ROOM_WIDTH:
		change_room()

	if global_position.y > DEATH_Y:
		die()

	update_ground_state()
	update_animation()

func change_room():
	var next_room := GameManager.current_room + 1
	var next_scene := "res://room_" + str(next_room) + ".tscn"

	if ResourceLoader.exists(next_scene):
		GameManager.current_room = next_room
		get_tree().change_scene_to_file(next_scene)
	else:
		show_win_screen()

func show_win_screen():
	get_tree().change_scene_to_file("res://win_screen.tscn")

func handle_input() -> void:
	var direction := Input.get_axis("move_left", "move_right")

	if direction != 0:
		last_direction = direction

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_pressed("dash"):
		try_dash()


func handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")

	if direction != 0:
		var acceleration := ground_acceleration if is_on_floor() else air_acceleration

		velocity.x = move_toward(
			velocity.x,
			direction * max_speed,
			acceleration * delta
		)
	else:
		var deceleration := ground_deceleration if is_on_floor() else air_deceleration

		velocity.x = move_toward(
			velocity.x,
			0,
			deceleration * delta
		)


func handle_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var current_gravity := gravity

	if velocity.y > 0:
		current_gravity *= fall_gravity_multiplier

	velocity.y += current_gravity * delta


func handle_jump() -> void:
	if jump_buffer_timer > 0 and coyote_timer > 0:
		jump()

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.45


func jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0
	coyote_timer = 0


func try_dash() -> void:
	if dash_cooldown_timer > 0 or is_dashing:
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if direction == Vector2.ZERO:
		direction = Vector2(last_direction, 0)

	direction = direction.normalized()

	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	velocity = direction * dash_speed


func handle_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = velocity.normalized() * dash_speed

	if dash_timer <= 0:
		is_dashing = false
		velocity *= 0.35


func update_timers(delta: float) -> void:
	coyote_timer = max(coyote_timer - delta, 0)
	jump_buffer_timer = max(jump_buffer_timer - delta, 0)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0)


func update_ground_state() -> void:
	if is_on_floor():
		coyote_timer = coyote_time

func update_animation() -> void:
	if is_dead or is_hurt:
		return

	if is_dashing:
		play_animation("roll")
		return

	if is_on_floor() and abs(velocity.x) > 20:
		play_animation("run")
	else:
		play_animation("idle")

	if velocity.x != 0:
		animated_sprite.flip_h = velocity.x < 0

func play_animation(animation_name: String) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func hit() -> void:
	if is_dead or is_hurt:
		return

	is_hurt = true
	animated_sprite.play("hit")

	await animated_sprite.animation_finished

	is_hurt = false

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	animated_sprite.play("death")

	await get_tree().create_timer(0.5).timeout

	get_tree().reload_current_scene()
