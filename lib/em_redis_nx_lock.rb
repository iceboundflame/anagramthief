module EmRedisNxLock
  
  @signature = rand(100000).to_s
  
  def self.prefixed(key)
    "l:#{key}"
  end
  
  def self.lock_value_for(seconds = 10)
    "#{@signature}:#{Time.now.to_i + seconds}"
  end
  
  def self.locker_and_expiration(key)
    key.split(":")
  end
  
  ##
  # Yields block when locked with true. if false, lock couldn't be aquired after retries times
  # The lock expires after 60 seconds
  # Retries retries times to lock
  def self.lock(key, server, timeout = 10, retries = 3, &block)
    server.setnx(Lock.prefixed(key), Lock.lock_value_for(timeout)) do |locked|
      if locked
        # Success the lock was acquired
        block.call(true)
      else
        if retries == 0
          block.call(false)
        else
          # Let's get the lock's value
          server.get(Lock.prefixed(key)) do |lock_content|
            locked_until = locker_and_expiration(lock_content)[1]
            if locked_until.to_i > Time.now.to_i
              # We sleep until the lock expires
              EM.add_timer(locked_until.to_i - Time.now.to_i + 1) {
                lock(key, server, timeout, retries-1, &block)
              }
            else 
              # The lock has expired but wasn't released... BAD!
              server.getset(Lock.prefixed(key), Lock.lock_value_for(timeout)) do |lock_content|
                before_lock = locker_and_expiration(lock_content)[1]
                if before_lock.to_i <= Time.now.to_i
                  # Success, we aquired the previously expired lock!
                  block.call(true)
                else
                  # Dammit, it seems that someone else was even faster than us to aquire this lock.
                  EM.add_timer(before_lock.to_i - Time.now.to_i + 1) {
                    lock(key, server, timeout, retries-1, &block)
                  }
                end
              end
            end
          end
        end
      end
    end
  end
  
  
  ##
  # Release the locks, but delete thes lock only if the lock hasn't expired yet.
  def self.unlock(key, server, &block)
    server.get(Lock.prefixed(key)) do |lock_content|
      locker = locker_and_expiration(lock_content)[0]
      if locker == @signature
        # Fine, the lock was acquired by us, we can safely delete it.
        server.del(Lock.prefixed(key)) do |res|
          block.call(false)
        end
      else
        # it seems that somebody acquired this lock, let's not delete it.
        block.call(true)
      end
    end
  end
  
end
