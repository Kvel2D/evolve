
import haxegon.*;
using haxegon.MathExtensions;
using Lambda;

import Queens.*;
import Units.*;
import Units.UnitStats;
import Units.Unit;

enum Resource {
    Resource_None;
    Resource_Food;
    Resource_Metal;
}

class Main {
// force unindent

static inline var SCREEN_WIDTH = 1000;
static inline var SCREEN_HEIGHT = 1000;
static inline var MAP_WIDTH = 100;
static inline var MAP_HEIGHT = 100;
public static inline var SCALE = 30;
static inline var VIEW_WIDTH = Math.ceil(SCREEN_WIDTH / SCALE);
static inline var VIEW_HEIGHT = Math.ceil(SCREEN_HEIGHT / SCALE);

static inline var STRUCTURE_METAL_COUNT = 5;

static var resource_map = Data.create2darray(MAP_WIDTH, MAP_HEIGHT, Resource_None);
static var structure_map = Data.create2darray(MAP_WIDTH, MAP_HEIGHT, false);
public static var structure_occupancy = Data.create2darray(MAP_WIDTH, MAP_HEIGHT, { current: 0, max: 0});
static var structure_active = Data.create2darray(MAP_WIDTH, MAP_HEIGHT, false);
public static var base_pos = {x: 10, y: 10};
public static var food_count = 0;
public static var metal_count = 10;
static var show_structure_occupancy = true;
static var camera: IntVector2 = {x: 0, y: 0};

var counts = new Map<Int, Int>();

function new() {
    Gfx.resizescreen(SCREEN_WIDTH, SCREEN_HEIGHT);

    for (x in 0...MAP_WIDTH) {
        for (y in 0...MAP_HEIGHT) {
            if (Random.chance(1)) {
                resource_map[x][y] = Resource_Food;
            } else if (Random.chance(1)) {
                resource_map[x][y] = Resource_Metal;
            }
        }
    }

    structure_map[base_pos.x][base_pos.y] = true;
    resource_map[base_pos.x][base_pos.y] = Resource_None;

    units_init();
    queens_init();

    var values_string = Data.loadtext('values.txt');
    for (i in 0...1000) {
        counts[i] = 0;
    }
    for (e in values_string) {
        var value_int = Std.parseInt(e);
        counts[value_int]++;
    }
    Gfx.createimage('graph', SCREEN_WIDTH, SCREEN_HEIGHT);
    Gfx.drawtoimage('graph');
    Gfx.fillbox(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, Col.GRAY);
    var GRAPH_SCALE = 8;
    var GRAPH_X = 100;
    var GRAPH_Y = 100;
    for (i in 0...100) {
        var count = counts[i];
        if (count > 0) {
            var x = GRAPH_X;
            var y = GRAPH_Y + i * GRAPH_SCALE;
            Gfx.fillbox(x, y, count * GRAPH_SCALE, 1 * GRAPH_SCALE, Col.BLUE);
            Gfx.drawbox(x, y, count * GRAPH_SCALE, 1 * GRAPH_SCALE, Col.DARKBLUE);
        }
    }

    for (i in 0...5) {
        Text.display(50, GRAPH_Y + i * 25 * GRAPH_SCALE, '${i * 25}');
    }

    for (i in 0...5) {
        Gfx.fillbox(0, GRAPH_Y + i * 25 * GRAPH_SCALE, 1000, 1, Col.WHITE);
    }

    Gfx.drawtoscreen();
}

var message_queue = new Array<String>();
var message_timer = 0;
static inline var MESSAGE_TIMER_MAX = 4 * 60;
function add_message(message) {
    message_queue.push(message);

    if (message_timer == 0) {
        message_timer = MESSAGE_TIMER_MAX;
    }
}

public static inline function screenx(x: Float) {
    return (x - camera.x) * SCALE;
}

public static inline function screeny(y: Float) {
    return (y - camera.y) * SCALE;
}

public static inline function in_view(x: Int, y: Int): Bool {
    return !(camera.x > x || x >= camera.x + VIEW_WIDTH || camera.y > y || y >= camera.y + VIEW_HEIGHT);
}

public static inline function in_map(x: Int, y: Int): Bool {
    return !(0 > x || x >= 0 + MAP_WIDTH || 0 > y || y >= 0 + MAP_HEIGHT);
}

public static function closest_resource_pos(resource: Resource): IntVector2 {
    var closest_pos = null;
    var closest_dst = 100000.0;
    for (x in 0...MAP_WIDTH) {
        for (y in 0...MAP_HEIGHT) {
            if (structure_active[x][y] && resource_map[x][y] == resource && structure_map[x][y] && structure_occupancy[x][y].current < structure_occupancy[x][y].max) {
                var dst = Math.dst(base_pos.x, base_pos.y, x, y);
                if (dst < closest_dst) {
                    closest_dst = dst;
                    closest_pos = {x: x, y: y};
                }
            }
        }
    }
    return closest_pos;
}

function update() {
    // Move camera
    if (Input.pressed(Key.W)) {
        camera.y--;
    }
    if (Input.pressed(Key.A)) {
        camera.x--;
    }
    if (Input.pressed(Key.S)) {
        camera.y++;
    }
    if (Input.pressed(Key.D)) {
        camera.x++;
    }

    if (Input.justpressed(Key.C)) {
        show_structure_occupancy = !show_structure_occupancy;
    }

    var mouse_x = Math.floor(Mouse.x / SCALE) + camera.x;
    var mouse_y = Math.floor(Mouse.y / SCALE) + camera.y;

    if (Mouse.leftclick()) {
        // Build structure
        if (resource_map[mouse_x][mouse_y] != Resource_None) {
            if (metal_count >= STRUCTURE_METAL_COUNT) {
                structure_map[mouse_x][mouse_y] = true;
                structure_active[mouse_x][mouse_y] = true;
                structure_occupancy[mouse_x][mouse_y] = {current: 0, max: 3};

                metal_count-= STRUCTURE_METAL_COUNT;
            } else {
                add_message('need ${STRUCTURE_METAL_COUNT} metal to build structure');
            }
        }
    } else if (Mouse.rightclick()) {
        // Suspend structure
        if (structure_map[mouse_x][mouse_y]) {
            structure_active[mouse_x][mouse_y] = !structure_active[mouse_x][mouse_y];
        }
    }

    queens_update();
    units_update();

    //
    // Render
    //
    Gfx.clearscreen(Col.GRAY);
    Gfx.fillbox(0, 0, MAP_WIDTH * SCALE, MAP_HEIGHT * SCALE, Col.GREEN);

    var x_start = camera.x;
    var x_end = camera.x + VIEW_WIDTH;
    var y_start = camera.y;
    var y_end = camera.y + VIEW_HEIGHT;

    // Render resources
    for (x in x_start...x_end) {
        for (y in y_start...y_end) {
            if (in_view(x, y) && in_map(x, y) && resource_map[x][y] != Resource_None) {
                Gfx.fillbox(screenx(x), screeny(y), SCALE, SCALE, 
                    switch (resource_map[x][y]) {
                        case Resource_Food: Col.YELLOW;
                        case Resource_Metal: Col.BLUE;
                        case Resource_None: Col.RED;
                    });
            }
        }
    }

    //
    // Render structures
    //
    var r = SCALE / 2;
    for (x in x_start...x_end) {
        for (y in y_start...y_end) {
            if (in_view(x, y) && in_map(x, y) && structure_map[x][y]) {
                var color = if (structure_active[x][y]) {
                    Col.PINK;
                } else {
                    Col.RED;
                }

                Gfx.drawcircle(screenx(x) + r, screeny(y) + r, r * 1.25, color);
                Gfx.drawline(screenx(x) + r, screeny(y) + r, screenx(base_pos.x) + r, screeny(base_pos.y) + r, Col.WHITE);
                if (show_structure_occupancy) {
                    Text.display(screenx(x) + r * 2, screeny(y) - r * 2, '${structure_occupancy[x][y].current}/${structure_occupancy[x][y].max}', Col.YELLOW);
                }
            }
        }
    }

    // Render base
    Gfx.fillbox(screenx(base_pos.x), screeny(base_pos.y), SCALE, SCALE, Col.ORANGE);

    units_render();

    //
    // Stats hud
    //
    Text.change_size(25);
    var units_status_text = 'unit hp avg: ${get_unit_hp_avg()}';
    Text.display(0, 0, '${queens_status_text()}\nunits: ${units.length}\n$units_status_text\nfood: ${food_count}\nmetal: ${metal_count}');

    var hungry_units_count = get_hungry_units_count();
    if (hungry_units_count > 0) {
        Text.display(300, 0, '${hungry_units_count}/${units.length} units are hungry, colony needs more food!');
    }

    queens_menu();

    //
    // Messages
    //
    if (message_timer > 0) {
        message_timer--;

        var progress = message_timer / MESSAGE_TIMER_MAX;
        Text.display(progress * (SCREEN_WIDTH - Text.width(message_queue[0])), progress * SCREEN_HEIGHT, message_queue[0], Col.RED);

        if (message_timer <= 0) {
            message_queue.shift();

            if (message_queue.length > 0) {
                message_timer = MESSAGE_TIMER_MAX;
            }
        }
    }

    Gfx.drawimage(0, 0, 'graph');
}

}
