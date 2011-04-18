#!/usr/bin/env ruby

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
    if filled?
      "#{seg} #{seg_id} for pid #{pid}"
    else "empty"
    end
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

def print_activity
  @segments.each_with_index {|s, index| puts "Seg #{index} => #{s}" }
  @processes.each_value {|s| puts s }
end

def main

  exseq = File.open('exseq2.txt', 'r')
  @exec_list = []
  @processes = {}
  @segments = Array.new(8) { MemSegment.new }

  exseq.each_with_index { |pcb| @exec_list << pcb.split.map(&:to_i) }

  @exec_list.each_with_index do |pcb, exec_index|
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

      @segments.each_with_index {|s, index| puts "Seg #{index} => #{s}" }
      @processes.each_value {|s| puts s}
    elsif pcb.size == 2 and pcb[1] == -1
      # a process is exiting
      puts "removing pid #{pcb[0]}"
      @segments.each { |s| s.clear if s.pid == pcb[0] }
      @processes.delete pcb[0]
      print_activity
    end
  end
end

main