class_name ObjectPool
extends RefCounted

## Пул объектов для снарядов и эффектов (Этап 10)
## Предотвращает просадки FPS и выделение памяти при сотнях снарядов на экране

var template_script: Script = null
var available_objects: Array[Node] = []
var active_objects: Array[Node] = []
var max_pool_size: int = 200

func _init(p_script: Script, p_initial_size: int = 20, p_max_size: int = 200) -> void:
	template_script = p_script
	max_pool_size = p_max_size
	prewarm(p_initial_size)

func prewarm(count: int) -> void:
	for i in range(count):
		if available_objects.size() < max_pool_size:
			var obj = _create_new_object()
			available_objects.append(obj)

func acquire() -> Node:
	var obj: Node = null
	if available_objects.size() > 0:
		obj = available_objects.pop_back()
	else:
		obj = _create_new_object()
		
	active_objects.append(obj)
	if obj.has_method("on_pool_acquire"):
		obj.on_pool_acquire()
	return obj

func release(obj: Node) -> void:
	if not is_instance_valid(obj):
		return
		
	var idx = active_objects.find(obj)
	if idx != -1:
		active_objects.remove_at(idx)
		
	if obj.has_method("on_pool_release"):
		obj.on_pool_release()
		
	if available_objects.size() < max_pool_size:
		available_objects.append(obj)
	else:
		obj.queue_free()

func get_active_count() -> int:
	return active_objects.size()

func get_available_count() -> int:
	return available_objects.size()

func clear() -> void:
	for obj in available_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	available_objects.clear()
	active_objects.clear()

func _create_new_object() -> Node:
	var obj = Node2D.new()
	if template_script != null:
		obj.set_script(template_script)
	return obj
