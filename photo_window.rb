require "gtk3"

# This class's use of instance variables is atrocious.

class PhotoWindow
  Crop = Struct.new(:x, :y, :width, :height)

  def initialize
    @image = Gtk::Image.new.tap do |o|
      o.set_size_request(400, 400)
    end

    # Put @image into an event box so it can get mouse clicks and
    # drags.

    @event_box = Gtk::EventBox.new
    @event_box.add(@image)

    @scale = :fit
    @offset_x = 0
    @offset_y = 0

    @image.signal_connect("size-allocate") do |widget, rectangle|
      show_pixbuf
    end

    @event_box.signal_connect("button-press-event") do |widget, event|
      case event.type.nick
      when "button-press"
        @motion_tracker = MotionTracker.new(event)
      when "2button-press"
        zoom_to(event.x, event.y)
      end
      false
    end

    @event_box.signal_connect("motion-notify-event") do |widget, event|
      # I'm not sure how things have gotten here without
      # @motion_tracker being set, but they have.

      if @motion_tracker
        @motion_tracker.track(event)

        if @scaled_pixbuf
          @offset_x -= @motion_tracker.delta_x
          @offset_y -= @motion_tracker.delta_y
          bound_offsets
          show_scaled_pixbuf
        end
      end

      false
    end
  end

  def bound_offsets
    @offset_x = bound(
      @offset_x, 0,
      max(@scaled_pixbuf.width - @image.allocated_width, 0))

    @offset_y =
      bound(
        @offset_y, 0,
        max(@scaled_pixbuf.height - @image.allocated_height, 0))
  end

  def bound(val, min, max)
    case
    when val < min
      min
    when val > max
      max
    else
      val
    end
  end

  def max(a, b)
    a > b ? a : b
  end

  def min(a, b)
    a < b ? a : b
  end

  def set_scale(scale)
    @scale = scale
    show_pixbuf
  end

  def show_photo(filename)
    @pixbuf = filename && Gdk::Pixbuf.new(file: filename)
    show_pixbuf
    GC.start
  end

  def show_pixbuf
    if @pixbuf
      @scale_factor = compute_scale(@scale, @image, @pixbuf)
      scale_pixbuf(@scale_factor)
      bound_offsets
      show_scaled_pixbuf
    else
      @image.set_pixbuf(nil)
    end
  end

  def scale_pixbuf(scale)
    if scale != @last_scale || @pixbuf != @last_pixbuf
      @last_scale = scale
      @last_pixbuf = @pixbuf
      @scaled_pixbuf =
        @pixbuf.scale(@pixbuf.width * scale, @pixbuf.height * scale)
    end
  end

  def show_scaled_pixbuf
    @crop = Crop.new(
      @offset_x, @offset_y,
      min(@image.allocated_width, @scaled_pixbuf.width),
      min(@image.allocated_height, @scaled_pixbuf.height))
    cropped_pixbuf = Gdk::Pixbuf.new(
      @scaled_pixbuf, @crop.x, @crop.y, @crop.width, @crop.height)
    @image.set_pixbuf(cropped_pixbuf)
  end

  def compute_scale(scale, image, pixbuf)
    case scale
    when :fit
      compute_scale_to_fit(image, pixbuf)
    else
      scale
    end
  end

  def compute_scale_to_fit(image, pixbuf)
    image_width = image.allocated_width
    pixbuf_width = pixbuf.width
    width_scale = image_width.to_f / pixbuf_width

    image_height = image.allocated_height
    pixbuf_height = pixbuf.height
    height_scale = image_height.to_f / pixbuf_height

    scale = width_scale < height_scale ? width_scale : height_scale
    scale > 1 ? 1 : scale
  end

  def zoom_to(x, y)
    x, y = get_pixbuf_coords(x, y)

    crop_width = min(@image.allocated_width, @pixbuf.width)
    crop_height = min(@image.allocated_height, @pixbuf.height)

    @offset_x = x - crop_width / 2
    @offset_y = y - crop_height / 2

    set_scale(1)
  end

  def get_pixbuf_coords(x, y)
    excess_width = @image.allocated_width - @crop.width
    x = (x - excess_width / 2 + @crop.x) / @scale_factor
    excess_height = @image.allocated_height - @crop.height
    y = (y - excess_height / 2 + @crop.y) / @scale_factor
    [x, y]
  end

  # This is only for packing the window layout, yuck.
  #
  def get_widget
    @event_box
  end
end

class MotionTracker
  attr_reader :delta_x, :delta_y

  def initialize(event)
    @last_x = event.x
    @last_y = event.y
  end

  def track(event)
    @delta_x = event.x - @last_x
    @last_x = event.x
    @delta_y = event.y - @last_y
    @last_y = event.y
  end
end
