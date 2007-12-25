#!/usr/bin/ruby

require 'Date'

if ARGV.size < 4
  printf("0.0\n")
  exit
end

searchstring = ARGV[0].downcase
searchpath = ARGV[1]
relevantframe = ARGV[2].to_i * (60*60*24)
relevance = ARGV[3].to_f

score = 0.0

Dir::chdir(searchpath)

files = Dir["*.emlx"].join(" ")
awkout = `/usr/bin/awk '/<key>date-sent<\\/key>/{getline OUTPUT}/<key>sender<\\/key>/{getline; $0 = tolower($0); if (/#{searchstring}/) print $0, ":", OUTPUT}' #{files}`

times = awkout.split("\n").collect do |timeline|
  timeline.sub(/.*<real>(.*)<\/real>/, '\1').to_i
end.sort

now = Time.now.to_i
worstratio = now - relevantframe

#print "\nMessages after #{Time.at(worstratio)}, relevance is #{relevance}...\n\n"

times.each do |msgtime|
  if (msgtime > worstratio)
    score += relevance * (msgtime - worstratio)/(now - worstratio)
#    print "Msg got at #{Time.at(msgtime)}, score is now #{score}\n"
  end
end

if (score > 1.0)
  score = 1.0
end

printf("%.06f\n#{searchstring}",score)
