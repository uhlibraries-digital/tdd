# frozen_string_literal: true

module TDD
  module_function

  def main_menu
    prompt = TTY::Prompt.new
    choices = {
      '2.3 Create Metadata Folders' => 'createMetaFolders',
      '3.0 Archive Digitized Batch' => 'archiveDigiBatch',
      '3.1 Archive OCR Batch' => 'archiveOCRBatch',
      '4 Metadata Notes' => 'getMetaNotes',
      '4.2 Validate YAML' => 'yamlValidation',
      '4.3 Add EXIF Metadata' => 'addExif',
      '5.1 Prepare Ingest Package' => 'packageIngest',
      '5.3 Prepare Selenium Script' => 'seleniumScript',
      'Statistics' => 'Statistics',
      'Quit' => 'Quit' }
    prompt.select('Choose a function:', choices, per_page: 11, cycle: true)
  end

  def new_spinner(message)
    pastel = Pastel.new
    spinner_format = "[#{pastel.yellow(':spinner')}] " + pastel.yellow("#{message} ...")
    spinner = TTY::Spinner.new(spinner_format, success_mark: pastel.green('+'))
  end

  def get_choices(path)
    choices = {}
    choices['.. (Main Menu)'] = 'Main Menu'
    batches = path.children
    batches.each {|path| choices[path.basename] = path}
    choices
  end


  def headers
    [
      'filename',
      'dc.identifier.other',
      'dc.contributor.advisor',
      'dc.contributor.committeeMember',
      'dc.creator',
      'dc.title',
      'dc.date.issued',
      'dc.description.department',
      'thesis.degree.discipline',
      'thesis.degree.college',
      'thesis.degree.department',
      'thesis.degree.name',
      'thesis.degree.level',
      'dc.language.iso',
      'dc.relation.ispartof',
      'dc.subject',
      'dc.type.dcmi',
      'dc.format.mimetype',
      'thesis.degree.grantor',
      'dc.format.digitalOrigin',
      'dc.type.genre',
      'dc.description.abstract',
      'dc.rights'
    ]
  end

  def get_dc_headers
    [
      'dc.identifier.other',
      'dc.contributor.advisor',
      'dc.contributor.committeeMember',
      'dc.creator',
      'dc.title',
      'dc.date.issued',
      'dc.description.department',
      'dc.language.iso',
      'dc.relation.ispartof',
      'dc.subject',
      'dc.type.dcmi',
      'dc.format.mimetype',
      'dc.format.digitalOrigin',
      'dc.type.genre',
      'dc.description.abstract',
      'dc.rights'
    ]
  end

  def get_thesis_headers
    [
      'thesis.degree.discipline',
      'thesis.degree.college',
      'thesis.degree.department',
      'thesis.degree.name',
      'thesis.degree.level',
      'thesis.degree.grantor',
    ]
  end

  def reorder(files, order)
    new_files = []
    order.each {|n| new_files << files[n]}
    new_files
  end

  def admin_fields
    [
      'Pages',
      'DigiBatch',
      'DateDigitized',
      'DigiNote',
      'MetaNote',
      'RightsNote'
    ]
  end

  def get_images(path, images = {})
    path.children.each do |child|
      if File.directory? child
        get_images child, images
      else
        if child.extname == '.tif'
          if images.has_key?(child.basename.to_s)
            images[child.basename.to_s] << child
          else
            images[child.basename.to_s] = [child]
          end
        end
      end
    end
    images
  end

  def timestamp(time = Time.now)
    time.strftime("%Y%m%d-%H%M")
  end

  def add_exif(path, metadata, count)
    creator = metadata['dc.creator']
    date = metadata['dc.date.issued']
    description = metadata['dc.description.abstract']
    identifier = metadata['dc.identifier.other']
    publisher = "University of Houston"
    subject = metadata['dc.subject'].gsub('||', ', ')
    title = metadata['dc.title']
    print "#{count}: #{path.basename} "
    system("exiftool -overwrite_original -XMP-dc:Creator=\"#{creator}\" -XMP-dc:Date=\"#{date}\" -XMP-dc:Description=\"#{description}\" -XMP-dc:Identifier=\"#{identifier}\" -XMP-dc:Publisher=\"#{publisher}\" -XMP-dc:Subject=\"#{subject}\" -XMP-dc:Title=\"#{title}\" #{path}")
    # system("exiftool -quiet -overwrite_original -XMP-dc:Creator=\"#{creator}\" -XMP-dc:Date=\"#{date}\" -XMP-dc:Description=\"#{description}\" -XMP-dc:Identifier=\"#{identifier}\" -XMP-dc:Publisher=\"#{publisher}\" -XMP-dc:Subject=\"#{subject}\" -XMP-dc:Title=\"#{title}\" #{path}")
  end

end
