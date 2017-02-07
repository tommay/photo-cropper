require "gtk3"

# This class's use of instance variables is atrocious.

class PhotoWindow
  Crop = Struct.new(:x, :y, :width, :height)

  def initialize
    # @image is a Gtk::Image used for getting the on-screen size and for
    # displaying a pixbuf with @image.set_pixbuf.  The actuaal widget used
    # in layout is @event_box, obtained from get_widget.

    @image = Gtk::Image.new.tap do |o|
      o.set_size_request(400, 400)
    end

    # Put @image into an event box so it can get mouse clicks and
    # drags.

    @event_box = Gtk::EventBox.new
    @event_box.add(@image)

    # @scale can be either :fit to fit the photo to the available
    # screen space, or a nuneric scale factor.  In practice this will
    # either be :fit, or 1 to display a portion of the image without
    # scaling.

    @scale = :fit

    # @offset is the upper left corner of the image to display.

    @offset = Coord.new(0, 0)

    @image.signal_connect("size-allocate") do |widget, rectangle|
      show_pixbuf
    end

    @event_box.signal_connect("button-press-event") do |widget, event|
      case event.type.nick
      when "button-press"
        @last_motion_coord = get_event_coord(event)
      when "2button-press"
        zoom_to(get_event_coord(event))
      end
      false
    end

    @event_box.signal_connect("motion-notify-event") do |widget, event|
      # I'm not sure how things have gotten here without
      # @last_motion_coord being set, but they have.

      if @last_motion_coord
        current = get_event_coord(event)
        delta = current - @last_motion_coord
        @last_motion_coord = current

        if @scaled_pixbuf
          @offset = bound_offset(@offset - delta)
          show_scaled_pixbuf
        end
      end

      false
    end
  end

  def bound_offset(offset)
    x = bound(
      offset.x, 0,
      max(@scaled_pixbuf.width - @image.allocated_width, 0))

    y = bound(
      offset.y, 0,
      max(@scaled_pixbuf.height - @image.allocated_height, 0))

    Coord.new(x, y)
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
      @offset = bound_offset(@offset)
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
      @offset.x, @offset.y,
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

  def zoom_to(event_coord)
    # Pan to event_coord

    pixbuf_coord = get_pixbuf_coord(event_coord)

    crop_width = min(@image.allocated_width, @pixbuf.width)
    crop_height = min(@image.allocated_height, @pixbuf.height)

    @offset = pixbuf_coord - Coord.new(crop_width / 2, crop_height / 2)

    # And zoom to full scale.

    set_scale(1)
  end

  def get_pixbuf_coord(event_coord)
    excess_width = @image.allocated_width - @crop.width
    x = (event_coord.x - excess_width / 2 + @crop.x) / @scale_factor
    excess_height = @image.allocated_height - @crop.height
    y = (event_coord.y - excess_height / 2 + @crop.y) / @scale_factor
    Coord.new(x, y)
  end

  # This is only for packing the window layout, yuck.
  #
  def get_widget
    @event_box
  end

  def get_event_coord(event)
    Coord.new(event.x, event.y)
  end
end

Coord = Struct.new(:x, :y) do
  def -(other)
    Coord.new(self.x - other.x, self.y - other.y)
  end
end
