#!/usr/bin/env shoes
require 'rubygems'
require 'ruby-debug'

class MemSegment
  attr_accessor :filled, :pid, :seg, :seg_id

  def initialize(filled=false, pid=nil, seg=nil, seg_id=0)
    @filled = filled
    @pid = pid.to_i
    @seg = seg.to_s
    @seg_id = seg_id.to_i
    self
  end

  def fill(pid, seg, seg_id)
    @filled = true; @pid = pid; @seg = seg; @seg_id = seg_id;
    self
  end

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

class SimProc
  include Enumerable
  attr_accessor :pid, :code, :data

  def initialize(pid, code, data)
    @pid = pid.to_i
    @code = code.to_i
    @data = data.to_i
  end

  def each
    yield :code, code
    yield :data, data
  end

  def to_s
    "[SimProc :pid => #{pid}, :code => #{code}, :data => #{data}]"
  end

  def to_a
    [@pid, @code, @data]
  end
end

class Manager
  attr_reader :segments, :processes, :exec_list, :exec_object

  def initialize
    @exec_list = []
    @processes = {}
    @segments = Array.new(8) { MemSegment.new }
  end

  def print_activity
    @segments.each_with_index {|s, index| puts "Seg #{index} => #{s}" }
    @processes.each_value {|s| puts s }
  end

  def load_process(pcb, exec_index)
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
              break
            # if all slots are filled and we couldn't place a proc block
            elsif index == @segments.size - 1
              bad_load = true
              puts "Cannot find a place for #{proc_seg} segment of size #{bsize}. Requeueing..."
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
            puts "Seg #{seg_index} => segment cleared: #{seg}"
          end
        end
        # reinsert this process after the next in the execution list
        # it will attempt to load and run after the next process is performed
        @exec_list.insert(exec_index + 2, p.to_a)
      end
      print_activity

    elsif pcb.size == 2 and pcb[1] == -1
      # a process is exiting
      puts "removing pid #{pcb[0]}"
      @segments.each { |s| s.clear if s.pid == pcb[0] }
      @processes.delete pcb[0]
      print_activity
    end
  end

  def set_exec_list(filename)
    file = File.open filename
    file.each { |pcb| @exec_list << pcb.split.map(&:to_i) } unless file.nil?
    filename
  end

  def load_next
    load_process(*@exec_object.next)
  end

  def main
    exseq = File.open('exseq2.txt')
    set_exec_list exseq

    # this is the object that will be used to run each process with .next
    @exec_object = @exec_list.each_with_index
    # @exec_list.each_with_index { |pcb, exec_index| load_process(pcb, exec_index) }
    (@exec_list.size + 1).times do
      load_process(*@exec_object.next)
    end
  end
end

=begin
manager = Manager.new
manager.main
=end

#=begin
Shoes.app(:title => "Paging Simulator", :width => 800, :height => 450) do
  @manager = Manager.new
  stack(:width => 200) do
    @exec_list = stack do
      title "Execution Queue", :size => 14
      @exec_lines = para "click button to load", :size => 9
      @file_button = button "Load Process List"
      #debugger
      @file_button.click do
        filename = ask_open_file
        @manager.set_exec_list filename
        # format output
        @exec_lines.replace @manager.exec_list.map {|p| "#{p.join ' '}\n"}
      end
    end
  end
  stack(:width => 300) do
    title "Memory Pages"
    for page in @memory.segments do
      para page
    end
  end
end
#=end