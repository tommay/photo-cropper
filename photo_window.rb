require "gtk3"

# This class's use of instance variables is atrocious.

class PhotoWindow
  def initialize
    # @image is a Gtk::DrawingArea used for getting the on-screen size
    # and for displaying a framed/cropped pixbuf with cairo.  The
    # actual widget used in layout is @event_box, obtained from
    # get_widget.

    @image= Gtk::DrawingArea.new.tap do |o|
      o.set_size_request(400, 400)
      o.signal_connect("draw") do |widget, cr|
        draw(widget, cr)
      end
    end

    # Put @image into an event box so it can get mouse clicks and
    # drags.

    @event_box = Gtk::EventBox.new
    @event_box.add(@image)

    @image.signal_connect("size-allocate") do |widget, rectangle|
      prepare_pixbuf
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
  end

  def set_aspect(width, height)
    puts "aspect #{width} #{height}"
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
    @pixbuf = filename && GdkPixbuf::Pixbuf.new(file: filename)
    prepare_pixbuf
    GC.start
  end

  def prepare_pixbuf
    if @pixbuf
      scale_factor = compute_scale(@image, @pixbuf)
      scale_pixbuf(scale_factor)
    else
      @scaled_pixbuf = nil
    end
  end

  def scale_pixbuf(scale)
    if scale != @last_scale || @pixbuf != @last_pixbuf
      @last_scale = scale
      @last_pixbuf = @pixbuf
      @scaled_pixbuf =
        @pixbuf.scale(@pixbuf.width * scale, @pixbuf.height * scale)
      GC.start
    end
  end

  def compute_scale(image, pixbuf)
    image_width = image.allocated_width
    pixbuf_width = pixbuf.width
    width_scale = image_width.to_f / pixbuf_width

    image_height = image.allocated_height
    pixbuf_height = pixbuf.height
    height_scale = image_height.to_f / pixbuf_height

    scale = width_scale < height_scale ? width_scale : height_scale
    scale > 1 ? 1 : scale
  end

  # This is only for packing the window layout, yuck.
  #
  def get_widget
    @event_box
  end

  def get_event_coord(event)
    Coord.new(event.x, event.y)
  end

  def draw(widget, cr)
    if @scaled_pixbuf
      frame_width = 20

      width = widget.allocated_width
      height = widget.allocated_height

      x = (width - @scaled_pixbuf.width) / 2
      y = (height - @scaled_pixbuf.height) / 2

      cr.set_source_pixbuf(@scaled_pixbuf, x, y)
      cr.rectangle(x, y, @scaled_pixbuf.width, @scaled_pixbuf.height)
      cr.fill

      cr.set_source_rgba(0, 0, 0, 1.0)

      # Left
      cr.rectangle(0, 0, x + frame_width, height)

      # Right
      cr.rectangle(width - (x + frame_width), 0, x + frame_width, height)

      # Top
      cr.rectangle(0, 0, width, y + frame_width)

      # Bottom
      cr.rectangle(0, height - (y + frame_width), width, y + frame_width)

      cr.fill
    end

    false
  end

  def min(a, b)
    a < b ? a : b
  end
end

Coord = Struct.new(:x, :y) do
  def -(other)
    Coord.new(self.x - other.x, self.y - other.y)
  end
end
