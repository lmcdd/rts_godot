extends Node2D

const COUNT_UNITS = 40
const SP_SIZE = 64
const UNIT_DISTANCE = 10
const PSEVDOFORM_UNIT_SIZE = Vector2(20, 20)
const PSEVDOFORM_COLOR = Color(0, 1, 0)
const SELECT_COLOR = Color(0, 1, 0, 0.24)
const PATH_IMG_UNIT = 'res://assets/art/units/'
const PATH_IMG_UNIT_TYPE = 'res://assets/art/ui/troop/'


var img_speed1 = preload('res://assets/art/ui/speed/speed1.png')
var img_speed2 = preload('res://assets/art/ui/speed/speed2.png')

onready var panel = get_node("CanvasLayer/ui/functionalPanel")
onready var units = get_node('Players/Player/Units/Regiment1') 
onready var units2 = get_node('Players/Player/Units/Regiment2') 
onready var army = get_node('Players/Player/Units/') 
onready var armyGrid = get_node('CanvasLayer/ui/armyPanel/GridContainer') 

var sel_units = []
var sel_regiment = []
var psevdoform_start_pos = Vector2()
var psevdoform_end_pos = null
var sel_start_pos = Vector2()
var sel_end_pos = null
var psevdoform

var propeties = {} #{regiment: {p:v...}}
var targets = {} #{unit: target_pos}


func square(units, m, n): #обобщенная модель для фаланги и квадрата
	var co = []
	var uf = []
	for x in range(0, abs(m)): 
		var tmp = []
		for y in range(0, abs(n)):
			if m < 0:
				tmp.append(Vector2((UNIT_DISTANCE + SP_SIZE) * -x, (UNIT_DISTANCE + SP_SIZE) * y))
			else:
				tmp.append(Vector2((UNIT_DISTANCE + SP_SIZE) * x, (UNIT_DISTANCE + SP_SIZE) * y))
			uf.append(Vector2(x,y))
		co.append(tmp)
	return [co, uf]
	
##############################################3		
		
func fill_box(units): #квадрат
	var k = sqrt(units.size())
	if  (k - floor(k)) != 0:
		k = int(k) + 1
	else:	
		k = int(k)
	return square(units, k, k)

func phalanx(units, k = null): #фаланга
	var n
	if k == null:
		n = 3
		var t = int(units.size() / n)
		k = units.size() % n
		if  k != 0:
			k = int(t + 1)
		else:
			k = int(t)
	else:
		n = abs(units.size() / k)
		if units.size() % k != 0:
			n = int(n) + 1
	return square(units, k, n)
	
func wedge(units): #клин
	var i = 0
	var co = []  
	for unit in units:
		for k in range(i + 1):
			var f = Vector2(((-0.5 * i) + k) * (UNIT_DISTANCE + SP_SIZE), i * (UNIT_DISTANCE + SP_SIZE)) 
			co.append(f)
		i += 1
	return [co,0]
		
func carre(units): #каре
	var co = []
	var uf = []
	var t = int(units.size() / 8)
	var k = units.size() % 8 
	if k != 0:
		k = int(t + 1)
	else:
		k = int(t)
	var x_max = k + 4
	var y_max = k + 2
	for x in range(0, x_max): 
		var tmp = [] 
		for y in range(0, y_max):
			if (not(x in [0, 1, x_max - 2, x_max - 1] and (y == 0 or y == y_max - 1)) 
			and not(x >= 2 and x <= x_max - 3 and y <= y_max - 3 and y >= 2)):
				co.append(Vector2((UNIT_DISTANCE + SP_SIZE) * x, (UNIT_DISTANCE + SP_SIZE) * y))
	return [co, 0]
	
##############################################

	
func PlaceUnits(units, form = 'phalanx', result = null): #пост обработка матрицы построения
	if result == null:
		if form == 'phalanx':
			result = phalanx(units)
		if form == 'box':
			result = fill_box(units)
		if form == 'wedge':
			result = wedge(units)
		if form == 'carre':
			result = carre(units)

	var co = result[0]
	var uf = result[1]
	
	for regiment in get_regiments(units):
		propeties[regiment]['type_form'] = form
	var type_form = form
	#print(type_form)
	
	var k = 0
	var angle = null
	for unit in units:
		var matrix_pos
		if form in ['phalanx', 'box']:
			matrix_pos = co[uf[k].x][uf[k].y]  
		else:
			matrix_pos = co[k]
		if psevdoform_end_pos != null:
			if angle == null:
				if type_form == 'phalanx':
					angle = 0
				else:
					angle = psevdoform_start_pos.angle_to_point(psevdoform_end_pos) + PI
	
			var m = psevdoform_start_pos + (matrix_pos).rotated(angle)
			targets[unit] = m

		k += 1
		
func gen_units(n, tex, node): #генерация юнитов
	for i in range(n):
		var cs2d
		var kin = KinematicBody2D.new()
		var shape = CircleShape2D.new()
		shape.set_radius(25)
		cs2d = CollisionShape2D.new()
		cs2d.set_shape(shape)
		kin.add_child(cs2d)
		var sp = Sprite.new()
		sp.set_name('Sprite')
		sp.set_texture(tex)
		kin.add_child(sp)
		kin.set_name('Unit' + str(i + 1))
		node.add_child(kin)
		


func psevdoform_controller(): #управление размещением
	var d # lkm <---- d ----> o 
	var type_form = 'phalanx'
	if sel_regiment != []:
		type_form = propeties[sel_regiment[0]]['type_form']
		#print(sel_regiment,propeties)
		
	if panel.get_global_pos().y > get_viewport().get_mouse_pos().y: #1)+ panel.get_size().x
		if Input.is_action_just_pressed('target'):
			psevdoform_start_pos = get_global_mouse_pos()
		if Input.is_action_pressed('target'):
			psevdoform_end_pos = get_global_mouse_pos()
			if type_form == 'phalanx':
				d = psevdoform_end_pos.x - psevdoform_start_pos.x
				var k = int( d / (SP_SIZE + UNIT_DISTANCE) )
				if k != 0:
					psevdoform = phalanx(sel_units, k)
					update()
			else:
				if type_form == 'wedge':
					psevdoform = wedge(sel_units)
					update()
				if type_form == 'box':
					psevdoform = fill_box(sel_units)
					update()
				if type_form == 'carre':
					psevdoform = carre(sel_units)
					update()
	
		if Input.is_action_just_released('target'):
			PlaceUnits(sel_units, type_form, psevdoform)
			d = null
			psevdoform = null
			update()
			
	if panel.get_global_pos().y <= get_viewport().get_mouse_pos().y: #1) + panel.get_size().x
		d = null
		psevdoform = null
		update()

func psevdoform_draw(): #отрисовка модели размещения
	var co = []
	var uf = []
	if psevdoform != null:
		var co = psevdoform[0]
		var uf = psevdoform[1]
		var pos = 0
		var angle = null

		for unit in sel_units:	
			var type_form = propeties[get_regiments([unit])[0]]['type_form']
			var matrix_pos
			if type_form in ['phalanx', 'box']:
				matrix_pos = co[uf[pos].x][uf[pos].y]  
			else:
				matrix_pos = co[pos] 
			if angle == null:
				if type_form == 'phalanx':
					angle = 0
				else:
					angle = psevdoform_start_pos.angle_to_point(psevdoform_end_pos) + PI
			draw_rect(Rect2(psevdoform_start_pos + (matrix_pos).rotated(angle), PSEVDOFORM_UNIT_SIZE), PSEVDOFORM_COLOR) 
			pos += 1

func move_units(): #перемещение юнитов
	for unit in targets:
		if unit.get_pos().distance_to(targets[unit]) > 0:
			var pos = targets[unit] - unit.get_global_pos()
			unit.move_and_slide(pos)#.normalized()
			unit.set_rot(get_global_pos().angle_to_point(pos))

func isInsideRect(x, y, z1, z2, z3, z4): #проверка вхождения точки в прямоугольник (квадрат)
	var x1 = min(z1, z3)
	var x2 = max(z1, z3)
	var y1 = min(z2, z4)
	var y2 = max(z2, z4)
	if ((x1 <= x) && (x <= x2) && (y1 <= y) && (y <= y2)):
		return true
	else:
		return false

func unit_modulate(units, color = Color(1,1,1)): #красим войска
	for unit in units:
		var sp = unit.get_node('Sprite')
		sp.set_modulate(color)
		
func select_controller(): #управление выделением
	if panel.get_global_pos().y > get_viewport().get_mouse_pos().y: #если координаты не область UI
		if Input.is_action_just_pressed('select'): #иницилизация выделения при 1 нажатии ЛКМ
			
			for regiment in army.get_children():
				unit_modulate(regiment.get_children())
			sel_units = []
			sel_regiment = []
			
			sel_start_pos = get_global_mouse_pos()
			
		if Input.is_action_pressed('select'): #растягивание выделения на ЛКМ
			sel_end_pos = get_global_mouse_pos()
			update()
			
		if Input.is_action_just_released('select'): #при отпущенной ЛКМ выделяем все попавшие в выделение войска (не юниты, а отряды)
			if 	sel_end_pos != null:
				for regiment in army.get_children():
					for unit in regiment.get_children():
						if isInsideRect(unit.get_pos().x, unit.get_pos().y, sel_start_pos.x, sel_start_pos.y, sel_end_pos.x, sel_end_pos.y):
							unit_modulate(regiment.get_children(), Color(0,1,0,0.9))
							sel_units += regiment.get_children()
							sel_regiment += [regiment]
							break
									
			sel_start_pos = Vector2()  #убираем выделение
			sel_end_pos = null
			update()
			
	if panel.get_global_pos().y <= get_viewport().get_mouse_pos().y: #убираем выделение, если оно зашло на панель 
		sel_start_pos = Vector2()
		sel_end_pos = null
		update()

func select_draw(): #отрисовка выделения
	if sel_end_pos != null:
		draw_rect(Rect2(sel_start_pos, sel_end_pos - sel_start_pos), SELECT_COLOR)
	
func army_panel():
	var i = 1	
	for regiment in army.get_children():
		var regiment_button = armyGrid.get_node('TArmy' + str(i))
		regiment_button.set_button_icon(load(PATH_IMG_UNIT_TYPE  + 'test.png'))
		var count = regiment_button.get_node('count')
		count.set_text(str(regiment.get_child_count()))
		i += 1
											
func _ready():
	var type_unit = 'test' 
	gen_units(COUNT_UNITS, load(PATH_IMG_UNIT + type_unit + '.png'), units)
	gen_units(COUNT_UNITS, load(PATH_IMG_UNIT + type_unit + '.png'), units2)
	for regiments in get_regiments(units.get_children()):
		propeties[regiments] = {'speed':1, 'type_form':'phalanx', 'type_troop':''}
	for regiments in get_regiments(units2.get_children()):
		propeties[regiments] = {'speed':1, 'type_form':'phalanx', 'type_troop':''}
	army_panel()
	set_process(true)

func get_regiments(units): #получить объект отряда(ов) по юнитам
	var regiments = {}
	for unit in units:
		regiments[unit.get_parent()] = null
	return regiments.keys()

func _process(delta):
	psevdoform_controller()
	select_controller()
	move_units()
	
	
func _draw():
	psevdoform_draw()
	select_draw()

func _on_phalanx_pressed():
	var type_form = 'phalanx'
	PlaceUnits(sel_units, type_form)

func _on_box_pressed():
	var type_form = 'box'
	PlaceUnits(sel_units, type_form)

func _on_wedge_pressed():
	var type_form = 'wedge'
	PlaceUnits(sel_units, type_form)

func _on_carre_pressed():
	var type_form = 'carre'
	PlaceUnits(sel_units, type_form)

func _on_turn_l_pressed():
	pass
	
func _on_turn_r_pressed():
	pass
	
func _on_speed_pressed():
	pass
	#var s = panel.get_node('GridContainer/speed')
	#if speed == 1:
	#	s.set_button_icon(img_speed2)
	#else:
	#	s.set_button_icon(img_speed1)
	#	propeties[] -= 1
#var thread = Thread.new()
#thread.start(self, "move_units", [m, unit])
