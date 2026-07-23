extends RefCounted
## Efecto visual de un solo uso (CPUParticles2D + auto-limpieza) para impactos de
## proyectil y muertes de enemigo -- sin escena propia, configurado por código, mismo
## criterio 100% programático que el resto del juego. CPUParticles2D en vez de
## GPUParticles2D: pocas partículas por evento, sesión corta de 3-5 min, sin necesidad de
## GPU-side particles.
##
##   const ImpactVfxGd := preload("res://src/features/vfx/impact_vfx.gd")
##   ImpactVfxGd.spawn(get_parent(), global_position, Color(0.4, 0.8, 0.3, 1.0))
##
## `at_position` es en coordenadas GLOBALES (ej. enemy.global_position) -- se asigna a
## global_position DESPUÉS de add_child(), nunca a position antes: position es relativo
## al parent recibido (EnemySpawner/Board, lo que sea), que puede tener su propio offset
## (ej. Board.gd centra el tablero con un position != Vector2.ZERO). Asignar antes de
## add_child() tampoco alcanza -- global_position necesita que el nodo ya esté en el
## árbol para resolver la transform del parent.

const DEFAULT_LIFETIME: float = 0.35


static func spawn(parent: Node, at_position: Vector2, color: Color, amount: int = 12) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = DEFAULT_LIFETIME
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	parent.add_child(particles)
	particles.global_position = at_position
	## finished (no un Timer manual) ata la limpieza exactamente a cuando el sistema
	## one_shot terminó de verdad -- sin depender de adivinar cuánto dura lifetime+margen.
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
