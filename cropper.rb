#!/usr/bin/env ruby

require "pathname"
ENV["BUNDLE_GEMFILE"] = Pathname.new(__FILE__).realpath.dirname.join("Gemfile").to_s

require "bundler/setup"
require "set"
require "gtk3"
require "fileutils"
require "byebug"

require_relative "photo_window"

class Cropper
  def initialize(args)
    GC.start
    init_ui

    @photo_window.show_photo(args[0])
  end

  def init_ui
    # Widget creation and layout are done as distinct steps.  It's
    # possible and maybe more beautiful to things together using
    # nested "tap" blocks, but it's less maintainable.  So usig
    # distinct steps wins.

    # A stack of radiobuttons for standard crop ratios.

    radio_buttons = Gtk::Box.new(:vertical)

    ["2:3", "3:2", "1:1"].reduce(nil) do |last, aspect|
      Gtk::RadioButton.new(label: aspect, member: last).tap do |o|
        radio_buttons.pack_start(o)
        width, height = aspect.split(":").map{|n|n.to_i}
        o.signal_connect("toggled") do |widget|
          # Both the old and new radiobuttons get a toggled signal.
          # We just care about the active one.
          if widget.active?
            @photo_window.set_aspect(width, height)
          end
        end
      end
    end

    # The photo crop widget.

    @photo_window = PhotoWindow.new

    # The main window.

    window = Gtk::Window.new.tap do |window|
      window.title = "Cropper"
      window.set_default_size(300, 280)
      window.position = :center
    end

    # Lay out widgets in the main window.

    # Put the radio buttons and the photo window next to each other
    # in a horizontal box.

    Gtk::Box.new(:horizontal).tap do |hbox|
      hbox.pack_start(radio_buttons)
      hbox.pack_start(@photo_window.get_widget)
      window.add(hbox)
    end

    window.signal_connect("destroy") do
      Gtk.main_quit
    end

    #window.maximize
    window.show_all
  end
end

Cropper.new(ARGV)
Gtk.main
