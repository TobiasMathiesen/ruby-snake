module Timer
  def set_timer
    @time = Gosu.milliseconds
    @next_tick = @time + @rate
  end

  def tick?
    @time = Gosu.milliseconds
    set_timer if @time > @next_tick
  end
end