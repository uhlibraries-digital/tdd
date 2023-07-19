# ==============================================================
# What it does: From a txt file containing a list of OCLC ids,
#     creates the batch for that list.
# When to use it: When starting a new batch.
# How to use it: Run the corresponding createDigiBatch*.exe
# How to build the exe:
#     Ruby must be installed, and %RUBY_HOME% must point to the
#         directory where Ruby is installed, e.g. C:\Ruby27-x64
#     Update lines 22-24 and save the file.
#     Open a CMD window and navigate to
#         %your_projects_home%\tdd\1_batch_prep.0_master_data.RB
#     Run buildCreateDigiBatchExe.bat
#     Copy or move the resulting createDigiBatch.exe from 
#         %RUBY_HOME%\bin to an appropriate createDigiBatch*.exe
#         in P:\DigitalProjects\_TDD\1_batch_prep\
# How to run the exe:
#     Open a CMD window and navigate to
#         P:\DigitalProjects\_TDD\1_batch_prep\
#     Run the desired createDigiBatch*.exe
# ==============================================================

require 'fileutils'
require 'pathname'

def start_wizard(wdir)
  batch = Time.now.strftime("%Y%m%d")
  if File.file? "#{wdir}/#{batch}.txt"
    total_found = 0
    found = []
    objects = []
    File.readlines("#{wdir}/#{batch}.txt").each {|line| objects << line.strip.to_s}
    total_prepared = objects.size
    FileUtils.mkdir_p "#{wdir}/#{batch}"

    puts "Create Digi Batch (Post-1989)"
    puts "Loading master data from 3_tdd-1989-2009 ..."
    paths = Dir.glob("#{wdir}/3_tdd-1989-2009/**/**")
    paths.each do |path|
      dir = Pathname.new(path)
      if objects.include? dir.basename.to_s
        dir_name = dir.basename.to_s
        FileUtils.mv path, "#{wdir}/#{batch}/#{dir_name}"
        found << dir_name
        objects.delete(dir_name)
      end
    end
    if total_prepared == found.size
      puts "Successfully created batch #{batch} with #{total_prepared} objects: #{found}"
      puts "Press Enter to exit the application."
      $stdin.gets.chomp
    else
      puts "Created batch #{batch} with #{found.size} objects: #{found}"
      puts "Could not find #{objects.size} of #{total_prepared} objects: #{objects}"
      puts "Press Enter to exit the application."
      $stdin.gets.chomp
    end
  else
    puts "Batch file \'#{batch}.txt\' does not exist. Try again? [Y/N]"
    response = $stdin.gets.chomp
    case response
    when 'Y', 'y', 'Yes', 'yes'
      start_wizard(wdir)
    when 'N', 'n', 'No', 'no'
      exit
    else
      puts "Unrecognized input. Exiting application."
      exit
    end
  end
end

begin
  start_wizard(Dir.pwd)
rescue Exception => e
  File.open("#{Dir.pwd}/exceptions.log", "w") do |f|
    f.puts e.inspect
    f.puts e.backtrace
  end
end
