# encoding: utf-8
require File.expand_path(File.join(File.dirname(__FILE__),'test_helper'))

class WikiParser < WikiCloth::Parser
  url_for do |page|
    page
  end

  template do |template|
    case template
    when "noinclude"
      "<noinclude>hello world</noinclude><includeonly>testing</includeonly>"
    when "test"
      "busted"
    when "nowiki"
      "hello world"
    when "testparams"
      "{{{def|hello world}}} {{{1}}} {{{test}}} {{{nested|{{{2}}}}}}"
    when "moreparamtest"
      "{{{{{test|bla}}|wtf}}}"
    when "loop"
      "{{loop}}"
    when "tablebegin"
      "<table>"
    when "tablemid"
      "<tr><td>test</td></tr>"
    when "tableend"
      "</table>"
    end
  end
  external_link do |url,text|
    "<a href=\"#{url}\" target=\"_blank\" class=\"exlink\">#{text.blank? ? url : text}</a>"
  end
end

class WikiClothTest < ActiveSupport::TestCase

  test "math tag" do
    wiki = WikiParser.new(:data => "<math>1-\frac{k}{|E(G_j)|}</math>")
    begin
      data = wiki.to_html
      assert true
    rescue
      assert false
    end
  end

  test "links and references" do
    wiki = WikiCloth::Parser.new(:data => File.open(File.join(File.dirname(__FILE__), '../sample_documents/george_washington.wiki'), READ_MODE) { |f| f.read })
    data = wiki.to_html
    assert wiki.external_links.size == 38
    assert wiki.references.size == 76
    assert wiki.internal_links.size == 450
  end
 
  test "links with imbedded links" do
    wiki = WikiParser.new(:data => "[[Datei:Schulze and Gerard 01.jpg|miniatur|Klaus Schulze während eines Konzerts mit [[Lisa Gerrard]]]] hello world")
    data = wiki.to_html
    assert data =~ /Lisa Gerrard/
  end
 
  test "links with trailing letters" do
    wiki = WikiParser.new(:data => "[[test]]s [[rawr]]alot [[some]]thi.ng [[a]] space")
    data = wiki.to_html
    assert data =~ /tests/
    assert data =~ /href="test"/
    assert data =~ /rawralot/
    assert data !~ /something/
    assert data !~ /aspace/
  end

  test "piped links with trailing letters" do
    wiki = WikiParser.new(:data => "[[a|b]]c [[b|c]]d<nowiki>e</nowiki>")
    data = wiki.to_html
    assert data =~ /bc/
    assert data =~ /href="a"/
    assert data =~ /cd/
    assert data !~ /cde/
  end

  test "Embedded images with no explicit title" do
    wiki = WikiParser.new(:data => "[[Image:Rectangular coordinates.svg|left|thumb|250px]]")
    test = true
    begin
      data = wiki.to_html
    rescue
      test = false 
    end
    assert test == true
  end

  test "First item in list not created when list is preceded by a heading" do
    wiki = WikiParser.new(:data => "=Heading=\n* One\n* Two\n* Three")
    data = wiki.to_html
    assert data !~ /\*/
  end

  test "behavior switch should not show up in the html output" do
    wiki = WikiParser.new(:data => "__NOTOC__hello world")
    data = wiki.to_html
    assert data !~ /TOC/
  end

  test "template vars should not be parsed inside a pre tag" do
    wiki = WikiCloth::Parser.new(:data => "<pre>{{{1}}}</pre>")
    data = wiki.to_html
    assert data =~ /&#123;&#123;&#123;1&#125;&#125;&#125;/
  end

  test "[[ links ]] should not work inside pre tags" do
    data = <<EOS 
Now instead of calling WikiCloth::Parser directly call your new class.

<pre>  @wiki = WikiParser.new({
    :params => { "PAGENAME" => "Testing123" },
    :data => "[[test]] {{hello|world}} From {{ PAGENAME }} -- [www.google.com]"
  })

  @wiki.to_html</pre>
EOS
    wiki = WikiCloth::Parser.new(:data => data)
    data = wiki.to_html
    assert data !~ /href/
    assert data !~ /\{/
    assert data !~ /\]/
  end

  test "auto pre at end of document" do
    wiki = WikiParser.new(:data => "test\n\n hello\n world\nend")
    data = wiki.to_html
    assert data =~ /hello/
    assert data =~ /world/

    wiki = WikiParser.new(:data => "test\n\n hello\n world")
    data = wiki.to_html
    assert data =~ /hello/
    assert data =~ /world/
  end

  test "template params" do
    wiki = WikiParser.new(:data => "{{testparams|test|test=bla|it worked|bla=whoo}}\n")
    data = wiki.to_html
    assert data =~ /hello world/
    assert data =~ /test/
    assert data =~ /bla/
    assert data =~ /it worked/ # nested default param

    wiki = WikiParser.new(:data => "{{moreparamtest|p=othervar}}")
    data = wiki.to_html
    assert data =~ /wtf/

    wiki = WikiParser.new(:data => "{{moreparamtest|p=othervar|busted=whoo}}")
    data = wiki.to_html
    assert data =~ /whoo/
  end
  
  test "table spanning template" do
    wiki = WikiParser.new(:data => "{{tablebegin}}{{tablemid}}{{tableend}}")
    data = wiki.to_html
    
    assert data =~ /test/
  end

  test "horizontal rule" do
    wiki = WikiParser.new(:data => "----\n")
    data = wiki.to_html
    assert data =~ /hr/
  end

  test "template loops" do
    wiki = WikiParser.new(:data => "{{#iferror:{{loop}}|loop detected|wtf}}")
    data = wiki.to_html
    assert data =~ /loop detected/
  end

  test "input with no newline" do
    wiki = WikiParser.new(:data => "{{test}}")
    data = wiki.to_html
    assert data =~ /busted/
  end

  test "lists" do
    wiki = WikiParser.new(:data => "* item 1\n* item 2\n* item 3\n")
    data = wiki.to_html
    assert data =~ /ul/
    count = 0
    # should == 6.. 3 <li>'s and 3 </li>'s
    data.gsub(/li/) { |ret|
      count += 1
      ret
    }
    assert_equal count.to_s, "6"
  end

  test "noinclude and includeonly tags" do
    wiki = WikiParser.new(:data => "<noinclude>main page</noinclude><includeonly>never seen</includeonly>{{noinclude}}\n")
    data = wiki.to_html
    assert data =~ /testing/
    assert data =~ /main page/
    assert !(data =~ /never seen/)
    assert !(data =~ /hello world/)
  end

  test "bold/italics" do
    wiki = WikiParser.new(:data => "test ''testing'' '''123''' '''''echo'''''\n")
    data = wiki.to_html
    assert data =~ /<i>testing<\/i>/
    assert data =~ /<b>123<\/b>/
    assert data =~ /<b><i>echo<\/i><\/b>/
  end

  test "sanitize html" do
    wiki = WikiParser.new(:data => "<script type=\"text/javascript\" src=\"bla.js\"></script>\n<a href=\"test.html\" onmouseover=\"alert('hello world');\">test</a>\n")
    data = wiki.to_html
    assert !(data =~ /<script/)
    assert !(data =~ /onmouseover/)
  end

  test "nowiki and code tags" do
    wiki = WikiParser.new(:data => "<nowiki>{{test}}</nowiki><code>{{test}}</code>{{nowiki}}\n")
    data = wiki.to_html
    assert !(data =~ /busted/)
    assert data =~ /hello world/
  end

  test "disable edit stuff" do
    wiki = WikiParser.new(:data => "= Hallo =")
    data = wiki.to_html
    assert_equal data, "\n<h1><span class=\"editsection\">&#91;<a href=\"?section=Hallo\" title=\"Edit section: Hallo\">edit</a>&#93;</span> <span class=\"mw-headline\" id=\"Hallo\"><a name=\"Hallo\">Hallo</a></span></h1>"

    data = wiki.to_html(:noedit => true)
    assert_equal data, "\n<h1><span class=\"mw-headline\" id=\"Hallo\"><a name=\"Hallo\">Hallo</a></span></h1>"

  end

end
