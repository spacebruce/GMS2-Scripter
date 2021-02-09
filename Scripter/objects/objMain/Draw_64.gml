draw_clear(c_dkgray);
var c = c_white;

var h = string_height("X");

#region Command list

draw_text(5, h, "Command list");
for(var i = 0; i < ds_list_size(Event.CommandList); ++i)
{
	draw_text(20, h * (i + 2), string(Event.CommandList[| i]));
}
draw_circle(10, h * (Event.ProgramPointer + 2.5), 10, true);

#endregion

draw_line(room_width/2, 0, room_width/2, room_height);

#region Stack viewer

draw_text((room_width/2) + 5, h, "Stack");
var s = ds_stack_create();
ds_stack_copy(s, Event.Stack);
var i = 0;
while(ds_stack_size(s) > 0)
{
	var thing = ds_stack_pop(s);
	draw_text((room_width/2)+20, h * (i + 2), string(thing));
	++i;
}

#endregion

#region jump map

draw_text((room_width/2) + 5, (room_height/2)+h, "Jump/Call map")
var s = ds_map_find_first(Event.JumpMap);
for(var i = 0; i < ds_map_size(Event.JumpMap); ++i)
{
	draw_text((room_width/2) + 20, (room_height/2)+((i + 2) * h), string(s) + " : " + string(ds_map_find_value(Event.JumpMap,s)));
	s = ds_map_find_next(Event.JumpMap, s);
}

#endregion