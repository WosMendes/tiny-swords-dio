class_name Player
extends CharacterBody2D

@export_category("Movement")
@export var speed: float = 3
@export_category("Attack")
@export var sword_damage: int = 2
@export var ritual_damage: int = 1
@export var ritual_interval: float = 30
@export var ritual_scene: PackedScene
@export_category("Life")
@export var health: int = 10
@export var max_health: int = 10
@export var death_prefab: PackedScene

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var sword_area: Area2D = $SwordArea
@onready var hurtbox_area: Area2D = $HurtBoxArea
@onready var health_progress_bar: ProgressBar = $HealthProgressBar


var input_vector: Vector2 = Vector2(0, 0)
var is_running: bool = false
var is_attacking: bool = false
var hurtbox_cooldown: float = 0.0
var ritual_cooldown: float = 0.0

signal meat_collected(value: int)

func _ready():
	GameManager.player = self
	animation_player.connect("animation_finished", _on_animation_finished)
	meat_collected.connect(func(value: int): GameManager.meat_counter += 1)
	
func _on_animation_finished(animation_name):
	if(animation_name == "attack_side_1"):
		is_attacking = false
		
func _process(delta: float) -> void:
	GameManager.player_position = position
	
	play_idle_or_run_animation()
	player_attack()
	update_hurtbox_detection(delta)
	update_ritual(delta)
	
	health_progress_bar.max_value = max_health
	health_progress_bar.value = health

func _physics_process(delta: float) -> void:
	read_input()
	apply_player_velocity()
	if not is_attacking:
		flip_player_horizontally()

func player_attack() -> void:
	if Input.is_action_just_pressed("attack"):
		if animation_player.current_animation == "attack_side_1":
			return
		animation_player.play("attack_side_1")
		is_attacking = true
	

func deal_damage_to_enemies() -> void:
	var bodies = sword_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var enemy: Enemy = body
			var direction_to_enemy = (enemy.position - position).normalized()
			var attack_direction: Vector2
			if sprite.flip_h:
				attack_direction = Vector2.LEFT
			else:
				attack_direction = Vector2.RIGHT
			var dot_product = direction_to_enemy.dot(attack_direction)
			if dot_product >= 0.3:
				enemy.damage(sword_damage)
		
	
func update_ritual(delta: float) -> void:
	ritual_cooldown -= delta
	if ritual_cooldown > 0: return
	ritual_cooldown = ritual_interval
	
	var ritual = ritual_scene.instantiate()
	ritual.damage_amount = ritual_damage
	add_child(ritual)

func read_input() -> void:
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
func apply_player_velocity() -> void:
	var target_velocity = input_vector * speed * 100.0
	if is_attacking:
		target_velocity *= 0.20
	velocity = lerp(velocity, target_velocity, 0.5)
	move_and_slide()
	# Atualizar o is_running
	is_running = not input_vector.is_zero_approx()
	
func play_idle_or_run_animation() -> void:
	if not is_attacking:
		if is_running:
			animation_player.play("run")
		else:
			animation_player.play("idle")

func flip_player_horizontally() -> void:
	if input_vector.x > 0:
		sprite.flip_h = false
	elif input_vector.x < 0:
		sprite.flip_h = true
		
func update_hurtbox_detection(delta: float) -> void:
	# Temporizador
	hurtbox_cooldown -= delta
	if hurtbox_cooldown > 0: return
	
	# Frequência
	hurtbox_cooldown = 0.5
	
	# Detectar inimigos
	var bodies = hurtbox_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			var enemy: Enemy = body
			var damage_amount = 1
			damage(damage_amount)


func damage(amount: int) -> void:
	if health <= 0: return
	
	health -= amount
	print("Inimigo recebeu dano de ", amount, ". A vida total é de ", health)
	
	# Piscar node
	modulate = Color.RED
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	# Processar morte
	if health <= 0:
		die()
		
func die() -> void:
	GameManager.end_game()
	
	if death_prefab:
		var death_object = death_prefab.instantiate()
		death_object.position = position
		get_parent().add_child(death_object)
	
	queue_free()

func heal(amount: int) -> int:
	health += amount
	if health > max_health:
		health = max_health
	print("Player recebeu cura de ", amount, ". A vida total é de ", health, "/", max_health)
	return health
