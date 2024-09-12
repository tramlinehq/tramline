require "irb/completion"
require "rubygems"

IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = "#{ENV["HOME"]}/.irb-save-history"
IRB.conf[:USE_AUTOCOMPLETE] = false

def Rel(slug) = Release.find_by_slug(slug)
def Wrun(id) = WorkflowRun.find(id)
def B(id) = Build.find(id)
def Prun(id) = ReleasePlatformRun(id)
def Csha(sha) = Commit.all.find { |c| c.short_sha == sha }
