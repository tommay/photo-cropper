require "gtk3"

class PhotoWindow
  FRAME_PIXELS = 10

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
      end
      false
    end

    @event_box.signal_connect("motion-notify-event") do |widget, event|
      # I'm not sure how things have gotten here without
      # @last_motion_coord being set, but they have.

      if @last_motion_coord
        current = get_event_coord(event)
        delta = (@last_motion_coord - current).round
        @last_motion_coord = current

        @scaled_crop = @scaled_crop.delta(delta.x, delta.y)
        @image.queue_draw
      end

      false
    end
  end

  def set_aspect(width, height)
    @crop = @crop.set_aspect(width, height)
    prepare_pixbuf
    @image.queue_draw
  end

  def show_photo(filename)
    @pixbuf = filename && GdkPixbuf::Pixbuf.new(file: filename)
    @crop = Crop.for_pixbuf(@pixbuf).set_aspect(2, 3)
    prepare_pixbuf
  end

  def prepare_pixbuf
    if @pixbuf
      scale_factor = compute_scale(@image, @crop)
      scale_pixbuf(scale_factor)
      @scaled_crop = @crop.scale_for(@scaled_pixbuf)
    else
      @scaled_pixbuf = nil
    end
    GC.start
  end

  def compute_scale(widget, crop)
    displayed_width = widget.allocated_width - 2*FRAME_PIXELS
    width_scale = displayed_width.to_f / crop.width

    displayed_height = widget.allocated_height - 2*FRAME_PIXELS
    height_scale = displayed_height.to_f / crop.height

    scale = width_scale < height_scale ? width_scale : height_scale
    scale > 1 ? 1 : scale
  end

  def scale_pixbuf(scale)
    if scale != @last_scale || @pixbuf != @last_pixbuf
      @last_scale = scale
      @last_pixbuf = @pixbuf
      @scaled_pixbuf =
        @pixbuf.scale((@pixbuf.width * scale).round,
                      (@pixbuf.height * scale).round)
      GC.start
    end
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
      width = widget.allocated_width
      height = widget.allocated_height

      cropped_pixbuf = @scaled_pixbuf.new_subpixbuf(
        @scaled_crop.left, @scaled_crop.top,
        @scaled_crop.width, @scaled_crop.height)

      # (x,y) ia the upper left widget coordinate for the cropped image.

      x = (width - cropped_pixbuf.width) / 2
      y = (height - cropped_pixbuf.height) / 2

      cr.set_source_pixbuf(cropped_pixbuf, x, y)
      cr.rectangle(x, y, cropped_pixbuf.width, cropped_pixbuf.height)
      cr.fill

      cr.set_source_rgba(0, 0, 0, 1.0)

      # Left
      cr.rectangle(0, 0, x, height)

      # Right
      cr.rectangle(x + cropped_pixbuf.width, 0, width, height)

      # Top
      cr.rectangle(0, 0, width, y)

      # Bottom
      cr.rectangle(0, y + cropped_pixbuf.height, width, height)

      cr.fill
    end

    GC.start
    false
  end
end

# Are the crop coordinates in screen coordinates in image coordinates?
# Panning the image and adjusting the frame will be done in screen
# coordinates.
# Try image coordinates.

class Crop
  attr_reader :left, :top, :width, :height

  def self.for_pixbuf(pixbuf)
    new(pixbuf, pixbuf.width.to_f / pixbuf.height,
        0, 0, pixbuf.width, pixbuf.height)
  end

  def initialize(pixbuf, aspect, left, top, width, height)
    @pixbuf = pixbuf
    @aspect = aspect
    @left = left
    @top = top
    @width = width
    @height = height
  end

  def initialize(pixbuf, aspect, left, top, width, height)
    @pixbuf = pixbuf
    @aspect = aspect
    @left = left
    @top = top
    @width = width
    @height = height
  end

  def copy(pixbuf: @pixbuf, aspect: @aspect, left: @left, top: @top,
           width: @width, height: @height)
    Crop.new(pixbuf, aspect, left, top, width, height)
  end

  def set_aspect(aspect_width, aspect_height)
    aspect = aspect_width.to_f / aspect_height.to_f
    if @height > @width
      # Existing crop is portrait.  Keep the existing height and
      # compute the width.
      height = @height
      width = height * aspect
      if width > @pixbuf.width
        # Too wide.  Maximize the width and reduce the height.
        width = @pixbuf.width
        height = width / aspect
      end
    else
      # Existing crop is landscaoe.  Keep the existing width and
      # compute the height.
      width = @width
      height = width / aspect
      if height > @pixbuf.height
        # Too high.  Maximize the height and reduce the width.
        height = @pixbuf,height
        width = height * aspect
      end
    end

    crop = copy(
      aspect: aspect, left: 0, top: 0, width: width, height: height)

    # Try to keep the same center, but don't move outside the pixbuf.

    crop.delta(@left + (@width - width)/2, @top + (@height - height)/2)
  end

  def scale_for(pixbuf)
    factor = pixbuf.width.to_f / @pixbuf.width
    copy(
      pixbuf: pixbuf,
      left: (@left * factor).to_i,
      top: (@top * factor).to_i,
      width: (@width * factor).to_i,
      height: (@height * factor).to_i)
  end

  def delta(x, y)
    left = @left + x
    top = @top + y

    # Adjust the position if it's off the pixbuf.

    left = bound(left, 0, @pixbuf.width - @width)
    top = bound(top, 0, @pixbuf.height - @height)

    copy(left: left, top: top)
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
end

Coord = Struct.new(:x, :y) do
  def -(other)
    Coord.new(self.x - other.x, self.y - other.y)
  end

  def round
    Coord.new(self.x.round, self.y.round)
  end
end
