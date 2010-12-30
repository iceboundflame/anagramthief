require 'redis'
#require 'fixnum'

module RedisLockQueue
  require 'term/ansicolor'
  require 'pp'
  @c = Term::ANSIColor
  @redis = Redis.new
  @redis2 = Redis.new

  def self.log(what)
    Rails.logger.info what if Rails and Rails.logger
  end

  def self.redis_lock_key(name)
    "#{Anathief::REDIS_KPREFIX}/lock/#{name}"
  end
  def self.redis_expiry_key(name)
    "#{Anathief::REDIS_KPREFIX}/lock-expiry/#{name}"
  end

  def self.get_lock(name, how_long=15, check_every=5)
    # To get the lock:
    # 
    # [while true:]
    #   WATCH expiry
    #   GET expiry
    #   [if expiry is null or before now]
    #     (Previous lock expired)
    # 
    #     MULTI
    #       expiry = rand int
    #       DEL lock
    #       RPUSH lock 'ok'
    #     EXEC
    # 
    #     if exec failed
    #   [else] (Previous lock still active
    #   [end]
    # 
    #   BLPOP lock 5
    #   [if ok, break]
    # 
    #   (Waited 5 seconds but didn't get lock)
    #   (Let's loop again and check the expiry)
    # [loop]
    # 
    # SET expiry [now + 15 sec]

    lock_key = redis_lock_key name
    expiry_key = redis_expiry_key name
    msg_head = "RedisLockQueue #{lock_key}:"

    log @c.yellow "#{msg_head} Locking"

    # try to lock, non-blocking (perhaps no other users are using it)
    got_lock = @redis.lpop lock_key

    unless got_lock
      log @c.yellow "#{msg_head} Couldn't get the lock by non-blocking, now blocking"

      while true
        #@redis.watch expiry_key
        expiry = @redis.get expiry_key
        now = Time.now
        if !expiry or Time.at(expiry.to_i) <= now
          if expiry
            log @c.red "#{msg_head} Error: Previous lock was expired"
          else
            log @c.yellow "#{msg_head} Init'ing the first lock"
          end

          # Try to allow one blpop to succeed
          #
          # Warning: if multiple clients check expiry at same time, this could
          # allow multiple blpops through.
          #
          # But this could only happen if the lock was not released in the first
          # place -- i.e. someone crashed!
          #
          # This rare scenario could be fixed by setting a WATCH on expiry
          # before doing the GET above.
          #
          @redis.multi do
            #@redis.set expiry_key, rand(now.to_i) # if using WATCH
            @redis.del lock_key
            @redis.rpush lock_key, 'OK' # allow one blpop to succeed
          end
        else
          log @c.yellow "#{msg_head} Lock still active"
          #@redis.unwatch # if using WATCH
        end

        # BLPOP will block and time out in check_every secs
        got_lock = @redis.blpop lock_key, check_every
        break if got_lock

        log @c.red "#{msg_head} Didn't get the lock after #{check_every} seconds"
      end
    end

    log @c.yellow "#{msg_head} Acquired with TTL=#{how_long}"
    @redis.set expiry_key, (Time.now + how_long).to_i
    return true
  end

  def self.release_lock(name)
    lock_key = redis_lock_key name
    expiry_key = redis_expiry_key name
    msg_head = "RedisLockQueue #{lock_key}:"

    @redis.multi do
      @redis.del lock_key, expiry_key
      @redis.rpush lock_key, 'OK'
    end

    log @c.yellow "#{msg_head} Released"
    return true
  end

  #def self.get_lock(name)
    #lock_id = rand(Fixnum::MAX).to_s
    #key = redis_key name
    #puts "Locking #{lock_id} on #{key}"

    #@redis.rpush key, lock_id

    #puts "Subscribing to lock listener"
    #@redis.subscribe key do |on|
      #on.subscribe do |channel|
        ## need to do this on a separate connection because only unsubscribe
        ## allowed inside of a subscribe
        #if @redis2.lindex(key, 0) == lock_id
          #puts "We have the lock."
          #@redis.unsubscribe
        #end
      #end
      #on.message do |channel, message|
        #puts "Got msg #{message}"
        #if message == lock_id
          #puts "It's my turn."
          #@redis.unsubscribe
        #end
      #end
    #end

    #puts "Lock #{lock_id} acquired"
    #return lock_id
  #end

  #def self.release_lock(name)
    #key = redis_key name

    #lock_id = @redis.lpop key
    #return false unless lock_id

    #puts "Released #{lock_id} on #{key}"

    #next_lock_id = @redis.lindex(key, 0)
    #if next_lock_id
      #puts "Next up: #{next_lock_id}"
      #@redis.publish key, next_lock_id
    #else
      #puts "Lock queue is now empty"
    #end

    #return true
  #end
end
