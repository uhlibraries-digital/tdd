require 'csv'
require 'json'
require 'yaml'
require 'fileutils'

def nilCheck(field)
  if field.nil?
    value = ''
  else
    value = field.to_s.strip
  end
  value.gsub("\"","\'")
end

# ==============================================================
# Update these variables before running on a new file
# ==============================================================
file_in = 'UH_Theses_1979_1988_fullmetaFINAL_with_copyright.csv'
file_out_base = 'tdd-1979-1988'
#file_out_base = 'tdd-1988-2010'
dir_out = '2_' + "#{file_out_base}"
#dir_out = '3_' + "#{file_out_base}"

# ==============================================================
# parse csv
# ==============================================================
file_out = file_out_base + ".json"
tdd = CSV.read("#{file_in}", headers: true)
records = {}

tdd.each do |record|
  records[record['dc.identifier.other']] = { 
    'dc.identifier.other' => nilCheck(record['dc.identifier.other']),
    'dc.creator' => nilCheck(record['dc.creator']),
    'dc.title' => nilCheck(record['dc.title']),
    'dc.date.issued' => nilCheck(record['dc.date.issued']),
    'dc.description.department' => nilCheck(record['dc.description.department']),
    'thesis.degree.discipline' => nilCheck(record['thesis.degree.discipline']),
    'thesis.degree.college' => nilCheck(record['thesis.degree.college']),
    'thesis.degree.department' => nilCheck(record['thesis.degree.department']),
    'thesis.degree.name' => nilCheck(record['thesis.degree.name']),
    'thesis.degree.level' => nilCheck(record['thesis.degree.level']),
    'dc.language.iso' => nilCheck(record['dc.language.iso']),
    'dc.relation.ispartof' => nilCheck(record['dc.relation.ispartof']),
    'dc.subject' => nilCheck(record['dc.subject']),
    'dc.type.dcmi' => nilCheck(record['dc.type.dcmi']),
    'dc.format.mimetype' => nilCheck(record['dc.format.mimetype']),
    'thesis.degree.grantor' => nilCheck(record['thesis.degree.grantor']),
    'dc.format.digitalorigin' => nilCheck(record['dc.format.digitalorigin']),
    'dc.type.genre' => nilCheck(record['dc.type.genre']),
    'dc.description.abstract' => nilCheck(record['dc.description.abstract']),
    'dc.rights' => nilCheck(record['dc.rights']),
    'dc.date.copyright' => nilCheck(record['dc.date.copyright']),
    'dcterms.accessRights' => nilCheck(record['dcterms.accessRights']) }
end
File.open("#{file_out}", 'w') {|f| f.write(records.to_json)}


# ==============================================================
# parse json
# ==============================================================
def create_object_folder(dir, id, record)
  date = record['dc.date.issued'][0..3]
  dir = dir + "/#{date}/#{id}"
  FileUtils.mkdir_p dir
  metadata = create_metadata(id, record)
  File.open("#{dir}/metadata.txt", "w") {|f| f.write(metadata.to_yaml)}
end 

def create_metadata(id, record)
  metadata = {}
  metadata['dc.identifier.other'] = id
  metadata['dc.contributor.advisor'] = ''
  metadata['dc.contributor.committeeMember'] = ''
  metadata['dc.creator'] = record['dc.creator']
  metadata['dc.title'] = record['dc.title']
  metadata['dc.date.issued'] = record['dc.date.issued']
  metadata['dc.description.department'] = record['dc.description.department']
  metadata['thesis.degree.discipline'] = record['thesis.degree.discipline']
  metadata['thesis.degree.college'] = record['thesis.degree.college']
  metadata['thesis.degree.department'] = record['thesis.degree.department']
  metadata['thesis.degree.name'] = record['thesis.degree.name']
  metadata['thesis.degree.level'] = record['thesis.degree.level']
  metadata['dc.language.iso'] = record['dc.language.iso']
  metadata['dc.relation.ispartof'] = record['dc.relation.ispartof']
  metadata['dc.subject'] = record['dc.subject']
  metadata['dc.type.dcmi'] = record['dc.type.dcmi']
  metadata['dc.format.mimetype'] = record['dc.format.mimetype']
  metadata['thesis.degree.grantor'] = record['thesis.degree.grantor']
  metadata['dc.format.digitalorigin'] = record['dc.format.digitalorigin']
  metadata['dc.type.genre'] = record['dc.type.genre']
  metadata['dc.description.abstract'] = record['dc.description.abstract']
  metadata['dc.rights'] = record['dc.rights']
  metadata['dc.date.copyright'] = record['dc.date.copyright']
  metadata['dcterms.accessRights'] = ''
  metadata['Pages'] = ''
  metadata['DateDigitized'] = ''
  metadata['DigiNote'] = ''
  metadata['MetaNote'] = ''
  metadata['RightsNote'] = ''
  metadata
end

file = File.read("#{file_out}")
parent = "#{dir_out}"
tdd = JSON.parse(file)
puts "Creating Object Directories..."
tdd.each do |id,record|
  print id + "  "
  case record['dc.date.issued'][0..2]
  when '194'
    dir = "#{parent}/1940s"
  when '195'
    dir = "#{parent}/1950s"    
  when '196'
    dir = "#{parent}/1960s"
  when '197'
    dir = "#{parent}/1970s"
  when '198'
    dir = "#{parent}/1980s"
  when '199'
    dir = "#{parent}/1990s"
  when '200'
    dir = "#{parent}/2000s"
  when '201'
    dir = "#{parent}/2010s"
  when '202'
    dir = "#{parent}/2020s"
  else
    dir = "#{parent}/unknown"
  end
  create_object_folder(dir, id, record)
end
