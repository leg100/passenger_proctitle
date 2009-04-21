module PhusionPassenger
module Railz
    
  # Passenger app instance process title modification.  
  class Proctitler
      
    # Initializes titler.    
    def initialize(rails_root, prefix)
      @prefix = prefix
      @rails_root = rails_root
      @mutex = Mutex.new
      @titles = []
      @queue_length = 0
      @request_count = 0
    end
    
    # Returns rails_root used in title.
    def rails_root
      @rails_root
    end
    
    # Return rails_root used in title.
    def rails_root=(new_rails_root)
      @rails_root = new_rails_root
    end
    
    def request(&block)
      titles, mutex = @titles, @mutex
      mutex.synchronize do
        @queue_length += 1
        titles.push(self.title)
      end
      begin
        yield
      ensure
        mutex.synchronize do
          @queue_length -= 1
          @request_count += 1
          self.title = titles.pop || "xxx"
        end
      end
    end
    
    # Reports process as being idle.
    def set_idle
      self.title = "idle"
    end

    # Reports process as handling a socket.
    def set_handling(params)
      address = params['REMOTE_ADDR']
      method = params['REQUEST_METHOD']
      path = params['REQUEST_URI']
      path = "#{path[0, 60]}..." if path.length > 60
      self.title = "handling #{address}: #{method} #{path}"
    end
    
    # Returns current title
    def title
      @title
    end
    
    # Sets process title.
    def title=(title)
      @title = title
      update_process_title
    end
    
    # Updates the process title.
    def update_process_title
      title = "#{@prefix} ["
      title << (@rails_root ? "#{@rails_root}" : "?")
      title << "|#{@queue_length}"
      title << "|#{@request_count}"
      title << "]: #{@title}"
      $0 = title
    end

  end
  
  class RequestHandler
    
    def main_loop_with_proctitle
      @titler = Proctitler.new( Object::RAILS_ROOT, "passenger" )
      @titler.set_idle
      main_loop_without_proctitle
    end
    
    alias_method :main_loop_without_proctitle, :main_loop
    alias_method :main_loop, :main_loop_with_proctitle

  	def process_request_with_proctitle(headers, input, output)
  	  @titler.request do
        @titler.set_handling(headers)
        return process_request_without_proctitle(headers, input, output) 
      end
  	end
  	
    alias_method :process_request_without_proctitle, :process_request
    alias_method :process_request, :process_request_with_proctitle
  end

end # module Railz
end # module PhusionPassenger