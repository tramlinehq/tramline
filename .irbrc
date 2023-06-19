require "irb/completion"
require "rubygems"

IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = "#{ENV["HOME"]}/.irb-save-history"
IRB.conf[:USE_AUTOCOMPLETE] = false

def bm
  # From http://blog.evanweaver.com/articles/2006/12/13/benchmark/
  # Call benchmark { } with any block and you get the wallclock runtime
  # as well as a percent change + or - from the last run
  cur = Time.now
  result = yield
  print "#{cur = Time.now - cur} seconds"
  begin
    puts " (#{(cur / $last_benchmark * 100).to_i - 100}% change)"
  rescue
    puts ""
  end
  $last_benchmark = cur
  result
end

def Srun(id) = StepRun.find(id)
def Prun(id) = ReleasePlatformRun(id)
def Rel(id) = Release.find(id)
