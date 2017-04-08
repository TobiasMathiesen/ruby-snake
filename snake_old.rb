require 'gosu'

class Player
  attr_accessor :direction, :score
  attr_reader :x, :y

  def initialize
    @head = Gosu::Image.new("head.png")
    @body = Gosu::Image.new("body.png")
    @x = @y = @angle = 0.0
    @direction = :down
    @score = 0
    @past_positions = []
  end

  def move
    case @direction
    when :right then @x += 32
    when :left then @x -= 32
    when :down then @y += 32
    when :up then @y -= 32
    end
  end

  def wrap
    if @x >= 768
      @x = 0
    elsif @x < 0
      @x = (768 - 32)
    end

    if @y >= 768
      @y = 0
    elsif @y < 0
      @y = (768 - 32)
    end
  end

  def colided?
    past = @past_positions[2..score]
    if past
      past.any? { |pos| pos == [@x, @y] }
    end
  end

  def update
    @past_positions.unshift([@x, @y])
    move
    wrap
  end

  def draw
    @head.draw(@x, @y, 1)
    @score.times do |i|
      @body.draw(@past_positions[i].first, @past_positions[i].last, 1)
    end
  end
end

class GameObject
  attr_reader :x, :y

  def initialize(x = 0, y = 0)
    @x = x
    @y = y
    @disabled = false
  end

  def disable
    @disabled = true
  end

  def disabled?
    @disabled
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

class SnakeGame < Gosu::Window
  RES = {x: 768, y: 768}
  MOVE_SPEED = 150

  def initialize
    super RES[:x], RES[:y]
    self.caption = "Snek"

    @background_image = Gosu::Image.new("background.png")
    @font = Gosu::Font.new(20)
    reset
  end

  def reset
    @player = Player.new
    @apples = []
    @time = Gosu.milliseconds
    @next_tick = @time + MOVE_SPEED
    @status = :play
    @round = 0
  end

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

  def spawn_apples
    (@round).times do
      position = {x: rand(0...24), y: rand(0...24)}
      @apples << Apple.new(position[:x] * 32, position[:y] * 32)
    end
  end

  def update
    movement_input
    @time = Gosu.milliseconds
    if @time > @next_tick && @status == :play
      @player.update

      if @player.colided?
        @status = :lost
      end

      @apples.each do |apple|
        if apple.x == @player.x && apple.y == @player.y
          apple.disable
          @player.score += 1
        end
      end

      if @apples.empty?
        @round += 1
        spawn_apples
      end

      marked_for_deletion = @apples.select { |apple| apple.disabled? }
      marked_for_deletion.each { |apple| @apples.delete(apple) }

      @time = Gosu.milliseconds
      @next_tick = @time + MOVE_SPEED
    end

    if @status == :lost
      if Gosu.button_down? Gosu:: KB_RETURN
        reset
      end
    end

  end

  def draw_hud
    @font.draw("Score: #{@player.score}", 10, 10, 1)
    if @status == :lost
      @font.draw("YOU LOST! PRESS ENTER TO PLAY AGAIN" , 225, 768 / 2.0, 1)
    end
  end

  def draw
    @background_image.draw(0, 0, 0)
    @player.draw
    @apples.each { |apple| apple.draw }
    draw_hud
  end
end

SnakeGame.new.show