# Copyright © 2009 Preston Lee. All rights reserved.

lib_dir = File.join(File.dirname(__FILE__), 'library')
Dir.new(lib_dir).entries.each do |e|
  # puts "#{e} #{e.class}"
  if File::directory?(File.join(lib_dir,e)) && !['.','..'].include?(e)
    l = File.join(lib_dir, e, 'lib')
    # puts "PUSHING #{l}"
    $LOAD_PATH.unshift(l)
  end
end
# puts $LOAD_PATH

require 'star'
require 'twitter'
require 'time'


  
class TwiverseStar < Star

  
  @data_mutex = Mutex.new
  attr_accessor :line
  attr_accessor :data
  
  def draw
    $app.push_matrix
    $app.translate(@x, @y, @z)
    # puts @line
    if @data.nil?
      $app.box(8)
    else
      created = Time.parse(@data.created_at)
      if created > (Time.now - (60 * 5))
        $app.fill(38, 179, 26) # green
      elsif created > (Time.now - (60 * 30))
        $app.fill(231, 157, 80) # yellow
      else
        $app.fill(233, 80, 80) # red
      end
      
      $app.scale(3.0, 3.0, 3.0)
      size = @data.text.size
      half = size / 2
      $app.text(@data.text[0, half], 0, 0, 0)
      $app.text(@data.text[half, size], 0, 10, 0)
      # $app.scale(0.5,0.5,0.5)
      $app.text("-#{@data.user.screen_name}, #{@data.user.url}", 0, 25, 0)
    end
    # $app.sphere(10)
    $app.pop_matrix
  end
  
  
  
end

class Twiverse < Processing::App

  
  load_library :opengl
  # load_library :openssl
  # load_library 'twitter-0.6.8'

  NUM_STARS = 100;
  CAMERA_SPEED = 20 # Pixels per wall second.
  CAMERA_ROTATE_SPEED = 0.08 # Radians per wall second.
  FRAME_RATE = 30 # Target frame per second.
  
  

  attr_accessor :stars

  def setup
    library_loaded?(:opengl) ? render_mode(OPENGL) : render_mode(P3D)
    frame_rate FRAME_RATE
    
    config = YAML::load(open(ENV['HOME'] + '/.twitter/config'))['default']
    auth = Twitter::HTTPAuth.new(config['login'], config['password'], :ssl => false)
    @twitter = Twitter::Base.new(auth)
    @friends_timeline = @twitter.friends_timeline
    # puts @friends_timeline
    
    
    @mouse_last_x = nil 
    @mouse_last_y = nil
    @active = true
    @active_mutex = Mutex.new
    @stars = []
    for n in 0..NUM_STARS do
      @stars << TwiverseStar.new
    end
    
    @twitter_thread = Thread.new do
      while true do # FIXME
        # Get new data.
        # puts "Updating Twitter data. #{@twitter}"
        puts "Received #{@friends_timeline.size} records. Updating field."
        # Update available stars.
        if @friends_timeline.size > 0
          @stars.each_with_index do |star, i|
            status = @friends_timeline[i % @friends_timeline.size]
            star.data = status
            # puts "Set #{status.id} to star #{i}."
            # puts status.inspect
          end
        end
        sleep 60
      end
    end

    @physics_thread = Thread.new do
      while true do #FIXME
        now = Time.now
        @active_mutex.synchronize do
          if @active
            @stars.each do |s| s.update end
            sleep 0.010 # FIXME Wait a while between updates.
            # puts @stars.first.z
          end
        end
      end
    end

    text_font load_font("Univers66.vlw.gz"), 10.0
    
  end
  
  
  def draw
    background 0 # Paint the entire screen solid black.
    fill(255)
    color(100,255,255)
    # sphere(100)
    # text("Moving starfield demo aoenu hreouh rcohurcoeuh arochuoaentuhoe u.", 0, 0, 0)

    @stars.each do |s|
      push_matrix
      s.draw
      pop_matrix
    end
    move_camera_for_frame
  end

  def mouse_released
    @mouse_last_x = nil
    @mouse_last_y = nil
  end
  
  def mouse_dragged
    @mouse_last_x = mouse_x if @mouse_last_x.nil?
    @mouse_last_y = mouse_y if @mouse_last_y.nil?
    
    dx = @mouse_last_x - mouse_x
    dy = @mouse_last_y - mouse_y
    
    begin_camera
    if dx != 0
    # puts "#{mouse_x} #{mouse_y}"
      rotate_y radians(-dx) * 0.1
    end
    if dy != 0
      rotate_x radians(dy) * 0.1
    end
      
    end_camera
    
    @mouse_last_x = mouse_x
    @mouse_last_y = mouse_y
  end
  
  
  def key_pressed
    # puts "KEY_PRESSED: #{key_code}"
    handle_camera_change_start
    handle_pause_and_resume
  end
  
  def handle_pause_and_resume
    case key_code
    when TAB:
      @active_mutex.synchronize do
        # @stars.each do |s|
        #   @active ? s.deactivate : s.activate
        # end
        @active = !@active
      end
    end
  end
  
  def key_released
    # puts "KEY_RELEASED: #{key_code}"
    handle_camera_change_stop
  end
  
  def handle_camera_change_start
    begin_camera
    case key_code
    when UP:
      @camera_move_z = -1
    when DOWN, 's', 'o':
      @camera_move_z = 1
    when LEFT:
      @camera_move_x = -1
    when RIGHT:
      @camera_move_x = 1
    end
    
    case key
    when 'w', ',':
      @camera_move_z = -1
    when 's', 'o':
      @camera_move_z = 1
    when 'a':
      @camera_move_x = -1
    when 'd', 'e':
      @camera_move_x = 1
    when 'r', 'p':
      @camera_move_y = -1
    when 'f', 'u':
      @camera_move_y = 1
    when 'z', ';':
      @camera_rotate_z = -1
    when 'c', 'j':
      @camera_rotate_z = 1
    end
    
    end_camera
  end
  
  def handle_camera_change_stop
    begin_camera
    case key_code
    when UP, DOWN, 'w', ',', 's', 'o':
      @camera_move_z = 0
    when LEFT, RIGHT, 'a', 'd', 'e':
      @camera_move_x = 0
    end
    
    case key
    when 'w', ',', 's', 'o':
      @camera_move_z = 0
    when 'a', 'd', 'e':
      @camera_move_x = 0
    when 'r', 'p', 'f', 'u':
      @camera_move_y = 0
    when 'z', ';', 'c', 'j':
      @camera_rotate_z = 0
    end
    end_camera
  end
  
  def move_camera_for_frame
    begin_camera
    translate(@camera_move_x * CAMERA_SPEED, 0, 0) if !@camera_move_x.nil? && @camera_move_x != 0
    translate(0, @camera_move_y * CAMERA_SPEED, 0) if !@camera_move_y.nil? && @camera_move_y != 0
    translate(0, 0, @camera_move_z * CAMERA_SPEED) if !@camera_move_z.nil? && @camera_move_z != 0  
    rotate_z(@camera_rotate_z * CAMERA_ROTATE_SPEED) if !@camera_rotate_z.nil? && @camera_rotate_z != 0
    end_camera
  end
  
end

Twiverse.new :width => 1000, :height => 800, :title => "Twiverse"


