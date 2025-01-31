//Slight error may happen, since I forget to copy the final version from the lab computer to my own; therefore, I wrote it agian without FPGA test. I also include the project in final floder.
module finalsnakes(
	input [9:0] SW,
	input [3:0] KEY,
	input CLOCK_50,
	input PS2_DAT,
	input PS2_CLK,
	output [17:0] LEDR,
	output VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N,
	output [9:0] VGA_R, VGA_G, VGA_B,
	output [6:0] HEX0, HEX1,
);

	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	
	wire [7:0] key_input;
	wire plot;
	wire clk;
	assign clk = CLOCK_50;
	wire mv_left, mv_right, mv_down, mv_up;
	
	wire press_button;
	assign press_button = mv_left || mv_right || mv_down || mv_up;
	wire [1:0] direction;
	wire grow;
	wire dead;
wire collision;
wire [1023:0] snake_x;
wire [1023:0] snake_y;
wire [7:0] snake_size;
wire [6:0] apple_y;
wire [7:0] apple_x;
wire [27:0] counter;
wire resetn;
wire [7:0] key_input;
assign resetn = 1'b1;
wire [4:0] state;
wire [4:0] prev_state;
assign LEDR[4:0] = state;
wire [13:0] random_out;

input_control i0(
.switch(SW[0]),
.key_input(key_input[3:0]),
.keys(KEY[3:0]),
.mv_left(mv_left),
.mv_right(mv_right),
.mv_down(mv_down),
.mv_up(mv_up),
);


vga_adapter VGA(
			.resetn(resetn),
			.clock(clk),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(plot),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";

	keyboard kb(
		.mapped_key(key_input[7:0]),
		.kb_clock(PS2_CLK),
		.kb_data(PS2_DAT)
	);
		
control c0(
.clk(clk),
.press_button(press_button),
.counter(counter),
.mv_left(mv_left),
.mv_right(mv_right),
.mv_down(mv_down),
.mv_up(mv_up),
.snake_x(snake_x),
.snake_y(snake_y),
.snake_size(snake_size),
.apple_x(apple_x),
.apple_y(apple_y),
.plot(plot),
.grow(grow),
.dead(dead),
.direction(direction),
.curr_state(state),
.prev_state(prev_state),
.collision(collision),
);

datapath d0(
.clk(clk),
.direction(direction),
.grow(grow),
.dead(dead),
.random_in(random_out),
.LEDR(LEDR[17:5]),
.counter(counter),
.snake_x(snake_x),
.snake_y(snake_y),
.snake_size(snake_size),
.apple_x(apple_x),
.apple_y(apple_y),
.draw_x(x),
.draw_y(y),
.colour(colour),
.current_state(state),
.prev_state(prev_state),
.collision(collision),
);

wire slow_clk;
wire [27:0] max;
assign max = 27'd50000;

rate_divider r0(
.enable(slow_clk),
.par_load(1'b0),
.max(max),
.clk(clk)
);


random random(
.clock(CLOCK_50),
.max_number(14'b11111111111111),
.num_out(random_out)
);

HEX h0(
.B(snake_size[3:0]),
.HEX(HEX0)
);

HEX h1(
.B(snake_size[7:4]),
.HEX(HEX1)
);

endmodule

module control(
input clk,
input press_button,
input [27:0] counter,
input mv_left, mv_right, mv_down, mv_up,
input [1023:0] snake_x, 
input [1023:0] snake_y,
input [7:0] snake_size,
input [7:0] apple_x,
input [6:0] apple_y,
input collision,
output reg plot,
output reg grow,
output reg dead,
output reg [1:0] direction,
output [4:0] curr_state, prev_state
);

reg [4:0] previous_state, current_state, next_state;
wire vsync_wire;
localparam  S_STARTING = 4'd0,
				S_STARTING_WAIT= 4'd1,
				S_LOAD_GAME	= 4'd2,
				S_MAKE_APPLE= 4'd3,
				S_CLR_SCREEN= 4'd4,
				S_DRAW_WALLS = 4'd5,
				S_DRAW_APPLE= 4'd6,
				S_DRAW_SNAKE = 5'd7,
				S_MOVING	= 4'd8,
				S_MUNCHING = 4'd9,
				S_MAKE_APPLE_X = 4'd10,
				S_MAKE_APPLE_Y = 4'd11,
				S_DEAD = 4'd12,
				S_DELAY = 5'd13,
				S_COLLISION_CHECK = 4'd14;

localparam  LEFT = 2'b00,
            RIGHT = 2'b01,
			   DOWN 	= 2'b10,
			   UP = 2'b11;	

wire [27:0] CLR_SCREEN_MAX,DRAW_SNAKE_MAX,DRAW_WALLS_MAX,COLLISION_MAX;
wire [27:0] DELAY_MAX;
assign CLR_SCREEN_MAX = 28'd32_000;
assign DRAW_WALLS_MAX = 28'd32_000;
assign DRAW_SNAKE_MAX = snake_size;
assign COLLISION_MAX = snake_size + 1;

delay d0(
.snake_size(snake_size),
.base_ticks(28'd8_000_000 - 1),
.delay_max(DELAY_MAX)
);

rate_divider vsync(
.clk(clk),
.enable(vsync_wire),
.max(DELAY_MAX),
.par_load(1'b0)
);

always@(*)
begin: state_table
case (current_state)
S_STARTING: next_state = press_button ? S_STARTING_WAIT : S_STARTING;
S_STARTING_WAIT: next_state = press_button ? S_STARTING_WAIT : S_LOAD_GAME;
S_LOAD_GAME: next_state = S_MAKE_APPLE_X;
S_MAKE_APPLE_X: next_state = S_MAKE_APPLE_Y;
S_MAKE_APPLE_Y: next_state = S_CLR_SCREEN;


S_CLR_SCREEN: begin
if (counter == CLR_SCREEN_MAX)
next_state = S_DRAW_WALLS;
else
next_state = S_CLR_SCREEN;
end

S_DRAW_WALLS: begin
if (counter == DRAW_WALLS_MAX)
next_state = S_DRAW_APPLE;
else
next_state = S_DRAW_WALLS;
end

S_DRAW_APPLE: next_state = S_DRAW_SNAKE;

S_DRAW_SNAKE: begin
if (counter == DRAW_SNAKE_MAX)
next_state = S_DELAY;
else
next_state = S_DRAW_SNAKE;
end

S_DELAY: begin
if (counter == DELAY_MAX)
next_state = S_MOVING;
else
next_state = S_DELAY;
end

S_MOVING: begin
if (collision)
next_state = S_DEAD;
else if(snake_x[7:0] == apple_x[7:0] && snake_y[7:0] == {1'b0, apple_y[6:0]})
next_state = S_MUNCHING;
else
next_state = S_COLLISION_CHECK;
end

S_COLLISION_CHECK: begin
if (counter == COLLISION_MAX)
next_state = S_CLR_SCREEN;
else
next_state = S_COLLISION_CHECK;
end

S_MUNCHING: next_state = S_MAKE_APPLE_X;

S_DEAD: next_state = press_button ? S_STARTING : S_DEAD;

default: next_state = S_STARTING;				
endcase
end

always @(*)				
begin: enable_signals
plot = 1'b0;
grow = 1'b0;
dead = 1'b0;
case (current_state)
S_CLR_SCREEN: begin
plot = 1'b1;
end
S_DRAW_WALLS: begin
plot = 1'b1;
end
S_DRAW_APPLE: begin
plot = 1'b1;
end
S_DRAW_SNAKE: begin
plot = 1'b1;
end
S_MOVING: begin
if (mv_left && direction != RIGHT)
direction = LEFT;
else if (mv_right && direction != LEFT)
direction = RIGHT;
else if (mv_down && direction != UP)
direction = DOWN;
else if (mv_up && direction != DOWN)
direction = UP;			
end

S_MUNCHING: begin
grow = 1'b1;
end

S_DEAD: begin
dead = 1'b1;
plot = 1'b1;
end

default: begin 
plot = 1'b0;
grow = 1'b0;
dead = 1'b0;
end
endcase
end

always@(posedge clk)
begin:state_FFS
previous_state <= current_state;
current_state <= next_state;
end

assign curr_state = current_state;
assign prev_state = previous_state;

endmodule


module datapath(
input clk,
input [1:0] direction,
input grow, dead,
input [4:0] current_state, prev_state,
input [13:0] random_in,
output [12:0] LEDR,
output reg [27:0] counter,
output reg [1023:0] snake_x,
output reg [1023:0] snake_y,
output reg [7:0] snake_size,
output reg [7:0] apple_x,
output reg [6:0] apple_y,
output reg [2:0] colour,
output reg [7:0] draw_x,
output reg [6:0] draw_y,
output reg collision
);
reg [1:0]snake_dir;
reg [1:0]last_dir;

localparam  LEFT = 2'b00,
            RIGHT = 2'b01,
				DOWN = 2'b10,
				UP = 2'b11;
localparam  S_STARTING = 4'd0,
				S_STARTING_WAIT= 4'd1,
				S_LOAD_GAME	= 4'd2,
				S_MAKE_APPLE= 4'd3,
				S_CLR_SCREEN= 4'd4,
				S_DRAW_WALLS = 4'd5,
				S_DRAW_APPLE= 4'd6,
				S_DRAW_SNAKE = 5'd7,
				S_MOVING	= 4'd8,
				S_MUNCHING = 4'd9,
				S_MAKE_APPLE_X = 4'd10,
				S_MAKE_APPLE_Y = 4'd11,
				S_DEAD = 4'd12,
				S_DELAY = 5'd13,
				S_COLLISION_CHECK = 4'd14;
reg [2:0] snake_colour;
reg [2:0] apple_colour;
reg [1023:0] snake_draw_x;
reg [1023:0] snake_draw_y;
reg [2:0] snake_draw_colour;

always @(posedge clk)
begin: enable_signals
snake_colour = 3'b111;
if(prev_state != current_state)
begin
counter = 28'd0;
snake_draw_x = snake_x;
snake_draw_y = snake_y;
snake_draw_colour = snake_colour;	
end

case (current_state)
S_STARTING: 
begin
end

S_STARTING_WAIT: 
begin
end

S_LOAD_GAME: begin
collision = 1'b0;

snake_x[7:0] = 8'd30;
snake_y[6:0] = 7'd20;
snake_x[15:8] = 8'd31;
snake_y[14:8] = 7'd20;
snake_x[23:16] = 8'd32;
snake_y[22:16] = 7'd20;
snake_x[31:24] = 8'd33;
snake_y[30:24] = 7'd20;
snake_x[39:32] = 8'd34;
snake_y[38:32] = 7'd20;
snake_x[1023:40] = 0;
snake_y[1023:39] = 0;

snake_size = 8'd5;				
end

S_MAKE_APPLE_X: begin
if(random_in[6:0] >= 7'd100)
begin
apple_x[7:0] <= random_in[6:0] + 8'd2 - 7'd100;
end
else
begin
apple_x[7:0] <= random_in[6:0] + 8'd2;
end

if(apple_x[2:0] > 3'b000)
apple_colour = apple_x[2:0];
else
apple_colour = 3'b100;
end

S_MAKE_APPLE_Y: begin
if(random_in[13:7] >= 7'd100)
begin
apple_y[6:0] <= random_in[13:7] + 7'd2 - 7'd100;
end

else
begin
apple_y[6:0] <= random_in[13:7] + 7'd2;
end

end

S_CLR_SCREEN: begin
colour = 3'b000;
draw_x = counter[14:7];
draw_y = counter[6:0]; 
counter = counter + 1'b1;
end

S_DRAW_WALLS: 
begin
colour = 3'b001;
if(counter[14:7] < 8'd2 || counter[14:7] > 8'd119 || counter[6:0] < 7'd2 || counter[6:0] > 7'd117)
begin 
draw_x = counter[14:7];
draw_y = counter[6:0];
end
counter = counter + 1'b1;
end

S_DRAW_APPLE: begin
colour = apple_colour[2:0];
draw_x = apple_x;
draw_y = apple_y;
end

S_DRAW_SNAKE: begin
colour = snake_draw_colour[2:0];
draw_x = snake_draw_x[7:0];
draw_y = snake_draw_y[6:0];
snake_draw_x = snake_draw_x >> 8;
snake_draw_y = snake_draw_y >> 8;
counter = counter + 1'b1;
end

S_DELAY: begin
counter = counter + 1'b1;
end

S_MOVING: begin
if(direction != last_dir)
begin
last_dir <= direction;
snake_dir <= direction;
end

if (snake_dir == LEFT)
begin
snake_x = snake_x << 8;
snake_y = snake_y << 8;
snake_x[7:0] = snake_x[15:8] - 1'b1;
snake_y[7:0] = snake_y[15:8];
end

else if (snake_dir == RIGHT)
begin
snake_x = snake_x << 8;
snake_y = snake_y << 8;
snake_x[7:0] = snake_x[15:8] + 1'b1;
snake_y[7:0] = snake_y[15:8];
end

else if (snake_dir == DOWN)
begin
snake_x = snake_x << 8;
snake_y = snake_y << 8;
snake_x[7:0] = snake_x[15:8];
snake_y[7:0] = snake_y[15:8] + 1'b1;
end

else if (snake_dir == UP)
begin
snake_x = snake_x << 8;
snake_y = snake_y << 8;
snake_x[7:0] = snake_x[15:8];
snake_y[7:0] = snake_y[15:8] - 1'b1;
end
end

S_MUNCHING: begin
snake_size = snake_size + apple_colour[2:0];
end

S_COLLISION_CHECK: begin
if(counter<snake_size)
begin
if(snake_x[7:0] == snake_draw_x[7:0] && snake_y[7:0] == snake_draw_y[7:0] && counter != 0)
collision = 1'b1;

snake_draw_x = snake_draw_x >> 8;
snake_draw_y = snake_draw_y >> 8;
end

else
begin
if(snake_x[7:0] < 8'd2 || snake_x[7:0] > 8'd119 || snake_y[7:0] < 8'd2 || snake_y[7:0] > 8'd117)
collision = 1'b1;
end
	counter = counter + 1;
end

S_DEAD: begin
end

endcase
end
endmodule

module random(clock, max_number, num_out);
input clock;
input [13:0] max_number;
output [13:0] num_out;
reg [13:0] counter;
assign num_out = counter;

always @(posedge clock)
begin
if(counter == max_number)
begin
counter <= 8'd0;
end
else
begin
counter <= counter + 1'b1;
end
end
endmodule

module rate_divider(enable, par_load, max, clk);
input par_load, clk;
input [27:0] max;
output reg enable;
    
reg [27:0] counter;
always @(posedge clk) 
begin
enable <= 0;
if (par_load == 1'b1) 
counter <= max; 
else if (counter == 0) 
begin
counter <= max; 
enable <= 1; 
end
else 
counter <= counter - 1'b1;
end
endmodule

module delay(
input [7:0] snake_size,
input [27:0] base_ticks,
output [27:0] delay_max
);

assign delay_max = base_ticks - (snake_size * 40_000);
	
endmodule

module keyboard(mapped_key, kb_clock, kb_data);
	input kb_clock, kb_data;
	output [7:0] mapped_key;

	reg [10:0] make_code;
	reg [8:0] scan_code;
	reg [7:0] prev_scan_code;

	localparam ZERO = 5'd0, KEY_BITS = 5'd11;
	reg [5:0] counter = ZERO;

	localparam ESCAPE = 8'hE0;

	always@(negedge kb_clock)
		begin: input_detection
			make_code[counter] = kb_data;
			counter = counter + 1'd1;
			if (counter == KEY_BITS)
				begin
					if (prev_scan_code == ESCAPE)
						begin
							scan_code <= {1'b1, make_code[8:1]};
							prev_scan_code <= make_code[8:1];
						end
					else if (prev_scan_code != ESCAPE && make_code[8:1] != ESCAPE)
						begin
							scan_code <= {1'b0, make_code[8:1]};
							prev_scan_code <= make_code[8:1];
						end
					else
						prev_scan_code <= make_code[8:1];
					counter = ZERO;
				end
		end

	localparam
			   KEY_W = {1'b0, 8'h1D},
			   KEY_A = {1'b0, 8'h1C},
			   KEY_S = {1'b0, 8'h1B},
			   KEY_D = {1'b0, 8'h23};

	localparam OUT_UP = 8'b0001,
			   OUT_DOWN = 8'b0010,
			   OUT_LEFT = 8'b0100,
			   OUT_RIGHT = 8'b1000,
			   OUT_NONE = 8'h0;

	reg [7:0] mapped_key;
	always@(*)
		begin
			mapped_key = OUT_NONE;
			case(scan_code)
				KEY_W: mapped_key = OUT_UP;
				KEY_S: mapped_key = OUT_DOWN;
				KEY_A: mapped_key = OUT_LEFT;
				KEY_D: mapped_key = OUT_RIGHT;
				default: mapped_key = mapped_key;
			endcase
		end
endmodule

module input_control(
input switch,
input [3:0] key_input,
input [3:0] keys,
output reg mv_left, mv_right, mv_down, mv_up
);
always @(switch)
begin
if(switch)
begin
mv_left = key_input[2];
mv_right = key_input[3];
mv_down = key_input[1];
mv_up = key_input[0];
end
else
begin
mv_left = ~keys[3];
mv_right = ~keys[0];
mv_down = ~keys[2];
mv_up = ~keys[1];
end
end
endmodule

module HEX(HEX, B);
input [3:0] B;
output [6:0] HEX;

     assign HEX[0] = (B[0] & B[1] & ~B[2] & B[3]) | (~B[0] & ~B[1] & B[2] & ~B[3]) | (B[0] & ~B[1] & B[2] & B[3]) | (B[0] & ~B[1] & ~B[2] & ~B[3]);
     assign HEX[1] = ~B[0] & B[2] & B[3] | ~B[0] & B[1] & B[2] | B[0] & B[1] & B[3] | B[0] & ~B[1] & B[2] & ~B[3];
	  assign HEX[2] = ~B[0] & B[1] & ~B[2] & ~B[3] | ~B[0] & B[2] & B[3] | B[1] & B[2] & B[3];
	  assign HEX[3] = ~B[0] & ~B[1] & B[2] & ~B[3] | ~B[0] & B[1] & ~B[2] & B[3] | B[0] & B[1] & B[2] | B[0] & ~B[1] & ~B[2] & ~B[3];
	  assign HEX[4] = ~B[1] & B[2] & ~B[3] | B[0] & ~B[3] | B[0] & ~B[1] & ~B[2];
     assign HEX[5] = B[1] & ~B[2] & ~B[3] | B[0] & ~B[2] & ~B[3] | B[0] & B[1] & ~B[3] | B[0] & ~B[1] & B[2] & B[3];
	  assign HEX[6] = ~B[1] & ~B[2] & ~B[3] | ~B[0] & ~B[1] & B[2] & B[3] | B[0] & B[1] & B[2] & ~B[3];

endmodule



