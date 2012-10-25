require 'buildr/java/commands'
require 'rubygems' # Necessary for Ruby < 1.9
require 'nokogiri' # Don't forget to do this first: gem install nokogiri

repositories.remote << 'http://repo1.maven.org/maven2' << 'http://nexus.gephi.org/nexus/content/repositories/public'

JAVAHELP = artifact('javax.help:javahelp:jar:2.0.05')
MRJADAPTER = download artifact('net.roydesign:mrjadapter:jar:1.1') => 'http://www.docjar.com/jar/MRJAdapter.jar'
COLORPICKER = download artifact('com.bric:colorpicker:jar:1.0') => 'http://javagraphics.java.net/jars/ColorPicker.jar'
FONTCHOOSER = artifact('com.connectina.swing:fontchooser:jar:1.0')

def javahelp()
    puts "Processing Java Help..."
    doc_src = 'src/main/resources/doc'
    doc_target = 'target/resources/doc'
    Dir.foreach(doc_src) do |locale|
        next if locale.length != 2 or locale == '..' # For each locale, ...
        # Build contents.xml:
        # With the id=>text mapping from locale/html/contents.html, ...
        dict = {}
        doc = Nokogiri::HTML(open("#{doc_src}/#{locale}/html/contents.html"))
        doc.xpath('//a').each do |a_tag|
            dict[a_tag['id']] = a_tag.content
        end
        # Rewrite support/base-contents.xml as locale/contents.xml.
        contents = Nokogiri::XML(open("#{doc_src}/support/base-contents.xml"))
        contents.xpath('//tocitem').each do |toc_item|
            toc_item['text'] = dict[toc_item['target']].nil? ? toc_item['target'] : dict[toc_item['target']]
        end
        open("#{doc_target}/#{locale}/contents.xml",'w') { |f| contents.write_xml_to f}

        # Build JavaHelp Map:
        map = Nokogiri::XML(open("#{doc_src}/support/base-map.jhm"))
        map.xpath('//mapID').each do |mapID|
            mapID['url'] = "#{locale}/#{mapID['url']}"
        end
        open("#{doc_target}/map_#{locale}.jhm",'w') { |f| map.write_xml_to f }

        # Build HelpSet
        hs = open("#{doc_src}/support/base-doc.hs").read
        hs.gsub!("{lang}",locale)
        open("#{doc_target}/doc_#{locale}.hs",'w') { |f| f.write(hs) }

        # Java help index
        Java::Commands.java('-cp', JAVAHELP.to_s, 'com.sun.java.help.search.Indexer', '-c', 'jhindexer.cfg', '-db', "#{doc_target}/search_lookup_#{locale}", '-locale', locale, "#{doc_target}/#{locale}/html/guide", "#{doc_target}/#{locale}/html/libs")
    end
end

define 'logisim' do
  project.version = '2.7.2'
  compile.using :lint=>'all'
  compile.with JAVAHELP, MRJADAPTER, COLORPICKER, FONTCHOOSER
  compile {
    puts "Including dependencies into generated jar..."
    compile.dependencies.map do |dep|
      unzip( 'target/classes' => dep.to_s ).exclude('META-INF/*').extract
    end
    javahelp()
  }
  manifest['Main-Class'] = 'com.cburch.logisim.Main'
  package(:jar)
end