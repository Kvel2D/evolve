
import haxegon.*;
using haxegon.MathExtensions;
using Lambda;

import Main.*;

enum Task {
    Task_None;
    Task_Harvest;
    Task_Dig;
    Task_Haul;
}

enum SubTask {
    SubTask_None;
    SubTask_MoveTo;
    SubTask_Do;
}

enum Carry {
    Carry_None;
    Carry_Food;
    Carry_Metal;
}

typedef UnitStats = {
    type: Int,
    hp_max: Int,
    speed: Float,
    harvest_skill: Float,
    dig_skill: Float,
};

typedef Unit = {
    id: Int,
    type: Int,
    task: Task,
    subtask: SubTask,
    subtask_timer: Int,
    subtask_timer_max: Int,
    current: Vec2i,
    prev: Vec2i,
    carry: Carry,
    hunger_timer: Int,
    age_timer: Int,

    hp: Int,
    hp_max: Int,
    speed: Float,
    harvest_skill: Float,
    dig_skill: Float,
};

class Units {
// force unindent

static inline var MOVE_SPEED_CONSTANT = 10;
static inline var HUNGER_TIMER_MAX = 10 * 60;
static inline function AGE_TIMER_MAX(): Int {
    return Random.int(20, 40);
}
static var UNIT_ID_MAX = 0;

static var show_unit_info = false;

public static var units = new Array<Unit>();
public static var unit_types = new Map<Int, UnitStats>();
public static var unit_type_counts = new Map<Int, Int>();

public static function make_unit(type: Int): Unit {
    if (!unit_types.exists(type)) {
        trace('type id ${type} doesn\'t exist');
        return null;
    }

    if (!unit_type_counts.exists(type)) {
        unit_type_counts[type] = 0;
    }
    unit_type_counts[type]++;
    structure_occupancy[base_pos.x][base_pos.y].current++;
    
    var stats = unit_types[type];

    UNIT_ID_MAX++;

    return {
        id: UNIT_ID_MAX - 1,
        type: -1,
        task: Task_None,
        subtask: SubTask_None,
        subtask_timer: 0,
        subtask_timer_max: 0,
        current: base_pos,
        prev: base_pos,
        carry: Carry_None,
        hunger_timer: HUNGER_TIMER_MAX,
        age_timer: AGE_TIMER_MAX(),
        hp: Random.int(Std.int(0.75 * stats.hp_max), stats.hp_max),
        hp_max: stats.hp_max,
        speed: stats.speed,
        harvest_skill: stats.harvest_skill,
        dig_skill: stats.dig_skill,
    }
}

public static function units_init() {
    var type_0: UnitStats = {
        type: 0,
        hp_max: 100,
        speed: 0,
        harvest_skill: 0.1,
        dig_skill: 0,
    };
    var type_1: UnitStats = {
        type: 1,
        hp_max: 100,
        speed: 0,
        harvest_skill: 0,
        dig_skill: 0.1,
    };

    unit_types[0] = type_0;
    unit_types[1] = type_1;

    for (i in 0...3) {
        var unit = make_unit(0);
        if (unit != null) {
            units.push(unit);
        }
    }

    for (i in 0...2) {
        var unit = make_unit(1);
        if (unit != null) {
            units.push(unit);
        }
    }
}

public static function get_unit_hp_avg(): Int {
    var unit_hp_total = 0;
    for (e in units) {
        unit_hp_total += e.hp;
    }
    return Math.round(unit_hp_total / units.length);
}

public static function get_hungry_units_count(): Int {
    var count = 0;
    for (e in units) {
        if (e.hunger_timer <= 0 && food_count == 0) {
            count++;
        }
    }
    return count;
}

public static function units_render() {
    if (Input.justpressed(Key.U)) {
        show_unit_info = !show_unit_info;
    }

    Text.change_size(12);
    var r = SCALE / 2;
    for (e in units) {
        var x: Float;
        var y: Float;
        if (e.subtask == SubTask_MoveTo) {
            var progress = 1 - e.subtask_timer / e.subtask_timer_max;
            x = e.prev.x + progress * (e.current.x - e.prev.x);
            y = e.prev.y + progress * (e.current.y - e.prev.y);
        } else {
            x = e.current.x;
            y = e.current.y;
        }

        if (in_view(Math.floor(x), Math.floor(y))) {
            Gfx.fillcircle(screenx(x) + r, screeny(y) + r, r * 0.35, Col.PINK);

            if (e.carry == Carry_Food) {
                Gfx.fillcircle(screenx(x) + r, screeny(y) + r * 1.1, r * 0.15, Col.YELLOW);
            } else if (e.carry == Carry_Metal) {
                Gfx.fillcircle(screenx(x) + r, screeny(y) + r * 1.1, r * 0.15, Col.BLUE);
            }

            if (show_unit_info) {
                Text.display(screenx(x) + r * 2, screeny(y), '${e.id}, ${e.task}, ${e.subtask}, ${e.subtask_timer}, ${e.carry}\n${e.hp}, ${e.hunger_timer}');
            }
        }
    }
}

public static function units_update() {
    var dead_units = new Array<Unit>();

    for (e in units) {
        // Hunger
        if (e.hunger_timer <= 0) {
            // Eat if possible
            if (food_count > 0) {
                food_count--;
                e.hunger_timer = HUNGER_TIMER_MAX;
            } else if (Random.chance(5)) {
                e.hp--;
            }
        } else {
            e.hunger_timer--;
        }

        // Aging
        e.age_timer--;
        if (e.age_timer <= 0) {
            e.age_timer = AGE_TIMER_MAX();
            e.hp--;
        }

        // Death
        if (e.hp <= 0) {
            dead_units.push(e);
            continue;
        }

        // Do task
        if (e.task == Task_None) {
            // Select new task when idle
            var closest_metal_pos = closest_resource_pos(Resource_Metal);
            var closest_food_pos = closest_resource_pos(Resource_Food);

            e.task = switch (e.carry) {
                case Carry_None: {
                    var task_prio = new Array<Task>();

                    // TODO: when >2 tasks, need to sort better
                    if (e.harvest_skill < e.dig_skill) {
                        task_prio.push(Task_Harvest);
                        task_prio.push(Task_Dig);
                    } else if (e.harvest_skill > e.dig_skill) {
                        task_prio.push(Task_Dig);
                        task_prio.push(Task_Harvest);
                    } else {
                        // Equal, tie breaker
                        if (Random.chance(50)) {
                            task_prio.push(Task_Harvest);
                            task_prio.push(Task_Dig);
                        } else {
                            task_prio.push(Task_Dig);
                            task_prio.push(Task_Harvest);
                        }
                    }

                    var selected_task = Task_None;

                    for (t in task_prio) {
                        switch (t) {
                            case Task_Harvest: {
                                if (closest_food_pos != null) {
                                    selected_task = Task_Harvest;
                                    break;
                                }
                            }
                            case Task_Dig: {
                                if (closest_metal_pos != null) {
                                    selected_task = Task_Dig;
                                    break;
                                }
                            }
                            default:
                        }
                    }

                    selected_task;
                }
                case Carry_Food: Task_Haul;
                case Carry_Metal: Task_Haul;
            };

            var destination = switch (e.task) {
                case Task_Harvest: closest_food_pos;
                case Task_Dig: closest_metal_pos;
                case Task_Haul: base_pos;
                case Task_None: base_pos;
            }

            if (destination != null) {
                e.subtask = SubTask_MoveTo;
                e.subtask_timer_max = Std.int(Math.dst(e.current.x, e.current.y, destination.x, destination.y) * MOVE_SPEED_CONSTANT * (1 - e.speed));
                e.subtask_timer = e.subtask_timer_max;
                e.prev = e.current;
                e.current = destination;

                structure_occupancy[e.prev.x][e.prev.y].current--;
                structure_occupancy[e.current.x][e.current.y].current++;
            } else {
                e.task = Task_None;
            }
        }

        if (e.subtask_timer <= 0) {
            switch (e.subtask) {
                case SubTask_MoveTo: {
                    e.subtask = SubTask_Do;
                    e.subtask_timer = switch (e.task) {
                        case Task_Harvest: Math.round(2 * 60 * (1 - e.harvest_skill));
                        case Task_Dig: Math.round(2 * 60 * (1 - e.dig_skill));
                        case Task_Haul: 0;
                        case Task_None: 0;
                    };
                    e.subtask_timer_max = e.subtask_timer;
                }
                case SubTask_Do: {
                    if (e.task == Task_Haul) {
                        switch (e.carry) {
                            case Carry_Food: food_count++;
                            case Carry_Metal: metal_count++;
                            case Carry_None:
                        }
                    }

                    e.carry = switch (e.task) {
                        case Task_Harvest: Carry_Food;
                        case Task_Dig: Carry_Metal;
                        case Task_Haul: Carry_None;
                        case Task_None: Carry_None;
                    };
                    e.task = Task_None;
                }
                case SubTask_None:
            }
        } else {
            e.subtask_timer--;
        }
    }

    // Remove dead units
    for (e in dead_units) {
        structure_occupancy[e.current.x][e.current.y].current--;
        unit_type_counts[e.type]--;
        units.remove(e);
    }
}

}