require 'fiber'

class CancelableFiber
  @@fibers = {}

  def initialize(&blk)
    @f = Fiber.new &blk
    @canceled = false

    @@fibers[@f] = self
  end
  def cancel
    @canceled = true
  end
  def resume
    return if @canceled
    @f.resume
  end
  def yield(*args)
    @f.yield(*args)
  end

  def self.inst(ruby_fiber)
    @@fibers[ruby_fiber]
  end
end

class Fiber
  class <<self
    alias :orig_current :current
  end

  # Monkey patched Fiber.current returns a CancelableFiber if the current
  # fiber is one.
  def self.current
    cur = orig_current()
    cancelable_fiber = CancelableFiber.inst(cur)
    return cancelable_fiber || cur
  end
end
