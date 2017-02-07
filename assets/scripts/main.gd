extends Node2D

const COUNT_UNITS = 40
const SP_SIZE = 64
const UNIT_DISTANCE = 2
const REGIMENT_DISTANCE = 30
const PSEVDOFORM_UNIT_SIZE = Vector2(20, 20)
const PSEVDOFORM_COLOR = Color(0, 1, 0)
const SELECT_COLOR = Color(0, 1, 0, 0.24)
const PATH_IMG_UNIT = 'res://assets/art/units/'
const PATH_IMG_UNIT_TYPE = 'res://assets/art/ui/troop/'

var troops = {'infantry':{}, 'cavalry':{}, 'artillery':{}}

var img_speed1 = preload('res://assets/art/ui/speed/speed1.png')
var img_speed2 = preload('res://assets/art/ui/speed/speed2.png')

onready var panel = get_node("CanvasLayer/ui/functionalPanel")
onready var btn_speed = panel.get_node("GridContainer/speed")
onready var units = get_node('Players/Player/Units/Regiment1') 
onready var units2 = get_node('Players/Player/Units/Regiment2') 
onready var army = get_node('Players/Player/Units/') 
onready var armyGrid = get_node('CanvasLayer/ui/armyPanel/GridContainer') 

#var sel_units = []
var sel_regiment = []
var psevdoform_start_pos = Vector2()
var psevdoform_end_pos = null
var sel_start_pos = Vector2()
var sel_end_pos = null
var psevdoforms = {}

var propeties = {} #{regiment: {p:v...}}
var targets = {} #{unit: target_pos}

func get_regiments(units): #получить объект отряда(ов) по юнитам
	var regiments = {}
	for unit in units:
		regiments[unit.get_parent()] = null
	return regiments.keys()

func get_units(regiments): #получить объект юнитов по отряду
	var units = {}
	for regiment in regiments:
		for unit in regiment.get_children():
			units[unit] = null
	return units.keys()

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
	var xmax = (UNIT_DISTANCE + SP_SIZE) * m
	return [co, uf, xmax]
	
##############################################3		
		
func fill_box(regiment): #квадрат
	var units = get_units([regiment])
	var k = sqrt(units.size())
	if  (k - floor(k)) != 0:
		k = int(k) + 1
	else:	
		k = int(k)
	return square(units, k, k)

func phalanx(regiment, k = null): #фаланга
	var units = get_units([regiment])
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
	
func wedge(regiment): #клин
	var units = get_units([regiment])
	var i = 0
	var co = []  
	#for unit in units:
	while units.size() > co.size():
		for k in range(i + 1):
			var f = Vector2(((-0.5 * i) + k) * (UNIT_DISTANCE + SP_SIZE), i * (UNIT_DISTANCE + SP_SIZE)) 
			co.append(f)
		i += 1
	var xmax = (UNIT_DISTANCE + SP_SIZE) * i
	return [co,0, xmax]
		
func carre(regiment): #каре
	var units = get_units([regiment])
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
	var xmax = (UNIT_DISTANCE + SP_SIZE) * x_max
	return [co, 0, xmax]
	
##############################################

func PlaceUnits(regiments, form, result = {}): #строит юнитов по матрице
	var flag = {}
	if result.keys() != []:
		flag = result

	var xmax = 0
	for regiment in regiments:
		var units = get_units([regiment])
		
		if flag.keys() == []:
			if form == 'phalanx':
				result[regiment] = phalanx(regiment)
			elif form == 'box':
				result[regiment] = fill_box(regiment)
			elif form == 'wedge':
				result[regiment] = wedge(regiment)
			elif form == 'carre':
				result[regiment] = carre(regiment)

		var co = result[regiment][0]
		var uf = result[regiment][1]
		var type_form 
		if form != null:
			propeties[regiment]['type_form'] = form
		type_form = propeties[regiment]['type_form']
		
		var k = 0
		var angle = null

		for unit in units:
			var matrix_pos
			if type_form in ['phalanx', 'box']:
				matrix_pos = co[uf[k].x][uf[k].y]  
			else:
				matrix_pos = co[k]

			if psevdoform_end_pos != null:
				if angle == null:
					if type_form == 'phalanx':
						angle = 0
					else:
						angle = psevdoform_start_pos.angle_to_point(psevdoform_end_pos) + PI
				var m = psevdoform_start_pos + Vector2(matrix_pos.x + xmax, matrix_pos.y).rotated(angle)
				targets[unit] = m
			k += 1
		xmax = result[regiment][2] + REGIMENT_DISTANCE

func psevdoform_controller(): #управление размещением (ПКМ)
	var d # lkm <---- d ----> o 

	if panel.get_global_pos().y > get_viewport().get_mouse_pos().y: #1)+ panel.get_size().x
		if Input.is_action_just_pressed('target'):
			psevdoform_start_pos = get_global_mouse_pos()
				
		if Input.is_action_pressed('target'):
			psevdoform_end_pos = get_global_mouse_pos()
			d = psevdoform_end_pos.x - psevdoform_start_pos.x
			var k = int( d / (SP_SIZE + UNIT_DISTANCE) )
			for regiment in sel_regiment:	
				var type_form = propeties[regiment]['type_form']
				var sel_units = get_units([regiment])
				if type_form == 'phalanx':
					if k != 0:
						psevdoforms[regiment] = phalanx(regiment, k)
						update()
					else:
						psevdoforms[regiment] = phalanx(regiment)
						update()
				else:
					if type_form == 'wedge':
						psevdoforms[regiment] = wedge(regiment)
						update()
					if type_form == 'box':
						psevdoforms[regiment] = fill_box(regiment)
						update()
					if type_form == 'carre':
						psevdoforms[regiment] = carre(regiment)
						update()
	
		if Input.is_action_just_released('target'): #Строим юнитов согласно псевдоформе
			PlaceUnits(sel_regiment, null, psevdoforms)
			d = null
			psevdoforms = {}
			update()
			
	if panel.get_global_pos().y <= get_viewport().get_mouse_pos().y: #1) + panel.get_size().x
		d = null
		psevdoforms = {}
		update()

func psevdoform_draw(): #отрисовка модели размещения
	var xmax = 0
	for regiment in psevdoforms.keys():
		var co = []
		var uf = []
	
		var pos = 0
		var psvd = psevdoforms[regiment]
		var co = psvd[0]
		var uf = psvd[1]
		
		var angle = null
		
		var type_form = propeties[regiment]['type_form']
		for unit in regiment.get_children():	

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
			draw_rect(Rect2(psevdoform_start_pos + (Vector2(matrix_pos.x + xmax, matrix_pos.y)).rotated(angle), PSEVDOFORM_UNIT_SIZE), PSEVDOFORM_COLOR) 
			pos += 1
		xmax = psvd[2] + REGIMENT_DISTANCE

	
func select_controller(): #управление выделением
	if panel.get_global_pos().y > get_viewport().get_mouse_pos().y: #если координаты не область UI
		if Input.is_action_just_pressed('select'): #иницилизация выделения при 1 нажатии ЛКМ
			
			for regiment in army.get_children(): #убрать цветовое выделение при одиночном нажатии ЛКМ
				unit_modulate(get_units([regiment]))
			sel_regiment = [] #обнуляем массив выделенных отрядов
			
			sel_start_pos = get_global_mouse_pos() #задаем стартовую точку выделения
			
		if Input.is_action_pressed('select'): #растягивание выделения на ЛКМ
			sel_end_pos = get_global_mouse_pos() #задаем конечную точку выделения (в динамике - текущая)
			update()
			
		if Input.is_action_just_released('select'): #при отпущенной ЛКМ выделяем все попавшие в выделение войска (не юниты, а отряды)
			sel_end_pos = get_global_mouse_pos()#del?
			if sel_end_pos != null: #and sel_start_pos != null:
				for regiment in army.get_children(): #все что ниже выделяет отряд, если хоть 1 его юнит попал в выделение
					for unit in regiment.get_children():
						var k = 0
						if sel_start_pos.distance_to(sel_end_pos) < 64:
							k = 32
						if isInsideRect(unit.get_pos().x, unit.get_pos().y, sel_start_pos.x - k, sel_start_pos.y - k, sel_end_pos.x + k, sel_end_pos.y + k):
							unit_modulate(regiment.get_children(), Color(0,1,0,0.9))
							sel_regiment += [regiment]
							break
				
				var speed = 3
				for regiment in sel_regiment:
					if speed > propeties[regiment]['speed']:
						speed = propeties[regiment]['speed']
				if speed in [1, 3]:
					btn_speed.set_button_icon(img_speed1)
				else:
					btn_speed.set_button_icon(img_speed2)
									
			sel_start_pos = Vector2()  #обнуляем позицию выделения (сброс)
			sel_end_pos = null
			update()
			
	if panel.get_global_pos().y <= get_viewport().get_mouse_pos().y: #обнуляем позицию выделения (сброс) если оно зашло на панель (логически)
		sel_start_pos = Vector2()
		sel_end_pos = null
		update()

func move_units(): #перемещение юнитов
	for unit in targets:
		var k = propeties[get_regiments([unit])[0]]['speed']
		if unit.get_pos().distance_to(targets[unit]) > 0:
			var pos = targets[unit] - unit.get_global_pos()
			unit.move(pos.normalized() * k)#.normalized()
			#unit.set_rot(get_global_pos().angle_to_point(pos))

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

func _ready():
	var type_unit = 'test' 
	gen_units(COUNT_UNITS, load(PATH_IMG_UNIT + type_unit + '.png'), units)
	gen_units(COUNT_UNITS, load(PATH_IMG_UNIT + type_unit + '.png'), units2)
	for regiment in army.get_children():
		propeties[regiment] = {'speed':1, 'type_form':'phalanx', 'type_troop':''}
	army_panel()
	set_process(true)

func _process(delta):
	psevdoform_controller()
	select_controller()
	move_units()
	btn_autostatus()


func _draw():
	psevdoform_draw()
	select_draw()

func select_draw(): #отрисовка выделения
	if sel_end_pos != null:
		draw_rect(Rect2(sel_start_pos, sel_end_pos - sel_start_pos), SELECT_COLOR)

func unit_modulate(units, color = Color(1,1,1)): #красим войска
	for unit in units:
		var sp = unit.get_node('Sprite')
		sp.set_modulate(color)
	
func army_panel(): #заполнение панели отрядов
	var i = 1	
	for regiment in army.get_children():
		var regiment_button = armyGrid.get_node('TArmy' + str(i))
		regiment_button.set_button_icon(load(PATH_IMG_UNIT_TYPE  + 'test.png'))
		var count = regiment_button.get_node('count')
		count.set_text(str(regiment.get_child_count()))
		i += 1

func btn_autostatus(): #если войска не выделены отключает кнопки управления ими
	if sel_regiment == []:
		for name in ['phalanx', 'box', 'carre', 'wedge', 'speed', 'retreat', 'turn_l', 'turn_r']:
			var btn = panel.get_node("GridContainer/" + name)
			btn.set_disabled(true)
	else:
		for name in ['phalanx', 'box', 'carre', 'wedge', 'speed', 'retreat', 'turn_l', 'turn_r']:
			var btn = panel.get_node("GridContainer/" + name)
			btn.set_disabled(false)

func isInsideRect(x, y, z1, z2, z3, z4): #проверка вхождения точки в прямоугольник (квадрат)
	var x1 = min(z1, z3)
	var x2 = max(z1, z3)
	var y1 = min(z2, z4)
	var y2 = max(z2, z4)
	if ((x1 <= x) && (x <= x2) && (y1 <= y) && (y <= y2)):
		return true
	else:
		return false

func _on_phalanx_pressed():
	var type_form = 'phalanx'
	PlaceUnits(sel_regiment, type_form)

func _on_box_pressed():
	var type_form = 'box'
	PlaceUnits(sel_regiment, type_form)

func _on_wedge_pressed():
	var type_form = 'wedge'
	PlaceUnits(sel_regiment, type_form)

func _on_carre_pressed():
	var type_form = 'carre'
	PlaceUnits(sel_regiment, type_form)

func _on_turn_l_pressed():
	pass
	
func _on_turn_r_pressed():
	pass
	
func _on_speed_pressed():
	var speed = 3
	for regiment in sel_regiment:
		if speed > propeties[regiment]['speed']:
			speed = propeties[regiment]['speed']
		
	if speed in [1,3]:
		btn_speed.set_button_icon(img_speed2)
		for regiment in sel_regiment:
			 propeties[regiment]['speed'] = 2
	else:
		btn_speed.set_button_icon(img_speed1)
		for regiment in sel_regiment:
			propeties[regiment]['speed'] = 1
#var thread = Thread.new()
#thread.start(self, "move_units", [m, unit])
