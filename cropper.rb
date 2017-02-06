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
    byebug

    # @photo_window.show_photo(args[0])
  end

  def init_ui
    # Create the widgets we actually care about and save in instance
    # variables for use.  Then lay them out.

    @photo_window = PhotoWindow.new

    # Create the top-levle window and put @photo_window in it.

    @window = Gtk::Window.new.tap do |o|
      o.title = "Cropper"
      # o.override_background_color(:normal, Gdk::RGBA::new(0.2, 0.2, 0.2, 1))
      o.set_default_size(300, 280)
      o.position = :center
    end

    @window.signal_connect("destroy") do
      Gtk.main_quit
    end

    #@window.maximize
    @window.show_all
  end
end

Cropper.new(ARGV)
Gtk.main
