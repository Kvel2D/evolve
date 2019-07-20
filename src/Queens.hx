
import haxegon.*;
using haxegon.MathExtensions;
using Lambda;

import Main.*;
import Units.*;

enum QueenMenuState {
    QueenMenuState_Closed;
    QueenMenuState_SelectQueen;
    QueenMenuState_Queen;
}

enum QueenState {
    QueenState_Active;
    QueenState_Paused;
    QueenState_Suspended;
}

class Queens {
// force unindent

// TODO: this needs to increase(double?) every queen
static inline var QUEEN_COST = 20;
static inline var CLONING_TIMER_MAX = 15 * 60;
static inline var CLONING_COST = 5;

static var queen_count = 1;
static var queen_type = new Map<Int, Int>();
static var queen_timer = new Map<Int, Int>();
static var queen_state = new Map<Int, QueenState>();

static var queen_menu_state = QueenMenuState_Closed;
static var queen_menu_selected = 0;

public static function queens_init() {
    // NOTE: free queen for testing
    queen_state[0] = QueenState_Suspended;
    queen_type[0] = 0;
}

public static function queens_status_text(): String {
    var text = '';
    for (i in 0...queen_count) {
        var cloning_progress = Math.round((1 - queen_timer[i] / CLONING_TIMER_MAX) * 100);

        text += 'queen #$i: ${cloning_progress}%';
        text += switch (queen_state[i]) {
            case QueenState_Suspended: '(suspended)';
            case QueenState_Paused: '(not enough metal)';
            case QueenState_Active: '';
        }
        text += '\n';
    }
    return text;
}

public static function queens_update() {
    // TODO: shuffle this so that queens are resumed randomly?
    // Resume active queens when there's enough metal
    for (i in queen_state.keys()) {
        switch (queen_state[i]) {
            case QueenState_Paused: {
                if (metal_count >= CLONING_COST) {
                    metal_count -= CLONING_COST;
                    queen_state[i] = QueenState_Active;
                }
            }
            case QueenState_Active: {
                if (queen_timer[i] > 0) {
                    queen_timer[i]--;
                } else {
                    units.push(make_unit(queen_type[i]));

                    queen_timer[i] = CLONING_TIMER_MAX;

                    // Begin new cycle
                    if (metal_count > CLONING_COST) {
                        metal_count -= CLONING_COST;
                    } else {
                        // Pause if not enough metal
                        queen_state[i] = QueenState_Paused;
                    }
                }
            }
            case QueenState_Suspended:
        }
    }
}

public static function queens_menu() {
    if (Input.justpressed(Key.Q)) {
        queen_menu_state = switch (queen_menu_state) {
            case QueenMenuState_Closed: QueenMenuState_SelectQueen;
            case QueenMenuState_SelectQueen: QueenMenuState_Closed;
            case QueenMenuState_Queen: QueenMenuState_Closed;
        }
    }

    if (queen_menu_state == QueenMenuState_SelectQueen) {
        Gfx.fillbox(100, 100, 500, 600, Col.ORANGE);
        GUI.x = 100;
        GUI.y = 100;
        // List queens
        for (i in 0...queen_count) {
            if (GUI.auto_text_button('Queen #${i}, cloning type ${queen_type[i]}')) {
                queen_menu_selected = i;
                queen_menu_state = QueenMenuState_Queen;
            }
        }

        // New queen button
        if (GUI.auto_text_button('Create new queen (cost ${QUEEN_COST})') && metal_count >= QUEEN_COST) {
            metal_count -= QUEEN_COST;
            var new_queen = queen_count;
            queen_count++;

            // Get first random id from current ids
            for (type in unit_types.keys()) {
                queen_type[new_queen] = type;
                break;
            }

            queen_timer[new_queen] = CLONING_TIMER_MAX;
            queen_state[new_queen] = QueenState_Suspended;
        }
    } else if (queen_menu_state == QueenMenuState_Queen) {
        Text.change_size(25);
        Gfx.fillbox(100, 100, 500, 600, Col.ORANGE);
        Text.display(110, 130, 'Queen #${queen_menu_selected}');
        Text.display(110, 160, 'Currently cloning type: ${queen_type[queen_menu_selected]}');

        var toggle_text = if (queen_state[queen_menu_selected] == QueenState_Suspended) {
            'Resume cloning';
        } else {
            'Suspend cloning';
        }

        GUI.x = 110;
        GUI.y = 200;

        if (GUI.auto_text_button(toggle_text)) {
            queen_state[queen_menu_selected] = if (queen_state[queen_menu_selected] == QueenState_Suspended) {
                QueenState_Paused;
            } else {
                QueenState_Suspended;
            }
        }

        for (i in unit_types.keys()) {
            var e = unit_types[i];

            var e_text = '${e.type}\ncount=${unit_type_counts[e.type]}\nhp=${e.hp_max}\nspeed=${e.speed}\nharvest=${e.harvest_skill}\ndig=${e.dig_skill}';
            
            if (GUI.auto_text_button(e_text)) {
                queen_type[queen_menu_selected] = e.type;
            }
        }
    }
}

}
