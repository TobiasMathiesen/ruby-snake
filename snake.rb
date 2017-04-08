require 'gosu'
require_relative 'timer'

module RNGHelper
  def self.chance(percent)
    rand(0..(1.0)) < (percent / 100.0)
  end
end

class Player
  include Timer

  attr_accessor :rate, :direction, :score
  attr_reader :x, :y, :alive

  ACCEPTABLE_COLLISION = 2
  SUPER_TICKS = 50
  TICK_RATE = 200

  def initialize
    # Init head and body sprites
    @head = Gosu::Image.new("head.bmp")
    @body = Gosu::Image.new("body.bmp")

    # Init super head and super body sprites
    @super_head = Gosu::Image.new("super_head.bmp")
    @super_body = Gosu::Image.new("super_body.bmp")

    # Init positional info
    @x, @y = *SnakeGame.random_tile
    @direction = :down

    # Player score
    @score = 0

    # Player dead or alive status
    @alive = true

    # Super snake disabled by default
    @super = false
    @super_ticks_left = 0

    # Initialize timer for update cycle
    init_timer

    # Container for past tile positions
    @history = []
  end

  def update
    if tick?
      update_history
      move
      update_super if @super_ticks_left > 0
    end
  end

  def colided?
    @collision_tiles = @history[ACCEPTABLE_COLLISION..score]
    if @collision_tiles
      @collision_tiles.any? { |pos| pos == [@x, @y] }
    else
      nil
    end
  end

  def direction_to_rotation
    case @direction
    when :down then 180.0
    when :up then 0.0
    when :left then -90.0
    when :right then 90.0
    end
  end

  def enable_super
    if !@super
      @old_rate = @rate
      @rate /= 2
    end
    @super_ticks_left = SUPER_TICKS
    @super = true
  end

  def disable_super
    @rate = @old_rate
    @super = false
  end

  def kill
    @alive = false
  end

  def warp(x, y)
    @x, @y = x, y
    move # Move out of the portal it so that it wont teleport back and forth
  end

  def draw
    draw_body
    draw_head
  end

  private

  def update_super
    @super_ticks_left -= 1
    disable_super if @super && @super_ticks_left <= 0
  end

  def move
    case @direction
    when :right then @x += SnakeGame::TILE_SIZE
    when :left then @x -= SnakeGame::TILE_SIZE
    when :down then @y += SnakeGame::TILE_SIZE
    when :up then @y -= SnakeGame::TILE_SIZE
    end
    wrap
  end

  def draw_head
    half_tile_size = SnakeGame::TILE_SIZE / 2
    if @super_ticks_left % 2 == 0
      @head.draw_rot(@x + half_tile_size, @y + half_tile_size, 1, direction_to_rotation)
    else
      @super_head.draw_rot(@x + half_tile_size, @y + half_tile_size, 1, direction_to_rotation)
    end
  end

  def draw_body
    if @super_ticks_left % 2 == 0
      @score.times { |i| @body.draw(@history[i].first, @history[i].last, 1) }
    else
      @score.times { |i| @super_body.draw(@history[i].first, @history[i].last, 1) }
    end
  end

  def update_history
    @history.unshift([@x, @y])
    @history = @history[0..(@score + SuperApple::VALUE)] # Trims the history to only contain relevant past positions
  end

  def wrap
    # Is the player out of bounds on the right or left side?
    if @x >= SnakeGame::SIZE
      @x = 0
    elsif @x < 0
      @x = SnakeGame::SIZE - SnakeGame::TILE_SIZE
    end

    # Is the player out of bounds on the top or bottom side?
    if @y >= SnakeGame::SIZE
      @y = 0
    elsif @y < 0
      @y = (SnakeGame::SIZE - SnakeGame::TILE_SIZE)
    end
  end

  def init_timer
    @rate = TICK_RATE
    set_timer
  end
end

# A basic Object that all other Game Objects whould derive from
class GameObject
  include Timer

  attr_accessor :x, :y, :delete, :rate

  def initialize(x = 0, y = 0, rate = 1000)
    @x = x; @y = y
    @delete = false
    @rate = rate
    set_timer
  end

  # Marks the object for deletion, which will be cleaned up by the ObjectManager
  def delete
    @delete = true
  end

  def delete?
    @delete
  end

  def draw
    @image.draw(@x, @y, 1)
  end
end

class Apple < GameObject
  def initialize(x = 0, y = 0)
    super
    @image = Gosu::Image.new("magicapple.bmp")
  end
end

class SuperApple < GameObject
  VALUE = 2
  def initialize(x = 0, y = 0)
    super
    @image = Gosu::Image.new("superapple.bmp")
  end
end

class Hole < GameObject
  def initialize(x = 0, y = 0)
    super
    @image = Gosu::Image.new("hole.bmp")
  end
end

class Portal < GameObject
  PORTAL_DURATION = 15000

  def initialize(x = 0, y = 0, rate = PORTAL_DURATION)
    super
    @image = Gosu::Image.new("portal.bmp")
    @linked_portal = nil
  end

  def update
    delete if tick?
  end

  def linked_portal
    @linked_portal
  end

  def link_portal(portal)
    @linked_portal = portal
  end
end

class ObjectManager
  attr_reader :apples, :super_apples, :holes, :portals

  def initialize
    @round = 0
    @apples = []
    @super_apples = []
    @holes = []
    @portals = []
    @available_tiles = all_tiles
  end

  def all_tiles
    tiles_per_axis = SnakeGame::SIZE / SnakeGame::TILE_SIZE
    xy_tiles = (0..(tiles_per_axis - 1)).map { |t| t * SnakeGame::TILE_SIZE }
    xy_tiles.product(xy_tiles)
  end

  def clean_up_deleted_objects(objs)
    marked = objs.select { |obj| obj.delete? }
    marked.each { |obj| @available_tiles << [obj.x, obj.y] }
    marked.each { |obj| objs.delete(obj) }
  end

  def spawn(obj)
    position = @available_tiles.sample
    @available_tiles.delete(position)
    new_obj = yield(position)
    obj << new_obj if position
    new_obj
  end

  def create_portals
    @portal1 = spawn(@portals) { |pos| Portal.new(*pos) }
    @portal2 = spawn(@portals) { |pos| Portal.new(*pos) }

    @portal1.link_portal(@portal2)
    @portal2.link_portal(@portal1)
  end

  def update
    # Individual object updates
    portals.each { |portal| portal.update }

    # Deletes objects marked for deletion
    clean_up_deleted_objects(@apples)
    clean_up_deleted_objects(@super_apples)
    clean_up_deleted_objects(@portals)

    # Every time a round is over
    if @apples.empty?
      (@round + 1).times { spawn(@apples) { |pos| Apple.new(*pos)} }
      spawn(@super_apples) { |pos| SuperApple.new(*pos) } if RNGHelper.chance(40)
      spawn(@holes) { |pos| Hole.new(*pos) } if RNGHelper.chance(50)
      create_portals if @portals.empty? && RNGHelper.chance(30)
      @round += 1
    end
  end

  def draw
    apples.each { |apple| apple.draw }
    super_apples.each { |super_apple| super_apple.draw }
    holes.each { |hole| hole.draw }
    portals.each { |portal| portal.draw }
  end
end

class CollisionManager
  def initialize(player, obj_manager)
    @player = player
    @apples = obj_manager.apples
    @super_apples = obj_manager.super_apples
    @holes = obj_manager.holes
    @portals = obj_manager.portals
  end

  # Is the player location the same as the obj's location?
  def same_as_player?(obj)
    obj.x == @player.x && obj.y == @player.y
  end

  def on_colide(objects)
    objects.each do |obj|
      if same_as_player?(obj)
        yield(obj)
      end
    end
  end

  def update
    # Apple collision
    on_colide(@apples) do |apple|
      apple.delete
      @player.score += 1
    end

    # Super Apple collision
    on_colide(@super_apples) do |super_apple|
      super_apple.delete
      @player.score += SuperApple::VALUE
      @player.enable_super
    end

    # Hole collision
    on_colide(@holes) do |hole|
      @player.kill
    end

    # Portal collision
    on_colide(@portals) do |portal|
      @player.warp(portal.linked_portal.x, portal.linked_portal.y)
    end
  end
end

class HUD
  SCORE_LOCATION = [10, 10]
  ZORDER = 1
  LOST_MESSAGE = "You lost! Press space to play again"

  def initialize(score_font_size = 20, status_font_size = 28)
    @score_font = Gosu::Font.new(score_font_size)
    @status_font = Gosu::Font.new(status_font_size)
  end

  def draw(score, status)
    # Display player score
    @score_font.draw("Score: #{score}", *SCORE_LOCATION, ZORDER)

    # Display message if player lost
    if status == :lost
      width_in_pixels = @status_font.text_width(LOST_MESSAGE)
      height_in_pixels = @status_font.height
      center_x = (SnakeGame::SIZE / 2.0) - (width_in_pixels / 2.0)
      center_y = (SnakeGame::SIZE / 2.0) - (height_in_pixels / 2.0)
      @status_font.draw(LOST_MESSAGE, center_x, center_y, ZORDER)
    end
  end
end


class SnakeGame < Gosu::Window
  TITLE = "Snake"
  TILE_SIZE = 32
  SIZE = 512

  def self.random_tile
    tiles_per_axis = SIZE / TILE_SIZE

    x_pos = TILE_SIZE * rand(0...tiles_per_axis)
    y_pos = TILE_SIZE * rand(0...tiles_per_axis)

    [x_pos, y_pos]
  end

  def initialize
    super(SIZE, SIZE)
    self.caption = TITLE # Set the title of the window
    @background_image = Gosu::Image.new("background.png")
    
    # Start off a new game
    reset
  end

  private

  def movement_input
    if Gosu.button_down? Gosu::KB_RIGHT or Gosu::button_down? Gosu::GP_RIGHT
      @player.direction = :right
    elsif Gosu.button_down? Gosu::KB_LEFT or Gosu::button_down? Gosu::GP_LEFT
      @player.direction = :left
    elsif Gosu.button_down? Gosu::KB_DOWN or Gosu::button_down? Gosu::GP_DOWN
      @player.direction = :down
    elsif Gosu.button_down? Gosu::KB_UP or Gosu::button_down? Gosu::KB_UP
      @player.direction = :up
    end
  end

  def reset
    @player = Player.new
    @obj_manager = ObjectManager.new
    @col_manager = CollisionManager.new(@player, @obj_manager)
    @hud = HUD.new
    @status = :play
  end

  def play_again?
    Gosu.button_down? Gosu::KB_SPACE
  end

  def update
    if @status == :play
      movement_input
      @player.update
      @obj_manager.update
      @col_manager.update

      @player.kill if @player.colided?
      @status = :lost if !@player.alive
    elsif @status == :lost
      reset if play_again?
    end
  end

  def draw
    @background_image.draw(0, 0, 0)
    @player.draw
    @obj_manager.draw
    @hud.draw(@player.score, @status)
  end
end

SnakeGame.new.show
