extends Resource
class_name WaveData

@export var point_budget: int = 10
@export var spawn_rate_curve: Curve          # null = linear 2s→0.3s delay
@export var spawn_pool: Array[EnemyEntry] = []
@export var guaranteed_spawns: Array[EnemyEntry] = []
