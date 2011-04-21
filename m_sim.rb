#!/usr/bin/env shoes
#require 'rubygems'
#require 'ruby-debug'

#
# Author: Joshua Kovach
# Course: CIS 452
# Date:   21 April 2011
# Description:
#   Implements a simulated process manager which supports non-contiguous memory
#   paging for process loading. GUI is built using the Shoes toolkit for Ruby.
#   Project specs are listed at:
#     http://www.cis.gvsu.edu/~dulimarh/CS452/Projects/MM/
#

# a class represenging a page in memory with size 512 bytes
class MemSegment
  attr_accessor :filled, :pid, :seg, :seg_id

  def initialize(filled=false, pid=nil, seg=nil, seg_id=0)
    @filled = filled
    @pid = pid.to_i
    @seg = seg.to_s
    @seg_id = seg_id.to_i
    self
  end

  # fill the page with a segment from the process
  def fill(pid, seg, seg_id)
    @filled = true; @pid = pid; @seg = seg; @seg_id = seg_id;
    self
  end

  # remove the any process from the memory page
  def clear
    self.filled = false; self.pid = nil; self.seg = nil;
    self
  end

  def filled?
    @filled
  end

  def to_s
    filled? ? "#{seg} #{seg_id} for pid #{pid}" : "Free"
  end
end

# a simple simulated process with a pid, a code segment of a given size, and a
# data segment of a given size which can be loaded into memory. These are
# enumerable so as to be stepped through in an easy way by the manager.
class SimProc
  include Enumerable
  attr_accessor :pid, :code, :data

  def initialize(pid, code, data)
    @pid = pid.to_i
    @code = code.to_i
    @data = data.to_i
  end

  # a way to retrieve each segment without specifying what segment it is
  def each
    yield :code, code
    yield :data, data
  end

  def to_s
    "[SimProc :pid => #{pid}, :code => #{code}, :data => #{data}]"
  end

  # necessary for requeueing into the execution list
  def to_a
    [@pid, @code, @data]
  end
end

# the memory manager class is the controller which determines when, where, and
# how processes are loaded into memory, when they can't be loaded, how to reload,
# and when to clear them from memory.
class Manager
  attr_reader :segments, :processes, :exec_list, :exec_object, :feedback

  def initialize
    @exec_list = []
    @processes = {}
    @segments = Array.new(8) { MemSegment.new }
    @feedback = ""
  end

  def print_activity
    @segments.each_with_index {|s, index| puts "Seg #{index} => #{s}" }
    @processes.each_value {|s| puts s }
  end

  def load_process(pcb, exec_index)
    # attempt to load the process's code and data segments into memory
    # if there is not enough memory, the load will be rolled back and the
    # process will be queued to run at a later time.
    if pcb.size == 3
      p = SimProc.new(*pcb)
      bad_load = false

      @processes.store p.pid, p
      @processes[p.pid].each do |proc_seg, bsize|
        (bsize / 512.0).ceil.times do |seg_id|
          @segments.each_with_index do |s, index|
            if !s.filled
              #find the first empty memory segment
              s.fill p.pid, proc_seg, seg_id
              @feedback += "Incoming process #{p.pid} with #{proc_seg} segment loaded to page #{seg_id}\n"
              break
            # if all slots are filled and we couldn't place a proc block
            elsif index == @segments.size - 1
              bad_load = true
              @feedback += "Cannot find a place for #{proc_seg} segment of size #{bsize}. Requeueing...\n"
              break;
            end
          end
          break if bad_load
        end
      end
      # recover pages and queue the process for later
      if bad_load
        @segments.each_with_index do |seg, seg_index|
          # clear any segments that didn't get loaded properly
          if seg.pid == p.pid
            seg.clear
            @feedback += "Seg #{seg_index} => segment reset: #{seg}\n"
          end
        end
        # reinsert this process after the next in the execution list
        # it will attempt to load and run after the next process is performed
        @exec_list.insert(exec_index + 2, p.to_a)
      end
      print_activity

    elsif pcb.size == 2 and pcb[1] == -1
      # a process is exiting
      @feedback +=  "Process #{pcb[0]} completed. Clearing from memory.\n"
      @segments.each { |s| s.clear if s.pid == pcb[0] }
      @processes.delete pcb[0]
      print_activity
    end
  end

  # load the execution list from a file into an array
  # create an enumerable referencing that array to be stepped through.
  def set_exec_list(filename)
    file = File.open filename
    @exec_list = []
    file.each { |pcb| @exec_list << pcb.split.map(&:to_i) } unless file.nil?
    @exec_object = @exec_list.each_with_index
    @feedback = ""
    filename
  end

  def exec_list_str
    # output the execution list in a readable format
    @exec_list.map {|p| "#{p.join ' '}\n"}
  end

  def load_next
    # loads the next process into memory if there is one
    load_process(*@exec_object.next) rescue alert "End of processes!"
  end

  def main
    # this should be fully functional if you comment out the Shoes.app section
    # and load the manager.main section. Untested in final version.
    exseq = File.open('exseq2.txt')
    set_exec_list exseq
    # @exec_list.each_with_index { |pcb, exec_index| load_process(pcb, exec_index) }
    (@exec_list.size + 1).times do
      load_next
    end
  end
end

=begin
manager = Manager.new
manager.main
=end

#=begin
# the GUI is powered by Shoes, which is more awesome than I originally thought
# Special thanks to Steve Klabnik, maintainer of the Shoes project, for his
# guidance in usage of this toolkit.
Shoes.app(:title => "Paging Simulator", :width => 800, :height => 450) do
  @manager = Manager.new
  @pages = []
  @page_background = []
  @page_contents = []

  # file input and process queue column
  stack(:width => 200) do
    title "Execution Queue", :size => 14

    @exec_list = stack(:width => 165) do
      background white
      @exec_lines = para "click button to load", :size => 9
    end

    @file_button = button "Load Process List"

    @file_button.click do
      # get the file and parse it into our execution list
      filename = ask_open_file
      @manager.set_exec_list filename
      # format output
      @exec_lines.replace @manager.exec_list_str
      @terminal.replace @manager.feedback
    end
  end

  # memory pages and process stepping control column
  stack(:width => 200) do
    caption "Memory Pages"
    for page in @manager.segments
      @pages << stack(:width => 165) do
        @page_background << background(page.filled? ? red : green)
        @page_contents << para(page)
      end
    end
    @next_btn = button "Next"
    @next_btn.click do
      @manager.exec_list.empty? ? alert("You must load an execution list!") : @manager.load_next
      @manager.segments.each_with_index do |page, index|
        @page_contents[index].replace(page)
      end
      @exec_lines.replace @manager.exec_list_str
      @terminal.replace @manager.feedback
    end
  end

  # terminal feedback section
  stack(:width => 400) do
    caption "Terminal Feedback"
    stack(:width => 350) do
      background white
      @terminal = para "", :size => 8
    end
  end

end
#=end