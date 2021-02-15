draw_clear(c_gray);
var c = c_white;

var h = string_height("X");
draw_line(0,h, room_width,h);
draw_line(room_width/2, h, room_width/2, room_height);
draw_line(room_width/2, room_height/3, room_width, room_height/3);
draw_line(room_width/2, room_height*(2/3), room_width, room_height*(2/3));


#region Status bar
draw_text(0,0,"Test game script thingy");

var s;
switch(Event.State)
{
	case EventState.Running:	s = "Running...";	break;
	case EventState.Finished:	s = "Program complete";	break;
	case EventState.Waiting:	s = "Waiting...";		break;
	case EventState.Error:		s = "Program error!";	break;
}
draw_text(room_width/2,0,s);

#endregion


#region Command list

draw_text(5, h, "Command list");
for(var i = 0; i < ds_list_size(Event.CommandList); ++i)
{
	var thing = Event.CommandList[| i];
	var type = (Event.NamesDefined) ? Event.FunctionName[? thing.Command] : string(thing.Command);
	var data = is_undefined(thing.Data) ? "" : string(thing.Data);
	var str = type + " : " + data

	draw_text(20, h * (i + 2), str);
	
	if(!DebugReady)
	{
		DebugLineLengths[| i] = string_width(str);
	}
	
	if(DebugReady)
	{
		if(thing.Command == EventCode.JumpTo || thing.Command == EventCode.Call)
		{
			if(is_method(thing.Data))
				continue;
			
			var c = c_black;
			switch(thing.Command)
			{
				case EventCode.JumpTo: c = c_blue; break;
				case EventCode.Call: c = c_red;	break;
			}
				
			var target = ds_map_find_value(Event.JumpMap, data).Target;
			var y1 = (h * (i + 2.5));
			var x1 = 20 + string_width(str) + 5;
			var y2 = (h * (target + 2.5));
			var x2 = DebugLineLengths[| target] + 20 + 5;
			var xmax = min(max(x1,x2) + 250, (room_width / 2) - 10);
			draw_set_colour(c);
			draw_line(x1,y1, xmax, y1);
			draw_line(xmax,y1, xmax,y2);
			draw_arrow(xmax,y2, x2,y2, 5);		
			draw_set_colour(c_black);
		}
		if(thing.Command == EventCode.Return)
		{
			var inFunction = (ds_stack_size(Event.FunctionEntryPoint) > 0);
			if(inFunction)
			{
				var target = ds_stack_top(Event.ReturnPointer) + 1;
				var y1 = (h * (i + 2.5));
				var x1 = 20 + string_width(str) + 5;
				var y2 = (h * (target + 2.5));
				var x2 = DebugLineLengths[| target] + 20 + 5;
				var xmax = max(x1,x2) + 250;
				var c = c_red;
				draw_set_colour(c);
				draw_line(x1,y1, xmax, y1);
				draw_line(xmax,y1, xmax,y2);
				draw_arrow(xmax,y2, x2,y2, 5);		
				draw_set_colour(c_black);
			}
		}
	}
}
DebugReady = true;

//Draw cursor
if(Event.ProgramPointer >= 0)
{
	var iy = h * (max(0,Event.ProgramPointer) + 2);
	var shape;	// 0 = tri, 1 = circle
	var col;
	switch(Event.State)
	{
		case EventState.Running:
			shape = 0;
			col = c_green;
		break;
		case EventState.Waiting:
			shape = 0;
			col = c_orange;
		break;
		case EventState.Finished:
			shape = 1;
			col = c_green;
		break;
		case EventState.Error:
			shape = 1;
			col = c_red;
		break;
	}
	if(shape == 0)
	{
		draw_triangle_colour(2,iy+2, 18,iy+(h*0.5), 2,iy+(h-2), col,col,col, false)
		draw_triangle(2,iy+2, 18,iy+(h*0.5), 2,iy+(h-2), true);
	}
	if(shape == 1)
	{
		draw_circle_colour(h*0.5, (iy+(h*0.5)), 8, col,col, false);
		draw_circle(h*0.5, (iy+(h*0.5)), 8, true);
	}
}

#endregion

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

#region Argument
draw_text(room_width/2 + 5, room_height*(1/3), "Function arguments");
if(ds_stack_size(Event.FunctionArguments) > 0)
{
	var args = ds_stack_top(Event.FunctionArguments);
	for(var i = 0; i < ds_list_size(args); ++i)
	{
		draw_text(room_width/2 + 20, room_height*(1/3) + ((i + 1) * h), string(i) + " : " + string(args[| i]));
	}
}
#endregion

draw_line(room_width*(3/4),room_height*(1/3), room_width*(3/4), room_height*(2/3));

#region Interrupts
draw_text(room_width*(3/4)+5, room_height*(1/3), "Interrupts");

var t = "no timers";
if(Event.State == EventState.Waiting)
{
	switch(Event.WaitMode)
	{
		case EventWaitMode.Timer:
			t = "Wait timer " + string(Event.WaitTimer);
		break;
		case EventWaitMode.Memory:
			t = "Wait memory " + string(Event.WaitMemory);
		break;
	}
}
draw_text(room_width*(3/4)+20, room_height*(1/3)+h, t);

for(var i = 0; i < ds_list_size(Event.Interrupts); ++i)
{
	var interrupt = Event.Interrupts[| i];
	var type = "";
	var data = "";
	switch(interrupt.Type)
	{
		case EventInterruptType.Timer:
			type = "Timer";
			data = string(interrupt.Value.Time);
		break;
		case EventInterruptType.UI:
			type = "External";
		break;
	}
	draw_text(room_width*(3/4)+20, room_height*(1/3) + ((i + 2) * h), type + " : " + data + " : " + string(interrupt.Function));
}

#endregion

#region jump map

draw_text((room_width*0.5) + 5, (room_height*(2/3)), "Jumps")
var s = ds_map_find_first(Event.JumpMap);
for(var i = 0; i < ds_map_size(Event.JumpMap); ++i)
{
	draw_text((room_width*0.5) + 20, (room_height*(2/3))+((i + 1) * h), string(s) + " : " + string(ds_map_find_value(Event.JumpMap,s)));
	s = ds_map_find_next(Event.JumpMap, s);
}

#endregion

#region Output log

#endregion