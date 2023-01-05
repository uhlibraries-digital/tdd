# frozen_string_literal: true

require 'tty-config'
require 'tty-box'
require 'tty-prompt'
require 'tty-spinner'
require 'ruby-progressbar'
require 'pastel'
require 'fileutils'
require 'pathname'
require 'facets'
require 'yaml'
require 'yaml/store'
require 'csv'
require 'mini_exiftool'
require 'logger'

require_relative 'lib/tdd'

def execute(function, config, log)
  prompt = TTY::Prompt.new
  pastel = Pastel.new

  case function

  when 'createMetaFolders'
    function_path = Pathname.new(config.fetch(:createMetaFolders))
    choices = TDD.get_choices function_path
    batch = prompt.select('Create Metadata Folders:', choices, per_page: 15)
    if batch == 'Main Menu'
      function = TDD.main_menu
      execute function, config, log
    else
      response = prompt.select("Process Batch #{pastel.yellow(batch.basename)}?", %w[Yes No])
      if response == 'Yes'
        spinner = TDD.new_spinner('Creating Metadata Folders')
        spinner.auto_spin
        batch_access_path = "#{batch}/Output/TIFF/#{batch.basename.to_s}"
        batch.children.each do |volume|
          if volume.basename.to_s == 'Output'
            next
          else
            oclc = volume.basename.to_s
            meta_path = "#{batch_access_path}/#{oclc}/metadata"
            FileUtils.mkdir_p meta_path
            FileUtils.cp("#{volume}/metadata.txt", "#{meta_path}/metadata.txt")
            access_path = Pathname.new("#{batch_access_path}/#{oclc}")
            access_path.children.each do |tiff|
              if tiff.basename.to_s == 'metadata'
                next
              else
                if tiff.basename.sub_ext('').to_s.chars.last(3).join == '_sp'
                  FileUtils.mv(tiff, meta_path)
                end
              end
            end
          end
        end
        FileUtils.mv(batch, config.fetch(:digiQC))
        log.info("#{TDD.timestamp} : created metadata folders for batch #{batch.basename}")
        spinner.success(pastel.green('Metadata Folders Created'))
        prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
        function = TDD.main_menu
        execute function, config, log
      else
        function = TDD.main_menu
        execute function, config, log
      end
    end


  when 'archiveDigiBatch'
    function_path = Pathname.new(config.fetch(:archiveDigiBatch))
    choices = TDD.get_choices function_path
    batch = prompt.select('Archive Digi Batch:', choices, per_page: 15)
    if batch == 'Main Menu'
      function = TDD.main_menu
      execute function, config, log
    else
      response = prompt.select("Archive Digi Batch #{pastel.yellow(batch.basename)}?", %w[Yes No])
      if response == 'Yes'
        date_digitized = Time.now.strftime('%Y%m%d')
        batchstr = batch.to_s.gsub('\\', '/')
        metadata_paths = Dir.glob("#{batchstr}/Output/TIFF/**/metadata.txt")
        batch_size = metadata_paths.size
        bar = ProgressBar.create(total: metadata_paths.size, format: 'Archiving Digi Batch: %c/%C |%W| %a')
        metadata_paths.each do |path|
          metadata = Pathname.new(path)
          object = metadata.parent.parent
          data = YAML.load_file(path)
          data['DateDigitized'] = date_digitized
          data['DigiBatch'] = batch.basename.to_s
          pages = Dir.glob("#{object}/*.tif").size
          data['Pages'] = pages
          File.open("#{object}/metadata/#{object.basename}_metadata.txt", 'w') { |file| file.write(data.to_yaml) }
          File.delete(path)
          dest_path = "#{config.fetch(:ocrInput)}/#{object.basename}"
          FileUtils.mv object, dest_path
          bar.increment
        end
        FileUtils.remove_dir "#{batchstr}/Output"
        original_metadata_paths = Dir.glob("#{batchstr}/**/metadata.txt")
        original_metadata_paths.each { |path| File.delete(path) }
        FileUtils.mv batch, "#{config.fetch(:pmArchive)}/#{batch.basename}"
        log.info("#{TDD.timestamp} : archived Digi batch #{batch.basename} with #{batch_size} objects")
        puts pastel.green('Archiving Complete')
        prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
        function = TDD.main_menu
        execute function, config, log
      else
        function = TDD.main_menu
        execute function, config, log
      end
    end

  when 'archiveOCRBatch'
    batch = Time.now.strftime('%Y%m%d')
    input_paths = Pathname.new(config.fetch(:ocrInput)).children
    output_paths = Pathname.new(config.fetch(:ocrOutput)).children
    if input_paths.size == output_paths.size
      if input_paths.size == 0
        puts pastel.red('There are no objects to archive.')
        prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
        function = TDD.main_menu
        execute function, config, log
      end
      response = prompt.select("Archive #{input_paths.size} objects in OCR Batch #{pastel.yellow(batch)}?", %w[Yes No])
      if response == 'Yes'
        input_dirs = []
        output_dirs = []
        input_paths.each { |path| input_dirs << path.basename.to_s }
        output_paths.each { |path| output_dirs << path.basename.to_s }
        if input_dirs.frequency == output_dirs.frequency
          total = input_paths.size + output_paths.size
          bar = ProgressBar.create(total: total, format: 'Archiving OCR Batch: %c/%C |%W| %a')
          FileUtils.mkdir_p "#{config.fetch(:acArchive)}/#{batch}"
          FileUtils.mkdir_p "#{config.fetch(:toMetadata)}/#{batch}"
          input_metadata = {}
          output_metadata = {}
          input_paths.each do |path|
            input_files = []
            id = path.basename.to_s
            input_file_paths = path.children
            input_file_paths.each { |file| input_files << file.basename.to_s }
            input_metadata[id] = input_files
            FileUtils.mv path, "#{config.fetch(:acArchive)}/#{batch}/#{id}"
            bar.increment
          end
          output_paths.each do |path|
            output_files = []
            id = path.basename.to_s
            output_file_paths = path.children
            output_file_paths.each { |file| output_files << file.basename.to_s }
            output_metadata[id] = output_files
            FileUtils.mv path, "#{config.fetch(:toMetadata)}/#{batch}/#{id}"
            bar.increment
          end
          spinner = TDD.new_spinner('Writing Batch Metadata')
          store = YAML::Store.new("#{config.fetch(:stats)}/tdd.yaml")
          store.transaction do
            store[batch] = {
              'ac_archive' => input_metadata,
              'to_metadata' => output_metadata
            }
            store.commit
          end
          log.info("#{TDD.timestamp} : archived OCR batch #{batch} with #{input_paths.size} objects")
          spinner.success(pastel.green('Archiving Complete'))
          prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
          function = TDD.main_menu
          execute function, config, log
        else
          puts pastel.red('The identifiers in the Input & Output directories do not match.')
          puts 'Please check the directories and try again.'
          prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
          function = TDD.main_menu
          execute function, config, log
        end
      else
        function = TDD.main_menu
        execute function, config, log
      end
    else
      puts pastel.red('The number of folders in the Input & Output directories do not match.')
      puts 'Please check the directories and try again.'
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log
    end

  when 'getMetaNotes'
    function_path = Pathname.new(config.fetch(:toMetadata))
    notes_path = function_path.join('0_Documentation','notes')
    spinner = TDD.new_spinner('Getting Metadata Notes')
    spinner.auto_spin
    metadata_paths = Dir.glob("#{function_path.to_s.gsub('\\', '/')}/**/*_metadata.txt")
    time = TDD.timestamp
    invalid = []
    headers = %w[Directory OCLC DigiNote MetaNote RightsNote]
    CSV.open("#{notes_path}/notes_#{time}.csv", 'w') do |csv|
      csv << headers
      metadata_paths.each do |path|
        parent = Pathname.new(path).parent.parent
        directory, oclc = parent.split
        row = [directory, oclc]
        begin
          metadata = YAML.load_file(path)
        rescue StandardError => e
          invalid << path
          log.error "#{e}"
          next
        end
        row << metadata['DigiNote']
        row << metadata['MetaNote']
        row << metadata['RightsNote']
        csv << row
      end
    end
    spinner.success(pastel.green("Notes Report: #{notes_path}/notes_#{time}.csv"))
    if invalid.size > 0
      file_names = []
      invalid.each {|path| file_names << Pathname.new(path).basename.to_s }
      if invalid.size == 1
        err = 'error'
      else
        err = 'errors'
      end
      puts pastel.red("Found #{invalid.size} metadata validation #{err}: #{file_names}")
    end
    prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
    function = TDD.main_menu
    execute function, config, log

  when 'batchMetadataReport'
    function_path = Pathname.new(config.fetch(:toMetadataEditing))
    exclude = %w(1_in_copyright 2_no_copyright 3_borrower_notice 4_potential_trigger 5_digital_problem_theses 6_questions4Laura 7_salima)
    choices = TDD.get_choices function_path, exclude
    batch = prompt.select('Batch Metadata Report:', choices, per_page: 15)
    if batch == 'Main Menu'
      function = TDD.main_menu
      execute function, config, log
    else
      response = prompt.select("Create Metadata Report for Batch #{pastel.yellow(batch.basename)}?", %w[Yes No])
      if response == 'Yes'
        spinner = TDD.new_spinner('Writing Metadata Report')
        spinner.auto_spin
        batch_path = function_path.join(batch)
        metadata_paths = Dir.glob("#{batch_path.to_s.gsub('\\', '/')}/**/*_metadata.txt")
        time = TDD.timestamp
        invalid = []
        csv_headers = []
        TDD.headers.each {|field| csv_headers << field unless field == 'filename'}
        TDD.admin_fields.each {|field| csv_headers << field}
        CSV.open("#{batch_path}/metadata_#{time}.csv", 'w') do |csv|
          csv << csv_headers
          metadata_paths.each do |path|
            begin
              metadata = YAML.load_file(path)
            rescue StandardError => e
              invalid << path
              log.error "#{e}"
              next
            end
            row = []
            csv_headers.each do |field|
              row << metadata[field]
            end
            csv << row
          end
        end
        spinner.success(pastel.green("Batch Metadata Report: #{batch_path}/metadata_#{time}.csv"))
        if invalid.size > 0
          file_names = []
          invalid.each {|path| file_names << Pathname.new(path).basename.to_s }
          if invalid.size == 1
            err = 'error'
          else
            err = 'errors'
          end
          puts pastel.red("Found #{invalid.size} metadata validation #{err}: #{file_names}")
        end
        prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
        function = TDD.main_menu
        execute function, config, log
      else
        function = TDD.main_menu
        execute function, config, log
      end
    end

  when 'yamlValidation'
    function_path = Pathname.new(config.fetch(:yamlValidation))
    validation_path = Pathname.new(config.fetch(:validationErrors))
    exif_path = Pathname.new(config.fetch(:addExif))
    metadata_paths = Dir.glob("#{function_path.to_s.gsub('\\', '/')}/**/*_metadata.txt")
    time = TDD.timestamp
    validation_errors = []
    response = prompt.select("Validate YAML for #{function_path.children.size} objects?", %w[Yes No])
    if response == 'Yes'
      spinner = TDD.new_spinner('Validating YAML Files')
      spinner.auto_spin
      metadata_paths.each do |path|
        begin
          metadata = YAML.load_file(path)
        rescue
          validation_errors << path
        else
          issue = Pathname.new(path).parent.parent
          FileUtils.mv issue, exif_path
        end
      end
      if validation_errors.size > 0
        errors_path = "#{validation_path}/validation_errors_#{time}.txt"
        File.open(errors_path, "w+") do |f|
          f.puts(validation_errors)
        end
        if validation_errors.size == 1
          e = "Error"
        else
          e = "Errors"
        end
        log.info("#{TDD.timestamp} : validated metadata with #{validation_errors.size} #{e}: #{errors_path}")
        spinner.success(pastel.red("Found #{validation_errors.size} #{e}: #{errors_path}"))
      else
        log.info("#{TDD.timestamp} : validated metadata with no errors")
        spinner.success(pastel.green("No YAML Validation Errors Found"))
      end
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log
    else
      function = TDD.main_menu
      execute function, config, log
    end

  when 'addExif'
    MiniExiftool.command = config.fetch(:exifTool)
    function_path = Pathname.new(config.fetch(:addExif))
    function_path_size = function_path.children.size
    open_access_path = Pathname.new(config.fetch(:openAccessStaging))
    cougarnet_path = Pathname.new(config.fetch(:cougarnetStaging))
    rights_errors = []
    response = prompt.select("Add EXIF Metadata for #{function_path.children.size} objects?", %w[Yes No])
    if response == 'Yes'
      puts pastel.yellow("Adding EXIF Metadata ...")
      function_path.children.each_with_index do |volume,i|
        metadata = YAML.load_file(volume.join('metadata', "#{volume.basename.to_s}_metadata.txt"))
        pdf = volume.join("#{volume.basename.to_s}.pdf")
        case metadata['dc.rights']
        when 'In Copyright'
          TDD.add_exif(pdf, metadata, "#{i+1}/#{function_path_size}")
          FileUtils.mv volume, cougarnet_path
        when 'No Copyright'
          TDD.add_exif(pdf, metadata, "#{i+1}/#{function_path_size}")
          FileUtils.mv volume, open_access_path
        else
          puts "#{i+1}/#{function_path_size}: #{volume.basename}  #{pastel.red('Rights Error')}"
          rights_errors << "#{volume} : '#{metadata['dc.rights']}'"
        end
      end
      if rights_errors.size > 0
        if rights_errors.size == 1
          s = 'statement'
        else
          s = 'statements'
        end
        puts pastel.red("Unknown rights #{s} found:")
        rights_errors.each {|error| puts pastel.yellow(error)}
      end
      log.info("#{TDD.timestamp} : added EXIF metadata to #{function_path.children.size} objects")
      puts pastel.green('EXIF Metadata Complete')
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log
    else
      function = TDD.main_menu
      execute function, config, log
    end

  when 'packageIngest'
    response = prompt.select("Please select ingest package type:", ['Open Access', 'Cougarnet', 'Cancel'])
    case response
    when 'Cancel'
      function = TDD.main_menu
      execute function, config, log
    when 'Open Access'
      function_path = Pathname.new(config.fetch(:packageIngest)).join('1_open_access')
      access_type = 'Open Access'
      access_type_short = 'OA'
    when 'Cougarnet'
      function_path = Pathname.new(config.fetch(:packageIngest)).join('2_cougarnet')
      access_type = 'Cougarnet'
      access_type_short = 'CN'
    end
    metadata_paths = Dir.glob("#{function_path.to_s.gsub('\\', '/')}/**/*_metadata.txt")
    rights_errors = []
    metadata_paths.each do |path|
      metadata = YAML.load_file(path)
      case metadata['dc.rights']
      when 'In Copyright'
        next
      when 'No Copyright'
        next
      else
        rights_errors << "#{path} : #{metadata['dc.rights']}"
      end
    end
    if rights_errors.size > 0
      if rights_errors.size == 1
        s = 'statement'
      else
        s = 'statements'
      end
      puts pastel.red("Unknown rights #{s} found:")
      rights_errors.each {|error| puts pastel.yellow(error)}
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log
    end
    objects = function_path.children
    response = prompt.select("Prepare #{objects.size} #{access_type} volumes for ingest?", %w[Yes No])
    if response == 'Yes'
      archive_path = config.fetch(:packageArchive)
      output_path = config.fetch(:packageOutput)
      batch_name = "#{access_type_short}_#{TDD.timestamp}"
      archive_dir = "#{archive_path}/#{batch_name}"
      batch_dir = "#{output_path}/#{batch_name}"
      FileUtils.mkdir_p archive_dir
      FileUtils.mkdir_p batch_dir
      headers = TDD.headers
      admin_fields = TDD.admin_fields
      bar = ProgressBar.create(total: objects.size, format: 'Preparing Ingest Batch: %c/%C |%W| %a')
      CSV.open("#{batch_dir}/#{batch_name}.csv", 'w') do |csv|
        csv << headers
        objects.each do |object|
          metadata = []
          meta_txt = object.join('metadata', "#{object.basename.to_s}_metadata.txt")
          pdf = "#{object.basename.to_s}.pdf"
          metadata_in = YAML.load_file(meta_txt)
          if metadata_in['dc.rights'] == 'In Copyright'
            metadata_in['dcterms.accessRights'] = 'The full text of this item is not available at this time because it contains documents that are presumed to be under copyright and are accessible only to users who have an active CougarNet ID. This item will continue to be made available through interlibrary loan.'
          end
          metadata_in.each do |k,v|
            unless admin_fields.include? k
              if k == 'dc.rights'
                v = 'This item is protected by copyright but is made available here under a claim of fair use (17 U.S.C. Section 107) for non-profit research and educational purposes. Users of this work assume the responsibility for determining copyright status prior to reusing, publishing, or reproducing this item for purposes other than what is allowed by fair use or other copyright exemptions. Any reuse of this item in excess of fair use or other copyright exemptions requires express permission of the copyright holder.'
              end
              metadata << v
            end
          end
          creator = metadata[3].strip.split(',')[0].gsub(/\s/,'')
          date = metadata[5].to_s.strip
          pdf_new = creator + '_' + date + '_' + pdf
          FileUtils.cp object.join(pdf), "#{batch_dir}/#{pdf_new}"
          csv << [pdf_new] + metadata
          FileUtils.mv object, "#{archive_dir}/#{object.basename}"
          bar.increment
        end
      end
      log.info("#{TDD.timestamp} : packaged #{objects.size} #{access_type} objects for ingest")
      puts pastel.green('Packaging Complete')
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log
    else
      function = TDD.main_menu
      execute function, config, log
    end

  when 'seleniumScript'
    template_path = Pathname.new(config.fetch(:seleniumTemplates))
    choices = ['.. Main Menu', 5, 10, 20, 50]
    response = prompt.select('Number of issues ingested:', choices)
    case response
    when 5
      template_file = 'TDD_template_005.side'
    when 10
      template_file = 'TDD_template_010.side'
    when 20
      template_file = 'TDD_template_020.side'
    when 50
      template_file = 'TDD_template_050.side'
    when '.. Main Menu'
      function = TDD.main_menu
      execute function, config, log
    end
    selenium_suite = JSON.parse(File.read(template_path.join(template_file)))
    first = prompt.ask('Enter first DSpace item number:').to_i
    last = first + response - 1
    items = [*first..last]
    collection = Pathname.new(config.fetch(:collection))
    output_path = Pathname.new(config.fetch(:seleniumOutput))
    items.each_with_index do |item,i|
      url = collection.join(item.to_s).to_s
      selenium_suite['tests'][i]['commands'][0]['target'] = url.strip
    end
    file_path = output_path.join("#{TDD.timestamp}.side")
    File.open(file_path,'w') do |f|
      f.write(selenium_suite.to_json)
    end
    log.info("#{TDD.timestamp} : wrote Selenium suite for #{response} Cougarnet items")
    puts pastel.green("Selenium suite available at: #{file_path}")
    prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
    function = TDD.main_menu
    execute function, config, log

  when 'Statistics'
    choices = ['.. Main Menu', 'Digi Production', 'Completed Volumes']
    response = prompt.select('Choose a report:', choices)
    case response
    when 'Digi Production'
      print pastel.yellow('Getting Images ... ')
      path = Pathname.new(config.fetch(:acArchive))
      images = TDD.get_images(path)
      puts pastel.green("Found #{images.size}")
      print pastel.yellow('Writing Report ... ')
      report = Time.now.strftime('%Y%m%d')
      report_path = Pathname.new(config.fetch(:stats))
      report_path = report_path.join('digi', "#{report}.txt")
      stats = {}
      stats['Project Total'] = images.size
      duplicates = []
      images.each do |filename, paths|
        paths.each do |path|
          t = File.ctime(path)
          if stats[t.year].nil?
            stats[t.year] = { 'Year Total' => 1, t.month => 1 }
          else
            if stats[t.year][t.month].nil?
              stats[t.year]['Year Total'] += 1
              stats[t.year].store(t.month, 1)
            else
              stats[t.year]['Year Total'] += 1
              stats[t.year][t.month] += 1
            end
          end
        end
        duplicates << { filename => paths } if paths.size > 1
      end
      stats['Duplicates'] = duplicates
      File.write(report_path, stats.to_yaml)
      puts pastel.green("Compiled #{report}.txt")
      prompt.keypress('Press Space or Return to continue ...', keys: %i[space return])
      function = TDD.main_menu
      execute function, config, log

    when 'Digitized Volumes'

    when '.. Main Menu'
      function = TDD.main_menu
      execute function, config, log
    end

  when 'Quit'
    response = prompt.select('Do you really want to quit?', %w[Yes No])
    if response == 'Yes'
      exit
    else
      function = TDD.main_menu
      execute function, config, log
    end
  end
end

config = TTY::Config.new
config.filename = 'paths'
config.append_path "P:/DigitalProjects/_TDD/0_dev/workflow"
config.read
log = Logger.new "P:/DigitalProjects/_TDD/0_dev/workflow/tdd-workflow-utility.log"
log.level = Logger::INFO

pastel = Pastel.new
print TTY::Box.frame(
  align: :center,
  border: :thick,
  style: {
    border: {
      fg: :red
    }
  }
) { pastel.bold('TDD Workflow Utility') }
function = TDD.main_menu
execute(function, config, log)
